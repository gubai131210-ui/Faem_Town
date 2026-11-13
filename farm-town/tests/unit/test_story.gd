extends GutTest
## 第三批：遗物、忆、公告栏委托、广场灯。


func before_each() -> void:
	SaveSystem.reset_all()
	Weather.today = &"sunny"
	GameClock.minutes = 600.0
	GameClock.day = 1


func after_each() -> void:
	SaveSystem.reset_all()


# ---------------------------------------------------------------- 数据表

func test_story_tables_validate() -> void:
	assert_eq(Database.validate().size(), 0, "\n".join(Database.validate()))
	assert_gt(Database.relics.size(), 10)
	assert_eq(Database.memories.size(), 11, "小满以外每位居民都有第一级忆")
	assert_true(Database.quests.size() >= 8)
	assert_true(Database.lamps.has(&"plaza"))


func test_relics_are_items_with_icons() -> void:
	for id: StringName in Database.relics:
		assert_true(Database.has_item(id), "%s 也是一种物品" % id)
		var item := Database.item(id)
		assert_eq(item.kind, &"relic")
		assert_false(item.sellable(), "遗物不能卖")
		assert_false(Residents.is_giftable(item), "遗物不能当礼物送")
		var img := PixelArt.icon(item.icon)
		assert_eq(img.get_width(), 16)
		assert_false(img.get_used_rect().size == Vector2i.ZERO, "%s 的图标不是空的" % id)


func test_memory_and_quest_dialogue_sections_exist() -> void:
	for m in Database.memories:
		var res: Resource = load(Residents.dialogue_path(m.npc))
		var line: Variant = await DialogueManager.get_next_dialogue_line(res, m.dialogue_title())
		assert_not_null(line, "%s 有 %s 段" % [m.npc, m.dialogue_title()])
		if line != null:
			assert_eq(str(line.character), Database.npc(m.npc).name)
	for id: StringName in Database.quests:
		var q := Database.quest(id)
		var res: Resource = load(Residents.dialogue_path(q.npc))
		var line: Variant = await DialogueManager.get_next_dialogue_line(res, q.dialogue_title())
		assert_not_null(line, "%s 有 %s 段" % [q.npc, q.dialogue_title()])
	var common: Resource = load(Residents.COMMON_DIALOGUE)
	for title: String in ["relic_early", "lamp_plaza"]:
		assert_not_null(await DialogueManager.get_next_dialogue_line(common, title), "公共对话有 %s" % title)
	var xiaoman: Resource = load(Residents.dialogue_path(&"xiaoman"))
	assert_not_null(await DialogueManager.get_next_dialogue_line(xiaoman, "prologue"), "小满有序幕")


func test_plaza_lamp_offerings_are_reachable_in_spring() -> void:
	var lamp := Database.lamp(&"plaza")
	for item_id: StringName in lamp.offerings:
		var item := Database.item(item_id)
		var ok := false
		if item.kind == &"crop":
			for crop_id: StringName in Database.crops:
				var crop := Database.crop(crop_id)
				if crop.produce == item_id and crop.can_sow(&"spring"):
					ok = true
		elif item.kind == &"forage":
			for f in Database.forage:
				if f.item == item_id and f.season == &"spring":
					ok = true
		assert_true(ok, "%s 春天就弄得到" % item_id)
	assert_eq(Database.relic(lamp.relic).found, &"quest", "关键遗物是委托给的")
	var from_quest := false
	for id: StringName in Database.quests:
		if Database.quest(id).relic == lamp.relic:
			from_quest = true
	assert_true(from_quest)


# ---------------------------------------------------------------- 灯

func test_lamp_offer_and_light() -> void:
	assert_false(Lamps.is_lit(&"plaza"))
	assert_false(Lamps.is_complete(&"plaza"))
	assert_eq(Lamps.missing(&"plaza", &"white_radish"), 4)
	assert_eq(Lamps.offer(&"plaza", &"white_radish", 6), 4, "多给的不收")
	assert_eq(Lamps.missing(&"plaza", &"white_radish"), 0)
	assert_eq(Lamps.offer(&"plaza", &"white_radish", 1), 0)
	assert_false(Lamps.light(&"plaza"), "供品没齐点不亮")
	Lamps.offer(&"plaza", &"rapeseed", 3)
	Lamps.offer(&"plaza", &"shepherds_purse", 3)
	assert_false(Lamps.is_complete(&"plaza"), "还差关键遗物")
	assert_eq(Lamps.offer(&"plaza", &"old_wick", 1), 1)
	assert_true(Lamps.is_complete(&"plaza"))
	watch_signals(EventBus)
	assert_true(Lamps.light(&"plaza"))
	assert_true(Lamps.is_lit(&"plaza"))
	assert_true(GameState.has_flag(&"lamp_plaza"))
	assert_signal_emitted(EventBus, "lamp_lit")
	assert_false(Lamps.light(&"plaza"), "不能点两次")


func test_lamp_progress_survives_save() -> void:
	Lamps.offer(&"plaza", &"rapeseed", 2)
	var data := Lamps.save_data()
	Lamps.reset_data()
	assert_eq(Lamps.missing(&"plaza", &"rapeseed"), 3)
	Lamps.load_data(data)
	assert_eq(Lamps.missing(&"plaza", &"rapeseed"), 1)


func test_grocery_shelves_fill_up_after_the_lamp() -> void:
	var before := Shop.entries(&"spring", Shop.GROCERY)
	var has_sapling := false
	for e in before:
		if Database.item(e.item_id).kind == &"sapling":
			has_sapling = true
	assert_false(has_sapling, "点灯前不卖树苗")
	GameState.set_flag(&"lamp_plaza")
	var after := Shop.entries(&"spring", Shop.GROCERY)
	assert_gt(after.size(), before.size(), "点灯后货架多了")


# ---------------------------------------------------------------- 委托

func test_board_posts_quests_by_day() -> void:
	var day1 := Quests.posted(1)
	assert_eq(day1.size(), 1)
	assert_eq(day1[0].id, &"jiang_radish")
	assert_eq(Quests.posted(10).size(), Quests.POSTED, "最多贴三张")
	assert_true(Quests.accept(&"jiang_radish"))
	assert_false(Quests.accept(&"jiang_radish"), "不能接两次")
	for q in Quests.posted(10):
		assert_ne(q.id, &"jiang_radish", "接了的不再贴着")


func test_delivering_a_quest_pays_money_relic_and_familiarity() -> void:
	Residents.met[&"jiang"] = true
	Quests.accept(&"jiang_radish")
	GameState.inventory.clear()
	GameState.inventory.add(&"white_radish", 5)
	GameState.selected_slot = 0
	var money := GameState.money
	watch_signals(EventBus)
	Residents.talk(&"jiang", false)
	assert_true(Quests.is_done(&"jiang_radish"))
	assert_eq(GameState.inventory.count_of(&"white_radish"), 2, "收走三个")
	assert_eq(GameState.inventory.count_of(&"old_wick"), 1, "给了旧灯芯")
	assert_eq(GameState.money, money + 80)
	assert_eq(Residents.familiarity_of(&"jiang"), Quests.DELIVER_POINTS)
	assert_signal_emitted_with_parameters(EventBus, "dialogue_requested", [Residents.dialogue_path(&"jiang"), "quest_jiang_radish"])


func test_quest_needs_enough_items_and_a_met_resident() -> void:
	Quests.accept(&"jiang_radish")
	GameState.inventory.clear()
	GameState.inventory.add(&"white_radish", 2)
	GameState.selected_slot = 0
	assert_null(Quests.deliverable(&"jiang", Database.item(&"white_radish"), 2), "两个不够")
	assert_not_null(Quests.deliverable(&"jiang", Database.item(&"white_radish"), 3))
	assert_null(Quests.deliverable(&"ahe", Database.item(&"white_radish"), 9), "不是她的委托")
	watch_signals(EventBus)
	GameState.inventory.add(&"white_radish", 1)
	Residents.talk(&"jiang", false)
	assert_false(Quests.is_done(&"jiang_radish"), "没见过面先打招呼，不交委托")
	assert_signal_emitted_with_parameters(EventBus, "dialogue_requested", [Residents.dialogue_path(&"jiang"), "first"])


func test_quests_survive_save() -> void:
	Quests.accept(&"jiang_radish")
	Quests.deliver(&"jiang_radish")
	Quests.accept(&"ahe_potato")
	var data := Quests.save_data()
	Quests.reset_data()
	Quests.load_data(data)
	assert_true(Quests.is_done(&"jiang_radish"))
	assert_true(Quests.is_active(&"ahe_potato"))


# ---------------------------------------------------------------- 忆

func test_returning_a_relic_needs_full_familiarity() -> void:
	Residents.met[&"ahe"] = true
	GameState.inventory.clear()
	GameState.inventory.add(&"ledger_page", 1)
	GameState.selected_slot = 0
	var page := Database.item(&"ledger_page")
	assert_true(Residents.is_relic_for(&"ahe", page))
	assert_false(Residents.is_relic_for(&"bai", page))
	assert_false(Residents.can_return(&"ahe", page), "熟悉度没满还不到时候")
	watch_signals(EventBus)
	Residents.talk(&"ahe", false)
	assert_signal_emitted_with_parameters(EventBus, "dialogue_requested", [Residents.COMMON_DIALOGUE, "relic_early"])
	assert_eq(GameState.inventory.count_of(&"ledger_page"), 1, "东西还在手里")
	Residents.add_familiarity(&"ahe", 100)
	assert_eq(Residents.familiarity_of(&"ahe"), 100, "上限 100")
	assert_true(Residents.can_return(&"ahe", page))
	Residents.talk(&"ahe", false)
	assert_eq(Residents.memory_level(&"ahe"), 1)
	assert_eq(GameState.inventory.count_of(&"ledger_page"), 0, "遗物交出去了")
	assert_eq(Residents.familiarity_cap(&"ahe"), 200, "忆升一级，熟悉度上限跟着涨")
	assert_signal_emitted_with_parameters(EventBus, "dialogue_requested", [Residents.dialogue_path(&"ahe"), "memory_1"])
	assert_false(Residents.is_relic_for(&"ahe", page), "同一件不能再还")


func test_recovered_memories_are_in_timeline_order_and_saved() -> void:
	assert_eq(Residents.recovered().size(), 0)
	Residents.return_relic(&"luyuan", &"train_ticket")
	Residents.return_relic(&"qingzhu", &"bridge_sketch")
	Residents.return_relic(&"laoqin", &"lamp_hook")
	var list := Residents.recovered()
	assert_eq(list.size(), 3)
	assert_eq(list[0].npc, &"qingzhu", "十年前的排最前")
	assert_eq(list[1].npc, &"laoqin")
	assert_eq(list[2].npc, &"luyuan", "三十年后的排最后")
	var data := Residents.save_data()
	Residents.reset_data()
	Residents.load_data(data)
	assert_eq(Residents.memory_level(&"qingzhu"), 1)
	assert_eq(Residents.recovered().size(), 3)


func test_wrong_level_relic_is_refused() -> void:
	assert_null(Residents.return_relic(&"ahe", &"train_ticket"), "不是她的")
	assert_null(Residents.return_relic(&"ahe", &"old_wick"), "灯芯不属于谁")
	assert_eq(Residents.memory_level(&"ahe"), 0)


func test_greet_counts_as_meeting_once() -> void:
	Residents.greet("xiaoman")
	assert_true(Residents.has_met(&"xiaoman"))
	assert_eq(Residents.familiarity_of(&"xiaoman"), Residents.MEET_POINTS)
	Residents.greet("xiaoman")
	assert_eq(Residents.familiarity_of(&"xiaoman"), Residents.MEET_POINTS, "第二次不再加")


func test_lamp_news_is_told_once() -> void:
	assert_false(Residents.lamp_news("xiaoman", "plaza"), "灯没亮没有新闻")
	GameState.set_flag(&"lamp_plaza")
	assert_true(Residents.lamp_news("xiaoman", "plaza"))
	assert_false(Residents.lamp_news("xiaoman", "plaza"), "说过一次就不说了")
	assert_true(Residents.lamp_news("jiang", "plaza"), "别人还能说")


# ---------------------------------------------------------------- 雾天捡遗物

func test_fog_day_drops_one_undiscovered_relic_on_the_farm() -> void:
	# 不是换季第一天，地上的东西不会被清掉
	GameClock.day = 2
	Weather.today = &"fog"
	Foraging._on_new_day()
	assert_ne(Foraging.pending_relic, &"")
	assert_eq(Database.relic(Foraging.pending_relic).found, &"fog")
	var relic := Foraging.pending_relic
	var land: Array[Vector2i] = [Vector2i(3, 3), Vector2i(4, 3)]
	Foraging.settle(&"farm", land, [])
	assert_eq(Foraging.pending_relic, &"")
	var found := false
	for t in land:
		if Foraging.item_at(&"farm", t) == relic:
			found = true
	assert_true(found, "遗物落到了地上")
	Weather.today = &"fog"
	Foraging._on_new_day()
	assert_ne(Foraging.pending_relic, relic, "躺在地上的不再掉第二件")
	for t in land:
		if Foraging.item_at(&"farm", t) == relic:
			Foraging.take(&"farm", t)
	assert_true(GameState.has_flag(StringName("relic_" + String(relic))), "捡到就记下")
	assert_eq(Foraging.pick_relic(0.0) == relic, false, "捡过的不再掉")


func test_sunny_day_drops_no_relic_and_pool_runs_out() -> void:
	Weather.today = &"sunny"
	Foraging._on_new_day()
	assert_eq(Foraging.pending_relic, &"")
	for id: StringName in Database.relics:
		GameState.set_flag(StringName("relic_" + String(id)))
	assert_eq(Foraging.pick_relic(0.5), &"", "都捡完了就没有了")
