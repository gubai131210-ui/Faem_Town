extends WildMap
## 沉灯井的井口：镇子北边的路走到头。一堆山石中间的洞口顺着梯子下第一层，
## 旁边的升降机直接下到亮着井灯的最深一层。

## 老井台是左上角 26×20；往东、往南扩到 50×40，老坐标一格不动（决策 159）。
const OLD_W := 26
const OLD_H := 20
const W := 50
const H := 40
const NEW_TREES: Array[String] = ["old0", "round0", "pine0", "round1", "old1", "pine1"]
## 南边的横路两行；通往东北高处的路两列
const CROSS_ROWS: Array[int] = [26, 27]
const NORTH_COLS: Array[int] = [40, 41]
## 往南下去是镇子
const ROAD_COLS: Array[int] = [12, 13]
## 洞口正面的两格（对着它按使用下井），山石占的范围是 [x0, y0, x1, y1]
const MOUTH_TILES: Array[Vector2i] = [Vector2i(12, 6), Vector2i(13, 6)]
const MOUND: Array[int] = [11, 4, 14, 6]
## 升降机占的两格
const LIFT_TILES: Array[Vector2i] = [Vector2i(17, 7), Vector2i(18, 7)]
## 守井人的小屋占的范围 [x0, y0, x1, y1]；最南一行是正面的墙
const HUT: Array[int] = [4, 6, 7, 8]
## 往西是矿工巷。井口灯亮了才能到井口，所以这条路一直通着（决策 114）
const LANE_ROWS: Array[int] = [12, 13]


func _ready() -> void:
	map_id = &"wellhead"
	_rng.seed = 20261120
	_scatter_cols = OLD_W
	_scatter_rows = OLD_H
	_setup_wild(W, H)
	_layout()
	_layout_new()
	_build_ground()
	_make_entities()
	_place_objects()
	_place_new()
	_spawn_npcs()


func spawn_position(spawn: StringName) -> Vector2:
	if spawn == &"from_mine":
		return tile_center(Vector2i(12, 7)) + Vector2(8, 0)
	if spawn == &"from_lane":
		return tile_center(Vector2i(1, LANE_ROWS[0]))
	return tile_center(Vector2i(ROAD_COLS[0], H - 2)) + Vector2(8, 0)


func spawn_facing(spawn: StringName) -> Facing:
	if spawn == &"from_mine":
		return Facing.DOWN
	if spawn == &"from_lane":
		return Facing.RIGHT
	return Facing.UP


func trigger_at(tile: Vector2i) -> Dictionary:
	if tile.y == H - 1 and ROAD_COLS.has(tile.x):
		return {"map": &"town", "spawn": &"from_wellhead"}
	if tile.x == 0 and LANE_ROWS.has(tile.y):
		return {"map": &"lane", "spawn": &"from_wellhead"}
	return {}


func query_use(_item: ItemDef, tile: Vector2i, _facing: Facing) -> StringName:
	if npc_at(tile) != null or MOUTH_TILES.has(tile) or LIFT_TILES.has(tile) or _at_hut(tile) or clues.has(tile):
		return &"interact"
	return &""


func perform(action: StringName, _item: ItemDef, tile: Vector2i, _quiet: bool = false) -> void:
	if action != &"interact" or _talk_at(tile):
		return
	if MOUTH_TILES.has(tile):
		_use_mouth()
	elif LIFT_TILES.has(tile):
		_use_lift()
	elif _at_hut(tile):
		var extra := PeopleLine.mark(&"laoqin")
		var line := "守井人的小屋。门边挂着一盏矿灯，门口摆着一双胶鞋，鞋底的泥是新的"
		EventBus.banner_requested.emit(line if extra == "" else line + "。" + extra)
	elif clues.has(tile):
		EventBus.banner_requested.emit(clues[tile])


## 这一格是不是小屋正面的墙。
func _at_hut(tile: Vector2i) -> bool:
	return tile.y == HUT[3] and tile.x >= HUT[0] and tile.x <= HUT[2]


## 头一回来先拿上门边的镐子和镰刀；之后顺着梯子下第一层。
func _use_mouth() -> void:
	# 还没拿的：[物品, 标记]。老存档里可能只拿过镐子
	var gifts: Array = []
	if not GameState.has_flag(Mine.PICKAXE_FLAG):
		gifts.append([Mine.PICKAXE, Mine.PICKAXE_FLAG])
	if not GameState.has_flag(Mine.WEAPON_FLAG):
		gifts.append([Mine.FIRST_WEAPON, Mine.WEAPON_FLAG])
	if not gifts.is_empty():
		var free := 0
		for i in GameState.inventory.size:
			if GameState.inventory.is_empty_slot(i):
				free += 1
		if free < gifts.size():
			EventBus.banner_requested.emit("洞口靠着下井用的家伙。背包满了，拿不了")
			Audio.play("deny", 0.0, -4.0)
			return
		for gift: Array in gifts:
			GameState.inventory.add(gift[0], 1)
			GameState.set_flag(gift[1])
		Audio.play("harvest", 0.0, -4.0)
		if gifts.size() == 2:
			EventBus.banner_requested.emit("洞口靠着一把旧镐子，旁边挂着一把镰刀。都拿上了。再按一下顺梯子下井")
		elif gifts[0][0] == Mine.PICKAXE:
			EventBus.banner_requested.emit("洞口靠着一把旧镐子，木柄磨得发亮。拿上了。再按一下顺梯子下井")
		else:
			EventBus.banner_requested.emit("洞口的木框上挂着一把旧镰刀。井下有东西，拿上防身")
		return
	if Mine.enter(1):
		Audio.play("select", 0.0, -6.0)
		SceneRouter.travel(&"mine", &"ladder")


func _use_lift() -> void:
	var n := Mine.lift_floor()
	if n <= 0:
		EventBus.banner_requested.emit("升降机。下面的井灯一盏都没亮，它不知道该停在哪")
		Audio.play("deny", 0.0, -6.0)
		return
	if Mine.enter(n):
		Audio.play("select", 0.0, -6.0)
		SceneRouter.travel(&"mine", &"lift")


func _layout() -> void:
	# 从镇上来的土路，通到洞口前的一片场地
	_fill(ROAD_COLS[0], 9, ROAD_COLS[1], OLD_H - 1, DIRT)
	_fill(9, 7, 20, 10, DIRT)
	# 往西去矿工巷
	_fill(0, LANE_ROWS[0], 11, LANE_ROWS[1], DIRT)


func _place_objects() -> void:
	var mouth_pos := Vector2(13 * TS, 7 * TS)
	_sprite(Px.tex(MineArt.mouth()), mouth_pos, Vector2(-32, -52))
	_ground_shadow(mouth_pos + Vector2(0, -1), Px.tex(PixelArt.shadow(60, 8, 0.25)))
	_block_rect(MOUND[0], MOUND[1], MOUND[2], MOUND[3])

	var lift_pos := Vector2(18 * TS, 8 * TS - 2)
	_sprite(Px.tex(MineArt.lift()), lift_pos, Vector2(-16, -46))
	_ground_shadow(lift_pos + Vector2(0, -1), Px.tex(PixelArt.shadow(30, 6, 0.22)))
	for t in LIFT_TILES:
		_block(t)
	_add_night_light(mouth_pos + Vector2(0, -30), 1.6)

	var hut_pos := Vector2((HUT[0] + HUT[2] + 1) * TS / 2.0, (HUT[3] + 1) * TS)
	_sprite(Px.tex(MineArt.hut()), hut_pos, Vector2(-32, -56))
	_ground_shadow(hut_pos + Vector2(0, -1), Px.tex(PixelArt.shadow(58, 8, 0.22)))
	_block_rect(HUT[0], HUT[1], HUT[2], HUT[3])
	_add_night_light(hut_pos + Vector2(-10, -16), 1.2)
	_reserve(HUT[0] - 1, HUT[1] - 2, HUT[2] + 1, HUT[3] + 2)

	# 场地和路上不长树
	_reserve(8, 3, 21, 11)
	_reserve(ROAD_COLS[0] - 1, 9, ROAD_COLS[1] + 1, OLD_H - 1)
	_reserve(0, LANE_ROWS[0] - 1, 11, LANE_ROWS[1] + 1)
	_scatter_trees(10)
	_scatter_bushes(10)
	_scatter_tufts(220)
	_release_ghosts()


# ---------------------------------------------------------------- 往东、往南扩出来的部分

func _ghost_tree(t: Vector2i) -> bool:
	return _legacy_edge(t, OLD_W, OLD_H)


func _layout_new() -> void:
	_fill(ROAD_COLS[0], OLD_H, ROAD_COLS[1], H - 1, DIRT)
	_fill(2, CROSS_ROWS[0], 46, CROSS_ROWS[1], DIRT)
	_fill(NORTH_COLS[0], 4, NORTH_COLS[1], CROSS_ROWS[0] - 1, DIRT)


func _place_new() -> void:
	_new_edge_trees(OLD_W, OLD_H, NEW_TREES)
	_building("miner_house", 19, 25, 4, 3, true)
	_wall_clue(19, 25, 4, "矿工的屋子。窗台上摆着一排矿灯，没有一盏是同一个年份的")
	_building("miner_house", 29, 25, 4, 3, true)
	_wall_clue(29, 25, 4, "窗里挂着洗得发白的工服，袖口上缝着补丁")
	_building("smithy", 44, 25, 4, 3, false)
	_wall_clue(44, 25, 4, "小炉子。炭是凉的，火钳放在最顺手的地方")
	_building("scaffold", 36, 12, 3, 2, false)
	_wall_clue(36, 12, 3, "井架的木头。绳子磨断过又接上，接头打得很结实")
	_wide_prop("wood_pile", Vector2i(24, 29), 2, "支井用的方木，码得一根压一根")
	_wide_prop("bench", Vector2i(34, 29), 2, "下井前坐一会儿的长凳。凳面上有一圈圈靴底印")
	_small_prop("jar_clay", Vector2i(16, 28), "装灯油的坛子，盖得很严")
	_small_prop("jar_jade", Vector2i(27, 29), "")
	_clue(Vector2i(NORTH_COLS[0], 4), "路到这里断了。再往上是山石，石缝里有风声")
	_clue(Vector2i(NORTH_COLS[1], 4), "路到这里断了。再往上是山石，石缝里有风声")
	for i in 12:
		var t := Vector2i(44 + (i % 4) * 2, 5 + (i / 4) * 2)
		if _is_free(t):
			_small_prop("rock_%d" % (i % 2), t, "废石堆。翻一翻，只有石头" if i == 0 else "")
	for t: Vector2i in [Vector2i(11, 24), Vector2i(14, 24), Vector2i(11, 33), Vector2i(14, 33), Vector2i(39, 24), Vector2i(42, 24), Vector2i(39, 14)]:
		if _is_free(t):
			_lamp_post(t)
	_grove(Rect2i(OLD_W, 0, W - OLD_W, 25), 20, NEW_TREES)
	_grove(Rect2i(0, OLD_H, W, H - OLD_H), 20, NEW_TREES)
	_sprinkle_grass(Rect2i(OLD_W, 0, W - OLD_W, OLD_H), 101)
	_sprinkle_grass(Rect2i(0, OLD_H, W, H - OLD_H), 102)
