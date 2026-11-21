class_name WildArt
extends RefCounted
## 大地图用的野外素材：高低地的崖面和石阶、老树、松、柳、茶丛、荷、芦苇、林下的小东西。
## 都是代码画的。颜色跟 GroundArt 的草色、PixelArt 的树一套。

const TS := 16

## 崖面的样子：0 茶山的干砌石墙，1 山石，2 土坎
const WALL := 0
const ROCK := 1
const EARTH := 2

const FACE_COLORS: Array = [
	["d6ccb2", "b9ad92", "94886e", "6e634f"],
	["b4b0a6", "969188", "746f68", "524d48"],
	["c9925a", "a8733f", "83562e", "5e3b20"],
]
const STEP_COLORS: Array = ["dcd6c8", "bdb7aa", "8f897e", "6a655c"]

const LEAF_SETS: Array = [
	[["a9d95a", "78bd48", "4f9a42", "35763d"], ["8fcf6a", "5fae56", "3f8a50", "2c6747"], ["9ad070", "66ac52", "45884a", "2f6642"]],
	[["9ccf58", "68b046", "3f8a3e", "2a6a38"], ["7fc264", "4f9e50", "34804a", "245f42"], ["8cc860", "5aa24c", "3a7e44", "285c3c"]],
	[["f6cc62", "e6a23e", "c47830", "8f4e28"], ["ecdc70", "cdbb4a", "a0963a", "706c30"], ["f4a070", "dc6e4a", "b44a3a", "823230"]],
]
const PINE_SETS: Array = [
	["86bc72", "568f5a", "3a6f4c", "27503e"],
	["7fb48a", "4f8a6a", "356a58", "244c46"],
]
const WILLOW: Array = ["d4ea92", "b6d874", "8fbc56", "64964a"]
const WILLOW_FALL: Array = ["f2e08a", "dcc462", "b49a48", "86723a"]
const BARK: Array = ["a06a3c", "84532d", "653d20"]
const BARK_OLD: Array = ["8f7458", "6f573f", "4d3b2b"]
const SNOW := "f4f8fb"


# ---------------------------------------------------------------- 高低地

## 把崖面、崖沿、石阶、瀑布画成一张和地图一样大的透明图，盖在地面贴图上面。
## face：0 不是崖面；否则是从崖沿往下数第几格。rim：位 1 北边低、2 西边低、4 东边低。
## stair：1 是石阶。fall：1 是瀑布。四张表都按格子存。
static func relief(cols: int, rows: int, face: PackedByteArray, rim: PackedByteArray,
		stair: PackedByteArray, fall: PackedByteArray, season: int, style: int) -> Image:
	var img := Px.new_img(cols * TS, rows * TS)
	var grass: Array = GroundArt.SEASON_GRASS[clampi(season, 0, 3)]
	var g_mid := Color.html(str(grass[1]))
	var g_dark := Color.html(str(grass[2]))
	var g_edge := Color.html(str(grass[5]))
	var fc: Array[Color] = []
	for hex: String in FACE_COLORS[clampi(style, 0, 2)]:
		fc.append(Color.html(hex))
	var sc: Array[Color] = []
	for hex: String in STEP_COLORS:
		sc.append(Color.html(hex))
	var w_lt := Color.html("c4e9f6")
	var w_md := Color.html("62b6e4")
	var w_dk := Color.html("3d8cc8")
	var w_edge := Color.html("2f73ad")
	for ty in rows:
		for tx in cols:
			var i := ty * cols + tx
			var d := face[i]
			var x0 := tx * TS
			var y0 := ty * TS
			if d > 0:
				var last := ty + 1 >= rows or face[i + cols] == 0
				var left_end := tx == 0 or (face[i - 1] == 0)
				var right_end := tx == cols - 1 or (face[i + 1] == 0)
				if stair[i] == 1:
					var l_wall := tx == 0 or stair[i - 1] == 0
					var r_wall := tx == cols - 1 or stair[i + 1] == 0
					for py in TS:
						var k := (y0 + py) % 4
						var c: Color = sc[0] if k == 0 else (sc[2] if k == 3 else sc[1])
						for px in TS:
							var cc := c
							if (l_wall and px < 2) or (r_wall and px > 13):
								cc = sc[3] if (px == 0 or px == 15) else sc[2]
							img.set_pixel(x0 + px, y0 + py, cc)
					continue
				if fall[i] == 1:
					for py in TS:
						for px in TS:
							var gx := x0 + px
							var streak := Px.h2(gx, 3) % 4
							var c := w_md
							if streak == 0:
								c = w_lt if (Px.h2(gx, (y0 + py) / 5) % 3) != 0 else w_md
							elif streak == 3:
								c = w_dk
							if (left_end and px == 0) or (right_end and px == 15):
								c = w_edge
							if last and py >= 12 and Px.h2(gx / 2, y0 + py) % 3 != 0:
								c = Color.WHITE if py >= 14 else w_lt
							img.set_pixel(gx, y0 + py, c)
					continue
				for py in TS:
					for px in TS:
						var gx := x0 + px
						var gy := y0 + py
						var c := _face_px(gx, gy, style, fc)
						if d == 1:
							var lip := 2 + Px.h2(gx / 3, ty) % 2
							if py < lip:
								c = g_dark if py < lip - 1 else g_edge
							elif py == lip:
								c = fc[3]
						if last and py >= 14:
							c = fc[3]
						if (left_end and px == 0) or (right_end and px == 15):
							c = fc[3]
						img.set_pixel(gx, gy, c)
				continue
			# 崖面底下一格的阴影
			if ty > 0 and face[i - cols] > 0 and stair[i - cols] == 0:
				for py in 3:
					for px in TS:
						img.set_pixel(x0 + px, y0 + py, Color(0.1, 0.12, 0.2, 0.26 - py * 0.07))
			var bits := rim[i]
			if bits == 0:
				continue
			if stair[i] == 1:
				continue
			if bits & 1 != 0:
				for px in TS:
					var deep := 2 + Px.h2((x0 + px) / 4, ty + 7) % 2
					for py in deep + 2:
						var c := fc[3] if py < deep - 1 else (fc[2] if py < deep else (g_edge if py == deep else g_dark))
						img.set_pixel(x0 + px, y0 + py, c)
			if bits & 2 != 0:
				for py in TS:
					var wide := 4 + Px.h2(3, (y0 + py) / 4) % 2
					for px in wide + 2:
						var c := fc[3] if px < 1 else (fc[2] if px < wide - 1 else (fc[1] if px < wide else (g_edge if px == wide else g_dark)))
						img.set_pixel(x0 + px, y0 + py, c)
			if bits & 4 != 0:
				for py in TS:
					var wide := 4 + Px.h2(5, (y0 + py) / 4) % 2
					for px in wide + 2:
						var c := fc[3] if px < 1 else (fc[2] if px < wide - 1 else (fc[1] if px < wide else (g_edge if px == wide else g_mid)))
						img.set_pixel(x0 + TS - 1 - px, y0 + py, c)
	return img


static func _face_px(gx: int, gy: int, style: int, fc: Array[Color]) -> Color:
	if style == WALL:
		var row := gy / 5
		var shift := (Px.h2(row, 9) % 5) + (4 if row % 2 == 1 else 0)
		var sx := gx + shift
		var stone := sx / 7
		if gy % 5 == 4 or sx % 7 == 0:
			return fc[3]
		var tone := Px.h2(stone, row) % 6
		if gy % 5 == 0:
			return fc[0]
		if tone == 0:
			return fc[0]
		if tone == 5:
			return fc[2]
		return fc[1]
	if style == EARTH:
		var n := Px.h2(gx / 3, gy / 2) % 7
		if n == 0:
			return fc[0]
		if n >= 5:
			return fc[2]
		if Px.h2(gx, gy) % 23 == 0:
			return fc[3]
		return fc[1]
	var slab := Px.h2(gx / 5 + (gy / 9) * 3, gy / 9) % 6
	if Px.h2(gx / 5 + (gy / 9) * 3, 77) % 4 == 0 and (gx + (gy / 9) * 2) % 5 == 0:
		return fc[3]
	if gy % 9 == 8 and Px.h2(gx / 4, gy) % 3 != 0:
		return fc[3]
	if slab == 0:
		return fc[0]
	if slab >= 4:
		return fc[2]
	return fc[1]


## 浅水里踩脚的石头，14×9。
static func stepping(variant: int) -> Image:
	var img := Px.new_img(14, 9)
	var lt := Color.html("c9cdc8")
	var md := Color.html("a3a8a5")
	var dk := Color.html("7a807e")
	var rx := 6.0 - (variant % 2)
	for y in 8:
		for x in 14:
			var p := Vector2((x + 0.5 - 7.0) / rx, (y + 0.5 - 4.0) / 3.4)
			if p.length() >= 1.0:
				continue
			var c := md
			if p.y < -0.25 and p.x < 0.4:
				c = lt
			if p.y > 0.45:
				c = dk
			img.set_pixel(x, y, c)
	return Px.outline(img)


# ---------------------------------------------------------------- 树

static func _cols(hexes: Array) -> Array[Color]:
	var out: Array[Color] = []
	for hex: String in hexes:
		out.append(Color.html(hex))
	return out


## 一团阔叶树冠：先铺底色，再叠带高光的叶簇。和 PixelArt.round_tree 一个画法，大小随参数。
static func _crown(img: Image, rng: RandomNumberGenerator, center: Vector2, rx: float, ry: float,
		cols: Array[Color], clump_r: float) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var lobes: Array[Vector3] = [Vector3(center.x, center.y, minf(rx, ry) * 0.92)]
	var n_lobes := 5 + int(rx / 9.0)
	for k in n_lobes:
		var a := TAU * k / n_lobes + rng.randf_range(-0.25, 0.25)
		var r := rng.randf_range(0.36, 0.5) * minf(rx, ry)
		var at := center + Vector2(cos(a) * (rx - r), sin(a) * (ry - r))
		lobes.append(Vector3(at.x, at.y, r))
	for y in range(maxi(0, int(center.y - ry) - 1), mini(h, int(center.y + ry) + 2)):
		for x in range(maxi(0, int(center.x - rx) - 1), mini(w, int(center.x + rx) + 2)):
			var inside := false
			for lobe in lobes:
				if Vector2(x + 0.5 - lobe.x, y + 0.5 - lobe.y).length() < lobe.z:
					inside = true
					break
			if not inside:
				continue
			var n := Vector2((x + 0.5 - center.x) / rx, (y + 0.5 - center.y) / ry)
			img.set_pixel(x, y, cols[3] if n.dot(Vector2(0.5, 0.86)) > 0.42 else cols[2])
	var count := int(rx * ry / (clump_r * clump_r) * 1.5)
	for k in count:
		var a := rng.randf_range(0.0, TAU)
		var m := sqrt(rng.randf())
		var cc := center + Vector2(cos(a) * rx * m * 0.9, sin(a) * ry * m * 0.9)
		var r := clump_r * rng.randf_range(0.8, 1.15)
		var lit := (cc.x - center.x) / rx * 0.5 + (cc.y - center.y) / ry * 0.86
		var sh := 0 if lit < 0.12 else 1
		for y in range(int(cc.y - r), int(cc.y + r) + 1):
			for x in range(int(cc.x - r), int(cc.x + r) + 1):
				if x < 0 or y < 0 or x >= w or y >= h or img.get_pixel(x, y).a == 0.0:
					continue
				var p := Vector2(x + 0.5, y + 0.5)
				if p.distance_to(cc) >= r:
					continue
				if p.distance_to(cc + Vector2(-1.5, -1.5)) >= r - 1.0:
					continue
				var col: Color = cols[1 + sh]
				if p.distance_to(cc + Vector2(-2.0, -2.0)) < r - 2.5 and p.distance_to(cc + Vector2(0.5, 1.0)) >= r - 3.0:
					col = cols[sh]
				img.set_pixel(x, y, col)


static func _trunk(img: Image, cx: int, top: int, bottom: int, half: int, bark: Array[Color], flare: int) -> void:
	for y in range(top, bottom + 1):
		var k := 0
		if bottom - y < flare:
			k = (flare - (bottom - y)) / 2 + 1
		var hw := half + k
		for x in range(cx - hw, cx + hw):
			var c: Color = bark[1]
			if x <= cx - hw + maxi(1, hw / 3):
				c = bark[0]
			if x >= cx + hw - maxi(2, hw / 2) or y < top + 6:
				c = bark[2]
			if Px.h2(x / 2, y / 5) % 9 == 0 and x > cx - hw + 1:
				c = bark[2]
			Px.px(img, x, y, c)


## 老树：比镇上的圆冠树高一头、冠更宽。64×80，锚点在 (32, 77)。variant 0–2。
static func old_tree(variant: int, season: int = 0) -> Image:
	var img := Px.new_img(64, 80)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4100 + variant * 37
	var bark := _cols(BARK if variant != 1 else BARK_OLD)
	if season == 3:
		var tips: Array = []
		PixelArt._branches(img, rng, Vector2(32, 77), rng.randf_range(-0.05, 0.05), 26.0, 9.0, 5, bark, tips)
		Px.rect(img, 26, 75, 12, 2, bark[1])
		PixelArt._snow_on(img, rng)
		return Px.outline(img)
	_trunk(img, 32, 44, 77, 4, bark, 6)
	var sets: Array = LEAF_SETS[clampi(season, 0, 2)]
	_crown(img, rng, Vector2(32, 28), 29.0, 25.0, _cols(sets[variant % sets.size()]), 7.5)
	return Px.outline(img)


## 千年樟：一棵占好几格的大树，树根张开，树干上有个黑洞。160×176，锚点在 (80, 170)。四季常绿，冬天冠上有雪。
static func giant_tree(season: int = 0) -> Image:
	var img := Px.new_img(160, 176)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9001
	var bark := _cols(BARK_OLD)
	_trunk(img, 80, 92, 170, 15, bark, 22)
	# 左右两条大枝
	for side: int in [-1, 1]:
		var a := Vector2(80 + side * 8, 112)
		var b := Vector2(80 + side * 44, 78)
		var n := 40
		for i in n + 1:
			var t := i / float(n)
			var p := a.lerp(b, t) + Vector2(0, -sin(t * PI) * 6.0)
			var wd := int(lerpf(9.0, 4.0, t))
			for k in wd:
				Px.px(img, int(p.x) + k - wd / 2, int(p.y), bark[0] if k == 0 else (bark[2] if k >= wd - 2 else bark[1]))
	# 树洞
	for y in range(136, 158):
		for x in range(72, 88):
			var p := Vector2((x + 0.5 - 80.0) / 7.0, (y + 0.5 - 148.0) / 10.5)
			if p.length() < 1.0:
				img.set_pixel(x, y, Color.html("2a1f1c") if p.length() < 0.82 else Color.html("3f2e24"))
	# 根上的苔
	for x in range(52, 108):
		if Px.h2(x / 3, 5) % 3 == 0:
			Px.px(img, x, 168 - Px.h2(x / 3, 6) % 4, Color.html("6fae52"))
			Px.px(img, x, 169 - Px.h2(x / 3, 6) % 4, Color.html("4f8a44"))
	var set_id := 2 if season == 2 else 0
	var cols := _cols(LEAF_SETS[1 if season == 1 else 0][set_id]) if season != 2 else _cols(["b8cf58", "8fae46", "64883e", "466638"])
	if season == 3:
		cols = _cols(["9dbf8e", "6f9a72", "4c775c", "365a4a"])
	_crown(img, rng, Vector2(80, 62), 76.0, 56.0, cols, 11.0)
	if season == 3:
		for y in range(4, 110):
			for x in 160:
				if img.get_pixel(x, y).a > 0.0 and img.get_pixel(x, y - 1).a == 0.0:
					img.set_pixel(x, y, Color.html(SNOW))
					if img.get_pixel(x, y + 1).a > 0.0 and Px.h2(x, y) % 2 == 0:
						img.set_pixel(x, y + 1, Color.html("d1dde7"))
	return Px.outline(img)


## 松：一层一层的塔形。36×72，锚点在 (18, 69)。冬天每层上面压着雪。
static func pine(variant: int, season: int = 0) -> Image:
	var img := Px.new_img(36, 72)
	var bark := _cols(BARK_OLD)
	_trunk(img, 18, 50, 69, 2, bark, 3)
	var cols := _cols(PINE_SETS[variant % 2])
	var tiers := 5
	var top := 3 + (variant % 3) * 2
	for k in tiers:
		var t0 := top + k * 10
		var t1 := t0 + 17
		var half_max := 6.0 + k * 2.6
		for y in range(t0, mini(t1, 60)):
			var f := float(y - t0) / float(t1 - t0)
			var half := 1.0 + f * half_max
			# 下沿剪成锯齿
			for x in range(int(18 - half), int(18 + half) + 1):
				if y >= t1 - 3 and (x + k) % 4 < 2 and y == t1 - 1:
					continue
				var c: Color = cols[2]
				var side := (x - 18) / maxf(half, 1.0)
				if side < -0.25:
					c = cols[1]
				if side < -0.6 or (f < 0.25 and side < 0.2):
					c = cols[0]
				if side > 0.45 or f > 0.82:
					c = cols[3]
				Px.px(img, x, y, c)
		if season == 3:
			for x in range(int(18 - half_max * 0.5), int(18 + half_max * 0.5)):
				var y := t0 + int(absf(x - 18) / maxf(half_max, 1.0) * 14.0)
				if (x + k) % 3 != 0:
					Px.px(img, x, y, Color.html(SNOW))
					Px.px(img, x, y + 1, Color.html("d1dde7"))
	return Px.outline(img)


## 垂柳：水边的树。60×68，锚点在 (30, 65)。春天嫩黄，夏天绿，秋天黄，冬天只剩枝条。
static func willow(variant: int, season: int = 0) -> Image:
	var img := Px.new_img(60, 68)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5200 + variant * 19
	var bark := _cols(BARK_OLD)
	var lean := -3 if variant % 2 == 0 else 3
	for y in range(26, 66):
		var f := float(65 - y) / 39.0
		var cx := 30 + int(lean * f * f)
		var hw := 3 if y < 58 else 4
		for x in range(cx - hw, cx + hw):
			Px.px(img, x, y, bark[0] if x == cx - hw else (bark[2] if x >= cx + hw - 2 else bark[1]))
	var cols := _cols(WILLOW_FALL if season == 2 else WILLOW)
	if season == 0:
		cols = _cols(["e6f29a", "cfe67c", "a6cc5e", "7aa84e"])
	var top := Vector2(30 + lean, 20)
	if season != 3:
		for y in range(4, 34):
			for x in range(4, 56):
				var p := Vector2((x + 0.5 - top.x) / 24.0, (y + 0.5 - top.y) / 15.0)
				if p.length() < 1.0:
					var c: Color = cols[2]
					if p.x * 0.5 + p.y * 0.86 > 0.35:
						c = cols[3]
					elif p.x * 0.5 + p.y * 0.86 < -0.3:
						c = cols[1]
					if p.x * 0.5 + p.y * 0.86 < -0.62:
						c = cols[0]
					img.set_pixel(x, y, c)
	# 垂下来的枝条
	for x in range(5, 55, 2):
		var away := absf(x - top.x) / 25.0
		if away > 1.0:
			continue
		var start := int(top.y + 6 + (1.0 - away * away) * 4.0) if season != 3 else int(top.y - 8 + away * 14.0)
		var length := rng.randi_range(18, 30) - int(away * 6.0)
		var sway := rng.randi_range(-1, 1)
		for k in length:
			var y := start + k
			if y >= 62:
				break
			var sx := x + int(sway * k / 12.0)
			if season == 3:
				if k % 5 != 4:
					Px.px(img, sx, y, bark[1] if k < 8 else bark[0])
				continue
			var c: Color = cols[1] if (x / 2) % 3 == 0 else cols[2]
			if k > length - 5:
				c = cols[0] if (x / 2) % 2 == 0 else cols[1]
			if (x / 2) % 4 == 3:
				c = cols[3]
			Px.px(img, sx, y, c)
			if k % 3 == 0:
				Px.px(img, sx + 1, y, c)
	return Px.outline(img)


# ---------------------------------------------------------------- 茶

## 茶垄的一格，16×16，底边贴着格子的下沿。mask 位 1 左边还是茶、2 右边还是茶：没有的那一头收圆。
## shoots 为真时垄顶冒一层新芽（清明到谷雨）。冬天顶上有雪。
static func tea_bush(mask: int, season: int = 0, shoots: bool = false) -> Image:
	var img := Px.new_img(16, 16)
	var cols := _cols(["8fca5e", "5fa648", "3f8440", "2c653a"])
	if season == 2:
		cols = _cols(["9cc25a", "6f9c46", "4b7c3e", "345e36"])
	elif season == 3:
		cols = _cols(["86b070", "5c8c5a", "40704c", "2e5640"])
	for x in 16:
		var edge := 0
		if mask & 1 == 0 and x < 4:
			edge = 4 - x
		if mask & 2 == 0 and x > 11:
			edge = x - 11
		var top := 3 + (edge * edge) / 3 + (1 if Px.h2(x / 2, mask + 3) % 3 == 0 else 0)
		for y in range(top, 15):
			var c: Color = cols[2]
			if y < top + 2:
				c = cols[0]
			elif y < top + 5:
				c = cols[1]
			if y >= 12:
				c = cols[3]
			if y >= top + 2 and y < 12 and Px.h2(x, y) % 5 == 0:
				c = cols[1] if y > top + 5 else cols[2]
			if edge > 0 and y > 10:
				c = cols[3]
			img.set_pixel(x, y, c)
		if shoots and season < 2 and x % 3 == Px.h2(x / 3, 11) % 3:
			Px.px(img, x, top, Color.html("e4f48a"))
			Px.px(img, x, top - 1, Color.html("c8ec6a"))
		if season == 3 and Px.h2(x, 2) % 4 != 0:
			Px.px(img, x, top, Color.html(SNOW))
			Px.px(img, x, top + 1, Color.html("d1dde7") if x % 2 == 0 else Color.html(SNOW))
	return Px.outline(img)


# ---------------------------------------------------------------- 水里的

## 荷：一格水面上的几片叶子，有的带花或莲蓬。16×22，底边在格子下沿。
## kind：0 只有叶，1 花苞，2 开花，3 莲蓬。春天小叶贴水，夏天花，秋天枯叶和莲蓬，冬天只剩断梗。
static func lotus(kind: int, variant: int, season: int = 1) -> Image:
	var img := Px.new_img(16, 22)
	var leaf := _cols(["a4dc8c", "6fb86e", "4a9460", "357650"])
	if season == 2:
		leaf = _cols(["d8c47a", "b89a52", "8f743c", "6a5630"])
	var stem := Color.html("4f8a50") if season != 2 else Color.html("7a6a3a")
	if season == 3:
		var dead := Color.html("6e5c44")
		for k in 3:
			var x := 3 + k * 5 + Px.h2(variant, k) % 2
			var top := 12 + Px.h2(variant + 4, k) % 4
			for y in range(top, 20):
				Px.px(img, x, y, dead)
			Px.px(img, x + 1, top, dead)
			Px.px(img, x + 2, top + 1, dead)
		return img
	var spots: Array = [[5, 16, 5, 3], [11, 18, 4, 2]] if variant % 2 == 0 else [[10, 15, 5, 3], [4, 18, 4, 2]]
	if season == 0:
		spots = [[5, 17, 3, 2], [11, 18, 3, 2]]
	for s: Array in spots:
		var cx: int = s[0]
		var cy: int = s[1]
		var rx: int = s[2]
		var ry: int = s[3]
		for y in range(cy - ry, cy + ry + 1):
			for x in range(cx - rx, cx + rx + 1):
				var p := Vector2((x + 0.5 - cx) / (rx + 0.5), (y + 0.5 - cy) / (ry + 0.5))
				if p.length() >= 1.0:
					continue
				var c: Color = leaf[1]
				if p.y < -0.3:
					c = leaf[0]
				if p.y > 0.4 or p.x > 0.6:
					c = leaf[2]
				if absf(p.x) < 0.14 and p.y > 0.0:
					c = leaf[3]
				Px.px(img, x, y, c)
		Px.px(img, cx, cy, leaf[3])
	if kind == 0 or season == 0:
		return Px.outline(img)
	var fx := 8 + (variant % 3) - 1
	for y in range(8, 16):
		Px.px(img, fx, y, stem)
	if kind == 3 or season == 2:
		var pod := _cols(["a8c070", "7f9a50", "5a743c"]) if season != 2 else _cols(["a88a52", "86693a", "5e4828"])
		Px.rect(img, fx - 2, 4, 5, 2, pod[0])
		Px.rect(img, fx - 2, 6, 5, 2, pod[1])
		Px.rect(img, fx - 1, 8, 3, 1, pod[2])
		Px.px(img, fx - 1, 5, pod[2])
		Px.px(img, fx + 1, 5, pod[2])
		Px.px(img, fx, 4, pod[2])
	elif kind == 1:
		var bud := _cols(["fbd0dc", "f09ab4", "d06a8c"])
		Px.rect(img, fx - 1, 5, 3, 3, bud[1])
		Px.px(img, fx, 4, bud[0])
		Px.px(img, fx - 1, 5, bud[0])
		Px.px(img, fx + 1, 7, bud[2])
	else:
		var pet := _cols(["fff0f4", "fbc4d4", "ee8eae", "d0668a"])
		Px.rect(img, fx - 3, 5, 7, 3, pet[1])
		Px.rect(img, fx - 2, 3, 5, 2, pet[1])
		Px.px(img, fx - 3, 4, pet[2])
		Px.px(img, fx + 3, 4, pet[2])
		Px.px(img, fx - 4, 6, pet[2])
		Px.px(img, fx + 4, 6, pet[2])
		Px.px(img, fx, 2, pet[0])
		Px.rect(img, fx - 1, 4, 3, 2, pet[0])
		Px.px(img, fx, 5, Color.html("f7d24a"))
		Px.rect(img, fx - 2, 8, 5, 1, pet[3])
	return Px.outline(img)


## 芦苇：一丛。16×30，底边在格子下沿。秋冬穗子发白。
static func reed(variant: int, season: int = 1) -> Image:
	var img := Px.new_img(16, 30)
	var stalk := _cols(["a8cc66", "7fae52", "5a8a40"])
	var plume := _cols(["f1e4b8", "d8c48a", "b09a62"])
	if season >= 2:
		stalk = _cols(["e0cc88", "c0a862", "94804a"])
		plume = _cols(["fbf4dc", "ecdcb0", "c8b488"])
	var rng := RandomNumberGenerator.new()
	rng.seed = 610 + variant * 7
	for k in 5:
		var x := 2 + k * 3 + rng.randi_range(-1, 0)
		var top := rng.randi_range(4, 11)
		var lean := rng.randi_range(-1, 1)
		for y in range(top, 29):
			var sx := x + int(lean * (29 - y) / 14.0)
			Px.px(img, sx, y, stalk[1] if k % 2 == 0 else stalk[2])
		var tx := x + int(lean * (29 - top) / 14.0)
		if k % 2 == 0 or season >= 2:
			for j in 5:
				Px.px(img, tx, top - 1 + j, plume[0] if j < 2 else plume[1])
				Px.px(img, tx + (1 if lean >= 0 else -1), top + j, plume[1] if j < 3 else plume[2])
		# 一片斜出去的叶
		var side := 1 if k % 2 == 0 else -1
		for j in 4:
			Px.px(img, x + side * (j + 1), top + 9 + j / 2 + k, stalk[0])
	return Px.outline(img)


## 水田里的一格秧。16×16，贴在水面上。春天稀的秧苗，夏天成片的绿，秋天金黄的稻，冬天是稻茬。
static func paddy(season: int, variant: int) -> Image:
	var img := Px.new_img(16, 16)
	var cols := _cols(["b4e07a", "86c456", "5fa046"])
	if season == 2:
		cols = _cols(["f6dc7a", "e0b84a", "b48a34"])
	elif season == 3:
		cols = _cols(["c8b488", "a08a5e", "7a6644"])
	for row in 4:
		for col in 4:
			var x := 1 + col * 4 + (row % 2) + Px.h2(col + variant, row) % 2
			var y := 3 + row * 4
			if season == 0:
				Px.px(img, x, y, cols[0])
				Px.px(img, x, y - 1, cols[1])
				Px.px(img, x + 1, y - 2, cols[0])
			elif season == 3:
				Px.px(img, x, y, cols[1])
				Px.px(img, x + 1, y, cols[2])
			else:
				Px.rect(img, x - 1, y - 2, 3, 3, cols[1])
				Px.px(img, x - 1, y - 3, cols[0])
				Px.px(img, x + 1, y - 3, cols[0])
				Px.px(img, x, y - 2, cols[0])
				Px.px(img, x + 1, y, cols[2])
				Px.px(img, x, y + 1, cols[2])
	return img


# ---------------------------------------------------------------- 林下

## 蘑菇，12×12。kind：0 红伞白点，1 褐的一对，2 白的一簇。
static func mushroom(kind: int) -> Image:
	var img := Px.new_img(12, 12)
	var stem := Color.html("f1ead6")
	var stem_d := Color.html("cbbfa3")
	if kind == 0:
		Px.rect(img, 5, 7, 2, 4, stem)
		Px.px(img, 6, 9, stem_d)
		Px.rect(img, 2, 5, 8, 2, Color.html("c8483c"))
		Px.rect(img, 3, 3, 6, 2, Color.html("e8604a"))
		Px.rect(img, 4, 2, 4, 1, Color.html("e8604a"))
		Px.px(img, 4, 4, Color.WHITE)
		Px.px(img, 7, 3, Color.WHITE)
		Px.px(img, 8, 5, Color.WHITE)
		Px.rect(img, 2, 6, 8, 1, Color.html("a03a32"))
	elif kind == 1:
		for o: Array in [[3, 6, 3], [8, 7, 2]]:
			var cx: int = o[0]
			var cy: int = o[1]
			var r: int = o[2]
			Px.rect(img, cx - 1 + (r % 2), cy, 2 - (r % 2) + 1, 5 - (cy - 6), stem)
			Px.rect(img, cx - r, cy - 1, r * 2 + 1, 2, Color.html("b07a42"))
			Px.rect(img, cx - r + 1, cy - 2, r * 2 - 1, 1, Color.html("c99a5a"))
			Px.rect(img, cx - r, cy, r * 2 + 1, 1, Color.html("7d5230"))
	else:
		for o: Array in [[3, 8], [6, 6], [9, 8]]:
			var cx: int = o[0]
			var cy: int = o[1]
			Px.rect(img, cx, cy, 1, 11 - cy, stem_d)
			Px.rect(img, cx - 1, cy - 1, 3, 2, Color.html("fbf7ec"))
			Px.px(img, cx + 1, cy, stem_d)
	return Px.outline(img)


## 蕨，16×12。
static func fern(variant: int, season: int = 0) -> Image:
	var img := Px.new_img(16, 12)
	var cols := _cols(["8fd06a", "5fae56", "3f8a50"])
	if season == 2:
		cols = _cols(["d8c060", "b89a48", "8a7238"])
	elif season == 3:
		cols = _cols(["b8c8b0", "8fa890", "6a8470"])
	for k in 5:
		var a := -1.25 + k * 0.62 + (variant % 2) * 0.1
		for j in 8:
			var p := Vector2(8, 11) + Vector2(sin(a), -cos(a)) * j * (1.0 if k != 2 else 1.25)
			var droop := j * j / 26.0 * absf(sin(a))
			var x := int(p.x)
			var y := int(p.y + droop)
			Px.px(img, x, y, cols[1])
			if j > 1 and j % 2 == 0:
				Px.px(img, x, y - 1, cols[0])
				Px.px(img, x + (1 if a > 0 else -1), y + 1, cols[2])
	return Px.outline(img)


## 树桩，18×14。
static func stump() -> Image:
	var img := Px.new_img(18, 14)
	var bark := _cols(BARK_OLD)
	Px.rect(img, 3, 5, 12, 7, bark[1])
	Px.rect(img, 3, 5, 3, 7, bark[0])
	Px.rect(img, 12, 5, 3, 7, bark[2])
	Px.rect(img, 1, 11, 16, 2, bark[1])
	Px.rect(img, 13, 11, 4, 2, bark[2])
	for y in range(2, 7):
		for x in range(3, 15):
			var p := Vector2((x + 0.5 - 9.0) / 6.2, (y + 0.5 - 4.5) / 2.6)
			if p.length() < 1.0:
				img.set_pixel(x, y, Color.html("e2c08a") if p.length() > 0.55 else (Color.html("c99a5a") if p.length() > 0.25 else Color.html("a8763f")))
	Px.px(img, 4, 9, Color.html("6fae52"))
	Px.px(img, 5, 10, Color.html("6fae52"))
	Px.px(img, 4, 10, Color.html("4f8a44"))
	return Px.outline(img)


## 碾场上的石碌碡：横躺的石滚子，套着木架。22×15。
static func roller() -> Image:
	var img := Px.new_img(22, 15)
	var stone := _cols(["d6d3c8", "b3b0a4", "8b887d", "66645c"])
	var wood := _cols(BARK)
	for y in range(3, 13):
		var c: Color = stone[0] if y < 5 else (stone[1] if y < 9 else stone[2])
		Px.rect(img, 4, y, 13, 1, c)
	for x in [7, 11, 14]:
		Px.rect(img, x, 4, 1, 8, stone[3])
	for y in range(3, 13):
		for x in range(14, 21):
			var p := Vector2((x + 0.5 - 17.0) / 3.2, (y + 0.5 - 8.0) / 5.0)
			if p.length() < 1.0:
				img.set_pixel(x, y, stone[1] if p.length() > 0.5 else stone[2])
	Px.rect(img, 16, 7, 2, 2, wood[2])
	Px.rect(img, 1, 7, 3, 2, wood[1])
	Px.rect(img, 1, 5, 2, 6, wood[0])
	return Px.outline(img)


## 倒下的树干，横着，48×16。上面长了苔。
static func fallen_log() -> Image:
	var img := Px.new_img(48, 16)
	var bark := _cols(BARK_OLD)
	for x in range(5, 46):
		for y in range(4, 14):
			var c: Color = bark[1]
			if y < 6:
				c = bark[0]
			if y > 10:
				c = bark[2]
			if Px.h2(x / 4, y / 2) % 7 == 0:
				c = bark[2]
			img.set_pixel(x, y, c)
	for y in range(3, 15):
		for x in range(0, 8):
			var p := Vector2((x + 0.5 - 4.5) / 4.0, (y + 0.5 - 9.0) / 6.0)
			if p.length() < 1.0:
				img.set_pixel(x, y, Color.html("e2c08a") if p.length() > 0.6 else (Color.html("c99a5a") if p.length() > 0.3 else Color.html("8a5a36")))
	for x in range(10, 44):
		var n := Px.h2(x / 3, 2) % 5
		if n < 3:
			Px.px(img, x, 3, Color.html("86c45a"))
			Px.px(img, x, 4, Color.html("5fa046"))
			if n == 0:
				Px.px(img, x, 5, Color.html("4a8a3e"))
	return Px.outline(img)


## 木头路牌，14×20。牌面留空。
static func signpost() -> Image:
	var img := Px.new_img(14, 20)
	Px.rect(img, 6, 6, 2, 13, Color.html("6b4226"))
	Px.rect(img, 1, 2, 12, 6, Color.html("c08a52"))
	Px.rect(img, 1, 7, 12, 1, Color.html("9a6a40"))
	Px.rect(img, 3, 4, 7, 1, Color.html("6e4526"))
	Px.px(img, 12, 5, Color.html("9a6a40"))
	return Px.outline(img)


## 林子里的地：盖一层暗和落叶。forest 每格一个字节，1 要盖。
static func floor_shade(forest: PackedByteArray, cols: int, rows: int, season: int) -> Image:
	var img := Px.new_img(cols * TS, rows * TS)
	var shade := Color(0.05, 0.2, 0.14, 0.3)
	var deep := Color(0.03, 0.14, 0.12, 0.36)
	var leaf_a := Color(0.56, 0.72, 0.3, 0.8)
	var leaf_b := Color(0.22, 0.42, 0.2, 0.85)
	if season == 2:
		leaf_a = Color(0.9, 0.62, 0.24, 0.9)
		leaf_b = Color(0.7, 0.36, 0.2, 0.9)
	elif season == 3:
		shade = Color(0.3, 0.42, 0.56, 0.2)
		deep = Color(0.26, 0.36, 0.52, 0.26)
		leaf_a = Color(0.62, 0.7, 0.78, 0.6)
		leaf_b = Color(0.5, 0.58, 0.68, 0.6)
	for ty in rows:
		for tx in cols:
			if forest[ty * cols + tx] != 1:
				continue
			for by in range(0, TS, 2):
				for bx in range(0, TS, 2):
					var gx := tx * TS + bx
					var gy := ty * TS + by
					# 林子的边沿留毛边，不是齐的
					var edge := false
					for d: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
						var nx := tx + d.x
						var ny := ty + d.y
						if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
							continue
						if forest[ny * cols + nx] != 1:
							var near := bx if d.x < 0 else (TS - 2 - bx if d.x > 0 else (by if d.y < 0 else TS - 2 - by))
							if near < 4 + Px.h2(gx / 6 + d.x, gy / 6 + d.y) % 6:
								edge = true
					if edge:
						continue
					var n := Px.h2(gx / 4, gy / 4) % 100
					if n < 10:
						continue
					var c := deep if n > 62 else shade
					img.fill_rect(Rect2i(gx, gy, 2, 2), c)
			for k in 3:
				var h := Px.h2(tx * 7 + k, ty * 5 + 1)
				var px := tx * TS + h % 15
				var py := ty * TS + (h / 16) % 14
				var c2 := leaf_a if h % 3 == 0 else leaf_b
				Px.px(img, px, py, c2)
				Px.px(img, px + 1, py + 1, c2)
	return img
