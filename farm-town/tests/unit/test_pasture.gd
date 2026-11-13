extends GutTest
## M4：第二幕（牛铃、牧野灯、北坡牧场）、家里的猫狗、稻草人和乌鸦。

const WEST_EDGE := Vector2i(0, 18)
const WEST_LAMP := Vector2i(3, 20)

var _banners: Array[String] = []
var _dialogues: Array[String] = []


func before_each() -> void:
	SaveSystem.reset_all()
	Weather.today = &"sunny"
	Weather.yesterday = &"sunny"
	GameClock.minutes = 600.0
	GameClock.day = 1
	_banners.clear()
	_dialogues.clear()
	EventBus.banner_requested.connect(_on_banner)
	EventBus.dialogue_requested.connect(_on_dialogue)


func after_each() -> void:
	EventBus.banner_requested.disconnect(_on_banner)
	EventBus.dialogue_requested.disconnect(_on_dialogue)
	SaveSystem.reset_all()
	Weather.today = &"sunny"
	Weather.yesterday = &"sunny"
	GameClock.running = false


func _on_banner(text: String) -> void:
	_banners.append(text)


func _on_dialogue(_path: String, title: String) -> void:
	_dialogues.append(title)


func _map(id: StringName) -> OutdoorMap:
	var scene: PackedScene = load(SceneRouter.MAPS[id])
	var m: OutdoorMap = scene.instantiate()
	add_child_autofree(m)
	return m


func _light_pasture() -> void:
	GameState.set_flag(&"lamp_plaza")
	GameState.set_flag(&"lamp_river")
	GameState.set_flag(&"lamp_pasture")


## 走一段对话，一路挑第一个能选的选项（或字里带 pick 的那个），返回说过的话。
func _say(path: String, title: String, pick: String = "") -> String:
	var res: Resource = load(path)
	var said := ""
	var line: Variant = await DialogueManager.get_next_dialogue_line(res, title)
	while line != null:
		said += str(line.text)
		var next: String = line.next_id
		if line.responses.size() > 0:
			var chosen := ""
			for r: DialogueResponse in line.responses:
				if r.is_allowed and (chosen == "" or (pick != "" and r.text.contains(pick))):
					chosen = r.next_id
					if pick == "" or r.text.contains(pick):
						break
			next = chosen
		if next == "end" or next == "":
			break
		line = await DialogueManager.get_next_dialogue_line(res, next)
	return said


## 在 t 这一格开一块地种上白萝卜；grown 为真就让它长过出苗的阶段。
func _sow(t: Vector2i, grown: bool = false) -> void:
	Farming.state.till(t)
	assert_true(Farming.state.plant(t, &"white_radish"))
	if grown:
		Farming.state.crops[t]["days"] = 6


# ---------------------------------------------------------------- 第二幕

func test_tables_are_valid() -> void:
	assert_eq(Database.validate(), PackedStringArray(), "数据表没有错")
	var lamp := Database.lamp(&"pasture")
	assert_eq(lamp.map, &"town")
	assert_eq(lamp.relic, &"cowbell")
	assert_eq(lamp.flag(), &"lamp_pasture")
	assert_true(Database.has_relic(&"cowbell"))
	assert_has(SceneRouter.MAPS, &"pasture")
	assert_has(Foraging.MAPS, &"pasture")


func test_west_road_is_fogged_until_the_lamp() -> void:
	var town := _map(&"town")
	assert_true(town.blocked(GameMap.tile_center(WEST_EDGE)))
	assert_eq(town.trigger_at(WEST_EDGE), {})
	town.perform(&"interact", null, WEST_EDGE)
	assert_string_contains(_banners[-1], "雾太浓")
	assert_false(GameState.inventory.count_of(&"cowbell") > 0, "阿牧没提过，雾里摸不到铃")


func test_bell_is_found_in_the_fog_after_the_hint() -> void:
	GameState.set_flag(&"bell_hint")
	var town := _map(&"town")
	town.perform(&"interact", null, WEST_EDGE)
	assert_eq(GameState.inventory.count_of(&"cowbell"), 1)
	assert_true(GameState.has_flag(&"relic_cowbell"))
	assert_eq(_dialogues, ["bell_found"] as Array[String])
	town.perform(&"interact", null, WEST_EDGE)
	assert_eq(GameState.inventory.count_of(&"cowbell"), 1, "只有一只")
	assert_string_contains(_banners[-1], "雾太浓")
	town.perform(&"interact", null, Vector2i(13, 0))
	assert_eq(GameState.inventory.count_of(&"cowbell"), 1, "北边的雾里没有")


func test_pasture_lamp_takes_offerings_and_lights() -> void:
	var town := _map(&"town")
	assert_eq(town.query_use(null, WEST_LAMP, GameMap.Facing.DOWN), &"interact")
	watch_signals(EventBus)
	town.perform(&"interact", null, WEST_LAMP)
	assert_signal_emitted_with_parameters(EventBus, "lamp_requested", [&"pasture"])
	for item_id in Lamps.wanted(&"pasture"):
		Lamps.offer(&"pasture", item_id, 99)
	assert_true(Lamps.light(&"pasture"))
	assert_true(GameState.has_flag(&"lamp_pasture"))
	town.on_lamp_lit(&"pasture")
	assert_false(town.blocked(GameMap.tile_center(WEST_EDGE)), "灯亮了雾就散了")
	assert_eq(town.trigger_at(WEST_EDGE), {"map": &"pasture", "spawn": &"from_town"})
	town.perform(&"interact", null, WEST_LAMP)
	assert_string_contains(_banners[-1], "牧野灯")
	# 北边去井口的路等的是井口灯（第三幕，决策 057）
	assert_true(town.blocked(GameMap.tile_center(Vector2i(13, 0)) + Vector2(8, 0)), "北边的雾还在")


func test_town_loads_with_the_west_road_open() -> void:
	_light_pasture()
	var town := _map(&"town")
	assert_false(town.blocked(GameMap.tile_center(WEST_EDGE)))
	assert_eq(town.trigger_at(Vector2i(0, 19)), {"map": &"pasture", "spawn": &"from_town"})
	var back := town.spawn_position(&"from_pasture")
	assert_false(town.blocked(back), "从牧场回来站得住")
	assert_eq(town.trigger_at(GameMap.tile_of(back)), {}, "回来不会又被送回去")


func test_heavy_snow_closes_the_slope() -> void:
	_light_pasture()
	# 大雪是冬天第 9–12 天
	GameClock.day = GameClock.DAYS_PER_SEASON * 3 + 9
	assert_eq(GameClock.term_id(), &"daxue")
	var town := _map(&"town")
	assert_true(town.blocked(GameMap.tile_center(WEST_EDGE)))
	assert_eq(town.trigger_at(WEST_EDGE), {})
	town.perform(&"interact", null, WEST_EDGE)
	assert_string_contains(_banners[-1], "大雪封山")


func test_amu_tells_the_story_in_order() -> void:
	var path := Residents.dialogue_path(&"amu")
	GameState.set_flag(&"lamp_plaza")
	GameState.set_flag(&"lamp_river")
	GameState.set_flag(&"amu_chicks")
	var said := await _say(path, "daily", "聊聊")
	assert_false(said.contains("铃"), "没养动物的时候不提")
	GameState.money = 100000
	Animals.order("coop")
	for i in 5:
		Animals.settle(false)
	Animals.buy("chicken")
	Animals.buy("duck")
	said = await _say(path, "daily", "聊聊")
	assert_false(said.contains("铃"), "动物还没养熟不提")
	Animals.animals[0]["mood"] = 75
	said = await _say(path, "daily", "聊聊")
	assert_string_contains(said, "铃没了")
	assert_true(GameState.has_flag(&"bell_hint"))
	said = await _say(path, "daily", "聊聊")
	assert_false(said.contains("铃没了"), "只说一回")
	GameState.set_flag(&"relic_cowbell")
	said = await _say(path, "daily", "聊聊")
	assert_string_contains(said, "花花的铃")
	assert_string_contains(said, "石灯")
	GameState.set_flag(&"lamp_pasture")
	said = await _say(path, "daily", "聊聊")
	assert_string_contains(said, "雾退了")
	said = await _say(path, "daily", "聊聊")
	assert_false(said.contains("雾退了"), "只说一回")


func test_narrations_exist() -> void:
	var path := "res://dialogue/common.dialogue"
	assert_string_contains(await _say(path, "bell_found"), "牛铃")
	assert_string_contains(await _say(path, "lamp_pasture"), "老牧道")


# ---------------------------------------------------------------- 北坡牧场

func test_pasture_is_walkable_from_the_road() -> void:
	var m := _map(&"pasture")
	assert_eq(m.map_id, &"pasture")
	var start := m.spawn_position(&"from_town")
	assert_false(m.blocked(start))
	assert_eq(m.trigger_at(GameMap.tile_of(start)), {}, "进来不会立刻又出去")
	assert_eq(m.trigger_at(Vector2i(43, 14)), {"map": &"town", "spawn": &"from_pasture"})
	var from := GameMap.tile_of(start)
	for goal: Vector2i in [Vector2i(14, 12), Vector2i(18, 16), Vector2i(16, 20), Vector2i(31, 10), Vector2i(36, 19)]:
		assert_gt(m.find_path(from, goal).size(), 0, "从路口走得到 %s" % goal)


func test_herd_grazes_by_day() -> void:
	GameClock.minutes = 600.0
	var m := _map(&"pasture")
	assert_eq(m._herd.size(), 7, "一头牛、两只山羊、两只绵羊、两只鸡")
	for c: Critter in m._herd:
		assert_false(m._tile_blocked(c.tile()), "牲口站在能站的地方")
	var cow: Critter = m._herd[0]
	assert_true(m.PADDOCK.has_point(cow.tile()), "花花在草场里")
	# 别的牲口可能正好站在它旁边：先挪开，免得摸到的是羊
	for c: Critter in m._herd:
		if c != cow:
			c.position = Vector2(-999, -999)
	var t := cow.tile()
	assert_eq(m.query_use(null, t, GameMap.Facing.DOWN), &"interact")
	m.perform(&"interact", null, t)
	assert_string_contains(_banners[-1], "花花")
	GameClock.minutes = 1200.0
	m._sync_herd()
	assert_eq(m._herd.size(), 0, "天黑了收回去")


func test_herd_stays_in_when_it_rains() -> void:
	Weather.today = &"rain"
	var m := _map(&"pasture")
	assert_eq(m._herd.size(), 0)


func test_barn_and_hives_have_signs() -> void:
	var m := _map(&"pasture")
	m.perform(&"interact", null, Vector2i(13, 10))
	assert_string_contains(_banners[-1], "畜棚")
	m.perform(&"interact", null, Vector2i(30, 8))
	assert_string_contains(_banners[-1], "蜂箱")
	assert_eq(m.query_use(null, Vector2i(40, 5), GameMap.Facing.DOWN), &"")


func test_amu_keeps_his_hours() -> void:
	var amu := Database.npc(&"amu")
	assert_eq(Database.validate_npc(amu), PackedStringArray())
	# 牧野灯亮以前牧场被雾封着，他白天都在镇上，玩家随时找得到
	assert_true(amu.is_early())
	for minute: float in [520.0, 630.0, 720.0, 900.0, 1000.0]:
		assert_eq(NpcSchedule.spot_at(amu, minute, &"sunny")["map"], &"town", "灯亮以前 %d 分在镇上" % int(minute))
	assert_eq(NpcSchedule.spot_at(amu, 420.0, &"sunny")["map"], &"", "一早还没出门")
	assert_eq(NpcSchedule.spot_at(amu, 1100.0, &"sunny")["map"], &"", "傍晚回去了")
	assert_eq(NpcSchedule.spot_at(amu, 660.0, &"rain")["map"], &"town", "下雨天在茶馆躲雨")
	assert_eq(NpcSchedule.spot_at(amu, 660.0, &"rain")["note"], "teahouse")
	GameState.set_flag(&"lamp_pasture")
	assert_false(amu.is_early())
	assert_eq(NpcSchedule.spot_at(amu, 420.0, &"sunny")["map"], &"pasture", "早上在牧场")
	assert_eq(NpcSchedule.spot_at(amu, 630.0, &"sunny")["map"], &"town", "十点多在镇上")
	assert_eq(NpcSchedule.spot_at(amu, 840.0, &"sunny")["map"], &"pasture", "下午回牧场")
	assert_eq(NpcSchedule.spot_at(amu, 840.0, &"rain")["map"], &"pasture", "下雨守着畜棚")
	GameClock.minutes = 840.0
	var m := _map(&"pasture")
	var npc := m.npc_at(Vector2i(18, 16))
	assert_not_null(npc, "下午阿牧站在草场口")
	if npc != null:
		assert_eq(npc.def.id, &"amu")
		assert_eq(m.query_use(null, Vector2i(18, 16), GameMap.Facing.DOWN), &"interact")
	assert_gt(m.find_path(Vector2i(43, 14), Vector2i(14, 12)).size(), 0)


func test_pasture_grows_forage() -> void:
	GameClock.advance_day()
	assert_gt(Foraging.pending_on(&"pasture"), 0)
	var m := _map(&"pasture")
	assert_gt(Foraging.count_on(&"pasture"), 0)
	for t: Vector2i in Foraging.items[&"pasture"]:
		assert_false(m.PADDOCK.has_point(t), "采集物不落在草场里")
		assert_eq(m.query_use(null, t, GameMap.Facing.DOWN), &"harvest")


# ---------------------------------------------------------------- 猫狗

func test_pet_choice_is_offered_from_day_two() -> void:
	var farm := _map(&"farm")
	farm.player = Node2D.new()
	add_child_autofree(farm.player)
	farm.entered()
	assert_eq(_dialogues.size(), 0, "第一天不来")
	GameClock.day = 2
	farm.entered()
	assert_eq(_dialogues, ["pet_choice"] as Array[String])
	GameState.set_flag(&"pet_cat")
	farm.entered()
	assert_eq(_dialogues.size(), 1, "选过就不再问")


func test_pet_choice_dialogue_sets_the_flag() -> void:
	var said := await _say("res://dialogue/common.dialogue", "pet_choice", "黄狗")
	assert_string_contains(said, "阿黄")
	assert_eq(Animals.pet_kind(), &"dog")
	GameState.flags.clear()
	said = await _say("res://dialogue/common.dialogue", "pet_choice", "花猫")
	assert_string_contains(said, "小花")
	assert_eq(Animals.pet_kind(), &"cat")


func test_pet_lives_in_the_yard() -> void:
	var farm := _map(&"farm")
	assert_null(farm._pet, "没养的时候没有")
	GameState.set_flag(&"pet_cat")
	farm._sync_pet()
	assert_not_null(farm._pet)
	assert_true(farm.PET_YARD.has_point(farm._pet.tile()))
	var t: Vector2i = farm._pet.tile()
	assert_eq(farm.query_use(null, t, GameMap.Facing.DOWN), &"tend")
	farm.perform(&"tend", null, t)
	assert_string_contains(_banners[-1], "小花")
	assert_string_contains(_banners[-1], "呼噜")
	farm.perform(&"tend", null, farm._pet.tile())
	assert_string_contains(_banners[-1], "不理你")
	GameClock.minutes = 1300.0
	farm._sync_pet()
	assert_null(farm._pet, "夜里回屋")


func test_dog_fetches_a_relic_on_fog_days() -> void:
	GameState.set_flag(&"pet_dog")
	Weather.today = &"fog"
	var farm := _map(&"farm")
	farm._sync_pet()
	assert_not_null(farm._pet)
	var before := _relics_held()
	farm.perform(&"tend", null, farm._pet.tile())
	assert_eq(_relics_held(), before + 1, "雾天头一回摸，叼回来一件")
	assert_string_contains(_banners[-1], "叼回来")
	farm.perform(&"tend", null, farm._pet.tile())
	assert_eq(_relics_held(), before + 1, "一天只找一回")
	GameClock.day += 1
	Weather.today = &"sunny"
	farm.perform(&"tend", null, farm._pet.tile())
	assert_eq(_relics_held(), before + 1, "晴天不找")
	assert_string_contains(_banners[-1], "摇着尾巴")


func test_dog_only_brings_fog_relics_not_yet_found() -> void:
	GameState.set_flag(&"pet_dog")
	Weather.today = &"fog"
	var farm := _map(&"farm")
	farm._sync_pet()
	for id: StringName in Database.relics:
		if Database.relic(id).found == &"fog":
			GameState.set_flag(StringName("relic_" + String(id)))
	var before := _relics_held()
	farm.perform(&"tend", null, farm._pet.tile())
	assert_eq(_relics_held(), before, "都找到过了就没有")
	assert_eq(GameState.inventory.count_of(&"cowbell"), 0)


func _relics_held() -> int:
	var n := 0
	for id: StringName in Database.relics:
		n += GameState.inventory.count_of(id)
	return n


func test_pet_day_survives_save_and_load() -> void:
	GameClock.day = 5
	assert_true(Animals.stroke_pet())
	assert_false(Animals.stroke_pet())
	var data := Animals.save_data()
	Animals.reset_data()
	Animals.load_data(JSON.parse_string(JSON.stringify(data)))
	assert_false(Animals.stroke_pet(), "读档以后今天还是摸过了")


# ---------------------------------------------------------------- 稻草人和乌鸦

func test_crows_wait_for_the_plaza_lamp_and_skip_winter() -> void:
	assert_false(Farming.crows_come(), "广场灯亮以前没有鸟")
	GameState.set_flag(&"lamp_plaza")
	assert_true(Farming.crows_come())
	GameClock.day = GameClock.DAYS_PER_SEASON * 3 + 2
	assert_false(Farming.crows_come(), "冬天不来")
	GameClock.day = 3
	GameState.set_flag(&"pet_cat")
	assert_true(Farming.crows_come(), "有猫也来，只是不敢落在屋子跟前")


func test_cat_guards_the_fields_near_the_house_only() -> void:
	var farm := _map(&"farm")
	assert_eq(Farming.CAT_HOME, farm.START_TILE, "猫守的是屋门口")
	assert_true(farm.PET_YARD.has_point(Farming.CAT_HOME))
	var near := Vector2i(Farming.CAT_HOME.x + Farming.CAT_RANGE, 12)
	var far := near + Vector2i(1, 0)
	assert_true(farm._can_till(near) and farm._can_till(far), "两格都在起始那块田里")
	_sow(near)
	_sow(far)
	assert_eq(Farming.crow_targets(), [near, far] as Array[Vector2i], "没猫的时候都够得着")
	GameState.set_flag(&"pet_dog")
	assert_false(Farming.cat_guards(near), "狗不管乌鸦")
	GameState.flags.erase(&"pet_dog")
	GameState.set_flag(&"pet_cat")
	assert_true(Farming.cat_guards(near))
	assert_false(Farming.cat_guards(far), "远一格就管不到")
	assert_eq(Farming.crow_targets(), [far] as Array[Vector2i])
	assert_true(Farming.place_scarecrow(far + Vector2i(2, -4)))
	assert_eq(Farming.crow_targets(), [] as Array[Vector2i], "远处的地立了稻草人也护住了")


func test_crows_eat_only_fresh_seeds() -> void:
	var seed_tile := Vector2i(16, 10)
	var grown_tile := Vector2i(18, 10)
	_sow(seed_tile)
	_sow(grown_tile, true)
	assert_eq(Farming.crow_targets(), [seed_tile] as Array[Vector2i])
	var rng := RandomNumberGenerator.new()
	var eaten := Farming.raid(2, rng)
	assert_eq(eaten, [seed_tile] as Array[Vector2i])
	assert_false(Farming.state.has_crop(seed_tile), "种子被刨了")
	assert_true(Farming.state.has_crop(grown_tile), "长出来的不动")
	assert_true(Farming.state.is_tilled(seed_tile), "地还在")


func test_scarecrow_guards_six_tiles_around() -> void:
	var near := Vector2i(16, 10)
	var far := Vector2i(24, 10)
	_sow(near)
	_sow(far)
	assert_true(Farming.place_scarecrow(Vector2i(17, 6 + 1)))
	assert_false(Farming.place_scarecrow(Vector2i(17, 7)), "一格只能立一个")
	assert_false(Farming.place_scarecrow(near), "耕地上不能立")
	assert_true(Farming.is_guarded(near))
	assert_false(Farming.is_guarded(far), "七格以外护不到")
	assert_eq(Farming.crow_targets(), [far] as Array[Vector2i])
	Farming.scarecrows[Vector2i(17, 7)] = true
	assert_false(Farming.is_guarded(near), "倒了就不管用")
	assert_true(Farming.raise_scarecrow(Vector2i(17, 7)))
	assert_true(Farming.is_guarded(near))
	assert_false(Farming.raise_scarecrow(Vector2i(17, 7)), "站着的不用扶")
	assert_true(Farming.take_scarecrow(Vector2i(17, 7)))
	assert_false(Farming.take_scarecrow(Vector2i(17, 7)))
	assert_false(Farming.is_guarded(near))


func test_wind_may_blow_scarecrows_down() -> void:
	for x in 40:
		Farming.place_scarecrow(Vector2i(x, 30))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var n := Farming.blow_scarecrows(rng)
	assert_between(n, 3, 20, "四十个里倒了一部分")
	var down := 0
	for t: Vector2i in Farming.scarecrows:
		if Farming.scarecrow_fallen(t):
			down += 1
	assert_eq(down, n)


func test_daily_raid_reports_in_the_morning() -> void:
	GameState.set_flag(&"lamp_plaza")
	var hit := 0
	for i in 60:
		Farming.state.clear()
		_sow(Vector2i(16, 10))
		_sow(Vector2i(17, 10))
		_sow(Vector2i(18, 10))
		Weather.today = &"sunny"
		Farming._on_new_day()
		if not Farming.raided.is_empty():
			hit += 1
			assert_between(Farming.raided.size(), 1, Farming.CROW_MAX)
			assert_string_contains("\n".join(Farming.morning_notes), "乌鸦")
			assert_eq(Farming.state.crops.size(), 3 - Farming.raided.size())
		else:
			assert_eq(Farming.state.crops.size(), 3)
	assert_between(hit, 8, 36, "六十天里大约三成的日子有乌鸦")
	GameState.set_flag(&"pet_cat")
	# 上面最后一天可能刚被刨过：以现在地里的数为准
	var kept := Farming.state.crops.size()
	for i in 30:
		Farming._on_new_day()
		assert_true(Farming.raided.is_empty(), "屋子跟前的地有猫守着")
		assert_eq(Farming.state.crops.size(), kept)
	# 屋子远处的地猫管不到，早上的提示换一句
	var far_hit := 0
	for i in 60:
		Farming.state.clear()
		_sow(Vector2i(24, 12))
		Farming._on_new_day()
		if not Farming.raided.is_empty():
			far_hit += 1
			assert_string_contains("\n".join(Farming.morning_notes), "猫管不到")
	assert_between(far_hit, 8, 36, "有猫，远处的地照样被刨")


func test_scarecrows_survive_save_and_load() -> void:
	Farming.place_scarecrow(Vector2i(20, 20))
	Farming.place_scarecrow(Vector2i(22, 20))
	Farming.scarecrows[Vector2i(22, 20)] = true
	var data := Farming.save_data()
	Farming.reset_data()
	assert_false(Farming.has_scarecrow(Vector2i(20, 20)))
	Farming.load_data(JSON.parse_string(JSON.stringify(data)))
	assert_true(Farming.has_scarecrow(Vector2i(20, 20)))
	assert_false(Farming.scarecrow_fallen(Vector2i(20, 20)))
	assert_true(Farming.scarecrow_fallen(Vector2i(22, 20)))


func test_grocery_sells_scarecrows_after_the_lamp() -> void:
	var ids := Shop.entries(&"spring", Shop.GROCERY).map(func(e: ShopEntry) -> StringName: return e.item_id)
	assert_false(ids.has(&"scarecrow"))
	GameState.set_flag(&"lamp_plaza")
	ids = Shop.entries(&"spring", Shop.GROCERY).map(func(e: ShopEntry) -> StringName: return e.item_id)
	assert_true(ids.has(&"scarecrow"))


func test_scarecrow_on_the_farm() -> void:
	var farm := _map(&"farm")
	var spot := _open_spot(farm)
	GameState.inventory.clear()
	GameState.inventory.add(&"scarecrow", 2)
	GameState.selected_slot = 0
	var item := GameState.selected_item()
	assert_eq(farm.query_use(item, spot, GameMap.Facing.DOWN), &"place")
	farm.perform(&"place", item, spot)
	assert_true(Farming.has_scarecrow(spot))
	assert_eq(GameState.inventory.count_of(&"scarecrow"), 1)
	assert_true(farm._tile_blocked(spot), "稻草人挡路")
	assert_true(farm._scarecrow_sprites.has(spot))
	assert_eq(farm.query_use(null, spot, GameMap.Facing.DOWN), &"interact")
	Farming.scarecrows[spot] = true
	Farming.scarecrows_changed.emit()
	farm.perform(&"interact", null, spot)
	assert_false(Farming.scarecrow_fallen(spot), "扶起来了")
	assert_string_contains(_banners[-1], "扶")
	farm.perform(&"interact", null, spot)
	assert_false(Farming.has_scarecrow(spot), "再按一下收走")
	assert_eq(GameState.inventory.count_of(&"scarecrow"), 2)
	assert_false(farm._tile_blocked(spot))


## 农场上一块能立东西的空草地。
func _open_spot(farm: OutdoorMap) -> Vector2i:
	for y in range(20, 30):
		for x in range(10, 28):
			var t := Vector2i(x, y)
			if farm._can_plant_tree(t):
				return t
	fail_test("农场上找不到空地")
	return Vector2i.ZERO


func test_crows_stand_on_raided_tiles_and_flee() -> void:
	GameClock.minutes = 400.0
	Farming.raided = [Vector2i(16, 10), Vector2i(20, 12)]
	var farm := _map(&"farm")
	assert_eq(farm._crows.size(), 2)
	var me := Node2D.new()
	add_child_autofree(me)
	farm.player = me
	me.position = Vector2(-500, -500)
	farm._process(0.016)
	assert_eq(farm._crows.size(), 2, "人离得远不飞")
	me.position = GameMap.tile_center(Vector2i(16, 10)) + Vector2(10, 0)
	farm._process(0.016)
	assert_eq(farm._crows.size(), 1, "走近的那只飞了")
	Farming.raided.clear()


func test_no_crows_on_the_farm_later_in_the_day() -> void:
	GameClock.minutes = 700.0
	Farming.raided = [Vector2i(16, 10)]
	var farm := _map(&"farm")
	assert_eq(farm._crows.size(), 0)
	Farming.raided.clear()


func test_cat_by_the_bin_does_not_steal_the_press() -> void:
	GameState.set_flag(&"pet_cat")
	var farm := _map(&"farm")
	farm._sync_pet()
	assert_not_null(farm._pet)
	# 猫蹲在出货箱正下方那一格：离箱子 16 像素，在“摸得到”的 20 像素以内
	farm._pet.position = GameMap.tile_center(farm.BIN_TILE + Vector2i(0, 1)) + Vector2(0, 3)
	GameState.inventory.add(&"white_radish", 1)
	var radish := Database.item(&"white_radish")
	assert_eq(farm.query_use(radish, farm.BIN_TILE, GameMap.Facing.UP), &"interact")
	farm.perform(&"interact", radish, farm.BIN_TILE)
	assert_eq(Shipping.count_of(&"white_radish"), 1, "对着出货箱按就是出货")
	assert_ne(Animals.pet_day, GameClock.day, "没有变成摸猫")
	# 猫蹲在信箱跟前：按的是信箱
	farm._pet.position = GameMap.tile_center(farm.MAILBOX_TILE + Vector2i(0, 1)) + Vector2(0, 3)
	GameState.flags.erase(&"read_letter")
	farm.perform(&"interact", null, farm.MAILBOX_TILE)
	assert_true(GameState.has_flag(&"read_letter"), "对着信箱按就是看信")
	assert_ne(Animals.pet_day, GameClock.day)
	# 对着猫自己那一格，还是摸猫
	farm.perform(&"tend", null, farm._pet.tile())
	assert_eq(Animals.pet_day, GameClock.day)
