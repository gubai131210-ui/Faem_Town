class_name UiMotion
extends RefCounted
## M9 第四批：界面和头像的画面规则。纯函数，不碰节点，方便单元测试和四帧预览。
## 眨眼与嘴动、图标飞向物品栏、钱数滚动、换季名牌都从这里取值；游戏和预览用同一套。
## 这一层不认识 Hud 或 DialogueBalloon，也不写存档：换季名牌是一次性画面，不进存档。

## 一张换季名牌从淡入到收走要走多久
const SEASON_CARD_TIME := 2.4
## 说话时的嘴形：半张、张、半张、闭，循环
const MOUTH_SEQ: Array[int] = [1, 2, 1, 0]
const PREVIEW_MOUTH: Array[int] = [0, 0, 1, 2]
const PREVIEW_MONEY_T: Array[float] = [0.0, 0.22, 0.55, 1.0]
const PREVIEW_CARD_T: Array[float] = [0.06, 0.3, 1.2, 2.3]
## 3×5 的点阵数字，只用于四帧预览里把滚动的钱数画出来
const DIGITS: Array[String] = [
	"111101101101111", "010110010010111", "111001111100111", "111001111001111",
	"101101111001001", "111100111001111", "111100111101111", "111001001001001",
	"111101111101111", "111101111001111",
]

const EYE_W := Color("f7cba4")
const INK := Color("3a2a35")
const LIP := Color("b05545")


## 眨一下只有 0.13 秒；周期和各人的相位都错开，免得整屏一起眨。
static func blink_closed(time: float, seed: float = 0.0) -> bool:
	var period := 3.2 + 0.9 * sin(seed * 2.1 + 0.4)
	var phase := fmod(maxf(time, 0.0) + seed * 1.7, period)
	return phase < 0.13


## 说话时嘴在半张、张、闭之间换；不说话就一直闭着。
static func mouth_frame(time: float, talking: bool, seed: float = 0.0) -> int:
	if not talking:
		return 0
	var k := int(fmod(maxf(time, 0.0) * 9.0 + seed, 4.0))
	return MOUTH_SEQ[k]


## 图标从画面中间飞向物品栏：直线插值再抬一道弧，落点正好是格子中心。
static func fly_pos(from: Vector2, to: Vector2, t: float) -> Vector2:
	if t <= 0.0:
		return from
	if t >= 1.0:
		return to
	var p := from.lerp(to, t)
	p.y -= 20.0 * sin(PI * t)
	return p


## 钱数先快后慢地滚到新值；两端一定落在准确的数上。
static func money_shown(from: int, to: int, t: float) -> int:
	var e := 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 3.0)
	return roundi(lerpf(float(from), float(to), e))


## 只有「真的换了一季、又过了一天」的早上才亮名牌；开局那一季不亮。
static func season_first_day(prev_day: int, day: int) -> bool:
	if day <= prev_day:
		return false
	return (prev_day - 1) / 24 != (day - 1) / 24


static func season_card_text(season_name: String, term_name: String) -> String:
	return "入%s · %s" % [season_name, term_name]


## 淡入 0.25 秒，停一阵，再淡出；亮一下就走，不占着屏幕。
static func season_card_alpha(t: float) -> float:
	if t <= 0.0 or t >= SEASON_CARD_TIME:
		return 0.0
	if t < 0.25:
		return t / 0.25
	if t < 1.6:
		return 1.0
	return clampf((SEASON_CARD_TIME - t) / (SEASON_CARD_TIME - 1.6), 0.0, 1.0)


# ---------------------------------------------------------------- 头像

## 在一张 64×64 的头像上合成闭眼和张嘴。不改磁盘上的素材，也不另画一张脸：
## 从这张脸自己取肤色、眼线和唇色，所以十二位居民、三档表情都用得上。
## closed=false 且 mouth=0 时原样返回，一句台词里大部分帧都走这条路。
static func face_variant(base: Image, closed: bool, mouth: int) -> Image:
	if base == null or base.is_empty():
		return base
	if not closed and mouth == 0:
		return base.duplicate() as Image
	var out: Image = base.duplicate()
	if out.get_format() != Image.FORMAT_RGBA8:
		out.convert(Image.FORMAT_RGBA8)
	if closed:
		# 眼睛实际占 x22–28 / x35–41、y31–37（小孩大眼底行到 37）；上边界收到 31、
		# 左右收窄，是为了不吃进 y28–30 的眉毛和 x20–21 的刘海，免得眨眼把发际线涂缺
		var eyes: Array[Rect2i] = [Rect2i(22, 31, 7, 7), Rect2i(35, 31, 7, 7)]
		for rect in eyes:
			_close_eye(out, rect)
	if mouth > 0:
		_open_mouth(out, mouth)
	return out


## 把一只眼睛里的深色像素换成肤色，只留一道眼线。眼线画在原来眼珠最密的那一行，
## 这样大人、小孩以及三种眼型都不用写死坐标。
static func _close_eye(img: Image, rect: Rect2i) -> void:
	var skin := _common_color(img, rect, false)
	var ink := _common_color(img, rect, true)
	var rows: Dictionary[int, int] = {}
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := img.get_pixel(x, y)
			if _is_deep(c):
				rows[y] = int(rows.get(y, 0)) + 1
				img.set_pixel(x, y, skin)
			elif _is_eye_white(c):
				# 眼白是浅色，光盖深色会留下两根白竖条，像闭着眼还翻白眼
				img.set_pixel(x, y, skin)
	var line := rect.position.y + 4
	var best := 0
	for y in rows:
		if rows[y] > best:
			best = rows[y]
			line = y
	var cx := rect.position.x + rect.size.x / 2
	for dx in range(-2, 3):
		img.set_pixel(cx + dx, line, ink)
	img.set_pixel(cx - 3, line - 1, ink)
	img.set_pixel(cx + 3, line - 1, ink)


## 先把原来那条嘴线换成肤色，再在原地画张开或半张的嘴。
static func _open_mouth(img: Image, frame: int) -> void:
	var rect := Rect2i(28, 39, 9, 6)
	# 唇色只从唇线那一行取、肤色只从嘴下那一行取：胡子是在嘴之前画的，整块取色会被
	# 白胡子或络腮胡带偏（老秦老周涂白、石叔唇色发灰）。这两行对十二位都稳定。
	var lip := _common_color(img, Rect2i(30, 41, 5, 1), true)
	if lip.is_equal_approx(EYE_W):
		lip = LIP
	var skin := _common_color(img, Rect2i(31, 43, 3, 1), false)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := img.get_pixel(x, y)
			if c.a > 0.5 and not c.is_equal_approx(skin) and c.r > c.g * 1.2 and c.g < 0.65:
				img.set_pixel(x, y, skin)
	if frame >= 2:
		# 张嘴：五行的椭圆，上面一行留一点牙色
		_mouth_row(img, 39, 31, 33, lip)
		_mouth_row(img, 40, 30, 34, lip)
		_mouth_row(img, 41, 29, 35, lip)
		_mouth_row(img, 42, 30, 34, lip)
		_mouth_row(img, 43, 31, 33, lip)
		_mouth_row(img, 40, 31, 33, Color("f6efe6"))
	else:
		_mouth_row(img, 41, 30, 34, lip)
		_mouth_row(img, 42, 31, 33, lip)


static func _mouth_row(img: Image, y: int, x0: int, x1: int, col: Color) -> void:
	for x in range(x0, x1 + 1):
		img.set_pixel(x, y, col)


static func _is_deep(c: Color) -> bool:
	return c.a > 0.5 and (c.r + c.g + c.b) / 3.0 < 0.45


## 眼珠里的高光：纯白那一点，以及细长眼用 ink+white 混出的灰（约 143,131,133）。
## 共同点是低饱和、比肤色暗又比眼线亮；肤色是暖色（红远大于蓝），不会误判。
static func _is_eye_white(c: Color) -> bool:
	if c.a <= 0.5:
		return false
	var mx := maxf(c.r, maxf(c.g, c.b))
	var mn := minf(c.r, minf(c.g, c.b))
	return mx - mn < 0.12 and c.r > 0.5 and c.b > 0.45


## 一块区域里最常见的颜色；want_deep 决定取深色还是肤色。找不到时给一个稳的默认值。
static func _common_color(img: Image, rect: Rect2i, want_deep: bool) -> Color:
	var count: Dictionary[int, int] = {}
	var colors: Dictionary[int, Color] = {}
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := img.get_pixel(x, y)
			if c.a < 0.5 or _is_deep(c) != want_deep:
				continue
			var key := c.to_rgba32()
			count[key] = int(count.get(key, 0)) + 1
			colors[key] = c
	var best := 0
	var found := -1
	for key in count:
		if count[key] > best:
			best = count[key]
			found = key
	if found < 0:
		return INK if want_deep else EYE_W
	return colors[found]


# ---------------------------------------------------------------- 四帧预览

## 四行 × 四帧：头像、图标飞行、钱数滚动、换季名牌。
## 画的是规则本身，不是游戏截图：名牌上的汉字在这里用色条示意。
static func preview() -> Image:
	var img := Image.create(640, 256, false, Image.FORMAT_RGBA8)
	img.fill(Color("2b2620"))
	var base := _preview_face()
	for frame in 4:
		var ox := frame * 160
		_row_mark(img, ox, 0, Color("c8483c"))
		_row_mark(img, ox, 64, Color("4a8a72"))
		_row_mark(img, ox, 128, Color("9a5a1c"))
		_row_mark(img, ox, 192, Color("c8903c"))
		# 第一行：整张脸，右边把嘴放大六倍
		var closed := frame == 1 or frame == 3
		var mouth: int = PREVIEW_MOUTH[frame]
		var face := face_variant(base, closed, mouth)
		img.blit_rect(face, Rect2i(0, 0, 64, 64), Vector2i(ox + 4, 0))
		for y in range(39, 45):
			for x in range(28, 37):
				var c := face.get_pixel(x, y)
				for dy in 6:
					for dx in 6:
						img.set_pixel(ox + 78 + (x - 28) * 6 + dx, 8 + (y - 39) * 6 + dy, c)
		# 第二行：图标从右上飞向左下的物品栏
		_fly_row(img, ox, float(frame) / 3.0)
		# 第三行：时钟面板里的钱数
		_money_row(img, ox, PREVIEW_MONEY_T[frame])
		# 第四行：换季名牌的淡入、停留、淡出
		_card_row(img, ox, PREVIEW_CARD_T[frame])
		if frame > 0:
			for y in 256:
				img.set_pixel(ox, y, Color("5a4a38"))
	return img


## 十二位居民各一行、四种状态各一列，用来检查程序化改的眼睛和嘴没把谁的脸画坏。
## 只看得见画，不参与游戏。
static func preview_faces() -> Image:
	var names: Array[String] = []
	var dir := DirAccess.open("res://art/characters")
	if dir != null:
		for f in dir.get_files():
			if f.ends_with("_face.png"):
				names.append(f)
		names.sort()
	if names.is_empty():
		return Image.create(4, 4, false, Image.FORMAT_RGBA8)
	var img := Image.create(256, names.size() * 64, false, Image.FORMAT_RGBA8)
	img.fill(Color("efe0bd"))
	for row in names.size():
		var tex := load("res://art/characters/" + names[row]) as Texture2D
		if tex == null:
			continue
		var strip := tex.get_image()
		if strip == null or strip.get_width() < 64 or strip.get_height() < 64:
			continue
		var base: Image = strip.get_region(Rect2i(0, 0, 64, 64))
		if base.get_format() != Image.FORMAT_RGBA8:
			base.convert(Image.FORMAT_RGBA8)
		for col in 4:
			var state := face_variant(base, col == 1 or col == 3, PREVIEW_MOUTH[col])
			img.blit_rect(state, Rect2i(0, 0, 64, 64), Vector2i(col * 64, row * 64))
	return img


static func _row_mark(img: Image, ox: int, oy: int, col: Color) -> void:
	for y in range(oy, oy + 64):
		for x in range(ox, ox + 3):
			img.set_pixel(x, y, col)


static func _fly_row(img: Image, ox: int, t: float) -> void:
	for y in range(66, 126):
		for x in range(ox + 4, ox + 159):
			img.set_pixel(x, y, Color("8fa9a0"))
	for i in 8:
		var bx := ox + 12 + i * 18
		_box(img, Rect2i(bx, 104, 17, 17), Color("5a4632"), Color("d8c49a"))
	# 要落进去的那一格亮一道边
	_box(img, Rect2i(ox + 12, 104, 17, 17), Color("efe0bd"), Color("fff6d8"))
	var to := Vector2(ox + 20.0, 112.0)
	var p := fly_pos(Vector2(ox + 146.0, 76.0), to, t)
	# 一颗白萝卜：两行绿顶、白身
	_box(img, Rect2i(int(p.x) - 5, int(p.y) - 4, 11, 11), Color.WHITE, Color("e8e0d0"))
	for y in range(int(p.y) - 7, int(p.y) - 4):
		for x in range(int(p.x) - 3, int(p.x) + 4):
			img.set_pixel(x, y, Color("6aa84f"))


static func _money_row(img: Image, ox: int, t: float) -> void:
	_box(img, Rect2i(ox + 8, 136, 144, 50), Color("5a4632"), Color("efe0bd"))
	_box(img, Rect2i(ox + 16, 142, 128, 14), Color("d8c49a"), Color("d8c49a"))
	_box(img, Rect2i(ox + 16, 160, 128, 18), Color("efe0bd"), Color("efe0bd"))
	var n := money_shown(120, 380, t)
	var text := "%d" % n
	for i in text.length():
		_digit(img, ox + 60 + i * 24, 161, int(text[i]), Color("9a5a1c"), 4)


static func _digit(img: Image, x0: int, y0: int, d: int, col: Color, scale: int) -> void:
	var bits: String = DIGITS[clampi(d, 0, 9)]
	for row in 5:
		for col_i in 3:
			if bits[row * 3 + col_i] != "1":
				continue
			for dy in scale:
				for dx in scale:
					img.set_pixel(x0 + col_i * scale + dx, y0 + row * scale + dy, col)


static func _card_row(img: Image, ox: int, t: float) -> void:
	var a := season_card_alpha(t)
	var back := Color("4a3a2c")
	var panel := Color("c8903c")
	var ink := Color("fff6d8")
	for y in range(194, 254):
		for x in range(ox + 4, ox + 159):
			img.set_pixel(x, y, back)
	_box(img, Rect2i(ox + 20, 208, 120, 30), _blend(back, panel, a), _blend(back, ink, a))
	# 字在这里是示意色条：游戏里由 UiKit 的 Label 写「入秋 · 立秋」
	if a > 0.05:
		for k in 5:
			var bx := ox + 34 + k * 19
			_box(img, Rect2i(bx, 218, 13, 9), _blend(panel, ink, a * 0.85), _blend(panel, ink, a))


static func _blend(a: Color, b: Color, t: float) -> Color:
	var c := a.lerp(b, clampf(t, 0.0, 1.0))
	c.a = 1.0
	return c


static func _box(img: Image, rect: Rect2i, fill: Color, border: Color) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var edge := x == rect.position.x or x == rect.end.x - 1 \
					or y == rect.position.y or y == rect.end.y - 1
			img.set_pixel(x, y, border if edge else fill)


## 预览优先用项目里真实的头像；资源不在时退到一张同布局的最小脸，不让导出脚本崩掉。
static func _preview_face() -> Image:
	var path := "res://art/characters/ahe_face.png"
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex != null:
			var strip := tex.get_image()
			if strip != null and strip.get_width() >= 64 and strip.get_height() >= 64:
				var region: Image = strip.get_region(Rect2i(0, 0, 64, 64))
				if region.get_format() != Image.FORMAT_RGBA8:
					region.convert(Image.FORMAT_RGBA8)
				return region
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(EYE_W)
	_box(img, Rect2i(16, 6, 32, 16), Color("d8d4d0"), Color("4a4048"))
	for y in range(31, 35):
		for x in range(22, 28):
			img.set_pixel(x, y, INK)
		for x in range(35, 41):
			img.set_pixel(x, y, INK)
	_mouth_row(img, 41, 29, 35, LIP)
	return img
