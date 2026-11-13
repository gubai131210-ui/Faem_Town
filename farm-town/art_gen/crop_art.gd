class_name CropArt
extends RefCounted
## 作物的画法：地里的四个生长阶段、产物图标、种子袋图标。
## 每种作物在 data/crops.json 的 art 字段里选一种形状并给出叶色和果色，这里按形状画。
## 地里的图是 16×24，植株的根部在第 20 行；图标是 16×16。

const W := 16
const H := 24
## 植株根部所在的行
const G := 20

const SEEDED := [
	"....d......d....",
	"........d.......",
	"...d.......d....",
	"......d.........",
]
const WITHERED := [
	".......t........",
	"...t...tT...t...",
	"....tT.tT..tT...",
	".....tTtT.tT....",
	"......tTTTT.....",
	".......TT.......",
]
## 根茎类（萝卜、土豆、红薯）的三个阶段，l/L 是叶子，v/x/X 是露出地面的根
const ROOT := [
	[
		".....ll..ll.....",
		".....lLllLl.....",
		"......lLLl......",
		".......LL.......",
		".......L........",
	],
	[
		".......ll.......",
		"...ll..lL..ll...",
		"..lllL.lL.Llll..",
		"..lllLLlLLLlll..",
		"...llLLlLLLll...",
		"....lLLLLLLl....",
		".....LLLLLL.....",
		"......LLLL......",
		".......LL.......",
	],
	[
		".......ll.......",
		"..ll...lL...ll..",
		".lllL..lL..Llll.",
		".lllLL.lL.LLlll.",
		".llllLLlLLLLlll.",
		"..llLLLlLLLLll..",
		"...lLLLLLLLLl...",
		"....LLLLLLLL....",
		".....vvvvvv.....",
		"....vvxxxxvv....",
		"....xxxxxxxX....",
		".....xxxxXX.....",
	],
]
const SEED_BAG := [
	"................",
	"................",
	"......kkkk......",
	".....kkKKkk.....",
	"......rrrr......",
	".....kkkkkk.....",
	"....kkkkkkkk....",
	"...kkkffkkkkK...",
	"...kkffFfkkkK...",
	"...kkkfFkkkkK...",
	"...kkkkFkkkkK...",
	"...kkkkkkkkKK...",
	"....kkkkkkKK....",
	"................",
	"................",
	"................",
]


# ---------------------------------------------------------------- 入口

## 地里的作物。stage：0 刚播种，1 出苗，2 长叶，3 成熟。dead 为真时画枯死的样子。
static func field(crop_id: StringName, stage: int, dead: bool = false) -> Image:
	var img := Px.new_img(W, H)
	if dead:
		_rows(img, WITHERED, G - WITHERED.size() + 1, Palette.colors())
		return Px.outline(img)
	if stage <= 0:
		_rows(img, SEEDED, G - 3, Palette.colors())
		return img
	var art := _art(crop_id)
	var leaf := ramp(_col(art, "leaf", "7cc74f"))
	var fruit := ramp(_col(art, "fruit", "f6efe6"))
	match str(art.get("shape", "root")):
		"leafy":
			_leafy(img, stage, leaf, fruit)
		"bush":
			_bush(img, stage, leaf, fruit, art)
		"stalk":
			_stalk(img, stage, leaf, fruit, art)
		"melon":
			_melon(img, stage, leaf, fruit, art)
		"herb":
			_herb(img, stage, leaf, fruit)
		"grain":
			_grain(img, stage, leaf, fruit, art)
		"lotus":
			_lotus(img, stage, leaf, ramp(_col(art, "flower", "f4a9be")))
		_:
			_root(img, stage, leaf, fruit, crop_id)
	return Px.outline(img)


## 巨型的瓜，32×32，根部在第 28 行。
static func giant(crop_id: StringName) -> Image:
	var img := Px.new_img(32, 32)
	var art := _art(crop_id)
	var leaf := ramp(_col(art, "leaf", "7cc74f"))
	var fruit := ramp(_col(art, "fruit", "f6efe6"))
	var squash := bool(art.get("squash", false))
	var cx := 16.0
	var cy := 18.5 if squash else 17.0
	var rx := 12.0 if squash else 11.0
	var ry := 8.5 if squash else 10.0
	ball(img, 4.0, 26.0, 3.6, 2.6, leaf)
	ball(img, 28.0, 26.0, 3.6, 2.6, leaf)
	var rim: Color = fruit[2]
	rim = rim.darkened(0.35)
	ball(img, cx, cy, rx + 1.0, ry + 1.0, [rim, rim, rim])
	ball(img, cx, cy, rx, ry, fruit)
	_decorate_fruit(img, cx, cy, rx, ry, fruit, art, 2)
	Px.rect(img, 15, int(cy - ry) - 3, 2, 3, leaf[2])
	Px.rect(img, 17, int(cy - ry) - 3, 3, 1, leaf[1])
	ball(img, 7.0, 27.5, 3.0, 2.0, leaf)
	ball(img, 25.0, 27.5, 3.0, 2.0, leaf)
	return Px.outline(img)


## 产物的 16×16 图标。
static func icon(crop_id: StringName) -> Image:
	var img := Px.new_img(16, 16)
	var art := _art(crop_id)
	var leaf := ramp(_col(art, "leaf", "7cc74f"))
	var fruit := ramp(_col(art, "fruit", "f6efe6"))
	match str(art.get("icon", "round")):
		"leafy":
			ball(img, 8.0, 12.0, 2.6, 2.6, ramp(Color.html("f1f3e2")))
			ball(img, 4.8, 7.0, 3.2, 3.8, leaf)
			ball(img, 11.2, 7.0, 3.2, 3.8, leaf)
			ball(img, 8.0, 5.5, 3.0, 4.2, leaf)
			Px.line(img, Vector2i(8, 6), Vector2i(8, 11), fruit[1])
			Px.line(img, Vector2i(5, 8), Vector2i(7, 11), fruit[1])
			Px.line(img, Vector2i(11, 8), Vector2i(9, 11), fruit[1])
		"cabbage":
			ball(img, 8.0, 8.5, 4.6, 6.0, fruit)
			ball(img, 5.0, 5.5, 2.6, 3.4, leaf)
			ball(img, 11.0, 5.5, 2.6, 3.4, leaf)
			ball(img, 8.0, 4.0, 2.6, 2.6, leaf)
			Px.line(img, Vector2i(8, 7), Vector2i(8, 13), fruit[2])
			Px.line(img, Vector2i(6, 9), Vector2i(6, 12), fruit[2])
			Px.line(img, Vector2i(10, 9), Vector2i(10, 12), fruit[2])
		"flower":
			Px.line(img, Vector2i(8, 7), Vector2i(8, 14), leaf[2])
			Px.line(img, Vector2i(8, 11), Vector2i(5, 9), leaf[1])
			Px.line(img, Vector2i(8, 12), Vector2i(11, 10), leaf[1])
			for p: Vector2i in [Vector2i(8, 3), Vector2i(5, 5), Vector2i(11, 5), Vector2i(7, 6), Vector2i(10, 7)]:
				_blossom(img, p.x, p.y, fruit)
		"bloom":
			# 一朵正面朝外的大花：一圈花瓣，中间是花心
			var center := ramp(_col(art, "center", "d88a1e"))
			Px.line(img, Vector2i(8, 10), Vector2i(8, 15), leaf[2])
			Px.line(img, Vector2i(8, 13), Vector2i(11, 11), leaf[1])
			Px.px(img, 12, 11, leaf[0])
			for k in 8:
				var a := TAU * k / 8.0
				ball(img, 8.0 + cos(a) * 3.6, 6.5 + sin(a) * 3.6, 1.9, 1.9, fruit)
			ball(img, 8.0, 6.5, 2.4, 2.4, center)
		"pods":
			_pod(img, Vector2i(3, 5), Vector2i(10, 8), fruit)
			_pod(img, Vector2i(5, 10), Vector2i(12, 12), fruit)
			Px.px(img, 2, 4, leaf[2])
			Px.px(img, 4, 9, leaf[2])
		"berry":
			ball(img, 8.0, 8.5, 4.6, 4.2, fruit)
			ball(img, 8.0, 11.5, 2.6, 2.6, fruit)
			for p: Vector2i in [Vector2i(6, 8), Vector2i(9, 7), Vector2i(8, 10), Vector2i(11, 9), Vector2i(7, 12)]:
				Px.px(img, p.x, p.y, Color.html("f9e3a0"))
			Px.rect(img, 6, 4, 5, 1, leaf[1])
			Px.rect(img, 7, 3, 3, 1, leaf[0])
			Px.px(img, 5, 5, leaf[1])
			Px.px(img, 11, 5, leaf[1])
		"chili":
			for i in 9:
				var x := 4 + i
				var y := 5 + int(i * 0.9) - int(i * i * 0.03)
				Px.px(img, x, y, fruit[0] if i < 6 else fruit[1])
				Px.px(img, x, y + 1, fruit[1])
				if i < 6:
					Px.px(img, x, y + 2, fruit[2])
			Px.rect(img, 3, 4, 2, 2, leaf[1])
			Px.px(img, 2, 3, leaf[2])
		"corn":
			ball(img, 8.0, 7.5, 3.4, 5.6, fruit)
			for y in range(3, 13):
				for x in range(5, 12):
					if img.get_pixel(x, y).a > 0.0 and (x + y) % 2 == 0:
						img.set_pixel(x, y, fruit[2] if x > 8 else fruit[1])
			ball(img, 5.0, 11.5, 2.4, 3.2, leaf)
			ball(img, 11.0, 11.5, 2.4, 3.2, leaf)
			Px.rect(img, 7, 13, 2, 2, leaf[2])
		"long":
			ball(img, 8.0, 9.0, 6.0, 3.2, fruit)
			Px.px(img, 1, 9, fruit[1])
			Px.px(img, 14, 9, fruit[2])
			Px.px(img, 5, 8, fruit[2])
			Px.px(img, 10, 10, fruit[2])
		"boll":
			Px.rect(img, 7, 11, 2, 3, Color.html("7d5230"))
			Px.line(img, Vector2i(4, 11), Vector2i(11, 11), Color.html("9a6a40"))
			ball(img, 5.5, 7.5, 3.0, 3.0, fruit)
			ball(img, 10.5, 7.5, 3.0, 3.0, fruit)
			ball(img, 8.0, 5.0, 3.0, 3.0, fruit)
		"pile":
			ball(img, 8.0, 10.5, 5.6, 3.0, fruit)
			ball(img, 8.0, 8.0, 3.2, 2.4, fruit)
			for p: Vector2i in [Vector2i(6, 9), Vector2i(9, 8), Vector2i(4, 11), Vector2i(8, 11), Vector2i(11, 10), Vector2i(7, 12)]:
				Px.px(img, p.x, p.y, fruit[2])
		"grain":
			# 三根交叉的穗子
			for k in 3:
				var bx := 4 + k * 4
				Px.line(img, Vector2i(8, 14), Vector2i(bx, 8), leaf[2])
				for i in 4:
					var y := 3 + i * 2
					var x := bx + (k - 1) * (3 - i) / 3
					Px.px(img, x, y, fruit[0])
					Px.px(img, x + 1, y, fruit[1])
					Px.px(img, x, y + 1, fruit[1])
					Px.px(img, x + 1, y + 1, fruit[2])
			Px.rect(img, 6, 11, 5, 1, Color.html("b07a42"))
		"lotus":
			# 三节连着的藕
			var joint: Color = fruit[2]
			ball(img, 3.8, 10.6, 2.8, 2.4, fruit)
			ball(img, 8.2, 8.6, 2.8, 2.4, fruit)
			ball(img, 12.4, 6.6, 2.6, 2.2, fruit)
			Px.px(img, 6, 10, joint.darkened(0.2))
			Px.px(img, 10, 8, joint.darkened(0.2))
			Px.px(img, 14, 5, joint.darkened(0.3))
			Px.px(img, 1, 11, joint.darkened(0.3))
		"tea":
			ball(img, 4.8, 9.5, 2.4, 4.2, leaf)
			ball(img, 11.2, 9.5, 2.4, 4.2, leaf)
			ball(img, 8.0, 6.5, 2.2, 4.4, fruit)
			Px.line(img, Vector2i(8, 4), Vector2i(8, 10), fruit[2])
			Px.line(img, Vector2i(5, 7), Vector2i(5, 12), leaf[2])
			Px.line(img, Vector2i(11, 7), Vector2i(11, 12), leaf[2])
			Px.rect(img, 7, 12, 2, 2, leaf[2])
		"bell":
			Px.line(img, Vector2i(8, 14), Vector2i(8, 4), leaf[2])
			Px.line(img, Vector2i(8, 4), Vector2i(5, 3), leaf[2])
			Px.line(img, Vector2i(8, 7), Vector2i(11, 6), leaf[2])
			Px.line(img, Vector2i(8, 12), Vector2i(5, 10), leaf[1])
			_bell(img, 4, 4, fruit, true)
			_bell(img, 11, 7, fruit, true)
		_:
			var big := bool(art.get("big", false))
			var rx := 6.0 if big else 5.0
			var ry := 4.4 if bool(art.get("squash", false)) else (5.2 if big else 4.6)
			ball(img, 8.0, 9.2, rx, ry, fruit)
			_decorate_fruit(img, 8.0, 9.2, rx, ry, fruit, art)
			if bool(art.get("stem", true)):
				Px.rect(img, 7, int(9.2 - ry) - 1, 2, 2, leaf[2])
				Px.px(img, 9, int(9.2 - ry) - 1, leaf[1])
				Px.px(img, 6, int(9.2 - ry), leaf[1])
	return Px.outline(img)


## 种子袋，袋子上的小苗用这种作物的果色。
static func seed_icon(crop_id: StringName) -> Image:
	var pal := Palette.colors().duplicate()
	var c := ramp(_col(_art(crop_id), "fruit", "7cc74f"))
	var mark: Color = c[1]
	# 颜色太浅会和袋子混在一起，压暗一点
	if mark.get_luminance() > 0.8:
		mark = mark.darkened(0.25)
	pal["f"] = mark.lightened(0.15)
	pal["F"] = mark.darkened(0.15)
	return Px.outline(Px.ascii(SEED_BAG, pal))


# ---------------------------------------------------------------- 各种形状

static func _root(img: Image, stage: int, leaf: Array, fruit: Array, crop_id: StringName) -> void:
	var rows: Array = ROOT[clampi(stage, 1, 3) - 1]
	var pal := {"l": leaf[1], "L": leaf[2], "v": fruit[0], "x": fruit[1], "X": fruit[2]}
	if crop_id == &"white_radish":
		# 白萝卜露出地面的那一圈是紫的
		pal["v"] = Palette.c("v")
		pal["l"] = Palette.c("l")
		pal["L"] = Palette.c("L")
	_rows(img, rows, G - rows.size() + 1, pal)


static func _leafy(img: Image, stage: int, leaf: Array, heart: Array) -> void:
	if stage == 1:
		_sprout(img, leaf)
		return
	if stage == 2:
		ball(img, 5.5, 17.5, 2.6, 2.4, leaf)
		ball(img, 10.5, 17.5, 2.6, 2.4, leaf)
		ball(img, 8.0, 15.5, 2.6, 2.6, leaf)
		Px.line(img, Vector2i(8, 16), Vector2i(8, 19), heart[1])
		return
	var dark := [leaf[1], leaf[2], (leaf[2] as Color).darkened(0.18)]
	ball(img, 3.8, 17.0, 3.2, 3.0, dark)
	ball(img, 12.2, 17.0, 3.2, 3.0, dark)
	ball(img, 5.5, 13.5, 3.0, 3.2, leaf)
	ball(img, 10.5, 13.5, 3.0, 3.2, leaf)
	ball(img, 8.0, 17.6, 3.6, 2.8, leaf)
	ball(img, 8.0, 15.0, 2.8, 3.0, heart)
	Px.line(img, Vector2i(8, 13), Vector2i(8, 18), heart[2])


static func _bush(img: Image, stage: int, leaf: Array, fruit: Array, art: Dictionary) -> void:
	var tall := bool(art.get("tall", false))
	var stake := Color.html("9a6a40")
	if stage == 1:
		_sprout(img, leaf)
		return
	if bool(art.get("trellis", false)):
		# 架子：两根立杆加两道横杆
		var top := 10 if stage == 2 else 4
		Px.line(img, Vector2i(3, top), Vector2i(3, G), stake)
		Px.line(img, Vector2i(12, top), Vector2i(12, G), stake)
		Px.line(img, Vector2i(3, top + 2), Vector2i(12, top + 2), stake)
		if stage > 2:
			Px.line(img, Vector2i(3, top + 8), Vector2i(12, top + 8), stake)
	elif tall:
		var top := 11 if stage == 2 else 5
		Px.line(img, Vector2i(8, top), Vector2i(8, G), stake)
	if stage == 2:
		ball(img, 8.0, 16.8, 3.8, 3.2, leaf)
		if tall:
			ball(img, 8.0, 13.5, 2.6, 2.4, leaf)
		return
	var spots: Array = []
	ball(img, 5.0, 16.5, 3.6, 3.4, leaf)
	ball(img, 11.0, 16.5, 3.6, 3.4, leaf)
	ball(img, 8.0, 14.0, 3.8, 3.4, leaf)
	spots = [Vector2i(4, 17), Vector2i(8, 15), Vector2i(11, 17), Vector2i(7, 18)]
	if tall:
		ball(img, 6.5, 10.5, 3.0, 2.8, leaf)
		ball(img, 9.5, 8.5, 2.8, 2.8, leaf)
		spots = [Vector2i(4, 17), Vector2i(11, 16), Vector2i(8, 13), Vector2i(6, 10), Vector2i(10, 9)]
	var kind := str(art.get("fruit_shape", "dot"))
	for p: Vector2i in spots:
		match kind:
			"pod":
				Px.px(img, p.x, p.y - 1, fruit[0])
				Px.px(img, p.x, p.y, fruit[1])
				Px.px(img, p.x + 1, p.y + 1, fruit[1])
			"long":
				Px.px(img, p.x, p.y - 1, fruit[0])
				Px.px(img, p.x, p.y, fruit[1])
				Px.px(img, p.x, p.y + 1, fruit[2])
			"bloom":
				# 一朵小花：十字形的花瓣加花心
				var center := _col(art, "center", "d88a1e")
				Px.px(img, p.x, p.y - 1, fruit[0])
				Px.px(img, p.x - 1, p.y, fruit[0])
				Px.px(img, p.x + 1, p.y, fruit[1])
				Px.px(img, p.x, p.y + 1, fruit[2])
				Px.px(img, p.x, p.y, center)
			_:
				Px.rect(img, p.x, p.y - 1, 2, 2, fruit[1])
				Px.px(img, p.x, p.y - 1, fruit[0])
				Px.px(img, p.x + 1, p.y, fruit[2])


static func _stalk(img: Image, stage: int, leaf: Array, fruit: Array, art: Dictionary) -> void:
	if stage == 1:
		_sprout(img, leaf)
		return
	var height := 10 if stage == 2 else 17
	var top := G - height
	Px.line(img, Vector2i(8, top), Vector2i(8, G), leaf[2])
	Px.line(img, Vector2i(7, top + 2), Vector2i(7, G), leaf[1])
	# 叶子左右交替，越往上越短
	var y := G - 2
	var side := -1
	while y > top + 1:
		var reach := 5 if y > top + 6 else 3
		var from_x := 7 if side < 0 else 8
		Px.line(img, Vector2i(from_x, y), Vector2i(from_x + side * reach, y - 2), leaf[1])
		Px.line(img, Vector2i(from_x + side, y), Vector2i(from_x + side * reach, y - 1), leaf[0])
		Px.px(img, from_x + side * (reach + 1), y - 1, leaf[1])
		y -= 3
		side = -side
	if stage < 3:
		return
	match str(art.get("top", "flower")):
		"ear":
			# 玉米：顶上是穗，秆的两侧各挂一个棒子
			Px.line(img, Vector2i(7, top - 1), Vector2i(6, top - 3), Color.html("d9c07a"))
			Px.line(img, Vector2i(8, top - 1), Vector2i(9, top - 3), Color.html("d9c07a"))
			Px.px(img, 8, top - 2, Color.html("c2a45e"))
			for e: Vector2i in [Vector2i(5, G - 9), Vector2i(9, G - 13)]:
				Px.rect(img, e.x, e.y, 2, 4, fruit[1])
				Px.px(img, e.x, e.y, fruit[0])
				Px.px(img, e.x, e.y + 1, fruit[0])
				Px.px(img, e.x + 1, e.y + 3, fruit[2])
				Px.px(img, e.x, e.y + 4, leaf[0])
				Px.px(img, e.x + 1, e.y + 4, leaf[2])
		"pods":
			for i in 5:
				var py := top + 1 + i * 2
				var px := 6 if i % 2 == 0 else 9
				Px.px(img, px, py, fruit[1])
				Px.px(img, px, py + 1, fruit[2])
			Px.px(img, 8, top - 1, fruit[0])
			Px.px(img, 7, top, fruit[0])
		"sun":
			# 向日葵：顶上一个大花盘
			var center := ramp(_col(art, "center", "7a4a24"))
			for k in 10:
				var a := TAU * k / 10.0
				ball(img, 8.0 + cos(a) * 3.8, top + 2.5 + sin(a) * 3.8, 1.7, 1.7, fruit)
			ball(img, 8.0, top + 2.5, 2.8, 2.8, center)
		_:
			for p: Vector2i in [Vector2i(8, top - 1), Vector2i(5, top + 1), Vector2i(11, top + 1),
					Vector2i(7, top + 3), Vector2i(10, top + 4), Vector2i(4, top + 5)]:
				_blossom(img, p.x, p.y, fruit)


static func _melon(img: Image, stage: int, leaf: Array, fruit: Array, art: Dictionary) -> void:
	if stage == 1:
		_sprout(img, leaf)
		return
	Px.line(img, Vector2i(2, 19), Vector2i(13, 19), leaf[2])
	ball(img, 3.5, 17.5, 2.6, 2.2, leaf)
	ball(img, 12.5, 17.8, 2.6, 2.0, leaf)
	ball(img, 8.0, 16.5, 2.8, 2.4, leaf)
	if stage == 2:
		Px.px(img, 6, 15, fruit[1] if bool(art.get("ribs", false)) else Color.html("f4d23c"))
		return
	var squash := bool(art.get("squash", false))
	var cx := 8.0
	var cy := 15.8 if squash else 15.0
	var rx := 5.4 if squash else 5.0
	var ry := 4.0 if squash else 4.8
	var rim: Color = fruit[2]
	rim = rim.darkened(0.35)
	ball(img, cx, cy, rx + 1.0, ry + 1.0, [rim, rim, rim])
	ball(img, cx, cy, rx, ry, fruit)
	_decorate_fruit(img, cx, cy, rx, ry, fruit, art)
	Px.rect(img, 7, int(cy - ry) - 2, 2, 2, leaf[2])
	ball(img, 1.8, 19.0, 1.8, 1.4, leaf)
	ball(img, 14.2, 19.0, 1.8, 1.4, leaf)


## 稻、麦：一丛细长的叶子，成熟时顶上是穗。droop 为真时穗子垂下来（稻）。
static func _grain(img: Image, stage: int, leaf: Array, fruit: Array, art: Dictionary) -> void:
	if stage == 1:
		_sprout(img, leaf)
		Px.line(img, Vector2i(6, G), Vector2i(4, G - 3), leaf[1])
		Px.line(img, Vector2i(10, G), Vector2i(12, G - 3), leaf[1])
		return
	var h := 8 if stage == 2 else 13
	var droop := bool(art.get("droop", false))
	var ripe := stage >= 3
	for i in 5:
		var lean := i - 2
		var base := Vector2i(8 + lean, G)
		var tip := Vector2i(8 + lean * 3, G - h + absi(lean))
		var blade: Color = leaf[1] if i % 2 == 0 else leaf[2]
		if ripe:
			blade = blade.lerp(fruit[2], 0.45)
		Px.line(img, base, tip, blade)
		if not ripe:
			Px.px(img, tip.x, tip.y - 1, leaf[0])
			continue
		var side := 1 if lean >= 0 else -1
		for k in 4:
			var p := tip + (Vector2i(side * (k + 1) / 2, k - 1) if droop else Vector2i(0, -k))
			Px.px(img, p.x, p.y, fruit[0] if k < 2 else fruit[1])
			if k % 2 == 1:
				Px.px(img, p.x + side, p.y, fruit[2])


## 藕：水面上的荷叶，成熟时开一朵荷花。
static func _lotus(img: Image, stage: int, leaf: Array, flower: Array) -> void:
	var dark := [leaf[1], leaf[2], (leaf[2] as Color).darkened(0.2)]
	if stage == 1:
		ball(img, 8.0, 18.5, 3.2, 1.6, leaf)
		Px.px(img, 8, 18, dark[2])
		return
	ball(img, 4.5, 19.0, 3.4, 1.6, dark)
	ball(img, 12.0, 18.0, 3.2, 1.6, dark)
	var top := 14 if stage == 2 else 10
	Px.line(img, Vector2i(7, G), Vector2i(7, top), leaf[2])
	ball(img, 7.0, top - 0.5, 5.2 if stage > 2 else 4.2, 2.4, leaf)
	Px.px(img, 7, top - 1, dark[2])
	if stage < 3:
		return
	Px.line(img, Vector2i(12, G - 2), Vector2i(12, 7), leaf[2])
	ball(img, 12.0, 5.0, 2.2, 2.8, flower)
	Px.px(img, 10, 6, flower[1])
	Px.px(img, 14, 6, flower[2])
	Px.px(img, 12, 2, flower[0])


static func _herb(img: Image, stage: int, leaf: Array, fruit: Array) -> void:
	if stage == 1:
		_sprout(img, leaf)
		return
	Px.line(img, Vector2i(8, G), Vector2i(8, 12 if stage == 2 else 8), leaf[2])
	Px.line(img, Vector2i(8, 18), Vector2i(5, 16), leaf[1])
	Px.line(img, Vector2i(8, 17), Vector2i(11, 15), leaf[1])
	Px.line(img, Vector2i(7, G), Vector2i(4, 18), leaf[0])
	Px.line(img, Vector2i(9, G), Vector2i(12, 18), leaf[0])
	if stage == 2:
		Px.px(img, 8, 11, fruit[1])
		return
	Px.line(img, Vector2i(8, 8), Vector2i(5, 7), leaf[2])
	Px.line(img, Vector2i(8, 11), Vector2i(11, 10), leaf[2])
	Px.line(img, Vector2i(8, 14), Vector2i(5, 13), leaf[2])
	_bell(img, 4, 8, fruit, true)
	_bell(img, 11, 11, fruit, true)
	_bell(img, 4, 14, fruit, false)


# ---------------------------------------------------------------- 小部件

## 刚出土的小苗，所有作物共用。
static func _sprout(img: Image, leaf: Array) -> void:
	Px.line(img, Vector2i(8, G), Vector2i(8, G - 3), leaf[2])
	Px.line(img, Vector2i(7, G - 3), Vector2i(5, G - 5), leaf[1])
	Px.line(img, Vector2i(8, G - 3), Vector2i(10, G - 5), leaf[1])
	Px.px(img, 5, G - 4, leaf[0])
	Px.px(img, 10, G - 4, leaf[0])
	Px.px(img, 6, G - 5, leaf[0])
	Px.px(img, 11, G - 5, leaf[0])


static func _blossom(img: Image, x: int, y: int, cols: Array) -> void:
	Px.px(img, x, y, cols[0])
	Px.px(img, x + 1, y, cols[1])
	Px.px(img, x, y + 1, cols[1])
	Px.px(img, x + 1, y + 1, cols[2])


static func _bell(img: Image, x: int, y: int, cols: Array, big: bool) -> void:
	Px.px(img, x, y, cols[0])
	Px.px(img, x + 1, y, cols[1])
	Px.px(img, x, y + 1, cols[1])
	Px.px(img, x + 1, y + 1, cols[2])
	if big:
		Px.px(img, x - 1, y + 2, cols[1])
		Px.px(img, x, y + 2, cols[0])
		Px.px(img, x + 1, y + 2, cols[1])
		Px.px(img, x + 2, y + 2, cols[2])


static func _pod(img: Image, a: Vector2i, b: Vector2i, cols: Array) -> void:
	Px.line(img, a, b, cols[0])
	Px.line(img, a + Vector2i(0, 1), b + Vector2i(0, 1), cols[1])
	Px.line(img, a + Vector2i(1, 2), b + Vector2i(-1, 2), cols[2])
	# 豆荚上一粒一粒鼓起来的地方
	var n := 3
	for i in n:
		var p := Vector2(a).lerp(Vector2(b), (i + 0.5) / n)
		Px.px(img, int(p.x), int(p.y) - 1, cols[0])


## 西瓜的条纹、南瓜的棱、土豆的芽眼。
## scale 是图的放大倍数：巨型作物的棱和条纹间距跟着变宽。
static func _decorate_fruit(img: Image, cx: float, cy: float, rx: float, ry: float, cols: Array,
		art: Dictionary, scale: int = 1) -> void:
	var x0 := int(cx - rx)
	var x1 := int(cx + rx)
	var y0 := int(cy - ry)
	var y1 := int(cy + ry)
	if art.has("stripes"):
		var stripe := Color.html(str(art["stripes"]))
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				if img.get_pixel(x, y).a == 0.0 or absf(x + 0.5 - cx) > rx or absf(y + 0.5 - cy) > ry:
					continue
				# 条纹顺着瓜的弧度弯：离中线越远偏得越多
				var bend := int(roundf((x - cx) * absf(y - cy) / ry * 0.35))
				if posmod(x - int(cx) + bend, 2 + scale) == 0 and (x + y) % 5 != 0:
					img.set_pixel(x, y, stripe)
	if bool(art.get("ribs", false)):
		for y in range(y0, y1 + 1):
			for dx: int in [-3, 0, 3]:
				var x := int(cx) + dx * scale
				if img.get_pixel(x, y).a > 0.0 and y > y0:
					img.set_pixel(x, y, cols[2])
	if bool(art.get("eyes", false)):
		for p: Vector2i in [Vector2i(-2, -1), Vector2i(2, 0), Vector2i(0, 2)]:
			Px.px(img, int(cx) + p.x, int(cy) + p.y, cols[2])


## 画一个椭圆，按左上来光分三档明暗。cols 是 [亮, 中, 暗]。
static func ball(img: Image, cx: float, cy: float, rx: float, ry: float, cols: Array) -> void:
	for y in range(floori(cy - ry), ceili(cy + ry) + 1):
		for x in range(floori(cx - rx), ceili(cx + rx) + 1):
			var nx := (x + 0.5 - cx) / rx
			var ny := (y + 0.5 - cy) / ry
			if nx * nx + ny * ny > 1.0:
				continue
			var v := -(nx * 0.6 + ny * 0.8)
			var col: Color = cols[1]
			if v > 0.38:
				col = cols[0]
			elif v < -0.42:
				col = cols[2]
			Px.px(img, x, y, col)


## 由一个颜色得到 [亮, 中, 暗] 三档。
static func ramp(c: Color) -> Array:
	return [c.lightened(0.28), c, Color(c.r * 0.72, c.g * 0.74, c.b * 0.8)]


static func _rows(img: Image, rows: Array, top: int, pal: Dictionary) -> void:
	for i in rows.size():
		var row: String = rows[i]
		for x in mini(W, row.length()):
			var ch := row[x]
			if ch != "." and pal.has(ch):
				var c: Color = pal[ch]
				Px.px(img, x, top + i, c)


static func _art(crop_id: StringName) -> Dictionary:
	if Database.has_crop(crop_id):
		return Database.crop(crop_id).art
	return {}


static func _col(art: Dictionary, key: String, fallback: String) -> Color:
	var s := str(art.get(key, fallback))
	return Color.html(s) if Color.html_is_valid(s) else Color.html(fallback)
