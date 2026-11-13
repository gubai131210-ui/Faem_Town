class_name Npc
extends Node2D
## 地图上的一位居民：站着或者沿一串格子走路。去哪儿由地图按日程决定，这里只管走和画。
## 为了不像木偶：起步和停下有加减速，拐弯抄近一点，站着时偶尔往旁边看一眼，玩家走近了会转过来。

## 走到了路的尽头；vanish 为真表示这位居民要离开这张地图
signal arrived(npc: Npc, vanish: bool)
## 前面的格子被人占着，等了一阵还没让开，请地图换一条路
signal stuck(npc: Npc)

## 走一个完整的循环（左右各一步）前进这么多像素；和腿摆的幅度对上，脚才不打滑
const STRIDE := 24.0
const ACCEL := 140.0
## 离终点这么近开始减速
const SLOW_DISTANCE := 10.0
const MIN_SPEED := 12.0
## 离拐角这么近就开始往下一格走，拐弯是斜着抄过去的
const CORNER := 5.0
## 走到终点前，玩家离终点这么近就先等着，免得停下来把玩家卡在同一格里
const WAIT_DISTANCE := 14.0
## 玩家走到这么近，站着的居民会转过来看；走出 NOTICE_FAR 以后再转回去
const NOTICE_NEAR := 26.0
const NOTICE_FAR := 36.0
## 出门、进门时淡入淡出的时间
const FADE := 0.35
## 前面有人挡着，等这么久再找别的路
const STUCK_TIME := 1.6
## 坐在长凳上时，人往上挪这么多像素，屁股才落在凳面上
const SIT_LIFT := 9.0
const DIR_VECTORS: Array[Vector2] = [Vector2.DOWN, Vector2.UP, Vector2.RIGHT, Vector2.LEFT]

var def: NpcDef
var facing := GameMap.Facing.DOWN
## 现在的日程项，地图用它判断日程有没有变
var spot: Dictionary = {}
## 地图给的函数：返回玩家脚底的位置。没给就不等玩家
var player_position := Callable()
## 地图给的函数：func(tile, me) -> bool，这一格是不是被别人（站着的居民、玩家）占着
var occupied := Callable()

var _sheet: CharacterSheet
var _sprite: Sprite2D
var _path: Array[Vector2i] = []
var _end_facing := GameMap.Facing.DOWN
var _vanish := false
var _anim: StringName = &"idle"
var _anim_t := 0.0
var _frame := 0
var _speed := 0.0
## 出发前先转身停一下的时间
var _delay := 0.0
## 站着时本来该朝的方向；看玩家、东张西望之后转回这里
var _home_facing := GameMap.Facing.DOWN
var _watching := false
## 离下一次东张西望还有多久；正在张望时是还要看多久
var _glance_wait := 0.0
var _glancing := false
var _idle_rate := 1.0
var _fade := 1.0
var _leaving := false
var _stuck := 0.0
## 正在和谁聊天（两个人站得近，偶尔面对面说几句）
var _chat_with: Npc
var _chat_left := 0.0
var _bubble: Sprite2D
var _bubble_t := 0.0


func setup(npc_def: NpcDef, tile: Vector2i, new_facing: int) -> void:
	def = npc_def
	name = String(npc_def.id).to_pascal_case()
	position = GameMap.tile_center(tile) + Vector2(0, 4)
	facing = new_facing as GameMap.Facing
	_home_facing = facing
	_sheet = CharacterSheet.load_sheet(npc_def.sheet)
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
	_bubble = Sprite2D.new()
	_bubble.texture = Px.tex(_bubble_image())
	_bubble.position = Vector2(9, -_sheet.foot_row + 6)
	_bubble.visible = false
	add_child(_bubble)
	# 每个人呼吸的快慢和起点都不一样，一群人站着不会同时一起一伏
	_idle_rate = randf_range(0.75, 1.1)
	_anim_t = randf() * 4.0
	_glance_wait = randf_range(3.0, 9.0)
	_apply()


## 从门里出来：淡入。
func appear() -> void:
	_fade = 0.0
	modulate.a = 0.0


func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	if _leaving:
		_fade = maxf(_fade - delta / FADE, 0.0)
		modulate.a = _fade
		if _fade <= 0.0:
			_leaving = false
			set_process(false)
			arrived.emit(self, true)
		return
	if _fade < 1.0:
		_fade = minf(_fade + delta / FADE, 1.0)
		modulate.a = _fade
	# 菜单、对话、转场时时间不走：走着的人停下，站着的人照常呼吸
	if not GameClock.running:
		_speed = 0.0
		_stand(delta)
		return
	if _path.is_empty():
		_idle(delta)
		return
	_walk(delta)


## 现在是不是坐着：日程说在长凳边，而且站定了。
func is_sitting() -> bool:
	return _path.is_empty() and not _leaving and str(spot.get("note", "")) == "bench" and _sheet.has_anim(&"sit")


func _bubble_image() -> Image:
	var img := Image.create(9, 7, false, Image.FORMAT_RGBA8)
	var edge := Color("5a3c2e")
	var fill := Color("fbf3dc")
	img.fill(Color(0, 0, 0, 0))
	for y in range(0, 5):
		for x in range(0, 9):
			var corner := (x == 0 or x == 8) and (y == 0 or y == 4)
			if corner:
				continue
			var border := x == 0 or x == 8 or y == 0 or y == 4
			img.set_pixel(x, y, edge if border else fill)
	for x in [2, 4, 6]:
		img.set_pixel(x, 2, edge)
	img.set_pixel(2, 5, edge)
	img.set_pixel(1, 6, edge)
	return img


func _walk(delta: float) -> void:
	var target := GameMap.tile_center(_path[0]) + Vector2(0, 4)
	var last := _path.size() == 1
	if last and not _vanish and _player_near(target):
		_speed = 0.0
		_stand(delta)
		return
	var to := target - position
	if _delay > 0.0:
		# 先朝要去的方向转过身，顿一下再迈步
		_delay -= delta
		_face_along(to, true)
		_stand(delta)
		return
	# 下一格被人占着就先等等；等久了请地图换条路
	if not last and occupied.is_valid() and bool(occupied.call(_path[0], self)):
		_speed = 0.0
		_face_along(to, true)
		_stand(delta)
		_stuck += delta
		if _stuck >= STUCK_TIME:
			_stuck = 0.0
			stuck.emit(self)
		return
	_stuck = 0.0
	var want := def.speed
	if last:
		want = clampf(def.speed * to.length() / SLOW_DISTANCE, MIN_SPEED, def.speed)
	_speed = move_toward(_speed, want, ACCEL * delta)
	var step := _speed * delta
	var reach := 0.0 if last else CORNER
	if to.length() <= maxf(step, reach):
		if last:
			position = target
		_path.remove_at(0)
		if _path.is_empty():
			_finish()
			return
		to = GameMap.tile_center(_path[0]) + Vector2(0, 4) - position
	position += to.normalized() * minf(step, to.length())
	_face_along(to, false)
	_set_anim(&"walk")
	var n := _sheet.frame_count(&"walk")
	_anim_t += step / STRIDE * n
	_frame = int(_anim_t) % n
	_apply()


func _finish() -> void:
	_speed = 0.0
	if _vanish:
		_leaving = true
		_set_anim(&"idle")
		_apply()
		return
	facing = _end_facing
	_home_facing = _end_facing
	_watching = false
	_glancing = false
	_glance_wait = randf_range(3.0, 9.0)
	_set_anim(&"idle")
	_apply()
	arrived.emit(self, false)


func _idle(delta: float) -> void:
	if _chat_with != null:
		_chat_left -= delta
		if _chat_left <= 0.0 or not is_instance_valid(_chat_with) or _chat_with.is_walking():
			_chat_with = null
			facing = _home_facing
			_glance_wait = randf_range(3.0, 8.0)
		else:
			_bubble_t += delta
			# 两个人轮流“说”：一个人的气泡亮着，另一个人的灭着
			_bubble.visible = fmod(_bubble_t, 2.4) < 1.1
			_stand(delta)
			return
	_bubble.visible = false
	var near := NOTICE_FAR + 1.0
	if player_position.is_valid():
		var pos: Vector2 = player_position.call()
		near = pos.distance_to(position)
		if near < NOTICE_NEAR or (_watching and near < NOTICE_FAR):
			_watching = true
			_glancing = false
			_face_along(pos - position, true)
	if _watching and near >= NOTICE_FAR:
		_watching = false
		facing = _home_facing
		_glance_wait = randf_range(2.0, 6.0)
	if not _watching:
		_glance_wait -= delta
		if _glance_wait <= 0.0:
			if _glancing:
				_glancing = false
				facing = _home_facing
				_glance_wait = randf_range(4.0, 11.0)
			else:
				_glancing = true
				facing = _side_of(_home_facing)
				_glance_wait = randf_range(1.0, 2.4)
	_stand(delta)


## 两个人聊起来：面对着对方，持续 seconds 秒；offset 让对方的气泡错开亮。
func chat(other: Npc, seconds: float, offset: float) -> void:
	_chat_with = other
	_chat_left = seconds
	_bubble_t = offset
	_watching = false
	_glancing = false
	_face_along(other.position - position, true)
	_apply()


func is_chatting() -> bool:
	return _chat_with != null


## 站着的动作：坐在长凳边就是坐着，否则慢慢地一起一伏。
func _stand(delta: float) -> void:
	if is_sitting():
		_set_anim(&"sit")
		_frame = 0
		_sprite.position.y = -_sheet.foot_row - SIT_LIFT
		_apply()
		return
	_sprite.position.y = -_sheet.foot_row
	_set_anim(&"idle")
	_anim_t += delta * _sheet.fps(&"idle") * _idle_rate
	_frame = int(_anim_t) % _sheet.frame_count(&"idle")
	_apply()


## 沿 path 走过去，到了以后面朝 end_facing；vanish 为真时到了就离开地图。
func walk(path: Array[Vector2i], end_facing: int, vanish: bool = false) -> void:
	_path = path.duplicate()
	_end_facing = end_facing as GameMap.Facing
	_vanish = vanish
	_watching = false
	_glancing = false
	_chat_with = null
	_bubble.visible = false
	_stuck = 0.0
	if _path.is_empty():
		if vanish:
			_leaving = true
			return
		facing = _end_facing
		_home_facing = _end_facing
		_apply()
		arrived.emit(self, false)
		return
	_delay = randf_range(0.15, 0.6)


func is_walking() -> bool:
	return not _path.is_empty() or _leaving


## 脚下的格子。
func tile() -> Vector2i:
	return GameMap.tile_of(position + Vector2(0, -4))


## 站着不动时占住的格子，玩家走不进去；走路时不挡人。
func solid_tile() -> Vector2i:
	return Vector2i(-999, -999) if is_walking() else tile()


## 转过去面对 pos（玩家来搭话时）。
func face_toward(pos: Vector2) -> void:
	_face_along(pos - position, true)
	_watching = true
	_glancing = false
	_chat_with = null
	_bubble.visible = false
	_apply()


## 按移动的方向定朝向。走路时两个方向差不多大就保持原来的朝向，免得斜着走时来回抖。
func _face_along(to: Vector2, snap: bool) -> void:
	var ax := absf(to.x)
	var ay := absf(to.y)
	if ax < 0.01 and ay < 0.01:
		return
	var horizontal := facing == GameMap.Facing.RIGHT or facing == GameMap.Facing.LEFT
	if not snap:
		if horizontal and ax * 1.6 > ay:
			ay = 0.0
		elif not horizontal and ay * 1.6 > ax:
			ax = 0.0
	if ax > ay:
		facing = GameMap.Facing.RIGHT if to.x > 0.0 else GameMap.Facing.LEFT
	else:
		facing = GameMap.Facing.DOWN if to.y > 0.0 else GameMap.Facing.UP


## 东张西望时看向哪边：正对着或背对着镜头就看左右，侧着站就转过来看镜头。
func _side_of(base: GameMap.Facing) -> GameMap.Facing:
	if base == GameMap.Facing.DOWN or base == GameMap.Facing.UP:
		return GameMap.Facing.LEFT if randf() < 0.5 else GameMap.Facing.RIGHT
	return GameMap.Facing.DOWN


func _player_near(target: Vector2) -> bool:
	if not player_position.is_valid():
		return false
	var pos: Vector2 = player_position.call()
	return pos.distance_to(target) < WAIT_DISTANCE


func _set_anim(anim: StringName) -> void:
	if _anim == anim:
		return
	_anim = anim
	if anim == &"walk":
		_anim_t = 0.0
	_frame = 0


func _apply() -> void:
	if _sheet != null and _sheet.is_valid():
		_sprite.region_rect = _sheet.region(_anim, facing, _frame)
