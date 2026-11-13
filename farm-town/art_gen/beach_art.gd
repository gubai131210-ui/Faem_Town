class_name BeachArt
extends RefCounted
## 东滩上的东西：灯塔、白鹭的画室、画架。都是代码画的，锚点在底边正中。

const WOOD := "a37648"
const WOOD_DARK := "6a4a2c"


## 灯塔，40×100。塔身上细下粗，刷白，两道红箍；顶上的灯室是黑的（lit 为真时亮着）。
static func lighthouse(lit: bool = false) -> Image:
	var img := Px.new_img(40, 100)
	var white := Color.html("ece8dc")
	var white_d := Color.html("cfc9b8")
	var white_l := Color.html("faf7ee")
	var red := Color.html("b8483c")
	var red_d := Color.html("8e342c")
	var stone := Color.html("8a8478")
	var stone_d := Color.html("6a655c")
	var iron := Color.html("3a3a42")
	# 石头底座
	Px.rect(img, 4, 88, 32, 11, stone)
	Px.rect(img, 4, 88, 32, 1, Color.html("a8a294"))
	Px.rect(img, 4, 96, 32, 3, stone_d)
	for x in range(8, 36, 7):
		Px.rect(img, x, 89, 1, 7, stone_d)
	# 塔身：从 y=28 到 88，半宽从 7 到 12
	for y in range(28, 88):
		var hw := 7 + int((y - 28) * 5.0 / 60.0 + 0.5)
		var band := (y >= 40 and y < 48) or (y >= 66 and y < 74)
		Px.rect(img, 20 - hw, y, hw * 2, 1, red if band else white)
		Px.rect(img, 20 - hw, y, 2, 1, (red if band else white_l))
		Px.rect(img, 20 + hw - 3, y, 3, 1, red_d if band else white_d)
	# 门和两扇小窗
	Px.rect(img, 16, 76, 8, 12, Color.html(WOOD_DARK))
	Px.rect(img, 17, 77, 6, 11, Color.html(WOOD))
	Px.rect(img, 20, 77, 1, 11, Color.html(WOOD_DARK))
	Px.px(img, 22, 83, Color.html("e0c060"))
	Px.rect(img, 18, 54, 4, 6, iron)
	Px.rect(img, 19, 55, 2, 4, Color.html("6a8494"))
	Px.rect(img, 18, 32, 4, 5, iron)
	Px.rect(img, 19, 33, 2, 3, Color.html("6a8494"))
	# 回廊
	Px.rect(img, 9, 25, 22, 3, iron)
	Px.rect(img, 9, 25, 22, 1, Color.html("5a5a64"))
	for x in range(10, 31, 4):
		Px.rect(img, x, 20, 1, 5, iron)
	Px.rect(img, 9, 20, 22, 1, iron)
	# 灯室
	Px.rect(img, 13, 11, 14, 14, iron)
	var glass := Color.html("ffd76a") if lit else Color.html("2a3038")
	Px.rect(img, 14, 12, 12, 12, glass)
	if lit:
		Px.rect(img, 17, 14, 6, 8, Color.html("fff6c8"))
	else:
		Px.rect(img, 15, 13, 2, 5, Color.html("46505c"))
	for x: int in [17, 22]:
		Px.rect(img, x, 12, 1, 12, iron)
	# 尖顶
	for i in 6:
		Px.rect(img, 12 + i, 5 + i, 16 - i * 2, 1, red if i % 2 == 0 else red_d)
	Px.rect(img, 12, 10, 16, 1, red_d)
	Px.rect(img, 19, 1, 2, 4, iron)
	Px.px(img, 19, 0, iron)
	return Px.outline(img)


## 白鹭的画室，64×56：刷白的墙，青灰瓦顶缺了一片瓦，蓝门，窗台上晾着几张画。
static func studio() -> Image:
	var img := Px.new_img(64, 56)
	var wall := Color.html("ece6d6")
	var wall_d := Color.html("cfc8b4")
	Px.rect(img, 6, 26, 52, 29, wall)
	Px.rect(img, 6, 26, 52, 2, wall_d)
	Px.rect(img, 6, 50, 52, 5, Color.html("8a8478"))
	Px.rect(img, 6, 54, 52, 1, Color.html("6a655c"))
	# 瓦顶
	var roof := Color.html("5f7480")
	var roof_d := Color.html("475a66")
	for i in 12:
		var hw := 20 + i
		Px.rect(img, 32 - hw, 4 + i * 2, hw * 2, 2, roof if i % 2 == 0 else roof_d)
	Px.rect(img, 12, 4, 40, 1, Color.html("7e94a0"))
	Px.rect(img, 1, 27, 62, 1, Color.html("2e3840"))
	# 屋檐缺的那片瓦
	Px.rect(img, 49, 22, 5, 4, Color.html("3a3430"))
	Px.rect(img, 50, 23, 3, 2, Color.html("8a6a4a"))
	# 门
	var door := Color.html("4a7a9a")
	var door_d := Color.html("34586e")
	Px.rect(img, 34, 34, 12, 21, door)
	Px.rect(img, 34, 34, 12, 1, door_d)
	Px.rect(img, 34, 34, 1, 21, door_d)
	Px.rect(img, 45, 34, 1, 21, door_d)
	Px.rect(img, 39, 35, 1, 20, door_d)
	Px.px(img, 43, 45, Color.html("e0c060"))
	# 窗和窗台上晾的画
	Px.rect(img, 11, 33, 16, 11, Color.html("3a3430"))
	Px.rect(img, 12, 34, 14, 9, Color.html("7a98a8"))
	Px.rect(img, 18, 34, 1, 9, Color.html("3a3430"))
	Px.rect(img, 12, 38, 14, 1, Color.html("3a3430"))
	Px.rect(img, 10, 44, 18, 2, Color.html(WOOD))
	Px.rect(img, 10, 45, 18, 1, Color.html(WOOD_DARK))
	var tints: Array[String] = ["e8b85a", "6aa8c8", "d87a6a"]
	for i in 3:
		Px.rect(img, 11 + i * 6, 39, 5, 5, Color.html("f4f0e4"))
		Px.rect(img, 12 + i * 6, 40, 3, 3, Color.html(tints[i]))
	return Px.outline(img)


## 画架，14×20：三条腿，上面架着一张画了一半的画。
static func easel() -> Image:
	var img := Px.new_img(14, 20)
	var wood := Color.html(WOOD)
	var wood_d := Color.html(WOOD_DARK)
	Px.line(img, Vector2i(6, 1), Vector2i(2, 19), wood)
	Px.line(img, Vector2i(7, 1), Vector2i(11, 19), wood_d)
	Px.line(img, Vector2i(6, 6), Vector2i(7, 18), wood_d)
	Px.rect(img, 2, 4, 10, 8, Color.html("f4f0e4"))
	Px.rect(img, 3, 5, 8, 3, Color.html("9ac8dc"))
	Px.rect(img, 3, 8, 8, 2, Color.html("5a9ac0"))
	Px.rect(img, 3, 10, 8, 1, Color.html("e9d8a6"))
	Px.rect(img, 8, 4, 1, 4, Color.html("ece8dc"))
	Px.rect(img, 1, 12, 12, 1, wood_d)
	return Px.outline(img)
