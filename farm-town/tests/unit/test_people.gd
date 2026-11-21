extends GutTest
## M15 第一批：结局簿、三段小结、十一位忆满以后镇上的变化（决策 130）。


const TMP := "user://test_saves_people"


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


func test_unseen_endings_keep_only_a_shadow_of_the_name() -> void:
	var text := Journal.page_text(7)
	assert_eq(Journal.page_name(7), "结局")
	assert_string_contains(text, "留…")
	assert_false(text.contains("留雾"))
	assert_eq(Journal.ending_replay(0), &"")
	GameState.set_flag(&"ending_keep")
	assert_string_contains(Journal.page_text(7), "留雾")
	assert_false(Journal.page_text(7).contains("散雾"), "另外两个还是影子")
	assert_eq(Journal.ending_replay(0), &"ending_keep")
	assert_eq(Journal.ending_replay(1), &"")


func test_a_full_span_is_said_once() -> void:
	Residents.met[&"xiaoman"] = true
	Residents.memory_levels[&"laozhou"] = 5
	Residents.memory_levels[&"yunniang"] = 5
	assert_false(PeopleLine.full(&"year"), "柏先生那几段还没齐")
	Residents.memory_levels[&"bai"] = 5
	assert_true(PeopleLine.full(&"year"))
	assert_false(PeopleLine.full(&"morning"), "老秦那天早上的还没齐")
	assert_eq(Residents.title_for(&"xiaoman", false), "span_year")
	assert_string_contains(Journal.page_text(1), "出事前一年")
	var last := Database.memory(&"bai", 5)
	assert_string_contains(PeopleLine.note_for(last), "码头")
	Residents._chat(&"xiaoman", false)
	assert_true(PeopleLine.said(&"year"))
	assert_ne(Residents.title_for(&"xiaoman", false), "span_year")
	var said := await _say(Residents.dialogue_path(&"xiaoman"), "span_year")
	assert_string_contains(said, "云娘的歌")
	var morning := await _say(Residents.dialogue_path(&"bai"), "span_morning")
	assert_string_contains(morning, "二十八只钩")


func test_five_memories_change_the_place_you_can_see() -> void:
	var town := _map(&"town")
	assert_string_contains(town._sign_at(Vector2i(8, 17)), "杂货铺")
	assert_string_contains(town._sign_at(Vector2i(34, 8)), "擦了又写")
	GameState.set_flag(&"lamp_plaza")
	Residents.memory_levels[&"ahe"] = 5
	Residents.memory_levels[&"yunniang"] = 5
	var lit: OutdoorMap = _map(&"town")
	assert_string_contains(lit._sign_at(Vector2i(8, 17)), "禾记")
	assert_string_contains(lit._sign_at(Vector2i(34, 8)), "唱完")
	var houses: Array = lit.get("_houses")
	var grocery: Node = houses[3]
	var sign: Sprite2D = grocery.get_node("GrocerySign")
	var img := (sign.texture as ImageTexture).get_image()
	assert_gt(img.get_width(), 16, "禾记比原来的米宽")
	var tea: Node = houses[2]
	var slip: Sprite2D = tea.get_node("SongSlip")
	assert_true(slip.visible)
	Residents.memory_levels[&"qingzhu"] = 5
	var stream: OutdoorMap = _map(&"nanxi")
	var bridge := Vector2i(-1, -1)
	var tiles: Array = stream._bridge_tiles()
	for i in tiles.size():
		var t: Vector2i = tiles[i]
		if stream.query_use(null, t, GameMap.Facing.UP) == &"interact":
			bridge = t
			break
	assert_ne(bridge, Vector2i(-1, -1), "桥上有一处能看那颗钉")
	watch_signals(EventBus)
	stream.perform(&"interact", null, bridge)
	assert_string_contains(str(get_signal_parameters(EventBus, "banner_requested")), "钉")
	Residents.memory_levels[&"luyuan"] = 5
	var lane: OutdoorMap = _map(&"lane")
	var stele: String = lane.clue_at(Vector2i(12, 10))
	assert_string_contains(stele, "秦")
	assert_string_contains(stele, "父亲")
	assert_false(stele.contains("禾娘"), "碑上不补新的名字")
	assert_not_null(lane.get_node_or_null("SteleCloth"))
	Residents.memory_levels[&"laozhou"] = 5
	var wharf: OutdoorMap = _map(&"wharf")
	assert_string_contains(wharf._look(Vector2i(8, 4)), "阿海")
	Residents.memory_levels[&"egret"] = 5
	var beach: OutdoorMap = _map(&"dongtan")
	assert_string_contains(beach.clue_at(Vector2i(15, 9)), "还没走通")
	Residents.memory_levels[&"amu"] = 5
	var pasture: OutdoorMap = _map(&"pasture")
	assert_string_contains(pasture._returned_text(Vector2i(7, 13)), "大黄")
	assert_not_null(pasture.get_node_or_null("DogTag"))
	Residents.memory_levels[&"jiang"] = 5
	GameState.set_flag(&"read_letter")
	var farm: OutdoorMap = _map(&"farm")
	farm._use_mailbox()
	assert_string_contains(str(get_signal_parameters(EventBus, "banner_requested", 1)), "阿芸")


func _map(id: StringName) -> OutdoorMap:
	var scene: PackedScene = load(SceneRouter.MAPS[id])
	var map: OutdoorMap = scene.instantiate()
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
