extends GutTest
## 各处能翻能看的东西（决策 125）。灯亮以后多出来的纸、木牌和画角。
## 不发明人名，匾上不加字。桥的北头进竹海（决策 126）。


const FULL_NAMES: Array[String] = [
	"姜婆婆", "小满", "柏先生", "阿禾", "石叔", "青竹", "云娘", "老周", "阿牧",
	"老秦", "陆远", "白鹭", "说书人", "酱园掌柜", "货郎", "船娘", "庙祝", "山里人", "岚",
]


func before_each() -> void:
	SaveSystem.base_dir = "user://test_saves_place_clues"
	SaveSystem.reset_all()


func test_plaza_clues_stay_hidden_until_the_lamp() -> void:
	var town := _outdoor(&"town")
	assert_eq(town.query_use(null, Vector2i(33, 7), GameMap.Facing.RIGHT), &"", "灯没亮，后巷告示不在")
	assert_eq(town.query_use(null, Vector2i(24, 17), GameMap.Facing.UP), &"", "灯没亮，戏台边的纸不在")
	_open(town, Vector2i(33, 7))
	_open(town, Vector2i(24, 17))


func test_plaza_clues_can_be_read_without_names() -> void:
	GameState.set_flag(&"lamp_plaza")
	var town := _outdoor(&"town")
	assert_eq(town.query_use(null, Vector2i(33, 7), GameMap.Facing.RIGHT), &"interact")
	assert_eq(town.query_use(null, Vector2i(24, 17), GameMap.Facing.UP), &"interact")
	assert_eq(town.query_use(null, Vector2i(16, 14), GameMap.Facing.UP), &"interact", "井台还是看看")
	assert_eq(town.query_use(null, Vector2i(26, 16), GameMap.Facing.UP), &"interact", "戏台还是看看")
	_no_names(town.clue_at(Vector2i(33, 7)))
	_no_names(town.clue_at(Vector2i(24, 17)))
	assert_string_contains(town.clue_at(Vector2i(33, 7)), "告示")
	assert_string_contains(town.clue_at(Vector2i(24, 17)), "名字那一行空着")
	town.perform(&"interact", null, Vector2i(33, 7))
	town.perform(&"interact", null, Vector2i(24, 17))
	assert_true(GameState.has_flag(&"read_alley_notice"))
	assert_true(GameState.has_flag(&"read_stage_book"))
	assert_gt(town.find_path(Vector2i(31, 9), Vector2i(32, 7)).size(), 0, "后巷还走得到告示跟前")
	assert_gt(town.find_path(Vector2i(31, 9), Vector2i(16, 3)).size(), 0, "巷子仍然通到后街")
	assert_gt(town.find_path(Vector2i(16, 16), Vector2i(23, 17)).size(), 0, "戏台边的纸旁边站得了人")
	_open(town, Vector2i(24, 18))
	_open(town, Vector2i(25, 16))
	_open(town, Vector2i(27, 17))
	_open(town, Vector2i(28, 17))


func test_soy_slip_and_the_bridge_into_the_bamboo() -> void:
	var wharf := _outdoor(&"wharf")
	assert_eq(wharf.query_use(null, Vector2i(13, 13), GameMap.Facing.UP), &"interact")
	assert_eq(wharf.query_use(null, Vector2i(4, 12), GameMap.Facing.UP), &"interact", "木匠铺的门还在")
	var bridge: String = wharf._look(Vector2i(22, 5))
	assert_string_contains(bridge, "竹海")
	assert_false(bridge.contains("雾还没退"), "桥已经接到竹海")
	assert_eq(wharf.trigger_at(Vector2i(22, 5)), {}, "桥中间还不换地图")
	assert_eq(wharf.trigger_at(Vector2i(22, 2))["map"], &"zhuhai", "桥北头进竹海")
	_no_names(wharf.clue_at(Vector2i(13, 13)))
	assert_string_contains(wharf.clue_at(Vector2i(13, 13)), "年份")
	wharf.perform(&"interact", null, Vector2i(13, 13))
	assert_true(GameState.has_flag(&"read_soy_slip"))
	_open(wharf, Vector2i(11, 13))
	assert_gt(wharf.find_path(Vector2i(26, 14), Vector2i(13, 14)).size(), 0, "从东口走得到这张纸跟前")


func test_mill_tally_leaves_the_peddler_and_the_path() -> void:
	var pasture := _outdoor(&"pasture")
	assert_eq(pasture.query_use(null, Vector2i(5, 11), GameMap.Facing.UP), &"interact")
	assert_string_contains(pasture._returned_text(Vector2i(2, 11)), "老磨坊")
	assert_string_contains(pasture._returned_text(Vector2i(18, 12)), "土地庙")
	_no_names(pasture.clue_at(Vector2i(5, 11)))
	assert_string_contains(pasture.clue_at(Vector2i(5, 11)), "记到一半")
	pasture.perform(&"interact", null, Vector2i(5, 11))
	assert_true(GameState.has_flag(&"read_mill_tally"))
	_open(pasture, Vector2i(2, 12))
	_open(pasture, Vector2i(13, 13))
	assert_gt(pasture.find_path(Vector2i(42, 14), Vector2i(5, 12)).size(), 0, "从镇口走得到木牌跟前")


func test_studio_corner_shows_the_lighthouse() -> void:
	var beach := _outdoor(&"dongtan")
	assert_eq(beach.query_use(null, Vector2i(15, 9), GameMap.Facing.LEFT), &"interact")
	var text: String = beach.clue_at(Vector2i(15, 9))
	assert_string_contains(text, "灯塔")
	assert_string_contains(text, "海")
	_no_names(text)
	beach.perform(&"interact", null, Vector2i(15, 9))
	assert_true(GameState.has_flag(&"read_egret_corner"))
	_open(beach, Vector2i(13, 11))
	assert_gt(beach.find_path(Vector2i(1, 14), Vector2i(15, 10)).size(), 0, "从路口走得到画角跟前")


func test_school_paper_does_not_write_the_plaques() -> void:
	var hill := _outdoor(&"shanci")
	assert_eq(hill.query_use(null, Vector2i(33, 8), GameMap.Facing.UP), &"interact")
	var paper: String = hill.clue_at(Vector2i(33, 8))
	assert_string_contains(paper, "一个字也没写")
	assert_false(paper.contains("青岚"), "这张纸不补匾上的字")
	_no_names(paper)
	watch_signals(EventBus)
	hill.perform(&"interact", null, Vector2i(30, 8))
	var school: Array = get_signal_parameters(EventBus, "banner_requested")
	assert_string_contains(str(school), "一个字也没有")
	hill.perform(&"interact", null, Vector2i(20, 16))
	var gate: Array = get_signal_parameters(EventBus, "banner_requested", 1)
	assert_string_contains(str(gate), "匾是空的")
	assert_false(str(gate).contains("青岚"))
	hill.perform(&"interact", null, Vector2i(33, 8))
	assert_true(GameState.has_flag(&"read_school_paper"))
	_open(hill, Vector2i(30, 9))
	assert_gt(hill.find_path(Vector2i(21, 28), Vector2i(33, 9)).size(), 0, "从石阶走得到这张纸跟前")


func test_cabinet_and_drawer_are_separate_from_the_old_lines() -> void:
	var tea := _indoor(&"teahouse")
	assert_eq(tea.query_use(null, Vector2i(24, 2), GameMap.Facing.UP), &"interact")
	assert_eq(tea.query_use(null, Vector2i(3, 7), GameMap.Facing.UP), &"interact", "茶桌还是看看")
	tea.perform(&"interact", null, Vector2i(24, 2))
	assert_true(GameState.has_flag(&"read_tea_cabinet"))
	watch_signals(EventBus)
	tea.perform(&"interact", null, Vector2i(3, 7))
	var cups: Array = get_signal_parameters(EventBus, "banner_requested")
	assert_string_contains(str(cups), "空杯")
	var herb := _indoor(&"herbshop")
	herb.perform(&"interact", null, Vector2i(2, 1))
	assert_true(GameState.has_flag(&"read_herb_slip"))
	herb.perform(&"interact", null, Vector2i(6, 1))
	var drawer: Array = get_signal_parameters(EventBus, "banner_requested", 2)
	assert_string_contains(str(drawer), "发苦")
	assert_false(str(drawer).contains("方子"))


func test_clue_pictures_are_painted() -> void:
	for img: Image in [PlaceClueArt.slip(), PlaceClueArt.booklet(), PlaceClueArt.tally(), PlaceClueArt.canvas()]:
		assert_gt(img.get_width(), 8)
		assert_gt(img.get_height(), 8)
		var painted := 0
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a < 0.5:
					continue
				painted += 1
				assert_false(c.r > 0.9 and c.g < 0.1 and c.b > 0.9, "不该画出调色板里没有的品红")
		assert_gt(painted, 20, "图不能是空的")


func _open(map: OutdoorMap, t: Vector2i) -> void:
	assert_eq(map.solid[map.idx(t)], 0, "%s 不该被新东西挡住" % t)


func _no_names(text: String) -> void:
	for full: String in FULL_NAMES:
		assert_false(text.contains(full), "不该写出 %s：%s" % [full, text])


func _outdoor(id: StringName) -> OutdoorMap:
	var scene: PackedScene = load(SceneRouter.MAPS[id])
	var map: OutdoorMap = scene.instantiate()
	add_child_autofree(map)
	return map


func _indoor(id: StringName) -> GameMap:
	var scene: PackedScene = load(SceneRouter.MAPS[id])
	var map: GameMap = scene.instantiate()
	add_child_autofree(map)
	return map
