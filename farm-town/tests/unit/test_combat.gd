extends GutTest
## M5 第二批：生命值、武器和连段、翻滚、浅坑的三种忘形、晕倒。

var _banners: Array[String] = []
var _knockouts := 0


func before_each() -> void:
	SaveSystem.reset_all()
	Weather.today = &"sunny"
	GameClock.minutes = 600.0
	GameClock.day = 1
	_banners.clear()
	_knockouts = 0
	EventBus.banner_requested.connect(_on_banner)
	GameState.knocked_out.connect(_on_knocked_out)


func after_each() -> void:
	EventBus.banner_requested.disconnect(_on_banner)
	GameState.knocked_out.disconnect(_on_knocked_out)
	SaveSystem.reset_all()
	GameClock.running = false


func _on_banner(text: String) -> void:
	_banners.append(text)


func _on_knocked_out() -> void:
	_knockouts += 1


func _map(id: StringName) -> GameMap:
	var scene: PackedScene = load(SceneRouter.MAPS[id])
	var m: GameMap = scene.instantiate()
	add_child_autofree(m)
	return m


func _gen(n: int, seed_value: int, extra: int = 0) -> MineFloor:
	return MineFloor.generate(n, Database.mine_layer(n), seed_value, n < Mine.OPEN_FLOORS, n % Mine.LAMP_EVERY == 0, extra)


## 一条横着的走廊：y = 3，x 从 1 到 len。
func _corridor(length: int) -> MineFloor:
	var f := MineFloor.new()
	for x in range(1, length + 1):
		f.open[Vector2i(x, 3)] = true
	return f


func _monster(id: StringName, at: Vector2) -> MineMonster:
	return MineMonster.create(Database.monster(id), at, 7)


## 下到第 n 层，把这一层的石头和忘形清掉，换上 monsters；返回 [地图, 主角]。
func _arena(monsters: Array[MineMonster]) -> Array:
	Mine.enter(3, 21)
	Mine.current.rocks.clear()
	Mine.current.hp.clear()
	Mine.current.monsters.clear()
	Mine.current.monsters.append_array(monsters)
	var m := _map(&"mine")
	var p := Player.new()
	m.entities.add_child(p)
	p.map = m
	m.player = p
	p.place(m.spawn_position(&"ladder"), GameMap.Facing.DOWN)
	return [m, p]


func _run(m: MineMonster, seconds: float, target: Vector2, level: MineFloor = null) -> void:
	var left := seconds
	while left > 0.0:
		m.update(0.02, target, level)
		left -= 0.02


# ---------------------------------------------------------------- 数据表

func test_weapon_and_monster_tables_are_valid() -> void:
	assert_eq(Database.validate().size(), 0, "\n".join(Database.validate()))
	for id: StringName in [&"old_sickle", &"short_sword", &"stone_hammer"]:
		assert_not_null(Database.weapon(id), String(id))
		assert_eq(Database.item(id).kind, &"weapon")
		assert_eq(Database.item(id).stack, 1)
		assert_false(Database.item(id).sellable(), "武器不能扔进出货箱")
	assert_null(Database.weapon(&"hoe"), "锄头不是武器")
	for id: StringName in [&"dust", &"stone_crab", &"bat"]:
		assert_true(Database.monsters.has(id), String(id))
	assert_true(Database.monster(&"stone_crab").guard)
	assert_true(Database.monster(&"stone_crab").hidden)
	assert_true(Database.monster(&"bat").flying)


func test_deeper_floors_hold_more_monsters() -> void:
	var layer := Database.mine_layer(1)
	assert_eq(layer.monster_count(1, 0.0), 1)
	assert_lte(layer.monster_count(1, 0.99), 2)
	assert_gte(layer.monster_count(10, 0.0), 3)
	assert_eq(layer.monster_count(10, 0.99), 4)


func test_first_floor_only_has_dust() -> void:
	var layer := Database.mine_layer(1)
	for i in 20:
		assert_eq(layer.pick_monster(1, i / 20.0), &"dust")
	var seen: Dictionary = {}
	for i in 100:
		seen[layer.pick_monster(5, i / 100.0)] = true
	assert_eq(seen.size(), 3, "第 5 层三种都有")


# ---------------------------------------------------------------- 楼层里的忘形

func test_monsters_start_away_from_the_ladder() -> void:
	for seed_value in [3, 14, 159, 2653]:
		var level := _gen(6, seed_value)
		assert_gt(level.monsters.size(), 0, "种子 %d" % seed_value)
		var dist := level.distances()
		var tiles: Dictionary = {}
		for m in level.monsters:
			var t := GameMap.tile_of(m.pos)
			assert_true(level.walkable(t), "忘形站在空地上")
			assert_gte(int(dist[t]), MineFloor.MONSTER_KEEP_OFF, "离下来的地方够远")
			assert_false(tiles.has(t), "一格最多一只")
			tiles[t] = true
		assert_eq(level.monsters_left(), level.monsters.size())


func test_same_seed_gives_same_monsters() -> void:
	var a := _gen(7, 4242)
	var b := _gen(7, 4242)
	assert_eq(a.monsters.size(), b.monsters.size())
	for i in a.monsters.size():
		assert_eq(a.monsters[i].def.id, b.monsters[i].def.id)
		assert_eq(a.monsters[i].pos, b.monsters[i].pos)


func test_extra_monsters_are_added() -> void:
	assert_eq(_gen(4, 99, 1).monsters.size(), _gen(4, 99).monsters.size() + 1)


func test_jingzhe_adds_a_monster_per_floor() -> void:
	Mine.enter(4, 99)
	var usual := Mine.current.monsters.size()
	Mine.leave()
	# 惊蛰是一年里第三个节气：第 9 到 12 天
	GameClock.day = 9
	assert_eq(GameClock.term_id(), &"jingzhe")
	Mine.enter(4, 99)
	assert_eq(Mine.current.monsters.size(), usual + 1)


# ---------------------------------------------------------------- 武器

func test_combo_damage_follows_the_style() -> void:
	var sickle := Database.weapon(&"old_sickle")
	assert_eq(sickle.combo_len(), 3)
	assert_eq(sickle.damage_at(0), 6)
	assert_eq(sickle.damage_at(2), 10, "最后一下重")
	var sword := Database.weapon(&"short_sword")
	assert_eq(sword.combo_len(), 4)
	var hammer := Database.weapon(&"stone_hammer")
	assert_eq(hammer.combo_len(), 2)
	assert_eq(hammer.damage_at(1), 16)
	assert_true(hammer.breaks_guard())
	assert_false(sickle.breaks_guard())
	assert_eq(sickle.skill_damage(), 12)


func test_swing_reaches_what_is_in_front() -> void:
	var sickle := Database.weapon(&"old_sickle")
	var at := Vector2(100, 100)
	assert_true(sickle.hits(at, Vector2.RIGHT, at + Vector2(20, 0)))
	assert_true(sickle.hits(at, Vector2.RIGHT, at + Vector2(14, 14)), "镰刀扫得宽")
	assert_false(sickle.hits(at, Vector2.RIGHT, at + Vector2(-20, 0)), "背后打不到")
	assert_false(sickle.hits(at, Vector2.RIGHT, at + Vector2(40, 0)), "太远")
	assert_true(sickle.hits(at, Vector2.RIGHT, at + Vector2(33, 0), 6.0), "身子大的够得着边")
	assert_true(sickle.hits(at, Vector2.RIGHT, at + Vector2(-3, 0), 6.0), "贴在身上的不管朝向")
	var sword := Database.weapon(&"short_sword")
	assert_true(sword.hits(at, Vector2.DOWN, at + Vector2(0, 20)))
	assert_false(sword.hits(at, Vector2.DOWN, at + Vector2(14, 14)), "短剑刺得窄")


func test_skills_have_their_own_shapes() -> void:
	var at := Vector2(100, 100)
	var sickle := Database.weapon(&"old_sickle")
	assert_true(sickle.skill_hits(at, at, at + Vector2(-25, 0)), "转一圈，背后也打到")
	assert_false(sickle.skill_hits(at, at, at + Vector2(-45, 0)))
	var sword := Database.weapon(&"short_sword")
	var end := at + Vector2(56, 0)
	assert_true(sword.skill_hits(at, end, at + Vector2(40, 5)), "突进一路上的都打到")
	assert_false(sword.skill_hits(at, end, at + Vector2(40, 30)))
	assert_false(sword.skill_hits(at, end, at + Vector2(-25, 0)), "突进打不到背后")
	var hammer := Database.weapon(&"stone_hammer")
	assert_true(hammer.skill_hits(at, at, at + Vector2(0, -38)), "砸地震开周围")


func test_combo_counts_up_and_wraps() -> void:
	var c := Combo.new()
	assert_eq(c.advance(3), 0)
	c.tick(0.3)
	assert_eq(c.advance(3), 1)
	c.tick(0.3)
	assert_eq(c.advance(3), 2)
	c.tick(0.3)
	assert_eq(c.advance(3), 0, "打完最后一下从头来")


func test_combo_resets_after_a_pause() -> void:
	var c := Combo.new()
	c.advance(3)
	c.tick(0.2)
	assert_eq(c.advance(3), 1)
	c.tick(Combo.WINDOW + 0.1)
	assert_eq(c.advance(3), 0, "隔久了从头来")
	c.advance(3)
	c.reset()
	assert_eq(c.advance(3), 0)


# ---------------------------------------------------------------- 忘形怎么动

func test_dust_rolls_toward_the_player() -> void:
	var m := _monster(&"dust", Vector2(100, 100))
	var target := Vector2(160, 100)
	assert_eq(m.state, MineMonster.State.ROAM)
	_run(m, 1.0, target)
	assert_eq(m.state, MineMonster.State.CHASE)
	assert_gt(m.pos.x, 110.0, "朝人挪过来了")
	assert_almost_eq(m.pos.y, 100.0, 0.5)


func test_monster_ignores_a_far_player() -> void:
	var m := _monster(&"dust", Vector2(100, 100))
	_run(m, 2.0, Vector2(400, 100))
	assert_eq(m.state, MineMonster.State.ROAM)
	assert_lt(m.pos.distance_to(Vector2(100, 100)), 40.0, "只在原地附近转")


func test_attack_has_a_windup_then_a_lunge_then_a_rest() -> void:
	var def := Database.monster(&"dust")
	var m := _monster(&"dust", Vector2(100, 100))
	var target := Vector2(118, 100)
	m.update(0.02, target, null)
	m.update(0.02, target, null)
	assert_eq(m.state, MineMonster.State.WINDUP, "够得着就先抬手")
	var before := m.pos
	_run(m, def.windup - 0.1, target)
	assert_eq(m.state, MineMonster.State.WINDUP)
	assert_eq(m.pos, before, "前摇的时候不动")
	assert_false(m.strikes(target), "前摇不伤人")
	_run(m, 0.14, target)
	assert_eq(m.state, MineMonster.State.STRIKE)
	_run(m, 0.1, target)
	assert_gt(m.pos.x, before.x + 4.0, "冲出去了")
	assert_true(m.strikes(m.pos), "撞上了")
	assert_false(m.strikes(m.pos), "一次出招只算一下")
	_run(m, def.strike_time, target)
	assert_eq(m.state, MineMonster.State.REST)
	_run(m, def.rest + 0.05, target)
	assert_true(m.state == MineMonster.State.CHASE or m.state == MineMonster.State.WINDUP, "歇够了接着来")


func test_lunge_keeps_the_direction_it_started_with() -> void:
	var m := _monster(&"bat", Vector2(100, 100))
	m.update(0.02, Vector2(150, 100), null)
	m.update(0.02, Vector2(150, 100), null)
	assert_eq(m.state, MineMonster.State.WINDUP)
	# 前摇的时候人躲到了上面：它还是照原来的方向冲
	_run(m, Database.monster(&"bat").windup + 0.3, Vector2(100, 40))
	assert_eq(m.state, MineMonster.State.STRIKE)
	assert_gt(m.pos.x, 120.0)
	assert_almost_eq(m.pos.y, 100.0, 0.5)


func test_crab_looks_like_a_rock_until_you_come_close() -> void:
	var m := _monster(&"stone_crab", Vector2(100, 100))
	assert_eq(m.state, MineMonster.State.HIDDEN)
	_run(m, 2.0, Vector2(160, 100))
	assert_eq(m.state, MineMonster.State.HIDDEN, "离得远不动")
	assert_eq(m.pos, Vector2(100, 100))
	_run(m, 0.1, Vector2(130, 100))
	assert_eq(m.state, MineMonster.State.WAKING)
	_run(m, MineMonster.WAKE_TIME + 0.05, Vector2(130, 100))
	assert_eq(m.state, MineMonster.State.CHASE)


func test_crab_shell_blocks_hits_from_the_front() -> void:
	var m := _monster(&"stone_crab", Vector2(100, 100))
	m.state = MineMonster.State.REST
	m.facing = Vector2.RIGHT
	var front := m.take_hit(6, Vector2(120, 100), 50.0)
	assert_true(bool(front["blocked"]))
	assert_eq(m.hp, Database.monster(&"stone_crab").hp, "正面砍不动")
	var back := m.take_hit(6, Vector2(80, 100), 50.0)
	assert_false(bool(back["blocked"]))
	assert_eq(m.hp, Database.monster(&"stone_crab").hp - 6, "背后砍得动")


func test_hammer_breaks_the_guard_and_stuns() -> void:
	var m := _monster(&"stone_crab", Vector2(100, 100))
	m.state = MineMonster.State.WINDUP
	m.facing = Vector2.RIGHT
	var res := m.take_hit(9, Vector2(120, 100), 90.0, true)
	assert_false(bool(res["blocked"]))
	assert_eq(m.hp, Database.monster(&"stone_crab").hp - 9)
	assert_eq(m.state, MineMonster.State.STUNNED, "抬到一半的手被打断了")
	assert_false(m.guarded_from(Vector2(120, 100)), "晕着的时候正面也砍得动")
	_run(m, MineMonster.STUN_TIME + 0.4, Vector2(300, 100))
	assert_ne(m.state, MineMonster.State.STUNNED)


func test_hitting_a_hidden_crab_wakes_it() -> void:
	var m := _monster(&"stone_crab", Vector2(100, 100))
	var res := m.take_hit(6, Vector2(100, 150), 50.0)
	assert_true(bool(res["blocked"]), "缩在壳里砍不动")
	assert_eq(m.state, MineMonster.State.WAKING)


func test_hit_knocks_back_and_kills_at_zero() -> void:
	var m := _monster(&"dust", Vector2(100, 100))
	var res := m.take_hit(6, Vector2(80, 100), 60.0)
	assert_eq(int(res["damage"]), 6)
	assert_false(bool(res["dead"]))
	m.update(0.05, Vector2(80, 100), null)
	assert_gt(m.pos.x, 100.5, "被推开了")
	m.take_hit(6, Vector2(80, 100), 60.0)
	res = m.take_hit(6, Vector2(80, 100), 60.0)
	assert_true(bool(res["dead"]))
	assert_false(m.alive())
	var where := m.pos
	m.update(0.5, Vector2(80, 100), null)
	assert_eq(m.pos, where, "倒了就不动了")


func test_rocks_stop_dust_but_not_bats() -> void:
	var level := _corridor(10)
	level.rocks[Vector2i(5, 3)] = &"stone"
	var start := GameMap.tile_center(Vector2i(3, 3))
	var target := GameMap.tile_center(Vector2i(8, 3))
	var dust := _monster(&"dust", start)
	_run(dust, 6.0, target, level)
	assert_lt(dust.pos.x, 5.0 * 16.0, "尘团被石头挡住")
	var bat := _monster(&"bat", start)
	bat.state = MineMonster.State.CHASE
	_run(bat, 0.5, target + Vector2(60, 0), level)
	_run(bat, 3.0, target, level)
	assert_gt(bat.pos.x, 5.0 * 16.0, "蝙蝠从石头上面飞过去")


func test_walls_stop_everything() -> void:
	var level := _corridor(6)
	var bat := _monster(&"bat", GameMap.tile_center(Vector2i(5, 3)))
	_run(bat, 5.0, GameMap.tile_center(Vector2i(12, 3)), level)
	assert_lt(bat.pos.x, 7.0 * 16.0, "岩壁谁也过不去")


# ---------------------------------------------------------------- 掉落、这一趟的收获、晕倒

func test_defeated_crab_drops_stone_into_the_bag() -> void:
	Mine.enter(2, 5)
	var m := _monster(&"stone_crab", Vector2(100, 100))
	var got := Mine.defeat(m)
	assert_true(got.has(&"stone"), "石蟹一定掉石头")
	assert_gte(GameState.inventory.count_of(&"stone"), 1)
	assert_gte(int(Mine.haul.get(&"stone", 0)), 1, "记在这一趟的收获里")


func test_haul_tracks_one_trip() -> void:
	Mine.enter(1, 5)
	for t: Vector2i in Mine.current.rocks.keys():
		while Mine.current.has_rock(t):
			Mine.strike(t)
		break
	var total := 0
	for item: StringName in Mine.haul:
		total += Mine.haul[item]
	assert_gt(total, 0)
	Mine.current.ladder_found = true
	Mine.descend()
	assert_false(Mine.haul.is_empty(), "往下走，收获还记着")
	Mine.leave()
	Mine.enter(1, 6)
	assert_true(Mine.haul.is_empty(), "回过地面再下来是新的一趟")


func test_fainting_loses_half_of_the_haul() -> void:
	GameState.inventory.add(&"stone", 10)
	Mine.enter(1, 5)
	Mine.haul[&"stone"] = 5
	Mine.haul[&"coal"] = 2
	GameState.inventory.add(&"stone", 5)
	GameState.inventory.add(&"coal", 2)
	var lost := Mine.faint()
	assert_eq(lost[&"stone"], 3, "单数的多丢一个")
	assert_eq(lost[&"coal"], 1)
	assert_eq(GameState.inventory.count_of(&"stone"), 12, "下井前带着的不丢")
	assert_eq(GameState.inventory.count_of(&"coal"), 1)
	assert_eq(Mine.floor_no, 0, "人回了地面")
	assert_true(Mine.haul.is_empty())


# ---------------------------------------------------------------- 生命

func test_hurt_takes_health_and_knocks_out_once() -> void:
	assert_eq(GameState.health, GameState.max_health)
	GameState.hurt(30)
	assert_eq(GameState.health, 70)
	assert_eq(_knockouts, 0)
	GameState.hurt(200)
	assert_eq(GameState.health, 0)
	assert_eq(_knockouts, 1)
	GameState.hurt(5)
	assert_eq(_knockouts, 1, "已经倒了不再发")


func test_food_heals_when_hurt() -> void:
	var soup := Database.item(&"radish_soup")
	GameState.energy = GameState.max_energy
	assert_eq(GameState.eat(soup), "", "没受伤、不累：不饿")
	GameState.hurt(40)
	var text := GameState.eat(soup)
	assert_string_contains(text, "生命 +")
	assert_gt(GameState.health, 60)


func test_health_is_full_after_loading() -> void:
	GameState.hurt(40)
	var data := GameState.save_data()
	GameState.load_data(data)
	assert_eq(GameState.health, GameState.max_health, "只有睡觉才存档，醒来是满的")


# ---------------------------------------------------------------- 主角：翻滚和挨打

func test_roll_moves_and_cannot_be_hit() -> void:
	var p := Player.new()
	add_child_autofree(p)
	p.place(Vector2(100, 100), GameMap.Facing.DOWN)
	assert_false(p.invincible())
	assert_true(p.roll(Vector2.RIGHT))
	assert_true(p.is_rolling())
	assert_true(p.invincible(), "滚的时候打不着")
	assert_false(p.roll(Vector2.RIGHT), "滚着不能再滚")
	for i in 5:
		p._process(0.05)
	assert_true(p.is_rolling())
	for i in 2:
		p._process(0.05)
	assert_false(p.is_rolling(), "滚完了")
	assert_false(p.invincible())
	assert_almost_eq(p.position.x, 100.0 + Player.ROLL_SPEED * Player.ROLL_TIME, 8.0)
	assert_eq(p.facing, GameMap.Facing.RIGHT)


func test_roll_stops_at_walls() -> void:
	var ctx := _arena([])
	var p: Player = ctx[1]
	# 下来的地方上面一格是梯子、再上面是岩壁
	p.roll(Vector2.UP)
	for i in 8:
		p._process(0.05)
	assert_false((ctx[0] as GameMap).blocked(p.position), "没滚进墙里")


func test_no_rolling_in_the_middle_of_a_swing() -> void:
	var p := Player.new()
	add_child_autofree(p)
	p.place(Vector2(100, 100), GameMap.Facing.DOWN)
	p.start_action(&"mine", Vector2i(6, 7))
	assert_true(p.is_acting())
	assert_false(p.roll(Vector2.LEFT))


func test_getting_hurt_gives_a_moment_of_safety() -> void:
	var p := Player.new()
	add_child_autofree(p)
	p.place(Vector2(100, 100), GameMap.Facing.DOWN)
	p.hurt(Vector2.LEFT)
	assert_true(p.invincible())
	p._process(0.05)
	assert_lt(p.position.x, 100.0, "被撞开了")
	for i in 20:
		p._process(0.05)
	assert_false(p.invincible())


func test_faster_actions_finish_sooner() -> void:
	var slow := Player.new()
	var fast := Player.new()
	add_child_autofree(slow)
	add_child_autofree(fast)
	slow.place(Vector2(100, 100), GameMap.Facing.DOWN)
	fast.place(Vector2(100, 100), GameMap.Facing.DOWN)
	slow.start_action(&"mine", Vector2i.ZERO)
	fast.start_action(&"mine", Vector2i.ZERO, 2.0)
	for i in 6:
		slow._process(0.05)
		fast._process(0.05)
	assert_true(slow.is_acting())
	assert_false(fast.is_acting())


# ---------------------------------------------------------------- 井里打起来

func test_weapon_in_hand_means_attack() -> void:
	var ctx := _arena([])
	var m: GameMap = ctx[0]
	var p: Player = ctx[1]
	assert_true(m.combat)
	assert_eq(m.query_use(Database.item(&"old_sickle"), p.target_tile(), p.facing), &"attack")
	assert_eq(m.query_use(Database.item(&"hoe"), p.target_tile(), p.facing), &"")
	assert_eq(m.query_use(Database.item(&"old_sickle"), Mine.current.entry, GameMap.Facing.UP), &"interact", "对着梯子还是爬梯子")
	assert_false(_map(&"wellhead").combat, "井口上不打")


func test_swing_hits_the_monster_in_front() -> void:
	var dust := _monster(&"dust", Vector2.ZERO)
	var ctx := _arena([dust])
	var m: GameMap = ctx[0]
	var p: Player = ctx[1]
	dust.pos = p.position + Vector2(0, 18)
	var sickle := Database.weapon(&"old_sickle")
	assert_eq(m.call(&"weapon_hit", sickle, 0, false), 1)
	assert_eq(dust.hp, Database.monster(&"dust").hp - 6)
	p.facing = GameMap.Facing.UP
	assert_eq(m.call(&"weapon_hit", sickle, 0, false), 0, "背对着打不到")
	p.facing = GameMap.Facing.DOWN
	m.call(&"weapon_hit", sickle, 1, false)
	m.call(&"weapon_hit", sickle, 2, false)
	assert_false(dust.alive(), "三下打倒一只尘团")
	assert_eq(Mine.current.monsters_left(), 0)


func test_spin_hits_everything_around() -> void:
	var a := _monster(&"dust", Vector2.ZERO)
	var b := _monster(&"dust", Vector2.ZERO)
	var ctx := _arena([a, b])
	var p: Player = ctx[1]
	a.pos = p.position + Vector2(0, 20)
	b.pos = p.position + Vector2(-20, 0)
	assert_eq((ctx[0] as GameMap).call(&"weapon_hit", Database.weapon(&"old_sickle"), 0, true), 2)
	assert_eq(a.hp, Database.monster(&"dust").hp - 12)
	assert_eq(b.hp, Database.monster(&"dust").hp - 12)


func test_dash_carries_the_player_forward() -> void:
	var dust := _monster(&"dust", Vector2.ZERO)
	var ctx := _arena([dust])
	var p: Player = ctx[1]
	var from := p.position
	dust.pos = from + Vector2(0, 30)
	assert_eq((ctx[0] as GameMap).call(&"weapon_hit", Database.weapon(&"short_sword"), 0, true), 1)
	assert_gt(p.position.y, from.y + 8.0, "人冲出去了")
	assert_false((ctx[0] as GameMap).blocked(p.position))


func test_front_hit_on_crab_gives_a_hint_once() -> void:
	var crab := _monster(&"stone_crab", Vector2.ZERO)
	var ctx := _arena([crab])
	var p: Player = ctx[1]
	crab.pos = p.position + Vector2(0, 18)
	crab.state = MineMonster.State.REST
	crab.facing = Vector2.UP
	var m: GameMap = ctx[0]
	m.call(&"weapon_hit", Database.weapon(&"old_sickle"), 0, false)
	assert_eq(crab.hp, Database.monster(&"stone_crab").hp)
	assert_eq(_banners.size(), 1)
	assert_string_contains(_banners[0], "背后")
	m.call(&"weapon_hit", Database.weapon(&"old_sickle"), 0, false)
	assert_eq(_banners.size(), 1, "提示只说一次")
	m.call(&"weapon_hit", Database.weapon(&"stone_hammer"), 0, false)
	assert_lt(crab.hp, Database.monster(&"stone_crab").hp, "锤砸得动")


func test_lunging_monster_hurts_the_player() -> void:
	var dust := _monster(&"dust", Vector2.ZERO)
	var ctx := _arena([dust])
	var m: GameMap = ctx[0]
	var p: Player = ctx[1]
	dust.pos = p.position + Vector2(0, 16)
	for i in 60:
		m.call(&"tick", 0.02)
	assert_eq(GameState.health, GameState.max_health - Database.monster(&"dust").damage, "挨了一下，而且只挨一下")
	assert_true(p.invincible())


func test_rolling_player_is_not_hurt() -> void:
	var dust := _monster(&"dust", Vector2.ZERO)
	var ctx := _arena([dust])
	var m: GameMap = ctx[0]
	var p: Player = ctx[1]
	dust.pos = p.position + Vector2(0, 16)
	# 等它抬手，然后人一直在滚
	for i in 30:
		m.call(&"tick", 0.02)
		if dust.state == MineMonster.State.STRIKE:
			break
	p.state = Player.State.ROLLING
	for i in 20:
		m.call(&"tick", 0.02)
	assert_eq(GameState.health, GameState.max_health, "滚着的时候撞不着")


func test_dead_monster_view_is_removed() -> void:
	var dust := _monster(&"dust", Vector2.ZERO)
	var ctx := _arena([dust])
	var m: GameMap = ctx[0]
	var p: Player = ctx[1]
	dust.pos = p.position + Vector2(0, 18)
	var views: Dictionary = m.get(&"_views")
	assert_eq(views.size(), 1)
	var view: MonsterView = views[dust]
	assert_eq(view.pose(), &"idle_a")
	for step in 3:
		m.call(&"weapon_hit", Database.weapon(&"old_sickle"), step, false)
	assert_eq((m.get(&"_views") as Dictionary).size(), 0)


func test_hidden_crab_is_drawn_as_a_plain_rock() -> void:
	var a := MineArt.monster(&"stone_crab", &"hidden")
	var b := MineArt.rock(Color(0, 0, 0, 0), 0)
	assert_eq(a.get_data(), b.get_data(), "装石头的石蟹和石头一模一样")
	for pose: StringName in MineArt.MONSTER_POSES:
		for id: StringName in Database.monsters:
			var side: int = Database.monster(id).size
			assert_eq(MineArt.monster(id, pose).get_size(), Vector2i(side, side))


# ---------------------------------------------------------------- 井口、铺子、界面

func test_mouth_hands_over_pickaxe_and_sickle() -> void:
	var m := _map(&"wellhead")
	m.perform(&"interact", null, Vector2i(12, 6))
	assert_eq(GameState.inventory.count_of(&"pickaxe"), 1)
	assert_eq(GameState.inventory.count_of(&"old_sickle"), 1)
	assert_true(GameState.has_flag(Mine.WEAPON_FLAG))
	assert_eq(Mine.floor_no, 0, "头一下只拿东西，不下井")


func test_old_save_with_only_the_pickaxe_still_gets_the_sickle() -> void:
	GameState.inventory.add(&"pickaxe")
	GameState.set_flag(Mine.PICKAXE_FLAG)
	var m := _map(&"wellhead")
	m.perform(&"interact", null, Vector2i(12, 6))
	assert_eq(GameState.inventory.count_of(&"pickaxe"), 1)
	assert_eq(GameState.inventory.count_of(&"old_sickle"), 1)
	assert_string_contains(_banners[-1], "镰刀")


func test_smith_sells_weapons_after_visiting_the_well() -> void:
	var names: Array[StringName] = []
	for e in Shop.entries(&"spring", Shop.SMITH):
		names.append(e.item_id)
	assert_false(names.has(&"short_sword"), "没到过井口，石叔不卖武器")
	GameState.set_flag(&"got_pickaxe")
	GameState.money = 5000
	names.clear()
	var sword: ShopEntry
	for e in Shop.entries(&"spring", Shop.SMITH):
		names.append(e.item_id)
		if e.item_id == &"short_sword":
			sword = e
	assert_true(names.has(&"short_sword"))
	assert_true(names.has(&"stone_hammer"))
	assert_false(names.has(&"old_sickle"), "旧镰刀不卖")
	assert_true(Shop.buy_entry(sword, 1))
	assert_eq(GameState.inventory.count_of(&"short_sword"), 1)
	names.clear()
	for e in Shop.entries(&"spring", Shop.SMITH):
		names.append(e.item_id)
	assert_false(names.has(&"short_sword"), "买过了就不再卖")
	names.clear()
	for e in Shop.entries(&"spring", Shop.GROCERY):
		names.append(e.item_id)
	assert_false(names.has(&"stone_hammer"), "杂货铺不卖武器")


func test_long_banners_stay_longer() -> void:
	assert_almost_eq(Hud.banner_hold("背包满了"), 1.1, 0.001)
	assert_gt(Hud.banner_hold("洞口靠着一把旧镐子，旁边挂着一把镰刀。都拿上了。再按一下顺梯子下井"), 2.0)
	assert_almost_eq(Hud.banner_hold("字".repeat(200)), 4.0, 0.001)


func test_first_descent_explains_the_keys_once() -> void:
	Mine.enter(1, 3)
	var m := _map(&"mine")
	m.entered()
	assert_string_contains(_banners[-1], "翻滚")
	m.entered()
	assert_false(_banners[-1].contains("翻滚"), "只说一次")


func test_health_bar_shows_only_when_it_matters() -> void:
	var hud := Hud.new()
	add_child_autofree(hud)
	GameState.map_id = &"farm"
	assert_false(hud.health_shown())
	GameState.hurt(10)
	assert_true(hud.health_shown(), "受了伤就露出来")
	GameState.health = GameState.max_health
	GameState.map_id = &"mine"
	assert_true(hud.health_shown(), "在井里一直露着")


# ---------------------------------------------------------------- 绕石头、互相挤开、血条、按键说明

## 一间 w × h 的空屋子（格子从 1 开始），rocks 这几格放上石头。
func _room(w: int, h: int, rocks: Array[Vector2i] = []) -> MineFloor:
	var f := MineFloor.new()
	for x in range(1, w + 1):
		for y in range(1, h + 1):
			f.open[Vector2i(x, y)] = true
	for t in rocks:
		f.rocks[t] = &"stone"
		f.hp[t] = 1
	return f


func test_next_step_goes_around_rocks() -> void:
	var f := _room(5, 3, [Vector2i(3, 1), Vector2i(3, 2)])
	assert_eq(f.next_step(Vector2i(2, 1), Vector2i(5, 1)), Vector2i(2, 2), "直着走被挡住，先往下绕")
	assert_eq(f.next_step(Vector2i(2, 3), Vector2i(5, 1)), Vector2i(3, 3))
	assert_eq(f.next_step(Vector2i(4, 1), Vector2i(5, 1)), Vector2i(5, 1))
	assert_eq(f.next_step(Vector2i(2, 2), Vector2i(2, 2)), Vector2i(2, 2), "已经到了")
	# 目的地那一格站不了（比如人贴着它）也算走得到
	assert_eq(f.next_step(Vector2i(2, 1), Vector2i(3, 1)), Vector2i(3, 1))


func test_next_step_gives_up_when_walled_off() -> void:
	var f := _room(5, 3, [Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 3)])
	assert_eq(f.next_step(Vector2i(1, 1), Vector2i(5, 1)), MineFloor.NONE)


func test_clear_line_sees_rocks() -> void:
	var f := _room(5, 3, [Vector2i(3, 1)])
	assert_false(f.clear_line(GameMap.tile_center(Vector2i(1, 1)), GameMap.tile_center(Vector2i(5, 1))))
	assert_true(f.clear_line(GameMap.tile_center(Vector2i(1, 2)), GameMap.tile_center(Vector2i(5, 2))))
	assert_true(f.clear_line(GameMap.tile_center(Vector2i(1, 3)), GameMap.tile_center(Vector2i(5, 2))), "斜着也行")


func test_dust_walks_around_a_rock_to_reach_the_player() -> void:
	var f := _room(5, 3, [Vector2i(3, 1), Vector2i(3, 2)])
	var m := _monster(&"dust", GameMap.tile_center(Vector2i(1, 1)))
	var target := GameMap.tile_center(Vector2i(5, 1))
	var far_x := m.pos.x
	var attacked := false
	for i in 700:
		m.update(0.02, target, f)
		far_x = maxf(far_x, m.pos.x)
		if m.state == MineMonster.State.WINDUP:
			attacked = true
	assert_gt(far_x, GameMap.tile_center(Vector2i(4, 1)).x - 8.0, "绕过了石头")
	assert_true(attacked, "到了跟前出了招")


func test_dust_stays_put_when_there_is_no_way() -> void:
	var f := _room(5, 3, [Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 3)])
	var m := _monster(&"dust", GameMap.tile_center(Vector2i(1, 1)))
	for i in 300:
		m.update(0.02, GameMap.tile_center(Vector2i(5, 1)), f)
	assert_lt(m.pos.x, GameMap.tile_center(Vector2i(3, 1)).x - 8.0, "没穿过石头")


func test_ground_monster_does_not_lunge_through_a_rock() -> void:
	var f := _room(5, 3, [Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 3)])
	var at := GameMap.tile_center(Vector2i(2, 1)) + Vector2(5, 0)
	var target := GameMap.tile_center(Vector2i(4, 1)) - Vector2(5, 0)
	var dust := _monster(&"dust", at)
	var bat := _monster(&"bat", at)
	var dust_windup := false
	var bat_windup := false
	for i in 20:
		dust.update(0.02, target, f)
		bat.update(0.02, target, f)
		dust_windup = dust_windup or dust.state == MineMonster.State.WINDUP
		bat_windup = bat_windup or bat.state == MineMonster.State.WINDUP
	assert_false(dust_windup, "隔着石头不出招")
	assert_true(bat_windup, "蝙蝠飞得过去，照样俯冲")


func test_crowded_monsters_push_apart() -> void:
	var f := _room(7, 5)
	var a := _monster(&"dust", GameMap.tile_center(Vector2i(4, 3)))
	var b := _monster(&"dust", GameMap.tile_center(Vector2i(4, 3)) + Vector2(2, 0))
	f.monsters.append(a)
	f.monsters.append(b)
	for i in 50:
		f.separate(0.02)
	assert_almost_eq(a.pos.distance_to(b.pos), float(a.def.radius + b.def.radius), 0.5)


func test_hidden_crab_is_not_pushed() -> void:
	var f := _room(7, 5)
	var at := GameMap.tile_center(Vector2i(4, 3))
	var crab := _monster(&"stone_crab", at)
	var dust := _monster(&"dust", at + Vector2(3, 0))
	f.monsters.append(crab)
	f.monsters.append(dust)
	for i in 50:
		f.separate(0.02)
	assert_eq(crab.pos, at, "装石头的一动不动")
	assert_gt(dust.pos.x, at.x + 3.0)


func test_monster_bar_shows_after_a_hit() -> void:
	var m := _monster(&"stone_crab", Vector2(100, 100))
	var view := MonsterView.new()
	add_child_autofree(view)
	view.setup(m)
	assert_false(view.bar_shown(), "没受伤不显示")
	m.state = MineMonster.State.STUNNED
	m.take_hit(5, Vector2(100, 120), 0.0)
	assert_true(view.bar_shown())
	assert_between(view.bar_width(), 1, MonsterView.BAR_W - 3)
	m.hp = 1
	assert_eq(view.bar_width(), 1, "还活着至少留一格")
	m.take_hit(99, Vector2(100, 120), 0.0, true)
	assert_false(view.bar_shown(), "倒了就收起来")


func test_key_help_lists_every_action() -> void:
	for row: Array in PauseMenu.KEY_ROWS:
		for action: StringName in row[1]:
			assert_true(InputMap.has_action(action), "有 %s 这个动作" % action)
	var rows := PauseMenu.key_rows()
	assert_eq(rows.size(), PauseMenu.KEY_ROWS.size())
	var by_name: Dictionary[String, String] = {}
	for row: Array in rows:
		assert_ne(String(row[1]), "", "%s 写了键" % row[0])
		by_name[String(row[0])] = String(row[1])
	assert_string_contains(by_name["翻滚（井里）"], "Shift")
	assert_string_contains(by_name["使用、搭话（按住蓄力）"], "空格")
	assert_string_contains(by_name["走动"], "↑")
	assert_eq(by_name["换手里的东西"], "1 – 8")


func test_pause_menu_opens_and_leaves_the_key_page() -> void:
	var menu := PauseMenu.new()
	add_child_autofree(menu)
	menu.open()
	assert_false(menu.keys_open())
	menu.show_keys()
	assert_true(menu.keys_open())
	var back: Button = menu.get(&"_back")
	var page: Control = menu.get(&"_keys_panel")
	assert_lt(back.size.y, 20.0, "返回按钮和别的按钮一样高")
	assert_lt(back.position.y + back.size.y, page.size.y - 4.0, "返回按钮在面板里面")
	menu.hide_keys()
	assert_true(menu.is_open(), "退回菜单，没有整个关掉")
	assert_false(menu.keys_open())
	menu.show_keys()
	menu.close()
	menu.open()
	assert_false(menu.keys_open(), "再打开从菜单开始")
