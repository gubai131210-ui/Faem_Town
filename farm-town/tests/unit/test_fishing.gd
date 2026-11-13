extends GutTest
## M3 第一批：鱼表、哪片水什么时候有什么鱼、收放线的规则、钓鱼记录、老周给的鱼竿。


func before_each() -> void:
	SaveSystem.reset_all()
	Weather.today = &"sunny"
	GameClock.minutes = 600.0
	GameClock.day = 1


func after_each() -> void:
	SaveSystem.reset_all()


# ---------------------------------------------------------------- 数据表

func test_fish_table_validates() -> void:
	assert_eq(Database.validate().size(), 0, "\n".join(Database.validate()))
	assert_eq(Database.fish.size(), 26, "设计文档里的全部鱼，含蟹笼的两种和三条传说")


func test_fish_are_sellable_items_with_icons() -> void:
	for id: StringName in Database.fish:
		assert_true(Database.has_item(id), "%s 也是一种物品" % id)
		var item := Database.item(id)
		assert_eq(item.kind, &"fish")
		assert_true(item.sellable(), "%s 能放进出货箱" % id)
		var img := PixelArt.icon(item.icon)
		assert_eq(img.get_width(), 16)
		assert_false(img.get_used_rect().size == Vector2i.ZERO, "%s 的图标不是空的" % id)


func test_rod_is_a_tool_that_the_shop_does_not_sell() -> void:
	var rod := Database.item(&"rod")
	assert_eq(rod.kind, &"tool")
	assert_eq(rod.price, 0, "鱼竿是老周给的，不卖")
	for e in Shop.entries(&"spring"):
		assert_ne(e.item_id, &"rod")


# ---------------------------------------------------------------- 哪片水有什么鱼

func _ids(fishes: Array[FishDef]) -> Array[StringName]:
	var out: Array[StringName] = []
	for f in fishes:
		out.append(f.id)
	return out


func test_pond_in_spring_daytime() -> void:
	var ids := _ids(Fishing.pool(&"pond"))
	assert_has(ids, &"crucian")
	assert_has(ids, &"sharpbelly")
	assert_does_not_have(ids, &"loach", "泥鳅只在雨天")
	assert_does_not_have(ids, &"carp", "鲤鱼在河里")
	Weather.today = &"rain"
	assert_has(_ids(Fishing.pool(&"pond")), &"loach")


func test_time_season_and_term_rules() -> void:
	GameClock.day = 24 * 1 + 1  # 夏
	assert_has(_ids(Fishing.pool(&"stream")), &"stream_grouper")
	GameClock.minutes = 21 * 60.0
	assert_does_not_have(_ids(Fishing.pool(&"stream")), &"stream_grouper", "溪石斑只在白天")
	assert_has(_ids(Fishing.pool(&"river")), &"catfish", "鲶鱼夜里咬钩")
	GameClock.minutes = 600.0
	assert_does_not_have(_ids(Fishing.pool(&"river")), &"catfish")
	GameClock.day = 24 * 3 + 1  # 冬
	assert_has(_ids(Fishing.pool(&"lake")), &"ice_fish")
	assert_does_not_have(_ids(Fishing.pool(&"sea")), &"tide_born", "潮生要冬至夜")
	GameClock.day = 24 * 3 + 4 * 3 + 1  # 冬至
	assert_eq(GameClock.term_id(), &"dongzhi")
	GameClock.minutes = 22 * 60.0
	assert_has(_ids(Fishing.pool(&"sea")), &"tide_born")


func test_weather_flag_and_trap_rules() -> void:
	assert_does_not_have(_ids(Fishing.pool(&"river")), &"fog_carp_king")
	Weather.today = &"fog"
	assert_has(_ids(Fishing.pool(&"river")), &"fog_carp_king", "雾天河里有雾鲤王")
	assert_does_not_have(_ids(Fishing.pool(&"river")), &"crab", "螃蟹只能用蟹笼")
	assert_does_not_have(_ids(Fishing.pool(&"mine_deep")), &"old_well_catfish")
	GameState.set_flag(&"boss_catfish")
	assert_has(_ids(Fishing.pool(&"mine_deep")), &"old_well_catfish")


func test_every_water_has_fish_all_year_in_daytime() -> void:
	for water in FishDef.WATERS:
		for season in 4:
			GameClock.day = season * 24 + 1
			assert_gt(Fishing.pool(water).size(), 0, "%s 在第 %d 季白天有鱼" % [water, season])


func test_pick_is_weighted_and_handles_empty_pool() -> void:
	var fishes := Fishing.pool(&"pond")
	assert_eq(Fishing.pick(&"pond", 0.0).id, fishes[0].id)
	assert_eq(Fishing.pick(&"pond", 0.999).id, fishes[fishes.size() - 1].id)
	assert_null(Fishing.pick(&"nowhere", 0.5))


func test_bite_wait_shrinks_with_rod_level() -> void:
	assert_almost_eq(Fishing.bite_wait(0, 0.0), Fishing.WAIT_MIN, 0.001)
	assert_almost_eq(Fishing.bite_wait(0, 1.0), Fishing.WAIT_MAX, 0.001)
	assert_lt(Fishing.bite_wait(2, 1.0), Fishing.bite_wait(0, 1.0))
	assert_gt(Fishing.bite_wait(3, 1.0), Fishing.WAIT_MIN)


func test_size_roll_and_quality() -> void:
	var f := Database.fish_def(&"crucian")
	assert_eq(Fishing.roll_size(f, 0.0), f.min_size)
	assert_eq(Fishing.roll_size(f, 1.0), f.max_size)
	assert_lt(Fishing.roll_size(f, 0.5), (f.min_size + f.max_size) / 2 + 1, "一半的随机数落在偏小的一侧")
	assert_eq(f.quality_for(f.min_size), 0)
	assert_eq(f.quality_for(f.max_size), 2)
	assert_eq(f.quality_for(roundi(lerpf(f.min_size, f.max_size, 0.6))), 1)


# ---------------------------------------------------------------- 收放线

func test_reeling_pulls_the_fish_in_and_tightens_the_line() -> void:
	var fight := FishFight.new(Database.fish_def(&"crucian"), 0, 1)
	var d0 := fight.distance
	fight.step(0.5, true)
	assert_lt(fight.distance, d0, "收线时鱼靠近")
	assert_gt(fight.tension, 0.0, "收线时线绷紧")
	var d1 := fight.distance
	var t1 := fight.tension
	fight.step(0.5, false)
	assert_gt(fight.distance, d1, "松手鱼往外跑")
	assert_lt(fight.tension, t1, "松手线松下来")


func test_holding_through_a_struggle_snaps_the_line() -> void:
	var fight := FishFight.new(Database.fish_def(&"black_carp"), 0, 3)
	for i in 600:
		fight.step(0.05, true)
		if fight.is_over():
			break
	assert_eq(fight.result, FishFight.Result.LOST_LINE, "一直按着收线，线必断")


func test_never_reeling_loses_the_fish() -> void:
	var fight := FishFight.new(Database.fish_def(&"crucian"), 0, 3)
	for i in 600:
		fight.step(0.05, false)
		if fight.is_over():
			break
	assert_eq(fight.result, FishFight.Result.LOST_FISH)


## 按规则玩（鱼挣扎或线太紧就松手）能钓到普通的鱼；传说的鱼要升过两级的竿。
func test_careful_player_lands_easy_and_legendary_fish() -> void:
	for id: StringName in [&"crucian", &"carp", &"fog_carp_king"]:
		var caught := 0
		for s in 8:
			var fight := FishFight.new(Database.fish_def(id), 2 if id == &"fog_carp_king" else 0, 100 + s)
			for i in 1200:
				var reel := not fight.struggling and not fight.warning and fight.tension < 0.6
				fight.step(0.05, reel)
				if fight.is_over():
					break
			if fight.result == FishFight.Result.CAUGHT:
				caught += 1
		if id == &"crucian":
			assert_eq(caught, 8, "鲫鱼按规则玩必上")
		else:
			assert_gt(caught, 0, "%s 按规则玩钓得到" % id)
		assert_lt(FishFight.new(Database.fish_def(id), 0, 1).elapsed, 0.001)


## 不升竿钓不到传说的鱼：这是老周那条线的奖励。
func test_legend_needs_a_better_rod() -> void:
	var caught := 0
	for s in 6:
		var fight := FishFight.new(Database.fish_def(&"fog_carp_king"), 0, 200 + s)
		for i in 2400:
			var reel := not fight.struggling and not fight.warning and fight.tension < 0.6
			fight.step(0.05, reel)
			if fight.is_over():
				break
		if fight.result == FishFight.Result.CAUGHT:
			caught += 1
	assert_lt(caught, 2, "普通竿基本钓不上雾鲤王")


func test_better_rod_makes_the_fight_easier() -> void:
	var slow := FishFight.new(Database.fish_def(&"carp"), 0, 5)
	var fast := FishFight.new(Database.fish_def(&"carp"), 3, 5)
	slow.step(1.0, true)
	fast.step(1.0, true)
	assert_lt(fast.distance, slow.distance, "好竿收得快")
	assert_lt(fast.tension, slow.tension, "好竿线没那么紧")


func test_struggle_is_announced_a_moment_before() -> void:
	var fight := FishFight.new(Database.fish_def(&"crucian"), 0, 9)
	var saw_warning := false
	for i in 400:
		fight.step(0.05, false)
		if fight.struggling:
			break
		if fight.warning:
			saw_warning = true
	assert_true(fight.struggling, "鲫鱼几秒内会挣扎一次")
	assert_true(saw_warning, "挣扎前先预警")


# ---------------------------------------------------------------- 记录与存档

func test_records_count_and_best_size_and_survive_saving() -> void:
	Fishing.record(&"crucian", 18)
	Fishing.record(&"crucian", 14)
	Fishing.record(&"carp", 40)
	assert_eq(Fishing.caught(&"crucian"), 2)
	assert_eq(Fishing.best(&"crucian"), 18)
	assert_eq(Fishing.species_count(), 2)
	var data := Fishing.save_data()
	Fishing.reset_data()
	assert_eq(Fishing.species_count(), 0)
	Fishing.load_data(data)
	assert_eq(Fishing.best(&"crucian"), 18)
	assert_eq(Fishing.caught(&"carp"), 1)


func test_night_boundaries() -> void:
	assert_false(Fishing.is_night(18 * 60.0))
	assert_true(Fishing.is_night(19 * 60.0))
	assert_true(Fishing.is_night(60.0), "凌晨一点还是夜里")
	assert_false(Fishing.is_night(6 * 60.0))


# ---------------------------------------------------------------- 鱼竿怎么来

func test_laozhou_hands_over_the_rod_once_after_the_lamp() -> void:
	assert_eq(GameState.inventory.count_of(&"rod"), 0)
	Residents.hand("rod")
	assert_eq(GameState.inventory.count_of(&"rod"), 1)
	assert_true(GameState.has_flag(&"got_rod"))
	Residents.hand("rod")
	assert_eq(GameState.inventory.count_of(&"rod"), 1, "只给一次")
	var res: Resource = load(Residents.dialogue_path(&"laozhou"))
	GameState.flags.clear()
	var line: Variant = await DialogueManager.get_next_dialogue_line(res, "daily")
	assert_false(str(line.text).contains("灯亮了"), "灯没亮以前老周不提竿子")
	GameState.set_flag(&"lamp_plaza")
	line = await DialogueManager.get_next_dialogue_line(res, "daily")
	assert_true(str(line.text).contains("灯亮了"), "灯亮以后老周先说竿子的事")


func test_farm_pond_and_stream_are_different_waters() -> void:
	var farm_scene: PackedScene = load(SceneRouter.MAPS[&"farm"])
	var farm: GameMap = farm_scene.instantiate()
	add_child_autofree(farm)
	assert_eq(farm.fishing_water(Vector2i(33, 17)), &"pond")
	assert_eq(farm.fishing_water(Vector2i(46, 10)), &"stream")
	assert_eq(farm.fishing_water(Vector2i(20, 12)), &"")
	var rod := Database.item(&"rod")
	assert_eq(farm.query_use(rod, Vector2i(33, 17), GameMap.Facing.RIGHT), &"cast")
	# 田里不长采集物，拿着竿子对着田什么也不做
	assert_eq(farm.query_use(rod, Vector2i(20, 12), GameMap.Facing.RIGHT), &"")


func test_farmer_sheet_has_fishing_poses_and_rod_tips() -> void:
	var sheet := CharacterSheet.load_sheet("farmer")
	for anim: StringName in [&"cast", &"fish", &"hook", &"reel", &"strain", &"trophy"]:
		assert_true(sheet.has_anim(anim), "序列帧里有 %s" % anim)
	# 持竿的姿势算出了竿尖位置：面朝右时竿尖在身体右边、头顶上方
	assert_true(sheet.has_tip(&"fish"))
	var tip := sheet.tip(&"fish", GameMap.Facing.RIGHT, 0)
	assert_gt(tip.x, 10.0)
	assert_lt(tip.y, -15.0)
	var left := sheet.tip(&"fish", GameMap.Facing.LEFT, 0)
	assert_lt(left.x, -10.0)
	# 绷竿时竿弯了，竿尖比平举时低一些、离身体近一些
	var strain := sheet.tip(&"strain", GameMap.Facing.RIGHT, 1)
	assert_lt(strain.x, tip.x)
	# 没有竿的动作返回零
	assert_false(sheet.has_tip(&"walk"))
	assert_eq(sheet.tip(&"walk", GameMap.Facing.RIGHT, 0), Vector2.ZERO)
	# 每个鱼的身形都有模板，模板是 16×16
	for id: StringName in Database.fish:
		var shape: String = Database.fish_def(id).shape
		assert_true(ItemArt.FISH_SHAPES.has(shape), "%s 的身形 %s 有模板" % [id, shape])
	for shape: String in ItemArt.FISH_SHAPES:
		var rows: Array = ItemArt.FISH_SHAPES[shape]
		assert_eq(rows.size(), 16, shape)
		for row: String in rows:
			assert_eq(row.length(), 16, shape)
