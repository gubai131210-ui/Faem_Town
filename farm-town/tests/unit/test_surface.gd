extends GutTest
## M9 第一批：水往哪流、雨后的水洼、摇幅、下雨和海浪的循环声。


func before_each() -> void:
	SaveSystem.reset_all()
	GameClock.day = 2
	GameClock.minutes = 360.0
	Weather.today = Weather.SUNNY
	Weather.tomorrow = Weather.SUNNY
	Weather.yesterday = Weather.SUNNY
	Weather.wet = 0.0
	Weather._noted = -1


func after_each() -> void:
	SaveSystem.reset_all()


func test_each_water_drifts_its_own_way() -> void:
	assert_eq(Surface.flow_of(&"stream"), Vector2(1, 0.6))
	assert_eq(Surface.flow_of(&"river"), Vector2(1, 0))
	assert_eq(Surface.flow_of(&"sea"), Vector2(0.7, 0))
	assert_eq(Surface.flow_of(&"pond"), Vector2.ZERO)
	var early := Surface.drift(&"stream", 0.1)
	var later := Surface.drift(&"stream", 0.5)
	assert_gt(later.x, early.x, "溪水的波光往下游走")
	assert_gt(later.y, early.y)
	assert_eq(Surface.drift(&"pond", 0.4).y, 0.0, "池塘只在原地拉长")


func test_the_shore_line_and_the_sway_follow_the_weather() -> void:
	var hi := -99.0
	var lo := 99.0
	for i in 40:
		var s := Surface.wave_shift(i * 0.2)
		hi = maxf(hi, s)
		lo = minf(lo, s)
	assert_eq(hi, 2.0, "浪线最多往下两像素")
	assert_eq(lo, -2.0, "浪线最多往上两像素")
	var calm := Surface.sway_amp(&"sunny", 1.5)
	assert_gt(Surface.sway_amp(&"wind", 1.5), calm)
	assert_gt(calm, Surface.sway_amp(&"snow", 1.5))
	assert_eq(Surface.sway_amp(&"cloudy", 1.2), 1.2)


func test_rain_fills_the_road_and_a_dry_day_empties_it() -> void:
	var soaked := Surface.soak(0.0, 360, 480, true)
	assert_almost_eq(soaked.x, 1.0, 0.01, "下两个小时积满")
	var dried := Surface.soak(soaked.x, int(soaked.y), 660, false)
	assert_almost_eq(dried.x, 0.0, 0.01, "再过三个小时干完")
	assert_eq(Surface.puddle_alpha(0.2), 0.0)
	assert_gt(Surface.puddle_alpha(1.0), 0.5)
	var held := Surface.soak(0.8, 1500, 360, false)
	assert_almost_eq(held.x, 0.8, 0.001, "时间往回拨只重新对齐，不拿来晾干")
	assert_eq(int(held.y), 360)


func test_the_morning_after_rain_starts_wet() -> void:
	Weather.today = Weather.RAIN
	Weather.tomorrow = Weather.SUNNY
	Weather.wet = 0.2
	Weather._on_new_day()
	assert_eq(Weather.yesterday, Weather.RAIN)
	assert_eq(Weather.today, Weather.SUNNY)
	assert_almost_eq(Weather.wet, 1.0, 0.001)
	Weather.today = Weather.RAIN
	Weather.tomorrow = Weather.STORM
	Weather.wet = 0.4
	Weather._on_new_day()
	assert_almost_eq(Weather.wet, 0.4, 0.001, "第二天还在下，水洼接着昨天的")


func test_an_old_save_without_wetness_still_has_morning_puddles() -> void:
	Weather.load_data({"today": "sunny", "tomorrow": "cloudy", "yesterday": "rain", "rng": "1"})
	assert_almost_eq(Weather.wet, 1.0, 0.001)
	Weather.load_data({"today": "sunny", "tomorrow": "sunny", "yesterday": "sunny", "wet": 0.4, "rng": "1"})
	assert_almost_eq(Weather.wet, 0.4, 0.001)


func test_rain_and_waves_are_loops() -> void:
	assert_true(Audio.has_sound("rain"))
	assert_true(Audio.has_sound("waves"))
	var rain: AudioStreamWAV = Audio.get("_streams")["rain"]
	var waves: AudioStreamWAV = Audio.get("_streams")["waves"]
	assert_eq(rain.loop_mode, AudioStreamWAV.LOOP_FORWARD)
	assert_eq(waves.loop_mode, AudioStreamWAV.LOOP_FORWARD)
	assert_gt(rain.data.size(), 1000)
	assert_gt(waves.data.size(), 1000)


func test_still_water_sparkles_stay_in_place() -> void:
	# 回归：原来的 drift 给池塘算了 roundf(t*6) 的横向位移，注释却写"只在原地闪"。
	assert_eq(Surface.drift(&"pond", 0.4), Vector2.ZERO, "池塘的波光不往右跑")
	assert_eq(Surface.drift(&"mine_shallow", 0.7), Vector2.ZERO, "井里的静水也不跑")


func test_sparkles_travel_and_loop_without_a_jump() -> void:
	var early := Surface.drift(&"river", 0.1)
	var late := Surface.drift(&"river", 0.9)
	assert_gt(late.x - early.x, 8.0, "一整轮要走开足够远，看得出顺流")
	assert_lt(Surface.grow(0.0), 0.05, "循环接缝处是看不见的")
	assert_lt(Surface.grow(1.0), 0.05, "回到起点时也看不见，才不会跳")
	assert_gt(Surface.grow(0.5), 0.9, "中间最亮")


func test_the_wave_line_has_a_shape_along_the_shore() -> void:
	# 回归：原来整条浪线只上下平移，看起来是一根直棍。
	var a := Surface.wave_at(0.0, 0.0)
	var b := Surface.wave_at(12.0, 0.0)
	assert_ne(a, b, "同一时刻岸线不同位置的高度不一样")
	assert_true(absf(a) <= 2.0 and absf(b) <= 2.0)
	assert_ne(Surface.wave_at(12.0, 0.0), Surface.wave_at(12.0, 1.0), "浪在推进")


func test_preview_is_big_enough_and_the_frames_differ() -> void:
	var img := Surface.preview()
	assert_gte(img.get_width(), 480, "四帧要能看清，不是一条 160 像素的色带")
	assert_gte(img.get_height(), 64)
	var first := img.get_region(Rect2i(0, 0, 120, img.get_height())).get_data()
	var last := img.get_region(Rect2i(360, 0, 120, img.get_height())).get_data()
	assert_ne(first, last, "四帧不能长得一样")
