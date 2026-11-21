class_name RoomArt
extends RefCounted
## 农舍的地板和后墙，代码画（决策 148）：屋子跟着扩建变大，墙和地能换。
## 颜色取 data/palette.json 里 Blender 物件用的那几段，和家具是一套。
## 花纹都按老屋的像素坐标取随机数，屋子扩了，老屋那一块的木板纹不变。

const TS := 16
const WALL_H := 32

const WOOD_DK: Array[String] = ["8a5a36", "6b4226", "4a2c18"]
const FLOOR_LOOKS: Dictionary[String, Array] = {
	"plank": [["a87a50", "8f6540"], ["9c7048", "845c3a"], "6b4226"],
	"dark": [["7a4e2e", "64402a"], ["6e4628", "5a3822"], "3e2414"],
}
const PAPER := ["fbeec4", "ecd9a0", "c9b47c"]
const PAPER_NIGHT := ["5b6aa0", "3f4a80", "2c3566"]


## cols×rows 格，老屋往东挪了 ox 格。windows 是窗所在的列（老屋坐标，窗占两列），door_x 是门的两列。
static func room(cols: int, rows: int, ox: int, wall: String, floor_look: String, windows: Array[int],
		door_x: Array[int], night: bool) -> Image:
	var img := Image.create(cols * TS, rows * TS, false, Image.FORMAT_RGBA8)
	_floor(img, cols, rows, ox, floor_look)
	_wall(img, cols, ox, wall)
	for w in windows:
		_window(img, (w + ox) * TS + TS - 14, 6, night)
	_mats(img, rows, ox, door_x)
	_edges(img, cols, rows, ox, door_x)
	return img


## 铺子和公所的里间（决策 161）：cols×rows 格，不带农舍那张桌下的席子。
## 后墙每隔几格一根立柱，windows 是窗所在的列（窗占两列），door_x 是门的两列。
static func shop(cols: int, rows: int, wall: String, floor_look: String, windows: Array[int],
		door_x: Array[int], night: bool) -> Image:
	var img := Image.create(cols * TS, rows * TS, false, Image.FORMAT_RGBA8)
	_floor(img, cols, rows, 0, floor_look)
	var posts: Array[int] = []
	for p in range(0, cols * TS - 4, 6 * TS):
		posts.append(p)
	posts.append(cols * TS - 4)
	_wall(img, cols, 0, wall, posts)
	for w in windows:
		_window(img, w * TS + 2, 6, night)
	var straw := [_c("efd890"), _c("d4b868"), _c("a89048")]
	var dx := door_x[0] * TS + 3
	var dy := rows * TS - 13
	Px.rect(img, dx, dy, 26, 10, straw[0])
	for x in range(dx, dx + 26):
		if (x - dx) % 3 == 0:
			Px.rect(img, x, dy + 1, 1, 8, straw[1])
	Px.rect(img, dx, dy + 5, 26, 1, _c("c08a52"))
	_edges(img, cols, rows, 0, door_x)
	return img


static func _c(h: String) -> Color:
	return Color.html(h)


# ---------------------------------------------------------------- 地

static func _floor(img: Image, cols: int, rows: int, ox: int, look: String) -> void:
	var w := cols * TS
	var h := rows * TS
	match look:
		"brick":
			img.fill_rect(Rect2i(0, WALL_H, w, h - WALL_H), _c("6e7270"))
			for y in range(WALL_H, h, 8):
				var row := (y - WALL_H) / 8
				var shift := 8 if row % 2 == 1 else 0
				for x in range(-16, w, 16):
					var bx := x + shift
					var rx := bx - ox * TS
					var tone := Px.h2(rx / 16 + 50, row) % 5
					var base := _c("a3a7a4") if tone < 2 else (_c("969a97") if tone < 4 else _c("8a8e8b"))
					for yy in range(y, mini(y + 7, h)):
						for xx in range(maxi(bx, 0), mini(bx + 15, w)):
							img.set_pixel(xx, yy, base)
					for xx in range(maxi(bx, 0), mini(bx + 15, w)):
						if y < h:
							img.set_pixel(xx, y, base.lightened(0.12))
					if Px.h2(rx, row + 9) % 4 == 0:
						Px.px(img, bx + 4 + Px.h2(rx, row) % 7, y + 3, _c("767c7b"))
		"mat":
			var straw := [_c("efd890"), _c("d4b868"), _c("a89048")]
			img.fill_rect(Rect2i(0, WALL_H, w, h - WALL_H), straw[0])
			for y in range(WALL_H, h):
				for x in w:
					var rx := x - ox * TS
					if rx % 3 == 0 and Px.h2(rx, y / 2) % 10 < 7:
						img.set_pixel(x, y, straw[1])
				if (y - WALL_H) % 24 == 23:
					for x in w:
						img.set_pixel(x, y, straw[2])
			# 竹席一张张拼起来，接缝是深一点的竖线
			for x in range(0, w):
				if (x - ox * TS) % 48 == 0:
					for y in range(WALL_H, h):
						img.set_pixel(x, y, straw[2])
		_:
			var pal: Array = FLOOR_LOOKS.get(look, FLOOR_LOOKS["plank"])
			var gap := _c(str(pal[2]))
			img.fill_rect(Rect2i(0, WALL_H, w, h - WALL_H), gap)
			var row := 0
			for y in range(WALL_H, h, 8):
				# 每一行都从老屋西边八格开始排，西边扩出来那一截也有木板，老屋那一块的接缝不跟着挪
				var rx := -(Px.h2(row, 3) % 24) - 8 * TS
				while rx < (cols - ox) * TS:
					var length := 29 + Px.h2(rx, row + 17) % 26
					var pair: Array = pal[0] if Px.h2(rx + 5, row) % 10 < 6 else pal[1]
					var base := _c(str(pair[0]))
					var grain := _c(str(pair[1]))
					var x0 := rx + ox * TS
					for yy in range(y, mini(y + 7, h)):
						for xx in range(maxi(x0, 0), mini(x0 + length - 1, w)):
							var c := base
							var gx := xx - ox * TS
							if Px.h2(gx / 5 + (yy * 3) % 5, yy) % 100 < 14 and Px.h2(gx, yy) % 100 < 85:
								c = grain
							img.set_pixel(xx, yy, c)
					rx += length
				row += 1


# ---------------------------------------------------------------- 墙

static func _wall(img: Image, cols: int, ox: int, look: String, custom_posts: Array[int] = []) -> void:
	var w := cols * TS
	var dk := [_c(WOOD_DK[0]), _c(WOOD_DK[1]), _c(WOOD_DK[2])]
	for y in range(3, WALL_H - 4):
		for x in w:
			img.set_pixel(x, y, _wall_px(x - ox * TS, y, look))
	# 顶上的梁、底下的踢脚
	img.fill_rect(Rect2i(0, 0, w, 3), dk[1])
	img.fill_rect(Rect2i(0, 0, w, 1), _c("391e24"))
	img.fill_rect(Rect2i(0, 3, w, 1), dk[2])
	img.fill_rect(Rect2i(0, WALL_H - 4, w, 4), dk[1])
	img.fill_rect(Rect2i(0, WALL_H - 4, w, 1), dk[0])
	img.fill_rect(Rect2i(0, WALL_H - 1, w, 1), dk[2])
	# 立柱：老屋原来那四根，扩出来的每一段两头各一根
	var posts: Array[int] = [0, 62, 120, 188]
	if cols - ox > 12:
		posts.append_array([250, (cols - ox) * TS - 4])
	if ox > 0:
		posts.append_array([-ox * TS, -ox * TS / 2 - 2])
	if not custom_posts.is_empty():
		posts = custom_posts
	for p in posts:
		var x := p + ox * TS
		img.fill_rect(Rect2i(clampi(x, 0, w - 4), 3, 4, WALL_H - 6), dk[1])
		img.fill_rect(Rect2i(clampi(x, 0, w - 4), 3, 1, WALL_H - 6), dk[0])


static func _wall_px(x: int, y: int, look: String) -> Color:
	match look:
		"timber":
			if x % 7 == 0:
				return _c("6e4526")
			var board := Px.h2(x / 7, 3) % 3
			var base := _c("c08a52") if board == 0 else (_c("b07e4a") if board == 1 else _c("9a6a40"))
			if Px.h2(x / 7 + y / 3, y) % 100 < 6:
				return _c("9a6a40")
			return base
		"indigo":
			var cx := posmod(x, 12)
			var cy := posmod(y - 3 + (6 if (x / 12) % 2 == 1 else 0), 12)
			var d := absi(cx - 6) + absi(cy - 6)
			if d == 0 or (d == 2 and (cx == 6 or cy == 6)):
				return _c("e8eef6")
			if d == 1:
				return _c("b8c8de")
			return _c("34507e") if Px.h2(x / 2, y / 2) % 9 == 0 else _c("3d5a8a")
		"stone":
			var srow := y / 8
			var off := (srow % 2) * 8
			if y % 8 == 7 or posmod(x + off, 16) == 15:
				return _c("5a5e60")
			var tone := Px.h2((x + off) / 16, srow) % 4
			return [_c("8a8f90"), _c("7c8182"), _c("969b9c"), _c("848a8b")][tone]
		"bamboo":
			var band := (y - 3) / 4
			var off := (band % 2) * 6
			var k := posmod(x + off, 12)
			if (y - 3) % 4 == 3:
				return _c("8a7a40")
			if k == 0:
				return _c("a89048")
			return _c("d8cc84") if (y - 3) % 4 == 0 else _c("c8b870")
		_:
			var n := Px.h2(x / 7, y / 7) % 100
			if n > 70 and Px.h2(x / 3, y / 3) % 3 != 0:
				return _c("fbf7ec")
			if Px.h2(x, y) % 97 == 0:
				return _c("c4bfb2")
			return _c("ebe5d6")


## 木格窗：深色框、糊纸、两横三竖的格子，下面一条窗台。x0 是左边，宽 28。
static func _window(img: Image, x0: int, y0: int, night: bool) -> void:
	var dk := _c(WOOD_DK[1])
	var paper: Array = PAPER_NIGHT if night else PAPER
	Px.rect(img, x0, y0, 28, 18, dk)
	Px.rect(img, x0 + 2, y0 + 2, 24, 14, _c(paper[1]))
	Px.rect(img, x0 + 2, y0 + 2, 24, 2, _c(paper[0]))
	for i in [8, 13, 19]:
		Px.rect(img, x0 + i, y0 + 2, 1, 14, dk)
	for j in [6, 11]:
		Px.rect(img, x0 + 2, y0 + j, 24, 1, dk)
	Px.rect(img, x0 - 3, y0 + 18, 34, 2, _c("c08a52"))
	Px.rect(img, x0 - 3, y0 + 20, 34, 1, _c("6e4526"))


# ---------------------------------------------------------------- 席子和边

## 桌子底下的草席、门口的草垫，都在老屋原来的位置。
static func _mats(img: Image, rows: int, ox: int, door_x: Array[int]) -> void:
	var straw := [_c("efd890"), _c("d4b868"), _c("a89048")]
	var wood := _c("c08a52")
	var x0 := 92 + ox * TS
	Px.rect(img, x0, 52, 72, 40, straw[0])
	for k in 9:
		Px.rect(img, x0, 54 + k * 4 + k / 2, 72, 1, wood)
	for x in range(x0, x0 + 72):
		if (x - x0) % 3 == 0:
			for y in range(52, 92):
				if Px.h2(x, y / 2) % 10 < 6 and img.get_pixel(x, y) == straw[0]:
					img.set_pixel(x, y, straw[1])
	Px.rect(img, x0, 52, 1, 40, _c(WOOD_DK[1]))
	Px.rect(img, x0 + 71, 52, 1, 40, _c(WOOD_DK[1]))
	var dx := (door_x[0] + ox) * TS + 3
	var dy := rows * TS - 13
	Px.rect(img, dx, dy, 26, 10, straw[0])
	for x in range(dx, dx + 26):
		if (x - dx) % 3 == 0:
			Px.rect(img, x, dy + 1, 1, 8, straw[1])
	Px.rect(img, dx, dy + 5, 26, 1, wood)


static func _edges(img: Image, cols: int, rows: int, ox: int, door_x: Array[int]) -> void:
	var dk := _c(WOOD_DK[1])
	var h := rows * TS
	var w := cols * TS
	img.fill_rect(Rect2i(0, WALL_H, 2, h - WALL_H), dk)
	img.fill_rect(Rect2i(w - 2, WALL_H, 2, h - WALL_H), dk)
	var gap0 := (door_x[0] + ox) * TS
	var gap1 := (door_x[door_x.size() - 1] + ox + 1) * TS
	for x in w:
		if x < gap0 or x >= gap1:
			img.set_pixel(x, h - 2, dk)
			img.set_pixel(x, h - 1, _c(WOOD_DK[2]))


# ---------------------------------------------------------------- 图标

## 墙纸、地板的背包图标：一块小样，外面一圈框。
static func swatch(kind: String, look: String) -> Image:
	var big := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var ground := Image.create(32, 64, false, Image.FORMAT_RGBA8)
	if kind != "paper":
		_floor(ground, 2, 4, 0, look)
	for y in 14:
		for x in 14:
			var c := _wall_px(x * 2, y + 6, look) if kind == "paper" else ground.get_pixel(x + 2, y + 34)
			big.set_pixel(x + 1, y + 1, c)
	return Px.outline(big)
