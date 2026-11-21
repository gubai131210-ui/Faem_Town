extends GutTest
## 镇公所和铁匠铺能走进去。人还在门外。地图按亮着的灯补色（决策 115）。


func before_each() -> void:
	SaveSystem.base_dir = "user://test_saves_hall"
	SaveSystem.reset_all()


func test_the_hall_door_is_the_middle_and_the_smith_stands_clear() -> void:
	var town := _town()
	assert_eq(town.get("HALL_DOOR"), Vector2i(22, 8))
	assert_eq(town.get("SMITHY_DOOR"), Vector2i(38, 17))
	assert_eq(town.query_use(null, Vector2i(21, 8), GameMap.Facing.UP), &"interact", "镇公所门旁边还是看看")
	assert_eq(town.query_use(null, Vector2i(37, 17), GameMap.Facing.UP), &"interact", "铁匠铺正中还是看看")
	assert_eq(town.query_use(null, Vector2i(8, 17), GameMap.Facing.UP), &"interact", "杂货铺的墙还是看看")
	var hall_back: Vector2 = town.spawn_position(&"hall_door")
	assert_eq(town.tile_of(hall_back), Vector2i(22, 9))
	assert_false(town.blocked(hall_back))
	assert_eq(town.solid[town.idx(Vector2i(22, 10))], 0, "柏先生站的地方还是空地")
	var smith_back: Vector2 = town.spawn_position(&"smithy_door")
	assert_eq(town.tile_of(smith_back), Vector2i(38, 18))
	assert_false(town.blocked(smith_back))
	assert_eq(town.solid[town.idx(Vector2i(37, 18))], 0, "石叔站的地方还是空地")


func test_the_doors_open_their_rooms() -> void:
	var town := _town()
	watch_signals(SceneRouter)
	town.perform(&"interact", null, town.get("HALL_DOOR"))
	await wait_seconds(0.6)
	assert_signal_emitted_with_parameters(SceneRouter, "map_change_requested", [&"hall", &"door"])
	await wait_seconds(0.5)
	assert_false(SceneRouter.busy)
	town.perform(&"interact", null, town.get("SMITHY_DOOR"))
	await wait_seconds(0.6)
	assert_signal_emitted_with_parameters(SceneRouter, "map_change_requested", [&"smithy", &"door"])
	await wait_seconds(0.5)
	assert_false(SceneRouter.busy)
	watch_signals(EventBus)
	town.perform(&"interact", null, Vector2i(37, 17))
	assert_signal_emitted(EventBus, "banner_requested")


func test_the_rooms_lead_back_and_the_map_fills_with_lamps() -> void:
	var hall := _hall()
	assert_true(hall.indoor)
	assert_eq(hall.trigger_at(Vector2i(12, 14))["map"], &"town")
	assert_eq(hall.trigger_at(Vector2i(12, 14))["spawn"], &"hall_door")
	assert_eq(hall.query_use(null, Vector2i(9, 1), GameMap.Facing.UP), &"interact")
	assert_eq(hall.map_filled(), 0)
	assert_false(hall.patch_visible(0))
	GameState.set_flag(&"lamp_plaza")
	GameState.set_flag(&"lamp_east")
	assert_eq(hall.map_filled(), 2)
	assert_true(hall.patch_visible(0), "广场灯补上第一格")
	assert_false(hall.patch_visible(1))
	assert_true(hall.patch_visible(4), "东滩灯补上下排中间")
	var smithy := _smithy()
	assert_eq(smithy.map_id, &"smithy")
	assert_eq(smithy.trigger_at(Vector2i(11, 13))["spawn"], &"smithy_door")
	assert_eq(smithy.query_use(null, Vector2i(11, 3), GameMap.Facing.UP), &"interact", "对着炉子")
	assert_eq(smithy.query_use(null, Vector2i(11, 10), GameMap.Facing.UP), &"")


func _town() -> OutdoorMap:
	var scene: PackedScene = load(SceneRouter.MAPS[&"town"])
	var town: OutdoorMap = scene.instantiate()
	add_child_autofree(town)
	return town


func _hall() -> GameMap:
	var scene: PackedScene = load(SceneRouter.MAPS[&"hall"])
	var room: GameMap = scene.instantiate()
	add_child_autofree(room)
	return room


func _smithy() -> GameMap:
	var scene: PackedScene = load(SceneRouter.MAPS[&"smithy"])
	var room: GameMap = scene.instantiate()
	add_child_autofree(room)
	return room
