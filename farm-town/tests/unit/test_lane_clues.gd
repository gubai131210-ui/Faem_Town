extends GutTest
## 矿工巷「能翻能看」：井口碑、墙上旧告示、从门口望见的屋内线索（决策 119）。
## 硬约束：门牌空白、屋内不进、不发明那 27 个名字，只剩「秦」。

const STELE_TILE := Vector2i(12, 10)
const NOTICE_TILE := Vector2i(5, 6)
const HOUSE_FRONTS: Array[Vector2i] = [
	Vector2i(3, 6), Vector2i(7, 6), Vector2i(11, 6), Vector2i(15, 6),
]
## 不写进碑和告示的人名。老秦只留一个「秦」字，不算人名。
const FULL_NAMES: Array[String] = [
	"姜婆婆", "小满", "柏先生", "阿禾", "石叔", "青竹", "云娘", "老周", "阿牧",
	"老秦", "陆远", "白鹭", "说书人", "酱园掌柜", "货郎", "船娘", "庙祝", "山里人",
]


func before_each() -> void:
	SaveSystem.base_dir = "user://test_saves_lane_clues"
	SaveSystem.reset_all()


func test_all_clue_spots_can_be_queried() -> void:
	var lane := _lane()
	assert_eq(lane.query_use(null, STELE_TILE, GameMap.Facing.UP), &"interact", "巷口的碑能翻")
	assert_eq(lane.query_use(null, NOTICE_TILE, GameMap.Facing.UP), &"interact", "墙上的旧告示能翻")
	for tile: Vector2i in HOUSE_FRONTS:
		assert_eq(lane.query_use(null, tile, GameMap.Facing.UP), &"interact", "屋前 %s 能望进去" % tile)
	assert_eq(lane.query_use(null, Vector2i(20, 12), GameMap.Facing.UP), &"", "空地没有线索")


func test_reading_a_clue_is_remembered_and_announced() -> void:
	var lane := _lane()
	watch_signals(EventBus)
	lane.perform(&"interact", null, STELE_TILE)
	assert_true(GameState.has_flag(&"read_miner_stele"), "碑看过要记下")
	assert_signal_emitted(EventBus, "banner_requested")
	lane.perform(&"interact", null, NOTICE_TILE)
	assert_true(GameState.has_flag(&"read_miner_notice"), "告示看过要记下")
	lane.perform(&"interact", null, HOUSE_FRONTS[0])
	assert_true(GameState.has_flag(&"read_miner_house_0"), "第一间屋看过要记下")


func test_stele_keeps_only_the_name_qin() -> void:
	var lane := _lane()
	var text: String = lane.clue_at(STELE_TILE)
	assert_string_contains(text, "秦", "碑上只剩一个秦字")
	assert_string_contains(text, "二十七", "碑记着没能上来的人")
	for full: String in FULL_NAMES:
		assert_false(text.contains(full), "碑上不该写出全名 %s" % full)


func test_notice_has_no_recoverable_signature() -> void:
	var lane := _lane()
	var text: String = lane.clue_at(NOTICE_TILE)
	assert_string_contains(text, "告示", "写的是旧告示")
	for full: String in FULL_NAMES:
		assert_false(text.contains(full), "告示的签名不该认得出 %s" % full)


func test_house_clues_show_daily_leftovers_without_names() -> void:
	var lane := _lane()
	const LEFTOVERS: Array[String] = ["碗", "木箱", "茶杯", "窗纸"]
	for i in HOUSE_FRONTS.size():
		var text: String = lane.clue_at(HOUSE_FRONTS[i])
		assert_string_contains(text, LEFTOVERS[i], "第 %d 间屋望进去有具体旧物" % (i + 1))
		assert_false(text.contains("的名字叫"), "不给人起名")
		for full: String in FULL_NAMES:
			assert_false(text.contains(full), "第 %d 间屋不该写出全名 %s" % [i + 1, full])


func test_houses_still_cannot_be_entered() -> void:
	var lane := _lane()
	for tile: Vector2i in [Vector2i(3, 5), Vector2i(7, 5), Vector2i(11, 5), Vector2i(15, 5)]:
		assert_eq(lane.trigger_at(tile), {}, "屋子还是进不去 %s" % tile)


func test_every_clue_can_be_reached_from_the_east_entrance() -> void:
	var lane := _lane()
	var from := GameMap.tile_of(lane.spawn_position(&"from_wellhead"))
	var stands: Array[Vector2i] = [
		Vector2i(12, 9), Vector2i(5, 7),
		Vector2i(3, 7), Vector2i(7, 7), Vector2i(11, 7), Vector2i(15, 7),
	]
	for stand: Vector2i in stands:
		assert_gt(lane.find_path(from, stand).size(), 0, "从东边走得到 %s" % stand)
	assert_true(lane.blocked(lane.tile_center(STELE_TILE)), "碑自己那格挡着")
	assert_true(lane.blocked(lane.tile_center(NOTICE_TILE)), "告示那格挡着")


func _lane() -> OutdoorMap:
	var scene: PackedScene = load(SceneRouter.MAPS[&"lane"])
	var m: OutdoorMap = scene.instantiate()
	add_child_autofree(m)
	return m
