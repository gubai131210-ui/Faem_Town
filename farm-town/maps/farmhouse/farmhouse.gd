extends GameMap
## 农舍室内：床（睡觉）、摆着两副碗筷的桌子、灶台（做菜）、柜子（上面的收音机报天气），门垫出门。

const W := 12
const H := 9
const WALL_ROWS := 2
const EXIT_TILES: Array[Vector2i] = [Vector2i(5, 8), Vector2i(6, 8)]
const INTRO_DIALOGUE := "res://dialogue/intro.dialogue"
const COMMON_DIALOGUE := "res://dialogue/common.dialogue"
## 家具：[素材名, 锚点所在的像素位置, 占的格子(左上角), 占地宽, 占地深]
const FURNITURE: Array = [
	["bed", Vector2(32, 80), Vector2i(1, 2), 2, 3],
	["cabinet", Vector2(64, 48), Vector2i(3, 2), 2, 1],
	["stove", Vector2(176, 48), Vector2i(10, 2), 2, 1],
	["table", Vector2(128, 80), Vector2i(7, 4), 2, 1],
	["stool", Vector2(104, 76), Vector2i(6, 4), 1, 1],
	["stool", Vector2(152, 76), Vector2i(9, 4), 1, 1],
	["jar_jade", Vector2(184, 108), Vector2i(11, 6), 1, 1],
	["jar_clay", Vector2(170, 124), Vector2i(10, 7), 1, 1],
]

var _solid: Dictionary[Vector2i, bool] = {}
var _bed_tiles: Array[Vector2i] = []
var _table_tiles: Array[Vector2i] = []
var _cabinet_tiles: Array[Vector2i] = []
var _stove_tiles: Array[Vector2i] = []
var _room: Sprite2D
var _room_day: Texture2D
var _room_night: Texture2D
var _is_night := false


func _ready() -> void:
	map_id = &"farmhouse"
	indoor = true

	_room_day = PropArt.texture("room_day")
	_room_night = PropArt.texture("room_night")
	_room = PropArt.sprite("room_day", Vector2(0, H * TS))
	_room.z_index = -10
	add_child(_room)
	_update_windows(true)

	entities = Node2D.new()
	entities.y_sort_enabled = true
	add_child(entities)
	for entry: Array in FURNITURE:
		var prop: String = entry[0]
		var pos: Vector2 = entry[1]
		var origin: Vector2i = entry[2]
		var wide: int = entry[3]
		var deep: int = entry[4]
		var shown := prop
		if prop == "bed" and Residents.memory_level(&"qingzhu") >= 3:
			shown = "bed_wide"
		entities.add_child(PropArt.sprite(shown, pos))
		for dy in deep:
			for dx in wide:
				var t := origin + Vector2i(dx, dy)
				_solid[t] = true
				if prop == "bed":
					_bed_tiles.append(t)
				elif prop == "table":
					_table_tiles.append(t)
				elif prop == "cabinet":
					_cabinet_tiles.append(t)
				elif prop == "stove":
					_stove_tiles.append(t)


func _process(_delta: float) -> void:
	_update_windows(false)


func _exit_tree() -> void:
	# 出了屋就听不到收音机了
	Audio.stop_radio()


func size_px() -> Vector2i:
	return Vector2i(W * TS, H * TS)


func spawn_position(spawn: StringName) -> Vector2:
	if spawn == &"bed":
		return tile_center(Vector2i(3, 3))
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
	if _bed_tiles.has(tile) or _table_tiles.has(tile) or _cabinet_tiles.has(tile) or _stove_tiles.has(tile):
		return &"interact"
	return &""


func perform(action: StringName, _item: ItemDef, tile: Vector2i, _quiet: bool = false) -> void:
	if action != &"interact":
		return
	if _bed_tiles.has(tile):
		EventBus.dialogue_requested.emit(COMMON_DIALOGUE, "bed")
	elif _table_tiles.has(tile):
		EventBus.dialogue_requested.emit(INTRO_DIALOGUE, "table")
	elif _stove_tiles.has(tile):
		EventBus.cook_requested.emit()
	elif _cabinet_tiles.has(tile):
		# 柜子上的收音机报明天的天气，一边出字一边播报
		Audio.play_radio(Weather.report_clips())
		EventBus.dialogue_requested.emit(COMMON_DIALOGUE, "radio")


func trigger_at(tile: Vector2i) -> Dictionary:
	if EXIT_TILES.has(tile):
		return {"map": &"farm", "spawn": &"house_door"}
	return {}


func _update_windows(force: bool) -> void:
	var night := GameClock.minutes >= 1140.0
	if night == _is_night and not force:
		return
	_is_night = night
	_room.texture = _room_night if night else _room_day
