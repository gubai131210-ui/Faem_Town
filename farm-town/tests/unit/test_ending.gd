extends GutTest
## M6 第三批：终幕（井底最初的灯）和三个结局，以及结局以后镇上的变化。

const ENDING_PATH := "res://dialogue/ending.dialogue"
const LAN_PATH := "res://dialogue/lan.dialogue"

var _banners: Array[String] = []
var _dialogues: Array[String] = []
var _endings: Array[StringName] = []


func before_each() -> void:
	SaveSystem.reset_all()
	Weather.today = &"sunny"
	Weather.yesterday = &"sunny"
	GameClock.minutes = 600.0
	GameClock.day = 1
	_banners.clear()
	_dialogues.clear()
	_endings.clear()
	EventBus.banner_requested.connect(_on_banner)
	EventBus.dialogue_requested.connect(_on_dialogue)
	EventBus.ending_requested.connect(_on_ending)


func after_each() -> void:
	EventBus.banner_requested.disconnect(_on_banner)
	EventBus.dialogue_requested.disconnect(_on_dialogue)
	EventBus.ending_requested.disconnect(_on_ending)
	Mine.leave()
	SaveSystem.reset_all()
	Weather.today = &"sunny"
	Weather.yesterday = &"sunny"
	GameClock.running = false


func _on_banner(text: String) -> void:
	_banners.append(text)


func _on_dialogue(_path: String, title: String) -> void:
	_dialogues.append(title)


func _on_ending(ending: StringName) -> void:
	_endings.append(ending)


func _map(id: StringName) -> Node2D:
	var scene: PackedScene = load(SceneRouter.MAPS[id])
	var m: Node2D = scene.instantiate()
	add_child_autofree(m)
	return m


## 走一段对话，返回说过的话。碰到选项选第 pick 个；pick 小于 0 时把选项的字也记下来就停。
func _say(path: String, title: String, pick: int = -1) -> String:
	var res: Resource = load(path)
	var said := ""
	var line: Variant = await DialogueManager.get_next_dialogue_line(res, title)
	while line != null:
		said += str(line.text)
		var next: String = line.next_id
		if not line.responses.is_empty():
			if pick < 0:
				for r: Variant in line.responses:
					said += "|" + str(r.text)
				break
			next = line.responses[pick].next_id
		if next == "end" or next == "":
			break
		line = await DialogueManager.get_next_dialogue_line(res, next)
	return said


## 让归名的条件齐全。
func _remember_everything() -> void:
	for m in Database.memories:
		Residents.memory_levels[m.npc] = Story.MEMORY_MAX
	GameState.set_flag(Story.LAN_FLAG)


# ---------------------------------------------------------------- 规则

func test_nothing_to_choose_before_the_trial() -> void:
	assert_eq(Story.ending(), &"")
	assert_false(Story.can_choose())
	assert_eq(Story.choose(true), &"", "考验没走完，点不了")
	assert_eq(Story.ending(), &"")


func test_keeping_the_fog_can_be_undone_but_lighting_cannot() -> void:
	GameState.set_flag(Story.TRIAL_FLAG)
	assert_true(Story.can_choose())
	assert_eq(Story.choose(false), Story.KEEP)
	assert_eq(Story.ending(), Story.KEEP)
	assert_true(Story.kept())
	assert_false(Story.lamp_lit())
	assert_true(Story.can_choose(), "选了不点，以后还能改主意")
	assert_eq(Story.choose(true), Story.CLEAR)
	assert_eq(Story.ending(), Story.CLEAR)
	assert_true(Story.lamp_lit())
	assert_false(Story.kept())
	assert_false(Story.can_choose(), "点了就不能再选")
	assert_eq(Story.choose(false), &"")
	assert_eq(Story.ending(), Story.CLEAR)


func test_true_ending_needs_every_memory_and_lan() -> void:
	GameState.set_flag(Story.TRIAL_FLAG)
	assert_eq(Story.unfinished().size(), 11, "十一位有忆的居民都还没找全")
	assert_false(Story.unfinished().has(&"xiaoman"), "小满什么都没忘，不算在里面")
	assert_false(Story.true_ready())
	for m in Database.memories:
		Residents.memory_levels[m.npc] = Story.MEMORY_MAX
	assert_eq(Story.unfinished().size(), 0)
	assert_false(Story.true_ready(), "还差岚")
	GameState.set_flag(Story.LAN_FLAG)
	Residents.memory_levels[&"laozhou"] = Story.MEMORY_MAX - 1
	assert_false(Story.true_ready(), "还差老周一级")
	Residents.memory_levels[&"laozhou"] = Story.MEMORY_MAX
	assert_true(Story.true_ready())
	assert_eq(Story.choose(false), Story.KEEP, "条件齐了也可以不点")
	assert_eq(Story.choose(true), Story.NAME)
	assert_eq(Story.ending(), Story.NAME)
	assert_true(Story.lamp_lit())


func test_ending_survives_a_save() -> void:
	GameState.set_flag(Story.TRIAL_FLAG)
	Story.choose(true)
	var data := GameState.save_data()
	GameState.reset_data()
	assert_eq(Story.ending(), &"")
	GameState.load_data(data)
	assert_eq(Story.ending(), Story.CLEAR)


# ---------------------------------------------------------------- 井底

func test_the_altar_offers_the_choice_after_the_trial() -> void:
	Mine.enter(40, 1)
	var altar := Mine.current.altar
	var m: GameMap = _map(&"mine")
	m.perform(&"interact", null, altar)
	assert_true(GameState.has_flag(Story.TRIAL_FLAG))
	assert_string_contains(_banners[-1], "旧矿灯", "考验走完的提示里说到龛里的灯")
	assert_eq(_dialogues.size(), 0, "放灯的那一下不直接进终幕")
	m.perform(&"interact", null, altar)
	assert_eq(_dialogues[-1], "first_lamp")
	Story.choose(false)
	m.perform(&"interact", null, altar)
	assert_eq(_dialogues.size(), 2, "选了不点，再来还能选")
	Story.choose(true)
	m.perform(&"interact", null, altar)
	assert_eq(_dialogues.size(), 2, "点亮以后不再问")
	assert_string_contains(_banners[-1], "两盏灯都亮着")


func test_floor_forty_mentions_the_first_lamp() -> void:
	GameState.set_flag(Story.TRIAL_FLAG)
	Mine.bosses.append(40)
	Mine.enter(40, 1)
	var m: GameMap = _map(&"mine")
	m.entered()
	assert_string_contains(_banners[-1], "还黑着")
	Story.choose(true)
	m.entered()
	assert_string_contains(_banners[-1], "也亮着")


func test_first_lamp_dialogue_has_three_choices() -> void:
	GameState.set_flag(Story.TRIAL_FLAG)
	var said := await _say(ENDING_PATH, "first_lamp")
	assert_string_contains(said, "旧矿灯")
	assert_string_contains(said, "没把自己的事想全", "条件没齐，岚会提醒")
	assert_string_contains(said, "|点亮它|不点，让雾留着|再想想")
	assert_eq(_endings.size(), 0)
	said = await _say(ENDING_PATH, "first_lamp", 2)
	assert_string_contains(said, "收了回来")
	assert_eq(_endings.size(), 0, "再想想：什么都不发生")
	assert_eq(Story.ending(), &"")
	await _say(ENDING_PATH, "first_lamp", 1)
	assert_eq(_endings, [Story.KEEP] as Array[StringName])
	said = await _say(ENDING_PATH, "first_lamp")
	assert_string_contains(said, "你又下来了")
	await _say(ENDING_PATH, "first_lamp", 0)
	assert_eq(_endings, [Story.KEEP, Story.CLEAR] as Array[StringName])


func test_first_lamp_dialogue_when_everyone_remembers() -> void:
	GameState.set_flag(Story.TRIAL_FLAG)
	_remember_everything()
	var said := await _say(ENDING_PATH, "first_lamp")
	assert_string_contains(said, "脚步声")
	assert_false(said.contains("没把自己的事想全"))
	await _say(ENDING_PATH, "first_lamp", 0)
	assert_eq(_endings, [Story.NAME] as Array[StringName])


func test_each_ending_has_its_narration() -> void:
	var keep := await _say(ENDING_PATH, "end_keep")
	assert_string_contains(keep, "没有认出你")
	var clear := await _say(ENDING_PATH, "end_clear")
	assert_string_contains(clear, "葬礼")
	assert_string_contains(clear, "蹄印")
	var named := await _say(ENDING_PATH, "end_name")
	assert_string_contains(named, "青岚")
	assert_string_contains(named, "它没有散")
	for id: StringName in Story.TITLES:
		assert_gt(String(Story.TITLES[id]).length(), 0)


# ---------------------------------------------------------------- 结局以后

func test_every_resident_speaks_once_after_the_lamp() -> void:
	GameState.set_flag(Story.TRIAL_FLAG)
	for id: StringName in Database.npcs:
		Residents.met[id] = true
		assert_ne(Residents.title_for(id, false), Residents.ENDING_NEWS, "灯没点，没有这一段")
	Story.choose(false)
	assert_ne(Residents.title_for(&"jiang", false), Residents.ENDING_NEWS, "留雾：镇上没人知道")
	Story.choose(true)
	for id: StringName in Database.npcs:
		assert_eq(Residents.title_for(id, true), Residents.ENDING_NEWS, "%s 先说那天的事" % id)
		var said := await _say(Residents.dialogue_path(id), Residents.ENDING_NEWS)
		assert_gt(said.length(), 10, "%s 有话说" % id)
	GameState.selected_slot = 5
	Residents.talk(&"jiang", false)
	assert_eq(_dialogues[-1], Residents.ENDING_NEWS)
	assert_ne(Residents.title_for(&"jiang", false), Residents.ENDING_NEWS, "只说一回")
	assert_eq(Residents.title_for(&"ahe", true), Residents.ENDING_NEWS, "别人的还留着")


func test_news_waits_for_the_first_meeting() -> void:
	GameState.set_flag(Story.TRIAL_FLAG)
	Story.choose(true)
	assert_eq(Residents.title_for(&"egret", false), "first", "没见过面的先认识")


func test_named_ending_adds_lines_about_the_deer() -> void:
	GameState.set_flag(Story.TRIAL_FLAG)
	_remember_everything()
	Story.choose(true)
	var said := await _say(Residents.dialogue_path(&"xiaoman"), Residents.ENDING_NEWS)
	assert_string_contains(said, "白鹿")
	said = await _say(Residents.dialogue_path(&"bai"), Residents.ENDING_NEWS)
	assert_string_contains(said, "镇子的名字")


func test_jiang_knows_you_after_the_lamp() -> void:
	GameState.set_flag(Story.TRIAL_FLAG)
	var before := await _say(Residents.dialogue_path(&"jiang"), "daily")
	assert_false(before.contains("囡囡"))
	Story.choose(false)
	before = await _say(Residents.dialogue_path(&"jiang"), "daily")
	assert_false(before.contains("囡囡"), "留雾：她还是认不出")
	Story.choose(true)
	var seen := ""
	for day in 4:
		GameClock.day = 10 + day
		Residents._on_new_day()
		seen += await _say(Residents.dialogue_path(&"jiang"), "daily")
	assert_string_contains(seen, "囡囡")
	assert_string_contains(seen, "灯塔")
	assert_false(seen.contains("谁家的孩子"))


func test_lan_after_each_ending() -> void:
	GameState.set_flag(Story.TRIAL_FLAG)
	GameState.set_flag(&"lan_talked")
	GameState.set_flag(&"lan_shade_told")
	Story.choose(false)
	var hill: OutdoorMap = _map(&"shanci")
	assert_false(hill.call(&"lan_here"), "留雾：还是只在雾天")
	Weather.today = &"fog"
	assert_true(hill.call(&"lan_here"))
	var said := await _say(LAN_PATH, "daily")
	assert_string_contains(said, "你没有点")
	said = await _say(LAN_PATH, "daily")
	assert_false(said.contains("你没有点"), "只说一回")
	Story.choose(true)
	assert_false(hill.call(&"lan_here"), "散雾：岚不在了，雾天也不在")
	await wait_process_frames(4)
	assert_null(hill.get(&"_lan"))
	hill.perform(&"interact", null, Vector2i(21, 9))
	assert_string_contains(_banners[-1], "干净的")


func test_named_lan_stays_at_the_shrine() -> void:
	GameState.set_flag(Story.TRIAL_FLAG)
	_remember_everything()
	Story.choose(true)
	var hill: OutdoorMap = _map(&"shanci")
	assert_true(hill.call(&"lan_here"), "归名：晴天也在")
	await wait_process_frames(4)
	assert_not_null(hill.get(&"_lan"))
	var at: Vector2i = hill.get(&"LAN_TILE")
	GameClock.day = 77
	hill.perform(&"interact", null, at)
	assert_eq(_dialogues[-1], "named")
	hill.perform(&"interact", null, at)
	assert_eq(_dialogues[-1], "named_again")
	var said := await _say(LAN_PATH, "named")
	assert_gt(said.length(), 10)
	said = await _say(LAN_PATH, "named_again")
	assert_gt(said.length(), 4)
	hill.perform(&"interact", null, Vector2i(21, 9))
	assert_string_contains(_banners[-1], "青岚")


func test_lighthouse_lights_up() -> void:
	GameState.set_flag(Story.TRIAL_FLAG)
	var beach: OutdoorMap = _map(&"dongtan")
	var box: Array = beach.get(&"LIGHTHOUSE")
	var door := Vector2i(int(box[0]), int(box[3]))
	beach.perform(&"interact", null, door)
	assert_string_contains(_banners[-1], "黑的")
	Story.choose(true)
	beach.perform(&"interact", null, door)
	assert_string_contains(_banners[-1], "亮了")


# ---------------------------------------------------------------- 画面

func test_ending_art() -> void:
	var keep := EndingArt.scene(Story.KEEP)
	var clear := EndingArt.scene(Story.CLEAR)
	var named := EndingArt.scene(Story.NAME)
	assert_eq(keep.get_size(), Vector2i(EndingArt.W, EndingArt.H))
	assert_ne(keep.get_data(), clear.get_data())
	assert_ne(clear.get_data(), named.get_data())
	assert_eq(keep.get_pixel(0, EndingArt.H - 1).a, 1.0, "画是铺满的")
	assert_ne(MineDarkArt.altar(true).get_data(), MineDarkArt.altar(true, true).get_data(), "最初的灯亮了，龛里不一样")
	assert_ne(BeachArt.lighthouse(false).get_data(), BeachArt.lighthouse(true).get_data())


func test_ending_screen_shows_the_title_and_waits() -> void:
	var screen := EndingScreen.new()
	add_child_autofree(screen)
	assert_false(screen.is_open())
	screen.open(Story.CLEAR)
	assert_true(screen.is_open())
	assert_false(screen.is_waiting(), "旁白没念完，按键不收")
	assert_eq(screen.title_text(), "散雾")
	watch_signals(screen)
	await screen.show_title()
	assert_true(screen.is_waiting())
	var ev := InputEventAction.new()
	ev.action = &"use"
	ev.pressed = true
	screen._unhandled_input(ev)
	assert_signal_emitted(screen, "closed")
	assert_false(screen.is_waiting())
	screen.close()
	assert_false(screen.is_open())
