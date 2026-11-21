extends GutTest
## 东滩灯带回鱼市和船坞，山祠灯带回山门和学堂。只看看，不进人（决策 116）。

var _banners: Array[String] = []


func before_each() -> void:
	SaveSystem.reset_all()
	Weather.today = &"sunny"
	_banners.clear()
	EventBus.banner_requested.connect(_on_banner)


func after_each() -> void:
	if EventBus.banner_requested.is_connected(_on_banner):
		EventBus.banner_requested.disconnect(_on_banner)
	SaveSystem.reset_all()


func _on_banner(text: String) -> void:
	_banners.append(text)


func test_the_beach_keeps_its_paths_and_gains_a_stall_and_a_yard() -> void:
	var beach: OutdoorMap = _map(&"dongtan")
	var from := Vector2i(1, 14)
	var pier: Array = beach.get(&"_pier")
	var end: Vector2i = pier[pier.size() - 1]
	assert_false(beach.find_path(from, end).is_empty(), "还走得到栈桥头")
	assert_false(beach.find_path(from, Vector2i(36, 8)).is_empty(), "还走得到灯塔门口")
	assert_false(beach.find_path(from, Vector2i(13, 11)).is_empty(), "还走得到白鹭画室门口")
	assert_false(beach.find_path(from, Vector2i(27, 20)).is_empty(), "还走得到白鹭画画的地方")
	assert_eq(beach.solid[beach.idx(Vector2i(27, 20))], 0)
	assert_eq(beach.solid[beach.idx(Vector2i(13, 11))], 0)
	var market: Array = beach.get("FISH_MARKET")
	var yard: Array = beach.get("BOATYARD")
	var mx: int = market[0]
	var my: int = market[1]
	var yx: int = yard[0]
	var yy: int = yard[1]
	var market_door := Vector2i(mx + 1, my - 1)
	var yard_door := Vector2i(yx + 1, yy - 1)
	assert_true(beach.blocked(GameMap.tile_center(market_door)), "鱼市的案挡路")
	assert_true(beach.blocked(GameMap.tile_center(yard_door)), "船坞挡路")
	assert_false(beach.find_path(from, Vector2i(mx + 1, my)).is_empty(), "走得到鱼市门前")
	assert_false(beach.find_path(from, Vector2i(yx + 1, yy)).is_empty(), "走得到船坞门前")
	assert_eq(beach.query_use(null, market_door, GameMap.Facing.UP), &"interact")
	beach.perform(&"interact", null, market_door)
	assert_string_contains(_banners[-1], "鱼市")
	assert_eq(beach.query_use(null, yard_door, GameMap.Facing.UP), &"interact")
	beach.perform(&"interact", null, yard_door)
	assert_string_contains(_banners[-1], "船坞")
	assert_eq(beach.trigger_at(Vector2i(0, 14)).get("map"), &"riverbank")


func test_the_hill_keeps_its_paths_and_gains_a_gate_and_a_school() -> void:
	var hill: OutdoorMap = _map(&"shanci")
	var from := Vector2i(21, 28)
	assert_false(hill.find_path(from, Vector2i(21, 10)).is_empty(), "还走得到祠门口")
	assert_true(hill.blocked(GameMap.tile_center(Vector2i(21, 8))), "古祠还挡路")
	assert_false(hill.find_path(from, Vector2i(9, 15)).is_empty(), "还走得进桂花林")
	var shore := Vector2i(-1, -1)
	for x in range(26, 35):
		if hill.fishing_water(Vector2i(x + 1, 19)) == &"lake" and hill.solid[hill.idx(Vector2i(x, 19))] == 0:
			shore = Vector2i(x, 19)
			break
	assert_ne(shore, Vector2i(-1, -1))
	assert_false(hill.find_path(from, shore).is_empty(), "还走得到湖边")
	assert_eq(hill.solid[hill.idx(Vector2i(25, 11))], 0, "岚站的地方还是空地")
	assert_eq(hill.solid[hill.idx(Vector2i(21, 16))], 0, "山门中间能过")
	assert_eq(hill.solid[hill.idx(Vector2i(22, 16))], 0, "山门中间能过")
	assert_true(hill.blocked(GameMap.tile_center(Vector2i(20, 16))), "西边的石柱挡路")
	assert_true(hill.blocked(GameMap.tile_center(Vector2i(23, 16))), "东边的石柱挡路")
	assert_eq(hill.query_use(null, Vector2i(21, 16), GameMap.Facing.UP), &"interact")
	hill.perform(&"interact", null, Vector2i(21, 16))
	assert_string_contains(_banners[-1], "山门")
	var school: Array = hill.get("SCHOOL")
	var sx: int = school[0]
	var sy: int = school[1]
	var school_door := Vector2i(sx + 1, sy - 1)
	assert_true(hill.blocked(GameMap.tile_center(school_door)), "学堂挡路")
	assert_false(hill.find_path(from, Vector2i(sx + 1, sy)).is_empty(), "走得到学堂门前")
	assert_eq(hill.query_use(null, school_door, GameMap.Facing.UP), &"interact")
	hill.perform(&"interact", null, school_door)
	assert_string_contains(_banners[-1], "学堂")
	assert_eq(hill.query_use(null, Vector2i(21, 9), GameMap.Facing.UP), &"interact", "古祠的门还是看看")


func _map(id: StringName) -> OutdoorMap:
	var scene: PackedScene = load(SceneRouter.MAPS[id])
	var m: OutdoorMap = scene.instantiate()
	add_child_autofree(m)
	return m
