extends OutdoorMap
## 镇广场：石板铺的广场和两条街，围着镇公所、药铺、茶馆、杂货铺、铁匠铺。
## 铺子没有室内：掌柜白天站在门口，和他们说话就能买东西。

const W := 46
const H := 30
## 往东出去是农场
const FARM_EXIT_ROWS: Array[int] = [18, 19]
const LAMP_TILE := Vector2i(22, 15)
const BOARD_TILES: Array[Vector2i] = [Vector2i(27, 8), Vector2i(28, 8)]
## 房子：[素材, 最西边那一列, 正面墙脚下面那一行, 占几格宽, 对着它按使用键时的说明]。房子占正面往北的五行。
const BUILDINGS: Array = [
	["town_hall", 19, 9, 7, "镇公所。门关着，里面有翻纸的声音"],
	["shop_herb", 6, 9, 5, "姜记药铺。门口晒着草药，闻着发苦"],
	["teahouse", 34, 9, 7, "云来茶馆。门口的菜牌擦了又写，写了又擦"],
	["shop_grocery", 6, 18, 5, "阿禾杂货铺。掌柜早上七点半到傍晚六点在门口"],
	["smithy", 35, 18, 5, "石叔铁匠铺。早上八点到傍晚五点半有人"],
]
## 通到地图边上的三条路：往北是矿井，往南是南溪，往西是北坡牧场。
const ROADS: Array[Rect2i] = [Rect2i(13, 0, 2, 9), Rect2i(22, 20, 2, 10), Rect2i(0, 18, 4, 2)]
## 北边和西边还被雾封着，只有居民走得过去。每项是 [路的范围, 雾封住的范围]
const FOG_ROADS: Array = [
	[Rect2i(13, 0, 2, 9), Rect2i(13, 0, 2, 2)],
	[Rect2i(0, 18, 4, 2), Rect2i(0, 18, 2, 2)],
]
## 往南出去是南溪：走到最南边那一行
const NANXI_EXIT_COLS: Array[int] = [22, 23]
## 长凳：每条占两格，这里记西边那一格
const BENCHES: Array[Vector2i] = [Vector2i(17, 12), Vector2i(26, 12)]
const LAMP_ID := &"plaza"
## 牧野灯：西街尽头路边的一盏石灯。点亮以后西边的雾散开，顺着路走到头是北坡牧场
const PASTURE_LAMP_TILE := Vector2i(3, 20)
const PASTURE_LAMP := &"pasture"
const PASTURE_EXIT_ROWS: Array[int] = [18, 19]
## FOG_ROADS 里西边那条路是第几项
const WEST_ROAD := 1
## FOG_ROADS 里北边那条路是第几项：顺着它走到头是沉灯井的井口
const NORTH_ROAD := 0
const WELL_EXIT_COLS: Array[int] = [13, 14]
## 井口灯：北边路口东侧的一盏石灯。点亮以后北边的雾散开，顺着路走到头是沉灯井
const WELL_LAMP_TILE := Vector2i(15, 7)
const WELL_LAMP := &"well"
## 牧野灯亮了以后对着北边的雾按过一下，被老秦喝住过
const WELL_WARNED := &"well_warned"
## 阿牧说过花花的铃丢在雾里以后，对着西边的雾能摸到它
const BELL_RELIC := &"cowbell"
const BELL_HINT := &"bell_hint"
const COMMON_DIALOGUE := "res://dialogue/common.dialogue"
## 第一次进镇时小满跑过来搭话；演过就记这个标记
const PROLOGUE_FLAG := &"prologue_town"
## 序幕里小满最多从这么多格外跑过来
const PROLOGUE_RUN := 12

var _lamp_sprite: Sprite2D
var _pasture_lamp_sprite: Sprite2D
var _well_lamp_sprite: Sprite2D
## 路的下标 -> 盖在路口的那几团雾
var _fog_puffs: Dictionary[int, Array] = {}
## 今天在广场上办的节日；没有是 null
var _festival: FestivalDef
## 除夕挂了几只灯笼
var _lanterns := 0


func _ready() -> void:
	map_id = &"town"
	_rng.seed = 20261112
	_setup_grid(W, H)
	_layout()
	_build_ground()
	_make_entities()
	_place_objects()
	_spawn_npcs()


func spawn_position(spawn: StringName) -> Vector2:
	if spawn == &"from_farm":
		return tile_center(Vector2i(W - 2, FARM_EXIT_ROWS[0])) + Vector2(0, 8)
	if spawn == &"from_nanxi":
		return tile_center(Vector2i(NANXI_EXIT_COLS[0], H - 2)) + Vector2(8, 0)
	if spawn == &"from_pasture":
		return tile_center(Vector2i(1, PASTURE_EXIT_ROWS[0])) + Vector2(0, 8)
	if spawn == &"from_wellhead":
		return tile_center(Vector2i(WELL_EXIT_COLS[0], 1)) + Vector2(8, 0)
	return tile_center(Vector2i(22, 18))


func spawn_facing(spawn: StringName) -> Facing:
	if spawn == &"from_farm":
		return Facing.LEFT
	if spawn == &"from_nanxi":
		return Facing.UP
	if spawn == &"from_pasture":
		return Facing.RIGHT
	return Facing.DOWN


func trigger_at(tile: Vector2i) -> Dictionary:
	if tile.x == W - 1 and FARM_EXIT_ROWS.has(tile.y):
		return {"map": &"farm", "spawn": &"from_town"}
	if tile.y == H - 1 and NANXI_EXIT_COLS.has(tile.x):
		return {"map": &"nanxi", "spawn": &"from_town"}
	if tile.x == 0 and PASTURE_EXIT_ROWS.has(tile.y) and not _west_closed():
		return {"map": &"pasture", "spawn": &"from_town"}
	if tile.y == 0 and WELL_EXIT_COLS.has(tile.x) and not _north_closed():
		return {"map": &"wellhead", "spawn": &"from_town"}
	return {}


func query_use(_item: ItemDef, tile: Vector2i, _facing: Facing) -> StringName:
	if npc_at(tile) != null or tile == LAMP_TILE or tile == PASTURE_LAMP_TILE or tile == WELL_LAMP_TILE or BOARD_TILES.has(tile) or _in_fog(tile) or _sign_at(tile) != "":
		return &"interact"
	if _festival != null and _festival.counter.has(tile):
		return &"interact"
	return &""


func perform(action: StringName, _item: ItemDef, tile: Vector2i, _quiet: bool = false) -> void:
	if action != &"interact" or _talk_at(tile):
		return
	if _festival != null and _festival.counter.has(tile):
		_use_counter()
	elif tile == LAMP_TILE:
		if Lamps.is_lit(LAMP_ID):
			EventBus.banner_requested.emit("广场灯。火苗很小，很稳，像一直就在那儿")
		else:
			EventBus.lamp_requested.emit(LAMP_ID)
	elif tile == PASTURE_LAMP_TILE:
		if Lamps.is_lit(PASTURE_LAMP):
			EventBus.banner_requested.emit("牧野灯。火苗朝着北坡那边歪，像在给谁指路")
		else:
			EventBus.lamp_requested.emit(PASTURE_LAMP)
	elif tile == WELL_LAMP_TILE:
		if Lamps.is_lit(WELL_LAMP):
			EventBus.banner_requested.emit("井口灯。火苗压得很低，风吹不动它")
		else:
			EventBus.lamp_requested.emit(WELL_LAMP)
	elif BOARD_TILES.has(tile):
		EventBus.board_requested.emit()
	elif _in_fog(tile):
		var west: Rect2i = FOG_ROADS[WEST_ROAD][1]
		var north: Rect2i = FOG_ROADS[NORTH_ROAD][1]
		if west.has_point(tile) and Lamps.is_lit(PASTURE_LAMP):
			EventBus.banner_requested.emit("大雪封山，北坡上不去")
		elif west.has_point(tile) and GameState.has_flag(BELL_HINT) and not GameState.has_flag(StringName("relic_" + String(BELL_RELIC))):
			_find_bell()
		elif north.has_point(tile) and Lamps.is_lit(PASTURE_LAMP):
			# 第三幕的开头：老秦守着这条路
			GameState.set_flag(WELL_WARNED)
			EventBus.banner_requested.emit("雾里有人喝了一声：“站住！那边是井，回去！”\n是老秦的声音")
		else:
			EventBus.banner_requested.emit("雾太浓了，前面的路一步也看不清")
	elif _sign_at(tile) != "":
		EventBus.banner_requested.emit(_sign_at(tile))


## 对着节日的摊子或长桌按使用键：摊主在就等于和他搭话。
func _use_counter() -> void:
	var keeper := _npc_of(_festival.keeper)
	if keeper == null or keeper.is_walking() or not Festivals.attending(_festival.keeper):
		EventBus.banner_requested.emit("%s的台子。%s" % [_festival.name, "已经散了" if GameClock.minutes >= _festival.to else "人还没到齐"])
		return
	if player != null:
		keeper.face_toward(player.position)
	Residents.talk(_festival.keeper, bool(keeper.spot.get("work", false)))


## 节日摆在广场上的东西：播种节的种子摊、丰收集和饺子宴的长桌、除夕的灯笼杆。节日那天一早就摆好。
func _place_festival() -> void:
	var def := Festivals.today()
	if def == null or def.map != map_id:
		return
	_festival = def
	if not def.counter.is_empty():
		var mid := Vector2.ZERO
		for t in def.counter:
			mid += tile_center(t)
			_block(t)
		mid = mid / def.counter.size() + Vector2(0, 7)
		var img := FestivalArt.stall() if def.id == &"sowing" else FestivalArt.table(String(def.id))
		_sprite(Px.tex(img), mid, Vector2(-img.get_width() / 2.0, -img.get_height()))
		_ground_shadow(mid + Vector2(0, -1), Px.tex(PixelArt.shadow(img.get_width() - 4, 6, 0.22)))
	if def.id == &"newyear":
		var pole := Px.tex(FestivalArt.lantern_pole(true))
		_lanterns = mini(Festivals.lantern_count(), def.decor.size())
		for i in _lanterns:
			var pos := tile_center(def.decor[i]) + Vector2(0, 6)
			_sprite(pole, pos, Vector2(-4, -33))
			_ground_shadow(pos + Vector2(0, -1), _small_shadow)
			_block(def.decor[i])
			# 灯太多画面会吃不消，只让最里面一圈真的发光
			if i < 4:
				_add_night_light(pos + Vector2(5, -24), 1.2)


## 雾封住的路玩家走不进去，居民可以。
func _tile_blocked(t: Vector2i) -> bool:
	return super._tile_blocked(t) or _in_fog(t)


func _in_fog(t: Vector2i) -> bool:
	for i in FOG_ROADS.size():
		if i == WEST_ROAD and not _west_closed():
			continue
		if i == NORTH_ROAD and not _north_closed():
			continue
		var fog: Rect2i = FOG_ROADS[i][1]
		if fog.has_point(t):
			return true
	return false


## 往井口的路走不走得通：井口灯亮了才通。
## 井口灯做出来以前这条路是跟着牧野灯开的（决策 050），那时候已经拿过镐子的旧存档照样走得通。
func _north_closed() -> bool:
	return not Lamps.is_lit(WELL_LAMP) and not GameState.has_flag(Mine.PICKAXE_FLAG)


## 往牧场的路走不走得通：牧野灯没亮是雾，大雪那几天是雪。
func _west_closed() -> bool:
	return not Lamps.is_lit(PASTURE_LAMP) or GameClock.term_id() == &"daxue"


## 在西边的雾里摸到花花的牛铃。
func _find_bell() -> void:
	if not GameState.inventory.can_add(BELL_RELIC, 1):
		EventBus.banner_requested.emit("雾里有东西在响，可背包满了")
		Audio.play("deny", 0.0, -4.0)
		return
	GameState.inventory.add(BELL_RELIC, 1)
	GameState.set_flag(StringName("relic_" + String(BELL_RELIC)))
	Audio.play("harvest", 0.0, -2.0)
	if player != null:
		Fx.pop_icon(self, player.position + Vector2(0, -20), Px.tex(PixelArt.icon(Database.item(BELL_RELIC).icon)))
	EventBus.dialogue_requested.emit(COMMON_DIALOGUE, "bell_found")


## 这一格是哪栋房子的正面墙，返回它的说明；不是就返回空。
func _sign_at(t: Vector2i) -> String:
	for b: Array in BUILDINGS:
		var x0: int = b[1]
		var front: int = b[2]
		var wide: int = b[3]
		if t.y == front - 1 and t.x >= x0 and t.x < x0 + wide:
			return str(b[4])
	return ""


func _layout() -> void:
	# 北街、广场、南街
	_fill(4, 9, 41, 10, PAVE)
	_fill(15, 11, 29, 19, PAVE)
	_fill(4, 18, 42, 19, PAVE)
	for r in ROADS:
		_fill(r.position.x, r.position.y, r.end.x - 1, r.end.y - 1, DIRT)
	# 出镇往农场的土路
	_fill(43, FARM_EXIT_ROWS[0], W - 1, FARM_EXIT_ROWS[1], DIRT)


func _place_objects() -> void:
	for b: Array in BUILDINGS:
		var prop: String = b[0]
		var x0: int = b[1]
		var front: int = b[2]
		var wide: int = b[3]
		var pos := Vector2((x0 + wide / 2.0) * TS, front * TS)
		_prop(prop, pos)
		_block_rect(x0, front - 5, x0 + wide - 1, front - 1)
		_ground_shadow(pos + Vector2(0, -1), Px.tex(PixelArt.shadow(wide * TS - 8, 10, 0.22)))
		_add_night_light(pos + Vector2(0, -22), 1.5)

	var lamp_pos := tile_center(LAMP_TILE) + Vector2(0, 6)
	_lamp_sprite = _prop("plaza_lamp", lamp_pos)
	_ground_shadow(lamp_pos + Vector2(0, -1), Px.tex(PixelArt.shadow(22, 6, 0.22)))
	_block(LAMP_TILE)
	if Lamps.is_lit(LAMP_ID):
		_show_lamp_lit()

	var west_lamp_pos := tile_center(PASTURE_LAMP_TILE) + Vector2(0, 6)
	_pasture_lamp_sprite = _prop("stone_lamp", west_lamp_pos)
	_ground_shadow(west_lamp_pos + Vector2(0, -1), Px.tex(PixelArt.shadow(16, 5, 0.22)))
	_block(PASTURE_LAMP_TILE)
	if Lamps.is_lit(PASTURE_LAMP):
		_add_night_light(west_lamp_pos + Vector2(0, -16), 2.0)

	var well_lamp_pos := tile_center(WELL_LAMP_TILE) + Vector2(0, 6)
	_well_lamp_sprite = _prop("stone_lamp", well_lamp_pos)
	_ground_shadow(well_lamp_pos + Vector2(0, -1), Px.tex(PixelArt.shadow(16, 5, 0.22)))
	_block(WELL_LAMP_TILE)
	if Lamps.is_lit(WELL_LAMP):
		_add_night_light(well_lamp_pos + Vector2(0, -16), 2.0)

	var board_pos := Vector2(BOARD_TILES[1].x * TS, BOARD_TILES[0].y * TS + 14)
	_prop("notice_board", board_pos)
	_ground_shadow(board_pos + Vector2(0, -1), Px.tex(PixelArt.shadow(34, 5, 0.22)))
	for t in BOARD_TILES:
		_block(t)

	for t in BENCHES:
		var pos := Vector2((t.x + 1) * TS, t.y * TS + 13)
		_prop("bench", pos)
		_ground_shadow(pos + Vector2(0, -1), Px.tex(PixelArt.shadow(30, 5, 0.2)))
		_block(t)
		_block(t + Vector2i(1, 0))

	_reserve(W - 2, FARM_EXIT_ROWS[0] - 1, W - 1, FARM_EXIT_ROWS[1] + 3)
	for r in ROADS:
		_reserve(r.position.x - 1, r.position.y - 1, r.end.x, r.end.y)
	_scatter_trees(16)
	_scatter_bushes(26)
	_scatter_tufts(320)
	_make_fog()
	_place_festival()


## 灯亮了：换成亮着的样子，晚上发光。
func _show_lamp_lit() -> void:
	_lamp_sprite.texture = PropArt.texture("plaza_lamp_lit")
	_lamp_sprite.offset = -PropArt.anchor("plaza_lamp_lit")
	_add_night_light(_lamp_sprite.position + Vector2(0, -20), 2.2)


## 点灯的那一下：火光、灯换样子。
func on_lamp_lit(lamp_id: StringName) -> void:
	if lamp_id == PASTURE_LAMP or lamp_id == WELL_LAMP:
		var sprite := _pasture_lamp_sprite if lamp_id == PASTURE_LAMP else _well_lamp_sprite
		var at := sprite.position + Vector2(0, -18)
		_add_night_light(sprite.position + Vector2(0, -16), 2.0)
		Fx.burst(self, at, Color(1.0, 0.85, 0.45, 0.95), 18, 40.0, 0.7, 20.0)
		Fx.burst(self, at, Color(1.0, 0.6, 0.25, 0.8), 10, 24.0, 0.9, 12.0)
		if not _west_closed():
			_lift_fog(WEST_ROAD)
		if not _north_closed():
			_lift_fog(NORTH_ROAD)
		return
	if lamp_id != LAMP_ID:
		return
	_show_lamp_lit()
	var top := _lamp_sprite.position + Vector2(0, -22)
	Fx.burst(self, top, Color(1.0, 0.85, 0.45, 0.95), 18, 40.0, 0.7, 20.0)
	Fx.burst(self, top, Color(1.0, 0.6, 0.25, 0.8), 10, 24.0, 0.9, 12.0)


## 一条路口的雾慢慢散掉。
func _lift_fog(road: int) -> void:
	var puffs: Array = _fog_puffs.get(road, [])
	for puff: Sprite2D in puffs:
		var tw := create_tween()
		tw.tween_property(puff, "modulate:a", 0.0, 1.5)
		tw.tween_callback(puff.queue_free)
	_fog_puffs.erase(road)


## 第一次进镇：小满从广场上跑过来搭话（序幕）。
func entered() -> void:
	if GameState.has_flag(PROLOGUE_FLAG) or player == null:
		return
	_prologue()


func _prologue() -> void:
	var def := Database.npc(&"xiaoman")
	var npc := _npc_of(&"xiaoman")
	var borrowed := npc == null
	if borrowed:
		# 下雨或天晚了她本来不在广场上，这次特地出来一趟；说完话日程会把她送回去
		npc = _add_npc(def, def.enter[map_id], Facing.DOWN)
		npc.appear()
	cutscene = true
	var me := tile_of(player.position)
	var goal := Vector2i(-1, -1)
	for side: Vector2i in [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0)]:
		var t := me + side
		if in_map(t) and _walkable(t) and not _in_fog(t):
			goal = t
			break
	var path := find_path(npc.tile(), goal) if goal.x >= 0 else ([] as Array[Vector2i])
	# 她在镇子另一头时不让玩家干等：从屏幕边上跑进来
	if path.size() > PROLOGUE_RUN:
		var skip := path.size() - PROLOGUE_RUN
		npc.position = tile_center(path[skip - 1]) + Vector2(0, 4)
		npc.appear()
		path = path.slice(skip)
	if not path.is_empty():
		npc.walk(path, Facing.RIGHT)
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
	GameState.set_flag(PROLOGUE_FLAG)
	cutscene = false
	if borrowed:
		npc.spot = {}
	EventBus.dialogue_requested.emit(Residents.dialogue_path(&"xiaoman"), "prologue")


## 三条路的尽头各盖一团雾。
func _make_fog() -> void:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 0.95), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	for i in FOG_ROADS.size():
		if i == WEST_ROAD and not _west_closed():
			continue
		if i == NORTH_ROAD and not _north_closed():
			continue
		var fog: Rect2i = FOG_ROADS[i][1]
		_fog_puffs[i] = []
		var mid := Vector2(fog.position + fog.end) * TS / 2.0
		# 往地图外面偏一点，路口那一侧淡出
		var out := (mid - Vector2(size_px()) / 2.0)
		out = Vector2(signf(out.x), 0) if absf(out.x) / W > absf(out.y) / H else Vector2(0, signf(out.y))
		for k in 3:
			var puff := Sprite2D.new()
			puff.texture = tex
			puff.position = mid + out * 10.0 + Vector2(out.y, out.x) * (k - 1) * 26.0
			puff.scale = Vector2(1.5, 1.5) if k == 1 else Vector2(1.2, 1.2)
			puff.z_index = 5
			add_child(puff)
			_fog_puffs[i].append(puff)
