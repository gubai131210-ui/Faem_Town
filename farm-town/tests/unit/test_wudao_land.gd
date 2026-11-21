extends GutTest
## 扩大的雾岛（决策 156）：往东、往南长到 48×42，老区域一格不动；新区只有景物和一句话线索。

const TMP_SAVES := "user://test_saves_wudao_land"

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
	var m: OutdoorMap = load("res://maps/wudao/wudao.tscn").instantiate()
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
	assert_eq(m.size_px(), Vector2i(48 * 16, 42 * 16))
	assert_eq(m.trigger_at(Vector2i(16, 41)), {"map": &"dongtan", "spawn": &"from_wudao"})
	assert_eq(m.trigger_at(Vector2i(17, 41)), {"map": &"dongtan", "spawn": &"from_wudao"})
	assert_true(m.trigger_at(Vector2i(16, 25)).is_empty(), "老南口现在是沙埂")
	assert_false(m.blocked(m.spawn_position(&"landing")))


func test_old_area_did_not_move() -> void:
	var m := _map()
	var lines: Array[String] = []
	for y in 24:
		for x in 30:
			var t := Vector2i(x, y)
			lines.append("%d,%d,%d,%d,%d" % [x, y, m.terrain[m.idx(t)], m.solid[m.idx(t)], 1 if m.occupied.has(t) else 0])
	assert_eq("\n".join(lines).hash(), 2183233172, "老区域的地形、挡路格、占着的格和扩大以前一样")
	var n := 0
	for c in m.entities.get_children():
		var s := c as Sprite2D
		if s != null and s.position.x < 30 * 16 and s.position.y < 24 * 16:
			n += 1
	assert_eq(n, 7, "老区域里的树、草、石头一个没多一个没少")


func test_every_clue_is_reachable() -> void:
	var m := _map()
	var from := Vector2i(16, 22)
	assert_gt(m.clues.size(), 4)
	for t: Vector2i in m.clues:
		assert_ne(m.clue_at(t), "")
		assert_true(_reach_side(m, from, t), "站得到 %s 旁边" % str(t))
	assert_true(_reach(m, from, Vector2i(16, 40)), "沙埂一直通到新的南边缘")
	assert_true(_reach(m, from, Vector2i(38, 33)), "东南的小沙洲走得到")


func test_clue_is_interactable() -> void:
	var m := _map()
	var t: Vector2i = m.clues.keys()[0]
	assert_eq(m.query_use(null, t, GameMap.Facing.UP), &"interact")
