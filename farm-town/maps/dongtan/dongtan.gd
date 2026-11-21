extends WildMap
## 东滩：顺着河岸往东走到头的海边。东滩灯亮了以后才来得了。
## 东边一整片是海（海钓的鱼都在这儿），海边一条沙滩能赶海；北头的岬角上立着灯塔，西边草地上是白鹭的画室。
## 船坞里的船壳仍只是看看。灯亮以后，岸边那条下水的船送到雾岛（决策 128）。

## 老东滩是左上角 44×30；往东（海）、往南（沙滩接着长）扩到 56×48，老坐标一格不动（决策 154）。
const OLD_W := 44
const OLD_H := 30
const W := 56
const H := 48
const NEW_TREES: Array[String] = ["round0", "pine0", "round1", "pine1", "round2", "willow0"]
## 南边渔村的路占的两行，和第二座栈桥所在的行
const SOUTH_ROWS: Array[int] = [38, 39]
const PIER2_ROW := 41
const PIER2_LEN := 8
## 往西回河岸的土路占的两行
const ROAD_ROWS: Array[int] = [14, 15]
## 沙滩从海岸线往西有几格宽
const SAND_WIDE := 7
## 北头伸进海里的岬角：这几行的海岸线往东多出几格
const CAPE_ROWS := Vector2i(3, 9)
const CAPE_OUT := 4
## 灯塔占的格子 [x0, y0, x1, y1]；最南一行是正面
const LIGHTHOUSE: Array[int] = [36, 6, 37, 7]
## 白鹭的画室占的格子 [x0, y0, x1, y1]；最南一行是正面的墙
const STUDIO: Array[int] = [11, 7, 14, 10]
## 伸进海里的栈桥：从哪一行、岸边往东几格
const PIER_ROW := 18
const PIER_LEN := 5
## 白鹭在沙滩上支画架的地方（她站在西边那一格）
const EASEL_TILE := Vector2i(28, 20)
## 画室东墙钉着的一角。下午她站在门前那一格，不占这格。
const CORNER_TILE := Vector2i(15, 9)
## 滩上的礁石。北边这一块落着精卫衔来的细枝。
const REEFS: Array[Vector2i] = [Vector2i(31, 23), Vector2i(32, 24), Vector2i(29, 11), Vector2i(33, 12), Vector2i(30, 26)]
const BIRD := Vector2i(29, 11)
## 下水的船停在这一行海岸外面。船坞里那两只壳不上水。
const BOAT_ROW := 23
## 鱼市 [x0, 门前那一行, 宽, 深]。门朝南，案在路南边的草地上
const FISH_MARKET: Array[int] = [4, 18, 3, 2]
## 船坞。再往南，两只船壳架在草棚下
const BOATYARD: Array[int] = [16, 24, 4, 3]

var _pier: Array[Vector2i] = []
## 灯塔亮了以后转的那道光柱。没点最初的灯时是空的
var _beam: Node2D
## 远行以后，半张船票钉在这一格。没看过是 (-1, -1)
var _stub_tile := Vector2i(-1, -1)


func _ready() -> void:
	map_id = &"dongtan"
	_rng.seed = 20261121
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
	var no_shore: Array[Vector2i] = []
	occupied[BIRD] = true
	Foraging.settle(map_id, beach_tiles(), no_shore, true)
	Foraging.changed.connect(_sync_forage)
	_sync_forage()
	_make_water_fx(160)
	_spawn_npcs()


func _exit_tree() -> void:
	super._exit_tree()
	if Foraging.changed.is_connected(_sync_forage):
		Foraging.changed.disconnect(_sync_forage)


func _process(delta: float) -> void:
	super._process(delta)
	if _beam != null:
		_beam.rotation = deg_to_rad(Glow.beam_angle(_time))


func _draw_beam() -> void:
	if _beam == null:
		return
	_beam.draw_colored_polygon(Glow.beam_points(), Glow.BEAM)


func spawn_position(spawn: StringName) -> Vector2:
	if spawn == &"from_wudao":
		return tile_center(boat_stand())
	return tile_center(Vector2i(1, ROAD_ROWS[0])) + Vector2(0, 8)


func spawn_facing(spawn: StringName) -> Facing:
	return Facing.LEFT if spawn == &"from_wudao" else Facing.RIGHT


func boat_tile() -> Vector2i:
	return Vector2i(_shore_x(BOAT_ROW) + 1, BOAT_ROW)


func boat_stand() -> Vector2i:
	return Vector2i(_shore_x(BOAT_ROW), BOAT_ROW)


## 灯亮了，这条船才出海。
func departure(tile: Vector2i) -> Dictionary:
	if tile == boat_tile() and Lamps.is_lit(&"east"):
		return {"map": &"wudao", "spawn": &"landing"}
	return {}


func trigger_at(tile: Vector2i) -> Dictionary:
	if tile.x == 0 and ROAD_ROWS.has(tile.y):
		return {"map": &"riverbank", "spawn": &"from_dongtan"}
	return {}


## 海里全是海水；栈桥的木板不算。
func fishing_water(tile: Vector2i) -> StringName:
	if tile == boat_tile() or not _is_water(tile) or _pier.has(tile) or planks.has(tile):
		return &""
	return &"sea"


func query_use(item: ItemDef, tile: Vector2i, _facing: Facing) -> StringName:
	if npc_at(tile) != null or _at_lighthouse(tile) or _at_studio(tile) or tile == EASEL_TILE or tile == CORNER_TILE or tile == _stub_tile or _at_returned(tile) or tile == boat_tile() or tile == BIRD or clues.has(tile):
		return &"interact"
	if Foraging.item_at(map_id, tile) != &"":
		return &"harvest"
	if item != null and item.id == &"rod" and fishing_water(tile) != &"":
		return &"cast"
	return &""


func perform(action: StringName, _item: ItemDef, tile: Vector2i, _quiet: bool = false) -> void:
	match action:
		&"interact":
			if _talk_at(tile):
				return
			var going := departure(tile)
			if not going.is_empty():
				SceneRouter.travel(going["map"] as StringName, going["spawn"] as StringName)
				return
			if tile == boat_tile():
				EventBus.banner_requested.emit("船还系在坞里。东边的灯亮了，船娘才出海。")
				return
			if tile == BIRD:
				if not Bestiary.known(&"jingwei"):
					Bestiary.hear(&"jingwei")
					EventBus.banner_requested.emit("礁上有细树枝。一只鸟衔着石子往海上飞。")
				else:
					EventBus.banner_requested.emit("树枝还在。鸟已经把石子投进海里了。")
				return
			if _at_lighthouse(tile):
				if Story.lamp_lit():
					EventBus.banner_requested.emit("灯塔。门开着，有人上去擦过玻璃。顶上的灯亮了，海上老远就看得见")
				else:
					EventBus.banner_requested.emit("灯塔。门锁着，锁眼里塞满了沙。顶上的灯是黑的")
			elif _at_studio(tile):
				EventBus.banner_requested.emit("滩上的小屋，白鹭拿它当画室。窗台上晾着一排画，画的都是这片滩")
			elif tile == EASEL_TILE:
				EventBus.banner_requested.emit("白鹭的画架。画的是灯塔，塔顶的灯亮着")
			elif tile == CORNER_TILE:
				GameState.set_flag(&"read_egret_corner")
				EventBus.banner_requested.emit(clue_at(tile))
			elif tile == _stub_tile:
				EventBus.banner_requested.emit(clue_at(tile))
			elif _at_front(FISH_MARKET, tile):
				EventBus.banner_requested.emit("鱼市。蓝棚底下一条案，案上摆着鱼。没人看摊")
			elif _at_front(BOATYARD, tile):
				EventBus.banner_requested.emit("船坞。草棚底下架着两只船壳，旁边一支桨。船还没下水")
			elif clues.has(tile):
				EventBus.banner_requested.emit(clues[tile])
		&"harvest":
			_pick_forage(tile)


func clue_at(tile: Vector2i) -> String:
	if clues.has(tile):
		return clues[tile]
	if tile == _stub_tile:
		return "半张船票钉在桩上。一边是撕开的。另外半张不在这。"
	if tile == CORNER_TILE:
		var extra := PeopleLine.mark(&"egret")
		if extra != "":
			return extra
		return "钉在画室东墙的一角。画的是岬角上的灯塔，塔在左边，海在右边。颜料干了，边角卷着。"
	return ""


func _at_lighthouse(tile: Vector2i) -> bool:
	return tile.y == LIGHTHOUSE[3] and tile.x >= LIGHTHOUSE[0] and tile.x <= LIGHTHOUSE[2]


func _at_studio(tile: Vector2i) -> bool:
	return tile.y == STUDIO[3] and tile.x >= STUDIO[0] and tile.x <= STUDIO[2]


func _at_front(place: Array[int], tile: Vector2i) -> bool:
	return tile.y == place[1] - 1 and tile.x >= place[0] and tile.x < place[0] + place[2]


func _at_returned(tile: Vector2i) -> bool:
	return _at_front(FISH_MARKET, tile) or _at_front(BOATYARD, tile)


# ---------------------------------------------------------------- 布局

## 这一行的海岸线在哪一列（这一列往东都是海）。
func _shore_x(y: int) -> int:
	var x := 34 + int(roundf(sin(y * 0.23 + 0.5) * 1.8 + sin(y * 0.61) * 0.7))
	if y >= CAPE_ROWS.x and y <= CAPE_ROWS.y:
		x += CAPE_OUT
	return x


func _layout() -> void:
	for y in H:
		var shore := _shore_x(y)
		for x in range(shore - SAND_WIDE, shore + 1):
			terrain[idx(Vector2i(x, y))] = SAND
		for x in range(shore + 1, W):
			_set_water(Vector2i(x, y))
	# 栈桥：水上的几格木板，能走
	for i in PIER_LEN:
		var t := Vector2i(_shore_x(PIER_ROW) + 1 + i, PIER_ROW)
		if in_map(t):
			_pier.append(t)
			solid[idx(t)] = 0
	# 从河岸来的土路，走到沙滩边上；画室门前一小段
	_fill(0, ROAD_ROWS[0], _shore_x(ROAD_ROWS[0]) - SAND_WIDE - 1, ROAD_ROWS[1], DIRT)
	_fill(12, STUDIO[3] + 1, 13, ROAD_ROWS[0] - 1, DIRT)
	# 路南边踩到鱼市门前，再往东绕到船坞
	_fill(3, ROAD_ROWS[1], 3, FISH_MARKET[1], DIRT)
	_fill(3, FISH_MARKET[1], 20, FISH_MARKET[1], DIRT)
	_fill(15, FISH_MARKET[1], 20, BOATYARD[1], DIRT)


## 能赶海的格子：空着的沙地。
func beach_tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(2, OLD_H - 2):
		for x in range(2, OLD_W):
			var t := Vector2i(x, y)
			if terrain[idx(t)] == SAND and solid[idx(t)] == 0 and not occupied.has(t):
				out.append(t)
	return out


func _place_objects() -> void:
	# 栈桥
	for t in _pier:
		var m := 0
		if _pier.has(t + Vector2i(1, 0)):
			m |= 2
		if _pier.has(t + Vector2i(-1, 0)) or not _is_water(t + Vector2i(-1, 0)):
			m |= 8
		var plank := Sprite2D.new()
		plank.texture = Px.tex(PixelArt.dock_tile(m))
		plank.centered = false
		plank.position = Vector2(t.x * TS, t.y * TS)
		plank.z_index = -7
		add_child(plank)
		occupied[t] = true
	var post_tex := Px.tex(PixelArt.dock_post())
	for t: Vector2i in [_pier[1], _pier[_pier.size() - 1]]:
		var post := Sprite2D.new()
		post.texture = post_tex
		post.centered = false
		post.position = Vector2(t.x * TS + 6, t.y * TS + 13)
		post.z_index = -7
		add_child(post)

	# 灯塔
	var tower_pos := Vector2((LIGHTHOUSE[0] + LIGHTHOUSE[2] + 1) * TS / 2.0, (LIGHTHOUSE[3] + 1) * TS)
	var tower := _sprite(Px.tex(BeachArt.lighthouse(Story.lamp_lit())), tower_pos, Vector2(-20, -100))
	if Story.lamp_lit():
		_beam = Node2D.new()
		_beam.position = Vector2(0, -82)
		_beam.z_index = 1
		_beam.draw.connect(_draw_beam)
		tower.add_child(_beam)
		_beam.queue_redraw()
	_ground_shadow(tower_pos + Vector2(0, -1), Px.tex(PixelArt.shadow(34, 8, 0.25)))
	_block_rect(LIGHTHOUSE[0], LIGHTHOUSE[1], LIGHTHOUSE[2], LIGHTHOUSE[3])

	# 白鹭的画室
	var studio_pos := Vector2((STUDIO[0] + STUDIO[2] + 1) * TS / 2.0, (STUDIO[3] + 1) * TS)
	_sprite(Px.tex(BeachArt.studio()), studio_pos, Vector2(-32, -56))
	_ground_shadow(studio_pos + Vector2(0, -1), Px.tex(PixelArt.shadow(58, 8, 0.22)))
	_block_rect(STUDIO[0], STUDIO[1], STUDIO[2], STUDIO[3])
	_hang_clue(CORNER_TILE, PlaceClueArt.canvas(), 6.0)
	_add_night_light(studio_pos + Vector2(-14, -16), 1.3)

	# 沙滩上的画架
	var easel_pos := tile_center(EASEL_TILE) + Vector2(0, 6)
	_sprite(Px.tex(BeachArt.easel()), easel_pos, Vector2(-7, -20))
	_ground_shadow(easel_pos + Vector2(0, -1), _small_shadow)
	_block(EASEL_TILE)
	occupied[EASEL_TILE + Vector2i(-1, 0)] = true

	# 鱼市和船坞。只看看，人不在这儿
	_place_returned(FISH_MARKET, "fish_market")
	_place_returned(BOATYARD, "boatyard")

	# 礁石
	for t in REEFS:
		if in_map(t) and solid[idx(t)] == 0:
			var rp := tile_center(t) + Vector2(0, 6)
			_prop("rock_%d" % (t.x % 2), rp)
			_ground_shadow(rp + Vector2(0, -1), _small_shadow)
			_block(t)

	_reserve(0, ROAD_ROWS[0] - 1, 26, ROAD_ROWS[1] + 1)
	_reserve(2, ROAD_ROWS[1], 21, BOATYARD[1] + 1)
	_reserve(STUDIO[0] - 1, STUDIO[1] - 2, STUDIO[2] + 1, ROAD_ROWS[0])
	# 路口南边不种树：树冠会把刚进来的人盖住
	_reserve(0, ROAD_ROWS[1] + 1, 3, ROAD_ROWS[1] + 4)
	var stub := Vector2i(_shore_x(PIER_ROW) - 1, PIER_ROW)
	_reserve(stub.x, stub.y, stub.x, stub.y)
	_scatter_trees(22)
	_scatter_bushes(14)
	_scatter_tufts(260)
	_release_ghosts()
	if GameState.has_flag(&"ending_voyage"):
		if in_map(stub) and solid[idx(stub)] == 0:
			_stub_tile = stub
			_hang_clue(stub, EndingArt.ticket_half(), 4.0)


func _place_returned(place: Array[int], prop_name: String) -> void:
	var x0: int = place[0]
	var front: int = place[1]
	var wide: int = place[2]
	var deep: int = place[3]
	var pos := Vector2((x0 + wide / 2.0) * TS, front * TS)
	_prop(prop_name, pos)
	_ground_shadow(pos + Vector2(0, -1), Px.tex(PixelArt.shadow(wide * TS - 4, 8, 0.22)))
	_block_rect(x0, front - deep, x0 + wide - 1, front - 1)


# ---------------------------------------------------------------- 往东、往南扩出来的部分

func _ghost_tree(t: Vector2i) -> bool:
	return _legacy_edge(t, OLD_W, OLD_H)


func _layout_new() -> void:
	# 南边渔村的路：从沙滩边往西，再往南一条
	var edge := _shore_x(SOUTH_ROWS[0]) - SAND_WIDE - 1
	_fill(4, SOUTH_ROWS[0], edge, SOUTH_ROWS[1], DIRT)
	_fill(6, SOUTH_ROWS[1] + 1, 7, 45, DIRT)
	# 第二座栈桥，比老的长
	for i in PIER2_LEN:
		_plank(Vector2i(_shore_x(PIER2_ROW) + 1 + i, PIER2_ROW))
	# 海里一个小沙洲，走不到
	for t in _blob(Vector2(W - 6.0, 22.0), 3.2, 2.2, 0.25, 8821):
		if t.x > _shore_x(t.y) + 3:
			terrain[idx(t)] = SAND
			solid[idx(t)] = 1


func _place_new() -> void:
	_new_edge_trees(OLD_W, OLD_H, NEW_TREES)
	_reserve(0, SOUTH_ROWS[0] - 1, _shore_x(SOUTH_ROWS[0]) - SAND_WIDE, SOUTH_ROWS[1] + 1)
	_building("house", 10, 36, 4, 3, true)
	_wall_clue(10, 36, 4, "渔家的屋子。门槛被踩得凹了下去，门口的鞋都是湿的")
	_building("house", 17, 36, 4, 3, true)
	_wall_clue(17, 36, 4, "窗纸上贴着剪纸的鱼，一条朝东，一条朝西")
	_building("boathouse", 25, 36, 5, 3, true)
	_wall_clue(25, 36, 5, "岸边的船屋。里面有一只补过的小船，补丁比船板还新")
	_building("well", 12, 45, 2, 2, false)
	_wall_clue(12, 45, 2, "海边的井，水是微咸的，打上来要沉一沉才能喝")
	_wide_prop("drying_rack", Vector2i(16, 43), 2, "晒着一排海带，用石头压着边")
	_wide_prop("wood_pile", Vector2i(21, 43), 2, "浮木劈成的柴，烧起来火是蓝的")
	_small_prop("jar_clay", Vector2i(9, 43), "盐坛。盖子上刻了一道道，数得出是几年的盐")
	_wide_prop("bench", Vector2i(_shore_x(44) - 6, 44), 2, "沙滩上的长凳，凳腿陷进了沙里")
	_clue(Vector2i(_shore_x(PIER2_ROW) + PIER2_LEN, PIER2_ROW), "栈桥尽头。水是深蓝色的，一直望到天边")
	for t: Vector2i in [Vector2i(8, 37), Vector2i(15, 37), Vector2i(23, 37), Vector2i(5, 42)]:
		if _is_free(t):
			_lamp_post(t)
	for t: Vector2i in [Vector2i(30, 41), Vector2i(31, 44), Vector2i(28, 46)]:
		if _is_free(t) and terrain[idx(t)] != SAND:
			_small_prop("rock_%d" % (t.x % 2), t)
	_grove(Rect2i(0, OLD_H, 28, 6), 22, NEW_TREES)
	_grove(Rect2i(0, 40, 28, 8), 22, NEW_TREES)
	_sprinkle_grass(Rect2i(0, OLD_H, 28, H - OLD_H), 71)
