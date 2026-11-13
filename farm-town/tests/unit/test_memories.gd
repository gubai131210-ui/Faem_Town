extends GutTest
## M6 第五批：二到五级忆、岚的五段、忆满以后打开的那些事。


func before_each() -> void:
	SaveSystem.reset_all()
	GameClock.day = 2
	GameClock.minutes = 600.0


func after_each() -> void:
	SaveSystem.reset_all()


func test_every_resident_has_five_memories_and_lan_does_too() -> void:
	assert_eq(Database.validate().size(), 0, "%s" % Database.validate())
	for id: StringName in Database.npcs:
		if id == &"xiaoman":
			assert_null(Database.memory(id, 1), "小满没有忆")
			continue
		for level in range(1, 6):
			var m := Database.memory(id, level)
			assert_not_null(m, "%s 第 %d 级" % [id, level])
			assert_eq(Database.relic(m.relic).level, level)
			var res: Resource = load(Residents.dialogue_path(id))
			var line: Variant = await DialogueManager.get_next_dialogue_line(res, "memory_%d" % level)
			assert_not_null(line, "%s 的 memory_%d 有话说" % [id, level])
	for level in range(1, 6):
		assert_not_null(Database.memory(&"lan", level))
	assert_eq(Story.lan_level(), 0)
	assert_false(Story.true_ready())


func test_higher_relics_stay_out_of_the_pool_until_you_are_ready() -> void:
	assert_false(Residents.relic_available(Database.relic(&"ahe_cover")))
	assert_true(Residents.relic_available(Database.relic(&"ledger_page")))
	for i in 30:
		var id := Foraging.pick_relic(i / 30.0)
		if id == &"":
			continue
		var r := Database.relic(id)
		assert_lte(r.level, 1, "雾天先不掉 %s" % id)
	Residents.memory_levels[&"ahe"] = 1
	assert_true(Residents.relic_available(Database.relic(&"ahe_cover")))
	assert_false(Residents.relic_available(Database.relic(&"ahe_abacus")))


func test_returning_a_relic_raises_the_cap_and_the_book() -> void:
	Residents.met[&"ahe"] = true
	Residents.familiarity[&"ahe"] = 200
	Residents.memory_levels[&"ahe"] = 1
	GameState.inventory.clear()
	GameState.inventory.add(&"ahe_cover", 1)
	GameState.selected_slot = 0
	assert_eq(Residents.familiarity_cap(&"ahe"), 200)
	Residents.talk(&"ahe", false)
	assert_eq(Residents.memory_level(&"ahe"), 2)
	assert_eq(Residents.familiarity_cap(&"ahe"), 300)
	assert_eq(GameState.inventory.count_of(&"ahe_cover"), 0)
	var titles: PackedStringArray = []
	for m in Residents.recovered():
		titles.append(m.title)
	assert_true(titles.has("封面上的字"))


func test_ahe_discounts_seeds_and_widens_the_shelves() -> void:
	var full := Database.item(&"bok_choy_seed").price
	assert_eq(Shop.asking_price(Database.item(&"bok_choy_seed")), full)
	Residents.memory_levels[&"ahe"] = 4
	assert_eq(Shop.asking_price(Database.item(&"bok_choy_seed")), maxi(1, int(round(full * 0.8))))
	Residents.memory_levels[&"ahe"] = 5
	var wide := Shop.stock(&"spring")
	var summer := false
	for it in wide:
		var crop := Database.crop(Database.item(it.id).crop)
		if crop.can_sow(&"summer"):
			summer = true
	assert_true(summer, "五级以后春季货架上有夏季的种子")


func test_memory_recipes_and_the_other_unlocks() -> void:
	assert_false(Crafting.knows(&"herb_tea"))
	Residents.memory_levels[&"jiang"] = 3
	assert_true(Crafting.knows(&"herb_tea"))
	assert_false(Crafting.knows(&"fog_tonic"))
	Residents.memory_levels[&"luyuan"] = 4
	assert_true(Crafting.knows(&"fog_tonic"))
	Residents.memory_levels[&"yunniang"] = 5
	assert_true(Crafting.knows(&"farewell_noodles"))
	assert_eq(Animals.price("coop"), Database.building(&"coop").price)
	Residents.memory_levels[&"qingzhu"] = 3
	assert_lt(Animals.price("coop"), Database.building(&"coop").price)
	assert_eq(Animals.animal_price("chicken"), Database.animal(&"chicken").price)
	Residents.memory_levels[&"amu"] = 3
	assert_lt(Animals.animal_price("chicken"), Database.animal(&"chicken").price)
	Residents.memory_levels[&"shishu"] = 5
	var ore := 0
	for e in Shop.entries(&"spring", Shop.SMITH):
		if e.upgrade and e.item_id == &"hoe":
			for m in e.materials:
				if m["item"] == &"iron_ore":
					ore = int(m["count"])
	assert_eq(ore, 4, "石叔少要一块铁矿")
	assert_eq(Fishing.effective_rod(&"river"), GameState.tool_level(&"rod"))
	Residents.memory_levels[&"laozhou"] = 3
	assert_eq(Fishing.effective_rod(&"river"), GameState.tool_level(&"rod") + 1)
	Residents.memory_levels[&"laozhou"] = 5
	assert_eq(Fishing.effective_rod(&"sea"), GameState.tool_level(&"rod") + 2)
	assert_eq(Fishing.effective_rod(&"river"), GameState.tool_level(&"rod") + 1)
	GameState.inventory.add(&"stone", 4)
	assert_true(Mine.enter(1))
	Mine.haul[&"stone"] = 4
	Residents.memory_levels[&"laoqin"] = 5
	var lost := Mine.faint()
	assert_eq(int(lost.get(&"stone", 0)), 1, "老秦想起以后，四块石头只掉一块")
	GameState.set_flag(&"lamp_plaza")
	assert_string_contains(Residents.uncharted(), "河灯")
	for id: StringName in Database.lamps:
		GameState.set_flag(StringName("lamp_" + String(id)))
	GameState.set_flag(Story.TRIAL_FLAG)
	assert_eq(Residents.uncharted(), "纸上的路都通了。")


func test_east_bank_and_the_bridge_wait_for_the_memory() -> void:
	var farm := _map(&"farm")
	var east := Vector2i(-1, -1)
	for y in range(10, 20):
		var x: int = farm._stream_x(y) + 2
		var t := Vector2i(x, y)
		if farm.terrain[farm.idx(t)] != farm.WATER and farm.solid[farm.idx(t)] == 0:
			east = t
			break
	assert_ne(east.x, -1, "溪东有能站的草地")
	assert_false(farm._can_till(east), "没有许可不能开垦")
	Residents.memory_levels[&"bai"] = 5
	assert_true(farm._can_till(east))
	var nanxi := _map(&"nanxi")
	var blocked: Vector2i = nanxi._bridge_tiles()[0]
	assert_false(nanxi._walkable(blocked), "桥还没修，水面不能走")
	Residents.memory_levels[&"qingzhu"] = 5
	nanxi = _map(&"nanxi")
	assert_true(nanxi._walkable(blocked), "青竹把桥补上了")
	assert_eq(nanxi.fishing_water(blocked), &"", "站在桥上不算在水里")


func test_giving_lan_her_name_opens_the_true_ending() -> void:
	for level in range(1, 5):
		GameState.inventory.clear()
		var relic: StringName = Database.memory(&"lan", level).relic
		GameState.inventory.add(relic, 1)
		GameState.selected_slot = 0
		assert_true(Residents.holding_lan_memory())
		Residents.give_lan()
		assert_eq(Story.lan_level(), level)
	assert_false(Story.true_ready(), "还差最后一段，而且居民没满")
	GameState.inventory.clear()
	GameState.inventory.add(Database.memory(&"lan", 5).relic, 1)
	GameState.selected_slot = 0
	Residents.give_lan()
	assert_eq(Story.lan_level(), 5)
	assert_true(GameState.has_flag(Story.LAN_FLAG))
	for id: StringName in Database.npcs:
		if Database.memory(id, 1) != null:
			Residents.memory_levels[id] = 5
	assert_true(Story.unfinished().is_empty())
	assert_true(Story.true_ready())
	var said := ""
	for m in Residents.recovered():
		if m.npc == &"lan" and m.level == 5:
			said = m.title
	assert_eq(said, "青岚")


func _map(id: StringName) -> OutdoorMap:
	var scene: PackedScene = load(SceneRouter.MAPS[id])
	var m: OutdoorMap = scene.instantiate()
	add_child_autofree(m)
	return m
