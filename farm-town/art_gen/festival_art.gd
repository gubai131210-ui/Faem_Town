class_name FestivalArt
extends RefCounted
## 节日上摆的东西：种子摊、长桌、灯笼杆、河灯、萤火虫。都是代码画的，锚点在底边正中。

const WOOD := "a37648"
const WOOD_DARK := "6a4a2c"
const WOOD_LIGHT := "c49a62"
const RED := "c8483c"
const RED_DARK := "96322c"
const CLOTH := "ece6d6"
const CLOTH_DARK := "cfc8b4"


## 播种节的种子摊，36×36，占两格宽：红白条的布棚，台面上摆着种子袋和一筐草莓。
static func stall() -> Image:
	var img := Px.new_img(36, 36)
	var wood := Color.html(WOOD)
	var wood_d := Color.html(WOOD_DARK)
	# 两根撑杆
	Px.rect(img, 3, 9, 2, 26, wood_d)
	Px.rect(img, 31, 9, 2, 26, wood_d)
	# 布棚：一条红一条白，下沿是波浪边
	for x in range(1, 35):
		var stripe := ((x - 1) / 4) % 2 == 0
		var c := Color.html(RED) if stripe else Color.html(CLOTH)
		var c_d := Color.html(RED_DARK) if stripe else Color.html(CLOTH_DARK)
		Px.rect(img, x, 2, 1, 7, c)
		Px.px(img, x, 2, c.lightened(0.15))
		Px.px(img, x, 8, c_d)
		if (x - 1) % 4 == 1 or (x - 1) % 4 == 2:
			Px.px(img, x, 9, c_d)
	# 台面和围布
	Px.rect(img, 2, 20, 32, 3, Color.html(WOOD_LIGHT))
	Px.rect(img, 2, 22, 32, 1, wood)
	Px.rect(img, 3, 23, 30, 11, Color.html("5f8a52"))
	Px.rect(img, 3, 23, 30, 1, Color.html("46703e"))
	Px.rect(img, 3, 33, 30, 1, Color.html("46703e"))
	for x in range(7, 32, 6):
		Px.rect(img, x, 24, 1, 9, Color.html("547c48"))
	# 围布上贴的“种”字牌：一块黄纸
	Px.rect(img, 15, 25, 6, 6, Color.html("e8c860"))
	Px.rect(img, 17, 26, 2, 4, Color.html("7a5a2a"))
	Px.rect(img, 16, 28, 4, 1, Color.html("7a5a2a"))
	# 台面上的种子袋：三只，袋口扎着
	var bags: Array[String] = ["d8c8a0", "c8b488", "d8c8a0"]
	for i in 3:
		var bx := 5 + i * 6
		Px.rect(img, bx, 15, 5, 5, Color.html(bags[i]))
		Px.rect(img, bx + 1, 14, 3, 1, Color.html("a89468"))
		Px.px(img, bx + 2, 17, Color.html(["6aa84a", "e0a030", "8a6ac0"][i]))
	# 一筐草莓
	Px.rect(img, 24, 16, 8, 4, Color.html("b88a4a"))
	Px.rect(img, 24, 19, 8, 1, Color.html("8a6230"))
	for i in 4:
		Px.px(img, 25 + i * 2, 15, Color.html("e04848"))
		Px.px(img, 25 + i * 2, 14, Color.html("5aa040") if i % 2 == 0 else Color.html("e86060"))
	return Px.outline(img)


## 长桌，52×24，占三格宽。kind 是 "harvest"（评比台：南瓜、鱼、一篮蛋、三条绶带）或 "dumpling"（宴席：蒸笼和几盘饺子）。
static func table(kind: String) -> Image:
	var img := Px.new_img(52, 24)
	var feast := kind == "dumpling"
	var cloth := Color.html("c8483c") if feast else Color.html(CLOTH)
	var cloth_d := Color.html("96322c") if feast else Color.html(CLOTH_DARK)
	# 桌腿、桌面、垂下来的桌布
	for x: int in [4, 46]:
		Px.rect(img, x, 14, 2, 9, Color.html(WOOD_DARK))
	Px.rect(img, 2, 9, 48, 3, Color.html(WOOD_LIGHT))
	Px.rect(img, 2, 12, 48, 6, cloth)
	Px.rect(img, 2, 17, 48, 1, cloth_d)
	for x in range(6, 50, 8):
		Px.rect(img, x, 13, 1, 4, cloth_d)
	if feast:
		# 两屉蒸笼冒着白气，中间几盘饺子
		for sx: int in [5, 39]:
			Px.rect(img, sx, 4, 9, 5, Color.html("d8b878"))
			Px.rect(img, sx, 6, 9, 1, Color.html("a8844a"))
			Px.rect(img, sx, 8, 9, 1, Color.html("a8844a"))
			Px.rect(img, sx + 1, 3, 7, 1, Color.html("e8cc90"))
			Px.px(img, sx + 3, 1, Color.html("f4f4f4"))
			Px.px(img, sx + 5, 2, Color.html("f4f4f4"))
		for i in 3:
			var px0 := 17 + i * 7
			Px.rect(img, px0, 7, 6, 2, Color.html("e8e4dc"))
			Px.rect(img, px0 + 1, 6, 4, 1, Color.html("f8f0d8"))
			Px.px(img, px0 + 1, 5, Color.html("f8f0d8"))
			Px.px(img, px0 + 3, 5, Color.html("f8f0d8"))
			Px.px(img, px0 + 2, 6, Color.html("d8c8a0"))
	else:
		# 南瓜
		Px.rect(img, 5, 4, 8, 5, Color.html("e08a30"))
		Px.rect(img, 6, 3, 6, 1, Color.html("e08a30"))
		Px.rect(img, 8, 4, 1, 5, Color.html("b86a20"))
		Px.rect(img, 11, 4, 1, 5, Color.html("b86a20"))
		Px.px(img, 9, 2, Color.html("5a8a3a"))
		# 一条鱼搁在盘子里
		Px.rect(img, 18, 7, 12, 2, Color.html("e8e4dc"))
		Px.rect(img, 20, 5, 7, 2, Color.html("8aa4b8"))
		Px.rect(img, 21, 4, 5, 1, Color.html("6a8498"))
		Px.px(img, 27, 5, Color.html("6a8498"))
		Px.px(img, 28, 4, Color.html("6a8498"))
		Px.px(img, 28, 6, Color.html("6a8498"))
		Px.px(img, 21, 5, Color.html("2a2a30"))
		# 一篮蛋
		Px.rect(img, 36, 6, 9, 3, Color.html("b88a4a"))
		Px.rect(img, 36, 8, 9, 1, Color.html("8a6230"))
		for i in 3:
			Px.rect(img, 37 + i * 3, 4, 2, 2, Color.html("f4ead0"))
		# 桌布上别着三条绶带：金、银、铜
		var ribbons: Array[String] = ["e8c040", "c8ccd4", "c88a5a"]
		for i in 3:
			Px.rect(img, 12 + i * 12, 13, 3, 3, Color.html(ribbons[i]))
			Px.px(img, 12 + i * 12, 16, Color.html(ribbons[i]))
			Px.px(img, 14 + i * 12, 16, Color.html(ribbons[i]))
	return Px.outline(img)


## 灯笼杆，14×34：一根木杆挑着一只红灯笼。lit 为真时灯笼里亮着。
static func lantern_pole(lit: bool) -> Image:
	var img := Px.new_img(14, 34)
	var wood_d := Color.html(WOOD_DARK)
	Px.rect(img, 3, 3, 2, 30, Color.html(WOOD))
	Px.rect(img, 4, 3, 1, 30, wood_d)
	Px.rect(img, 2, 32, 4, 1, wood_d)
	# 横出去的挑杆和吊绳
	Px.rect(img, 3, 3, 8, 1, wood_d)
	Px.px(img, 9, 4, Color.html("3a3430"))
	# 灯笼：上下两个金口，中间鼓出来
	var body := Color.html("e85a40") if lit else Color.html(RED)
	var body_d := Color.html(RED_DARK)
	Px.rect(img, 8, 5, 3, 1, Color.html("e0b040"))
	Px.rect(img, 7, 6, 5, 6, body)
	Px.rect(img, 6, 7, 7, 4, body)
	Px.rect(img, 11, 7, 2, 4, body_d)
	Px.rect(img, 8, 12, 3, 1, Color.html("e0b040"))
	Px.px(img, 9, 13, Color.html("e0b040"))
	Px.px(img, 9, 14, Color.html("e0b040"))
	if lit:
		Px.rect(img, 8, 7, 2, 4, Color.html("ffd76a"))
		Px.px(img, 8, 8, Color.html("fff6c8"))
	else:
		Px.px(img, 7, 7, Color.html("e0685a"))
	return Px.outline(img)


## 河灯，12×10：纸折的莲花托着一点火。frame 0、1 是火苗晃的两帧。
static func river_lantern(frame: int) -> Image:
	var img := Px.new_img(12, 10)
	var petal := Color.html("f0b8c0")
	var petal_d := Color.html("d88a9a")
	Px.rect(img, 2, 6, 8, 2, petal)
	Px.rect(img, 3, 8, 6, 1, petal_d)
	Px.px(img, 1, 5, petal)
	Px.px(img, 10, 5, petal)
	Px.px(img, 3, 5, petal_d)
	Px.px(img, 8, 5, petal_d)
	Px.rect(img, 4, 5, 4, 1, Color.html("f8dcc0"))
	# 火苗
	Px.rect(img, 5, 3, 2, 2, Color.html("ffd76a"))
	Px.px(img, 5 + (frame % 2), 2, Color.html("ffb040"))
	Px.px(img, 5 + (frame % 2), 1, Color.html("fff6c8") if frame % 2 == 0 else Color.html("ffd76a"))
	return Px.outline(img)


## 萤火虫，5×5：一个黄绿色的光点，frame 1 暗一些。不描边。
static func firefly(frame: int) -> Image:
	var img := Px.new_img(5, 5)
	var core := Color.html("f4ffa0") if frame % 2 == 0 else Color.html("c8e070")
	var glow := Color(0.8, 1.0, 0.4, 0.55 if frame % 2 == 0 else 0.25)
	Px.px(img, 2, 2, core)
	for d: Vector2i in [Vector2i(1, 2), Vector2i(3, 2), Vector2i(2, 1), Vector2i(2, 3)]:
		Px.px(img, d.x, d.y, glow)
	return img
