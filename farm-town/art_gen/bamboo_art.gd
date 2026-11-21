class_name BambooArt
extends RefCounted
## 竹海的竹子、路牌石和酒碗（决策 126）。颜色只从 palette.json 取。


const CULM := "k"
const CULM_DK := "K"
const LEAF := "l"
const LEAF_DK := "L"
const STONE := "m"
const STONE_DK := "M"
const INK := "e"
const CLAY := "w"


## 一丛竹子。0 高的三根，1 中等的两根、梢头偏着，2 矮的两根（盖在路和溪边上用）。
## 竿是青玉色，左边亮右边暗，一节一节，节上有深色的环和一个小凸点；梢头和上面几个节上长出一簇簇下垂的细叶。
## 整张描一圈深绿的边，铺在亮草地上才站得出来。
static func stalk(kind: int) -> Image:
	if kind == 2:
		var img := Px.new_img(18, 30)
		_culm(img, 6, 30, 12, 0, 8, 3)
		_culm(img, 12, 30, 7, 1, 8, 5)
		return Px.outline(img)
	if kind == 1:
		var img := Px.new_img(24, 44)
		_culm(img, 8, 44, 4, -2, 9, 11)
		_culm(img, 16, 44, 14, 1, 9, 13)
		return Px.outline(img)
	var img := Px.new_img(26, 54)
	_culm(img, 5, 54, 12, -1, 9, 21)
	_culm(img, 12, 54, 2, 0, 9, 22)
	_culm(img, 19, 54, 16, 2, 9, 23)
	return Px.outline(img)


## 给旧的调用留着：一丛高竹子。
static func clump() -> Image:
	return stalk(0)


const _JADE_HI := "9be0a8"
const _JADE := "52ad74"
const _JADE_DK := "2f7c58"
const _NODE := "1f5c42"
const _BLADE_HI := "9fdc6e"
const _BLADE := "55a74e"
const _BLADE_DK := "357c43"


## 一根竿：从 bottom 往上画到 top，三像素宽，最上面一小段收成两像素；上端往 lean 那边偏一点。
## seg 是两节之间的像素数，seed 让每根的叶子不一样。
static func _culm(img: Image, cx: int, bottom: int, top: int, lean: int, seg: int, seed: int) -> void:
	var hi := Color.html(_JADE_HI)
	var mid := Color.html(_JADE)
	var dk := Color.html(_JADE_DK)
	var node := Color.html(_NODE)
	var span := float(bottom - top)
	for y in range(top, bottom):
		var t := 1.0 - float(y - top) / span
		var shift := roundi(float(lean) * t * t)
		var x := cx + shift
		if y < top + 7:
			Px.px(img, x, y, hi)
			Px.px(img, x + 1, y, dk)
		else:
			Px.px(img, x - 1, y, hi)
			Px.px(img, x, y, mid)
			Px.px(img, x + 1, y, dk)
		if (bottom - y) % seg == 0 and y > top + 3:
			# 节：一道深色的环，两边各凸出一点
			Px.px(img, x - 2, y, node)
			Px.px(img, x - 1, y, node)
			Px.px(img, x, y, node)
			Px.px(img, x + 1, y, node)
			Px.px(img, x + 2, y, node)
			# 节上长枝的地方：越往上越密
			if y < top + 26:
				var face := -1 if (y + seed) % 2 == 0 else 1
				_leaf(img, x + (face if face > 0 else -2), y - 1, face, 6 + (seed + y) % 3)
				_leaf(img, x + (face if face > 0 else -2), y - 3, face, 4)
	var tip := cx + roundi(float(lean))
	_leaf(img, tip - 1, top + 1, -1, 7)
	_leaf(img, tip + 1, top + 1, 1, 7)
	_leaf(img, tip, top - 1, -1, 5)
	_leaf(img, tip + 1, top - 1, 1, 5)
	_leaf(img, tip, top + 4, -1, 6)
	_leaf(img, tip + 1, top + 5, 1, 6)


## 一片竹叶：先平着往外伸，后半段往下垂，两像素厚，尖上收成一像素；上沿一道亮线。
static func _leaf(img: Image, x: int, y: int, face: int, length: int) -> void:
	var body := Color.html(_BLADE)
	var dark := Color.html(_BLADE_DK)
	var light := Color.html(_BLADE_HI)
	for i in length:
		var drop := int(float(i * i) / float(length) * 0.7)
		var px := x + face * (i + 1)
		var py := y + drop
		if i >= length - 2:
			Px.px(img, px, py, dark)
		else:
			Px.px(img, px, py, body)
			Px.px(img, px, py + 1, dark)
			if i > 0 and i % 2 == 1:
				Px.px(img, px, py - 1, light)


## 竹林的地：整张图盖一层树荫（深青绿，一块一块的亮斑漏下来），再撒落叶。
## forest 每格一个字节，1 是竹林里的格子（要盖荫），0 是路、水、空地（不盖）。返回和地图一样大的透明图。
static func floor_shade(forest: PackedByteArray, cols: int, rows: int) -> Image:
	var ts := 16
	var img := Px.new_img(cols * ts, rows * ts)
	var shade := Color(0.10, 0.30, 0.24, 0.34)
	var deep := Color(0.06, 0.22, 0.2, 0.34)
	var litter := Color(0.78, 0.82, 0.36, 0.85)
	var litter_dk := Color(0.28, 0.46, 0.22, 0.9)
	for ty in rows:
		for tx in cols:
			if forest[ty * cols + tx] != 1:
				continue
			for by in range(0, ts, 2):
				for bx in range(0, ts, 2):
					var gx := tx * ts + bx
					var gy := ty * ts + by
					var n := Px.h2(gx / 4, gy / 4) % 100
					if n < 14:
						continue
					var c := deep if n > 70 else shade
					for dy in 2:
						for dx in 2:
							Px.px(img, gx + dx, gy + dy, c)
			for k in 3:
				var h := Px.h2(tx * 7 + k, ty * 5 + 1)
				var px := tx * ts + h % 15
				var py := ty * ts + (h / 16) % 14
				var c2 := litter if h % 3 == 0 else litter_dk
				Px.px(img, px, py, c2)
				Px.px(img, px + 1, py + 1, c2)
	return img


## 路边的记路石，12×14。上面一道刻痕，不是字。
static func marker() -> Image:
	var img := Px.new_img(12, 14)
	var stone: Color = Palette.c(STONE)
	var dark: Color = Palette.c(STONE_DK)
	Px.rect(img, 2, 4, 8, 8, stone)
	Px.rect(img, 3, 3, 6, 1, stone)
	Px.rect(img, 1, 6, 1, 5, dark)
	Px.rect(img, 10, 6, 1, 5, dark)
	Px.rect(img, 3, 12, 6, 1, dark)
	Px.rect(img, 4, 6, 4, 1, Palette.c(INK))
	return Px.outline(img)


## 狌狌的空碗，12×8。
static func bowl() -> Image:
	var img := Px.new_img(12, 8)
	var clay: Color = Palette.c(CLAY)
	var dark: Color = Palette.c("K")
	Px.rect(img, 2, 3, 8, 3, clay)
	Px.rect(img, 1, 4, 1, 2, dark)
	Px.rect(img, 10, 4, 1, 2, dark)
	Px.rect(img, 3, 6, 6, 1, dark)
	Px.rect(img, 4, 2, 4, 1, clay)
	return Px.outline(img)
