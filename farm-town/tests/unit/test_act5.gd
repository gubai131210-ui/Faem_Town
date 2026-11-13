extends GutTest
## M6 第二批：第五幕（雾里的白鹿、柏先生坦白、山祠灯）、山祠地图、岚、无光层要等山祠灯。

const HILL_FOG := Vector2i(24, 1)
const HILL_EDGE := Vector2i(24, 0)
const HILL_LAMP := Vector2i(26, 4)
const DEER := Vector2i(24, 4)
const LAN_PATH := "res://dialogue/lan.dialogue"

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


func _light_shrine() -> void:
	for item_id: StringName in Lamps.wanted(&"shrine"):
		Lamps.offer(&"shrine", item_id, 99)
	assert_true(Lamps.light(&"shrine"))


# ---------------------------------------------------------------- 数据和素材

func test_tables_are_valid() -> void:
	assert_eq(Database.validate(), PackedStringArray(), "数据表没有错")
	var lamp := Database.lamp(&"shrine")
	assert_eq(lamp.map, &"pasture")
	assert_eq(lamp.relic, &"prayer_tablet")
	assert_true(Database.has_relic(&"prayer_tablet"))
	assert_eq(PixelArt.icon(Database.item(&"prayer_tablet").icon).get_size(), Vector2i(16, 16))
	assert_true(SceneRouter.MAPS.has(&"shanci"))
	assert_true(Foraging.MAPS.has(&"shanci"))


func test_shrine_art() -> void:
	assert_eq(ShrineArt.shrine().get_size(), Vector2i(88, 80))
	assert_eq(ShrineArt.plaque_rack().get_size(), Vector2i(36, 26))
	assert_eq(ShrineArt.deer(0).get_size(), Vector2i(48, 46))
	assert_ne(ShrineArt.deer(0).get_data(), ShrineArt.deer(1).get_data(), "两帧不一样")
	assert_ne(ShrineArt.osmanthus(2).get_data(), ShrineArt.osmanthus(0).get_data(), "秋天开花")
	assert_ne(ShrineArt.osmanthus(3).get_data(), ShrineArt.osmanthus(0).get_data(), "冬天落雪")


func test_narrations_exist() -> void:
	var said := await _say(Residents.COMMON_DIALOGUE, "lamp_shrine")
	assert_string_contains(said, "石阶")


# ---------------------------------------------------------------- 无光层的雾

func test_the_dark_floors_wait_for_the_shrine_lamp() -> void:
	Mine.bosses.append(30)
	assert_true(Mine.enter(30, 3))
	Mine.current.ladder_found = true
	assert_true(Mine.deep_closed())
	assert_true(Mine.ladder_fogged())
	assert_false(Mine.descend(), "山祠灯没亮，第 30 层下不去")
	assert_eq(Mine.floor_no, 30)
	GameState.set_flag(&"lamp_shrine")
	assert_false(Mine.ladder_fogged())
	assert_true(Mine.descend())
	assert_eq(Mine.floor_no, 31)


func test_shallower_ladders_are_not_fogged() -> void:
	assert_true(Mine.enter(29, 3))
	Mine.current.ladder_found = true
	assert_false(Mine.ladder_fogged())
	assert_true(Mine.descend())
	assert_eq(Mine.floor_no, 30)


func test_old_saves_that_went_deeper_are_not_locked_out() -> void:
	Mine.deepest = 36
	Mine.bosses.append(30)
	Mine.enter(30, 3)
	Mine.current.ladder_found = true
	assert_false(Mine.deep_closed())
	assert_true(Mine.descend())


func test_the_fogged_ladder_says_so() -> void:
	Mine.bosses.append(30)
	Mine.enter(30, 3)
	Mine.current.ladder_found = true
	var m := _map(&"mine")
	m.call(&"entered")
	assert_string_contains(_banners[-1], "冒着雾")
	m.call(&"perform", &"interact", null, Mine.current.ladder)
	assert_string_contains(_banners[-1], "山上来的")
	assert_eq(Mine.floor_no, 30)


# ---------------------------------------------------------------- 牧场上的山路和白鹿

func test_hill_path_is_fogged_until_the_lamp() -> void:
	var pasture: OutdoorMap = _map(&"pasture")
	assert_true(pasture.blocked(GameMap.tile_center(HILL_FOG)), "上山的路被雾封着")
	assert_true(pasture.trigger_at(HILL_EDGE).is_empty())
	assert_eq(pasture.query_use(null, HILL_FOG, GameMap.Facing.UP), &"interact")
	pasture.perform(&"interact", null, HILL_FOG)
	assert_string_contains(_banners[-1], "一步也看不清")
	assert_false(pasture.find_path(Vector2i(42, 14), Vector2i(24, 5)).is_empty(), "从路口走得到山路底下")
	assert_eq(pasture.solid[pasture.idx(HILL_LAMP)], 1, "灯挡路")
	assert_false(pasture.blocked(pasture.spawn_position(&"from_town")), "从镇上来还是落在路上")
	watch_signals(EventBus)
	pasture.perform(&"interact", null, HILL_LAMP)
	assert_signal_emitted_with_parameters(EventBus, "lamp_requested", [&"shrine"])


func test_hoofprints_hint_after_the_east_lamp() -> void:
	GameState.set_flag(&"lamp_east")
	var pasture: OutdoorMap = _map(&"pasture")
	assert_false(pasture.call(&"lan_waiting"), "晴天白鹿不来")
	assert_eq(pasture.solid[pasture.idx(DEER)], 0)
	assert_false(pasture.blocked(GameMap.tile_center(DEER)))
	pasture.perform(&"interact", null, HILL_FOG)
	assert_string_contains(_banners[-1], "蹄印")
	assert_string_contains(_banners[-1], "起雾的日子")


func test_the_deer_waits_in_the_fog_and_leaves_once_met() -> void:
	Weather.today = &"fog"
	var early: OutdoorMap = _map(&"pasture")
	assert_false(early.call(&"lan_waiting"), "东滩灯没亮它不来")
	GameState.set_flag(&"lamp_east")
	var pasture: OutdoorMap = _map(&"pasture")
	assert_true(pasture.call(&"lan_waiting"))
	assert_not_null(pasture.get(&"_lan"))
	assert_true(pasture.blocked(GameMap.tile_center(DEER)), "它站的地方走不过去")
	assert_eq(pasture.query_use(null, DEER, GameMap.Facing.UP), &"interact")
	pasture.perform(&"interact", null, DEER)
	assert_eq(_dialogues[-1], "meet")
	var said := await _say(LAN_PATH, "meet")
	assert_string_contains(said, "柏先生")
	assert_true(GameState.has_flag(&"met_lan"))
	await wait_process_frames(4)
	assert_null(pasture.get(&"_lan"), "见过以后它走了")
	assert_false(pasture.blocked(GameMap.tile_center(DEER)))
	pasture.perform(&"interact", null, HILL_FOG)
	assert_string_contains(_banners[-1], "石灯还黑着")


func test_lighting_the_shrine_lamp_opens_the_hill() -> void:
	var pasture: OutdoorMap = _map(&"pasture")
	_light_shrine()
	pasture.call(&"on_lamp_lit", &"shrine")
	assert_true(GameState.has_flag(&"lamp_shrine"))
	assert_false(pasture.blocked(GameMap.tile_center(HILL_FOG)))
	assert_eq(pasture.trigger_at(HILL_EDGE).get("map"), &"shanci")
	pasture.perform(&"interact", null, HILL_LAMP)
	assert_string_contains(_banners[-1], "山祠灯")
	assert_eq(pasture.spawn_facing(&"from_shanci"), GameMap.Facing.DOWN)
	assert_false(pasture.blocked(pasture.spawn_position(&"from_shanci")))
	assert_eq(pasture.spawn_facing(&"from_town"), GameMap.Facing.LEFT)


# ---------------------------------------------------------------- 柏先生

func test_bai_will_not_talk_about_it_to_a_stranger() -> void:
	var path := Residents.dialogue_path(&"bai")
	Residents.met[&"bai"] = true
	var said := await _say(path, "daily")
	assert_false(said.contains("白鹿"), "没见过鹿就是平常的话")
	GameState.set_flag(&"met_lan")
	said = await _say(path, "daily")
	assert_string_contains(said, "白鹿")
	assert_string_contains(said, "改日")
	said = await _say(path, "daily")
	assert_string_contains(said, "不是今天")
	assert_eq(GameState.inventory.count_of(&"prayer_tablet"), 0)


func test_bai_confesses_and_hands_over_the_tablet() -> void:
	var path := Residents.dialogue_path(&"bai")
	Residents.met[&"bai"] = true
	Residents.add_familiarity(&"bai", 40)
	GameState.set_flag(&"met_lan")
	var said := await _say(path, "daily")
	assert_string_contains(said, "二十七个人")
	assert_string_contains(said, "让大家别这么疼")
	assert_eq(GameState.inventory.count_of(&"prayer_tablet"), 1)
	assert_true(GameState.has_flag(&"got_prayer_tablet"))
	said = await _say(path, "daily")
	assert_false(said.contains("二十七个人"), "只说一回")
	assert_eq(GameState.inventory.count_of(&"prayer_tablet"), 1)


func test_bai_keeps_the_tablet_while_the_bag_is_full() -> void:
	var path := Residents.dialogue_path(&"bai")
	Residents.met[&"bai"] = true
	Residents.add_familiarity(&"bai", 40)
	GameState.set_flag(&"met_lan")
	_fill_bag()
	var said := await _say(path, "daily")
	assert_string_contains(said, "腾个地方")
	assert_false(GameState.has_flag(&"got_prayer_tablet"))
	said = await _say(path, "again")
	assert_false(said.contains("二十七个人"), "坦白的话不重说")
	assert_string_contains(said, "腾个地方")
	GameState.inventory._slots[10] = {}
	said = await _say(path, "again")
	assert_string_contains(said, "拿着")
	assert_eq(GameState.inventory.count_of(&"prayer_tablet"), 1)


func test_bai_talks_about_the_shrine_lamp_once() -> void:
	Residents.met[&"bai"] = true
	GameState.set_flag(&"got_prayer_tablet")
	_light_shrine()
	var said := await _say(Residents.dialogue_path(&"bai"), "daily")
	assert_string_contains(said, "山上的灯亮了")
	said = await _say(Residents.dialogue_path(&"bai"), "daily")
	assert_false(said.contains("山上的灯亮了"))


# ---------------------------------------------------------------- 山祠

func test_shanci_has_steps_a_shrine_and_a_lake() -> void:
	var hill: OutdoorMap = _map(&"shanci")
	var from := Vector2i(21, 28)
	assert_false(hill.blocked(hill.spawn_position(&"from_pasture")))
	assert_eq(hill.spawn_facing(&"from_pasture"), GameMap.Facing.UP)
	assert_eq(hill.trigger_at(Vector2i(21, 29)).get("map"), &"pasture")
	assert_eq(hill.trigger_at(Vector2i(22, 29)).get("spawn"), &"from_shanci")
	assert_false(hill.find_path(from, Vector2i(21, 10)).is_empty(), "走得到祠门口")
	assert_true(hill.blocked(GameMap.tile_center(Vector2i(21, 8))), "古祠挡路")
	assert_eq(hill.query_use(null, Vector2i(21, 9), GameMap.Facing.UP), &"interact")
	hill.perform(&"interact", null, Vector2i(21, 9))
	assert_string_contains(_banners[-1], "古祠")
	assert_string_contains(_banners[-1], "蹄印", "不起雾的日子只看得见蹄印")
	hill.perform(&"interact", null, Vector2i(16, 10))
	assert_string_contains(_banners[-1], "木牌")
	assert_eq(hill.fishing_water(Vector2i(35, 19)), &"lake")
	assert_eq(hill.fishing_water(Vector2i(21, 12)), &"")
	var shore := Vector2i(-1, -1)
	for x in range(26, 35):
		if hill.fishing_water(Vector2i(x + 1, 19)) == &"lake":
			shore = Vector2i(x, 19)
			break
	assert_ne(shore, Vector2i(-1, -1))
	assert_false(hill.find_path(from, shore).is_empty(), "走得到湖边")
	assert_eq(hill.query_use(Database.item(&"rod"), shore + Vector2i(1, 0), GameMap.Facing.RIGHT), &"cast")
	var lake_fish := 0
	for id: StringName in Database.fish:
		if Database.fish[id].waters.has(&"lake"):
			lake_fish += 1
	assert_gt(lake_fish, 2, "湖里有鱼可钓")


func test_osmanthus_grove() -> void:
	var hill: OutdoorMap = _map(&"shanci")
	var tree := Vector2i(9, 14)
	assert_true(hill.blocked(GameMap.tile_center(tree)))
	assert_eq(hill.query_use(null, tree, GameMap.Facing.UP), &"interact")
	hill.perform(&"interact", null, tree)
	assert_string_contains(_banners[-1], "桂花树")
	assert_false(hill.find_path(Vector2i(21, 28), Vector2i(9, 15)).is_empty(), "走得进桂花林")


func test_forage_grows_on_the_hill() -> void:
	Foraging.pending[&"shanci"] = 4
	var hill: OutdoorMap = _map(&"shanci")
	assert_gt(Foraging.count_on(&"shanci"), 0)
	var on_map: Dictionary = Foraging.items[&"shanci"]
	for t: Vector2i in on_map:
		assert_eq(hill.query_use(null, t, GameMap.Facing.DOWN), &"harvest")
		assert_false([&"clam", &"kelp", &"conch", &"oyster"].has(on_map[t]), "山上不长赶海的东西")


func test_lan_only_comes_out_in_fog() -> void:
	var hill: OutdoorMap = _map(&"shanci")
	var at: Vector2i = hill.get(&"LAN_TILE")
	assert_null(hill.get(&"_lan"), "晴天岚不在")
	assert_false(hill.blocked(GameMap.tile_center(at)))
	assert_eq(hill.query_use(null, at, GameMap.Facing.UP), &"")
	Weather.today = &"fog"
	await wait_process_frames(4)
	assert_not_null(hill.get(&"_lan"), "起雾了它就在祠前")
	assert_true(hill.blocked(GameMap.tile_center(at)))
	assert_false(hill.find_path(Vector2i(21, 28), at + Vector2i(0, 1)).is_empty(), "走得到它跟前")
	assert_eq(hill.query_use(null, at, GameMap.Facing.UP), &"interact")
	hill.perform(&"interact", null, Vector2i(21, 9))
	assert_false(_banners[-1].contains("蹄印"))
	Weather.today = &"sunny"
	await wait_process_frames(4)
	assert_null(hill.get(&"_lan"), "雾散了它也走了")


func test_talking_to_lan() -> void:
	Weather.today = &"fog"
	GameClock.day = 7
	var hill: OutdoorMap = _map(&"shanci")
	var at: Vector2i = hill.get(&"LAN_TILE")
	hill.perform(&"interact", null, at)
	assert_eq(_dialogues[-1], "first")
	var said := await _say(LAN_PATH, "first")
	assert_string_contains(said, "让大家别这么疼")
	assert_true(GameState.has_flag(&"lan_talked"))
	hill.perform(&"interact", null, at)
	assert_eq(_dialogues[-1], "again", "当天再说")
	GameClock.day = 8
	hill.perform(&"interact", null, at)
	assert_eq(_dialogues[-1], "daily", "第二天又是新的一段")
	hill.perform(&"interact", null, at)
	assert_eq(_dialogues[-1], "again")
	said = await _say(LAN_PATH, "daily")
	assert_false(said.contains("井底"))
	assert_gt(said.length(), 8)
	said = await _say(LAN_PATH, "again")
	assert_gt(said.length(), 0)


func test_lan_knows_the_shade_at_the_bottom() -> void:
	GameState.set_flag(&"lan_talked")
	GameState.set_flag(&"boss_shade")
	var said := await _say(LAN_PATH, "daily")
	assert_string_contains(said, "别让灯灭")
	said = await _say(LAN_PATH, "daily")
	assert_false(said.contains("别让灯灭"), "只说一回")
