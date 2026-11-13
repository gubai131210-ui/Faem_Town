class_name MineDeepArt
extends RefCounted
## 水渍层、遗落层和两个首领用代码画的东西：六种忘形、废矿车、井底老鲶，被忘掉的摆设，飞着的纸钱和水弹，铁轨。
## 姿势的名字和 MineArt.MONSTER_POSES 一样；都朝右画，朝左由画它的节点翻过来。

const IDS: Array[StringName] = [&"moss_frog", &"leech_swarm", &"leaky_umbrella", &"empty_shoes",
	&"walking_clock", &"faceless_paper", &"mine_cart", &"well_catfish"]
const EYE := "241c1a"
const EYE_ANGRY := "f0503a"
const EYE_GLOW := "ffe07a"


static func has(id: StringName) -> bool:
	return IDS.has(id)


static func monster(id: StringName, pose: StringName) -> Image:
	match id:
		&"moss_frog":
			return _frog(pose)
		&"leech_swarm":
			return _leeches(pose)
		&"leaky_umbrella":
			return _umbrella(pose)
		&"empty_shoes":
			return _shoes(pose)
		&"walking_clock":
			return _clock(pose)
		&"faceless_paper":
			return _paper(pose)
		&"mine_cart":
			return _cart(pose)
	return _catfish(pose)


static func _angry(pose: StringName) -> bool:
	return pose == &"windup" or pose == &"strike"


## 苔蛙：一只长满青苔的蛙。出招前压扁，跳起来时拉长、腿拖在后面。
static func _frog(pose: StringName) -> Image:
	var img := Px.new_img(16, 16)
	var g := CropArt.ramp(Color.html("6a9a4a"))
	var cy := 11.0
	var rx := 5.5
	var ry := 3.8
	if pose == &"idle_b":
		ry = 3.4
		cy = 11.4
	elif pose == &"windup" or pose == &"stun":
		rx = 6.5
		ry = 2.8
		cy = 12.2
	elif pose == &"strike":
		rx = 4.8
		ry = 4.4
		cy = 8.5
	# 腿
	if pose == &"strike":
		Px.rect(img, 3, 12, 2, 3, g[2])
		Px.rect(img, 11, 12, 2, 3, g[2])
	else:
		Px.rect(img, 1, 13, 3, 1, g[2])
		Px.rect(img, 12, 13, 3, 1, g[2])
	CropArt.ball(img, 8.0, cy, rx, ry, g)
	Px.rect(img, 6, int(cy) + 1, 5, 1, Color.html("c8d8a0"))
	# 背上的苔
	for p: Vector2i in [Vector2i(6, 0), Vector2i(9, -1), Vector2i(11, 0)]:
		Px.px(img, p.x, int(cy) + p.y - 1, Color.html("3f6a34"))
	# 两只鼓出来的眼睛
	var ey := int(cy - ry)
	Px.rect(img, 4, ey - 1, 3, 3, g[1])
	Px.rect(img, 9, ey - 1, 3, 3, g[1])
	Px.px(img, 4, ey - 1, g[0])
	Px.px(img, 9, ey - 1, g[0])
	var eye := Color.html(EYE_ANGRY) if _angry(pose) else Color.html(EYE)
	if pose == &"stun":
		Px.rect(img, 4, ey, 3, 1, eye)
		Px.rect(img, 9, ey, 3, 1, eye)
	else:
		Px.px(img, 5, ey, eye)
		Px.px(img, 10, ey, eye)
	return Px.outline(img)


## 水蛭群：一小堆扭来扭去的黑红色虫子。出招前缩成一团，扑出去时都拉长。
static func _leeches(pose: StringName) -> Image:
	var img := Px.new_img(16, 16)
	var body := Color.html("6a2834")
	var head := Color.html("a84c58")
	var spots: Array[Vector2i] = [Vector2i(2, 10), Vector2i(6, 8), Vector2i(10, 11), Vector2i(4, 13), Vector2i(10, 7), Vector2i(7, 12)]
	var wig := 1 if pose == &"idle_b" else 0
	for i in spots.size():
		var p := spots[i]
		if pose == &"windup":
			p = Vector2i((p.x + 7) / 2, (p.y + 11) / 2)
		elif pose == &"stun":
			p.y = 13 - i % 2
		var up := (i + wig) % 2
		var length := 5 if pose == &"strike" else 3
		Px.rect(img, p.x, p.y + up, length, 1, body)
		Px.px(img, p.x + length, p.y + 1 - up, body)
		Px.px(img, p.x + length + 1, p.y + 1 - up, Color.html(EYE_ANGRY) if _angry(pose) else head)
	return Px.outline(img)


## 漏雨伞：撑开的时候是一把破了洞的油纸伞，伞底下露着两只眼；出招和歇着的时候收起来，像一根矛。
static func _umbrella(pose: StringName) -> Image:
	var img := Px.new_img(16, 16)
	var paper := CropArt.ramp(Color.html("c8643a"))
	var rib := Color.html("8a3c24")
	var wood := Color.html("7a5234")
	if pose == &"strike":
		# 收起来，尖朝前
		Px.rect(img, 1, 8, 3, 1, wood)
		Px.px(img, 1, 9, wood)
		Px.rect(img, 4, 7, 9, 3, paper[1])
		Px.rect(img, 4, 7, 9, 1, paper[0])
		Px.rect(img, 4, 9, 9, 1, paper[2])
		Px.rect(img, 13, 8, 2, 1, rib)
		Px.px(img, 7, 8, Color.html(EYE_ANGRY))
		Px.px(img, 10, 8, Color.html(EYE_ANGRY))
		return Px.outline(img)
	if pose == &"stun":
		# 收起来，垂着
		Px.rect(img, 7, 2, 1, 2, rib)
		Px.rect(img, 6, 4, 3, 8, paper[1])
		Px.rect(img, 6, 4, 1, 8, paper[0])
		Px.rect(img, 8, 4, 1, 8, paper[2])
		Px.rect(img, 7, 12, 1, 2, wood)
		Px.px(img, 8, 14, wood)
		Px.px(img, 7, 7, Color.html(EYE))
		Px.px(img, 7, 9, Color.html(EYE))
		return Px.outline(img)
	var lift := 1 if pose == &"idle_b" else 0
	# 伞面：半个椭圆
	for x in range(1, 15):
		var k := (x - 7.5) / 7.0
		var top := 7 - int(round(5.0 * sqrt(maxf(0.0, 1.0 - k * k))))
		for y in range(top, 8):
			var c: Color = paper[0] if y == top else paper[1]
			if x >= 11:
				c = paper[2]
			Px.px(img, x, y - lift, c)
	for x: int in [4, 8, 11]:
		Px.rect(img, x, 3 - lift, 1, 5, rib)
	# 两个破洞
	Px.px(img, 5, 5 - lift, Color(0, 0, 0, 0))
	Px.px(img, 6, 5 - lift, Color(0, 0, 0, 0))
	Px.px(img, 10, 6 - lift, Color(0, 0, 0, 0))
	# 伞柄
	Px.rect(img, 7, 8 - lift, 1, 6, wood)
	Px.px(img, 8, 13 - lift, wood)
	var eye := Color.html(EYE_ANGRY) if _angry(pose) else Color.html(EYE_GLOW)
	Px.px(img, 5, 9 - lift, eye)
	Px.px(img, 10, 9 - lift, eye)
	return Px.outline(img)


static func _shoe(img: Image, x: int, y: int, upside_down: bool = false) -> void:
	var cloth := Color.html("2e2e3c")
	var sole := Color.html("e8e2d0")
	if upside_down:
		Px.rect(img, x, y, 6, 1, sole)
		Px.rect(img, x, y + 1, 5, 2, cloth)
		return
	Px.rect(img, x, y, 5, 2, cloth)
	Px.px(img, x + 5, y + 1, cloth)
	Px.px(img, x + 1, y, Color.html("5a5a6c"))
	Px.rect(img, x, y + 2, 6, 1, sole)


## 空鞋：一双没人穿的布鞋，一前一后地跑。
static func _shoes(pose: StringName) -> Image:
	var img := Px.new_img(16, 16)
	match pose:
		&"idle_b":
			_shoe(img, 2, 9)
			_shoe(img, 9, 11)
		&"windup":
			_shoe(img, 3, 11)
			_shoe(img, 8, 11)
			Px.px(img, 6, 9, Color.html(EYE_ANGRY))
			Px.px(img, 11, 9, Color.html(EYE_ANGRY))
		&"strike":
			_shoe(img, 3, 7)
			_shoe(img, 9, 9)
		&"stun":
			_shoe(img, 2, 11, true)
			_shoe(img, 9, 11)
		_:
			_shoe(img, 2, 11)
			_shoe(img, 9, 9)
	return Px.outline(img)


## 走时钟：一只长了脚的座钟。钟面平时是白的，出招前变红。
static func _clock(pose: StringName) -> Image:
	var img := Px.new_img(16, 16)
	var wood := CropArt.ramp(Color.html("7a5234"))
	var lean := 1 if pose == &"strike" else 0
	# 脚：两帧一高一低
	var left_up := 1 if pose == &"idle_b" else 0
	var right_up := 1 if pose == &"idle_a" else 0
	if pose == &"stun":
		left_up = 0
		right_up = 0
	Px.rect(img, 5, 13 - left_up, 2, 2, wood[2])
	Px.rect(img, 10, 13 - right_up, 2, 2, wood[2])
	Px.rect(img, 4 + lean, 3, 9, 10, wood[1])
	Px.rect(img, 4 + lean, 3, 1, 10, wood[0])
	Px.rect(img, 12 + lean, 3, 1, 10, wood[2])
	Px.rect(img, 5 + lean, 2, 7, 1, wood[0])
	Px.rect(img, 7 + lean, 1, 3, 1, wood[1])
	var face := Color.html("f08a78") if _angry(pose) else Color.html("f0ead8")
	Px.rect(img, 6 + lean, 5, 5, 5, face)
	Px.px(img, 6 + lean, 5, wood[1])
	Px.px(img, 10 + lean, 5, wood[1])
	Px.px(img, 6 + lean, 9, wood[1])
	Px.px(img, 10 + lean, 9, wood[1])
	var ink := Color.html(EYE)
	if pose == &"stun":
		Px.px(img, 7, 6, ink)
		Px.px(img, 9, 8, ink)
		Px.px(img, 9, 6, ink)
		Px.px(img, 7, 8, ink)
		Px.px(img, 8, 7, ink)
	else:
		# 指针：三点一刻
		Px.px(img, 8 + lean, 7, ink)
		Px.px(img, 9 + lean, 7, ink)
		Px.px(img, 8 + lean, 6 if pose != &"idle_b" else 8, ink)
	# 钟摆
	Px.px(img, 8 + lean + (1 if pose == &"idle_b" else -1 if pose == &"idle_a" else 0), 11, Color.html("c09a3e"))
	return Px.outline(img)


## 无面纸人：白纸扎的小人，脸上什么都没有。出招前举起一枚纸钱，出招时甩出去。
static func _paper(pose: StringName) -> Image:
	var img := Px.new_img(16, 16)
	var paper := CropArt.ramp(Color.html("efe9d8"))
	var drop := 1 if pose == &"stun" else 0
	CropArt.ball(img, 7.5, 4.5 + drop, 2.6, 2.6, paper)
	for y in range(7, 15):
		var k := (y - 6) / 2
		Px.rect(img, 7 - k, y + drop, k * 2 + 2, 1, paper[1] if y < 13 else paper[2])
	Px.rect(img, 6, 9 + drop, 4, 1, Color.html("b04040"))
	var arm: Color = paper[0]
	var up := 1 if pose == &"idle_b" else 0
	Px.line(img, Vector2i(5, 8 + drop), Vector2i(2, 10 + drop - up), arm)
	if pose == &"windup":
		Px.line(img, Vector2i(10, 8), Vector2i(13, 5), arm)
		Px.rect(img, 13, 3, 2, 2, Color.html("e8c860"))
	elif pose == &"strike":
		Px.line(img, Vector2i(10, 8), Vector2i(15, 8), arm)
	else:
		Px.line(img, Vector2i(10, 8 + drop), Vector2i(13, 10 + drop - up), arm)
	return Px.outline(img)


## 废矿车：一辆锈了的矿车，车斗的石头堆里亮着两只眼。32×32。
static func _cart(pose: StringName) -> Image:
	var img := Px.new_img(32, 32)
	var rust := CropArt.ramp(Color.html("8a5236"))
	var iron := CropArt.ramp(Color.html("6a6e78"))
	var sink := 1 if pose == &"stun" else 0
	var bob := 1 if pose == &"idle_b" else 0
	# 车斗里的石头和煤
	CropArt.ball(img, 11.0, 10.0 - bob + sink, 5.0, 4.0, CropArt.ramp(Color.html("8d8a86")))
	CropArt.ball(img, 20.0, 9.0 - bob + sink, 6.5, 5.0, CropArt.ramp(Color.html("3a3a44")))
	var eye := Color.html(EYE_ANGRY) if _angry(pose) else Color.html(EYE_GLOW)
	if pose == &"stun":
		eye = Color.html("8a8a90")
		Px.rect(img, 17, 9 + sink, 3, 1, eye)
		Px.rect(img, 22, 9 + sink, 3, 1, eye)
		for p: Vector2i in [Vector2i(9, 2), Vector2i(16, 0), Vector2i(23, 2)]:
			Px.px(img, p.x, p.y, Color.html("ffe07a"))
			Px.px(img, p.x + 1, p.y + 1, Color.html("ffe07a"))
	else:
		Px.rect(img, 17, 8 - bob, 2, 2, eye)
		Px.rect(img, 22, 8 - bob, 2, 2, eye)
	# 车斗：上宽下窄
	for y in range(13, 25):
		var inset := (y - 13) / 4
		var c: Color = rust[1] if y < 21 else rust[2]
		Px.rect(img, 4 + inset, y + sink, 24 - inset * 2, 1, c)
	Px.rect(img, 3, 11 + sink, 26, 2, iron[0])
	Px.rect(img, 3, 12 + sink, 26, 1, iron[1])
	for x in range(6, 27, 5):
		Px.px(img, x, 15 + sink, iron[0])
		Px.px(img, x, 20 + sink, rust[2])
	Px.rect(img, 9, 16 + sink, 4, 3, rust[2])
	Px.rect(img, 19, 17 + sink, 3, 2, rust[0])
	# 轮子
	CropArt.ball(img, 10.0, 27.0, 3.6, 3.6, CropArt.ramp(Color.html("4a4a54")))
	CropArt.ball(img, 22.0, 27.0, 3.6, 3.6, CropArt.ramp(Color.html("4a4a54")))
	Px.px(img, 10, 27, iron[0])
	Px.px(img, 22, 27, iron[0])
	if pose == &"strike":
		for y: int in [14, 19, 24]:
			Px.rect(img, 0, y, 3, 1, Color(1.0, 1.0, 0.94, 0.7))
	return Px.outline(img)


## 井底老鲶，32×32。平时（idle）只露着背，在水里是一道黑影；windup、strike 抬起头张着嘴；stun 是被拉上岸躺着。
static func _catfish(pose: StringName) -> Image:
	var img := Px.new_img(32, 32)
	var skin := CropArt.ramp(Color.html("34343c"))
	var belly := Color.html("8a8a80")
	var ripple := Color(0.62, 0.82, 0.86, 0.8)
	if pose == &"stun":
		# 躺在岸上：尾巴在左，头在右
		for i in 5:
			Px.rect(img, 1 + i, 20 - (4 - i), 1, (4 - i) * 2 + 3, skin[2])
		CropArt.ball(img, 17.0, 22.0, 12.0, 5.5, skin)
		Px.rect(img, 9, 25, 16, 2, belly)
		Px.rect(img, 12, 27, 10, 1, belly)
		Px.rect(img, 14, 15, 6, 2, skin[2])
		Px.line(img, Vector2i(27, 23), Vector2i(31, 27), skin[1])
		Px.line(img, Vector2i(27, 24), Vector2i(29, 29), skin[1])
		Px.rect(img, 25, 24, 3, 1, Color.html("7a3a40"))
		Px.px(img, 23, 20, Color.html("d8d8d0"))
		Px.px(img, 24, 21, Color.html("d8d8d0"))
		Px.px(img, 24, 20, Color.html(EYE))
		Px.px(img, 23, 21, Color.html(EYE))
		return Px.outline(img)
	if _angry(pose):
		# 头探出水面，张着嘴
		CropArt.ball(img, 16.0, 17.0, 9.0, 7.5, skin)
		var open := 5 if pose == &"strike" else 3
		Px.rect(img, 10, 19, 12, open, Color.html("7a3a40"))
		Px.rect(img, 11, 19, 10, 1, Color.html("3a1c20"))
		Px.rect(img, 9, 12, 3, 3, Color.html(EYE_ANGRY))
		Px.rect(img, 20, 12, 3, 3, Color.html(EYE_ANGRY))
		Px.px(img, 10, 13, Color.html(EYE))
		Px.px(img, 21, 13, Color.html(EYE))
		Px.line(img, Vector2i(8, 19), Vector2i(2, 23), skin[1])
		Px.line(img, Vector2i(23, 19), Vector2i(29, 23), skin[1])
		Px.line(img, Vector2i(9, 21), Vector2i(5, 27), skin[1])
		Px.line(img, Vector2i(22, 21), Vector2i(26, 27), skin[1])
		var out := Px.outline(img)
		Px.rect(out, 4, 25, 8, 1, ripple)
		Px.rect(out, 19, 26, 9, 1, ripple)
		return out
	# 水里的一道黑影：背露出一点，两根须
	var shift := 1 if pose == &"idle_b" else 0
	for y in range(17, 28):
		for x in range(3, 29):
			var kx := (x - 16.0) / 12.5
			var ky := (y - 22.0) / 5.0
			if kx * kx + ky * ky <= 1.0:
				img.set_pixel(x, y, Color(0.08, 0.09, 0.12, 0.6))
	Px.rect(img, 11, 20, 12, 2, skin[1])
	Px.rect(img, 13, 19, 8, 1, skin[0])
	Px.line(img, Vector2i(27, 21), Vector2i(31, 18 + shift), Color(0.08, 0.09, 0.12, 0.8))
	Px.line(img, Vector2i(27, 23), Vector2i(31, 26 - shift), Color(0.08, 0.09, 0.12, 0.8))
	Px.rect(img, 6 + shift * 2, 16, 6, 1, ripple)
	Px.rect(img, 20 - shift * 2, 28, 7, 1, ripple)
	return img


# ---------------------------------------------------------------- 摆设、投射物、铁轨

## 遗落层里被忘掉的东西。宽 16，高各不相同，底边对着格子底边。
static func prop(kind: StringName) -> Image:
	var wood := CropArt.ramp(Color.html("7a5a44"))
	match kind:
		&"street_lamp":
			var img := Px.new_img(16, 30)
			var iron := CropArt.ramp(Color.html("42444e"))
			Px.rect(img, 7, 9, 2, 19, iron[1])
			Px.rect(img, 8, 9, 1, 19, iron[2])
			Px.rect(img, 5, 27, 6, 2, iron[1])
			Px.rect(img, 5, 28, 6, 1, iron[2])
			Px.rect(img, 4, 1, 8, 1, iron[0])
			Px.rect(img, 6, 0, 4, 1, iron[1])
			Px.rect(img, 5, 2, 6, 7, iron[2])
			Px.rect(img, 6, 3, 4, 5, Color.html("d8b860"))
			Px.rect(img, 7, 4, 2, 3, Color.html("f0e0a0"))
			return Px.outline(img)
		&"cabinet":
			var img := Px.new_img(16, 22)
			Px.rect(img, 2, 2, 12, 19, wood[1])
			Px.rect(img, 2, 2, 12, 1, wood[0])
			Px.rect(img, 2, 2, 1, 19, wood[0])
			Px.rect(img, 13, 2, 1, 19, wood[2])
			Px.rect(img, 2, 20, 12, 1, wood[2])
			Px.rect(img, 7, 4, 1, 15, wood[2])
			# 一扇门开着，里面是空的
			Px.rect(img, 9, 4, 4, 15, Color.html("2a1c14"))
			Px.rect(img, 9, 10, 4, 1, wood[2])
			Px.px(img, 5, 11, Color.html("c09a3e"))
			return Px.outline(img)
		&"chair":
			var img := Px.new_img(16, 16)
			Px.rect(img, 4, 3, 8, 2, wood[0])
			Px.rect(img, 4, 3, 2, 12, wood[1])
			Px.rect(img, 10, 3, 2, 7, wood[1])
			Px.rect(img, 4, 9, 9, 2, wood[0])
			Px.rect(img, 11, 11, 2, 4, wood[2])
			Px.rect(img, 7, 5, 2, 4, wood[2])
			return Px.outline(img)
	var img := Px.new_img(16, 16)
	Px.rect(img, 1, 7, 14, 2, wood[0])
	Px.rect(img, 1, 9, 14, 1, wood[2])
	Px.rect(img, 2, 10, 2, 5, wood[1])
	Px.rect(img, 12, 10, 2, 5, wood[1])
	# 桌上一只没收走的碗
	Px.rect(img, 6, 5, 4, 2, Color.html("e8e2d0"))
	Px.rect(img, 7, 6, 2, 1, Color.html("b8b2a0"))
	return Px.outline(img)


## 插在岸边的一根旧鱼竿，16×24，底边对着格子底边。
static func spare_rod() -> Image:
	var img := Px.new_img(16, 24)
	var cane := Color.html("b89a62")
	var cane_d := Color.html("8a6e40")
	Px.line(img, Vector2i(5, 23), Vector2i(11, 2), cane)
	Px.line(img, Vector2i(6, 23), Vector2i(12, 2), cane_d)
	for y: int in [8, 14, 19]:
		Px.px(img, 9 - (y - 8) / 4, y, cane_d)
	# 垂下来的线和一只浮漂
	Px.line(img, Vector2i(12, 2), Vector2i(13, 11), Color(0.9, 0.9, 0.86, 0.9))
	var out := Px.outline(img)
	Px.rect(out, 12, 12, 2, 2, Color.html("d8504a"))
	Px.px(out, 13, 14, Color.html("f0ead8"))
	return out


## 飞着的东西，8×8：paper 纸钱（圆的，中间一个方孔）、water 水弹。
static func shot(kind: StringName) -> Image:
	var img := Px.new_img(8, 8)
	if kind == &"water":
		CropArt.ball(img, 4.0, 4.0, 2.8, 2.8, [Color.html("c8ecf8"), Color.html("6ab8d8"), Color.html("3a7a9a")])
		return Px.outline(img)
	CropArt.ball(img, 4.0, 4.0, 3.0, 3.0, CropArt.ramp(Color.html("e8d890")))
	Px.rect(img, 3, 3, 2, 2, Color.html("5a4a2a"))
	return Px.outline(img)


## 一格铁轨，16×16，透明底：两根铁条压着枕木。horizontal 为真是横着的。
static func rail(horizontal: bool) -> Image:
	var img := Px.new_img(16, 16)
	var tie := Color.html("3a2c22")
	var steel := Color.html("7a7e88")
	var steel_d := Color.html("4a4e58")
	if horizontal:
		for x: int in [1, 6, 11]:
			Px.rect(img, x, 3, 2, 10, tie)
		Px.rect(img, 0, 5, 16, 1, steel)
		Px.rect(img, 0, 6, 16, 1, steel_d)
		Px.rect(img, 0, 10, 16, 1, steel)
		Px.rect(img, 0, 11, 16, 1, steel_d)
	else:
		for y: int in [1, 6, 11]:
			Px.rect(img, 3, y, 10, 2, tie)
		Px.rect(img, 5, 0, 1, 16, steel)
		Px.rect(img, 6, 0, 1, 16, steel_d)
		Px.rect(img, 10, 0, 1, 16, steel)
		Px.rect(img, 11, 0, 1, 16, steel_d)
	return img
