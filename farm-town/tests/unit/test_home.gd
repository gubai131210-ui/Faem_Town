extends GutTest
## 农舍扩建和装扮（决策 148）：青竹分两回扩，钱和石料先收、过几夜盖好；家具自己摆自己收，
## 不许把门口到床、灶、桌子的路堵死；墙纸地板换下来的收回背包；老存档屋里原样。

const TMP_SAVES := "user://test_saves_home"

var _old_dir := ""


func before_each() -> void:
	_old_dir = SaveSystem.base_dir
	SaveSystem.base_dir = TMP_SAVES
	SaveSystem.reset_all()
	GameClock.day = 10
	GameClock.minutes = 600.0


func after_each() -> void:
	SaveSystem.reset_all()
	SaveSystem.base_dir = _old_dir


func _house() -> GameMap:
	var map: GameMap = (load(SceneRouter.MAPS[&"farmhouse"]) as PackedScene).instantiate()
	add_child_autofree(map)
	return map


func test_a_new_game_has_the_old_room() -> void:
	assert_eq(Home.tier, 0)
	assert_eq(Vector2i(Home.width(), Home.height()), Vector2i(12, 9))
	assert_eq(Home.ox(), 0)
	assert_eq(Home.pieces.size(), 4, "两只凳子两只罐子")
	assert_eq(Home.paper, &"paper_plaster")
	assert_eq(Home.floor_id, &"floor_plank")
	var house := _house()
	assert_eq(house.size_px(), Vector2i(192, 144))
	assert_eq(house.trigger_at(Vector2i(5, 8)).get("map"), &"farm", "门还在老地方")
	assert_eq(house.query_use(null, Vector2i(10, 2), GameMap.Facing.UP), &"interact", "灶")
	assert_true(house.blocked(house.tile_center(Vector2i(6, 4))), "凳子挡路")


func test_qingzhu_builds_two_rooms_for_money_and_stone() -> void:
	assert_false(Home.can_offer(), "广场灯没亮、和青竹也不熟，她不接")
	GameState.set_flag(&"lamp_plaza")
	assert_true(Home.can_offer())
	GameState.money = 5000
	assert_false(Home.order(), "没有石头")
	assert_eq(GameState.money, 5000, "没订成什么都不收")
	GameState.inventory.add(&"stone", 60)
	assert_true(Home.order())
	assert_eq(GameState.money, 2000)
	assert_eq(GameState.inventory.count_of(&"stone"), 10)
	assert_eq(Home.building_now(), "东边的灶屋还要 3 天")
	assert_false(Home.can_offer(), "正在盖不接第二回")
	for i in 3:
		Home._on_new_day()
	assert_eq(Home.tier, 1)
	assert_string_contains(Home.morning_note, "灶屋")
	assert_eq(Vector2i(Home.width(), Home.height()), Vector2i(18, 10))
	assert_false(Home.can_offer(), "西厢要河灯")
	GameState.set_flag(&"lamp_river")
	GameState.money = 9000
	GameState.inventory.add(&"stone", 100)
	GameState.inventory.add(&"iron_ore", 20)
	assert_true(Home.order())
	for i in 4:
		Home._on_new_day()
	assert_eq(Home.tier, 2)
	assert_eq(Home.ox(), 6)
	assert_true(Home.on_floor(Vector2i(-6, 2)), "西厢在老屋西边")
	assert_false(Home.can_offer(), "扩满了")
	assert_eq(Home.next_upgrade(), {})


func test_old_things_move_east_with_the_west_room() -> void:
	Home.tier = 2
	var house := _house()
	assert_eq(house.size_px(), Vector2i(24 * 16, 11 * 16))
	assert_eq(house.query_use(null, Vector2i(16, 2), GameMap.Facing.UP), &"interact", "灶跟着老屋往东挪了六格")
	assert_eq(house.trigger_at(Vector2i(11, 10)).get("map"), &"farm", "门在最下面一行")
	assert_eq(house.trigger_at(Vector2i(5, 10)), {})
	assert_false(house.blocked(house.spawn_position(&"door")), "进门站得住")
	assert_false(house.blocked(house.tile_center(Vector2i(2, 5))), "西厢能走")


func test_furniture_cannot_wall_off_the_stove_or_the_door() -> void:
	assert_false(Home.can_place(&"stool", Vector2i(5, 8)), "门口")
	assert_false(Home.can_place(&"stool", Vector2i(5, 7)), "门里面那一格")
	assert_false(Home.can_place(&"stool", Vector2i(9, 3)), "灶君站的地方")
	assert_false(Home.can_place(&"stool", Vector2i(1, 3)), "床上")
	assert_false(Home.can_place(&"stool", Vector2i(12, 4)), "屋外")
	assert_false(Home.can_place(&"stool", Vector2i(6, 6), Vector2i(6, 6)), "人站着的那一格")
	assert_true(Home.place(&"bench", Vector2i(10, 3)))
	assert_false(Home.can_place(&"stool", Vector2i(9, 2)), "再放一只灶就够不着了")
	assert_true(Home.can_place(&"stool", Vector2i(3, 5)))
	assert_false(Home.can_place(&"paper_indigo", Vector2i(3, 5)), "墙纸不是摆的")


func test_a_rug_lies_under_furniture_and_comes_up_last() -> void:
	assert_true(Home.place(&"rug", Vector2i(5, 5)))
	var rug: Vector2i = Home.pieces[-1]["at"]
	assert_false(Home.blocked_tiles().has(rug), "毯子上能走")
	assert_false(Home.can_place(&"rug", rug), "毯子不叠毯子")
	var spot := rug + Vector2i(2, 1)
	assert_true(Home.place(&"stool", spot), "凳子能放在毯子上")
	assert_eq(Home.take(spot), &"stool", "先收上面的凳子")
	assert_eq(Home.take(spot), &"rug")


func test_scrolls_go_on_bare_wall_only() -> void:
	assert_true(Home.can_place(&"wall_scroll", Vector2i(3, 1)))
	assert_false(Home.can_place(&"wall_scroll", Vector2i(1, 1)), "窗上")
	assert_false(Home.can_place(&"wall_scroll", Vector2i(8, 1)), "老挂轴和牌那一段")
	assert_false(Home.can_place(&"wall_scroll", Vector2i(3, 3)), "不是墙")
	assert_true(Home.place(&"wall_fu", Vector2i(3, 1)))
	assert_false(Home.can_place(&"wall_scroll", Vector2i(3, 1)), "挂过了")


func test_placing_and_picking_up_in_the_house() -> void:
	var house := _house()
	GameState.inventory.add(&"bookshelf", 1)
	var shelf := Database.item(&"bookshelf")
	# 对着的那一格是书架正面左边那格（宽 2 往左摊一半取整为 0）
	assert_eq(house.query_use(shelf, Vector2i(2, 7), GameMap.Facing.DOWN), &"place")
	house.perform(&"place", shelf, Vector2i(2, 7))
	assert_eq(GameState.inventory.count_of(&"bookshelf"), 0)
	assert_true(house.blocked(house.tile_center(Vector2i(3, 7))))
	assert_eq(house.query_use(null, Vector2i(3, 7), GameMap.Facing.DOWN), &"interact")
	house.perform(&"interact", null, Vector2i(3, 7))
	assert_eq(GameState.inventory.count_of(&"bookshelf"), 1, "收回来了")
	assert_false(house.blocked(house.tile_center(Vector2i(3, 7))))
	# 原来那两只凳子也能收
	house.perform(&"interact", null, Vector2i(6, 4))
	assert_eq(GameState.inventory.count_of(&"stool"), 1)


func test_wallpaper_and_floor_swap_back_into_the_bag() -> void:
	var house := _house()
	GameState.inventory.add(&"paper_indigo", 1)
	GameState.inventory.add(&"floor_brick", 1)
	var paper := Database.item(&"paper_indigo")
	assert_eq(house.query_use(paper, Vector2i(4, 1), GameMap.Facing.UP), &"place")
	house.perform(&"place", paper, Vector2i(4, 1))
	assert_eq(Home.paper, &"paper_indigo")
	assert_eq(GameState.inventory.count_of(&"paper_plaster"), 1, "白灰墙收进背包")
	house.perform(&"place", Database.item(&"floor_brick"), Vector2i(4, 5))
	assert_eq(Home.floor_id, &"floor_brick")
	assert_eq(GameState.inventory.count_of(&"floor_plank"), 1)
	assert_eq(Home.apply_surface(&"floor_brick"), &"", "同一种不再换")


func test_home_survives_a_save_and_old_saves_keep_the_old_room() -> void:
	Home.tier = 1
	Home.days_left = 2
	Home.place(&"bonsai", Vector2i(14, 5))
	Home.apply_surface(&"paper_bamboo")
	var data := Home.save_data()
	Home.reset_data()
	Home.load_data(JSON.parse_string(JSON.stringify(data)))
	assert_eq(Home.tier, 1)
	assert_eq(Home.days_left, 2)
	assert_eq(Home.paper, &"paper_bamboo")
	assert_eq(Home.piece_at(Vector2i(14, 5)) >= 0, true)
	assert_eq(Home.pieces.size(), 5)
	Home.reset_data()
	Home.load_data({})
	assert_eq(Home.pieces.size(), 4, "老存档没有这一项：屋里还是那两只凳子两只罐子")
	assert_eq(Home.tier, 0)


func test_the_carpenter_sells_furniture_and_only_she_does() -> void:
	var names: Array[StringName] = []
	for e in Shop.entries(&"spring", Shop.CARPENTER):
		names.append(e.item_id)
	assert_true(names.has(&"bookshelf") and names.has(&"paper_indigo") and names.has(&"floor_brick"))
	assert_eq(names.size(), Home.all_ids().size(), "表里每一样都卖")
	for e in Shop.entries(&"spring", Shop.GROCERY):
		assert_false(Home.is_decor(e.item_id), "杂货铺不卖家具")
	for id in Home.all_ids():
		assert_true(Database.has_item(id), "%s 在物品表里" % id)
		assert_eq(Database.item(id).kind, &"decor")
		assert_false(Database.item(id).sellable(), "家具不进出货箱")
		var used := PixelArt.icon(Database.item(id).icon).get_used_rect().size
		assert_gt(maxi(used.x, used.y), 8, "%s 有图标" % id)
		var prop := Home.prop_of(id)
		if prop != "":
			assert_true(PropArt.has(prop), "%s 有素材" % prop)


func test_qingzhu_offers_the_extension_in_her_menu() -> void:
	var res: Resource = load(Residents.dialogue_path(&"qingzhu"))
	GameState.set_flag(&"lamp_plaza")
	GameState.money = 3500
	GameState.inventory.add(&"stone", 50)
	var line: Variant = await DialogueManager.get_next_dialogue_line(res, "daily")
	var picked := ""
	while line != null and line.responses.is_empty():
		line = await DialogueManager.get_next_dialogue_line(res, line.next_id)
	var texts := PackedStringArray()
	for r: DialogueResponse in line.responses:
		if r.is_allowed:
			texts.append(r.text)
			if r.text.contains("扩建农舍"):
				picked = r.next_id
	assert_true(" ".join(texts).contains("扩建农舍：东边的灶屋（3000 文，石头 ×50，3 天）"), " ".join(texts))
	assert_true(" ".join(texts).contains("看看家具"))
	line = await DialogueManager.get_next_dialogue_line(res, picked)
	assert_eq(Home.days_left, 3)
	assert_eq(GameState.money, 500)


func test_the_farm_shows_the_wings() -> void:
	var farm: OutdoorMap = (load(SceneRouter.MAPS[&"farm"]) as PackedScene).instantiate()
	add_child_autofree(farm)
	assert_false(farm._tile_blocked(Vector2i(12, 5)), "开局东边是空地")
	farm.queue_free()
	Home.tier = 2
	var built: OutdoorMap = (load(SceneRouter.MAPS[&"farm"]) as PackedScene).instantiate()
	add_child_autofree(built)
	assert_true(built._tile_blocked(Vector2i(12, 5)), "东边灶屋")
	assert_true(built._tile_blocked(Vector2i(3, 5)), "西厢")
	assert_false(built._tile_blocked(Vector2i(11, 8)), "信箱前面还能站")
	assert_gt(built.find_path(Vector2i(8, 8), Vector2i(1, 11)).size(), 0, "出门往镇上的路没堵")
