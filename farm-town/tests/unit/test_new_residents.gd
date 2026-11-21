extends GutTest
## M13 第五批（名单已过目）：六位新居民进表、被各自的灯带回、站得住、能搭话能送礼。
## 归名条件不变——六位各有三段忆，不进 Story.unfinished()。

const TMP_SAVES := "user://test_saves_new_residents"
const NEW_IDS: Array[StringName] = [
	&"shuoshu", &"jiangyuan", &"huolang", &"chuanniang", &"miaozhu", &"shanliren",
]
## 每位：id -> 灯标记、出入门、灯亮后的日程落点
const PLAN: Dictionary = {
	&"shuoshu": {
		"lamp": &"lamp_plaza", "map": &"town", "door": [24, 18],
		"spots": [[25, 16], [27, 17], [28, 17]],
	},
	&"jiangyuan": {
		"lamp": &"lamp_river", "map": &"wharf", "door": [11, 13],
		"spots": [[11, 13], [18, 13], [24, 14]],
	},
	&"huolang": {
		"lamp": &"lamp_pasture", "map": &"pasture", "door": [42, 14],
		"spots": [[2, 12], [6, 13], [9, 13]],
	},
	&"chuanniang": {
		"lamp": &"lamp_east", "map": &"dongtan", "door": [2, 14],
		"spots": [[17, 24], [18, 24], [20, 24]],
	},
	&"miaozhu": {
		"lamp": &"lamp_shrine", "map": &"shanci", "door": [21, 28],
		"spots": [[21, 16], [22, 17], [24, 14]],
	},
	&"shanliren": {
		"lamp": &"lamp_shrine", "map": &"shanci", "door": [22, 28],
		"spots": [[30, 9], [31, 9], [30, 12]],
	},
}
## 钉死、不能被新居民占的格子
const KEEP_CLEAR: Dictionary = {
	&"town": [[8, 17], [8, 9], [37, 9], [9, 9], [22, 10], [37, 18], [22, 9], [38, 18]],
	&"dongtan": [[27, 20], [13, 11]],
	&"wharf": [[26, 14]],  # 河埠默认出生点，居民不该占
}


var _old_dir := ""


func before_each() -> void:
	_old_dir = SaveSystem.base_dir
	SaveSystem.base_dir = TMP_SAVES
	SaveSystem.reset_all()
	Weather.today = &"sunny"


func after_each() -> void:
	for i in SaveSystem.SLOT_COUNT:
		SaveSystem.delete(i)
	SaveSystem.base_dir = _old_dir
	SaveSystem.current_slot = -1
	SaveSystem.reset_all()


func _map(id: StringName) -> OutdoorMap:
	var scene: PackedScene = load(SceneRouter.MAPS[id])
	var map: OutdoorMap = scene.instantiate()
	add_child_autofree(map)
	return map


func _all_lamps() -> void:
	for flag: StringName in [&"lamp_plaza", &"lamp_river", &"lamp_pasture", &"lamp_well", &"lamp_east", &"lamp_shrine"]:
		GameState.set_flag(flag)


# ---------------------------------------------------------------- 表与素材

func test_six_new_residents_are_in_the_table_and_validate() -> void:
	assert_eq(Database.validate(), PackedStringArray(), "数据表校验通过")
	for id in NEW_IDS:
		assert_true(Database.has_npc(id), "有居民 %s" % id)
		var def := Database.npc(id)
		assert_ne(def.name, "", "%s 有名字" % id)
		assert_ne(def.role, "", "%s 有身份" % id)
		assert_not_null(UiKit.face(def.sheet), "%s 有头像" % id)
		assert_false(def.loves.is_empty() or def.likes.is_empty(), "%s 有喜好" % id)
	assert_eq(Database.npcs.size(), 18, "原十二位加六位新居民")


func test_new_residents_use_existing_sheets_and_gated_schedules() -> void:
	for id in NEW_IDS:
		var def := Database.npc(id)
		var p: Dictionary = PLAN[id]
		assert_eq(def.sheet, String(id), "%s 用同名序列帧" % id)
		assert_eq(String(def.early_until), String(p["lamp"]), "%s 由 %s 带回" % [id, p["lamp"]])
		assert_false(def.early_schedule.is_empty(), "%s 灯亮前有一套日程（在家）" % id)
		var early := NpcSchedule.plan_for(def, &"sunny")
		assert_eq(early[0]["map"], &"", "%s 灯亮前不在任何地图上" % id)
		assert_true(def.enter.has(p["map"]), "%s 写了 %s 的进出口" % [id, p["map"]])
		assert_eq(def.enter[p["map"]], Vector2i(p["door"][0], p["door"][1]), "%s 的进出口对" % id)


# ---------------------------------------------------------------- 归名不变

func test_new_residents_have_three_memories_and_stay_out_of_the_ending() -> void:
	for id in NEW_IDS:
		assert_eq(Database.memory_cap(id), 3, "%s 三段忆" % id)
		assert_false(Story.unfinished().has(id), "%s 不进归名条件" % id)
		assert_eq(Residents.memory_level(id), 0, "%s 一开始还没想起" % id)
		assert_false(Residents.relic_available(Database.relic(Database.memory(id, 2).relic)), "%s 的第二件先不出" % id)
		assert_true(Residents.relic_available(Database.relic(Database.memory(id, 1).relic)))
	Residents.familiarity[&"shuoshu"] = Residents.familiarity_cap(&"shuoshu")
	var page := Database.item(&"story_page")
	assert_true(Residents.can_return(&"shuoshu", page))
	assert_eq(Residents.return_relic(&"shuoshu", &"story_page").level, 1)
	assert_true(Residents.relic_available(Database.relic(&"story_sheet")))
	assert_false(Story.unfinished().has(&"shuoshu"), "找回一段也不进归名")
	for id: StringName in Database.npcs:
		if Database.memory(id, 5) != null:
			Residents.memory_levels[id] = 5
	for level in range(1, 6):
		GameState.set_flag(StringName("memory_lan_%d" % level))
	assert_true(Story.true_ready(), "六位停在第 0 级，归名仍然凑得齐")
	assert_eq(Story.unfinished().size(), 0)


# ---------------------------------------------------------------- 落点站得住

func test_new_resident_doors_and_spots_are_walkable() -> void:
	_all_lamps()
	var maps: Dictionary[StringName, OutdoorMap] = {}
	for id in NEW_IDS:
		var p: Dictionary = PLAN[id]
		var map_id: StringName = p["map"]
		if not maps.has(map_id):
			maps[map_id] = _map(map_id)
		var map: OutdoorMap = maps[map_id]
		var door := Vector2i(p["door"][0], p["door"][1])
		assert_false(map.blocked(map.tile_center(door)), "%s 的出入口站得住" % id)
		for spot in p["spots"]:
			var tile := Vector2i(spot[0], spot[1])
			assert_false(map.blocked(map.tile_center(tile)), "%s 的落点 %s 站得住" % [id, tile])
			if tile != door:
				assert_gt(map.find_path(door, tile).size(), 0, "%s 从门口走得到 %s" % [id, tile])
			if KEEP_CLEAR.has(map_id):
				for fixed: Array in KEEP_CLEAR[map_id]:
					assert_ne(tile, Vector2i(fixed[0], fixed[1]), "%s 不占钉死的格子" % id)


func test_new_residents_never_share_a_spot_with_each_other() -> void:
	## 庙祝和山里人同在 shanci、同一盏灯带回；晴天雨天、灯亮后都不能站在同一格。
	_all_lamps()
	for weather: StringName in [&"sunny", &"rain"]:
		for minute in range(360, 1300, 10):
			var taken: Dictionary[String, StringName] = {}
			for id in NEW_IDS:
				var spot := NpcSchedule.spot_at(Database.npc(id), float(minute), weather)
				if spot["map"] == &"":
					continue
				var tile: Vector2i = spot["tile"]
				var key := "%s:%s" % [spot["map"], tile]
				assert_false(taken.has(key), "%s 天 %d 分 %s 和 %s 都在 %s 的 %s" % [weather, minute, id, taken.get(key, &""), spot["map"], tile])
				taken[key] = id


func test_new_residents_appear_after_their_lamp_and_stay_home_before() -> void:
	for id in NEW_IDS:
		var def := Database.npc(id)
		var p: Dictionary = PLAN[id]
		var map_id: StringName = p["map"]
		var before := NpcSchedule.spot_at(def, 600.0, &"sunny")
		assert_eq(before["map"], &"", "%s 灯没亮时不在地图上" % id)
	_all_lamps()
	for id in NEW_IDS:
		var def := Database.npc(id)
		var p: Dictionary = PLAN[id]
		var after := NpcSchedule.spot_at(def, 600.0, &"sunny")
		assert_eq(after["map"], p["map"], "%s 灯亮后回到 %s" % [id, p["map"]])
		assert_eq(after["tile"], Vector2i(p["spots"][0][0], p["spots"][0][1]), "%s 站在自己的位置" % id)


# ---------------------------------------------------------------- 对话与送礼

func test_new_residents_have_all_dialogue_titles() -> void:
	for id in NEW_IDS:
		var res: Resource = load(Residents.dialogue_path(id))
		assert_not_null(res, "%s 的对话文件能导入" % id)
		if res == null:
			continue
		for title: String in ["first", "work", "daily", "again", "ending_news", "gift_love", "gift_like", "gift_ok", "gift_dislike"]:
			var line: Variant = await DialogueManager.get_next_dialogue_line(res, title)
			assert_not_null(line, "%s 的 %s 段有内容" % [id, title])


func test_new_residents_accept_gifts_and_remember_tastes() -> void:
	for id in NEW_IDS:
		var def := Database.npc(id)
		Residents.greet(String(id))
		var favorite: StringName = def.loves[0]
		var taste := Residents.give(id, favorite, 0)
		assert_eq(taste, &"love", "%s 喜欢 %s" % [id, favorite])
		assert_true(Residents.known(id, &"love").has(favorite), "%s 记住了这个喜好" % id)
		assert_eq(Residents.talks(id), 0, "送礼不算说话")


func test_new_residents_really_spawn_on_their_maps_after_lamps() -> void:
	_all_lamps()
	GameClock.day = 1
	GameClock.minutes = 600.0
	var plan: Dictionary = {
		&"town": [&"shuoshu"], &"wharf": [&"jiangyuan"], &"pasture": [&"huolang"],
		&"dongtan": [&"chuanniang"], &"shanci": [&"miaozhu", &"shanliren"],
	}
	for map_id: StringName in plan:
		var scene: PackedScene = load(SceneRouter.MAPS[map_id])
		var map: OutdoorMap = scene.instantiate()
		add_child_autofree(map)
		for id: StringName in plan[map_id]:
			assert_not_null(map._npc_of(id), "%s 灯亮后真的出现在 %s" % [id, map_id])


func test_float_lanterns_still_include_everyone_after_the_end() -> void:
	_all_lamps()
	GameState.set_flag(Story.TRIAL_FLAG)
	Story.choose(true)
	assert_eq(Festivals.floaters().size(), Database.npcs.size(), "结局灯亮了，十八位人人放灯")
	for id in NEW_IDS:
		assert_true(Festivals.floaters().has(id), "%s 也放一盏" % id)
