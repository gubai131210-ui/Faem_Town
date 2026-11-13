extends GutTest
## M6 第四批：六个节日。日子和天气、居民的站位、每个节日的活动、对话、摆设。

const PATH := "res://dialogue/festival.dialogue"
## 六个节日是一年里的第几天
const SOWING := 13
const LANTERN := 17
const FIREFLY := 45
const HARVEST := 61
const DUMPLING := 85
const NEWYEAR := 96

var _banners: Array[String] = []
var _dialogues: Array[String] = []
var _sleeps := 0


func before_each() -> void:
	SaveSystem.reset_all()
	Weather.today = &"sunny"
	Weather.yesterday = &"sunny"
	GameClock.minutes = 600.0
	GameClock.day = 1
	_banners.clear()
	_dialogues.clear()
	_sleeps = 0
	EventBus.banner_requested.connect(_on_banner)
	EventBus.dialogue_requested.connect(_on_dialogue)
	EventBus.sleep_requested.connect(_on_sleep)


func after_each() -> void:
	EventBus.banner_requested.disconnect(_on_banner)
	EventBus.dialogue_requested.disconnect(_on_dialogue)
	EventBus.sleep_requested.disconnect(_on_sleep)
	SaveSystem.reset_all()
	Weather.today = &"sunny"
	Weather.yesterday = &"sunny"
	GameClock.running = false


func _on_banner(text: String) -> void:
	_banners.append(text)


func _on_dialogue(_path: String, title: String) -> void:
	_dialogues.append(title)


func _on_sleep() -> void:
	_sleeps += 1


func _map(id: StringName) -> OutdoorMap:
	var scene: PackedScene = load(SceneRouter.MAPS[id])
	var m: OutdoorMap = scene.instantiate()
	add_child_autofree(m)
	return m


## 走一段对话，返回说过的话。碰到选项选第 pick 个；pick 小于 0 时把选项的字也记下来就停。
func _say(title: String, pick: int = -1) -> String:
	var res: Resource = load(PATH)
	var said := ""
	var line: Variant = await DialogueManager.get_next_dialogue_line(res, title)
	while line != null:
		said += str(line.text)
		var next: String = line.next_id
		var open: Array = line.responses.filter(func(r: Variant) -> bool: return r.is_allowed)
		if not open.is_empty():
			if pick < 0:
				for r: Variant in open:
					said += "|" + str(r.text)
				break
			next = open[pick].next_id
		if next == "end" or next == "":
			break
		line = await DialogueManager.get_next_dialogue_line(res, next)
	return said


func _at(day: int, minutes: float) -> void:
	GameClock.day = day
	GameClock.minutes = minutes


func _meet_everyone() -> void:
	for id: StringName in Database.npcs:
		Residents.met[id] = true


## 把一样东西拿在手里（放在快捷栏第 6 格）。
func _hold(id: StringName, quality: int = 0) -> void:
	GameState.inventory.clear()
	for i in 5:
		GameState.inventory.add(&"stone", 1)
		GameState.inventory.add(&"coal", 1)
	GameState.inventory.clear()
	GameState.inventory.add(id, 1, quality)
	GameState.selected_slot = 0


# ---------------------------------------------------------------- 日子

func test_six_festivals_fall_on_their_days() -> void:
	assert_eq(Database.validate().size(), 0, "数据表校验通过：%s" % [Database.validate()])
	assert_eq(Database.festivals.size(), 6)
	var days := {SOWING: &"sowing", LANTERN: &"lantern", FIREFLY: &"firefly", HARVEST: &"harvest", DUMPLING: &"dumpling", NEWYEAR: &"newyear"}
	for day: int in days:
		var def := Database.festival_on(day)
		assert_not_null(def, "第 %d 天是节日" % day)
		if def != null:
			assert_eq(def.id, days[day])
		assert_not_null(Database.festival_on(day + 96), "第二年的同一天也是")
	var count := 0
	for day in range(1, 97):
		if Database.festival_on(day) != null:
			count += 1
	assert_eq(count, 6, "一年只有六天是节日")
	assert_null(Database.festival_on(SOWING + 1), "播种节只有春分头一天")
	assert_null(Database.festival_on(NEWYEAR - 1), "除夕是大寒最后一天")


func test_festival_days_never_rain() -> void:
	for day: int in [SOWING, LANTERN, FIREFLY, HARVEST, DUMPLING, NEWYEAR]:
		var w := Weather.weights_for(day)
		for kind: StringName in w:
			assert_true(kind == Weather.SUNNY or kind == Weather.CLOUDY, "第 %d 天不该有 %s" % [day, kind])
	assert_true(Weather.weights_for(FIREFLY + 1).has(Weather.STORM), "大暑别的日子照样多雷暴")


func test_festival_is_open_only_in_its_hours() -> void:
	_at(SOWING, 500.0)
	assert_not_null(Festivals.today())
	assert_false(Festivals.is_open(), "九点以前还没开")
	_at(SOWING, 540.0)
	assert_true(Festivals.is_open())
	assert_true(Festivals.is_open(&"sowing"))
	assert_false(Festivals.is_open(&"harvest"))
	_at(SOWING, 1020.0)
	assert_false(Festivals.is_open(), "五点散")
	_at(SOWING + 1, 600.0)
	assert_null(Festivals.today())
	assert_false(Festivals.is_open())
	_at(NEWYEAR, 1500.0 - 1.0)
	assert_true(Festivals.is_open(&"newyear"), "除夕开到后半夜")


func test_morning_note_names_the_festival() -> void:
	_at(SOWING, 360.0)
	assert_string_contains(Festivals.morning_note(), "今天是播种节")
	assert_string_contains(Festivals.morning_note(), "镇广场")
	_at(SOWING + 1, 360.0)
	assert_eq(Festivals.morning_note(), "")


# ---------------------------------------------------------------- 站位

func test_everyone_gathers_while_the_festival_is_open() -> void:
	_at(SOWING, 500.0)
	var jiang := Database.npc(&"jiang")
	assert_ne(str(NpcSchedule.spot_at(jiang, 500.0, &"sunny").get("note", "")), Festivals.NOTE, "开始以前照平常的日程")
	var taken: Dictionary[Vector2i, bool] = {}
	for id: StringName in Database.npcs:
		var spot := NpcSchedule.spot_at(Database.npc(id), 600.0, &"rain")
		assert_eq(spot["map"], &"town", "%s 在广场上（下雨也来）" % id)
		assert_eq(str(spot["note"]), Festivals.NOTE)
		assert_false(taken.has(spot["tile"]), "%s 的位置没和别人重" % id)
		taken[spot["tile"]] = true
		assert_eq(NpcSchedule.spot_at(Database.npc(id), 1020.0, &"sunny")["map"], &"", "%s 散了回家" % id)
	assert_true(NpcSchedule.spot_at(Database.npc(&"ahe"), 600.0, &"sunny")["work"], "阿禾在看摊子")
	assert_false(NpcSchedule.spot_at(Database.npc(&"bai"), 600.0, &"sunny")["work"])
	GameClock.minutes = 600.0
	assert_true(Festivals.attending(&"laozhou"))
	_at(SOWING + 1, 600.0)
	assert_false(Festivals.attending(&"laozhou"))
	assert_ne(str(NpcSchedule.spot_at(jiang, 600.0, &"sunny").get("note", "")), Festivals.NOTE, "第二天就照常了")


func test_every_festival_spot_can_be_walked_to() -> void:
	var days := {SOWING: 600.0, LANTERN: 1140.0, FIREFLY: 1200.0, HARVEST: 600.0, DUMPLING: 1080.0, NEWYEAR: 1140.0}
	for day: int in days:
		_at(day, days[day])
		var def := Festivals.today()
		var m := _map(def.map)
		await wait_process_frames(2)
		for id: StringName in Database.npcs:
			var npc: Npc = m.call(&"_npc_of", id)
			assert_not_null(npc, "%s：%s 到场了" % [def.name, id])
			if npc == null:
				continue
			var tile: Vector2i = NpcSchedule.spot_at(npc.def, GameClock.minutes, &"sunny")["tile"]
			assert_eq(npc.tile(), tile, "%s：%s 站在自己的位置上" % [def.name, id])
			assert_true(m.call(&"_walkable", tile), "%s：%s 的位置 %s 能站人" % [def.name, id, tile])
			var door: Vector2i = m.call(&"_door", npc.def)
			assert_ne(door, FestivalDef.NO_TILE, "%s：%s 有地方进出" % [def.name, id])
			assert_false(m.find_path(door, tile).is_empty(), "%s：%s 从 %s 走得到 %s" % [def.name, id, door, tile])
		for t in def.counter:
			assert_false(m.call(&"_walkable", t), "%s 的台子挡路" % def.name)
		# 主持人身边至少有一格能站：玩家够得着
		var reach := false
		var around: Array[Vector2i] = [def.host_tile]
		around.append_array(def.counter)
		for t in around:
			for d: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
				if m.call(&"_walkable", t + d) and m.npc_at(t + d) == null:
					reach = true
		assert_true(reach, "%s 的主持人够得着" % def.name)
		m.free()


func test_residents_come_to_the_stream_through_the_road() -> void:
	_at(LANTERN, 1140.0)
	var m := _map(&"nanxi")
	var ahe := Database.npc(&"ahe")
	assert_false(ahe.enter.has(&"nanxi"))
	assert_eq(m.call(&"_door", ahe), Vector2i(19, 0), "节日那天从北边的路口进来")
	_at(LANTERN + 1, 1140.0)
	assert_eq(m.call(&"_door", ahe), FestivalDef.NO_TILE, "平常她不来南溪")
	assert_eq(m.call(&"_door", Database.npc(&"laozhou")), Vector2i(19, 0))


# ---------------------------------------------------------------- 搭话

func test_talking_at_a_festival_plays_festival_lines() -> void:
	_meet_everyone()
	_at(SOWING, 600.0)
	GameState.selected_slot = 7
	assert_eq(Residents.title_for(&"bai", false), "fest_sowing_host")
	assert_eq(Residents.title_for(&"jiang", false), "fest_sowing_jiang")
	assert_eq(Residents.title_for(&"ahe", true), "work", "阿禾在摊子上照常卖东西")
	assert_eq(Residents.path_for(&"jiang", "fest_sowing_jiang"), PATH)
	assert_eq(Residents.path_for(&"jiang", "daily"), Residents.dialogue_path(&"jiang"))
	var before := Residents.familiarity_of(&"jiang")
	Residents.talk(&"jiang", false)
	assert_eq(_dialogues[-1], "fest_sowing_jiang")
	assert_eq(Residents.familiarity_of(&"jiang"), before + Residents.TALK_POINTS, "节日上搭话照样加熟悉度")
	assert_eq(Residents.title_for(&"jiang", false), "again", "第二回照平常的说")
	Residents.talk(&"bai", false)
	assert_eq(Residents.title_for(&"bai", false), "fest_sowing_host", "主持人每回都是节日的话")
	Residents.met.erase(&"egret")
	assert_eq(Residents.title_for(&"egret", false), "first", "没见过面的先认识")
	_at(SOWING, 500.0)
	assert_eq(Residents.title_for(&"shishu", false), "daily", "节日开始以前照常")


func test_every_resident_has_a_line_at_every_festival() -> void:
	var res: Resource = load(PATH)
	var titles: Array = res.get(&"cues").keys()
	for fid: StringName in Database.festivals:
		var def := Database.festival(fid)
		assert_true(titles.has("fest_%s_host" % fid), "%s 有主持人的话" % def.name)
		for id: StringName in Database.npcs:
			if id == def.host:
				continue
			var title := "fest_%s_%s" % [fid, id]
			assert_true(titles.has(title), "缺 %s" % title)
			if titles.has(title):
				var said := await _say(title)
				assert_gt(said.length(), 4, "%s 有话说" % title)
	for id: StringName in Database.npcs:
		if id != &"xiaoman":
			assert_true(titles.has("fest_firefly_heart_%s" % id), "%s 有萤火夜的心里话" % id)
	for flavor: String in ["veg", "fish", "wild", "rich", "sweet", "odd"]:
		assert_true(titles.has("fest_dumpling_feast_" + flavor), "饺子宴有 %s 这一桌" % flavor)
	for i in range(1, 5):
		assert_true(titles.has("fest_sowing_result_%d" % i))
		assert_true(titles.has("fest_harvest_result_%d" % i))


# ---------------------------------------------------------------- 播种节

func test_strawberry_seeds_are_sold_only_at_the_stall() -> void:
	var ids := func() -> Array:
		return Shop.entries(&"spring", Shop.GROCERY).map(func(e: ShopEntry) -> StringName: return e.item_id)
	_at(SOWING, 500.0)
	assert_false(ids.call().has(&"strawberry_seed"), "摊子没开")
	_at(SOWING, 600.0)
	assert_true(ids.call().has(&"strawberry_seed"))
	assert_eq(ids.call()[0], &"strawberry_seed", "排在最前面")
	assert_false(Shop.entries(&"spring", Shop.SMITH).map(func(e: ShopEntry) -> StringName: return e.item_id).has(&"strawberry_seed"))
	_at(SOWING + 1, 600.0)
	assert_false(ids.call().has(&"strawberry_seed"), "过了这天就没有了")
	_at(HARVEST, 600.0)
	assert_false(ids.call().has(&"strawberry_seed"), "别的节日不卖")


func test_sowing_on_the_farm_is_counted_for_the_day() -> void:
	var farm := _map(&"farm")
	var t := Vector2i(20, 14)
	Farming.state.till(t)
	Farming.state.till(t + Vector2i(1, 0))
	GameState.inventory.add(&"white_radish_seed", 2)
	assert_eq(Farming.sown_today, 0)
	farm.perform(&"plant", Database.item(&"white_radish_seed"), t)
	farm.perform(&"plant", Database.item(&"white_radish_seed"), t)
	assert_eq(Farming.sown_today, 1, "种过的格子再种不算")
	farm.perform(&"plant", Database.item(&"white_radish_seed"), t + Vector2i(1, 0))
	assert_eq(Farming.sown_today, 2)
	GameClock.advance_day()
	assert_eq(Farming.sown_today, 0, "过了一夜清零")


func test_sowing_contest_ranks_against_three_residents() -> void:
	var rivals: Array = Database.festival(&"sowing").rivals[&"sow"]
	assert_eq(Festivals.rank(25, rivals), 1)
	assert_eq(Festivals.rank(20, rivals), 1, "打平算赢")
	assert_eq(Festivals.rank(12, rivals), 2)
	assert_eq(Festivals.rank(6, rivals), 3)
	assert_eq(Festivals.rank(3, rivals), 4)
	_at(SOWING, 500.0)
	Farming.sown_today = 30
	assert_true(Festivals.act(&"sow").is_empty(), "没开始不能报")
	_at(SOWING, 600.0)
	Farming.sown_today = 0
	assert_eq(Festivals.act(&"sow")["title"], "fest_sowing_none")
	assert_false(Festivals.done("sow"), "没播不算报过")
	Farming.sown_today = 14
	GameState.money = 0
	var result := Festivals.act(&"sow")
	assert_eq(result["title"], "fest_sowing_result_2")
	assert_true(result["join"])
	assert_eq(GameState.money, 250)
	assert_eq(Festivals.said["count"], "14")
	assert_string_contains(Festivals.said["best"], "阿禾")
	assert_true(Festivals.done("sow"))
	assert_true(Festivals.act(&"sow").is_empty(), "一年报一回")
	assert_eq(GameState.money, 250)
	_at(SOWING + 96, 600.0)
	assert_false(Festivals.done("sow"), "第二年能再来")
	Farming.sown_today = 3
	assert_eq(Festivals.act(&"sow")["title"], "fest_sowing_result_4")
	assert_eq(GameState.money, 250, "前三名以外没有钱")


func test_joining_makes_everyone_present_a_little_closer() -> void:
	_at(SOWING, 600.0)
	Residents.met[&"jiang"] = true
	Residents.met[&"bai"] = true
	Farming.sown_today = 22
	Residents.festival_act("sow")
	assert_eq(_dialogues[-1], "fest_sowing_result_1")
	assert_eq(Residents.familiarity_of(&"jiang"), Festivals.JOIN_POINTS)
	assert_eq(Residents.familiarity_of(&"bai"), Festivals.JOIN_POINTS)
	assert_eq(Residents.familiarity_of(&"egret"), 0, "没见过面的不加")
	Residents.festival_act("sow")
	assert_eq(_dialogues.size(), 1, "报过了，再报什么都不发生")
	var said := await _say("fest_sowing_result_1")
	assert_string_contains(said, "22")
	assert_string_contains(said, "500")
	said = await _say("fest_sowing_host")
	assert_string_contains(said, "记在册子上")


func test_sowing_host_offers_the_contest() -> void:
	_at(SOWING, 600.0)
	var said := await _say("fest_sowing_host")
	assert_string_contains(said, "|报数|我先去播种")
	Farming.sown_today = 0
	await _say("fest_sowing_host", 0)
	assert_eq(_dialogues[-1], "fest_sowing_none")


# ---------------------------------------------------------------- 放河灯

func test_more_residents_float_a_lantern_as_lamps_are_lit() -> void:
	assert_eq(Festivals.floaters(), [&"xiaoman"] as Array[StringName], "一盏灯都没亮：只有小满")
	GameState.set_flag(&"lamp_plaza")
	GameState.set_flag(&"lamp_river")
	assert_eq(Festivals.floaters(), [&"xiaoman", &"ahe", &"laozhou"] as Array[StringName])
	assert_true(Residents.floats("laozhou"))
	assert_false(Residents.floats("amu"))
	GameState.set_flag(Story.TRIAL_FLAG)
	Story.choose(true)
	assert_eq(Festivals.floaters().size(), Database.npcs.size(), "最初的灯亮了，人人都放")


func test_floating_a_lantern_once_a_year() -> void:
	_at(LANTERN, 1000.0)
	assert_true(Festivals.act(&"float").is_empty(), "六点以前还没开始")
	_at(LANTERN, 1140.0)
	var said := await _say("fest_lantern_host")
	assert_string_contains(said, "我不放")
	assert_string_contains(said, "|把灯放进水里|再等等")
	GameState.set_flag(&"lamp_river")
	said = await _say("fest_lantern_host")
	assert_string_contains(said, "扎了两盏")
	await _say("fest_lantern_host", 0)
	assert_eq(_dialogues[-1], "fest_lantern_float")
	assert_true(Festivals.done("float"))
	said = await _say("fest_lantern_host")
	assert_string_contains(said, "漂远了")
	assert_true(Festivals.act(&"float").is_empty())
	said = await _say("fest_lantern_jiang")
	assert_string_contains(said, "上谁的坟")
	GameState.set_flag(&"lamp_shrine")
	said = await _say("fest_lantern_jiang")
	assert_string_contains(said, "糊了一盏")


func test_lanterns_drift_on_the_stream() -> void:
	GameState.set_flag(&"lamp_plaza")
	_at(LANTERN, 1140.0)
	var m := _map(&"nanxi")
	await wait_seconds(0.4)
	var lanterns: Array = m.get(&"_river_lanterns")
	assert_eq(lanterns.size(), 2, "小满和阿禾各一盏")
	Festivals.act(&"float")
	await wait_seconds(0.4)
	assert_eq(lanterns.size(), 3, "玩家的那一盏也在水上")
	for s: Sprite2D in lanterns:
		assert_true(m.call(&"_is_water", GameMap.tile_of(s.position)), "灯漂在水面上：%s" % s.position)
	GameClock.minutes = 1330.0
	await wait_seconds(0.4)
	assert_eq(lanterns.size(), 0, "十点散了，灯也漂走了")


# ---------------------------------------------------------------- 萤火夜

func test_catching_fireflies_and_letting_them_go() -> void:
	_at(FIREFLY, 1200.0)
	var m := _map(&"nanxi")
	await wait_seconds(0.4)
	var flies: Dictionary = m.get(&"_fireflies")
	assert_eq(flies.size(), Festivals.FIREFLY_TOTAL)
	var def := Database.festival(&"firefly")
	for t: Vector2i in flies:
		assert_true(m.call(&"_walkable", t), "萤火虫停在走得到的地方")
		assert_false(def.crowd.has(t) or t == def.host_tile, "不停在人站的格子上")
	assert_true(Festivals.act(&"release").is_empty(), "一只没捉，放不了")
	var said := await _say("fest_firefly_host")
	assert_string_contains(said, "0 只")
	var tiles: Array = flies.keys()
	for i in Festivals.FIREFLY_GOAL:
		assert_eq(m.query_use(null, tiles[i], GameMap.Facing.DOWN), &"interact")
		m.perform(&"interact", null, tiles[i])
	assert_eq(Festivals.caught(), Festivals.FIREFLY_GOAL)
	assert_eq(flies.size(), Festivals.FIREFLY_TOTAL - Festivals.FIREFLY_GOAL)
	assert_string_contains(_banners[-1], "去找小满")
	assert_eq(m.query_use(null, tiles[0], GameMap.Facing.DOWN), &"", "捉走的那一格空了")
	await wait_seconds(0.4)
	assert_eq(flies.size(), Festivals.FIREFLY_TOTAL - Festivals.FIREFLY_GOAL, "对过一遍还是剩这么多")
	said = await _say("fest_firefly_host")
	assert_string_contains(said, "|松手|再捉几只")
	await _say("fest_firefly_host", 0)
	assert_eq(_dialogues[-1], "fest_firefly_release")
	assert_true(Festivals.done("release"))
	await wait_seconds(0.4)
	assert_eq(flies.size(), 0, "放掉以后草地上不再有能捉的")
	assert_false(Festivals.catch_firefly())
	said = await _say("fest_firefly_host")
	assert_string_contains(said, "明年还来")


func test_fireflies_only_on_the_night() -> void:
	_at(FIREFLY, 1000.0)
	assert_eq(Festivals.fireflies_left(), 0, "天没黑")
	assert_false(Festivals.catch_firefly())
	_at(FIREFLY, 1200.0)
	assert_eq(Festivals.fireflies_left(), Festivals.FIREFLY_TOTAL)
	assert_true(Festivals.catch_firefly())
	assert_eq(Festivals.caught(), 1)
	_at(FIREFLY + 96, 1200.0)
	assert_eq(Festivals.caught(), 0, "明年从头捉")


func test_the_closest_resident_comes_over_after_the_release() -> void:
	assert_eq(Festivals.heart_npc(), &"", "谁的忆都没找回：没有人来")
	Residents.memory_levels[&"laozhou"] = 1
	Residents.memory_levels[&"ahe"] = 1
	assert_eq(Festivals.heart_npc(), &"ahe", "一样深，取居民表里靠前的")
	Residents.memory_levels[&"laozhou"] = 2
	assert_eq(Festivals.heart_npc(), &"laozhou")
	_at(FIREFLY, 1200.0)
	assert_false(Festivals.heart_due(), "还没放")
	for i in Festivals.FIREFLY_GOAL:
		Festivals.catch_firefly()
	Festivals.act(&"release")
	assert_true(Festivals.heart_due())
	var m := _map(&"nanxi")
	var p := Player.new()
	p.map = m
	m.entities.add_child(p)
	m.player = p
	p.place(GameMap.tile_center(Vector2i(20, 6)), GameMap.Facing.DOWN)
	await wait_seconds(0.4)
	assert_eq(_dialogues.size(), 0, "对话还开着（时间没走）的时候不过来")
	GameClock.running = true
	for i in 100:
		if not _dialogues.is_empty():
			break
		await wait_seconds(0.25)
	GameClock.running = false
	assert_eq(_dialogues, ["fest_firefly_heart_laozhou"] as Array[String])
	assert_false(Festivals.heart_due(), "只来一回")
	var npc: Npc = m.call(&"_npc_of", &"laozhou")
	assert_lt(npc.position.distance_to(p.position), 28.0, "他走到了玩家身边")
	var said := await _say("fest_firefly_heart_laozhou")
	assert_string_contains(said, "钩子")


# ---------------------------------------------------------------- 丰收集

func test_harvest_fair_sorts_goods_into_three_classes() -> void:
	assert_eq(Festivals.category(Database.item(&"pumpkin")), &"crop")
	assert_eq(Festivals.category(Database.item(&"crucian")), &"fish")
	assert_eq(Festivals.category(Database.item(&"egg")), &"animal")
	assert_eq(Festivals.category(Database.item(&"wool")), &"animal")
	assert_eq(Festivals.category(Database.item(&"honey_rape")), &"animal")
	assert_eq(Festivals.category(Database.item(&"pickles")), &"", "加工品不评")
	assert_eq(Festivals.category(Database.item(&"shepherds_purse")), &"", "野菜不评")
	assert_eq(Festivals.category(Database.item(&"hoe")), &"")
	assert_eq(Festivals.category(null), &"")


func test_harvest_fair_judges_what_you_hold() -> void:
	_at(HARVEST, 600.0)
	GameState.money = 0
	_hold(&"hoe")
	assert_eq(Festivals.act(&"judge")["title"], "fest_harvest_reject")
	_hold(&"pumpkin", 2)
	GameState.inventory.add(&"pumpkin", 1, 0)
	var result := Festivals.act(&"judge")
	assert_eq(result["title"], "fest_harvest_result_1", "优品南瓜 315 分，赢过阿禾的 240")
	assert_eq(GameState.money, 800)
	assert_eq(GameState.inventory.count_of(&"pumpkin", 2), 0, "评过的那一个留在台上")
	assert_eq(GameState.inventory.count_of(&"pumpkin"), 1)
	assert_true(Festivals.done("judge_crop"))
	_hold(&"pumpkin")
	assert_eq(Festivals.act(&"judge")["title"], "fest_harvest_twice")
	assert_eq(GameState.inventory.count_of(&"pumpkin"), 1, "评过的项目不再收东西")
	assert_eq(Festivals.said["category"], "作物")
	_hold(&"crucian")
	result = Festivals.act(&"judge")
	assert_eq(result["title"], "fest_harvest_result_4", "一条普通鲫鱼排不上")
	assert_eq(GameState.money, 800)
	assert_string_contains(Festivals.said["best"], "老周")
	_hold(&"milk", 1)
	result = Festivals.act(&"judge")
	assert_eq(result["title"], "fest_harvest_result_2", "良品牛奶 138 分，第二")
	assert_eq(GameState.money, 1200)
	var said := await _say("fest_harvest_result_2")
	assert_string_contains(said, "牛奶")
	assert_string_contains(said, "畜产")
	assert_string_contains(said, "400")
	said = await _say("fest_harvest_host")
	assert_string_contains(said, "三项你都评过了")
	_at(HARVEST, 1100.0)
	_hold(&"pumpkin")
	assert_true(Festivals.act(&"judge").is_empty(), "散了集不评")


func test_harvest_table_talks_to_the_host() -> void:
	_meet_everyone()
	_at(HARVEST, 600.0)
	GameState.selected_slot = 7
	var m := _map(&"town")
	await wait_process_frames(2)
	var counter := Database.festival(&"harvest").counter[1]
	assert_eq(m.query_use(null, counter, GameMap.Facing.UP), &"interact")
	m.perform(&"interact", null, counter)
	assert_eq(_dialogues[-1], "fest_harvest_host")
	GameClock.minutes = 1100.0
	m.perform(&"interact", null, counter)
	assert_string_contains(_banners[-1], "散了")


func test_goods_in_hand_are_for_the_table_not_a_gift() -> void:
	_meet_everyone()
	_at(HARVEST, 600.0)
	_hold(&"pumpkin")
	assert_true(Residents.can_gift(&"bai", GameState.selected_item()))
	assert_true(Festivals.takes_goods(&"bai"))
	assert_false(Festivals.takes_goods(&"ahe"))
	Residents.talk(&"bai", false)
	assert_eq(_dialogues[-1], "fest_harvest_host", "拿着南瓜找柏先生是来评比的，不问送不送")
	Residents.talk(&"ahe", false)
	assert_eq(_dialogues[-1], "gift_offer", "别的居民照常能送")
	_at(SOWING, 600.0)
	assert_false(Festivals.takes_goods(&"bai"), "播种节柏先生不收东西")
	_at(DUMPLING, 1080.0)
	assert_true(Festivals.takes_goods(&"yunniang"))
	_at(DUMPLING, 1000.0)
	assert_false(Festivals.takes_goods(&"yunniang"), "没开席照常")


func test_seed_stall_opens_the_shop() -> void:
	_meet_everyone()
	_at(SOWING, 600.0)
	GameState.selected_slot = 7
	var m := _map(&"town")
	await wait_process_frames(2)
	var counter := Database.festival(&"sowing").counter[0]
	m.perform(&"interact", null, counter)
	assert_eq(_dialogues[-1], "work", "对着摊子就是找阿禾买东西")
	var res: Resource = load(Residents.dialogue_path(&"ahe"))
	var line: Variant = await DialogueManager.get_next_dialogue_line(res, "work")
	assert_string_contains(str(line.text), "草莓种子")
	_at(SOWING + 1, 600.0)
	var plain := _map(&"town")
	assert_eq(plain.query_use(null, counter, GameMap.Facing.UP), &"", "平常的日子广场上没有摊子")
	assert_true(plain.call(&"_walkable", counter))


# ---------------------------------------------------------------- 饺子宴

func test_fillings_have_flavors() -> void:
	var expect := {
		&"bok_choy": &"veg", &"pickles": &"veg", &"crucian": &"fish", &"shepherds_purse": &"wild", &"egg": &"rich", &"cheese": &"rich",
		&"strawberry": &"sweet", &"honey_wild": &"sweet", &"persimmon": &"sweet", &"coal": &"odd", &"wool": &"odd",
		&"camellia": &"odd", &"radish_soup": &"odd", &"hoe": &"", &"white_radish_seed": &"", &"old_wick": &"",
	}
	for id: StringName in expect:
		assert_eq(Festivals.flavor(Database.item(id)), expect[id], String(id))
	assert_eq(Festivals.flavor(null), &"")


func test_dumpling_feast_takes_one_filling() -> void:
	_at(DUMPLING, 1000.0)
	_hold(&"bok_choy")
	assert_true(Festivals.act(&"fill").is_empty(), "五点以前没开席")
	_at(DUMPLING, 1080.0)
	_hold(&"hoe")
	assert_eq(Festivals.act(&"fill")["title"], "fest_dumpling_reject")
	assert_false(Festivals.done("fill"))
	_hold(&"coal")
	GameState.inventory.add(&"coal", 2)
	GameState.energy = 10
	var result := Festivals.act(&"fill")
	assert_eq(result["title"], "fest_dumpling_feast_odd")
	assert_true(result["join"])
	assert_eq(GameState.inventory.count_of(&"coal"), 2, "只收一个")
	assert_eq(GameState.energy, GameState.max_energy, "吃饱了")
	var said := await _say("fest_dumpling_feast_odd")
	assert_string_contains(said, "煤")
	assert_string_contains(said, "硌牙")
	assert_true(Festivals.act(&"fill").is_empty(), "一年一桌")
	said = await _say("fest_dumpling_host")
	assert_string_contains(said, "吃饱了没有")
	_at(DUMPLING + 96, 1080.0)
	_hold(&"crucian")
	assert_eq(Festivals.act(&"fill")["title"], "fest_dumpling_feast_fish")
	said = await _say("fest_dumpling_feast_fish")
	assert_string_contains(said, "鲫鱼")


# ---------------------------------------------------------------- 除夕灯会

func test_lantern_show_grows_with_the_lamps() -> void:
	assert_eq(Festivals.lit_count(), 0)
	assert_eq(Festivals.scale(), 0)
	assert_eq(Festivals.lantern_count(), 4)
	GameState.set_flag(&"lamp_plaza")
	assert_eq(Festivals.scale(), 0)
	GameState.set_flag(&"lamp_river")
	assert_eq(Festivals.scale(), 1)
	assert_eq(Festivals.lantern_count(), 8)
	GameState.set_flag(&"lamp_pasture")
	GameState.set_flag(&"lamp_well")
	assert_eq(Festivals.scale(), 2)
	GameState.set_flag(&"lamp_east")
	GameState.set_flag(&"lamp_shrine")
	assert_eq(Festivals.lit_count(), 6)
	assert_eq(Festivals.scale(), 3)
	assert_eq(Festivals.lantern_count(), 20)
	GameState.set_flag(Story.TRIAL_FLAG)
	Story.choose(true)
	assert_eq(Festivals.lit_count(), 7, "最初的灯也算一盏")
	assert_eq(Residents.lantern_scale(), 3)


func test_plaza_hangs_lanterns_on_new_years_eve() -> void:
	_at(NEWYEAR, 1140.0)
	var few := _map(&"town")
	assert_eq(few.get(&"_lanterns"), 4)
	var decor := Database.festival(&"newyear").decor
	assert_false(few.call(&"_walkable", decor[0]), "灯笼杆挡路")
	assert_true(few.call(&"_walkable", decor[10]), "没挂到的地方是空的")
	few.free()
	for id: String in ["plaza", "river", "pasture", "well", "east", "shrine"]:
		GameState.set_flag(StringName("lamp_" + id))
	var full := _map(&"town")
	assert_eq(full.get(&"_lanterns"), 20)
	assert_false(full.call(&"_walkable", decor[19]))
	full.free()
	_at(NEWYEAR - 1, 1140.0)
	var plain := _map(&"town")
	assert_eq(plain.get(&"_lanterns"), 0, "平常没有灯笼")
	assert_true(plain.call(&"_walkable", decor[0]))


func test_year_income_adds_up_and_starts_over_in_spring() -> void:
	GameClock.day = 90
	Shipping.add(&"white_radish", 2)
	GameClock.advance_day()
	assert_eq(Shipping.year_income, 70)
	Shipping.add(&"white_radish", 1)
	GameClock.advance_day()
	assert_eq(Shipping.year_income, 105)
	var data := Shipping.save_data()
	Shipping.reset_data()
	assert_eq(Shipping.year_income, 0)
	Shipping.load_data(data)
	assert_eq(Shipping.year_income, 105, "进了存档")
	GameClock.day = 96
	Shipping.add(&"white_radish", 1)
	GameClock.advance_day()
	assert_eq(GameClock.day_of_season(), 1)
	assert_eq(Shipping.year_income, 35, "开春重新算，头一天早上结的货算新年的")


func test_new_year_summary_and_vigil() -> void:
	_meet_everyone()
	_at(NEWYEAR, 1000.0)
	assert_true(Festivals.act(&"summary").is_empty())
	assert_true(Festivals.act(&"vigil").is_empty())
	_at(NEWYEAR, 1140.0)
	Shipping.year_income = 4321
	GameState.set_flag(&"lamp_plaza")
	Mine.deepest = 17
	Residents.memory_levels[&"ahe"] = 1
	var said := await _say("fest_newyear_host")
	assert_string_contains(said, "|听听这一年|和大家一起守岁|再逛逛")
	await _say("fest_newyear_host", 0)
	assert_eq(_dialogues[-1], "fest_newyear_summary")
	said = await _say("fest_newyear_summary")
	assert_string_contains(said, "第 1 年")
	assert_string_contains(said, "4321 文")
	assert_string_contains(said, "1 盏")
	assert_string_contains(said, "1 段")
	assert_string_contains(said, "第 17 层")
	assert_string_contains(said, "12 位")
	await _say("fest_newyear_host", 1)
	assert_eq(_dialogues[-1], "fest_newyear_vigil")
	assert_true(Festivals.done("vigil"))
	assert_eq(Residents.familiarity_of(&"jiang"), Festivals.JOIN_POINTS)
	said = await _say("fest_newyear_host")
	assert_false(said.contains("守岁|"), "守过了就不再问")
	assert_eq(_sleeps, 0)
	await _say("fest_newyear_vigil")
	assert_eq(_sleeps, 1, "守完岁一觉到新年")
	GameClock.advance_day()
	assert_eq(GameClock.year(), 2)
	assert_string_contains(Festivals.morning_note(), "守了一夜的岁")
	GameClock.advance_day()
	assert_eq(Festivals.morning_note(), "")


func test_no_vigil_no_note() -> void:
	_at(NEWYEAR, 1140.0)
	GameClock.advance_day()
	assert_eq(Festivals.morning_note(), "")


# ---------------------------------------------------------------- 画面

func test_festival_art() -> void:
	assert_eq(FestivalArt.stall().get_size(), Vector2i(36, 36))
	assert_eq(FestivalArt.table("harvest").get_size(), Vector2i(52, 24))
	assert_ne(FestivalArt.table("harvest").get_data(), FestivalArt.table("dumpling").get_data())
	assert_ne(FestivalArt.lantern_pole(true).get_data(), FestivalArt.lantern_pole(false).get_data())
	assert_ne(FestivalArt.river_lantern(0).get_data(), FestivalArt.river_lantern(1).get_data())
	assert_ne(FestivalArt.firefly(0).get_data(), FestivalArt.firefly(1).get_data())
	assert_gt(FestivalArt.firefly(0).get_pixel(2, 2).a, 0.9)
