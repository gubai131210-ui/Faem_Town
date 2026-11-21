extends GutTest
## 后山：山祠再往上。夏天涨水、冬天结冰，雷雨有夔，旱天毕方点灯，月圆玉兔，秋天当康，山顶白泽（决策 127）。


func before_each() -> void:
	SaveSystem.base_dir = "user://test_saves_houshan"
	SaveSystem.reset_all()
	GameClock.day = 10
	GameClock.minutes = 600.0
	Weather.today = Weather.SUNNY


func test_the_shrine_path_climbs_and_the_seasons_open_the_stream() -> void:
	var hill := _outdoor(&"shanci")
	assert_eq(hill.trigger_at(Vector2i(17, 0))["map"], &"houshan")
	assert_gt(hill.find_path(Vector2i(21, 28), Vector2i(17, 1)).size(), 0, "从石阶走得到后山路口")
	var back: Vector2 = hill.spawn_position(&"from_houshan")
	assert_eq(hill.tile_of(back), Vector2i(17, 2), "下来不踩回出口")
	var spring := _hill()
	assert_true(spring.combat)
	assert_eq(spring.trigger_at(Vector2i(15, 47))["map"], &"shanci")
	assert_gt(spring.find_path(Vector2i(15, 20), Vector2i(15, 8)).size(), 0, "春秋从踏脚的石头过溪")
	assert_eq(spring.solid[spring.idx(Vector2i(4, 15))], 1, "旁边的溪过不去")
	assert_string_contains(spring.clue_at(Vector2i(14, 16)), "冬天")
	GameClock.day = 25
	var summer := _hill()
	assert_eq(summer.find_path(Vector2i(15, 20), Vector2i(15, 8)).size(), 0, "夏天水涨，过不去")
	assert_string_contains(summer.clue_at(Vector2i(15, 15)), "涨")
	GameClock.day = 73
	var winter := _hill()
	assert_eq(winter.solid[winter.idx(Vector2i(4, 15))], 0, "冬天溪冻上了")
	assert_gt(winter.find_path(Vector2i(4, 16), Vector2i(4, 14)).size(), 0, "冻上的溪走得过去")
	assert_string_contains(winter.clue_at(Vector2i(8, 15)), "冻")


func test_the_storm_the_drought_and_the_summit() -> void:
	var hill := _hill()
	assert_false(hill.kui_out())
	assert_eq(hill.clue_at(Vector2i(5, 20)), "崖洞。口子不大，里面黑着。")
	hill.perform(&"interact", null, Vector2i(16, 3))
	assert_true(Bestiary.seen(&"baize"))
	assert_false(Bestiary.known(&"baize"))
	Bestiary.hear(&"shanxiao")
	assert_string_contains(Bestiary.line(&"shanxiao"), "忌夜里")
	Weather.today = Weather.STORM
	assert_true(hill.kui_out())
	var sickle := Database.item(&"old_sickle")
	assert_eq(hill.query_use(sickle, Vector2i(23, 20), GameMap.Facing.UP), &"attack")
	assert_eq(hill.apply_hit(6), 24)
	assert_eq(hill.apply_hit(24), 0)
	assert_true(Bestiary.known(&"kui"))
	assert_false(hill.kui_out())
	assert_string_contains(Journal.page_text(6), "散了")
	GameClock.day = 25
	Weather.today = Weather.SUNNY
	var dry := _hill()
	assert_string_contains(dry.clue_at(Vector2i(8, 20)), "毕方")
	dry.perform(&"interact", null, Vector2i(8, 20))
	assert_true(Bestiary.known(&"bifang"))
	assert_string_contains(dry.clue_at(Vector2i(5, 20)), "点着")
	GameClock.day = 9
	GameClock.minutes = 1200.0
	var night := _hill()
	assert_string_contains(night.clue_at(Vector2i(12, 5)), "玉兔")
	night.perform(&"interact", null, Vector2i(12, 5))
	assert_string_contains(Journal.page_text(6), "药铺")
	GameClock.day = 49
	GameClock.minutes = 600.0
	var autumn := _hill()
	assert_string_contains(autumn.clue_at(Vector2i(26, 24)), "当康")
	autumn.perform(&"interact", null, Vector2i(26, 24))
	assert_string_contains(Bestiary.line(&"dangkang"), "好年成")
	assert_null(Bestiary.portrait(&"xingxing"), "没见过的不给画")
	var face := Bestiary.portrait(&"baize")
	assert_not_null(face)
	assert_gt(face.get_width(), 8)
	assert_eq(hill.fishing_water(Vector2i(18, 13)), &"")


func test_meeting_dangkang_adds_one_harvest_that_day() -> void:
	# 0.9 高于土豆的多收概率，平时只收 1 个
	var roll := 0.9
	assert_gt(roll, Database.crop(&"potato").extra_chance)
	var farm := Farming.state
	var t := Vector2i(4, 4)
	farm.till(t)
	farm.plant(t, &"potato")
	farm.crops[t]["days"] = Database.crop(&"potato").total_days()
	assert_eq(Farming.dangkang_day, -1)
	assert_eq(farm.yield_at(t, roll), 1, "没见过当康")
	var seen := 49
	GameClock.day = seen
	var hill := _hill()
	hill.perform(&"interact", null, Vector2i(26, 24))
	assert_eq(Farming.dangkang_day, seen)
	assert_eq(farm.yield_at(t, roll), 2, "见过当康的当天多收一个")
	var ledger_plot := FarmState.new()
	ledger_plot.till(t)
	ledger_plot.plant(t, &"potato")
	ledger_plot.crops[t]["days"] = Database.crop(&"potato").total_days()
	assert_eq(ledger_plot.yield_at(t, roll), 1, "账本的耕地不加")
	var young := Vector2i(6, 6)
	farm.till(young)
	farm.plant(young, &"potato")
	assert_eq(farm.yield_at(young, roll), 0, "没熟仍是 0")
	farm.crops[t]["giant"] = true
	assert_eq(farm.yield_at(t, roll), 4, "巨型不加")
	farm.crops[t]["giant"] = false
	GameClock.day = seen + 1
	assert_eq(farm.yield_at(t, roll), 1, "第二天不再加")
	var packed: Dictionary = JSON.parse_string(JSON.stringify(Farming.save_data()))
	Farming.reset_data()
	assert_eq(Farming.dangkang_day, -1)
	assert_false(farm.has_crop(t))
	Farming.load_data(packed)
	GameClock.day = seen
	assert_eq(Farming.dangkang_day, seen)
	assert_eq(farm.yield_at(t, roll), 2, "存档再读，这一天的加成还在")
	packed.erase("dangkang_day")
	Farming.load_data(packed)
	assert_eq(Farming.dangkang_day, -1)
	assert_eq(farm.yield_at(t, roll), 1, "旧档没有这一项，当成没见过")


func _hill() -> OutdoorMap:
	return _outdoor(&"houshan")


func _outdoor(id: StringName) -> OutdoorMap:
	var scene: PackedScene = load(SceneRouter.MAPS[id])
	var map: OutdoorMap = scene.instantiate()
	add_child_autofree(map)
	return map
