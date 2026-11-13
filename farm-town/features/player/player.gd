class_name Player
extends Node2D
## 玩家角色：移动、朝向、序列帧动画、工具动作。
## 不知道地图上有什么，也不改游戏状态；动作生效时发 acted 信号，由上层处理。

## 动作进行到生效的那一帧
signal acted(action: StringName, tile: Vector2i)
signal stepped

## HOLDING：保持一个循环动作（持竿等鱼），不接受移动，直到 release()
## ROLLING：翻滚，朝一个方向冲一小段，这期间打不着
enum State { FREE, ACTING, HOLDING, ROLLING }

const MAX_SPEED := 78.0
## 吃了“脚步轻快”的食物以后走得快多少
const SWIFT_SPEED := 1.2
const ACCEL := 620.0
const FRICTION := 900.0
## 走过这么多像素换一帧（按 6 帧一个循环计），让脚步和位移对得上
const PX_PER_FRAME := 7.0
## 翻滚：多快、滚多久（滚出去差不多三格）
const ROLL_SPEED := 150.0
const ROLL_TIME := 0.3
## 挨了一下以后多久之内不会再挨，以及被撞开的速度
const HURT_TIME := 0.8
const KNOCK_SPEED := 120.0
const DIR_VECTORS: Array[Vector2] = [Vector2.DOWN, Vector2.UP, Vector2.RIGHT, Vector2.LEFT]
## 地图动作名对应的角色动画
const ACTION_ANIMS: Dictionary[StringName, StringName] = {
	&"hoe": &"hoe",
	&"water": &"water",
	&"dig": &"hoe",
	&"plant": &"reach",
	&"fertilize": &"reach",
	&"harvest": &"reach",
	&"cast": &"cast",
	&"place_trap": &"reach",
	&"tend": &"reach",
	&"place": &"reach",
	&"mine": &"hoe",
	# 三类武器的一下：镰刀横扫、短剑直刺、锤往下砸
	&"slash": &"slash",
	&"stab": &"stab",
	&"smash": &"smash",
}

var map: GameMap
var facing := GameMap.Facing.DOWN
var velocity := Vector2.ZERO
var input_enabled := true
var state := State.FREE
## 翻滚完再多这么多秒打不着（饰品给的）。地图每帧写
var roll_grace := 0.0
var _grace_t := 0.0
## 走路的速度再乘这么多（蹚水、走时钟旁边）。地图每帧写，换地图时回到 1
var slow := 1.0

var _sheet: CharacterSheet
var _sprite: Sprite2D
var _anim: StringName = &"idle"
var _frame := 0
var _anim_t := 0.0
var _act_name: StringName
var _act_tile := Vector2i.ZERO
var _act_seq: Array = []
var _act_strike := 0
var _act_i := 0
var _act_t := 0.0
## 这次动作放多快（1 是序列帧里写的时间）
var _act_speed := 1.0
var _roll_dir := Vector2.DOWN
var _roll_t := 0.0
var _hurt_t := 0.0


func _ready() -> void:
	_sheet = CharacterSheet.load_sheet("farmer")
	var shadow := Sprite2D.new()
	shadow.texture = Px.tex(PixelArt.shadow(14, 5, 0.28))
	shadow.position = Vector2(0, -1)
	shadow.z_index = -1
	add_child(shadow)
	_sprite = Sprite2D.new()
	_sprite.texture = _sheet.texture
	_sprite.centered = false
	_sprite.region_enabled = true
	_sprite.position = Vector2(-_sheet.cell / 2.0, -_sheet.foot_row)
	add_child(_sprite)
	_apply()


func _process(delta: float) -> void:
	# 卡顿时限制单帧步长，避免一帧走太远穿过障碍
	delta = minf(delta, 0.05)
	_grace_t = maxf(0.0, _grace_t - delta)
	if _hurt_t > 0.0:
		_hurt_t = maxf(0.0, _hurt_t - delta)
		# 挨打以后闪几下
		_sprite.modulate.a = 0.4 if _hurt_t > 0.0 and int(_hurt_t * 14.0) % 2 == 0 else 1.0
	if state == State.ROLLING:
		_update_roll(delta)
		return
	if state == State.ACTING:
		_update_action(delta)
		return
	if state == State.HOLDING:
		_anim_t += delta * _sheet.fps(_anim)
		_frame = int(_anim_t) % maxi(1, _sheet.frame_count(_anim))
		_apply()
		return
	var inp := Vector2.ZERO
	if input_enabled:
		inp = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if inp.length() > 0.1:
		var top := MAX_SPEED * (SWIFT_SPEED if GameState.buff_active(&"swift") else 1.0) * slow
		velocity = velocity.move_toward(inp.limit_length(1.0) * top, ACCEL * delta)
		_update_facing(inp)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	_move(velocity * delta)
	_update_locomotion(delta)
	_apply()


func is_acting() -> bool:
	return state == State.ACTING


## 面前的那一格。
func target_tile() -> Vector2i:
	return GameMap.tile_of(position + Vector2(0, -3) + DIR_VECTORS[facing] * 13.0)


## 开始一个带动画的动作；动画播到生效帧时发 acted。speed 大于 1 放得快。
func start_action(action: StringName, tile: Vector2i, speed: float = 1.0) -> void:
	if state == State.ACTING or state == State.ROLLING or not ACTION_ANIMS.has(action):
		return
	var anim := ACTION_ANIMS[action]
	var seq := _sheet.sequence(anim)
	if seq.is_empty():
		acted.emit(action, tile)
		return
	state = State.ACTING
	velocity = Vector2.ZERO
	_act_speed = maxf(0.2, speed)
	_anim = anim
	_act_name = action
	_act_tile = tile
	_act_seq = seq
	_act_strike = _sheet.strike_index(anim)
	_act_i = 0
	_act_t = 0.0
	_enter_action_step()


## 朝 dir 翻滚一小段。正在做动作、持竿、已经在滚的时候滚不了，返回假。
func roll(dir: Vector2) -> bool:
	if state != State.FREE or dir.length() < 0.1:
		return false
	state = State.ROLLING
	_roll_dir = dir.normalized()
	_roll_t = 0.0
	velocity = Vector2.ZERO
	_update_facing(_roll_dir)
	_anim = &"roll" if _sheet.has_anim(&"roll") else &"walk"
	_frame = 0
	_apply()
	return true


func is_rolling() -> bool:
	return state == State.ROLLING


## 这一刻打不着：正在翻滚，或者刚挨过一下。
func invincible() -> bool:
	return state == State.ROLLING or _hurt_t > 0.0 or _grace_t > 0.0


## 挨了一下：往 away 那边被撞开，接下来一小会儿不会再挨。
func hurt(away: Vector2) -> void:
	_hurt_t = HURT_TIME
	if state == State.FREE and away.length() > 0.01:
		velocity = away.normalized() * KNOCK_SPEED


## 被带着挪 d 这么远（短剑的突进），撞到东西就停。返回实际挪到了哪。
func shove(d: Vector2) -> Vector2:
	var steps := maxi(1, ceili(d.length() / 3.0))
	for i in steps:
		var before := position
		_move(d / steps)
		if position.distance_to(before) < 0.01:
			break
	return position


## 立刻停下并回到站立，用于转场、对话开始时。
func halt() -> void:
	velocity = Vector2.ZERO
	if state == State.FREE:
		_set_idle()
		_apply()


## 摆一个循环的姿势不动（持竿等鱼）。序列帧里没有这个动作就站着。
func hold(anim: StringName) -> void:
	velocity = Vector2.ZERO
	state = State.HOLDING
	_anim = anim if _sheet.has_anim(anim) else &"idle"
	_anim_t = 0.0
	_frame = 0
	_apply()


func is_holding() -> bool:
	return state == State.HOLDING


## 正在保持的姿势（没有就是空）。
func held_anim() -> StringName:
	return _anim if state == State.HOLDING else &""


## 手里鱼竿的竿尖在哪（世界坐标）。当前这一帧没有竿就用持竿姿势的位置。
func rod_tip() -> Vector2:
	var anim := _anim if _sheet.has_tip(_anim) else &"fish"
	return position + _sheet.tip(anim, facing, _frame)


## 从 hold 的姿势回到站立。
func release() -> void:
	if state == State.HOLDING:
		state = State.FREE
		_set_idle()
		_apply()


func place(pos: Vector2, new_facing: GameMap.Facing) -> void:
	position = pos
	facing = new_facing
	velocity = Vector2.ZERO
	state = State.FREE
	slow = 1.0
	roll_grace = 0.0
	_grace_t = 0.0
	_hurt_t = 0.0
	_sprite.modulate.a = 1.0
	_set_idle()
	_apply()


func _update_roll(delta: float) -> void:
	_roll_t += delta
	_move(_roll_dir * ROLL_SPEED * delta)
	var n := maxi(1, _sheet.frame_count(_anim))
	_frame = mini(n - 1, int(_roll_t / ROLL_TIME * n))
	_apply()
	if _roll_t >= ROLL_TIME:
		state = State.FREE
		_grace_t = roll_grace
		# 滚完带着一点速度接着走
		velocity = _roll_dir * MAX_SPEED * 0.5
		_set_idle()
		_apply()


func _move(d: Vector2) -> void:
	if map == null:
		position += d
		return
	# 两个轴分开判断，贴着墙走时可以沿墙滑动
	var p := position
	var nx := Vector2(p.x + d.x, p.y)
	if not map.blocked(nx):
		p = nx
	else:
		velocity.x = 0.0
	var ny := Vector2(p.x, p.y + d.y)
	if not map.blocked(ny):
		p = ny
	else:
		velocity.y = 0.0
	position = p


func _update_facing(inp: Vector2) -> void:
	var ax := absf(inp.x)
	var ay := absf(inp.y)
	var horiz := GameMap.Facing.RIGHT if inp.x > 0.0 else GameMap.Facing.LEFT
	var vert := GameMap.Facing.DOWN if inp.y > 0.0 else GameMap.Facing.UP
	if ax > 0.1 and ay > 0.1:
		# 斜向移动时保持原来的朝向，避免来回抖动
		if facing != horiz and facing != vert:
			facing = horiz
	elif ax > ay:
		facing = horiz
	else:
		facing = vert


func _update_locomotion(delta: float) -> void:
	var speed := velocity.length()
	if speed > 8.0:
		if _anim != &"walk":
			_anim = &"walk"
			_anim_t = 1.0
		var n := _sheet.frame_count(&"walk")
		_anim_t += speed * delta / PX_PER_FRAME * n / 6.0
		var f := int(_anim_t) % n
		if f != _frame and _sheet.step_frames(&"walk").has(float(f)):
			stepped.emit()
		_frame = f
	else:
		if _anim != &"idle":
			_set_idle()
		_anim_t += delta * _sheet.fps(&"idle")
		_frame = int(_anim_t) % _sheet.frame_count(&"idle")


func _set_idle() -> void:
	_anim = &"idle"
	_anim_t = 0.0
	_frame = 0


func _enter_action_step() -> void:
	var step: Array = _act_seq[_act_i]
	_frame = int(step[0])
	_apply()
	if _act_i == _act_strike:
		acted.emit(_act_name, _act_tile)


func _update_action(delta: float) -> void:
	_act_t += delta
	var step: Array = _act_seq[_act_i]
	var duration := float(step[1]) / _act_speed
	if _act_t < duration:
		return
	_act_t -= duration
	_act_i += 1
	if _act_i >= _act_seq.size():
		state = State.FREE
		_set_idle()
		_apply()
		return
	_enter_action_step()


func _apply() -> void:
	if _sheet.is_valid():
		_sprite.region_rect = _sheet.region(_anim, facing, _frame)
