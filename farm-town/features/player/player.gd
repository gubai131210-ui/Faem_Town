class_name Player
extends Node2D
## 玩家角色：移动、朝向、序列帧动画、工具动作。
## 不知道地图上有什么，也不改游戏状态；动作生效时发 acted 信号，由上层处理。

## 动作进行到生效的那一帧
signal acted(action: StringName, tile: Vector2i)
signal stepped

enum State { FREE, ACTING }

const MAX_SPEED := 78.0
const ACCEL := 620.0
const FRICTION := 900.0
## 走过这么多像素换一帧（按 6 帧一个循环计），让脚步和位移对得上
const PX_PER_FRAME := 7.0
const DIR_VECTORS: Array[Vector2] = [Vector2.DOWN, Vector2.UP, Vector2.RIGHT, Vector2.LEFT]
## 地图动作名对应的角色动画
const ACTION_ANIMS: Dictionary[StringName, StringName] = {
	&"hoe": &"hoe",
	&"water": &"water",
	&"plant": &"reach",
	&"harvest": &"reach",
}

var map: GameMap
var facing := GameMap.Facing.DOWN
var velocity := Vector2.ZERO
var input_enabled := true
var state := State.FREE

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
	if state == State.ACTING:
		_update_action(delta)
		return
	var inp := Vector2.ZERO
	if input_enabled:
		inp = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if inp.length() > 0.1:
		velocity = velocity.move_toward(inp.limit_length(1.0) * MAX_SPEED, ACCEL * delta)
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


## 开始一个带动画的动作；动画播到生效帧时发 acted。
func start_action(action: StringName, tile: Vector2i) -> void:
	if state == State.ACTING or not ACTION_ANIMS.has(action):
		return
	var anim := ACTION_ANIMS[action]
	var seq := _sheet.sequence(anim)
	if seq.is_empty():
		acted.emit(action, tile)
		return
	state = State.ACTING
	velocity = Vector2.ZERO
	_anim = anim
	_act_name = action
	_act_tile = tile
	_act_seq = seq
	_act_strike = _sheet.strike_index(anim)
	_act_i = 0
	_act_t = 0.0
	_enter_action_step()


## 立刻停下并回到站立，用于转场、对话开始时。
func halt() -> void:
	velocity = Vector2.ZERO
	if state == State.FREE:
		_set_idle()
		_apply()


func place(pos: Vector2, new_facing: GameMap.Facing) -> void:
	position = pos
	facing = new_facing
	velocity = Vector2.ZERO
	state = State.FREE
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
	var duration := float(step[1])
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
