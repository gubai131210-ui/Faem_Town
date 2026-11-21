extends WildMap
## 茶岭：北坡牧场的老牧道再往西。一面坡，六层石砌的梯田，一垄一垄的茶。
## 谷底是茶农的草屋和进山的路；半山一块平台上是老茶坊；岭顶有观云亭、泉眼和一棵老茶树。
## 泉水从岭顶沿西边一级一级跌下来，落进谷底的潭，再往东南流出去。
## 这里只管地形、画面和能走的地方；采茶、炒茶、人和剧情见 docs/新地图.md。

const W := 72
const H := 58
## 梯田有几层（最上面一层是岭顶）
const TIERS := 6
## 每层梯田南北几格（含下面那格石墙）
const DEPTH := 5
## 半山的平台：第三层在这几列多出几格深
const YARD_X0 := 45
const YARD_X1 := 61
const YARD_EXTRA := 3
## 茶垄从哪一列种到哪一列
const TEA_X0 := 14
const TEA_X1 := 64
## 泉水往下跌的那两列
const FALL_X0 := 10
const FALL_X1 := 11
## 往东出去是北坡牧场
const ROAD_ROWS: Array[int] = [49, 50]
## 各层石阶大致在哪一列（会挪到石墙平直的地方）
const STAIR_HINTS: Array[int] = [50, 24, 38, 56, 30, 42]

const HUT := [22, 49, 4, 3]
const FACTORY := [50, 0, 6, 3]
const PAVILION := [29, 10, 3, 2]
const OLD_TEA := Vector2i(20, 9)
const SPRING := Vector2(11, 8)
const POOL := Vector2(10.5, 49)

var _stairs: Array[int] = []
var _tea: Dictionary[Vector2i, bool] = {}


func _ready() -> void:
	map_id = &"chaling"
	_rng.seed = 20261201
	_setup_wild(W, H)
	_layout()
	_finish_relief()
	_build_ground()
	_add_relief(WildArt.WALL)
	_make_entities()
	_place()
	_add_planks()
	_make_water_fx(40)


func spawn_position(_spawn: StringName) -> Vector2:
	return tile_center(Vector2i(W - 2, ROAD_ROWS[0])) + Vector2(0, 8)


func spawn_facing(_spawn: StringName) -> Facing:
	return Facing.LEFT


func trigger_at(tile: Vector2i) -> Dictionary:
	if tile.x == W - 1 and ROAD_ROWS.has(tile.y):
		return {"map": &"pasture", "spawn": &"from_chaling"}
	return {}


func query_use(_item: ItemDef, tile: Vector2i, _facing: Facing) -> StringName:
	return &"interact" if clue_at(tile) != "" else &""


func perform(action: StringName, _item: ItemDef, tile: Vector2i, _quiet: bool = false) -> void:
	if action == &"interact" and clue_at(tile) != "":
		EventBus.banner_requested.emit(clue_at(tile))


func clue_at(tile: Vector2i) -> String:
	if clues.has(tile):
		return clues[tile]
	if _tea.has(tile):
		return "一垄茶。叶子厚，摸上去有点凉。"
	if in_map(tile) and fall[idx(tile)] == 1:
		return "泉水从上一层跌下来，石墙被冲得发亮。"
	return ""


# ---------------------------------------------------------------- 地形

## 第一层石墙在这一列的哪一行。平台那一段是平的，房子才摆得正。
func _base(x: int) -> int:
	var cx := clampi(x, 0, W - 1)
	if cx >= YARD_X0 - 1 and cx <= YARD_X1 + 1:
		cx = YARD_X0 - 1
	return 44 + int(roundf(2.6 * sin(cx * 0.075 + 0.4)))


func _extra(x: int) -> int:
	return clampi(mini(x - YARD_X0 + 1, YARD_X1 + 1 - x), 0, YARD_EXTRA)


## 第 k 层（1 起）的石墙在这一列的哪一行；这一行往北是第 k 层的地。
func _edge(k: int, x: int) -> int:
	var y := _base(x) - (k - 1) * DEPTH
	if k > 3:
		y -= _extra(x)
	return y


func _flat(k: int, x: int) -> bool:
	return _edge(k, x - 1) == _edge(k, x) and _edge(k, x + 1) == _edge(k, x)


func _layout() -> void:
	for y in H:
		for x in W:
			var lv := 0
			for k in range(1, TIERS + 1):
				if y < _edge(k, x):
					lv = k
			level[y * W + x] = lv
	# 石阶：挪到两边都平直的两列上
	for k in range(1, TIERS + 1):
		var x: int = STAIR_HINTS[k - 1]
		while not (_flat(k, x) and _flat(k, x + 1)):
			x += 1
		_stairs.append(x)
		_steps(x, x + 1, _edge(k, x))
	# 泉、一级级跌下来的水、谷底的潭和流出去的溪
	_lake(SPRING, 3.2, 2.2, 0.5, 11)
	for y in range(int(SPRING.y), int(POOL.y)):
		_set_water(Vector2i(FALL_X0, y))
		_set_water(Vector2i(FALL_X1, y))
	_lake(POOL, 4.2, 3.2, 0.6, 12)
	_trail([Vector2i(13, 51), Vector2i(20, 53), Vector2i(30, 52), Vector2i(40, 53), Vector2i(48, 53), Vector2i(53, 55), Vector2i(55, 57)], 2, WATER)
	# 进山的路：东口进来，往西到茶农家；岔一条往北上第一道石阶
	_trail([Vector2i(W - 1, 49), Vector2i(18, 49)], 2, DIRT)
	var s1: int = _stairs[0]
	_trail([Vector2i(s1, 49), Vector2i(s1, _edge(1, s1) + 1)], 2, DIRT)
	# 梯田上：石墙顶上那一行踩成了土路，石阶上下清出一道口子
	for k in range(1, TIERS):
		for x in range(TEA_X0 - 1, TEA_X1 + 2):
			var lane := Vector2i(x, _edge(k, x) - 1)
			if in_map(lane) and terrain[idx(lane)] != WATER:
				terrain[idx(lane)] = DIRT
		for col: int in [_stairs[k - 1], _stairs[k]]:
			for x in [col, col + 1]:
				for off in range(1, DEPTH + _extra(x)):
					var t := Vector2i(x, _edge(k, x) - off)
					if in_map(t) and terrain[idx(t)] != WATER:
						terrain[idx(t)] = DIRT
	# 半山平台：茶坊门口一块晒场
	var yard_y := _edge(3, YARD_X0 + 4)
	_fill(YARD_X0 + 3, yard_y - 3, YARD_X1 - 3, yard_y - 1, DIRT)
	# 岭顶：石阶上来，一条小路通到亭子、老茶树和泉边
	var top: int = _stairs[TIERS - 1]
	_trail([Vector2i(top, _edge(TIERS, top) - 1), Vector2i(top, 12), Vector2i(31, 11), Vector2i(22, 11), Vector2i(15, 10)], 1, DIRT)
	_trail([Vector2i(top, 12), Vector2i(56, 10), Vector2i(62, 9)], 1, DIRT)
	# 四周的林子；东口留出来
	_fringe(3, 3, 5, [Rect2i(64, 46, 8, 7), Rect2i(6, 50, 52, 5), Rect2i(52, 54, 6, 4)])
	_wood_rect(67, 0, W - 1, 44)


func _place() -> void:
	_add_woods(["pine0", "old0", "pine1", "old2", "round1"])
	_place_tea()
	# 谷底：茶农的草屋、晒架、井
	_building("tea_hut", HUT[0], HUT[1], HUT[2], HUT[3])
	_clue(Vector2i(HUT[0] + 1, HUT[1] - 1), "茶农的草屋。门边靠着一只背篓，篓底还粘着茶末。")
	_thing(PropArt.texture("drying_rack"), Vector2i(27, 47), 2).offset = -PropArt.anchor("drying_rack")
	_clue(Vector2i(27, 47), "晒青的架子。竹匾里摊着今早采的叶子。")
	_clue(Vector2i(28, 47), "晒青的架子。竹匾里摊着今早采的叶子。")
	_prop("well", tile_center(Vector2i(18, 46)) + Vector2(8, 8))
	_block_rect(18, 45, 19, 46)
	_clue(Vector2i(18, 46), "井。井绳上打了三个结，不知道记的是什么。")
	_clue(Vector2i(19, 46), "井。井绳上打了三个结，不知道记的是什么。")
	# 上山的口子立着牌坊
	var s1: int = _stairs[0]
	_prop("stone_arch", Vector2((s1 + 1) * TS, 48 * TS))
	_block(Vector2i(s1 - 1, 47))
	_block(Vector2i(s1 + 2, 47))
	_clue(Vector2i(s1 - 1, 47), "石牌坊。额上的字磨平了，只剩一个「茶」字的草头。")
	_clue(Vector2i(s1 + 2, 47), "石牌坊。额上的字磨平了，只剩一个「茶」字的草头。")
	_hang_clue(Vector2i(60, 48), WildArt.signpost(), 2.0)
	_clue(Vector2i(60, 48), "路牌。往西：茶岭。往东：老牧道。")
	var lamp := tile_center(Vector2i(64, 48)) + Vector2(0, 6)
	_prop("stone_lamp", lamp)
	_block(Vector2i(64, 48))
	_add_night_light(lamp + Vector2(0, -16), 1.8)
	# 半山：老茶坊和两副晒架
	var yard_y := _edge(3, YARD_X0 + 4)
	_building("tea_factory", FACTORY[0], yard_y - 3, FACTORY[2], FACTORY[3])
	_clue(Vector2i(FACTORY[0] + 1, yard_y - 4), "老茶坊。门上了锁，从门缝里闻得到陈年的茶香。")
	_clue(Vector2i(FACTORY[0] + 2, yard_y - 4), "老茶坊。门上了锁，从门缝里闻得到陈年的茶香。")
	_clue(Vector2i(FACTORY[0] + 5, yard_y - 4), "炒茶的土灶。锅是冷的，锅沿磨得发亮。")
	for x: int in [YARD_X0 + 2, YARD_X1 - 3]:
		_thing(PropArt.texture("drying_rack"), Vector2i(x, yard_y - 4), 2).offset = -PropArt.anchor("drying_rack")
	# 岭顶：观云亭、老茶树、泉眼、长凳
	_building("pavilion", PAVILION[0], PAVILION[1], PAVILION[2], PAVILION[3], false)
	_clue(Vector2i(PAVILION[0] + 1, PAVILION[1] - 1), "观云亭。坐在这儿，整个镇子都在脚下的雾里。")
	_tree("old1", OLD_TEA)
	_clue(OLD_TEA, "一棵老茶树，比人高出两头。树干上系着褪了色的红布条。")
	_hang_clue(Vector2i(15, 9), BambooArt.marker(), 4.0)
	_clue(Vector2i(15, 9), "泉眼边的石头。刻着一道一道的痕，像是在记哪年的水大。")
	for t: Vector2i in [Vector2i(60, 8), Vector2i(36, 8)]:
		_prop("bench", tile_center(t) + Vector2(8, 4))
		_block_rect(t.x, t.y, t.x + 1, t.y)
	# 岭顶和谷底零星的树，梯田两头的老树
	_grove(Rect2i(12, 5, 54, 9), 7, ["plum0", "old0", "pine0", "plum1"])
	_grove(Rect2i(14, 14, 34, 9), 4, ["pine0", "plum0", "round1"])
	_grove(Rect2i(6, 44, 60, 11), 5, ["round0", "plum0", "round2", "willow0"])
	_grove(Rect2i(6, 12, 8, 32), 14, ["old2", "round1"])
	_grove(Rect2i(62, 12, 5, 32), 20, ["old0", "pine1"])
	_scatter_bushes(46)
	_scatter_tufts(700)
	var ferns: Array[Texture2D] = [Px.tex(WildArt.fern(0, _season)), Px.tex(WildArt.fern(1, _season))]
	_sprinkle(Rect2i(4, 4, 64, 50), 22, ferns, 3)


## 每层梯田上两行茶垄。石墙拐弯的地方、石阶上下不种，人从那里穿过去。
func _place_tea() -> void:
	var shoots := _season == 0
	for k in range(1, TIERS):
		for x in range(TEA_X0, TEA_X1 + 1):
			if not _flat(k, x) or _extra(x) > 0 and k == 3:
				continue
			if absi(x - _stairs[k - 1]) <= 1 or absi(x - _stairs[k - 1] - 1) <= 1:
				continue
			if absi(x - _stairs[k]) <= 1 or absi(x - _stairs[k] - 1) <= 1:
				continue
			for off: int in [2, 3]:
				var t := Vector2i(x, _edge(k, x) - off)
				if in_map(t) and terrain[idx(t)] == GRASS and solid[idx(t)] == 0 and woods[idx(t)] == 0:
					_tea[t] = true
	var cache: Dictionary[int, Texture2D] = {}
	for t: Vector2i in _tea:
		var m := 0
		if _tea.has(t + Vector2i(-1, 0)):
			m |= 1
		if _tea.has(t + Vector2i(1, 0)):
			m |= 2
		if not cache.has(m):
			cache[m] = Px.tex(WildArt.tea_bush(m, _season, shoots))
		var s := _sprite(cache[m], Vector2(t.x * TS, t.y * TS + TS), Vector2(0, -TS))
		s.position.y -= 1
		_block(t)
