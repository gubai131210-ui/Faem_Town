extends GutTest
## 扩大的南溪（决策 150）：往东、往南长到 72×48，老溪岸一格不动；北岸东头多了船屋和栈桥，桥那头多了一片南岸。

const TMP_SAVES := "user://test_saves_nanxi_land"

var _old_dir := ""


func before_each() -> void:
	_old_dir = SaveSystem.base_dir
	SaveSystem.base_dir = TMP_SAVES
	SaveSystem.reset_all()
	GameClock.day = 10
	GameClock.minutes = 600.0
	Weather.today = Weather.SUNNY


func after_each() -> void:
	SaveSystem.reset_all()
	SaveSystem.base_dir = _old_dir


func _map() -> OutdoorMap:
	var m: OutdoorMap = load("res://maps/nanxi/nanxi.tscn").instantiate()
	add_child_autofree(m)
	m.npcs.clear()
	return m


func _reach(m: OutdoorMap, from: Vector2i, to: Vector2i) -> bool:
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
			if m.in_map(n) and not seen.has(n) and not m._tile_blocked(n):
				seen[n] = true
				queue.append(n)
	return false


func _reach_side(m: OutdoorMap, from: Vector2i, target: Vector2i) -> bool:
	for d: Vector2i in GridPath.DIRS:
		var n := target + d
		if m.in_map(n) and not m._tile_blocked(n) and _reach(m, from, n):
			return true
	return false


func test_size_and_north_exit() -> void:
	var m := _map()
	assert_eq(m.size_px(), Vector2i(72 * 16, 48 * 16))
	assert_eq(m.trigger_at(Vector2i(19, 0)), {"map": &"town", "spawn": &"from_nanxi"})
	assert_false(m.blocked(m.spawn_position(&"from_town")))


func test_old_bank_did_not_move() -> void:
	var m := _map()
	var lines: Array[String] = []
	for y in 28:
		for x in 38:
			var t := Vector2i(x, y)
			lines.append("%d,%d,%d,%d,%d" % [x, y, m.terrain[m.idx(t)], m.solid[m.idx(t)], 1 if m.occupied.has(t) else 0])
	assert_eq("\n".join(lines).hash(), 4198036410, "老溪岸的地形、挡路格、占着的格和扩大以前一样")
	var n := 0
	for c in m.entities.get_children():
		var s := c as Sprite2D
		if s != null and s.position.x < 38 * 16 and s.position.y < 28 * 16:
			n += 1
	assert_eq(n, 279, "老溪岸上的树、草、石头一个没多一个没少")


func test_pool_and_pier_reach_the_water() -> void:
	var m := _map()
	assert_true(m._is_water(Vector2i(62, 22)), "东边有个大潭")
	assert_true(m.planks.has(Vector2i(60, 17)), "栈桥架在潭上")
	assert_eq(m.fishing_water(Vector2i(62, 22)), &"stream", "潭里能钓")
	assert_eq(m.fishing_water(Vector2i(60, 17)), &"", "栈桥的木板不算水")


func test_north_bank_walks_east_to_the_pier() -> void:
	var m := _map()
	var from := Vector2i(19, 12)
	assert_true(_reach(m, from, Vector2i(60, 17)), "从码头路走得到栈桥")
	for t: Vector2i in m.clues:
		if t.y < 20:
			assert_true(_reach_side(m, from, t), "北岸的 %s 站得到旁边" % str(t))
	assert_gt(m.clues.size(), 8)


func test_south_bank_needs_the_bridge() -> void:
	var m := _map()
	assert_false(_reach(m, Vector2i(19, 12), Vector2i(40, 38)), "没有桥，对岸过不去")
	Residents.memory_levels[&"qingzhu"] = 5
	var b := _map()
	assert_true(_reach(b, Vector2i(19, 12), Vector2i(40, 38)), "桥修好了，走得到对岸深处")
	for t: Vector2i in b.clues:
		if t.y >= 28:
			assert_true(_reach_side(b, Vector2i(19, 12), t), "南岸的 %s 站得到旁边" % str(t))


func test_clue_is_interactable() -> void:
	var m := _map()
	var t := Vector2i(52, 10)
	assert_ne(m.clue_at(t), "")
	assert_eq(m.query_use(null, t, GameMap.Facing.UP), &"interact")

