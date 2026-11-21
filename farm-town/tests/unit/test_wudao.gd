extends GutTest
## 雾岛：东滩的船，潮水开合潮洞，精卫、鲛人、文鳐（决策 128）。


var _banners: Array[String] = []


func before_each() -> void:
	SaveSystem.base_dir = "user://test_saves_wudao"
	SaveSystem.reset_all()
	GameClock.day = 10
	GameClock.minutes = 600.0
	Weather.today = Weather.SUNNY
	_banners.clear()
	EventBus.banner_requested.connect(_on_banner)


func after_each() -> void:
	if EventBus.banner_requested.is_connected(_on_banner):
		EventBus.banner_requested.disconnect(_on_banner)


func _on_banner(text: String) -> void:
	_banners.append(text)


func test_the_boat_leaves_at_low_tide_and_the_cave_closes_after_noon() -> void:
	var beach := _outdoor(&"dongtan")
	assert_true(beach.departure(beach.boat_tile()).is_empty(), "灯没亮，船不出海")
	beach.perform(&"interact", null, beach.boat_tile())
	assert_string_contains(_banners[-1], "灯")
	GameState.set_flag(Database.lamp(&"east").flag())
	assert_eq(beach.departure(beach.boat_tile())["map"], &"wudao")
	var back: Vector2 = beach.spawn_position(&"from_wudao")
	assert_eq(beach.tile_of(back), beach.boat_stand(), "下船站在岸上")
	assert_ne(beach.tile_of(back), beach.boat_tile())
	assert_false(beach.blocked(back))
	assert_eq(beach.spawn_facing(&"from_wudao"), GameMap.Facing.LEFT)
	var isle := _outdoor(&"wudao")
	assert_true(isle.combat)
	assert_eq(isle.trigger_at(Vector2i(16, 41))["map"], &"dongtan")
	assert_true(isle.low_tide())
	assert_gt(isle.find_path(Vector2i(16, 22), Vector2i(8, 12)).size(), 0, "早上沙露着，走得到洞口")
	assert_string_contains(isle.clue_at(Vector2i(15, 16)), "潮")
	assert_true(isle.jiao_out())
	assert_false(isle.wen_out())
	GameClock.minutes = 800.0
	var noon := _outdoor(&"wudao")
	assert_false(noon.low_tide())
	assert_eq(noon.find_path(Vector2i(16, 22), Vector2i(8, 12)).size(), 0, "午后涨潮，过不去")
	assert_string_contains(noon.clue_at(Vector2i(9, 12)), "没过")
	assert_false(noon.jiao_out())
	assert_eq(noon.fishing_water(Vector2i(4, 4)), &"")


func test_helping_the_bird_the_shell_and_the_night_fish() -> void:
	var beach := _outdoor(&"dongtan")
	beach.perform(&"interact", null, Vector2i(29, 11))
	assert_true(Bestiary.heard(&"jingwei"))
	assert_string_contains(_banners[-1], "鸟")
	var isle := _outdoor(&"wudao")
	assert_true(isle.jing_out())
	assert_eq(isle.query_use(Database.item(&"old_sickle"), Vector2i(16, 20), GameMap.Facing.UP), &"attack")
	assert_eq(isle.query_use(Database.item(&"old_sickle"), Vector2i(15, 16), GameMap.Facing.UP), &"interact")
	isle.perform(&"interact", null, Vector2i(17, 9))
	assert_true(Bestiary.known(&"jingwei"))
	assert_string_contains(Bestiary.line(&"jingwei"), "傍晚")
	GameClock.minutes = 900.0
	var late := _outdoor(&"wudao")
	assert_true(late.low_tide(), "帮过以后，下午还退着")
	assert_gt(late.find_path(Vector2i(16, 22), Vector2i(8, 12)).size(), 0)
	assert_false(late.jing_out())
	GameClock.minutes = 1100.0
	var dusk := _outdoor(&"wudao")
	assert_false(dusk.low_tide(), "傍晚还是涨")
	GameClock.minutes = 600.0
	var cave := _outdoor(&"wudao")
	var shell := Database.item(&"conch")
	assert_eq(cave.query_use(null, Vector2i(7, 12), GameMap.Facing.RIGHT), &"interact")
	assert_string_contains(cave.clue_at(Vector2i(7, 12)), "海螺")
	assert_false(Bestiary.known(&"jiaoren"))
	GameState.inventory.add(&"conch")
	assert_eq(cave.query_use(shell, Vector2i(7, 12), GameMap.Facing.RIGHT), &"offer")
	cave.perform(&"offer", shell, Vector2i(7, 12))
	assert_eq(GameState.inventory.count_of(&"conch"), 0)
	assert_true(Bestiary.known(&"jiaoren"))
	assert_string_contains(Bestiary.line(&"jiaoren"), "珠")
	assert_eq(cave.clue_at(Vector2i(21, 11)), "", "白天没有文鳐")
	GameClock.minutes = 1200.0
	var night := _outdoor(&"wudao")
	assert_true(night.wen_out())
	assert_string_contains(night.clue_at(Vector2i(21, 11)), "文鳐")
	night.perform(&"interact", null, Vector2i(21, 11))
	assert_string_contains(Bestiary.line(&"wenyao"), "年成")
	var face := Bestiary.portrait(&"jingwei")
	assert_not_null(face)
	assert_gt(face.get_width(), 8)
	assert_null(Bestiary.portrait(&"shanxiao"), "没见过的不给画")


func _outdoor(id: StringName) -> OutdoorMap:
	var scene: PackedScene = load(SceneRouter.MAPS[id])
	var map: OutdoorMap = scene.instantiate()
	add_child_autofree(map)
	return map
