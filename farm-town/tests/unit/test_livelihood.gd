extends GutTest
## 家业线：六个行当的条件、师傅的话、看得见的变化（决策 131）。


const TMP := "user://test_saves_livelihood"


func before_each() -> void:
	SaveSystem.base_dir = TMP
	SaveSystem.reset_all()
	GameClock.day = 10
	GameClock.minutes = 600.0
	Weather.today = &"sunny"


func after_each() -> void:
	SaveSystem.base_dir = "user://saves"
	SaveSystem.reset_all()
	GameClock.day = 1
	GameClock.minutes = 600.0


func test_a_trade_is_told_one_level_at_a_time() -> void:
	Residents.met[&"ahe"] = true
	Shipping.add(&"white_radish", 1, 2)
	Shipping.add(&"potato", 1, 2)
	Shipping.add(&"egg", 1, 2)
	Shipping.settle()
	assert_eq(Shipping.gold_crops.size(), 2, "鸡蛋不是作物")
	assert_eq(Livelihood.ready(&"farm"), 1)
	assert_eq(Livelihood.told(&"farm"), 0)
	assert_eq(Residents.title_for(&"ahe", true), "trade_farm_1")
	Residents._chat(&"ahe", true)
	assert_eq(Livelihood.told(&"farm"), 1)
	assert_eq(Livelihood.pending_title(&"ahe"), "")
	assert_eq(Livelihood.energy_cut(&"hoe"), 1)
	assert_eq(Livelihood.energy_cut(&"water"), 0)
	var said := await _say(Residents.dialogue_path(&"ahe"), "trade_farm_1")
	assert_string_contains(said, "磨轻")
	for id: StringName in Database.items:
		if Database.item(id).kind != &"crop" or Shipping.gold_crops.has(id):
			continue
		Shipping.gold_crops.append(id)
		if Shipping.gold_crops.size() >= 12:
			break
	assert_eq(Livelihood.ready(&"farm"), 3)
	assert_eq(Livelihood.pending_level(&"farm"), 2, "不能从一级跳到三级")
	var saved := Shipping.save_data()
	Shipping.reset_data()
	Shipping.load_data(saved)
	assert_eq(Shipping.gold_crops.size(), 12)
	var farm := _map(&"farm")
	assert_not_null(farm.get_node_or_null("FarmStake"))
	watch_signals(EventBus)
	farm._use_bin(null)
	assert_string_contains(str(get_signal_parameters(EventBus, "banner_requested")), "界桩")
	assert_string_contains(Journal.page_text(2), "种田，一级")


func test_the_other_trades_use_records_that_already_exist() -> void:
	Fishing.record(&"crucian", 12)
	Fishing.record(&"carp", 20)
	Fishing.record(&"loach", 10)
	Residents.met[&"laozhou"] = true
	assert_eq(Residents.title_for(&"laozhou", false), "trade_fish_1")
	Residents._chat(&"laozhou", false)
	assert_eq(Livelihood.fish_wait_mult(), 1.0, "一级只省甩竿的力气")
	assert_eq(Livelihood.energy_cut(&"cast"), 1)
	var more: Array[StringName] = [&"perch", &"catfish", &"mandarin_fish", &"grass_carp", &"black_carp"]
	for id in more:
		Fishing.record(id, 10)
	assert_eq(Livelihood.pending_level(&"fish"), 2)
	Residents._chat(&"laozhou", false)
	assert_almost_eq(Livelihood.fish_wait_mult(), 0.85, 0.001)
	var wharf := _map(&"wharf")
	assert_not_null(wharf.get_node_or_null("FishBobber"))
	assert_string_contains(wharf._look(Vector2i(8, 4)), "浮子")
	Animals.raised.append(&"chicken")
	Residents.met[&"amu"] = true
	Residents._chat(&"amu", false)
	Animals.animals.append({"kind": &"chicken", "name": "咕咕", "mood": 60, "fed": false, "petted": false, "days": 0, "work": 0})
	assert_true(Animals.pet(0))
	assert_eq(Animals.mood_of(0), 70, "原来加 8，养殖一级再加 2")
	Mine.deepest = 5
	Residents.met[&"shishu"] = true
	Residents.met[&"laoqin"] = true
	assert_eq(Residents.title_for(&"shishu", false), "trade_mine_1")
	Residents._chat(&"shishu", false)
	assert_eq(Livelihood.pending_title(&"laoqin"), "")
	assert_eq(Livelihood.energy_cut(&"mine"), 1)
	Mine.deepest = 30
	GameState.upgrade_tool(&"pickaxe")
	GameState.upgrade_tool(&"pickaxe")
	assert_eq(Livelihood.pending_level(&"mine"), 2)
	Foraging.items[&"farm"] = {Vector2i(2, 2): &"mint"}
	assert_eq(Foraging.take(&"farm", Vector2i(2, 2)), &"mint")
	assert_true(Foraging.found.has(&"mint"))
	Foraging.found.append(&"fern")
	Foraging.found.append(&"chestnut")
	Residents.met[&"jiang"] = true
	Residents._chat(&"jiang", false)
	GameState.energy = 40
	var town := _map(&"town")
	assert_string_contains(town._sign_at(Vector2i(7, 8)), "篮子")
	assert_string_contains(town._sign_at(Vector2i(8, 17)), "杂货铺", "杂货铺的墙不写采集")
	town.perform(&"interact", null, Vector2i(7, 8))
	assert_eq(GameState.energy, 44)
	town.perform(&"interact", null, Vector2i(7, 8))
	assert_eq(GameState.energy, 44, "同一天只续一口")
	var houses: Array = town.get("_houses")
	var herb: Node = houses[1]
	assert_not_null(herb.get_node_or_null("HerbBasket"))
	Crafting.rank = &"helper"
	assert_eq(Livelihood.told(&"stove"), 1)
	assert_eq(Livelihood.pending_title(&"yunniang"), "")
	assert_string_contains(Journal.page_text(2), "灶台，一级")
	assert_string_contains(Livelihood.year_line(), "钓鱼到二级")
	assert_string_contains(Livelihood.year_line(), "灶台到一级")
	var house := _map(&"farmhouse")
	assert_not_null(house.get_node_or_null("WokSpoon"))
	GameState.set_flag(&"trade_mine_2")
	GameState.set_flag(&"trade_mine_3")
	assert_eq(Livelihood.energy_cut(&"dig"), 1)
	assert_almost_eq(Livelihood.fish_wait_mult(), 0.85, 0.001)


func _map(id: StringName) -> Node:
	var scene: PackedScene = load(SceneRouter.MAPS[id])
	var map: Node = scene.instantiate()
	add_child_autofree(map)
	return map


func _say(path: String, title: String) -> String:
	var res: Resource = load(path)
	var said := ""
	var line: Variant = await DialogueManager.get_next_dialogue_line(res, title)
	while line != null:
		said += str(line.text)
		var next: String = line.next_id
		if next == "end" or next == "":
			break
		line = await DialogueManager.get_next_dialogue_line(res, next)
	return said
