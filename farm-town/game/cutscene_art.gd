class_name CutsceneArt
extends RefCounted
## 开场与结局的过场画。画面固定 192×108。
## picture() 用的是每段结束时的那一帧（参数都走默认值）。
## at() 按时间把同一段画出来：信滑上桌、字一行行写上、车窗外的景往后退、
## 雾聚进灯里、鹿迈步、手抬起来。人的走路帧不在这里贴，由过场脚本贴。
## 颜色只从 palette.json 取（单字母键）。

const W := 192
const H := 108


static func c(key: String, light: float = 0.0, dark: float = 0.0) -> Color:
	var base: Color = Palette.c(key)
	if light > 0.0:
		return base.lightened(light)
	if dark > 0.0:
		return base.darkened(dark)
	return base


static func rect(img: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	img.fill_rect(Rect2i(x, y, w, h), col)


static func px(img: Image, x: int, y: int, col: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	img.set_pixel(x, y, col)


## 带描边和顶部高光的块，用来画木头、石头、布，比纯色方块有体积。
static func block(img: Image, x: int, y: int, w: int, h: int, key: String) -> void:
	rect(img, x, y, w, h, c(key))
	rect(img, x, y, w, 1, c(key, 0.16))
	rect(img, x, y + h - 1, w, 1, c(key, 0, 0.28))
	rect(img, x, y, 1, h, c(key, 0.1))
	rect(img, x + w - 1, y, 1, h, c(key, 0, 0.24))


## 天空：上深下浅加一层渐变条，再加远山剪影，比原来一大块纯色有空间。
static func sky(img: Image, top: Color, low: Color, ground_y: int, ground: Color,
		mountain: Color) -> void:
	img.fill(top)
	rect(img, 0, 38, W, ground_y - 38, low)
	# 渐变：从上往下每 8 行叠一层，做出过渡而不是硬切
	for i in 6:
		var y := 38 + i * 6
		if y >= ground_y:
			break
		rect(img, 0, y, W, 6, low.lerp(top, float(6 - i) / 8.0))
	# 远山：两座三角剪影
	for k in 2:
		var bx := 20 + k * 96
		for row in 18:
			var half := row
			rect(img, bx - half, ground_y - 20 + row, half * 2 + 1, 1, mountain)
	rect(img, 0, ground_y, W, H - ground_y, ground)


## 一扇带木格和窗纸的窗。scroll 让窗外的树和雾往左走，窗框不动，像车在开。
static func window_scene(img: Image, fog: bool, scroll: float = 0.0) -> void:
	img.fill(c("e"))
	var sky_col: Color = c("g", 0, 0.35) if fog else c("b", 0, 0.15)
	var far_col: Color = c("g") if fog else c("b")
	rect(img, 18, 10, 156, 88, sky_col)
	rect(img, 18, 10, 156, 30, far_col)
	rect(img, 18, 70, 156, 28, c("l", 0, 0.15))
	var s := int(scroll)
	for i in 8:
		_pine(img, 8 + i * 34 - s, 68)
	if fog:
		for i in 5:
			var x := 24 + i * 30 - s / 2
			rect(img, x, 40 + (i % 3) * 8, 26, 10, c("g", 0.12))
	rect(img, 40 - s / 3, 46, 72, 18, c("x", 0, 0.06))
	# 窗框
	block(img, 14, 6, 164, 6, "H")
	block(img, 14, 96, 164, 6, "H")
	block(img, 14, 6, 8, 96, "H")
	block(img, 170, 6, 8, 96, "H")
	block(img, 92, 6, 6, 96, "H")
	block(img, 16, 50, 160, 4, "H")
	# 窗台木纹
	for i in 16:
		px(img, 16 + i * 10, 98, c("T", 0, 0.2))
	# 反光画在玻璃上，跟着窗框，不跟着外面的景走
	for i in 14:
		rect(img, 24 + i, 16 + i, 3, 2, c("x", 0.12 - i * 0.004))
		rect(img, 104 + i, 60 - i / 2, 2, 2, c("x", 0.08))


## 一张摊开的信纸：横线、折痕、火漆。
static func letter(img: Image, ink: float = 1.0) -> void:
	# 桌面木纹：深浅木板，不只是纯深底
	img.fill(c("H", 0, 0.32))
	for i in 12:
		rect(img, 0, i * 9, W, 1, c("H", 0, 0.42))
		for j in 5:
			px(img, (j * 41 + i * 17) % W, i * 9 + 3, c("H", 0, 0.24))
	rect(img, 26, 12, 140, 84, c("H", 0, 0.2))
	# 信纸：纸面、上缘、下缘的折影
	rect(img, 28, 14, 136, 80, c("x"))
	rect(img, 28, 14, 136, 3, c("x", 0.06))
	rect(img, 28, 91, 136, 4, c("X", 0, 0.12))
	rect(img, 28, 17, 3, 74, c("X", 0, 0.06))
	# 字行：两档深浅，末尾那行短
	for i in 7:
		var full := 96 - i * 10
		var shown := int(float(full) * clampf(ink * 8.0 - float(i), 0.0, 1.0))
		if shown < 2:
			continue
		rect(img, 40, 27 + i * 8, shown, 2, c("M", 0, 0.18))
		rect(img, 40, 29 + i * 8, maxi(shown - 6, 1), 1, c("M", 0.12))
	# 折痕：一横一竖
	rect(img, 96, 16, 1, 76, c("X", 0, 0.08))
	rect(img, 28, 55, 136, 1, c("X", 0, 0.05))
	# 火漆：深红底 + 亮红高光 + 暗边
	rect(img, 138, 74, 12, 12, c("R", 0, 0.15))
	rect(img, 140, 76, 10, 10, c("R"))
	px(img, 142, 78, c("r"))
	px(img, 143, 79, c("r", 0.1))
	rect(img, 140, 84, 8, 1, c("R", 0, 0.2))
	key(img, 116, 62)


## 一把黄铜钥匙，带齿和环。
static func key(img: Image, x: int, y: int) -> void:
	var gold := c("y")
	var dark := c("Y")
	rect(img, x, y + 3, 16, 3, dark)
	rect(img, x, y + 2, 16, 3, gold)
	rect(img, x + 12, y + 2, 3, 8, gold)
	rect(img, x + 8, y + 5, 3, 5, dark)
	rect(img, x + 3, y + 7, 3, 4, gold)
	# 钥匙环
	rect(img, x - 2, y - 2, 8, 2, gold)
	rect(img, x - 3, y - 1, 2, 7, gold)
	rect(img, x + 3, y - 1, 2, 7, gold)
	rect(img, x - 2, y + 5, 8, 2, gold)
	rect(img, x - 1, y, 4, 4, c("e"))


## 一张木桌，桌上摊着信与钥匙，背景是灰墙。
static func desk(img: Image, letter_x: int = 76) -> void:
	img.fill(c("g", 0, 0.25))
	rect(img, 0, 60, W, 48, c("H"))
	rect(img, 0, 60, W, 4, c("h"))
	for i in 8:
		rect(img, i * 26, 66, 1, 40, c("H", 0, 0.18))
	# 墙上的木窗：外面天光，窗棂十字
	block(img, 60, 6, 72, 44, "T")
	rect(img, 64, 10, 64, 36, c("g"))
	rect(img, 64, 10, 64, 14, c("b"))
	rect(img, 64, 34, 64, 12, c("l", 0, 0.1))
	rect(img, 94, 10, 3, 36, c("T"))
	rect(img, 64, 27, 64, 3, c("T"))
	block(img, 58, 4, 76, 4, "h")
	# 桌上的信：信封 + 露出的信纸。letter_x 是信封左边，信和钥匙一起动。
	rect(img, letter_x, 46, 46, 26, c("X", 0, 0.08))
	rect(img, letter_x, 46, 46, 2, c("x"))
	for i in 12:
		rect(img, letter_x + 6 + i, 52 + i / 2, 1, 1, c("M", 0, 0.25))
		rect(img, letter_x + 39 - i, 52 + i / 2, 1, 1, c("M", 0, 0.25))
	rect(img, letter_x + 6, 50, 34, 2, c("B"))
	rect(img, letter_x + 20, 62, 6, 6, c("R"))
	key(img, letter_x + 54, 74)


## 井口的石灯：黑着的灯室、石座、苔痕。
static func unlit_lamp(img: Image, drift: int = 0) -> void:
	sky(img, c("p", 0, 0.45), c("P", 0, 0.2), 76, c("e", 0.1), c("p", 0, 0.5))
	# 飘着的雾：一缕缕横过中景
	for i in 5:
		var y := 30 + i * 9
		rect(img, 6 + (i % 2) * 10 + drift, y, 48, 4, c("g", 0.05))
		rect(img, 140 - (i % 3) * 8 - drift, y + 3, 44, 4, c("g", 0.03))
	blit_lamp(img, 80, 24, false)


## 梯子下井：井壁砖纹、一盏盏小灯、脚下的暗。
static func shaft(img: Image, drip: int = 0) -> void:
	img.fill(c("e", 0.05))
	# 错缝砖墙：每层错开半块，比棋盘格像井壁
	for row in 14:
		var offset := 0 if row % 2 == 0 else 10
		for col in 11:
			var x := col * 20 - offset
			rect(img, x, row * 8, 19, 7, c("M", 0, 0.44))
			rect(img, x, row * 8, 19, 1, c("M", 0, 0.34))
	# 井口透下来的一束光
	for i in 6:
		rect(img, 60 + i, 0, 72 - i * 2, 12 + i * 6, c("b", 0, 0.5 - i * 0.07))
	# 梯子：两根边梁 + 横档 + 影
	rect(img, 80, 0, 6, 108, c("H", 0, 0.25))
	rect(img, 106, 0, 6, 108, c("H", 0, 0.25))
	block(img, 84, 0, 22, 108, "t")
	for i in 12:
		rect(img, 84, i * 9 + 3, 22, 3, c("T"))
		rect(img, 84, i * 9 + 6, 22, 1, c("H", 0, 0.3))
	# 挂在梯上的小灯，一盏盏往下
	for i in 7:
		var y := 10 + i * 14
		rect(img, 78, y, 2, 5, c("k"))
		rect(img, 76, y + 5, 6, 7, c("y"))
		rect(img, 77, y + 6, 4, 4, c("x"))
	# 井壁渗的水
	for i in 4:
		rect(img, 24 + i * 38, 30 + (i % 2) * 20 + drip % 28, 2, 12, c("g", 0, 0.2))


## 火苗被划着：夜色、石灯、跳动的火、光晕。
static func flame_scene(img: Image, power: float = 1.0, _wobble: float = 0.0) -> void:
	sky(img, c("p", 0, 0.5), c("P", 0, 0.3), 78, c("e", 0.1), c("p", 0, 0.55))
	blit_lamp(img, 100, 26, power > 0.45)


## 雾往灯里走：中心一盏暖灯，两侧一条条雾带卷进来。
static func inward(img: Image, gather: float = 0.0, _t: float = 0.0) -> void:
	img.fill(c("p", 0, 0.42))
	rect(img, 0, 78, W, 30, c("e", 0.1))
	# 细雾往灯收，留出中间给井灯和白鹿，不再铺大色块。
	for i in 5:
		var y := 18 + i * 8
		var x := int(lerpf(6.0, 36.0, gather)) + i * 2
		var xr := int(lerpf(150.0, 118.0, gather)) - i * 2
		rect(img, x, y, 22, 2, c("g", 0.1))
		rect(img, xr, y + 2, 20, 2, c("g", 0.06))
	blit_lamp(img, 80, 28, true)


## 空祠：用山祠那座古祠，匾还是空的，阶前有落叶。
static func empty_shrine(img: Image, leaf: float = 0.0) -> void:
	sky(img, c("g", 0.1), c("b", 0.05), 70, c("l", 0, 0.2), c("g", 0, 0.15))
	# 放在 (52, 16)，(96, 84) 正好落在石阶上。
	blit_prop(img, "shrine", ShrineArt.shrine(), 52, 16)
	for i in 12:
		var x := 40 + (i * 17) % 116
		var y := 96 + (i % 3) * 3
		if leaf > 0.001:
			x = 40 + (i * 17 + int(leaf * 14.0)) % 116
			y = 90 + int(leaf * 16.0 + float(i) * 3.0) % 16
		px(img, x, y, c("r", 0, 0.1))


## 十几只手拢着火苗：一排手从下方伸进来，围住中心的光。
static func hands(img: Image, _drop: int = 0, _t: float = 0.0) -> void:
	img.fill(c("e", 0.08))
	rect(img, 0, 86, W, 22, c("H", 0, 0.2))
	blit_lamp(img, 80, 34, true)


## 白鹿从灯光里走出来。静帧是它走到光外面的那一步。
static func step_out(img: Image) -> void:
	_step_bg(img)


static func _step_bg(img: Image) -> void:
	sky(img, c("p", 0.02), c("S", 0.05), 74, c("l", 0, 0.15), c("p", 0.1))
	blit_lamp(img, 150, 28, true)


## 桂花树下的白鹿。静帧是它已经卧下的样子。
static func tree(img: Image) -> void:
	_tree_bg(img, 0.0)


static func _tree_bg(img: Image, petal: float) -> void:
	sky(img, c("S", 0.08), c("y", 0.1), 76, c("l", 0, 0.1), c("g", 0, 0.1))
	# 秋天的桂花树，就是山祠旁边那一棵。锚点 (20, 50)，脚落在 (148, 100)。
	blit_prop(img, "osmanthus", ShrineArt.osmanthus(2), 128, 50)
	if petal <= 0.001:
		return
	for k in 8:
		var fy := 40 + int(petal * 50.0 + float(k) * 6.0) % 48
		px(img, 120 + (k * 7) % 36, fy, c("y"))


## 镇上的灯亮着，雾停在山腰：远山、屋舍灯火、半山一条雾带。
static func hill(img: Image, u: float = 1.0) -> void:
	sky(img, c("p", 0, 0.35), c("P", 0, 0.1), 64, c("g", 0, 0.2), c("M", 0, 0.2))
	# 雾从山上沉到山腰就停住
	var fog_y := int(lerpf(22.0, 44.0, clampf(u * 1.25, 0.0, 1.0)))
	var dy := fog_y - 44
	rect(img, 0, 44 + dy, W, 12, c("b", 0.15))
	for i in 6:
		rect(img, 8 + i * 32, 42 + (i % 2) * 3 + dy, 24, 6, c("x", 0, 0.06))
	for i in 8:
		rect(img, 4 + i * 24, 46 + (i % 3) * 4 + dy, 20, 4, c("m", 0.05))
	# 山脚的屋舍与灯火：白墙、黛瓦、暖窗
	for i in 6:
		var x := 16 + i * 28
		block(img, x, 70, 16, 12, "b")
		rect(img, x + 1, 71, 14, 4, c("B", 0, 0.1))
		block(img, x - 2, 67, 20, 4, "T")
		if u >= float(i) / 7.0:
			rect(img, x + 6, 74, 4, 4, c("y"))
			rect(img, x + 7, 75, 2, 2, c("x"))
			px(img, x + 8, 73, c("Y"))
		else:
			rect(img, x + 6, 74, 4, 4, c("e", 0.1))
	# 地上的灯影
	for i in 6:
		if u < float(i) / 7.0:
			continue
		var x := 18 + i * 28
		rect(img, x, 83, 8, 2, c("y", 0, 0.3))


## 姜婆婆多摆了一副碗筷：木桌、两副碗、灶上的热气。
static func bowl(img: Image, u: float = 1.0, t: float = 0.0) -> void:
	# 屋里：墙、灶台、灶火，比纯深底丰富
	img.fill(c("h", 0, 0.28))
	rect(img, 0, 20, W, 50, c("H", 0, 0.18))
	block(img, 132, 30, 50, 32, "M")
	rect(img, 140, 40, 34, 18, c("H", 0, 0.1))
	rect(img, 150, 48, 14, 8, c("r", 0, 0.1))
	rect(img, 153, 50, 8, 5, c("y"))
	# 木桌与木纹
	rect(img, 0, 30, W, 78, c("H", 0, 0.08))
	for i in 10:
		rect(img, 0, 34 + i * 7, W, 1, c("H", 0, 0.02))
	block(img, 48, 62, 96, 8, "h")
	# 两副碗筷：碗身、碗口、高光、筷子
	for i in 2:
		var x := 70 if i == 0 else int(lerpf(168.0, 96.0, u))
		rect(img, x, 56, 10, 6, c("X"))
		rect(img, x + 1, 55, 8, 2, c("x"))
		rect(img, x + 2, 56, 3, 2, c("x", 0.12))
		rect(img, x + 10, 54, 2, 9, c("t"))
		rect(img, x + 13, 54, 2, 9, c("T"))
		rect(img, x + 10, 54, 5, 1, c("t", 0.12))
	# 灶上的热气：两档深浅
	var rise := int(t * 12.0) % 9
	for i in 4:
		rect(img, 150 + i * 3, 40 - i * 8 - rise, 2, 10, c("g", 0.12))
		rect(img, 156 + i * 2, 36 - i * 7 - rise, 1, 8, c("x", 0, 0.1))


## 片尾：夜色里一排人影，中间一行字。
static func credits(img: Image, u: float = 1.0) -> void:
	# 夜空上深下浅，几点星
	img.fill(c("p", 0, 0.5))
	rect(img, 0, 40, W, 44, c("p", 0, 0.36))
	for i in 18:
		var sx := (i * 37 + 11) % W
		var sy := 4 + (i * 23) % 40
		px(img, sx, sy, c("x", 0, 0.15) if (i + int(u * 6.0)) % 3 == 0 else c("g", 0.05))
	# 远山剪影
	for i in 3:
		var bx := 30 + i * 70
		for row in 12:
			rect(img, bx - row, 68 - 12 + row, row * 2 + 1, 1, c("p", 0, 0.58))
	# 地面：草与土两层
	rect(img, 0, 84, W, 24, c("g", 0, 0.25))
	rect(img, 0, 96, W, 12, c("H", 0, 0.28))
	# 人用游戏里的序列帧贴。片名在字幕里，不再盖一块空牌子。


static func _ease(u: float) -> float:
	var t := clampf(u, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## 窗外一棵小树。画在窗框之前，开出玻璃的部分会被窗框盖住。
static func _pine(img: Image, x: int, y: int) -> void:
	rect(img, x - 1, y, 3, 8, c("h"))
	for row in 7:
		var w := 15 - row * 2
		rect(img, x - w / 2, y - 14 + row * 2, w, 2, c("l", 0, 0.08 * float(row % 2)))


static var _lamps: Dictionary = {}
static var _props: Dictionary = {}


## 游戏里那盏井灯。原图 16×26，过场里放大两倍，还是同一盏。
static func blit_lamp(img: Image, left: int, top: int, lit: bool) -> void:
	if not _lamps.has(lit):
		var src := MineArt.lamp(lit)
		var big := src.duplicate()
		big.resize(32, 52, Image.INTERPOLATE_NEAREST)
		_lamps[lit] = big
	var lamp: Image = _lamps[lit]
	img.blend_rect(lamp, Rect2i(0, 0, lamp.get_width(), lamp.get_height()), Vector2i(left, top))


static func blit_prop(img: Image, key: String, source: Image, left: int, top: int) -> void:
	if not _props.has(key):
		_props[key] = source
	var spr: Image = _props[key]
	img.blend_rect(spr, Rect2i(0, 0, spr.get_width(), spr.get_height()), Vector2i(left, top))


## 这一刻的画面。u、t 都是这一段里的时间，u 已经收在 0 到 1。
static func at(id: StringName, u: float, t: float) -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var e := _ease(u)
	match id:
		&"desk":
			desk(img, int(lerpf(148.0, 76.0, e)))
		&"letter":
			letter(img, u)
		&"window":
			window_scene(img, true, u * 96.0)
		&"end_flame":
			flame_scene(img, clampf((u - 0.55) / 0.45, 0.0, 1.0), t * 11.0)
		&"end_inward":
			inward(img, e, t)
		&"end_empty":
			empty_shrine(img, u)
		&"end_hands":
			hands(img)
		&"end_step":
			_step_bg(img)
		&"end_tree":
			_tree_bg(img, u)
		&"end_unlit":
			unlit_lamp(img, int(t * 7.0))
		&"end_climb":
			shaft(img, int(t * 16.0))
		&"end_hill":
			hill(img, e)
		&"end_bowl":
			bowl(img, e, t)
		&"end_seats":
			seats(img)
		&"end_roster":
			roster(img)
		&"end_names":
			name_hill(img)
		&"end_plaque":
			plaque_scene(img)
		&"end_mail":
			mail(img)
		&"end_dock":
			dock(img)
		&"end_stub":
			stub_close(img)
		&"credits":
			credits(img, e)
		_:
			img.fill(Color(0, 0, 0, 0))
	return img


## 二十八副碗筷排成一长桌。人不在这里画。
static func seats(img: Image) -> void:
	img.fill(c("d"))
	rect(img, 0, 78, W, 30, c("w"))
	rect(img, 8, 62, 176, 22, c("h"))
	rect(img, 12, 66, 168, 12, c("r"))
	var bowls := 28
	var span := 160
	for i in bowls:
		var x := 16 + int(float(i) * float(span) / float(bowls - 1))
		rect(img, x, 68, 3, 2, c("x"))
		px(img, x + 1, 70, c("X"))


## 二十八行。前二十七行墨被水冲淡，最后一行还在，而且比上面的长。
static func roster(img: Image) -> void:
	img.fill(c("H", 0, 0.3))
	rect(img, 24, 6, 144, 96, c("x"))
	rect(img, 24, 6, 144, 2, c("X"))
	rect(img, 24, 100, 144, 2, c("X"))
	for i in 28:
		var y := 14 + i * 3
		var ink := c("e", 0.62) if i < 27 else c("e")
		var wide := 72 if i < 27 else 104
		rect(img, 36, y, wide, 1, ink)


## 后山。白泽由过场贴上去。
static func name_hill(img: Image) -> void:
	img.fill(c("g", 0.15))
	rect(img, 0, 70, W, 38, c("L", 0, 0.15))
	for x in W:
		var hill := 58 + int(sin(float(x) * 0.08) * 8.0)
		rect(img, x, hill, 1, 70 - hill, c("L"))
	rect(img, 0, 78, W, 30, c("l", 0, 0.05))


## 屋檐下那块匾的近景。字和农场上挂的是同一块。
static func plaque_scene(img: Image) -> void:
	img.fill(c("b"))
	rect(img, 0, 0, W, 16, c("M", 0, 0.2))
	rect(img, 0, 16, W, 4, c("h"))
	var mark := EndingArt.plaque()
	mark.resize(90, 48, Image.INTERPOLATE_NEAREST)
	img.blend_rect(mark, Rect2i(0, 0, 90, 48), Vector2i(51, 28))


## 东滩。灯塔、栈桥、往外开的船。人不画在这张底上。
static func dock(img: Image) -> void:
	img.fill(c("g", 0.22))
	rect(img, 0, 58, W, 50, c("p"))
	rect(img, 0, 70, W, 6, c("p", 0.12))
	rect(img, 0, 84, 128, 24, c("d"))
	rect(img, 0, 84, 128, 2, c("d", 0.14))
	block(img, 18, 28, 14, 56, "m")
	rect(img, 14, 24, 22, 6, c("M"))
	rect(img, 22, 14, 6, 12, c("q"))
	rect(img, 23, 16, 4, 4, c("y"))
	rect(img, 62, 80, 72, 5, c("w"))
	rect(img, 62, 85, 72, 2, c("W"))
	rect(img, 70, 72, 4, 14, c("T"))
	rect(img, 122, 72, 4, 14, c("T"))
	# 船在栈桥外面的水上，船头朝右
	rect(img, 142, 70, 32, 10, c("h"))
	rect(img, 142, 70, 32, 2, c("w", 0.16))
	rect(img, 174, 72, 8, 6, c("h"))
	rect(img, 182, 74, 6, 3, c("W"))
	rect(img, 146, 78, 36, 2, c("W"))
	rect(img, 156, 62, 14, 8, c("w"))
	rect(img, 162, 50, 2, 20, c("T"))
	var slip := EndingArt.ticket_half()
	img.blend_rect(slip, Rect2i(0, 0, slip.get_width(), slip.get_height()), Vector2i(76, 60))


## 码头桩上那半张船票的近景。右边是撕开的，钉在木桩上。
static func stub_close(img: Image) -> void:
	img.fill(c("p"))
	for i in 5:
		rect(img, 0, 8 + i * 14, W, 4, c("p", 0.1) if i % 2 == 0 else c("P"))
	rect(img, 0, 86, W, 22, c("d"))
	rect(img, 0, 86, W, 2, c("d", 0.16))
	for i in 8:
		px(img, 8 + i * 22, 96, c("K"))
		px(img, 16 + i * 22, 102, c("d", 0.18))
	block(img, 108, 18, 14, 72, "t")
	rect(img, 112, 22, 2, 64, c("T"))
	rect(img, 116, 22, 2, 64, c("h"))
	var slip := EndingArt.ticket_half()
	slip.resize(72, 56, Image.INTERPOLATE_NEAREST)
	img.blend_rect(slip, Rect2i(0, 0, 72, 56), Vector2i(48, 26))
	rect(img, 70, 30, 2, 46, c("X"))
	rect(img, 50, 80, 56, 2, c("P"))
	rect(img, 108, 48, 3, 3, c("e"))


## 城里寄来的信。没有钥匙，不是开场那一封。
static func mail(img: Image) -> void:
	img.fill(c("H", 0, 0.2))
	rect(img, 28, 16, 136, 76, c("x"))
	rect(img, 28, 16, 136, 2, c("X"))
	rect(img, 28, 90, 136, 2, c("X"))
	rect(img, 28, 16, 2, 76, c("X"))
	rect(img, 162, 16, 2, 76, c("X"))
	var widths: Array[int] = [88, 104, 72, 96, 60, 84]
	for i in widths.size():
		rect(img, 40, 28 + i * 8, widths[i], 2, c("e", 0.35))
	rect(img, 132, 70, 16, 12, c("r"))
	rect(img, 136, 74, 8, 4, c("R"))
