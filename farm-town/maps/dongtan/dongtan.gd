extends OutdoorMap
## 东滩：顺着河岸往东走到头的海边。东滩灯亮了以后才来得了。
## 东边一整片是海（海钓的鱼都在这儿），海边一条沙滩能赶海；北头的岬角上立着灯塔，西边草地上是白鹭的画室。

const W := 44
const H := 30
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
## 滩上的礁石
const REEFS: Array[Vector2i] = [Vector2i(31, 23), Vector2i(32, 24), Vector2i(29, 11), Vector2i(33, 12), Vector2i(30, 26)]

var _pier: Array[Vector2i] = []


func _ready() -> void:
	map_id = &"dongtan"
	_rng.seed = 20261121
	_setup_grid(W, H)
	_layout()
	_build_ground()
	_make_entities()
	_place_objects()
	var no_shore: Array[Vector2i] = []
	Foraging.settle(map_id, beach_tiles(), no_shore, true)
	Foraging.changed.connect(_sync_forage)
	_sync_forage()
	_make_water_fx(160)
	_spawn_npcs()


func _exit_tree() -> void:
	if Foraging.changed.is_connected(_sync_forage):
		Foraging.changed.disconnect(_sync_forage)


func spawn_position(_spawn: StringName) -> Vector2:
	return tile_center(Vector2i(1, ROAD_ROWS[0])) + Vector2(0, 8)


func spawn_facing(_spawn: StringName) -> Facing:
	return Facing.RIGHT


func trigger_at(tile: Vector2i) -> Dictionary:
	if tile.x == 0 and ROAD_ROWS.has(tile.y):
		return {"map": &"riverbank", "spawn": &"from_dongtan"}
	return {}


## 海里全是海水；栈桥的木板不算。
func fishing_water(tile: Vector2i) -> StringName:
	if not _is_water(tile) or _pier.has(tile):
		return &""
	return &"sea"


func query_use(item: ItemDef, tile: Vector2i, _facing: Facing) -> StringName:
	if npc_at(tile) != null or _at_lighthouse(tile) or _at_studio(tile) or tile == EASEL_TILE:
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
			if _at_lighthouse(tile):
				if Story.lamp_lit():
					EventBus.banner_requested.emit("灯塔。门开着，有人上去擦过玻璃。顶上的灯亮了，海上老远就看得见")
				else:
					EventBus.banner_requested.emit("灯塔。门锁着，锁眼里塞满了沙。顶上的灯是黑的")
			elif _at_studio(tile):
				EventBus.banner_requested.emit("滩上的小屋，白鹭拿它当画室。窗台上晾着一排画，画的都是这片滩")
			elif tile == EASEL_TILE:
				EventBus.banner_requested.emit("白鹭的画架。画的是灯塔，塔顶的灯亮着")
		&"harvest":
			_pick_forage(tile)


func _at_lighthouse(tile: Vector2i) -> bool:
	return tile.y == LIGHTHOUSE[3] and tile.x >= LIGHTHOUSE[0] and tile.x <= LIGHTHOUSE[2]


func _at_studio(tile: Vector2i) -> bool:
	return tile.y == STUDIO[3] and tile.x >= STUDIO[0] and tile.x <= STUDIO[2]


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


## 能赶海的格子：空着的沙地。
func beach_tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(2, H - 2):
		for x in range(2, W):
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
	_sprite(Px.tex(BeachArt.lighthouse(Story.lamp_lit())), tower_pos, Vector2(-20, -100))
	_ground_shadow(tower_pos + Vector2(0, -1), Px.tex(PixelArt.shadow(34, 8, 0.25)))
	_block_rect(LIGHTHOUSE[0], LIGHTHOUSE[1], LIGHTHOUSE[2], LIGHTHOUSE[3])

	# 白鹭的画室
	var studio_pos := Vector2((STUDIO[0] + STUDIO[2] + 1) * TS / 2.0, (STUDIO[3] + 1) * TS)
	_sprite(Px.tex(BeachArt.studio()), studio_pos, Vector2(-32, -56))
	_ground_shadow(studio_pos + Vector2(0, -1), Px.tex(PixelArt.shadow(58, 8, 0.22)))
	_block_rect(STUDIO[0], STUDIO[1], STUDIO[2], STUDIO[3])
	_add_night_light(studio_pos + Vector2(-14, -16), 1.3)

	# 沙滩上的画架
	var easel_pos := tile_center(EASEL_TILE) + Vector2(0, 6)
	_sprite(Px.tex(BeachArt.easel()), easel_pos, Vector2(-7, -20))
	_ground_shadow(easel_pos + Vector2(0, -1), _small_shadow)
	_block(EASEL_TILE)
	occupied[EASEL_TILE + Vector2i(-1, 0)] = true

	# 礁石
	for t in REEFS:
		if in_map(t) and solid[idx(t)] == 0:
			var rp := tile_center(t) + Vector2(0, 6)
			_prop("rock_%d" % (t.x % 2), rp)
			_ground_shadow(rp + Vector2(0, -1), _small_shadow)
			_block(t)

	_reserve(0, ROAD_ROWS[0] - 1, 26, ROAD_ROWS[1] + 1)
	_reserve(STUDIO[0] - 1, STUDIO[1] - 2, STUDIO[2] + 1, ROAD_ROWS[0])
	# 路口南边不种树：树冠会把刚进来的人盖住
	_reserve(0, ROAD_ROWS[1] + 1, 3, ROAD_ROWS[1] + 4)
	_scatter_trees(22)
	_scatter_bushes(14)
	_scatter_tufts(260)
