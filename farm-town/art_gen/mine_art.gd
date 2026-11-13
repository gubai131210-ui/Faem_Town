class_name MineArt
extends RefCounted
## 沉灯井里用代码画的东西：一层的地面和岩壁、石头和矿石、梯子、井灯、井口和升降机，还有镐子和矿石的图标。

const TS := 16
const FLOOR := "5c4b3d"
const FLOOR_LIGHT := "6a5847"
const FLOOR_DARK := "4a3c31"
const WALL := "211c1a"
const WALL_SPECK := "2b2522"
const FACE := "4f4038"
const FACE_LIGHT := "6b5a4c"
const FACE_DARK := "372c27"
const STONE := "8d8a86"
const WOOD := "9a6a40"
const WOOD_DARK := "6a4628"
## 每一段的颜色：地面三色、岩壁两色、墙面三色。没写的层段用浅坑的
const THEMES: Dictionary[StringName, Dictionary] = {
	&"shallow": {"floor": FLOOR, "light": FLOOR_LIGHT, "dark": FLOOR_DARK, "wall": WALL, "speck": WALL_SPECK,
		"face": FACE, "face_light": FACE_LIGHT, "face_dark": FACE_DARK},
	&"waterlogged": {"floor": "3f4e52", "light": "4c5e62", "dark": "303d42", "wall": "151c20", "speck": "1e282c",
		"face": "36474a", "face_light": "4d6466", "face_dark": "263336"},
	&"forgotten": {"floor": "54505e", "light": "625e6e", "dark": "423f4c", "wall": "1a1820", "speck": "24222c",
		"face": "5a4a50", "face_light": "786468", "face_dark": "3c3036"},
	&"lightless": {"floor": "3a3848", "light": "464458", "dark": "2c2a38", "wall": "0e0d14", "speck": "16151e",
		"face": "34324a", "face_light": "4a4866", "face_dark": "222032"},
}
const WATER := "4a8a9a"
const WATER_LIGHT := "7ab8c4"
const POOL := "1c3c52"
const POOL_LIGHT := "3a6a84"
const MOSS := "4a7a44"


## 一整层的地面贴图：open 里的是空地，其余是岩壁；空地上方紧挨着的那格岩壁画成朝南的墙面。
## theme 是层段的 id；water 是浅水，pools 是暗河。
static func ground(open: Dictionary, w: int, h: int, theme: StringName = &"shallow",
		water: Dictionary = {}, pools: Dictionary = {}) -> Image:
	var th: Dictionary = THEMES.get(theme, THEMES[&"shallow"])
	var img := Px.new_img(w * TS, h * TS)
	img.fill(Color.html(th["wall"]))
	for y in h:
		for x in w:
			var t := Vector2i(x, y)
			var ox := x * TS
			var oy := y * TS
			if open.has(t):
				_floor_tile(img, ox, oy, not open.has(t + Vector2i(0, -1)), th)
				if theme == &"waterlogged" and Px.h2(x * 3 + 1, y * 5 + 2) % 4 == 0:
					_moss(img, ox, oy)
				if pools.has(t):
					_pool_tile(img, ox, oy, pools, t)
				elif water.has(t):
					_water_tile(img, ox, oy)
			elif open.has(t + Vector2i(0, 1)):
				_face_tile(img, ox, oy, th)
				if theme == &"forgotten":
					_house_face(img, ox, oy, Px.h2(x * 11 + 5, y * 7 + 3))
				elif theme == &"waterlogged":
					_drip_face(img, ox, oy, Px.h2(x * 11 + 5, y * 7 + 3))
			else:
				for i in 5:
					var hx := Px.h2(x * 7 + i, y * 13 + i * 3)
					Px.px(img, ox + hx % TS, oy + (hx / 16) % TS, Color.html(th["speck"]))
	# 空地的左右两边贴着岩壁的地方压一道暗边，洞看起来有深度
	for y in h:
		for x in w:
			var t := Vector2i(x, y)
			if not open.has(t):
				continue
			if not open.has(t + Vector2i(-1, 0)):
				Px.rect(img, x * TS, y * TS, 1, TS, Color.html(th["dark"]))
			if not open.has(t + Vector2i(1, 0)):
				Px.rect(img, x * TS + TS - 1, y * TS, 1, TS, Color.html(th["dark"]))
			if not open.has(t + Vector2i(0, 1)):
				Px.rect(img, x * TS, y * TS + TS - 2, TS, 2, Color.html(th["wall"]))
	return img


## 浅水：盖一层半透明的水色，几道亮的水纹；看得见底下的地。
static func _water_tile(img: Image, ox: int, oy: int) -> void:
	var tint := Color.html(WATER)
	tint.a = 0.55
	for y in TS:
		for x in TS:
			img.set_pixel(ox + x, oy + y, img.get_pixel(ox + x, oy + y).blend(tint))
	for i in 3:
		var hx := Px.h2(ox + i * 7, oy + i * 13)
		Px.rect(img, ox + hx % (TS - 4), oy + 2 + (hx / 16) % (TS - 4), 3 + hx % 2, 1, Color.html(WATER_LIGHT))


## 暗河：深色的水，挨着岸的边上一道亮边。
static func _pool_tile(img: Image, ox: int, oy: int, pools: Dictionary, t: Vector2i) -> void:
	Px.rect(img, ox, oy, TS, TS, Color.html(POOL))
	for i in 2:
		var hx := Px.h2(ox + i * 9, oy + i * 5)
		Px.rect(img, ox + hx % (TS - 5), oy + 3 + (hx / 16) % (TS - 6), 4, 1, Color.html(POOL_LIGHT))
	var edge := Color.html(POOL_LIGHT)
	if not pools.has(t + Vector2i(0, -1)):
		Px.rect(img, ox, oy, TS, 2, Color.html("0e2030"))
		Px.rect(img, ox, oy + 2, TS, 1, edge)
	if not pools.has(t + Vector2i(0, 1)):
		Px.rect(img, ox, oy + TS - 1, TS, 1, edge)
	if not pools.has(t + Vector2i(-1, 0)):
		Px.rect(img, ox, oy, 1, TS, edge)
	if not pools.has(t + Vector2i(1, 0)):
		Px.rect(img, ox + TS - 1, oy, 1, TS, edge)


static func _moss(img: Image, ox: int, oy: int) -> void:
	var hx := Px.h2(ox + 3, oy + 7)
	var x0 := ox + 1 + hx % (TS - 6)
	var y0 := oy + 3 + (hx / 16) % (TS - 6)
	Px.rect(img, x0, y0, 4, 2, Color.html(MOSS))
	Px.px(img, x0 + 1, y0 - 1, Color.html(MOSS))
	Px.px(img, x0 + 2, y0, Color.html("6a9a5a"))


## 水渍层的墙面：有的往下淌着一道水。
static func _drip_face(img: Image, ox: int, oy: int, roll: int) -> void:
	if roll % 3 != 0:
		return
	var x0 := ox + 3 + roll / 8 % 10
	Px.rect(img, x0, oy + 2, 1, TS - 3, Color.html(WATER))
	Px.px(img, x0, oy + 4 + roll / 64 % 8, Color.html(WATER_LIGHT))
	Px.rect(img, x0 - 1, oy + TS - 3, 3, 1, Color.html(MOSS))


## 遗落层的墙面：有的是半截老屋的墙，带一扇窗或者一扇门。
static func _house_face(img: Image, ox: int, oy: int, roll: int) -> void:
	var kind := roll % 5
	if kind > 2:
		return
	Px.rect(img, ox, oy + 2, TS, TS - 5, Color.html("b8ac98"))
	Px.rect(img, ox, oy, TS, 2, Color.html("3a3a44"))
	Px.rect(img, ox, oy + TS - 3, TS, 3, Color.html("6a6258"))
	for i in 2:
		var hx := Px.h2(ox + i * 5, oy + i * 3)
		Px.rect(img, ox + hx % 12, oy + 4 + (hx / 16) % 7, 2, 1, Color.html("9a8e7c"))
	if kind == 0:
		# 窗：黑着
		Px.rect(img, ox + 4, oy + 4, 8, 7, Color.html("5a4030"))
		Px.rect(img, ox + 5, oy + 5, 6, 5, Color.html("14121a"))
		Px.rect(img, ox + 7, oy + 5, 1, 5, Color.html("5a4030"))
		Px.rect(img, ox + 5, oy + 7, 6, 1, Color.html("5a4030"))
	elif kind == 1:
		# 门：关着
		Px.rect(img, ox + 4, oy + 3, 8, TS - 3, Color.html("5a4030"))
		Px.rect(img, ox + 5, oy + 4, 6, TS - 4, Color.html("7a5a44"))
		Px.rect(img, ox + 8, oy + 4, 1, TS - 4, Color.html("5a4030"))
		Px.px(img, ox + 9, oy + 10, Color.html("c09a3e"))


static func _floor_tile(img: Image, ox: int, oy: int, under_wall: bool, th: Dictionary = THEMES[&"shallow"]) -> void:
	Px.rect(img, ox, oy, TS, TS, Color.html(th["floor"]))
	for i in 7:
		var hx := Px.h2(ox + i * 5, oy + i * 11)
		var c := Color.html(th["light"]) if i % 2 == 0 else Color.html(th["dark"])
		var px := ox + hx % TS
		var py := oy + (hx / 16) % TS
		Px.px(img, px, py, c)
		if i < 2 and px < ox + TS - 1:
			Px.px(img, px + 1, py, c)
	if under_wall:
		Px.rect(img, ox, oy, TS, 3, Color.html(th["dark"]))


static func _face_tile(img: Image, ox: int, oy: int, th: Dictionary = THEMES[&"shallow"]) -> void:
	Px.rect(img, ox, oy, TS, TS, Color.html(th["face"]))
	Px.rect(img, ox, oy, TS, 2, Color.html(th["face_light"]))
	Px.rect(img, ox, oy + TS - 3, TS, 3, Color.html(th["face_dark"]))
	# 几道石缝
	for i in 3:
		var hx := Px.h2(ox + i * 9, oy + i * 17)
		var x0 := ox + hx % (TS - 4)
		var y0 := oy + 3 + (hx / 16) % 8
		Px.rect(img, x0, y0, 3 + hx % 3, 1, Color.html(th["face_dark"]))
		Px.px(img, x0 + 1, y0 + 1, Color.html(th["face_light"]))


## 一块石头，16×16。fleck 不透明时石头上带这种颜色的矿点；variant 换一换形状。
static func rock(fleck: Color, variant: int) -> Image:
	var img := Px.new_img(16, 16)
	var cols := CropArt.ramp(Color.html(STONE))
	if variant % 2 == 0:
		CropArt.ball(img, 7.5, 10.0, 6.5, 4.6, cols)
		CropArt.ball(img, 9.5, 6.5, 4.0, 3.4, cols)
	else:
		CropArt.ball(img, 8.5, 10.0, 6.5, 4.6, cols)
		CropArt.ball(img, 6.0, 7.0, 3.6, 3.6, cols)
		CropArt.ball(img, 11.0, 7.5, 2.6, 2.4, cols)
	if fleck.a > 0.0:
		var spots: Array[Vector2i] = [Vector2i(5, 9), Vector2i(9, 6), Vector2i(11, 10), Vector2i(7, 12)]
		if variant % 2 == 1:
			spots = [Vector2i(6, 7), Vector2i(10, 9), Vector2i(4, 11), Vector2i(9, 12)]
		for p in spots:
			Px.rect(img, p.x, p.y, 2, 2, fleck)
			Px.px(img, p.x, p.y, fleck.lightened(0.35))
	return Px.outline(img)


## 往上的梯子，靠在墙上，16×28，底边对着格子底边。
static func ladder_up() -> Image:
	var img := Px.new_img(16, 28)
	Px.rect(img, 4, 0, 2, 28, Color.html(WOOD))
	Px.rect(img, 10, 0, 2, 28, Color.html(WOOD))
	Px.rect(img, 5, 0, 1, 28, Color.html(WOOD_DARK))
	Px.rect(img, 11, 0, 1, 28, Color.html(WOOD_DARK))
	for y in range(3, 28, 5):
		Px.rect(img, 4, y, 8, 2, Color.html(WOOD))
		Px.rect(img, 4, y + 1, 8, 1, Color.html(WOOD_DARK))
	return Px.outline(img)


## 往下的梯子：地上一个黑洞，露出梯子头，16×16。
static func ladder_down() -> Image:
	var img := Px.new_img(16, 16)
	CropArt.ball(img, 8.0, 9.0, 7.0, 5.5, [Color.html("1a1614"), Color.html("0e0c0b"), Color.html("060505")])
	Px.rect(img, 5, 4, 2, 8, Color.html(WOOD))
	Px.rect(img, 9, 4, 2, 8, Color.html(WOOD))
	Px.rect(img, 5, 6, 6, 1, Color.html(WOOD_DARK))
	Px.rect(img, 5, 9, 6, 1, Color.html(WOOD_DARK))
	return Px.outline(img)


## 井灯：一根石桩顶着一盏灯，16×26。
static func lamp(lit: bool) -> Image:
	var img := Px.new_img(16, 26)
	var stone := CropArt.ramp(Color.html("9a958c"))
	Px.rect(img, 6, 12, 4, 12, stone[1])
	Px.rect(img, 9, 12, 1, 12, stone[2])
	Px.rect(img, 4, 23, 8, 2, stone[1])
	Px.rect(img, 4, 24, 8, 1, stone[2])
	Px.rect(img, 4, 10, 8, 2, stone[0])
	Px.rect(img, 5, 3, 6, 7, Color.html("3a3430"))
	Px.rect(img, 6, 4, 4, 5, Color.html("ffd76a") if lit else Color.html("54504c"))
	if lit:
		Px.rect(img, 7, 5, 2, 3, Color.html("fff6c8"))
	Px.rect(img, 4, 2, 8, 1, stone[1])
	Px.rect(img, 6, 1, 4, 1, stone[2])
	return Px.outline(img)


## 井口：一堆山石中间一个木头撑起来的黑洞，64×52，底边中点对着洞口前面。
static func mouth() -> Image:
	var img := Px.new_img(64, 52)
	var cols := CropArt.ramp(Color.html("7d7870"))
	CropArt.ball(img, 32.0, 32.0, 30.0, 19.0, cols)
	CropArt.ball(img, 16.0, 26.0, 14.0, 14.0, cols)
	CropArt.ball(img, 46.0, 24.0, 16.0, 16.0, cols)
	CropArt.ball(img, 31.0, 16.0, 17.0, 13.0, cols)
	# 洞口
	Px.rect(img, 21, 24, 22, 27, Color.html("0c0a09"))
	Px.rect(img, 23, 22, 18, 2, Color.html("0c0a09"))
	# 木框
	Px.rect(img, 18, 22, 4, 29, Color.html(WOOD))
	Px.rect(img, 42, 22, 4, 29, Color.html(WOOD))
	Px.rect(img, 21, 22, 1, 29, Color.html(WOOD_DARK))
	Px.rect(img, 45, 22, 1, 29, Color.html(WOOD_DARK))
	Px.rect(img, 16, 18, 32, 4, Color.html(WOOD))
	Px.rect(img, 16, 21, 32, 1, Color.html(WOOD_DARK))
	# 往下的梯子头
	Px.rect(img, 27, 34, 2, 17, Color.html(WOOD_DARK))
	Px.rect(img, 35, 34, 2, 17, Color.html(WOOD_DARK))
	for y in range(37, 50, 4):
		Px.rect(img, 27, y, 10, 1, Color.html(WOOD_DARK))
	return Px.outline(img)


## 升降机：木架子吊着一只笼子，32×46。
static func lift() -> Image:
	var img := Px.new_img(32, 46)
	Px.rect(img, 3, 2, 3, 43, Color.html(WOOD))
	Px.rect(img, 26, 2, 3, 43, Color.html(WOOD))
	Px.rect(img, 5, 2, 1, 43, Color.html(WOOD_DARK))
	Px.rect(img, 28, 2, 1, 43, Color.html(WOOD_DARK))
	Px.rect(img, 1, 1, 30, 4, Color.html(WOOD))
	Px.rect(img, 1, 4, 30, 1, Color.html(WOOD_DARK))
	# 滑轮和绳子
	Px.rect(img, 14, 5, 4, 3, Color.html("54504c"))
	Px.rect(img, 15, 8, 2, 10, Color.html("c8b890"))
	# 笼子
	Px.rect(img, 8, 18, 16, 2, Color.html("7a7670"))
	Px.rect(img, 8, 40, 16, 3, Color.html("7a7670"))
	for x in [8, 12, 16, 20, 23]:
		Px.rect(img, x, 20, 1, 20, Color.html("9a958c"))
	Px.rect(img, 9, 20, 14, 20, Color.html("1a1614"))
	for x in [8, 12, 16, 20, 23]:
		Px.rect(img, x, 20, 1, 20, Color.html("9a958c"))
	return Px.outline(img)


## 守井人的小屋：木板墙、灰瓦顶，门边挂一盏矿灯，64×56，底边中点对着门口。
static func hut() -> Image:
	var img := Px.new_img(64, 56)
	var wall := Color.html("b8a888")
	var wall_d := Color.html("94846a")
	Px.rect(img, 6, 26, 52, 29, wall)
	for x in range(6, 58, 8):
		Px.rect(img, x, 26, 1, 24, wall_d)
	Px.rect(img, 6, 50, 52, 5, Color.html("7d7870"))
	Px.rect(img, 6, 54, 52, 1, Color.html("5e5a54"))
	# 烟囱在屋顶后面
	Px.rect(img, 45, 1, 6, 9, Color.html("7d7870"))
	Px.rect(img, 45, 1, 6, 2, Color.html("5e5a54"))
	# 瓦顶：一层比一层宽
	var roof := Color.html("5a5f6a")
	var roof_d := Color.html("434852")
	for i in 12:
		var hw := 20 + i
		Px.rect(img, 32 - hw, 4 + i * 2, hw * 2, 2, roof if i % 2 == 0 else roof_d)
	Px.rect(img, 12, 4, 40, 1, Color.html("767c88"))
	Px.rect(img, 1, 27, 62, 1, Color.html("2e3138"))
	# 门
	Px.rect(img, 26, 34, 12, 21, Color.html(WOOD))
	Px.rect(img, 26, 34, 12, 1, Color.html(WOOD_DARK))
	Px.rect(img, 26, 34, 1, 21, Color.html(WOOD_DARK))
	Px.rect(img, 37, 34, 1, 21, Color.html(WOOD_DARK))
	Px.rect(img, 31, 35, 1, 20, Color.html(WOOD_DARK))
	Px.px(img, 35, 45, Color.html("e0c060"))
	# 窗
	Px.rect(img, 44, 35, 10, 9, Color.html("3a3430"))
	Px.rect(img, 45, 36, 8, 7, Color.html("6a8494"))
	Px.rect(img, 48, 36, 1, 7, Color.html("3a3430"))
	Px.rect(img, 45, 39, 8, 1, Color.html("3a3430"))
	# 门边挂的矿灯
	Px.rect(img, 19, 33, 1, 3, Color.html("3a3430"))
	Px.rect(img, 17, 36, 5, 6, Color.html("3a3430"))
	Px.rect(img, 18, 37, 3, 4, Color.html("ffd76a"))
	Px.px(img, 19, 38, Color.html("fff6c8"))
	return Px.outline(img)


## 图标：pickaxe（镐子）、stone（石头），别的按矿石画：一小堆带矿点的碎石。
## tier：镐子的等级（0 铜 1 铁 2 银 3 金），镐头的颜色跟着变。
static func icon(id: StringName, tier: int = 0) -> Image:
	var img := Px.new_img(16, 16)
	if id == &"pickaxe":
		Px.line(img, Vector2i(3, 13), Vector2i(10, 6), Color.html(WOOD_DARK))
		Px.line(img, Vector2i(4, 13), Vector2i(11, 6), Color.html(WOOD))
		var metal: Array = PixelArt.TIER_COLORS[clampi(tier, 0, PixelArt.TIER_COLORS.size() - 1)]
		var steel := Color.html(str(metal[0]))
		var steel_d := Color.html(str(metal[1]))
		Px.line(img, Vector2i(5, 3), Vector2i(9, 3), steel)
		Px.line(img, Vector2i(9, 3), Vector2i(13, 7), steel)
		Px.line(img, Vector2i(13, 7), Vector2i(13, 10), steel)
		Px.line(img, Vector2i(6, 4), Vector2i(9, 4), steel_d)
		Px.line(img, Vector2i(9, 4), Vector2i(12, 7), steel_d)
		Px.px(img, 4, 4, steel_d)
		Px.px(img, 13, 11, steel_d)
		return Px.outline(img)
	var cols := CropArt.ramp(Color.html(STONE))
	CropArt.ball(img, 5.5, 10.5, 3.6, 3.0, cols)
	CropArt.ball(img, 10.5, 10.0, 3.8, 3.4, cols)
	CropArt.ball(img, 8.0, 6.5, 3.4, 3.0, cols)
	if id != &"stone":
		var fleck := Database.ore_color(id)
		for p: Vector2i in [Vector2i(4, 10), Vector2i(10, 9), Vector2i(7, 6), Vector2i(11, 11), Vector2i(8, 5)]:
			Px.rect(img, p.x, p.y, 2, 2, fleck)
			Px.px(img, p.x, p.y, fleck.lightened(0.35))
	return Px.outline(img)


# ---------------------------------------------------------------- 忘形和武器

## 忘形的几个姿势：idle_a / idle_b 平时来回换，windup 出招前，strike 出招，stun 起身和被砸晕，hidden 装成石头
const MONSTER_POSES: Array[StringName] = [&"idle_a", &"idle_b", &"windup", &"strike", &"stun", &"hidden"]
const EYE := "241c1a"
const EYE_ANGRY := "f0503a"


## 一只忘形的一个姿势，16×16（首领 32×32），朝右；朝左由画它的节点翻过来。
## skin：同一只有几副样子的时候是哪一副（戏班的面具），别的不用管。
static func monster(id: StringName, pose: StringName, skin: StringName = &"") -> Image:
	if MineDarkArt.has(id):
		return MineDarkArt.monster(id, &"idle_a" if pose == &"hidden" else pose, skin)
	if MineDeepArt.has(id):
		if pose == &"hidden":
			pose = &"idle_a"
		return MineDeepArt.monster(id, pose)
	if id == &"stone_crab":
		return _crab(pose)
	if id == &"bat":
		return _bat(pose)
	return _dust(pose)


## 尘团：一团灰，两只眼。平时一鼓一瘪，出招前压扁，冲出去时拉长。
static func _dust(pose: StringName) -> Image:
	var img := Px.new_img(16, 16)
	# 偏青白的雾色：和灰石头、褐色的地都分得开
	var cols := CropArt.ramp(Color.html("a8c4d2"))
	var cx := 8.0
	var cy := 10.0
	var rx := 5.5
	var ry := 4.5
	if pose == &"idle_b":
		rx = 6.0
		ry = 4.0
		cy = 10.5
	elif pose == &"windup" or pose == &"stun":
		rx = 6.8
		ry = 3.2
		cy = 11.5
	elif pose == &"strike":
		rx = 6.5
		ry = 3.8
		cy = 9.0
	CropArt.ball(img, cx, cy, rx, ry, cols)
	# 边上几撮散开的灰
	for i in 6:
		var hx := Px.h2(i * 7 + 3, int(rx * 10.0) + i)
		var ang := TAU * i / 6.0 + float(hx % 10) * 0.05
		Px.px(img, int(cx + cos(ang) * (rx + 0.6)), int(cy + sin(ang) * (ry + 0.6)), cols[1])
	var eye := Color.html(EYE_ANGRY) if pose == &"windup" or pose == &"strike" else Color.html(EYE)
	var ey := int(cy) - 1
	if pose == &"stun":
		Px.rect(img, 5, ey + 1, 2, 1, eye)
		Px.rect(img, 9, ey + 1, 2, 1, eye)
	else:
		Px.rect(img, 6, ey, 1, 2, eye)
		Px.rect(img, 10, ey, 1, 2, eye)
	return Px.outline(img)


## 石蟹：hidden 和井里的普通石头一模一样；醒了以后石头底下伸出腿和两只钳子。
static func _crab(pose: StringName) -> Image:
	if pose == &"hidden":
		return rock(Color(0, 0, 0, 0), 0)
	var img := Px.new_img(16, 16)
	var shell := Color.html("c0683c")
	var shell_d := Color.html("8a4428")
	var lift := 0 if pose == &"stun" else 2
	# 腿：两帧来回换
	var legs: Array[int] = [3, 5, 10, 12]
	if pose == &"idle_b":
		legs = [2, 6, 9, 13]
	if lift > 0:
		for x in legs:
			Px.rect(img, x, 13, 1, 2, shell_d)
	# 钳子：平时垂在两边，出招前举起来，出招时往前伸
	if pose == &"windup":
		Px.rect(img, 0, 4, 3, 3, shell)
		Px.rect(img, 13, 4, 3, 3, shell)
		Px.px(img, 1, 4, shell_d)
		Px.px(img, 14, 4, shell_d)
	elif pose == &"strike":
		Px.rect(img, 12, 8, 4, 2, shell)
		Px.rect(img, 12, 11, 4, 2, shell)
		Px.rect(img, 0, 10, 2, 2, shell)
	else:
		Px.rect(img, 0, 10 - lift / 2, 2, 3, shell)
		Px.rect(img, 14, 10 - lift / 2, 2, 3, shell)
	var body := Px.new_img(16, 16)
	var cols := CropArt.ramp(Color.html(STONE))
	CropArt.ball(body, 7.5, 10.0, 6.5, 4.6, cols)
	CropArt.ball(body, 9.5, 6.5, 4.0, 3.4, cols)
	Px.blit(img, body, 0, -lift)
	var eye := Color.html(EYE_ANGRY) if pose == &"windup" or pose == &"strike" else Color.html("ffe07a")
	if pose == &"stun":
		Px.rect(img, 5, 11, 2, 1, Color.html(EYE))
		Px.rect(img, 9, 11, 2, 1, Color.html(EYE))
	else:
		Px.rect(img, 5, 10 - lift, 2, 2, Color.html(EYE))
		Px.rect(img, 9, 10 - lift, 2, 2, Color.html(EYE))
		Px.px(img, 5, 10 - lift, eye)
		Px.px(img, 9, 10 - lift, eye)
	return Px.outline(img)


## 蝙蝠：小身子、两只耳朵，翅膀一上一下；出招前翅膀张到最大，俯冲时收在身后。
static func _bat(pose: StringName) -> Image:
	var img := Px.new_img(16, 16)
	var fur := Color.html("5a4670")
	var wing := Color.html("3c2e50")
	var wing_l := Color.html("6e5a88")
	if pose == &"idle_a" or pose == &"windup":
		# 翅膀朝上
		var span := 7 if pose == &"windup" else 6
		for i in span:
			var top := 4 + absi(i - 2)
			Px.rect(img, 7 - i, top, 1, 9 - top - (i / 3), wing)
			Px.rect(img, 8 + i, top, 1, 9 - top - (i / 3), wing)
		Px.px(img, 7 - span + 1, 4 + absi(span - 3), wing_l)
		Px.px(img, 8 + span - 1, 4 + absi(span - 3), wing_l)
	elif pose == &"strike":
		# 俯冲：翅膀收到身后
		Px.rect(img, 2, 6, 5, 2, wing)
		Px.rect(img, 1, 8, 4, 2, wing)
		Px.rect(img, 9, 5, 2, 2, wing)
	else:
		# 翅膀朝下
		for i in 6:
			var top := 8 + i / 2
			Px.rect(img, 7 - i, top, 1, 3, wing)
			Px.rect(img, 8 + i, top, 1, 3, wing)
		Px.px(img, 2, 12, wing_l)
		Px.px(img, 13, 12, wing_l)
	var by := 10 if pose == &"stun" else 8
	CropArt.ball(img, 7.5, float(by), 2.6, 3.0, [fur.lightened(0.15), fur, fur.darkened(0.25)])
	Px.px(img, 6, by - 4, fur)
	Px.px(img, 9, by - 4, fur)
	var eye := Color.html(EYE_ANGRY) if pose == &"windup" or pose == &"strike" else Color.html("ffe07a")
	Px.px(img, 6, by - 1, eye)
	Px.px(img, 9, by - 1, eye)
	return Px.outline(img)


## 武器的图标：sickle 镰刀、dagger 短剑、hammer 锤；首领掉的两件单独画：rail_hammer 道钉锤、fishbone_sickle 鱼骨镰。
static func weapon_icon(kind: StringName) -> Image:
	var img := Px.new_img(16, 16)
	var steel := Color.html("c3ccd6")
	var steel_d := Color.html("8a94a3")
	if kind == &"rail_hammer":
		# 石锤那样的方头，换成深色的铁，头更长，一头收尖，带锈
		Px.line(img, Vector2i(2, 14), Vector2i(8, 8), Color.html(WOOD_DARK))
		Px.line(img, Vector2i(3, 14), Vector2i(9, 8), Color.html(WOOD))
		var iron := CropArt.ramp(Color.html("565c68"))
		Px.rect(img, 4, 3, 9, 5, iron[1])
		Px.rect(img, 4, 3, 9, 1, iron[0])
		Px.rect(img, 4, 7, 9, 1, iron[2])
		Px.rect(img, 4, 3, 1, 5, iron[0])
		Px.rect(img, 13, 4, 1, 3, iron[1])
		Px.px(img, 14, 5, iron[2])
		for p: Vector2i in [Vector2i(6, 5), Vector2i(10, 4), Vector2i(11, 6)]:
			Px.px(img, p.x, p.y, Color.html("a8643c"))
		return Px.outline(img)
	if kind == &"fishbone_sickle":
		# 一根弯的背刺，骨白色，刃口发青，背上几根小刺
		var bone := Color.html("e8e2d0")
		var bone_d := Color.html("b8b09a")
		var edge := Color.html("7ab8c4")
		Px.line(img, Vector2i(4, 14), Vector2i(8, 7), Color.html("4a4e58"))
		Px.line(img, Vector2i(5, 14), Vector2i(9, 7), Color.html("6a6e78"))
		Px.line(img, Vector2i(8, 6), Vector2i(6, 4), bone)
		Px.line(img, Vector2i(6, 4), Vector2i(7, 2), bone)
		Px.line(img, Vector2i(7, 2), Vector2i(11, 2), bone)
		Px.line(img, Vector2i(11, 2), Vector2i(13, 4), bone)
		Px.line(img, Vector2i(13, 4), Vector2i(13, 8), bone_d)
		Px.line(img, Vector2i(8, 3), Vector2i(11, 3), edge)
		Px.line(img, Vector2i(11, 3), Vector2i(12, 5), edge)
		Px.px(img, 12, 7, edge)
		for p: Vector2i in [Vector2i(8, 1), Vector2i(10, 1), Vector2i(12, 2), Vector2i(14, 5)]:
			Px.px(img, p.x, p.y, bone_d)
		return Px.outline(img)
	if kind == &"hammer":
		Px.line(img, Vector2i(3, 13), Vector2i(9, 7), Color.html(WOOD_DARK))
		Px.line(img, Vector2i(4, 13), Vector2i(10, 7), Color.html(WOOD))
		var cols := CropArt.ramp(Color.html(STONE))
		Px.rect(img, 7, 2, 7, 6, cols[1])
		Px.rect(img, 7, 2, 7, 1, cols[0])
		Px.rect(img, 7, 7, 7, 1, cols[2])
		Px.rect(img, 13, 3, 1, 5, cols[2])
		return Px.outline(img)
	if kind == &"dagger":
		Px.line(img, Vector2i(3, 13), Vector2i(5, 11), Color.html(WOOD_DARK))
		Px.line(img, Vector2i(3, 9), Vector2i(7, 13), Color.html("b8964a"))
		Px.line(img, Vector2i(6, 10), Vector2i(13, 3), steel)
		Px.line(img, Vector2i(7, 10), Vector2i(13, 4), steel_d)
		Px.line(img, Vector2i(6, 9), Vector2i(12, 3), steel)
		return Px.outline(img)
	# 镰刀：短木柄，顶上一弯月牙
	Px.line(img, Vector2i(4, 14), Vector2i(8, 7), Color.html(WOOD_DARK))
	Px.line(img, Vector2i(5, 14), Vector2i(9, 7), Color.html(WOOD))
	Px.line(img, Vector2i(8, 6), Vector2i(6, 4), steel)
	Px.line(img, Vector2i(6, 4), Vector2i(7, 2), steel)
	Px.line(img, Vector2i(7, 2), Vector2i(11, 2), steel)
	Px.line(img, Vector2i(11, 2), Vector2i(13, 4), steel)
	Px.line(img, Vector2i(13, 4), Vector2i(13, 7), steel)
	Px.line(img, Vector2i(8, 3), Vector2i(11, 3), steel_d)
	Px.line(img, Vector2i(11, 3), Vector2i(12, 5), steel_d)
	return Px.outline(img)


## 挥出去的那道白光：一段弧，朝右（+x），圆心在图的正中。reach 是半径，arc 是左右各多少度。
static func slash(reach: float, arc: float) -> Image:
	var r := ceili(reach)
	var size := r * 2 + 2
	var img := Px.new_img(size, size)
	var c := Vector2(size / 2.0, size / 2.0)
	for y in size:
		for x in size:
			var v := Vector2(x + 0.5, y + 0.5) - c
			var d := v.length()
			var ang := absf(rad_to_deg(v.angle()))
			if ang > arc or d > reach:
				continue
			# 中间厚、两头尖
			var thick := 5.0 * (1.0 - 0.75 * ang / maxf(1.0, arc)) if arc < 179.0 else 3.0
			if d < reach - thick:
				continue
			var a := 0.55 + 0.4 * (d - (reach - thick)) / maxf(1.0, thick)
			img.set_pixel(x, y, Color(1.0, 1.0, 0.94, a))
	return img


## 突进留下的一道白线，朝右，length 像素长。
static func streak(length: int) -> Image:
	var img := Px.new_img(maxi(4, length), 5)
	for x in img.get_width():
		var a := 0.25 + 0.7 * float(x) / float(img.get_width())
		img.set_pixel(x, 2, Color(1.0, 1.0, 0.94, a))
		if x > img.get_width() / 3:
			img.set_pixel(x, 1, Color(1.0, 1.0, 0.94, a * 0.5))
			img.set_pixel(x, 3, Color(1.0, 1.0, 0.94, a * 0.5))
	return img
