extends GutTest
## 扩大的农场（决策 147）：地块跟着灯和柏先生的许可一块块开；栅栏自己摆自己收；石头灌木清得掉；老档的东西还在原位。

const TMP_SAVES := "user://test_saves_farm_land"

var _old_dir := ""


func before_each() -> void:
	_old_dir = SaveSystem.base_dir
	SaveSystem.base_dir = TMP_SAVES
	SaveSystem.reset_all()
	GameClock.day = 10
	GameClock.minutes = 600.0
	Weather.today = Weather.SUNNY


func after_each() -> void:
	SaveSystem.reset_all()
	SaveSystem.base_dir = _old_dir


func test_every_tile_belongs_to_one_region() -> void:
	assert_eq(FarmLand.region_of(Vector2i(8, 8)), FarmLand.HOME)
	assert_eq(FarmLand.region_of(Vector2i(20, 12)), FarmLand.HOME, "原来那块田在老院")
	assert_eq(FarmLand.region_of(Vector2i(46, 20)), FarmLand.HOME, "溪水算西岸的")
	assert_eq(FarmLand.region_of(Vector2i(60, 12)), FarmLand.EAST)
	assert_eq(FarmLand.region_of(Vector2i(88, 12)), FarmLand.RIDGE)
	assert_eq(FarmLand.region_of(Vector2i(20, 45)), FarmLand.SOUTH)
	assert_eq(FarmLand.region_of(Vector2i(20, 63)), FarmLand.MARSH)
	assert_eq(FarmLand.region_of(Vector2i(72, 50)), FarmLand.SLOPE)
	for y in FarmLand.OLD_H:
		assert_eq(FarmLand.stream_x(y), 46 + int(roundf(sin(y * 0.33) * 1.6)), "老农场那一段小溪没挪")


func test_lamps_and_the_mayor_open_the_land() -> void:
	assert_eq(FarmLand.open_regions(), [FarmLand.HOME] as Array[StringName], "开局只有老院")
	GameState.set_flag(&"lamp_plaza")
	assert_true(FarmLand.is_open(FarmLand.SOUTH))
	assert_false(FarmLand.is_open(FarmLand.MARSH))
	GameState.set_flag(&"lamp_river")
	GameState.set_flag(&"lamp_pasture")
	GameState.set_flag(&"lamp_well")
	assert_true(FarmLand.is_open(FarmLand.MARSH))
	assert_true(FarmLand.is_open(FarmLand.SLOPE))
	assert_true(FarmLand.is_open(FarmLand.RIDGE))
	assert_false(FarmLand.is_open(FarmLand.EAST), "溪东不看灯")
	Residents.memory_levels[&"bai"] = 5
	assert_true(FarmLand.is_open(FarmLand.EAST))
	assert_eq(FarmLand.open_regions().size(), 6)


func test_fog_blocks_walking_tilling_and_says_why() -> void:
	var farm := _farm()
	var south := Vector2i(22, 46)
	assert_eq(farm.solid[farm.idx(south)], 0, "雾里的地本身是空的")
	assert_true(farm._tile_blocked(south), "雾里走不进去")
	assert_false(farm._can_till(south))
	assert_eq(farm.query_use(Database.item(&"hoe"), south, GameMap.Facing.DOWN), &"interact")
	watch_signals(EventBus)
	farm.perform(&"interact", null, south)
	assert_string_contains(str(get_signal_parameters(EventBus, "banner_requested")), "广场")
	assert_true(farm._fog.visible)
	GameState.set_flag(&"lamp_plaza")
	assert_false(farm._tile_blocked(south), "广场灯亮了，南坡能走")
	assert_true(farm._can_till(south))
	farm.perform(&"hoe", Database.item(&"hoe"), south, true)
	assert_true(Farming.state.is_tilled(south), "南坡开得出地")
	farm._sync_fog()
	assert_true(farm._fog.visible, "别的地块还盖着")
	for flag: StringName in [&"lamp_river", &"lamp_pasture", &"lamp_well"]:
		GameState.set_flag(flag)
	Residents.memory_levels[&"bai"] = 5
	farm._sync_fog()
	assert_false(farm._fog.visible, "全开了就没有雾")


func test_the_old_farm_is_where_it_was() -> void:
	var farm := _farm()
	assert_eq(farm.cols, 100)
	assert_eq(farm.rows, 72)
	assert_eq(farm.terrain[farm.idx(Vector2i(20, 12))], OutdoorMap.DIRT, "原来那块田")
	assert_eq(farm.terrain[farm.idx(Vector2i(33, 17))], OutdoorMap.WATER, "池塘")
	assert_eq(farm.trigger_at(Vector2i(0, 11))["map"], &"town")
	assert_true(Farming.has_fence(Vector2i(14, 8)), "原来那圈栅栏还在")
	assert_false(Farming.has_fence(Vector2i(14, 11)), "口子留着")
	assert_true(farm._tile_blocked(Vector2i(20, 8)), "栅栏挡路")
	assert_false(farm._walkable(Vector2i(20, 8)), "居民也绕着走")
	assert_gt(farm.find_path(Vector2i(8, 8), Vector2i(20, 12)).size(), 0, "从屋门口走得进田")
	assert_eq(farm.solid[farm.idx(Vector2i(51, 20))], 0, "原来东边那两排树不种了")


func test_fences_come_up_and_go_down_where_you_like() -> void:
	var farm := _farm()
	var post := Vector2i(20, 8)
	assert_eq(farm.query_use(Database.item(&"hoe"), post, GameMap.Facing.UP), &"hoe", "拿着锄头不会误收栅栏")
	assert_eq(farm.query_use(null, post, GameMap.Facing.UP), &"interact")
	farm.perform(&"interact", null, post)
	assert_false(Farming.has_fence(post))
	assert_eq(GameState.inventory.count_of(&"fence"), 1, "收回背包")
	assert_false(farm._tile_blocked(post))
	assert_true(farm._can_till(post), "拆了栅栏的地能开垦")
	var fence := Database.item(&"fence")
	var spot := Vector2i(20, 20)
	assert_eq(farm.query_use(fence, spot, GameMap.Facing.DOWN), &"place")
	farm.perform(&"place", fence, spot)
	assert_true(Farming.has_fence(spot))
	assert_eq(GameState.inventory.count_of(&"fence"), 0)
	assert_true(farm._fence_sprites.has(spot))
	assert_false(farm._can_till(spot), "栅栏底下不能开垦")
	Farming.state.till(Vector2i(21, 20))
	assert_eq(farm.query_use(fence, Vector2i(21, 20), GameMap.Facing.DOWN), &"", "耕地上不摆栅栏")
	var names: Array[StringName] = []
	for entry in Shop.entries(&"spring", Shop.GROCERY):
		names.append(entry.item_id)
	assert_has(names, &"fence", "杂货铺一开始就卖栅栏")


func test_rocks_break_and_shrubs_dig_and_both_stay_gone() -> void:
	GameState.set_flag(&"lamp_plaza")
	var farm := _farm()
	var rock := Vector2i(-1, -1)
	var shrub := Vector2i(-1, -1)
	for t: Vector2i in farm._bush_nodes:
		if farm._rubble_at(t) and FarmLand.region_of(t) == FarmLand.SOUTH and rock.x < 0:
			rock = t
		if farm._shrub_at(t) and shrub.x < 0:
			shrub = t
	assert_ne(rock.x, -1, "南坡有乱石")
	assert_ne(shrub.x, -1, "老院有灌木")
	var pick := Database.item(&"pickaxe")
	assert_eq(farm.query_use(pick, rock, GameMap.Facing.DOWN), &"mine")
	assert_false(farm._can_till(rock))
	farm.perform(&"mine", pick, rock, true)
	assert_eq(GameState.inventory.count_of(&"stone"), 1)
	assert_true(farm._can_till(rock), "敲掉石头的地能开垦")
	var hoe := Database.item(&"hoe")
	assert_eq(farm.query_use(hoe, shrub, GameMap.Facing.DOWN), &"hoe")
	farm.perform(&"hoe", hoe, shrub, true)
	assert_false(Farming.state.is_tilled(shrub), "头一下只刨掉灌木")
	assert_true(farm._can_till(shrub))
	farm = _farm()
	assert_false(farm._bush_nodes.has(rock), "再进农场，石头还是没有")
	assert_false(farm._bush_nodes.has(shrub))
	assert_eq(farm.solid[farm.idx(rock)], 0)


func test_fences_and_cleared_tiles_survive_a_save_and_old_saves_keep_the_ring() -> void:
	Farming.take_fence(Vector2i(14, 8))
	Farming.place_fence(Vector2i(30, 30))
	Farming.clear_wild(Vector2i(22, 46))
	assert_true(SaveSystem.save(1, GameState.save_meta()))
	SaveSystem.reset_all()
	assert_true(Farming.has_fence(Vector2i(14, 8)), "新开的档是原来那一圈")
	assert_true(SaveSystem.load_slot(1))
	assert_false(Farming.has_fence(Vector2i(14, 8)))
	assert_true(Farming.has_fence(Vector2i(30, 30)))
	assert_true(Farming.is_cleared(Vector2i(22, 46)))
	var old := Farming.save_data()
	old.erase("fences")
	old.erase("cleared")
	Farming.load_data(old)
	assert_eq(Farming.fences.size(), Farming.old_fence().size(), "扩大以前的档：栅栏是原来那一圈")
	assert_true(Farming.cleared.is_empty())


func test_every_landmark_is_reached_once_the_fog_is_gone() -> void:
	for flag: StringName in [&"lamp_plaza", &"lamp_river", &"lamp_pasture", &"lamp_well"]:
		GameState.set_flag(flag)
	Residents.memory_levels[&"bai"] = 5
	var farm := _farm()
	var start := Vector2i(8, 8)
	var goals: Dictionary[Vector2i, String] = {
		Vector2i(44, 11): "桥西头", Vector2i(47, 11): "桥东头", Vector2i(61, 14): "塌院子门口",
		Vector2i(15, 46): "老槐树下", Vector2i(20, 57): "苇塘的钓台", Vector2i(40, 68): "古木林的路口",
		Vector2i(50, 47): "踩石头过了溪", Vector2i(72, 52): "碾场", Vector2i(86, 30): "东岗第一层", Vector2i(88, 11): "岗顶亭子前",
	}
	for goal: Vector2i in goals:
		assert_gt(farm.find_path(start, goal).size(), 0, "走得到%s" % goals[goal])
		assert_false(farm._tile_blocked(goal), "%s站得住" % goals[goal])
	assert_eq(farm.level[farm.idx(Vector2i(88, 11))], 4, "亭子在岗顶那一层")
	assert_eq(farm.fishing_water(Vector2i(45, 11)), &"", "桥板上不是钓点")
	assert_eq(farm.fishing_water(Vector2i(20, 64)), &"pond", "苇塘是池塘的鱼")
	assert_eq(farm.fishing_water(Vector2i(FarmLand.stream_x(50), 50)), &"stream")
	assert_string_contains(farm.clue_at(Vector2i(61, 12)), "身高线")
	assert_eq(farm.query_use(null, Vector2i(61, 12), GameMap.Facing.UP), &"interact")
	assert_false(farm._can_till(Vector2i(72, 51)), "碾场的石板不开垦")
	assert_true(farm._can_till(Vector2i(90, 26)), "岗上能种")


func test_forage_only_grows_where_the_fog_has_gone() -> void:
	var farm := _farm()
	for t: Vector2i in farm._forage_tiles(false):
		assert_eq(FarmLand.region_of(t), FarmLand.HOME)
	GameState.set_flag(&"lamp_plaza")
	var south := 0
	for t: Vector2i in farm._forage_tiles(false):
		if FarmLand.region_of(t) == FarmLand.SOUTH:
			south += 1
		assert_true(FarmLand.open_tile(t))
	assert_gt(south, 100, "南坡开了就长东西")


func _farm() -> WildMap:
	var scene: PackedScene = load(SceneRouter.MAPS[&"farm"])
	var map: WildMap = scene.instantiate()
	add_child_autofree(map)
	return map
