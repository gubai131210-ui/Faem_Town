extends GutTest
## 灶上这一场：下锅、看火、出锅（决策 101）。


func before_each() -> void:
	SaveSystem.reset_all()
	Weather.today = &"sunny"
	GameClock.minutes = 600.0
	GameClock.day = 1


func _to_heat(h: CookHeat) -> void:
	while h.phase == CookHeat.DROP:
		h.advance(0.05)


func test_ingredients_drop_one_by_one_then_fire_rises() -> void:
	var h := CookHeat.new()
	h.start(3, 3.0, true)
	assert_eq(h.phase, CookHeat.DROP)
	assert_eq(h.dropped(), 1)
	assert_eq(h.fire_level(), 0)
	h.advance(CookHeat.DROP_EACH * 1.5)
	assert_eq(h.dropped(), 2)
	assert_almost_eq(h.drop_progress(0), 1.0, 0.01)
	assert_almost_eq(h.drop_progress(1), 0.5, 0.01)
	assert_almost_eq(h.drop_progress(2), 0.0, 0.01)
	h.advance(CookHeat.DROP_EACH * 1.6)
	assert_eq(h.phase, CookHeat.HEAT)
	assert_eq(h.fire_level(), 1)
	h.advance(3.0 * 0.7)
	assert_eq(h.fire_level(), 2, "火候到了火是旺的")


func test_pressing_early_loses_nothing_and_can_try_again() -> void:
	var h := CookHeat.new()
	h.start(1, 2.0, true)
	_to_heat(h)
	h.advance(0.2)
	assert_eq(h.press(), &"early")
	assert_true(h.early_shown())
	assert_eq(h.phase, CookHeat.HEAT, "按早了锅还在灶上")
	h.advance(2.0 * 0.6)
	assert_true(h.in_sweet())
	assert_eq(h.press(), &"just")
	assert_true(h.just)
	assert_eq(h.phase, CookHeat.SERVE)


func test_never_pressing_still_serves_a_plain_dish() -> void:
	var h := CookHeat.new()
	h.start(2, 1.0, true)
	for i in 400:
		h.advance(0.02)
	assert_eq(h.phase, CookHeat.OVER, "不按也会自己走完")
	assert_false(h.just)


func test_late_press_is_ignored_and_serve_press_closes() -> void:
	var h := CookHeat.new()
	h.start(0, 1.0, true)
	assert_eq(h.phase, CookHeat.HEAT, "没有材料直接看火")
	h.advance(0.95)
	assert_false(h.in_sweet())
	assert_eq(h.press(), &"")
	h.advance(0.1)
	assert_eq(h.phase, CookHeat.SERVE)
	assert_eq(h.press(), &"close")
	assert_eq(h.phase, CookHeat.OVER)


func test_no_watch_means_no_sweet_spot() -> void:
	var h := CookHeat.new()
	h.start(1, 1.0, false)
	_to_heat(h)
	h.advance(0.7)
	assert_false(h.in_sweet())
	assert_eq(h.press(), &"")
	assert_false(h.just)


func test_heat_mark_is_kept_in_save_and_changes_nothing_else() -> void:
	assert_false(Crafting.has_heat(&"radish_soup"))
	Crafting.mark_heat(&"radish_soup")
	Crafting.mark_heat(&"radish_soup")
	Crafting.mark_heat(&"no_such_dish")
	assert_eq(Crafting.heat_dishes.size(), 1)
	assert_eq(Crafting.made_dishes.size(), 0, "火候印不算做过")
	var saved := Crafting.save_data()
	Crafting.reset_data()
	assert_false(Crafting.has_heat(&"radish_soup"))
	Crafting.load_data(JSON.parse_string(JSON.stringify(saved)))
	assert_true(Crafting.has_heat(&"radish_soup"))
	Crafting.load_data({"jobs": {}})
	assert_false(Crafting.has_heat(&"radish_soup"), "旧存档没有火候印")


func test_fond_of_names_someone_met_who_loves_an_ingredient() -> void:
	var who := &""
	var dish := &""
	for rid: StringName in Database.recipes:
		var rec: RecipeDef = Database.recipes[rid]
		for nid: StringName in Database.npcs:
			for item_id: StringName in rec.ingredients:
				if Database.npc(nid).loves.has(item_id):
					who = nid
					dish = rid
	assert_ne(dish, &"", "总有一道菜的材料是谁的心头好")
	assert_eq(Crafting.fond_of(dish), "", "还没见过面，不念名字")
	for nid: StringName in Database.npcs:
		Residents.met[nid] = true
	assert_ne(Crafting.fond_of(dish), "")
	assert_eq(Crafting.fond_of(&"no_such_dish"), "")
	assert_ne(who, &"")


func test_preview_only_plays_and_writes_nothing() -> void:
	var show := CookShow.new()
	add_child_autofree(show)
	show.open(&"tomato_egg", true)
	assert_true(show.is_open())
	assert_false(Crafting.made_dishes.has(&"tomato_egg"))
	assert_eq(GameState.inventory.count_of(&"tomato_egg"), 0)
	var use := InputEventAction.new()
	use.action = &"use"
	use.pressed = true
	var guard := 0
	while not show._heat.in_sweet() and guard < 2000:
		show._process(0.02)
		guard += 1
	show._input(use)
	assert_false(Crafting.has_heat(&"tomato_egg"))
	show.close()
	assert_false(show.is_open())
	assert_false(Crafting.made_dishes.has(&"tomato_egg"))


func test_show_opens_on_the_stage_and_cancel_skips_keeping_the_dish() -> void:
	var show := CookShow.new()
	add_child_autofree(show)
	GameState.inventory.add(&"white_radish", 2)
	assert_true(Crafting.cook(&"radish_soup"))
	show.open(&"radish_soup")
	assert_true(show.is_open())
	assert_eq(show.phase(), CookHeat.DROP)
	assert_true(Crafting.made_dishes.has(&"radish_soup"), "一打开就记了做过")
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	show._input(cancel)
	assert_false(show.is_open())
	assert_eq(GameState.inventory.count_of(&"radish_soup"), 1)
	assert_false(Crafting.has_heat(&"radish_soup"))


func test_show_use_in_the_sweet_spot_leaves_the_heat_mark() -> void:
	var show := CookShow.new()
	add_child_autofree(show)
	show.open(&"radish_soup")
	var use := InputEventAction.new()
	use.action = &"use"
	use.pressed = true
	var guard := 0
	while not show._heat.in_sweet() and guard < 2000:
		show._process(0.02)
		guard += 1
	assert_true(show._heat.in_sweet())
	show._input(use)
	assert_true(Crafting.has_heat(&"radish_soup"))
	assert_eq(show.phase(), CookHeat.SERVE)
	show._input(use)
	assert_false(show.is_open(), "盘子亮着时再按一下收起")
	show.open(&"radish_soup")
	assert_false(show._heat.watch, "有了火候印，下回只演不用按")
