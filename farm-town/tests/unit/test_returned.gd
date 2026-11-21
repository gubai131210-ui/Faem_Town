extends GutTest
## 广场灯带回井台、戏台和后街。河岸上的铺面挪到河埠（决策 111、113）。


func before_each() -> void:
	SaveSystem.base_dir = "user://test_saves_returned"
	SaveSystem.reset_all()


func test_the_plaza_stays_open_before_the_lamp() -> void:
	var town := _town()
	assert_false(town.blocked(town.tile_center(Vector2i(15, 14))), "井还没回来")
	assert_eq(town.query_use(null, Vector2i(15, 14), GameMap.Facing.UP), &"")
	assert_eq(town.query_use(null, Vector2i(27, 16), GameMap.Facing.UP), &"")
	assert_eq(town.terrain[5 * town.cols + 31], OutdoorMap.GRASS, "巷子还是草地")


func test_the_plaza_lamp_brings_the_well_the_stage_and_the_alley() -> void:
	GameState.set_flag(&"lamp_plaza")
	var town := _town()
	assert_true(town.blocked(town.tile_center(Vector2i(15, 14))))
	assert_true(town.blocked(town.tile_center(Vector2i(27, 16))))
	assert_false(town.blocked(town.tile_center(Vector2i(16, 16))), "播种节的摊子还在")
	assert_false(town.blocked(town.tile_center(Vector2i(22, 12))), "丰收集的长桌还在")
	assert_eq(town.query_use(null, Vector2i(16, 14), GameMap.Facing.UP), &"interact")
	assert_eq(town.query_use(null, Vector2i(26, 16), GameMap.Facing.UP), &"interact")
	assert_eq(town.query_use(null, Vector2i(8, 17), GameMap.Facing.UP), &"interact", "杂货铺的墙还是看看")
	watch_signals(EventBus)
	town.perform(&"interact", null, Vector2i(15, 14))
	assert_signal_emitted(EventBus, "banner_requested")
	assert_eq(town.terrain[5 * town.cols + 31], OutdoorMap.PAVE)
	assert_gt(town.find_path(Vector2i(31, 9), Vector2i(16, 3)).size(), 0, "巷子通到后街")


func test_the_dock_stays_after_the_shops_move_west() -> void:
	GameState.set_flag(&"lamp_river")
	var bank := _bank()
	assert_eq(bank.query_use(null, Vector2i(3, 17), GameMap.Facing.UP), &"", "铺面不在河岸上")
	assert_eq(bank.query_use(null, Vector2i(9, 17), GameMap.Facing.UP), &"")
	assert_eq(bank.query_use(null, Vector2i(14, 17), GameMap.Facing.UP), &"")
	assert_gt(bank.find_path(Vector2i(15, 10), Vector2i(bank.BOATHOUSE_X, bank.BOATHOUSE_FRONT)).size(), 0, "从码头还走得到船屋")
	assert_gt(bank.find_path(Vector2i(15, 10), Vector2i(1, 16)).size(), 0, "从码头走得到西边的土路")
	assert_eq(bank.fishing_water(Vector2i(14, 8)), &"river")
	assert_eq(bank.query_use(Database.item(&"rod"), Vector2i(14, 8), GameMap.Facing.UP), &"cast")


func _town() -> OutdoorMap:
	var scene: PackedScene = load(SceneRouter.MAPS[&"town"])
	var town: OutdoorMap = scene.instantiate()
	add_child_autofree(town)
	return town


func _bank() -> OutdoorMap:
	var scene: PackedScene = load(SceneRouter.MAPS[&"riverbank"])
	var bank: OutdoorMap = scene.instantiate()
	add_child_autofree(bank)
	return bank
