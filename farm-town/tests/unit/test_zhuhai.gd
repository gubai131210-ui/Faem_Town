extends GutTest
## 竹海：桥北头进来，夜里山魈，米酒引狌狌，白天见乘黄，见过以后脚下快一点，手账里有山海录（决策 126）。


func before_each() -> void:
	SaveSystem.base_dir = "user://test_saves_zhuhai"
	SaveSystem.reset_all()
	GameClock.day = 10
	GameClock.minutes = 600.0
	Weather.today = Weather.SUNNY


func test_the_bridge_end_enters_and_the_south_edge_leaves() -> void:
	var wharf := _outdoor(&"wharf")
	assert_eq(wharf.trigger_at(Vector2i(22, 2))["map"], &"zhuhai")
	assert_eq(wharf.trigger_at(Vector2i(23, 2))["spawn"], &"bridge")
	assert_gt(wharf.find_path(Vector2i(26, 14), Vector2i(22, 3)).size(), 0, "从街上走得到桥北头")
	var sea := _sea()
	assert_true(sea.combat, "竹海里能用武器和翻滚")
	assert_eq(sea.trigger_at(Vector2i(16, 41))["map"], &"wharf")
	assert_gt(sea.find_path(Vector2i(16, 23), Vector2i(8, 7)).size(), 0, "石径往西走得到乘黄跟前")
	assert_gt(sea.find_path(Vector2i(16, 23), Vector2i(9, 7)).size(), 0, "走得到酒碗跟前")
	assert_gt(sea.find_path(Vector2i(16, 23), Vector2i(26, 12)).size(), 0, "东边走到死路跟前")
	assert_eq(sea.solid[sea.idx(Vector2i(10, 14))], 1, "岔路外面的竹子挡着，绕不过去")
	assert_eq(sea.solid[sea.idx(Vector2i(16, 18))], 0, "溪上有踏脚的石头")
	assert_eq(sea.solid[sea.idx(Vector2i(10, 18))], 1, "旁边的溪过不去")
	assert_eq(sea.fishing_water(Vector2i(10, 18)), &"", "溪太浅，甩不了竿")
	assert_eq(sea.query_use(Database.item(&"rod"), Vector2i(10, 18), GameMap.Facing.DOWN), &"interact")


func test_the_sign_the_fox_and_the_bowl_by_day() -> void:
	var sea := _sea()
	assert_eq(sea.query_use(null, Vector2i(15, 11), GameMap.Facing.UP), &"interact")
	assert_string_contains(sea.clue_at(Vector2i(15, 11)), "往西")
	sea.perform(&"interact", null, Vector2i(15, 11))
	assert_true(Bestiary.heard(&"shanxiao"))
	assert_false(Bestiary.seen(&"shanxiao"), "白天只是听说，还没见着")
	sea.perform(&"interact", null, Vector2i(12, 12))
	assert_true(Bestiary.heard(&"chenghuang"))
	sea.perform(&"interact", null, Vector2i(7, 7))
	assert_true(Bestiary.seen(&"chenghuang"))
	assert_false(Bestiary.known(&"chenghuang"), "它还没跟着来")
	assert_string_contains(sea.clue_at(Vector2i(10, 7)), "酒香")
	assert_eq(sea.query_use(Database.item(&"old_sickle"), Vector2i(16, 20), GameMap.Facing.UP), &"attack")
	assert_eq(sea.apply_hit(6), -1, "白天没有山魈")
	var book := Journal.page_text(6)
	assert_string_contains(book, "山魈")
	assert_string_contains(book, "乘黄")
	assert_false(book.contains("散了"), "还没打散，不写全")


func test_fog_hides_the_sign_and_night_brings_the_shanxiao() -> void:
	var sea := _sea()
	Weather.today = Weather.FOG
	sea.perform(&"interact", null, Vector2i(15, 11))
	assert_false(Bestiary.heard(&"shanxiao"), "雾里看不清，不算听说")
	assert_string_contains(sea.clue_at(Vector2i(15, 11)), "看不清")
	Weather.today = Weather.SUNNY
	GameClock.minutes = 1200.0
	assert_true(sea.shanxiao_out())
	assert_eq(sea.query_use(null, Vector2i(22, 11), GameMap.Facing.UP), &"interact")
	var sickle := Database.item(&"old_sickle")
	assert_eq(sea.query_use(sickle, Vector2i(22, 11), GameMap.Facing.UP), &"attack", "拿着武器对着它是打")
	assert_eq(sea.apply_hit(6), 18)
	assert_true(Bestiary.seen(&"shanxiao"))
	assert_false(Bestiary.known(&"shanxiao"))
	assert_eq(sea.apply_hit(18), 0)
	assert_true(Bestiary.known(&"shanxiao"))
	assert_false(sea.shanxiao_out())
	assert_string_contains(Journal.page_text(6), "散了")


func test_wine_brings_the_xingxing_and_the_book_writes_the_story() -> void:
	var sea := _sea()
	assert_eq(sea.query_use(null, Vector2i(10, 7), GameMap.Facing.UP), &"interact")
	GameState.inventory.add(&"rice_wine", 1)
	assert_eq(sea.query_use(Database.item(&"rice_wine"), Vector2i(10, 7), GameMap.Facing.UP), &"offer")
	sea.perform(&"offer", Database.item(&"rice_wine"), Vector2i(10, 7))
	assert_eq(GameState.inventory.count_of(&"rice_wine"), 0, "酒喝掉了")
	assert_true(Bestiary.known(&"xingxing"))
	assert_string_contains(sea.clue_at(Vector2i(10, 7)), "不再开口")
	var book := Journal.page_text(6)
	assert_string_contains(book, "一截一截")
	assert_string_contains(book, "狌狌")
	var face := Bestiary.portrait(&"xingxing")
	assert_not_null(face)
	assert_gt(face.get_width(), 8)
	assert_null(Bestiary.portrait(&"shanxiao"), "没见过的不给画")


func test_seeing_the_fox_quickens_the_step_until_night() -> void:
	var sea := _sea()
	var who := Player.new()
	sea.entities.add_child(who)
	who.map = sea
	sea.player = who
	who.place(sea.tile_center(Vector2i(16, 23)), GameMap.Facing.UP)
	sea._apply_cheng_pace()
	assert_eq(who.slow, 1.0, "还没见过，不改步速")
	assert_eq(sea.chenghuang_pace(), 1.0, "还没见过，脚下不加快")
	assert_string_contains(sea.clue_at(Vector2i(7, 7)), "没跟着来")
	sea.perform(&"interact", null, Vector2i(7, 7))
	assert_true(Bestiary.seen(&"chenghuang"))
	assert_false(Bestiary.known(&"chenghuang"), "跟着走也不算问出来")
	assert_almost_eq(sea.chenghuang_pace(), 1.15, 0.001)
	sea._apply_cheng_pace()
	assert_almost_eq(who.slow, 1.15, 0.001, "白天把这一档写到人身上")
	assert_string_contains(sea.clue_at(Vector2i(7, 7)), "跟在后面")
	GameClock.minutes = 1200.0
	assert_eq(sea.chenghuang_pace(), 1.0, "夜里它不在，速度回到原来")
	sea._apply_cheng_pace()
	assert_eq(who.slow, 1.0, "天黑了还在竹海里，步速也收回")


func _sea() -> OutdoorMap:
	var scene: PackedScene = load(SceneRouter.MAPS[&"zhuhai"])
	var map: OutdoorMap = scene.instantiate()
	add_child_autofree(map)
	return map


func _outdoor(id: StringName) -> OutdoorMap:
	var scene: PackedScene = load(SceneRouter.MAPS[id])
	var map: OutdoorMap = scene.instantiate()
	add_child_autofree(map)
	return map
