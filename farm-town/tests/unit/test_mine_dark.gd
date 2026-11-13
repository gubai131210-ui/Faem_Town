extends GutTest
## M5 第四批：无光层、灯油和黑暗、三种新忘形、无名戏班、岚之影的考验、饰品。

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


# ---------------------------------------------------------------- 层段

func test_four_layers_cover_forty_floors() -> void:
	assert_eq(Mine.OPEN_FLOORS, 40)
	assert_eq(Database.mine_layer(31).id, &"lightless")
	assert_eq(Database.mine_layer(40).id, &"lightless")
	assert_true(Database.mine_layer(35).dark)
	assert_false(Database.mine_layer(25).dark)
	assert_true(Mine.has_boss_room(30))
	assert_true(Mine.has_boss_room(40))
	assert_false(Mine.has_boss_room(35))


func test_lightless_floors_are_dark_and_have_their_own_ores_and_monsters() -> void:
	var ores: Dictionary[StringName, bool] = {}
	var kinds: Dictionary[StringName, bool] = {}
	for s in 16:
		var n := 33 + s % 6
		var f := MineFloor.generate(n, Database.mine_layer(n), 100 + s, true, n % Mine.LAMP_EVERY == 0)
		assert_true(f.dark)
		assert_true(f.distances().has(f.ladder), "第 %d 层 种子 %d 梯子走得到" % [n, s])
		for t: Vector2i in f.rocks:
			ores[f.rocks[t]] = true
		for m in f.monsters:
			kinds[m.def.id] = true
	assert_true(ores.has(&"gold_ore"))
	assert_true(ores.has(&"lan_crystal"))
	for id: StringName in [&"light_moth", &"shadow", &"nameless"]:
		assert_true(kinds.has(id), String(id))
	assert_false(MineFloor.generate(25, Database.mine_layer(25), 3, true, true).dark)


# ---------------------------------------------------------------- 灯油

func test_entering_from_the_surface_tops_the_lamp_up() -> void:
	assert_eq(Mine.oil, 0.0)
	Mine.enter(1)
	assert_eq(Mine.oil, Mine.ENTRY_OIL)
	Mine.oil = 90.0
	Mine.enter(2)
	assert_eq(Mine.oil, 90.0, "在井里换层不添油")
	Mine.leave()
	Mine.enter(1)
	assert_eq(Mine.oil, 90.0, "比底油多就不动")


func test_oil_only_burns_on_dark_floors() -> void:
	Mine.enter(5)
	var before := Mine.oil
	Mine.burn(10.0)
	assert_eq(Mine.oil, before)
	Mine.enter(33)
	Mine.burn(10.0)
	assert_almost_eq(Mine.oil, before - Mine.OIL_DRAIN * 10.0, 0.01)
	Mine.burn(10000.0)
	assert_eq(Mine.oil, 0.0)
	assert_eq(Mine.light_radius(), 0.0)


func test_light_shrinks_as_oil_runs_down() -> void:
	Mine.oil = Mine.OIL_MAX
	assert_almost_eq(Mine.light_radius(), Mine.LIGHT_MAX, 0.01)
	Mine.oil = 1.0
	assert_gt(Mine.light_radius(), Mine.LIGHT_MIN - 0.01)
	assert_lt(Mine.light_radius(), Mine.LIGHT_MIN + 2.0)


func test_refuel_with_lamp_oil_or_cooking_oil() -> void:
	Mine.enter(33)
	Mine.oil = 10.0
	assert_false(Mine.refuel(&"lamp_oil"), "背包里没有")
	GameState.inventory.add(&"lamp_oil", 1)
	GameState.inventory.add(&"cooking_oil", 2)
	assert_true(Mine.refuel(&"lamp_oil"))
	assert_eq(Mine.oil, 70.0)
	assert_eq(GameState.inventory.count_of(&"lamp_oil"), 0)
	assert_true(Mine.refuel(&"cooking_oil"))
	assert_eq(Mine.oil, 95.0)
	assert_true(Mine.refuel(&"cooking_oil"))
	assert_eq(Mine.oil, Mine.OIL_MAX, "不会超过满")
	GameState.inventory.add(&"cooking_oil", 1)
	assert_false(Mine.refuel(&"cooking_oil"), "满了不添")
	assert_eq(GameState.inventory.count_of(&"cooking_oil"), 1)
	assert_false(Mine.refuel(&"stone"))


func test_snuff_has_a_short_gap() -> void:
	Mine.oil = 50.0
	assert_true(Mine.snuff(15.0))
	assert_eq(Mine.oil, 35.0)
	assert_false(Mine.snuff(15.0), "刚掉过一口")
	Mine.burn(Mine.SNUFF_GAP + 0.01)
	assert_true(Mine.snuff(100.0))
	assert_eq(Mine.oil, 0.0)


func test_oil_and_accessories_are_saved() -> void:
	GameState.inventory.add(&"silver_guard", 1)
	Mine.toggle_accessory(&"silver_guard")
	Mine.oil = 33.0
	var data := Mine.save_data()
	Mine.reset_data()
	assert_eq(Mine.oil, 0.0)
	assert_true(Mine.equipped.is_empty())
	Mine.load_data(data)
	assert_eq(Mine.oil, 33.0)
	assert_true(Mine.equipped.has(&"silver_guard"))


func test_use_key_with_oil_in_hand_refuels_in_the_mine() -> void:
	Mine.enter(33, 5)
	Mine.oil = 20.0
	var pair := _enter_map(Mine.current.spawn)
	var m: GameMap = pair[0]
	GameState.inventory.add(&"lamp_oil", 1)
	var item := Database.item(&"lamp_oil")
	assert_eq(m.query_use(item, Mine.current.spawn + Vector2i(0, 1), GameMap.Facing.DOWN), &"")
	assert_true(m.use_item(item))
	assert_eq(Mine.oil, 80.0)
	assert_false(m.use_item(Database.item(&"stone")))


func test_dark_floor_tints_the_screen_and_shows_the_oil_bar() -> void:
	Mine.enter(33, 5)
	var pair := _enter_map(Mine.current.spawn)
	var m: GameMap = pair[0]
	assert_gt(m.forced_tint().a, 0.0)
	assert_true(m.oil_bar_shown())
	Mine.oil = Mine.OIL_MAX / 2.0
	assert_eq(m.oil_bar_width(), m.OIL_BAR_W / 2)
	m.tick(STEP)
	assert_almost_eq(Mine.current.light, Mine.light_radius(), 0.01)
	Mine.enter(5, 5)
	var lit: GameMap = _enter_map(Mine.current.spawn)[0]
	assert_eq(lit.forced_tint().a, 0.0)
	assert_false(lit.oil_bar_shown())


# ---------------------------------------------------------------- 三种忘形

func test_shadow_walks_where_the_player_was() -> void:
	var f := _room(16, 8)
	var m := _monster(&"shadow", _c(2, 4))
	# 人从 (6,4) 往右走，影子先愣 echo 秒，然后跟着走过的路来
	var target := _c(6, 4)
	_run(m, m.def.echo - 0.3, target, f)
	assert_eq(m.pos, _c(2, 4), "还没到时候不动")
	var left := 3.0
	while left > 0.0:
		target.x += 40.0 * STEP
		m.update(STEP, target, f)
		left -= STEP
	assert_gt(m.pos.x, _c(6, 4).x - 1.0, "走到了人待过的地方")
	assert_lt(m.pos.x, target.x - 40.0, "但落在后面")
	assert_false(m.strikes(target))
	# 人站住：它走上来，碰到算一下，然后歇一会儿
	var hit := false
	left = 4.0
	while left > 0.0 and not hit:
		m.update(STEP, target, f)
		hit = m.strikes(target)
		left -= STEP
	assert_true(hit)
	m.update(STEP, target, f)
	assert_false(m.strikes(target), "刚碰过")


func test_nameless_freezes_in_the_light() -> void:
	var f := _room(16, 8)
	f.light = 60.0
	var m := _monster(&"nameless", _c(2, 4))
	var target := _c(10, 4)
	_run(m, 2.0, target, f)
	var gap := m.pos.distance_to(target)
	assert_lt(gap, _c(2, 4).distance_to(target), "灯照不到的地方会走过来")
	_run(m, 6.0, target, f)
	assert_gt(m.pos.distance_to(target), 58.0, "走到灯光边上就停住")
	assert_ne(m.state, MineMonster.State.STRIKE)
	# 灯灭了：一直走到跟前动手
	f.light = 0.0
	var struck := false
	var left := 8.0
	while left > 0.0 and not struck:
		m.update(STEP, target, f)
		struck = m.strikes(target)
		left -= STEP
	assert_true(struck)


func test_moth_eats_oil_instead_of_hurting() -> void:
	Mine.enter(33, 5)
	Mine.current.monsters.clear()
	Mine.oil = 50.0
	var pair := _enter_map(Mine.current.spawn)
	var m: GameMap = pair[0]
	var p: Player = pair[1]
	var moth := _monster(&"light_moth", p.position + Vector2(20, 0))
	Mine.current.monsters.append(moth)
	var health := GameState.health
	var left := 4.0
	while left > 0.0 and Mine.oil > 40.0:
		m.tick(STEP)
		left -= STEP
	assert_almost_eq(Mine.oil, 50.0 - moth.def.eat_light, 2.0)
	assert_eq(GameState.health, health)


# ---------------------------------------------------------------- 无名戏班

func test_troupe_arena_on_floor_30() -> void:
	assert_true(Mine.enter(30, 1))
	var f := Mine.current
	assert_eq(f.arena, &"troupe")
	assert_true(f.boss is MineTroupe)
	assert_false(f.dark)
	assert_false(f.ladder_found)


func test_troupe_cycles_three_masks() -> void:
	var f := _room(20, 12)
	var boss := _monster(&"nameless_troupe", _c(10, 6)) as MineTroupe
	var target := _c(5, 6)
	assert_eq(boss.skin(), &"red")
	# 红脸：一轮里冲三回
	var dashes := 0
	var was := boss.state
	var left := 12.0
	while left > 0.0 and boss.skin() == &"red":
		boss.update(STEP, target, f)
		if boss.state == MineMonster.State.STRIKE and was != MineMonster.State.STRIKE:
			dashes += 1
		was = boss.state
		left -= STEP
	assert_eq(dashes, MineTroupe.DASHES)
	assert_eq(boss.skin(), &"white")
	assert_true(boss.events.has(&"mask"))
	# 白脸：两圈纸钱
	boss.pending_shots.clear()
	left = 12.0
	while left > 0.0 and boss.skin() == &"white":
		boss.update(STEP, target, f)
		left -= STEP
	assert_eq(boss.pending_shots.size(), MineTroupe.RING * 2)
	assert_eq(boss.skin(), &"black")
	# 黑脸：跳起来，落地砸一圈
	assert_true(_run_until(boss, MineMonster.State.STRIKE, 6.0, target, f))
	boss.update(STEP, target, f)
	assert_gt(boss.air(), 0.0)
	var hit := false
	left = 2.0
	while left > 0.0 and boss.state == MineMonster.State.STRIKE:
		boss.update(STEP, target, f)
		hit = hit or boss.strikes(target)
		left -= STEP
	assert_true(hit, "站着不动会被砸到")
	left = 6.0
	while left > 0.0 and boss.skin() == &"black":
		boss.update(STEP, target, f)
		left -= STEP
	assert_eq(boss.skin(), &"red", "三张脸转回来")


func test_troupe_can_always_be_hit_but_not_stunned() -> void:
	var boss := _monster(&"nameless_troupe", _c(10, 6))
	var at := boss.pos
	var res := boss.take_hit(10, _c(9, 6), 200.0, true)
	assert_false(bool(res["blocked"]))
	assert_eq(boss.hp, boss.def.hp - 10)
	assert_ne(boss.state, MineMonster.State.STUNNED)
	_run(boss, 0.1, _c(40, 6))
	assert_almost_eq(boss.pos.x, at.x, 1.0, "推不开")
	res = boss.take_hit(1000, _c(9, 6), 0.0)
	assert_true(bool(res["dead"]))


func test_shots_vanish_when_the_boss_falls() -> void:
	Mine.enter(30, 1)
	var boss := Mine.current.boss
	var pair := _enter_map(Vector2i(5, 8))
	var m: GameMap = pair[0]
	var p: Player = pair[1]
	Mine.current.shots.append(MineShot.create(p.position + Vector2(60, 40), Vector2(10, 0), 5, &"paper"))
	boss.hp = 1
	boss.pos = p.position + Vector2(0, 10)
	m.weapon_hit(Database.weapon(&"old_sickle"), 0, false)
	assert_false(Mine.current.boss_alive())
	assert_true(Mine.current.shots.is_empty(), "首领倒了，飞着的纸钱也没了")


func test_beating_the_troupe_drops_the_blade_and_the_mask() -> void:
	Mine.enter(30, 1)
	var got := Mine.defeat(Mine.current.boss)
	assert_true(got.has(&"opera_blade"))
	assert_true(got.has(&"mask_shard"))
	assert_true(GameState.has_flag(&"boss_troupe"))
	assert_true(Mine.bosses.has(30))


# ---------------------------------------------------------------- 岚之影

func test_trial_floor_layout() -> void:
	assert_true(Mine.enter(40, 1))
	var f := Mine.current
	assert_eq(f.arena, &"shade")
	assert_true(f.dark)
	assert_true(f.boss is MineShade)
	assert_eq(f.ladder, MineFloor.NONE, "井底没有再往下的梯子")
	assert_false(f.walkable(f.altar))
	assert_true(f.distances().has(f.altar + Vector2i(-1, 0)), "走得到灯座跟前")
	assert_eq(f.monsters.size(), 1 + MineFloor.TRIAL_MOTHS.size())
	assert_eq(Mine.oil, Mine.OIL_MAX, "进来的时候灯是满的")
	assert_true(Mine.trial_running())
	GameState.inventory.add(&"lamp_oil", 1)
	Mine.oil = 50.0
	assert_false(Mine.refuel(&"lamp_oil"), "考验当中添不了油")


func test_shade_cannot_be_hit_and_blows_the_lamp() -> void:
	var f := _room(20, 12)
	var shade := _monster(&"lan_shade", _c(10, 6)) as MineShade
	var target := _c(6, 6)
	assert_true(bool(shade.take_hit(999, target, 100.0, true)["blocked"]))
	assert_true(shade.alive())
	var left := 8.0
	while left > 0.0 and shade.pending_shots.is_empty():
		shade.update(STEP, target, f)
		assert_false(shade.strikes(target))
		left -= STEP
	assert_eq(shade.pending_shots.size(), MineShade.GUSTS)
	for s in shade.pending_shots:
		assert_eq(s.kind, &"gust")
		assert_eq(s.snuff, shade.def.eat_light)
		assert_eq(s.damage, 0)
	assert_true(shade.events.has(&"blow"))


func test_gust_takes_oil_not_health() -> void:
	Mine.enter(40, 1)
	Mine.current.monsters.clear()
	Mine.current.boss = null
	var pair := _enter_map(Mine.current.spawn)
	var m: GameMap = pair[0]
	var p: Player = pair[1]
	Mine.oil = 80.0
	var health := GameState.health
	var shot := MineShot.create(p.position + Vector2(10, 0), Vector2(-60, 0), 0, &"gust")
	shot.snuff = 22.0
	Mine.current.shots.append(shot)
	for i in 30:
		m.tick(STEP)
	assert_almost_eq(Mine.oil, 58.0, 1.0)
	assert_eq(GameState.health, health)


func test_trial_restarts_when_the_lamp_goes_out() -> void:
	Mine.enter(40, 1)
	var pair := _enter_map(Vector2i(10, 7))
	var m: GameMap = pair[0]
	var p: Player = pair[1]
	Mine.oil = 0.0
	m.tick(STEP)
	assert_eq(p.position, GameMap.tile_center(Mine.current.spawn))
	assert_eq(Mine.oil, Mine.OIL_MAX)
	assert_true(Mine.trial_running(), "考验还在")
	assert_gt(GameState.health, 0)
	assert_true(_banners.back().contains("再走一回"))


func test_reaching_the_altar_finishes_the_trial() -> void:
	Mine.enter(40, 1)
	var altar := Mine.current.altar
	var pair := _enter_map(altar + Vector2i(-1, 0), GameMap.Facing.RIGHT)
	var m: GameMap = pair[0]
	assert_false(m.boss_bar_shown(), "它没有血条")
	assert_eq(m.query_use(null, altar, GameMap.Facing.RIGHT), &"interact")
	m.perform(&"interact", null, altar)
	assert_false(Mine.trial_running())
	assert_true(GameState.has_flag(&"boss_shade"))
	assert_true(Mine.bosses.has(40))
	assert_eq(GameState.inventory.count_of(&"lan_tassel"), 1)
	assert_false(Mine.current.dark, "灯座亮了，井底不黑了")
	assert_eq(m.forced_tint().a, 0.0)
	assert_false(m.oil_bar_shown())
	# 再来：没有影子，也不黑
	Mine.leave()
	Mine.enter(40, 1)
	assert_false(Mine.trial_running())
	assert_false(Mine.current.dark)
	assert_true(Mine.current.monsters.is_empty())


# ---------------------------------------------------------------- 饰品

func test_accessory_table() -> void:
	assert_eq(Database.accessories.size(), 7)
	for id: StringName in Database.accessories:
		var def := Database.accessory(id)
		assert_true(AccessoryDef.EFFECTS.has(def.effect), String(id))
		var item := Database.item(id)
		assert_eq(item.kind, &"accessory")
		assert_eq(item.stack, 1)
		assert_gt(PixelArt.icon(item.icon).get_used_rect().size.x, 4, String(id))


func test_wear_two_at_most_and_take_off() -> void:
	for id: StringName in [&"silver_guard", &"leech_tooth", &"soft_soles"]:
		GameState.inventory.add(id, 1)
	assert_eq(Mine.toggle_accessory(&"lan_wick"), "", "手里没有")
	assert_true(Mine.toggle_accessory(&"silver_guard").begins_with("戴上了"))
	assert_true(Mine.toggle_accessory(&"leech_tooth").begins_with("戴上了"))
	assert_true(Mine.toggle_accessory(&"soft_soles").contains("只能戴"))
	assert_false(Mine.wearing(&"soft_soles"))
	assert_eq(GameState.display_name(Database.item(&"silver_guard")), "银护腕（戴着）")
	assert_true(Mine.toggle_accessory(&"silver_guard").begins_with("摘下了"))
	assert_eq(GameState.display_name(Database.item(&"silver_guard")), "银护腕")
	assert_true(Mine.toggle_accessory(&"soft_soles").begins_with("戴上了"))


func test_bonus_needs_the_item_in_the_bag() -> void:
	GameState.inventory.add(&"silver_guard", 1)
	Mine.toggle_accessory(&"silver_guard")
	assert_almost_eq(Mine.bonus(&"armor"), 0.15, 0.001)
	assert_eq(Mine.bonus(&"power"), 0.0)
	GameState.inventory.remove(&"silver_guard", 1)
	assert_eq(Mine.bonus(&"armor"), 0.0, "卖掉了就不算")
	assert_false(Mine.wearing(&"silver_guard"))


func test_lan_wick_saves_oil_and_tassel_widens_the_light() -> void:
	Mine.enter(33)
	Mine.oil = 50.0
	var plain := Mine.light_radius()
	GameState.inventory.add(&"lan_wick", 1)
	GameState.inventory.add(&"lan_tassel", 1)
	Mine.toggle_accessory(&"lan_wick")
	Mine.toggle_accessory(&"lan_tassel")
	Mine.burn(10.0)
	assert_almost_eq(Mine.oil, 50.0 - Mine.OIL_DRAIN * 0.6 * 10.0, 0.01)
	Mine.oil = 50.0
	assert_almost_eq(Mine.light_radius(), plain * 1.25, 0.01)


func test_leech_tooth_heals_on_kill() -> void:
	GameState.inventory.add(&"leech_tooth", 1)
	Mine.toggle_accessory(&"leech_tooth")
	Mine.enter(3)
	GameState.health = 50
	Mine.defeat(_monster(&"dust", _c(3, 3)))
	assert_eq(GameState.health, 52)


func test_armor_wade_power_and_roll_grace_apply_in_the_mine() -> void:
	Mine.enter(14, 31)
	Mine.current.monsters.clear()
	var water: Vector2i = Mine.current.water.keys()[0]
	var pair := _enter_map(Mine.current.spawn)
	var m: GameMap = pair[0]
	var p: Player = pair[1]
	assert_almost_eq(m.slow_at(GameMap.tile_center(water)), m.WADE, 0.001)
	for id: StringName in [&"oilcloth_wraps", &"silver_guard"]:
		GameState.inventory.add(id, 1)
		Mine.toggle_accessory(id)
	assert_eq(m.slow_at(GameMap.tile_center(water)), 1.0)
	var health := GameState.health
	m._hurt_player(p, 20, Vector2.RIGHT)
	assert_eq(GameState.health, health - 17)
	Mine.toggle_accessory(&"oilcloth_wraps")
	Mine.toggle_accessory(&"silver_guard")
	for id: StringName in [&"soft_soles", &"mask_shard"]:
		GameState.inventory.add(id, 1)
		Mine.toggle_accessory(id)
	m.tick(STEP)
	assert_almost_eq(p.roll_grace, 0.15, 0.001)
	# 半张面具：武器多两成
	var dust := _monster(&"dust", p.position + Vector2(0, 10))
	dust.hp = 1000
	Mine.current.monsters.append(dust)
	var sickle := Database.weapon(&"old_sickle")
	m.weapon_hit(sickle, 0, false)
	assert_eq(1000 - dust.hp, roundi(sickle.damage_at(0) * 1.2))


func test_roll_grace_keeps_the_player_safe_a_moment_after_rolling() -> void:
	Mine.enter(3, 5)
	Mine.current.monsters.clear()
	var pair := _enter_map(Mine.current.spawn)
	var p: Player = pair[1]
	p.roll_grace = 0.15
	assert_true(p.roll(Vector2.DOWN))
	var guard := 200
	while p.is_rolling() and guard > 0:
		p._process(STEP)
		guard -= 1
	assert_true(p.invincible(), "滚完还有一小会儿")
	for i in 12:
		p._process(STEP)
	assert_false(p.invincible())


func test_smith_makes_accessories_for_money_and_ore() -> void:
	GameState.set_flag(&"visited_wellhead")
	var names: Array[StringName] = []
	for e in Shop.entries(&"spring", Shop.SMITH):
		names.append(e.item_id)
	assert_false(names.has(&"silver_guard"), "打倒矿车以前不打")
	GameState.set_flag(&"boss_cart")
	var guard: ShopEntry
	names.clear()
	for e in Shop.entries(&"spring", Shop.SMITH):
		names.append(e.item_id)
		if e.item_id == &"silver_guard":
			guard = e
	assert_not_null(guard)
	assert_false(names.has(&"mask_shard"), "首领给的不卖")
	assert_false(names.has(&"lan_tassel"))
	GameState.money = 5000
	assert_eq(Shop.affordable_entry(guard, 1), 0, "没有银矿")
	assert_false(Shop.buy_entry(guard, 1))
	assert_eq(GameState.money, 5000)
	GameState.inventory.add(&"silver_ore", 6)
	assert_eq(Shop.affordable_entry(guard, 1), 1)
	assert_true(Shop.buy_entry(guard, 1))
	assert_eq(GameState.money, 4500)
	assert_eq(GameState.inventory.count_of(&"silver_ore"), 1)
	assert_eq(GameState.inventory.count_of(&"silver_guard"), 1)
	for e in Shop.entries(&"spring", Shop.SMITH):
		assert_ne(e.item_id, &"silver_guard", "有了就不再打")


func test_new_relics_and_art_exist() -> void:
	for id: StringName in [&"lamp_shade", &"old_photo", &"name_tag"]:
		assert_true(Database.has_relic(id))
		assert_gt(PixelArt.icon(Database.item(id).icon).get_used_rect().size.x, 4, String(id))
	for id: StringName in [&"light_moth", &"shadow", &"nameless", &"nameless_troupe", &"lan_shade"]:
		var size := Database.monster(id).size
		for pose: StringName in MineArt.MONSTER_POSES:
			assert_eq(MineArt.monster(id, pose).get_size(), Vector2i(size, size), "%s %s" % [id, pose])
	var red := MineArt.monster(&"nameless_troupe", &"idle_a", &"red")
	var white := MineArt.monster(&"nameless_troupe", &"idle_a", &"white")
	assert_ne(red.get_data(), white.get_data(), "面具不一样，图也不一样")
