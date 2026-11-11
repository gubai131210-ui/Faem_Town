class_name PixelArt
extends RefCounted
## 用代码逐像素绘制的素材：作物、图标、植物、建筑、地面、界面。
## 文件变大以后按类别拆开。

static var P: Dictionary = Palette.colors()

const CROPS := [
	[
		"................", "................", "................", "................",
		"................", "................", "................", "................",
		"................",
		"....d......d....",
		"........d.......",
		"...d.......d....",
		"......d.........",
		"................", "................", "................",
	],
	[
		"................", "................", "................", "................",
		"................", "................",
		".....ll..ll.....",
		".....lLllLl.....",
		"......lLLl......",
		".......LL.......",
		".......L........",
		"................", "................", "................", "................", "................",
	],
	[
		"................", "................",
		".......ll.......",
		"...ll..lL..ll...",
		"..lllL.lL.Llll..",
		"..lllLLlLLLlll..",
		"...llLLlLLLll...",
		"....lLLLLLLl....",
		".....LLLLLL.....",
		"......LLLL......",
		".......LL.......",
		"................", "................", "................", "................", "................",
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
		"................", "................", "................", "................",
	],
]

const ICONS := {
	"turnip": [
		"................",
		"......l..ll.....",
		".....lLl.lL.....",
		"......lLLL......",
		".......LL.......",
		".....vvvvvv.....",
		"....vvvvvvvv....",
		"...vvxxxxxxvv...",
		"...xxxxxxxxxx...",
		"...xxxxxxxxxX...",
		"....xxxxxxxX....",
		".....xxxxxX.....",
		"......xxXX......",
		".......xX.......",
		"................",
		"................",
	],
	"can": [
		"................",
		"................",
		"....ggggg.......",
		"...g.....g......",
		"...g.....g...gg.",
		"..ggggggggg.gg..",
		"..gGGGGGGGGgg...",
		"..gGGGGGGGGg....",
		"..gGGGGGGGG.....",
		"..gGGGGGGGG.....",
		"..GGGGGGGGG.....",
		"..GGGGGGGGG.....",
		"...GGGGGGG......",
		"................",
		"................",
		"................",
	],
	"seeds": [
		"................",
		"................",
		"......kkkk......",
		".....kkKKkk.....",
		"......rrrr......",
		".....kkkkkk.....",
		"....kkkkkkkk....",
		"...kkkllkkkkK...",
		"...kkllLlkkkK...",
		"...kkklLkkkkK...",
		"...kkkkLkkkkK...",
		"...kkkkkkkkKK...",
		"....kkkkkkKK....",
		"................",
		"................",
		"................",
	],
}

const TUFT := [
	"..l.....l...",
	".lL..l..Ll..",
	".lL.lL..Ll.l",
	"..LllL.lLlL.",
	"..LLLLLLLL..",
]

const FLOWER := [
	"..fff...",
	".ffqff..",
	"..fff...",
	"...L....",
	".l.L....",
	"..LL.l..",
	"...LL...",
]

# ---------------------------------------------------------------- 作物与图标

## 作物某个生长阶段的图。目前只画了白萝卜，其他作物先用它代替，M1 补齐。
static func crop(_crop_id: StringName, stage: int) -> Image:
	var rows: Array = CROPS[clampi(stage, 0, CROPS.size() - 1)]
	var img := Px.ascii(rows, P)
	if stage == 0:
		return img
	return Px.outline(img)


static func icon(n: String) -> Image:
	if n == "hoe":
		var img := Px.new_img(16, 16)
		Px.line(img, Vector2i(3, 13), Vector2i(11, 5), P["w"])
		Px.line(img, Vector2i(4, 13), Vector2i(12, 5), P["W"])
		Px.rect(img, 8, 2, 6, 3, P["m"])
		Px.rect(img, 11, 4, 3, 4, P["m"])
		Px.rect(img, 13, 3, 1, 5, P["M"])
		Px.rect(img, 11, 7, 3, 1, P["M"])
		return Px.outline(img)
	var rows: Array = ICONS[n]
	return Px.outline(Px.ascii(rows, P))


static func tuft() -> Image:
	# 草丛不描边，只用比地面略深的两档绿色，避免满地黑边显得脏
	var pal := {"l": Color.html("5fa043"), "L": Color.html("4a8a3a")}
	return Px.ascii(TUFT, pal)


static func flower(variant: int) -> Image:
	var pal := P.duplicate()
	var cols := [Color.html("f6f1ea"), Color.html("f28fb0"), Color.html("f4c542"), Color.html("9d8cf0")]
	pal["f"] = cols[variant % cols.size()]
	if variant % cols.size() == 2:
		pal["q"] = Color.html("e07a2e")
	return Px.outline(Px.ascii(FLOWER, pal))


# ---------------------------------------------------------------- 树、灌木、石头

## 用若干个圆拼出一团，按左上方来光分四档明暗，并加少量杂色做出叶丛质感。
static func blob(img: Image, circles: Array, cols: Array, sd: int) -> void:
	var ymin := 1000.0
	var ymax := -1000.0
	for cv in circles:
		var c0: Vector3 = cv
		ymin = minf(ymin, c0.y - c0.z)
		ymax = maxf(ymax, c0.y + c0.z)
	for y in img.get_height():
		for x in img.get_width():
			var bd := 9.0
			var bc := Vector3.ZERO
			for cv in circles:
				var c: Vector3 = cv
				var d := Vector2(x + 0.5 - c.x, y + 0.5 - c.y).length() / c.z
				if d < bd:
					bd = d
					bc = c
			if bd > 1.0:
				continue
			var n := Vector2(x + 0.5 - bc.x, y + 0.5 - bc.y) / bc.z
			var v := n.dot(Vector2(-0.55, -0.83)) * 0.9
			v -= (y - ymin) / (ymax - ymin) * 0.9 - 0.4
			v += (float(Px.h2(x / 2 + sd, y / 2) % 100) / 100.0 - 0.5) * 0.45
			v += (float(Px.h2(x + sd * 7, y) % 100) / 100.0 - 0.5) * 0.2
			var idx := 3
			if v > 0.5:
				idx = 0
			elif v > 0.0:
				idx = 1
			elif v > -0.5:
				idx = 2
			var col: Color = cols[idx]
			img.set_pixel(x, y, col)


static func tree(variant: int) -> Image:
	var img := Px.new_img(44, 60)
	var rng := RandomNumberGenerator.new()
	rng.seed = 100 + variant * 17
	var bark := [Color.html("a06a3c"), Color.html("84532d"), Color.html("653d20")]
	var bx := 22
	for y in range(34, 57):
		var half := 3
		if y >= 53:
			half = 4
		if y >= 55:
			half = 5
		for x in range(bx - half, bx + half):
			var c: Color = bark[1]
			if x <= bx - half + 1:
				c = bark[0]
			if x >= bx + half - 2:
				c = bark[2]
			if Px.h2(x, y / 2 + variant) % 6 == 0:
				c = bark[2]
			if y < 43:
				c = bark[2]
			img.set_pixel(x, y, c)
	var greens := [
		[Color.html("a9d95a"), Color.html("6fb845"), Color.html("4a9440"), Color.html("32733c")],
		[Color.html("8fcf6a"), Color.html("56a653"), Color.html("3a8250"), Color.html("2a6347")],
		[Color.html("bfdc5c"), Color.html("86bd45"), Color.html("5e9a3c"), Color.html("437a37")],
	]
	var base := [Vector3(22, 19, 13), Vector3(12, 26, 9), Vector3(32, 26, 9),
		Vector3(15, 13, 8), Vector3(29, 13, 8), Vector3(22, 30, 10)]
	var circles: Array = []
	for cv in base:
		var c: Vector3 = cv
		circles.append(Vector3(c.x + rng.randi_range(-1, 1), c.y + rng.randi_range(-1, 1), c.z))
	var gcols: Array = greens[variant % greens.size()]
	blob(img, circles, gcols, variant * 13 + 5)
	if variant % 3 == 2:
		for i in 7:
			var ax := rng.randi_range(8, 34)
			var ay := rng.randi_range(12, 34)
			if img.get_pixel(ax, ay).a > 0.0 and img.get_pixel(ax + 1, ay + 1).a > 0.0:
				Px.rect(img, ax, ay, 2, 2, Color.html("d9483b"))
				Px.px(img, ax, ay, Color.html("f07a5e"))
	return Px.outline(img)


static func bush(variant: int) -> Image:
	var img := Px.new_img(22, 18)
	var cols := [Color.html("9bd35a"), Color.html("64b048"), Color.html("428c40"), Color.html("2f6c3a")]
	blob(img, [Vector3(8, 10, 6), Vector3(14, 10, 6), Vector3(11, 7, 6)], cols, 40 + variant)
	if variant % 2 == 1:
		for pv in [Vector2i(6, 9), Vector2i(12, 6), Vector2i(15, 11), Vector2i(9, 12)]:
			var pp: Vector2i = pv
			img.set_pixel(pp.x, pp.y, Color.html("e8506a"))
	return Px.outline(img)


static func rock(variant: int) -> Image:
	var img := Px.new_img(18, 14)
	var cols := [Color.html("d3d6dc"), Color.html("a9aeb8"), Color.html("848a98"), Color.html("666b7a")]
	var circles := [Vector3(7, 8, 5), Vector3(11, 7, 5)]
	if variant % 2 == 1:
		circles = [Vector3(8, 8, 5), Vector3(11, 9, 4)]
	blob(img, circles, cols, 70 + variant)
	for x in 18:
		img.set_pixel(x, 12, Color(0, 0, 0, 0))
		img.set_pixel(x, 13, Color(0, 0, 0, 0))
	return Px.outline(img)


# ---------------------------------------------------------------- 房子与栅栏

static func house() -> Image:
	var img := Px.new_img(96, 84)
	var wall := Color.html("dba66b")
	var wall_l := Color.html("e8b97f")
	var wall_d := Color.html("b98350")
	var post := Color.html("8f5e36")
	for y in range(40, 80):
		for x in range(6, 90):
			var c := wall
			var plank := (y - 40) / 6
			if (y - 40) % 6 == 5:
				c = wall_d
			elif Px.h2((x + plank * 5) / 11, plank) % 4 == 0:
				c = wall_l
			elif (x + plank * 5) % 11 == 0:
				c = wall_d
			if x < 9 or x >= 87:
				c = post
			img.set_pixel(x, y, c)
	# 石头地基
	for y in range(76, 80):
		for x in range(6, 90):
			var c := Color.html("a9aeb8")
			if y == 79 or (x + (y / 2) * 4) % 8 == 0:
				c = Color.html("7d8392")
			elif y == 76:
				c = Color.html("c9cdd6")
			img.set_pixel(x, y, c)
	# 烟囱
	for y in range(1, 16):
		for x in range(68, 78):
			var c := Color.html("b5654a")
			if (y % 3 == 0) or ((x + (y / 3) * 3) % 6 == 0):
				c = Color.html("8e4a38")
			if y < 3:
				c = Color.html("7d8392")
			img.set_pixel(x, y, c)
	# 屋顶
	var roof := Color.html("c8553d")
	var roof_l := Color.html("e07a55")
	var roof_d := Color.html("9b3b30")
	for y in range(6, 46):
		var inset := 0
		if y < 9:
			inset = 9 - y
		for x in range(1 + inset, 95 - inset):
			var ry := y - 6
			var row := ry / 6
			var off := 4 if row % 2 == 1 else 0
			var c := roof
			if ry % 6 == 5:
				c = roof_d
			elif (x + off) % 8 == 0:
				c = roof_d
			elif ry % 6 == 0:
				c = roof_l
			if y < 9:
				c = roof_l
			if y >= 44:
				c = roof_d
			img.set_pixel(x, y, c)
	Px.rect(img, 6, 46, 84, 2, Color.html("96643c"))
	# 门
	Px.rect(img, 41, 54, 14, 26, post)
	Px.rect(img, 43, 56, 10, 24, Color.html("a8703f"))
	Px.rect(img, 43, 56, 10, 1, Color.html("c08a52"))
	Px.rect(img, 47, 56, 1, 24, Color.html("8a5a32"))
	Px.rect(img, 44, 59, 3, 6, Color.html("8a5a32"))
	Px.rect(img, 49, 59, 3, 6, Color.html("8a5a32"))
	Px.rect(img, 50, 68, 2, 2, Color.html("f2d06b"))
	# 窗
	for wx in [16, 66]:
		Px.rect(img, wx, 53, 16, 14, Color.html("f6efe0"))
		Px.rect(img, wx + 2, 55, 12, 10, Color.html("8fd0e8"))
		Px.rect(img, wx + 2, 55, 12, 3, Color.html("bfe6f2"))
		Px.rect(img, wx + 7, 55, 2, 10, Color.html("f6efe0"))
		Px.rect(img, wx + 2, 59, 12, 1, Color.html("f6efe0"))
		Px.rect(img, wx - 1, 67, 18, 2, Color.html("96643c"))
	return Px.outline(img)


## mask 位：1=上 2=右 4=下 8=左 有相邻栅栏。
static func fence(mask: int) -> Image:
	var img := Px.new_img(16, 18)
	var c1 := Color.html("d9b07a")
	var c2 := Color.html("b98a55")
	var c3 := Color.html("8f6238")
	if mask & 8:
		Px.rect(img, 0, 7, 7, 2, c1)
		Px.rect(img, 0, 9, 7, 1, c3)
		Px.rect(img, 0, 12, 7, 2, c1)
		Px.rect(img, 0, 14, 7, 1, c3)
	if mask & 2:
		Px.rect(img, 9, 7, 7, 2, c1)
		Px.rect(img, 9, 9, 7, 1, c3)
		Px.rect(img, 9, 12, 7, 2, c1)
		Px.rect(img, 9, 14, 7, 1, c3)
	if mask & 1:
		Px.rect(img, 7, 0, 2, 5, c2)
	if mask & 4:
		Px.rect(img, 7, 15, 2, 3, c2)
	Px.rect(img, 6, 4, 4, 12, c1)
	Px.rect(img, 9, 5, 1, 11, c2)
	Px.rect(img, 6, 15, 4, 1, c3)
	Px.rect(img, 6, 3, 4, 1, Color.html("ecc995"))
	return Px.outline(img)


# ---------------------------------------------------------------- 地面

## mask 位：1=上 2=右 4=下 8=左 有相邻耕地，用来决定哪一边画田埂。
static func soil(mask: int, wet: bool) -> Image:
	var img := Px.new_img(16, 16)
	var base := Color.html("b47a4c")
	var dark := Color.html("96623c")
	var light := Color.html("c99060")
	var rim := Color.html("7d5030")
	if wet:
		base = Color.html("74503a")
		dark = Color.html("5b3c2d")
		light = Color.html("8a6045")
		rim = Color.html("4a3026")
	var n := (mask & 1) != 0
	var e := (mask & 2) != 0
	var s := (mask & 4) != 0
	var w := (mask & 8) != 0
	for y in 16:
		for x in 16:
			var c := base
			var fy := (y + 1) % 4
			if fy == 3:
				c = dark
			elif fy == 0:
				c = light
			var hh := Px.h2(x + 31, y + 17) % 29
			if hh == 0:
				c = dark
			elif hh == 1:
				c = light
			if (not n and y == 0) or (not s and y == 15) or (not w and x == 0) or (not e and x == 15):
				c = rim
			var cx := -1
			var cy := -1
			if not n and not w:
				cx = 0
				cy = 0
				if x == 1 and y == 1:
					c = rim
			if x == cx and y == cy:
				continue
			if not n and not e:
				if x == 15 and y == 0:
					continue
				if x == 14 and y == 1:
					c = rim
			if not s and not w:
				if x == 0 and y == 15:
					continue
				if x == 1 and y == 14:
					c = rim
			if not s and not e:
				if x == 15 and y == 15:
					continue
				if x == 14 and y == 14:
					c = rim
			img.set_pixel(x, y, c)
	return img


static func shadow(w: int, h: int, alpha: float) -> Image:
	var img := Px.new_img(w, h)
	for y in h:
		for x in w:
			var dx := (x + 0.5 - w * 0.5) / (w * 0.5)
			var dy := (y + 0.5 - h * 0.5) / (h * 0.5)
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, Color(0.1, 0.12, 0.2, alpha))
	return img


# ---------------------------------------------------------------- 界面

static func ui_panel() -> Image:
	var img := Px.new_img(16, 16)
	var cols := [Color.html("5b3a21"), Color.html("e3ab6a"), Color.html("c98a4b"), Color.html("7a4a2a")]
	for y in 16:
		for x in 16:
			var d := mini(mini(x, y), mini(15 - x, 15 - y))
			var c := Color.html("f7e3b5")
			if d < 4:
				c = cols[d]
				if d == 1 and (x > y or 15 - x < 15 - y) and (x >= 15 - 1 or y >= 15 - 1):
					c = Color.html("a56a35")
			if d == 0 and (x == 0 or x == 15) and (y == 0 or y == 15):
				continue
			img.set_pixel(x, y, c)
	return img


static func ui_slot(selected: bool) -> Image:
	var img := Px.new_img(22, 22)
	for y in 22:
		for x in 22:
			var d := mini(mini(x, y), mini(21 - x, 21 - y))
			var c := Color.html("eccb92")
			if d == 0:
				c = Color.html("5b3a21")
			elif d == 1:
				c = Color.html("c98a4b")
				if selected:
					c = Color.html("fff6d8")
			elif d == 2:
				c = Color.html("b98350") if (x == 2 or y == 2) else Color.html("f7dfae")
				if selected:
					c = Color.html("e0553f")
			if d == 0 and (x == 0 or x == 21) and (y == 0 or y == 21):
				continue
			img.set_pixel(x, y, c)
	return img


static func cursor() -> Image:
	var img := Px.new_img(18, 18)
	var c := Color.html("fff6d8")
	for k in 4:
		for corner in [Vector2i(1, 1), Vector2i(16, 1), Vector2i(1, 16), Vector2i(16, 16)]:
			var cv: Vector2i = corner
			var sx := 1 if cv.x == 1 else -1
			var sy := 1 if cv.y == 1 else -1
			img.set_pixel(cv.x + sx * k, cv.y, c)
			img.set_pixel(cv.x, cv.y + sy * k, c)
	return Px.outline(img)


# ---------------------------------------------------------------- 预览图

static func sheet(images: Array, cols: int, cell: Vector2i, scale: int, bg: Color) -> Image:
	var rows := int(ceil(images.size() / float(cols)))
	var img := Image.create(cols * cell.x, rows * cell.y, false, Image.FORMAT_RGBA8)
	img.fill(bg)
	for i in images.size():
		var src: Image = images[i]
		var cx := (i % cols) * cell.x + (cell.x - src.get_width()) / 2
		var cy := (i / cols) * cell.y + (cell.y - src.get_height()) / 2
		Px.blit(img, src, cx, cy)
	img.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)
	return img

# ---------------------------------------------------------------- 信箱与室内

static func mailbox() -> Image:
	var img := Px.new_img(12, 18)
	Px.rect(img, 5, 8, 2, 10, P["w"])
	Px.rect(img, 6, 8, 1, 10, P["W"])
	Px.rect(img, 1, 2, 10, 7, P["r"])
	Px.rect(img, 1, 7, 10, 2, P["R"])
	Px.rect(img, 2, 1, 8, 1, P["r"])
	Px.rect(img, 3, 4, 5, 1, P["R"])
	Px.rect(img, 9, 0, 1, 4, P["y"])
	Px.rect(img, 9, 0, 2, 2, P["y"])
	return Px.outline(img)


## 木地板，w 和 h 是像素尺寸。
static func floor_wood(w: int, h: int) -> Image:
	var img := Px.new_img(w, h)
	var base := Color.html("c99766")
	var light := Color.html("d8a875")
	var dark := Color.html("a87a4e")
	for y in h:
		for x in w:
			var row := y / 8
			var off := 11 if row % 2 == 1 else 0
			var c := base
			if y % 8 == 7:
				c = dark
			elif (x + off) % 22 == 0:
				c = dark
			elif Px.h2((x + off) / 22, row) % 3 == 0:
				c = light
			if Px.h2(x, y) % 53 == 0:
				c = dark
			img.set_pixel(x, y, c)
	return img


## 室内的墙面，上沿有一条木饰边，下沿有踢脚线。
static func wall(w: int, h: int) -> Image:
	var img := Px.new_img(w, h)
	var base := Color.html("e9dcc0")
	var shade := Color.html("d6c6a4")
	for y in h:
		for x in w:
			var c := base
			if (x / 12) % 2 == 1:
				c = shade
			if y < 3:
				c = Color.html("8f5e36") if y < 2 else Color.html("6e4526")
			if y >= h - 4:
				c = Color.html("9a6a40") if y < h - 1 else Color.html("6e4526")
			img.set_pixel(x, y, c)
	return img


static func bed() -> Image:
	var img := Px.new_img(22, 34)
	var wood: Color = P["w"]
	var wood_d: Color = P["W"]
	Px.rect(img, 0, 0, 22, 34, wood)
	Px.rect(img, 0, 30, 22, 4, wood_d)
	Px.rect(img, 0, 0, 22, 2, Color.html("c08a52"))
	Px.rect(img, 2, 4, 18, 27, Color.html("f6efe6"))
	Px.rect(img, 4, 6, 14, 6, Color.html("ffffff"))
	Px.rect(img, 4, 11, 14, 1, Color.html("d6c8bd"))
	Px.rect(img, 2, 14, 18, 17, P["p"])
	Px.rect(img, 2, 14, 18, 2, Color.html("6f95d6"))
	Px.rect(img, 2, 28, 18, 3, P["P"])
	for x in range(4, 19, 4):
		Px.rect(img, x, 19, 2, 2, Color.html("6f95d6"))
		Px.rect(img, x + 2, 24, 2, 2, Color.html("6f95d6"))
	return Px.outline(img)


static func table() -> Image:
	var img := Px.new_img(26, 20)
	Px.rect(img, 2, 10, 3, 10, P["W"])
	Px.rect(img, 21, 10, 3, 10, P["W"])
	Px.rect(img, 0, 0, 26, 10, P["w"])
	Px.rect(img, 0, 0, 26, 2, Color.html("c08a52"))
	Px.rect(img, 0, 10, 26, 3, P["W"])
	# 桌上多摆的一副碗筷
	Px.rect(img, 5, 3, 6, 4, Color.html("f6efe6"))
	Px.rect(img, 6, 6, 4, 1, Color.html("d6c8bd"))
	Px.rect(img, 15, 3, 6, 4, Color.html("f6efe6"))
	Px.rect(img, 16, 6, 4, 1, Color.html("d6c8bd"))
	Px.rect(img, 12, 2, 1, 6, P["H"])
	return Px.outline(img)


static func rug(w: int, h: int) -> Image:
	var img := Px.new_img(w, h)
	for y in h:
		for x in w:
			var d := mini(mini(x, y), mini(w - 1 - x, h - 1 - y))
			var c := Color.html("b5493f")
			if d == 0:
				c = Color.html("8a342f")
			elif d == 2:
				c = Color.html("e8c46a")
			elif (x + y) % 8 == 0 or (x - y + 800) % 8 == 0:
				c = Color.html("c9605a")
			img.set_pixel(x, y, c)
	return img


static func window(night: bool) -> Image:
	var img := Px.new_img(18, 16)
	Px.rect(img, 0, 0, 18, 16, Color.html("8f5e36"))
	Px.rect(img, 2, 2, 14, 12, Color.html("2c3566") if night else Color.html("8fd0e8"))
	if not night:
		Px.rect(img, 2, 2, 14, 4, Color.html("bfe6f2"))
	Px.rect(img, 8, 2, 2, 12, Color.html("8f5e36"))
	Px.rect(img, 2, 7, 14, 1, Color.html("8f5e36"))
	Px.rect(img, 0, 14, 18, 2, Color.html("6e4526"))
	return img


static func doormat() -> Image:
	var img := Px.new_img(20, 8)
	Px.rect(img, 0, 0, 20, 8, Color.html("7d9a52"))
	Px.rect(img, 0, 0, 20, 1, Color.html("5e7a3c"))
	Px.rect(img, 0, 7, 20, 1, Color.html("5e7a3c"))
	for x in range(2, 19, 4):
		Px.rect(img, x, 3, 2, 2, Color.html("9bb86a"))
	return img
