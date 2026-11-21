extends GutTest
## 亲手做菜：备料、掌火、起锅的规则，和灶台上的结算。

const STEP := 1.0 / 60.0


func before_each() -> void:
	SaveSystem.reset_all()


func _event(id: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = id
	event.pressed = true
	return event


## 一局打到底。careful：等刀走到中间再落、锅温跟着正好那一段、提鲜、等光圈收到锅沿。
## hold：不 careful 时是不是一直按着。
func _play(batch: CookRound, careful: bool, hold: bool = false) -> void:
	var guard := 0
	while batch.step != CookRound.Step.DONE and guard < 20000:
		guard += 1
		match batch.step:
			CookRound.Step.PREP:
				batch.advance(STEP, false)
				if not careful or batch.beat_in_window():
					batch.chop()
			CookRound.Step.FIRE:
				var press := hold
				if careful:
					press = batch.temp + batch.vel * 0.18 < batch.zone
					batch.season()
				batch.advance(STEP, press)
			CookRound.Step.SERVE:
				batch.advance(STEP, false)
				if not careful or batch.serve_ring() <= CookRound.SERVE_GOOD:
					batch.serve()
		batch.events.clear()


func test_only_stir_dishes_are_played_by_hand_for_now() -> void:
	assert_true(CookRound.supports(Database.recipes[&"tomato_egg"]))
	assert_false(CookRound.supports(Database.recipes[&"radish_soup"]))
	assert_false(CookRound.supports(null))


func test_chopping_in_the_middle_counts_and_always_moves_on() -> void:
	var batch := CookRound.new(&"stir", 2, 0, 1)
	assert_eq(batch.cuts_total, 4)
	assert_false(batch.beat_in_window(), "刀从案板一头起")
	assert_true(batch.chop())
	assert_eq(batch.cuts_good, 0)
	while not batch.beat_in_window():
		batch.advance(STEP, false)
	batch.chop()
	assert_eq(batch.cuts_good, 1)
	batch.chop()
	batch.chop()
	assert_eq(batch.step, CookRound.Step.FIRE, "准不准都往下走")
	assert_eq(batch.drops, 1, "头一样料下了锅")
	assert_true(batch.events.has(&"drop"))
	assert_false(batch.chop())


func test_holding_heats_with_inertia_and_letting_go_cools() -> void:
	var batch := CookRound.new(&"stir", 1, 0, 1)
	_skip_prep(batch)
	var start := batch.temp
	for i in 30:
		batch.advance(STEP, true)
	assert_gt(batch.temp, start)
	var hot := batch.temp
	batch.advance(STEP, false)
	assert_gt(batch.temp, hot, "松手那一下还带着往上的劲")
	for i in 120:
		batch.advance(STEP, false)
	assert_lt(batch.temp, hot)
	assert_between(batch.temp, 0.0, 1.0)


func _skip_prep(batch: CookRound) -> void:
	while batch.step == CookRound.Step.PREP:
		batch.chop()
	batch.events.clear()


func test_cooking_goes_fast_in_the_zone_slow_below_and_scorches_above() -> void:
	var cold := CookRound.new(&"stir", 1, 0, 1)
	_skip_prep(cold)
	for i in 120:
		cold.advance(STEP, false)
	var hot := CookRound.new(&"stir", 1, 0, 1)
	_skip_prep(hot)
	for i in 240:
		hot.advance(STEP, true)
	assert_gt(hot.scorch, 0.1, "一直按着就焦")
	assert_eq(cold.scorch, 0.0)
	var steady := CookRound.new(&"stir", 1, 0, 1)
	_skip_prep(steady)
	for i in 120:
		steady.advance(STEP, steady.temp + steady.vel * 0.18 < steady.zone)
	assert_gt(steady.done, cold.done * 3.0, "锅温正好时熟得快得多")
	assert_gt(steady.in_time, 0.8)


func test_each_new_ingredient_chills_the_pan() -> void:
	var batch := CookRound.new(&"stir", 3, 0, 1)
	_skip_prep(batch)
	var seen := 1
	var dipped := false
	for i in 3000:
		var before := batch.temp
		batch.advance(STEP, batch.temp + batch.vel * 0.18 < batch.zone)
		if batch.drops > seen:
			seen = batch.drops
			dipped = dipped or batch.temp < before - 0.1
		if batch.step != CookRound.Step.FIRE:
			break
	assert_eq(batch.drops, 3)
	assert_true(dipped, "下料那一下锅温掉一截")


func test_seasoning_only_works_while_the_chance_is_open() -> void:
	var batch := CookRound.new(&"stir", 1, 0, 1)
	_skip_prep(batch)
	assert_false(batch.season(), "机会没开")
	var opened := false
	for i in 3000:
		batch.advance(STEP, batch.temp + batch.vel * 0.18 < batch.zone)
		if batch.events.has(&"season_open"):
			opened = true
			break
	assert_true(opened)
	var before := batch.temp
	assert_true(batch.season())
	assert_lt(batch.temp, before, "撒下去锅温掉一点")
	assert_true(batch.seasoned)
	assert_false(batch.season(), "一局只有一把")


func test_serving_waits_three_rings_then_plates_by_itself() -> void:
	var batch := CookRound.new(&"stir", 1, 0, 1)
	_skip_prep(batch)
	while batch.step == CookRound.Step.FIRE:
		batch.advance(STEP, batch.temp + batch.vel * 0.18 < batch.zone)
	assert_eq(batch.step, CookRound.Step.SERVE)
	assert_almost_eq(batch.serve_ring(), 1.0, 0.05)
	for i in int(CookRound.SERVE_SECONDS * CookRound.SERVE_ROUNDS * 60.0) + 5:
		batch.advance(STEP, false)
	assert_eq(batch.step, CookRound.Step.DONE, "一直不按也会出锅")
	assert_false(batch.serve_good)
	assert_false(batch.serve())


func test_a_careful_cook_earns_signature_and_careless_ones_do_not() -> void:
	for seed_value in 6:
		var careful := CookRound.new(&"stir", 2, 0, seed_value)
		_play(careful, true)
		assert_eq(careful.grade, CookRound.Grade.SIGNATURE, "用心做是拿手（种子 %d，%.2f 分）" % [seed_value, careful.score])
		assert_lt(careful.fire_time, 20.0, "一局不拖")
	var lazy := CookRound.new(&"stir", 2, 0, 3)
	_play(lazy, false)
	assert_eq(lazy.step, CookRound.Step.DONE, "不添火也做得完")
	assert_eq(lazy.grade, CookRound.Grade.HOME)
	assert_almost_eq(lazy.fire_time, CookRound.FIRE_LIMIT, 0.1)
	var rough := CookRound.new(&"stir", 2, 0, 3)
	_play(rough, false, true)
	assert_ne(rough.grade, CookRound.Grade.SIGNATURE)
	assert_gt(rough.scorch, 0.3)
	assert_string_contains(rough.remark(), "焦")


func test_rank_and_clean_prep_widen_the_zone() -> void:
	var plain := CookRound.new(&"stir", 2, 0, 1)
	var master := CookRound.new(&"stir", 2, 3, 1)
	assert_gt(master.half, plain.half)
	var before := plain.half
	while plain.step == CookRound.Step.PREP:
		plain.advance(STEP, false)
		if plain.beat_in_window():
			plain.chop()
	assert_almost_eq(plain.half, before + CookRound.HALF_FOR_PREP, 0.001)


func test_signature_raises_the_fresh_plate_one_grade() -> void:
	GameState.inventory.add(&"tomato")
	GameState.inventory.add(&"egg", 1, 0, false, false)
	assert_true(Crafting.cook(&"tomato_egg"))
	assert_eq(GameState.inventory.count_of(&"tomato_egg", 0), 1)
	assert_false(Crafting.raise_plate(&"fried_egg"), "不是刚出锅的那道")
	assert_true(Crafting.raise_plate(&"tomato_egg"))
	assert_eq(GameState.inventory.count_of(&"tomato_egg", 0), 0)
	assert_eq(GameState.inventory.count_of(&"tomato_egg", 1), 1)
	assert_false(Crafting.raise_plate(&"tomato_egg"), "一份只抬一回")
	assert_eq(GameState.inventory.count_of(&"tomato_egg"), 1)


func test_stove_plays_a_stir_dish_by_hand_and_rewards_signature() -> void:
	var show := CookShow.new()
	add_child_autofree(show)
	var panel := CookPanel.new()
	add_child_autofree(panel)
	EventBus.cook_show_requested.connect(show.open)
	GameState.inventory.add(&"tomato")
	GameState.inventory.add(&"egg", 1, 0, false, false)
	panel.open()
	for i in panel._list.size():
		if panel._list[i].id == &"tomato_egg":
			panel._cursor = i
			break
	assert_true(panel.cook_selected())
	assert_true(show.is_open())
	assert_true(show._bench.visible)
	assert_eq(GameState.inventory.count_of(&"tomato_egg"), 1, "菜一下锅就在背包里")
	show._bench.start(Database.recipes[&"tomato_egg"], 2)
	var batch: CookRound = show._bench.round
	# 备料走输入：等刀到中间再按使用
	while batch.step == CookRound.Step.PREP:
		batch.advance(STEP, false)
		if batch.beat_in_window():
			show._input(_event(&"use"))
	assert_eq(batch.cuts_good, batch.cuts_total)
	while batch.step == CookRound.Step.FIRE:
		batch.advance(STEP, batch.temp + batch.vel * 0.18 < batch.zone)
		if batch.season_left > 0.0:
			show._input(_event(&"move_up"))
	assert_true(batch.seasoned)
	while batch.serve_ring() > CookRound.SERVE_GOOD:
		batch.advance(STEP, false)
	show._input(_event(&"use"))
	assert_eq(batch.step, CookRound.Step.DONE)
	assert_eq(batch.grade, CookRound.Grade.SIGNATURE)
	assert_true(Crafting.has_heat(&"tomato_egg"))
	assert_eq(GameState.inventory.count_of(&"tomato_egg", 1), 1, "拿手：这一份高一档")
	assert_eq(GameState.inventory.count_of(&"tomato_egg"), 1)
	assert_true(show._bench.raised)
	show._input(_event(&"use"))
	assert_false(show.is_open())


func test_skipping_keeps_the_plain_dish() -> void:
	var show := CookShow.new()
	add_child_autofree(show)
	GameState.inventory.add(&"tomato")
	GameState.inventory.add(&"egg", 1, 0, false, false)
	assert_true(Crafting.cook(&"tomato_egg"))
	show.open(&"tomato_egg")
	assert_true(show._bench.visible)
	show._input(_event(&"ui_cancel"))
	assert_false(show.is_open())
	assert_true(Crafting.made_dishes.has(&"tomato_egg"))
	assert_false(Crafting.has_heat(&"tomato_egg"))
	assert_eq(GameState.inventory.count_of(&"tomato_egg", 0), 1)


func test_other_methods_still_use_the_old_show() -> void:
	var show := CookShow.new()
	add_child_autofree(show)
	GameState.inventory.add(&"white_radish", 2)
	assert_true(Crafting.cook(&"radish_soup"))
	show.open(&"radish_soup")
	assert_false(show._bench.visible)
	assert_eq(show.phase(), CookHeat.DROP)


func test_drawn_crop_atlas_keeps_growth_shapes_and_bounds() -> void:
	for id: StringName in CropArt.PAINTED_CROPS:
		var seedling := CropArt.field(id, 1)
		var mature := CropArt.field(id, 3)
		assert_eq(mature.get_size(), Vector2i(16, 24))
		assert_gt(mature.get_used_rect().size.y, seedling.get_used_rect().size.y, "%s 成株比苗高" % id)
		assert_lte(mature.get_used_rect().end.y, 23)
