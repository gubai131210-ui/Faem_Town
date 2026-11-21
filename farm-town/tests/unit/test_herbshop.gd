extends GutTest
## 姜记药铺能走进去，门垫回到镇北街门口（决策 110）。
## 见过玉兔以后，其余药柜能喝一剂，最左边仍是旧方子。


const HerbshopScript := preload("res://maps/herbshop/herbshop.gd")


func before_each() -> void:
	SaveSystem.base_dir = "user://test_saves_herbshop"
	SaveSystem.reset_all()


func test_the_front_door_is_the_middle_of_the_herb_wall() -> void:
	var town := _town()
	var door: Vector2i = town.get("HERB_DOOR")
	assert_eq(door, Vector2i(8, 8))
	assert_eq(town.query_use(null, door, GameMap.Facing.UP), &"interact")
	assert_ne(town.call(&"_sign_at", door), "", "门仍在药铺正面上")
	assert_eq(town.query_use(null, Vector2i(6, 8), GameMap.Facing.UP), &"interact", "门旁边的墙还是看看")
	assert_eq(town.query_use(null, Vector2i(8, 17), GameMap.Facing.UP), &"interact", "杂货铺的墙还是看看")


func test_using_the_door_goes_inside() -> void:
	var town := _town()
	watch_signals(SceneRouter)
	town.perform(&"interact", null, town.get("HERB_DOOR"))
	await wait_seconds(0.6)
	assert_signal_emitted_with_parameters(SceneRouter, "map_change_requested", [&"herbshop", &"door"])
	await wait_seconds(0.5)
	assert_false(SceneRouter.busy)


func test_the_mat_leads_back_and_a_counter_is_a_counter() -> void:
	var room := _room()
	assert_true(room.indoor)
	assert_eq(room.map_id, &"herbshop")
	var out: Dictionary = room.trigger_at(Vector2i(10, 13))
	assert_eq(out["map"], &"town")
	assert_eq(out["spawn"], &"herb_door")
	assert_eq(room.trigger_at(Vector2i(10, 12)), {})
	assert_eq(room.query_use(null, Vector2i(6, 1), GameMap.Facing.UP), &"interact", "对着药柜")
	assert_eq(room.query_use(null, Vector2i(10, 10), GameMap.Facing.UP), &"", "过道上没有东西")
	watch_signals(EventBus)
	room.perform(&"interact", null, Vector2i(6, 1))
	assert_signal_emitted(EventBus, "banner_requested")
	var town := _town()
	var back: Vector2 = town.spawn_position(&"herb_door")
	assert_eq(town.tile_of(back), Vector2i(8, 10))
	assert_eq(town.spawn_facing(&"herb_door"), GameMap.Facing.UP)
	assert_false(town.blocked(back), "出来站在姜婆婆前面一格，不叠在她身上")


func test_yutu_medicine_is_one_sip_and_the_left_drawer_stays_the_slip() -> void:
	var room := _room()
	var slip := Vector2i(HerbshopScript.COUNTER_X0, 1)
	var drawer := Vector2i(6, 1)
	assert_ne(drawer.x, slip.x, "（6, 1）不是最左边的旧方子")
	GameState.energy = 20
	assert_false(Bestiary.known(&"yutu"))
	watch_signals(EventBus)
	room.perform(&"interact", null, drawer)
	assert_eq(GameState.energy, 20, "没见过玉兔，不加体力")
	assert_false(GameState.has_flag(&"yutu_medicine"))
	assert_false(GameState.has_flag(&"read_herb_slip"))
	assert_eq(_banner(), "药柜上的小抽屉一格一格，闻着发苦。")
	Bestiary.know(&"yutu")
	room.perform(&"interact", null, slip)
	assert_eq(GameState.energy, 20, "最左边仍是旧方子，不加体力")
	assert_false(GameState.has_flag(&"yutu_medicine"))
	assert_true(GameState.has_flag(&"read_herb_slip"))
	assert_eq(_banner(), "最左边的抽屉缝里露出半张方子。药名磨掉了，只剩剂量。")
	room.perform(&"interact", null, drawer)
	assert_eq(GameState.energy, 60, "见过以后喝一剂，体力 +40")
	assert_true(GameState.has_flag(&"yutu_medicine"))
	assert_eq(_banner(), "柜上留着玉兔捣的药。喝了，身上暖和一点。")
	room.perform(&"interact", null, drawer)
	assert_eq(GameState.energy, 60, "再按不再加")
	assert_eq(_banner(), "药柜上的小抽屉一格一格，闻着发苦。")
	# 标记是一次性的。清掉再喝，才能看快满时会不会超过上限。
	GameState.clear_flag(&"yutu_medicine")
	var almost := GameState.max_energy - 10
	assert_gt(almost + 40, GameState.max_energy)
	GameState.energy = almost
	room.perform(&"interact", null, drawer)
	assert_eq(GameState.energy, GameState.max_energy, "快满了也不超过上限")
	assert_true(GameState.has_flag(&"yutu_medicine"))
	assert_eq(_banner(), "柜上留着玉兔捣的药。喝了，身上暖和一点。")


func _town() -> OutdoorMap:
	var scene: PackedScene = load(SceneRouter.MAPS[&"town"])
	var town: OutdoorMap = scene.instantiate()
	add_child_autofree(town)
	return town


func _room() -> GameMap:
	var scene: PackedScene = load(SceneRouter.MAPS[&"herbshop"])
	var room: GameMap = scene.instantiate()
	add_child_autofree(room)
	return room


func _banner() -> String:
	var said: Array = get_signal_parameters(EventBus, "banner_requested")
	return str(said[0])
