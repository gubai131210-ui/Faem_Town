extends GutTest
## M1：节气、天气、作物的季节与再收、出货、种子目录。

const TMP_SAVES := "user://test_saves"

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


# ---------------------------------------------------------------- 节气

func test_each_term_lasts_four_days_and_year_wraps() -> void:
	assert_eq(Database.terms.size(), 24)
	GameClock.day = 1
	assert_eq(GameClock.term_name(), "立春")
	GameClock.day = 4
	assert_eq(GameClock.term_id(), &"lichun")
	GameClock.day = 5
	assert_eq(GameClock.term_name(), "雨水")
	GameClock.day = 24
	assert_eq(GameClock.term_name(), "谷雨")
	GameClock.day = 25
	assert_eq(GameClock.term_name(), "立夏")
	GameClock.day = 96
	assert_eq(GameClock.term_name(), "大寒")
	GameClock.day = 97
	assert_eq(GameClock.term_name(), "立春", "第二年从头开始")


func test_term_season_matches_calendar_season() -> void:
	for d in range(1, 97):
		GameClock.day = d
		assert_eq(GameClock.term().season, GameClock.season_id(), "第 %d 天" % d)


# ---------------------------------------------------------------- 天气

func test_weather_pick_follows_weights() -> void:
	var w := {Weather.SUNNY: 50, Weather.RAIN: 30, Weather.FOG: 20}
	assert_eq(Weather.pick(w, 0.0), Weather.SUNNY)
	assert_eq(Weather.pick(w, 0.49), Weather.SUNNY)
	assert_eq(Weather.pick(w, 0.5), Weather.RAIN)
	assert_eq(Weather.pick(w, 0.79), Weather.RAIN)
	assert_eq(Weather.pick(w, 0.8), Weather.FOG)
	assert_eq(Weather.pick(w, 0.999), Weather.FOG)


func test_guyu_always_rains_and_winter_never_rains() -> void:
	for d in range(21, 25):
		var w := Weather.weights_for(d)
		for k: StringName in w:
			assert_true(k == Weather.RAIN or k == Weather.STORM, "谷雨第 %d 天出现了 %s" % [d, k])
	for d in range(73, 97):
		var w := Weather.weights_for(d)
		assert_false(w.has(Weather.RAIN), "冬天不下雨")
		# 节日那天只有晴和多云
		if Database.festival_on(d) == null:
			assert_true(w.has(Weather.SNOW))


func test_yushui_rains_more_than_lichun() -> void:
	var before: int = Weather.weights_for(1)[Weather.RAIN]
	var during: int = Weather.weights_for(5)[Weather.RAIN]
	assert_gt(during, before)


func test_new_day_moves_forecast_into_today() -> void:
	Weather.today = Weather.SUNNY
	Weather.tomorrow = Weather.FOG
	GameClock.advance_day()
	assert_eq(Weather.yesterday, Weather.SUNNY)
	assert_eq(Weather.today, Weather.FOG)
	assert_true(Weather.NAMES.has(Weather.tomorrow))


func test_rain_waters_the_farm_overnight() -> void:
	var t := Vector2i(4, 4)
	Farming.state.till(t)
	Weather.tomorrow = Weather.RAIN
	GameClock.advance_day()
	assert_true(Farming.state.is_wet(t), "下雨天早上地是湿的")
	Weather.tomorrow = Weather.SUNNY
	GameClock.advance_day()
	assert_false(Farming.state.is_wet(t), "晴天早上地是干的")


func test_bailu_dew_wets_the_farm() -> void:
	var t := Vector2i(4, 4)
	Farming.state.till(t)
	GameClock.day = 56  # 明天是秋 9 日，白露第一天
	Weather.tomorrow = Weather.SUNNY
	GameClock.advance_day()
	assert_eq(GameClock.term_id(), &"bailu")
	assert_true(Farming.state.is_wet(t))


func test_radio_has_a_voice_clip_for_every_term_and_weather() -> void:
	for def in Database.terms:
		assert_true(ResourceLoader.exists(Audio.RADIO_DIR + "today_%s.wav" % def.id), "缺少节气 %s 的播报" % def.name)
	for kind: StringName in Weather.NAMES:
		assert_true(ResourceLoader.exists(Audio.RADIO_DIR + "w_%s.wav" % kind), "缺少天气 %s 的播报" % kind)
	assert_true(ResourceLoader.exists(Audio.RADIO_DIR + "tomorrow.wav"))


func test_radio_report_follows_today_and_tomorrow() -> void:
	GameClock.day = 5
	Weather.today = Weather.RAIN
	Weather.tomorrow = Weather.FOG
	assert_eq(Array(Weather.report_clips()), ["today_yushui", "w_rain", "tomorrow", "w_fog"])
	Audio.play_radio(Weather.report_clips())
	assert_true(Audio.is_radio_playing())
	Audio.stop_radio()
	assert_false(Audio.is_radio_playing())


# ---------------------------------------------------------------- 作物

func test_out_of_season_crop_withers_and_can_be_cleared() -> void:
	var farm := FarmState.new()
	var t := Vector2i(1, 1)
	farm.till(t)
	farm.plant(t, &"white_radish")
	farm.advance_day(&"spring")
	assert_false(farm.is_dead(t))
	farm.advance_day(&"summer")
	assert_true(farm.is_dead(t), "春季作物到夏天枯死")
	assert_false(farm.is_ripe(t))
	assert_false(farm.can_plant(t), "枯死的作物占着地")
	assert_eq(farm.harvest(t), &"")
	assert_true(farm.clear_dead(t))
	assert_true(farm.can_plant(t))


func test_corn_survives_from_summer_into_autumn() -> void:
	var farm := FarmState.new()
	var t := Vector2i(1, 1)
	farm.till(t)
	farm.plant(t, &"corn")
	farm.advance_day(&"autumn")
	assert_false(farm.is_dead(t))
	farm.advance_day(&"winter")
	assert_true(farm.is_dead(t))


func test_regrowing_crop_stays_and_ripens_again() -> void:
	var farm := FarmState.new()
	var t := Vector2i(2, 2)
	var def := Database.crop(&"tomato")
	farm.till(t)
	farm.plant(t, &"tomato")
	for i in def.total_days():
		farm.water(t)
		farm.advance_day(&"summer")
	assert_true(farm.is_ripe(t))
	assert_eq(farm.harvest(t), &"tomato")
	assert_true(farm.has_crop(t), "番茄收完还在地里")
	assert_false(farm.is_ripe(t))
	for i in def.regrow_days - 1:
		farm.water(t)
		farm.advance_day(&"summer")
	assert_false(farm.is_ripe(t))
	farm.water(t)
	farm.advance_day(&"summer")
	assert_true(farm.is_ripe(t), "过了再收的天数又熟了")


func test_ripe_crop_does_not_keep_counting_days() -> void:
	var farm := FarmState.new()
	var t := Vector2i(2, 2)
	farm.till(t)
	farm.plant(t, &"white_radish")
	for i in 9:
		farm.water(t)
		farm.advance_day(&"spring")
	assert_eq(farm.crop_days_at(t), Database.crop(&"white_radish").total_days())


func test_fog_crop_grows_only_on_fog_days() -> void:
	var farm := FarmState.new()
	var t := Vector2i(3, 3)
	farm.till(t)
	farm.plant(t, &"fog_bell")
	farm.water(t)
	farm.advance_day(&"spring", &"sunny")
	assert_eq(farm.crop_days_at(t), 0, "不是雾天，浇了水也不长")
	farm.advance_day(&"spring", &"fog")
	assert_eq(farm.crop_days_at(t), 1, "雾天不浇水也长")


func test_extra_yield_depends_on_roll() -> void:
	var farm := FarmState.new()
	var t := Vector2i(5, 5)
	farm.till(t)
	farm.plant(t, &"potato")
	assert_eq(farm.yield_at(t, 0.0), 0, "没熟收不到")
	for i in Database.crop(&"potato").total_days():
		farm.water(t)
		farm.advance_day(&"spring")
	assert_eq(farm.yield_at(t, 0.1), 2)
	assert_eq(farm.yield_at(t, 0.9), 1)


func test_dead_flag_survives_save_round_trip() -> void:
	var farm := FarmState.new()
	var t := Vector2i(1, 1)
	farm.till(t)
	farm.plant(t, &"white_radish")
	farm.advance_day(&"summer")
	var data: Variant = JSON.parse_string(JSON.stringify(farm.to_dict()))
	var copy := FarmState.new()
	copy.from_dict(data)
	assert_true(copy.is_dead(t))
	# 旧存档里没有第五个字段，读出来应当是活的
	copy.from_dict({"soil": [[1, 1, false]], "crops": [[1, 1, "white_radish", 2]]})
	assert_false(copy.is_dead(t))
	assert_eq(copy.crop_days_at(t), 2)


func test_every_crop_has_art_and_icons() -> void:
	for id: StringName in Database.crops:
		for stage in 4:
			var img := PixelArt.crop(id, stage)
			assert_eq(img.get_size(), Vector2i(16, 24), "%s 阶段 %d" % [id, stage])
			assert_false(img.is_invisible(), "%s 阶段 %d 是空图" % [id, stage])
		var def := Database.crop(id)
		assert_false(PixelArt.icon(Database.item(def.produce).icon).is_invisible(), "%s 的产物图标" % id)
		assert_false(PixelArt.icon(Database.item(def.seed).icon).is_invisible(), "%s 的种子图标" % id)


# ---------------------------------------------------------------- 出货与商店

func test_shipping_pays_next_morning() -> void:
	GameState.money = 100
	assert_true(Shipping.add(&"white_radish", 3))
	assert_false(Shipping.add(&"hoe", 1), "工具不能卖")
	assert_false(Shipping.add(&"white_radish_seed", 1), "种子不收")
	assert_eq(Shipping.pending_value(), 105)
	assert_eq(GameState.money, 100, "当天不到账")
	Weather.tomorrow = Weather.SUNNY
	GameClock.advance_day()
	assert_eq(GameState.money, 205)
	assert_eq(Shipping.last_income, 105)
	assert_eq(Shipping.pending_value(), 0)
	GameClock.advance_day()
	assert_eq(Shipping.last_income, 0, "没出货的那天收入归零")


func test_shop_sells_seeds_of_the_season_only() -> void:
	var spring := Shop.stock(&"spring")
	var ids: Array[StringName] = []
	for def in spring:
		ids.append(def.id)
		assert_eq(def.kind, &"seed")
	assert_true(ids.has(&"white_radish_seed"))
	assert_true(ids.has(&"fog_bell_seed"), "雾铃草全年都卖")
	assert_false(ids.has(&"tomato_seed"), "夏季种子春天不卖")
	assert_false(ids.has(&"strawberry_seed"), "草莓种子只在播种节卖")
	for i in range(1, spring.size()):
		assert_true(spring[i - 1].price <= spring[i].price, "按价格排序")
	assert_gt(Shop.stock(&"winter").size(), 0, "冬天也有东西可种")


func test_shop_buy_checks_money_and_space() -> void:
	GameState.money = 25
	assert_eq(Shop.affordable(&"white_radish_seed", 5), 2)
	assert_false(Shop.buy(&"white_radish_seed", 3), "钱不够不能买")
	assert_eq(GameState.money, 25)
	assert_true(Shop.buy(&"white_radish_seed", 2))
	assert_eq(GameState.money, 5)
	assert_eq(GameState.inventory.count_of(&"white_radish_seed"), 14)
	GameState.money = 10000
	for i in GameState.inventory.size:
		if GameState.inventory.is_empty_slot(i):
			GameState.inventory.add(&"hoe")
	assert_eq(Shop.affordable(&"bok_choy_seed", 1), 0, "背包满了买不了新种类")
	assert_false(Shop.buy(&"bok_choy_seed", 1))
	assert_eq(GameState.money, 10000)


func test_weather_and_shipping_are_saved() -> void:
	Weather.today = Weather.FOG
	Weather.tomorrow = Weather.STORM
	Shipping.add(&"white_radish", 4)
	assert_true(SaveSystem.save(1, GameState.save_meta()))
	SaveSystem.reset_all()
	assert_eq(Shipping.count_of(&"white_radish"), 0)
	assert_true(SaveSystem.load_slot(1))
	assert_eq(Weather.today, Weather.FOG)
	assert_eq(Weather.tomorrow, Weather.STORM)
	assert_eq(Shipping.count_of(&"white_radish"), 4)
