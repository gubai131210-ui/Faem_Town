extends WildMap
## 藕花荡：南溪往上游走到头，是一片大荡子。溪水就是从这里流出去的。
## 北岸一条路，路边是吊脚的水屋、鸭棚和几块水田；荡里满是荷叶，
## 九曲的木桥通到湖心的小岛，岛上有亭子；南边是泥滩、钓台和一条采莲的小船。
## 这里只管地形、画面和能走的地方；采莲、挖藕、养鸭、人和剧情见 docs/新地图.md。

const W := 80
const H := 52
## 往东出去是南溪
const ROAD_ROWS: Array[int] = [10, 11]
const LAKE := Vector2(44, 31)
const ISLAND := Vector2(44, 30)
const ISLE_WEST := Vector2(25, 34)
const ISLE_EAST := Vector2(62, 27)
## 水田：每块 [x0, y0, x1, y1]
const PADDIES := [[4, 15, 8, 18], [10, 15, 14, 18], [4, 20, 8, 23], [10, 20, 14, 24], [4, 25, 8, 29], [10, 26, 13, 29]]
const HOUSE_A := [18, 9, 5, 3]
const HOUSE_B := [28, 9, 5, 3]
const DUCK_SHED := [50, 9, 3, 2]
const PAVILION := [43, 30, 3, 2]
const BOAT := Vector2i(59, 42)

var _paddy: Dictionary[Vector2i, bool] = {}
var _lotus: Dictionary[Vector2i, bool] = {}


func _ready() -> void:
	map_id = &"ouhua"
	_rng.seed = 20261202
	_setup_wild(W, H)
	_layout()
	_finish_relief()
	_build_ground()
	_make_entities()
	_add_planks()
	_place()
	_make_water_fx(90)


func spawn_position(_spawn: StringName) -> Vector2:
	return tile_center(Vector2i(W - 2, ROAD_ROWS[0])) + Vector2(0, 8)


func spawn_facing(_spawn: StringName) -> Facing:
	return Facing.LEFT


func trigger_at(tile: Vector2i) -> Dictionary:
	if tile.x == W - 1 and ROAD_ROWS.has(tile.y):
		return {"map": &"nanxi", "spawn": &"from_ouhua"}
	return {}


## 鱼表先借山祠那片湖的；荡子自己的鱼见 docs/新地图.md。
func fishing_water(tile: Vector2i) -> StringName:
	if not _is_water(tile) or planks.has(tile) or stones.has(tile) or _paddy.has(tile):
		return &""
	return &"lake"


func query_use(_item: ItemDef, tile: Vector2i, _facing: Facing) -> StringName:
	return &"interact" if clue_at(tile) != "" else &""


func perform(action: StringName, _item: ItemDef, tile: Vector2i, _quiet: bool = false) -> void:
	if action == &"interact" and clue_at(tile) != "":
		EventBus.banner_requested.emit(clue_at(tile))


func clue_at(tile: Vector2i) -> String:
	if clues.has(tile):
		return clues[tile]
	if _paddy.has(tile):
		return "水田。水很浅，看得见泥上的脚印。"
	if _lotus.has(tile):
		return "荷叶挨着荷叶，底下的水是凉的。"
	return ""


# ---------------------------------------------------------------- 地形

func _land(tiles: Array[Vector2i], kind: int = GRASS) -> void:
	for t in tiles:
		terrain[idx(t)] = kind
		solid[idx(t)] = 0


func _layout() -> void:
	# 南岸的泥滩先铺上，再挖荡子
	for t in _blob(Vector2(40, 47), 34, 4.5, 0.5, 31):
		terrain[idx(t)] = SAND
	_lake(LAKE, 30, 13.5, 0.55, 21)
	_lake(Vector2(22, 27), 9, 8, 0.6, 22)
	_lake(Vector2(64, 34), 10, 8, 0.6, 23)
	# 荡水往东流出去，就是南溪
	_trail([Vector2i(72, 32), Vector2i(76, 31), Vector2i(W - 1, 31)], 3, WATER)
	# 岛
	_land(_blob(ISLAND, 5.5, 3.6, 0.4, 24))
	_land(_blob(ISLE_WEST, 3.2, 2.4, 0.4, 25))
	_land(_blob(ISLE_EAST, 3.0, 2.2, 0.4, 26))
	# 北岸的路：东口进来，弯弯地往西到水田
	_trail([Vector2i(W - 1, 10), Vector2i(66, 10), Vector2i(58, 12), Vector2i(46, 11), Vector2i(34, 12), Vector2i(22, 11), Vector2i(12, 12), Vector2i(6, 12)], 2, DIRT)
	# 下到桥头、鸭滩的小路
	_trail([Vector2i(40, 12), Vector2i(40, 17)], 1, DIRT)
	_trail([Vector2i(54, 12), Vector2i(56, 17)], 1, DIRT)
	# 九曲桥：北岸到湖心岛
	_bridge([Vector2i(40, 16), Vector2i(40, 20), Vector2i(36, 20), Vector2i(36, 24), Vector2i(41, 24), Vector2i(41, 27)])
	# 岛往南到钓台
	_bridge([Vector2i(47, 33), Vector2i(47, 37), Vector2i(53, 37), Vector2i(53, 41), Vector2i(49, 41), Vector2i(49, 45)])
	# 钓台：东南一块伸进水里的台子
	_bridge([Vector2i(53, 39), Vector2i(58, 39)])
	for y in range(38, 41):
		for x in range(58, 62):
			_plank(Vector2i(x, y))
	# 西边小岛：从湖心岛踩石头过去
	for x in range(26, 43):
		var t := Vector2i(x, 33)
		if _is_water(t):
			_stone(t)
	# 东边小岛：木桥接北岸
	_bridge([Vector2i(62, 17), Vector2i(62, 25)])
	# 水田和田埂
	_fill(3, 14, 15, 30, DIRT)
	for p: Array in PADDIES:
		for y in range(p[1], p[3] + 1):
			for x in range(p[0], p[2] + 1):
				var t := Vector2i(x, y)
				_set_water(t)
				_paddy[t] = true
	# 四周的林子；东口和溪口留出来
	_fringe(3, 4, 8, [Rect2i(72, 8, 8, 6), Rect2i(72, 29, 8, 5), Rect2i(8, 43, 64, 5)])


## 沿着一串点架木桥，只在水上铺板。
func _bridge(points: Array) -> void:
	for k in range(points.size() - 1):
		var a: Vector2i = points[k]
		var b: Vector2i = points[k + 1]
		var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
		for s in n + 1:
			var t := Vector2i(a.x + signi(b.x - a.x) * mini(s, absi(b.x - a.x)), a.y + signi(b.y - a.y) * mini(s, absi(b.y - a.y)))
			if in_map(t) and _is_water(t):
				_plank(t)


func _place() -> void:
	_add_woods(["willow0", "round0", "old0", "round2", "willow1"])
	_place_paddy()
	_place_lotus()
	# 北岸：两户水屋、鸭棚
	_building("stilt_house", HOUSE_A[0], HOUSE_A[1], HOUSE_A[2], HOUSE_A[3])
	_building("stilt_house", HOUSE_B[0], HOUSE_B[1], HOUSE_B[2], HOUSE_B[3])
	_clue(Vector2i(HOUSE_A[0] + 2, HOUSE_A[1] - 1), "吊脚的水屋。梯子边晾着一串莲蓬。")
	_clue(Vector2i(HOUSE_B[0] + 2, HOUSE_B[1] - 1), "门关着。窗台上摆了一排空的鸭蛋壳，壳上画了脸。")
	_building("duck_shed", DUCK_SHED[0], DUCK_SHED[1], DUCK_SHED[2], DUCK_SHED[3], false)
	_clue(Vector2i(DUCK_SHED[0] + 1, DUCK_SHED[1] - 1), "鸭棚。里头铺着干稻草，有一股暖烘烘的味道。")
	# 鸭滩围一圈篱笆的意思：几只晒网的架子
	_thing(PropArt.texture("drying_rack"), Vector2i(24, 13), 2).offset = -PropArt.anchor("drying_rack")
	_clue(Vector2i(24, 13), "竹匾里晒着切开的藕片，白的，一孔一孔。")
	_clue(Vector2i(25, 13), "竹匾里晒着切开的藕片，白的，一孔一孔。")
	_hang_clue(Vector2i(70, 9), WildArt.signpost(), 2.0)
	_clue(Vector2i(70, 9), "路牌。往西：藕花荡。往东：南溪。")
	for t: Vector2i in [Vector2i(68, 12), Vector2i(41, 14), Vector2i(16, 13)]:
		var lamp := tile_center(t) + Vector2(0, 6)
		_prop("stone_lamp", lamp)
		_block(t)
		_add_night_light(lamp + Vector2(0, -16), 1.8)
	# 湖心岛：亭子、老柳、长凳
	_building("pavilion", PAVILION[0], PAVILION[1], PAVILION[2], PAVILION[3], false)
	_clue(Vector2i(PAVILION[0] + 1, PAVILION[1] - 1), "湖心亭。柱子上刻着字：「藕断」，下半句被人刮掉了。")
	_tree("willow0", Vector2i(47, 30))
	_tree("willow1", Vector2i(40, 31))
	_prop("bench", tile_center(Vector2i(45, 32)) + Vector2(8, 4))
	_block_rect(45, 32, 46, 32)
	# 两座小岛
	_tree("willow1", Vector2i(25, 34))
	_hang_clue(Vector2i(26, 35), BambooArt.marker(), 4.0)
	_clue(Vector2i(26, 35), "岛上一块石头，压着半张湿透的纸。字化开了。")
	_tree("old0", Vector2i(62, 27))
	_clue(Vector2i(62, 27), "老树的树洞里塞着一只木头刻的鸭子。")
	# 钓台边系着采莲船
	_prop("lotus_boat", tile_center(BOAT) + Vector2(8, 6))
	_block_rect(BOAT.x - 1, BOAT.y, BOAT.x + 1, BOAT.y)
	for dx in range(-1, 2):
		_clue(BOAT + Vector2i(dx, 0), "采莲的小船，系在钓台边上。船底补过三回。")
	# 岸上的树：柳为主
	_grove(Rect2i(4, 12, 72, 8), 9, ["willow0", "willow1", "round0"])
	_grove(Rect2i(4, 42, 72, 8), 8, ["willow1", "round2", "willow0", "old2"])
	_grove(Rect2i(4, 4, 72, 6), 12, ["round0", "plum0", "round1"])
	_scatter_bushes(40)
	_scatter_tufts(600)


func _place_paddy() -> void:
	for t: Vector2i in _paddy:
		var s := Sprite2D.new()
		s.centered = false
		s.texture = Px.tex(WildArt.paddy(_season, Px.h2(t.x, t.y) % 3))
		s.position = Vector2(t.x * TS, t.y * TS)
		s.z_index = -8
		add_child(s)


## 荷和芦苇。荷成片长在荡里，桥边和水道留空；芦苇贴着岸。
func _place_lotus() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 77
	noise.frequency = 0.085
	var lotus: Array[Texture2D] = []
	for kind in 4:
		for v in 2:
			lotus.append(Px.tex(WildArt.lotus(kind, v, _season)))
	var reeds: Array[Texture2D] = [Px.tex(WildArt.reed(0, _season)), Px.tex(WildArt.reed(1, _season))]
	for y in rows:
		for x in cols:
			var t := Vector2i(x, y)
			if not _is_water(t) or planks.has(t) or stones.has(t) or _paddy.has(t) or woods[idx(t)] == 1:
				continue
			if x > 70 and y > 28 and y < 35:
				continue
			if absi(x - BOAT.x) <= 2 and absi(y - BOAT.y) <= 1:
				continue
			var roll := Px.h2(x * 5 + 9, y * 7 + 4)
			var shore := false
			for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				var n: Vector2i = t + d
				if in_map(n) and not _is_water(n):
					shore = true
			if shore:
				if roll % 100 < 38:
					var r: Texture2D = reeds[roll % 2]
					_sprite(r, Vector2(x * TS + 8 + roll % 5 - 2, y * TS + 13), Vector2(-r.get_width() / 2.0, -float(r.get_height())))
				continue
			if noise.get_noise_2d(x, y) < -0.02 or roll % 100 < 22:
				continue
			_lotus[t] = true
			# 花和莲蓬少，叶多
			var k := roll / 100 % 10
			var kind := 0 if k < 4 else (1 if k < 7 else (2 if k < 9 else 3))
			var tex: Texture2D = lotus[kind * 2 + roll % 2]
			_sprite(tex, Vector2(x * TS + 8 + roll % 3 - 1, y * TS + 14 - roll / 3 % 3), Vector2(-tex.get_width() / 2.0, -float(tex.get_height())))
