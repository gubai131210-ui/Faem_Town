extends WildMap

const DishFrames := preload("res://art_gen/dish_art.gd")
## 镇广场：石板铺的广场和两条街，围着镇公所、药铺、茶馆、杂货铺、铁匠铺。
## 铺子仍是门口买卖。茶馆、药铺、铁匠铺和镇公所的门可以走进去（决策 109、110、115）。
## 广场灯亮了以后，井台、戏台和后街才回来（决策 111）。
## 镇子往东、往南扩到 84×54，老镇子那一片的坐标不动；新长出来的东市、南巷、河湾磨坊和北岗随灯回来（决策 149，规则在 `TownLand`）。

const W := TownLand.W
const H := TownLand.H
## 往东出去是农场
const FARM_EXIT_ROWS: Array[int] = [18, 19]
const LAMP_TILE := Vector2i(22, 15)
const BOARD_TILES: Array[Vector2i] = [Vector2i(27, 8), Vector2i(28, 8)]
## 茶馆、药铺正面墙正中那一格。对着它按使用键进屋。
const TEAHOUSE_DOOR := Vector2i(37, 8)
const HERB_DOOR := Vector2i(8, 8)
## 镇公所门在门脸正中。柏先生站在门外下一格，出来不叠在他身上。
const HALL_DOOR := Vector2i(22, 8)
## 铁匠铺门偏东一格。石叔站在正中那一格，不挡这扇门。
const SMITHY_DOOR := Vector2i(38, 17)
## 广场灯亮了以后才挡路的老井，占西边这两格。
const WELL_TILES: Array[Vector2i] = [Vector2i(15, 13), Vector2i(16, 13), Vector2i(15, 14), Vector2i(16, 14)]
## 戏台在广场东边，人站在南边那一排看。
const STAGE_X0 := 26
const STAGE_X1 := 29
const STAGE_Y := 16
## 后街在北排房子后面，巷子从北街通上去，夹在镇公所和茶馆之间。
const ALLEY_X0 := 31
const ALLEY_X1 := 32
## 广场灯亮了以后才钉上：后巷西墙的旧告示，戏台边一叠折纸。
const ALLEY_NOTICE := Vector2i(33, 7)
const STAGE_BOOK := Vector2i(24, 17)
## 房子：[素材, 最西边那一列, 正面墙脚下面那一行, 占几格宽, 对着它按使用键时的说明]。房子占正面往北的五行。
const BUILDINGS: Array = [
	["town_hall", 19, 9, 7, "镇公所。里面有一张桌子，墙上钉着旧地图"],
	["shop_herb", 6, 9, 5, "姜记药铺。门口晒着草药，闻着发苦"],
	["teahouse", 34, 9, 7, "云来茶馆。门口的菜牌擦了又写，写了又擦"],
	["shop_grocery", 6, 18, 5, "阿禾杂货铺。掌柜早上七点半到傍晚六点在门口"],
	["smithy", 35, 18, 5, "石叔铁匠铺。炉子在里面，早上八点到傍晚五点半有人"],
]
## 通到地图边上的三条路：往北是矿井，往南是南溪，往西是北坡牧场。
const ROADS: Array[Rect2i] = [Rect2i(13, 0, 2, 9), Rect2i(22, 20, 2, H - 20), Rect2i(0, 18, 4, 2)]
## 北边和西边还被雾封着，只有居民走得过去。每项是 [路的范围, 雾封住的范围]
const FOG_ROADS: Array = [
	[Rect2i(13, 0, 2, 9), Rect2i(13, 0, 2, 2)],
	[Rect2i(0, 18, 4, 2), Rect2i(0, 18, 2, 2)],
]
## 往南出去是南溪：走到最南边那一行
const NANXI_EXIT_COLS: Array[int] = [22, 23]
## 长凳：每条占两格，这里记西边那一格
const BENCHES: Array[Vector2i] = [Vector2i(17, 12), Vector2i(26, 12)]
## 小满雪天堆的雪人：堆好立旗，化雪（雪停后的第二天）才清掉
const SNOWMAN_FLAG := &"snowman_built"
const SNOWMAN_TILE := Vector2i(23, 14)
## 除夕夜里年站在镇东口的土路上，不挡进镇那一格（决策 129）。
const NIAN := Vector2i(43, 18)
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

## 雾区盖的雾，和农场开地用的是同一种
const ZONE_FOG_SHADER := """
shader_type canvas_item;
uniform vec2 tiles = vec2(84.0, 54.0);
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y);
}
void fragment() {
	float shut = texture(TEXTURE, UV).a;
	vec2 p = floor(UV * tiles * 16.0) / 16.0 * 0.4;
	float v = n(p + vec2(TIME * 0.03, TIME * 0.012)) * 0.6 + n(p * 2.3 - vec2(TIME * 0.02, 0.0)) * 0.4;
	float a = smoothstep(0.3, 0.7, shut + (v - 0.5) * 0.45);
	COLOR = vec4(mix(vec3(0.84, 0.89, 0.92), vec3(0.98, 0.99, 1.0), v), a * (0.9 + 0.08 * v));
}
"""
## 新镇子的树
const NEW_TREES: Array[String] = ["round0", "round1", "round2", "round0", "round1", "plum0"]

var _zone_fog: Sprite2D
var _zone_key := "?"

var _lamp_sprite: Sprite2D
var _pasture_lamp_sprite: Sprite2D
var _well_lamp_sprite: Sprite2D
## 路的下标 -> 盖在路口的那几团雾
var _fog_puffs: Dictionary[int, Array] = {}
## 今天在广场上办的节日；没有是 null
var _festival: FestivalDef
## 除夕挂了几只灯笼
var _lanterns := 0
var _nian: Sprite2D
var _nian_sheet: CharacterSheet
var _grocery: Sprite2D
var _heji_on := false
var _song: Sprite2D
var _song_on := false
var _basket: Sprite2D
## 灯亮以后杂货铺门侧原来是「米」。
static func _rice_rows() -> PackedStringArray:
	return PackedStringArray(["....##....", "..##..##..", "....##....", "##########", "....##....", "..##..##..", ".##....##.", "##......##"])


## 阿禾忆满以后换成「禾记」。左边是禾，右边是记。
static func _heji_rows() -> PackedStringArray:
	return PackedStringArray([
		"....#.....#...####.",
		"...#.......#......#",
		"..#..#....#.......#",
		".#...#.....#....###",
		".#######..#.#.....#",
		"....#......#......#",
		"....#.....#...####.",
		"...#.#.....#.......",
		"...#.#....#........",
		"..#...#............",
		".#.....#...........",
	])
## 饺子宴和除夕的长桌，以及摆上去的菜
var _fest_table: Sprite2D
var _fest_dishes: Array[Sprite2D] = []
var _snowman: Sprite2D
var _houses: Array[Sprite2D] = []
var _returned := false


func _ready() -> void:
	map_id = &"town"
	_rng.seed = 20261112
	# 老镇子那一块撒树撒灌木的随机数不变；东、南两排当边界的树让给通路
	_scatter_cols = TownLand.OLD_W
	_scatter_rows = TownLand.OLD_H
	_setup_wild(W, H)
	_layout()
	_layout_new()
	_finish_relief()
	_build_ground()
	_add_relief(WildArt.ROCK)
	_make_entities()
	_place_objects()
	_place_new()
	_add_planks()
	_make_water_fx(60)
	_sync_zones()
	_spawn_npcs()
	_refresh_snowman()
	Weather.changed.connect(_refresh_snowman)
	_sync_nian()


func _exit_tree() -> void:
	if Crafting.changed.is_connected(_sync_fest_dishes):
		Crafting.changed.disconnect(_sync_fest_dishes)
	super._exit_tree()


func _process(delta: float) -> void:
	super._process(delta)
	_sync_nian()
	_sync_marks()
	if _fest_dishes.is_empty():
		return
	var frame := int(Time.get_ticks_msec() / 180) % 4
	for i in _fest_dishes.size():
		if i >= Crafting.table_dishes.size():
			break
		_fest_dishes[i].texture = DishFrames.frame(Crafting.table_dishes[i], frame)


func _nian_out() -> bool:
	var fest := Festivals.today()
	if fest == null or fest.id != &"newyear" or Bestiary.known(&"nian"):
		return false
	return GameClock.minutes >= 1140.0 + GameClock.dusk_shift()


func _sync_nian() -> void:
	var on := _nian_out()
	if on:
		if _nian == null:
			_nian_sheet = CharacterSheet.load_sheet("nian", CharacterSheet.CREATURE_DIR)
			if not _nian_sheet.is_valid():
				return
			_nian = Sprite2D.new()
			_nian.texture = _nian_sheet.texture
			_nian.centered = false
			_nian.region_enabled = true
			_nian.region_rect = _nian_sheet.region(&"idle", Facing.LEFT, 0)
			_nian.offset = Vector2(-_nian_sheet.cell / 2.0, -float(_nian_sheet.foot_row))
			_nian.position = tile_center(NIAN) + Vector2(0, 4)
			entities.add_child(_nian)
		_block(NIAN)
	elif _nian != null:
		_nian.queue_free()
		_nian = null
		solid[idx(NIAN)] = 0
		occupied.erase(NIAN)


func spawn_position(spawn: StringName) -> Vector2:
	if spawn == &"from_farm":
		return tile_center(Vector2i(W - 2, FARM_EXIT_ROWS[0])) + Vector2(0, 8)
	if spawn == &"from_nanxi":
		return tile_center(Vector2i(NANXI_EXIT_COLS[0], H - 2)) + Vector2(8, 0)
	if spawn == &"from_pasture":
		return tile_center(Vector2i(1, PASTURE_EXIT_ROWS[0])) + Vector2(0, 8)
	if spawn == &"from_wellhead":
		return tile_center(Vector2i(WELL_EXIT_COLS[0], 1)) + Vector2(8, 0)
	if spawn == &"teahouse_door":
		return tile_center(Vector2i(37, 10))
	if spawn == &"herb_door":
		return tile_center(Vector2i(8, 10))
	if spawn == &"hall_door":
		return tile_center(Vector2i(22, 9))
	if spawn == &"smithy_door":
		return tile_center(Vector2i(38, 18))
	return tile_center(Vector2i(22, 18))


func spawn_facing(spawn: StringName) -> Facing:
	if spawn == &"from_farm":
		return Facing.LEFT
	if spawn == &"from_nanxi":
		return Facing.UP
	if spawn == &"from_pasture":
		return Facing.RIGHT
	if spawn == &"teahouse_door" or spawn == &"herb_door" or spawn == &"hall_door" or spawn == &"smithy_door":
		return Facing.UP
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
	if in_map(tile) and not TownLand.open_tile(tile):
		return &"interact"
	if npc_at(tile) != null or (tile == NIAN and _nian_out()) or tile == LAMP_TILE or tile == PASTURE_LAMP_TILE or tile == WELL_LAMP_TILE or BOARD_TILES.has(tile) or _in_fog(tile) or _sign_at(tile) != "" or _returned_text(tile) != "":
		return &"interact"
	if _festival != null and _festival.counter.has(tile):
		return &"interact"
	return &""


func perform(action: StringName, _item: ItemDef, tile: Vector2i, _quiet: bool = false) -> void:
	if action != &"interact" or _talk_at(tile):
		return
	if tile == NIAN and _nian_out():
		EventBus.banner_requested.emit(Bestiary.push_nian())
		return
	if _festival != null and _festival.counter.has(tile):
		if _lay_dish(_item):
			return
		if _festival.id == &"newyear":
			var brought := Crafting.table_dishes.size()
			EventBus.banner_requested.emit("除夕的长桌。" if brought == 0 else "今年带了%d道菜。" % brought)
			return
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
	elif in_map(tile) and not TownLand.open_tile(tile):
		EventBus.banner_requested.emit(TownLand.waiting(TownLand.zone_of(tile)))
	elif _in_fog(tile):
		var west: Rect2i = FOG_ROADS[WEST_ROAD][1]
		var north: Rect2i = FOG_ROADS[NORTH_ROAD][1]
		if west.has_point(tile) and Lamps.is_lit(PASTURE_LAMP):
			EventBus.banner_requested.emit("大雪封山，北坡上不去")
		elif west.has_point(tile) and GameState.has_flag(BELL_HINT) and not GameState.has_flag(StringName("relic_" + String(BELL_RELIC))):
			_find_bell()
		elif north.has_point(tile):
			# 第三幕的开头：老秦守着这条路。不看牧野灯，井可以先走（决策 067）
			GameState.set_flag(WELL_WARNED)
			EventBus.banner_requested.emit("雾里有人喝了一声：“站住！那边是井，回去！”\n是老秦的声音")
		else:
			EventBus.banner_requested.emit("雾太浓了，前面的路一步也看不清")
	elif tile == TEAHOUSE_DOOR:
		SceneRouter.travel(&"teahouse", &"door")
	elif tile == HERB_DOOR:
		SceneRouter.travel(&"herbshop", &"door")
	elif tile == HALL_DOOR:
		SceneRouter.travel(&"hall", &"door")
	elif tile == SMITHY_DOOR:
		SceneRouter.travel(&"smithy", &"door")
	elif _returned_text(tile) != "":
		if tile == ALLEY_NOTICE:
			GameState.set_flag(&"read_alley_notice")
		elif tile == STAGE_BOOK:
			GameState.set_flag(&"read_stage_book")
		EventBus.banner_requested.emit(_returned_text(tile))
	elif _sign_at(tile) != "":
		var line := _sign_at(tile)
		if tile != HERB_DOOR and _herb_wall(tile) and Livelihood.offer_sip():
			line += "她给你续了一口。"
		EventBus.banner_requested.emit(line)


## 对着节日的摊子或长桌按使用键：摊主在就等于和他搭话。
func _use_counter() -> void:
	var keeper := _npc_of(_festival.keeper)
	if keeper == null or keeper.is_walking() or not Festivals.attending(_festival.keeper):
		EventBus.banner_requested.emit("%s的台子。%s" % [_festival.name, "已经散了" if GameClock.minutes >= _festival.to else "人还没到齐"])
		return
	if player != null:
		keeper.face_toward(player.position)
	Residents.talk(_festival.keeper, bool(keeper.spot.get("work", false)))


## 饺子宴和除夕：手里拿着做好的菜，对着长桌就摆上去。不是菜就返回假，交给原来的摊子。
func _lay_dish(item: ItemDef) -> bool:
	if _festival == null or (_festival.id != &"dumpling" and _festival.id != &"newyear"):
		return false
	if item == null or not Database.recipes.has(item.id) or item.id == Crafting.ODD_BOWL:
		return false
	if Crafting.place_dish(item.id):
		EventBus.banner_requested.emit("摆上了%s。" % item.name)
	elif Crafting.table_dishes.has(item.id):
		EventBus.banner_requested.emit("这道已经在桌上了。")
	elif Crafting.table_dishes.size() >= Crafting.TABLE_MAX:
		EventBus.banner_requested.emit("桌上摆满了。")
	else:
		EventBus.banner_requested.emit("手上没有这道菜。")
	return true


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
		var laid := def.id == &"dumpling" or def.id == &"newyear"
		var img := FestivalArt.stall() if def.id == &"sowing" else _fest_image(def.id, laid)
		_fest_table = _sprite(Px.tex(img), mid, Vector2(-img.get_width() / 2.0, -float(img.get_height())))
		_ground_shadow(mid + Vector2(0, -1), Px.tex(PixelArt.shadow(img.get_width() - 4, 6, 0.22)))
		if laid:
			_sync_fest_dishes()
			if not Crafting.changed.is_connected(_sync_fest_dishes):
				Crafting.changed.connect(_sync_fest_dishes)
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


func _fest_image(fest_id: StringName, laid: bool) -> Image:
	if not laid:
		return FestivalArt.table(String(fest_id))
	if fest_id == &"dumpling" and Crafting.table_dishes.is_empty():
		return FestivalArt.table("dumpling")
	return FestivalArt.cloth(String(fest_id))


func _sync_fest_dishes() -> void:
	if _fest_table == null or _festival == null:
		return
	if _festival.id != &"dumpling" and _festival.id != &"newyear":
		return
	var img := _fest_image(_festival.id, true)
	_fest_table.texture = Px.tex(img)
	for spr in _fest_dishes:
		spr.queue_free()
	_fest_dishes.clear()
	var n := Crafting.table_dishes.size()
	var scale := FestivalArt.dish_scale(n)
	var places := FestivalArt.dish_places(n)
	for i in n:
		var spr := Sprite2D.new()
		spr.centered = true
		spr.scale = Vector2(scale, scale)
		spr.texture = DishFrames.frame(Crafting.table_dishes[i], 0)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.position = Vector2(-img.get_width() / 2.0, -img.get_height()) + places[i]
		_fest_table.add_child(spr)
		_fest_dishes.append(spr)


## 雾封住的路玩家走不进去，居民可以。
func _tile_blocked(t: Vector2i) -> bool:
	return super._tile_blocked(t) or _in_fog(t) or not TownLand.open_tile(t)


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
			var prop := str(b[0])
			if prop == "shop_grocery" and PeopleLine.mark(&"ahe") != "":
				return PeopleLine.mark(&"ahe")
			if prop == "teahouse" and PeopleLine.mark(&"yunniang") != "":
				return PeopleLine.mark(&"yunniang")
			var text := str(b[4])
			if prop == "shop_herb" and Livelihood.mark(&"pick") != "":
				return text + Livelihood.mark(&"pick")
			return text
	return ""


## 老镇子东、南两排当边界的树，现在是通往新镇子的路，不画；撒树撒灌木时仍先占着，老镇子别处的位置才不变。
func _ghost_tree(t: Vector2i) -> bool:
	return _legacy_edge(t, TownLand.OLD_W, TownLand.OLD_H)


func _layout() -> void:
	# 北街、广场、南街
	_fill(4, 9, 41, 10, PAVE)
	_fill(15, 11, 29, 19, PAVE)
	_fill(4, 18, 42, 19, PAVE)
	for r in ROADS:
		_fill(r.position.x, r.position.y, r.end.x - 1, r.end.y - 1, DIRT)
	# 出镇往农场的土路
	_fill(43, FARM_EXIT_ROWS[0], W - 1, FARM_EXIT_ROWS[1], DIRT)
	if Lamps.is_lit(LAMP_ID):
		_pave_returned()


func _place_objects() -> void:
	for i in BUILDINGS.size():
		var b: Array = BUILDINGS[i]
		var prop: String = b[0]
		var x0: int = b[1]
		var front: int = b[2]
		var wide: int = b[3]
		var pos := Vector2((x0 + wide / 2.0) * TS, front * TS)
		var house := _prop(prop, pos)
		_add_window(house, Vector2(-22, -42), i * 2)
		_add_window(house, Vector2(22, -42), i * 2 + 1)
		if prop == "teahouse":
			_add_plume(house, Vector2(28, -86), false)
			_song = Sprite2D.new()
			_song.name = "SongSlip"
			_song.texture = Px.tex(_song_slip())
			_song.centered = false
			_song.position = Vector2(-55, -14)
			_song.visible = Residents.memory_level(&"yunniang") >= Story.MEMORY_MAX
			_song_on = _song.visible
			house.add_child(_song)
		elif prop == "smithy":
			_add_plume(house, Vector2(-16, -40), true)
		_block_rect(x0, front - 5, x0 + wide - 1, front - 1)
		_ground_shadow(pos + Vector2(0, -1), Px.tex(PixelArt.shadow(wide * TS - 8, 10, 0.22)))
		_add_night_light(pos + Vector2(0, -22), 1.5)
		_houses.append(house)

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
	# 老镇口原来占着的那一块照旧占着：撒树是“空着才取随机数”，不占就会把后面的树和草全挪位
	_reserve(TownLand.OLD_W - 2, FARM_EXIT_ROWS[0] - 1, TownLand.OLD_W - 1, FARM_EXIT_ROWS[1] + 3)
	for r in ROADS:
		_reserve(r.position.x - 1, r.position.y - 1, r.end.x, r.end.y)
	_reserve(7, 3, 12, 3)
	_reserve(15, 3, 33, 3)
	_reserve(ALLEY_X0, 3, ALLEY_X1, 9)
	if Lamps.is_lit(LAMP_ID):
		_place_returned()
	_scatter_trees(16)
	_scatter_bushes(26)
	_scatter_tufts(320)
	_release_ghosts()
	_make_fog()
	_place_festival()
	_refresh_snowman()
	_sync_basket()


## 雪人在不在：旗立着就摆一个；雪停后的第二天化掉，清旗收走。
func _refresh_snowman() -> void:
	if GameState.has_flag(SNOWMAN_FLAG) and Weather.today != Weather.SNOW and Weather.yesterday != Weather.SNOW:
		GameState.clear_flag(SNOWMAN_FLAG)
	var show := GameState.has_flag(SNOWMAN_FLAG)
	if show and _snowman == null:
		_snowman = Sprite2D.new()
		_snowman.texture = Px.tex(_snowman_image())
		_snowman.centered = false
		_snowman.offset = Vector2(-8, -20)
		_snowman.position = tile_center(SNOWMAN_TILE) + Vector2(0, 4)
		entities.add_child(_snowman)
		_ground_shadow(_snowman.position + Vector2(0, -1), Px.tex(PixelArt.shadow(14, 5, 0.2)))
	elif not show and _snowman != null:
		_snowman.queue_free()
		_snowman = null


## 雪人：两个雪球、煤球眼睛、胡萝卜鼻子、两根树枝手。
func _snowman_image() -> Image:
	var img := Image.create(16, 20, false, Image.FORMAT_RGBA8)
	var snow := Color("f4f8fb")
	var shade := Color("c3d2dd")
	var coal := Color("2b2b33")
	var carrot := Color("e0762f")
	img.fill(Color(0, 0, 0, 0))
	for y in range(20):
		for x in range(16):
			var dx := x - 8.0
			var body := dx * dx + (y - 14.0) * (y - 14.0) <= 30.0
			var head := dx * dx + (y - 6.0) * (y - 6.0) <= 12.0
			if body or head:
				img.set_pixel(x, y, shade if (x + y) % 5 == 0 else snow)
	img.set_pixel(6, 5, coal)
	img.set_pixel(10, 5, coal)
	img.set_pixel(8, 7, carrot)
	img.set_pixel(9, 7, carrot)
	for x in [1, 2, 13, 14]:
		img.set_pixel(x, 11, Color("6b4a2f"))
	return img


## 灯亮了：换成亮着的样子，晚上发光。
func _show_lamp_lit() -> void:
	_lamp_sprite.texture = PropArt.texture("plaza_lamp_lit")
	_lamp_sprite.offset = -PropArt.anchor("plaza_lamp_lit")
	_add_night_light(_lamp_sprite.position + Vector2(0, -20), 2.2)


## 点灯的那一下：火光、灯换样子。
func on_lamp_lit(lamp_id: StringName) -> void:
	_sync_zones()
	_announce_zone()
	if lamp_id == PASTURE_LAMP or lamp_id == WELL_LAMP:
		var sprite := _pasture_lamp_sprite if lamp_id == PASTURE_LAMP else _well_lamp_sprite
		var at := sprite.position + Vector2(0, -18)
		_add_night_light(sprite.position + Vector2(0, -16), 2.0)
		Fx.burst(self, at, Color(1.0, 0.85, 0.45, 0.95), 18, 40.0, 0.7, 20.0)
		Fx.burst(self, at, Color(1.0, 0.6, 0.25, 0.8), 10, 24.0, 0.9, 12.0)
		if not _west_closed():
			_lift_fog(WEST_ROAD, sprite.position)
		if not _north_closed():
			_lift_fog(NORTH_ROAD, sprite.position)
		return
	if lamp_id != LAMP_ID:
		return
	_show_lamp_lit()
	var top := _lamp_sprite.position + Vector2(0, -22)
	Fx.burst(self, top, Color(1.0, 0.85, 0.45, 0.95), 18, 40.0, 0.7, 20.0)
	Fx.burst(self, top, Color(1.0, 0.6, 0.25, 0.8), 10, 24.0, 0.9, 12.0)
	if not _returned:
		_pave_returned()
		for child in get_children():
			var spr := child as Sprite2D
			if spr != null and spr.z_index == -10:
				spr.queue_free()
		_build_ground()
		_place_returned()


## 一条路口的雾从灯那边往外退着散掉。
func _lift_fog(road: int, lamp: Vector2) -> void:
	var puffs: Array = _fog_puffs.get(road, [])
	for puff: Sprite2D in puffs:
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(puff, "modulate:a", 0.0, 1.4)
		tw.tween_property(puff, "position", puff.position + OutdoorMap.fog_drift(puff.position, lamp), 1.4)
		tw.chain().tween_callback(puff.queue_free)
	_fog_puffs.erase(road)


func lamp_focus(lamp_id: StringName) -> Vector2:
	if lamp_id == LAMP_ID and _lamp_sprite != null:
		return _lamp_sprite.global_position
	if lamp_id == PASTURE_LAMP and _pasture_lamp_sprite != null:
		return _pasture_lamp_sprite.global_position
	if lamp_id == WELL_LAMP and _well_lamp_sprite != null:
		return _well_lamp_sprite.global_position
	return Vector2.INF


## 第一次进镇：小满从广场上跑过来搭话（序幕）。
func entered() -> void:
	if player == null:
		return
	if not GameState.has_flag(PROLOGUE_FLAG):
		_prologue()
		return
	_announce_zone()


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
			_remember_fog(puff)
			_fog_puffs[i].append(puff)


func _ground_key() -> String:
	return "%s:%d:%d" % [map_id, _season, 1 if Lamps.is_lit(LAMP_ID) else 0]


## 北排房子后面的一条街，和通上去的巷子。灯亮之前这里是草地。
func _pave_returned() -> void:
	_fill(7, 3, 12, 3, PAVE)
	_fill(15, 3, 33, 3, PAVE)
	_fill(ALLEY_X0, 4, ALLEY_X1, 9, PAVE)
	var m := TownLand.MARKET
	_fill(m.position.x, m.position.y, m.end.x - 1, m.end.y - 1, PAVE)


## 井、戏台、巷门，和各家门口的旧招牌。
func _place_returned() -> void:
	if _returned:
		return
	_returned = true
	var well_pos := Vector2(16.0 * TS, 15.0 * TS)
	_prop("well", well_pos)
	_ground_shadow(well_pos + Vector2(0, -1), Px.tex(PixelArt.shadow(28, 6, 0.22)))
	for t in WELL_TILES:
		_block(t)
	var stage_pos := Vector2(28.0 * TS, 17.0 * TS)
	_prop("stage", stage_pos)
	_ground_shadow(stage_pos + Vector2(0, -1), Px.tex(PixelArt.shadow(60, 8, 0.22)))
	for x in range(STAGE_X0, STAGE_X1 + 1):
		_block(Vector2i(x, STAGE_Y))
		_block(Vector2i(x, STAGE_Y - 1))
	var gate_pos := Vector2(32.0 * TS, 10.0 * TS)
	_prop("alley_gate", gate_pos)
	_hang_clue(ALLEY_NOTICE, PlaceClueArt.slip(), 6.0)
	_hang_clue(STAGE_BOOK, PlaceClueArt.booklet(), 2.0)
	var glyphs: Array[PackedStringArray] = [
		PackedStringArray(),
		PackedStringArray(["..##...##...##..", "################", "....##....##....", ".##.............", "####............", ".##....######...", ".##........##...", ".##....####.....", "........##......", "......####......", "........##......", "......####......"]),
		PackedStringArray(["##..##..##", "##########", "....##....", "..##..##..", "##......##", "##########", "....##....", "..##..##..", "##......##"]),
		_rice_rows(),
		PackedStringArray(["##########", "##########", "...####...", "...####...", "..######..", "##########", "##......##"]),
	]
	_place_market()
	for i in _houses.size():
		if glyphs[i].is_empty():
			continue
		var rows: PackedStringArray = glyphs[i]
		if i == 3 and Residents.memory_level(&"ahe") >= Story.MEMORY_MAX:
			rows = _heji_rows()
		var wide: int = BUILDINGS[i][3]
		var sign := _hang_sign(_houses[i], rows, Vector2(-wide * 9.0, -68.0))
		if i == 3:
			sign.name = "GrocerySign"
			_grocery = sign
			_heji_on = Residents.memory_level(&"ahe") >= Story.MEMORY_MAX


func clue_at(tile: Vector2i) -> String:
	var seen: String = clues.get(tile, "")
	if seen != "":
		return seen
	if not Lamps.is_lit(LAMP_ID):
		return ""
	if tile == ALLEY_NOTICE:
		return "后巷的墙上钉着一张旧告示。字被雨冲开了，落款涂成一块墨。"
	if tile == STAGE_BOOK:
		return "戏台边压着一叠折好的纸。讲的是山里的事，名字那一行空着。"
	return ""


func _returned_text(tile: Vector2i) -> String:
	var clue := clue_at(tile)
	if clue != "":
		return clue
	if not Lamps.is_lit(LAMP_ID):
		return ""
	if WELL_TILES.has(tile) and tile.y == 14:
		return "老井台。井沿被手磨亮了，井里看不见底"
	if tile.y == STAGE_Y and tile.x >= STAGE_X0 and tile.x <= STAGE_X1:
		return "戏台。红帐从中间分开，台板上还有一只鼓"
	return ""


func _hang_sign(house: Sprite2D, rows: PackedStringArray, at: Vector2) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.texture = Px.tex(Px.outline(_sign_image(rows)))
	spr.centered = false
	spr.position = at
	house.add_child(spr)
	return spr


func _sync_marks() -> void:
	if _grocery != null:
		var heji := Residents.memory_level(&"ahe") >= Story.MEMORY_MAX
		if heji != _heji_on:
			_heji_on = heji
			var rows: PackedStringArray = _heji_rows() if heji else _rice_rows()
			_grocery.texture = Px.tex(Px.outline(_sign_image(rows)))
	if _song != null:
		var on := Residents.memory_level(&"yunniang") >= Story.MEMORY_MAX
		if on != _song_on:
			_song_on = on
			_song.visible = on
	_sync_basket()


func _herb_wall(t: Vector2i) -> bool:
	return t.y == 8 and t.x >= 6 and t.x < 11


func _sync_basket() -> void:
	var on := Livelihood.told(&"pick") >= 1
	if not on:
		if _basket != null:
			_basket.queue_free()
			_basket = null
		return
	if _basket != null or _houses.size() < 2:
		return
	_basket = Sprite2D.new()
	_basket.name = "HerbBasket"
	_basket.texture = Px.tex(_basket_image())
	_basket.centered = false
	_basket.position = Vector2(-40, -14)
	_houses[1].add_child(_basket)


func _basket_image() -> Image:
	var img := Px.new_img(10, 8)
	Px.rect(img, 1, 2, 8, 6, Color.html("c4a06a"))
	Px.rect(img, 0, 2, 10, 1, Color.html("6a4430"))
	Px.rect(img, 2, 4, 2, 2, Color.html("3a8a40"))
	Px.rect(img, 5, 3, 2, 2, Color.html("6aaa48"))
	return img


func _song_slip() -> Image:
	var img := Px.new_img(12, 8)
	Px.rect(img, 0, 0, 12, 8, Color.html("f3e2b0"))
	Px.rect(img, 2, 1, 8, 1, Color.html("8a3030"))
	Px.rect(img, 2, 3, 6, 1, Color.html("8a3030"))
	Px.rect(img, 2, 5, 7, 1, Color.html("8a3030"))
	return img


func _sign_image(rows: PackedStringArray) -> Image:
	var sample: String = rows[0]
	var gw := sample.length()
	var gh := rows.size()
	var img := Px.new_img(gw + 8, gh + 10)
	Px.rect(img, 0, 0, gw + 8, gh + 10, Color.html("6a4430"))
	Px.rect(img, 3, 4, gw + 2, gh + 2, Color.html("e8604a"))
	var gold := Color.html("f7dc80")
	for r in rows.size():
		var row: String = rows[r]
		for c in row.length():
			if row[c] == "#":
				img.set_pixel(4 + c, 5 + r, gold)
	return img


# ---------------------------------------------------------------- 新镇子（决策 149）

## 河在这一行的中心列：从北往南缓缓弯，三格宽
func _river_x(y: int) -> int:
	return 60 + int(roundf(sin(y * 0.19 + 0.4) * 1.4))


func _layout_new() -> void:
	for y in H:
		var c := _river_x(y)
		for x in range(c - 1, c + 2):
			_set_water(Vector2i(x, y))
	# 东街：从老镇口铺到桥头，过桥是土路通农场
	_fill(46, 18, 55, 19, PAVE)
	_walk([Vector2i(56, 18), Vector2i(64, 18)], 2, DIRT, false)
	# 南街一路下到南溪，东西各一条巷
	_fill(24, 37, 55, 38, PAVE)
	_walk([Vector2i(56, 37), Vector2i(64, 37)], 2, DIRT, false)
	_fill(65, 37, 68, 38, DIRT)
	_fill(41, 31, 42, 36, PAVE)
	_fill(26, 48, 57, 49, PAVE)
	# 河湾的小路，和北岗的上山路
	_fill(52, 2, 53, 12, PAVE)
	_fill(72, 9, 73, 17, DIRT)
	# 东岸的田埂路和菜地
	_fill(67, 20, 68, 52, DIRT)
	_fill(70, 29, 77, 34, DIRT)
	_fill(70, 38, 77, 44, DIRT)
	_fill(79, 29, 82, 34, DIRT)
	# 北岗：一层高地，南边两格宽的石阶
	_raise(66, 2, 80, 7, 1)
	_steps(72, 73, 8)
	_fill(70, 4, 75, 7, PAVE)


func _place_new() -> void:
	_new_edge_trees(TownLand.OLD_W, TownLand.OLD_H, NEW_TREES)
	_place_east_bank()
	_place_south_lanes()
	_place_mill_bend()
	_place_north_hill()
	_place_southwest()
	var woods: Array[String] = NEW_TREES
	_grove(Rect2i(63, 28, 20, 25), 13, woods)
	_grove(Rect2i(2, 31, 19, 22), 15, woods)
	_grove(Rect2i(58, 0, 6, 17), 14, woods)
	_sprinkle_grass(Rect2i(46, 0, 38, 30), 21)
	_sprinkle_grass(Rect2i(0, 30, W, H - 30), 22)


## 桥两头的石灯、路牌，路北的两户和路南的两户，地里的稻草人。
func _place_east_bank() -> void:
	for t: Vector2i in [Vector2i(57, 17), Vector2i(57, 20), Vector2i(63, 20)]:
		_lamp_post(t)
	_hang_clue(Vector2i(64, 17), WildArt.signpost(), 2.0)
	_clue(Vector2i(64, 17), "路牌。往西：镇广场。往东：农场。往南：田埂和渡口。")
	_building("miner_house", 65, 18, 5, 3)
	_wall_clue(65, 18, 5, "门口斜靠着一把扫帚，地扫得很干净。")
	_building("miner_house", 76, 18, 5, 3)
	_wall_clue(76, 18, 5, "窗纸是新糊的，没有一个补丁。")
	_building("house", 69, 26, 8, 4)
	_wall_clue(69, 26, 8, "农户。院墙上钉着一排稻穗，是去年的。")
	_building("miner_house", 78, 25, 5, 3)
	_wall_clue(78, 25, 5, "晒谷场上扣着一只竹筐，筐下压着一块石头。")
	_wide_prop("drying_rack", Vector2i(63, 22), 2, "竹匾里晒着南瓜干，被谁翻过一遍。")
	_wide_prop("wood_pile", Vector2i(63, 25), 2, "柴垛靠着一棵老树，树皮上刻着一道一道的线，是量孩子身高的。")
	_small_prop("scarecrow", Vector2i(73, 31), "稻草人。破草帽底下压着一张褪了色的红纸。")
	_small_prop("scarecrow", Vector2i(73, 41), "稻草人。袖子里塞满了干草，像刚有人替它整理过。")
	_small_prop("scarecrow", Vector2i(80, 32), "稻草人。脚边落着几根麻雀的羽毛。")


## 南巷：两排老屋夹着石板巷，中间是一口井，东头是船屋。灯亮以前盖在雾里。
func _place_south_lanes() -> void:
	# 北排
	_building("miner_house", 28, 37, 5, 4)
	_wall_clue(28, 37, 5, "窄门矮檐，门口留着一双磨平了底的草鞋。")
	_building("shop_soy", 35, 37, 5, 4)
	_wall_clue(35, 37, 5, "酱油铺。门口的大缸晒得发白，缸沿上有一圈手印。")
	_building("schoolhouse", 44, 37, 6, 4)
	_wall_clue(44, 37, 6, "学堂。窗里一排小凳，最后一张凳子腿下垫着一块砖。")
	_building("house", 50, 37, 8, 4)
	_wall_clue(50, 37, 8, "大宅子。门环擦得亮，院里的晾衣绳上挂着一件孩子的小褂。")
	# 南排
	_building("miner_house", 28, 48, 5, 4)
	_wall_clue(28, 48, 5, "屋檐下挂着一串风干的辣椒，红得很新。")
	_building("house", 35, 48, 8, 4)
	_wall_clue(35, 48, 8, "门缝里塞着一张字条，被雨洇得认不出字。")
	_building("miner_house", 46, 48, 5, 4)
	_wall_clue(46, 48, 5, "窗台上放着一碗水，碗沿结着青苔。")
	_building("boathouse", 52, 48, 5, 4)
	_wall_clue(52, 48, 5, "船屋。河水一下一下拍着台阶，一条船也没系。")
	# 巷子中间的井和树
	var well_pos := Vector2(45.0 * TS, 42.0 * TS)
	_prop("well", well_pos)
	_ground_shadow(well_pos + Vector2(0, -1), Px.tex(PixelArt.shadow(28, 6, 0.22)))
	for t: Vector2i in [Vector2i(44, 40), Vector2i(45, 40), Vector2i(44, 41), Vector2i(45, 41)]:
		_block(t)
	_clue(Vector2i(44, 41), "巷里的井。井绳是新换的，还没磨出印子。")
	_clue(Vector2i(45, 41), "巷里的井。井绳是新换的，还没磨出印子。")
	_tree("plum0", Vector2i(32, 41))
	_tree("round1", Vector2i(53, 41))
	_wide_prop("bench", Vector2i(37, 41), 2)
	_wide_prop("drying_rack", Vector2i(29, 40), 2, "竹匾里晒着梅干，一颗一颗，摆得很齐。")
	_lamp_post(Vector2i(27, 39))
	_lamp_post(Vector2i(43, 39))
	_lamp_post(Vector2i(56, 39))


## 河湾：水磨、船坞和码好的柴。灯亮以前盖在雾里。
func _place_mill_bend() -> void:
	_building("mill", 46, 9, 6, 4)
	_wall_clue(46, 9, 6, "水磨。石磨停着，磨盘缝里还有一线白粉。")
	_small_prop("millstone", Vector2i(45, 10), "一只废磨盘靠在墙边，上面刻着一个字，磨得认不出了。")
	_building("boatyard", 54, 9, 4, 2, false)
	_wall_clue(54, 9, 4, "船坞。龙骨架在木墩上，板子只钉了一半。")
	_wide_prop("wood_pile", Vector2i(47, 11), 2, "码得齐整的劈柴，最上面一层是潮的。")
	_wide_prop("drying_rack", Vector2i(49, 11), 2, "竹匾里的鱼干刚翻过一面。")
	_lamp_post(Vector2i(51, 12))
	_lamp_post(Vector2i(54, 12))


## 北岗：石门、石阶、土地祠和一座小亭。灯亮以前盖在雾里。
func _place_north_hill() -> void:
	var gate := Vector2(73.0 * TS, 13.0 * TS)
	_prop("stone_arch", gate)
	_ground_shadow(gate + Vector2(0, -1), Px.tex(PixelArt.shadow(78, 8, 0.2)))
	for x in [70, 71, 74, 75]:
		_block(Vector2i(x, 12))
	for x in [70, 71, 74, 75]:
		_clue(Vector2i(x, 12), "石门。门楣上有字，被雾磨平了。往上是北岗。")
	_building("earth_shrine", 72, 6, 2, 1, false)
	_wall_clue(72, 6, 2, "土地祠。香炉里的灰是软的，像是刚有人来过。")
	_building("pavilion", 67, 7, 3, 2, false)
	_wall_clue(67, 7, 3, "亭子。石桌上刻着棋盘，棋子只摆了半盘。")
	_lamp_post(Vector2i(71, 7))
	_lamp_post(Vector2i(74, 7))
	_tree("plum0", Vector2i(78, 4))
	_tree("round2", Vector2i(78, 6))
	_tree("round1", Vector2i(68, 3))


## 南街西边：一口池塘、一条长凳、几盏灯。
func _place_southwest() -> void:
	_lake(Vector2(11.0, 44.0), 4.0, 3.0, 0.25, 149)
	_wide_prop("bench", Vector2i(14, 38), 2)
	_clue(Vector2i(10, 41), "池塘。水不流，岸上有一圈小脚印，是鸭子的。")
	for t: Vector2i in [Vector2i(21, 34), Vector2i(24, 45), Vector2i(21, 50)]:
		_lamp_post(t)


## 东市：广场灯亮了才有。铺石板、支摊子、摆缸罐。
func _place_market() -> void:
	_building("shop_teastall", 47, 16, 3, 1, false)
	_wall_clue(47, 16, 3, "茶摊。碗倒扣在板上，壶还温着。")
	_building("fish_market", 51, 16, 3, 1, false)
	_wall_clue(51, 16, 3, "鱼摊。案板刚刷过，鱼鳞贴在缝里。")
	_wide_prop("drying_rack", Vector2i(55, 15), 2, "竹匾里晒着干菜，边上压着一块石头。")
	_small_prop("pickle_vat", Vector2i(48, 22), "缸盖上压着石头，缸里是新腌的。")
	_small_prop("pickle_vat", Vector2i(49, 22), "缸盖上压着石头，缸里是新腌的。")
	_small_prop("wine_jar", Vector2i(51, 22), "酒坛封着红纸，纸角翘起来了，一股酒糟味。")
	_small_prop("jar_clay", Vector2i(52, 22), "空陶罐，罐底还有一圈没干的水印。")
	_wide_prop("bench", Vector2i(54, 22), 2)
	_lamp_post(Vector2i(47, 20))
	_lamp_post(Vector2i(56, 20))


# ---------------------------------------------------------------- 雾区

## 没亮灯的三块盖着雾；灯亮了就把那一块的雾退掉。
func _sync_zones() -> void:
	var key := ""
	for id in TownLand.open_zones():
		key += String(id) + ","
	if key == _zone_key:
		return
	_zone_key = key
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var any := false
	for z: Array in TownLand.ZONES:
		if TownLand.is_open(z[0]):
			continue
		any = true
		var rect: Rect2i = z[1]
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				img.set_pixel(x, y, Color(1, 1, 1, 1))
	if _zone_fog == null:
		_zone_fog = Sprite2D.new()
		_zone_fog.name = "ZoneFog"
		_zone_fog.centered = false
		_zone_fog.scale = Vector2(TS, TS)
		_zone_fog.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_zone_fog.z_index = 5
		var shader := Shader.new()
		shader.code = ZONE_FOG_SHADER
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter(&"tiles", Vector2(W, H))
		_zone_fog.material = mat
		add_child(_zone_fog)
	_zone_fog.texture = ImageTexture.create_from_image(img)
	_zone_fog.visible = any


## 头一回看见一块雾退了，说一句。一次说一块。
func _announce_zone() -> void:
	for id in TownLand.open_zones():
		var flag := StringName("town_zone_" + String(id))
		if GameState.has_flag(flag):
			continue
		GameState.set_flag(flag)
		EventBus.banner_requested.emit(TownLand.opened_text(id))
		return
