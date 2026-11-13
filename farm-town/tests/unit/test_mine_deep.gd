extends GutTest
## M5 第三批：水渍层、遗落层、六种新忘形、废矿车和井底老鲶。

const STEP := 1.0 / 60.0

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


func _gen(n: int, seed_value: int) -> MineFloor:
	return MineFloor.generate(n, Database.mine_layer(n), seed_value, n < Mine.OPEN_FLOORS, n % Mine.LAMP_EVERY == 0)


## 一间 w × h 的空屋子（格子从 1 开始）。
func _room(w: int, h: int) -> MineFloor:
	var f := MineFloor.new()
	for x in range(1, w + 1):
		for y in range(1, h + 1):
			f.open[Vector2i(x, y)] = true
	return f


func _monster(id: StringName, at: Vector2) -> MineMonster:
	return MineMonster.create(Database.monster(id), at, 7)


func _run(m: MineMonster, seconds: float, target: Vector2, level: MineFloor = null) -> void:
	var left := seconds
	while left > 0.0:
		m.update(STEP, target, level)
		left -= STEP


## 一直跑到它进了 state（最多 seconds 秒）。返回到没到。
func _run_until(m: MineMonster, state: MineMonster.State, seconds: float, target: Vector2, level: MineFloor = null) -> bool:
	var left := seconds
	while left > 0.0:
		if m.state == state:
			return true
		m.update(STEP, target, level)
		left -= STEP
	return m.state == state


func _c(x: int, y: int) -> Vector2:
	return GameMap.tile_center(Vector2i(x, y))


## 进到现在这一层的地图里，主角站在 at 这一格。返回 [地图, 主角]。
func _enter_map(at: Vector2i, facing: GameMap.Facing = GameMap.Facing.DOWN) -> Array:
	var scene: PackedScene = load(SceneRouter.MAPS[&"mine"])
	var m: GameMap = scene.instantiate()
	add_child_autofree(m)
	var p := Player.new()
	m.entities.add_child(p)
	p.map = m
	m.player = p
	p.place(GameMap.tile_center(at), facing)
	return [m, p]


# ---------------------------------------------------------------- 层段和楼层

func test_three_layers_cover_thirty_floors() -> void:
	assert_eq(Database.mine_layer(10).id, &"shallow")
	assert_eq(Database.mine_layer(11).id, &"waterlogged")
	assert_eq(Database.mine_layer(20).id, &"waterlogged")
	assert_eq(Database.mine_layer(21).id, &"forgotten")
	assert_eq(Database.mine_layer(30).id, &"forgotten")
	assert_true(Mine.has_boss_room(10))
	assert_true(Mine.has_boss_room(20))
	assert_true(Mine.has_boss_room(30))
	assert_false(Mine.has_boss_room(15))


func test_shallow_floors_have_no_water_or_props() -> void:
	for s in 12:
		var f := _gen(1 + s % 9, 100 + s)
		assert_true(f.water.is_empty() and f.pools.is_empty() and f.props.is_empty())


func test_waterlogged_floors_have_water_and_some_have_pools() -> void:
	var with_pool := 0
	for s in 20:
		var f := _gen(12, 300 + s)
		assert_gt(f.water.size(), 0, "种子 %d 没有水" % s)
		if not f.pools.is_empty():
			with_pool += 1
			assert_gte(f.pools.size(), 3)
	assert_gt(with_pool, 3)
	assert_lt(with_pool, 20)


func test_forgotten_floors_have_props() -> void:
	for s in 10:
		var f := _gen(24, 500 + s)
		assert_gt(f.props.size(), 0)
		for t: Vector2i in f.props:
			assert_true(MineFloor.PROP_KINDS.has(f.props[t]))


func test_pools_and_props_never_cut_the_floor_apart() -> void:
	for n: int in [12, 17, 24, 29]:
		for s in 25:
			var f := _gen(n, 700 + s * 3 + n)
			var dist := f.distances()
			assert_eq(dist.size(), f.open.size() - f.pools.size() - f.props.size(), "第 %d 层种子 %d 有走不到的地方" % [n, s])
			assert_true(dist.has(f.ladder), "梯子走得到")
			assert_false(f.solid(f.ladder))
			assert_false(f.solid(f.spawn))
			for t: Vector2i in f.rocks:
				assert_false(f.water.has(t) or f.solid(t), "石头不压在水和摆设上")
			for m in f.monsters:
				assert_true(f.walkable(GameMap.tile_of(m.pos)))


func test_pools_and_props_block_walking() -> void:
	var f := _room(5, 5)
	f.pools[Vector2i(2, 2)] = true
	f.props[Vector2i(3, 3)] = &"chair"
	f.water[Vector2i(4, 4)] = true
	assert_false(f.walkable(Vector2i(2, 2)))
	assert_false(f.walkable(Vector2i(3, 3)))
	assert_true(f.walkable(Vector2i(4, 4)), "浅水能走")
	assert_false(f.clear_line(_c(1, 2), _c(4, 2)), "隔着暗河不算直线过得去")


func test_same_seed_same_deep_floor() -> void:
	var a := _gen(13, 4242)
	var b := _gen(13, 4242)
	assert_eq(a.pools, b.pools)
	assert_eq(a.water, b.water)
	assert_eq(a.rocks, b.rocks)
	assert_eq(a.monsters.size(), b.monsters.size())


func test_new_monsters_show_up_on_their_floors() -> void:
	var seen: Dictionary[StringName, bool] = {}
	for s in 30:
		for n: int in [15, 26]:
			for m in _gen(n, 900 + s).monsters:
				seen[m.def.id] = true
	for id: StringName in [&"moss_frog", &"leech_swarm", &"leaky_umbrella", &"empty_shoes", &"walking_clock", &"faceless_paper"]:
		assert_true(seen.has(id), "%s 没出现过" % id)
	assert_false(seen.has(&"mine_cart") or seen.has(&"well_catfish"), "首领不在普通楼层出现")


# ---------------------------------------------------------------- 新忘形

func test_frog_leaps_over_rocks_and_hurts_only_on_landing() -> void:
	var f := _room(10, 3)
	f.rocks[Vector2i(4, 2)] = &"stone"
	var frog := _monster(&"moss_frog", _c(3, 2))
	var target := _c(6, 2)
	assert_true(_run_until(frog, MineMonster.State.STRIKE, 3.0, target, f), "隔着石头也起跳")
	_run(frog, frog.def.strike_time * 0.5, target, f)
	assert_gt(frog.air(), 0.2)
	assert_false(frog.strikes(frog.pos), "在半空碰不着人")
	assert_true(_run_until(frog, MineMonster.State.REST, 2.0, target, f))
	assert_gt(frog.pos.x, _c(4, 2).x + 8.0, "跳过了石头")
	assert_true(frog.events.has(&"land"))
	assert_true(frog.strikes(frog.pos + Vector2(frog.def.blast, 0)), "落地那一下周围一圈都算")
	assert_false(frog.strikes(frog.pos), "一跳只算一下")
	assert_eq(frog.air(), -1.0)


func test_frog_landing_far_away_misses() -> void:
	var frog := _monster(&"moss_frog", _c(3, 2))
	var target := _c(6, 2)
	assert_true(_run_until(frog, MineMonster.State.REST, 4.0, target))
	assert_false(frog.strikes(frog.pos + Vector2(frog.def.blast + 12.0, 0)))


func test_leeches_are_fast_only_in_water() -> void:
	var f := _room(12, 3)
	for x in range(1, 13):
		f.water[Vector2i(x, 1)] = true
	var wet := _monster(&"leech_swarm", _c(1, 1))
	var dry := _monster(&"leech_swarm", _c(1, 3))
	wet.state = MineMonster.State.CHASE
	dry.state = MineMonster.State.CHASE
	_run(wet, 1.0, _c(12, 1), f)
	_run(dry, 1.0, _c(12, 3), f)
	assert_gt(wet.pos.x - _c(1, 1).x, (dry.pos.x - _c(1, 3).x) * 2.5)


func test_umbrella_blocks_while_open_and_not_after_striking() -> void:
	var f := _room(10, 3)
	var u := _monster(&"leaky_umbrella", _c(6, 2))
	var from := _c(5, 2)
	u.state = MineMonster.State.CHASE
	u.facing = Vector2.LEFT
	assert_true(u.guarded_from(from))
	assert_true(bool(u.take_hit(5, from, 0.0)["blocked"]))
	assert_false(bool(u.take_hit(5, from, 0.0, true)["blocked"]), "锤砸得开")
	u.state = MineMonster.State.REST
	assert_false(u.guarded_from(from), "收了伞就挡不住")
	u.state = MineMonster.State.STRIKE
	assert_false(u.guarded_from(from))
	# 撑着的时候转身快：绕到背后也没用
	u.state = MineMonster.State.CHASE
	u.facing = Vector2.LEFT
	_run(u, 0.1, _c(9, 2), f)
	assert_true(u.guarded_from(_c(9, 2)))


func test_paper_figure_throws_instead_of_charging() -> void:
	var f := _room(12, 3)
	var p := _monster(&"faceless_paper", _c(2, 2))
	var target := _c(7, 2)
	assert_true(_run_until(p, MineMonster.State.STRIKE, 3.0, target, f))
	assert_eq(p.pending_shots.size(), 1)
	var shot := p.pending_shots[0]
	assert_eq(shot.kind, &"paper")
	assert_gt(shot.vel.x, 50.0)
	var before := p.pos
	_run(p, 0.1, target, f)
	assert_almost_eq(p.pos.x, before.x, 0.01, "扔东西的时候自己不冲")
	assert_false(p.strikes(p.pos))


func test_paper_figure_backs_off_when_crowded() -> void:
	var f := _room(12, 3)
	var p := _monster(&"faceless_paper", _c(6, 2))
	p.state = MineMonster.State.CHASE
	_run(p, 0.5, _c(5, 2), f)
	assert_gt(p.pos.x, _c(6, 2).x + 4.0, "人贴上来先往后退")
	assert_eq(p.state, MineMonster.State.CHASE)
	# 退不了多久，照样出手
	assert_true(_run_until(p, MineMonster.State.WINDUP, 3.0, p.pos + Vector2(-16, 0), f))


func test_shot_flies_straight_and_dies_on_obstacles() -> void:
	var f := _room(10, 3)
	f.pools[Vector2i(4, 2)] = true
	f.rocks[Vector2i(8, 2)] = &"stone"
	var s := MineShot.create(_c(2, 2), Vector2(100, 0), 7, &"paper")
	f.shots.append(s)
	for i in 30:
		f.step_shots(STEP)
	assert_true(s.alive, "暗河上面飞得过去")
	assert_almost_eq(s.pos.x, _c(2, 2).x + 50.0, 1.0)
	assert_true(s.hits(s.pos + Vector2(6, 0)))
	assert_false(s.hits(s.pos + Vector2(20, 0)))
	for i in 60:
		f.step_shots(STEP)
	assert_false(s.alive, "撞上石头就没了")
	assert_eq(f.shots.size(), 0)


func test_shot_does_not_fly_forever() -> void:
	var s := MineShot.create(Vector2.ZERO, Vector2(10, 0), 7, &"paper")
	for i in 60 * 4:
		s.update(STEP, null)
	assert_false(s.alive)


func test_shoes_come_in_pairs() -> void:
	assert_eq(Database.monster(&"empty_shoes").pack, 2)
	var paired := 0
	var total := 0
	for s in 30:
		var n := 0
		for m in _gen(22, 1200 + s).monsters:
			if m.def.id == &"empty_shoes":
				n += 1
		if n > 0:
			total += 1
			if n >= 2:
				paired += 1
	assert_gt(total, 5)
	assert_gt(paired, total * 0.8)


func test_monster_relic_drops_once() -> void:
	Mine.enter(12, 5)
	var def := Database.monster(&"moss_frog")
	assert_eq(Mine.roll_relic(def, 0.99), &"")
	assert_eq(Mine.roll_relic(def, 0.0), &"frog_weight")
	assert_eq(Mine.roll_relic(Database.monster(&"dust"), 0.0), &"", "没写遗物的不掉")
	GameState.set_flag(&"relic_frog_weight")
	assert_eq(Mine.roll_relic(def, 0.0), &"", "每件只掉一回")


func test_forgotten_layer_drops_relics_more_often() -> void:
	var def := Database.monster(&"walking_clock")
	Mine.enter(22, 5)
	var roll := def.relic_chance * 1.2
	assert_eq(Mine.roll_relic(def, roll), &"stopped_clock", "遗落层的机会更大")
	var base := Database.mine_layer(22).relic_bonus
	assert_gt(base, 1.0)
	assert_eq(Mine.roll_relic(def, def.relic_chance * base + 0.01), &"")


func test_mine_relics_are_real_items() -> void:
	for id: StringName in [&"frog_weight", &"hemp_rope", &"oil_umbrella", &"cloth_shoes", &"stopped_clock", &"paper_figure"]:
		assert_true(Database.has_relic(id))
		assert_true(Database.has_item(id))
		assert_eq(Database.relic(id).found, &"mine")
		var img := PixelArt.icon(Database.item(id).icon)
		assert_false(img.is_invisible(), "%s 的图标是空的" % id)


# ---------------------------------------------------------------- 废矿车

func test_floor_ten_is_the_cart_arena() -> void:
	assert_true(Mine.enter(10, 3))
	var f := Mine.current
	assert_eq(f.arena, &"cart")
	assert_true(f.boss_alive())
	assert_true(f.boss is MineCart)
	assert_true(f.rocks.is_empty())
	assert_eq(f.lamp, MineFloor.ARENA_LAMP, "首领房有井灯")
	assert_ne(f.ladder, MineFloor.NONE)
	assert_false(f.ladder_found, "打倒首领才有往下的路")
	assert_false(Mine.descend())
	assert_true(f.walkable(f.spawn))


func test_cart_only_takes_damage_when_stunned() -> void:
	var cart := _monster(&"mine_cart", _c(5, 3))
	assert_true(cart.is_boss())
	var res := cart.take_hit(20, _c(4, 3), 100.0, true)
	assert_true(bool(res["blocked"]), "锤也砸不动")
	assert_eq(cart.hp, cart.def.hp)
	cart.state = MineMonster.State.STUNNED
	res = cart.take_hit(20, _c(4, 3), 100.0)
	assert_false(bool(res["blocked"]))
	assert_eq(cart.hp, cart.def.hp - 20)


func test_cart_crashes_into_a_near_wall_and_is_stunned() -> void:
	var f := _room(14, 5)
	var cart := _monster(&"mine_cart", _c(5, 3))
	var target := _c(2, 3)
	assert_true(_run_until(cart, MineMonster.State.WINDUP, 1.0, target, f), "对齐了就开始抖")
	assert_true(_run_until(cart, MineMonster.State.STUNNED, 3.0, target, f), "撞上墙就晕")
	assert_true(cart.events.has(&"crash"))
	assert_lt(cart.pos.x, _c(2, 3).x + 8.0)
	assert_almost_eq(cart.pos.y, _c(5, 3).y, 0.01, "只走直线")
	_run(cart, cart.def.stun - 0.3, target, f)
	assert_eq(cart.state, MineMonster.State.STUNNED)
	_run(cart, 0.5, target, f)
	assert_ne(cart.state, MineMonster.State.STUNNED, "晕完了接着来")


func test_cart_stops_by_itself_when_the_wall_is_far() -> void:
	var f := _room(14, 5)
	var cart := _monster(&"mine_cart", _c(13, 3))
	var target := _c(2, 3)
	assert_true(_run_until(cart, MineMonster.State.REST, 4.0, target, f))
	assert_false(cart.events.has(&"crash"))
	assert_almost_eq(_c(13, 3).x - cart.pos.x, cart.def.charge_len, 6.0)


func test_cart_lines_up_before_charging() -> void:
	var f := _room(14, 7)
	var cart := _monster(&"mine_cart", _c(10, 2))
	var target := _c(3, 5)
	_run(cart, 0.3, target, f)
	assert_eq(cart.state, MineMonster.State.CHASE)
	assert_gt(cart.pos.y, _c(10, 2).y, "先挪到和人一排")
	assert_almost_eq(cart.pos.x, _c(10, 2).x, 0.01)
	assert_true(_run_until(cart, MineMonster.State.STRIKE, 4.0, target, f))
	assert_almost_eq(cart.pos.y, target.y, MineCart.ALIGN + 0.5)


func test_cart_hits_the_player_in_its_path() -> void:
	var f := _room(14, 5)
	var cart := _monster(&"mine_cart", _c(8, 3))
	var target := _c(5, 3)
	assert_true(_run_until(cart, MineMonster.State.STRIKE, 2.0, target, f))
	var hit := false
	for i in 60:
		cart.update(STEP, target, f)
		if cart.strikes(target):
			hit = true
			break
	assert_true(hit)


func test_beating_the_cart_opens_the_way_and_gives_the_hammer() -> void:
	Mine.enter(10, 3)
	var boss := Mine.current.boss
	boss.state = MineMonster.State.STUNNED
	assert_true(bool(boss.take_hit(999, Vector2.ZERO, 0.0)["dead"]))
	var got := Mine.defeat(boss)
	assert_true(got.has(&"rail_hammer"))
	assert_eq(GameState.inventory.count_of(&"rail_hammer"), 1)
	assert_true(Mine.bosses.has(10))
	assert_true(GameState.has_flag(&"boss_cart"))
	assert_true(Mine.current.ladder_found)
	assert_false(Mine.haul.has(&"rail_hammer"), "武器不算这一趟的收获，晕倒不丢")
	assert_true(Mine.descend())
	assert_eq(Mine.floor_no, 11)
	# 再来：屋子空着，梯子露着
	Mine.enter(10, 4)
	assert_false(Mine.current.boss_alive())
	assert_eq(Mine.current.monsters_left(), 0)
	assert_true(Mine.current.ladder_found)


func test_beaten_bosses_are_saved() -> void:
	Mine.bosses.append(10)
	Mine.owed.append(&"rail_hammer")
	var data := Mine.save_data()
	Mine.reset_data()
	assert_true(Mine.bosses.is_empty())
	Mine.load_data(data)
	assert_eq(Mine.bosses, [10] as Array[int])
	assert_eq(Mine.owed, [&"rail_hammer"] as Array[StringName])
	Mine.load_data({"bosses": [7, 10, "x"], "owed": ["no_such_item"]})
	assert_eq(Mine.bosses, [10] as Array[int], "不是首领房的层不认")
	assert_true(Mine.owed.is_empty())


func test_boss_drop_waits_when_the_bag_is_full() -> void:
	for id: StringName in Database.items:
		if not GameState.inventory.can_add(&"rail_hammer", 1):
			break
		if id != &"rail_hammer" and id != &"copper_ore" and id != &"coal":
			GameState.inventory.add(id, 1)
	assert_false(GameState.inventory.can_add(&"rail_hammer", 1), "背包得是满的")
	Mine.enter(10, 3)
	var boss := Mine.current.boss
	boss.state = MineMonster.State.STUNNED
	boss.take_hit(999, Vector2.ZERO, 0.0)
	var got := Mine.defeat(boss)
	assert_false(got.has(&"rail_hammer"))
	assert_true(Mine.owed.has(&"rail_hammer"), "放不下先欠着")
	assert_true(Mine.collect_owed().is_empty(), "还是放不下")
	GameState.inventory.clear()
	assert_true(Mine.collect_owed().has(&"rail_hammer"))
	assert_eq(GameState.inventory.count_of(&"rail_hammer"), 1)
	assert_true(Mine.owed.is_empty())


func test_boss_weapons_are_not_sold() -> void:
	GameState.set_flag(&"got_pickaxe")
	for e in Shop.entries(&"spring", Shop.SMITH):
		assert_false(e.item_id == &"rail_hammer" or e.item_id == &"fishbone_sickle")
	assert_gt(Database.weapon(&"rail_hammer").damage, Database.weapon(&"stone_hammer").damage)
	assert_gt(Database.weapon(&"fishbone_sickle").damage, Database.weapon(&"old_sickle").damage)


# ---------------------------------------------------------------- 井底老鲶

func test_floor_twenty_is_the_catfish_arena() -> void:
	assert_true(Mine.enter(20, 3))
	var f := Mine.current
	assert_eq(f.arena, &"catfish")
	assert_true(f.boss is MineCatfish)
	assert_eq(f.pools.size(), MineFloor.ARENA_POOL.size.x * MineFloor.ARENA_POOL.size.y)
	assert_true(f.pools.has(GameMap.tile_of(f.boss.pos)), "老鲶在水池里")
	assert_eq(f.distances().size(), f.open.size() - f.pools.size(), "水池四周都走得到")


func test_catfish_stays_in_the_pool_and_spits() -> void:
	Mine.enter(20, 3)
	var f := Mine.current
	var fish := f.boss as MineCatfish
	var target := _c(5, 8)
	var shots := 0
	for i in 60 * 12:
		fish.update(STEP, target, f)
		shots += fish.pending_shots.size()
		fish.pending_shots.clear()
		assert_true(f.pools.has(GameMap.tile_of(fish.pos)))
	assert_gte(shots, 9, "十二秒里至少吐三回，一回三颗")
	assert_eq(shots % 3, 0)
	assert_false(fish.strikes(fish.pos), "它自己不撞人")


func test_catfish_spits_five_when_hurt() -> void:
	Mine.enter(20, 3)
	var fish := Mine.current.boss as MineCatfish
	fish.hp = fish.def.hp / 2
	assert_true(_run_until(fish, MineMonster.State.STRIKE, 6.0, _c(5, 8), Mine.current))
	assert_eq(fish.pending_shots.size(), 5)
	assert_eq(fish.pending_shots[0].kind, &"water")
	assert_true(fish.events.has(&"spit"))


func test_catfish_cannot_be_hit_in_the_water() -> void:
	Mine.enter(20, 3)
	var fish := Mine.current.boss as MineCatfish
	assert_true(bool(fish.take_hit(50, Vector2.ZERO, 0.0, true)["blocked"]))
	assert_eq(fish.hp, fish.def.hp)
	assert_true(fish.in_water())


func test_catfish_comes_to_the_bait_then_can_be_landed() -> void:
	Mine.enter(20, 3)
	var f := Mine.current
	var fish := f.boss as MineCatfish
	var target := _c(7, 7)
	var bait := _c(9, 7)
	fish.cast_line(bait)
	_run(fish, 1.0, target, f)
	assert_false(fish.at_bait(), "刚下来它还戒备着，不咬钩")
	var left := 8.0
	while left > 0.0 and not fish.at_bait():
		fish.update(STEP, target, f)
		left -= STEP
	assert_true(fish.at_bait(), "戒备过了就游到浮漂底下")
	fish.pending_shots.clear()
	_run(fish, 3.0, target, f)
	assert_true(fish.pending_shots.is_empty(), "咬着钩的时候不吐水")
	fish.land(_c(7, 8))
	assert_eq(fish.state, MineMonster.State.STUNNED)
	assert_true(fish.events.has(&"ashore"))
	assert_false(fish.in_water())
	assert_false(bool(fish.take_hit(30, target, 0.0)["blocked"]))
	assert_eq(fish.hp, fish.def.hp - 30)
	assert_eq(fish.pos, _c(7, 8), "挨打不被推开")
	_run(fish, fish.def.stun + 0.1, target, f)
	assert_true(fish.events.has(&"dive"))
	assert_lt(fish.pos.distance_to(fish.home), 8.0, "晕完跳回水里")
	assert_true(fish.in_water())
	assert_gt(fish.wary(), 3.0)
	fish.cast_line(bait)
	_run(fish, 2.0, target, f)
	assert_false(fish.at_bait(), "刚回水里不上当")


func test_catfish_gets_wary_after_slipping_the_hook() -> void:
	Mine.enter(20, 3)
	var f := Mine.current
	var fish := f.boss as MineCatfish
	fish.cast_line(_c(9, 7))
	var left := 8.0
	while left > 0.0 and not fish.at_bait():
		fish.update(STEP, _c(7, 7), f)
		left -= STEP
	fish.line_gone()
	assert_gt(fish.wary(), 1.0)
	_run(fish, 0.1, _c(7, 7), f)
	assert_ne(fish.state, MineMonster.State.CHASE)


func test_no_ordinary_fish_bites_in_the_boss_pool() -> void:
	assert_null(Fishing.pick(&"mine_boss", 0.5))
	assert_eq(Fishing.pick(&"mine_shallow", 0.5).id, &"blind_fish")


# ---------------------------------------------------------------- 地图

func test_wading_and_clock_aura_slow_the_player() -> void:
	Mine.enter(3, 21)
	var f := Mine.current
	f.monsters.clear()
	var wet := f.spawn
	f.water[wet] = true
	var res := _enter_map(wet)
	var m: GameMap = res[0]
	var p: Player = res[1]
	assert_almost_eq(float(m.call(&"slow_at", p.position)), 0.7, 0.001)
	f.water.erase(wet)
	assert_almost_eq(float(m.call(&"slow_at", p.position)), 1.0, 0.001)
	var clock := _monster(&"walking_clock", p.position + Vector2(30, 0))
	f.monsters.append(clock)
	assert_almost_eq(float(m.call(&"slow_at", p.position)), 0.6, 0.001)
	assert_almost_eq(float(m.call(&"slow_at", p.position + Vector2(-40, 0))), 1.0, 0.001)
	m.call(&"tick", STEP)
	assert_almost_eq(p.slow, 0.6, 0.001)
	p.place(p.position, GameMap.Facing.DOWN)
	assert_eq(p.slow, 1.0, "换地方就不慢了")


func test_shots_hurt_the_player_and_rolling_dodges() -> void:
	Mine.enter(3, 21)
	var f := Mine.current
	f.monsters.clear()
	f.rocks.clear()
	var res := _enter_map(f.spawn)
	var m: GameMap = res[0]
	var p: Player = res[1]
	f.shots.append(MineShot.create(p.position + Vector2(0, 2), Vector2.ZERO, 9, &"paper"))
	m.call(&"tick", STEP)
	assert_eq(GameState.health, GameState.max_health - 9)
	assert_false(f.shots[0].alive)
	m.call(&"tick", STEP)
	assert_eq(int(m.call(&"shot_count")), 0)
	# 刚挨过打的那一小会儿不再挨
	f.shots.append(MineShot.create(p.position + Vector2(0, 2), Vector2.ZERO, 9, &"water"))
	m.call(&"tick", STEP)
	assert_eq(GameState.health, GameState.max_health - 9)
	assert_eq(int(m.call(&"shot_count")), 1, "飞着的画出来了")


func test_rod_casts_into_underground_pools() -> void:
	Mine.enter(12, 5)
	var f := Mine.current
	f.monsters.clear()
	var at := f.spawn + Vector2i(0, 1)
	f.rocks.erase(at)
	f.pools[at] = true
	var res := _enter_map(f.spawn)
	var m: GameMap = res[0]
	assert_eq(m.fishing_water(at), &"mine_shallow")
	assert_eq(m.fishing_water(f.spawn), &"")
	assert_eq(m.query_use(Database.item(&"rod"), at, GameMap.Facing.DOWN), &"cast")
	assert_ne(m.query_use(Database.item(&"pickaxe"), at, GameMap.Facing.DOWN), &"cast")
	assert_true(m.blocked(GameMap.tile_center(at)), "暗河过不去")
	assert_null(m.fishing_bite(GameMap.tile_center(at)), "普通楼层咬钩的照这片水平常的来")
	assert_false(m.fish_landed(Database.fish_def(&"blind_fish")))


func test_landing_the_catfish_through_the_map() -> void:
	Mine.enter(20, 3)
	var f := Mine.current
	var fish := f.boss as MineCatfish
	var res := _enter_map(Vector2i(7, 7), GameMap.Facing.RIGHT)
	var m: GameMap = res[0]
	var p: Player = res[1]
	assert_true(bool(m.call(&"boss_bar_shown")))
	assert_eq(int(m.call(&"boss_bar_width")), 120)
	assert_eq(m.fishing_water(Vector2i(8, 7)), &"mine_boss")
	assert_eq(m.query_use(Database.item(&"rod"), Vector2i(8, 7), GameMap.Facing.RIGHT), &"cast")
	# 水里的它武器够不着
	fish.pos = _c(8, 7)
	assert_eq(int(m.call(&"weapon_hit", Database.weapon(&"old_sickle"), 0, false)), 0)
	var bait := _c(9, 7)
	m.fishing_started(bait)
	assert_true(fish.lured)
	assert_null(m.fishing_bite(bait), "还没游过来")
	var left := 8.0
	while left > 0.0 and not fish.at_bait():
		m.call(&"tick", STEP)
		left -= STEP
	var bite := m.fishing_bite(bait)
	assert_not_null(bite)
	assert_eq(bite.id, &"old_well_catfish")
	# 最普通的竿、最笨的遛法（线不紧就收）也遛得上来
	var fight := FishFight.new(bite, 0, 11)
	for i in 60 * 60:
		if fight.is_over():
			break
		fight.step(STEP, not fight.struggling and not fight.warning and fight.tension < 0.6)
	assert_eq(fight.result, FishFight.Result.CAUGHT)
	assert_lt(fight.elapsed, 25.0)
	assert_true(m.fish_landed(bite), "这条鱼不进背包")
	m.fishing_ended()
	assert_eq(GameState.inventory.count_of(&"old_well_catfish"), 0)
	assert_eq(fish.state, MineMonster.State.STUNNED)
	assert_true(f.walkable(GameMap.tile_of(fish.pos)), "摔在岸上")
	assert_lt(fish.pos.distance_to(p.position), 26.0, "就在人身边")
	m.call(&"tick", STEP)
	assert_string_contains(_banners[-1], "拉上来了")
	# 上了岸就打得着
	p.facing = GameMap.Facing.DOWN if fish.pos.y > p.position.y + 4.0 else (GameMap.Facing.UP if fish.pos.y < p.position.y - 4.0 else GameMap.Facing.RIGHT)
	fish.hp = 1
	assert_eq(int(m.call(&"weapon_hit", Database.weapon(&"old_sickle"), 0, false)), 1)
	assert_false(f.boss_alive())
	assert_false(bool(m.call(&"boss_bar_shown")))
	assert_true(Mine.bosses.has(20))
	assert_true(GameState.has_flag(&"boss_catfish"))
	assert_eq(GameState.inventory.count_of(&"fishbone_sickle"), 1)
	assert_string_contains(_banners[-1], "鱼骨镰")
	assert_string_contains(_banners[-1], "梯子")
	assert_eq(m.fishing_water(Vector2i(8, 7)), &"mine_deep", "打倒以后水池里是深处的鱼")
	assert_false(m.fish_landed(bite), "往后再钓上来就是一条普通的鱼")


func test_spare_rod_by_the_pool_when_the_player_has_none() -> void:
	Mine.enter(20, 3)
	var res := _enter_map(Vector2i(7, 7), GameMap.Facing.RIGHT)
	var m: GameMap = res[0]
	var pool := Vector2i(8, 7)
	assert_true(bool(m.call(&"spare_rod")), "没有鱼竿：岸边有一根旧的")
	assert_eq(m.query_use(null, pool, GameMap.Facing.RIGHT), &"cast", "空着手对着水池就是甩竿")
	assert_eq(m.query_use(Database.item(&"pickaxe"), pool, GameMap.Facing.RIGHT), &"cast")
	assert_eq(m.query_use(Database.item(&"old_sickle"), pool, GameMap.Facing.RIGHT), &"attack", "拿着武器还是挥")
	assert_ne(m.query_use(null, Vector2i(6, 7), GameMap.Facing.LEFT), &"cast", "不对着水不算")
	m.entered()
	assert_string_contains(_banners[-1], "旧鱼竿")
	GameState.inventory.add(&"rod", 1)
	assert_false(bool(m.call(&"spare_rod")), "自己有竿就用自己的")
	assert_ne(m.query_use(null, pool, GameMap.Facing.RIGHT), &"cast")
	assert_eq(m.query_use(Database.item(&"rod"), pool, GameMap.Facing.RIGHT), &"cast")
	GameState.inventory.clear()
	Mine.current.boss.state = MineMonster.State.DEAD
	assert_false(bool(m.call(&"spare_rod")), "老鲶倒了旧竿就没用了")
	# 普通楼层的暗河没有旧竿
	Mine.enter(12, 5)
	Mine.current.pools[Mine.current.spawn + Vector2i(0, 1)] = true
	Mine.current.rocks.erase(Mine.current.spawn + Vector2i(0, 1))
	m = _enter_map(Mine.current.spawn)[0]
	assert_ne(m.query_use(null, Mine.current.spawn + Vector2i(0, 1), GameMap.Facing.DOWN), &"cast")


func test_boss_weapons_have_their_own_icons_and_new_sounds_exist() -> void:
	var hammer := PixelArt.icon(Database.item(&"rail_hammer").icon)
	var sickle := PixelArt.icon(Database.item(&"fishbone_sickle").icon)
	assert_ne(hammer.get_data(), PixelArt.icon(Database.item(&"stone_hammer").icon).get_data())
	assert_ne(sickle.get_data(), PixelArt.icon(Database.item(&"old_sickle").icon).get_data())
	assert_false(hammer.is_invisible() or sickle.is_invisible())
	assert_eq(Database.item(&"stone_hammer").icon, "weapon:hammer", "没单独画的还用这一类通用的")
	assert_false(MineDeepArt.spare_rod().is_invisible())
	for n: String in ["thump", "crash", "spit", "plunge"]:
		assert_true(Audio.has_sound(n), "没有 %s 这个声音" % n)


func test_arena_banner_hints_at_the_boss() -> void:
	Mine.enter(10, 3)
	var m: GameMap = _enter_map(Mine.current.spawn)[0]
	m.entered()
	assert_string_contains(_banners[-1], "矿车")
	Mine.bosses.append(20)
	Mine.owed.append(&"fishbone_sickle")
	Mine.enter(20, 3)
	m = _enter_map(Mine.current.spawn)[0]
	m.entered()
	assert_false(_banners[-1].contains("影子"), "打倒过了不再提")
	assert_string_contains(_banners[-1], "鱼骨镰")
	assert_eq(GameState.inventory.count_of(&"fishbone_sickle"), 1, "欠着的进井就补上")


func test_cart_crash_is_announced_and_blocked_hits_explain() -> void:
	Mine.enter(10, 3)
	var f := Mine.current
	var res := _enter_map(Vector2i(13, 8), GameMap.Facing.RIGHT)
	var m: GameMap = res[0]
	var p: Player = res[1]
	var cart := f.boss
	cart.pos = p.position + Vector2(14, 0)
	assert_eq(int(m.call(&"weapon_hit", Database.weapon(&"old_sickle"), 0, false)), 1)
	assert_eq(cart.hp, cart.def.hp)
	assert_string_contains(_banners[-1], "铁皮")
	cart.events.append(&"crash")
	m.call(&"tick", STEP)
	assert_string_contains(_banners[-1], "撞晕")
	assert_true(cart.events.is_empty())


func test_monster_view_poses_for_new_monsters() -> void:
	var u := _monster(&"leaky_umbrella", Vector2(40, 40))
	var view := MonsterView.new()
	add_child_autofree(view)
	view.setup(u)
	u.state = MineMonster.State.REST
	assert_eq(view.pose(), &"stun", "歇着的伞是收起来的")
	var cart := _monster(&"mine_cart", Vector2(40, 40))
	var big := MonsterView.new()
	add_child_autofree(big)
	big.setup(cart)
	cart.hp -= 10
	assert_false(big.bar_shown(), "首领的血条在屏幕顶上")


func test_deep_art_is_drawn() -> void:
	for kind in MineFloor.PROP_KINDS:
		var img := MineDeepArt.prop(kind)
		assert_eq(img.get_width(), 16)
		assert_false(img.is_invisible())
	assert_false(MineDeepArt.shot(&"paper").is_invisible())
	assert_ne(MineDeepArt.shot(&"paper").get_data(), MineDeepArt.shot(&"water").get_data())
	var open: Dictionary[Vector2i, bool] = {Vector2i(1, 2): true, Vector2i(2, 2): true}
	var a := MineArt.ground(open, 4, 4)
	var b := MineArt.ground(open, 4, 4, &"waterlogged")
	var c := MineArt.ground(open, 4, 4, &"waterlogged", {Vector2i(1, 2): true}, {Vector2i(2, 2): true})
	assert_ne(a.get_data(), b.get_data(), "每一段的颜色不一样")
	assert_ne(b.get_data(), c.get_data(), "水画出来了")
	for id: StringName in MineDeepArt.IDS:
		assert_ne(MineArt.monster(id, &"idle_a").get_data(), MineArt.monster(id, &"strike").get_data())
