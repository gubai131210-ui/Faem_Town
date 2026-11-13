extends GutTest
## M4 第一批：请青竹盖鸡舍、找阿牧买鸡鸭、喂食抚摸、心情和产蛋。

const WALL := Vector2i(34, 9)


func before_each() -> void:
	SaveSystem.reset_all()
	Weather.today = &"sunny"
	GameClock.minutes = 600.0
	GameClock.day = 1


func after_each() -> void:
	SaveSystem.reset_all()
	Weather.today = &"sunny"
	GameClock.running = false


func _farm() -> OutdoorMap:
	var scene: PackedScene = load(SceneRouter.MAPS[&"farm"])
	var m: OutdoorMap = scene.instantiate()
	add_child_autofree(m)
	return m


## 直接把四栋建筑都盖好，再买几只。
func _ranch(kinds: Array[String]) -> void:
	# 三盏灯都亮了，阿牧关于牛铃和牧道的话也都说过了
	for f: StringName in [&"lamp_plaza", &"lamp_river", &"lamp_pasture", &"bell_hint", &"amu_bell", &"amu_pasture"]:
		GameState.set_flag(f)
	GameState.money = 1000000
	for id: StringName in Database.buildings:
		Animals.order(String(id))
	for i in 5:
		Animals.settle(false)
	Animals.morning_notes.clear()
	for k in kinds:
		assert_true(Animals.buy(k), "买得到 %s" % k)
	GameState.money = 0


## 走一段对话，碰到选择就按 picks 里的字样依次挑；返回说过的所有话（含选项的字）。
func _say(res: Resource, title: String, picks: Array[String] = []) -> String:
	var said := ""
	var line: Variant = await DialogueManager.get_next_dialogue_line(res, title)
	var k := 0
	while line != null:
		said += str(line.text)
		var next: String = line.next_id
		if line.responses.size() > 0:
			var chosen := ""
			for r: DialogueResponse in line.responses:
				if not r.is_allowed:
					continue
				said += "[%s]" % r.text
				if k < picks.size() and chosen == "" and r.text.contains(picks[k]):
					chosen = r.next_id
			if chosen == "":
				break
			k += 1
			next = chosen
		if next == "end" or next == "":
			break
		line = await DialogueManager.get_next_dialogue_line(res, next)
	return said


# ---------------------------------------------------------------- 数据

func test_tables_are_valid() -> void:
	assert_eq(Database.validate(), PackedStringArray(), "数据表没有错")
	assert_true(Database.has_building(&"coop"))
	var coop := Database.building(&"coop")
	assert_eq(coop.footprint().size(), coop.width * coop.depth)
	assert_true(coop.footprint().has(WALL))
	assert_false(coop.footprint().has(coop.door_tile()), "门口那格在占地外面")
	for id: StringName in [&"chicken", &"duck"]:
		var a := Database.animal(id)
		assert_eq(a.building, &"coop")
		assert_true(Database.has_item(a.produce))
		assert_gt(a.names.size(), 3)
	assert_true(Database.item(&"egg").sellable())
	assert_false(Database.item(&"feed").sellable(), "饲料不往出货箱里放")


func test_grocery_sells_feed_after_the_lamp() -> void:
	var found := false
	for e in Shop.entries(&"spring", Shop.GROCERY):
		found = found or e.item_id == &"feed"
	assert_false(found, "广场灯没亮货架上没有饲料")
	GameState.set_flag(&"lamp_plaza")
	for e in Shop.entries(&"spring", Shop.GROCERY):
		found = found or e.item_id == &"feed"
	assert_true(found)


# ---------------------------------------------------------------- 盖房子

func test_order_needs_lamp_and_money_and_takes_days() -> void:
	GameState.money = 5000
	assert_false(Animals.can_offer("coop"), "广场灯没亮青竹不接活")
	assert_false(Animals.order("coop"))
	GameState.set_flag(&"lamp_plaza")
	assert_true(Animals.can_offer("coop"))
	GameState.money = 100
	assert_false(Animals.order("coop"), "钱不够")
	assert_eq(Animals.building_state("coop"), -1)
	GameState.money = 5000
	assert_true(Animals.order("coop"))
	assert_eq(GameState.money, 5000 - Animals.price("coop"))
	assert_false(Animals.can_offer("coop"), "订过了不再问")
	assert_false(Animals.is_built(&"coop"))
	assert_eq(Animals.building_state("coop"), 3)
	Animals.settle(false)
	Animals.settle(false)
	assert_eq(Animals.days_left(&"coop"), 1)
	Animals.settle(false)
	assert_true(Animals.is_built(&"coop"))
	assert_true("".join(Animals.morning_notes).contains("鸡舍"), "盖好那天早上说一声")


# ---------------------------------------------------------------- 买动物

func test_buy_needs_river_lamp_room_and_money() -> void:
	GameState.set_flag(&"lamp_plaza")
	GameState.money = 100000
	Animals.order("coop")
	GameState.set_flag(&"lamp_river")
	assert_eq(Animals.room("coop"), 0, "没盖好没地方住")
	assert_false(Animals.buy("chicken"))
	for i in 3:
		Animals.settle(false)
	assert_eq(Animals.room("coop"), 4)
	assert_false(Animals.sells_kind("goat"), "没有畜棚")
	GameState.money = 10
	assert_false(Animals.buy("chicken"), "钱不够")
	GameState.money = 100000
	assert_false(Animals.buy("dragon"))
	var names: Dictionary[String, bool] = {}
	for k: String in ["chicken", "chicken", "duck", "duck"]:
		assert_true(Animals.buy(k))
		assert_false(names.has(Animals.last_name), "名字不重样")
		names[Animals.last_name] = true
	assert_eq(Animals.room("coop"), 0)
	assert_false(Animals.buy("chicken"), "住满了")
	assert_eq(GameState.money, 100000 - 2 * 400 - 2 * 600)
	assert_eq(Animals.mood_of(0), Animals.START_MOOD)


func test_no_buying_before_the_river_lamp() -> void:
	_ranch([])
	GameState.flags.erase(&"lamp_river")
	GameState.money = 5000
	assert_false(Animals.sells_kind("chicken"))
	assert_false(Animals.buy("chicken"))
	assert_true(Animals.sells_kind("goat"), "山羊看的是牧野灯")


# ---------------------------------------------------------------- 喂、摸、过夜

func test_feed_uses_feed_once_a_day() -> void:
	_ranch(["chicken", "duck"])
	assert_false(Animals.feed(0), "没有饲料")
	GameState.inventory.add(&"feed", 3)
	assert_true(Animals.feed(0))
	assert_false(Animals.feed(0), "一天喂一次")
	assert_eq(GameState.inventory.count_of(&"feed"), 2)
	assert_eq(Animals.hungry_in(&"coop"), 1)
	assert_eq(Animals.feed_all(&"coop"), 1)
	assert_eq(GameState.inventory.count_of(&"feed"), 1)
	assert_eq(Animals.hungry_in(&"coop"), 0)


func test_pet_raises_mood_once_a_day() -> void:
	_ranch(["chicken"])
	assert_true(Animals.pet(0))
	assert_eq(Animals.mood_of(0), Animals.START_MOOD + Animals.PET_MOOD)
	assert_false(Animals.pet(0))
	Animals.settle(false)
	assert_true(Animals.pet(0), "第二天又能摸")


func test_fed_animals_lay_and_hungry_ones_sulk() -> void:
	_ranch(["chicken", "chicken"])
	GameState.inventory.add(&"feed", 1)
	Animals.feed(0)
	Animals.settle(false)
	assert_eq(Animals.stored(&"coop"), 1, "只有喂过的那只下蛋")
	assert_eq(Animals.mood_of(0), Animals.START_MOOD + Animals.FED_MOOD)
	assert_eq(Animals.mood_of(1), Animals.START_MOOD + Animals.HUNGRY_MOOD)
	assert_false(Animals.is_fed(0), "过了夜又要喂")
	# 一直不喂，心情掉到底，喂了也不下
	for i in 5:
		Animals.settle(false)
	assert_lt(Animals.mood_of(1), Animals.SULK_MOOD)
	var before := Animals.stored(&"coop")
	GameState.inventory.add(&"feed", 1)
	Animals.feed(1)
	Animals.settle(false)
	assert_eq(Animals.stored(&"coop"), before, "闷闷不乐的时候不下蛋")
	assert_eq(Animals.mood_text(1), "闷闷不乐")


func test_rain_suits_ducks_not_chickens() -> void:
	_ranch(["chicken", "duck"])
	GameState.inventory.add(&"feed", 2)
	Animals.feed_all(&"coop")
	Animals.settle(true)
	assert_eq(Animals.mood_of(0), Animals.START_MOOD + Animals.FED_MOOD - 5)
	assert_eq(Animals.mood_of(1), Animals.START_MOOD + Animals.FED_MOOD + 10)


func test_quality_follows_mood() -> void:
	assert_eq(Animals.quality_for(30, 0.0), 0)
	assert_eq(Animals.quality_for(Animals.GOOD_MOOD, 0.1), 1)
	assert_eq(Animals.quality_for(Animals.GOOD_MOOD, 0.9), 0)
	assert_eq(Animals.quality_for(Animals.GREAT_MOOD, 0.1), 2)
	assert_eq(Animals.quality_for(Animals.GREAT_MOOD, 0.9), 1)


func test_collect_leaves_what_does_not_fit() -> void:
	_ranch(["chicken", "chicken"])
	GameState.inventory.add(&"feed", 2)
	Animals.feed_all(&"coop")
	Animals.settle(false)
	assert_eq(Animals.stored(&"coop"), 2)
	# 把背包塞满
	var inv := GameState.inventory
	var filler: Array[StringName] = []
	for id: StringName in Database.items:
		if id != &"egg":
			filler.append(id)
	var k := 0
	while inv.can_add(&"egg", 1, 0) and k < filler.size():
		inv.add(filler[k], 1)
		k += 1
	assert_eq(Animals.collect(&"coop").size(), 0)
	assert_eq(Animals.stored(&"coop"), 2, "放不下的留在鸡舍里")
	inv.clear()
	assert_eq(Animals.collect(&"coop").size(), 2)
	assert_eq(Animals.stored(&"coop"), 0)
	assert_eq(inv.count_of(&"egg"), 2)


func test_store_is_capped() -> void:
	_ranch(["chicken"])
	for i in 40:
		GameState.inventory.add(&"feed", 1)
		Animals.feed(0)
		Animals.settle(false)
	assert_eq(Animals.stored(&"coop"), Database.building(&"coop").capacity * Animals.STORE_PER_ANIMAL)


func test_save_round_trip() -> void:
	_ranch(["chicken", "duck"])
	GameState.inventory.add(&"feed", 1)
	Animals.feed(1)
	Animals.pet(0)
	Animals.settle(false)
	Animals.pet(1)
	var name0 := Animals.name_of(0)
	var data: Dictionary = JSON.parse_string(JSON.stringify(Animals.save_data()))
	Animals.reset_data()
	assert_eq(Animals.animals.size(), 0)
	Animals.load_data(data)
	assert_true(Animals.is_built(&"coop"))
	assert_eq(Animals.animals.size(), 2)
	assert_eq(Animals.name_of(0), name0)
	assert_eq(Animals.def_of(1).id, &"duck")
	assert_true(Animals.is_petted(1))
	assert_false(Animals.is_petted(0))
	assert_gte(Animals.stored(&"coop"), 1, "鸭蛋在，可能还有一根鸭毛")
	assert_gt(Animals.collect(&"coop").size(), 0)
	# 坏数据不崩
	Animals.load_data({"buildings": {"castle": 1}, "animals": [{"kind": "dragon"}, 3], "stores": {"coop": [["nothing", 0], 5]}})
	assert_eq(Animals.animals.size(), 0)
	assert_false(Animals.has_building(&"castle"))
	assert_eq(Animals.stored(&"coop"), 0)


# ---------------------------------------------------------------- 农场上

func test_site_is_open_ground_until_built() -> void:
	var farm := _farm()
	var coop := Database.building(&"coop")
	for t in coop.footprint():
		assert_false(farm._tile_blocked(t), "没盖的时候 %s 是空地" % t)
	assert_true(farm._walkable(coop.door_tile()))
	for x in range(coop.yard.position.x, coop.yard.end.x):
		for y in range(coop.yard.position.y, coop.yard.end.y):
			assert_false(farm._tile_blocked(Vector2i(x, y)), "院子里没有树和石头 %d,%d" % [x, y])
	assert_eq(farm.query_use(null, WALL, GameMap.Facing.UP), &"")


func test_scaffold_then_coop_blocks_the_site() -> void:
	var farm := _farm()
	var coop := Database.building(&"coop")
	GameState.set_flag(&"lamp_plaza")
	GameState.money = 5000
	Animals.order("coop")
	assert_eq(farm._building_shown[&"coop"], "scaffold")
	for t in coop.footprint():
		assert_true(farm._tile_blocked(t))
	assert_false(farm._tile_blocked(coop.door_tile()))
	assert_eq(farm.query_use(null, WALL, GameMap.Facing.UP), &"interact")
	watch_signals(EventBus)
	farm.perform(&"interact", null, WALL)
	assert_signal_emitted(EventBus, "banner_requested")
	for i in 3:
		Animals.settle(false)
	assert_eq(farm._building_shown[&"coop"], "coop")
	assert_eq(farm.query_use(null, WALL, GameMap.Facing.UP), &"interact", "空鸡舍只能看看")
	# 存档里已经盖好的，进地图就在
	var again := _farm()
	assert_eq(again._building_shown[&"coop"], "coop")
	assert_true(again._tile_blocked(WALL))


func test_building_clears_what_was_on_the_site() -> void:
	var t := Vector2i(33, 8)
	Farming.state.till(t)
	Farming.state.plant(t, &"bok_choy")
	_ranch([])
	var farm := _farm()
	assert_false(Farming.state.has_crop(t), "占地上的作物拔掉了")
	assert_not_null(farm)


func test_critters_come_out_by_day_and_weather() -> void:
	_ranch(["chicken", "duck"])
	var farm := _farm()
	assert_eq(farm._critters.size(), 2)
	var coop := Database.building(&"coop")
	for c: Critter in farm._critters:
		assert_true(coop.yard.grow(1).has_point(c.tile()), "在院子里 %s" % c.tile())
	GameClock.minutes = 1200.0
	farm._sync_critters()
	assert_eq(farm._critters.size(), 0, "天黑回窝")
	GameClock.minutes = 600.0
	Weather.today = Weather.RAIN
	farm._sync_critters()
	assert_eq(farm._critters.size(), 1, "下雨只有鸭子在外面")
	assert_eq(farm._critters[0].def.id, &"duck")
	Weather.today = Weather.STORM
	farm._sync_critters()
	assert_eq(farm._critters.size(), 0)
	Weather.today = &"sunny"
	farm._sync_critters()
	Animals.buy("chicken")
	GameState.money = 5000
	Animals.buy("chicken")
	assert_eq(farm._critters.size(), 3, "新买的也出来了")


func test_interact_feeds_then_pets_then_tells() -> void:
	_ranch(["chicken"])
	var farm := _farm()
	var c: Critter = farm._critters[0]
	var t := c.tile()
	assert_eq(farm.query_use(null, t, GameMap.Facing.UP), &"tend", "没摸过：伸手")
	GameState.inventory.add(&"feed", 1)
	var feed := Database.item(&"feed")
	farm.perform(&"interact", feed, t)
	assert_true(Animals.is_fed(0))
	assert_eq(GameState.inventory.count_of(&"feed"), 0)
	assert_false(Animals.is_petted(0))
	farm.perform(&"interact", feed, t)
	assert_true(Animals.is_petted(0), "喂过了再按就是摸")
	assert_eq(farm.query_use(feed, t, GameMap.Facing.UP), &"interact", "都做过了只是看看")
	var mood := Animals.mood_of(0)
	watch_signals(EventBus)
	farm.perform(&"interact", null, t)
	assert_eq(Animals.mood_of(0), mood)
	assert_signal_emitted(EventBus, "banner_requested")


func test_coop_wall_feeds_all_and_collects() -> void:
	_ranch(["chicken", "duck"])
	var farm := _farm()
	GameState.inventory.add(&"feed", 5)
	var feed := Database.item(&"feed")
	farm.perform(&"interact", feed, WALL)
	assert_eq(Animals.hungry_in(&"coop"), 0)
	assert_eq(GameState.inventory.count_of(&"feed"), 3)
	Animals.settle(false)
	assert_gte(Animals.stored(&"coop"), 2)
	farm.perform(&"interact", null, WALL)
	assert_eq(Animals.stored(&"coop"), 0)
	assert_eq(GameState.inventory.count_of(&"egg"), 1)
	assert_eq(GameState.inventory.count_of(&"duck_egg"), 1)


func test_chicken_at_the_foot_of_the_wall_does_not_steal_the_press() -> void:
	_ranch(["chicken", "duck"])
	var farm := _farm()
	# 一只鸡正好晃到墙根下，贴着墙那一格的上沿
	var hen: Critter = farm._critters[0]
	hen.position = GameMap.tile_center(WALL) + Vector2(0, 11)
	# 别的家禽起始位置是随机的，偶尔比这只鸡离得还近：挪远，免得按到它们
	for i in range(1, farm._critters.size()):
		farm._critters[i].position = Vector2(-500, -500)
	assert_same(farm._critter_at(WALL), hen, "按老规矩这一下会对上它")
	GameState.inventory.add(&"feed", 5)
	var feed := Database.item(&"feed")
	assert_eq(farm.query_use(feed, WALL, GameMap.Facing.UP), &"tend")
	farm.perform(&"tend", feed, WALL)
	assert_eq(Animals.hungry_in(&"coop"), 0, "对着墙添料，整栋都喂上")
	assert_eq(GameState.inventory.count_of(&"feed"), 3)
	assert_false(Animals.is_petted(hen.index), "没有变成摸它")
	# 对着它自己站的那一格，还是它
	farm.perform(&"tend", null, hen.tile())
	assert_true(Animals.is_petted(hen.index))


# ---------------------------------------------------------------- 第二批：畜棚、蜂场、蚕房

func test_every_building_has_room_on_the_farm() -> void:
	var farm := _farm()
	var seen: Dictionary[Vector2i, StringName] = {}
	for id: StringName in Database.buildings:
		var b := Database.building(id)
		for t in b.footprint():
			assert_true(farm.in_map(t), "%s 的占地在地图里" % id)
			assert_false(farm._tile_blocked(t), "%s 的占地 %s 是空地" % [id, t])
			assert_false(seen.has(t), "%s 和 %s 不重叠" % [id, seen.get(t, &"")])
			seen[t] = id
		assert_true(farm._walkable(b.door_tile()), "%s 门口能站人" % id)
		assert_true(PropArt.has(b.prop), "%s 有物件" % id)
	assert_true(PropArt.has("scaffold_6") and PropArt.has("scaffold_3"))


func test_buildings_wait_for_their_lamps() -> void:
	GameState.money = 100000
	GameState.set_flag(&"lamp_plaza")
	assert_true(Animals.can_offer("coop"))
	assert_false(Animals.can_offer("silk_house"))
	assert_false(Animals.can_offer("barn"))
	GameState.set_flag(&"lamp_river")
	assert_true(Animals.can_offer("silk_house"))
	GameState.set_flag(&"lamp_pasture")
	assert_true(Animals.can_offer("barn") and Animals.can_offer("apiary"))
	assert_true(Animals.any_offer())
	for id: StringName in Database.buildings:
		Animals.order(String(id))
	assert_false(Animals.any_offer())
	assert_ne(Animals.building_now(), "")


func test_sheep_gives_wool_every_third_day() -> void:
	_ranch(["sheep", "goat"])
	for day in 3:
		GameState.inventory.add(&"feed", 2)
		assert_eq(Animals.feed_all(&"barn"), 2)
		Animals.settle(false)
	var got := Animals.collect(&"barn")
	var wool := 0
	var milk := 0
	for e: Array in got:
		wool += 1 if e[0] == &"wool" else 0
		milk += 1 if e[0] == &"goat_milk" else 0
	assert_eq(wool, 1, "三天剪一团")
	assert_eq(milk, 3, "羊奶天天有")


func test_bees_need_no_feed_and_follow_the_flowers() -> void:
	_ranch(["bee"])
	GameClock.day = 1
	assert_true(Animals.is_fed(0), "蜜蜂不用喂")
	assert_eq(Animals.hungry_in(&"apiary"), 0)
	Animals.nectar = func() -> StringName: return &""
	Animals.settle(false)
	assert_eq(Animals.stored(&"apiary"), 0, "两天一罐")
	Animals.settle(false)
	assert_eq(Animals.collect(&"apiary")[0][0], &"honey_wild", "没有认得的花是野花蜜")
	Animals.nectar = func() -> StringName: return &"rapeseed"
	Animals.settle(false)
	Animals.settle(false)
	assert_eq(Animals.collect(&"apiary")[0][0], &"honey_rape")
	assert_eq(Animals.mood_of(0), Animals.START_MOOD, "蜂没有心情涨落")
	# 冬天没花不酿；种着山茶就有
	GameClock.day = 3 * GameClock.DAYS_PER_SEASON + 2
	Animals.nectar = func() -> StringName: return &""
	Animals.settle(false)
	Animals.settle(false)
	assert_eq(Animals.stored(&"apiary"), 0)
	Animals.nectar = func() -> StringName: return &"camellia"
	Animals.settle(false)
	Animals.settle(false)
	assert_eq(Animals.collect(&"apiary")[0][0], &"honey_camellia")
	Animals.nectar = Callable()


func test_nectar_is_the_commonest_flower_near_the_apiary() -> void:
	var site := Database.building(&"apiary").site
	assert_eq(RanchLink.nectar(), &"")
	var farm := Farming.state
	for dx in 3:
		var t := site + Vector2i(dx - 1, 3)
		farm.till(t)
		farm.plant(t, &"rapeseed")
	assert_eq(RanchLink.nectar(), &"", "还没出苗不算")
	for t: Vector2i in farm.crops:
		farm.crops[t]["days"] = 30
	assert_eq(RanchLink.nectar(), &"rapeseed")
	# 远处的不算，不是花的不算
	var far := site + Vector2i(-20, 0)
	farm.till(far)
	farm.plant(far, &"rapeseed")
	var veg := site + Vector2i(0, 4)
	farm.till(veg)
	farm.plant(veg, &"bok_choy")
	farm.crops[veg]["days"] = 30
	assert_eq(RanchLink.nectar(), &"rapeseed")


func test_silkworms_eat_mulberry_leaves() -> void:
	_ranch(["silkworm", "silkworm"])
	GameState.inventory.add(&"feed", 5)
	assert_eq(Animals.feed_all(&"silk_house"), 0, "蚕不吃饲料")
	assert_false(Animals.feed(0))
	assert_eq(Animals.hungry_in(&"silk_house", &"feed"), 0)
	assert_eq(Animals.hungry_in(&"silk_house", &"mulberry_leaf"), 2)
	for day in 4:
		GameState.inventory.add(&"mulberry_leaf", 2)
		assert_eq(Animals.feed_all(&"silk_house", &"mulberry_leaf"), 2)
		Animals.settle(true)
	assert_eq(Animals.stored(&"silk_house"), 2, "四天一批茧")
	assert_eq(Animals.mood_of(0), Animals.START_MOOD + 4 * Animals.FED_MOOD, "屋里的不管下不下雨")
	assert_eq(GameState.inventory.count_of(&"feed"), 5)
	# 农场上：拿着桑叶对着蚕房的墙
	var farm := _farm()
	var wall := Database.building(&"silk_house").site
	var leaf := Database.item(&"mulberry_leaf")
	farm.perform(&"tend", null, wall)
	assert_eq(GameState.inventory.count_of(&"cocoon"), 2)
	assert_eq(farm.query_use(Database.item(&"feed"), wall, GameMap.Facing.UP), &"interact", "拿错了东西只能看看")
	assert_eq(farm.query_use(leaf, wall, GameMap.Facing.UP), &"tend")
	GameState.inventory.add(&"mulberry_leaf", 1)
	farm.perform(&"tend", leaf, wall)
	assert_eq(Animals.hungry_in(&"silk_house"), 1, "只有一把桑叶，喂了一匾")
	assert_eq(farm._critters.size(), 0, "蚕不出门")


func test_sending_one_back_refunds_half() -> void:
	_ranch(["chicken", "duck", "chicken"])
	var farm := _farm()
	assert_eq(farm._critters.size(), 3)
	var keep := Animals.name_of(2)
	assert_eq(Animals.nth_in("coop", 1), 1)
	assert_true(Animals.sell_nth("coop", 1))
	assert_eq(GameState.money, 300)
	assert_eq(Animals.animals.size(), 2)
	assert_eq(Animals.name_of(1), keep)
	assert_false(Animals.sell_nth("coop", 5))
	assert_false(Animals.has_nth("barn", 0))
	# 地图上的跟着换：两只，下标对得上
	assert_eq(farm._critters.size(), 2)
	var kinds: Array[StringName] = []
	for c: Critter in farm._critters:
		kinds.append(Animals.def_of(c.index).id)
		assert_eq(c.def.id, Animals.def_of(c.index).id)
	assert_eq(kinds, [&"chicken", &"chicken"] as Array[StringName])


func test_critters_already_out_stay_where_they_are() -> void:
	_ranch(["chicken"])
	var farm := _farm()
	var first: Critter = farm._critters[0]
	var pos := first.position
	GameState.money = 5000
	Animals.buy("duck")
	assert_eq(farm._critters.size(), 2)
	assert_same(farm._critters[0], first, "原来那只没被换掉")
	assert_eq(first.position, pos)


func test_ducks_may_enter_the_pond_and_chickens_may_not() -> void:
	_ranch(["chicken", "duck"])
	var farm := _farm()
	var hen: Critter = farm._critters[0]
	var duck: Critter = farm._critters[1]
	var pond := Vector2i(33, 17)
	assert_eq(farm.fishing_water(pond), &"pond")
	assert_true(duck._allowed(pond) and duck._can_stand(pond))
	assert_false(hen._allowed(pond))
	assert_false(hen._can_stand(pond))
	assert_false(duck._allowed(Vector2i(46, 17)), "小溪不在它的范围里")
	duck.position = GameMap.tile_center(pond)
	duck._apply()
	assert_true(duck.in_water())
	duck.position = GameMap.tile_center(Vector2i(33, 12))
	duck._apply()
	assert_false(duck.in_water())


func test_critter_steps_aside_when_crowded() -> void:
	_ranch(["chicken"])
	var farm := _farm()
	var hen: Critter = farm._critters[0]
	hen.position = GameMap.tile_center(Vector2i(34, 12))
	var dummy := Node2D.new()
	dummy.position = hen.position + Vector2(2, 0)
	farm.add_child(dummy)
	farm.player = dummy
	hen.avoid = dummy
	hen._wait = 0.5
	hen._moving = false
	GameClock.running = true
	await wait_seconds(0.6)
	assert_gt(hen.position.distance_to(dummy.position), 7.0, "让开了")
	assert_lt(hen.position.x, dummy.position.x, "往反方向走")


func test_buffalo_plows_a_whole_row() -> void:
	_ranch(["buffalo"])
	var farm := _farm()
	var ox: Critter = farm._critters[0]
	var dummy := Node2D.new()
	dummy.position = ox.position + Vector2(10, 0)
	farm.add_child(dummy)
	farm.player = dummy
	# 找一行八格都能开垦的空地
	var start := Vector2i(-1, -1)
	for y in range(28, 35):
		for x in range(16, 34):
			var clear := true
			for k in 8:
				clear = clear and farm._can_till(Vector2i(x + k, y))
			if clear and start.x < 0:
				start = Vector2i(x, y)
	assert_gt(start.x, 0)
	assert_eq(farm.plow_row(start, GameMap.Facing.RIGHT).size(), 0, "没牵着不算")
	# 喂、摸、再按一下才牵得走
	var t := ox.tile()
	GameState.inventory.add(&"feed", 1)
	farm.perform(&"tend", Database.item(&"feed"), t)
	farm.perform(&"tend", null, t)
	assert_true(Animals.is_fed(0) and Animals.is_petted(0))
	assert_null(farm._led)
	assert_eq(farm.query_use(null, t, GameMap.Facing.UP), &"interact")
	farm.perform(&"interact", null, t)
	assert_same(farm._led, ox)
	assert_same(ox.leader, dummy)
	var row := farm.plow_row(start, GameMap.Facing.RIGHT)
	assert_eq(row.size(), Animals.PLOW_LENGTH)
	assert_eq(row[0], start)
	assert_eq(row[7], start + Vector2i(7, 0))
	# 朝着畜棚走：到墙根为止
	var to_wall := farm.plow_row(Vector2i(19, 27), GameMap.Facing.UP)
	assert_lt(to_wall.size(), 3)
	assert_does_not_have(to_wall, Vector2i(19, 25))
	# 牛离远了不算
	dummy.position = ox.position + Vector2(200, 0)
	assert_eq(farm.plow_row(start, GameMap.Facing.RIGHT).size(), 0)
	dummy.position = ox.position + Vector2(10, 0)
	# 一天六行，干够了自己松开
	for i in Animals.PLOW_ROWS:
		assert_true(Animals.can_plow(0))
		farm.plowed()
	assert_false(Animals.can_plow(0))
	assert_null(farm._led)
	assert_null(ox.leader)
	watch_signals(EventBus)
	farm.perform(&"interact", null, ox.tile())
	assert_null(farm._led, "干够了牵不走")
	Animals.settle(false)
	assert_true(Animals.can_plow(0), "第二天又肯干")
	# 再按一下放开
	farm.perform(&"tend", null, ox.tile())
	farm.perform(&"interact", null, ox.tile())
	assert_same(farm._led, ox)
	farm.perform(&"interact", null, ox.tile())
	assert_null(farm._led)


func test_hoe_wins_over_the_led_buffalo_standing_in_the_way() -> void:
	_ranch(["buffalo"])
	var farm := _farm()
	var ox: Critter = farm._critters[0]
	var start := Vector2i(-1, -1)
	for y in range(28, 35):
		for x in range(16, 34):
			var clear := true
			for k in 8:
				clear = clear and farm._can_till(Vector2i(x + k, y))
			if clear and start.x < 0:
				start = Vector2i(x, y)
	assert_gt(start.x, 0)
	var dummy := Node2D.new()
	dummy.position = GameMap.tile_center(start + Vector2i(-1, 0))
	farm.add_child(dummy)
	farm.player = dummy
	# 牛就站在要开的第一格上
	ox.position = GameMap.tile_center(start) + Vector2(0, 3)
	var hoe := Database.item(&"hoe")
	assert_eq(farm.query_use(hoe, start, GameMap.Facing.RIGHT), &"tend", "没牵着的时候对着它是摸")
	Animals.pet(0)
	farm._toggle_lead(ox)
	assert_same(farm._led, ox)
	assert_eq(farm.query_use(hoe, start, GameMap.Facing.RIGHT), &"hoe", "牵着牛、拿着锄头、面前能开一行：锄地优先")
	assert_eq(farm.query_use(null, start, GameMap.Facing.RIGHT), &"interact", "空手对着它还是放开")
	assert_eq(farm.query_use(Database.item(&"watering_can"), start, GameMap.Facing.RIGHT), &"interact", "拿别的工具不抢")
	# 面前开不了一行（朝着建筑）就还是对牛
	var wall := Database.building(&"barn").site
	ox.position = GameMap.tile_center(wall + Vector2i(0, 1)) + Vector2(0, 3)
	dummy.position = GameMap.tile_center(wall + Vector2i(0, 2))
	assert_eq(farm.query_use(hoe, wall + Vector2i(0, 1), GameMap.Facing.UP), &"interact")


func test_led_buffalo_follows() -> void:
	_ranch(["buffalo"])
	var farm := _farm()
	var ox: Critter = farm._critters[0]
	var dummy := Node2D.new()
	dummy.position = ox.position + Vector2(90, 0)
	farm.add_child(dummy)
	ox.leader = dummy
	GameClock.running = true
	await wait_seconds(1.2)
	assert_lt(ox.position.distance_to(dummy.position), 40.0, "跟上来了")
	assert_gt(ox.position.distance_to(dummy.position), 12.0, "不贴在身上")


func test_sulking_buffalo_will_not_work() -> void:
	_ranch(["buffalo"])
	Animals.animals[0]["mood"] = 5
	assert_false(Animals.can_plow(0))
	_ranch([])
	assert_false(Animals.can_plow(7), "没有这头牛")


# ---------------------------------------------------------------- 对话

func test_qingzhu_offers_buildings() -> void:
	var res: Resource = load(Residents.dialogue_path(&"qingzhu"))
	var said: String = await _say(res, "daily")
	assert_false(said.contains("鸡舍"), "灯没亮不提")
	GameState.set_flag(&"lamp_plaza")
	GameState.money = 10
	said = await _say(res, "daily", ["鸡舍"])
	assert_true(said.contains("鸡舍（1200 文，3 天）"), said)
	assert_false(said.contains("畜棚"), "牧野灯没亮不提畜棚")
	assert_false(said.contains("蚕房"), "河灯没亮不提蚕房")
	assert_true(said.contains("钱袋子"), said)
	assert_false(Animals.has_building(&"coop"))
	# 不想盖也能接着聊
	said = await _say(res, "daily", ["聊聊别的"])
	assert_gt(said.length(), 60, said)
	GameState.money = 2000
	said = await _say(res, "again", ["鸡舍"])
	assert_true(said.contains("成"), said)
	assert_eq(GameState.money, 800)
	assert_eq(Animals.building_state("coop"), 3)
	said = await _say(res, "daily")
	assert_true(said.contains("鸡舍还要 3 天"), said)
	# 盖好了，别的灯也亮了：单子上是剩下的三样
	for i in 3:
		Animals.settle(false)
	GameState.set_flag(&"lamp_river")
	GameState.set_flag(&"lamp_pasture")
	GameState.money = 10000
	said = await _say(res, "daily", ["畜棚"])
	assert_true(said.contains("蚕房") and said.contains("蜂场"), said)
	assert_false(said.contains("[鸡舍"), "盖过的不再列")
	assert_eq(Animals.building_state("barn"), 4)


func test_amu_sells_chicks() -> void:
	var res: Resource = load(Residents.dialogue_path(&"amu"))
	GameState.set_flag(&"lamp_plaza")
	GameState.set_flag(&"lamp_river")
	var said: String = await _say(res, "daily")
	assert_true(said.contains("青竹"), said)
	assert_true(GameState.has_flag(&"amu_chicks"))
	said = await _say(res, "daily")
	assert_false(said.contains("盖一间鸡舍"), "提醒只说一次")
	GameState.money = 100000
	Animals.order("coop")
	for i in 3:
		Animals.settle(false)
	GameState.money = 1000
	said = await _say(res, "daily", ["小鸡小鸭", "鸡（400"])
	assert_eq(Animals.animals.size(), 1)
	assert_true(said.contains(Animals.name_of(0)), said)
	assert_false(said.contains("羊和牛"), "没有畜棚不卖大牲口")
	said = await _say(res, "again", ["小鸡小鸭", "鸭（600"])
	assert_eq(Animals.animals.size(), 2)
	assert_eq(Animals.def_of(1).id, &"duck")
	assert_eq(GameState.money, 0)
	said = await _say(res, "again", ["小鸡小鸭", "鸡（"])
	assert_true(said.contains("不够"), said)
	said = await _say(res, "daily", ["聊聊"])
	assert_eq(Animals.animals.size(), 2)
	assert_gt(said.length(), 40, "不买也能聊：%s" % said)


func test_amu_takes_an_animal_back() -> void:
	var res: Resource = load(Residents.dialogue_path(&"amu"))
	_ranch(["chicken", "duck", "goat"])
	var duck := Animals.name_of(1)
	var said: String = await _say(res, "daily", ["送一只回来", duck])
	assert_true(said.contains("%s（鸭，300 文）" % duck), said)
	assert_eq(Animals.animals.size(), 2)
	assert_eq(GameState.money, 300)
	assert_eq(Animals.def_of(1).id, &"goat", "后面的往前补")
	assert_true(said.contains("领回去了"), said)


func test_amu_keeps_the_buffalo_until_he_remembers() -> void:
	var res: Resource = load(Residents.dialogue_path(&"amu"))
	_ranch([])
	GameState.money = 5000
	var said: String = await _say(res, "daily", ["羊和牛"])
	assert_true(said.contains("[山羊") and said.contains("[绵羊"), said)
	assert_false(said.contains("[水牛"), "阿牧的忆没找回来以前不卖水牛")
	Residents.memory_levels[&"amu"] = 1
	said = await _say(res, "daily", ["羊和牛", "水牛"])
	assert_eq(Animals.animals.size(), 1)
	assert_true(Animals.def_of(0).plows)
