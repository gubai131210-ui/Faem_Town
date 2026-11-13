class_name Critter
extends Node2D
## 地图上的一只动物：在自己的院子里慢慢逛，停下来啄两口、吃两口草。只管走和画，喂和摸由地图处理。
## 会水的（鸭）能走进 swim_area 里的水面，在水里只露上半身；人贴得太近会让开；被牵着（水牛）就跟着人走。

const DIR_VECTORS: Array[Vector2] = [Vector2.DOWN, Vector2.UP, Vector2.RIGHT, Vector2.LEFT]
## 走一个循环前进多少像素
const STRIDE := 10.0
## 人离得比这还近就让开
const CROWD := 7.0
## 被牵着的时候和人保持的距离
const LEAD_NEAR := 20.0
const LEAD_FAR := 26.0
## 在水里身子沉下去几行
const SINK := 4

var def: AnimalDef
## 它在 Animals.animals 里的下标
var index := 0
var facing := GameMap.Facing.DOWN
## 地图给的函数：func(tile) -> bool，这一格能不能走 / 是不是水
var walkable := Callable()
var water := Callable()
## 活动范围（格子）；会水的还能去 swim_area
var yard := Rect2i()
var swim_area := Rect2i()
## 要躲着的人（玩家）
var avoid: Node2D
## 牵着它的人；空就是自己逛
var leader: Node2D

var _sheet: CharacterSheet
var _sprite: Sprite2D
var _shadow: Sprite2D
var _anim: StringName = &"idle"
var _anim_t := 0.0
var _frame := 0
var _target := Vector2.ZERO
var _moving := false
var _wait := 0.0
var _wet := false
var _rng := RandomNumberGenerator.new()


func setup(animal_def: AnimalDef, animal_index: int, pos: Vector2) -> void:
	def = animal_def
	index = animal_index
	position = pos
	_rng.randomize()
	_sheet = CharacterSheet.load_sheet(animal_def.sheet, CharacterSheet.CREATURE_DIR)
	_shadow = Sprite2D.new()
	_shadow.texture = Px.tex(PixelArt.shadow(10 if _sheet.cell <= 32 else 22, 4 if _sheet.cell <= 32 else 6, 0.26))
	_shadow.position = Vector2(0, -1)
	_shadow.z_index = -1
	add_child(_shadow)
	_sprite = Sprite2D.new()
	_sprite.texture = _sheet.texture
	_sprite.centered = false
	_sprite.region_enabled = true
	_sprite.position = Vector2(-_sheet.cell / 2.0, -_sheet.foot_row)
	add_child(_sprite)
	facing = _rng.randi_range(0, 3) as GameMap.Facing
	_wait = _rng.randf_range(0.5, 4.0)
	_anim_t = _rng.randf() * 4.0
	_apply()


func tile() -> Vector2i:
	return GameMap.tile_of(position + Vector2(0, -2))


func in_water() -> bool:
	return _wet


## 被喂、被摸的时候停下来，转过去。
func notice(pos: Vector2) -> void:
	_moving = false
	_wait = 1.6
	_set_anim(&"idle")
	_face(pos - position)
	_apply()


func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	if not GameClock.running:
		return
	if leader != null and is_instance_valid(leader):
		_follow(delta)
		return
	if _moving:
		_walk(delta, def.speed)
		return
	if avoid != null and is_instance_valid(avoid) and _wait < 1.0 and avoid.position.distance_to(position) < CROWD:
		_step_aside()
	_wait -= delta
	if _wait <= 0.0:
		if _anim == &"idle" and not _wet and _sheet.has_anim(&"peck") and _rng.randf() < 0.4:
			_set_anim(&"peck")
			_wait = _rng.randf_range(1.0, 2.2)
		else:
			_pick_target()
	_anim_t += delta * _sheet.fps(_anim)
	_frame = int(_anim_t) % _sheet.frame_count(_anim)
	_apply()


func _allowed(t: Vector2i) -> bool:
	if yard.has_point(t):
		return true
	return def.swims and swim_area.has_point(t)


func _can_stand(t: Vector2i) -> bool:
	if def.swims and water.is_valid() and bool(water.call(t)):
		return true
	return not walkable.is_valid() or bool(walkable.call(t))


func _pick_target() -> void:
	_set_anim(&"idle")
	_wait = _rng.randf_range(1.5, 5.0)
	var here := tile()
	for i in 6:
		var t := here + Vector2i(_rng.randi_range(-3, 3), _rng.randi_range(-2, 2))
		if t == here or not _allowed(t) or not _clear_line(here, t):
			continue
		_target = GameMap.tile_center(t) + Vector2(_rng.randf_range(-4, 4), _rng.randf_range(-2, 4))
		_moving = true
		return


## 人挤过来了：往反方向挪一格。
func _step_aside() -> void:
	var away := position - avoid.position
	if away.length() < 0.5:
		away = DIR_VECTORS[_rng.randi_range(0, 3)]
	var here := tile()
	for turn: float in [0.0, 0.8, -0.8, 1.6, -1.6]:
		var to := position + away.normalized().rotated(turn) * 14.0
		var t := GameMap.tile_of(to + Vector2(0, -2))
		if _can_stand(t) and _clear_line(here, t):
			_target = to
			_moving = true
			return


## 从 a 到 b 的直线上每一格都能走。
func _clear_line(a: Vector2i, b: Vector2i) -> bool:
	var steps := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in range(1, steps + 1):
		var p := Vector2(a) + Vector2(b - a) * (float(i) / steps)
		if not _can_stand(Vector2i(roundi(p.x), roundi(p.y))):
			return false
	return true


func _walk(delta: float, speed: float) -> void:
	var to := _target - position
	var step := speed * delta
	if to.length() <= step:
		position = _target
		_moving = false
		_set_anim(&"idle")
		_apply()
		return
	position += to.normalized() * step
	_face(to)
	_set_anim(&"walk")
	var n := _sheet.frame_count(&"walk")
	_anim_t += step / STRIDE * n
	_frame = int(_anim_t) % n
	_apply()


## 被牵着：离远了就跟上去，不管路上有什么（牵着走的时候人会带它绕）。
func _follow(delta: float) -> void:
	var to := leader.position - position
	if to.length() > LEAD_FAR or (_moving and to.length() > LEAD_NEAR):
		_moving = true
		_target = leader.position - to.normalized() * LEAD_NEAR
		_walk(delta, maxf(def.speed, 70.0))
		return
	_moving = false
	_set_anim(&"idle")
	_face(to)
	_anim_t += delta * _sheet.fps(_anim)
	_frame = int(_anim_t) % _sheet.frame_count(_anim)
	_apply()


func _face(to: Vector2) -> void:
	if absf(to.x) < 0.01 and absf(to.y) < 0.01:
		return
	# 动物侧着好看，横向稍微有点就朝左右
	if absf(to.x) * 1.5 > absf(to.y):
		facing = GameMap.Facing.RIGHT if to.x > 0.0 else GameMap.Facing.LEFT
	else:
		facing = GameMap.Facing.DOWN if to.y > 0.0 else GameMap.Facing.UP


func _set_anim(anim: StringName) -> void:
	if _anim == anim:
		return
	_anim = anim
	_anim_t = 0.0
	_frame = 0


func _apply() -> void:
	if _sheet == null or not _sheet.is_valid():
		return
	var wet := def.swims and water.is_valid() and bool(water.call(tile()))
	if wet != _wet:
		_wet = wet
		_shadow.visible = not wet
		queue_redraw()
	# 在水里不迈腿：用站着的那一帧，下半身切掉，整个往下沉一点
	var r := _sheet.region(&"idle" if wet else _anim, facing, _frame % _sheet.frame_count(&"idle") if wet else _frame)
	if wet:
		r.size.y = _sheet.foot_row - SINK
		_sprite.position.y = -_sheet.foot_row + SINK
	else:
		_sprite.position.y = -_sheet.foot_row
	_sprite.region_rect = r


func _draw() -> void:
	if _wet:
		draw_rect(Rect2(-7, -1, 14, 1), Color(0.86, 0.95, 1.0, 0.7))
		draw_rect(Rect2(-4, 0, 8, 1), Color(0.86, 0.95, 1.0, 0.4))
