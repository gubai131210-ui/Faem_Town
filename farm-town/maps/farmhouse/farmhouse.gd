extends GameMap
## 农舍室内：床（睡觉）、桌子、出门的门垫。

const W := 12
const H := 9
const WALL_ROWS := 2
const BED_TILES: Array[Vector2i] = [Vector2i(1, 2), Vector2i(1, 3)]
const TABLE_TILES: Array[Vector2i] = [Vector2i(7, 4), Vector2i(8, 4)]
const EXIT_TILES: Array[Vector2i] = [Vector2i(5, 8), Vector2i(6, 8)]
const INTRO_DIALOGUE := "res://dialogue/intro.dialogue"
const COMMON_DIALOGUE := "res://dialogue/common.dialogue"

var _solid: Dictionary[Vector2i, bool] = {}
var _windows: Array[Sprite2D] = []
var _window_day: Texture2D
var _window_night: Texture2D
var _is_night := false


func _ready() -> void:
	map_id = &"farmhouse"
	indoor = true

	var room := Px.new_img(W * TS, H * TS)
	Px.blit(room, PixelArt.wall(W * TS, WALL_ROWS * TS), 0, 0)
	Px.blit(room, PixelArt.floor_wood(W * TS, (H - WALL_ROWS) * TS), 0, WALL_ROWS * TS)
	Px.rect(room, 0, WALL_ROWS * TS, W * TS, 2, Color(0.35, 0.22, 0.14, 0.55))
	Px.blit(room, PixelArt.rug(56, 34), 60, 76)
	Px.blit(room, PixelArt.doormat(), 86, 134)
	var ground := Sprite2D.new()
	ground.centered = false
	ground.texture = Px.tex(room)
	ground.z_index = -10
	add_child(ground)

	_window_day = Px.tex(PixelArt.window(false))
	_window_night = Px.tex(PixelArt.window(true))
	for x: int in [52, 122]:
		var w := Sprite2D.new()
		w.centered = false
		w.position = Vector2(x, 7)
		w.z_index = -9
		add_child(w)
		_windows.append(w)
	_update_windows(true)

	entities = Node2D.new()
	entities.y_sort_enabled = true
	add_child(entities)
	_prop(PixelArt.bed(), Vector2(27, 66), Vector2(-12, -35))
	_prop(PixelArt.table(), Vector2(128, 82), Vector2(-14, -21))
	for t in BED_TILES:
		_solid[t] = true
	for t in TABLE_TILES:
		_solid[t] = true


func _process(_delta: float) -> void:
	_update_windows(false)


func size_px() -> Vector2i:
	return Vector2i(W * TS, H * TS)


func spawn_position(spawn: StringName) -> Vector2:
	if spawn == &"bed":
		return tile_center(Vector2i(2, 3))
	return tile_center(Vector2i(5, 7)) + Vector2(8, 0)


func spawn_facing(spawn: StringName) -> Facing:
	return Facing.DOWN if spawn == &"bed" else Facing.UP


func blocked(p: Vector2) -> bool:
	for c: Vector2 in [Vector2(-4, -4), Vector2(4, -4), Vector2(-4, 1), Vector2(4, 1)]:
		var t := tile_of(p + c)
		if t.x < 0 or t.x >= W or t.y < WALL_ROWS or t.y >= H or _solid.has(t):
			return true
	return false


func query_use(_item: ItemDef, tile: Vector2i, _facing: Facing) -> StringName:
	if BED_TILES.has(tile) or TABLE_TILES.has(tile):
		return &"interact"
	return &""


func perform(action: StringName, _item: ItemDef, tile: Vector2i) -> void:
	if action != &"interact":
		return
	if BED_TILES.has(tile):
		EventBus.dialogue_requested.emit(COMMON_DIALOGUE, "bed")
	elif TABLE_TILES.has(tile):
		EventBus.dialogue_requested.emit(INTRO_DIALOGUE, "table")


func trigger_at(tile: Vector2i) -> Dictionary:
	if EXIT_TILES.has(tile):
		return {"map": &"farm", "spawn": &"house_door"}
	return {}


func _prop(img: Image, pos: Vector2, offset: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = Px.tex(img)
	s.centered = false
	s.offset = offset
	s.position = pos
	entities.add_child(s)


func _update_windows(force: bool) -> void:
	var night := GameClock.minutes >= 1140.0
	if night == _is_night and not force:
		return
	_is_night = night
	for w in _windows:
		w.texture = _window_night if night else _window_day
