extends GutTest
## M3 第二批：南溪地图、鱼饵浮漂、蟹笼、雾天钓遗物、鱼谱。


func before_each() -> void:
	SaveSystem.reset_all()
	Weather.today = &"sunny"
	GameClock.minutes = 600.0
	GameClock.day = 1


func after_each() -> void:
	SaveSystem.reset_all()
	Weather.today = &"sunny"


func _map(id: StringName) -> OutdoorMap:
	var scene: PackedScene = load(SceneRouter.MAPS[id])
	var m: OutdoorMap = scene.instantiate()
	add_child_autofree(m)
	return m


# ---------------------------------------------------------------- 南溪地图

func test_town_south_road_leads_to_nanxi_and_back() -> void:
	var town := _map(&"town")
	assert_false(town.blocked(GameMap.tile_center(Vector2i(22, 29))), "南边的路不再有雾")
	assert_eq(town.trigger_at(Vector2i(22, 29)), {"map": &"nanxi", "spawn": &"from_town"})
	assert_eq(town.trigger_at(Vector2i(23, 29)), {"map": &"nanxi", "spawn": &"from_town"})
	assert_eq(town.spawn_facing(&"from_nanxi"), GameMap.Facing.UP)
	assert_false(town.blocked(town.spawn_position(&"from_nanxi")), "从南溪回来站的地方能站")
	# 北边、西边还封着
	assert_true(town.blocked(GameMap.tile_center(Vector2i(13, 0))))
	assert_true(town.blocked(GameMap.tile_center(Vector2i(0, 18))))
	var nanxi := _map(&"nanxi")
	assert_eq(nanxi.map_id, &"nanxi")
	assert_eq(nanxi.trigger_at(Vector2i(19, 0)), {"map": &"town", "spawn": &"from_nanxi"})
	assert_eq(nanxi.trigger_at(Vector2i(20, 0)), {"map": &"town", "spawn": &"from_nanxi"})
	assert_false(nanxi.blocked(nanxi.spawn_position(&"from_town")), "从镇上下来站的地方能站")
	# 路一直通到溪边的空地
	assert_gt(nanxi.find_path(Vector2i(19, 1), Vector2i(19, 13)).size(), 0, "路能走到溪边")


func test_nanxi_has_a_stream_a_dock_and_the_river_lamp() -> void:
	# 七点老周还在镇上，码头是空的
	GameClock.minutes = 420.0
	var nanxi := _map(&"nanxi")
	var water := 0
	for y in nanxi.rows:
		for x in nanxi.cols:
			if nanxi.fishing_water(Vector2i(x, y)) == &"stream":
				water += 1
	assert_gt(water, 80, "溪占了不少格子")
	# 码头的木板架在水上，人能站，但不能对着木板甩竿
	for t in nanxi.DOCK_TILES:
		assert_false(nanxi.blocked(GameMap.tile_center(t)), "码头 %s 能站" % t)
		assert_eq(nanxi.fishing_water(t), &"")
	assert_eq(nanxi.fishing_water(Vector2i(19, 17)), &"stream", "码头尽头往南是水")
	assert_gt(nanxi.find_path(Vector2i(19, 12), Vector2i(20, 16)).size(), 0, "从岸上能走到码头尽头")
	# 河灯
	assert_eq(nanxi.query_use(null, nanxi.LAMP_TILE, GameMap.Facing.UP), &"interact")
	watch_signals(EventBus)
	nanxi.perform(&"interact", null, nanxi.LAMP_TILE)
	assert_signal_emitted_with_parameters(EventBus, "lamp_requested", [&"river"])
	var lamp := Database.lamp(&"river")
	assert_eq(lamp.map, &"nanxi")
	assert_eq(lamp.relic, &"river_lantern")
	assert_eq(Database.relic(&"river_lantern").found, &"fishing")
	# 拿着鱼竿对着溪能甩
	assert_eq(nanxi.query_use(Database.item(&"rod"), Vector2i(19, 17), GameMap.Facing.DOWN), &"cast")


func test_laozhou_spends_the_day_on_his_dock() -> void:
	var def := Database.npc(&"laozhou")
	var spot := NpcSchedule.spot_at(def, 600.0, &"sunny")
	assert_eq(spot["map"], &"nanxi")
	assert_eq(spot["tile"], Vector2i(20, 16))
	assert_eq(spot["note"], "dock")
	assert_eq(NpcSchedule.spot_at(def, 420.0, &"sunny")["map"], &"town", "早上还在镇上卖鱼")
	assert_eq(NpcSchedule.spot_at(def, 1080.0, &"sunny")["map"], &"town", "傍晚回镇上坐长凳")
	assert_eq(NpcSchedule.spot_at(def, 600.0, &"rain")["map"], &"", "下雨回家")
	var nanxi := _map(&"nanxi")
	var npc := nanxi.npc_at(Vector2i(20, 16))
	assert_not_null(npc, "十点老周站在码头上")
	if npc != null:
		assert_eq(npc.def.id, &"laozhou")
	assert_true(Residents.at("laozhou", "dock"))


func test_nanxi_grows_forage_and_shares_the_daily_settlement() -> void:
	assert_has(Foraging.MAPS, &"nanxi")
	GameClock.day = 2
	Foraging._on_new_day()
	assert_gt(Foraging.pending_on(&"nanxi"), 0)
	var nanxi := _map(&"nanxi")
	assert_eq(Foraging.pending_on(&"nanxi"), 0, "进地图时攒着的份数落了地")
	assert_gt(Foraging.count_on(&"nanxi"), 0)
	for t: Vector2i in Foraging.items[&"nanxi"]:
		assert_eq(nanxi.query_use(null, t, GameMap.Facing.DOWN), &"harvest", "空手能捡 %s" % t)
		assert_false(nanxi.blocked(GameMap.tile_center(t)), "采集物长在能走到的地方")


# ---------------------------------------------------------------- 鱼饵、浮漂

func test_bait_halves_the_wait_and_is_used_up() -> void:
	var plain := Fishing.bite_wait(0, 0.5)
	assert_almost_eq(Fishing.bite_wait(0, 0.5, true), plain * 0.5, 0.001)
	assert_false(Fishing.use_bait(), "没有鱼饵就不挂")
	GameState.inventory.add(&"bait", 2)
	assert_true(Fishing.use_bait())
	assert_eq(GameState.inventory.count_of(&"bait"), 1)
	assert_true(Fishing.use_bait())
	assert_false(Fishing.use_bait())


func test_bobber_widens_the_bite_window() -> void:
	assert_almost_eq(Fishing.bite_window(), Fishing.BITE_WINDOW, 0.001)
	GameState.inventory.add(&"bobber", 1)
	assert_almost_eq(Fishing.bite_window(), Fishing.BOBBER_WINDOW, 0.001)
	assert_gt(Fishing.BOBBER_WINDOW, Fishing.BITE_WINDOW)


func test_grocery_sells_gear_after_the_lamp() -> void:
	var ids: Array[StringName] = []
	for e in Shop.entries(&"spring", Shop.GROCERY):
		ids.append(e.item_id)
	assert_does_not_have(ids, &"bait", "点灯前不卖钓具")
	GameState.set_flag(&"lamp_plaza")
	ids.clear()
	var once: Dictionary = {}
	for e in Shop.entries(&"spring", Shop.GROCERY):
		ids.append(e.item_id)
		once[e.item_id] = e.once
	assert_has(ids, &"bait")
	assert_has(ids, &"bobber")
	assert_has(ids, &"crab_trap")
	assert_true(once[&"bobber"], "浮漂只买一个")
	assert_false(once[&"bait"])
	GameState.inventory.add(&"bobber", 1)
	ids.clear()
	for e in Shop.entries(&"spring", Shop.GROCERY):
		ids.append(e.item_id)
	assert_does_not_have(ids, &"bobber", "有了浮漂就不再上架")
	assert_has(ids, &"bait")


# ---------------------------------------------------------------- 蟹笼

func test_trap_placed_in_the_stream_catches_something_overnight() -> void:
	assert_false(Fishing.has_trap(&"nanxi", Vector2i(10, 18)))
	Fishing.place_trap(&"nanxi", Vector2i(10, 18), &"stream")
	assert_true(Fishing.has_trap(&"nanxi", Vector2i(10, 18)))
	assert_eq(Fishing.trap_catch(&"nanxi", Vector2i(10, 18)), &"")
	GameClock.day = 1
	var pool := Fishing.trap_pool(&"stream")
	assert_gt(pool.size(), 0, "溪里有能用笼子装的东西")
	for f in pool:
		assert_true(f.trap)
	# 运气够好就装到了
	Fishing.settle_traps(0.0)
	var got := Fishing.trap_catch(&"nanxi", Vector2i(10, 18))
	assert_ne(got, &"", "一夜过去笼子里有东西")
	assert_true(Database.fish_def(got).trap)
	# 收了以后笼子空了，还在原地
	assert_eq(Fishing.take_catch(&"nanxi", Vector2i(10, 18)), got)
	assert_eq(Fishing.trap_catch(&"nanxi", Vector2i(10, 18)), &"")
	assert_true(Fishing.has_trap(&"nanxi", Vector2i(10, 18)))
	# 装着东西的笼子第二天不会被覆盖
	Fishing.settle_traps(0.0)
	var again := Fishing.trap_catch(&"nanxi", Vector2i(10, 18))
	Fishing.settle_traps(0.0)
	assert_eq(Fishing.trap_catch(&"nanxi", Vector2i(10, 18)), again)
	Fishing.remove_trap(&"nanxi", Vector2i(10, 18))
	assert_eq(Fishing.trap_count(), 0)


func test_trap_can_come_up_empty_and_crab_only_in_warm_seasons() -> void:
	Fishing.place_trap(&"farm", Vector2i(33, 17), &"pond")
	Fishing.settle_traps(0.99)
	assert_eq(Fishing.trap_catch(&"farm", Vector2i(33, 17)), &"", "运气差就是空的")
	var pond_ids: Array[StringName] = []
	for f in Fishing.trap_pool(&"pond"):
		pond_ids.append(f.id)
	assert_has(pond_ids, &"river_shrimp", "池塘里有河虾")
	assert_does_not_have(pond_ids, &"crab", "池塘里没有螃蟹")
	GameClock.day = 1
	var stream_ids: Array[StringName] = []
	for f in Fishing.trap_pool(&"stream"):
		stream_ids.append(f.id)
	assert_does_not_have(stream_ids, &"crab", "春天没有螃蟹")
	GameClock.day = 28 * 2 + 1
	stream_ids.clear()
	for f in Fishing.trap_pool(&"stream"):
		stream_ids.append(f.id)
	assert_has(stream_ids, &"crab", "秋天有螃蟹")


func test_map_places_and_collects_traps() -> void:
	var nanxi := _map(&"nanxi")
	var trap := Database.item(&"crab_trap")
	var t := Vector2i(10, 18)
	assert_eq(nanxi.fishing_water(t), &"stream")
	GameState.inventory.add(&"crab_trap", 1)
	assert_eq(nanxi.query_use(trap, t, GameMap.Facing.DOWN), &"place_trap")
	assert_eq(nanxi.query_use(trap, Vector2i(10, 10), GameMap.Facing.DOWN), &"", "对着草地放不了")
	nanxi.perform(&"place_trap", trap, t)
	assert_eq(GameState.inventory.count_of(&"crab_trap"), 0)
	assert_true(Fishing.has_trap(&"nanxi", t))
	assert_eq(nanxi.query_use(trap, t, GameMap.Facing.DOWN), &"interact", "有笼子的地方按一下是收")
	assert_eq(nanxi.query_use(Database.item(&"rod"), t, GameMap.Facing.DOWN), &"interact", "拿着鱼竿也不会往笼子上甩")
	# 空笼子收回来
	nanxi.perform(&"interact", null, t)
	assert_false(Fishing.has_trap(&"nanxi", t))
	assert_eq(GameState.inventory.count_of(&"crab_trap"), 1)
	# 装到东西的笼子：先拿东西，笼子留下
	nanxi.perform(&"place_trap", trap, t)
	Fishing.settle_traps(0.0)
	var got := Fishing.trap_catch(&"nanxi", t)
	assert_ne(got, &"")
	nanxi.perform(&"interact", null, t)
	assert_eq(GameState.inventory.count_of(got), 1)
	assert_true(Fishing.has_trap(&"nanxi", t))
	assert_eq(Fishing.caught(got), 1, "笼子收的也记进鱼谱")


func test_traps_survive_save_and_load() -> void:
	Fishing.place_trap(&"nanxi", Vector2i(10, 18), &"stream")
	Fishing.place_trap(&"farm", Vector2i(33, 17), &"pond")
	Fishing.traps[&"nanxi"][Vector2i(10, 18)]["catch"] = &"river_shrimp"
	var data := Fishing.save_data()
	Fishing.reset_data()
	assert_eq(Fishing.trap_count(), 0)
	Fishing.load_data(data)
	assert_eq(Fishing.trap_count(), 2)
	assert_eq(Fishing.trap_catch(&"nanxi", Vector2i(10, 18)), &"river_shrimp")
	assert_eq(Fishing.traps[&"farm"][Vector2i(33, 17)]["water"], &"pond")


# ---------------------------------------------------------------- 雾天钓遗物

func test_relics_bite_only_in_fog_or_at_qingming() -> void:
	assert_false(Fishing.relic_weather())
	assert_false(Fishing.relic_bites(0.0))
	Weather.today = &"fog"
	assert_true(Fishing.relic_weather())
	assert_true(Fishing.relic_bites(0.1))
	assert_false(Fishing.relic_bites(0.9), "雾天也不是每口都是遗物")
	Weather.today = &"sunny"
	GameClock.day = 17
	assert_eq(GameClock.term_id(), &"qingming")
	assert_true(Fishing.relic_weather())


func test_fished_relic_pool_has_the_river_lantern_and_skips_found_ones() -> void:
	var ids: Array[StringName] = []
	for i in 40:
		var id := Fishing.pick_relic(i / 40.0)
		if not ids.has(id):
			ids.append(id)
	assert_has(ids, &"river_lantern", "河底的灯盏只能钓到")
	assert_has(ids, &"fish_hook", "雾天地上会掉的也能钓到")
	assert_does_not_have(ids, &"old_wick", "委托给的不会钓到")
	GameState.set_flag(&"relic_river_lantern")
	ids.clear()
	for i in 40:
		var id := Fishing.pick_relic(i / 40.0, [&"fish_hook"])
		if not ids.has(id):
			ids.append(id)
	assert_does_not_have(ids, &"river_lantern", "得到过的不再出")
	assert_does_not_have(ids, &"fish_hook", "传进来排除的不出")
	# 全找齐了就没有
	for id: StringName in Database.relics:
		GameState.set_flag(StringName("relic_" + String(id)))
	assert_eq(Fishing.pick_relic(0.5), &"")


func test_relic_in_the_water_does_not_struggle_but_comes_slowly() -> void:
	var def := FishDef.new()
	def.id = &"river_lantern"
	def.pull = 0.12
	def.fights = 999.0
	def.fight_len = 0.0
	var fight := FishFight.new(def, 0, 7)
	var t := 0.0
	while not fight.is_over() and t < 60.0:
		fight.step(1.0 / 60.0, fight.tension < 0.6)
		t += 1.0 / 60.0
	assert_eq(fight.result, FishFight.Result.CAUGHT)
	assert_gt(t, 3.0, "拖上来要花点时间")


# ---------------------------------------------------------------- 鱼谱

func test_fishbook_text_describes_where_and_when() -> void:
	var where := ResidentsPanel.fish_where(Database.fish_def(&"crucian"))
	assert_true(where.contains("池塘"), where)
	assert_true(where.contains("全年"), where)
	var cat := ResidentsPanel.fish_where(Database.fish_def(&"catfish"))
	assert_true(cat.contains("夜里"), cat)
	var crab := ResidentsPanel.fish_where(Database.fish_def(&"crab"))
	assert_true(crab.contains("蟹笼"), crab)
	assert_true(crab.contains("秋"), crab)
	var loach := ResidentsPanel.fish_where(Database.fish_def(&"loach"))
	assert_true(loach.contains("雨天"), loach)
