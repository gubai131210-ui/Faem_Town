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
	assert_eq(Database.machines.size(), 6, "六台设备")
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
	assert_eq(entries.size(), 6)
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


func test_yunniang_teaches_one_dish_a_day() -> void:
	assert_true(Crafting.has_lesson("yunniang"))
	assert_true(Crafting.learn("yunniang"))
	assert_true(Crafting.knows(&"fish_soup"))
	assert_eq(Crafting.last_dish, "鲫鱼萝卜汤")
	assert_false(Crafting.has_lesson("yunniang"), "一天只教一道")
	assert_false(Crafting.learn("yunniang"))
	var days := 0
	while days < 30:
		GameClock.advance_day()
		days += 1
		if not Crafting.learn("yunniang"):
			break
	for id: StringName in Database.recipes:
		if Database.recipes[id].from == &"memory":
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


func test_food_can_be_sold() -> void:
	assert_true(Database.item(&"radish_soup").sellable())
	assert_true(Database.item(&"pickles").sellable())
