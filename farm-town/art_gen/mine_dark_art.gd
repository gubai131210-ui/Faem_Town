class_name MineDarkArt
extends RefCounted
## 无光层和后两个首领用代码画的东西：噬光蛾、影子、忘名者，无名戏班（三张面具各一套），岚之影，
## 井底的灯座，吹过来的一口风，七件饰品的图标。
## 姿势的名字和 MineArt.MONSTER_POSES 一样；都朝右画，朝左由画它的节点翻过来。

const IDS: Array[StringName] = [&"light_moth", &"shadow", &"nameless", &"nameless_troupe", &"lan_shade"]
const EYE := "241c1a"
const EYE_ANGRY := "f0503a"
const GLOW := "ffe07a"
## 戏班三张面具的颜色：脸、脸上的花纹、袍子
const MASKS: Dictionary[StringName, Array] = {
	&"red": ["c83a30", "f8e8d0", "7a2a3a"],
	&"white": ["f0ead8", "3a3440", "8a90a8"],
	&"black": ["2c2830", "e8d8a0", "3c4a44"],
}


static func has(id: StringName) -> bool:
	return IDS.has(id)


static func monster(id: StringName, pose: StringName, skin: StringName = &"") -> Image:
	match id:
		&"light_moth":
			return _moth(pose)
		&"shadow":
			return _shadow(pose)
		&"nameless":
			return _nameless(pose)
		&"nameless_troupe":
			return _troupe(pose, skin if MASKS.has(skin) else &"red")
	return _shade(pose)


static func _angry(pose: StringName) -> bool:
	return pose == &"windup" or pose == &"strike"


## 噬光蛾：灰褐色的毛身子，一对发白的翅膀，翅膀上各一个亮点。平时一扇一扇，扑过来时翅膀张到最大。
static func _moth(pose: StringName) -> Image:
	var img := Px.new_img(16, 16)
	var wing := CropArt.ramp(Color.html("b8b0c8"))
	var body := CropArt.ramp(Color.html("6a5a4c"))
	var up := pose == &"idle_a" or pose == &"strike"
	if pose == &"stun":
		# 掉在地上，翅膀摊着
		Px.rect(img, 2, 12, 5, 2, wing[2])
		Px.rect(img, 9, 12, 5, 2, wing[2])
		CropArt.ball(img, 8.0, 12.0, 1.8, 2.2, body)
		return Px.outline(img)
	var wy := 5.0 if up else 9.0
	var rx := 4.2 if pose == &"strike" else (2.2 if pose == &"windup" else 3.4)
	CropArt.ball(img, 8.0 - rx - 0.5, wy, rx, 3.2, wing)
	CropArt.ball(img, 8.0 + rx + 0.5, wy, rx, 3.2, wing)
	var spot := Color.html(EYE_ANGRY) if _angry(pose) else Color.html(GLOW)
	Px.px(img, int(8.0 - rx - 0.5), int(wy), spot)
	Px.px(img, int(8.0 + rx + 0.5), int(wy), spot)
	CropArt.ball(img, 8.0, 8.0, 1.6, 3.4, body)
	Px.px(img, 7, 3, body[2])
	Px.px(img, 9, 3, body[2])
	Px.px(img, 6, 2, body[2])
	Px.px(img, 10, 2, body[2])
	return Px.outline(img)


## 影子：一个人形的黑影，半透明，只有两只眼是亮的。
static func _shadow(pose: StringName) -> Image:
	var img := Px.new_img(16, 16)
	var dark := Color(0.07, 0.06, 0.12, 0.82)
	var edge := Color(0.16, 0.14, 0.26, 0.6)
	var lean := 2 if pose == &"strike" else (-1 if pose == &"windup" else 0)
	var bob := 1 if pose == &"idle_b" else 0
	if pose == &"stun":
		Px.rect(img, 2, 12, 12, 2, dark)
		Px.rect(img, 3, 11, 10, 1, edge)
		return img
	# 头
	Px.rect(img, 6 + lean, 2 + bob, 4, 4, dark)
	Px.rect(img, 7 + lean, 1 + bob, 2, 1, edge)
	# 身子，越往下越宽，底下拖成一摊
	for y in range(6 + bob, 14):
		var k := (y - 6) / 3
		var shift := lean * (13 - y) / 8
		Px.rect(img, 5 - k + shift, y, 6 + k * 2, 1, dark)
	Px.rect(img, 2, 14, 12, 1, edge)
	# 手
	if _angry(pose):
		Px.rect(img, 11 + lean, 6 + bob, 3, 1, dark)
		Px.rect(img, 11 + lean, 8 + bob, 3, 1, dark)
	var eye := Color.html(EYE_ANGRY) if _angry(pose) else Color.html("e8e8f8")
	Px.px(img, 7 + lean, 3 + bob, eye)
	Px.px(img, 9 + lean, 3 + bob, eye)
	return img


## 忘名者：穿着灰袍子的人，脸上什么都没有，胸口挂着一块空名牌。被灯照着就不动。
static func _nameless(pose: StringName) -> Image:
	var img := Px.new_img(16, 16)
	var robe := CropArt.ramp(Color.html("6c6a7c"))
	var face := Color.html("d8d2c8")
	var bob := 1 if pose == &"idle_b" else 0
	var lean := 2 if pose == &"strike" else 0
	if pose == &"stun":
		CropArt.ball(img, 8.0, 12.0, 5.5, 2.6, robe)
		Px.rect(img, 10, 10, 3, 3, face)
		return Px.outline(img)
	for y in range(6 + bob, 15):
		var k := (y - 6) / 4
		Px.rect(img, 5 - k + lean / 2, y, 6 + k * 2, 1, robe[1] if y < 12 else robe[2])
	Px.rect(img, 5 + lean / 2, 6 + bob, 1, 8 - bob, robe[0])
	# 头和兜帽
	Px.rect(img, 5 + lean, 1 + bob, 6, 5, robe[1])
	Px.rect(img, 5 + lean, 1 + bob, 6, 1, robe[0])
	Px.rect(img, 7 + lean, 2 + bob, 4, 4, face)
	if _angry(pose):
		# 脸上裂开一道
		Px.rect(img, 8 + lean, 4 + bob, 3, 1, Color.html(EYE_ANGRY))
		Px.rect(img, 11 + lean, 7 + bob, 3, 1, robe[1])
		Px.px(img, 14 + lean if lean == 0 else 15, 7 + bob, face)
	# 名牌
	Px.rect(img, 7 + lean / 2, 9 + bob, 3, 2, Color.html("c8b890"))
	return Px.outline(img)


## 无名戏班，32×32：一个穿戏服的人影，脸上是面具。红脸提刀，白脸甩水袖，黑脸空着两只大手。
static func _troupe(pose: StringName, skin: StringName) -> Image:
	var img := Px.new_img(32, 32)
	var cols: Array = MASKS[skin]
	var face := Color.html(cols[0])
	var mark := Color.html(cols[1])
	var robe := CropArt.ramp(Color.html(cols[2]))
	var trim := Color.html("d8b450")
	var bob := 1 if pose == &"idle_b" else 0
	var lean := 0
	var squat := 0
	if pose == &"windup":
		lean = -2
		squat = 2
	elif pose == &"strike":
		lean = 3
	elif pose == &"stun":
		squat = 3
	var top := 4 + bob + squat
	# 袍子：肩窄摆宽
	for y in range(top + 9, 30):
		var k := (y - top - 9) / 3
		var shift := lean * (29 - y) / 20
		Px.rect(img, 11 - k + shift, y, 10 + k * 2, 1, robe[1] if y < 24 else robe[2])
		Px.px(img, 11 - k + shift, y, robe[0])
	Px.rect(img, 9, 29, 14, 1, trim)
	# 腰带
	Px.rect(img, 10 + lean / 2, top + 14, 12, 2, trim)
	# 袖子和手里的东西
	var sy := top + 10
	if skin == &"red":
		Px.rect(img, 20 + lean, sy, 4, 3, robe[1])
		var blade := Color.html("d8dce4")
		if pose == &"windup":
			Px.line(img, Vector2i(23 + lean, sy), Vector2i(27 + lean, sy - 9), blade)
			Px.line(img, Vector2i(24 + lean, sy), Vector2i(28 + lean, sy - 9), Color.html("9aa2b0"))
		else:
			Px.line(img, Vector2i(23 + lean, sy + 1), Vector2i(31, sy + 1 if pose == &"strike" else sy + 6), blade)
			Px.line(img, Vector2i(23 + lean, sy + 2), Vector2i(31, sy + 2 if pose == &"strike" else sy + 7), Color.html("9aa2b0"))
		Px.rect(img, 7 + lean, sy, 4, 5, robe[1])
	elif skin == &"white":
		var sleeve := Color.html("e8ecf4")
		var sleeve_d := Color.html("b8c0d0")
		var drop := 2 if pose == &"strike" else (10 if pose == &"windup" else 7)
		var out := 6 if pose == &"strike" else 2
		Px.rect(img, 20 + lean, sy, 4 + out, 3, sleeve)
		Px.rect(img, 22 + lean + out, sy + 2, 3, drop, sleeve)
		Px.rect(img, 22 + lean + out, sy + 2 + drop - 1, 3, 1, sleeve_d)
		Px.rect(img, 8 + lean - out, sy, 4 + out, 3, sleeve)
		Px.rect(img, 7 + lean - out, sy + 2, 3, drop, sleeve)
		Px.rect(img, 7 + lean - out, sy + 2 + drop - 1, 3, 1, sleeve_d)
	else:
		var hand := Color.html("d8c8a8")
		var raise := -8 if pose == &"windup" else (4 if pose == &"strike" else 0)
		Px.rect(img, 21 + lean, sy + mini(raise, 0), 4, 4 + absi(raise), robe[1])
		Px.rect(img, 7 + lean, sy + mini(raise, 0), 4, 4 + absi(raise), robe[1])
		Px.rect(img, 21 + lean, sy + raise + (0 if raise < 0 else 4) - (4 if raise < 0 else 0), 5, 4, hand)
		Px.rect(img, 6 + lean, sy + raise + (0 if raise < 0 else 4) - (4 if raise < 0 else 0), 5, 4, hand)
	# 头：帽子、面具
	var hx := 11 + lean
	Px.rect(img, hx - 1, top - 2, 12, 3, Color.html("2a2430"))
	Px.rect(img, hx + 3, top - 4, 4, 2, trim)
	Px.px(img, hx - 2, top - 3, Color.html("c83a30"))
	Px.px(img, hx + 11, top - 3, Color.html("c83a30"))
	Px.rect(img, hx, top + 1, 10, 8, face)
	Px.rect(img, hx + 1, top + 9, 8, 1, face)
	# 花纹：眉、眼、嘴
	Px.rect(img, hx + 1, top + 2, 3, 1, mark)
	Px.rect(img, hx + 6, top + 2, 3, 1, mark)
	var eye := Color.html(EYE_ANGRY) if _angry(pose) and skin != &"red" else Color.html(EYE)
	if pose == &"stun":
		Px.rect(img, hx + 2, top + 4, 2, 1, eye)
		Px.rect(img, hx + 6, top + 4, 2, 1, eye)
	else:
		Px.rect(img, hx + 2, top + 3, 2, 2, eye)
		Px.rect(img, hx + 6, top + 3, 2, 2, eye)
		if _angry(pose):
			Px.px(img, hx + 3, top + 4, Color.html(GLOW))
			Px.px(img, hx + 7, top + 4, Color.html(GLOW))
	Px.rect(img, hx + 3, top + 7, 4, 1, mark)
	if skin == &"black":
		Px.rect(img, hx + 4, top + 1, 2, 2, mark)
	elif skin == &"white":
		Px.px(img, hx + 1, top + 6, Color.html("c83a30"))
		Px.px(img, hx + 8, top + 6, Color.html("c83a30"))
	return Px.outline(img)


## 岚之影，32×32：一个半透明的、青白色的女人的影子，下半截散成雾，手里提着一盏不亮的灯。
## 吹风之前鼓起腮，吹的时候嘴张着。
static func _shade(pose: StringName) -> Image:
	var img := Px.new_img(32, 32)
	var body := Color(0.5, 0.88, 0.85, 0.62)
	var light := Color(0.8, 0.98, 0.96, 0.75)
	var deep := Color(0.3, 0.6, 0.66, 0.45)
	var bob := 1 if pose == &"idle_b" else 0
	var top := 3 + bob
	# 头发披下来
	Px.rect(img, 11, top, 10, 4, deep)
	Px.rect(img, 10, top + 3, 3, 9, deep)
	Px.rect(img, 19, top + 3, 3, 7, deep)
	# 脸
	var puff := 1 if pose == &"windup" else 0
	Px.rect(img, 13 - puff, top + 2, 7 + puff * 2, 7, light)
	Px.px(img, 15, top + 5, Color(0.1, 0.2, 0.25, 0.9))
	Px.px(img, 18, top + 5, Color(0.1, 0.2, 0.25, 0.9))
	if pose == &"strike":
		Px.rect(img, 18, top + 7, 2, 2, Color(0.1, 0.2, 0.25, 0.9))
	elif pose == &"windup":
		Px.px(img, 19, top + 7, Color(0.1, 0.2, 0.25, 0.9))
	# 身子：往下散开，越往下越淡
	for y in range(top + 9, 30):
		var k := (y - top - 9) / 3
		var fade := 1.0 - maxf(0.0, (y - 20) / 12.0)
		var c := Color(body.r, body.g, body.b, body.a * fade)
		var wob := 1 if (y + bob) % 4 < 2 and y > 22 else 0
		Px.rect(img, 12 - k + wob, y, 8 + k * 2, 1, c)
		Px.px(img, 12 - k + wob, y, Color(light.r, light.g, light.b, light.a * fade))
	# 提灯的手和灯
	Px.rect(img, 20, top + 11, 5, 2, body)
	Px.line(img, Vector2i(25, top + 12), Vector2i(25, top + 15), deep)
	Px.rect(img, 23, top + 15, 5, 6, Color(0.2, 0.3, 0.36, 0.85))
	Px.rect(img, 24, top + 16, 3, 4, Color(0.42, 0.56, 0.6, 0.8))
	if pose == &"strike":
		Px.px(img, 25, top + 18, Color.html(GLOW))
	return img


## 井底的灯座，16×24：一截石台，上面一个放灯的铁架。lit 为真是灯已经放上去、点着了。
## 石台正面的龛里嵌着最初的那盏矿灯：灯座亮了才看得见它（黑的），first_lit 为真是它也点着了。
static func altar(lit: bool, first_lit: bool = false) -> Image:
	var img := Px.new_img(16, 24)
	var stone := CropArt.ramp(Color.html("7a7888"))
	Px.rect(img, 3, 14, 10, 9, stone[1])
	Px.rect(img, 3, 14, 10, 1, stone[0])
	Px.rect(img, 3, 21, 10, 2, stone[2])
	Px.rect(img, 2, 12, 12, 2, stone[0])
	Px.rect(img, 2, 13, 12, 1, stone[1])
	Px.rect(img, 6, 17, 4, 3, stone[2])
	var iron := Color.html("3a3840")
	Px.rect(img, 5, 11, 6, 1, iron)
	Px.px(img, 5, 10, iron)
	Px.px(img, 10, 10, iron)
	if lit:
		Px.rect(img, 6, 6, 4, 5, Color.html("c09a3e"))
		Px.rect(img, 7, 7, 2, 3, Color.html("fff2b0"))
		Px.rect(img, 6, 5, 4, 1, iron)
		Px.px(img, 7, 4, iron)
		Px.px(img, 8, 4, iron)
		Px.px(img, 7, 2, Color.html("f0a040"))
		Px.px(img, 8, 3, Color.html("ffe07a"))
		# 龛里的旧矿灯：一个铁提梁，底下一截灯身
		Px.rect(img, 5, 16, 6, 5, Color.html("2a2830"))
		Px.rect(img, 7, 16, 2, 1, iron)
		Px.rect(img, 6, 17, 4, 3, Color.html("fff2b0") if first_lit else Color.html("4a4e58"))
		Px.rect(img, 6, 20, 4, 1, Color.html("8a6a3a") if first_lit else iron)
		if first_lit:
			Px.rect(img, 7, 18, 2, 1, Color.html("ffffff"))
		else:
			Px.px(img, 6, 17, Color.html("6a7078"))
	return Px.outline(img)


## 吹过来的一口风，8×8：一道发青的弯。
static func gust() -> Image:
	var img := Px.new_img(8, 8)
	var c := Color(0.75, 0.96, 0.94, 0.9)
	var d := Color(0.45, 0.8, 0.8, 0.7)
	Px.rect(img, 2, 1, 3, 1, c)
	Px.rect(img, 5, 2, 1, 1, c)
	Px.rect(img, 6, 3, 1, 2, c)
	Px.rect(img, 5, 5, 1, 1, c)
	Px.rect(img, 2, 6, 3, 1, c)
	Px.rect(img, 1, 3, 4, 1, d)
	Px.rect(img, 2, 4, 3, 1, d)
	return img


## 饰品的图标，16×16。
static func accessory(id: StringName) -> Image:
	var img := Px.new_img(16, 16)
	var silver := CropArt.ramp(Color.html("b8c0cc"))
	var cord := Color.html("8a3030")
	match id:
		&"silver_guard":
			# 一只护腕
			Px.rect(img, 4, 5, 8, 7, silver[1])
			Px.rect(img, 4, 5, 8, 1, silver[0])
			Px.rect(img, 4, 11, 8, 1, silver[2])
			Px.rect(img, 3, 6, 1, 5, silver[2])
			Px.rect(img, 12, 6, 1, 5, silver[2])
			Px.rect(img, 6, 7, 4, 3, silver[0])
			Px.px(img, 7, 8, Color.html("5a6270"))
			Px.px(img, 8, 8, Color.html("5a6270"))
		&"leech_tooth":
			# 红绳拴着一颗弯牙
			Px.line(img, Vector2i(4, 2), Vector2i(8, 6), cord)
			Px.line(img, Vector2i(12, 2), Vector2i(8, 6), cord)
			Px.rect(img, 7, 6, 3, 3, Color.html("f0ead8"))
			Px.rect(img, 7, 9, 2, 3, Color.html("f0ead8"))
			Px.px(img, 7, 12, Color.html("d8d0b8"))
			Px.px(img, 6, 13, Color.html("d8d0b8"))
			Px.px(img, 9, 7, Color.html("c8c0a8"))
		&"oilcloth_wraps":
			# 一卷油布绑腿
			var cloth := CropArt.ramp(Color.html("8a7a3c"))
			Px.rect(img, 5, 3, 6, 11, cloth[1])
			Px.rect(img, 5, 3, 1, 11, cloth[0])
			Px.rect(img, 10, 3, 1, 11, cloth[2])
			for y: int in [5, 8, 11]:
				Px.line(img, Vector2i(5, y + 1), Vector2i(10, y - 1), cloth[2])
			Px.rect(img, 11, 12, 3, 1, cloth[1])
			Px.px(img, 13, 13, cloth[2])
		&"soft_soles":
			# 一只千层底布鞋
			Px.rect(img, 2, 8, 11, 3, Color.html("2c2a34"))
			Px.rect(img, 3, 6, 6, 2, Color.html("2c2a34"))
			Px.rect(img, 4, 6, 4, 1, Color.html("46424e"))
			Px.rect(img, 11, 9, 3, 2, Color.html("2c2a34"))
			Px.rect(img, 2, 11, 12, 2, Color.html("f0ead8"))
			Px.rect(img, 2, 12, 12, 1, Color.html("c8c0a8"))
			for x: int in [4, 7, 10]:
				Px.px(img, x, 11, Color.html("a89c80"))
		&"lan_wick":
			# 一截灯芯，顶上嵌着一粒岚晶
			Px.line(img, Vector2i(5, 13), Vector2i(9, 6), Color.html("e8dcb8"))
			Px.line(img, Vector2i(6, 13), Vector2i(10, 6), Color.html("c9b88e"))
			Px.rect(img, 8, 3, 4, 4, Color.html("7fe0d8"))
			Px.px(img, 9, 4, Color.html("d8fff8"))
			Px.px(img, 11, 6, Color.html("4aa8a0"))
			Px.px(img, 10, 2, Color.html("7fe0d8"))
		&"mask_shard":
			# 半张红脸面具
			Px.rect(img, 4, 3, 6, 10, Color.html("c83a30"))
			Px.rect(img, 5, 13, 4, 1, Color.html("c83a30"))
			Px.rect(img, 5, 4, 3, 1, Color.html("f8e8d0"))
			Px.rect(img, 5, 6, 3, 2, Color.html(EYE))
			Px.rect(img, 6, 10, 3, 1, Color.html("f8e8d0"))
			# 断口
			Px.px(img, 9, 4, Color(0, 0, 0, 0))
			Px.px(img, 9, 7, Color(0, 0, 0, 0))
			Px.px(img, 9, 8, Color(0, 0, 0, 0))
			Px.px(img, 9, 11, Color(0, 0, 0, 0))
			Px.px(img, 10, 5, Color.html("c83a30"))
			Px.px(img, 10, 9, Color.html("c83a30"))
		_:
			# 岚的灯穗：一个结，底下一把青色的穗子
			Px.line(img, Vector2i(8, 1), Vector2i(8, 4), cord)
			Px.rect(img, 6, 4, 5, 3, Color.html("d8b450"))
			Px.px(img, 8, 5, Color.html("fff2b0"))
			for x in range(5, 12):
				Px.rect(img, x, 7, 1, 6 if x % 2 == 0 else 7, Color.html("7fe0d8") if x % 2 == 0 else Color.html("4aa8a0"))
	return Px.outline(img)
