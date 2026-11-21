class_name ShopRoom
extends GameMap
## 铺子和公所的里间的共同底子（决策 161）。墙和地是 RoomArt.shop 画的，家具要么是 Blender 的
## 物件（PropArt），要么是代码画的（InteriorArt）。子类只写三件事：
##   _setup()  定 map_id、W、H、出门去哪；
##   _look()   墙、地、窗开在哪几列；
##   _stock()  摆家具，用 _put / _hang / _decal / _atop。
## 摆下去的东西占的格子挡人；带 key 的格子对着按使用键，会走 _on_use。
## 不带 key 的只是摆设。门在最下面一行正中两格，出门回到镇上。

const WALL_ROWS := 2
const WALL_PX := 32

var W := 24
var H := 14
## 出门去哪：{"map": ..., "spawn": ...}
var _exit: Dictionary = {}
var _door_x: Array[int] = []
var _solid: Dictionary[Vector2i, bool] = {}
var _use: Dictionary[Vector2i, StringName] = {}
var _room: Sprite2D
var _day: Texture2D
var _night: Texture2D
var _is_night := false


## 子类在这里设 map_id、W、H、_exit。
func _setup() -> void:
	pass


## 返回 {"wall": 墙的样子, "floor": 地的样子, "windows": 窗所在的列}。
func _look() -> Dictionary:
	return {"wall": "plaster", "floor": "plank", "windows": [] as Array[int]}


func _stock() -> void:
	pass


## key 对应的一句话。子类不重写 _on_use 时就念这一句。
func _lines() -> Dictionary:
	return {}


func _ready() -> void:
	_setup()
	indoor = true
	_door_x = [W / 2 - 1, W / 2]
	var look := _look()
	var windows: Array[int] = []
	windows.assign(look.get("windows", []))
	_day = Px.tex(RoomArt.shop(W, H, str(look["wall"]), str(look["floor"]), windows, _door_x, false))
	_night = Px.tex(RoomArt.shop(W, H, str(look["wall"]), str(look["floor"]), windows, _door_x, true))
	_room = Sprite2D.new()
	_room.centered = false
	_room.z_index = -10
	add_child(_room)
	entities = Node2D.new()
	entities.y_sort_enabled = true
	add_child(entities)
	_stock()
	_update_windows(true)


func _process(_delta: float) -> void:
	_update_windows(false)


func size_px() -> Vector2i:
	return Vector2i(W * TS, H * TS)


func spawn_position(_spawn: StringName) -> Vector2:
	return tile_center(Vector2i(_door_x[0], H - 2)) + Vector2(8, 0)


func spawn_facing(_spawn: StringName) -> Facing:
	return Facing.UP


func blocked(p: Vector2) -> bool:
	for c: Vector2 in [Vector2(-4, -4), Vector2(4, -4), Vector2(-4, 1), Vector2(4, 1)]:
		var t := tile_of(p + c)
		if t.x < 0 or t.x >= W or t.y < WALL_ROWS or t.y >= H or _solid.has(t):
			return true
	return false


func query_use(_item: ItemDef, tile: Vector2i, _facing: Facing) -> StringName:
	if _use.has(tile):
		return &"interact"
	return &""


func perform(action: StringName, _item: ItemDef, tile: Vector2i, _quiet: bool = false) -> void:
	if action == &"interact" and _use.has(tile):
		_on_use(_use[tile], tile)


func _on_use(key: StringName, _tile: Vector2i) -> void:
	var line := str(_lines().get(key, ""))
	if line != "":
		EventBus.banner_requested.emit(line)


func trigger_at(tile: Vector2i) -> Dictionary:
	if tile.y == H - 1 and _door_x.has(tile.x):
		return _exit
	return {}


## 对着按使用键的格子，给测试用。
func use_tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.assign(_use.keys())
	return out


func use_key(tile: Vector2i) -> StringName:
	return _use.get(tile, &"")


func solid_tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.assign(_solid.keys())
	return out


# ---------------------------------------------------------------- 摆东西

## 站在地上的家具：tile 是占的格子的左上角，foot 是占几格宽、几格深。锚点在占地底边正中。
## key 不空：这些格子对着按使用键走 _on_use。solid 为假：只是摆着，人能踩过去。
func _put(art: String, tile: Vector2i, foot: Vector2i = Vector2i(1, 1), key: StringName = &"",
		solid: bool = true) -> Sprite2D:
	var pos := Vector2(tile.x * TS + foot.x * TS / 2.0, (tile.y + foot.y) * TS)
	var spr := _sprite(art, pos)
	entities.add_child(spr)
	for dy in foot.y:
		for dx in foot.x:
			var t := tile + Vector2i(dx, dy)
			if solid:
				_solid[t] = true
			if key != &"":
				_use[t] = key
	return spr


## 挂在后墙上的：cx 是中心的像素 x，bottom 是底边的像素 y。
## key 不空：墙脚那一行（第 1 行）从 use_x 起 use_w 格对着按使用键。
func _hang(art: String, cx: float, bottom: float, key: StringName = &"", use_x: int = 0, use_w: int = 0) -> Sprite2D:
	var spr := _sprite(art, Vector2(cx, bottom))
	spr.z_index = -9
	add_child(spr)
	if key != &"":
		for dx in use_w:
			_use[Vector2i(use_x + dx, WALL_ROWS - 1)] = key
	return spr


## 贴在地上的：地毯、戏台。人能踩，不挡。左上角在 tile。
func _decal(art: String, tile: Vector2i) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.texture = InteriorArt.texture(art)
	spr.centered = false
	spr.position = Vector2(tile * TS)
	spr.z_index = -8
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(spr)
	return spr


## 摆在别的家具上面的小东西（秤、药臼），不占格子，盖在家具前面。
func _atop(art: String, pos: Vector2) -> Sprite2D:
	var spr := _sprite(art, pos)
	spr.z_index = 2
	entities.add_child(spr)
	return spr


## 只占格子、不画东西（画在别的图上的，比如墙边的柱子）。
func _mark(tile: Vector2i, foot: Vector2i, key: StringName) -> void:
	for dy in foot.y:
		for dx in foot.x:
			_use[tile + Vector2i(dx, dy)] = key


func _sprite(art: String, pos: Vector2) -> Sprite2D:
	if InteriorArt.has(art):
		return InteriorArt.sprite(art, pos)
	return PropArt.sprite(art, pos)


func _update_windows(force: bool) -> void:
	var night := GameClock.minutes >= 1140.0 + GameClock.dusk_shift()
	if night == _is_night and not force:
		return
	_is_night = night
	_room.texture = _night if night else _day
