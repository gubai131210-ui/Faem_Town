extends ShopRoom
## 镇公所里间。门垫回到北街。柏先生仍在门外。墙上六格地图，亮过的灯补上一块（决策 115）。
## 扩成 26×15（决策 161）：后墙正中一张大图，两边红幡，角上是存旧册的架子；
## 红毯从门口铺到柏先生的桌子，当中一张议事的长桌，两边是等着办事的人坐的长凳。

const MAP_X0 := 8
const MAP_X1 := 17
## 大图在墙上的位置（图片左上角的像素）
const MAP_ORIGIN := Vector2(128, 4)
const DESK_X0 := 11
const DESK_X1 := 14
## 顺序是上排广场、河、牧野，下排井、东滩、山祠。
const LAMPS: Array[StringName] = [&"plaza", &"river", &"pasture", &"well", &"east", &"shrine"]
const COLORS: PackedColorArray = [
	Color("f7dc80"), Color("7f9cc4"), Color("9ad45e"),
	Color("4a4a52"), Color("d69a68"), Color("b4d8c8"),
]

var _patches: Array[Sprite2D] = []


func _setup() -> void:
	map_id = &"hall"
	W = 26
	H = 15
	_exit = {"map": &"town", "spawn": &"hall_door"}


func _look() -> Dictionary:
	return {"wall": "plaster", "floor": "plank", "windows": [3, 21] as Array[int]}


func _lines() -> Dictionary:
	return {
		&"archive": "架上码着旧册，封皮上的年份看不清。",
		&"table": "议事的长桌，桌面上一圈茶杯印，是开会开出来的。",
		&"bench": "等着办事的人坐的长凳，坐得久了，凳面是凹的。",
		&"notice": "公告栏上钉着几张旧告示，边角卷了，日期都是前几年的。",
		&"tea": "茶几上一壶凉茶，给等着办事的人解渴。壶底沉着茶叶梗。",
		&"map": "墙上这张图分六格：广场、河、牧野、井、东滩、山祠。亮过的灯，会补上一块。",
	}


func _stock() -> void:
	_hang("big_map", MAP_ORIGIN.x + InteriorArt.BIG_MAP_W / 2.0, MAP_ORIGIN.y + InteriorArt.BIG_MAP_H - 1,
			&"map", MAP_X0, MAP_X1 - MAP_X0 + 1)
	_make_patches()
	_sync_patches()
	_hang("flag", 6 * TS + 8, 31)
	_hang("flag", 19 * TS + 8, 31)
	_put("bookshelf", Vector2i(0, 2), Vector2i(2, 1), &"archive")
	_put("bookshelf", Vector2i(24, 2), Vector2i(2, 1), &"archive")
	# 柏先生的桌子
	_put("desk:4", Vector2i(DESK_X0, 3), Vector2i(4, 1), &"desk")
	_decal("runner:2:10", Vector2i(12, 4))
	# 议事长桌，两边的凳子
	_put("long_table:6", Vector2i(10, 7), Vector2i(6, 1), &"table")
	for x in [10, 12, 14]:
		_put("stool", Vector2i(x, 6))
	for x in [11, 13, 15]:
		_put("stool", Vector2i(x, 8))
	# 两边等着办事的人
	_put("bench", Vector2i(2, 9), Vector2i(2, 1), &"bench")
	_put("bench", Vector2i(22, 9), Vector2i(2, 1), &"bench")
	_put("notice_board", Vector2i(2, 5), Vector2i(2, 1), &"notice")
	_put("tea_table", Vector2i(22, 5), Vector2i(2, 1), &"tea")
	_put("floor_lamp", Vector2i(7, 12))
	_put("floor_lamp", Vector2i(18, 12))
	_put("bonsai", Vector2i(5, 12))
	_put("bonsai", Vector2i(20, 12))


func _process(delta: float) -> void:
	super._process(delta)
	_sync_patches()


func _on_use(key: StringName, tile: Vector2i) -> void:
	match key:
		&"desk":
			var extra := PeopleLine.mark(&"bai")
			var line := "桌上摊着旧纸。墙上的地图，亮过的灯会补上一块。"
			EventBus.banner_requested.emit(line if extra == "" else line + extra)
		_:
			super._on_use(key, tile)


func map_filled() -> int:
	var n := 0
	for id in LAMPS:
		if Lamps.is_lit(id):
			n += 1
	return n


func patch_visible(i: int) -> bool:
	_sync_patches()
	return i >= 0 and i < _patches.size() and _patches[i].visible


func _make_patches() -> void:
	for i in InteriorArt.BIG_MAP_CELLS.size():
		var cell: Rect2i = InteriorArt.BIG_MAP_CELLS[i]
		var img := Image.create(cell.size.x - 2, cell.size.y - 2, false, Image.FORMAT_RGBA8)
		img.fill(COLORS[i])
		var spr := Sprite2D.new()
		spr.texture = ImageTexture.create_from_image(img)
		spr.centered = false
		spr.position = MAP_ORIGIN + Vector2(cell.position) + Vector2(1, 1)
		spr.visible = false
		spr.z_index = -8
		add_child(spr)
		_patches.append(spr)


func _sync_patches() -> void:
	for i in _patches.size():
		_patches[i].visible = Lamps.is_lit(LAMPS[i])
