extends GutTest
## 四个支线结局：团圆饭、山海有名、家业、远行。不覆盖留雾、散雾、归名（决策 132、137）。


const CutsceneScript := preload("res://game/cutscene.gd")


const TMP := "user://test_saves_side_endings"


var _endings: Array[StringName] = []


func before_each() -> void:
	SaveSystem.base_dir = TMP
	SaveSystem.reset_all()
	GameClock.day = 10
	GameClock.minutes = 600.0
	Weather.today = &"sunny"
	_endings.clear()
	EventBus.ending_requested.connect(_on_ending)


func after_each() -> void:
	EventBus.ending_requested.disconnect(_on_ending)
	SaveSystem.base_dir = "user://saves"
	SaveSystem.reset_all()
	GameClock.day = 1
	GameClock.minutes = 600.0


func _on_ending(ending: StringName) -> void:
	_endings.append(ending)


func test_the_feast_uses_the_mine_list_and_does_not_replace_the_old_ending() -> void:
	assert_false(Story.side_ready(Story.FEAST))
	Crafting.sets.append(&"terms")
	Crafting.sets.append(&"homes")
	assert_false(Story.side_ready(Story.FEAST), "还没下过井")
	GameState.set_flag(&"relic_miner_roster")
	assert_true(Story.side_ready(Story.FEAST))
	Residents.met[&"yunniang"] = true
	assert_eq(Residents.title_for(&"yunniang", true), "side_feast")
	var said := await _say(Residents.dialogue_path(&"yunniang"), "side_feast")
	assert_string_contains(said, "二十八")
	assert_eq(_endings, [Story.FEAST])
	assert_false(Story.side_ready(Story.FEAST))
	GameState.set_flag(&"ending_clear")
	assert_eq(Story.ending(), Story.CLEAR, "团圆饭不改原来点过的灯")
	assert_string_contains(Journal.page_text(7), "团圆饭")
	assert_string_contains(Journal.page_text(7), "山…")
	assert_string_contains(Journal.page_text(7), "家…")
	assert_eq(CutsceneScript.ending_steps(Story.FEAST).size(), 4)
	assert_eq(CutsceneScript.picture(&"end_seats").get_width(), 192)


func test_the_named_ending_needs_every_beast_and_the_list() -> void:
	GameState.set_flag(&"relic_miner_roster")
	assert_false(Story.side_ready(Story.NAMED))
	for id: StringName in Bestiary.IDS:
		Bestiary.see(id)
	assert_eq(Bestiary.IDS.size(), 16)
	assert_true(Story.side_ready(Story.NAMED))
	var hill := _map(&"houshan")
	watch_signals(EventBus)
	hill.perform(&"interact", null, Vector2i(16, 3))
	var params: Array = get_signal_parameters(EventBus, "dialogue_requested")
	assert_string_contains(str(params), "offer_named")
	var said := await _say(Story.DIALOGUE, "offer_named")
	assert_string_contains(said, "白泽")
	assert_eq(_endings, [Story.NAMED])
	assert_eq(CutsceneScript.picture(&"end_names").get_width(), 192)


func test_the_estate_hangs_a_plaque_and_a_letter_arrives() -> void:
	for id: StringName in [&"fish", &"herd", &"mine", &"pick"]:
		for n in [1, 2, 3]:
			GameState.set_flag(StringName("trade_%s_%d" % [id, n]))
	Crafting.rank = &"master"
	GameState.set_flag(&"trade_farm_1")
	GameState.set_flag(&"trade_farm_2")
	for id: StringName in Database.items:
		if Database.item(id).kind != &"crop":
			continue
		if Shipping.gold_crops.has(id):
			continue
		Shipping.gold_crops.append(id)
		if Shipping.gold_crops.size() >= 12:
			break
	Residents.met[&"ahe"] = true
	assert_eq(Residents.title_for(&"ahe", false), "trade_farm_3")
	Residents._chat(&"ahe", false)
	assert_eq(_endings, [Story.ESTATE])
	assert_eq(Story.ending(), &"", "家业不是留雾那三个里的一个")
	var farm := _map(&"farm")
	var house := farm.find_child("House", true, false)
	assert_not_null(house, "农场的房子还在")
	assert_not_null(house.get_node_or_null("EstatePlaque"))
	GameState.set_flag(&"read_letter")
	watch_signals(EventBus)
	farm.call("_use_mailbox")
	assert_string_contains(str(get_signal_parameters(EventBus, "banner_requested")), "还能去吗")
	farm.call("_use_mailbox")
	assert_string_contains(str(get_signal_parameters(EventBus, "banner_requested", 1)), "信箱是空的")
	var art := EndingArt.plaque()
	assert_eq(art.get_width(), 30)
	assert_gt(art.get_pixel(8, 4).r, 0.0)


func test_the_voyage_leaves_the_half_ticket_and_does_not_replace_the_lamp() -> void:
	var before := _map(&"dongtan")
	assert_eq(_find_stub(before), Vector2i(-1, -1), "还没远行，码头上没有这半张")
	assert_false(Story.side_ready(Story.VOYAGE))
	GameState.set_flag(&"memory_jiang_5")
	GameState.set_flag(&"got_ferry_stub")
	assert_false(Story.side_ready(Story.VOYAGE), "东边的灯还没亮")
	GameState.set_flag(&"lamp_east")
	assert_true(Story.side_ready(Story.VOYAGE))
	Residents.met[&"jiang"] = true
	assert_eq(Residents.title_for(&"jiang", false), "side_voyage")
	var said := await _say(Residents.dialogue_path(&"jiang"), "side_voyage")
	assert_string_contains(said, "另外半张")
	assert_string_contains(said, "阿芸")
	assert_string_contains(said, "空的")
	assert_eq(_endings, [Story.VOYAGE])
	Story.begin_side("voyage")
	assert_eq(_endings.size(), 1, "看过就不再演一次")
	assert_false(Story.side_ready(Story.VOYAGE))
	assert_eq(Story.ending(), &"", "远行不改留雾、散雾、归名")
	assert_false(Story.lamp_lit())
	assert_false(Story.owes_news(&"jiang"))
	GameState.set_flag(&"ending_clear")
	assert_eq(Story.ending(), Story.CLEAR)
	assert_string_contains(Journal.page_text(7), "远行")
	assert_false(Journal.page_text(7).contains("留雾"))
	assert_eq(Journal.page_count(), 8)
	assert_eq(CutsceneScript.ending_steps(Story.VOYAGE).size(), 4)
	var stub: Image = CutsceneScript.picture(&"end_stub")
	assert_eq(stub.get_width(), 192)
	var red := 0
	var paper := 0
	for y in range(0, stub.get_height(), 2):
		for x in range(0, stub.get_width(), 2):
			var px: Color = stub.get_pixel(x, y)
			if px.r > 0.7 and px.g < 0.4 and px.b < 0.4:
				red += 1
			if px.r > 0.9 and px.g > 0.85 and px.b > 0.75:
				paper += 1
	assert_gt(red, 2, "半张票上有一道红线")
	assert_gt(paper, 8, "票是浅色的纸")
	var bare: Image = CutsceneArt.at(&"end_dock", 1.0, 2.6)
	var full: Image = CutsceneScript.picture(&"end_dock")
	var changed := 0
	for y in range(0, bare.get_height(), 2):
		for x in range(0, bare.get_width(), 2):
			if bare.get_pixel(x, y) != full.get_pixel(x, y):
				changed += 1
	assert_gt(changed, 20, "人和姜婆婆是贴上去的")
	var card: Image = EndingArt.scene(Story.VOYAGE)
	var mark: Color = card.get_pixel(44, 74)
	assert_gt(mark.r, 0.7, "亮名字时岸上有那半张票")
	assert_lt(mark.g, 0.4)
	var beach := _map(&"dongtan")
	var found := _find_stub(beach)
	assert_ne(found, Vector2i(-1, -1), "东滩桩上钉着这半张")
	assert_ne(found, beach.call("boat_tile"), "不挡去雾岛的那条船")
	assert_eq(beach.call("query_use", null, found, GameMap.Facing.DOWN), &"interact")
	assert_string_contains(str(beach.call("departure", beach.call("boat_tile"))), "wudao")


func _find_stub(beach: Node) -> Vector2i:
	for y in 30:
		for x in 44:
			var tile := Vector2i(x, y)
			if str(beach.call("clue_at", tile)).contains("船票"):
				return tile
	return Vector2i(-1, -1)


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
