extends GutTest
## M2 第一批：居民的定义和日程、寻路、搭话、两家铺子的货单、镇广场地图。

const TMP_SAVES := "user://test_saves"
const NPC_IDS: Array[StringName] = [
	&"jiang", &"xiaoman", &"bai", &"ahe", &"shishu", &"qingzhu",
	&"yunniang", &"laozhou", &"amu", &"laoqin", &"luyuan", &"egret",
	&"shuoshu", &"jiangyuan", &"huolang", &"chuanniang", &"miaozhu", &"shanliren",
]

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


func _def() -> NpcDef:
	return NpcDef.from_dict({
		"id": "tester", "name": "测试", "sheet": "ahe", "service": "grocery",
		"enter": {"town": [3, 4]},
		"schedule": [
			{"from": "8:00", "map": "town", "tile": [5, 6], "facing": "left", "work": true},
			{"from": "18:30", "map": "town", "tile": [9, 9]},
			{"from": "20:00"},
		],
		"rain_schedule": [{"from": "9:00", "map": "town", "tile": [1, 1]}],
	})


# ---------------------------------------------------------------- 定义

func test_parse_time() -> void:
	assert_eq(NpcDef.parse_time("8:30"), 510)
	assert_eq(NpcDef.parse_time("25:00"), 1500)
	assert_eq(NpcDef.parse_time("八点"), -1)


func test_npc_def_from_dict() -> void:
	var def := _def()
	assert_eq(def.id, &"tester")
	assert_eq(def.service, &"grocery")
	assert_eq(def.enter[&"town"], Vector2i(3, 4))
	assert_eq(def.schedule.size(), 3)
	var first := def.schedule[0]
	assert_eq(first["from"], 480)
	assert_eq(first["map"], &"town")
	assert_eq(first["tile"], Vector2i(5, 6))
	assert_eq(first["facing"], GameMap.Facing.LEFT)
	assert_true(first["work"])
	assert_eq(def.schedule[2]["map"], &"", "不写地图就是回家")


func test_npc_table_is_valid() -> void:
	assert_eq(Database.validate(), PackedStringArray(), "数据表校验通过")
	assert_eq(Database.npcs.size(), NPC_IDS.size(), "十八位居民")
	for id in NPC_IDS:
		assert_true(Database.has_npc(id), "有居民 %s" % id)
		assert_ne(Database.npc(id).role, "", "%s 有身份" % id)
		assert_not_null(UiKit.face(Database.npc(id).sheet), "%s 有头像" % id)
	assert_eq(Database.npc(&"ahe").service, &"grocery")
	assert_eq(Database.npc(&"shishu").service, &"smith")


func test_snow_exceptions_send_xiaoman_and_qingzhu_to_work() -> void:
	var xm := Database.npc(&"xiaoman")
	var spot := NpcSchedule.spot_at(xm, 720.0, &"snow")
	assert_eq(str(spot["note"]), "snowman", "雪天小满在广场堆雪人")
	assert_eq(str(spot["pose"]), "squat")
	assert_eq(str(NpcSchedule.spot_at(xm, 720.0, &"sunny")["note"]), "board", "晴天还是看告示")
	var qz := Database.npc(&"qingzhu")
	var qspot := NpcSchedule.spot_at(qz, 600.0, &"snow")
	assert_eq(str(qspot["note"]), "door", "雪天青竹扫门口")
	assert_eq(str(qspot["pose"]), "sweep")


func test_snowman_stays_until_the_snow_melts() -> void:
	var town: OutdoorMap = load("res://maps/town/town.tscn").instantiate()
	add_child_autofree(town)
	var was_today := Weather.today
	var was_yest := Weather.yesterday
	GameState.set_flag(&"snowman_built")
	Weather.today = Weather.SNOW
	Weather.yesterday = Weather.SNOW
	town._refresh_snowman()
	assert_not_null(town._snowman, "雪还没化，雪人站着")
	Weather.today = Weather.SUNNY
	Weather.yesterday = Weather.SNOW
	town._refresh_snowman()
	assert_not_null(town._snowman, "雪停当天还不化")
	Weather.yesterday = Weather.SUNNY
	town._refresh_snowman()
	assert_null(town._snowman, "化雪了收走")
	assert_false(GameState.has_flag(&"snowman_built"))
	Weather.today = was_today
	Weather.yesterday = was_yest


func test_validate_npc_catches_mistakes() -> void:
	assert_eq(Database.validate_npc(_def()), PackedStringArray())
	var bad := NpcDef.from_dict({
		"id": "Bad", "sheet": "nobody", "service": "bank",
		"enter": {"moon": [0, 0]},
		"schedule": [
			{"from": "9:00", "map": "town", "tile": [1, 1]},
			{"from": "8:00", "map": "moon", "tile": [1, 1]},
		],
	})
	var text := "\n".join(Database.validate_npc(bad))
	for expect: String in ["小写下划线", "没有名字", "铺子无效", "序列帧不存在", "头像不存在", "出入口在不存在的地图", "从早到晚", "没写从哪一格进出"]:
		assert_string_contains(text, expect)


# ---------------------------------------------------------------- 日程

func test_schedule_spot_by_time() -> void:
	var def := _def()
	assert_eq(NpcSchedule.spot_at(def, 400.0, &"sunny")["map"], &"", "没到点还在家")
	assert_eq(NpcSchedule.spot_at(def, 480.0, &"sunny")["tile"], Vector2i(5, 6))
	assert_eq(NpcSchedule.spot_at(def, 1109.9, &"sunny")["tile"], Vector2i(5, 6))
	assert_eq(NpcSchedule.spot_at(def, 1110.0, &"sunny")["tile"], Vector2i(9, 9))
	assert_eq(NpcSchedule.spot_at(def, 1300.0, &"sunny")["map"], &"", "晚上回家")
	assert_true(NpcSchedule.is_on(def, 600.0, &"sunny", &"town"))
	assert_false(NpcSchedule.is_on(def, 600.0, &"sunny", &"farm"))
	assert_false(NpcSchedule.is_on(def, 1300.0, &"sunny", &"town"))


func test_schedule_rainy_day() -> void:
	var def := _def()
	for weather: StringName in [&"rain", &"storm", &"snow"]:
		assert_eq(NpcSchedule.spot_at(def, 600.0, weather)["tile"], Vector2i(1, 1), "%s 用雨天日程" % weather)
	assert_eq(NpcSchedule.spot_at(def, 600.0, &"fog")["tile"], Vector2i(5, 6), "雾天照常")
	def.rain_schedule.clear()
	assert_eq(NpcSchedule.spot_at(def, 600.0, &"rain")["tile"], Vector2i(5, 6), "没写雨天日程就照常")


# ---------------------------------------------------------------- 平常 + 例外（决策 073）

func _exc_def() -> NpcDef:
	return NpcDef.from_dict({
		"id": "tester", "name": "测试", "sheet": "ahe", "service": "grocery",
		"enter": {"town": [3, 4]},
		"schedule": [
			{"from": "8:00", "map": "town", "tile": [5, 6]},
			{"from": "12:00", "map": "town", "tile": [7, 7]},
			{"from": "18:00", "map": "town", "tile": [9, 9]},
			{"from": "20:00"},
		],
		"exceptions": [
			{"season": "summer", "from": "12:00", "to": "15:00",
				"plan": [{"from": "12:00", "map": "town", "tile": [2, 2], "note": "shade"}]},
		],
	})


## 除雪天例外外，每时每刻的去处必须和“只按天气/灯亮选整套”一模一样。
## 雪天小满堆雪人、青竹扫雪是第二批加的例外，只在那两段换去处。
func test_non_snow_schedules_match_base() -> void:
	for lit: bool in [false, true]:
		SaveSystem.reset_all()
		GameClock.day = 1
		if lit:
			for flag: StringName in [&"lamp_plaza", &"lamp_river", &"lamp_pasture", &"lamp_well", &"lamp_east"]:
				GameState.set_flag(flag)
		for id in NPC_IDS:
			var def := Database.npc(id)
			# 雾天会晚出门，不再和底表相同。晴、雨、雷雨在立春仍是同一套。
			for weather: StringName in [&"sunny", &"rain", &"storm"]:
				var base := NpcSchedule._base_plan(def, weather)
				assert_eq(NpcSchedule.plan_for(def, weather), base, "%s %s 天还是同一套" % [id, weather])
				for minute in range(0, 1561, 60):
					var expect: Dictionary = NpcSchedule.HOME
					for entry in base:
						if int(entry["from"]) <= minute:
							expect = entry
					assert_eq(NpcSchedule.spot_at(def, minute, weather), expect, "%s %s %d 分去处不变" % [id, weather, minute])
			if def.exceptions.is_empty():
				var snow_base := NpcSchedule._base_plan(def, &"snow")
				assert_eq(NpcSchedule.plan_for(def, &"snow"), snow_base, "%s 雪天没有例外就还是同一套" % id)


func test_exception_replaces_only_its_time_segment() -> void:
	var def := _exc_def()
	var base := NpcSchedule._base_plan(def, &"sunny")
	var summer := NpcSchedule.overlay(base, def.exceptions, &"summer", &"lixia", &"sunny")
	assert_eq(summer.size(), 5, "8:00、12:00 树荫、15:00 接回、18:00、20:00")
	assert_eq(summer[0]["tile"], Vector2i(5, 6), "上午不动")
	assert_eq(summer[1]["from"], 720)
	assert_eq(summer[1]["tile"], Vector2i(2, 2), "午后换到树荫")
	assert_eq(summer[1]["note"], "shade")
	assert_eq(summer[2]["from"], 900, "段末把平常的去处接回来")
	assert_eq(summer[2]["tile"], Vector2i(7, 7))
	assert_eq(summer[3]["from"], 1080, "傍晚不动")
	assert_eq(summer[4]["map"], &"", "晚上回家不动")
	# 不是夏天就原样返回，平常日程也没被改坏
	assert_eq(NpcSchedule.overlay(base, def.exceptions, &"spring", &"lichun", &"sunny"), base, "春天不生效")
	assert_eq(base.size(), 4)
	assert_eq(base[1]["tile"], Vector2i(7, 7), "盖例外不动平常那份")


func test_exception_conditions_filter() -> void:
	var def := NpcDef.from_dict({
		"id": "tester", "name": "测试", "sheet": "ahe",
		"enter": {"town": [3, 4]},
		"schedule": [{"from": "8:00", "map": "town", "tile": [5, 6]}, {"from": "20:00"}],
		"exceptions": [
			{"term": "xiaoshu", "weather": "sunny", "from": "12:00", "to": "15:00",
				"plan": [{"from": "12:00", "map": "town", "tile": [2, 2]}]},
		],
	})
	var base := NpcSchedule._base_plan(def, &"sunny")
	var ex := def.exceptions
	assert_ne(NpcSchedule.overlay(base, ex, &"summer", &"xiaoshu", &"sunny"), base, "小暑晴天生效")
	assert_eq(NpcSchedule.overlay(base, ex, &"summer", &"dashu", &"sunny"), base, "别的节气不生效")
	assert_eq(NpcSchedule.overlay(base, ex, &"summer", &"xiaoshu", &"rain"), base, "雨天不生效")


func test_exception_spot_at_reads_the_calendar() -> void:
	var def := _exc_def()
	Weather.today = &"sunny"
	GameClock.day = GameClock.DAYS_PER_SEASON + 1
	assert_eq(GameClock.season_id(), &"summer")
	assert_eq(NpcSchedule.spot_at(def, 11 * 60.0, &"sunny")["tile"], Vector2i(5, 6), "上午照常")
	assert_eq(NpcSchedule.spot_at(def, 13 * 60.0, &"sunny")["tile"], Vector2i(2, 2), "夏天午后在树荫")
	assert_eq(NpcSchedule.spot_at(def, 16 * 60.0, &"sunny")["tile"], Vector2i(7, 7), "三点以后接回平常")
	GameClock.day = GameClock.DAYS_PER_SEASON * 3 + 1
	assert_eq(NpcSchedule.spot_at(def, 13 * 60.0, &"sunny")["tile"], Vector2i(7, 7), "冬天午后照常")


func test_validate_npc_catches_bad_exceptions() -> void:
	assert_eq(Database.validate_npc(_exc_def()), PackedStringArray(), "写对的例外不报错")
	var bad := NpcDef.from_dict({
		"id": "tester", "name": "测试", "sheet": "ahe",
		"enter": {"town": [3, 4]},
		"schedule": [{"from": "8:00", "map": "town", "tile": [5, 6]}, {"from": "20:00"}],
		"exceptions": [
			{"season": "monsoon", "term": "nowhere", "weather": "hail",
				"from": "15:00", "to": "12:00",
				"plan": [{"from": "13:00", "map": "moon", "tile": [1, 1]}]},
		],
	})
	var text := "\n".join(Database.validate_npc(bad))
	for expect: String in ["时间段不对", "不存在的季节", "不存在的节气", "不存在的天气", "不存在的地图", "例外去处要落在"]:
		assert_string_contains(text, expect)


# ---------------------------------------------------------------- 寻路

func test_grid_path_straight_and_around() -> void:
	var bounds := Rect2i(0, 0, 6, 6)
	var open := func(_t: Vector2i) -> bool: return true
	var path := GridPath.find(Vector2i(0, 0), Vector2i(3, 0), open, bounds)
	assert_eq(path.size(), 3)
	assert_eq(path[2], Vector2i(3, 0))
	# 中间竖一道墙，只在最下面留口
	var wall := func(t: Vector2i) -> bool: return t.x != 2 or t.y == 5
	path = GridPath.find(Vector2i(0, 0), Vector2i(4, 0), wall, bounds)
	assert_eq(path.size(), 14, "绕到最下面再回来")
	assert_true(path.has(Vector2i(2, 5)))
	for i in range(1, path.size()):
		assert_eq((path[i] - path[i - 1]).length_squared(), 1, "一步只走一格")


func test_grid_path_edge_cases() -> void:
	var bounds := Rect2i(0, 0, 4, 4)
	var open := func(_t: Vector2i) -> bool: return true
	var closed := func(_t: Vector2i) -> bool: return false
	assert_eq(GridPath.find(Vector2i(1, 1), Vector2i(1, 1), open, bounds).size(), 0, "原地不动")
	assert_eq(GridPath.find(Vector2i(0, 0), Vector2i(9, 9), open, bounds).size(), 0, "出界")
	assert_eq(GridPath.find(Vector2i(0, 0), Vector2i(3, 3), closed, bounds).size(), 0, "走不通")
	assert_eq(GridPath.find(Vector2i(0, 0), Vector2i(1, 0), closed, bounds).size(), 1, "终点本身不要求可走")


# ---------------------------------------------------------------- 搭话

func test_talk_titles() -> void:
	assert_eq(Residents.title_for(&"ahe", true), "first", "没见过面先自我介绍")
	watch_signals(EventBus)
	Residents.talk(&"ahe", true)
	assert_signal_emitted_with_parameters(EventBus, "dialogue_requested", ["res://dialogue/ahe.dialogue", "first"])
	assert_true(Residents.has_met(&"ahe"))
	assert_eq(Residents.title_for(&"ahe", true), "work", "看铺子的时候谈买卖")
	assert_eq(Residents.title_for(&"ahe", false), "again", "今天说过话了")
	assert_eq(Residents.title_for(&"jiang", false), "first")
	GameClock.advance_day()
	assert_eq(Residents.title_for(&"ahe", false), "daily", "第二天又有新话")
	assert_eq(Residents.talks(&"ahe"), 0)


func test_residents_save_and_reset() -> void:
	Residents.talk(&"xiaoman", false)
	var data := Residents.save_data()
	Residents.reset_data()
	assert_false(Residents.has_met(&"xiaoman"))
	Residents.load_data(data)
	assert_true(Residents.has_met(&"xiaoman"))
	assert_eq(Residents.talks(&"xiaoman"), 0, "今天说过几次话不存档")
	SaveSystem.reset_all()
	assert_false(Residents.has_met(&"xiaoman"), "新游戏谁都没见过")


func test_dialogue_helpers() -> void:
	assert_true(Residents.season_is(String(GameClock.season_id())))
	assert_false(Residents.season_is("nowhere"))
	assert_true(Residents.weather_is(String(Weather.today)))
	GameClock.minutes = 600.0
	assert_false(Residents.is_evening())
	GameClock.minutes = 1100.0
	assert_true(Residents.is_evening())


## 每位居民的对话文件都在，四段都能读出第一句。
func test_dialogue_files_have_all_titles() -> void:
	for id in NPC_IDS:
		var res: Resource = load(Residents.dialogue_path(id))
		assert_not_null(res, "%s 的对话文件能导入" % id)
		if res == null:
			continue
		for title: String in ["first", "work", "daily", "again", "gift_love", "gift_like", "gift_ok", "gift_dislike"]:
			var line: Variant = await DialogueManager.get_next_dialogue_line(res, title)
			assert_not_null(line, "%s 的 %s 段有内容" % [id, title])
			if line != null:
				assert_eq(str(line.character), Database.npc(id).name, "%s 的 %s 段由本人开口" % [id, title])


## 四季、各种天气下，日常对话都走得到头，不会读到空行或出错。
func test_daily_dialogue_runs_in_every_season_and_weather() -> void:
	for id in NPC_IDS:
		var res: Resource = load(Residents.dialogue_path(id))
		if res == null:
			continue
		for season in 4:
			GameClock.day = season * GameClock.DAYS_PER_SEASON + 1
			for weather: StringName in [&"sunny", &"rain", &"fog", &"snow"]:
				Weather.today = weather
				var line: Variant = await DialogueManager.get_next_dialogue_line(res, "daily")
				var steps := 0
				while line != null and steps < 20:
					steps += 1
					assert_ne(str(line.text), "", "%s 在第 %d 季 %s 天有话说" % [id, season, weather])
					if line.responses.size() > 0:
						break
					line = await DialogueManager.get_next_dialogue_line(res, line.next_id)
				assert_gt(steps, 0)


# ---------------------------------------------------------------- 铺子

func test_shop_counters_split_the_catalog() -> void:
	var grocery := Shop.entries(&"spring", Shop.GROCERY)
	var smith := Shop.entries(&"spring", Shop.SMITH)
	assert_gt(grocery.size(), 0)
	assert_gt(smith.size(), 0)
	for e in grocery:
		assert_false(e.upgrade, "杂货铺不升级工具")
	for e in smith:
		assert_true(e.upgrade, "铁匠铺只升级工具")
	assert_eq(Shop.entries(&"spring").size(), grocery.size() + smith.size(), "不指定铺子就是两家合起来")


func test_request_shop_passes_counter() -> void:
	watch_signals(EventBus)
	EventBus.request_shop("smith")
	assert_signal_emitted_with_parameters(EventBus, "shop_requested", [&"smith"])


# ---------------------------------------------------------------- 地面和地图

func test_ground_art_paints_all_terrains() -> void:
	var terrain := PackedByteArray()
	terrain.resize(4 * 3)
	terrain[1] = GroundArt.DIRT
	terrain[5] = GroundArt.PAVE
	terrain[10] = GroundArt.WATER
	var painted := GroundArt.paint(terrain, 4, 3, 0)
	var img: Image = painted["image"]
	var tbuf: PackedByteArray = painted["tbuf"]
	assert_eq(img.get_size(), Vector2i(64, 48))
	assert_eq(tbuf.size(), 64 * 48)
	assert_eq(tbuf[8 * 64 + 24], GroundArt.DIRT, "格子中心是这一格的地形")
	assert_eq(tbuf[24 * 64 + 24], GroundArt.PAVE)
	assert_eq(tbuf[40 * 64 + 40], GroundArt.WATER)
	assert_eq(tbuf[40 * 64 + 8], GroundArt.GRASS)
	var clear := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a < 0.99:
				clear += 1
	assert_eq(clear, 0, "交界的格子也要铺满，不能透出黑底")


func _town() -> OutdoorMap:
	var scene: PackedScene = load(SceneRouter.MAPS[&"town"])
	var town: OutdoorMap = scene.instantiate()
	add_child_autofree(town)
	return town


func test_town_exit_leads_to_farm_and_back() -> void:
	GameClock.minutes = 360.0
	var town := _town()
	var spawn := GameMap.tile_of(town.spawn_position(&"from_farm"))
	assert_false(town.blocked(town.spawn_position(&"from_farm")), "进镇的地方站得住")
	assert_true(town.trigger_at(spawn).is_empty(), "进镇的地方不在出口格上")
	var out := town.trigger_at(Vector2i(spawn.x + 1, spawn.y))
	assert_eq(out.get("map"), &"farm")
	var farm_scene: PackedScene = load(SceneRouter.MAPS[&"farm"])
	var farm: OutdoorMap = farm_scene.instantiate()
	add_child_autofree(farm)
	var back: StringName = out["spawn"]
	var farm_spawn := GameMap.tile_of(farm.spawn_position(back))
	assert_false(farm.blocked(farm.spawn_position(back)), "回农场的地方站得住")
	assert_eq(farm.trigger_at(Vector2i(farm_spawn.x - 1, farm_spawn.y)).get("map"), &"town")
	assert_gt(farm.find_path(farm_spawn, Vector2i(8, 8)).size(), 0, "从镇上回来能走到家门口")


## 日程里写的每个位置都站得住，而且从出入口走得到。
func test_every_schedule_spot_is_reachable() -> void:
	GameClock.minutes = 360.0
	var town := _town()
	var from_farm := GameMap.tile_of(town.spawn_position(&"from_farm"))
	for id in NPC_IDS:
		var def := Database.npc(id)
		var door: Vector2i = def.enter[&"town"]
		assert_eq(town.solid[town.idx(door)], 0, "%s 的出入口没被挡住" % id)
		assert_gt(town.find_path(from_farm, door).size(), 0, "玩家走得到 %s 的出入口" % id)
		for plan: Array[Dictionary] in [def.schedule, def.rain_schedule, def.early_schedule, def.early_rain_schedule]:
			for entry in plan:
				if entry["map"] != &"town":
					continue
				var tile: Vector2i = entry["tile"]
				assert_eq(town.solid[town.idx(tile)], 0, "%s 在 %s 站得住" % [id, tile])
				assert_true(tile == door or town.find_path(door, tile).size() > 0, "%s 走得到 %s" % [id, tile])


## 同一时刻没有两个人站在同一格上，晴天雨天都查。
func test_no_two_residents_share_a_spot() -> void:
	# 灯亮以前、以后各查一遍：有的人灯亮以前是另一套日程
	for lit: bool in [false, true]:
		if lit:
			for flag: StringName in [&"lamp_plaza", &"lamp_river", &"lamp_pasture", &"lamp_well"]:
				GameState.set_flag(flag)
		for weather: StringName in [&"sunny", &"rain"]:
			for minute in range(360, 1500, 10):
				var taken: Dictionary[Vector2i, StringName] = {}
				for id in NPC_IDS:
					var spot := NpcSchedule.spot_at(Database.npc(id), minute, weather)
					if spot["map"] != &"town":
						continue
					var tile: Vector2i = spot["tile"]
					assert_false(taken.has(tile), "灯%s %s 天 %d 分，%s 和 %s 都在 %s" % ["亮了" if lit else "没亮", weather, minute, id, taken.get(tile, &""), tile])
					taken[tile] = id


func test_fog_roads_stop_the_player_but_not_residents() -> void:
	GameClock.minutes = 360.0
	var town := _town()
	var center := Vector2i(22, 18)
	for edge: Vector2i in [Vector2i(13, 0), Vector2i(0, 18)]:
		assert_true(town.blocked(GameMap.tile_center(edge)), "玩家走不进 %s 的雾里" % edge)
		assert_gt(town.find_path(edge, center).size(), 0, "居民能从 %s 走进镇子" % edge)
		assert_eq(town.query_use(null, edge, GameMap.Facing.UP), &"interact", "对着雾有提示")
	assert_eq(town.query_use(null, Vector2i(8, 17), GameMap.Facing.UP), &"interact", "对着铺子的墙能看说明")
	assert_eq(town.query_use(null, Vector2i(12, 12), GameMap.Facing.UP), &"", "空地上没东西可看")


func test_town_npcs_follow_the_clock() -> void:
	Weather.today = &"sunny"
	GameClock.minutes = 600.0
	var town := _town()
	assert_eq(town.npcs.size(), 10, "上午十点镇上有十个人（老周回码头了，老秦还没来）")
	var ahe := town.npc_at(Vector2i(8, 18))
	assert_not_null(ahe, "阿禾站在铺子门口")
	if ahe != null:
		assert_eq(ahe.def.id, &"ahe")
		assert_true(town.blocked(GameMap.tile_center(Vector2i(8, 18))), "站着的居民挡路")
		assert_eq(town.query_use(null, Vector2i(8, 18), GameMap.Facing.UP), &"interact")
	watch_signals(EventBus)
	town.perform(&"interact", null, Vector2i(8, 18))
	assert_signal_emitted_with_parameters(EventBus, "dialogue_requested", ["res://dialogue/ahe.dialogue", "first"])
	town.perform(&"interact", null, Vector2i(8, 18))
	assert_signal_emitted_with_parameters(EventBus, "dialogue_requested", ["res://dialogue/ahe.dialogue", "work"])


func test_town_npcs_leave_at_night() -> void:
	Weather.today = &"sunny"
	GameClock.minutes = 1300.0
	var town := _town()
	assert_eq(town.npcs.size(), 0, "夜里都回家了")
	GameClock.minutes = 300.0
	var early := _town()
	assert_eq(early.npcs.size(), 0, "天没亮也没人")
	GameClock.minutes = 480.0
	early._update_npcs()
	assert_eq(early.npcs.size(), 6, "八点有六个人出门了")
	var xiaoman := early._npc_of(&"xiaoman")
	assert_not_null(xiaoman)
	if xiaoman != null:
		assert_true(xiaoman.is_walking(), "小满从出入口往广场走")
		assert_false(early.blocked(xiaoman.position), "走着的居民不挡路")
