extends OutdoorMap
## 沉灯井的井口：镇子北边的路走到头。一堆山石中间的洞口顺着梯子下第一层，
## 旁边的升降机直接下到亮着井灯的最深一层。

const W := 26
const H := 20
## 往南下去是镇子
const ROAD_COLS: Array[int] = [12, 13]
## 洞口正面的两格（对着它按使用下井），山石占的范围是 [x0, y0, x1, y1]
const MOUTH_TILES: Array[Vector2i] = [Vector2i(12, 6), Vector2i(13, 6)]
const MOUND: Array[int] = [11, 4, 14, 6]
## 升降机占的两格
const LIFT_TILES: Array[Vector2i] = [Vector2i(17, 7), Vector2i(18, 7)]
## 守井人的小屋占的范围 [x0, y0, x1, y1]；最南一行是正面的墙
const HUT: Array[int] = [4, 6, 7, 8]


func _ready() -> void:
	map_id = &"wellhead"
	_rng.seed = 20261120
	_setup_grid(W, H)
	_layout()
	_build_ground()
	_make_entities()
	_place_objects()
	_spawn_npcs()


func spawn_position(spawn: StringName) -> Vector2:
	if spawn == &"from_mine":
		return tile_center(Vector2i(12, 7)) + Vector2(8, 0)
	return tile_center(Vector2i(ROAD_COLS[0], H - 2)) + Vector2(8, 0)


func spawn_facing(spawn: StringName) -> Facing:
	return Facing.DOWN if spawn == &"from_mine" else Facing.UP


func trigger_at(tile: Vector2i) -> Dictionary:
	if tile.y == H - 1 and ROAD_COLS.has(tile.x):
		return {"map": &"town", "spawn": &"from_wellhead"}
	return {}


func query_use(_item: ItemDef, tile: Vector2i, _facing: Facing) -> StringName:
	if npc_at(tile) != null or MOUTH_TILES.has(tile) or LIFT_TILES.has(tile) or _at_hut(tile):
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
		EventBus.banner_requested.emit("守井人的小屋。门边挂着一盏矿灯，门口摆着一双胶鞋，鞋底的泥是新的")


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
	_fill(ROAD_COLS[0], 9, ROAD_COLS[1], H - 1, DIRT)
	_fill(9, 7, 20, 10, DIRT)


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
	_reserve(ROAD_COLS[0] - 1, 9, ROAD_COLS[1] + 1, H - 1)
	_scatter_trees(10)
	_scatter_bushes(10)
	_scatter_tufts(220)
