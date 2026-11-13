class_name EndingArt
extends RefCounted
## 三个结局各一张画，192×108：远山、近山、山谷里的镇子。
## 留雾：黄昏，雾一层一层压着山腰和镇子。散雾：晴夜，星星、月亮、灯塔的光，一串灯笼往井口去。
## 归名：清晨，山脚一线薄雾，山脊上站着一头白鹿。

const W := 192
const H := 108
## 镇子里房子的左边缘
const HOUSES: Array[int] = [52, 62, 73, 82, 93, 104, 114, 126]
## 井口在近山上的位置
const WELL := Vector2i(150, 62)
## 画好以后整张往上提这么多行
const LIFT := 18


static func scene(id: StringName) -> Image:
	var img := Px.new_img(W, H)
	var top := Color.html("2c3450")
	var low := Color.html("6a7088")
	var far := Color.html("46506a")
	var near := Color.html("303a50")
	var ground := Color.html("262e40")
	var house := Color.html("1c2230")
	var window := Color.html("d8b060")
	match id:
		Story.CLEAR:
			top = Color.html("0c1030")
			low = Color.html("2c3c70")
			far = Color.html("1e2a52")
			near = Color.html("141c3c")
			ground = Color.html("0e142a")
			house = Color.html("0a0e20")
			window = Color.html("ffd76a")
		Story.NAME:
			top = Color.html("7c8cc4")
			low = Color.html("f4bc94")
			far = Color.html("8c88b0")
			near = Color.html("4c5c74")
			ground = Color.html("3c5444")
			house = Color.html("2c3440")
			window = Color.html("ffe08a")
	# 天：分成几档的渐变
	for y in H:
		var t := floorf(clampf(y / 70.0, 0.0, 1.0) * 9.0) / 9.0
		Px.rect(img, 0, y, W, 1, top.lerp(low, t))
	if id == Story.CLEAR:
		for i in 70:
			var sx := Px.h2(i, 7) % W
			var sy := LIFT + Px.h2(i, 13) % 40
			Px.px(img, sx, sy, Color.html("fff6d8") if i % 5 == 0 else Color.html("8c9cd0"))
		_disc(img, 40, 32, 5.0, Color.html("f4f0d8"))
		_disc(img, 42, 31, 4.0, top.lerp(low, 0.3))
	elif id == Story.NAME:
		# 太阳刚露出远山
		_disc(img, 96, 58, 13.0, Color(1.0, 0.92, 0.7, 0.35), true)
		_disc(img, 96, 58, 8.0, Color.html("fff0c0"))
	# 远山、近山
	for x in W:
		var fy := _far_y(x)
		Px.rect(img, x, fy, 1, H - fy, far)
		if id != Story.KEEP and fy < 60:
			Px.px(img, x, fy, far.lightened(0.18))
	for x in W:
		var ny := _near_y(x)
		Px.rect(img, x, ny, 1, H - ny, near)
	Px.rect(img, 0, 92, W, H - 92, ground)
	for x in W:
		if Px.h2(x, 3) % 3 == 0:
			Px.px(img, x, 92, near)
	# 镇子
	for i in HOUSES.size():
		var hx := HOUSES[i]
		var hw := 7 + Px.h2(i, 1) % 3
		var hh := 5 + Px.h2(i, 2) % 3
		var hy := 92 - hh
		Px.rect(img, hx, hy, hw, hh, house)
		Px.rect(img, hx - 1, hy - 1, hw + 2, 1, house)
		Px.rect(img, hx + 1, hy - 2, hw - 2, 1, house)
		var lit := id != Story.KEEP or i % 2 == 0
		if lit:
			Px.rect(img, hx + 2, hy + 2, 2, 2, window)
			if hw >= 9 and id != Story.KEEP:
				Px.rect(img, hx + 6, hy + 2, 1, 2, window)
	# 井口：近山上的一个黑洞口，旁边一盏灯
	Px.rect(img, WELL.x - 2, WELL.y, 5, 4, house)
	Px.rect(img, WELL.x - 3, WELL.y - 1, 7, 1, house)
	match id:
		Story.KEEP:
			_fog(img, 44, 9, 0.62, 0)
			_fog(img, 60, 7, 0.5, 40)
			_fog(img, 78, 8, 0.42, 90)
			_fog(img, 96, 6, 0.3, 20)
			# 雾里透出来的六盏石灯
			for lx: int in [30, 60, 84, 108, 132, 164]:
				_glow(img, lx, 88 - Px.h2(lx, 5) % 8, Color(1.0, 0.82, 0.45), 3)
		Story.CLEAR:
			_glow(img, WELL.x, WELL.y - 3, Color(1.0, 0.86, 0.5), 5)
			# 从镇子往井口去的一串灯笼
			for i in 12:
				var t := i / 11.0
				var px := int(lerpf(128.0, WELL.x - 5.0, t))
				_glow(img, px, _near_y(px) - 2 + (4 - int(t * 4.0)), Color(1.0, 0.8, 0.45), 1)
			_lighthouse(img, 180, true)
		Story.NAME:
			_glow(img, WELL.x, WELL.y - 3, Color(1.0, 0.9, 0.6), 4)
			_fog(img, 88, 4, 0.34, 10)
			_lighthouse(img, 180, false)
			_deer(img, 22, _near_y(26) - 1)
	# 整张画往上提：屏幕底下那一截要让给对话框，镇子得露在它上面
	var out := Px.new_img(W, H)
	out.fill(ground)
	out.blit_rect(img, Rect2i(0, LIFT, W, H - LIFT), Vector2i.ZERO)
	return out


static func _far_y(x: int) -> int:
	return 46 + int(roundf(sin(x * 0.045 + 0.6) * 9.0 + sin(x * 0.11 + 2.0) * 4.0 - 10.0 * exp(-pow((x - 120.0) / 26.0, 2.0))))


static func _near_y(x: int) -> int:
	var y := 78.0 + sin(x * 0.06 + 3.4) * 4.0
	# 左边一道山脊，右边井口那座山
	y -= 22.0 * exp(-pow((x - 24.0) / 22.0, 2.0))
	y -= 18.0 * exp(-pow((x - 156.0) / 24.0, 2.0))
	return mini(92, int(roundf(y)))


static func _blend(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < W and y < H:
		img.set_pixel(x, y, img.get_pixel(x, y).blend(c))


static func _disc(img: Image, cx: int, cy: int, r: float, c: Color, soft: bool = false) -> void:
	for y in range(cy - int(r) - 1, cy + int(r) + 2):
		for x in range(cx - int(r) - 1, cx + int(r) + 2):
			var d := Vector2(x - cx, y - cy).length()
			if d <= r:
				_blend(img, x, y, Color(c.r, c.g, c.b, c.a * (1.0 - d / r)) if soft else c)


## 一小团灯光：中间一个亮点，外面 r 格淡下去。
static func _glow(img: Image, cx: int, cy: int, c: Color, r: int) -> void:
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			var d := absi(x - cx) + absi(y - cy)
			if d <= r:
				_blend(img, x, y, Color(c.r, c.g, c.b, 0.9 if d == 0 else 0.45 * (1.0 - d / float(r + 1))))


## 一条横着的雾：上下边缘起伏，中间最浓。
static func _fog(img: Image, y0: int, thick: int, alpha: float, shift: int) -> void:
	for x in W:
		var wob := int(roundf(sin((x + shift) * 0.07) * 2.0 + sin((x + shift) * 0.19) * 1.0))
		for k in thick:
			var edge := minf(k, thick - 1 - k) / (thick / 2.0)
			_blend(img, x, y0 + wob + k, Color(0.86, 0.89, 0.93, alpha * clampf(0.35 + edge, 0.0, 1.0)))


static func _lighthouse(img: Image, x: int, beam: bool) -> void:
	var white := Color.html("d8d4c8")
	Px.rect(img, x, 76, 3, 16, white)
	Px.rect(img, x, 81, 3, 2, Color.html("b8483c"))
	Px.rect(img, x - 1, 74, 5, 2, Color.html("3a3a42"))
	Px.rect(img, x, 72, 3, 2, Color.html("ffe07a"))
	Px.px(img, x + 1, 71, Color.html("b8483c"))
	if beam:
		for i in 60:
			var half := 1 + i / 9
			for k in range(-half, half + 1):
				_blend(img, x - 1 - i, 73 - i / 6 + k, Color(1.0, 0.95, 0.7, 0.3 * (1.0 - i / 60.0)))
	_glow(img, x + 1, 73, Color(1.0, 0.9, 0.55), 3)


## 山脊上的白鹿，朝右；(x, y) 是前蹄落地的位置。
static func _deer(img: Image, x: int, y: int) -> void:
	var c := Color.html("f8fbff")
	Px.rect(img, x - 6, y - 7, 7, 3, c)
	for lx: int in [x - 6, x - 4, x - 1, x]:
		Px.rect(img, lx, y - 4, 1, 4, c)
	Px.rect(img, x, y - 10, 2, 4, c)
	Px.rect(img, x + 1, y - 12, 3, 2, c)
	Px.px(img, x, y - 13, c)
	Px.px(img, x - 1, y - 14, c)
	Px.px(img, x + 2, y - 14, c)
	Px.px(img, x + 3, y - 15, c)
	Px.px(img, x + 1, y - 13, c)
	Px.px(img, x - 7, y - 7, c)
