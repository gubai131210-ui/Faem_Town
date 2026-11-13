class_name TreeArt
extends RefCounted
## 果树的画法：树苗、小树、长成三个阶段，随季节变色，挂果和落果都画出来。
## 图是 36×48，树根在 (18, 45)。

const W := 36
const H := 48
const AX := 18
const AY := 45
## 长成的树上挂果的位置，按结果的先后
const FRUIT_SPOTS: Array[Vector2i] = [Vector2i(11, 17), Vector2i(24, 14), Vector2i(18, 23)]
## 落在地上的果子的位置
const FALLEN_SPOTS: Array[Vector2i] = [Vector2i(9, 45), Vector2i(27, 45), Vector2i(23, 46)]


## stage：0 树苗，1 小树，2 长成。season：0 春 … 3 冬。item 是现在结着的东西，fruit、fallen 是树上和地上的个数。
static func tree(tree_id: StringName, stage: int, season: int, item: StringName = &"",
		fruit: int = 0, fallen: int = 0) -> Image:
	var img := Px.new_img(W, H)
	var def := Database.tree(tree_id)
	var bark := [Color.html("a06a3c"), Color.html("84532d"), Color.html("653d20")]
	var base := _col(str(def.art.get("leaf", "5fa84a")))
	var bare := false
	if not def.evergreen:
		if season == 2:
			base = base.lerp(Color.html("e89a34"), 0.82)
		elif season == 3:
			bare = true
	elif season == 3:
		base = base.darkened(0.1)
	var leaf := CropArt.ramp(base)
	var dark := [leaf[1], leaf[2], (leaf[2] as Color).darkened(0.22)]
	var info := def.yield_of(item)
	var fruit_cols := CropArt.ramp(_col(str(info.get("color", "f2b23e"))))
	var is_flower := bool(info.get("flower", false))

	if stage <= 0:
		Px.line(img, Vector2i(AX, AY), Vector2i(AX, 36), bark[1])
		Px.px(img, AX - 1, AY, bark[2])
		Px.px(img, AX + 1, AY, bark[2])
		if bare:
			Px.line(img, Vector2i(AX, 39), Vector2i(AX - 3, 36), bark[1])
			Px.line(img, Vector2i(AX, 38), Vector2i(AX + 3, 35), bark[1])
		else:
			CropArt.ball(img, 15.0, 37.0, 2.6, 2.0, leaf)
			CropArt.ball(img, 21.5, 35.5, 2.6, 2.0, leaf)
			CropArt.ball(img, 18.0, 33.0, 2.6, 2.4, leaf)
		return Px.outline(img)

	if stage == 1:
		Px.rect(img, AX - 1, 31, 2, 15, bark[1])
		Px.rect(img, AX, 31, 1, 15, bark[2])
		Px.px(img, AX - 2, AY, bark[1])
		Px.px(img, AX + 1, AY, bark[2])
		if bare:
			var rng := RandomNumberGenerator.new()
			rng.seed = 41
			var tips: Array = []
			PixelArt._branches(img, rng, Vector2(AX, 32), 0.0, 6.0, 2.0, 2, bark, tips)
		else:
			CropArt.ball(img, 18.0, 27.5, 8.0, 5.0, dark)
			CropArt.ball(img, 13.5, 26.0, 5.0, 4.6, leaf)
			CropArt.ball(img, 22.5, 25.0, 5.0, 4.6, leaf)
			CropArt.ball(img, 18.0, 21.5, 6.0, 5.4, leaf)
		return Px.outline(img)

	# 长成：树干
	for y in range(27, AY + 1):
		var half := 2 if y < 42 else (3 if y < 44 else 4)
		for x in range(AX - half, AX + half):
			var c: Color = bark[1]
			if x == AX - half:
				c = bark[0]
			if x >= AX + half - 1 or y < 31:
				c = bark[2]
			img.set_pixel(x, y, c)
	if bare:
		var rng := RandomNumberGenerator.new()
		rng.seed = 97
		var tips: Array = []
		PixelArt._branches(img, rng, Vector2(AX, 30), 0.0, 9.0, 3.0, 3, bark, tips)
		PixelArt._snow_on(img, rng)
		return Px.outline(img)
	# 树冠：先一团暗的打底，再叠亮的叶簇
	CropArt.ball(img, 18.0, 17.0, 13.0, 11.0, dark)
	CropArt.ball(img, 18.0, 26.0, 9.0, 4.0, dark)
	CropArt.ball(img, 11.5, 13.0, 6.0, 5.4, leaf)
	CropArt.ball(img, 23.5, 11.0, 6.0, 5.4, leaf)
	CropArt.ball(img, 8.5, 21.0, 5.4, 4.8, leaf)
	CropArt.ball(img, 18.0, 19.0, 6.4, 5.6, leaf)
	CropArt.ball(img, 27.5, 20.0, 5.2, 4.8, leaf)
	for i in mini(fruit, FRUIT_SPOTS.size()):
		var p := FRUIT_SPOTS[i]
		if is_flower:
			# 花：一处开一小片
			for o: Vector2i in [Vector2i(0, 0), Vector2i(4, -2), Vector2i(-3, 3), Vector2i(3, 4), Vector2i(-5, -2)]:
				_blossom(img, p + o, fruit_cols)
		else:
			_fruit(img, p, fruit_cols)
	for i in mini(fallen, FALLEN_SPOTS.size()):
		var p := FALLEN_SPOTS[i]
		if is_flower:
			_blossom(img, p, fruit_cols)
		else:
			CropArt.ball(img, p.x + 0.5, p.y + 0.0, 1.6, 1.6, fruit_cols)
	return Px.outline(img)


## 树苗的 16×16 图标：带土球的小苗，叶子用这种树的颜色，旁边一点果色。
static func sapling_icon(tree_id: StringName) -> Image:
	var img := Px.new_img(16, 16)
	var def := Database.tree(tree_id)
	var leaf := CropArt.ramp(_col(str(def.art.get("leaf", "5fa84a"))))
	var first: Dictionary = def.yields[def.yields.size() - 1] if not def.yields.is_empty() else {}
	var fruit_cols := CropArt.ramp(_col(str(first.get("color", "f2b23e"))))
	CropArt.ball(img, 8.0, 12.5, 3.4, 2.2, CropArt.ramp(Color.html("9a6a40")))
	Px.line(img, Vector2i(8, 11), Vector2i(8, 5), Color.html("84532d"))
	CropArt.ball(img, 5.5, 7.5, 2.4, 1.8, leaf)
	CropArt.ball(img, 10.5, 6.0, 2.4, 1.8, leaf)
	CropArt.ball(img, 8.0, 3.5, 2.2, 2.0, leaf)
	Px.px(img, 11, 9, fruit_cols[1])
	Px.px(img, 12, 9, fruit_cols[2])
	Px.px(img, 11, 8, fruit_cols[0])
	return Px.outline(img)


static func _fruit(img: Image, p: Vector2i, cols: Array) -> void:
	var rim: Color = cols[2]
	rim = rim.darkened(0.35)
	CropArt.ball(img, p.x + 0.5, p.y + 0.5, 2.6, 2.6, [rim, rim, rim])
	CropArt.ball(img, p.x + 0.5, p.y + 0.5, 1.7, 1.7, cols)


static func _blossom(img: Image, p: Vector2i, cols: Array) -> void:
	Px.px(img, p.x, p.y, Color.html("fff4f6"))
	Px.px(img, p.x - 1, p.y, cols[1])
	Px.px(img, p.x + 1, p.y, cols[1])
	Px.px(img, p.x, p.y - 1, cols[0])
	Px.px(img, p.x, p.y + 1, cols[2])


static func _col(hex: String) -> Color:
	return Color.html(hex) if Color.html_is_valid(hex) else Color.html("5fa84a")
