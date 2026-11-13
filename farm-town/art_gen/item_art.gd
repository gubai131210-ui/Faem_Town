class_name ItemArt
extends RefCounted
## 水果和野外采集物的 16×16 图标。图标名是 "wild:物品id"。

const LEAF := "4a9a3c"
const STEM := "84532d"


static func icon(id: String) -> Image:
	var img := Px.new_img(16, 16)
	var leaf := CropArt.ramp(Color.html(LEAF))
	var stem := Color.html(STEM)
	match id:
		"loquat":
			var c := CropArt.ramp(Color.html("f2b23e"))
			Px.line(img, Vector2i(8, 2), Vector2i(8, 5), stem)
			CropArt.ball(img, 5.5, 9.5, 2.8, 3.4, c)
			CropArt.ball(img, 10.5, 10.0, 2.8, 3.4, c)
			CropArt.ball(img, 8.0, 6.5, 2.6, 3.0, c)
			Px.px(img, 5, 12, stem)
			Px.px(img, 10, 13, stem)
			CropArt.ball(img, 11.5, 3.5, 2.4, 1.4, leaf)
		"peach":
			var c := CropArt.ramp(Color.html("f59a8a"))
			CropArt.ball(img, 8.0, 9.5, 5.2, 4.8, c)
			Px.line(img, Vector2i(8, 5), Vector2i(7, 10), c[2])
			Px.px(img, 5, 7, Color.html("fde0d0"))
			Px.px(img, 6, 7, Color.html("fde0d0"))
			CropArt.ball(img, 10.5, 4.0, 2.6, 1.4, leaf)
			Px.px(img, 8, 4, stem)
		"persimmon":
			var c := CropArt.ramp(Color.html("ee6a22"))
			CropArt.ball(img, 8.0, 9.8, 5.6, 4.4, c)
			Px.rect(img, 6, 5, 5, 1, leaf[1])
			Px.rect(img, 5, 6, 2, 1, leaf[2])
			Px.rect(img, 10, 6, 2, 1, leaf[2])
			Px.rect(img, 7, 4, 2, 1, stem)
		"mandarin":
			var c := CropArt.ramp(Color.html("f59a1e"))
			CropArt.ball(img, 8.0, 9.5, 5.2, 4.6, c)
			for p: Vector2i in [Vector2i(9, 8), Vector2i(7, 11), Vector2i(10, 11), Vector2i(6, 8)]:
				Px.px(img, p.x, p.y, c[2])
			Px.px(img, 8, 5, leaf[2])
			CropArt.ball(img, 10.5, 4.2, 2.4, 1.3, leaf)
		"peach_blossom":
			var c := CropArt.ramp(Color.html("f4a9be"))
			Px.line(img, Vector2i(3, 14), Vector2i(12, 4), stem)
			Px.line(img, Vector2i(8, 9), Vector2i(12, 10), stem)
			for p: Vector2i in [Vector2i(12, 3), Vector2i(8, 6), Vector2i(13, 10), Vector2i(5, 10), Vector2i(10, 7)]:
				_flower(img, p, c)
		"shepherds_purse":
			# 贴地的一丛锯齿叶，底下一小段白根
			for a: Vector2i in [Vector2i(2, 7), Vector2i(4, 4), Vector2i(8, 3), Vector2i(12, 4), Vector2i(14, 7), Vector2i(3, 10), Vector2i(13, 10)]:
				Px.line(img, Vector2i(8, 11), a, leaf[1])
				Px.px(img, a.x, a.y, leaf[0])
				Px.px(img, (a.x + 8) / 2, (a.y + 11) / 2 - 1, leaf[2])
			Px.rect(img, 7, 12, 2, 2, Color.html("f1ead6"))
		"spring_bamboo_shoot":
			_shoot(img, 8.0, 3, 14, 3.4, CropArt.ramp(Color.html("c9a063")), Color.html("7a5a34"), Color.html("a8c860"))
		"winter_bamboo_shoot":
			_shoot(img, 8.0, 5, 14, 4.4, CropArt.ramp(Color.html("d8b25a")), Color.html("8a6230"), Color.html("e8d890"))
		"fern":
			for x: int in [6, 10]:
				var top := 5 if x == 6 else 3
				Px.line(img, Vector2i(x, 14), Vector2i(x, top + 2), leaf[1])
				Px.px(img, x + 1, top + 1, leaf[1])
				Px.px(img, x + 2, top, leaf[0])
				Px.px(img, x + 3, top + 1, leaf[1])
				Px.px(img, x + 3, top + 2, leaf[2])
				Px.px(img, x + 2, top + 3, leaf[2])
				Px.px(img, x - 1, top + 6, leaf[0])
				Px.px(img, x + 1, top + 8, leaf[0])
		"bayberry":
			var c := CropArt.ramp(Color.html("a82a4a"))
			Px.line(img, Vector2i(8, 2), Vector2i(8, 5), stem)
			CropArt.ball(img, 5.5, 9.5, 3.4, 3.4, c)
			CropArt.ball(img, 11.0, 8.5, 3.2, 3.2, c)
			for p: Vector2i in [Vector2i(4, 9), Vector2i(6, 11), Vector2i(6, 8), Vector2i(10, 8), Vector2i(12, 10), Vector2i(11, 7)]:
				Px.px(img, p.x, p.y, Color.html("d8607a"))
			CropArt.ball(img, 11.0, 3.6, 2.6, 1.3, leaf)
		"water_caltrop":
			var c := CropArt.ramp(Color.html("5a3a52"))
			CropArt.ball(img, 8.0, 9.5, 4.2, 3.2, c)
			Px.line(img, Vector2i(4, 9), Vector2i(1, 6), c[1])
			Px.line(img, Vector2i(11, 9), Vector2i(14, 6), c[2])
			Px.px(img, 8, 5, c[1])
			Px.px(img, 8, 6, c[1])
			Px.px(img, 6, 8, Color.html("8a6a82"))
		"mint":
			var c := CropArt.ramp(Color.html("6fc88a"))
			Px.line(img, Vector2i(8, 14), Vector2i(8, 3), Color.html("3f8a5a"))
			for y: int in [5, 8, 11]:
				var r := 1.6 + (y - 5) * 0.2
				CropArt.ball(img, 5.5, float(y), r + 0.8, 1.3, c)
				CropArt.ball(img, 10.5, float(y), r + 0.8, 1.3, c)
			CropArt.ball(img, 8.0, 3.0, 1.6, 1.4, c)
		"chestnut":
			var c := CropArt.ramp(Color.html("8a4a2a"))
			CropArt.ball(img, 8.0, 9.5, 5.0, 4.4, c)
			Px.rect(img, 5, 12, 6, 2, Color.html("d8b890"))
			Px.px(img, 8, 4, c[2])
			Px.px(img, 8, 3, Color.html("d8b890"))
			Px.px(img, 6, 7, Color.html("c07a4a"))
		"wild_mushroom":
			var cap := CropArt.ramp(Color.html("b8763e"))
			var stalk := Color.html("f1ead6")
			Px.rect(img, 5, 9, 2, 5, stalk)
			Px.rect(img, 11, 11, 2, 3, stalk)
			Px.px(img, 6, 13, Color.html("cbbfa3"))
			CropArt.ball(img, 6.0, 7.0, 4.2, 2.8, cap)
			CropArt.ball(img, 12.0, 9.8, 2.8, 2.0, cap)
			Px.px(img, 4, 6, Color.html("e8c89a"))
			Px.px(img, 7, 7, Color.html("e8c89a"))
		"hawthorn":
			var c := CropArt.ramp(Color.html("d8342a"))
			Px.line(img, Vector2i(8, 2), Vector2i(8, 6), stem)
			Px.line(img, Vector2i(8, 4), Vector2i(4, 7), stem)
			Px.line(img, Vector2i(8, 4), Vector2i(12, 7), stem)
			CropArt.ball(img, 4.5, 9.5, 2.4, 2.4, c)
			CropArt.ball(img, 11.5, 9.5, 2.4, 2.4, c)
			CropArt.ball(img, 8.0, 11.5, 2.4, 2.4, c)
			for p: Vector2i in [Vector2i(4, 11), Vector2i(11, 11), Vector2i(8, 13)]:
				Px.px(img, p.x, p.y, Color.html("5a2a20"))
		"pine_cone":
			var c := CropArt.ramp(Color.html("8a5a34"))
			CropArt.ball(img, 8.0, 8.5, 4.0, 5.6, c)
			for y in range(3, 14):
				for x in range(4, 12):
					if img.get_pixel(x, y).a > 0.0 and (x + y * 2) % 4 == 0:
						img.set_pixel(x, y, Color.html("5a3a20"))
			Px.px(img, 8, 2, stem)
		"clam":
			# 扇形的壳，一圈圈的纹从壳顶散开
			var c := CropArt.ramp(Color.html("e2cfa8"))
			CropArt.ball(img, 8.0, 9.5, 5.6, 4.2, c)
			Px.rect(img, 7, 4, 2, 2, c[2])
			for a: Vector2i in [Vector2i(3, 10), Vector2i(5, 12), Vector2i(8, 13), Vector2i(11, 12), Vector2i(13, 10)]:
				Px.line(img, Vector2i(8, 6), a, Color.html("b89a6a"))
			Px.px(img, 5, 7, Color.html("f6ecd2"))
		"kelp":
			# 两条弯弯的海带
			var c := CropArt.ramp(Color.html("4a6a3a"))
			for k in range(12):
				var y := 14 - k
				var x := 5 + int(roundf(sin(k * 0.9) * 1.4))
				Px.rect(img, x, y, 2, 1, c[1] if k % 3 != 0 else c[0])
				var x2 := 10 + int(roundf(sin(k * 0.9 + 2.0) * 1.4))
				if k < 10:
					Px.rect(img, x2, y, 2, 1, c[2] if k % 3 != 1 else c[1])
		"conch":
			# 尖顶的螺，壳口朝右下，泛一点粉
			var c := CropArt.ramp(Color.html("e8c8a0"))
			CropArt.ball(img, 8.5, 10.0, 4.6, 3.8, c)
			CropArt.ball(img, 6.5, 6.5, 3.0, 2.6, c)
			CropArt.ball(img, 5.0, 4.0, 1.8, 1.6, c)
			Px.px(img, 4, 2, c[2])
			Px.line(img, Vector2i(4, 7), Vector2i(9, 7), c[2])
			Px.line(img, Vector2i(4, 5), Vector2i(7, 4), c[2])
			Px.rect(img, 9, 10, 3, 2, Color.html("e89a9a"))
			Px.px(img, 10, 12, Color.html("c87878"))
		"oyster":
			# 糙壳半开，里面一点白肉
			var c := CropArt.ramp(Color.html("8a8478"))
			CropArt.ball(img, 8.0, 10.5, 5.8, 3.4, c)
			CropArt.ball(img, 8.0, 7.0, 5.2, 2.8, c)
			Px.rect(img, 4, 8, 8, 2, Color.html("f1ead6"))
			Px.rect(img, 6, 9, 3, 1, Color.html("d8d0bc"))
			for p: Vector2i in [Vector2i(5, 6), Vector2i(9, 5), Vector2i(11, 7), Vector2i(6, 12), Vector2i(10, 12)]:
				Px.px(img, p.x, p.y, Color.html("5e5a52"))
		_:
			CropArt.ball(img, 8.0, 9.0, 4.0, 4.0, CropArt.ramp(Color.html("c8c8c8")))
	return Px.outline(img)


## 遗物的 16×16 图标，按 data/relics.json 里的 shape 画。都是旧东西，颜色压得灰一点。
## 动物的产物和饲料的 16×16 图标。图标名是 "product:物品id"。
static func product(id: StringName) -> Image:
	var img := Px.new_img(16, 16)
	match id:
		&"egg":
			var c := CropArt.ramp(Color.html("f3e4c4"))
			CropArt.ball(img, 8.0, 9.0, 4.2, 5.4, c)
			Px.px(img, 6, 5, Color.html("fbf7ec"))
			Px.px(img, 6, 6, Color.html("fbf7ec"))
		&"duck_egg":
			var c := CropArt.ramp(Color.html("cfe3d6"))
			CropArt.ball(img, 8.0, 8.5, 4.8, 6.0, c)
			Px.px(img, 6, 4, Color.html("eef7f0"))
			Px.px(img, 6, 5, Color.html("eef7f0"))
			Px.px(img, 9, 11, c[2])
		&"feather":
			var c := CropArt.ramp(Color.html("f1ead6"))
			# 羽轴斜着，两边的羽片一片片
			Px.line(img, Vector2i(3, 14), Vector2i(12, 3), Color.html("8a6a4e"))
			for k in range(5):
				var p := Vector2i(5 + k * 2, 12 - k * 2)
				Px.line(img, p, p + Vector2i(-2, -1), c[1])
				Px.line(img, p + Vector2i(1, -1), p + Vector2i(3, 0), c[0])
			Px.px(img, 12, 3, c[0])
			Px.px(img, 11, 4, c[0])
			Px.px(img, 10, 5, c[0])
			Px.px(img, 11, 5, c[1])
		&"mulberry_leaf":
			var c := CropArt.ramp(Color.html("5fa848"))
			CropArt.ball(img, 6.0, 8.0, 3.6, 4.6, c)
			CropArt.ball(img, 10.5, 9.5, 3.2, 4.0, c)
			Px.line(img, Vector2i(6, 5), Vector2i(6, 12), c[2])
			Px.line(img, Vector2i(10, 7), Vector2i(11, 13), c[2])
			Px.line(img, Vector2i(7, 13), Vector2i(10, 14), Color.html("7a5a36"))
		&"goat_milk":
			# 小陶罐，口上蒙着布
			var jar := CropArt.ramp(Color.html("b8805a"))
			CropArt.ball(img, 8.0, 10.0, 4.4, 4.2, jar)
			Px.rect(img, 6, 4, 4, 3, jar[1])
			Px.rect(img, 5, 3, 6, 2, Color.html("f6efe6"))
			Px.rect(img, 5, 5, 6, 1, Color.html("c8483c"))
		&"milk":
			# 木桶，里面是奶
			var wood := CropArt.ramp(Color.html("b07a42"))
			Px.rect(img, 4, 6, 8, 8, wood[1])
			Px.rect(img, 4, 6, 1, 8, wood[0])
			Px.rect(img, 11, 6, 1, 8, wood[2])
			Px.rect(img, 4, 8, 8, 1, Color.html("5a5a62"))
			Px.rect(img, 4, 12, 8, 1, Color.html("5a5a62"))
			Px.rect(img, 5, 5, 6, 2, Color.html("fbf7ec"))
			Px.line(img, Vector2i(4, 5), Vector2i(7, 2), wood[2])
			Px.line(img, Vector2i(8, 2), Vector2i(11, 5), wood[2])
		&"wool":
			var c := CropArt.ramp(Color.html("f1ead6"))
			CropArt.ball(img, 6.0, 9.0, 3.6, 3.4, c)
			CropArt.ball(img, 10.5, 9.5, 3.4, 3.2, c)
			CropArt.ball(img, 8.0, 6.5, 3.4, 3.0, c)
			Px.px(img, 7, 5, Color.html("fffdf6"))
			Px.px(img, 5, 8, Color.html("fffdf6"))
		&"cocoon":
			var c := CropArt.ramp(Color.html("f3efe2"))
			CropArt.ball(img, 6.0, 7.0, 2.6, 3.8, c)
			CropArt.ball(img, 10.5, 10.0, 2.6, 3.8, c)
			Px.px(img, 5, 5, Color.html("ffffff"))
			Px.px(img, 10, 8, Color.html("ffffff"))
		&"honey_wild", &"honey_rape", &"honey_sunflower", &"honey_chrys", &"honey_osmanthus", &"honey_camellia":
			var tints: Dictionary[StringName, String] = {&"honey_wild": "d89a3a", &"honey_rape": "f2e2a0", &"honey_sunflower": "f2b83a",
				&"honey_chrys": "e2a850", &"honey_osmanthus": "f0c860", &"honey_camellia": "b86a2e"}
			var c := CropArt.ramp(Color.html(tints[id]))
			# 玻璃罐：罐身是蜜的颜色，木塞，一道高光
			Px.rect(img, 4, 6, 8, 8, c[1])
			Px.rect(img, 5, 14, 6, 1, c[2])
			Px.rect(img, 4, 12, 8, 2, c[2])
			Px.rect(img, 5, 4, 6, 2, Color.html("e8f0f0"))
			Px.rect(img, 6, 2, 4, 2, Color.html("9a6a40"))
			Px.rect(img, 5, 7, 1, 4, c[0])
			Px.px(img, 6, 6, Color.html("ffffff"))
		&"pickles":
			# 腌菜坛子：深色的坛身，口上压着石头
			var jar := CropArt.ramp(Color.html("6a5a48"))
			CropArt.ball(img, 8.0, 10.0, 4.8, 4.2, jar)
			Px.rect(img, 5, 5, 6, 2, jar[2])
			Px.rect(img, 6, 3, 4, 2, Color.html("9aa0a6"))
			Px.rect(img, 6, 9, 4, 3, Color.html("c8483c"))
			Px.px(img, 7, 10, Color.html("f1ead6"))
			Px.px(img, 8, 10, Color.html("f1ead6"))
		&"white_rice", &"flour":
			# 布袋：米袋口敞着露出米，面袋扎着口
			var sack := CropArt.ramp(Color.html("d8c8a8" if id == &"white_rice" else "e8dcc0"))
			Px.rect(img, 4, 6, 8, 8, sack[1])
			Px.rect(img, 4, 6, 1, 8, sack[0])
			Px.rect(img, 4, 12, 8, 2, sack[2])
			if id == &"white_rice":
				Px.rect(img, 5, 4, 6, 3, Color.html("fbf7ec"))
				Px.px(img, 6, 5, Color.html("d8d0c0"))
				Px.px(img, 9, 4, Color.html("d8d0c0"))
			else:
				Px.rect(img, 6, 4, 4, 2, sack[2])
				Px.rect(img, 5, 3, 6, 1, sack[0])
				Px.rect(img, 6, 5, 4, 1, Color.html("9a6a40"))
				Px.rect(img, 6, 9, 4, 2, Color.html("fbf7ec"))
		&"cooking_oil", &"lamp_oil":
			# 细颈的壶
			var c := CropArt.ramp(Color.html("e8c84a" if id == &"cooking_oil" else "7a94b8"))
			CropArt.ball(img, 8.0, 10.5, 4.2, 3.8, c)
			Px.rect(img, 7, 4, 2, 4, c[1])
			Px.rect(img, 6, 2, 4, 2, Color.html("9a6a40"))
			Px.px(img, 6, 9, c[0])
			Px.px(img, 6, 10, c[0])
			if id == &"lamp_oil":
				Px.px(img, 8, 1, Color.html("f0a040"))
		&"dried_tea":
			# 纸包，麻绳十字捆着
			var paper := CropArt.ramp(Color.html("b8a070"))
			Px.rect(img, 3, 5, 10, 9, paper[1])
			Px.rect(img, 3, 5, 10, 1, paper[0])
			Px.rect(img, 3, 13, 10, 1, paper[2])
			Px.rect(img, 7, 5, 1, 9, Color.html("6a4a2a"))
			Px.rect(img, 3, 9, 10, 1, Color.html("6a4a2a"))
			Px.rect(img, 9, 6, 3, 2, Color.html("4a8a3c"))
		&"silk":
			# 一绞丝：拧成麻花的一束
			var c := CropArt.ramp(Color.html("f3ecd4"))
			for k in range(5):
				CropArt.ball(img, 4.5 + k * 1.8, 11.5 - k * 1.8, 2.4, 2.0, c)
			Px.line(img, Vector2i(3, 11), Vector2i(11, 3), Color.html("fffdf6"))
			Px.rect(img, 7, 7, 2, 2, Color.html("c8483c"))
		&"cheese":
			# 切开的一角
			var c := CropArt.ramp(Color.html("f0cc5a"))
			for y in range(6, 14):
				Px.rect(img, 3, y, mini(11, 4 + (y - 6) * 2), 1, c[1] if y < 12 else c[2])
			Px.rect(img, 3, 6, 4, 1, c[0])
			for p: Vector2i in [Vector2i(5, 9), Vector2i(8, 11), Vector2i(10, 12), Vector2i(4, 12)]:
				Px.px(img, p.x, p.y, c[2])
		&"scarecrow":
			var straw := CropArt.ramp(Color.html("d8b45a"))
			Px.rect(img, 7, 3, 2, 12, Color.html("7a5a36"))
			Px.rect(img, 2, 7, 12, 2, Color.html("7a5a36"))
			Px.rect(img, 5, 6, 6, 5, Color.html("8a6a9a"))
			Px.rect(img, 6, 3, 4, 3, straw[0])
			Px.rect(img, 4, 2, 8, 1, straw[2])
			Px.rect(img, 6, 1, 4, 1, straw[2])
			Px.px(img, 2, 9, straw[1])
			Px.px(img, 13, 9, straw[1])
		&"feed":
			var sack := CropArt.ramp(Color.html("d8b45a"))
			Px.rect(img, 4, 6, 8, 8, sack[1])
			Px.rect(img, 5, 6, 6, 1, sack[0])
			Px.rect(img, 4, 12, 8, 2, sack[2])
			Px.rect(img, 6, 4, 4, 2, sack[2])
			Px.rect(img, 5, 3, 6, 1, sack[0])
			for p: Vector2i in [Vector2i(6, 8), Vector2i(9, 9), Vector2i(7, 11), Vector2i(10, 11)]:
				Px.px(img, p.x, p.y, Color.html("f7d24a"))
	return img


## 加工设备在铺子里的 16×16 图标。图标名是 "machine:设备id"。照着农场上那件物件的样子画，只留认得出的轮廓。
static func machine(id: StringName) -> Image:
	var img := Px.new_img(16, 16)
	var wood := CropArt.ramp(Color.html("b07a42"))
	var dark := Color.html("4a3626")
	match id:
		&"pickle_vat":
			# 高身的陶缸，口上压着一块石头
			var jar := CropArt.ramp(Color.html("c08a5c"))
			CropArt.ball(img, 8.0, 10.0, 5.0, 5.0, jar)
			Px.rect(img, 5, 4, 6, 3, jar[1])
			Px.rect(img, 5, 4, 1, 3, jar[0])
			Px.rect(img, 10, 4, 1, 3, jar[2])
			Px.rect(img, 4, 9, 8, 1, jar[2])
			Px.rect(img, 6, 2, 4, 2, Color.html("9aa0a6"))
			Px.px(img, 7, 2, Color.html("c8ccd0"))
		&"millstone":
			# 一扇圆磨盘架在木座上，右边伸出推杆
			var stone := CropArt.ramp(Color.html("a8acb0"))
			Px.rect(img, 3, 12, 9, 3, wood[1])
			Px.rect(img, 3, 14, 9, 1, wood[2])
			CropArt.ball(img, 7.5, 7.5, 5.0, 5.0, stone)
			Px.rect(img, 7, 4, 2, 2, dark)
			Px.rect(img, 6, 12, 3, 1, Color.html("fbf7ec"))
			Px.rect(img, 12, 6, 3, 1, wood[2])
			Px.rect(img, 14, 6, 1, 4, wood[2])
		&"oil_press":
			# 箍着铁箍的木榨，底下滴着油
			Px.rect(img, 3, 3, 10, 6, wood[1])
			Px.rect(img, 3, 3, 10, 1, wood[0])
			Px.rect(img, 3, 8, 10, 1, wood[2])
			Px.rect(img, 3, 3, 1, 6, Color.html("5a5a62"))
			Px.rect(img, 12, 3, 1, 6, Color.html("5a5a62"))
			Px.rect(img, 6, 5, 4, 2, wood[2])
			Px.rect(img, 3, 9, 2, 5, wood[2])
			Px.rect(img, 11, 9, 2, 5, wood[2])
			Px.rect(img, 7, 10, 2, 3, Color.html("e8c84a"))
			Px.px(img, 7, 13, Color.html("c8a030"))
			Px.px(img, 8, 13, Color.html("c8a030"))
		&"tea_roaster":
			# 土灶上架一口锅，锅里是茶叶，灶口有火
			var clay := CropArt.ramp(Color.html("b8805a"))
			Px.rect(img, 3, 7, 10, 8, clay[1])
			Px.rect(img, 3, 7, 1, 8, clay[0])
			Px.rect(img, 12, 7, 1, 8, clay[2])
			Px.rect(img, 3, 14, 10, 1, clay[2])
			Px.rect(img, 7, 11, 3, 4, dark)
			Px.rect(img, 8, 13, 1, 2, Color.html("f0a040"))
			Px.rect(img, 2, 5, 12, 2, Color.html("4a4a52"))
			Px.rect(img, 4, 3, 8, 2, Color.html("5fa848"))
			Px.rect(img, 5, 2, 3, 1, Color.html("7cc74f"))
			Px.px(img, 10, 3, Color.html("7cc74f"))
		&"silk_reel":
			# 两根立柱夹着两卷白丝
			Px.rect(img, 3, 2, 2, 13, wood[1])
			Px.rect(img, 11, 2, 2, 13, wood[1])
			Px.rect(img, 3, 2, 1, 13, wood[0])
			Px.rect(img, 12, 2, 1, 13, wood[2])
			Px.rect(img, 2, 3, 12, 1, wood[2])
			Px.rect(img, 2, 9, 12, 1, wood[2])
			for y: int in [4, 10]:
				Px.rect(img, 5, y, 6, 4, Color.html("f3ecd4"))
				Px.rect(img, 5, y, 6, 1, Color.html("fffdf6"))
				Px.rect(img, 5, y + 3, 6, 1, Color.html("d0c6a8"))
				Px.px(img, 7, y + 2, Color.html("d0c6a8"))
		&"cheese_rack":
			# 三层木架，每层晾着奶酪
			Px.rect(img, 3, 2, 1, 13, wood[2])
			Px.rect(img, 12, 2, 1, 13, wood[2])
			var cheese := CropArt.ramp(Color.html("f0cc5a"))
			for y: int in [5, 10, 14]:
				Px.rect(img, 3, y, 10, 1, wood[1])
			# 每块奶酪：[左, 上, 高]，底边正好落在搁板上
			for b: Array in [[5, 2, 3], [9, 3, 2], [4, 7, 3], [8, 7, 3], [6, 12, 2]]:
				Px.rect(img, b[0], b[1], 3, b[2], cheese[1])
				Px.rect(img, b[0], b[1], 3, 1, cheese[0])
			Px.rect(img, 9, 12, 3, 2, Color.html("fbf7ec"))
	return img


## 食物的 16×16 图标。图标名是 "food:物品id"。汤、饭、面都盛在碗里，靠颜色和点缀区分。
static func food(id: StringName) -> Image:
	var img := Px.new_img(16, 16)
	# 碗里的东西：[主色, 点缀的颜色]
	var bowls: Dictionary[StringName, Array] = {
		&"radish_soup": ["efe6cf", "fbf7ec"],
		&"stir_greens": ["5fa848", "9ad878"],
		&"rice_bowl": ["fbf7ec", "e2dccc"],
		&"fish_soup": ["ece6da", "8a98a4"],
		&"plain_noodles": ["e0c080", "5fa848"],
		&"egg_fried_rice": ["f2dc8a", "f0a040"],
		&"pumpkin_porridge": ["f0a23c", "f8cc70"],
	}
	if bowls.has(id):
		var cols: Array = bowls[id]
		var fill := Color.html(str(cols[0]))
		var dot := Color.html(str(cols[1]))
		var bowl := CropArt.ramp(Color.html("5a7fa8"))
		Px.rect(img, 4, 5, 8, 1, fill)
		Px.rect(img, 3, 6, 10, 2, fill)
		Px.rect(img, 2, 8, 12, 1, bowl[0])
		Px.rect(img, 2, 9, 12, 1, bowl[1])
		Px.rect(img, 3, 10, 10, 2, bowl[1])
		Px.rect(img, 4, 12, 8, 1, bowl[2])
		Px.rect(img, 6, 13, 4, 1, bowl[2])
		for p: Vector2i in [Vector2i(5, 6), Vector2i(8, 5), Vector2i(10, 7), Vector2i(7, 7)]:
			Px.px(img, p.x, p.y, dot)
		if Database.has_item(id) and Database.item(id).hot:
			for p: Vector2i in [Vector2i(6, 3), Vector2i(7, 2), Vector2i(10, 3), Vector2i(9, 1)]:
				Px.px(img, p.x, p.y, Color(1, 1, 1, 0.75))
		return img
	match id:
		&"fried_egg":
			var white := CropArt.ramp(Color.html("fbf7ec"))
			CropArt.ball(img, 8.0, 9.0, 6.0, 4.4, white)
			CropArt.ball(img, 8.5, 8.5, 2.4, 2.2, CropArt.ramp(Color.html("f2b23e")))
			Px.px(img, 7, 7, Color.html("fde8a0"))
		&"roast_sweet_potato":
			var skin := CropArt.ramp(Color.html("9a5a48"))
			CropArt.ball(img, 8.0, 9.5, 6.2, 3.6, skin)
			Px.rect(img, 5, 8, 6, 3, Color.html("f0a23c"))
			Px.rect(img, 6, 8, 3, 1, Color.html("f8cc70"))
			Px.px(img, 7, 4, Color(1, 1, 1, 0.75))
			Px.px(img, 9, 3, Color(1, 1, 1, 0.75))
		&"tea_egg":
			var shell := CropArt.ramp(Color.html("a8784a"))
			CropArt.ball(img, 8.0, 9.0, 4.2, 5.4, shell)
			for a: Array in [[Vector2i(6, 6), Vector2i(9, 9)], [Vector2i(9, 6), Vector2i(7, 11)], [Vector2i(5, 10), Vector2i(10, 12)]]:
				Px.line(img, a[0], a[1], shell[2])
		&"milk_cake", &"osmanthus_cake":
			var c := CropArt.ramp(Color.html("f0d8a0" if id == &"milk_cake" else "fbf3dc"))
			Px.rect(img, 3, 7, 10, 6, c[1])
			Px.rect(img, 3, 7, 10, 1, c[0])
			Px.rect(img, 3, 12, 10, 1, c[2])
			Px.rect(img, 2, 13, 12, 1, Color.html("8a6a4e"))
			var top := Color.html("d89a3a" if id == &"milk_cake" else "f2b83a")
			for p: Vector2i in [Vector2i(5, 6), Vector2i(8, 6), Vector2i(11, 6), Vector2i(6, 9), Vector2i(10, 10)]:
				Px.px(img, p.x, p.y, top)
	return img


static func relic(id: StringName) -> Image:
	var img := Px.new_img(16, 16)
	var shape := Database.relic(id).shape if Database.has_relic(id) else ""
	var paper := Color.html("e8dcb8")
	var paper_dk := Color.html("c9b88e")
	var ink := Color.html("5a4a3c")
	var iron := CropArt.ramp(Color.html("7a7a80"))
	var brass := CropArt.ramp(Color.html("c09a3e"))
	var wood := CropArt.ramp(Color.html("8a5a34"))
	match shape:
		"frog":
			# 压秤的石蛙
			var stone := CropArt.ramp(Color.html("7a9a6a"))
			CropArt.ball(img, 8.0, 10.0, 5.5, 3.8, stone)
			Px.rect(img, 4, 5, 3, 3, stone[1])
			Px.rect(img, 9, 5, 3, 3, stone[1])
			Px.px(img, 5, 6, ink)
			Px.px(img, 10, 6, ink)
			Px.rect(img, 2, 13, 3, 1, stone[2])
			Px.rect(img, 11, 13, 3, 1, stone[2])
		"rope":
			# 一卷麻绳
			var hemp := CropArt.ramp(Color.html("b89a62"))
			CropArt.ball(img, 8.0, 9.0, 5.5, 4.5, hemp)
			CropArt.ball(img, 8.0, 9.0, 2.2, 1.6, [ink, ink, ink])
			for p: Vector2i in [Vector2i(4, 7), Vector2i(6, 12), Vector2i(11, 7), Vector2i(12, 10), Vector2i(8, 5)]:
				Px.px(img, p.x, p.y, hemp[2])
			Px.line(img, Vector2i(12, 12), Vector2i(14, 14), hemp[1])
		"umbrella":
			var oil := CropArt.ramp(Color.html("c8643a"))
			Px.line(img, Vector2i(3, 13), Vector2i(12, 4), oil[1])
			Px.line(img, Vector2i(4, 13), Vector2i(13, 4), oil[2])
			Px.line(img, Vector2i(3, 12), Vector2i(11, 4), oil[0])
			Px.px(img, 13, 3, wood[1])
			Px.px(img, 14, 2, wood[1])
			Px.px(img, 2, 14, wood[1])
			Px.px(img, 1, 14, wood[2])
		"shoes":
			for at: Vector2i in [Vector2i(2, 5), Vector2i(8, 9)]:
				Px.rect(img, at.x, at.y, 5, 2, Color.html("2e2e3c"))
				Px.px(img, at.x + 5, at.y + 1, Color.html("2e2e3c"))
				Px.px(img, at.x + 1, at.y, Color.html("5a5a6c"))
				Px.rect(img, at.x, at.y + 2, 6, 1, Color.html("e8e2d0"))
		"clock":
			Px.rect(img, 4, 3, 9, 11, wood[1])
			Px.rect(img, 4, 3, 1, 11, wood[0])
			Px.rect(img, 12, 3, 1, 11, wood[2])
			Px.rect(img, 6, 2, 5, 1, wood[0])
			Px.rect(img, 6, 5, 5, 5, Color.html("f0ead8"))
			Px.px(img, 8, 7, ink)
			Px.px(img, 8, 6, ink)
			Px.px(img, 9, 7, ink)
			Px.px(img, 8, 12, brass[1])
		"lampshade":
			# 被啃出洞的纸灯罩
			for y in range(4, 13):
				var k := 1 if y < 6 or y > 10 else 0
				Px.rect(img, 4 + k, y, 8 - k * 2, 1, paper if y < 10 else paper_dk)
			Px.rect(img, 6, 3, 4, 1, wood[1])
			Px.rect(img, 6, 13, 4, 1, wood[2])
			Px.rect(img, 6, 6, 2, 2, Color(0, 0, 0, 0))
			Px.px(img, 10, 9, Color(0, 0, 0, 0))
			Px.px(img, 9, 5, Color(0, 0, 0, 0))
		"photo":
			# 一张照片，脸那里是白的
			Px.rect(img, 3, 3, 10, 11, paper)
			Px.rect(img, 4, 4, 8, 7, Color.html("6a6258"))
			Px.rect(img, 6, 8, 4, 3, Color.html("3c3832"))
			Px.rect(img, 7, 5, 2, 3, Color.html("d8d0c0"))
			Px.rect(img, 3, 13, 10, 1, paper_dk)
		"family":
			# 全家福：两个大人中间一个孩子，脸还看得清
			Px.rect(img, 2, 3, 12, 11, paper)
			Px.rect(img, 3, 4, 10, 8, Color.html("8a7a62"))
			Px.rect(img, 4, 7, 3, 5, Color.html("3c3832"))
			Px.rect(img, 9, 7, 3, 5, Color.html("4a443c"))
			Px.rect(img, 7, 9, 2, 3, Color.html("b04040"))
			Px.rect(img, 5, 5, 1, 2, Color.html("ecdcc4"))
			Px.rect(img, 10, 5, 1, 2, Color.html("ecdcc4"))
			Px.px(img, 7, 8, Color.html("ecdcc4"))
			Px.rect(img, 2, 13, 12, 1, paper_dk)
		"roster":
			# 名单：一行行的名字，大半被水洗掉了，只剩最底下一行
			Px.rect(img, 3, 2, 10, 13, paper)
			Px.rect(img, 3, 14, 10, 1, paper_dk)
			Px.rect(img, 3, 2, 10, 1, Color.html("b04040"))
			for y: int in [4, 6, 8, 10]:
				Px.rect(img, 5, y, 6, 1, paper_dk)
			Px.rect(img, 5, 12, 4, 1, ink)
			Px.px(img, 11, 12, Color.html("b04040"))
		"tag":
			# 木头名牌，字磨没了
			Px.rect(img, 4, 5, 9, 6, wood[1])
			Px.rect(img, 4, 5, 9, 1, wood[0])
			Px.rect(img, 4, 10, 9, 1, wood[2])
			Px.px(img, 5, 7, Color.html("3a2a1c"))
			Px.line(img, Vector2i(5, 7), Vector2i(2, 3), Color.html("b04040"))
			Px.rect(img, 7, 7, 4, 1, wood[2])
			Px.rect(img, 8, 8, 2, 1, wood[2])
		"figure":
			# 纸扎的小人
			CropArt.ball(img, 7.5, 4.0, 2.4, 2.4, [paper, paper, paper_dk])
			for y in range(7, 14):
				var k := (y - 6) / 2
				Px.rect(img, 7 - k, y, k * 2 + 2, 1, paper if y < 12 else paper_dk)
			Px.rect(img, 6, 9, 4, 1, Color.html("b04040"))
			Px.line(img, Vector2i(5, 8), Vector2i(3, 10), paper)
			Px.line(img, Vector2i(10, 8), Vector2i(12, 10), paper)
		"wick":
			Px.line(img, Vector2i(4, 13), Vector2i(11, 4), Color.html("d8c8a0"))
			Px.line(img, Vector2i(5, 13), Vector2i(12, 4), Color.html("b8a880"))
			Px.rect(img, 11, 2, 3, 3, Color.html("3a3030"))
			Px.px(img, 12, 1, Color.html("f0a040"))
		"page", "sheet":
			Px.rect(img, 4, 2, 9, 12, paper)
			Px.rect(img, 4, 13, 9, 1, paper_dk)
			for y: int in [5, 7, 9, 11]:
				Px.rect(img, 6, y, 5 if y != 11 else 3, 1, ink)
			if shape == "sheet":
				for p: Vector2i in [Vector2i(7, 4), Vector2i(10, 6), Vector2i(8, 10)]:
					Px.px(img, p.x, p.y, Color.html("a04040"))
			Px.px(img, 12, 2, Color(0, 0, 0, 0))
			Px.px(img, 12, 3, paper_dk)
		"sketch", "blueprint":
			var back := Color.html("5a7aa0") if shape == "blueprint" else paper
			var line := Color.html("e8f0ff") if shape == "blueprint" else ink
			Px.rect(img, 2, 3, 12, 10, back)
			Px.line(img, Vector2i(3, 11), Vector2i(13, 11), line)
			Px.line(img, Vector2i(4, 11), Vector2i(7, 6), line)
			Px.line(img, Vector2i(7, 6), Vector2i(10, 6), line)
			Px.line(img, Vector2i(10, 6), Vector2i(12, 11), line)
			if shape == "blueprint":
				Px.rect(img, 5, 9, 2, 2, line)
				Px.rect(img, 9, 9, 2, 2, line)
			else:
				Px.rect(img, 6, 8, 1, 3, line)
		"envelope":
			Px.rect(img, 2, 5, 12, 8, paper)
			Px.line(img, Vector2i(2, 5), Vector2i(8, 10), paper_dk)
			Px.line(img, Vector2i(13, 5), Vector2i(8, 10), paper_dk)
			Px.rect(img, 10, 6, 3, 2, Color.html("b05050"))
		"seal":
			Px.rect(img, 5, 2, 6, 6, brass[1])
			Px.rect(img, 5, 2, 2, 6, brass[0])
			Px.rect(img, 9, 2, 2, 6, brass[2])
			Px.rect(img, 4, 8, 8, 5, Color.html("a03030"))
			Px.rect(img, 4, 12, 8, 1, Color.html("702020"))
			Px.px(img, 6, 10, Color.html("e8c0c0"))
			Px.px(img, 9, 10, Color.html("e8c0c0"))
		"chisel":
			Px.rect(img, 3, 2, 4, 6, wood[1])
			Px.rect(img, 3, 2, 1, 6, wood[0])
			Px.rect(img, 6, 2, 1, 6, wood[2])
			Px.rect(img, 4, 8, 2, 2, iron[1])
			Px.rect(img, 9, 10, 2, 3, iron[1])
			Px.px(img, 10, 13, iron[0])
			Px.px(img, 7, 10, iron[2])
		"hook":
			Px.line(img, Vector2i(8, 2), Vector2i(8, 9), iron[1])
			Px.line(img, Vector2i(8, 10), Vector2i(6, 12), iron[1])
			Px.line(img, Vector2i(5, 12), Vector2i(4, 9), iron[0])
			Px.px(img, 4, 8, iron[0])
			Px.rect(img, 8, 2, 1, 3, Color.html("c03030"))
		"bell":
			# 牛铃：上窄下宽，顶上一个环，底下露出铃舌
			Px.rect(img, 6, 4, 4, 2, brass[1])
			Px.rect(img, 5, 6, 6, 3, brass[1])
			Px.rect(img, 4, 9, 8, 3, brass[1])
			Px.rect(img, 4, 11, 8, 1, brass[2])
			Px.rect(img, 5, 6, 1, 5, brass[0])
			Px.rect(img, 7, 2, 2, 2, iron[1])
			Px.px(img, 7, 3, Color(0, 0, 0, 0))
			Px.rect(img, 7, 12, 2, 2, iron[2])
			Px.px(img, 8, 8, ink)
		"whistle":
			Px.rect(img, 3, 6, 10, 4, Color.html("c8b060"))
			Px.rect(img, 3, 6, 10, 1, Color.html("e0d090"))
			Px.rect(img, 3, 9, 10, 1, Color.html("8a7a3a"))
			Px.rect(img, 6, 5, 2, 1, Color.html("5a4a2a"))
			Px.line(img, Vector2i(12, 7), Vector2i(14, 3), Color.html("a03030"))
		"key":
			# 井口的钥匙：长柄，圆环头上缠着布条，底下两个齿
			Px.rect(img, 5, 2, 5, 5, iron[1])
			Px.rect(img, 6, 3, 3, 3, Color(0, 0, 0, 0))
			Px.rect(img, 5, 2, 5, 1, iron[0])
			Px.rect(img, 7, 7, 2, 7, iron[1])
			Px.rect(img, 8, 7, 1, 7, iron[2])
			Px.rect(img, 9, 10, 2, 1, iron[1])
			Px.rect(img, 9, 12, 3, 1, iron[1])
			Px.rect(img, 4, 4, 2, 2, Color.html("4a4038"))
		"lamphook":
			Px.line(img, Vector2i(6, 2), Vector2i(6, 7), iron[1])
			Px.line(img, Vector2i(6, 8), Vector2i(8, 11), iron[1])
			Px.line(img, Vector2i(9, 11), Vector2i(11, 9), iron[0])
			Px.px(img, 11, 8, iron[0])
			Px.rect(img, 5, 1, 3, 2, iron[2])
			Px.px(img, 7, 11, Color.html("e0a040"))
		"lantern":
			# 河灯：烂了一半的纸灯，竹骨露出来
			Px.rect(img, 4, 4, 8, 9, Color.html("d8b890"))
			Px.rect(img, 4, 4, 8, 3, Color.html("c09060"))
			for x: int in [4, 7, 11]:
				Px.rect(img, x, 3, 1, 11, wood[1])
			Px.rect(img, 5, 9, 2, 3, Color(0, 0, 0, 0))
			Px.rect(img, 9, 11, 2, 2, Color(0, 0, 0, 0))
			Px.rect(img, 3, 13, 10, 1, wood[2])
			Px.rect(img, 6, 1, 4, 2, wood[0])
		"tablet":
			# 祈愿的木牌：竖着的一块，顶上穿着断了的红绳，字只剩几道印子
			Px.rect(img, 5, 4, 7, 11, wood[1])
			Px.rect(img, 6, 3, 5, 1, wood[1])
			Px.rect(img, 5, 4, 1, 11, wood[0])
			Px.rect(img, 11, 4, 1, 11, wood[2])
			Px.rect(img, 5, 14, 7, 1, wood[2])
			Px.px(img, 8, 5, Color(0, 0, 0, 0))
			Px.rect(img, 8, 1, 1, 3, Color.html("b04040"))
			Px.px(img, 9, 1, Color.html("b04040"))
			for y: int in [7, 9, 11]:
				Px.rect(img, 8, y, 1, 1, ink)
			Px.px(img, 7, 12, ink)
		"ticket":
			Px.rect(img, 2, 5, 12, 7, paper)
			Px.rect(img, 2, 5, 3, 7, Color.html("c8a870"))
			Px.rect(img, 4, 5, 1, 7, paper_dk)
			for y: int in [7, 9]:
				Px.rect(img, 7, y, 5, 1, ink)
			Px.px(img, 1, 8, Color(0, 0, 0, 0))
			Px.px(img, 14, 8, Color(0, 0, 0, 0))
		_:
			CropArt.ball(img, 8.0, 9.0, 4.0, 4.0, CropArt.ramp(Color.html("9a9a90")))
	return Px.outline(img)


## 鱼的 16×16 图标：头朝左，按 data/fish.json 里的 shape 选一张手摆的模板，body 是背色、belly 是肚色。
## 模板字符：B 背（深）、M 身（中）、L 身（亮）、W 肚、E 眼、H 眼里的光、F 鳍、S 花纹、G 发光。
const FISH_SHAPES: Dictionary[String, Array] = {
	"carp": [
		"................",
		"................",
		"................",
		".......BB.......",
		"......BBBB......",
		"....BBBBBBB.....",
		"..BBMMMMMMMBB.F.",
		".BEHMMMMMMMMBFFF",
		"MMMGLMMMMMMMMFF.",
		".LLGLLLLMMMMBFF.",
		"..WWWWWFLLLBBFFF",
		"...WWWFWWBB...F.",
		"......F.........",
		"................",
		"................",
		"................",
	],
	"slim": [
		"................",
		"................",
		"................",
		"................",
		"................",
		"......BBB.......",
		"...BBBBBBBBB..F.",
		".BBMMMMMMMMMBFFF",
		"EHGMMMMMMMMMMFF.",
		".LLGLLLLLLLMBFF.",
		"..WWWWFWWWLBBFFF",
		".....F........F.",
		"................",
		"................",
		"................",
		"................",
	],
	"striped": [
		"................",
		"................",
		"................",
		"......BBBBB.....",
		".....BBBBBBB....",
		"....BBSBSBSB....",
		"..BBMSMSMSMBB.F.",
		".BEHMSMSMSMMBFFF",
		"MMMGLSLSLSMMMFF.",
		".LLGLSLSLSLMBFF.",
		"..WWWWWFLLLBBFFF",
		"...WWWFWWBB...F.",
		"......F.........",
		"................",
		"................",
		"................",
	],
	"loach": [
		"................",
		"................",
		"................",
		"................",
		"................",
		"S...............",
		".SBBB...........",
		".BMMMBBB....BBB.",
		"EHMMMMMMBBBBMMMF",
		".WWWWWMMMMMMMMFF",
		".SWWWWWWWWWWMBF.",
		"S..WW........F..",
		"................",
		"................",
		"................",
		"................",
	],
	"cat": [
		"................",
		"................",
		"................",
		"................",
		"S.BBBBB.........",
		".SBBMMMMBBBBB...",
		".BMEMMMMMMMMMBB.",
		"BMMHMMMMMMMMMMMF",
		"BWWWGWWMMMMMMMFF",
		".BWWWWWWWLLMMBF.",
		".SBBWWFWWWLBB.F.",
		"S.....F.........",
		"................",
		"................",
		"................",
		"................",
	],
	"bass": [
		"................",
		"................",
		"................",
		"......B.B.B.....",
		"......BBBBBB....",
		"....BBBBBBBB....",
		"..BBMMMMMMMBB.F.",
		".BEHMMMMMMMMBFFF",
		"MMMGLMMMMMMMMFF.",
		".LLGLLLLMMMMBFF.",
		"..WWWWWFLLLBBFFF",
		"...WWWFWWBB...F.",
		"......F.........",
		"................",
		"................",
		"................",
	],
	"flat": [
		"................",
		"................",
		".......BB.......",
		"......BBBB......",
		".....BBMMBB.....",
		"....BMMMMMMB....",
		"...BMMMMMMMMB...",
		"..BEHMMMMMMMB.F.",
		".MMMGLMMMMMMBFFF",
		".LLLGLLLMMMMBFF.",
		"..LLLLLLLLLBBFF.",
		"...WWWWWWLLB.FFF",
		"....WWWFWWB...F.",
		".....WWFW.......",
		"......F.........",
		"................",
	],
	"ribbon": [
		"................",
		"................",
		"................",
		"BB..............",
		"EHBBF...........",
		"WMMMBBF.........",
		".WMMMMBBF.......",
		"..WWMMMMBBF.....",
		"...WWMMMMMBBF...",
		".....WWMMMMMBBF.",
		".......WWMMMMMB.",
		".........WWMMMMB",
		"...........WWMMB",
		".............WMB",
		"...............B",
		"................",
	],
	"squid": [
		"................",
		".......B........",
		"......BBB.......",
		".....BMMMB......",
		"....BMMMMMB.....",
		"...FMMMLMMMF....",
		"..F.MMMLMMM.F...",
		"....MMMMMMM.....",
		"....MEMMMEM.....",
		"....MHMMMHM.....",
		"....WWWWWWW.....",
		"...W.W.W.W.W....",
		"..W..W.W.W..W...",
		".W...W...W...W..",
		"....W.......W...",
		"................",
	],
	"turtle": [
		"................",
		"................",
		"................",
		"................",
		".....BBBBBB.....",
		"...BBMMSMMSBB...",
		".WWBMSMMMMMSMB..",
		"EWWBMMMSMMSMMB.B",
		".WWBMSMMMMMSMBB.",
		"...BBMMSMMSBB...",
		"..WW.BBBBBB.WW..",
		"..WW........WW..",
		"................",
		"................",
		"................",
		"................",
	],
	"shrimp": [
		"................",
		"................",
		".S..............",
		"..S.........BB..",
		"...S.......BMMB.",
		"....S.....BMMMMB",
		".....BBB.BMMMMB.",
		"....BEMMBMMMMM..",
		"....BHMMMMMMM...",
		".....MWMWMWMM...",
		".....WWWWWW.....",
		"....W.W.W.W.....",
		"................",
		"................",
		"................",
		"................",
	],
	"crab": [
		"................",
		"................",
		"................",
		"..BB......BB....",
		".BMMB....BMMB...",
		".BMM......MMB...",
		"..BM..E..E.MB...",
		"..BBBMMMMMMBBB..",
		".BMMMMMMMMMMMMB.",
		".BMMMMMMMMMMMMB.",
		"..BMMWWWWWWMMB..",
		"..B.BWWWWWWB.B..",
		".B..B.B..B.B..B.",
		"................",
		"................",
		"................",
	],
	"glow": [
		"................",
		"................",
		"................",
		"....G...........",
		"...GSG..........",
		"....G.B.........",
		"......BBBBBBB...",
		"...BBBMMMMMMMB.F",
		"..BEHMMMMMMMMBFF",
		".MMMMMSMMSMMMFFF",
		".LLLLLLLLLMMBFF.",
		"..WWWWWFLLLBBFFF",
		"....WWFWWWB...F.",
		"................",
		"................",
		"................",
	],
}


## 鱼的 16×16 图标。
static func fish(id: StringName) -> Image:
	var def := Database.fish_def(id) if Database.has_fish(id) else null
	var shape := def.shape if def != null else "carp"
	var body := CropArt.ramp(def.body if def != null else Color.html("8a9a7a"))
	var belly: Color = def.belly if def != null else Color.html("d8dcc8")
	var rows: Array = FISH_SHAPES.get(shape, FISH_SHAPES["carp"])
	var dark: Color = body[2]
	var pal := {
		"B": dark,
		"M": body[1],
		"L": body[0],
		"W": belly,
		"E": Color.html("16161e"),
		"H": Color.html("f4f4f0"),
		"F": body[0].lerp(belly, 0.4),
		"S": Color(dark.r * 0.7, dark.g * 0.7, dark.b * 0.75),
		"G": Color.html("fff0a0"),
	}
	if shape == "glow":
		pal["S"] = Color.html("ffffe0")
	elif shape == "shrimp" or shape == "loach" or shape == "cat":
		# 触须、胡须用背色，细一点看得出是须
		pal["S"] = dark
	return Px.outline(Px.ascii(rows, pal))


## 笋：一个尖头的锥形，外面一层一层的壳。
static func _shoot(img: Image, cx: float, top: int, bottom: int, half: float, cols: Array, band: Color, tip: Color) -> void:
	for y in range(top, bottom + 1):
		var k := float(y - top) / float(bottom - top)
		var w := lerpf(0.6, half, sqrt(k))
		for x in range(floori(cx - w), ceili(cx + w)):
			var c: Color = cols[1]
			if x + 0.5 < cx - w * 0.35:
				c = cols[0]
			elif x + 0.5 > cx + w * 0.4:
				c = cols[2]
			# 壳的边缘：左右交替的斜纹
			if (y + (x if x < cx else -x)) % 4 == 0:
				c = band
			Px.px(img, x, y, c)
	Px.px(img, int(cx), top - 1, tip)
	Px.px(img, int(cx) - 1, top, tip)


static func _flower(img: Image, p: Vector2i, cols: Array) -> void:
	Px.px(img, p.x, p.y, Color.html("fff4f6"))
	Px.px(img, p.x - 1, p.y, cols[1])
	Px.px(img, p.x + 1, p.y, cols[1])
	Px.px(img, p.x, p.y - 1, cols[0])
	Px.px(img, p.x, p.y + 1, cols[2])
