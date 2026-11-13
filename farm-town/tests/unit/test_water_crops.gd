extends GutTest
## M1 第三批：水渠、水田、水稻和莲藕、冬小麦、茶树、架子、巨型作物、四季的树。

const TMP_SAVES := "user://test_saves"
const T := Vector2i(5, 5)

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


## 从 (0, 5) 的水源向右挖 n 格水渠。
func _canal(farm: FarmState, n: int) -> void:
	for x in n:
		farm.dig_canal(Vector2i(x, 5), x == 0)


# ---------------------------------------------------------------- 水渠

func test_canal_needs_a_connection_to_water() -> void:
	var farm := FarmState.new()
	assert_true(farm.dig_canal(Vector2i(3, 5), false))
	assert_false(farm.is_flooded(Vector2i(3, 5)), "没接到水源是干的")
	assert_false(farm.dig_canal(Vector2i(3, 5), false), "不能重复挖")
	farm.dig_canal(Vector2i(1, 5), true)
	assert_true(farm.is_flooded(Vector2i(1, 5)))
	assert_false(farm.is_flooded(Vector2i(3, 5)), "中间断着")
	farm.dig_canal(Vector2i(2, 5), false)
	assert_true(farm.is_flooded(Vector2i(3, 5)), "接通以后水流过来")
	farm.fill_canal(Vector2i(2, 5))
	assert_false(farm.is_flooded(Vector2i(3, 5)), "填掉中间又断了")


func test_canal_does_not_connect_diagonally() -> void:
	var farm := FarmState.new()
	farm.dig_canal(Vector2i(0, 0), true)
	farm.dig_canal(Vector2i(1, 1), false)
	assert_false(farm.is_flooded(Vector2i(1, 1)))


func test_canal_irrigates_two_tiles_around() -> void:
	var farm := FarmState.new()
	_canal(farm, 3)
	assert_true(farm.is_irrigated(Vector2i(2, 3)))
	assert_true(farm.is_irrigated(Vector2i(4, 7)), "斜着两格也算")
	assert_false(farm.is_irrigated(Vector2i(2, 2)))
	assert_false(farm.is_irrigated(Vector2i(5, 5)))


func test_irrigated_soil_is_wet_every_morning() -> void:
	var farm := FarmState.new()
	_canal(farm, 3)
	var near := Vector2i(2, 4)
	var far := Vector2i(2, 9)
	farm.till(near)
	farm.till(far)
	assert_true(farm.is_wet(near), "在水渠边开垦出来就是湿的")
	assert_false(farm.is_wet(far))
	farm.advance_day(&"spring", &"sunny", false)
	assert_true(farm.is_wet(near))
	assert_false(farm.is_wet(far))


func test_digging_a_canal_wets_soil_already_there() -> void:
	var farm := FarmState.new()
	farm.till(Vector2i(1, 4))
	assert_false(farm.is_wet(Vector2i(1, 4)))
	_canal(farm, 2)
	assert_true(farm.is_wet(Vector2i(1, 4)))


func test_dry_canal_irrigates_nothing() -> void:
	var farm := FarmState.new()
	farm.dig_canal(Vector2i(3, 5), false)
	farm.till(Vector2i(3, 4))
	assert_false(farm.is_irrigated(Vector2i(3, 4)))
	assert_false(farm.is_wet(Vector2i(3, 4)))


func test_canal_and_soil_cannot_share_a_tile() -> void:
	var farm := FarmState.new()
	farm.till(T)
	assert_false(farm.dig_canal(T, true), "耕地上不能挖水渠")
	farm.dig_canal(Vector2i(1, 1), true)
	assert_false(farm.till(Vector2i(1, 1)), "水渠上不能开垦")


func test_canal_raises_quality_score() -> void:
	var farm := FarmState.new()
	_canal(farm, 2)
	var near := Vector2i(1, 4)
	farm.till(near)
	farm.till(Vector2i(9, 9))
	farm.plant(near, &"white_radish")
	farm.plant(Vector2i(9, 9), &"white_radish")
	assert_eq(farm.quality_score(near), 1)
	assert_eq(farm.quality_score(Vector2i(9, 9)), 0)


# ---------------------------------------------------------------- 水田

func test_paddy_needs_water_nearby_and_empty_soil() -> void:
	var farm := FarmState.new()
	farm.till(T)
	assert_false(farm.set_paddy(T, true), "离水渠太远")
	_canal(farm, 4)
	assert_true(farm.set_paddy(T, true))
	assert_true(farm.is_paddy(T))
	assert_false(farm.set_paddy(T, true), "已经是水田")
	assert_false(farm.set_paddy(Vector2i(4, 4), true), "没开垦的地不行")
	assert_true(farm.set_paddy(T, false), "可以把水放掉")
	farm.plant(T, &"white_radish")
	assert_false(farm.set_paddy(T, true), "有作物的地不行")


func test_paddy_crops_only_in_paddy_and_dry_crops_only_on_dry_soil() -> void:
	var farm := FarmState.new()
	_canal(farm, 4)
	var dry := Vector2i(3, 4)
	farm.till(T)
	farm.till(dry)
	farm.set_paddy(T, true)
	assert_false(farm.plant(dry, &"rice"), "水稻不能种旱地")
	assert_false(farm.plant(T, &"tomato"), "水田里不能种番茄")
	assert_true(farm.plant(T, &"rice"))
	assert_true(farm.plant(dry, &"tomato"))


func test_rice_grows_in_paddy_without_watering() -> void:
	var farm := FarmState.new()
	_canal(farm, 4)
	farm.till(T)
	farm.set_paddy(T, true)
	farm.plant(T, &"rice")
	for i in Database.crop(&"rice").total_days():
		farm.advance_day(&"summer", &"sunny", false, true)
	assert_true(farm.is_ripe(T), "水田一直有水，小暑也不怕")
	assert_eq(farm.harvest(T), &"rice")


func test_paddy_dries_when_canal_is_cut() -> void:
	var farm := FarmState.new()
	_canal(farm, 4)
	farm.till(T)
	farm.set_paddy(T, true)
	farm.plant(T, &"rice")
	farm.fill_canal(Vector2i(1, 5))
	farm.advance_day(&"summer")
	assert_eq(farm.crop_days_at(T), 1, "断水那天地还是湿的")
	farm.advance_day(&"summer")
	assert_eq(farm.crop_days_at(T), 1, "之后没水就不长")
	assert_true(farm.is_paddy(T))


func test_lotus_gives_a_flower_too() -> void:
	var def := Database.crop(&"lotus_root")
	assert_true(def.paddy)
	assert_eq(def.bonus_produce, &"lotus_flower")
	assert_true(Database.item(&"lotus_flower").sellable())


func test_canals_and_paddies_survive_save() -> void:
	var farm := FarmState.new()
	_canal(farm, 4)
	farm.till(T)
	farm.set_paddy(T, true)
	var data: Variant = JSON.parse_string(JSON.stringify(farm.to_dict()))
	var copy := FarmState.new()
	copy.from_dict(data)
	assert_true(copy.is_flooded(Vector2i(3, 5)))
	assert_true(copy.is_paddy(T))
	assert_true(copy.is_irrigated(T))
	copy.clear()
	assert_false(copy.is_canal(Vector2i(3, 5)))
	assert_false(copy.is_irrigated(T))


func test_shovel_uproots_any_crop() -> void:
	var farm := FarmState.new()
	farm.till(T)
	farm.fertilize(T, 1)
	farm.plant(T, &"white_radish")
	assert_true(farm.uproot(T))
	assert_false(farm.has_crop(T))
	assert_eq(farm.fert_at(T), 0)
	assert_false(farm.uproot(T))


# ---------------------------------------------------------------- 冬小麦与茶树

func test_wheat_is_sown_only_in_autumn() -> void:
	var def := Database.crop(&"winter_wheat")
	assert_true(def.can_sow(&"autumn"))
	assert_false(def.can_sow(&"spring"))
	assert_true(def.grows_in(&"winter"))
	var autumn: Array[StringName] = []
	for item in Shop.stock(&"autumn"):
		autumn.append(item.id)
	assert_true(autumn.has(&"winter_wheat_seed"))
	for item in Shop.stock(&"winter"):
		assert_ne(item.id, &"winter_wheat_seed", "冬天不卖麦种")


func test_wheat_overwinters_and_ripens_at_mangzhong() -> void:
	var farm := FarmState.new()
	var def := Database.crop(&"winter_wheat")
	farm.till(T)
	farm.plant(T, &"winter_wheat")
	# 秋季最后一天（全年第 72 天）种下，从第 73 天开始一天天过，不浇水，中间有霜
	var ripe_day := -1
	for day in range(73, 73 + 96):
		var season: StringName = Database.SEASON_IDS[((day - 1) / 24) % 4]
		farm.advance_day(season, &"sunny", false, false, day % 7 == 0, GameClock.term_index_of(day))
		assert_false(farm.is_dead(T), "第 %d 天" % day)
		if farm.is_ripe(T) and ripe_day < 0:
			ripe_day = day
	assert_eq(ripe_day, 96 + 24 + 9, "来年夏季第 9 天（芒种）成熟")
	assert_eq(farm.crop_days_at(T), def.total_days())


func test_wheat_sown_early_still_waits_for_mangzhong() -> void:
	var farm := FarmState.new()
	farm.till(T)
	farm.plant(T, &"winter_wheat")
	for day in range(50, 96 + 24 + 9):
		farm.advance_day(&"", &"sunny", false, false, false, GameClock.term_index_of(day))
	assert_false(farm.is_ripe(T), "芒种前一天还没熟")
	farm.advance_day(&"", &"sunny", false, false, false, GameClock.term_index_of(96 + 24 + 9))
	assert_true(farm.is_ripe(T))


func test_can_ripen_window() -> void:
	var def := Database.crop(&"winter_wheat")
	assert_eq(def.ripe_term_index, 8, "芒种是一年里第 9 个节气")
	assert_false(def.can_ripen_at(7))
	assert_true(def.can_ripen_at(8))
	assert_true(def.can_ripen_at(11))
	assert_false(def.can_ripen_at(12), "过了夏天不行")
	assert_true(def.can_ripen_at(-1), "不检查节气时不拦")
	assert_true(Database.crop(&"tomato").can_ripen_at(3))


func test_tea_grows_all_year_without_water_and_regrows_each_term() -> void:
	var farm := FarmState.new()
	var def := Database.crop(&"tea")
	farm.till(T)
	farm.plant(T, &"tea")
	for i in def.total_days():
		farm.advance_day(&"winter", &"snow", false, true, true)
	assert_true(farm.is_ripe(T), "不浇水、有霜、高温都照长")
	assert_eq(farm.harvest(T), &"tea_leaf")
	assert_true(farm.has_crop(T))
	for i in GameClock.DAYS_PER_TERM:
		assert_false(farm.is_ripe(T))
		farm.advance_day(&"spring")
	assert_true(farm.is_ripe(T), "一个节气后又能采")


func test_tea_is_best_around_guyu() -> void:
	var def := Database.crop(&"tea")
	assert_eq(def.bonus_in_term(&"guyu"), 2)
	assert_eq(def.bonus_in_term(&"qingming"), 1)
	assert_eq(def.bonus_in_term(&"lixia"), 1)
	assert_eq(def.bonus_in_term(&"dashu"), 0)
	var farm := FarmState.new()
	farm.till(T)
	farm.plant(T, &"tea")
	assert_eq(farm.harvest_quality(T, 0.2, 0), 0)
	assert_eq(farm.harvest_quality(T, 0.2, def.bonus_in_term(&"guyu")), 2)


# ---------------------------------------------------------------- 架子与巨型作物

func test_trellis_crop_blocks_walking_once_sprouted() -> void:
	var farm := FarmState.new()
	farm.till(T)
	farm.plant(T, &"pea")
	assert_false(farm.blocks_walking(T), "刚种下还能走过去")
	for i in 2:
		farm.water(T)
		farm.advance_day(&"spring")
	assert_true(farm.blocks_walking(T))
	farm.advance_day(&"summer")
	assert_false(farm.blocks_walking(T), "枯死以后不挡路")
	var t2 := Vector2i(6, 5)
	farm.till(t2)
	farm.plant(t2, &"white_radish")
	farm.water(t2)
	farm.advance_day(&"spring")
	assert_false(farm.blocks_walking(t2), "没架子的作物不挡路")


func test_melon_can_grow_giant() -> void:
	var def := Database.crop(&"watermelon")
	assert_gt(def.giant_chance, 0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var farm := FarmState.new()
	for x in 200:
		var t := Vector2i(x, 0)
		farm.till(t)
		farm.plant(t, &"watermelon")
	for i in def.total_days() + 3:
		for t: Vector2i in farm.soil:
			farm.water(t)
		farm.advance_day(&"summer", &"sunny", false, false, false, -1, rng)
	var giants := farm.giant_count()
	assert_between(giants, 4, 40, "200 株里大约 8% 长成巨型，熟了以后不会再掷")
	for t: Vector2i in farm.crops.keys():
		if farm.is_giant(t):
			assert_eq(farm.yield_at(t, 0.99), FarmState.GIANT_YIELD)
			farm.harvest(t)
			assert_false(farm.has_crop(t))
			return


func test_no_giants_without_rng_and_flag_is_saved() -> void:
	var farm := FarmState.new()
	farm.till(T)
	farm.plant(T, &"pumpkin")
	for i in Database.crop(&"pumpkin").total_days():
		farm.water(T)
		farm.advance_day(&"autumn")
	assert_false(farm.is_giant(T))
	farm.crops[T]["giant"] = true
	var copy := FarmState.new()
	copy.from_dict(farm.to_dict())
	assert_true(copy.is_giant(T))


# ---------------------------------------------------------------- 铁锹和素材

func test_catalogue_sells_shovel_once() -> void:
	GameState.set_flag(&"lamp_plaza")
	GameState.money = 1000
	var entry: ShopEntry = null
	for e in Shop.entries(&"spring"):
		if e.item_id == &"shovel":
			entry = e
	assert_not_null(entry)
	assert_true(entry.once)
	assert_eq(Shop.affordable_entry(entry, 5), 1)
	assert_true(Shop.buy_entry(entry, 1))
	assert_eq(GameState.inventory.count_of(&"shovel"), 1)
	for e in Shop.entries(&"spring"):
		assert_ne(e.item_id, &"shovel", "买过就不再卖")


func test_new_art_exists() -> void:
	for season in 4:
		for v in 3:
			assert_eq(PixelArt.round_tree(v, season).get_size(), Vector2i(44, 60))
		for v in 2:
			assert_eq(PixelArt.plum_tree(v, season).get_size(), Vector2i(48, 60))
		assert_false(PixelArt.tuft(season).is_invisible())
	assert_ne(PixelArt.round_tree(0, 0).get_data(), PixelArt.round_tree(0, 2).get_data())
	assert_eq(CropArt.giant(&"watermelon").get_size(), Vector2i(32, 32))
	assert_false(UiKit.item_icon(&"shovel").get_image().is_invisible())
	assert_false(PixelArt.icon("lotus_flower").is_invisible())
