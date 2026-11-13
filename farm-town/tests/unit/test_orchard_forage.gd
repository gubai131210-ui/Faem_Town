extends GutTest
## M1 第四批：花、果树、大风落果、野外采集物。

const TMP_SAVES := "user://test_saves"
const T := Vector2i(5, 5)
const SEASONS: Array[StringName] = [&"spring", &"summer", &"autumn", &"winter"]

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


## 种一棵树并让它长成（在不结果的季节里长，树上是空的）。
func _grown(orchard: Orchard, kind: StringName, idle_season: StringName) -> void:
	orchard.plant(T, kind)
	for i in Database.tree(kind).grow_days:
		orchard.advance_day(idle_season)


# ---------------------------------------------------------------- 数据

func test_tables_are_valid() -> void:
	assert_eq(Database.validate(), PackedStringArray(), "数据表校验通过")
	assert_eq(Database.trees.size(), 4, "四种果树")


func test_two_flowers_every_season() -> void:
	for season in SEASONS:
		var n := 0
		for id: StringName in Database.items:
			if Database.item(id).flower == season:
				n += 1
		assert_eq(n, 2, "%s 有两种花" % season)


func test_winter_flowers_survive_frost() -> void:
	for id: StringName in [&"wintersweet", &"camellia"]:
		var def := Database.crop(id)
		assert_true(def.hardy, "%s 耐寒" % id)
		assert_true(def.can_sow(&"winter"))


func test_every_tree_has_sapling_and_produce() -> void:
	for id: StringName in Database.trees:
		var def := Database.tree(id)
		var sapling := Database.item(def.sapling)
		assert_eq(sapling.kind, &"sapling")
		assert_eq(sapling.tree, id)
		assert_gt(def.yields.size(), 0)
		for y in def.yields:
			assert_true(Database.has_item(StringName(str(y["item"]))))


func test_every_season_has_a_fruit_and_forage() -> void:
	for season in SEASONS:
		var fruit := false
		for id: StringName in Database.trees:
			if Database.tree(id).produce_in(season) != &"":
				fruit = true
		assert_true(fruit, "%s 有果树结果" % season)
		assert_gt(Foraging.options(season, -1, false).size(), 0, "%s 有采集物" % season)


func test_shop_sells_saplings() -> void:
	# 树苗要点亮广场灯以后才上架
	GameState.set_flag(&"lamp_plaza")
	var found := 0
	for e in Shop.entries(&"spring"):
		if e.item_id != &"" and Database.item(e.item_id).kind == &"sapling":
			found += 1
	assert_eq(found, 4, "目录里有四种树苗")


func test_new_art_draws() -> void:
	for id: StringName in Database.items:
		var def := Database.item(id)
		if def.icon.begins_with("wild:") or def.icon.begins_with("sapling:"):
			var img := PixelArt.icon(def.icon)
			assert_eq(img.get_size(), Vector2i(16, 16), "%s 的图标" % id)
			assert_false(img.is_invisible(), "%s 的图标不是空的" % id)
	for id: StringName in Database.trees:
		var def := Database.tree(id)
		for stage in 3:
			for season in 4:
				var img := TreeArt.tree(id, stage, season)
				assert_eq(img.get_size(), Vector2i(TreeArt.W, TreeArt.H))
				assert_false(img.is_invisible())
		var y: Dictionary = def.yields[0]
		var bare := TreeArt.tree(id, 2, SEASONS.find(StringName(str(y["season"]))))
		var loaded := TreeArt.tree(id, 2, SEASONS.find(StringName(str(y["season"]))), StringName(str(y["item"])), 3, 2)
		assert_ne(bare.get_data(), loaded.get_data(), "%s 挂果和不挂果画得不一样" % id)


# ---------------------------------------------------------------- 果树

func test_trees_need_a_gap() -> void:
	var orchard := Orchard.new()
	assert_true(orchard.plant(T, &"peach"))
	assert_false(orchard.plant(T, &"peach"), "同一格不能再种")
	assert_false(orchard.plant(T + Vector2i(1, 1), &"loquat"), "紧挨着不能种")
	assert_true(orchard.plant(T + Vector2i(2, 0), &"loquat"), "隔一格可以")
	assert_false(orchard.plant(Vector2i(20, 20), &"no_such_tree"))


func test_tree_grows_through_three_stages() -> void:
	var orchard := Orchard.new()
	orchard.plant(T, &"persimmon")
	var grow := Database.tree(&"persimmon").grow_days
	assert_eq(orchard.stage_at(T), 0)
	for i in grow / 2:
		orchard.advance_day(&"spring")
	assert_eq(orchard.stage_at(T), 1, "长到一半是小树")
	for i in grow - grow / 2 - 1:
		orchard.advance_day(&"spring")
	assert_false(orchard.is_mature(T))
	orchard.advance_day(&"spring")
	assert_true(orchard.is_mature(T))
	assert_eq(orchard.ready_at(T), 0, "柿树春天不结果")


func test_young_tree_bears_nothing() -> void:
	var orchard := Orchard.new()
	orchard.plant(T, &"persimmon")
	for i in 5:
		orchard.advance_day(&"autumn")
	assert_eq(orchard.ready_at(T), 0)


func test_mature_tree_bears_one_a_day_up_to_three() -> void:
	var orchard := Orchard.new()
	_grown(orchard, &"persimmon", &"summer")
	orchard.advance_day(&"autumn")
	assert_eq(orchard.fruit_at(T), 1)
	assert_eq(orchard.item_at(T), &"persimmon")
	for i in 5:
		orchard.advance_day(&"autumn")
	assert_eq(orchard.fruit_at(T), Orchard.MAX_FRUIT, "最多挂三个")
	assert_eq(orchard.collect(T), 3)
	assert_eq(orchard.ready_at(T), 0)
	assert_eq(orchard.collect(T), 0)


func test_peach_gives_blossom_then_fruit() -> void:
	var orchard := Orchard.new()
	_grown(orchard, &"peach", &"winter")
	orchard.advance_day(&"spring")
	orchard.advance_day(&"spring")
	assert_eq(orchard.item_at(T), &"peach_blossom")
	assert_eq(orchard.fruit_at(T), 2)
	orchard.advance_day(&"summer")
	assert_eq(orchard.item_at(T), &"peach", "换季换成桃子")
	assert_eq(orchard.fruit_at(T), 1, "上一季的花不留到夏天")
	orchard.advance_day(&"autumn")
	assert_eq(orchard.ready_at(T), 0, "秋天不结")


func test_wind_drops_fruit_and_it_rots_next_day() -> void:
	var orchard := Orchard.new()
	_grown(orchard, &"mandarin", &"autumn")
	orchard.advance_day(&"winter")
	orchard.advance_day(&"winter")
	assert_eq(orchard.fruit_at(T), 2)
	orchard.advance_day(&"winter", true)
	assert_eq(orchard.fallen_at(T), 2, "大风把树上的吹到地上")
	assert_eq(orchard.fruit_at(T), 1, "当天新结的还在树上")
	assert_eq(orchard.fallen_total(), 2)
	orchard.advance_day(&"winter")
	assert_eq(orchard.fallen_at(T), 0, "没捡的烂掉了")
	assert_eq(orchard.fruit_at(T), 2)


func test_fallen_fruit_can_be_collected() -> void:
	var orchard := Orchard.new()
	_grown(orchard, &"mandarin", &"autumn")
	orchard.advance_day(&"winter")
	orchard.advance_day(&"winter", true)
	assert_eq(orchard.collect(T), 2, "树上一个加地上一个")


func test_orchard_round_trips_through_save() -> void:
	var orchard := Orchard.new()
	_grown(orchard, &"mandarin", &"autumn")
	orchard.advance_day(&"winter")
	orchard.advance_day(&"winter", true)
	var copy := Orchard.new()
	copy.from_array(JSON.parse_string(JSON.stringify(orchard.to_array())))
	assert_eq(copy.kind_at(T), &"mandarin")
	assert_eq(copy.age_at(T), orchard.age_at(T))
	assert_eq(copy.fruit_at(T), 1)
	assert_eq(copy.fallen_at(T), 1)
	assert_eq(copy.item_at(T), &"mandarin")


func test_farming_saves_trees() -> void:
	Farming.orchard.plant(T, &"loquat")
	var data := Farming.save_data()
	Farming.reset_data()
	assert_false(Farming.orchard.has(T))
	Farming.load_data(JSON.parse_string(JSON.stringify(data)))
	assert_eq(Farming.orchard.kind_at(T), &"loquat")


# ---------------------------------------------------------------- 采集

func test_options_follow_season_and_shore() -> void:
	for def in Foraging.options(&"summer", -1, false):
		assert_eq(def.season, &"summer")
		assert_false(def.shore)
	var shore := Foraging.options(&"summer", -1, true)
	assert_eq(shore.size(), 1)
	assert_eq(shore[0].item, &"water_caltrop")
	assert_eq(Foraging.options(&"spring", -1, true).size(), 0)


func test_winter_bamboo_shoot_waits_for_xiaoxue() -> void:
	var xiaoxue := -1
	for i in 24:
		if Database.term(i).id == &"xiaoxue":
			xiaoxue = i
	assert_gt(xiaoxue, 0)
	var before: Array[StringName] = []
	for def in Foraging.options(&"winter", xiaoxue - 1, false):
		before.append(def.item)
	var after: Array[StringName] = []
	for def in Foraging.options(&"winter", xiaoxue, false):
		after.append(def.item)
	assert_false(before.has(&"winter_bamboo_shoot"))
	assert_true(after.has(&"winter_bamboo_shoot"))
	assert_true(before.has(&"pine_cone"))


func test_pick_follows_weights() -> void:
	var list := Foraging.options(&"spring", -1, false)
	assert_eq(Foraging.pick(list, 0.0), list[0].item)
	assert_eq(Foraging.pick(list, 0.999), list[list.size() - 1].item)
	var empty: Array[ForageDef] = []
	assert_eq(Foraging.pick(empty, 0.5), &"")


func test_settle_places_pending_on_free_tiles() -> void:
	GameClock.day = 1
	var land: Array[Vector2i] = []
	for x in 10:
		land.append(Vector2i(x, 0))
	var no_shore: Array[Vector2i] = []
	assert_eq(Foraging.pending_on(&"farm"), Foraging.START_PENDING)
	Foraging.settle(&"farm", land, no_shore)
	assert_eq(Foraging.pending_on(&"farm"), 0)
	assert_between(Foraging.count_on(&"farm"), 1, Foraging.START_PENDING)
	var on_map: Dictionary = Foraging.items[&"farm"]
	for t: Vector2i in on_map:
		assert_true(land.has(t))
		assert_eq(Database.item(on_map[t]).kind, &"forage")
	# 再载入一次地图不会多长
	var n := Foraging.count_on(&"farm")
	Foraging.settle(&"farm", land, no_shore)
	assert_eq(Foraging.count_on(&"farm"), n)


func test_take_removes_the_item() -> void:
	GameClock.day = 1
	var land: Array[Vector2i] = [Vector2i(3, 3)]
	var no_shore: Array[Vector2i] = []
	Foraging.settle(&"farm", land, no_shore)
	var id := Foraging.item_at(&"farm", Vector2i(3, 3))
	assert_ne(id, &"")
	assert_eq(Foraging.take(&"farm", Vector2i(3, 3)), id)
	assert_eq(Foraging.take(&"farm", Vector2i(3, 3)), &"")
	assert_eq(Foraging.count_on(&"farm"), 0)


func test_daily_growth_is_capped() -> void:
	for i in 10:
		GameClock.advance_day()
	assert_eq(Foraging.pending_on(&"farm") + Foraging.count_on(&"farm"), Foraging.MAX_PER_MAP)


func test_new_season_clears_old_forage() -> void:
	GameClock.day = 1
	var land: Array[Vector2i] = [Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3)]
	var no_shore: Array[Vector2i] = []
	Foraging.settle(&"farm", land, no_shore)
	assert_gt(Foraging.count_on(&"farm"), 0)
	while GameClock.day_of_season() != 1 or GameClock.season_id() == &"spring":
		GameClock.advance_day()
	assert_eq(Foraging.count_on(&"farm"), 0, "换季时上一季的采集物消失")


func test_foraging_round_trips_through_save() -> void:
	GameClock.day = 1
	var land: Array[Vector2i] = [Vector2i(3, 3)]
	var no_shore: Array[Vector2i] = []
	Foraging.settle(&"farm", land, no_shore)
	var id := Foraging.item_at(&"farm", Vector2i(3, 3))
	Foraging.pending[&"farm"] = 2
	var data: Dictionary = JSON.parse_string(JSON.stringify(Foraging.save_data()))
	Foraging.reset_data()
	Foraging.load_data(data)
	assert_eq(Foraging.item_at(&"farm", Vector2i(3, 3)), id)
	assert_eq(Foraging.pending_on(&"farm"), 2)
