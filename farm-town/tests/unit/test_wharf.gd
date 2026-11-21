extends GutTest
## 河岸西边通到河埠；木匠铺能进去。桥的北头接上竹海（决策 126）。


func before_each() -> void:
	SaveSystem.base_dir = "user://test_saves_wharf"
	SaveSystem.reset_all()


func test_the_west_edge_of_the_riverbank_opens_the_wharf() -> void:
	var bank := _bank()
	assert_false(bank.blocked(bank.tile_center(Vector2i(1, 16))), "西边的土路能走")
	var edge: Dictionary = bank.trigger_at(Vector2i(0, 16))
	assert_eq(edge["map"], &"wharf")
	assert_eq(edge["spawn"], &"from_riverbank")
	assert_eq(bank.trigger_at(Vector2i(0, 12)), {}, "岸边不是出口")
	var back: Vector2 = bank.spawn_position(&"from_wharf")
	assert_eq(bank.tile_of(back), Vector2i(1, 17), "站在西边土路上，不踩回出口")
	assert_eq(bank.spawn_facing(&"from_wharf"), GameMap.Facing.RIGHT)
	assert_false(bank.blocked(back))


func test_the_shops_stand_on_the_wharf_and_the_dock_path_stays() -> void:
	var wharf := _wharf()
	assert_eq(wharf.query_use(null, Vector2i(4, 12), GameMap.Facing.UP), &"interact", "木匠铺的门")
	assert_eq(wharf.query_use(null, Vector2i(3, 12), GameMap.Facing.UP), &"interact", "门旁边的墙")
	assert_eq(wharf.query_use(null, Vector2i(11, 12), GameMap.Facing.UP), &"interact", "酱园")
	assert_eq(wharf.query_use(null, Vector2i(17, 12), GameMap.Facing.UP), &"interact", "茶摊")
	assert_eq(wharf.query_use(null, Vector2i(22, 3), GameMap.Facing.UP), &"interact", "桥面还能看")
	assert_eq(wharf.query_use(null, Vector2i(7, 5), GameMap.Facing.UP), &"interact", "渡口")
	assert_gt(wharf.find_path(Vector2i(50, 14), Vector2i(4, 14)).size(), 0, "从东边的路走得到铺子门口")
	assert_gt(wharf.find_path(Vector2i(22, 6), Vector2i(22, 2)).size(), 0, "桥面走得到北头")
	assert_eq(wharf.trigger_at(Vector2i(22, 2))["map"], &"zhuhai", "桥北头进竹海")
	assert_eq(wharf.trigger_at(Vector2i(22, 3)), {}, "桥中间不换地图")
	var back_sea: Vector2 = wharf.spawn_position(&"from_zhuhai")
	assert_eq(wharf.tile_of(back_sea), Vector2i(22, 4), "回来站在桥上，不踩回竹海")
	assert_eq(wharf.spawn_facing(&"from_zhuhai"), GameMap.Facing.DOWN)
	assert_false(wharf.blocked(back_sea))
	assert_eq(wharf.fishing_water(Vector2i(4, 3)), &"river")
	assert_eq(wharf.fishing_water(Vector2i(7, 5)), &"")
	var edge: Dictionary = wharf.trigger_at(Vector2i(51, 14))
	assert_eq(edge["map"], &"riverbank")
	assert_eq(edge["spawn"], &"from_wharf")
	var here: Vector2 = wharf.spawn_position(&"from_riverbank")
	assert_eq(wharf.tile_of(here), Vector2i(50, 14))
	assert_false(wharf.blocked(here))
	watch_signals(EventBus)
	wharf.perform(&"interact", null, Vector2i(11, 12))
	assert_signal_emitted(EventBus, "banner_requested")


func test_the_carpenter_door_opens_the_workshop() -> void:
	var wharf := _wharf()
	watch_signals(SceneRouter)
	wharf.perform(&"interact", null, wharf.DOOR)
	await wait_seconds(0.6)
	assert_signal_emitted_with_parameters(SceneRouter, "map_change_requested", [&"workshop", &"door"])
	await wait_seconds(0.5)
	assert_false(SceneRouter.busy)
	var room := _room()
	assert_true(room.indoor)
	assert_eq(room.map_id, &"workshop")
	var out: Dictionary = room.trigger_at(Vector2i(12, 13))
	assert_eq(out["map"], &"wharf")
	assert_eq(out["spawn"], &"carpenter_door")
	assert_eq(room.query_use(null, Vector2i(8, 1), GameMap.Facing.UP), &"interact", "对着图纸")
	assert_eq(room.query_use(null, Vector2i(11, 11), GameMap.Facing.UP), &"", "过道上没有东西")
	var back: Vector2 = wharf.spawn_position(&"carpenter_door")
	assert_eq(wharf.tile_of(back), Vector2i(4, 14))
	assert_eq(wharf.spawn_facing(&"carpenter_door"), GameMap.Facing.UP)
	assert_false(wharf.blocked(back))


func _bank() -> OutdoorMap:
	var scene: PackedScene = load(SceneRouter.MAPS[&"riverbank"])
	var bank: OutdoorMap = scene.instantiate()
	add_child_autofree(bank)
	return bank


func _wharf() -> OutdoorMap:
	var scene: PackedScene = load(SceneRouter.MAPS[&"wharf"])
	var wharf: OutdoorMap = scene.instantiate()
	add_child_autofree(wharf)
	return wharf


func _room() -> GameMap:
	var scene: PackedScene = load(SceneRouter.MAPS[&"workshop"])
	var room: GameMap = scene.instantiate()
	add_child_autofree(room)
	return room
