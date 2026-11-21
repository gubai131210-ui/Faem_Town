extends GutTest
## 见过文鳐以后，逢三的夜里飞到农场池塘上。不养、不结缘、不加收成。


const POND := Vector2i(33, 17)
const OTHER_POND := Vector2i(32, 17)
const STREAM := Vector2i(46, 10)

var _banners: Array[String] = []


func before_each() -> void:
	SaveSystem.base_dir = "user://test_saves_wenyao_pond"
	SaveSystem.reset_all()
	GameClock.day = 3
	GameClock.minutes = 600.0
	Weather.today = Weather.SUNNY
	_banners.clear()
	EventBus.banner_requested.connect(_on_banner)


func after_each() -> void:
	if EventBus.banner_requested.is_connected(_on_banner):
		EventBus.banner_requested.disconnect(_on_banner)
	SaveSystem.base_dir = "user://saves"
	SaveSystem.reset_all()


func _on_banner(text: String) -> void:
	_banners.append(text)


func test_wenyao_out_only_after_seen_on_a_third_night() -> void:
	var farm := _farm()
	GameClock.minutes = 1200.0
	assert_false(Bestiary.seen(&"wenyao"))
	assert_false(farm.wenyao_out(), "没见过，夜里也不来")
	Bestiary.hear(&"wenyao")
	assert_false(farm.wenyao_out(), "只听说过还不算见过")
	Bestiary.see(&"wenyao")
	assert_true(farm.wenyao_out(), "见过，天数能被 3 整除，夜里来")
	GameClock.minutes = 600.0
	assert_eq(GameClock.day, 3)
	assert_false(farm.wenyao_out(), "同一天白天不来")
	GameClock.minutes = 1200.0
	GameClock.day = 4
	assert_false(farm.wenyao_out(), "不是逢三的夜里不来")


func test_wenyao_night_reaches_before_dawn_and_follows_the_solstice() -> void:
	Bestiary.see(&"wenyao")
	var farm := _farm()
	GameClock.minutes = 1139.0
	assert_false(farm.wenyao_out(), "差一分钟还没黑")
	GameClock.minutes = 1140.0
	assert_true(farm.wenyao_out(), "十九点整入夜")
	GameClock.minutes = 1500.0
	assert_true(farm.wenyao_out(), "过了午夜，钟点还在天亮以前")
	GameClock.minutes = GameClock.DAY_START
	assert_false(farm.wenyao_out(), "六点天亮，白天不来")
	GameClock.minutes = GameClock.DAY_START - 1.0
	assert_true(farm.wenyao_out(), "天亮前一分钟还算夜里")
	GameClock.day = 39
	assert_eq(GameClock.term_id(), &"xiazhi")
	assert_eq(GameClock.dusk_shift(), GameClock.SOLSTICE_SHIFT)
	GameClock.minutes = 1140.0 + GameClock.SOLSTICE_SHIFT - 1.0
	assert_false(farm.wenyao_out(), "夏至天黑推迟")
	GameClock.minutes = 1140.0 + GameClock.SOLSTICE_SHIFT
	assert_true(farm.wenyao_out())
	GameClock.day = 87
	assert_eq(GameClock.term_id(), &"dongzhi")
	assert_eq(GameClock.dusk_shift(), -GameClock.SOLSTICE_SHIFT)
	GameClock.minutes = 1140.0 - GameClock.SOLSTICE_SHIFT - 1.0
	assert_false(farm.wenyao_out(), "冬至提前那一分钟还没黑")
	GameClock.minutes = 1140.0 - GameClock.SOLSTICE_SHIFT
	assert_true(farm.wenyao_out(), "冬至天黑提前")


func test_wenyao_sprite_stays_over_the_pond_and_leaves_the_rod() -> void:
	Bestiary.see(&"wenyao")
	GameClock.minutes = 1200.0
	var farm := _farm()
	var spr := _wenyao_sprite(farm)
	var sheet := CharacterSheet.load_sheet("wenyao", CharacterSheet.CREATURE_DIR)
	var right := sheet.region(&"flap", GameMap.Facing.RIGHT, 0)
	assert_eq(_wenyao_count(farm), 1)
	assert_not_null(spr)
	assert_eq(spr.get_parent(), farm.entities)
	assert_eq(GameMap.tile_of(spr.position), POND)
	assert_eq(spr.position, GameMap.tile_center(POND) + Vector2(0, 4))
	assert_eq(spr.offset, Vector2(-sheet.cell / 2.0, -float(sheet.foot_row)))
	assert_false(spr.centered)
	assert_true(spr.region_enabled)
	assert_eq(spr.texture, sheet.texture)
	assert_eq(spr.region_rect.position.y, right.position.y)
	assert_eq(spr.region_rect.size, right.size)
	assert_eq(str(spr.get_meta(&"anim")), "flap")
	assert_eq(int(spr.get_meta(&"face")), GameMap.Facing.RIGHT)
	assert_eq(farm.fishing_water(POND), &"pond")
	assert_eq(farm.solid[farm.idx(POND)], 1)
	assert_false(farm.occupied.has(POND))
	var rod := Database.item(&"rod")
	var trap := Database.item(Fishing.TRAP_ID)
	assert_eq(farm.query_use(rod, POND, GameMap.Facing.RIGHT), &"cast")
	assert_eq(farm.query_use(trap, POND, GameMap.Facing.RIGHT), &"place_trap")
	Fishing.place_trap(&"farm", POND, &"pond")
	assert_eq(farm.query_use(null, POND, GameMap.Facing.DOWN), &"interact")
	_banners.clear()
	farm.perform(&"interact", null, POND)
	assert_false(Fishing.has_trap(&"farm", POND), "格子上有蟹笼时，这一下是收笼子")
	assert_eq(_banners.size(), 0)
	assert_eq(farm.fishing_water(OTHER_POND), &"pond")
	assert_eq(farm.query_use(null, OTHER_POND, GameMap.Facing.RIGHT), &"")
	assert_eq(farm.fishing_water(STREAM), &"stream")
	assert_eq(farm.query_use(null, STREAM, GameMap.Facing.RIGHT), &"")
	assert_eq(farm.query_use(null, POND, GameMap.Facing.DOWN), &"interact")
	_banners.clear()
	farm.perform(&"interact", null, POND)
	assert_eq(_banners.size(), 1)
	assert_eq(_banners[0], "文鳐贴着池塘飞。翅膀是白的。")
	GameClock.minutes = 600.0
	farm.call(&"_sync_wenyao")
	assert_false(farm.wenyao_out())
	assert_null(farm.get(&"_wenyao"))
	assert_true(spr.is_queued_for_deletion())
	assert_eq(_wenyao_count(farm), 0)
	assert_eq(farm.query_use(null, POND, GameMap.Facing.DOWN), &"")


func _farm() -> OutdoorMap:
	var scene: PackedScene = load(SceneRouter.MAPS[&"farm"])
	var map: OutdoorMap = scene.instantiate()
	add_child_autofree(map)
	return map


func _wenyao_sprite(map: OutdoorMap) -> Sprite2D:
	for child in map.entities.get_children():
		var spr := child as Sprite2D
		if spr == null or not spr.has_meta(&"who"):
			continue
		var who: String = str(spr.get_meta(&"who"))
		if who == "wenyao":
			return spr
	return null


func _wenyao_count(map: OutdoorMap) -> int:
	var found := 0
	for child in map.entities.get_children():
		var spr := child as Sprite2D
		if spr == null or spr.is_queued_for_deletion() or not spr.has_meta(&"who"):
			continue
		var who: String = str(spr.get_meta(&"who"))
		if who == "wenyao":
			found += 1
	return found
