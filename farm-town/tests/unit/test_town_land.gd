extends GutTest
## 扩大的镇子（决策 149）：往东往南长到 84×54，老镇子一格不动；东市随广场灯回来，三块雾区各等一盏灯。

const TMP_SAVES := "user://test_saves_town_land"

var _old_dir := ""


func before_each() -> void:
	_old_dir = SaveSystem.base_dir
	SaveSystem.base_dir = TMP_SAVES
	SaveSystem.reset_all()
	GameClock.day = 10
	GameClock.minutes = 600.0
	Weather.today = Weather.SUNNY
	GameState.set_flag(&"prologue_town")


func after_each() -> void:
	SaveSystem.reset_all()
	SaveSystem.base_dir = _old_dir


func _town() -> OutdoorMap:
	var town: OutdoorMap = load("res://maps/town/town.tscn").instantiate()
	add_child_autofree(town)
	town.npcs.clear()
	return town


func _light(ids: Array) -> void:
	for id: StringName in ids:
		GameState.set_flag(Database.lamp(id).flag())


## 玩家能不能从 from 走到 to（四向，按玩家的挡路规则）
func _reach(town: OutdoorMap, from: Vector2i, to: Vector2i) -> bool:
	var seen := {from: true}
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size():
		var t := queue[head]
		head += 1
		if t == to:
			return true
		for d: Vector2i in GridPath.DIRS:
			var n := t + d
			if town.in_map(n) and not seen.has(n) and not town._tile_blocked(n):
				seen[n] = true
				queue.append(n)
	return false


func _reach_any_side(town: OutdoorMap, from: Vector2i, target: Vector2i) -> bool:
	for d: Vector2i in GridPath.DIRS:
		var n := target + d
		if town.in_map(n) and not town._tile_blocked(n) and _reach(town, from, n):
			return true
	return false


func test_size_and_exits_moved_to_the_new_edges() -> void:
	var town := _town()
	assert_eq(town.size_px(), Vector2i(84 * 16, 54 * 16))
	assert_eq(town.trigger_at(Vector2i(83, 18)), {"map": &"farm", "spawn": &"from_town"})
	assert_eq(town.trigger_at(Vector2i(83, 19)), {"map": &"farm", "spawn": &"from_town"})
	assert_eq(town.trigger_at(Vector2i(22, 53)), {"map": &"nanxi", "spawn": &"from_town"})
	assert_true(town.trigger_at(Vector2i(45, 18)).is_empty(), "老镇口现在是街，不是出口")
	assert_true(town.trigger_at(Vector2i(22, 29)).is_empty())
	assert_eq(town.spawn_position(&"from_farm"), GameMap.tile_center(Vector2i(82, 18)) + Vector2(0, 8))
	assert_eq(town.spawn_position(&"from_nanxi"), GameMap.tile_center(Vector2i(22, 52)) + Vector2(8, 0))


func test_old_town_did_not_move() -> void:
	var town := _town()
	var lines: Array[String] = []
	for y in 28:
		for x in 44:
			var t := Vector2i(x, y)
			lines.append("%d,%d,%d,%d,%d" % [x, y, town.terrain[town.idx(t)], town.solid[town.idx(t)], 1 if town.occupied.has(t) else 0])
	assert_eq("\n".join(lines).hash(), 3587551577, "老镇子的地形、挡路格、占着的格和扩大以前一样")
	var spots: Array[String] = []
	for n in town.entities.get_children():
		var s := n as Sprite2D
		if s != null and s.position.x < 44 * 16 and s.position.y < 28 * 16:
			spots.append("%d,%d" % [int(s.position.x), int(s.position.y)])
	spots.sort()
	assert_eq(spots.size(), 260, "老镇子里的树、灌木、草、房子一个没多一个没少")
	assert_eq("\n".join(spots).hash(), SPOTS_HASH, "每一个都在原来的位置")


const SPOTS_HASH := 2329566360


func test_zones_follow_the_lamps() -> void:
	assert_eq(TownLand.zone_of(Vector2i(30, 40)), TownLand.SOUTH)
	assert_eq(TownLand.zone_of(Vector2i(50, 5)), TownLand.MILL)
	assert_eq(TownLand.zone_of(Vector2i(70, 5)), TownLand.HILL)
	assert_eq(TownLand.zone_of(Vector2i(22, 40)), &"", "南街的路不在雾里")
	assert_eq(TownLand.zone_of(Vector2i(50, 18)), &"", "东街不在雾里")
	assert_eq(TownLand.zone_of(Vector2i(72, 17)), &"", "上山的路口不在雾里")
	assert_true(TownLand.open_zones().is_empty(), "开局三块都盖着")
	_light([&"river"])
	assert_true(TownLand.is_open(TownLand.SOUTH))
	assert_false(TownLand.is_open(TownLand.MILL))
	_light([&"pasture", &"well"])
	assert_eq(TownLand.open_zones().size(), 3)
	for z: Array in TownLand.ZONES:
		assert_ne(TownLand.waiting(z[0]), "")
		assert_ne(TownLand.opened_text(z[0]), "")


func test_fog_blocks_and_says_why() -> void:
	var town := _town()
	var lane := Vector2i(35, 40)
	assert_eq(town.solid[town.idx(lane)], 0, "雾里的地本身是空的")
	assert_true(town._tile_blocked(lane), "雾里走不进去")
	assert_eq(town.query_use(null, lane, GameMap.Facing.DOWN), &"interact")
	watch_signals(EventBus)
	town.perform(&"interact", null, lane)
	assert_string_contains(str(get_signal_parameters(EventBus, "banner_requested")), "河灯")
	assert_true(town._zone_fog.visible)
	_light([&"river"])
	assert_false(town._tile_blocked(lane), "河灯亮了，南巷能走")
	town._sync_zones()
	assert_true(town._zone_fog.visible, "别的两块还盖着")
	_light([&"pasture", &"well"])
	town._sync_zones()
	assert_false(town._zone_fog.visible)


func test_walk_from_both_gates_to_the_plaza() -> void:
	var town := _town()
	var plaza := Vector2i(22, 18)
	assert_true(_reach(town, Vector2i(82, 18), plaza), "农场那头进来，过桥走得到广场")
	assert_true(_reach(town, Vector2i(22, 52), plaza), "南溪那头进来，走得到广场")
	assert_true(_reach(town, Vector2i(82, 18), Vector2i(67, 50)), "东岸的田埂路走得通")
	assert_true(_reach(town, Vector2i(82, 18), Vector2i(72, 17)), "上山的路口走得到")
	assert_false(_reach(town, Vector2i(22, 18), Vector2i(35, 40)), "雾里的南巷走不到")
	assert_false(_reach(town, Vector2i(22, 18), Vector2i(72, 6)), "雾里的北岗走不到")
	assert_false(_reach(town, Vector2i(22, 18), Vector2i(52, 5)), "雾里的磨坊走不到")


func test_every_clue_can_be_reached_when_all_lamps_are_lit() -> void:
	_light([&"plaza", &"river", &"pasture", &"well"])
	var town := _town()
	var from := Vector2i(82, 18)
	var seen := 0
	for t: Vector2i in town.clues:
		seen += 1
		assert_ne(town.clue_at(t), "")
		assert_true(_reach_any_side(town, from, t), "站得到 %s 旁边" % str(t))
	assert_gt(seen, 40, "新镇子上能看的东西不少")
	assert_true(_reach(town, from, Vector2i(72, 7)), "山顶走得上去")
	assert_true(_reach(town, from, Vector2i(35, 38)), "南巷里走得通")
	assert_true(_reach(town, from, Vector2i(52, 4)), "河湾的小路走得通")
	assert_true(_reach(town, Vector2i(35, 38), Vector2i(64, 37)), "南巷的桥能过到东岸")


func test_market_comes_back_with_the_plaza_lamp() -> void:
	var dark := _town()
	assert_eq(dark.clue_at(Vector2i(48, 15)), "", "灯不亮的时候东市是空地")
	assert_eq(dark.terrain[dark.idx(Vector2i(50, 14))], OutdoorMap.GRASS)
	assert_true(dark._walkable(Vector2i(48, 15)))
	_light([&"plaza"])
	var lit := _town()
	assert_ne(lit.clue_at(Vector2i(48, 15)), "茶摊不见了")
	assert_eq(lit.terrain[lit.idx(Vector2i(50, 14))], OutdoorMap.PAVE)
	assert_false(lit._walkable(Vector2i(48, 15)), "摊子挡路")
	assert_true(_reach(lit, Vector2i(82, 18), Vector2i(50, 21)), "东市里走得进去")


func test_tell_each_opened_zone_once() -> void:
	var town := _town()
	town.player = Node2D.new()
	add_child_autofree(town.player)
	watch_signals(EventBus)
	town.entered()
	assert_signal_not_emitted(EventBus, "banner_requested")
	_light([&"river"])
	town.entered()
	assert_string_contains(str(get_signal_parameters(EventBus, "banner_requested")), "南巷")
	assert_true(GameState.has_flag(&"town_zone_south"))
	var told: int = get_signal_emit_count(EventBus, "banner_requested")
	town.entered()
	assert_eq(get_signal_emit_count(EventBus, "banner_requested"), told, "同一块只说一次")
	_light([&"well"])
	town.entered()
	assert_string_contains(str(get_signal_parameters(EventBus, "banner_requested")), "北岗")


func test_hill_only_climbs_by_the_steps() -> void:
	_light([&"well"])
	var town := _town()
	assert_eq(town.solid[town.idx(Vector2i(72, 8))], 0, "石阶能走")
	assert_eq(town.solid[town.idx(Vector2i(73, 8))], 0)
	assert_eq(town.solid[town.idx(Vector2i(71, 8))], 1, "石阶两边是崖")
	assert_eq(town.solid[town.idx(Vector2i(74, 8))], 1)
	assert_true(_reach(town, Vector2i(72, 13), Vector2i(72, 6)))
	assert_eq(town.solid[town.idx(Vector2i(70, 12))], 1, "石门的柱子挡路")
	assert_eq(town.solid[town.idx(Vector2i(72, 12))], 0, "石门中间走得过")


func test_new_edges_have_trees_but_the_roads_stay_open() -> void:
	var town := _town()
	assert_eq(town.solid[town.idx(Vector2i(82, 18))], 0)
	assert_eq(town.solid[town.idx(Vector2i(82, 17))], 0, "农场口两边不长树")
	assert_eq(town.solid[town.idx(Vector2i(22, 52))], 0)
	assert_eq(town.solid[town.idx(Vector2i(21, 52))], 0, "南溪口两边不长树")
	var trees := 0
	for x in range(46, 84):
		if town.solid[town.idx(Vector2i(x, 0))] == 1 and not town._is_water(Vector2i(x, 0)):
			trees += 1
	assert_gt(trees, 5, "北边新长出来的那一段围着树")
	for t in [Vector2i(44, 20), Vector2i(45, 20), Vector2i(43, 28), Vector2i(44, 28), Vector2i(45, 29)]:
		assert_eq(town.solid[town.idx(t)], 0, "老镇子东南边界的树放开了 %s" % str(t))
