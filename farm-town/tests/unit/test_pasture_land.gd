extends GutTest
## 扩大的北坡牧场（决策 151）：往东、往南长到 76×48，老牧场一格不动；东边多一块歇着的草场和草料棚，南边多羊圈、水塘和井。

const TMP_SAVES := "user://test_saves_pasture_land"

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
	var m: OutdoorMap = load("res://maps/pasture/pasture.tscn").instantiate()
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


func test_size_and_exits() -> void:
	var m := _map()
	assert_eq(m.size_px(), Vector2i(76 * 16, 48 * 16))
	assert_eq(m.trigger_at(Vector2i(75, 14)), {"map": &"town", "spawn": &"from_pasture"})
	assert_eq(m.trigger_at(Vector2i(75, 15)), {"map": &"town", "spawn": &"from_pasture"})
	assert_true(m.trigger_at(Vector2i(43, 14)).is_empty(), "老东口现在是路")
	assert_false(m.blocked(m.spawn_position(&"from_town")))


func test_old_pasture_did_not_move() -> void:
	var m := _map()
	var lines: Array[String] = []
	for y in 28:
		for x in 42:
			var t := Vector2i(x, y)
			lines.append("%d,%d,%d,%d,%d" % [x, y, m.terrain[m.idx(t)], m.solid[m.idx(t)], 1 if m.occupied.has(t) else 0])
	assert_eq("\n".join(lines).hash(), 3335486578, "老牧场的地形、挡路格、占着的格和扩大以前一样")
	var n := 0
	for c in m.entities.get_children():
		var s := c as Sprite2D
		if s != null and s.position.x < 42 * 16 and s.position.y < 28 * 16:
			n += 1
	assert_eq(n, 447, "老牧场里的树、草、石头、栅栏一个没多一个没少")


func test_every_clue_is_reachable_from_the_east_gate() -> void:
	var m := _map()
	var from := Vector2i(74, 14)
	assert_gt(m.clues.size(), 8)
	for t: Vector2i in m.clues:
		assert_ne(m.clue_at(t), "")
		assert_true(_reach_side(m, from, t), "站得到 %s 旁边" % str(t))
	assert_true(_reach(m, from, Vector2i(18, 17)), "新路接得上老牧场的草场口")
	assert_true(_reach(m, from, Vector2i(50, 44)), "往南的路走得通")


func test_new_water_and_clue_use() -> void:
	var m := _map()
	assert_true(m._is_water(Vector2i(62, 39)), "南边多一个水塘")
	var t := Vector2i(53, 30)
	assert_ne(m.clue_at(t), "")
	assert_eq(m.query_use(null, t, GameMap.Facing.UP), &"interact")
