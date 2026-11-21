extends GutTest
## M16 第二批：稻草防霜、挖果树要再按一次、一天能调慢（决策 134）。


const TMP := "user://test_saves_safeguards"
const CROP := Vector2i(16, 12)
const TREE := Vector2i(20, 22)
const RICE := Vector2i(18, 12)


func before_each() -> void:
	SaveSystem.base_dir = TMP
	SaveSystem.reset_all()
	GameClock.running = false
	GameClock.minutes = 600.0


func after_each() -> void:
	GameClock.running = false
	GameClock.set_slow_day(false)
	SaveSystem.base_dir = "user://saves"
	SaveSystem.reset_all()


func test_straw_keeps_one_crop_through_frost() -> void:
	var farm := FarmState.new()
	var bare := Vector2i(4, 3)
	farm.till(CROP)
	farm.till(bare)
	farm.plant(CROP, &"pumpkin")
	farm.plant(bare, &"pumpkin")
	assert_false(farm.cover(Vector2i(1, 1)))
	assert_true(farm.cover(CROP))
	assert_false(farm.cover(CROP), "盖过了不再盖一次")
	farm.advance_day(&"autumn", &"sunny", false, false, true)
	assert_false(farm.is_dead(CROP), "盖着稻草冻不着")
	assert_true(farm.is_dead(bare))
	farm.advance_day(&"winter", &"sunny", false, false, true)
	assert_true(farm.is_dead(CROP), "换季照样枯，稻草不挡这个")
	var again := Vector2i(6, 3)
	farm.till(again)
	farm.plant(again, &"tomato")
	farm.cover(again)
	farm.crops[again]["days"] = 99
	assert_eq(farm.harvest(again), &"tomato")
	assert_true(farm.has_crop(again), "能再收的还留着")
	assert_false(farm.is_covered(again), "收到就把稻草揭了")
	assert_eq(Database.crop(&"rice").bonus_produce, &"straw")
	var straw := Database.item(&"straw")
	assert_eq(straw.price, 0)
	assert_false(straw.sellable())
	assert_false(Residents.is_giftable(straw))
	var icon := PixelArt.icon("product:straw")
	assert_false(icon.is_invisible())
	assert_ne(icon.get_data(), PixelArt.icon("product:hay").get_data())


func test_cover_survives_saving_and_old_saves_stay_bare() -> void:
	var farm := FarmState.new()
	farm.till(CROP)
	farm.plant(CROP, &"pumpkin")
	farm.cover(CROP)
	var data: Variant = JSON.parse_string(JSON.stringify(farm.to_dict()))
	var copy := FarmState.new()
	copy.from_dict(data)
	assert_true(copy.is_covered(CROP))
	copy.from_dict({"soil": [[16, 12, false]], "crops": [[16, 12, "pumpkin", 2]]})
	assert_false(copy.is_covered(CROP), "旧存档没有这一格，就是没盖")


func test_a_slow_day_takes_twice_as_long() -> void:
	GameClock.running = true
	GameClock.minutes = 400.0
	GameClock.set_slow_day(false)
	GameClock._process(0.05)
	var fast := GameClock.minutes - 400.0
	GameClock.minutes = 400.0
	GameClock.set_slow_day(true)
	GameClock._process(0.05)
	assert_almost_eq(GameClock.minutes - 400.0, fast * 0.5, 0.001)
	var saved: Dictionary = GameClock.save_data()
	GameClock.set_slow_day(false)
	GameClock.load_data(saved)
	assert_true(GameClock.is_slow(), "慢日子写进存档")
	GameClock.load_data({"day": 3, "minutes": 500})
	assert_false(GameClock.is_slow(), "旧存档仍是平常的速度")
	GameClock.reset_data()
	assert_false(GameClock.is_slow())


func test_pause_menu_switches_the_day_speed() -> void:
	var menu := PauseMenu.new()
	add_child_autofree(menu)
	menu.open()
	var pace: Button = menu.get(&"_pace")
	assert_eq(pace.text, "一天：平常")
	pace.pressed.emit()
	assert_true(GameClock.is_slow())
	assert_eq(pace.text, "一天：慢")
	pace.pressed.emit()
	assert_false(GameClock.is_slow())
	assert_eq(pace.text, "一天：平常")
	await get_tree().process_frame
	var panel: Control = menu.get(&"_panel")
	var spot := pace.get_global_rect()
	assert_gt(spot.size.y, 10.0)
	assert_true(panel.get_global_rect().encloses(spot.grow(-1.0)), "调速的按钮在面板里面")


func test_the_farm_covers_crops_and_asks_before_digging_a_tree() -> void:
	var map := _farm()
	_clear(CROP)
	Farming.state.till(CROP)
	Farming.state.plant(CROP, &"pumpkin")
	GameState.inventory.add(&"straw", 2)
	var straw := Database.item(&"straw")
	assert_eq(map.call("query_use", straw, CROP, GameMap.Facing.DOWN), &"place")
	watch_signals(EventBus)
	map.call("perform", &"place", straw, CROP)
	assert_true(Farming.state.is_covered(CROP))
	assert_eq(GameState.inventory.count_of(&"straw"), 1)
	map.call("perform", &"place", straw, CROP)
	assert_eq(GameState.inventory.count_of(&"straw"), 1, "已经盖着就不再收一份")
	assert_string_contains(str(get_signal_parameters(EventBus, "banner_requested", 1)), "已经盖着")
	_clear(RICE)
	Farming.state.till(RICE)
	Farming.state.crops[RICE] = {"crop": &"rice", "days": 99, "dead": false, "bonus": 0, "wilt": false}
	var rice_had := GameState.inventory.count_of(&"rice")
	var straw_had := GameState.inventory.count_of(&"straw")
	map.call("perform", &"harvest", null, RICE)
	assert_gt(GameState.inventory.count_of(&"rice"), rice_had)
	assert_eq(GameState.inventory.count_of(&"straw"), straw_had + 1, "收水稻带一把稻草")
	_clear(TREE)
	assert_true(Farming.orchard.plant(TREE, &"peach"))
	Farming.orchard.trees[TREE]["fruit"] = 1
	Farming.orchard.trees[TREE]["item"] = &"peach_blossom"
	var shovel := Database.item(&"shovel")
	assert_eq(map.call("query_use", shovel, TREE, GameMap.Facing.DOWN), &"harvest", "树上有花先收")
	Farming.orchard.trees[TREE]["fruit"] = 0
	assert_eq(map.call("query_use", shovel, TREE, GameMap.Facing.DOWN), &"interact")
	map.call("perform", &"interact", shovel, TREE)
	assert_true(Farming.orchard.has(TREE), "问过还在")
	assert_string_contains(str(get_signal_parameters(EventBus, "banner_requested", 2)), "再按一次")
	assert_eq(map.call("query_use", shovel, TREE, GameMap.Facing.DOWN), &"dig")
	map.call("perform", &"dig", shovel, TREE)
	assert_false(Farming.orchard.has(TREE))
	Farming.state.till(CROP)
	Farming.state.plant(CROP, &"pumpkin")
	assert_eq(map.call("query_use", shovel, CROP, GameMap.Facing.DOWN), &"dig")
	map.call("perform", &"dig", shovel, CROP)
	assert_false(Farming.state.has_crop(CROP), "庄稼一铲就掉，不用问")


func _farm() -> Node:
	var scene: PackedScene = load(SceneRouter.MAPS[&"farm"])
	var map: Node = scene.instantiate()
	add_child_autofree(map)
	return map


func _clear(tile: Vector2i) -> void:
	if Foraging.item_at(&"farm", tile) != &"":
		Foraging.take(&"farm", tile)
