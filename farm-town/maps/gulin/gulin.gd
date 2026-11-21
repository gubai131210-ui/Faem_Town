extends WildMap
## 古木林：农场南边那片一直进不去的老林子。树密得不见天，路是人踩出来的，弯弯绕绕。
## 林子正中一片空地，站着一棵千年的老樟；西边是猎户的木屋和炭窑，西北一座石头小山，
## 山顶有泉；东边是一条没人走的石板驿道，北头是塌了的驿站，南头的山口堵着。
## 这里只管地形、画面和能走的地方；砍柴、采菇、烧炭、人和剧情见 docs/新地图.md。

const W := 84
const H := 60
## 往北出去是农场
const GATE_COLS: Array[int] = [40, 41]
const GIANT := Vector2i(42, 27)
const CABIN := [9, 27, 4, 3]
const KILN := [15, 33, 3, 2]
const RUIN := [59, 10, 5, 3]
const ARCH := Vector2i(66, 54)
const MOSS_POND := Vector2(54, 43)
const SPRING := Vector2(14.5, 7.5)
## 林间空地：[中心 x, 中心 y, 半径]，这些圈里不长密林
const GLADES := [[42, 28, 8], [12, 28, 6], [17, 33, 4], [20, 50, 6], [62, 10, 6], [54, 43, 7], [40, 4, 4], [66, 52, 4]]

var _shrooms: Dictionary[Vector2i, int] = {}


func _ready() -> void:
	map_id = &"gulin"
	_rng.seed = 20261203
	_setup_wild(W, H)
	_layout()
	_finish_relief()
	_build_ground()
	_add_relief(WildArt.ROCK)
	_make_entities()
	_add_planks()
	_place()
	_make_water_fx(30)


func spawn_position(_spawn: StringName) -> Vector2:
	return tile_center(Vector2i(GATE_COLS[0], 1)) + Vector2(8, 0)


func spawn_facing(_spawn: StringName) -> Facing:
	return Facing.DOWN


func trigger_at(tile: Vector2i) -> Dictionary:
	if tile.y == 0 and GATE_COLS.has(tile.x):
		return {"map": &"farm", "spawn": &"from_gulin"}
	return {}


func fishing_water(tile: Vector2i) -> StringName:
	if not _is_water(tile) or planks.has(tile) or stones.has(tile):
		return &""
	return &"stream"


func query_use(_item: ItemDef, tile: Vector2i, _facing: Facing) -> StringName:
	return &"interact" if clue_at(tile) != "" else &""


func perform(action: StringName, _item: ItemDef, tile: Vector2i, _quiet: bool = false) -> void:
	if action == &"interact" and clue_at(tile) != "":
		EventBus.banner_requested.emit(clue_at(tile))


# ---------------------------------------------------------------- 地形

func _layout() -> void:
	# 西北的石头小山：两层
	_raise(6, 4, 23, 14, 1)
	_raise(6, 4, 7, 5, 0)
	_raise(22, 4, 23, 6, 0)
	_raise(22, 13, 23, 14, 0)
	_raise(9, 4, 19, 10, 2)
	_raise(18, 9, 19, 10, 1)
	_steps(19, 20, 15)
	_steps(11, 12, 11)
	# 山顶的泉，水从南面跌下来，成一条溪，斜穿整片林子往南流出去
	_lake(SPRING, 2.6, 1.8, 0.3, 41)
	_trail([Vector2i(15, 8), Vector2i(15, 18), Vector2i(22, 21), Vector2i(29, 21), Vector2i(32, 26), Vector2i(31, 36), Vector2i(29, 43), Vector2i(34, 51), Vector2i(37, 59)], 2, WATER)
	_lake(MOSS_POND, 5.0, 3.4, 0.5, 42)
	# 路。先有溪再踩路：过溪的地方架木头或者踩石头
	# 北口进来，到老樟
	_walk([Vector2i(40, 0), Vector2i(40, 7), Vector2i(45, 13), Vector2i(44, 19), Vector2i(42, 22)], 2, DIRT, false)
	# 老樟脚下踩实的一圈
	for t in _blob(Vector2(42.5, 28.5), 5.5, 3.8, 0.35, 43):
		if not _is_water(t):
			terrain[idx(t)] = DIRT
	# 往西：过溪到猎户家，岔一条上石头山
	_walk([Vector2i(37, 28), Vector2i(28, 27), Vector2i(21, 29), Vector2i(14, 28)], 2, DIRT, false)
	_walk([Vector2i(24, 28), Vector2i(21, 24), Vector2i(20, 19), Vector2i(20, 16)], 1, DIRT, false)
	_walk([Vector2i(19, 13), Vector2i(13, 13), Vector2i(12, 12)], 1, DIRT, false)
	_walk([Vector2i(15, 29), Vector2i(16, 33)], 1, DIRT, false)
	# 往南：到蘑菇坡，过溪踩石头
	_walk([Vector2i(42, 33), Vector2i(41, 41), Vector2i(36, 47), Vector2i(26, 50), Vector2i(21, 50)], 2, DIRT, true)
	# 往东南：到苔潭，再接上驿道
	_walk([Vector2i(41, 41), Vector2i(48, 40)], 1, DIRT, false)
	_walk([Vector2i(60, 43), Vector2i(66, 44)], 1, DIRT, false)
	# 往东：接驿道
	_walk([Vector2i(48, 28), Vector2i(56, 30), Vector2i(62, 28), Vector2i(67, 29)], 2, DIRT, false)
	# 石板驿道：北头驿站，南头山口
	_walk([Vector2i(64, 11), Vector2i(66, 14), Vector2i(66, 22), Vector2i(68, 30), Vector2i(68, 38), Vector2i(66, 45), Vector2i(66, 55)], 2, PAVE, false)
	# 苔潭里几块踩脚石
	for x in range(48, 61):
		var t := Vector2i(x, 43)
		if _is_water(t):
			_stone(t)
	_grow_woods()


## 密林：四边一圈，里头按噪声一团一团地长。路、水、空地和小山旁边不长。
func _grow_woods() -> void:
	_fringe(4, 4, 9, [Rect2i(38, 0, 6, 9)])
	var noise := FastNoiseLite.new()
	noise.seed = 99
	noise.frequency = 0.075
	for y in rows:
		for x in cols:
			var t := Vector2i(x, y)
			if noise.get_noise_2d(x, y) > -0.05 and not _open(t, 2):
				woods[idx(t)] = 1
	for y in rows:
		for x in cols:
			var t := Vector2i(x, y)
			if woods[idx(t)] == 1 and _open(t, 1):
				woods[idx(t)] = 0
	# 山口：驿道出图的地方堵死
	_wood_rect(63, 57, 70, H - 1)


func _open(t: Vector2i, reach: int) -> bool:
	for g: Array in GLADES:
		if Vector2(t.x - g[0], (t.y - g[1]) * 1.3).length() < g[2]:
			return true
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var n := t + Vector2i(dx, dy)
			if not in_map(n):
				continue
			if terrain[idx(n)] != GRASS or level[idx(n)] > 0:
				return true
	return false


func _place() -> void:
	_add_woods(["old0", "old1", "pine0", "old2", "round1", "old0", "pine1"])
	# 千年老樟
	var giant := Px.tex(WildArt.giant_tree(_season))
	var gpos := Vector2(GIANT.x * TS + 8, GIANT.y * TS + 14)
	var g := _sprite(giant, gpos, Vector2(-80, -170))
	g.material = _tree_mat
	_ground_shadow(gpos + Vector2(0, -1), Px.tex(PixelArt.shadow(96, 22, 0.3)))
	_block_rect(GIANT.x - 1, GIANT.y - 1, GIANT.x + 1, GIANT.y)
	for dx in range(-1, 2):
		_clue(GIANT + Vector2i(dx, 0), "老樟树。五六个人抱不过来。树皮的裂缝里塞着很多叠起来的纸条。")
	_prop("bench", tile_center(Vector2i(46, 30)) + Vector2(8, 4))
	_block_rect(46, 30, 47, 30)
	# 西边：猎户的木屋、柴垛、炭窑
	_building("hunter_cabin", CABIN[0], CABIN[1], CABIN[2], CABIN[3])
	_clue(Vector2i(CABIN[0] + 1, CABIN[1] - 1), "猎户的木屋。门楣上挂着一副鹿角，角尖磨圆了。")
	_prop("wood_pile", Vector2(14 * TS, 27 * TS))
	_block_rect(13, 26, 14, 26)
	_clue(Vector2i(13, 26), "柴垛。码得整整齐齐，一根不多一根不少。")
	_clue(Vector2i(14, 26), "柴垛。码得整整齐齐，一根不多一根不少。")
	_building("charcoal_kiln", KILN[0], KILN[1], KILN[2], KILN[3], false)
	_clue(Vector2i(KILN[0] + 1, KILN[1] - 1), "炭窑。窑口是凉的，里头还剩半窑没出的炭。")
	# 东北：塌了的驿站
	_building("relay_ruin", RUIN[0], RUIN[1], RUIN[2], RUIN[3], false)
	_clue(Vector2i(RUIN[0] + 2, RUIN[1] - 1), "驿站只剩半面墙。墙上钉着一块木牌，牌上的站名被雾舔干净了。")
	# 南头：山口的石牌坊
	_prop("stone_arch", Vector2((ARCH.x + 1) * TS, (ARCH.y + 1) * TS))
	_block(ARCH + Vector2i(-1, 0))
	_block(ARCH + Vector2i(2, 0))
	_clue(ARCH + Vector2i(-1, 0), "山口的牌坊。过去就是出山的路，现在叫树和石头堵死了。")
	_clue(ARCH + Vector2i(2, 0), "山口的牌坊。过去就是出山的路，现在叫树和石头堵死了。")
	# 路牌和石灯
	_hang_clue(Vector2i(38, 5), WildArt.signpost(), 2.0)
	_clue(Vector2i(38, 5), "路牌。往南：古木林。林深，天黑前出来。")
	_hang_clue(Vector2i(65, 30), WildArt.signpost(), 2.0)
	_clue(Vector2i(65, 30), "路牌。往北：驿站。往南：山口。两个箭头都褪了色。")
	for t: Vector2i in [Vector2i(43, 6), Vector2i(38, 24), Vector2i(65, 20), Vector2i(70, 40), Vector2i(15, 30)]:
		var lamp := tile_center(t) + Vector2(0, 6)
		_prop("stone_lamp", lamp)
		_block(t)
		_add_night_light(lamp + Vector2(0, -16), 1.8)
	# 石头山上：泉边的石头、松
	_hang_clue(Vector2i(17, 9), BambooArt.marker(), 4.0)
	_clue(Vector2i(17, 9), "泉眼。水是从石头缝里渗出来的，很凉，有一点甜。")
	_grove(Rect2i(6, 4, 18, 11), 16, ["pine0", "pine1"])
	# 倒木、树桩
	var log_tex := Px.tex(WildArt.fallen_log())
	for t: Vector2i in [Vector2i(33, 15), Vector2i(50, 22), Vector2i(24, 44), Vector2i(57, 36), Vector2i(47, 50)]:
		if _is_free(t) and _is_free(t + Vector2i(1, 0)) and _is_free(t + Vector2i(2, 0)):
			_thing(log_tex, t, 3)
			for dx in 3:
				_clue(t + Vector2i(dx, 0), "一根倒了很多年的木头，上面长满了苔。")
	var stump := Px.tex(WildArt.stump())
	for t: Vector2i in [Vector2i(18, 27), Vector2i(19, 31), Vector2i(12, 31), Vector2i(36, 31), Vector2i(48, 25), Vector2i(23, 52), Vector2i(60, 13), Vector2i(52, 46)]:
		if _is_free(t):
			_thing(stump, t)
	# 能走进去的疏林
	_grove(Rect2i(4, 4, 76, 52), 9, ["old0", "old1", "old2", "pine0", "round1"], 1)
	# 蘑菇坡：一片蘑菇
	_place_shrooms()
	var ferns: Array[Texture2D] = [Px.tex(WildArt.fern(0, _season)), Px.tex(WildArt.fern(1, _season))]
	_sprinkle(Rect2i(2, 2, 80, 56), 90, ferns, 5)
	# 苔潭边的芦苇
	var reed := Px.tex(WildArt.reed(0, _season))
	for t in _blob(MOSS_POND, 5.0, 3.4, 0.5, 42):
		var roll := Px.h2(t.x * 3, t.y * 5)
		if _is_water(t) and not stones.has(t) and not _is_water(t + Vector2i(0, 1)) and roll % 3 != 0:
			_sprite(reed, Vector2(t.x * TS + 8, t.y * TS + 13), Vector2(-8, -30))
	_scatter_bushes(60)
	_scatter_tufts(500)


func _place_shrooms() -> void:
	var kinds: Array[Texture2D] = [Px.tex(WildArt.mushroom(0)), Px.tex(WildArt.mushroom(1)), Px.tex(WildArt.mushroom(2))]
	for y in range(44, 56):
		for x in range(13, 28):
			var t := Vector2i(x, y)
			if not _is_free(t):
				continue
			var roll := Px.h2(x * 9 + 2, y * 5 + 7)
			if roll % 100 >= 16:
				continue
			var k := roll / 100 % 3
			_shrooms[t] = k
			_sprite(kinds[k], Vector2(x * TS + 8, y * TS + 13), Vector2(-6, -12))
			occupied[t] = true
			_clue(t, ["一丛褐色的蘑菇，伞盖上还挂着露水。", "红伞白点的蘑菇。好看，多半不能吃。", "一小簇白蘑菇，挤在一起。"][k])
