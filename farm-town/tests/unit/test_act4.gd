extends GutTest
## M6 第一批：第四幕（遗落层的铁盒、姜婆婆认出相片、东滩灯）、东滩地图、赶海、白鹭的画室。

const EAST_FOG := Vector2i(42, 16)
const EAST_EDGE := Vector2i(43, 16)
const EAST_LAMP := Vector2i(39, 15)

var _banners: Array[String] = []
var _dialogues: Array[String] = []


func before_each() -> void:
	SaveSystem.reset_all()
	Weather.today = &"sunny"
	Weather.yesterday = &"sunny"
	GameClock.minutes = 600.0
	GameClock.day = 1
	_banners.clear()
	_dialogues.clear()
	EventBus.banner_requested.connect(_on_banner)
	EventBus.dialogue_requested.connect(_on_dialogue)


func after_each() -> void:
	EventBus.banner_requested.disconnect(_on_banner)
	EventBus.dialogue_requested.disconnect(_on_dialogue)
	Mine.leave()
	SaveSystem.reset_all()
	Weather.today = &"sunny"
	Weather.yesterday = &"sunny"
	GameClock.running = false


func _on_banner(text: String) -> void:
	_banners.append(text)


func _on_dialogue(_path: String, title: String) -> void:
	_dialogues.append(title)


func _map(id: StringName) -> Node2D:
	var scene: PackedScene = load(SceneRouter.MAPS[id])
	var m: Node2D = scene.instantiate()
	add_child_autofree(m)
	return m


func _fill_bag() -> void:
	for i in GameState.inventory.size:
		if GameState.inventory.is_empty_slot(i):
			GameState.inventory._slots[i] = {"id": &"stone", "count": 99, "q": 0}


## 走一段对话，返回说过的话。
func _say(path: String, title: String) -> String:
	var res: Resource = load(path)
	var said := ""
	var line: Variant = await DialogueManager.get_next_dialogue_line(res, title)
	while line != null:
		said += str(line.text)
		var next: String = line.next_id
		if next == "end" or next == "":
			break
		line = await DialogueManager.get_next_dialogue_line(res, next)
	return said


# ---------------------------------------------------------------- 数据

func test_tables_are_valid() -> void:
	assert_eq(Database.validate(), PackedStringArray(), "数据表没有错")
	var lamp := Database.lamp(&"east")
	assert_eq(lamp.map, &"riverbank")
	assert_eq(lamp.relic, &"ferry_stub")
	for id: StringName in [&"miner_roster", &"family_photo", &"ferry_stub"]:
		assert_true(Database.has_relic(id), String(id))
		assert_eq(PixelArt.icon(Database.item(id).icon).get_size(), Vector2i(16, 16))
	for id: StringName in [&"clam", &"kelp", &"conch", &"oyster"]:
		assert_eq(Database.item(id).kind, &"forage")
		assert_eq(PixelArt.icon(Database.item(id).icon).get_size(), Vector2i(16, 16))
	assert_true(SceneRouter.MAPS.has(&"dongtan"))


func test_sand_is_painted_as_its_own_ground() -> void:
	var terrain := PackedByteArray()
	terrain.resize(16)
	for i in 16:
		terrain[i] = GroundArt.SAND if i % 4 >= 2 else GroundArt.GRASS
	var painted := GroundArt.paint(terrain, 4, 4, 0)
	var tbuf: PackedByteArray = painted["tbuf"]
	assert_eq(tbuf[8 * 64 + 56], GroundArt.SAND, "沙地中间是沙")
	assert_eq(tbuf[8 * 64 + 8], GroundArt.GRASS, "草地中间是草")
	var img: Image = painted["image"]
	assert_ne(img.get_pixel(56, 8), img.get_pixel(8, 8), "沙和草颜色不一样")


# ---------------------------------------------------------------- 遗落层的铁盒

func test_the_box_under_the_lamp_on_floor_25() -> void:
	assert_true(Mine.enter(Mine.BOX_FLOOR, 5))
	assert_false(Mine.box_waiting(), "灯没亮，看不见盒子")
	assert_false(Mine.take_box())
	assert_true(Mine.light_lamp())
	assert_true(Mine.box_waiting())
	assert_true(Mine.take_box())
	assert_eq(GameState.inventory.count_of(&"miner_roster"), 1)
	assert_eq(GameState.inventory.count_of(&"family_photo"), 1)
	assert_true(GameState.has_flag(&"relic_family_photo"))
	assert_false(Mine.box_waiting(), "只有一只盒子")
	assert_false(Mine.take_box())
	assert_eq(GameState.inventory.count_of(&"family_photo"), 1)


func test_other_lamps_have_no_box() -> void:
	assert_true(Mine.enter(5, 5))
	assert_true(Mine.light_lamp())
	assert_false(Mine.box_waiting())


func test_the_box_waits_while_the_bag_is_full() -> void:
	Mine.enter(Mine.BOX_FLOOR, 5)
	Mine.light_lamp()
	_fill_bag()
	GameState.inventory._slots[10] = {}
	assert_false(Mine.take_box(), "只空一格放不下两样")
	assert_true(Mine.box_waiting())
	GameState.inventory._slots[11] = {}
	assert_true(Mine.take_box())


func test_lighting_the_lamp_in_the_mine_opens_the_box() -> void:
	Mine.enter(Mine.BOX_FLOOR, 5)
	var m := _map(&"mine")
	m.call(&"perform", &"interact", null, Mine.current.lamp)
	assert_true(Mine.lamp_lit(Mine.BOX_FLOOR))
	assert_eq(GameState.inventory.count_of(&"family_photo"), 1)
	assert_true(_dialogues.has("act4_box"), "拿到盒子有一段旁白")


func test_an_old_save_with_the_lamp_already_lit_still_gets_the_box() -> void:
	Mine.lit.append(Mine.BOX_FLOOR)
	Mine.enter(Mine.BOX_FLOOR, 5)
	_fill_bag()
	var m := _map(&"mine")
	m.call(&"perform", &"interact", null, Mine.current.lamp)
	assert_string_contains(_banners[-1], "腾出两格")
	assert_false(GameState.has_flag(Mine.BOX_FLAG))
	GameState.inventory._slots[10] = {}
	GameState.inventory._slots[11] = {}
	m.call(&"perform", &"interact", null, Mine.current.lamp)
	assert_eq(GameState.inventory.count_of(&"miner_roster"), 1)
	m.call(&"perform", &"interact", null, Mine.current.lamp)
	assert_string_contains(_banners[-1], "井灯亮着", "拿过以后就是一盏普通的井灯")


func test_box_narration_exists() -> void:
	var said := await _say(Residents.COMMON_DIALOGUE, "act4_box")
	assert_string_contains(said, "囡囡周岁")
	said = await _say(Residents.COMMON_DIALOGUE, "lamp_east")
	assert_string_contains(said, "灯塔")


# ---------------------------------------------------------------- 姜婆婆

func test_jiang_recognises_the_photo_and_hands_over_the_stub() -> void:
	var path := Residents.dialogue_path(&"jiang")
	Residents.met[&"jiang"] = true
	var said := await _say(path, "daily")
	assert_false(said.contains("囡囡"), "没有相片就是平常的话")
	GameState.set_flag(&"relic_family_photo")
	said = await _say(path, "daily")
	assert_string_contains(said, "囡囡")
	assert_string_contains(said, "趁我还记得")
	assert_string_contains(said, "这是谁家的孩子", "说完她又忘了")
	assert_eq(GameState.inventory.count_of(&"ferry_stub"), 1)
	assert_true(GameState.has_flag(&"got_ferry_stub"))
	said = await _say(path, "daily")
	assert_false(said.contains("囡囡"), "只说一回")
	assert_eq(GameState.inventory.count_of(&"ferry_stub"), 1)


func test_jiang_keeps_the_stub_while_the_bag_is_full() -> void:
	var path := Residents.dialogue_path(&"jiang")
	Residents.met[&"jiang"] = true
	GameState.set_flag(&"relic_family_photo")
	_fill_bag()
	var said := await _say(path, "daily")
	assert_string_contains(said, "腾个地方")
	assert_false(GameState.has_flag(&"got_ferry_stub"))
	GameState.inventory._slots[10] = {}
	said = await _say(path, "again")
	assert_string_contains(said, "船票")
	assert_eq(GameState.inventory.count_of(&"ferry_stub"), 1)


func test_jiang_and_egret_talk_about_the_east_lamp_once() -> void:
	Residents.met[&"jiang"] = true
	Residents.met[&"egret"] = true
	GameState.set_flag(&"lamp_east")
	var said := await _say(Residents.dialogue_path(&"jiang"), "daily")
	assert_string_contains(said, "灯塔")
	said = await _say(Residents.dialogue_path(&"jiang"), "daily")
	assert_false(said.contains("梦见灯塔"))
	said = await _say(Residents.dialogue_path(&"egret"), "daily")
	assert_string_contains(said, "一模一样")
	said = await _say(Residents.dialogue_path(&"egret"), "daily")
	assert_false(said.contains("一模一样"))


# ---------------------------------------------------------------- 东滩灯

func test_east_road_is_fogged_until_the_lamp() -> void:
	var bank: OutdoorMap = _map(&"riverbank")
	assert_true(bank.blocked(GameMap.tile_center(EAST_FOG)), "往东的路被雾封着")
	assert_true(bank.trigger_at(EAST_EDGE).is_empty())
	assert_eq(bank.query_use(null, EAST_FOG, GameMap.Facing.RIGHT), &"interact")
	bank.perform(&"interact", null, EAST_FOG)
	assert_string_contains(_banners[-1], "咸味")
	assert_false(bank.find_path(Vector2i(15, 11), Vector2i(38, 16)).is_empty(), "从码头走得到灯跟前")
	assert_eq(bank.solid[bank.idx(EAST_LAMP)], 1, "灯挡路")
	watch_signals(EventBus)
	bank.perform(&"interact", null, EAST_LAMP)
	assert_signal_emitted_with_parameters(EventBus, "lamp_requested", [&"east"])


func test_lighting_the_east_lamp_opens_the_road() -> void:
	var bank: OutdoorMap = _map(&"riverbank")
	var lamp := Database.lamp(&"east")
	for item_id: StringName in Lamps.wanted(&"east"):
		Lamps.offer(&"east", item_id, 99)
	assert_true(Lamps.is_complete(&"east"))
	assert_true(Lamps.light(&"east"))
	bank.call(&"on_lamp_lit", &"east")
	assert_true(GameState.has_flag(lamp.flag()))
	assert_false(bank.blocked(GameMap.tile_center(EAST_FOG)))
	assert_eq(bank.trigger_at(EAST_EDGE).get("map"), &"dongtan")
	bank.perform(&"interact", null, EAST_LAMP)
	assert_string_contains(_banners[-1], "东滩灯")
	assert_eq(bank.spawn_facing(&"from_dongtan"), GameMap.Facing.LEFT)
	assert_false(bank.blocked(bank.spawn_position(&"from_dongtan")))
	assert_false(bank.blocked(bank.spawn_position(&"from_boat")), "坐船来还是落在码头上")


# ---------------------------------------------------------------- 东滩

func test_dongtan_has_sea_sand_and_a_pier() -> void:
	var beach: OutdoorMap = _map(&"dongtan")
	assert_eq(beach.fishing_water(Vector2i(42, 22)), &"sea")
	assert_eq(beach.fishing_water(Vector2i(20, 20)), &"")
	var pier: Array = beach.get(&"_pier")
	assert_eq(pier.size(), 5)
	for t: Vector2i in pier:
		assert_eq(beach.fishing_water(t), &"", "栈桥上不是水")
		assert_eq(beach.solid[beach.idx(t)], 0, "栈桥能走")
	var end: Vector2i = pier[pier.size() - 1]
	assert_eq(beach.fishing_water(end + Vector2i(1, 0)), &"sea", "栈桥头上对着海")
	var from := Vector2i(1, 14)
	assert_false(beach.blocked(beach.spawn_position(&"from_riverbank")))
	assert_eq(beach.trigger_at(Vector2i(0, 14)).get("map"), &"riverbank")
	assert_false(beach.find_path(from, end).is_empty(), "走得到栈桥头")
	assert_false(beach.find_path(from, Vector2i(36, 8)).is_empty(), "走得到灯塔门口")
	var rod := Database.item(&"rod")
	assert_eq(beach.query_use(rod, end + Vector2i(1, 0), GameMap.Facing.RIGHT), &"cast")
	var sea_fish := 0
	for id: StringName in Database.fish:
		if Database.fish[id].waters.has(&"sea"):
			sea_fish += 1
	assert_gt(sea_fish, 3, "海里有鱼可钓")


func test_dongtan_lighthouse_and_studio() -> void:
	var beach: OutdoorMap = _map(&"dongtan")
	assert_true(beach.blocked(GameMap.tile_center(Vector2i(36, 6))), "灯塔挡路")
	assert_eq(beach.query_use(null, Vector2i(36, 7), GameMap.Facing.UP), &"interact")
	beach.perform(&"interact", null, Vector2i(36, 7))
	assert_string_contains(_banners[-1], "灯塔")
	beach.perform(&"interact", null, Vector2i(12, 10))
	assert_string_contains(_banners[-1], "画室")
	beach.perform(&"interact", null, Vector2i(28, 20))
	assert_string_contains(_banners[-1], "画架")
	assert_eq(BeachArt.lighthouse().get_size(), Vector2i(40, 100))
	assert_ne(BeachArt.lighthouse(true).get_pixel(20, 18), BeachArt.lighthouse(false).get_pixel(20, 18), "亮着和黑着不一样")
	assert_eq(BeachArt.studio().get_size(), Vector2i(64, 56))


func test_beachcombing_only_gives_beach_things() -> void:
	var winter := Foraging.options(&"winter", 20, false, true)
	var summer := Foraging.options(&"summer", 8, false, true)
	var names: Array[StringName] = []
	for def in winter:
		names.append(def.item)
	assert_true(names.has(&"oyster") and names.has(&"clam"))
	names.clear()
	for def in summer:
		names.append(def.item)
	assert_true(names.has(&"clam") and names.has(&"conch") and names.has(&"kelp"))
	assert_false(names.has(&"oyster"), "牡蛎只有冬天有")
	for def in Foraging.options(&"summer", 8, false):
		assert_false(def.beach, "别的地图上不长赶海的东西")
	Foraging.pending[&"dongtan"] = 4
	var beach: OutdoorMap = _map(&"dongtan")
	assert_gt(Foraging.count_on(&"dongtan"), 0)
	var on_map: Dictionary = Foraging.items[&"dongtan"]
	for t: Vector2i in on_map:
		assert_eq(beach.terrain[beach.idx(t)], GroundArt.SAND, "落在沙滩上")
		assert_true([&"clam", &"kelp", &"conch", &"oyster"].has(on_map[t]))
		assert_eq(beach.query_use(null, t, GameMap.Facing.DOWN), &"harvest")
	var first: Vector2i = on_map.keys()[0]
	var id: StringName = on_map[first]
	beach.perform(&"harvest", null, first)
	assert_eq(GameState.inventory.count_of(id), 1)


func test_egret_moves_to_the_beach_after_the_lamp() -> void:
	var egret := Database.npc(&"egret")
	assert_eq(NpcSchedule.spot_at(egret, 600.0, &"sunny")["map"], &"town", "灯没亮还在镇上画")
	GameState.set_flag(&"lamp_east")
	var beach: OutdoorMap = _map(&"dongtan")
	for minutes: float in [600.0, 930.0]:
		var spot := NpcSchedule.spot_at(egret, minutes, &"sunny")
		assert_eq(spot["map"], &"dongtan")
		var tile: Vector2i = spot["tile"]
		assert_eq(beach.solid[beach.idx(tile)], 0, "她站的地方是空地")
		assert_false(beach.find_path(Vector2i(0, 14), tile).is_empty(), "从路口走得到")
	assert_eq(NpcSchedule.spot_at(egret, 800.0, &"sunny")["map"], &"town", "中午回茶馆")
	assert_eq(NpcSchedule.spot_at(egret, 600.0, &"rain")["map"], &"town", "下雨不去海边")
	assert_not_null(beach.call(&"_npc_of", &"egret"), "上午她在滩上")
	var said := await _say(Residents.dialogue_path(&"egret"), "daily")
	assert_string_contains(said, "一模一样")
