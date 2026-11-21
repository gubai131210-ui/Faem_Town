extends GutTest
## 三张大地图（茶岭、藕花荡、古木林）：高低地只能走石阶上下，从入口走得到每一处地标。


func before_each() -> void:
	SaveSystem.base_dir = "user://test_saves_wild"
	SaveSystem.reset_all()
	GameClock.day = 10
	GameClock.minutes = 600.0
	Weather.today = Weather.SUNNY


func test_relief_blocks_everything_but_the_stairs() -> void:
	var map := WildMap.new()
	add_child_autofree(map)
	map._setup_wild(12, 10)
	map._raise(0, 0, 11, 4, 1)
	map._steps(5, 6, 5)
	map._set_water(Vector2i(9, 3))
	map._set_water(Vector2i(9, 4))
	map._finish_relief()
	assert_eq(map.face[map.idx(Vector2i(2, 5))], 1, "高地南边那一格是崖面")
	assert_eq(map.solid[map.idx(Vector2i(2, 5))], 1, "崖面挡路")
	assert_eq(map.stair[map.idx(Vector2i(5, 5))], 1)
	assert_eq(map.solid[map.idx(Vector2i(5, 5))], 0, "石阶能走")
	assert_eq(map.stair[map.idx(Vector2i(5, 4))], 0, "石阶只在崖面上算数")
	assert_eq(map.fall[map.idx(Vector2i(9, 5))], 1, "水流到崖边，崖面上是瀑布")
	assert_eq(map.fall[map.idx(Vector2i(2, 5))], 0)
	assert_eq(map.face[map.idx(Vector2i(2, 6))], 0, "只高一级，崖面只有一格")


func test_two_levels_make_a_two_tile_face_and_side_rims_block() -> void:
	var map := WildMap.new()
	add_child_autofree(map)
	map._setup_wild(12, 10)
	map._raise(3, 0, 8, 3, 2)
	map._finish_relief()
	assert_eq(map.face[map.idx(Vector2i(5, 4))], 1)
	assert_eq(map.face[map.idx(Vector2i(5, 5))], 2, "高两级，崖面两格")
	assert_eq(map.face[map.idx(Vector2i(5, 6))], 0)
	assert_eq(map.solid[map.idx(Vector2i(3, 2))], 1, "西边挨着低地的那一格是崖沿，下不去")
	assert_eq(map.solid[map.idx(Vector2i(8, 2))], 1, "东边也是")
	assert_eq(map.solid[map.idx(Vector2i(5, 2))], 0, "高地中间能走")
	assert_eq(map.rim[map.idx(Vector2i(3, 2))] & 2, 2)


func test_chaling_every_terrace_is_reached_by_the_stairs() -> void:
	var map := _map(&"chaling")
	var start := map.tile_of(map.spawn_position(&"from_pasture"))
	assert_eq(map.trigger_at(Vector2i(71, 49))["map"], &"pasture")
	assert_eq(map.trigger_at(Vector2i(71, 50))["spawn"], &"from_chaling")
	assert_eq(map.level[map.idx(start)], 0, "进来在谷底")
	for goal: Vector2i in [Vector2i(23, 49), Vector2i(52, 30), Vector2i(30, 11), Vector2i(21, 10), Vector2i(15, 10), Vector2i(61, 9)]:
		assert_gt(map.find_path(start, goal).size(), 0, "走得到 %s" % goal)
	assert_eq(map.level[map.idx(Vector2i(30, 11))], 6, "亭子在岭顶")
	assert_eq(map.level[map.idx(Vector2i(52, 30))], 3, "茶坊在半山")
	assert_eq(map.query_use(null, Vector2i(30, 9), GameMap.Facing.UP), &"interact")
	assert_string_contains(map.clue_at(Vector2i(30, 9)), "观云亭")
	var tea := 0
	for y in map.rows:
		for x in map.cols:
			if map.clue_at(Vector2i(x, y)).begins_with("一垄茶"):
				tea += 1
				assert_eq(map.solid[map.idx(Vector2i(x, y))], 1, "茶垄挡路")
	assert_gt(tea, 250, "满坡都是茶")


func test_ouhua_bridges_reach_the_islands_and_the_platform() -> void:
	var map := _map(&"ouhua")
	var start := map.tile_of(map.spawn_position(&"from_nanxi"))
	assert_eq(map.trigger_at(Vector2i(79, 10))["map"], &"nanxi")
	for goal: Vector2i in [Vector2i(20, 9), Vector2i(51, 9), Vector2i(9, 19), Vector2i(44, 32), Vector2i(60, 39), Vector2i(62, 26), Vector2i(25, 33)]:
		assert_gt(map.find_path(start, goal).size(), 0, "走得到 %s" % goal)
	assert_eq(map.solid[map.idx(Vector2i(40, 18))], 0, "九曲桥能走")
	assert_eq(map.fishing_water(Vector2i(40, 18)), &"", "桥上不是钓点")
	assert_eq(map.solid[map.idx(Vector2i(44, 22))], 1, "荡子里的水过不去")
	assert_eq(map.fishing_water(Vector2i(44, 22)), &"lake")
	assert_eq(map.fishing_water(Vector2i(6, 16)), &"", "水田里不钓鱼")
	assert_string_contains(map.clue_at(Vector2i(6, 16)), "水田")


func test_gulin_trails_cross_the_stream_and_reach_every_landmark() -> void:
	var map := _map(&"gulin")
	var start := map.tile_of(map.spawn_position(&"from_farm"))
	assert_eq(map.trigger_at(Vector2i(40, 0))["map"], &"farm")
	assert_eq(map.trigger_at(Vector2i(41, 0))["spawn"], &"from_gulin")
	for goal: Vector2i in [Vector2i(42, 29), Vector2i(10, 27), Vector2i(16, 33), Vector2i(21, 50), Vector2i(61, 11), Vector2i(66, 53), Vector2i(17, 10), Vector2i(60, 43)]:
		assert_gt(map.find_path(start, goal).size(), 0, "走得到 %s" % goal)
	assert_eq(map.level[map.idx(Vector2i(17, 10))], 2, "泉在石头山顶上")
	assert_eq(map.solid[map.idx(Vector2i(66, 58))], 1, "山口堵着")
	assert_string_contains(map.clue_at(Vector2i(42, 27)), "老樟")


func _map(id: StringName) -> WildMap:
	var scene: PackedScene = load(SceneRouter.MAPS[id])
	var map: WildMap = scene.instantiate()
	add_child_autofree(map)
	return map
