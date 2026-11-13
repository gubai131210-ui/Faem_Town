extends GutTest
## M1 第二批：品质、肥料、工具升级与蓄力范围、小暑、霜、雷劈。

const TMP_SAVES := "user://test_saves"
const T := Vector2i(3, 3)

var _old_dir := ""


func before_each() -> void:
	_old_dir = SaveSystem.base_dir
	SaveSystem.base_dir = TMP_SAVES
	SaveSystem.reset_all()


func after_each() -> void:
	for i in SaveSystem.SLOT_COUNT:
		SaveSystem.delete(i)
	SaveSystem.base_dir = _old_dir
	SaveSystem.current_slot = -1
	SaveSystem.reset_all()


func _ripe_radish(farm: FarmState, t: Vector2i, bonus: int = 0) -> void:
	farm.till(t)
	farm.plant(t, &"white_radish", bonus)
	for i in Database.crop(&"white_radish").total_days():
		farm.water(t)
		farm.advance_day()


# ---------------------------------------------------------------- 品质

func test_quality_for_follows_score_and_roll() -> void:
	assert_eq(FarmState.quality_for(0, 0.05), 1, "没施肥也偶尔出良品")
	assert_eq(FarmState.quality_for(0, 0.5), 0)
	assert_eq(FarmState.quality_for(0, 0.0), 1, "没有加成时出不了优品")
	assert_eq(FarmState.quality_for(1, 0.05), 2)
	assert_eq(FarmState.quality_for(1, 0.3), 1)
	assert_eq(FarmState.quality_for(1, 0.9), 0)
	assert_eq(FarmState.quality_for(3, 0.5), 2)
	assert_eq(FarmState.quality_for(9, 0.5), 2, "分数超出表按最高档算")
	assert_eq(FarmState.quality_for(-2, 0.99), 0)


func test_better_score_never_lowers_quality() -> void:
	for step in 20:
		var roll := step / 20.0
		for score in 3:
			assert_true(FarmState.quality_for(score + 1, roll) >= FarmState.quality_for(score, roll),
				"分数 %d 掷出 %.2f" % [score, roll])


func test_fertilizer_and_chunfen_bonus_add_up() -> void:
	var farm := FarmState.new()
	farm.till(T)
	assert_true(farm.fertilize(T, 2))
	assert_false(farm.fertilize(T, 1), "一格地只能施一次肥")
	assert_false(farm.fertilize(Vector2i(9, 9), 1), "没开垦的地不能施肥")
	farm.plant(T, &"white_radish", 1)
	assert_eq(farm.quality_score(T), 3)
	assert_eq(farm.harvest_quality(T, 0.5), 2)


func test_fertilizer_is_used_up_with_the_crop_but_stays_for_regrowing_ones() -> void:
	var farm := FarmState.new()
	farm.till(T)
	farm.fertilize(T, 1)
	_ripe_radish(farm, T)
	farm.harvest(T)
	assert_eq(farm.fert_at(T), 0, "拔掉以后肥料用完")
	var t2 := Vector2i(5, 3)
	farm.till(t2)
	farm.fertilize(t2, 1)
	farm.plant(t2, &"tomato")
	for i in Database.crop(&"tomato").total_days():
		farm.water(t2)
		farm.advance_day()
	assert_ne(farm.harvest(t2), &"")
	assert_eq(farm.fert_at(t2), 1, "能再收的作物肥料留着")


func test_fertilizer_and_bonus_survive_save() -> void:
	var farm := FarmState.new()
	farm.till(T)
	farm.fertilize(T, 2)
	farm.plant(T, &"white_radish", 1)
	var copy := FarmState.new()
	copy.from_dict(farm.to_dict())
	assert_eq(copy.fert_at(T), 2)
	assert_eq(copy.quality_score(T), 3)


func test_old_farm_save_without_new_fields_loads() -> void:
	var farm := FarmState.new()
	farm.from_dict({"soil": [[3, 3, true]], "crops": [[3, 3, "white_radish", 2, false]]})
	assert_eq(farm.crop_days_at(T), 2)
	assert_eq(farm.quality_score(T), 0)
	assert_false(farm.is_wilted(T))


func test_inventory_keeps_qualities_apart() -> void:
	var inv := Inventory.new(3)
	inv.add(&"white_radish", 2, 0)
	inv.add(&"white_radish", 1, 2)
	inv.add(&"white_radish", 1, 0)
	assert_eq(inv.count_at(0), 3)
	assert_eq(inv.quality_at(1), 2)
	assert_eq(inv.count_of(&"white_radish"), 4)
	assert_eq(inv.count_of(&"white_radish", 2), 1)
	var copy := Inventory.new(3)
	copy.from_array(inv.to_array())
	assert_eq(copy.quality_at(1), 2)
	assert_eq(copy.quality_at(0), 0)


func test_inventory_can_add_counts_only_matching_quality() -> void:
	var inv := Inventory.new(1)
	inv.add(&"white_radish", 1, 0)
	assert_true(inv.can_add(&"white_radish", 1, 0))
	assert_false(inv.can_add(&"white_radish", 1, 1), "不同品质不能叠在一起")


func test_quality_raises_selling_price() -> void:
	var def := Database.item(&"white_radish")
	assert_eq(def.price_for(0), def.price)
	assert_eq(def.price_for(1), roundi(def.price * 1.25))
	assert_eq(def.price_for(2), roundi(def.price * 1.5))
	Shipping.add(&"white_radish", 2, 0)
	Shipping.add(&"white_radish", 1, 2)
	assert_eq(Shipping.count_of(&"white_radish"), 3)
	assert_eq(Shipping.pending_value(), def.price * 2 + def.price_for(2))


func test_shipping_bin_saves_qualities_and_reads_old_format() -> void:
	Shipping.add(&"white_radish", 2, 1)
	var data: Dictionary = Shipping.save_data()
	Shipping.reset_data()
	Shipping.load_data(data)
	assert_eq(Shipping.count_of(&"white_radish", 1), 2)
	Shipping.load_data({"bin": {"white_radish": 4}})
	assert_eq(Shipping.count_of(&"white_radish", 0), 4, "旧存档的数量算普通品质")


# ---------------------------------------------------------------- 工具

func test_tool_area_grows_with_charge() -> void:
	var o := Vector2i(10, 10)
	assert_eq(ToolArea.tiles(o, GameMap.Facing.DOWN, 0), [o] as Array[Vector2i])
	assert_eq(ToolArea.tiles(o, GameMap.Facing.RIGHT, 1),
		[o, Vector2i(11, 10), Vector2i(12, 10)] as Array[Vector2i])
	var up := ToolArea.tiles(o, GameMap.Facing.UP, 2)
	assert_eq(up.size(), 5)
	assert_true(up.has(Vector2i(10, 6)))
	var wide := ToolArea.tiles(o, GameMap.Facing.LEFT, 3)
	assert_eq(wide.size(), 9)
	assert_true(wide.has(Vector2i(8, 9)) and wide.has(Vector2i(8, 11)) and wide.has(Vector2i(10, 11)))
	assert_false(wide.has(Vector2i(11, 10)), "不会作用到身后")


func test_tool_area_matches_counts_and_has_no_repeats() -> void:
	for facing in 4:
		for charge in 4:
			var tiles := ToolArea.tiles(Vector2i.ZERO, facing, charge)
			assert_eq(tiles.size(), ToolArea.COUNTS[charge])
			assert_eq(tiles[0], Vector2i.ZERO)
			var seen := {}
			for t in tiles:
				seen[t] = true
			assert_eq(seen.size(), tiles.size())


func test_tool_upgrade_costs_money_and_stops_at_gold() -> void:
	# 矿石管够，这里只看钱和等级（要矿石那一半在 test_act3.gd）
	for ore: StringName in [&"iron_ore", &"copper_ore", &"silver_ore", &"gold_ore", &"coal"]:
		GameState.inventory.add(ore, 50)
	GameState.money = 1000
	var entry := _upgrade_entry(&"hoe")
	assert_not_null(entry)
	assert_eq(entry.price, Shop.UPGRADE_PRICES[0])
	assert_true(Shop.buy_entry(entry, 1))
	assert_eq(GameState.money, 0)
	assert_eq(GameState.tool_level(&"hoe"), 1)
	assert_eq(GameState.tool_level(&"watering_can"), 0)
	assert_eq(GameState.display_name(Database.item(&"hoe")), "铁锄头")
	assert_false(Shop.buy_entry(_upgrade_entry(&"hoe"), 1), "钱不够不能升")
	GameState.money = 99999
	while _upgrade_entry(&"hoe") != null:
		assert_true(Shop.buy_entry(_upgrade_entry(&"hoe"), 1))
	assert_eq(GameState.tool_level(&"hoe"), GameState.MAX_TOOL_LEVEL)
	assert_false(GameState.upgrade_tool(&"hoe"))


func test_tool_levels_survive_save() -> void:
	GameState.upgrade_tool(&"watering_can")
	GameState.upgrade_tool(&"watering_can")
	SaveSystem.save(0, GameState.save_meta())
	SaveSystem.reset_all()
	assert_eq(GameState.tool_level(&"watering_can"), 0)
	SaveSystem.load_slot(0)
	assert_eq(GameState.tool_level(&"watering_can"), 2)


func test_catalogue_sells_fertilizer_every_season() -> void:
	# 好肥料要点亮广场灯以后才上架
	GameState.set_flag(&"lamp_plaza")
	# 好肥料要点亮广场灯以后才上架
	GameState.set_flag(&"lamp_plaza")
	for season: StringName in [&"spring", &"summer", &"autumn", &"winter"]:
		var ids: Array[StringName] = []
		for e in Shop.entries(season):
			if not e.upgrade:
				ids.append(e.item_id)
		assert_true(ids.has(&"fertilizer") and ids.has(&"fine_fertilizer"), String(season))
	assert_false(Database.item(&"fertilizer").sellable(), "肥料不能放进出货箱")


func test_tool_icons_exist_for_every_tier() -> void:
	for level in GameState.MAX_TOOL_LEVEL + 1:
		for n: String in ["hoe", "can"]:
			assert_eq(PixelArt.icon("%s@%d" % [n, level]).get_size(), Vector2i(16, 16))
	assert_ne(PixelArt.icon("hoe@0").get_data(), PixelArt.icon("hoe@3").get_data())
	assert_eq(PixelArt.icon("fert:1").get_size(), Vector2i(16, 16))
	assert_eq(PixelArt.weather_icon("frost").get_size(), Vector2i(11, 11))


func _upgrade_entry(tool: StringName) -> ShopEntry:
	for e in Shop.entries(&"spring"):
		if e.upgrade and e.item_id == tool:
			return e
	return null


# ---------------------------------------------------------------- 节气与天气

func test_heat_wilts_dry_crops_then_kills_them() -> void:
	var farm := FarmState.new()
	farm.till(T)
	farm.plant(T, &"tomato")
	farm.advance_day(&"summer", &"sunny", false, true)
	assert_true(farm.is_wilted(T))
	assert_false(farm.is_dead(T))
	assert_eq(farm.crop_days_at(T), 0)
	farm.advance_day(&"summer", &"sunny", false, true)
	assert_true(farm.is_dead(T), "连着两天没浇水")


func test_watering_revives_wilted_crop() -> void:
	var farm := FarmState.new()
	farm.till(T)
	farm.plant(T, &"tomato")
	farm.advance_day(&"summer", &"sunny", false, true)
	farm.water(T)
	farm.advance_day(&"summer", &"sunny", false, true)
	assert_false(farm.is_wilted(T))
	assert_false(farm.is_dead(T))
	assert_eq(farm.crop_days_at(T), 1, "浇了水当天照常生长")


func test_dry_crop_without_heat_just_waits() -> void:
	var farm := FarmState.new()
	farm.till(T)
	farm.plant(T, &"tomato")
	for i in 3:
		farm.advance_day(&"summer", &"sunny", false, false)
	assert_false(farm.is_wilted(T))
	assert_false(farm.is_dead(T))


func test_frost_kills_only_tender_crops() -> void:
	var farm := FarmState.new()
	var t2 := Vector2i(4, 3)
	farm.till(T)
	farm.till(t2)
	farm.plant(T, &"pumpkin")
	farm.plant(t2, &"napa_cabbage")
	farm.advance_day(&"autumn", &"sunny", false, false, true)
	assert_true(farm.is_dead(T))
	assert_false(farm.is_dead(t2), "大白菜耐霜")


func test_everything_that_grows_in_winter_is_hardy() -> void:
	for id: StringName in Database.crops:
		var def: CropDef = Database.crops[id]
		if def.grows_in(&"winter"):
			assert_true(def.hardy, "%s 冬天能种就得耐寒" % id)


func test_frost_weather_only_late_autumn_and_winter() -> void:
	for day in range(1, 97):
		var w: Dictionary = Weather.weights_for(day)
		var term := Database.term(GameClock.term_index_of(day))
		# 节日那天只有晴和多云
		var expected: bool = (term.id == &"shuangjiang" or term.season == &"winter") and Database.festival_on(day) == null
		assert_eq(int(w.get(Weather.FROST, 0)) > 0, expected, "第 %d 天" % day)


func test_strike_kills_one_living_crop() -> void:
	var farm := FarmState.new()
	assert_false(farm.strike(0), "没有作物可劈")
	for x in 3:
		farm.till(Vector2i(x, 0))
		farm.plant(Vector2i(x, 0), &"white_radish")
	assert_true(farm.strike(4))
	assert_eq(farm.dead_count(), 1)
	assert_true(farm.is_dead(Vector2i(1, 0)), "第 4 株绕回来是第 2 株")
	assert_true(farm.strike(0))
	assert_true(farm.strike(0))
	assert_eq(farm.dead_count(), 3)
	assert_false(farm.strike(0))


func test_frosty_morning_is_reported() -> void:
	GameClock.day = 70
	Farming.state.till(T)
	Farming.state.plant(T, &"pumpkin")
	Weather.tomorrow = Weather.FROST
	GameClock.advance_day()
	assert_eq(Weather.today, Weather.FROST)
	assert_true(Farming.state.is_dead(T))
	assert_eq(Farming.morning_notes.size(), 1)
	Weather.tomorrow = Weather.SUNNY
	GameClock.advance_day()
	assert_eq(Farming.morning_notes.size(), 0, "提示只留一天")


func test_heat_only_counts_during_xiaoshu() -> void:
	# 夏季第 17 天（全年第 41 天）起是小暑
	GameClock.day = 40
	Farming.state.till(T)
	Farming.state.plant(T, &"tomato")
	Weather.tomorrow = Weather.SUNNY
	GameClock.advance_day()
	assert_false(Farming.state.is_wilted(T), "芒种的最后一天不算高温")
	Weather.tomorrow = Weather.SUNNY
	GameClock.advance_day()
	assert_true(Farming.state.is_wilted(T), "小暑第一天没浇水就蔫")
