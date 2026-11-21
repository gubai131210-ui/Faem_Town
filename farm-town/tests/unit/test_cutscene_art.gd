extends GutTest
## 决策 120：开场与结局的过场画重画后要有细节、能认出主题，不能退回色块。

const CutsceneScript := preload("res://game/cutscene.gd")

## 每张画至少要有这么多种颜色——旧的纯色横带画只有个位数。
const ALL: Array[StringName] = [
	&"desk", &"letter", &"window",
	&"end_flame", &"end_inward", &"end_empty", &"end_hands",
	&"end_step", &"end_tree", &"end_unlit", &"end_climb", &"end_hill", &"end_bowl", &"credits",
	&"end_dock", &"end_stub",
]


func test_every_code_painting_has_real_detail() -> void:
	for id: StringName in ALL:
		var img: Image = CutsceneScript.picture(id)
		assert_eq(img.get_size(), Vector2i(192, 108), "%s 画幅不变" % id)
		var colors := {}
		for y in range(0, img.get_height(), 2):
			for x in range(0, img.get_width(), 2):
				colors[img.get_pixel(x, y)] = true
		assert_gt(colors.size(), 12, "%s 有明暗层次，不是几条色带" % id)


func test_key_themes_are_recognizable() -> void:
	# 开场：信封上的火漆是红的
	var letter: Image = CutsceneScript.picture(&"letter")
	var seal: Color = letter.get_pixel(143, 79)
	assert_gt(seal.r, seal.g + 0.2, "信封有红火漆")
	# 结局·空祠：石阶那一带有石头的灰，檐下是木的褐
	var shrine: Image = CutsceneScript.picture(&"end_empty")
	var stone: Color = shrine.get_pixel(96, 84)
	assert_gt(stone.r, 0.3, "石阶不是黑的")
	assert_almost_eq(stone.r, stone.g, 0.12, "石阶是灰的")
	# 结局·下井：梯子横档是木色，井壁是灰砖
	var shaft: Image = CutsceneScript.picture(&"end_climb")
	var rung: Color = shaft.get_pixel(95, 5)
	assert_gt(rung.r, rung.b + 0.05, "梯子是暖木色")
	var brick: Color = shaft.get_pixel(10, 5)
	assert_almost_eq(brick.r, brick.g, 0.12, "井壁是灰砖")


func test_no_palette_lookup_fallback_magenta() -> void:
	# Palette.c 缺键会回退洋红。这些画不该出现洋红——出现就说明用了不存在的色键。
	for id: StringName in ALL:
		var img: Image = CutsceneScript.picture(id)
		for y in range(0, img.get_height(), 3):
			for x in range(0, img.get_width(), 3):
				var c: Color = img.get_pixel(x, y)
				assert_false(c.r > 0.8 and c.g < 0.2 and c.b > 0.8, "%s 没有洋红错色" % id)
