extends GutTest
## M5 第一批：沉灯井的楼层生成、镐子敲石头、梯子和井灯、井口地图。

var _banners: Array[String] = []


func before_each() -> void:
	SaveSystem.reset_all()
	Weather.today = &"sunny"
	GameClock.minutes = 600.0
	GameClock.day = 1
	_banners.clear()
	EventBus.banner_requested.connect(_on_banner)


func after_each() -> void:
	EventBus.banner_requested.disconnect(_on_banner)
	SaveSystem.reset_all()
	GameClock.running = false


func _on_banner(text: String) -> void:
	_banners.append(text)


func _map(id: StringName) -> GameMap:
	var scene: PackedScene = load(SceneRouter.MAPS[id])
	var m: GameMap = scene.instantiate()
	add_child_autofree(m)
	return m


func _gen(n: int, seed_value: int) -> MineFloor:
	return MineFloor.generate(n, Database.mine_layer(n), seed_value, n < Mine.OPEN_FLOORS, n % Mine.LAMP_EVERY == 0)


# ---------------------------------------------------------------- 数据表

func test_mine_table_is_valid() -> void:
	assert_eq(Database.validate().size(), 0, "\n".join(Database.validate()))
	assert_not_null(Database.mine_layer(1))
	assert_eq(Database.mine_layer(1).id, &"shallow")
	assert_eq(Database.mine_layer(10).id, &"shallow")
	assert_null(Database.mine_layer(0))
	assert_true(Database.item(&"copper_ore").sellable(), "矿石能卖")
	assert_false(Database.item(&"pickaxe").sellable())


func test_layer_pick_follows_weights() -> void:
	var layer := Database.mine_layer(1)
	assert_eq(layer.pick(0.0), &"copper_ore")
	assert_eq(layer.pick(0.999), &"stone")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var seen: Dictionary = {}
	for i in 400:
		var item := layer.pick(rng.randf())
		seen[item] = int(seen.get(item, 0)) + 1
	assert_gt(int(seen[&"stone"]), int(seen[&"copper_ore"]), "普通石头最多")
	assert_gt(int(seen[&"copper_ore"]), int(seen[&"coal"]))
	assert_gt(int(seen[&"coal"]), 10)


# ---------------------------------------------------------------- 楼层生成

func test_same_seed_gives_same_floor() -> void:
	var a := _gen(3, 42)
	var b := _gen(3, 42)
	assert_eq(a.open.keys(), b.open.keys())
	assert_eq(a.rocks, b.rocks)
	assert_eq(a.ladder, b.ladder)
	var c := _gen(3, 43)
	assert_ne(a.open.keys(), c.open.keys(), "换个种子就不一样")


func test_every_floor_is_playable() -> void:
	for seed_value in 60:
		var n := 1 + seed_value % 9
		var f := _gen(n, seed_value * 7919 + 1)
		assert_gt(f.open.size(), 80, "空地够大")
		for t: Vector2i in f.open:
			assert_true(t.x >= 1 and t.x <= MineFloor.W - 2 and t.y >= 2 and t.y <= MineFloor.H - 2, "四周留着墙")
		assert_true(f.is_open(f.entry) and f.is_open(f.spawn))
		assert_true(f.walkable(f.spawn), "下来的地方站得住")
		assert_false(f.walkable(f.entry), "梯子挡路")
		# 所有空地连成一片：从下来的地方不管石头都走得到
		assert_eq(f.distances().size(), f.open.size(), "种子 %d 的洞是连着的" % seed_value)
		assert_ne(f.ladder, MineFloor.NONE, "有往下的梯子")
		assert_true(f.is_open(f.ladder))
		assert_ne(f.ladder, f.spawn)
		assert_gte(f.distances()[f.ladder], 3, "梯子不在脚边")
		assert_eq(f.has_rock(f.ladder), not f.ladder_found, "梯子要么露着要么压在石头下")
		assert_false(f.has_rock(f.spawn))
		for d in MineFloor.DIRS:
			assert_false(f.has_rock(f.spawn + d), "下来以后身边是空的")
		assert_gt(f.rocks.size(), 15, "有石头可敲")
		for t: Vector2i in f.rocks:
			assert_true(f.is_open(t))
			assert_true(Database.has_item(f.rocks[t]))


func test_lamp_only_on_every_fifth_floor() -> void:
	assert_eq(_gen(4, 1).lamp, MineFloor.NONE)
	for seed_value in 20:
		var f := _gen(5, seed_value)
		assert_ne(f.lamp, MineFloor.NONE)
		assert_true(f.is_open(f.lamp))
		assert_false(f.has_rock(f.lamp))
		assert_false(f.walkable(f.lamp))
		assert_ne(f.lamp, f.spawn)
		assert_ne(f.lamp, f.ladder)


func test_last_open_floor_has_no_ladder() -> void:
	var f := _gen(Mine.OPEN_FLOORS, 9)
	assert_eq(f.ladder, MineFloor.NONE)
	assert_ne(f.lamp, MineFloor.NONE, "第十层有井灯")


func test_hitting_rocks() -> void:
	var f := _gen(2, 11)
	var stone := MineFloor.NONE
	var ore := MineFloor.NONE
	for t: Vector2i in f.rocks:
		if t == f.ladder:
			continue
		if f.rocks[t] == &"stone" and stone == MineFloor.NONE:
			stone = t
		elif f.rocks[t] != &"stone" and ore == MineFloor.NONE:
			ore = t
	assert_ne(stone, MineFloor.NONE)
	assert_ne(ore, MineFloor.NONE)
	assert_true(f.hit(Vector2i(0, 0)).is_empty(), "墙上没东西可敲")
	assert_true(f.breaks_next(stone))
	var res := f.hit(stone)
	assert_true(res["broken"])
	assert_eq(res["item"], &"stone")
	assert_eq(res["count"], 1)
	assert_false(f.has_rock(stone))
	assert_true(f.walkable(stone), "敲开就能走")
	assert_false(f.breaks_next(ore), "矿石要两下")
	assert_false(f.hit(ore)["broken"])
	assert_true(f.has_rock(ore))
	res = f.hit(ore)
	assert_true(res["broken"])
	assert_between(int(res["count"]), 1, 2)


func test_ladder_shows_up_under_its_rock() -> void:
	var f: MineFloor = null
	for seed_value in 50:
		f = _gen(1, seed_value)
		if not f.ladder_found:
			break
	assert_false(f.ladder_found)
	assert_true(f.has_rock(f.ladder))
	var res: Dictionary = {}
	for i in 3:
		res = f.hit(f.ladder)
		if bool(res.get("broken", false)):
			break
	assert_true(res["ladder"])
	assert_true(f.ladder_found)
	assert_false(f.walkable(f.ladder), "露出来的梯子口不能踩")


# ---------------------------------------------------------------- Mine

func test_enter_descend_and_deepest() -> void:
	assert_false(Mine.enter(0))
	assert_false(Mine.enter(Mine.OPEN_FLOORS + 1), "还没挖通的层下不去")
	assert_true(Mine.enter(1, 3))
	assert_eq(Mine.floor_no, 1)
	assert_eq(Mine.deepest, 1)
	Mine.current.ladder_found = false
	assert_false(Mine.descend(), "没找到梯子下不去")
	Mine.current.ladder_found = true
	assert_true(Mine.descend())
	assert_eq(Mine.floor_no, 2)
	assert_eq(Mine.deepest, 2)
	Mine.enter(1)
	assert_eq(Mine.deepest, 2, "回到浅处不改最深记录")
	Mine.leave()
	assert_eq(Mine.floor_no, 0)
	assert_null(Mine.current)


func test_well_lamps_and_lift() -> void:
	assert_eq(Mine.lift_floor(), 0)
	Mine.enter(4)
	assert_false(Mine.light_lamp(), "这一层没有井灯")
	Mine.enter(5)
	assert_true(Mine.light_lamp())
	assert_false(Mine.light_lamp(), "亮过了")
	assert_eq(Mine.lift_floor(), 5)
	Mine.enter(10)
	assert_true(Mine.light_lamp())
	assert_eq(Mine.lift_floor(), 10)


func test_strike_puts_ore_in_the_bag() -> void:
	Mine.enter(1, 21)
	var f := Mine.current
	var ore := MineFloor.NONE
	for t: Vector2i in f.rocks:
		if f.rocks[t] != &"stone" and t != f.ladder:
			ore = t
			break
	assert_ne(ore, MineFloor.NONE)
	var item := f.rocks[ore]
	assert_false(Mine.strike(ore)["broken"])
	assert_eq(GameState.inventory.count_of(item), 0)
	assert_true(Mine.strike(ore)["broken"])
	assert_between(GameState.inventory.count_of(item), 1, 2)
	assert_true(Mine.strike(ore).is_empty(), "敲没了")


func test_full_bag_keeps_the_rock() -> void:
	Mine.enter(1, 21)
	var f := Mine.current
	var inv := GameState.inventory
	for i in inv.size:
		if inv.is_empty_slot(i):
			inv.add(&"scarecrow", 9)
	var stone := MineFloor.NONE
	for t: Vector2i in f.rocks:
		if f.rocks[t] == &"stone" and t != f.ladder:
			stone = t
			break
	assert_true(Mine.strike(stone)["full"])
	assert_true(f.has_rock(stone), "放不下就不敲开")


func test_mine_save_roundtrip_and_night() -> void:
	Mine.enter(5)
	Mine.light_lamp()
	Mine.enter(6)
	var data := Mine.save_data()
	Mine.reset_data()
	assert_eq(Mine.deepest, 0)
	assert_eq(Mine.lift_floor(), 0)
	Mine.load_data(data)
	assert_eq(Mine.deepest, 6)
	assert_eq(Mine.lift_floor(), 5)
	assert_eq(Mine.floor_no, 0, "读档以后人不在井里")
	Mine.enter(2)
	GameClock.advance_day()
	assert_eq(Mine.floor_no, 0, "过了一夜人回到地面")
	Mine.load_data({"deepest": 999, "lit": [5, 7, 5, 300]})
	assert_eq(Mine.deepest, Mine.OPEN_FLOORS)
	assert_eq(Mine.lit, [5] as Array[int], "乱七八糟的井灯记录读进来会筛掉")


# ---------------------------------------------------------------- 地图

func test_north_road_opens_with_the_well_lamp() -> void:
	GameState.set_flag(&"lamp_pasture")
	var town := _map(&"town")
	var edge := Vector2i(13, 0)
	assert_true(town.blocked(GameMap.tile_center(Vector2i(13, 1))), "井口灯没亮，北边还是雾")
	assert_true(town.trigger_at(edge).is_empty())
	town.free()
	GameState.set_flag(&"lamp_well")
	town = _map(&"town")
	assert_false(town.blocked(GameMap.tile_center(Vector2i(13, 1)) + Vector2(8, 0)))
	assert_eq(town.trigger_at(edge).get("map"), &"wellhead")
	assert_false(town.blocked(town.spawn_position(&"from_wellhead")))


func test_wellhead_gives_pickaxe_then_leads_down() -> void:
	var well := _map(&"wellhead")
	assert_false(well.blocked(well.spawn_position(&"from_town")))
	assert_false(well.blocked(well.spawn_position(&"from_mine")))
	assert_eq(well.trigger_at(Vector2i(12, 19)).get("map"), &"town")
	var mouth := Vector2i(12, 6)
	assert_eq(well.query_use(null, mouth, GameMap.Facing.UP), &"interact")
	well.perform(&"interact", null, mouth)
	assert_eq(GameState.inventory.count_of(&"pickaxe"), 1)
	assert_string_contains(_banners[-1], "镐子")
	assert_eq(Mine.floor_no, 0, "头一下只是拿镐子")
	well.perform(&"interact", null, mouth)
	assert_eq(GameState.inventory.count_of(&"pickaxe"), 1, "只拿一把")
	assert_eq(Mine.floor_no, 1)
	await wait_seconds(0.8)


func test_lift_needs_a_lit_lamp() -> void:
	var well := _map(&"wellhead")
	var lift := Vector2i(17, 7)
	assert_eq(well.query_use(null, lift, GameMap.Facing.UP), &"interact")
	well.perform(&"interact", null, lift)
	assert_string_contains(_banners[-1], "井灯")
	assert_eq(Mine.floor_no, 0)
	Mine.enter(5)
	Mine.light_lamp()
	Mine.leave()
	well.perform(&"interact", null, lift)
	assert_eq(Mine.floor_no, 5)
	await wait_seconds(0.8)


func test_mine_map_rocks_ladders_and_lamp() -> void:
	Mine.enter(5, 77)
	var f := Mine.current
	var map := _map(&"mine")
	assert_eq(map.spawn_position(&"ladder"), GameMap.tile_center(f.spawn))
	assert_false(map.blocked(map.spawn_position(&"ladder")))
	assert_true(map.blocked(GameMap.tile_center(Vector2i(0, 0))), "岩壁挡路")
	var pick := Database.item(&"pickaxe")
	var rock := MineFloor.NONE
	for t: Vector2i in f.rocks:
		if f.rocks[t] == &"stone" and t != f.ladder:
			rock = t
			break
	assert_true(map.blocked(GameMap.tile_center(rock)), "石头挡路")
	assert_eq(map.query_use(pick, rock, GameMap.Facing.UP), &"mine")
	assert_eq(map.query_use(Database.item(&"hoe"), rock, GameMap.Facing.UP), &"interact", "别的工具敲不动")
	map.perform(&"interact", null, rock)
	assert_string_contains(_banners[-1], "镐子")
	map.perform(&"mine", pick, rock)
	assert_false(f.has_rock(rock))
	assert_eq(GameState.inventory.count_of(&"stone"), 1)
	assert_false(map.blocked(GameMap.tile_center(rock)))
	assert_eq(map.query_use(pick, rock, GameMap.Facing.UP), &"", "空地没什么可做")
	# 井灯
	assert_eq(map.query_use(null, f.lamp, GameMap.Facing.UP), &"interact")
	map.perform(&"interact", null, f.lamp)
	assert_true(Mine.lamp_lit(5))
	assert_string_contains(_banners[-1], "点亮")
	map.perform(&"interact", null, f.lamp)
	assert_string_contains(_banners[-1], "亮着")
	# 往下的梯子：没露出来按不了，露出来按一下下一层
	if not f.ladder_found:
		assert_ne(map.query_use(null, f.ladder, GameMap.Facing.UP), &"")
		while f.has_rock(f.ladder):
			map.perform(&"mine", pick, f.ladder)
		assert_string_contains(_banners[-1], "梯子")
	assert_eq(map.query_use(null, f.ladder, GameMap.Facing.UP), &"interact")
	map.perform(&"interact", null, f.ladder)
	assert_eq(Mine.floor_no, 6)
	await wait_seconds(0.8)
	# 往上的梯子回井口
	map.perform(&"interact", null, f.entry)
	assert_eq(Mine.floor_no, 0)
	await wait_seconds(0.8)


func test_mine_art_exists() -> void:
	for icon: String in ["mine:pickaxe", "mine:stone", "mine:copper_ore", "mine:coal"]:
		var img := PixelArt.icon(icon)
		assert_eq(img.get_size(), Vector2i(16, 16), icon)
		assert_false(img.is_invisible(), icon)
	assert_ne(PixelArt.icon("mine:copper_ore").get_data(), PixelArt.icon("mine:coal").get_data(), "两种矿石看得出区别")
	assert_ne(MineArt.rock(Color(0, 0, 0, 0), 0).get_data(), MineArt.rock(Color.html("d8843c"), 0).get_data())
	var f := _gen(1, 5)
	assert_eq(MineArt.ground(f.open, MineFloor.W, MineFloor.H).get_size(), Vector2i(MineFloor.W * 16, MineFloor.H * 16))
