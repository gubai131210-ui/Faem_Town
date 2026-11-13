extends GutTest
## M5 第五批：第三幕（老秦的钥匙、井口灯、守井人的小屋）、工具升级要矿石、镐子的等级。

const NORTH_FOG := Vector2i(13, 1)
const NORTH_EDGE := Vector2i(13, 0)
const WELL_LAMP := Vector2i(15, 7)

var _banners: Array[String] = []


func before_each() -> void:
	SaveSystem.reset_all()
	Weather.today = &"sunny"
	Weather.yesterday = &"sunny"
	GameClock.minutes = 600.0
	GameClock.day = 1
	_banners.clear()
	EventBus.banner_requested.connect(_on_banner)


func after_each() -> void:
	EventBus.banner_requested.disconnect(_on_banner)
	SaveSystem.reset_all()
	Weather.today = &"sunny"
	Weather.yesterday = &"sunny"
	GameClock.running = false


func _on_banner(text: String) -> void:
	_banners.append(text)


func _map(id: StringName) -> OutdoorMap:
	var scene: PackedScene = load(SceneRouter.MAPS[id])
	var m: OutdoorMap = scene.instantiate()
	add_child_autofree(m)
	return m


func _three_lamps() -> void:
	for flag: StringName in [&"lamp_plaza", &"lamp_river", &"lamp_pasture"]:
		GameState.set_flag(flag)


## 走一段对话，一路挑第一个能选的选项，返回说过的话。
func _say(title: String) -> String:
	var res: Resource = load(Residents.dialogue_path(&"laoqin"))
	var said := ""
	var line: Variant = await DialogueManager.get_next_dialogue_line(res, title)
	while line != null:
		said += str(line.text)
		var next: String = line.next_id
		if next == "end" or next == "":
			break
		line = await DialogueManager.get_next_dialogue_line(res, next)
	return said


func _upgrade_entry(tool: StringName) -> ShopEntry:
	for e in Shop.entries(&"spring", Shop.SMITH):
		if e.upgrade and e.item_id == tool:
			return e
	return null


# ---------------------------------------------------------------- 数据

func test_tables_are_valid() -> void:
	assert_eq(Database.validate(), PackedStringArray(), "数据表没有错")
	var lamp := Database.lamp(&"well")
	assert_eq(lamp.map, &"town")
	assert_eq(lamp.relic, &"well_key")
	assert_eq(lamp.flag(), &"lamp_well")
	assert_true(Database.has_relic(&"well_key"))
	assert_eq(PixelArt.icon(Database.item(&"well_key").icon).get_size(), Vector2i(16, 16))


# ---------------------------------------------------------------- 北边的雾和老秦

func test_north_fog_stays_after_the_pasture_lamp_and_laoqin_shouts() -> void:
	_three_lamps()
	var town := _map(&"town")
	assert_true(town.blocked(GameMap.tile_center(NORTH_FOG)), "牧野灯亮了，北边的雾还在")
	assert_true(town.trigger_at(NORTH_EDGE).is_empty())
	town.perform(&"interact", null, NORTH_FOG)
	assert_string_contains(_banners[-1], "老秦")
	assert_true(GameState.has_flag(&"well_warned"))


func test_north_fog_is_plain_before_the_pasture_lamp() -> void:
	var town := _map(&"town")
	town.perform(&"interact", null, NORTH_FOG)
	assert_string_contains(_banners[-1], "雾太浓")
	assert_false(GameState.has_flag(&"well_warned"))


func test_laoqin_hands_over_the_key_once_he_knows_you() -> void:
	_three_lamps()
	Residents.met[&"laoqin"] = true
	GameState.set_flag(&"well_warned")
	var said := await _say("daily")
	assert_string_contains(said, "看不透", "不熟的时候只是训一顿")
	assert_eq(GameState.inventory.count_of(&"well_key"), 0)
	said = await _say("daily")
	assert_false(said.contains("看不透"), "训过一回就不再训")
	Residents.add_familiarity(&"laoqin", 40)
	said = await _say("daily")
	assert_string_contains(said, "钥匙")
	assert_eq(GameState.inventory.count_of(&"well_key"), 1)
	assert_true(GameState.has_flag(&"got_well_key"))
	said = await _say("daily")
	assert_string_contains(said, "灯座")
	assert_eq(GameState.inventory.count_of(&"well_key"), 1, "只给一把")
	said = await _say("daily")
	assert_false(said.contains("灯座"), "催一回就回到平常的话")


func test_laoqin_keeps_the_key_while_the_bag_is_full() -> void:
	_three_lamps()
	Residents.met[&"laoqin"] = true
	Residents.add_familiarity(&"laoqin", 40)
	for i in GameState.inventory.size:
		if GameState.inventory.is_empty_slot(i):
			GameState.inventory._slots[i] = {"id": &"stone", "count": 99, "q": 0}
	var said := await _say("daily")
	assert_string_contains(said, "腾个地方")
	assert_false(GameState.has_flag(&"got_well_key"))
	GameState.inventory._slots[10] = {}
	said = await _say("again")
	assert_string_contains(said, "钥匙")
	assert_eq(GameState.inventory.count_of(&"well_key"), 1, "当天再说一次也能拿到")


func test_laoqin_says_nothing_about_the_well_before_the_pasture_lamp() -> void:
	Residents.met[&"laoqin"] = true
	Residents.add_familiarity(&"laoqin", 100)
	var said := await _say("daily")
	assert_eq(GameState.inventory.count_of(&"well_key"), 0)
	assert_false(said.contains("钥匙"))


# ---------------------------------------------------------------- 井口灯

func test_well_lamp_takes_offerings_and_opens_the_north_road() -> void:
	_three_lamps()
	var town := _map(&"town")
	assert_eq(town.query_use(null, WELL_LAMP, GameMap.Facing.UP), &"interact")
	assert_true(town.blocked(GameMap.tile_center(WELL_LAMP)), "灯座挡路")
	assert_false(town.blocked(GameMap.tile_center(WELL_LAMP + Vector2i(0, 1))), "灯座前面站得住")
	watch_signals(EventBus)
	town.perform(&"interact", null, WELL_LAMP)
	assert_signal_emitted_with_parameters(EventBus, "lamp_requested", [&"well"])
	assert_false(Lamps.light(&"well"), "供品没齐点不亮")
	for item_id in Lamps.wanted(&"well"):
		Lamps.offer(&"well", item_id, 99)
	assert_true(Lamps.light(&"well"))
	assert_true(GameState.has_flag(&"lamp_well"))
	town.on_lamp_lit(&"well")
	assert_false(town.blocked(GameMap.tile_center(NORTH_FOG) + Vector2(8, 0)), "灯亮了北边的雾散了")
	assert_eq(town.trigger_at(NORTH_EDGE).get("map"), &"wellhead")
	town.perform(&"interact", null, WELL_LAMP)
	assert_string_contains(_banners[-1], "井口灯")


func test_old_save_that_already_has_the_pickaxe_keeps_the_road() -> void:
	_three_lamps()
	GameState.set_flag(Mine.PICKAXE_FLAG)
	var town := _map(&"town")
	assert_false(town.blocked(GameMap.tile_center(NORTH_FOG) + Vector2(8, 0)))
	assert_eq(town.trigger_at(NORTH_EDGE).get("map"), &"wellhead")


func test_lamp_news_and_narration() -> void:
	_three_lamps()
	Residents.met[&"laoqin"] = true
	GameState.set_flag(&"lamp_well")
	var said := await _say("daily")
	assert_string_contains(said, "背你上来")
	said = await _say("daily")
	assert_false(said.contains("背你上来"), "只说一回")
	var res: Resource = load(Residents.COMMON_DIALOGUE)
	var line: Variant = await DialogueManager.get_next_dialogue_line(res, "lamp_well")
	assert_string_contains(str(line.text), "北边的雾")


# ---------------------------------------------------------------- 老秦搬回井口

func test_laoqin_moves_to_the_wellhead_after_the_lamp() -> void:
	var qin := Database.npc(&"laoqin")
	assert_true(qin.is_early())
	assert_eq(NpcSchedule.spot_at(qin, 600.0, &"sunny")["map"], &"", "灯没亮，白天不露面")
	assert_eq(NpcSchedule.spot_at(qin, 990.0, &"sunny")["map"], &"town", "傍晚来镇上打酒")
	GameState.set_flag(&"lamp_well")
	assert_false(qin.is_early())
	assert_eq(NpcSchedule.spot_at(qin, 600.0, &"sunny")["map"], &"wellhead", "白天守着井口")
	assert_eq(NpcSchedule.spot_at(qin, 990.0, &"sunny")["map"], &"town", "傍晚照旧去打酒")
	assert_eq(NpcSchedule.spot_at(qin, 1200.0, &"sunny")["map"], &"wellhead", "打完酒回井口")
	assert_eq(NpcSchedule.spot_at(qin, 600.0, &"rain")["map"], &"wellhead", "下雨也不走")


func test_wellhead_has_the_hut_and_room_for_laoqin() -> void:
	GameState.set_flag(&"lamp_well")
	var well := _map(&"wellhead")
	assert_true(well.blocked(GameMap.tile_center(Vector2i(5, 7))), "小屋挡路")
	assert_eq(well.query_use(null, Vector2i(5, 8), GameMap.Facing.UP), &"interact")
	well.perform(&"interact", null, Vector2i(5, 8))
	assert_string_contains(_banners[-1], "守井人的小屋")
	var qin := Database.npc(&"laoqin")
	for weather: StringName in [&"sunny", &"rain"]:
		var spot := NpcSchedule.spot_at(qin, 600.0, weather)
		var tile: Vector2i = spot["tile"]
		# 他自己站在那儿会挡路，所以看的是地形
		assert_eq(well.solid[well.idx(tile)], 0, "老秦站的地方是空地（%s）" % weather)
		assert_false(well.find_path(Vector2i(12, 19), tile).is_empty(), "从路上走得到（%s）" % weather)
	assert_eq(MineArt.hut().get_size(), Vector2i(64, 56))


func test_faint_text_names_laoqin_once_the_lamp_is_lit() -> void:
	var game: Node = load("res://game/game.gd").new()
	var lost: Dictionary[StringName, int] = {}
	assert_string_contains(game._faint_text(lost), "不知道是谁")
	GameState.set_flag(&"lamp_well")
	assert_string_contains(game._faint_text(lost), "老秦")
	game.free()


# ---------------------------------------------------------------- 工具升级要矿石

func test_upgrade_needs_ore_as_well_as_money() -> void:
	GameState.money = 5000
	var entry := _upgrade_entry(&"hoe")
	assert_not_null(entry)
	assert_eq(entry.materials.size(), 2)
	assert_string_contains(entry.desc, "铁矿石 ×5")
	assert_eq(Shop.affordable_entry(entry, 1), 0, "没有矿石买不了")
	assert_false(Shop.buy_entry(entry, 1))
	assert_eq(GameState.money, 5000)
	GameState.inventory.add(&"iron_ore", 6)
	GameState.inventory.add(&"copper_ore", 4)
	assert_false(Shop.buy_entry(entry, 1), "差一块也不行")
	GameState.inventory.add(&"copper_ore", 1)
	assert_true(Shop.buy_entry(entry, 1))
	assert_eq(GameState.tool_level(&"hoe"), 1)
	assert_eq(GameState.money, 5000 - Shop.UPGRADE_PRICES[0])
	assert_eq(GameState.inventory.count_of(&"iron_ore"), 1, "矿石收走了")
	assert_eq(GameState.inventory.count_of(&"copper_ore"), 0)
	entry = _upgrade_entry(&"hoe")
	assert_string_contains(entry.desc, "银矿石")


func test_every_upgrade_level_lists_ore_that_exists() -> void:
	assert_eq(Shop.UPGRADE_MATERIALS.size(), GameState.MAX_TOOL_LEVEL)
	for level: Array in Shop.UPGRADE_MATERIALS:
		assert_false(level.is_empty())
		for m: Dictionary in level:
			assert_true(Database.has_item(m["item"]), str(m["item"]))
			assert_eq(Database.item(m["item"]).kind, &"ore")
			assert_gt(int(m["count"]), 0)
	assert_eq(Shop.PICKAXE_NOTES.size(), GameState.MAX_TOOL_LEVEL)


func test_pickaxe_upgrade_shows_up_only_after_you_have_one() -> void:
	assert_null(_upgrade_entry(&"pickaxe"), "还没拿到镐子不列")
	GameState.inventory.add(&"pickaxe", 1)
	GameState.set_flag(Mine.PICKAXE_FLAG)
	var entry := _upgrade_entry(&"pickaxe")
	assert_not_null(entry)
	assert_eq(entry.name, "升级：铁镐子")
	assert_string_contains(entry.desc, "一下敲开")
	assert_eq(GameState.display_name(Database.item(&"pickaxe")), "铜镐子")
	for level in GameState.MAX_TOOL_LEVEL + 1:
		assert_eq(PixelArt.icon("mine:pickaxe@%d" % level).get_size(), Vector2i(16, 16))
	assert_ne(PixelArt.icon("mine:pickaxe@0").get_pixel(9, 3), PixelArt.icon("mine:pickaxe@3").get_pixel(9, 3), "镐头的颜色跟着等级变")


# ---------------------------------------------------------------- 镐子的等级

func _floor_with_ore() -> Vector2i:
	Mine.enter(1)
	var f := Mine.current
	var at := f.spawn + Vector2i(1, 0)
	f.rocks[at] = &"copper_ore"
	f.hp[at] = f.hp_of(&"copper_ore")
	return at


func test_plain_pickaxe_takes_two_hits_on_ore() -> void:
	var at := _floor_with_ore()
	assert_false(bool(Mine.strike(at)["broken"]), "铜镐敲矿石要两下")
	assert_true(bool(Mine.strike(at)["broken"]))
	assert_eq(Mine.pick_cost(2), 2)


func test_iron_pickaxe_breaks_ore_in_one_hit() -> void:
	GameState.upgrade_tool(&"pickaxe")
	var at := _floor_with_ore()
	assert_true(bool(Mine.strike(at)["broken"]), "铁镐一下敲开")
	assert_gt(GameState.inventory.count_of(&"copper_ore"), 0)
	assert_eq(Mine.pick_cost(2), 2, "铁镐还不省力")


func test_silver_pickaxe_costs_one_energy_and_gold_is_luckier() -> void:
	GameState.upgrade_tool(&"pickaxe")
	GameState.upgrade_tool(&"pickaxe")
	assert_eq(Mine.pick_cost(2), 1)
	assert_eq(Mine.pick_luck(), MineFloor.DOUBLE_CHANCE)
	GameState.upgrade_tool(&"pickaxe")
	assert_gt(Mine.pick_luck(), MineFloor.DOUBLE_CHANCE)
	# 机会给到十成就一定多掉一份
	Mine.enter(1)
	var f := Mine.current
	var at := f.spawn + Vector2i(1, 0)
	f.rocks[at] = &"copper_ore"
	f.hp[at] = 1
	assert_eq(int(f.hit(at, 1, 1.0)["count"]), 2)
	f.rocks[at] = &"copper_ore"
	f.hp[at] = 1
	assert_eq(int(f.hit(at, 1, 0.0)["count"]), 1)


# ---------------------------------------------------------------- 界面

func test_inventory_describes_tools_by_what_the_level_does() -> void:
	var panel := InventoryPanel.new()
	add_child_autofree(panel)
	GameState.inventory._slots[8] = {"id": &"pickaxe", "count": 1, "q": 0}
	GameState.inventory._slots[9] = {"id": &"rod", "count": 1, "q": 0}
	GameState.upgrade_tool(&"pickaxe")
	GameState.upgrade_tool(&"rod")
	panel.open()
	panel._cursor = 8
	panel._refresh()
	assert_string_contains(panel._desc.text, "一下敲开")
	assert_false(panel._desc.text.contains("蓄力"), "镐子不蓄力")
	panel._cursor = 9
	panel._refresh()
	assert_false(panel._desc.text.contains("蓄力"), "鱼竿升了级也不是蓄力")


func test_board_keeps_the_lamp_notes_to_three_lines() -> void:
	var panel := BoardPanel.new()
	add_child_autofree(panel)
	panel.open()
	assert_lte(panel._lamp.text.split("\n").size(), 3)
	assert_string_contains(panel._lamp.text, "白菔", "没亮的先列最前面的")
	_three_lamps()
	panel._refresh()
	var lines := panel._lamp.text.split("\n")
	assert_eq(lines.size(), 3)
	assert_string_contains(lines[0], "广场灯、河灯、牧野灯")
	assert_string_contains(lines[1], "井钥")
	assert_string_contains(lines[2], "船票", "井口灯后面是东滩灯")
