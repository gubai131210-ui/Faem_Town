extends GutTest
## M10 第三批：夏天摇扇、冬天搓手、立冬干草、大雪银鱼、暑天树荫心情。


func before_each() -> void:
	SaveSystem.reset_all()
	Weather.today = &"sunny"
	GameClock.minutes = 600.0


func after_each() -> void:
	SaveSystem.reset_all()


func test_look_stops_are_the_four_terms() -> void:
	var seen: Array[StringName] = []
	for stop: Dictionary in GameClock.LOOK_STOPS:
		GameClock.day = int(stop["day"])
		assert_eq(GameClock.term_id(), stop["term"])
		seen.append(stop["term"])
	assert_eq(seen, [&"xiaoshu", &"lidong", &"daxue", &"xiaoxue", &"lichun", &"liqiu"])
	assert_eq(GameClock.LOOK_STOPS[4]["today"], &"fog")
	assert_eq(GameClock.LOOK_STOPS[5]["today"], &"wind")


const ScenicScript := preload("res://maps/scenic.gd")


func test_fog_and_wind_move_people() -> void:
	var bai := NpcSchedule.spot_at(Database.npc(&"bai"), 10 * 60.0, &"fog")
	assert_eq(str(bai["map"]), "", "雾天柏先生不出门")
	var xm := NpcSchedule.spot_at(Database.npc(&"xiaoman"), 7 * 60.0 + 30, &"fog")
	assert_eq(str(xm["map"]), "", "雾天出门晚一小时")
	var egret := NpcSchedule.spot_at(Database.npc(&"egret"), 11 * 60.0, &"fog")
	assert_eq(str(egret["pose"]), "paint", "雾天白鹭画画")
	var ahe := NpcSchedule.spot_at(Database.npc(&"ahe"), 15 * 60.0 + 30, &"wind")
	assert_eq(str(ahe["map"]), "", "大风阿禾收了摊")
	assert_true(bool(NpcSchedule.spot_at(Database.npc(&"ahe"), 10 * 60.0, &"wind")["work"]))
	var yun := NpcSchedule.spot_at(Database.npc(&"yunniang"), 10 * 60.0 + 30, &"wind")
	assert_eq(str(yun["note"]), "banner", "大风云娘去追幌子")
	assert_almost_eq(ScenicScript.pace(20.0, &"fog"), 13.0, 0.01)
	assert_almost_eq(ScenicScript.pace(20.0, &"sunny"), 20.0, 0.01)
	Residents.met[&"jiang"] = true
	Residents.talks_today[&"jiang"] = 1
	Weather.today = &"fog"
	assert_eq(Residents.title_for(&"jiang", false), "daily", "雾天忘了刚说过的话")
	Weather.today = &"sunny"
	assert_eq(Residents.title_for(&"jiang", false), "again")


func test_scenic_follows_season() -> void:
	assert_eq(ScenicScript.kind(&"spring", &"sunny"), &"swallow")
	assert_eq(ScenicScript.kind(&"summer", &"sunny"), &"dragonfly")
	assert_eq(ScenicScript.kind(&"autumn", &"wind"), &"geese")
	assert_eq(ScenicScript.kind(&"winter", &"snow"), &"sparrow")
	assert_eq(ScenicScript.kind(&"winter", &"sunny"), &"")
	assert_eq(ScenicScript.kind(&"spring", &"rain"), &"")
	assert_eq(ScenicScript.count(&"geese"), 4)
	assert_true(ScenicScript.cicada(&"summer", &"sunny", false, 12 * 60.0))
	assert_false(ScenicScript.cicada(&"summer", &"rain", false, 12 * 60.0))
	assert_false(ScenicScript.cicada(&"summer", &"sunny", true, 12 * 60.0))
	assert_false(ScenicScript.cicada(&"spring", &"sunny", false, 12 * 60.0))
	var a := ScenicScript.spot(&"swallow", 0, 0.0, Vector2(200, 100))
	var b := ScenicScript.spot(&"swallow", 0, 1.0, Vector2(200, 100))
	assert_gt(b.x, a.x, "燕子在往前飞")
	var sky := Vector2(384, 216)
	assert_lt(ScenicScript.spot(&"swallow", 1, 0.0, sky).y, 90.0, "燕子在画面上沿")
	assert_lt(ScenicScript.spot(&"geese", 3, 0.0, sky).y, 100.0, "雁在画面上沿")
	for id in [&"swallow", &"dragonfly", &"geese", &"sparrow"]:
		var ext: Vector2i = ScenicScript.extent(id)
		assert_gte(ext.x, 12, "%s 要画得认得出" % id)
		assert_gte(ext.y, 7, "%s 要画得认得出" % id)


func test_heat_sends_town_people_to_the_shade_with_fans() -> void:
	GameClock.day = 10 * 4 + 1
	assert_eq(GameClock.term_id(), &"xiaoshu")
	var spot := NpcSchedule.spot_at(Database.npc(&"xiaoman"), 13 * 60.0, &"sunny")
	assert_eq(str(spot["note"]), "shade")
	assert_eq(str(spot["pose"]), "fan")
	assert_eq(str(NpcSchedule.spot_at(Database.npc(&"ahe"), 13 * 60.0, &"sunny")["pose"]), "fan")
	var smith := NpcSchedule.spot_at(Database.npc(&"shishu"), 9 * 60.0, &"sunny")
	assert_eq(str(smith["pose"]), "smash", "早上照样打铁")
	assert_eq(str(NpcSchedule.spot_at(Database.npc(&"shishu"), 13 * 60.0, &"sunny")["pose"]), "fan")
	assert_eq(str(NpcSchedule.spot_at(Database.npc(&"shishu"), 16 * 60.0 + 30, &"sunny")["pose"]), "smash", "下午再打")
	assert_eq(str(NpcSchedule.spot_at(Database.npc(&"laozhou"), 13 * 60.0, &"sunny")["pose"]), "fish", "码头的人不叫回镇")
	Weather.today = &"rain"
	assert_ne(str(NpcSchedule.spot_at(Database.npc(&"xiaoman"), 13 * 60.0, &"rain")["pose"]), "fan", "下雨不摇扇")


func test_winter_starts_late_ends_early_and_rubs() -> void:
	GameClock.day = 18 * 4 + 1
	assert_eq(GameClock.season_id(), &"winter")
	assert_eq(GameClock.term_id(), &"lidong")
	var xm := Database.npc(&"xiaoman")
	assert_eq(str(NpcSchedule.spot_at(xm, 7 * 60.0 + 30, &"sunny")["map"]), "", "七点半还没出门")
	var noon := NpcSchedule.spot_at(xm, 11 * 60.0, &"sunny")
	assert_eq(str(noon["pose"]), "rub")
	var tea := NpcSchedule.spot_at(xm, 15 * 60.0, &"sunny")
	assert_eq(str(tea["note"]), "tea", "午后在茶馆门口")
	assert_eq(str(tea["pose"]), "rub")
	assert_true(Npc.shows_breath(&"winter", &"rub", false))
	assert_false(Npc.shows_breath(&"winter", &"rub", true), "走路不呵气")
	assert_false(Npc.shows_breath(&"summer", &"idle", false))


func test_lidong_hay_shade_mood_and_staying_in() -> void:
	for f: StringName in [&"lamp_plaza", &"lamp_river", &"lamp_pasture"]:
		GameState.set_flag(f)
	GameState.money = 100000
	Animals.order("coop")
	for _i in 5:
		Animals.settle(false)
	assert_true(Animals.buy("chicken"))
	GameClock.day = 18 * 4 + 1
	assert_true(Animals.stays_in(&"lidong"))
	assert_false(Animals.stays_in(&"xiaoxue"))
	assert_eq(Animals.ration_of(0), Animals.HAY_ID)
	GameState.inventory.add(&"feed", 1)
	assert_false(Animals.feed(0), "立冬饲料喂不进去")
	assert_eq(GameState.inventory.count_of(&"feed"), 1)
	GameState.inventory.add(&"hay", 1)
	assert_true(Animals.feed(0))
	var before := Animals.mood_of(0)
	GameClock.day = 10 * 4 + 1
	Animals.settle(false)
	assert_eq(Animals.mood_of(0), before + Animals.FED_MOOD + Animals.SHADE_MOOD)
	GameClock.day = 1
	assert_eq(Animals.ration_of(0), &"feed")
