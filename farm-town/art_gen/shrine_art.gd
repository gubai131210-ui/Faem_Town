class_name ShrineArt
extends RefCounted
## 山祠上的东西：古祠、挂祈愿牌的木架、桂花树，还有岚（一头白鹿）。都是代码画的，锚点在底边正中。

const WOOD := "7a5236"
const WOOD_DARK := "523522"
const WOOD_LIGHT := "9a6e48"


## 古祠，88×80：石台基，发黑的木墙，两根褪色的红柱，一大片灰瓦顶，门楣上的匾是空的。
static func shrine() -> Image:
	var img := Px.new_img(88, 80)
	var stone := Color.html("8f8a7e")
	var stone_d := Color.html("6c675d")
	var stone_l := Color.html("aaa598")
	var wall := Color.html(WOOD)
	var wall_d := Color.html(WOOD_DARK)
	var pillar := Color.html("9c4a3c")
	var pillar_d := Color.html("74342a")
	var tile := Color.html("5d6468")
	var tile_d := Color.html("454b50")
	var tile_l := Color.html("7a8388")
	# 台基和三级台阶
	Px.rect(img, 6, 68, 76, 11, stone)
	Px.rect(img, 6, 68, 76, 1, stone_l)
	Px.rect(img, 6, 76, 76, 3, stone_d)
	for x in range(14, 82, 11):
		Px.rect(img, x, 69, 1, 7, stone_d)
	Px.rect(img, 32, 70, 24, 9, stone_l)
	for i in 3:
		Px.rect(img, 32, 71 + i * 3, 24, 1, stone_d)
	# 木墙
	Px.rect(img, 10, 40, 68, 28, wall)
	for x in range(13, 78, 5):
		Px.rect(img, x, 40, 1, 28, wall_d)
	Px.rect(img, 10, 40, 68, 3, wall_d)
	# 门洞：里面是黑的，只看得见一点供桌的边
	Px.rect(img, 33, 46, 22, 22, Color.html("1e1a1c"))
	Px.rect(img, 38, 61, 12, 2, Color.html("4a3626"))
	Px.rect(img, 43, 57, 2, 4, Color.html("6a6a72"))
	Px.rect(img, 31, 44, 26, 2, wall_d)
	# 门两边的格子窗
	for wx: int in [15, 61]:
		Px.rect(img, wx, 48, 12, 12, wall_d)
		for k in 3:
			Px.rect(img, wx + 1 + k * 4, 49, 2, 10, Color.html("2a2426"))
	# 柱子
	for px_: int in [28, 57]:
		Px.rect(img, px_, 40, 3, 28, pillar)
		Px.rect(img, px_ + 2, 40, 1, 28, pillar_d)
		Px.rect(img, px_ - 1, 66, 5, 2, stone_d)
	# 空着的匾
	Px.rect(img, 34, 35, 20, 8, Color.html("2e2622"))
	Px.rect(img, 35, 36, 18, 6, Color.html("5a4a3a"))
	Px.rect(img, 37, 38, 14, 2, Color.html("66564a"))
	# 瓦顶：中间高，两头的檐角往上翘
	for i in 15:
		var y := 8 + i * 2
		var hw := 22 + i * 1.5
		var c := tile if i % 2 == 0 else tile_d
		Px.rect(img, 44 - int(hw), y, int(hw) * 2, 2, c)
	for x in range(4, 84, 4):
		Px.rect(img, x, 36, 2, 2, tile_l)
	Px.rect(img, 1, 37, 86, 2, tile_d)
	Px.rect(img, 1, 39, 86, 1, Color.html("2c3034"))
	# 檐角
	for side: int in [0, 1]:
		var sx := 1 if side == 0 else 83
		Px.rect(img, sx, 34, 4, 3, tile_d)
		Px.rect(img, sx if side == 0 else sx + 2, 31, 2, 3, tile_d)
	# 屋脊
	Px.rect(img, 20, 5, 48, 3, tile_d)
	Px.rect(img, 20, 5, 48, 1, tile_l)
	Px.rect(img, 18, 3, 4, 4, tile_d)
	Px.rect(img, 66, 3, 4, 4, tile_d)
	# 瓦缝里长的草
	for gx: int in [26, 51, 63]:
		Px.px(img, gx, 21 + gx % 5, Color.html("6f9a52"))
		Px.px(img, gx + 1, 20 + gx % 5, Color.html("86b062"))
	return Px.outline(img)


## 挂祈愿牌的木架，36×26：两根柱子一根横梁，底下挂着两排小木牌，字都没了。
static func plaque_rack() -> Image:
	var img := Px.new_img(36, 26)
	var wood := Color.html(WOOD)
	var wood_d := Color.html(WOOD_DARK)
	var wood_l := Color.html(WOOD_LIGHT)
	Px.rect(img, 3, 3, 3, 22, wood)
	Px.rect(img, 5, 3, 1, 22, wood_d)
	Px.rect(img, 30, 3, 3, 22, wood)
	Px.rect(img, 32, 3, 1, 22, wood_d)
	Px.rect(img, 1, 3, 34, 3, wood_l)
	Px.rect(img, 1, 5, 34, 1, wood_d)
	Px.rect(img, 6, 13, 24, 1, wood_d)
	var tints: Array[String] = ["c9b088", "b89c74", "d6c098", "a88c66"]
	for row in 2:
		for k in 5:
			var x := 7 + k * 5 - row
			var y := 7 + row * 8
			if row == 1 and k == 3:
				# 断了绳子的那一块：只剩一截绳头
				Px.px(img, x + 1, y, Color.html("8a3a30"))
				continue
			Px.px(img, x + 1, y - 1, Color.html("8a3a30"))
			Px.rect(img, x, y, 3, 5, Color.html(tints[(k + row) % 4]))
			Px.px(img, x + 2, y + 4, wood_d)
	return Px.outline(img)


## 桂花树，40×52：矮而密的深绿树冠。秋天满树碎金，冬天顶上落一层雪。锚点在 (20, 50)。
## season：0 春 1 夏 2 秋 3 冬。
static func osmanthus(season: int = 0) -> Image:
	var img := Px.new_img(40, 52)
	var bark := [Color.html("8a6a48"), Color.html("6c5034"), Color.html("4e3824")]
	for y in range(34, 50):
		var half := 2 if y < 47 else 3
		for x in range(20 - half, 20 + half):
			img.set_pixel(x, y, bark[0] if x == 20 - half else (bark[2] if x >= 20 + half - 1 else bark[1]))
	var leaf := [Color.html("5f9a58"), Color.html("3f7f45"), Color.html("2f6638"), Color.html("234e2c")]
	var body: Array = [Vector3(20, 18, 13), Vector3(10, 24, 8), Vector3(30, 24, 8), Vector3(20, 28, 10)]
	for y in 42:
		for x in 40:
			var inside := false
			for cv: Vector3 in body:
				if Vector2(x + 0.5 - cv.x, y + 0.5 - cv.y).length() < cv.z:
					inside = true
					break
			if not inside:
				continue
			var n := Vector2(x + 0.5 - 20.0, y + 0.5 - 20.0) / 16.0
			var col: Color = leaf[2]
			if n.dot(Vector2(0.5, 0.86)) > 0.5:
				col = leaf[3]
			elif n.dot(Vector2(-0.6, -0.8)) > 0.45:
				col = leaf[1]
			img.set_pixel(x, y, col)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4107
	# 叶簇上的亮点
	for i in 46:
		var x := rng.randi_range(4, 35)
		var y := rng.randi_range(6, 34)
		if img.get_pixel(x, y).a == 0.0:
			continue
		img.set_pixel(x, y, leaf[0] if y < 22 else leaf[1])
	if season == 2:
		for i in 70:
			var x := rng.randi_range(3, 36)
			var y := rng.randi_range(6, 36)
			if img.get_pixel(x, y).a == 0.0:
				continue
			img.set_pixel(x, y, Color.html("f6b83a") if i % 3 != 0 else Color.html("ffd76a"))
	elif season == 3:
		for y in range(1, 30):
			for x in 40:
				if img.get_pixel(x, y).a > 0.0 and img.get_pixel(x, y - 1).a == 0.0:
					img.set_pixel(x, y, Color.html("f4f8fb"))
					if rng.randf() < 0.6 and img.get_pixel(x, y + 1).a > 0.0:
						img.set_pixel(x, y + 1, Color.html("dfe8ee"))
	return Px.outline(img)


## 岚：一头白鹿，48×46，朝右，比人高一头。身子发白发青，外面一圈淡青的边
## （不描黑边：它不是实的；可没有边在雪地和雾里就看不见了）。
## 站着的两帧：frame 0 抬着头，1 耳朵动一下、头低一点；四条腿站直，蹄子落在地上。
## 锚点在 (22, 45)。
static func deer(frame: int = 0) -> Image:
	return _deer_img(0.0, false, frame == 1)


## 走路的八帧：四拍步，后左、前左、后右、前右依次抬起迈出，一条腿在空中，其余三条踩地；
## 每条腿分大腿和小腿，膝盖弯着，抬起来再落下。身子随步子一上一下，头跟着轻轻点。frame 取 0..7。
## 锚点同站着的鹿，(22, 45)。
static func deer_walk(frame: int) -> Image:
	return _deer_img(float(posmod(frame, 8)) / 8.0, true, false)


static func _deer_img(phase: float, walking: bool, low: bool) -> Image:
	var img := Px.new_img(48, 46)
	var white := Color.html("f6fbff")
	var pale := Color.html("d5e6f1")
	var shade := Color.html("a9c6da")
	var horn := Color.html("6f95b3")
	var bob := 0
	var nod := 1 if low else 0
	if walking:
		bob = -1 if cos(phase * TAU * 2.0) > 0.45 else 0
		nod = 1 if sin(phase * TAU * 2.0 + 0.6) > 0.5 else 0
	var hip_y := 27 + bob
	# 远处的两条腿先画，暗一档
	_deer_leg(img, 14, hip_y, phase + 0.5, walking, -1, shade, Color.html("93b4cb"))
	_deer_leg(img, 31, hip_y, phase + 0.75, walking, 1, shade, Color.html("93b4cb"))
	# 屁股、身子、胸口
	_oval(img, 12.5, 23.5 + bob, 5.0, 5.0, white, pale, shade)
	_oval(img, 21.0, 24.5 + bob, 10.5, 4.0, white, pale, shade)
	_oval(img, 30.0, 23.0 + bob, 4.5, 6.0, white, pale, shade)
	# 尾巴：走的时候轻轻甩
	var wag := 0
	if walking:
		wag = int(round(sin(phase * TAU) * 1.0))
	Px.rect(img, 6 + wag, 19 + bob, 2, 3, white)
	Px.px(img, 6 + wag, 22 + bob, pale)
	# 近处的两条腿盖在身子上
	_deer_leg(img, 12, hip_y, phase, walking, -1, white, pale)
	_deer_leg(img, 29, hip_y, phase + 0.25, walking, 1, white, pale)
	# 脖子：从胸口斜着往上
	var dip := nod + bob
	for i in 11:
		var nx := 30 + int(i * 0.5)
		var ny := 19 - i + dip + (bob if i < 4 else 0)
		Px.rect(img, nx, ny, 4, 1, white)
		Px.px(img, nx, ny, pale)
		Px.px(img, nx + 3, ny, pale if i > 2 else shade)
	# 头和嘴
	_oval(img, 38.5, 8.5 + dip, 4.0, 3.2, white, pale, shade)
	Px.rect(img, 41, 8 + dip, 4, 3, white)
	Px.rect(img, 41, 10 + dip, 3, 1, pale)
	Px.px(img, 45, 9 + dip, pale)
	Px.px(img, 45, 8 + dip, Color.html("7f9cb4"))
	Px.px(img, 39, 8 + dip, Color.html("2f4f6e"))
	# 耳朵
	if low:
		Px.rect(img, 32, 7 + dip, 3, 1, pale)
		Px.px(img, 31, 7 + dip, shade)
	else:
		Px.px(img, 34, 6 + dip, pale)
		Px.px(img, 33, 5 + dip, pale)
		Px.px(img, 32, 4 + dip, shade)
	# 外面一圈淡青的边；蹄子以下才淡掉
	var edge := Color.html("86a9c4")
	var solid: Array[Vector2i] = []
	for y in 46:
		for x in 48:
			if img.get_pixel(x, y).a >= 0.6:
				solid.append(Vector2i(x, y))
	for s in solid:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = s + d
			if n.x < 0 or n.y < 0 or n.x >= 48 or n.y >= 46:
				continue
			if img.get_pixel(n.x, n.y).a == 0.0:
				var fade := clampf(1.0 - (n.y - 43) / 3.0, 0.0, 1.0)
				img.set_pixel(n.x, n.y, Color(edge.r, edge.g, edge.b, 0.85 * fade))
	# 角：两枝，往后上方伸，各分一叉。放在描边之后画，细线再描边就糊了
	Px.line(img, Vector2i(36, 5 + dip), Vector2i(31, 1 + dip), edge)
	Px.line(img, Vector2i(33, 3 + dip), Vector2i(33, dip), edge)
	Px.line(img, Vector2i(38, 5 + dip), Vector2i(37, dip), horn)
	Px.line(img, Vector2i(38, 3 + dip), Vector2i(41, 1 + dip), horn)
	# 脚下一层很薄的雾：只在地面那一行，不盖住蹄子
	for x in range(4, 40):
		var a := 0.3 - absf(x - 22.0) / 55.0
		if a > 0.0:
			var old := img.get_pixel(x, 45)
			if old.a < a:
				img.set_pixel(x, 45, Color(1, 1, 1, a))
	return img


## 一条腿：大腿、膝盖、小腿、蹄。hip 是腿根，ph 是这条腿在步子里走到哪（0..1）。
## 0 到 0.62 踩在地上往后蹬，之后抬起来往前迈，迈到最高膝盖朝前顶。
## knee_dir：前腿膝盖朝前弯（1），后腿的踝朝后弯（-1）。站着时四条腿直立，只有后腿微微带一点弯。
static func _deer_leg(img: Image, hx: int, hy: int, ph: float, walking: bool, knee_dir: int, col: Color, col2: Color) -> void:
	var u := fposmod(ph, 1.0)
	var fx := 0.0
	var lift := 0.0
	if walking:
		if u < 0.62:
			fx = 4.5 - 9.0 * (u / 0.62)
		else:
			var s := (u - 0.62) / 0.38
			fx = -4.5 + 9.0 * s
			lift = 5.0 * sin(PI * s)
	var foot := Vector2i(hx + roundi(fx), 43 - roundi(lift))
	var bend := knee_dir * (1 + roundi(lift * 0.5)) if walking else (-1 if knee_dir < 0 else 0)
	var knee := Vector2i(hx + roundi(fx * 0.5) + bend, (hy + foot.y) / 2 - roundi(lift * 0.3))
	for dx in 2:
		var c := col if dx == 0 else col2
		Px.line(img, Vector2i(hx + dx, hy), Vector2i(knee.x + dx, knee.y), c)
		Px.line(img, Vector2i(knee.x + dx, knee.y), Vector2i(foot.x + dx, foot.y - 1), c)
	# 大腿根粗一点
	Px.px(img, hx - 1, hy, col)
	Px.px(img, hx + 2, hy, col2)
	Px.px(img, hx - 1, hy + 1, col)
	Px.px(img, hx + 2, hy + 1, col2)
	# 蹄
	var hoof := Color.html("7f9cb4")
	Px.rect(img, foot.x, foot.y - 1, 2, 2, hoof)


## 一个上亮下暗的椭圆：里面三档颜色。
static func _oval(img: Image, cx: float, cy: float, rx: float, ry: float, light: Color, mid: Color, dark: Color) -> void:
	for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
		for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			if dx * dx + dy * dy > 1.0:
				continue
			var c := light
			if dy > 0.55:
				c = dark
			elif dy > 0.1:
				c = mid
			Px.px(img, x, y, c)
