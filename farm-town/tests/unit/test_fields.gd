extends GutTest
## M9 第三批：田里和树上的画面规则（作物摇、成熟闪、落花落叶、落地弹跳）。


func test_trees_drop_something_only_in_the_right_season() -> void:
	assert_eq(FieldMotion.fall_kind(0, false), &"petal", "春天落花瓣")
	assert_eq(FieldMotion.fall_kind(1, false), &"", "夏天不落")
	assert_eq(FieldMotion.fall_kind(2, false), &"leaf", "秋天落叶")
	assert_eq(FieldMotion.fall_kind(3, false), &"snow", "冬天掉雪")
	assert_eq(FieldMotion.fall_kind(2, true), &"osmanthus", "桂花林秋天飘桂花")
	assert_eq(FieldMotion.fall_kind(0, true), &"", "桂花林春天不飘")


func test_leaves_fall_down_at_their_own_pace() -> void:
	var a := FieldMotion.fall_pos(0, 0.0)
	var b := FieldMotion.fall_pos(0, 0.6)
	assert_gt(b.y, a.y, "往下落")
	assert_true(absf(b.x) <= 5.0, "左右只打几个像素的旋")
	assert_ne(FieldMotion.fall_pos(0, 0.4).y, FieldMotion.fall_pos(3, 0.4).y, "每片落得不一样快")
	assert_eq(FieldMotion.fall_color(&"snow").a, 1.0)
	assert_eq(FieldMotion.fall_color(&"nope").a, 0.0)


func test_crops_only_sway_when_there_is_wind() -> void:
	assert_eq(FieldMotion.crop_sway(&"sunny"), 0.0, "晴天站着不动")
	assert_eq(FieldMotion.crop_sway(&"cloudy"), 0.0)
	assert_gt(FieldMotion.crop_sway(&"wind"), FieldMotion.crop_sway(&"storm"))
	assert_gt(FieldMotion.crop_sway(&"storm"), FieldMotion.crop_sway(&"rain"))
	assert_gt(FieldMotion.crop_sway(&"rain"), FieldMotion.crop_sway(&"snow"))


func test_ripe_crops_flash_once_in_a_while() -> void:
	assert_eq(FieldMotion.ripe_flash(0.5, 0.0), 1.0, "平时不亮")
	assert_gt(FieldMotion.ripe_flash(0.14, 0.0), 1.1, "闪的那一下更亮")
	assert_eq(FieldMotion.ripe_flash(3.9, 0.0), 1.0, "隔一会儿才再闪")


func test_popped_items_bounce_then_settle() -> void:
	assert_almost_eq(FieldMotion.bounce(0.0), 0.0, 0.001)
	assert_almost_eq(FieldMotion.bounce(0.35), -18.0, 0.001, "弹到最高")
	assert_almost_eq(FieldMotion.bounce(0.55), 0.0, 0.001, "落地")
	assert_lt(FieldMotion.bounce(0.66), -3.0, "落地以后还有一小跳")
	assert_eq(FieldMotion.bounce(1.0), 0.0, "停住")
	for i in 21:
		assert_lte(FieldMotion.bounce(float(i) / 20.0), 0.001, "全过程都在地面以上")


func test_preview_is_big_enough_and_the_frames_differ() -> void:
	var img := FieldMotion.preview()
	assert_gte(img.get_width(), 480, "四帧要能看清")
	assert_gte(img.get_height(), 64)
	var first := img.get_region(Rect2i(0, 0, 120, img.get_height())).get_data()
	var last := img.get_region(Rect2i(360, 0, 120, img.get_height())).get_data()
	assert_ne(first, last, "四帧不能长得一样")
