extends GutTest
## M3 第三批：河底的灯盏、河灯点亮后坐船去河岸、老周的忆换高级鱼竿。


func before_each() -> void:
	SaveSystem.reset_all()
	Weather.today = &"sunny"
	GameClock.minutes = 600.0
	GameClock.day = 1


func after_each() -> void:
	SaveSystem.reset_all()
	Weather.today = &"sunny"
	GameClock.running = false


func _map(id: StringName) -> OutdoorMap:
	var scene: PackedScene = load(SceneRouter.MAPS[id])
	var m: OutdoorMap = scene.instantiate()
	add_child_autofree(m)
	return m


# ---------------------------------------------------------------- 潭底的灯盏

func test_lantern_lies_in_the_deep_water_only_after_laozhou_hints() -> void:
	GameClock.minutes = 420.0
	var nanxi := _map(&"nanxi")
	var deep := Vector2i(17, 18)
	assert_eq(nanxi.fishing_water(deep), &"stream")
	assert_eq(nanxi.sunken_relic(deep), &"", "老周没说过以前钓不到")
	GameState.set_flag(&"lantern_hint")
	assert_eq(nanxi.sunken_relic(deep), &"river_lantern")
	assert_eq(nanxi.sunken_relic(Vector2i(5, 18)), &"", "潭以外的溪水里没有")
	assert_eq(nanxi.sunken_relic(Vector2i(17, 10)), &"", "岸上没有")
	GameState.set_flag(&"relic_river_lantern")
	assert_eq(nanxi.sunken_relic(deep), &"", "钓上来以后潭底就空了")
	# 别的地图没有沉着的东西
	var farm := _map(&"farm")
	assert_eq(farm.sunken_relic(Vector2i(33, 17)), &"")


func test_laozhou_comes_over_when_the_lantern_is_fished_up() -> void:
	var nanxi := _map(&"nanxi")
	assert_not_null(nanxi.npc_at(Vector2i(20, 16)), "十点老周在码头")
	# 测试里没有真正的玩家，放个替身站在码头根上
	var dummy := Node2D.new()
	dummy.position = GameMap.tile_center(Vector2i(19, 13))
	nanxi.add_child(dummy)
	nanxi.player = dummy
	GameClock.running = true
	GameState.set_flag(&"relic_river_lantern")
	watch_signals(EventBus)
	nanxi.relic_fished(&"river_lantern")
	# 老周走过来要一会儿；等过场结束
	var waited := 0.0
	while nanxi.cutscene and waited < 8.0:
		await wait_seconds(0.2)
		waited += 0.2
	assert_signal_emitted_with_parameters(EventBus, "dialogue_requested", [Residents.dialogue_path(&"laozhou"), "lantern_found"])
	# 钓到别的遗物老周不管
	var other := _map(&"nanxi")
	watch_signals(EventBus)
	other.relic_fished(&"fish_hook")
	assert_false(other.cutscene)


func test_laozhou_dialogue_walks_through_the_lantern_story() -> void:
	var res: Resource = load(Residents.dialogue_path(&"laozhou"))
	GameState.set_flag(&"lamp_plaza")
	GameState.set_flag(&"got_rod")
	var nanxi := _map(&"nanxi")
	assert_true(Residents.at("laozhou", "dock"))
	# 在码头上第一次聊：说潭底有灯
	var line: Variant = await DialogueManager.get_next_dialogue_line(res, "daily")
	assert_true(str(line.text).contains("潭中间"), line.text)
	while line != null and line.next_id != "end":
		line = await DialogueManager.get_next_dialogue_line(res, line.next_id)
	assert_true(GameState.has_flag(&"lantern_hint"), "聊完记下线索")
	line = await DialogueManager.get_next_dialogue_line(res, "daily")
	assert_false(str(line.text).contains("潭中间"), "线索只说一次")
	# 钓上来了但还没走完那段话：再找他也接上
	GameState.set_flag(&"relic_river_lantern")
	line = await DialogueManager.get_next_dialogue_line(res, "daily")
	var said := ""
	while line != null and line.next_id != "end":
		said += str(line.text)
		line = await DialogueManager.get_next_dialogue_line(res, line.next_id)
	assert_true(said.contains("给我看看"), said)
	assert_true(GameState.has_flag(&"lantern_found"))
	# 河灯亮了：送船，送竿子
	assert_eq(GameState.tool_level(&"rod"), 0)
	GameState.set_flag(&"lamp_river")
	line = await DialogueManager.get_next_dialogue_line(res, "daily")
	assert_true(str(line.text).contains("亮了"), line.text)
	while line != null and line.next_id != "end":
		line = await DialogueManager.get_next_dialogue_line(res, line.next_id)
	assert_eq(GameState.tool_level(&"rod"), 1, "河灯亮了老周送一根好竿子")
	line = await DialogueManager.get_next_dialogue_line(res, "daily")
	assert_false(str(line.text).contains("三十年"), "新闻只说一次")
	assert_not_null(nanxi)


func test_laozhou_tells_the_story_even_if_you_already_talked_today() -> void:
	var res: Resource = load(Residents.dialogue_path(&"laozhou"))
	GameState.set_flag(&"got_rod")
	var nanxi := _map(&"nanxi")
	assert_not_null(nanxi)
	var line: Variant = await DialogueManager.get_next_dialogue_line(res, "again")
	assert_true(str(line.text).contains("潭中间"), line.text)
	while line != null and line.next_id != "end":
		line = await DialogueManager.get_next_dialogue_line(res, line.next_id)
	assert_true(GameState.has_flag(&"lantern_hint"))
	GameState.set_flag(&"relic_river_lantern")
	line = await DialogueManager.get_next_dialogue_line(res, "again")
	var said := ""
	while line != null and line.next_id != "end":
		said += str(line.text)
		line = await DialogueManager.get_next_dialogue_line(res, line.next_id)
	assert_true(said.contains("给我看看"), said)
	GameState.set_flag(&"lamp_river")
	line = await DialogueManager.get_next_dialogue_line(res, "again")
	while line != null and line.next_id != "end":
		line = await DialogueManager.get_next_dialogue_line(res, line.next_id)
	assert_eq(GameState.tool_level(&"rod"), 1)
	line = await DialogueManager.get_next_dialogue_line(res, "again")
	assert_true(str(line.text).contains("……"), "说完了又只剩一声叹")


func test_laozhou_memory_upgrades_the_rod_too() -> void:
	var res: Resource = load(Residents.dialogue_path(&"laozhou"))
	var line: Variant = await DialogueManager.get_next_dialogue_line(res, "memory_1")
	while line != null and line.next_id != "end":
		line = await DialogueManager.get_next_dialogue_line(res, line.next_id)
	assert_eq(GameState.tool_level(&"rod"), 1)
	Residents.upgrade("rod")
	assert_eq(GameState.tool_level(&"rod"), 2, "忆加河灯两次升级，够钓传说鱼")
	Residents.mark("something")
	assert_true(GameState.has_flag(&"something"))


func test_common_dialogue_narrates_the_river_lamp() -> void:
	var common: Resource = load("res://dialogue/common.dialogue")
	var line: Variant = await DialogueManager.get_next_dialogue_line(common, "lamp_river")
	assert_not_null(line)
	assert_true(str(line.text).contains("溪"), line.text)


# ---------------------------------------------------------------- 船和河岸

func test_boat_waits_for_the_lamp_then_ferries_to_the_riverbank() -> void:
	GameClock.minutes = 420.0
	var nanxi := _map(&"nanxi")
	var boat: Vector2i = nanxi.BOAT_TILES[0]
	assert_eq(nanxi.query_use(null, boat, GameMap.Facing.DOWN), &"interact")
	assert_eq(nanxi.query_use(Database.item(&"rod"), boat, GameMap.Facing.DOWN), &"interact", "拿着竿子也不会往船上甩")
	watch_signals(EventBus)
	watch_signals(SceneRouter)
	nanxi.perform(&"interact", null, boat)
	assert_signal_emitted(EventBus, "banner_requested")
	assert_signal_not_emitted(SceneRouter, "map_change_requested")
	GameState.set_flag(&"lamp_river")
	nanxi.perform(&"interact", null, boat)
	await wait_seconds(0.5)
	assert_signal_emitted_with_parameters(SceneRouter, "map_change_requested", [&"riverbank", &"from_boat"])
	await wait_seconds(0.5)
	assert_false(SceneRouter.busy)
	assert_false(nanxi.blocked(nanxi.spawn_position(&"from_boat")), "坐船回来站在码头上")
	assert_eq(nanxi.spawn_facing(&"from_boat"), GameMap.Facing.LEFT)
	assert_has(nanxi.BOAT_TILES, GameMap.tile_of(nanxi.spawn_position(&"from_boat")) + Vector2i(-1, 0), "下船的地方朝西就是船")


func test_riverbank_has_river_water_a_boat_back_and_laozhou_boathouse() -> void:
	assert_has(SceneRouter.MAPS, &"riverbank")
	assert_has(Foraging.MAPS, &"riverbank")
	var bank := _map(&"riverbank")
	assert_eq(bank.map_id, &"riverbank")
	var water := 0
	for y in bank.rows:
		for x in bank.cols:
			if bank.fishing_water(Vector2i(x, y)) == &"river":
				water += 1
	assert_gt(water, 200, "北边是一整条河")
	assert_false(bank.blocked(bank.spawn_position(&"from_boat")), "下船站的地方能站")
	for t in bank.DOCK_TILES:
		assert_false(bank.blocked(GameMap.tile_center(t)), "码头 %s 能站" % t)
		assert_eq(bank.fishing_water(t), &"")
	assert_eq(bank.fishing_water(Vector2i(14, 8)), &"river", "码头尽头是河")
	assert_gt(bank.find_path(Vector2i(15, 10), Vector2i(bank.BOATHOUSE_X, bank.BOATHOUSE_FRONT)).size(), 0, "从码头能走到船屋门口")
	# 船回南溪
	var boat: Vector2i = bank.BOAT_TILES[0]
	assert_eq(bank.query_use(null, boat, GameMap.Facing.RIGHT), &"interact")
	watch_signals(SceneRouter)
	bank.perform(&"interact", null, boat)
	await wait_seconds(0.5)
	assert_signal_emitted_with_parameters(SceneRouter, "map_change_requested", [&"nanxi", &"from_boat"])
	await wait_seconds(0.5)
	# 船屋挡路，按一下有话
	assert_true(bank.blocked(GameMap.tile_center(Vector2i(bank.BOATHOUSE_X, bank.BOATHOUSE_FRONT - 1))))
	assert_eq(bank.query_use(null, Vector2i(bank.BOATHOUSE_X, bank.BOATHOUSE_FRONT - 1), GameMap.Facing.UP), &"interact")
	# 河里能甩竿、能下笼
	assert_eq(bank.query_use(Database.item(&"rod"), Vector2i(14, 8), GameMap.Facing.UP), &"cast")
	GameState.inventory.add(&"crab_trap", 1)
	assert_eq(bank.query_use(Database.item(&"crab_trap"), Vector2i(10, 7), GameMap.Facing.UP), &"place_trap")


func test_riverbank_grows_forage() -> void:
	GameClock.day = 2
	Foraging._on_new_day()
	assert_gt(Foraging.pending_on(&"riverbank"), 0)
	var bank := _map(&"riverbank")
	assert_eq(Foraging.pending_on(&"riverbank"), 0)
	assert_gt(Foraging.count_on(&"riverbank"), 0)
	for t: Vector2i in Foraging.items[&"riverbank"]:
		assert_false(bank.blocked(GameMap.tile_center(t)), "采集物长在能走到的地方 %s" % t)


func test_fishbook_total_shows_the_rod_level() -> void:
	var panel := ResidentsPanel.new()
	add_child_autofree(panel)
	panel._refresh_fishbook()
	assert_true(panel._fish_total.text.contains("鱼竿 1 级"), panel._fish_total.text)
	GameState.upgrade_tool(&"rod")
	panel._refresh_fishbook()
	assert_true(panel._fish_total.text.contains("鱼竿 2 级"), panel._fish_total.text)
