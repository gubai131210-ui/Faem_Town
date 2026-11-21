extends WildMap
## 河埠：河岸西边的一排铺面。河灯亮了才能到河岸，顺着西边的土路走过来。
## 木匠铺能进去。酱园和茶摊只能看。桥的北头接上竹海（决策 126）。

## 老河埠是左上角 28×20；往东、往南扩到 52×40，老坐标一格不动（决策 158）。
const OLD_W := 28
const OLD_H := 20
const W := 52
const H := 40
const NEW_TREES: Array[String] = ["willow0", "round0", "willow1", "round1", "round2"]
## 往南去的石板街占的两列，和南边的横街两行
const SOUTH_COLS: Array[int] = [40, 41]
const CROSS_ROWS: Array[int] = [30, 31]
## 东边新栈桥
const PIER2_X := 36
const EAST_ROWS: Array[int] = [14, 15]
## 渡口伸进河里的木板
const DOCK_TILES: Array[Vector2i] = [
	Vector2i(7, 4), Vector2i(8, 4), Vector2i(7, 5), Vector2i(8, 5), Vector2i(7, 6), Vector2i(8, 6),
]
## 往北伸进河里、北头接上竹海的桥
const BRIDGE_TILES: Array[Vector2i] = [
	Vector2i(22, 2), Vector2i(22, 3), Vector2i(22, 4), Vector2i(22, 5),
	Vector2i(23, 2), Vector2i(23, 3), Vector2i(23, 4), Vector2i(23, 5),
]
## 木匠铺门：门脸那一排的正中。旁边的墙只是看看。
const DOOR := Vector2i(4, 12)
## 酱园东墙根的一张数目纸。不挡掌柜站的那一格。桥的北头才进竹海。
const SOY_SLIP := Vector2i(13, 13)
## [素材, 最西一列, 门脸那一行, 宽, 深, 说明]
const SHOPS: Array = [
	["shop_carpenter", 3, 13, 3, 3, "青竹的木匠铺。门口码着木料，幌子上写着木"],
	["shop_soy", 10, 13, 3, 3, "酱园。门口排着三口酱缸"],
	["shop_teastall", 17, 13, 2, 2, "渡口的茶摊。蓝棚底下有一把壶，幌子上写着茶"],
]


func _ready() -> void:
	map_id = &"wharf"
	_rng.seed = 20261116
	_scatter_cols = OLD_W
	_scatter_rows = OLD_H
	_setup_wild(W, H)
	_layout()
	_layout_new()
	_build_ground()
	_make_entities()
	_place_objects()
	_place_new()
	_add_planks()
	_spawn_npcs()  # 决策 118：酱园掌柜河灯亮后回河埠；此前这张图漏了生成居民
	_make_water_fx(48)


func spawn_position(spawn: StringName) -> Vector2:
	if spawn == &"carpenter_door":
		return tile_center(Vector2i(DOOR.x, 14))
	if spawn == &"from_zhuhai":
		return tile_center(Vector2i(22, 4))
	return tile_center(Vector2i(W - 2, EAST_ROWS[0]))


func spawn_facing(spawn: StringName) -> Facing:
	if spawn == &"from_zhuhai":
		return Facing.DOWN
	return Facing.UP if spawn == &"carpenter_door" else Facing.LEFT


func trigger_at(tile: Vector2i) -> Dictionary:
	if tile.x == W - 1 and EAST_ROWS.has(tile.y):
		return {"map": &"riverbank", "spawn": &"from_wharf"}
	if BRIDGE_TILES.has(tile) and tile.y == 2:
		return {"map": &"zhuhai", "spawn": &"bridge"}
	return {}


func fishing_water(tile: Vector2i) -> StringName:
	if not _is_water(tile) or DOCK_TILES.has(tile) or BRIDGE_TILES.has(tile) or planks.has(tile):
		return &""
	return &"river"


func query_use(item: ItemDef, tile: Vector2i, _facing: Facing) -> StringName:
	if _look(tile) != "":
		return &"interact"
	if item != null and item.id == &"rod" and fishing_water(tile) != &"":
		return &"cast"
	return &""


func perform(action: StringName, _item: ItemDef, tile: Vector2i, _quiet: bool = false) -> void:
	if action != &"interact":
		return
	if tile == DOOR:
		SceneRouter.travel(&"workshop", &"door")
		return
	var text := _look(tile)
	if text != "":
		if tile == SOY_SLIP:
			GameState.set_flag(&"read_soy_slip")
		EventBus.banner_requested.emit(text)


func _layout() -> void:
	for y in 6:
		for x in W:
			_set_water(Vector2i(x, y))
	_fill(0, 6, OLD_W - 1, OLD_H - 1, DIRT)
	_fill(1, EAST_ROWS[0], OLD_W - 2, EAST_ROWS[1], PAVE)
	for t in DOCK_TILES:
		solid[idx(t)] = 0
	for t in BRIDGE_TILES:
		solid[idx(t)] = 0


func _place_objects() -> void:
	_lay_planks(DOCK_TILES)
	_lay_planks(BRIDGE_TILES)
	for shop: Array in SHOPS:
		var x0: int = shop[1]
		var front: int = shop[2]
		var wide: int = shop[3]
		var deep: int = shop[4]
		var pos := Vector2((x0 + wide / 2.0) * TS, front * TS)
		_prop(str(shop[0]), pos)
		_ground_shadow(pos + Vector2(0, -1), Px.tex(PixelArt.shadow(wide * TS - 6, 8, 0.22)))
		_block_rect(x0, front - deep, x0 + wide - 1, front - 1)
	_hang_clue(SOY_SLIP, PlaceClueArt.slip(), 6.0)
	_add_night_light(Vector2(18 * TS, 12 * TS), 1.2)
	_reserve(0, 6, OLD_W - 1, 15)
	_scatter_trees(6)
	_scatter_bushes(4)
	_scatter_tufts(80)
	_release_ghosts()
	if Livelihood.told(&"fish") >= 1:
		var bobber := Sprite2D.new()
		bobber.name = "FishBobber"
		bobber.texture = Px.tex(_bobber())
		bobber.centered = false
		bobber.position = tile_center(Vector2i(8, 4)) + Vector2(4, -14)
		bobber.z_index = 1
		add_child(bobber)


func _lay_planks(tiles: Array[Vector2i]) -> void:
	for t in tiles:
		var m := 0
		if tiles.has(t + Vector2i(0, -1)):
			m |= 1
		if tiles.has(t + Vector2i(1, 0)):
			m |= 2
		if tiles.has(t + Vector2i(0, 1)) or not _is_water(t + Vector2i(0, 1)):
			m |= 4
		if tiles.has(t + Vector2i(-1, 0)):
			m |= 8
		var plank := Sprite2D.new()
		plank.texture = Px.tex(PixelArt.dock_tile(m))
		plank.centered = false
		plank.position = Vector2(t.x * TS, t.y * TS)
		plank.z_index = -7
		add_child(plank)


func _bobber() -> Image:
	var img := Px.new_img(5, 8)
	Px.rect(img, 2, 0, 1, 3, Color.html("6a4430"))
	Px.rect(img, 1, 3, 3, 3, Color.html("e8604a"))
	Px.rect(img, 2, 6, 1, 2, Color.html("f7dc80"))
	return img


func clue_at(tile: Vector2i) -> String:
	if clues.has(tile):
		return clues[tile]
	if tile == SOY_SLIP:
		return "酱园墙根钉着一张纸。写的是黄豆和盐的数目，年份那一格空着。"
	return ""


func _look(tile: Vector2i) -> String:
	var clue := clue_at(tile)
	if clue != "":
		return clue
	if BRIDGE_TILES.has(tile):
		if tile.y == 2:
			return "桥这一头接上了。对面是竹海。"
		return "桥往北接过去。对岸是竹海。"
	if DOCK_TILES.has(tile):
		var extra := PeopleLine.mark(&"laozhou")
		var line := "渡口。船还没靠过来。"
		if extra != "":
			line += extra
		var trade := Livelihood.mark(&"fish")
		return line if trade == "" else line + trade
	for shop: Array in SHOPS:
		var x0: int = shop[1]
		var front: int = shop[2]
		var wide: int = shop[3]
		if tile.y == front - 1 and tile.x >= x0 and tile.x < x0 + wide:
			return str(shop[5])
	return ""


# ---------------------------------------------------------------- 往东、往南扩出来的部分

func _ghost_tree(t: Vector2i) -> bool:
	return _legacy_edge(t, OLD_W, OLD_H)


func _layout_new() -> void:
	_fill(OLD_W, 6, W - 1, 8, DIRT)
	_fill(OLD_W - 1, EAST_ROWS[0], W - 1, EAST_ROWS[1], PAVE)
	_fill(SOUTH_COLS[0], EAST_ROWS[1] + 1, SOUTH_COLS[1], H - 2, PAVE)
	_fill(4, CROSS_ROWS[0], W - 2, CROSS_ROWS[1], PAVE)
	# 东边第二座渡口：木板架在河上
	for y in range(1, 6):
		_plank(Vector2i(PIER2_X, y))
		_plank(Vector2i(PIER2_X + 1, y))
	_fill(PIER2_X, 6, PIER2_X + 1, EAST_ROWS[0] - 1, DIRT)


func _place_new() -> void:
	_new_edge_trees(OLD_W, OLD_H, NEW_TREES)
	_clue(Vector2i(PIER2_X, 1), "渡口尽头拴着一根断了的缆绳，断口是新的")
	_clue(Vector2i(PIER2_X + 1, 1), "渡口尽头拴着一根断了的缆绳，断口是新的")
	_building("boathouse", 44, 12, 5, 3, true)
	_wall_clue(44, 12, 5, "河埠的公用船屋。里面的船都编了号，缺了三号")
	_wide_prop("drying_rack", Vector2i(30, 12), 2, "渡口边晾着一排缆绳，一根比一根粗")
	_wide_prop("bench", Vector2i(39, 12), 2, "等船的人坐的长凳，扶手上刻着一道一道的")
	# 南街两边的铺面（只看看）
	_building("shop_grocery", 33, 24, 3, 3, true)
	_wall_clue(33, 24, 3, "杂货铺。闸板半放着，里面的秤盘还在晃")
	_building("shop_herb", 44, 26, 3, 3, true)
	_wall_clue(44, 26, 3, "药铺。门口的药碾子里还留着没碾完的药")
	_building("house", 33, 36, 4, 3, true)
	_wall_clue(33, 36, 4, "船工的屋子。屋檐下挂着一串干透的鱼")
	_building("house", 45, 36, 4, 3, true)
	_wall_clue(45, 36, 4, "仓房。门板上用粉笔记着进出的数，最后一笔停在半路")
	_building("well", 38, 22, 2, 2, false)
	_wall_clue(38, 22, 2, "河埠的井。井绳上拴着一只红布条，是谁家的记号")
	_wide_prop("wood_pile", Vector2i(30, 28), 2, "码好的船板，一股桐油味")
	_wide_prop("drying_rack", Vector2i(46, 22), 2, "晾网的架子，网眼里卡着一根羽毛")
	_small_prop("jar_clay", Vector2i(36, 28), "酱缸，盖子上压着一块青石")
	_small_prop("wine_jar", Vector2i(43, 28), "酒坛，封泥上盖着一个模糊的印")
	for t: Vector2i in [Vector2i(39, 18), Vector2i(42, 18), Vector2i(39, 26), Vector2i(42, 33), Vector2i(10, 29), Vector2i(20, 29)]:
		if _is_free(t) or terrain[idx(t)] == PAVE:
			_lamp_post(t)
	_grove(Rect2i(OLD_W, 9, W - OLD_W, 3), 18, NEW_TREES)
	_grove(Rect2i(0, OLD_H, 30, 9), 22, NEW_TREES)
	_grove(Rect2i(0, 32, W, H - 32), 20, NEW_TREES)
	_grove(Rect2i(OLD_W, 16, 11, 14), 16, NEW_TREES)
	_sprinkle_grass(Rect2i(OLD_W, 6, W - OLD_W, 24), 91)
	_sprinkle_grass(Rect2i(0, OLD_H, W, H - OLD_H), 92)
