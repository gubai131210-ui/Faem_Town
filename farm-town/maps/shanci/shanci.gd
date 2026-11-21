extends WildMap
## 山祠：从北坡牧场顺着山路上来的山顶。山祠灯亮了以后才来得了。祠西再往上是后山。
## 石阶上去是一座古祠，檐下挂着祈愿的木牌；西边一片桂花林，东边是山顶湖（湖里的鱼都在这儿钓）。
## 起雾的日子，岚（一头白鹿）站在祠前。

## 老山顶是左上角 44×30；往东、往南扩到 76×48，老坐标一格不动（决策 153）。
const OLD_W := 44
const OLD_H := 30
const W := 76
const H := 48
const NEW_TREES: Array[String] = ["round0", "pine0", "round1", "pine1", "round2", "old0"]
## 山腰的两条横路：南北向的石阶在中间交成十字
const CROSS_ROWS: Array[int] = [38, 39]
## 往北去高处的小路占的两列
const NORTH_COLS: Array[int] = [56, 57]
## 下山回牧场的石阶占的两列
const STEP_COLS: Array[int] = [21, 22]
## 祠前的石板地 [x0, y0, x1, y1]
const COURT: Array[int] = [16, 10, 27, 13]
## 古祠占的格子 [x0, y0, x1, y1]；最南一行是正面
const SHRINE: Array[int] = [19, 6, 23, 9]
## 挂祈愿牌的木架占的格子
const RACK_TILES: Array[Vector2i] = [Vector2i(16, 10), Vector2i(17, 10)]
## 桂花树种在哪几格
const GROVE: Array[Vector2i] = [
	Vector2i(5, 15), Vector2i(9, 14), Vector2i(13, 15),
	Vector2i(7, 18), Vector2i(11, 18), Vector2i(4, 21),
	Vector2i(9, 21), Vector2i(13, 21), Vector2i(6, 24), Vector2i(11, 24),
]
## 桂花林这一片不长别的树
const GROVE_AREA: Array[int] = [3, 13, 15, 26]
## 山顶湖：圆心和两个半径（格）
const LAKE_CENTER := Vector2(35.0, 19.0)
const LAKE_RADIUS := Vector2(6.2, 4.6)
## 起雾的日子岚站在哪
const LAN_TILE := Vector2i(25, 11)
## 山门的两根石柱。台阶本身（21、22 列）留着走
const GATE_POSTS: Array[Vector2i] = [Vector2i(20, 16), Vector2i(23, 16)]
## 学堂 [x0, 门前那一行, 宽, 深]。在古祠东边、湖路北边
const SCHOOL: Array[int] = [29, 9, 4, 3]
## 学堂东墙根的一张空格纸。山里人站在门前，不占这格。匾上仍然没有字。
const SCHOOL_PAPER := Vector2i(33, 8)
const LAN_DIALOGUE := "res://dialogue/lan.dialogue"
## 和岚说过话没有；这一天说过没有（进存档的只有前一个）
const LAN_TALKED := &"lan_talked"

## 哪一天已经和岚说过话（只在这一局里记着）
static var _talk_day := -1

var _lan: Sprite2D
var _lan_frames: Array[Texture2D] = []
var _lan_time := 0.0


func _ready() -> void:
	map_id = &"shanci"
	_rng.seed = 20261122
	_scatter_cols = OLD_W
	_scatter_rows = OLD_H
	_setup_wild(W, H)
	_layout()
	_layout_new()
	_build_ground()
	_make_entities()
	_place_objects()
	_place_new()
	Foraging.settle(map_id, _forage_tiles(false), _forage_tiles(true))
	Foraging.changed.connect(_sync_forage)
	_sync_forage()
	_make_water_fx(60)
	_spawn_npcs()
	_sync_lan()


func _exit_tree() -> void:
	super._exit_tree()
	if Foraging.changed.is_connected(_sync_forage):
		Foraging.changed.disconnect(_sync_forage)


func _process(delta: float) -> void:
	super._process(delta)
	_sync_lan()
	if _lan != null:
		_lan_time += delta
		_lan.texture = _lan_frames[1] if fmod(_lan_time, 3.2) > 2.8 else _lan_frames[0]


func spawn_position(spawn: StringName) -> Vector2:
	if spawn == &"from_houshan":
		return tile_center(Vector2i(17, 2))
	return tile_center(Vector2i(STEP_COLS[0], H - 2)) + Vector2(8, 0)


func spawn_facing(spawn: StringName) -> Facing:
	return Facing.DOWN if spawn == &"from_houshan" else Facing.UP


func trigger_at(tile: Vector2i) -> Dictionary:
	if tile.y == H - 1 and STEP_COLS.has(tile.x):
		return {"map": &"pasture", "spawn": &"from_shanci"}
	if tile.y == 0 and (tile.x == 17 or tile.x == 18):
		return {"map": &"houshan", "spawn": &"slope"}
	return {}


## 山顶湖是湖水。
func fishing_water(tile: Vector2i) -> StringName:
	return &"lake" if _is_water(tile) else &""


## 岚只在起雾的日子出来。散雾以后它不在了；归名以后它天天都在。
func lan_here() -> bool:
	match Story.ending():
		Story.CLEAR:
			return false
		Story.NAME:
			return true
	return Weather.is_foggy()


func _tile_blocked(t: Vector2i) -> bool:
	return super._tile_blocked(t) or (_lan != null and t == LAN_TILE)


func query_use(item: ItemDef, tile: Vector2i, _facing: Facing) -> StringName:
	if npc_at(tile) != null or _at_shrine(tile) or RACK_TILES.has(tile) or _grove_at(tile) or (_lan != null and tile == LAN_TILE) or _at_school(tile) or _at_gate(tile) or tile == SCHOOL_PAPER or clues.has(tile):
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
			if _lan != null and tile == LAN_TILE:
				_talk_to_lan()
			elif _at_shrine(tile):
				if Story.ending() == Story.CLEAR:
					EventBus.banner_requested.emit("古祠。门里黑着，供桌上的香炉是冷的。\n祠前的石板上有一小块地方是干净的，落叶和雪都不往上落")
				elif Story.ending() == Story.NAME:
					EventBus.banner_requested.emit("古祠。供桌上的香炉里有人新插了香。门楣的匾上是两个字：青岚")
				elif lan_here():
					EventBus.banner_requested.emit("古祠。门里黑着，供桌上的香炉是冷的。门楣上的匾空着，一个字也没有")
				else:
					EventBus.banner_requested.emit("古祠。门里黑着，供桌上的香炉是冷的。门楣上的匾空着，一个字也没有。\n台阶上有几个蹄印，是湿的")
			elif RACK_TILES.has(tile):
				EventBus.banner_requested.emit("檐下的木架上挂满了祈愿的木牌，字都没了，风一吹互相碰着响。\n有一根红绳是断的，底下空着一块牌的位置")
			elif _grove_at(tile):
				EventBus.banner_requested.emit(_grove_text())
			elif _at_school(tile):
				EventBus.banner_requested.emit("学堂。门洞是暗的，里面一块板，一个字也没有。门口两张小凳")
			elif tile == SCHOOL_PAPER:
				GameState.set_flag(&"read_school_paper")
				EventBus.banner_requested.emit(clue_at(tile))
			elif _at_gate(tile):
				EventBus.banner_requested.emit("山门。两根石柱夹着上台阶的路，中间的匾是空的")
			elif clues.has(tile):
				EventBus.banner_requested.emit(clues[tile])
		&"harvest":
			_pick_forage(tile)


func _at_shrine(tile: Vector2i) -> bool:
	return tile.y == SHRINE[3] and tile.x >= SHRINE[0] and tile.x <= SHRINE[2]


func clue_at(tile: Vector2i) -> String:
	if clues.has(tile):
		return clues[tile]
	if tile == SCHOOL_PAPER:
		return "学堂东墙根压着一张纸。格子画好了，一个字也没写。"
	return ""


func _at_school(tile: Vector2i) -> bool:
	return tile.y == SCHOOL[1] - 1 and tile.x >= SCHOOL[0] and tile.x < SCHOOL[0] + SCHOOL[2]


func _at_gate(tile: Vector2i) -> bool:
	if GATE_POSTS.has(tile):
		return true
	return tile.y == GATE_POSTS[0].y and STEP_COLS.has(tile.x)


func _grove_at(tile: Vector2i) -> bool:
	return GROVE.has(tile)


func _grove_text() -> String:
	match _season:
		2:
			return "桂花树。满树碎金，香得人站着不想走"
		3:
			return "桂花树。叶子上压着雪，还是绿的"
	return "桂花树。还没到开花的时候，叶子绿得发黑"


## 和岚说话：头一回、每天头一回、当天再说，各一段。
func _talk_to_lan() -> void:
	var title := "again"
	if Story.ending() == Story.NAME:
		title = "named" if _talk_day != GameClock.day else "named_again"
	elif not GameState.has_flag(LAN_TALKED):
		title = "first"
	elif _talk_day != GameClock.day:
		title = "daily"
	_talk_day = GameClock.day
	EventBus.dialogue_requested.emit(LAN_DIALOGUE, title)


func _sync_lan() -> void:
	var want := lan_here()
	if want == (_lan != null):
		return
	if want:
		if _lan_frames.is_empty():
			_lan_frames = [Px.tex(ShrineArt.deer(0)), Px.tex(ShrineArt.deer(1))]
		_lan = _sprite(_lan_frames[0], tile_center(LAN_TILE) + Vector2(0, 7), Vector2(-25, -45))
		_lan.flip_h = true
	else:
		var gone := _lan
		_lan = null
		var tw := create_tween()
		tw.tween_property(gone, "modulate:a", 0.0, 1.2)
		tw.tween_callback(gone.queue_free)


# ---------------------------------------------------------------- 布局

func _in_lake(t: Vector2i) -> bool:
	var d := (Vector2(t) + Vector2(0.5, 0.5) - LAKE_CENTER) / LAKE_RADIUS
	return d.length_squared() <= 1.0 + sin(t.x * 0.9 + t.y * 0.6) * 0.12


func _layout() -> void:
	for y in OLD_H:
		for x in OLD_W:
			if _in_lake(Vector2i(x, y)):
				_set_water(Vector2i(x, y))
	# 上山的石阶和祠前的石板地
	_fill(STEP_COLS[0], COURT[3] + 1, STEP_COLS[1], OLD_H - 1, PAVE)
	_fill(COURT[0], COURT[1], COURT[2], COURT[3], PAVE)
	# 从石板地到湖边、到桂花林各踩出一条土路。祠西再往上是后山。
	_fill(COURT[2] + 1, 12, 32, 13, DIRT)
	_fill(17, 0, 18, COURT[1] - 1, DIRT)
	_fill(12, 12, COURT[0] - 1, 13, DIRT)
	_fill(30, SCHOOL[1], 31, 12, DIRT)


## 采集物长在能走到的空草地；shore 为真时只要紧挨着湖水的。
func _forage_tiles(shore: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(3, OLD_H - 2):
		for x in range(2, OLD_W - 2):
			var t := Vector2i(x, y)
			if not _is_free(t):
				continue
			if _next_to_water(t) == shore:
				out.append(t)
	return out


func _place_objects() -> void:
	# 古祠
	var shrine_pos := Vector2((SHRINE[0] + SHRINE[2] + 1) * TS / 2.0, (SHRINE[3] + 1) * TS)
	_sprite(Px.tex(ShrineArt.shrine()), shrine_pos, Vector2(-44, -80))
	_ground_shadow(shrine_pos + Vector2(0, -1), Px.tex(PixelArt.shadow(80, 9, 0.25)))
	_block_rect(SHRINE[0], SHRINE[1], SHRINE[2], SHRINE[3])

	# 山门夹在石阶两边，人从中间的两格走上去
	var gate_pos := Vector2(22 * TS, (GATE_POSTS[0].y + 1) * TS)
	_prop("mountain_gate", gate_pos)
	_ground_shadow(gate_pos + Vector2(0, -1), Px.tex(PixelArt.shadow(36, 6, 0.2)))
	for post: Vector2i in GATE_POSTS:
		_block(post)

	# 学堂
	var school_pos := Vector2((SCHOOL[0] + SCHOOL[2] / 2.0) * TS, SCHOOL[1] * TS)
	_prop("schoolhouse", school_pos)
	_ground_shadow(school_pos + Vector2(0, -1), Px.tex(PixelArt.shadow(SCHOOL[2] * TS - 4, 8, 0.22)))
	_block_rect(SCHOOL[0], SCHOOL[1] - SCHOOL[3], SCHOOL[0] + SCHOOL[2] - 1, SCHOOL[1] - 1)
	_hang_clue(SCHOOL_PAPER, PlaceClueArt.slip(), 6.0)

	# 挂祈愿牌的木架
	var rack_pos := Vector2((RACK_TILES[0].x + 1) * TS, (RACK_TILES[0].y + 1) * TS - 2)
	_sprite(Px.tex(ShrineArt.plaque_rack()), rack_pos, Vector2(-18, -26))
	_ground_shadow(rack_pos + Vector2(0, -1), Px.tex(PixelArt.shadow(30, 5, 0.2)))
	for t in RACK_TILES:
		_block(t)

	# 桂花林
	var tree_tex := Px.tex(ShrineArt.osmanthus(_season))
	for t in GROVE:
		var pos := tile_center(t) + Vector2(0, 6)
		var s := _sprite(tree_tex, pos, Vector2(-20, -50))
		s.material = _tree_mat
		_ground_shadow(pos + Vector2(0, -1), Px.tex(PixelArt.shadow(26, 7, 0.22)))
		_block(t)
	# 秋天飘桂花，别的季节桂花林安安静静
	var falling := FieldMotion.fall_kind(GameClock.season(), true)
	if falling != &"":
		var homes: Array = []
		for t: Vector2i in GROVE:
			homes.append(tile_center(t) + Vector2(0, -20))
		_add_falling(falling, homes, 3)

	# 湖边的石头
	for t: Vector2i in [Vector2i(29, 16), Vector2i(31, 24), Vector2i(40, 23)]:
		if _is_free(t):
			var rp := tile_center(t) + Vector2(0, 6)
			_prop("rock_%d" % (t.x % 2), rp)
			_ground_shadow(rp + Vector2(0, -1), _small_shadow)
			_block(t)

	_reserve(STEP_COLS[0] - 2, COURT[3] + 1, STEP_COLS[1] + 2, OLD_H - 1)
	_reserve(19, 15, 24, 17)
	_reserve(COURT[0] - 1, SHRINE[1] - 2, COURT[2] + 1, COURT[3] + 1)
	_reserve(SCHOOL[0] - 1, SCHOOL[1] - SCHOOL[3], SCHOOL[0] + SCHOOL[2], 13)
	_reserve(GROVE_AREA[0], GROVE_AREA[1], GROVE_AREA[2], GROVE_AREA[3])
	_scatter_trees(26)
	_scatter_bushes(16)
	_scatter_tufts(300)
	_release_ghosts()


# ---------------------------------------------------------------- 往东、往南扩出来的部分

func _ghost_tree(t: Vector2i) -> bool:
	return _legacy_edge(t, OLD_W, OLD_H)


func _layout_new() -> void:
	# 石阶一直通到新的南边缘，半山交成十字
	_fill(STEP_COLS[0], OLD_H, STEP_COLS[1], H - 1, PAVE)
	_fill(3, CROSS_ROWS[0], 70, CROSS_ROWS[1], DIRT)
	_fill(NORTH_COLS[0], 14, NORTH_COLS[1], CROSS_ROWS[0] - 1, DIRT)
	_lake(Vector2(63, 28), 6.0, 3.8, 0.3, 7741)


func _place_new() -> void:
	_new_edge_trees(OLD_W, OLD_H, NEW_TREES)
	# 十字路口东边：凉亭、土地祠、守山人的屋子
	_building("pavilion", 28, 37, 3, 2, false)
	_wall_clue(28, 37, 3, "山腰的凉亭。栏杆上的漆掉光了，坐凳上却一点灰也没有")
	_building("earth_shrine", 40, 37, 2, 2, false)
	_wall_clue(40, 37, 2, "小小的土地祠。香炉里插着三根没点的香")
	_building("house", 48, 37, 4, 3, true)
	_wall_clue(48, 37, 4, "山脚人家。窗台上晾着一排干桂花")
	_wide_prop("bench", Vector2i(59, 36), 2, "长凳朝着山顶湖那边，凳面上落着一片叶子")
	# 十字路口西边：柴垛、竹匾、桂花林的边
	_wide_prop("wood_pile", Vector2i(10, 36), 2, "劈好的柴，码得和祠前的香案一样齐")
	_wide_prop("drying_rack", Vector2i(14, 36), 2, "竹匾里晒着桂花，一半是黄的，一半是白的")
	_small_prop("jar_clay", Vector2i(8, 37), "装桂花的坛子，封口的纸上写着年份，墨迹已经淡了")
	# 北边的小路尽头：石牌坊的位置换成一块立着的石头
	_small_prop("rock_1", Vector2i(54, 13), "路尽头立着一块石头，上面的字被苔藓盖住了")
	for t: Vector2i in [Vector2i(19, 33), Vector2i(24, 33), Vector2i(19, 43), Vector2i(24, 43), Vector2i(19, 36), Vector2i(24, 36)]:
		if _is_free(t):
			_lamp_post(t)
	for t: Vector2i in [Vector2i(58, 31), Vector2i(68, 31), Vector2i(66, 25), Vector2i(59, 25)]:
		if _is_free(t) and not _is_water(t):
			_tree("pine%d" % (t.x % 2), t)
	for t: Vector2i in [Vector2i(52, 30), Vector2i(72, 34)]:
		if _is_free(t):
			_small_prop("rock_%d" % (t.x % 2), t)
	_grove(Rect2i(OLD_W, 0, W - OLD_W, 30), 20, NEW_TREES)
	_grove(Rect2i(0, OLD_H, W, H - OLD_H), 24, NEW_TREES)
	_sprinkle_grass(Rect2i(OLD_W, 0, W - OLD_W, OLD_H), 61)
	_sprinkle_grass(Rect2i(0, OLD_H, W, H - OLD_H), 62)
