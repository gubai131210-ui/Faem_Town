extends GutTest
## M9 第四批：界面和头像的画面规则（眨眼、嘴动、图标飞行、钱数滚动、换季名牌）。


func test_blink_is_short_and_not_a_metronome() -> void:
	assert_true(UiMotion.blink_closed(0.05, 0.0), "刚开场眨一下")
	assert_false(UiMotion.blink_closed(1.0, 0.0), "大多数时候是睁着的")
	assert_false(UiMotion.blink_closed(0.05, 3.0), "各人错开，不会一起眨")
	var closed := 0
	for i in 200:
		if UiMotion.blink_closed(float(i) * 0.05, 0.0):
			closed += 1
	assert_lt(closed, 22, "十秒里只闭一小会儿，不是一半时间都闭着")


func test_mouth_moves_only_while_talking() -> void:
	assert_eq(UiMotion.mouth_frame(0.7, false), 0, "没在说话就闭着")
	var seen := {}
	for i in 12:
		seen[UiMotion.mouth_frame(float(i) * 0.1, true)] = true
	assert_gte(seen.size(), 3, "说话时至少张、半张、闭三档都出现")


func test_icon_flys_from_the_middle_into_the_bar() -> void:
	var from := Vector2(192, 132)
	var to := Vector2(84, 202)
	assert_eq(UiMotion.fly_pos(from, to, 0.0), from)
	assert_eq(UiMotion.fly_pos(from, to, 1.0), to)
	var mid := UiMotion.fly_pos(from, to, 0.5)
	assert_lt(mid.y, lerpf(from.y, to.y, 0.5), "走的是上抛的弧线，不是直线")
	assert_lt(mid.x, from.x, "往左边的格子去")


func test_money_rolls_and_lands_on_the_exact_number() -> void:
	assert_eq(UiMotion.money_shown(120, 380, 0.0), 120)
	assert_eq(UiMotion.money_shown(120, 380, 1.0), 380)
	assert_gt(UiMotion.money_shown(120, 380, 0.5), 260, "先快后慢")
	assert_eq(UiMotion.money_shown(380, 120, 1.0), 120, "少了钱也往下滚")


func test_season_card_only_on_the_first_morning_of_a_season() -> void:
	assert_true(UiMotion.season_first_day(24, 25), "春末到夏初")
	assert_true(UiMotion.season_first_day(48, 49))
	assert_true(UiMotion.season_first_day(72, 73))
	assert_false(UiMotion.season_first_day(1, 2), "开局那一季不亮")
	assert_false(UiMotion.season_first_day(25, 26), "季中不亮")
	assert_false(UiMotion.season_first_day(25, 25), "没有进入下一天也不亮")
	assert_eq(UiMotion.season_card_text("秋", "立秋"), "入秋 · 立秋")


func test_season_card_fades_in_holds_and_fades_out() -> void:
	assert_almost_eq(UiMotion.season_card_alpha(0.0), 0.0, 0.001)
	assert_gt(UiMotion.season_card_alpha(0.2), 0.6, "亮起来")
	assert_eq(UiMotion.season_card_alpha(1.0), 1.0, "停一会儿")
	assert_almost_eq(UiMotion.season_card_alpha(UiMotion.SEASON_CARD_TIME), 0.0, 0.001)


func test_season_card_fades_out_gradually() -> void:
	assert_gt(UiMotion.season_card_alpha(1.7), 0.8, "刚过停留段还很亮")
	assert_almost_eq(UiMotion.season_card_alpha(2.0), 0.5, 0.05, "淡出段走一半")
	assert_lt(UiMotion.season_card_alpha(2.3), 0.2, "快收完了")


func test_face_variant_closes_eyes_and_opens_mouth() -> void:
	var base := _face()
	var closed := UiMotion.face_variant(base, true, 0)
	var eye := Rect2i(21, 30, 9, 8)
	assert_lt(_deep_in(closed, eye), _deep_in(base, eye), "眼睛大部分被肤色盖住")
	assert_gte(_deep_in(closed, eye), 4, "还留一道深色眼线")
	assert_ne(closed.get_pixel(24, 33).to_html(false), "f6efe6", "眼白也一起盖掉，不留白竖条")
	assert_eq(UiMotion.face_variant(base, false, 0).get_pixel(25, 33), base.get_pixel(25, 33))
	var talking := UiMotion.face_variant(base, false, 2)
	var mouth := Rect2i(28, 39, 9, 6)
	assert_gt(_deep_in(talking, mouth), _deep_in(base, mouth), "嘴比原来那条线张得开")
	assert_ne(talking.get_pixel(32, 39), base.get_pixel(32, 39), "张嘴比原来那条线高")


func test_every_residents_face_can_blink_and_talk() -> void:
	var img := UiMotion.preview_faces()
	assert_eq(img.get_width(), 256, "四列：睁、闭、微张、张")
	var rows := img.get_height() / 64
	assert_gte(rows, 12, "十二位居民各占一行")
	# 细长眼那点灰高光（ink+white 混色），闭眼该一起盖掉，不能留灰点
	for r in rows:
		var open := img.get_region(Rect2i(0, r * 64, 64, 64))
		var closed := img.get_region(Rect2i(64, r * 64, 64, 64))
		var talk := img.get_region(Rect2i(192, r * 64, 64, 64))
		assert_ne(open.get_data(), closed.get_data(), "第 %d 行闭眼和睁眼不一样" % r)
		# 刘海（x20/21）和眉梢（x23/40）在 y30，闭眼不该把它们涂成肤色
		for x in [20, 21, 23, 40]:
			assert_eq(closed.get_pixel(x, 30), open.get_pixel(x, 30),
					"第 %d 行 y30 的刘海/眉毛没被涂" % r)
		# 闭眼后眼里不该残留灰高光：低饱和的浅色就是没盖掉的高光，
		# 肤色是暖色（红远大于蓝）、眼线是深色，都不该被这条判成残留
		for p in [Vector2i(24, 33), Vector2i(37, 33)]:
			var c := closed.get_pixel(p.x, p.y)
			var mx := maxf(c.r, maxf(c.g, c.b))
			var mn := minf(c.r, minf(c.g, c.b))
			assert_false(mx - mn < 0.12 and c.r > 0.5,
					"第 %d 行闭眼盖掉了灰高光" % r)
		# 张嘴的嘴心是红唇，不是白胡子或络腮胡
		var lip := talk.get_pixel(32, 41)
		assert_gt(lip.r, lip.g * 1.2, "第 %d 行张嘴是红唇不是胡子色" % r)


func test_preview_has_four_rows_of_four_different_frames() -> void:
	var img := UiMotion.preview()
	assert_eq(img.get_size(), Vector2i(640, 256))
	var top_left := img.get_region(Rect2i(0, 0, 160, 64)).get_data()
	var top_last := img.get_region(Rect2i(480, 0, 160, 64)).get_data()
	assert_ne(top_left, top_last, "头像是四帧不同的")
	var money_row := img.get_region(Rect2i(0, 128, 160, 64)).get_data()
	var money_last := img.get_region(Rect2i(480, 128, 160, 64)).get_data()
	assert_ne(money_row, money_last, "钱数在滚")


## 一张最小的 64×64 脸：肤色底、两只深色眼、一条唇色的嘴。
func _face() -> Image:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color("f7cba4"))
	for y in range(31, 36):
		for x in range(22, 28):
			img.set_pixel(x, y, Color("3a2a35"))
		for x in range(35, 41):
			img.set_pixel(x, y, Color("3a2a35"))
	for x in range(29, 36):
		img.set_pixel(x, 41, Color("b05545"))
	img.set_pixel(24, 33, Color("f6efe6"))
	img.set_pixel(37, 33, Color("f6efe6"))
	return img


## 一块区域里有多少个深色像素。
func _deep_in(img: Image, rect: Rect2i) -> int:
	var n := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := img.get_pixel(x, y)
			if c.a > 0.5 and (c.r + c.g + c.b) / 3.0 < 0.45:
				n += 1
	return n
