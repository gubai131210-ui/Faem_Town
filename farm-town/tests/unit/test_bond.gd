extends GutTest
## 年、灶君、饕餮、腓腓、耳鼠，以及结缘和带一只出门（决策 129）。


var _banner := ""


func before_each() -> void:
	SaveSystem.base_dir = "user://test_saves_bond"
	SaveSystem.reset_all()
	GameClock.day = 10
	GameClock.minutes = 600.0
	Weather.today = Weather.SUNNY
	EventBus.banner_requested.connect(_hear)


func after_each() -> void:
	if EventBus.banner_requested.is_connected(_hear):
		EventBus.banner_requested.disconnect(_hear)
	GameClock.day = 1
	GameClock.minutes = 600.0
	Weather.today = Weather.SUNNY


func _hear(text: String) -> void:
	_banner = text


func test_new_year_beast_backs_down_when_the_lamps_are_up() -> void:
	var quiet := _town()
	assert_false(quiet.call(&"_nian_out"), "平日镇东口没有年")
	assert_false(quiet.blocked(quiet.tile_center(Vector2i(43, 18))))
	GameClock.day = 96
	GameClock.minutes = 600.0
	var afternoon := _town()
	assert_false(afternoon.call(&"_nian_out"), "除夕白天还不出来")
	GameClock.minutes = 1200.0
	var night := _town()
	assert_true(night.call(&"_nian_out"))
	assert_false(night.blocked(night.spawn_position(&"from_farm")), "不挡进镇那一格")
	assert_true(night.blocked(night.tile_center(Vector2i(43, 18))))
	assert_eq(night.query_use(Database.item(&"old_sickle"), Vector2i(43, 18), GameMap.Facing.UP), &"interact")
	assert_eq(Bestiary.nian_need(), 4, "一盏灯都没有，要赶四次")
	for i in 4:
		night.perform(&"interact", null, Vector2i(43, 18))
	assert_true(Bestiary.known(&"nian"))
	assert_string_contains(Bestiary.line(&"nian"), "镇东口")
	assert_false(night.call(&"_nian_out"))
	SaveSystem.reset_all()
	GameClock.day = 96
	GameClock.minutes = 1200.0
	for id in ["plaza", "river", "pasture", "well", "east", "shrine"]:
		GameState.set_flag(Database.lamp(StringName(id)).flag())
	assert_eq(Bestiary.nian_need(), 1, "灯都亮了，赶一次就走")
	var bright := _town()
	bright.perform(&"interact", null, Vector2i(43, 18))
	assert_true(Bestiary.known(&"nian"))
	assert_string_contains(_banner, "满街")


func test_the_kitchen_god_forgives_one_missing_thing() -> void:
	var house := _house()
	assert_false(house.call(&"_zao_out"), "不是小寒，灶边没有人")
	GameState.inventory.add(&"cheese", 1)
	GameState.inventory.add(&"flour", 1)
	GameState.inventory.add(&"stone", 1)
	assert_eq(Crafting.experiment([&"cheese", &"flour", &"stone"]), &"odd_bowl")
	GameClock.day = 89
	var winter := _house()
	assert_true(winter.call(&"_zao_out"))
	assert_eq(winter.query_use(null, Vector2i(9, 3), GameMap.Facing.UP), &"interact")
	assert_eq(winter.query_use(Database.item(&"radish_soup"), Vector2i(10, 2), GameMap.Facing.UP), &"interact", "灶台还是做菜")
	GameState.inventory.add(&"radish_soup", 1)
	assert_eq(winter.query_use(Database.item(&"radish_soup"), Vector2i(9, 3), GameMap.Facing.UP), &"offer")
	winter.perform(&"offer", Database.item(&"radish_soup"), Vector2i(9, 3))
	assert_eq(GameState.inventory.count_of(&"radish_soup"), 0)
	assert_true(Bestiary.zaojun_helps())
	assert_string_contains(Bestiary.line(&"zaojun"), "试对")
	GameState.inventory.add(&"cheese", 1)
	GameState.inventory.add(&"flour", 1)
	GameState.inventory.add(&"stone", 1)
	assert_eq(Crafting.experiment([&"cheese", &"flour", &"stone"]), &"milk_cake")
	winter.perform(&"offer", Database.item(&"radish_soup"), Vector2i(9, 3))
	assert_string_contains(_banner, "已经祭过")


func test_the_feast_and_the_two_pets() -> void:
	var sea := _map(&"zhuhai")
	assert_eq(sea.query_use(Database.item(&"old_sickle"), Vector2i(17, 16), GameMap.Facing.UP), &"interact", "饕餮不吃打")
	assert_eq(sea.query_use(Database.item(&"old_sickle"), Vector2i(16, 20), GameMap.Facing.UP), &"attack")
	assert_gt(sea.find_path(Vector2i(16, 23), Vector2i(26, 12)).size(), 0, "它站在路中间，旁边还过得去")
	var dishes: Array[StringName] = [&"radish_soup", &"stir_greens", &"fried_egg", &"rice_bowl"]
	for id in dishes:
		GameState.inventory.add(id, 1)
		assert_eq(sea.query_use(Database.item(id), Vector2i(17, 16), GameMap.Facing.UP), &"offer")
		sea.perform(&"offer", Database.item(id), Vector2i(17, 16))
	assert_true(Bestiary.known(&"taotie"))
	assert_eq(GameState.inventory.count_of(&"radish_soup"), 0)
	assert_string_contains(Bestiary.line(&"taotie"), "四道")
	var gone := _map(&"zhuhai")
	assert_false(gone.call(&"_tao_out"))
	Weather.today = Weather.FOG
	var fog := _map(&"zhuhai")
	assert_true(fog.call(&"_fei_out"))
	fog.perform(&"interact", null, Vector2i(16, 14))
	assert_true(Bestiary.bonded(&"feifei"))
	assert_string_contains(Journal.page_text(6), "腓腓")
	var home := _house()
	assert_eq(home.query_use(null, Vector2i(2, 6), GameMap.Facing.UP), &"interact")
	home.perform(&"interact", null, Vector2i(2, 6))
	assert_eq(Bestiary.out_id(), &"feifei")
	assert_true(Bestiary.soothed())
	GameState.inventory.add(&"stone", 4)
	Mine.enter(1, 3)
	Mine.haul[&"stone"] = 4
	var lost := Mine.faint()
	assert_eq(lost[&"stone"], 1, "摸过以后，四块只丢一块")
	var hill := _map(&"houshan")
	assert_gt(hill.find_path(Vector2i(15, 20), Vector2i(15, 8)).size(), 0, "耳鼠只占路的一格")
	assert_eq(hill.query_use(null, Vector2i(16, 22), GameMap.Facing.UP), &"interact")
	GameState.inventory.add(&"radish_soup", 1)
	assert_eq(hill.query_use(Database.item(&"radish_soup"), Vector2i(16, 22), GameMap.Facing.UP), &"offer")
	hill.perform(&"offer", Database.item(&"radish_soup"), Vector2i(16, 22))
	assert_true(Bestiary.bonded(&"ershu"))
	assert_eq(GameState.inventory.count_of(&"radish_soup"), 0)
	home = _house()
	home.perform(&"interact", null, Vector2i(4, 6))
	assert_eq(Bestiary.out_id(), &"feifei", "一次只能带一只")
	assert_string_contains(_banner, "一只")
	assert_eq(Bestiary.greet_out(&"farm"), "摸了摸它。今天要是晕倒，丢的少一半。它回家了。")
	assert_eq(Bestiary.out_id(), &"", "在外面再按一下，腓腓回家")
	home = _house()
	home.perform(&"interact", null, Vector2i(4, 6))
	assert_eq(Bestiary.out_id(), &"ershu")
	assert_string_contains(Bestiary.dig(), "荠菜")
	assert_eq(GameState.inventory.count_of(&"shepherds_purse"), 1)
	assert_string_contains(Bestiary.dig(), "翻过")
	assert_eq(GameState.inventory.count_of(&"shepherds_purse"), 1)
	var face := Bestiary.portrait(&"ershu")
	assert_not_null(face)
	assert_gt(face.get_width(), 8)
	assert_null(Bestiary.portrait(&"nian"), "没见过的不给画")


func _town() -> OutdoorMap:
	return _map(&"town")


func _house() -> GameMap:
	var scene: PackedScene = load(SceneRouter.MAPS[&"farmhouse"])
	var map: GameMap = scene.instantiate()
	add_child_autofree(map)
	return map


func _map(id: StringName) -> OutdoorMap:
	var scene: PackedScene = load(SceneRouter.MAPS[id])
	var map: OutdoorMap = scene.instantiate()
	add_child_autofree(map)
	return map
