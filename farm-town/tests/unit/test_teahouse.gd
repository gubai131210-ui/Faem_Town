extends GutTest
## 云来茶馆能走进去，门垫回到镇广场门口（决策 109）。


func before_each() -> void:
	SaveSystem.base_dir = "user://test_saves_teahouse"
	SaveSystem.reset_all()


func test_the_front_door_is_the_middle_of_the_teahouse_wall() -> void:
	var town := _town()
	var door: Vector2i = town.get("TEAHOUSE_DOOR")
	assert_eq(door, Vector2i(37, 8))
	assert_eq(town.query_use(null, door, GameMap.Facing.UP), &"interact")
	assert_ne(town.call(&"_sign_at", door), "", "门仍在茶馆正面上")
	assert_eq(town.query_use(null, Vector2i(8, 17), GameMap.Facing.UP), &"interact", "杂货铺的墙还是看看")


func test_using_the_door_goes_inside() -> void:
	var town := _town()
	watch_signals(SceneRouter)
	town.perform(&"interact", null, town.get("TEAHOUSE_DOOR"))
	await wait_seconds(0.6)
	assert_signal_emitted_with_parameters(SceneRouter, "map_change_requested", [&"teahouse", &"door"])
	await wait_seconds(0.5)
	assert_false(SceneRouter.busy)


func test_the_mat_leads_back_and_a_table_is_a_table() -> void:
	var room := _room()
	assert_true(room.indoor)
	assert_eq(room.map_id, &"teahouse")
	var out: Dictionary = room.trigger_at(Vector2i(12, 14))
	assert_eq(out["map"], &"town")
	assert_eq(out["spawn"], &"teahouse_door")
	assert_eq(room.trigger_at(Vector2i(3, 6)), {})
	assert_eq(room.query_use(null, Vector2i(3, 7), GameMap.Facing.UP), &"interact", "对着茶桌")
	assert_eq(room.query_use(null, Vector2i(11, 10), GameMap.Facing.UP), &"", "过道上没有东西")
	watch_signals(EventBus)
	room.perform(&"interact", null, Vector2i(3, 7))
	assert_signal_emitted(EventBus, "banner_requested")
	var town := _town()
	var back: Vector2 = town.spawn_position(&"teahouse_door")
	assert_eq(town.tile_of(back), Vector2i(37, 10))
	assert_eq(town.spawn_facing(&"teahouse_door"), GameMap.Facing.UP)


func _town() -> OutdoorMap:
	var scene: PackedScene = load(SceneRouter.MAPS[&"town"])
	var town: OutdoorMap = scene.instantiate()
	add_child_autofree(town)
	return town


func _room() -> GameMap:
	var scene: PackedScene = load(SceneRouter.MAPS[&"teahouse"])
	var room: GameMap = scene.instantiate()
	add_child_autofree(room)
	return room
