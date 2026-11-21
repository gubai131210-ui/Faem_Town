extends GutTest
## M16 第一批：鱼和花能送，井里的收藏拿给老秦或白鹭看，走近能听见闲聊（决策 133）。


const TMP := "user://test_saves_loose_ends"


func before_each() -> void:
	SaveSystem.base_dir = TMP
	SaveSystem.reset_all()
	Chatter.reset()
	GameClock.day = 4
	GameClock.minutes = 600.0
	GameClock.running = true
	Weather.today = &"sunny"


func after_each() -> void:
	Chatter.reset()
	GameClock.running = false
	SaveSystem.base_dir = "user://saves"
	SaveSystem.reset_all()
	GameClock.day = 1
	GameClock.minutes = 600.0


func test_fish_and_flowers_can_be_given() -> void:
	assert_true(Residents.is_giftable(Database.item(&"crucian")))
	assert_true(Residents.is_giftable(Database.item(&"wintersweet")))
	assert_false(Residents.is_giftable(Database.item(&"hoe")))
	assert_false(Residents.is_giftable(Database.item(&"frog_weight")))
	Residents.met[&"ahe"] = true
	assert_true(Residents.can_gift(&"ahe", Database.item(&"crucian")))
	assert_eq(Residents.give(&"ahe", &"crucian"), &"ok")


func test_a_mine_keepsake_is_shown_once_and_not_taken() -> void:
	var n := 0
	for id: StringName in Database.relics:
		if Database.relic(id).found == &"mine":
			n += 1
	assert_eq(n, 9, "井里的收藏是九件")
	_hold(&"frog_weight")
	Residents.met[&"laoqin"] = true
	watch_signals(EventBus)
	Residents.talk(&"laoqin", false)
	assert_string_contains(str(get_signal_parameters(EventBus, "dialogue_requested")), "mine_frog_weight")
	assert_true(GameState.has_flag(&"shown_laoqin_frog_weight"))
	assert_eq(GameState.inventory.count_of(&"frog_weight"), 1, "看过还在手里")
	Residents.talk(&"laoqin", false)
	assert_false(str(get_signal_parameters(EventBus, "dialogue_requested", 1)).contains("mine_"))
	var said := await _say(Residents.dialogue_path(&"laoqin"), "mine_frog_weight")
	assert_string_contains(said, "镇纸")
	var painted := await _say(Residents.dialogue_path(&"egret"), "mine_frog_weight")
	assert_string_contains(painted, "画不出来")


func test_a_pending_story_line_comes_before_the_keepsake() -> void:
	_hold(&"frog_weight")
	Residents.met[&"egret"] = true
	GameState.set_flag(&"ending_clear")
	watch_signals(EventBus)
	Residents.talk(&"egret", false)
	assert_string_contains(str(get_signal_parameters(EventBus, "dialogue_requested")), "ending_news")
	assert_false(GameState.has_flag(&"shown_egret_frog_weight"))


func test_overhearing_uses_the_pair_and_only_once_a_day() -> void:
	var said := Chatter.line(&"jiang", &"ahe")
	assert_string_contains(said, "招牌")
	assert_string_contains(Chatter.line(&"shishu", &"luyuan"), "锤子")
	assert_string_contains(Chatter.line(&"shishu", &"luyuan"), "手臂")
	assert_eq(Chatter.notice(&"ahe", &"jiang"), said)
	assert_eq(Chatter.notice(&"jiang", &"ahe"), "")
	GameClock.advance_day()
	assert_eq(Chatter.notice(&"ahe", &"jiang"), said)
	var town: OutdoorMap = load("res://maps/town/town.tscn").instantiate()
	add_child_autofree(town)
	town.npcs.clear()
	var a := _npc(&"ahe", Vector2i(2, 2))
	var b := _npc(&"jiang", Vector2i(3, 2))
	a.chat(b, 8.0, 0.0)
	b.chat(a, 8.0, 1.2)
	town.npcs.append(a)
	town.npcs.append(b)
	var who := Node2D.new()
	add_child_autofree(who)
	who.position = (a.position + b.position) * 0.5
	town.player = who
	Chatter.reset()
	watch_signals(EventBus)
	town._overhear()
	assert_string_contains(str(get_signal_parameters(EventBus, "banner_requested")), "招牌")
	town._overhear()
	assert_eq(get_signal_emit_count(EventBus, "banner_requested"), 1, "同一对今天不再说一遍")


func _hold(item_id: StringName) -> void:
	GameState.inventory.clear()
	GameState.inventory.add(item_id, 1)
	GameState.selected_slot = 0


func _npc(id: StringName, tile: Vector2i) -> Npc:
	var npc := Npc.new()
	add_child_autofree(npc)
	npc.setup(Database.npc(id), tile, GameMap.Facing.DOWN)
	npc.set_process(false)
	return npc


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
