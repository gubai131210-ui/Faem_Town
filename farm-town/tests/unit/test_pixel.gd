extends GutTest
## 像素绘制工具的基础测试，同时用来确认测试框架本身能跑。


func test_ascii_maps_characters_to_palette() -> void:
	var img := Px.ascii(["a.", ".a"], {"a": Color.RED})
	assert_eq(img.get_size(), Vector2i(2, 2))
	assert_eq(img.get_pixel(0, 0), Color.RED)
	assert_eq(img.get_pixel(1, 0).a, 0.0)


func test_outline_surrounds_opaque_pixels_only() -> void:
	var img := Px.new_img(5, 5)
	img.set_pixel(2, 2, Color.WHITE)
	var out := Px.outline(img)
	assert_eq(out.get_pixel(2, 2), Color.WHITE, "原像素不变")
	for p: Vector2i in [Vector2i(2, 1), Vector2i(1, 2), Vector2i(3, 2), Vector2i(2, 3)]:
		assert_gt(out.get_pixelv(p).a, 0.5, "上下左右有描边")
	assert_eq(out.get_pixel(1, 1).a, 0.0, "斜角不描边")
	assert_eq(out.get_pixel(0, 0).a, 0.0)
