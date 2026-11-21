extends WildMap
## 南溪：镇子南边的一条溪。从镇上的南街走过来，路到溪边就断了，
## 岸边是老周的小码头和一盏没亮的河灯。溪里能钓，岸上长野菜。

## 老地图是左上角 40×30；往东、往南扩到 72×48，老坐标一格不动（决策 150）。
const OLD_W := 40
const OLD_H := 30
const W := 72
const H := 48
## 北岸东头的栈桥：从岸上伸进东边那个大潭
const PIER_X := 60
## 新长出的树
const NEW_TREES: Array[String] = ["round0", "round1", "round2", "willow0", "round0", "willow1"]
## 南岸新区的名字：过了青竹父亲那座桥才走得过去
const SOUTH_BANK := Rect2i(0, 30, W, H - 30)
## 从镇上下来的路占的两列
const ROAD_COLS: Array[int] = [19, 20]
## 路从北边进来，走到这一行就到了溪边的空地
const ROAD_END := 13
## 码头的木板：从岸边伸进水里
const DOCK_TILES: Array[Vector2i] = [Vector2i(19, 15), Vector2i(20, 15), Vector2i(19, 16), Vector2i(20, 16)]
## 河灯
const LAMP_TILE := Vector2i(23, 13)
const LAMP_ID := &"river"
## 小船系在码头东侧；对着这两格按使用键上船
## 船系在码头西侧，站在码头上朝西按一下就能坐
const BOAT_POS := Vector2(17 * TS + 16, 16 * TS + 4)
const BOAT_TILES: Array[Vector2i] = [Vector2i(17, 16), Vector2i(18, 16)]
## 老周说过潭底沉着一盏灯以后，码头两侧的深水里能钓起它
const SUNKEN_X := Vector2i(15, 25)
const SUNKEN_RELIC := &"river_lantern"
const HINT_FLAG := &"lantern_hint"
const FOUND_FLAG := &"lantern_found"

## 河灯漂在这一行水面上，从西漂到东（像素）
const DRIFT_Y := 18 * TS + 8
const DRIFT_X := Vector2(7 * TS, 29 * TS)
## 一盏河灯从这头漂到那头要多少秒
const DRIFT_SECONDS := 46.0
## 萤火虫可以停在这片草地上（格子范围），彼此至少隔这么多格
const MEADOW := Rect2i(4, 3, 31, 10)
const FIREFLY_GAP := 3

var _lamp_sprite: Sprite2D
## 水面上漂着的河灯，和它们的两帧贴图
var _river_lanterns: Array[Sprite2D] = []
var _lantern_tex: Array[Texture2D] = []
## 草地上飞着的萤火虫：格子 -> 精灵
var _fireflies: Dictionary[Vector2i, Sprite2D] = {}
var _firefly_tex: Array[Texture2D] = []
var _festival_t := 0.0


func _ready() -> void:
	map_id = &"nanxi"
	_rng.seed = 20261113
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
	Foraging.settle(map_id, _forage_tiles(false), _forage_tiles(true))
	Foraging.changed.connect(_sync_forage)
	_sync_forage()
	Fishing.changed.connect(_sync_traps)
	_sync_traps()
	_make_water_fx(60)
	_spawn_npcs()


func _process(delta: float) -> void:
	super._process(delta)
	_festival_t += delta
	if _festival_t >= 0.25:
		_festival_t = 0.0
		_sync_festival()
	_move_festival()


func _exit_tree() -> void:
	super._exit_tree()
	if Foraging.changed.is_connected(_sync_forage):
		Foraging.changed.disconnect(_sync_forage)
	if Fishing.changed.is_connected(_sync_traps):
		Fishing.changed.disconnect(_sync_traps)


func spawn_position(spawn: StringName) -> Vector2:
	if spawn == &"from_town":
		return tile_center(Vector2i(ROAD_COLS[0], 1)) + Vector2(8, 4)
	if spawn == &"from_boat":
		return tile_center(Vector2i(19, 16)) + Vector2(0, 2)
	return tile_center(Vector2i(ROAD_COLS[0], ROAD_END - 1)) + Vector2(8, 0)


func spawn_facing(spawn: StringName) -> Facing:
	return Facing.LEFT if spawn == &"from_boat" else Facing.DOWN


func trigger_at(tile: Vector2i) -> Dictionary:
	if tile.y == 0 and ROAD_COLS.has(tile.x):
		return {"map": &"town", "spawn": &"from_nanxi"}
	return {}


## 溪里全是溪水；码头的木板不算水。
func fishing_water(tile: Vector2i) -> StringName:
	if not _is_water(tile) or DOCK_TILES.has(tile) or planks.has(tile) or _bridge_tiles().has(tile):
		return &""
	return &"stream"


func query_use(item: ItemDef, tile: Vector2i, _facing: Facing) -> StringName:
	if npc_at(tile) != null or tile == LAMP_TILE or BOAT_TILES.has(tile) or _fireflies.has(tile) or clue_at(tile) != "":
		return &"interact"
	if Foraging.item_at(map_id, tile) != &"":
		return &"harvest"
	if _bridge_tiles().has(tile) and PeopleLine.mark(&"qingzhu") != "":
		return &"interact"
	var trap := _trap_query(item, tile)
	if trap != &"":
		return trap
	if item != null and item.id == &"rod" and fishing_water(tile) != &"":
		return &"cast"
	return &""


func perform(action: StringName, item: ItemDef, tile: Vector2i, _quiet: bool = false) -> void:
	match action:
		&"interact":
			if _talk_at(tile) or _trap_perform(action, tile):
				return
			if _fireflies.has(tile):
				_catch_firefly(tile)
			elif tile == LAMP_TILE:
				if Lamps.is_lit(LAMP_ID):
					EventBus.banner_requested.emit("河灯。火光照在水上，碎成一片")
				else:
					EventBus.lamp_requested.emit(LAMP_ID)
			elif BOAT_TILES.has(tile):
				_use_boat()
			elif _bridge_tiles().has(tile) and PeopleLine.mark(&"qingzhu") != "":
				EventBus.banner_requested.emit(PeopleLine.mark(&"qingzhu"))
			elif clue_at(tile) != "":
				EventBus.banner_requested.emit(clue_at(tile))
		&"harvest":
			_pick_forage(tile)
		&"place_trap":
			_trap_perform(action, tile, item)


## 老周的船：河灯亮了以后能坐它去河岸。
func _use_boat() -> void:
	if not Lamps.is_lit(LAMP_ID):
		EventBus.banner_requested.emit("老周的船。桨收着，船头对着下游的雾")
		return
	SceneRouter.travel(&"riverbank", &"from_boat")


## 老周提过以后，码头两侧的深潭底下沉着那盏灯；钓上来以前一直在。
func sunken_relic(tile: Vector2i) -> StringName:
	if not GameState.has_flag(HINT_FLAG) or GameState.has_flag(StringName("relic_" + String(SUNKEN_RELIC))):
		return &""
	if fishing_water(tile) == &"" or tile.x < SUNKEN_X.x or tile.x > SUNKEN_X.y:
		return &""
	return SUNKEN_RELIC


## 钓起河底的灯盏：老周在码头上的话走过来说几句。
func relic_fished(relic_id: StringName) -> void:
	if relic_id != SUNKEN_RELIC or GameState.has_flag(FOUND_FLAG):
		return
	var npc := _npc_of(&"laozhou")
	if npc == null or player == null:
		return
	_approach(npc, "lantern_found")


# ---------------------------------------------------------------- 节日

## 节日开着的时候把水面上的河灯、草地上的萤火虫对一遍；萤火虫放掉以后，叫忆最深的那位居民走过来说话。
func _sync_festival() -> void:
	var lanterns := 0
	if Festivals.is_open(&"lantern"):
		# 到了场的居民里今年放灯的，加上玩家自己那一盏
		for id in Festivals.floaters():
			if _npc_of(id) != null and not _npc_of(id).is_walking():
				lanterns += 1
		if Festivals.done("float"):
			lanterns += 1
	while _river_lanterns.size() > lanterns:
		var gone: Sprite2D = _river_lanterns.pop_back()
		gone.queue_free()
	while _river_lanterns.size() < lanterns:
		_river_lanterns.append(_make_river_lantern())
	var want: Array[Vector2i] = []
	var left := Festivals.fireflies_left()
	if left > 0:
		var homes := firefly_homes()
		want = homes.slice(homes.size() - mini(left, homes.size()))
	for t: Vector2i in _fireflies.keys():
		if not want.has(t):
			_fireflies[t].queue_free()
			_fireflies.erase(t)
	for t in want:
		if not _fireflies.has(t):
			_fireflies[t] = _make_firefly(t)
	if Festivals.heart_due() and GameClock.running and not cutscene and player != null:
		var who := _npc_of(Festivals.heart_npc())
		if who != null and not who.is_walking():
			Festivals.heart_told()
			_approach(who, "fest_firefly_heart_%s" % who.def.id, Festivals.DIALOGUE)


## 河灯顺水漂，萤火虫在自己那一格上头打转。
func _move_festival() -> void:
	for i in _river_lanterns.size():
		var s := _river_lanterns[i]
		var k := fmod(_time / DRIFT_SECONDS + float(i) * 0.137, 1.0)
		s.position = Vector2(lerpf(DRIFT_X.x, DRIFT_X.y, k), DRIFT_Y + (i % 3 - 1) * 5 + roundf(sin(_time * 1.1 + i) * 1.5))
		s.modulate.a = clampf(minf(k, 1.0 - k) * 12.0, 0.0, 1.0)
		s.texture = _lantern_tex[int(_time * 3.0 + i) % 2]
	for t: Vector2i in _fireflies:
		var s := _fireflies[t]
		var seed_t := float(t.x * 7 + t.y * 13)
		s.position = tile_center(t) + Vector2(roundf(sin(_time * 0.9 + seed_t) * 4.0), -10.0 + roundf(cos(_time * 1.3 + seed_t) * 3.0))
		s.texture = _firefly_tex[0 if fmod(_time * 1.6 + seed_t, 2.0) < 1.3 else 1]


func _make_river_lantern() -> Sprite2D:
	if _lantern_tex.is_empty():
		_lantern_tex = [Px.tex(FestivalArt.river_lantern(0)), Px.tex(FestivalArt.river_lantern(1))]
	var s := Sprite2D.new()
	s.texture = _lantern_tex[0]
	s.offset = Vector2(0, -3)
	s.z_index = -7
	add_child(s)
	# 灯太多画面会吃不消：前六盏带一圈光，别的只有火苗
	if _river_lanterns.size() < 6:
		s.add_child(_glow(0.7, Color(1.0, 0.8, 0.45), 0.8))
	return s


func _make_firefly(t: Vector2i) -> Sprite2D:
	if _firefly_tex.is_empty():
		_firefly_tex = [Px.tex(FestivalArt.firefly(0)), Px.tex(FestivalArt.firefly(1))]
	var s := Sprite2D.new()
	s.texture = _firefly_tex[0]
	s.z_index = 4
	s.position = tile_center(t) + Vector2(0, -10)
	add_child(s)
	s.add_child(_glow(0.4, Color(0.8, 1.0, 0.45), 0.9))
	return s


## 今晚萤火虫停的格子：草地上能走到、没有人站的空地，每天换一批。捉掉的从前面数起。
func firefly_homes() -> Array[Vector2i]:
	var def := Database.festival(&"firefly")
	var taken: Array[Vector2i] = []
	if def != null:
		taken.append(def.host_tile)
		taken.append_array(def.crowd)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7700 + GameClock.day
	var out: Array[Vector2i] = []
	var tries := 0
	while out.size() < Festivals.FIREFLY_TOTAL and tries < 600:
		tries += 1
		var t := Vector2i(rng.randi_range(MEADOW.position.x, MEADOW.end.x - 1), rng.randi_range(MEADOW.position.y, MEADOW.end.y - 1))
		if not _walkable(t) or _is_water(t) or ROAD_COLS.has(t.x) or taken.has(t):
			continue
		var ok := true
		for o in out:
			if absi(o.x - t.x) + absi(o.y - t.y) < FIREFLY_GAP:
				ok = false
		for o in taken:
			if absi(o.x - t.x) + absi(o.y - t.y) < 2:
				ok = false
		if ok:
			out.append(t)
	return out


func _catch_firefly(tile: Vector2i) -> void:
	if not Festivals.catch_firefly():
		return
	var s := _fireflies[tile]
	Fx.burst(self, s.position, Color(0.85, 1.0, 0.5, 0.9), 8, 26.0, 0.5, -8.0)
	s.queue_free()
	_fireflies.erase(tile)
	Audio.play("harvest", 0.0, -6.0)
	var n := Festivals.caught()
	if n == Festivals.FIREFLY_GOAL:
		EventBus.banner_requested.emit("捉到 %d 只了，拢在手心里一闪一闪\n够了。去找小满，她说要一起放" % n)
	elif n < Festivals.FIREFLY_GOAL:
		EventBus.banner_requested.emit("捉到一只萤火虫（%d / %d）" % [n, Festivals.FIREFLY_GOAL])
	else:
		EventBus.banner_requested.emit("又捉到一只（%d 只）" % n)


## 过场：居民走到玩家身边，面对面说一段。走不过去就站在原地说。file 不写就是这位居民自己的对话文件。
func _approach(npc: Npc, title: String, file: String = "") -> void:
	cutscene = true
	var me := tile_of(player.position)
	var goal := Vector2i(-1, -1)
	var best := 9999
	for side: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var t := me + side
		if in_map(t) and _walkable(t) and not _occupied_by_someone(t, npc):
			var d := absi(t.x - npc.tile().x) + absi(t.y - npc.tile().y)
			if d < best:
				best = d
				goal = t
	# 节日的时候草地上站着人：绕开他们走，不然半路被挡住会折回原位
	var free := func(t: Vector2i) -> bool: return _walkable(t) and not _occupied_by_someone(t, npc)
	var path: Array[Vector2i] = []
	if goal.x >= 0:
		path = GridPath.find(npc.tile(), goal, free, Rect2i(0, 0, cols, rows))
	if not path.is_empty():
		npc.walk(path, Facing.DOWN)
		await npc.arrived
		if not is_inside_tree():
			return
	npc.face_toward(player.position)
	var toward := npc.position - player.position
	var facing := Facing.DOWN
	if absf(toward.x) >= absf(toward.y):
		facing = Facing.LEFT if toward.x < 0 else Facing.RIGHT
	elif toward.y < 0:
		facing = Facing.UP
	if player.has_method(&"place"):
		player.call(&"place", player.position, facing)
	cutscene = false
	EventBus.dialogue_requested.emit(file if file != "" else Residents.dialogue_path(npc.def.id), title)


## 灯亮了：换成亮着的样子，晚上发光。
func on_lamp_lit(lamp_id: StringName) -> void:
	if lamp_id != LAMP_ID:
		return
	_show_lamp_lit()
	var top := _lamp_sprite.position + Vector2(0, -18)
	Fx.burst(self, top, Color(1.0, 0.85, 0.45, 0.95), 18, 40.0, 0.7, 20.0)
	Fx.burst(self, top, Color(1.0, 0.6, 0.25, 0.8), 10, 24.0, 0.9, 12.0)


func lamp_focus(lamp_id: StringName) -> Vector2:
	if lamp_id == LAMP_ID and _lamp_sprite != null:
		return _lamp_sprite.global_position
	return Vector2.INF


func _show_lamp_lit() -> void:
	_add_night_light(_lamp_sprite.position + Vector2(0, -16), 2.0)


# ---------------------------------------------------------------- 布局

## 青竹父亲那座桥：西边水面窄的两列，整段跨过去。
func _bridge_tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in [8, 9]:
		var cy := _stream_y(x)
		var half := _stream_half(x)
		for y in range(cy - half, cy + half + 1):
			out.append(Vector2i(x, y))
	return out


## 溪在这一列的中心行：从西往东缓缓弯
func _stream_y(x: int) -> int:
	return 18 + int(roundf(sin(x * 0.23 + 0.6) * 1.6))


## 溪在这一列有多宽（半宽）：码头附近宽成一个潭
func _stream_half(x: int) -> int:
	if x >= 15 and x <= 25:
		return 2
	if x >= 58 and x <= 64:
		return 4
	if x >= 56 and x <= 66:
		return 3
	return 1


func _layout() -> void:
	_fill(ROAD_COLS[0], 0, ROAD_COLS[1], ROAD_END, DIRT)
	_fill(16, ROAD_END - 2, 23, ROAD_END, DIRT)
	for x in W:
		var cy := _stream_y(x)
		var half := _stream_half(x)
		for y in range(cy - half, cy + half + 1):
			_set_water(Vector2i(x, y))
	# 码头的木板架在水上，人能走
	for t in DOCK_TILES:
		solid[idx(t)] = 0
	# 青竹忆到五级：西边窄水面铺上她父亲那座桥
	if Residents.memory_level(&"qingzhu") >= 5:
		for t in _bridge_tiles():
			solid[idx(t)] = 0


## 采集物可以落在哪些格子：溪北岸能走到的空草地。shore 为真时只要紧挨着水的。
func _forage_tiles(shore: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(3, OLD_H - 2):
		for x in range(2, OLD_W - 2):
			var t := Vector2i(x, y)
			if not _is_free(t) or y > _stream_y(x) + _stream_half(x):
				continue
			if absi(x - ROAD_COLS[0]) <= 1 and y <= 3:
				continue
			if _next_to_water(t) == shore:
				out.append(t)
	return out


func _place_objects() -> void:
	if Residents.memory_level(&"qingzhu") >= 5:
		var tiles := _bridge_tiles()
		var mid: Vector2i = tiles[tiles.size() / 2]
		_prop("bridge", tile_center(mid))
	# 码头：木板、水里的桩、系着的船
	for t in DOCK_TILES:
		var m := 0
		if DOCK_TILES.has(t + Vector2i(0, -1)) or not _is_water(t + Vector2i(0, -1)):
			m |= 1
		if DOCK_TILES.has(t + Vector2i(1, 0)):
			m |= 2
		if DOCK_TILES.has(t + Vector2i(0, 1)):
			m |= 4
		if DOCK_TILES.has(t + Vector2i(-1, 0)):
			m |= 8
		var plank := Sprite2D.new()
		plank.texture = Px.tex(PixelArt.dock_tile(m))
		plank.centered = false
		plank.position = Vector2(t.x * TS, t.y * TS)
		plank.z_index = -7
		add_child(plank)
		occupied[t] = true
	var post_tex := Px.tex(PixelArt.dock_post())
	for p: Vector2 in [Vector2(19 * TS + 1, 17 * TS - 2), Vector2(21 * TS - 5, 17 * TS - 2)]:
		var post := Sprite2D.new()
		post.texture = post_tex
		post.centered = false
		post.position = p
		post.z_index = -7
		add_child(post)
	var boat := _sprite(Px.tex(PixelArt.boat()), BOAT_POS, Vector2(-16, -10))
	boat.z_index = -7
	for t in BOAT_TILES:
		occupied[t] = true

	# 河灯：溪边一盏石灯
	var lamp_pos := tile_center(LAMP_TILE) + Vector2(0, 6)
	_lamp_sprite = _prop("stone_lamp", lamp_pos)
	_ground_shadow(lamp_pos + Vector2(0, -1), Px.tex(PixelArt.shadow(16, 5, 0.22)))
	_block(LAMP_TILE)
	if Lamps.is_lit(LAMP_ID):
		_show_lamp_lit()

	# 岸边几块石头
	for t: Vector2i in [Vector2i(14, 15), Vector2i(27, 14), Vector2i(9, 16)]:
		if _is_free(t):
			var pos := tile_center(t) + Vector2(0, 6)
			_prop("rock_%d" % (t.x % 2), pos)
			_ground_shadow(pos + Vector2(0, -1), _small_shadow)
			_block(t)

	_reserve(ROAD_COLS[0] - 1, 0, ROAD_COLS[1] + 1, ROAD_END + 1)
	_reserve(15, ROAD_END - 3, 24, ROAD_END + 1)
	_scatter_trees(18)
	_scatter_bushes(22)
	_scatter_tufts(300)
	_release_ghosts()


# ---------------------------------------------------------------- 往东、往南扩出来的部分

func _ghost_tree(t: Vector2i) -> bool:
	return _legacy_edge(t, OLD_W, OLD_H)


## 新区的地形：北岸一条往东的土路通到栈桥；南岸从桥头往东南一条路。
## 老地图那一块不动（路都从老边界以外开始铺），老格子上的树留着，连得上靠随机碰运气以外的口子：东、南两排边界树放开了。
func _layout_new() -> void:
	_trail([Vector2i(OLD_W, 12), Vector2i(PIER_X + 1, 12)], 2, DIRT)
	_walk([Vector2i(PIER_X, 14), Vector2i(PIER_X, 19)], 2, DIRT, false)
	_trail([Vector2i(8, OLD_H), Vector2i(12, 34), Vector2i(26, 37), Vector2i(40, 38)], 2, DIRT)
	_trail([Vector2i(40, 38), Vector2i(50, 34), Vector2i(58, 31)], 2, DIRT)


func _spot(t: Vector2i) -> bool:
	return in_map(t) and _is_free(t) and not _is_water(t)


func _place_new() -> void:
	_new_edge_trees(OLD_W, OLD_H, NEW_TREES)
	# 北岸东段
	_building("boathouse", 46, 10, 5, 4, true)
	_wall_clue(46, 10, 5, "岸上的船屋。门闩上缠着一圈渔线，没锁")
	_wide_prop("drying_rack", Vector2i(52, 10), 2, "竹匾里晒着小鱼干，一条条头朝一个方向")
	_wide_prop("wood_pile", Vector2i(42, 10), 2, "劈好的柴，码得比人还齐")
	_wide_prop("bench", Vector2i(56, 13), 2, "长凳朝着潭面。坐的人不在，凳子还是温的")
	_lamp_post(Vector2i(59, 11))
	_lamp_post(Vector2i(62, 11))
	for t: Vector2i in [Vector2i(44, 14), Vector2i(50, 14), Vector2i(54, 14), Vector2i(66, 14), Vector2i(68, 15)]:
		if _spot(t):
			_tree("willow%d" % (t.x % 2), t)
	_small_prop("rock_0", Vector2i(63, 14), "潭边的石头，被水磨得滑溜溜的")
	_small_prop("rock_1", Vector2i(48, 15))
	# 栈桥尽头的告示
	_clue(Vector2i(PIER_X, 19), "栈桥一直伸到潭心。水是绿的，看不见底")
	_clue(Vector2i(PIER_X + 1, 19), "栈桥一直伸到潭心。水是绿的，看不见底")
	# 南岸：桥那边的人家和旧亭
	_building("pavilion", 22, 35, 3, 2, false)
	_wall_clue(22, 35, 3, "亭子的栏杆上刻着一排高低不一的线")
	_building("boathouse", 57, 30, 4, 3, true)
	_wall_clue(57, 30, 4, "南岸的船屋，门板被水泡得发白")
	_wide_prop("drying_rack", Vector2i(52, 36), 2, "竹匾空着。底下压着一张折了四折的网")
	_wide_prop("wood_pile", Vector2i(44, 41), 2)
	_building("well", 36, 43, 2, 2, false)
	_wall_clue(36, 43, 2, "井口封着一块石板，石板上压着一只空碗")
	for t: Vector2i in [Vector2i(11, 32), Vector2i(25, 39), Vector2i(41, 36)]:
		if _spot(t):
			_lamp_post(t)
	_small_prop("rock_0", Vector2i(30, 41), "石头缝里长着一小丛没见过的蕨")
	# 林子和草
	_grove(Rect2i(40, 0, 32, 9), 22, NEW_TREES)
	_grove(Rect2i(OLD_W, 14, 14, 3), 14, NEW_TREES)
	_grove(Rect2i(67, 9, 5, 22), 22, NEW_TREES)
	_grove(Rect2i(0, OLD_H, W, 5), 14, NEW_TREES)
	_grove(Rect2i(0, 40, W, 8), 22, NEW_TREES)
	_grove(Rect2i(62, 26, 10, 14), 18, NEW_TREES)
	_sprinkle_grass(Rect2i(OLD_W, 0, W - OLD_W, 30), 31)
	_sprinkle_grass(SOUTH_BANK, 32)
