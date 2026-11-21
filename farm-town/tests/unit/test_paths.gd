extends GutTest
## M8 第一批：本事从灯上拆开，三盏灯的先后放开。灯亮了的旧存档照旧。


func before_each() -> void:
	SaveSystem.reset_all()
	Weather.today = &"sunny"
	GameClock.day = 10
	GameClock.minutes = 600.0


func after_each() -> void:
	SaveSystem.reset_all()


func test_trust_npcs_are_real_people() -> void:
	for id: StringName in Database.buildings:
		var by := Database.building(id).by
		if by != &"":
			assert_true(Database.npcs.has(by), "%s 的 by" % id)
	for id: StringName in Database.animals:
		var who := Database.animal(id).by
		if who != &"":
			assert_true(Database.npcs.has(who), "%s 的 by" % id)


func test_lamps_still_open_the_old_way_with_no_familiarity() -> void:
	assert_eq(Residents.familiarity_of(&"qingzhu"), 0)
	assert_false(Animals.can_offer("coop"))
	GameState.set_flag(&"lamp_plaza")
	GameState.set_flag(&"lamp_river")
	var saved := GameState.save_data()
	GameState.reset_data()
	GameState.load_data(saved)
	assert_true(Animals.can_offer("coop"), "旧存档广场灯亮着，鸡舍照旧能盖")
	assert_true(Animals.can_offer("silk_house"))
	assert_false(Animals.can_offer("barn"), "畜棚仍要牧野灯")
	assert_false(Animals.can_offer("apiary"))
	var ids := _grocery()
	assert_true(ids.has(&"bait"))
	assert_true(ids.has(&"feed"))
	assert_true(ids.has(&"mulberry_leaf"))
	assert_true(ids.has(&"scarecrow"))


func test_trust_opens_skills_without_lighting_any_lamp() -> void:
	Residents.add_familiarity(&"qingzhu", Residents.TRUST - 1)
	assert_false(Animals.can_offer("coop"), "差 1 点不给盖")
	Residents.add_familiarity(&"qingzhu", 1)
	assert_true(Animals.can_offer("coop"))
	assert_true(Animals.can_offer("silk_house"), "蚕房和青竹熟了就盖，不用等河灯")
	assert_false(Animals.can_offer("barn"))
	assert_false(Animals.can_offer("apiary"))
	assert_false(GameState.has_flag(&"lamp_plaza"), "熟了不等于灯亮了")
	assert_false(GameState.has_flag(&"lamp_river"))
	GameState.money = 100000
	assert_true(Animals.order("coop"))
	assert_true(Animals.order("silk_house"))
	for _i in 3:
		Animals.settle(false)
	assert_false(Animals.sells_kind("chicken"), "鸡舍好了，阿牧还不熟，不卖鸡")
	Residents.add_familiarity(&"amu", Residents.TRUST)
	assert_true(Animals.sells_kind("chicken"))
	assert_true(Animals.sells_kind("duck"))
	assert_true(Animals.sells_kind("silkworm"))
	assert_false(Animals.sells_kind("goat"), "山羊仍要牧野灯")
	assert_false(Animals.sells_kind("bee"))
	var ids := _grocery()
	assert_false(ids.has(&"bait"), "钓鱼还没开，不卖钓具")
	assert_true(ids.has(&"feed"))
	assert_false(ids.has(&"scarecrow"), "稻草人仍等广场灯")
	Residents.add_familiarity(&"laozhou", Residents.TRUST)
	ids = _grocery()
	assert_true(ids.has(&"bait"))
	assert_true(ids.has(&"bobber"))
	assert_true(ids.has(&"crab_trap"))
	assert_false(GameState.has_flag(&"lamp_plaza"))


func test_laozhou_gives_the_rod_once_he_knows_you() -> void:
	var said := await _talk(&"laozhou", "daily")
	assert_false(said.contains("会钓鱼"))
	assert_eq(GameState.inventory.count_of(&"rod"), 0)
	Residents.add_familiarity(&"laozhou", Residents.TRUST)
	said = await _talk(&"laozhou", "daily")
	assert_true(said.contains("会钓鱼"))
	assert_false(said.contains("灯亮了"), "灯没亮，不提灯")
	assert_eq(GameState.inventory.count_of(&"rod"), 1)
	assert_true(GameState.has_flag(&"got_rod"))
	assert_false(GameState.has_flag(&"lamp_plaza"))


func test_the_cowbell_does_not_wait_for_the_river_lamp() -> void:
	Residents.add_familiarity(&"qingzhu", Residents.TRUST)
	Residents.add_familiarity(&"amu", Residents.TRUST)
	GameState.money = 100000
	Animals.order("coop")
	for _i in 3:
		Animals.settle(false)
	assert_true(Animals.buy("chicken"))
	assert_true(Animals.buy("duck"))
	Animals.animals[0]["mood"] = 80
	var said := await _talk(&"amu", "daily")
	assert_true(said.contains("铃没了"))
	assert_true(GameState.has_flag(&"bell_hint"))
	assert_false(GameState.has_flag(&"lamp_river"))
	assert_false(GameState.has_flag(&"lamp_pasture"))


func _grocery() -> Array[StringName]:
	var ids: Array[StringName] = []
	for e in Shop.entries(&"spring", Shop.GROCERY):
		ids.append(e.item_id)
	return ids


func _talk(who: StringName, title: String) -> String:
	var res: Resource = load(Residents.dialogue_path(who))
	var said := ""
	var line: Variant = await DialogueManager.get_next_dialogue_line(res, title)
	while line != null:
		said += str(line.text)
		var next: String = line.next_id
		if next == "end" or next == "":
			break
		line = await DialogueManager.get_next_dialogue_line(res, next)
	return said
