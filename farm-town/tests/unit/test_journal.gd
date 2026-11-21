extends GutTest
## M8 第二批：手账，以及公告栏做完以后的小事。


func before_each() -> void:
	SaveSystem.reset_all()
	GameClock.day = 1
	GameClock.minutes = 600.0


func after_each() -> void:
	SaveSystem.reset_all()


const CutsceneScript := preload("res://game/cutscene.gd")


func test_the_journal_starts_blank_and_only_has_the_lines_that_exist() -> void:
	assert_eq(Journal.page_count(), 8)
	assert_eq(Journal.page_name(0), "灯")
	assert_eq(Journal.page_name(1), "人")
	assert_eq(Journal.page_name(2), "家业")
	assert_eq(Journal.page_name(3), "灶")
	assert_eq(Journal.page_name(4), "食单")
	assert_eq(Journal.page_name(5), "看过")
	assert_eq(Journal.page_name(6), "山海录")
	assert_eq(Journal.page_name(7), "结局")
	for i in Journal.page_count():
		if Journal.page_id(i) == &"endings":
			var shadow := Journal.page_text(i)
			assert_string_contains(shadow, "留…")
			assert_string_contains(shadow, "散…")
			assert_string_contains(shadow, "归…")
			assert_false(shadow.contains("留雾"), "没看过的结局不写全名")
		else:
			assert_eq(Journal.page_text(i), Journal.BLANK)


func test_the_journal_only_writes_what_was_already_said() -> void:
	GameState.set_flag(&"prologue_town")
	var lamps := Journal.page_text(0)
	assert_string_contains(lamps, "灯座")
	assert_false(lamps.contains("河灯"), "还没听说河灯，手账不写")
	assert_string_contains(Journal.page_text(1), "旧东西")
	assert_eq(Journal.page_text(2), Journal.BLANK, "信还没看，家业那一页是空的")
	GameState.set_flag(&"lamp_plaza")
	lamps = Journal.page_text(0)
	assert_string_contains(lamps, "广场灯亮了")
	assert_false(lamps.contains("以前是亮的"), "灯已经亮了，不再把同一句话当线索")
	GameState.set_flag(&"lantern_hint")
	GameState.set_flag(&"bell_hint")
	lamps = Journal.page_text(0)
	assert_string_contains(lamps, "水底")
	assert_false(lamps.contains("花花"), "下一条线索只写最近的那件还没做的事")
	assert_false(lamps.contains("%"))
	assert_false(lamps.contains("/"))


func test_people_and_livelihood_follow_what_happened() -> void:
	GameState.set_flag(&"prologue_town")
	Residents.met[&"ahe"] = true
	Residents.memory_levels[&"ahe"] = 1
	var people := Journal.page_text(1)
	assert_string_contains(people, "阿禾")
	assert_false(people.contains("/"), "不写完成度")
	Residents.memory_levels[&"ahe"] = 0
	Residents.familiarity[&"ahe"] = Residents.familiarity_cap(&"ahe")
	people = Journal.page_text(1)
	assert_string_contains(people, "阿禾熟悉到头了")
	assert_false(people.contains("遗物"), "线索用小满的话，不写成任务")
	GameState.set_flag(&"read_letter")
	GameState.set_flag(&"got_rod")
	var live := Journal.page_text(2)
	assert_string_contains(live, "回来吧")
	assert_string_contains(live, "浮漂")
	GameState.set_flag(&"amu_pasture")
	assert_string_contains(Journal.page_text(2), "畜棚")
	Animals.buildings[&"barn"] = 0
	assert_false(Journal.page_text(2).contains("先找青竹"), "畜棚已经在盖了，这句话就收起来")


func test_a_scrap_half_does_not_name_the_dish() -> void:
	var left := RecipeDef.scrap_item(&"vinegar_napa", 0)
	GameState.inventory.add(left, 1)
	var text := Journal.page_text(3)
	assert_string_contains(text, "半张")
	assert_string_contains(text, "井里")
	assert_false(text.contains("醋溜"), "没看懂之前不写菜名")
	GameState.inventory.add(RecipeDef.scrap_item(&"vinegar_napa", 1), 1)
	assert_string_contains(Journal.page_text(3), "两半")
	assert_eq(Crafting.read_scrap(left), "看懂了：醋溜白菜")
	assert_string_contains(Journal.page_text(3), "醋溜白菜")
	assert_false(Journal.page_text(3).contains("3,"), "不写格子")


func test_the_menu_hides_the_name_until_the_dish_is_made() -> void:
	var ids := Journal.menu_ids()
	assert_false(ids.has(&"odd_bowl"), "试失败的那一碗不上食单")
	assert_eq(ids[0], &"radish_soup")
	assert_true(ids.has(&"herb_tea"))
	var hidden := Journal.menu_line(&"radish_soup")
	assert_string_contains(hidden, "炖")
	assert_string_contains(hidden, "春天")
	assert_false(hidden.contains("萝卜"), "没做过不写菜名")
	assert_false(Journal.menu_line(&"herb_tea").contains("药"), "忆里的菜没做过也不写名字")
	assert_string_contains(Journal.menu_line(&"pea_egg"), "惊蛰")
	assert_false(Journal.menu_line(&"pea_egg").contains("豌豆"))
	Crafting.mark_cooked(&"fried_egg")
	assert_eq(Journal.menu_line(&"fried_egg"), "煎蛋")
	var roster := ResidentsPanel.new()
	add_child_autofree(roster)
	roster.open()
	roster._page = ResidentsPanel.PAGE_JOURNAL
	roster._journal_cursor = 4
	roster._refresh()
	assert_false(roster._journal_text.visible)
	assert_true(roster._menu_root.visible)
	var dim: TextureRect = roster._menu_cells[0].get_node("Icon")
	var bright: TextureRect = roster._menu_cells[ids.find(&"fried_egg")].get_node("Icon")
	assert_eq(dim.modulate, Color(0.72, 0.62, 0.5))
	assert_eq(bright.modulate, Color.WHITE)
	assert_false(roster._menu_line.text.contains("萝卜"))
	roster._move(1)
	assert_eq(roster._journal_cursor, 4, "食单里上下是在选菜，不是翻页")
	assert_eq(roster._menu_cursor, 1)


func test_the_morning_hint_is_said_once_after_the_first_night() -> void:
	assert_eq(Journal.morning_line(), "")
	assert_false(GameState.has_flag(Journal.HINT_FLAG))
	GameClock.day = 2
	assert_eq(Journal.morning_line(), Journal.HINT)
	assert_true(GameState.has_flag(Journal.HINT_FLAG))
	assert_eq(Journal.morning_line(), "", "只说一次")


func test_errands_wait_until_the_board_is_clear_and_do_not_expire() -> void:
	assert_gt(Database.errands.size(), 0)
	assert_eq(Database.validate().size(), 0, "\n".join(Database.validate()))
	Quests.accept(&"jiang_radish")
	GameClock.advance_day()
	assert_null(Quests.errand, "正事还在，不贴小事")
	_finish_the_board()
	assert_null(Quests.errand, "做完的当天不贴，等下一个早上")
	Residents.met[&"jiang"] = true
	GameClock.advance_day()
	assert_not_null(Quests.errand)
	assert_false(Quests.errand_taken)
	assert_eq(Quests.errand.npc, &"jiang", "只见过姜婆婆，小事就是她的")
	assert_eq(Quests.errand.item, &"crucian")
	assert_eq(Quests.posted(GameClock.day).size(), 0, "小事不占那八张的位置")
	var item := Quests.errand.item
	var count := Quests.errand.count
	for _i in 5:
		GameClock.advance_day()
	assert_false(Quests.errand_taken)
	assert_eq(Quests.errand.item, item, "放着不做也不会过期")
	assert_eq(Quests.errand.count, count)


func test_delivering_an_errand_pays_and_the_next_one_waits() -> void:
	Residents.met[&"jiang"] = true
	_finish_the_board()
	GameClock.advance_day()
	assert_true(Quests.accept(Quests.ERRAND_ID))
	assert_false(Quests.accept(Quests.ERRAND_ID), "不能接两次")
	GameState.inventory.clear()
	GameState.inventory.add(Quests.errand.item, Quests.errand.count)
	GameState.selected_slot = 0
	var money := Quests.errand.money
	var before := GameState.money
	watch_signals(EventBus)
	Residents.talk(&"jiang", false)
	assert_null(Quests.errand)
	assert_false(Quests.is_done(Quests.ERRAND_ID))
	assert_eq(GameState.money, before + money)
	assert_eq(GameState.inventory.count_of(&"crucian"), 0)
	assert_eq(Residents.familiarity_of(&"jiang"), Quests.ERRAND_POINTS)
	assert_signal_emitted_with_parameters(EventBus, "dialogue_requested", [Residents.COMMON_DIALOGUE, "errand"])
	GameClock.advance_day()
	GameClock.advance_day()
	assert_null(Quests.errand, "隔够了天才贴下一张")
	GameClock.advance_day()
	assert_not_null(Quests.errand)


func test_an_errand_survives_save_and_old_saves_still_load() -> void:
	Residents.met[&"jiang"] = true
	_finish_the_board()
	GameClock.advance_day()
	var item := Quests.errand.item
	assert_true(Quests.accept(Quests.ERRAND_ID))
	var data := Quests.save_data()
	Quests.reset_data()
	Quests.load_data(data)
	assert_true(Quests.errand_taken)
	assert_eq(Quests.errand.item, item)
	Quests.load_data({"active": ["jiang_radish"], "done": ["ahe_potato"]})
	assert_null(Quests.errand, "没有小事字段的旧存档读出来是空的")
	assert_true(Quests.is_active(&"jiang_radish"))
	assert_true(Quests.is_done(&"ahe_potato"))


func test_seen_cutscenes_list_in_order_and_replay_does_not_touch_state() -> void:
	assert_eq(Journal.seen_id(0), &"")
	GameState.set_flag(CutsceneScript.seen_flag(&"memory_ahe"))
	GameState.set_flag(CutsceneScript.seen_flag(&"opening"))
	GameState.set_flag(CutsceneScript.seen_flag(&"fest_sowing_y1"))
	GameState.set_flag(CutsceneScript.seen_flag(&"memory_lan"))
	var lines := Journal.seen_lines()
	assert_eq(lines.size(), 3, "岚的五级忆不进名单")
	assert_eq(lines[0], "开场")
	assert_string_contains(lines[1], "阿禾")
	assert_string_contains(lines[2], "播种节")
	assert_string_contains(lines[2], "第1年")
	assert_eq(Journal.seen_id(0), &"opening")
	assert_eq(CutsceneScript.replay_steps(&"opening").size(), 4)
	assert_eq(CutsceneScript.replay_steps(&"memory_ahe").size(), 2)
	assert_eq(CutsceneScript.replay_steps(&"fest_sowing_y1").size(), 1)
	assert_eq(CutsceneScript.replay_steps(&"ending_keep").size(), 5)
	assert_eq(CutsceneScript.replay_steps(&"nope").size(), 0)
	assert_false(GameState.has_flag(CutsceneScript.seen_flag(&"ending_keep")), "重看排步骤不记新的看过")
	var roster := ResidentsPanel.new()
	add_child_autofree(roster)
	roster.open()
	roster._page = ResidentsPanel.PAGE_JOURNAL
	roster._journal_cursor = 5
	roster._refresh()
	assert_string_contains(roster._journal_text.text, "▸ 开场")
	roster._move(1)
	assert_string_contains(roster._journal_text.text, "▸ ")
	assert_string_contains(roster._journal_text.text, "阿禾")
	var got: Array[StringName] = []
	var cb := func(id: StringName) -> void: got.append(id)
	EventBus.cutscene_replay_requested.connect(cb)
	assert_true(roster._replay_selected())
	EventBus.cutscene_replay_requested.disconnect(cb)
	assert_eq(got[0], &"memory_ahe")
	assert_false(roster._root.visible)
	for who in ["egret", "qingzhu", "shishu", "amu", "laozhou", "yunniang", "bai", "luyuan", "laoqin"]:
		GameState.set_flag(CutsceneScript.seen_flag(StringName("memory_" + who)))
	roster.open()
	roster._page = ResidentsPanel.PAGE_JOURNAL
	roster._journal_cursor = 5
	roster._seen_cursor = Journal.seen_lines().size() - 1
	roster._refresh()
	assert_string_contains(roster._journal_text.text, "▸ ")
	assert_string_contains(roster._journal_text.text, "老秦")
	assert_false(roster._journal_text.text.contains("开场"), "选到末尾时，开头那几条让出位置")


func test_the_roster_turns_to_the_journal() -> void:
	var roster := ResidentsPanel.new()
	add_child_autofree(roster)
	roster.open()
	roster._page = ResidentsPanel.PAGE_JOURNAL
	roster._refresh()
	assert_eq(roster._head.text, "手账")
	assert_true(roster._journal.visible)
	assert_false(roster._fishbook.visible)
	assert_string_contains(roster._journal_text.text, "空白")


func test_the_board_shows_the_errand_first() -> void:
	_finish_the_board()
	GameClock.advance_day()
	var panel := BoardPanel.new()
	add_child_autofree(panel)
	panel.open()
	assert_eq(panel._states[0], "posted")
	assert_eq(panel._list[0].id, Quests.ERRAND_ID)
	assert_false(panel._list[0].title.is_empty())


func _finish_the_board() -> void:
	for id: StringName in Database.quests:
		if not Quests.is_done(id):
			Quests.accept(id)
			Quests.deliver(id)
