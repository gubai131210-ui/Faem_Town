extends OutdoorMap
## 山祠：从北坡牧场顺着山路上来的山顶。山祠灯亮了以后才来得了。
## 石阶上去是一座古祠，檐下挂着祈愿的木牌；西边一片桂花林，东边是山顶湖（湖里的鱼都在这儿钓）。
## 起雾的日子，岚（一头白鹿）站在祠前。

const W := 44
const H := 30
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
	_setup_grid(W, H)
	_layout()
	_build_ground()
	_make_entities()
	_place_objects()
	Foraging.settle(map_id, _forage_tiles(false), _forage_tiles(true))
	Foraging.changed.connect(_sync_forage)
	_sync_forage()
	_make_water_fx(60)
	_spawn_npcs()
	_sync_lan()


func _exit_tree() -> void:
	if Foraging.changed.is_connected(_sync_forage):
		Foraging.changed.disconnect(_sync_forage)


func _process(delta: float) -> void:
	super._process(delta)
	_sync_lan()
	if _lan != null:
		_lan_time += delta
		_lan.texture = _lan_frames[1] if fmod(_lan_time, 3.2) > 2.8 else _lan_frames[0]


func spawn_position(_spawn: StringName) -> Vector2:
	return tile_center(Vector2i(STEP_COLS[0], H - 2)) + Vector2(8, 0)


func spawn_facing(_spawn: StringName) -> Facing:
	return Facing.UP


func trigger_at(tile: Vector2i) -> Dictionary:
	if tile.y == H - 1 and STEP_COLS.has(tile.x):
		return {"map": &"pasture", "spawn": &"from_shanci"}
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
	if npc_at(tile) != null or _at_shrine(tile) or RACK_TILES.has(tile) or _grove_at(tile) or (_lan != null and tile == LAN_TILE):
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
		&"harvest":
			_pick_forage(tile)


func _at_shrine(tile: Vector2i) -> bool:
	return tile.y == SHRINE[3] and tile.x >= SHRINE[0] and tile.x <= SHRINE[2]


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
	for y in H:
		for x in W:
			if _in_lake(Vector2i(x, y)):
				_set_water(Vector2i(x, y))
	# 上山的石阶和祠前的石板地
	_fill(STEP_COLS[0], COURT[3] + 1, STEP_COLS[1], H - 1, PAVE)
	_fill(COURT[0], COURT[1], COURT[2], COURT[3], PAVE)
	# 从石板地到湖边、到桂花林各踩出一条土路
	_fill(COURT[2] + 1, 12, 29, 13, DIRT)
	_fill(12, 12, COURT[0] - 1, 13, DIRT)


## 采集物长在能走到的空草地；shore 为真时只要紧挨着湖水的。
func _forage_tiles(shore: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(3, H - 2):
		for x in range(2, W - 2):
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

	# 湖边的石头
	for t: Vector2i in [Vector2i(29, 16), Vector2i(31, 24), Vector2i(40, 23)]:
		if _is_free(t):
			var rp := tile_center(t) + Vector2(0, 6)
			_prop("rock_%d" % (t.x % 2), rp)
			_ground_shadow(rp + Vector2(0, -1), _small_shadow)
			_block(t)

	_reserve(STEP_COLS[0] - 2, COURT[3] + 1, STEP_COLS[1] + 2, H - 1)
	_reserve(COURT[0] - 1, SHRINE[1] - 2, COURT[2] + 1, COURT[3] + 1)
	_reserve(GROVE_AREA[0], GROVE_AREA[1], GROVE_AREA[2], GROVE_AREA[3])
	_scatter_trees(26)
	_scatter_bushes(16)
	_scatter_tufts(300)
