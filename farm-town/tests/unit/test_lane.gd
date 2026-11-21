extends GutTest
## 牧野灯带回老牧道、磨坊和土地庙；井口西边通到矿工巷（决策 114）。


func before_each() -> void:
	SaveSystem.base_dir = "user://test_saves_lane"
	SaveSystem.reset_all()


func test_the_pasture_keeps_the_old_road_the_mill_and_the_shrine() -> void:
	var pasture := _map(&"pasture")
	assert_eq(pasture.query_use(null, Vector2i(2, 11), GameMap.Facing.UP), &"interact", "磨坊")
	assert_eq(pasture.query_use(null, Vector2i(18, 12), GameMap.Facing.UP), &"interact", "土地庙")
	assert_eq(pasture.query_use(null, Vector2i(7, 13), GameMap.Facing.UP), &"interact", "老牧道")
	var from := GameMap.tile_of(pasture.spawn_position(&"from_town"))
	for goal: Vector2i in [Vector2i(14, 12), Vector2i(18, 16), Vector2i(16, 20), Vector2i(31, 10), Vector2i(36, 19), Vector2i(3, 12)]:
		assert_gt(pasture.find_path(from, goal).size(), 0, "从路口走得到 %s" % goal)
	watch_signals(EventBus)
	pasture.perform(&"interact", null, Vector2i(7, 13))
	assert_signal_emitted(EventBus, "banner_requested")


func test_the_wellhead_west_edge_opens_the_lane() -> void:
	var well := _map(&"wellhead")
	assert_eq(well.solid[well.idx(Vector2i(9, 9))], 0, "老秦晴天站的地方还是空地")
	assert_eq(well.solid[well.idx(Vector2i(8, 9))], 0, "老秦雨天站的地方还是空地")
	assert_false(well.find_path(Vector2i(12, 19), Vector2i(9, 9)).is_empty(), "从路上还走得到老秦那儿")
	assert_false(well.blocked(well.tile_center(Vector2i(1, 12))), "西边的路能走")
	var edge: Dictionary = well.trigger_at(Vector2i(0, 12))
	assert_eq(edge["map"], &"lane")
	assert_eq(edge["spawn"], &"from_wellhead")
	var back: Vector2 = well.spawn_position(&"from_lane")
	assert_eq(well.tile_of(back), Vector2i(1, 12))
	assert_eq(well.spawn_facing(&"from_lane"), GameMap.Facing.RIGHT)
	assert_false(well.blocked(back))


func test_the_lane_houses_have_blank_boards_and_lead_back() -> void:
	var lane := _map(&"lane")
	assert_eq(lane.query_use(null, Vector2i(3, 6), GameMap.Facing.UP), &"interact")
	assert_eq(lane.query_use(null, Vector2i(7, 6), GameMap.Facing.UP), &"interact")
	assert_eq(lane.query_use(null, Vector2i(11, 6), GameMap.Facing.UP), &"interact")
	assert_eq(lane.query_use(null, Vector2i(15, 6), GameMap.Facing.UP), &"interact")
	assert_eq(lane.trigger_at(Vector2i(3, 6)), {}, "屋子这轮不进")
	assert_gt(lane.find_path(Vector2i(48, 8), Vector2i(3, 8)).size(), 0, "从东边走得到第一家门口")
	var edge: Dictionary = lane.trigger_at(Vector2i(49, 8))
	assert_eq(edge["map"], &"wellhead")
	assert_eq(edge["spawn"], &"from_lane")
	var here: Vector2 = lane.spawn_position(&"from_wellhead")
	assert_false(lane.blocked(here))
	watch_signals(EventBus)
	lane.perform(&"interact", null, Vector2i(3, 6))
	assert_signal_emitted(EventBus, "banner_requested")


func _map(id: StringName) -> OutdoorMap:
	var scene: PackedScene = load(SceneRouter.MAPS[id])
	var m: OutdoorMap = scene.instantiate()
	add_child_autofree(m)
	return m
