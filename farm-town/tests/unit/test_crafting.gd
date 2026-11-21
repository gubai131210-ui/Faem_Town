extends GutTest
## M4：加工设备（石叔卖、摆在农场、放原料过几天出成品）和烹饪（灶台、菜谱、吃东西）。

const VAT_TILE := Vector2i(13, 5)


func before_each() -> void:
	SaveSystem.reset_all()
	Weather.today = &"sunny"
	GameClock.minutes = 600.0
	GameClock.day = 1


func after_each() -> void:
	SaveSystem.reset_all()
	Weather.today = &"sunny"
	GameClock.running = false


func _farm() -> OutdoorMap:
	var scene: PackedScene = load(SceneRouter.MAPS[&"farm"])
	var m: OutdoorMap = scene.instantiate()
	add_child_autofree(m)
	return m


func _own(id: StringName) -> void:
	GameState.set_flag(Database.machine(id).owned_flag())


## 把背包清空，只放这一样，选中它。
func _hold(id: StringName, count: int, quality: int = 0) -> void:
	GameState.inventory.clear()
	GameState.inventory.add(id, count, quality)
	GameState.selected_slot = 0


# ---------------------------------------------------------------- 数据

func test_tables_are_valid() -> void:
	assert_eq(Database.validate(), PackedStringArray(), "数据表没有错")
	assert_eq(Database.machines.size(), 8, "八台设备")
	assert_gt(Database.recipes.size(), 8)


func test_every_new_icon_draws_something() -> void:
	for id: StringName in Database.items:
		var def := Database.item(id)
		if def.kind != &"food" and def.kind != &"product" and id != &"scarecrow":
			continue
		var img := PixelArt.icon(def.icon)
		var used := 0
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.0:
					used += 1
		assert_gt(used, 20, "%s 的图标画出来了" % id)


func test_every_machine_has_its_own_shop_icon() -> void:
	for flag: StringName in [&"lamp_plaza", &"lamp_river", &"lamp_pasture"]:
		GameState.set_flag(flag)
	var entries := _machine_entries()
	assert_eq(entries.size(), 8)
	var seen: Dictionary[String, bool] = {}
	for e in entries:
		assert_true(e.icon.begins_with("machine:"), "%s 用专门画的图标" % e.name)
		var img := PixelArt.icon(e.icon)
		assert_eq(img.get_size(), Vector2i(16, 16))
		var used := 0
		for y in 16:
			for x in 16:
				if img.get_pixel(x, y).a > 0.0:
					used += 1
		assert_gt(used, 40, "%s 的图标画出来了" % e.name)
		var key := img.get_data().hex_encode()
		assert_false(seen.has(key), "%s 的图标和别的不一样" % e.name)
		seen[key] = true


func test_machines_do_not_overlap_anything() -> void:
	var farm := _farm()
	var seen: Dictionary[Vector2i, bool] = {}
	for id: StringName in Database.machines:
		var t := Database.machine(id).tile
		assert_false(seen.has(t), "%s 的位置没和别的设备撞上" % id)
		seen[t] = true
		assert_false(farm._tile_blocked(t), "没买的时候 %s 的位置是空地" % id)
		assert_false(farm._tile_blocked(t + Vector2i(0, 1)), "%s 前面站得了人" % id)


# ---------------------------------------------------------------- 买

func test_smith_sells_machines_once() -> void:
	GameState.money = 5000
	assert_eq(_machine_entries().size(), 0, "广场灯亮以前不卖")
	GameState.set_flag(&"lamp_plaza")
	var names := _machine_entries().map(func(e: ShopEntry) -> String: return e.name)
	assert_true(names.has("腌缸") and names.has("石磨") and names.has("榨油机") and names.has("茶焙"))
	assert_false(names.has("缫丝机"), "缫丝机要等河灯")
	assert_false(names.has("奶酪架"), "奶酪架要等牧野灯")
	var vat: ShopEntry = _machine_entries()[0]
	assert_true(Shop.buy_entry(vat, 1))
	assert_eq(GameState.money, 5000 - 600)
	assert_true(Crafting.owned(&"pickle_vat"))
	assert_false(_machine_entries().map(func(e: ShopEntry) -> String: return e.name).has("腌缸"), "买过就不再卖")
	assert_false(Shop.buy_entry(vat, 1), "不能买两回")
	for e in Shop.entries(&"spring", Shop.GROCERY):
		assert_eq(e.flag, &"", "杂货铺不卖设备")


func test_cannot_buy_machine_without_money() -> void:
	GameState.set_flag(&"lamp_plaza")
	GameState.money = 100
	assert_false(Shop.buy_entry(_machine_entries()[0], 1))
	assert_false(Crafting.owned(&"pickle_vat"))
	assert_eq(GameState.money, 100)


func _machine_entries() -> Array:
	return Shop.entries(&"spring", Shop.SMITH).filter(func(e: ShopEntry) -> bool: return e.flag != &"")


# ---------------------------------------------------------------- 加工

func test_put_wait_take() -> void:
	_own(&"pickle_vat")
	_hold(&"white_radish", 3, 2)
	assert_true(Crafting.can_put(&"pickle_vat", 0))
	assert_true(Crafting.put(&"pickle_vat", 0))
	assert_eq(GameState.inventory.count_of(&"white_radish"), 1, "用掉两个")
	assert_eq(Crafting.state(&"pickle_vat"), Crafting.WORKING)
	assert_false(Crafting.can_put(&"pickle_vat", 0), "正做着不能再放")
	assert_eq(Crafting.take(&"pickle_vat"), [], "没做好收不了")
	GameClock.advance_day()
	assert_eq(Crafting.state(&"pickle_vat"), Crafting.WORKING, "腌菜要两天")
	GameClock.advance_day()
	assert_eq(Crafting.state(&"pickle_vat"), Crafting.READY)
	var got := Crafting.take(&"pickle_vat")
	assert_eq(got, [&"pickles", 1, 2], "成品的品质跟着原料")
	assert_eq(GameState.inventory.count_of(&"pickles", 2), 1)
	assert_eq(Crafting.state(&"pickle_vat"), Crafting.IDLE)


func test_wrong_or_too_few_inputs_are_refused() -> void:
	_own(&"pickle_vat")
	_hold(&"white_radish", 1)
	assert_false(Crafting.put(&"pickle_vat", 0), "一个不够")
	assert_true(Crafting.accepts(&"pickle_vat", &"white_radish"))
	_hold(&"rice", 5)
	assert_false(Crafting.put(&"pickle_vat", 0), "腌缸不收稻谷")
	assert_eq(GameState.inventory.count_of(&"rice"), 5)
	assert_false(Crafting.put(&"millstone", 0), "没买的设备用不了")


func test_each_machine_makes_its_product() -> void:
	var cases: Array = [
		[&"millstone", &"rice", &"white_rice"], [&"millstone", &"winter_wheat", &"flour"],
		[&"oil_press", &"rapeseed", &"cooking_oil"], [&"oil_press", &"fog_bell", &"lamp_oil"],
		[&"tea_roaster", &"tea_leaf", &"dried_tea"], [&"silk_reel", &"cocoon", &"silk"],
		[&"cheese_rack", &"goat_milk", &"cheese"], [&"cheese_rack", &"milk", &"cheese"],
	]
	for c: Array in cases:
		var machine: StringName = c[0]
		var input: StringName = c[1]
		_own(machine)
		_hold(input, 5)
		assert_true(Crafting.put(machine, 0), "%s 收 %s" % [machine, input])
		GameClock.advance_day()
		GameClock.advance_day()
		var got := Crafting.take(machine)
		assert_eq(got.size(), 3)
		assert_eq(got[0], c[2], "%s 放进 %s 出 %s" % [input, machine, c[2]])
		var made := Database.item(c[2])
		assert_gt(made.price, Database.item(input).price * Crafting.need(machine, input) - 1, "%s 比原料值钱" % c[2])


func test_take_needs_room_in_bag() -> void:
	_own(&"millstone")
	_hold(&"rice", 1)
	Crafting.put(&"millstone", 0)
	GameClock.advance_day()
	GameState.inventory.clear()
	for i in GameState.INVENTORY_SIZE:
		GameState.inventory.add(&"hoe")
	assert_eq(Crafting.take(&"millstone"), [], "背包满了收不了")
	assert_eq(Crafting.state(&"millstone"), Crafting.READY, "东西还在里面")


func test_jobs_survive_save_and_load() -> void:
	_own(&"tea_roaster")
	_hold(&"tea_leaf", 2, 1)
	Crafting.put(&"tea_roaster", 0)
	var data := Crafting.save_data()
	Crafting.reset_data()
	assert_eq(Crafting.state(&"tea_roaster"), Crafting.IDLE)
	Crafting.load_data(JSON.parse_string(JSON.stringify(data)))
	assert_eq(Crafting.state(&"tea_roaster"), Crafting.WORKING)
	GameClock.advance_day()
	assert_eq(Crafting.take(&"tea_roaster"), [&"dried_tea", 1, 1])


# ---------------------------------------------------------------- 农场上

func test_machine_shows_up_on_farm_and_works() -> void:
	var farm := _farm()
	assert_eq(farm.query_use(null, VAT_TILE, GameMap.Facing.UP), &"", "没买的时候那儿什么都没有")
	_own(&"pickle_vat")
	Crafting.changed.emit()
	assert_true(farm._tile_blocked(VAT_TILE), "买了以后占一格")
	assert_eq(farm.query_use(null, VAT_TILE, GameMap.Facing.UP), &"interact", "空手是看看")
	_hold(&"napa_cabbage", 2)
	var item := GameState.selected_item()
	assert_eq(farm.query_use(item, VAT_TILE, GameMap.Facing.UP), &"tend", "拿着够数的原料是伸手放")
	farm.perform(&"tend", item, VAT_TILE)
	assert_eq(Crafting.state(&"pickle_vat"), Crafting.WORKING)
	assert_eq(GameState.inventory.count_of(&"napa_cabbage"), 0)
	assert_eq(farm.query_use(null, VAT_TILE, GameMap.Facing.UP), &"interact", "正做着是看看")
	GameClock.advance_day()
	GameClock.advance_day()
	assert_eq(farm.query_use(null, VAT_TILE, GameMap.Facing.UP), &"tend", "做好了是伸手收")
	farm.perform(&"tend", null, VAT_TILE)
	assert_eq(GameState.inventory.count_of(&"pickles"), 1)


# ---------------------------------------------------------------- 烹饪

func test_starter_recipes_are_known() -> void:
	assert_true(Crafting.knows(&"radish_soup"))
	assert_false(Crafting.knows(&"fish_soup"), "云娘的菜要她教")
	assert_false(Crafting.knows(&"no_such_dish"))
	for def in Crafting.known_recipes():
		assert_eq(def.from, &"start")


func test_cook_uses_ingredients() -> void:
	GameState.inventory.clear()
	GameState.inventory.add(&"white_radish", 5)
	assert_eq(Crafting.servings(&"radish_soup"), 2)
	assert_true(Crafting.cook(&"radish_soup"))
	assert_eq(GameState.inventory.count_of(&"white_radish"), 3)
	assert_eq(GameState.inventory.count_of(&"radish_soup"), 1)
	assert_true(Crafting.cook(&"radish_soup"))
	assert_false(Crafting.cook(&"radish_soup"), "剩一个萝卜做不了")
	assert_eq(GameState.inventory.count_of(&"white_radish"), 1)


func test_cannot_cook_unknown_recipe() -> void:
	GameState.inventory.add(&"crucian", 1)
	GameState.inventory.add(&"white_radish", 1)
	assert_eq(Crafting.servings(&"fish_soup"), 0)
	assert_false(Crafting.cook(&"fish_soup"))
	assert_eq(GameState.inventory.count_of(&"crucian"), 1)


func test_new_term_dishes_cover_the_empty_terms() -> void:
	var covered: Dictionary[StringName, bool] = {}
	for id: StringName in Database.recipes:
		var rec: RecipeDef = Database.recipes[id]
		if rec.term != &"":
			covered[rec.term] = true
	for term_id: StringName in [&"lichun", &"guyu", &"xiaoman", &"mangzhong", &"xiaoshu", &"liqiu", &"bailu", &"shuangjiang", &"lidong"]:
		assert_true(covered.has(term_id), "这个节气有菜：%s" % term_id)
	GameState.inventory.add(&"spring_bamboo_shoot", 1)
	GameState.inventory.add(&"cooking_oil", 1)
	assert_false(Crafting.knows(&"bamboo_stir"), "炒春笋是云娘教的，开局不会")
	Crafting.learn("yunniang")
	var guard := 0
	while not Crafting.knows(&"bamboo_stir") and guard < 80:
		GameClock.advance_day()
		Crafting.learn("yunniang")
		guard += 1
	assert_true(Crafting.knows(&"bamboo_stir"))
	assert_true(Crafting.cook(&"bamboo_stir"))
	assert_eq(GameState.inventory.count_of(&"bamboo_stir"), 1)


func test_yunniang_teaches_one_dish_a_day() -> void:
	assert_true(Crafting.has_lesson("yunniang"))
	assert_true(Crafting.learn("yunniang"))
	assert_true(Crafting.knows(&"fish_soup"))
	assert_eq(Crafting.last_dish, "鲫鱼萝卜汤")
	assert_false(Crafting.has_lesson("yunniang"), "一天只教一道")
	assert_false(Crafting.learn("yunniang"))
	var days := 0
	while days < 80:
		GameClock.advance_day()
		days += 1
		if not Crafting.learn("yunniang"):
			break
	for id: StringName in Database.recipes:
		if Database.recipes[id].from == &"memory" or Database.recipes[id].from == &"odd":
			continue
		assert_true(Crafting.knows(id), "最后都学会了：%s" % id)
	assert_false(Crafting.has_lesson("yunniang"), "教完了")


func test_yunniang_dialogue_teaches() -> void:
	GameState.set_flag(&"lamp_plaza")
	var res: Resource = load("res://dialogue/yunniang.dialogue")
	var line: Variant = await DialogueManager.get_next_dialogue_line(res, "work")
	assert_string_contains(str(line.text), "鲫鱼萝卜汤")
	assert_true(Crafting.knows(&"fish_soup"))
	line = await DialogueManager.get_next_dialogue_line(res, "work")
	assert_false(str(line.text).contains("教你一道菜"), "当天再聊就是平常的话")


func test_stove_opens_cook_panel() -> void:
	var scene: PackedScene = load(SceneRouter.MAPS[&"farmhouse"])
	var house: GameMap = scene.instantiate()
	add_child_autofree(house)
	var stove := Vector2i(10, 2)
	assert_eq(house.query_use(null, stove, GameMap.Facing.UP), &"interact")
	watch_signals(EventBus)
	house.perform(&"interact", null, stove)
	assert_signal_emitted(EventBus, "cook_requested")


func test_cook_panel_lists_and_cooks() -> void:
	var panel := CookPanel.new()
	add_child_autofree(panel)
	GameState.inventory.clear()
	GameState.inventory.add(&"white_radish", 2)
	panel.open()
	assert_true(panel.is_open())
	assert_eq(panel._list.size(), Crafting.known_recipes().size())
	assert_eq(panel._list[0].id, &"radish_soup")
	assert_true(panel.cook_selected())
	assert_eq(GameState.inventory.count_of(&"radish_soup"), 1)
	assert_false(panel.cook_selected(), "材料用完了")
	panel.close()
	assert_false(panel.is_open())


# ---------------------------------------------------------------- 吃

func test_eating_restores_energy() -> void:
	GameState.energy = 40
	var text := GameState.eat(Database.item(&"radish_soup"))
	assert_eq(GameState.energy, 70)
	assert_string_contains(text, "+30")
	GameState.energy = 95
	text = GameState.eat(Database.item(&"radish_soup"))
	assert_eq(GameState.energy, 100, "不超过上限")
	assert_string_contains(text, "+5")


func test_not_hungry_when_full() -> void:
	GameState.energy = GameState.max_energy
	assert_eq(GameState.eat(Database.item(&"radish_soup")), "", "体力满了不吃")
	assert_ne(GameState.eat(Database.item(&"tea_egg")), "", "带增益的满了也能吃")
	assert_eq(GameState.eat(Database.item(&"white_radish")), "", "生萝卜不能直接吃")


func test_hot_food_doubles_in_xiaohan() -> void:
	# 小寒是冬天第 17–20 天
	GameClock.day = GameClock.DAYS_PER_SEASON * 3 + 17
	assert_eq(GameClock.term_id(), &"xiaohan")
	GameState.energy = 10
	GameState.eat(Database.item(&"radish_soup"))
	assert_eq(GameState.energy, 70, "热食翻倍")
	GameState.energy = 10
	GameState.eat(Database.item(&"fried_egg"))
	assert_eq(GameState.energy, 35, "凉的不翻倍")


func test_chushu_speeds_energy_recovery() -> void:
	# 处暑是秋天第 5–8 天
	GameClock.day = GameClock.DAYS_PER_SEASON * 2 + 5
	assert_eq(GameClock.term_id(), &"chushu")
	GameState.energy = 10
	GameState.eat(Database.item(&"radish_soup"))
	assert_eq(GameState.energy, 55, "处暑恢复加快：30 ×1.5 = 45")
	GameState.energy = 10
	GameState.eat(Database.item(&"fried_egg"))
	assert_eq(GameState.energy, 48, "凉的也加快：25 ×1.5 向上取整 = 38")


func test_buff_lasts_for_its_minutes_and_ends_with_the_day() -> void:
	GameClock.minutes = 600.0
	GameState.energy = 50
	GameState.eat(Database.item(&"plain_noodles"))
	assert_true(GameState.buff_active(&"swift"))
	assert_false(GameState.buff_active(&"hearty"))
	GameClock.minutes = 600.0 + 179.0
	assert_true(GameState.buff_active(&"swift"))
	GameClock.minutes = 600.0 + 181.0
	assert_false(GameState.buff_active(&"swift"), "三个小时就过了")
	GameClock.minutes = 600.0
	GameState.eat(Database.item(&"milk_cake"))
	GameClock.advance_day()
	GameClock.minutes = 400.0
	assert_false(GameState.buff_active(&"swift"), "睡一觉就没了")


func test_buff_survives_save_and_load() -> void:
	GameState.energy = 50
	GameState.eat(Database.item(&"egg_fried_rice"))
	var data := GameState.save_data()
	GameState.reset_data()
	assert_false(GameState.buff_active(&"hearty"))
	GameState.load_data(JSON.parse_string(JSON.stringify(data)))
	assert_true(GameState.buff_active(&"hearty"))


func test_farmer_sheet_has_a_cooking_pose_after_the_old_rows() -> void:
	var sheet := CharacterSheet.load_sheet("farmer")
	assert_true(sheet.has_anim(&"cook"), "主角的序列帧里有做菜")
	assert_eq(sheet.frame_count(&"cook"), 8, "铲子来回八帧，一步一格")
	assert_almost_eq(sheet.fps(&"cook"), 10.0, 0.01)
	# 做菜排在最后，原来的动作还在原来的行上
	assert_eq(sheet.region(&"roll", GameMap.Facing.DOWN, 0).position.y, 60.0 * sheet.cell)
	assert_eq(sheet.region(&"cook", GameMap.Facing.DOWN, 0).position.y, 64.0 * sheet.cell)


func test_food_can_be_sold() -> void:
	assert_true(Database.item(&"radish_soup").sellable())
	assert_true(Database.item(&"pickles").sellable())


func test_the_table_keeps_each_dish_and_the_feast_needs_eight() -> void:
	GameState.inventory.add(&"stir_greens", 2)
	assert_true(Crafting.place_dish(&"stir_greens"))
	assert_eq(GameState.inventory.count_of(&"stir_greens"), 1)
	assert_false(Crafting.place_dish(&"stir_greens"), "同一道不摆第二次")
	assert_false(Crafting.place_dish(&"egg"), "鸡蛋不是菜")
	assert_false(Crafting.feast_ready())
	for id: StringName in Crafting.FEAST:
		if id == &"stir_greens":
			continue
		GameState.inventory.add(id, 1)
		assert_true(Crafting.place_dish(id), "摆上 %s" % id)
	assert_true(Crafting.feast_ready())
	var data := Crafting.save_data()
	Crafting.clear_table()
	assert_eq(Crafting.table_dishes.size(), 0)
	Crafting.load_data(data)
	assert_true(Crafting.feast_ready(), "存档里的席面还在")
	Crafting.load_data({"jobs": {}})
	assert_eq(Crafting.table_dishes.size(), 0, "旧存档没有桌子")
	var scene: PackedScene = load(SceneRouter.MAPS[&"farmhouse"])
	var house: GameMap = scene.instantiate()
	add_child_autofree(house)
	GameState.inventory.add(&"tomato_egg", 1)
	house.perform(&"interact", Database.item(&"tomato_egg"), Vector2i(7, 4))
	assert_eq(Crafting.table_dishes[0], &"tomato_egg")
	var dishes: Array = house.get("_dishes")
	assert_eq(dishes.size(), 1)
	assert_ne((dishes[0] as Sprite2D).texture, null)


func test_seasonal_dishes_use_that_seasons_crop_or_fish() -> void:
	var bad := RecipeDef.new()
	bad.id = &"bad_greens"
	bad.season = &"winter"
	bad.ingredients[&"bok_choy"] = 1
	assert_false(Database.recipe_season_errors(bad).is_empty())
	var fish := RecipeDef.new()
	fish.id = &"bad_fish"
	fish.season = &"summer"
	fish.ingredients[&"ice_fish"] = 1
	assert_false(Database.recipe_season_errors(fish).is_empty())
	var kept := RecipeDef.new()
	kept.id = &"kept_beans"
	kept.season = &"winter"
	kept.kept = true
	kept.ingredients[&"soybean"] = 1
	assert_true(Database.recipe_season_errors(kept).is_empty())
	assert_eq(Database.recipes[&"fish_soup"].season, &"spring")
	assert_true(Database.recipes[&"eight_treasure"].kept)
	assert_eq(Database.recipes[&"laba_porridge"].term, &"xiaohan")
	for msg in Database.validate():
		assert_false(msg.contains("菜谱"), msg)


func test_the_feast_lines_up_one_dish_per_guest() -> void:
	var cutscene: Script = load("res://game/cutscene.gd")
	GameState.inventory.add(&"stir_greens", 1)
	Crafting.place_dish(&"stir_greens")
	var steps: Array = cutscene.call(&"feast_steps")
	assert_eq(steps.size(), 2)
	assert_eq(steps[0]["picture"], &"feast_hall")
	assert_eq((steps[0]["cast"] as Array).size(), 8)
	assert_eq((steps[1]["cast"] as Array).size(), 16)
	assert_eq((cutscene.call(&"replay_steps", &"feast_banquet") as Array).size(), 2)
	assert_eq(Crafting.table_dishes.size(), 1, "排重看的步骤不撤桌上的菜")


func test_the_first_pot_plays_longer_than_the_next() -> void:
	assert_almost_eq(Crafting.cook_seconds(&"radish_soup"), 2.4, 0.01)
	Crafting.mark_cooked(&"radish_soup")
	assert_almost_eq(Crafting.cook_seconds(&"radish_soup"), 1.0, 0.01)
	var data := Crafting.save_data()
	Crafting.reset_data()
	assert_almost_eq(Crafting.cook_seconds(&"radish_soup"), 2.4, 0.01, "新的一局头一回仍是长的")
	Crafting.load_data(data)
	assert_almost_eq(Crafting.cook_seconds(&"radish_soup"), 1.0, 0.01, "做过的菜记在档里")
	assert_eq(Database.recipes[&"tomato_egg"].method, &"stir")
	assert_eq(Database.recipes[&"lotus_slices"].method, &"cut")
	assert_eq(Database.recipes[&"oil_shrimp"].method, &"fry")
	assert_eq(Database.recipes[&"roast_sweet_potato"].method, &"roast")
	assert_eq(Database.recipes[&"cold_noodles"].method, &"mix")
	assert_eq(Database.recipes[&"rice_bowl"].method, &"steam")
	assert_eq(Database.recipes[&"napa_pot"].method, &"stew")
	assert_eq(Database.recipes[&"fish_soup"].method, &"boil")


func test_the_sauce_vat_and_wine_jar_make_the_four_condiments() -> void:
	var sauce := Database.machine(&"sauce_vat")
	var wine := Database.machine(&"wine_jar")
	assert_eq(sauce.recipe_for(&"soybean")["output"], &"soy_sauce")
	assert_eq(sauce.recipe_for(&"white_rice")["output"], &"rice_vinegar")
	assert_eq(wine.recipe_for(&"white_rice")["output"], &"rice_wine")
	assert_eq(wine.recipe_for(&"winter_wheat")["output"], &"malt_sugar")
	assert_eq(int(sauce.recipe_for(&"soybean")["days"]), 3)
	assert_eq(Database.recipes[&"soy_greens"].ingredients[&"soy_sauce"], 1)
	assert_eq(Database.recipes[&"vinegar_napa"].season, &"autumn")
	assert_eq(Database.recipes[&"wine_perch"].method, &"steam")
	assert_eq(Database.recipes[&"sugar_roast"].method, &"roast")


func test_both_halves_teach_the_dish_and_one_half_does_not() -> void:
	var left := RecipeDef.scrap_item(&"soy_greens", 0)
	var right := RecipeDef.scrap_item(&"soy_greens", 1)
	assert_eq(Database.item(left).name, "绿残页·左")
	assert_eq(Database.item(right).name, "绿残页·右")
	assert_false(Crafting.knows(&"soy_greens"))
	assert_eq(Crafting.offer_scrap(&"mine", 0.0), left)
	assert_eq(Crafting.offer_scrap(&"mine", 0.99), &"", "多数时候不掉")
	GameState.inventory.add(left, 1)
	assert_eq(Crafting.read_scrap(left), "只有半张，看不全")
	assert_false(Crafting.knows(&"soy_greens"))
	assert_eq(GameState.inventory.count_of(left), 1, "没凑齐不收走")
	assert_ne(Crafting.offer_scrap(&"mine", 0.0), left, "手里这张不再掉")
	GameState.inventory.add(right, 1)
	assert_eq(Crafting.read_scrap(right), "看懂了：酱青菜")
	assert_true(Crafting.knows(&"soy_greens"))
	assert_eq(GameState.inventory.count_of(left), 0)
	assert_eq(GameState.inventory.count_of(right), 0)
	assert_false(Crafting.offer_scrap(&"wild", 0.0) == right, "会了就不再掉这道的残页")
	var got := Mine.grant_scrap(0.0)
	assert_eq(got, RecipeDef.scrap_item(&"wine_perch", 0), "井里下一张是另一道的左半")
	Foraging._queue_scrap(&"fog", 0.0)
	assert_eq(Foraging.pending_scrap_fog, RecipeDef.scrap_item(&"vinegar_napa", 1))
	Foraging.pending[&"farm"] = 0
	Foraging.settle(&"farm", [Vector2i(2, 2)], [])
	assert_eq(Foraging.item_at(&"farm", Vector2i(2, 2)), RecipeDef.scrap_item(&"vinegar_napa", 1))
	var page := PixelArt.icon("scrap:soy_greens:0")
	var other := PixelArt.icon("scrap:soy_greens:1")
	assert_gt(page.get_pixel(3, 6).a, 0.5, "左半是一张纸")
	assert_eq(other.get_pixel(3, 6).a, 0.0, "右半不占左边")
	assert_eq(page.get_pixel(7, 7).to_html(false), "3d7a3a")
	assert_eq(other.get_pixel(8, 7).to_html(false), "3d7a3a", "两半墨色一样")


func test_trying_three_things_learns_the_match_and_not_a_memory() -> void:
	assert_false(Crafting.knows(&"egg_fried_rice"))
	GameState.inventory.add(&"white_rice", 1)
	GameState.inventory.add(&"egg", 1)
	GameState.inventory.add(&"cooking_oil", 1)
	assert_eq(Crafting.experiment([&"white_rice", &"egg", &"cooking_oil"]), &"egg_fried_rice")
	assert_true(Crafting.knows(&"egg_fried_rice"))
	assert_eq(GameState.inventory.count_of(&"egg_fried_rice"), 1)
	assert_eq(GameState.inventory.count_of(&"cooking_oil"), 0)
	GameState.inventory.add(&"egg", 1)
	GameState.inventory.add(&"white_rice", 1)
	GameState.inventory.add(&"stone", 1)
	assert_eq(Crafting.experiment([&"egg", &"white_rice", &"stone"]), &"odd_bowl", "两道一样贴，算没对上")
	assert_true(GameState.has_flag(Crafting.ODD_FLAG))
	assert_eq(GameState.inventory.count_of(&"stone"), 0)
	GameState.inventory.add(&"fog_bell", 1)
	GameState.inventory.add(&"dried_tea", 1)
	GameState.inventory.add(&"stone", 1)
	assert_eq(Crafting.experiment([&"fog_bell", &"dried_tea", &"stone"]), &"odd_bowl")
	assert_false(Crafting.knows(&"herb_tea"), "忆里的菜试不出来")
	var panel := CookPanel.new()
	add_child_autofree(panel)
	panel.open()
	panel._move(panel._list.size())
	assert_true(panel._on_trial())
	assert_string_contains(panel._need.text, "放进去")
	_hold(&"egg", 1)
	panel._add_trial()
	assert_eq(panel._trial.size(), 1)
	assert_eq(GameState.inventory.count_of(&"egg"), 1, "没凑满三样先不扣")


func _slot_of(id: StringName) -> int:
	for i in GameState.inventory.size:
		if GameState.inventory.id_at(i) == id:
			return i
	return -1


func test_in_season_and_today_raise_the_plate() -> void:
	GameState.inventory.clear()
	GameState.inventory.add(&"white_radish", 2)
	assert_true(Crafting.is_fresh(Database.recipes[&"radish_soup"]), "立春的萝卜算新鲜")
	assert_true(Crafting.cook(&"radish_soup"))
	assert_eq(GameState.inventory.quality_at(_slot_of(&"radish_soup")), 1)
	assert_false(GameState.inventory.term_at(_slot_of(&"radish_soup")), "萝卜汤不绑节气")
	GameClock.day = 73
	GameState.inventory.clear()
	GameState.inventory.add(&"white_radish", 2)
	assert_false(Crafting.is_fresh(Database.recipes[&"radish_soup"]), "放到冬天没有加成")
	assert_true(Crafting.cook(&"radish_soup"))
	assert_eq(GameState.inventory.quality_at(_slot_of(&"radish_soup")), 0)
	GameClock.day = 9
	GameState.inventory.clear()
	GameState.inventory.add(&"pea", 1)
	GameState.inventory.add(&"egg", 1)
	GameState.set_flag(Database.recipes[&"pea_egg"].known_flag())
	assert_true(Crafting.in_term(Database.recipes[&"pea_egg"]))
	assert_true(Crafting.is_fresh(Database.recipes[&"pea_egg"]))
	assert_true(Crafting.cook(&"pea_egg"))
	var dish := _slot_of(&"pea_egg")
	assert_eq(GameState.inventory.quality_at(dish), 2, "当令再加新鲜，到优")
	assert_true(GameState.inventory.term_at(dish))
	assert_eq(GameState.inventory.fresh_of(&"egg"), 0)
	GameState.energy = 10
	var text := GameState.eat(Database.item(&"pea_egg"), true)
	assert_eq(GameState.energy, 62, "26 点体力翻倍")
	assert_string_contains(text, "当令")
	GameState.inventory.clear_fresh()
	GameState.inventory.add(&"egg", 1)
	GameState.inventory.clear_fresh()
	GameState.inventory.add(&"pea", 1)
	assert_false(Crafting.is_fresh(Database.recipes[&"pea_egg"]), "昨天的蛋不算")
	assert_eq(Crafting.plate_quality(Database.recipes[&"pea_egg"]), 1, "节气还在，只高一档")
	GameState.inventory.add(&"crucian", 1)
	var saved := GameState.save_data()
	GameState.inventory.clear_fresh()
	GameState.load_data(saved)
	assert_eq(GameState.inventory.fresh_of(&"crucian"), 1)
	GameClock.advance_day()
	assert_eq(GameState.inventory.fresh_of(&"crucian"), 0)
	Weather.today = Weather.RAIN
	GameClock.minutes = 600.0
	GameState.energy = 10
	GameState.eat(Database.item(&"plain_noodles"))
	assert_eq(GameState.buff_left(), 270, "下雨天热食多走一半时间")


func test_hosting_eats_the_dishes_and_a_loved_plate_is_said_once() -> void:
	Residents.met[&"jiang"] = true
	Residents.met[&"xiaoman"] = true
	assert_eq(Crafting.host([&"jiang"]).size(), 0, "空桌请不成")
	GameState.inventory.add(&"radish_soup", 1)
	assert_true(Crafting.place_dish(&"radish_soup"))
	assert_eq(Crafting.host([&"ahe"]).size(), 0, "没见过面请不成")
	assert_eq(Crafting.table_dishes.size(), 1)
	var lines := Crafting.host([&"jiang"])
	assert_eq(lines.size(), 1)
	assert_string_contains(lines[0], "姜婆婆")
	assert_string_contains(lines[0], "白萝卜")
	assert_false(lines[0].contains("她说"), "只是喜欢，不说那句")
	assert_eq(Residents.familiarity_of(&"jiang"), Crafting.HOST_POINTS[&"like"])
	assert_true(Crafting.table_dishes.is_empty())
	assert_eq(Crafting.meals, 1)
	GameState.inventory.add(&"radish_soup", 1)
	assert_true(Crafting.place_dish(&"radish_soup"))
	assert_eq(Crafting.host([&"jiang"]).size(), 0, "今天请过了")
	assert_eq(Crafting.table_dishes.size(), 1, "请不成不撤菜")
	GameClock.advance_day()
	GameState.inventory.add(&"strawberry_bowl", 1)
	assert_true(Crafting.place_dish(&"strawberry_bowl"))
	lines = Crafting.host([&"xiaoman"])
	assert_string_contains(lines[0], "草莓")
	assert_string_contains(lines[0], "她说")
	assert_eq(Residents.familiarity_of(&"xiaoman"), Crafting.HOST_POINTS[&"love"])
	GameClock.advance_day()
	GameState.inventory.add(&"strawberry_bowl", 1)
	assert_true(Crafting.place_dish(&"strawberry_bowl"))
	lines = Crafting.host([&"xiaoman"])
	assert_false(lines[0].contains("她说"), "那句只说一次")
	GameClock.advance_day()
	GameState.inventory.add(&"mustard_fry", 1)
	assert_true(Crafting.place_dish(&"mustard_fry"))
	var before := Residents.familiarity_of(&"xiaoman")
	lines = Crafting.host([&"xiaoman"])
	assert_string_contains(lines[0], "没怎么吃")
	assert_eq(Residents.familiarity_of(&"xiaoman"), before, "不爱吃不加熟悉")
	var saved := Crafting.save_data()
	Crafting.reset_data()
	Crafting.load_data(saved)
	assert_gt(Crafting.meals, 0)
	GameState.inventory.add(&"fried_egg", 1)
	assert_true(Crafting.place_dish(&"fried_egg"))
	var panel := TablePanel.new()
	add_child_autofree(panel)
	panel.open()
	assert_string_contains(panel._who.text, "请：")
	panel._start_meal()
	assert_eq(Crafting.table_dishes.size(), 1, "没入座不开席")
	panel._toggle_seat()
	assert_eq(panel._seats.size(), 1)
	var cutscene: Script = load("res://game/cutscene.gd")
	var steps: Array = cutscene.call(&"guest_steps", [&"xiaoman"], [&"strawberry_bowl"], lines[0])
	assert_eq(steps.size(), 1)
	assert_eq((steps[0]["cast"] as Array).size(), 2)


func test_yunniang_gives_the_three_ranks_in_order() -> void:
	Residents.met[&"yunniang"] = true
	assert_false(Crafting.rank_ready())
	assert_eq(Residents.title_for(&"yunniang", true), "work")
	var n := 0
	for id: StringName in Database.recipes:
		if Database.recipes[id].from == &"odd":
			continue
		Crafting.mark_cooked(id)
		n += 1
		if n == 6:
			break
	assert_eq(Crafting.pending_rank(), &"helper")
	assert_eq(Residents.title_for(&"yunniang", true), "rank")
	var res: Resource = load(Residents.dialogue_path(&"yunniang"))
	var line: Variant = await DialogueManager.get_next_dialogue_line(res, "rank")
	assert_not_null(line)
	assert_string_contains(str(line.text), "帮厨")
	assert_eq(Crafting.rank_name(), "帮厨")
	assert_string_contains(Journal.page_text(3), "云娘叫你帮厨")
	assert_false(Crafting.rank_ready(), "下一档还不够")
	GameClock.day = 9
	GameState.set_flag(Database.recipes[&"pea_egg"].known_flag())
	GameState.inventory.add(&"pea", 1)
	GameState.inventory.add(&"egg", 1)
	assert_true(Crafting.cook(&"pea_egg"))
	Crafting.mark_cooked(&"pea_egg")
	assert_true(Crafting.term_made.has(&"pea_egg"), "惊蛰做的豌豆炒蛋记成当令")
	while Crafting.made_dishes.size() < 14:
		Crafting.mark_cooked(StringName("extra_%d" % Crafting.made_dishes.size()))
	Crafting.term_made.append(&"fish_soup")
	Crafting.term_made.append(&"qingming_tea")
	Crafting.meals = 2
	assert_eq(Crafting.pending_rank(), &"wok")
	Crafting.grant_rank()
	assert_eq(Crafting.rank_name(), "掌勺")
	assert_eq(Crafting.pending_rank(), &"", "大师傅还差菜、当令和桌")
	while Crafting.made_dishes.size() < 24:
		Crafting.mark_cooked(StringName("extra_%d" % Crafting.made_dishes.size()))
	while Crafting.term_made.size() < 6:
		Crafting.term_made.append(StringName("term_%d" % Crafting.term_made.size()))
	Crafting.meals = 5
	assert_eq(Crafting.pending_rank(), &"master")
	Crafting.grant_rank()
	assert_eq(Crafting.rank_name(), "大师傅")
	assert_false(Crafting.rank_ready(), "再往上留给以后")
	var saved := Crafting.save_data()
	Crafting.reset_data()
	Crafting.load_data(saved)
	assert_eq(Crafting.rank_name(), "大师傅")
	assert_true(Crafting.term_made.has(&"pea_egg"))


func test_three_sets_hang_and_are_mentioned_once() -> void:
	var banners: Array[String] = []
	var note := func(text: String) -> void:
		banners.append(text)
	EventBus.banner_requested.connect(note)
	for id: StringName in Database.recipes:
		if Database.recipes[id].term != &"":
			Crafting.mark_cooked(id)
	assert_true(Crafting.has_set(&"terms"))
	assert_string_contains(banners[-1], "节气牌")
	assert_false(Crafting.has_set(&"homes"))
	for id: StringName in Database.recipes:
		if Database.recipes[id].from == &"memory":
			Crafting.mark_cooked(id)
	assert_true(Crafting.has_set(&"homes"))
	assert_string_contains(Journal.page_text(3), "墙上挂着节气牌")
	GameState.inventory.clear()
	var placed := 0
	for id: StringName in Database.recipes:
		if Database.recipes[id].from == &"odd":
			continue
		GameState.inventory.add(id, 1, 1)
		assert_true(Crafting.place_dish(id))
		placed += 1
		if placed == 8:
			break
	assert_false(Crafting.has_set(&"fine"), "良品摆满不是优席")
	Crafting.clear_table()
	placed = 0
	for id: StringName in Database.recipes:
		if Database.recipes[id].from == &"odd":
			continue
		GameState.inventory.add(id, 1, 2)
		assert_true(Crafting.place_dish(id))
		placed += 1
		if placed == 8:
			break
	assert_true(Crafting.has_set(&"fine"))
	assert_eq(Crafting.table_quality[0], 2)
	Crafting.clear_table()
	assert_true(Crafting.has_set(&"fine"), "菜撤了牌还在")
	var saved := Crafting.save_data()
	Crafting.reset_data()
	assert_false(Crafting.has_set(&"terms"))
	Crafting.load_data(saved)
	assert_true(Crafting.has_set(&"terms"))
	assert_true(Crafting.has_set(&"homes"))
	assert_true(Crafting.has_set(&"fine"))
	var house: GameMap = (load(SceneRouter.MAPS[&"farmhouse"]) as PackedScene).instantiate()
	add_child_autofree(house)
	await wait_process_frames(2)
	var plaques: Array = house.get(&"_plaques")
	assert_eq(plaques.size(), 3)
	Residents.talk(&"ahe", false)
	var mentioned := banners.size()
	Residents.talk(&"ahe", false)
	assert_string_contains(banners[-1], "阿禾")
	assert_string_contains(banners[-1], "节气牌")
	Residents.talk(&"ahe", false)
	Residents.talk(&"ahe", false)
	assert_eq(banners.size(), mentioned + 3, "三块牌各提一次")
	EventBus.banner_requested.disconnect(note)


func test_the_sixteen_dishes_fill_out_seventy_two() -> void:
	var ids: Array[StringName] = [
		&"pan_loach", &"vinegar_carp", &"steam_grass_carp", &"steam_sharpbelly",
		&"clam_soup", &"winter_shoot", &"chili_potato", &"pickle_rice",
		&"caltrop_porridge", &"hawthorn_cake", &"kelp_soup", &"chrys_tea",
		&"steam_fog_carp", &"catfish_soup", &"tide_soup", &"giant_melon",
	]
	assert_eq(Journal.menu_ids().size(), 72, "食单是七十二道，不算说不上来的那一碗")
	assert_false(Journal.menu_ids().has(&"odd_bowl"))
	assert_eq(Journal.menu_ids()[0], &"radish_soup")
	assert_eq(Database.item(&"odd_bowl").price, 8)
	var terms: Dictionary = {}
	for recipe_id: StringName in Database.recipes:
		var any: RecipeDef = Database.recipes[recipe_id]
		if any.term != &"":
			terms[any.term] = true
	assert_eq(terms.size(), 24, "节气菜仍是原来那二十四道")
	for id: StringName in ids:
		var rec: RecipeDef = Database.recipes[id]
		assert_eq(rec.from, &"yunniang", "%s 是云娘教的" % id)
		assert_eq(rec.term, &"", "%s 不占节气" % id)
		assert_false(Crafting.knows(id), "%s 开局不会" % id)
		assert_eq(Database.item(id).buff, &"")
		assert_gt(Database.item(id).energy, 0)
		assert_lte(Database.item(id).price, Ledger.ingredient_sum(rec))
		var img: Image = Image.load_from_file(ProjectSettings.globalize_path("res://art/food/%s.png" % id))
		assert_not_null(img, "%s 没有菜的图" % id)
		if img == null:
			continue
		assert_eq(img.get_size(), Vector2i(128, 32), "%s 的图不是四帧" % id)
	assert_eq(Database.recipes[&"giant_melon"].ingredients[&"watermelon"], 4)
	assert_eq(Database.recipes[&"clam_soup"].season, &"spring")
	assert_eq(Database.recipes[&"winter_shoot"].season, &"winter")
	assert_eq(Database.recipes[&"chrys_tea"].season, &"autumn")
	assert_eq(Database.recipes[&"tide_soup"].season, &"winter")
	assert_eq(Database.recipes[&"giant_melon"].season, &"summer")
	assert_eq(Database.recipes[&"chili_potato"].season, &"")
	assert_true(Crafting.learn("yunniang"))
	assert_true(Crafting.knows(&"fish_soup"))
	assert_eq(Crafting.last_dish, "鲫鱼萝卜汤")
	assert_false(Crafting.knows(&"pan_loach"))
	var hidden := Journal.menu_line(&"winter_shoot")
	assert_string_contains(hidden, "炒")
	assert_string_contains(hidden, "冬天")
	assert_false(hidden.contains("冬笋"))
	assert_string_contains(Journal.menu_line(&"giant_melon"), "切")
	assert_string_contains(Journal.menu_line(&"giant_melon"), "夏天")
	GameState.set_flag(Database.recipes[&"giant_melon"].known_flag())
	GameState.inventory.add(&"watermelon", 3)
	assert_false(Crafting.cook(&"giant_melon"), "三个西瓜不够")
	GameState.inventory.add(&"watermelon", 1)
	assert_true(Crafting.cook(&"giant_melon"))
	assert_eq(GameState.inventory.count_of(&"watermelon"), 0)
	assert_eq(GameState.inventory.count_of(&"giant_melon"), 1)
	var roster := ResidentsPanel.new()
	add_child_autofree(roster)
	var edge := 0.0
	var bottom := 0.0
	for cell: Control in roster._menu_cells:
		edge = maxf(edge, cell.position.x + cell.size.x)
		bottom = maxf(bottom, cell.position.y + cell.size.y)
	assert_eq(roster._menu_cells.size(), 72)
	assert_lte(edge, ResidentsPanel.PANEL_SIZE.x, "食单右边出了框")
	assert_lte(roster._menu_line.position.y + roster._menu_line.size.y, ResidentsPanel.PANEL_SIZE.y, "菜名出了框")
	assert_lt(bottom, roster._menu_line.position.y, "格子压住了菜名")
