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


## 岚：一头白鹿，48×46，朝右，比人高一头。身子发白发青，四条腿往下淡成雾，外面一圈淡青的边
## （不描黑边：它不是实的；可没有边在雪地和雾里就看不见了）。frame 0 抬着头，1 耳朵动一下、头低一点。
## 锚点在 (22, 45)。
static func deer(frame: int = 0) -> Image:
	var img := Px.new_img(48, 46)
	var white := Color.html("f6fbff")
	var pale := Color.html("d5e6f1")
	var shade := Color.html("a9c6da")
	var horn := Color.html("6f95b3")
	var dip := 1 if frame == 1 else 0
	# 四条腿：后腿在膝盖那儿往后弯一点；越往下越淡。远处的两条暗一档
	var legs: Array = [[11, 0, true], [15, -1, false], [28, 0, true], [32, 0, false]]
	for leg: Array in legs:
		var lx: int = leg[0]
		var far: bool = leg[2]
		for k in 15:
			var a := clampf(1.15 - k / 13.0, 0.0, 1.0)
			var x := lx + (int(leg[1]) if k > 6 else 0)
			var c := shade if far else pale
			Px.px(img, x, 28 + k, Color(c.r, c.g, c.b, a))
			if k < 9:
				var c2 := shade if not far else Color.html("93b4cb")
				Px.px(img, x + 1, 28 + k, Color(c2.r, c2.g, c2.b, a))
	# 屁股、身子、胸口
	_oval(img, 12.5, 23.5, 5.0, 5.0, white, pale, shade)
	_oval(img, 21.0, 24.5, 10.5, 4.0, white, pale, shade)
	_oval(img, 30.0, 23.0, 4.5, 6.0, white, pale, shade)
	# 尾巴
	Px.rect(img, 6, 19, 2, 3, white)
	Px.px(img, 6, 22, pale)
	# 脖子：从胸口斜着往上
	for i in 11:
		var nx := 30 + int(i * 0.5)
		var ny := 19 - i + dip
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
	if frame == 1:
		Px.rect(img, 32, 7 + dip, 3, 1, pale)
		Px.px(img, 31, 7 + dip, shade)
	else:
		Px.px(img, 34, 6, pale)
		Px.px(img, 33, 5, pale)
		Px.px(img, 32, 4, shade)
	# 外面一圈淡青的边
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
				var fade := clampf(1.0 - (n.y - 30) / 12.0, 0.0, 1.0) if n.y > 30 else 1.0
				img.set_pixel(n.x, n.y, Color(edge.r, edge.g, edge.b, 0.85 * fade))
	# 角：两枝，往后上方伸，各分一叉。放在描边之后画，细线再描边就糊了
	# 远的一枝往后仰，近的一枝直着往上、朝前分一叉
	Px.line(img, Vector2i(36, 5 + dip), Vector2i(31, 1 + dip), edge)
	Px.line(img, Vector2i(33, 3 + dip), Vector2i(33, dip), edge)
	Px.line(img, Vector2i(38, 5 + dip), Vector2i(37, dip), horn)
	Px.line(img, Vector2i(38, 3 + dip), Vector2i(41, 1 + dip), horn)
	# 脚下的一小团雾
	for x in range(4, 40):
		var a := 0.4 - absf(x - 22.0) / 45.0
		if a > 0.0:
			for y in range(42, 46):
				var old := img.get_pixel(x, y)
				if old.a < a:
					img.set_pixel(x, y, Color(1, 1, 1, a * (1.0 if y < 45 else 0.5)))
	return img


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
