extends GutTest
## M9 第二批：灯的亮度、窗户、做饭的烟、铁匠铺的火星、灯塔光柱、夏天的萤火虫。


func test_lights_only_change_brightness() -> void:
	var lo := 2.0
	var hi := 0.0
	for i in 40:
		var v := Glow.flicker(i * 0.15, 0.4)
		lo = minf(lo, v)
		hi = maxf(hi, v)
		assert_gte(v, Glow.FLICKER_LO)
		assert_lte(v, Glow.FLICKER_HI)
	assert_gt(hi - lo, 0.1, "会晃，不是一直一个亮度")


func test_windows_light_one_after_another() -> void:
	assert_eq(Glow.window_alpha(0, 1000.0), 0.0, "五点以前是黑的")
	assert_gt(Glow.window_alpha(0, 1030.0), 0.4)
	assert_eq(Glow.window_alpha(1, 1025.0), 0.0, "第二扇还没到点")
	assert_almost_eq(Glow.window_alpha(0, 1200.0), 1.0, 0.001)
	assert_almost_eq(Glow.window_alpha(2, 1200.0), 1.0, 0.001)


func test_cooking_hours_and_the_forge() -> void:
	assert_true(Glow.cooking(450.0), "七点半在做早饭")
	assert_false(Glow.cooking(600.0))
	assert_true(Glow.cooking(720.0), "中午")
	assert_true(Glow.cooking(1100.0), "傍晚做饭")
	assert_true(Glow.forge(540.0), "九点炉子开着")
	assert_false(Glow.forge(450.0), "八点以前还没开工")
	assert_false(Glow.forge(1060.0), "五点半以后收工")


func test_summer_evening_fireflies_and_the_beam() -> void:
	assert_eq(Glow.firefly_count(0, 1200.0), 0, "春天没有")
	assert_eq(Glow.firefly_count(1, 1000.0), 0, "夏天傍晚以前没有")
	assert_eq(Glow.firefly_count(1, 1200.0), Glow.FLY_COUNT)
	assert_eq(Glow.firefly_count(1, 1400.0), 0, "十点以后歇了")
	var a := Glow.beam_angle(0.0)
	var b := Glow.beam_angle(4.0)
	assert_gt(b, a)
	assert_eq(Glow.beam_points().size(), 3)
	assert_gt(Glow.window_image().get_pixel(2, 2).a, 0.9)


func test_flicker_is_not_a_single_mechanical_sine() -> void:
	# 回归：原来是严格周期的正弦，所有灯只差相位，看着像机器在闪。
	var turns := 0
	var prev := Glow.flicker(0.02, 0.4) - Glow.flicker(0.0, 0.4)
	for i in range(1, 100):
		var d := Glow.flicker(float(i + 1) * 0.02, 0.4) - Glow.flicker(float(i) * 0.02, 0.4)
		if d * prev < 0.0:
			turns += 1
		prev = d
	assert_gt(turns, 2, "两秒内至少有三次起伏，不是一条正弦")
	for i in 40:
		var v := Glow.flicker(i * 0.15, 0.4)
		assert_gte(v, Glow.FLICKER_LO)
		assert_lte(v, Glow.FLICKER_HI)


func test_fireflies_fade_in_and_out_instead_of_popping() -> void:
	assert_lt(Glow.firefly_count(1, 1140.0), Glow.FLY_COUNT, "七点整先只来一部分")
	assert_eq(Glow.firefly_count(1, 1200.0), Glow.FLY_COUNT)
	assert_lt(Glow.firefly_alpha(1140.0), 0.2, "刚入夜还是暗的")
	assert_gt(Glow.firefly_alpha(1200.0), 0.9, "八点亮透")
	assert_lt(Glow.firefly_alpha(1320.0), 0.2, "十点收干净")


func test_preview_is_big_enough_and_the_frames_differ() -> void:
	var img := Glow.preview()
	assert_gte(img.get_width(), 480, "四帧要能看清，不是一条 160 像素的色带")
	assert_gte(img.get_height(), 64)
	var first := img.get_region(Rect2i(0, 0, 120, img.get_height())).get_data()
	var last := img.get_region(Rect2i(360, 0, 120, img.get_height())).get_data()
	assert_ne(first, last, "四帧不能长得一样")
