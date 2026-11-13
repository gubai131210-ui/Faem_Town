extends GutTest
## M2 第二批：喜好、送礼、熟悉度、名册。

const TMP_SAVES := "user://test_saves"

var _old_dir := ""


func before_each() -> void:
	_old_dir = SaveSystem.base_dir
	SaveSystem.base_dir = TMP_SAVES
	SaveSystem.reset_all()


func after_each() -> void:
	for i in SaveSystem.SLOT_COUNT:
		SaveSystem.delete(i)
	SaveSystem.base_dir = _old_dir
	SaveSystem.current_slot = -1
	SaveSystem.reset_all()


## 把背包清空，手里只拿 count 个 item_id。
func _hold(item_id: StringName, count: int = 1, quality: int = 0) -> void:
	GameState.inventory.clear()
	GameState.inventory.add(item_id, count, quality)
	GameState.selected_slot = 0


func test_taste_of() -> void:
	var def := Database.npc(&"xiaoman")
	assert_eq(def.taste_of(&"strawberry"), &"love")
	assert_eq(def.taste_of(&"peach"), &"like")
	assert_eq(def.taste_of(&"fern"), &"dislike")
	assert_eq(def.taste_of(&"potato"), &"ok")


func test_every_resident_has_tastes() -> void:
	for id: StringName in Database.npcs:
		var def := Database.npc(id)
		assert_gt(def.loves.size(), 0, "%s 有最喜欢的东西" % id)
		assert_gt(def.likes.size(), 0, "%s 有喜欢的东西" % id)
		assert_gt(def.dislikes.size(), 0, "%s 有不喜欢的东西" % id)
		for item_id in def.loves + def.likes + def.dislikes:
			assert_true(Residents.is_giftable(Database.item(item_id)), "%s 的喜好 %s 是能送的东西" % [id, item_id])


func test_validate_catches_bad_tastes() -> void:
	var bad := NpcDef.from_dict({
		"id": "tester", "name": "测试", "sheet": "ahe", "enter": {"town": [3, 4]},
		"loves": ["moon_rock", "potato"], "likes": ["potato"],
		"schedule": [{"from": "8:00", "map": "town", "tile": [5, 6]}],
	})
	var text := "\n".join(Database.validate_npc(bad))
	assert_string_contains(text, "不存在的物品")
	assert_string_contains(text, "出现了两次")


func test_what_can_be_given() -> void:
	assert_true(Residents.is_giftable(Database.item(&"potato")))
	assert_true(Residents.is_giftable(Database.item(&"mint")))
	assert_false(Residents.is_giftable(Database.item(&"hoe")))
	assert_false(Residents.is_giftable(Database.item(&"potato_seed")))
	assert_false(Residents.is_giftable(Database.item(&"fertilizer")))
	assert_false(Residents.is_giftable(null))
	assert_false(Residents.can_gift(&"ahe", Database.item(&"potato")), "没见过面不能送")
	Residents.met[&"ahe"] = true
	assert_true(Residents.can_gift(&"ahe", Database.item(&"potato")))
	Residents.give(&"ahe", &"potato")
	assert_false(Residents.can_gift(&"ahe", Database.item(&"potato")), "一天只能送一次")
	GameClock.advance_day()
	assert_true(Residents.can_gift(&"ahe", Database.item(&"potato")), "第二天又能送")


func test_talking_builds_familiarity_once_a_day() -> void:
	_hold(&"hoe")
	Residents.talk(&"jiang", false)
	assert_eq(Residents.familiarity_of(&"jiang"), Residents.MEET_POINTS, "第一次见面")
	Residents.talk(&"jiang", false)
	assert_eq(Residents.familiarity_of(&"jiang"), Residents.MEET_POINTS, "当天再说不加")
	GameClock.advance_day()
	Residents.talk(&"jiang", false)
	Residents.talk(&"jiang", false)
	assert_eq(Residents.familiarity_of(&"jiang"), Residents.MEET_POINTS + Residents.TALK_POINTS, "每天第一次说话加一回")


func test_gift_points_by_taste_and_quality() -> void:
	assert_eq(Residents.give(&"xiaoman", &"strawberry"), &"love")
	assert_eq(Residents.familiarity_of(&"xiaoman"), 40)
	assert_eq(Residents.give(&"ahe", &"corn", 2), &"like")
	assert_eq(Residents.familiarity_of(&"ahe"), 20 + 2 * Residents.QUALITY_BONUS, "优品多加一点")
	assert_eq(Residents.give(&"shishu", &"bok_choy"), &"ok")
	assert_eq(Residents.familiarity_of(&"shishu"), 10)
	Residents.add_familiarity(&"jiang", 30)
	assert_eq(Residents.give(&"jiang", &"chili", 2), &"dislike")
	assert_eq(Residents.familiarity_of(&"jiang"), 15, "不喜欢的东西品质再好也扣")
	assert_eq(Residents.give(&"bai", &"pine_cone"), &"dislike")
	assert_eq(Residents.familiarity_of(&"bai"), 0, "不会扣成负数")


func test_familiarity_stops_at_the_cap() -> void:
	for i in 5:
		Residents.give(&"xiaoman", &"strawberry")
	assert_eq(Residents.familiarity_of(&"xiaoman"), Residents.familiarity_cap(&"xiaoman"))
	assert_eq(Residents.familiarity_cap(&"xiaoman"), Residents.STEP, "还没有忆的时候最多一级的量")


func test_known_tastes_are_remembered() -> void:
	Residents.give(&"xiaoman", &"strawberry")
	Residents.give(&"xiaoman", &"fern")
	assert_eq(Residents.known(&"xiaoman", &"love"), [&"strawberry"] as Array[StringName])
	assert_eq(Residents.known(&"xiaoman", &"dislike"), [&"fern"] as Array[StringName])
	assert_eq(Residents.known(&"xiaoman", &"like").size(), 0)
	assert_eq(Residents.known(&"ahe", &"love").size(), 0)


## 拿着能送的东西搭话：先问要不要送，选“送”以后东西少一个，接着是对方的反应。
func test_offer_then_give() -> void:
	Residents.met[&"xiaoman"] = true
	_hold(&"strawberry", 2)
	watch_signals(EventBus)
	Residents.talk(&"xiaoman", false)
	assert_signal_emitted_with_parameters(EventBus, "dialogue_requested", [Residents.COMMON_DIALOGUE, "gift_offer"])
	assert_eq(Residents.offer_name(), "小满")
	assert_eq(Residents.offer_item_name(), "草莓")
	assert_eq(Residents.talks(&"xiaoman"), 0, "还没算说过话")
	Residents.give_offer()
	assert_signal_emitted_with_parameters(EventBus, "dialogue_requested", ["res://dialogue/xiaoman.dialogue", "gift_love"])
	assert_eq(GameState.inventory.count_of(&"strawberry"), 1, "送出去一个")
	assert_eq(Residents.familiarity_of(&"xiaoman"), 40)
	Residents.talk(&"xiaoman", false)
	assert_signal_emitted_with_parameters(EventBus, "dialogue_requested", ["res://dialogue/xiaoman.dialogue", "daily"])
	assert_eq(GameState.inventory.count_of(&"strawberry"), 1, "今天送过了，再搭话就是聊天")


func test_offer_then_just_talk() -> void:
	Residents.met[&"ahe"] = true
	_hold(&"potato")
	watch_signals(EventBus)
	Residents.talk(&"ahe", true)
	assert_signal_emitted_with_parameters(EventBus, "dialogue_requested", [Residents.COMMON_DIALOGUE, "gift_offer"])
	Residents.decline_offer()
	assert_signal_emitted_with_parameters(EventBus, "dialogue_requested", ["res://dialogue/ahe.dialogue", "work"])
	assert_eq(GameState.inventory.count_of(&"potato"), 1, "东西还在")
	assert_false(Residents.gifted_today.get(&"ahe", false))


func test_first_meeting_never_asks_for_a_gift() -> void:
	_hold(&"potato")
	watch_signals(EventBus)
	Residents.talk(&"ahe", true)
	assert_signal_emitted_with_parameters(EventBus, "dialogue_requested", ["res://dialogue/ahe.dialogue", "first"])


func test_gift_offer_dialogue_reads_names() -> void:
	Residents.met[&"jiang"] = true
	_hold(&"mint")
	Residents.talk(&"jiang", false)
	var res: Resource = load(Residents.COMMON_DIALOGUE)
	var line: Variant = await DialogueManager.get_next_dialogue_line(res, "gift_offer")
	assert_not_null(line)
	if line == null:
		return
	assert_string_contains(str(line.text), "薄荷")
	assert_string_contains(str(line.text), "姜婆婆")
	assert_eq(line.responses.size(), 3)


func test_save_keeps_familiarity_and_tastes() -> void:
	Residents.met[&"xiaoman"] = true
	Residents.give(&"xiaoman", &"strawberry")
	var data := Residents.save_data()
	Residents.reset_data()
	assert_eq(Residents.familiarity_of(&"xiaoman"), 0)
	Residents.load_data(JSON.parse_string(JSON.stringify(data)))
	assert_eq(Residents.familiarity_of(&"xiaoman"), 40)
	assert_eq(Residents.known(&"xiaoman", &"love"), [&"strawberry"] as Array[StringName])
	assert_false(Residents.gifted_today.get(&"xiaoman", false), "今天送没送过不存档")


func test_residents_panel_shows_what_is_known() -> void:
	var panel := ResidentsPanel.new()
	add_child_autofree(panel)
	Residents.met[&"jiang"] = true
	Residents.give(&"jiang", &"mint")
	panel.open()
	assert_true(panel.is_open())
	assert_eq(panel._name.text, "姜婆婆", "第一位是姜婆婆")
	assert_eq(panel._points.text, "熟悉 40 / 100")
	assert_false(panel._taste_empty[&"love"].visible, "知道她最喜欢薄荷")
	assert_true(panel._taste_empty[&"dislike"].visible)
	panel._move(1)
	assert_eq(panel._name.text, "？？？", "没见过的人不显示名字")
	panel.close()
	assert_false(panel.is_open())
