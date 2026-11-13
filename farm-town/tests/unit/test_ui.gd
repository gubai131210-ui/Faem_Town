extends GutTest
## 界面的共用零件和背包面板：按键提示、窗口、整理背包、物品说明。


func before_each() -> void:
	SaveSystem.reset_all()
	GameClock.day = 1
	GameClock.minutes = 600.0


func after_each() -> void:
	SaveSystem.reset_all()


func _panel() -> InventoryPanel:
	var p := InventoryPanel.new()
	add_child_autofree(p)
	return p


func test_key_hints_split_into_keys_and_words() -> void:
	assert_eq(KeyHints.parse("空格 买 1 个    → 买 5 个    E 关闭"), [["空格", "买 1 个"], ["→", "买 5 个"], ["E", "关闭"]])
	assert_eq(KeyHints.parse("空格 供上 / 点灯    E 离开"), [["空格", "供上 / 点灯"], ["E", "离开"]])
	assert_eq(KeyHints.parse("睡觉时保存进度"), [["", "睡觉时保存进度"]])
	assert_eq(KeyHints.parse(""), [])


func test_key_hints_rebuild_when_text_changes() -> void:
	var h := KeyHints.new("空格 做一份    E 关闭")
	add_child_autofree(h)
	# 键帽、说明、空隙、键帽、说明
	assert_eq(h.get_child_count(), 5)
	h.text = "E 关闭"
	assert_eq(h.get_child_count(), 2)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	assert_eq(h.alignment, BoxContainer.ALIGNMENT_CENTER)


func test_window_has_a_title_band_and_new_art_sizes() -> void:
	var w := UiKit.window()
	add_child_autofree(w)
	assert_not_null(w.get_node_or_null("TitleBand"))
	assert_eq(PixelArt.ui_panel().get_size(), Vector2i(24, 24))
	assert_eq(PixelArt.ui_slot(false).get_size(), Vector2i(ItemSlot.SIZE, ItemSlot.SIZE))
	assert_ne(PixelArt.ui_slot(false).get_data(), PixelArt.ui_slot(true).get_data())
	for kind: StringName in ItemDef.KINDS:
		assert_true(UiKit.KIND_TAGS.has(kind), "种类 %s 有标签" % kind)


func test_tidy_merges_sorts_and_leaves_the_hotbar_alone() -> void:
	var inv := Inventory.new(24)
	inv._slots[3] = {"id": &"hoe", "count": 1, "q": 0}
	inv._slots[10] = {"id": &"copper_ore", "count": 30, "q": 0}
	inv._slots[12] = {"id": &"white_radish", "count": 2, "q": 0}
	inv._slots[15] = {"id": &"copper_ore", "count": 80, "q": 0}
	inv._slots[17] = {"id": &"white_radish", "count": 3, "q": 0}
	inv._slots[18] = {"id": &"white_radish", "count": 1, "q": 2}
	watch_signals(inv)
	inv.tidy(8)
	assert_signal_emitted(inv, "changed")
	assert_eq(inv.id_at(3), &"hoe", "物品栏不动")
	assert_eq(inv.count_of(&"copper_ore"), 110, "东西一个不少")
	assert_eq(inv.count_of(&"white_radish"), 6)
	# 作物排在矿石前面；同一种东西品质高的在前；能并的并成一格
	assert_eq([inv.id_at(8), inv.quality_at(8), inv.count_at(8)], [&"white_radish", 2, 1])
	assert_eq([inv.id_at(9), inv.quality_at(9), inv.count_at(9)], [&"white_radish", 0, 5])
	var stack := Database.item(&"copper_ore").stack
	assert_eq([inv.id_at(10), inv.count_at(10)], [&"copper_ore", mini(110, stack)])
	var used := 11
	if stack < 110:
		assert_eq([inv.id_at(11), inv.count_at(11)], [&"copper_ore", 110 - stack], "一格叠不下的另起一格")
		used = 12
	for i in range(used, 24):
		assert_true(inv.is_empty_slot(i), "空格都在最后")


func test_inventory_panel_shows_what_the_cursor_is_on() -> void:
	var p := _panel()
	GameState.inventory.add(&"white_radish", 3, 1)
	var at := -1
	for i in GameState.inventory.size:
		if GameState.inventory.id_at(i) == &"white_radish":
			at = i
	p.open()
	p._on_slot_hovered(at)
	var def := Database.item(&"white_radish")
	assert_eq((p.get(&"_title") as Label).text, "%s（良） ×3" % def.name)
	assert_eq((p.get(&"_tag_text") as Label).text, "作物")
	assert_true((p.get(&"_tag") as Control).visible)
	assert_eq((p.get(&"_price") as Label).text, "售价 %d 文" % def.price_for(1))
	assert_eq((p.get(&"_desc") as Label).text, def.desc)
	assert_not_null((p.get(&"_big_icon") as TextureRect).texture)
	assert_eq((p.get(&"_money") as Label).text, "%d 文" % GameState.money)
	# 空格
	var empty := -1
	for i in GameState.inventory.size:
		if GameState.inventory.id_at(i) == &"":
			empty = i
	p._on_slot_hovered(empty)
	assert_eq((p.get(&"_title") as Label).text, "")
	assert_false((p.get(&"_tag") as Control).visible)
	assert_null((p.get(&"_big_icon") as TextureRect).texture)


func test_inventory_panel_tidy_drops_what_was_held() -> void:
	var p := _panel()
	var inv := GameState.inventory
	inv.add(&"stone", 5)
	var from := -1
	for i in inv.size:
		if inv.id_at(i) == &"stone":
			from = i
	inv.swap(from, 20)
	p.open()
	p._pick(20)
	assert_eq(p.get(&"_held"), 20)
	p.tidy_up()
	assert_eq(p.get(&"_held"), -1)
	assert_eq(inv.id_at(GameState.HOTBAR_SIZE), &"stone", "挪到了物品栏后面的第一格")
	assert_eq(inv.id_at(20), &"")
