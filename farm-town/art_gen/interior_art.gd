class_name InteriorArt
extends RefCounted
## 铺子里间的家具和墙上的东西，代码画（决策 161）：药柜、炉膛、铁砧、工作台、木料架……
## 名字后面可以带一个数，比如 "counter:5" 是五格宽的柜台。锚点在底边正中。
## 颜色和 RoomArt、Blender 家具是一套木色、铁色。

const TS := 16
## 议事厅墙上那张大图：左上角相对图片，三列两行，每格的大小
const BIG_MAP_W := 160
const BIG_MAP_H := 26
const BIG_MAP_CELLS: Array[Rect2i] = [
	Rect2i(4, 3, 50, 10), Rect2i(56, 3, 50, 10), Rect2i(108, 3, 50, 10),
	Rect2i(4, 14, 50, 10), Rect2i(56, 14, 50, 10), Rect2i(108, 14, 50, 10),
]

const KNOWN: Array[String] = [
	"counter", "long_table", "desk", "drawers", "herb_bundles", "jar_shelf", "mortar", "scale",
	"herb_tray", "forge", "anvil", "trough", "bellows", "tool_rack", "ore_bin", "coal_bin", "grindstone",
	"workbench", "lumber_rack", "plank_pile", "saw_horse", "oar_rack", "rope_coil", "skiff_frame",
	"net_wall", "teapot_shelf", "tea_tins", "stage", "big_map", "runner", "lantern", "flag",
	"bucket", "sacks", "tea_tray_stack", "pigeon_holes", "drawing_board",
]

static var _images: Dictionary = {}
static var _textures: Dictionary = {}


static func has(name: String) -> bool:
	return KNOWN.has(name.get_slice(":", 0))


static func image(name: String) -> Image:
	if not _images.has(name):
		_images[name] = _make(name)
	return _images[name]


static func texture(name: String) -> Texture2D:
	if not _textures.has(name):
		_textures[name] = Px.tex(image(name))
	return _textures[name]


static func anchor(name: String) -> Vector2:
	var img := image(name)
	return Vector2(img.get_width() / 2, img.get_height() - 1)


## 锚点落在 pos。
static func sprite(name: String, pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = texture(name)
	s.centered = false
	s.offset = -anchor(name)
	s.position = pos
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return s


static func _f(img: Image, x: int, y: int, w: int, h: int, hex: String) -> void:
	Px.rect(img, x, y, w, h, Color.html(hex))


static func _make(name: String) -> Image:
	var parts := name.split(":")
	var k := parts[0]
	var a := int(parts[1]) if parts.size() > 1 else 1
	var b := int(parts[2]) if parts.size() > 2 else 1
	var c := int(parts[3]) if parts.size() > 3 else 0
	match k:
		"counter": return _counter(a)
		"long_table": return _long_table(a, false)
		"desk": return _long_table(a, true)
		"drawers": return _drawers(a)
		"herb_bundles": return _herb_bundles()
		"jar_shelf": return _jar_shelf(a)
		"mortar": return _mortar()
		"scale": return _scale()
		"herb_tray": return _herb_tray()
		"forge": return _forge()
		"anvil": return _anvil()
		"trough": return _trough()
		"bellows": return _bellows()
		"tool_rack": return _tool_rack(a)
		"ore_bin": return _bin(false)
		"coal_bin": return _bin(true)
		"grindstone": return _grindstone()
		"workbench": return _workbench(a)
		"lumber_rack": return _lumber_rack()
		"plank_pile": return _plank_pile()
		"saw_horse": return _saw_horse()
		"oar_rack": return _oar_rack(a)
		"rope_coil": return _rope_coil()
		"skiff_frame": return _skiff_frame()
		"net_wall": return _net_wall()
		"teapot_shelf": return _teapot_shelf(a)
		"tea_tins": return _tea_tins(a)
		"stage": return _stage(a, b)
		"big_map": return _big_map()
		"runner": return _runner(a, b, c)
		"lantern": return _lantern()
		"flag": return _flag()
		"bucket": return _bucket()
		"sacks": return _sacks()
		"tea_tray_stack": return _tray_stack()
		"pigeon_holes": return _pigeon_holes(a)
		"drawing_board": return _drawing_board()
	push_error("没有这个室内物件：%s" % name)
	return Px.new_img(4, 4)


# ---------------------------------------------------------------- 通用

static func _counter(n: int) -> Image:
	var w := n * TS
	var img := Px.new_img(w, 28)
	_f(img, 1, 2, w - 2, 7, "d8a468")
	_f(img, 1, 2, w - 2, 1, "ecc488")
	_f(img, 1, 9, w - 2, 17, "a06a40")
	for x in range(1, w - 1, 16):
		_f(img, x + 2, 11, 12, 13, "8a5a36")
		_f(img, x + 3, 12, 10, 11, "9a6a40")
	_f(img, 1, 26, w - 2, 1, "4a2c18")
	return Px.outline(img)


static func _long_table(n: int, papers: bool) -> Image:
	var w := n * TS
	var img := Px.new_img(w, 26)
	_f(img, 1, 3, w - 2, 9, "c08a52")
	_f(img, 1, 3, w - 2, 1, "dcaa72")
	_f(img, 1, 11, w - 2, 2, "8a5a36")
	for x in [3, w - 6]:
		_f(img, x, 13, 3, 12, "8a5a36")
		_f(img, x, 13, 1, 12, "a06a40")
	_f(img, 4, 18, w - 8, 2, "6e4526")
	if papers:
		_f(img, 8, 4, 10, 6, "f4f0e4")
		_f(img, 9, 5, 8, 1, "b8b4a8")
		_f(img, 9, 7, 6, 1, "b8b4a8")
		_f(img, w - 22, 5, 8, 5, "ecd9a0")
		_f(img, w - 12, 5, 4, 4, "a83e36")
		_f(img, w - 11, 4, 2, 1, "6a2a24")
	return Px.outline(img)


static func _drawers(n: int) -> Image:
	var w := n * TS
	var img := Px.new_img(w, 30)
	_f(img, 1, 1, w - 2, 28, "6e4526")
	_f(img, 2, 2, w - 4, 26, "8a5a36")
	var cols := n * 2
	for r in 4:
		for c in cols:
			var x := 3 + c * 8
			var y := 3 + r * 6
			_f(img, x, y, 7, 5, "a06a40")
			_f(img, x, y, 7, 1, "c08a52")
			_f(img, x + 3, y + 2, 1, 1, "f7dc80")
			if Px.h2(c + n, r) % 5 == 0:
				_f(img, x + 1, y + 3, 3, 1, "ecd9a0")
	return Px.outline(img)


static func _herb_bundles() -> Image:
	var img := Px.new_img(30, 24)
	_f(img, 1, 1, 28, 1, "4a2c18")
	var greens := ["6aa04a", "c8b84a", "5a8a3c"]
	for i in 3:
		var x := 4 + i * 9
		_f(img, x + 2, 2, 1, 4, "a89048")
		_f(img, x, 6, 5, 4, greens[i])
		_f(img, x + 1, 10, 3, 6, greens[(i + 1) % 3])
		_f(img, x + 2, 16, 1, 3, greens[i])
		_f(img, x, 6, 5, 1, "a89048")
	return Px.outline(img)


static func _jar_shelf(n: int) -> Image:
	var w := n * TS
	var img := Px.new_img(w, 30)
	_f(img, 1, 13, w - 2, 2, "8a5a36")
	_f(img, 1, 27, w - 2, 2, "8a5a36")
	_f(img, 1, 1, 1, 28, "6e4526")
	_f(img, w - 2, 1, 1, 28, "6e4526")
	var kinds := [["8fc8a8", "5a9a78"], ["f4f0e4", "c8c4b8"], ["b86a48", "8a4a30"], ["6a8ab8", "4a6a98"]]
	for row in 2:
		var base := 13 + row * 14
		var x := 3
		while x < w - 8:
			var kind: Array = kinds[Px.h2(x + n, row) % kinds.size()]
			var jw := 6 + Px.h2(x, row + 3) % 3
			var jh := 8 + Px.h2(x, row + 7) % 3
			_f(img, x, base - jh, jw, jh, kind[0])
			_f(img, x, base - jh, 1, jh, kind[1])
			_f(img, x + 1, base - jh - 1, jw - 2, 1, "4a2c18")
			_f(img, x + 1, base - jh + 2, jw - 2, 2, "ecd9a0")
			x += jw + 2
	return Px.outline(img)


static func _mortar() -> Image:
	var img := Px.new_img(16, 14)
	_f(img, 3, 6, 10, 6, "a8aaa8")
	_f(img, 2, 5, 12, 2, "c8ccd0")
	_f(img, 4, 7, 8, 1, "6a6e70")
	_f(img, 5, 11, 6, 1, "7c8182")
	_f(img, 9, 0, 2, 7, "c08a52")
	_f(img, 8, 0, 4, 2, "dcaa72")
	return Px.outline(img)


static func _scale() -> Image:
	var img := Px.new_img(18, 18)
	_f(img, 8, 2, 2, 14, "8a5a36")
	_f(img, 2, 3, 14, 1, "6e4526")
	_f(img, 2, 4, 1, 4, "6e4526")
	_f(img, 15, 4, 1, 4, "6e4526")
	_f(img, 1, 8, 4, 2, "d8c070")
	_f(img, 13, 8, 4, 2, "d8c070")
	_f(img, 5, 15, 8, 2, "6e4526")
	return Px.outline(img)


static func _herb_tray() -> Image:
	var img := Px.new_img(28, 14)
	_f(img, 2, 3, 24, 9, "d8c27a")
	_f(img, 1, 5, 26, 5, "d8c27a")
	_f(img, 3, 4, 22, 7, "efd890")
	var greens := ["6aa04a", "c8b84a", "8a7a40", "5a8a3c"]
	for i in 14:
		var x := 4 + Px.h2(i, 1) % 19
		var y := 5 + Px.h2(i, 2) % 5
		_f(img, x, y, 2, 1, greens[Px.h2(i, 3) % greens.size()])
	return Px.outline(img)


static func _stage(cols: int, rows: int) -> Image:
	var w := cols * TS
	var h := rows * TS
	var img := Px.new_img(w, h)
	_f(img, 0, 0, w, h - 6, "9a4a3a")
	for y in range(2, h - 6, 5):
		_f(img, 0, y, w, 1, "7e3a2e")
	_f(img, 0, 0, w, 1, "c8745a")
	_f(img, 0, h - 6, w, 6, "5a2a24")
	_f(img, 0, h - 6, w, 1, "d8b060")
	for x in range(2, w - 2, 12):
		_f(img, x, h - 5, 1, 4, "4a2c18")
	return img


static func _runner(cols: int, rows: int, green: int) -> Image:
	var w := cols * TS
	var h := rows * TS
	var img := Px.new_img(w, h)
	var tone := ["8a3a34", "a8483e"] if green == 0 else ["3f6a46", "5a8a5a"]
	_f(img, 0, 0, w, h, tone[0])
	_f(img, 2, 2, w - 4, h - 4, tone[1])
	_f(img, 4, 4, w - 8, h - 8, tone[0])
	for x in range(8, w - 8, 12):
		_f(img, x, h / 2 - 1, 4, 3, "d8b060")
		_f(img, x + 1, h / 2 - 2, 2, 5, "d8b060")
	_f(img, 0, 0, w, 1, "d8b060")
	_f(img, 0, h - 1, w, 1, "d8b060")
	return img


static func _lantern() -> Image:
	var img := Px.new_img(12, 20)
	_f(img, 5, 0, 2, 4, "4a2c18")
	_f(img, 2, 4, 8, 11, "c8463a")
	_f(img, 3, 5, 6, 9, "e8683e")
	_f(img, 2, 4, 8, 1, "d8b060")
	_f(img, 2, 14, 8, 1, "d8b060")
	_f(img, 5, 15, 2, 4, "d8b060")
	return Px.outline(img)


static func _flag() -> Image:
	var img := Px.new_img(16, 30)
	_f(img, 0, 0, 16, 2, "6e4526")
	_f(img, 2, 2, 12, 24, "a83e36")
	_f(img, 2, 2, 1, 24, "c8584a")
	_f(img, 4, 8, 8, 2, "f7dc80")
	_f(img, 7, 6, 2, 12, "f7dc80")
	_f(img, 5, 20, 6, 2, "f7dc80")
	for x in [2, 6, 10]:
		_f(img, x, 26, 4, 3, "a83e36")
	return Px.outline(img)


static func _bucket() -> Image:
	var img := Px.new_img(12, 14)
	_f(img, 2, 4, 8, 9, "a06a40")
	_f(img, 2, 4, 8, 1, "3d5a8a")
	_f(img, 2, 5, 1, 8, "c08a52")
	_f(img, 2, 8, 8, 1, "6a6e70")
	_f(img, 2, 11, 8, 1, "6a6e70")
	_f(img, 3, 1, 1, 3, "6a6e70")
	_f(img, 8, 1, 1, 3, "6a6e70")
	_f(img, 3, 1, 6, 1, "6a6e70")
	return Px.outline(img)


static func _sacks() -> Image:
	var img := Px.new_img(28, 20)
	_f(img, 2, 8, 12, 11, "d8c498")
	_f(img, 3, 6, 10, 3, "d8c498")
	_f(img, 4, 7, 8, 1, "a89048")
	_f(img, 12, 5, 12, 14, "c8b488")
	_f(img, 13, 3, 10, 3, "c8b488")
	_f(img, 14, 4, 8, 1, "a89048")
	_f(img, 3, 12, 8, 1, "b8a478")
	_f(img, 14, 11, 8, 1, "b8a478")
	return Px.outline(img)


# ---------------------------------------------------------------- 药铺

static func _tray_stack() -> Image:
	var img := Px.new_img(24, 26)
	for i in 4:
		var y := 4 + i * 5
		_f(img, 2, y, 20, 4, "d8c27a")
		_f(img, 2, y, 20, 1, "efd890")
		_f(img, 3, y + 3, 18, 1, "a89048")
	_f(img, 4, 24, 3, 1, "6e4526")
	_f(img, 17, 24, 3, 1, "6e4526")
	return Px.outline(img)


static func _pigeon_holes(n: int) -> Image:
	var w := n * TS
	var img := Px.new_img(w, 30)
	_f(img, 1, 1, w - 2, 28, "6e4526")
	for r in 3:
		for c in n * 2:
			var x := 3 + c * 8
			var y := 3 + r * 9
			_f(img, x, y, 7, 8, "3a2414")
			_f(img, x, y + 7, 7, 1, "8a5a36")
			var h := Px.h2(c + 7, r) % 4
			if h < 3:
				_f(img, x + 1, y + 2, 5, 5, "ecd9a0")
				_f(img, x + 1, y + 2 + h % 2, 5, 1, "c9b47c")
	return Px.outline(img)


# ---------------------------------------------------------------- 铁匠铺

static func _forge() -> Image:
	var img := Px.new_img(44, 50)
	# 烟罩和烟囱
	_f(img, 17, 1, 10, 12, "6a6e70")
	_f(img, 17, 1, 2, 12, "8a8f90")
	_f(img, 12, 12, 20, 5, "7c8182")
	_f(img, 8, 16, 28, 5, "6a6e70")
	_f(img, 8, 16, 28, 1, "969b9c")
	# 炉身
	_f(img, 4, 21, 36, 27, "7c8182")
	for y in range(21, 48, 6):
		_f(img, 4, y + 5, 36, 1, "5a5e60")
		for x in range(4 + (y / 6 % 2) * 6, 40, 12):
			_f(img, x, y, 1, 6, "5a5e60")
	_f(img, 4, 21, 36, 2, "969b9c")
	# 炉口
	_f(img, 12, 28, 20, 14, "2a1810")
	_f(img, 14, 32, 16, 10, "c8463a")
	_f(img, 16, 34, 12, 8, "f08a30")
	_f(img, 19, 37, 6, 5, "f7dc80")
	_f(img, 21, 30, 2, 3, "f08a30")
	_f(img, 10, 42, 24, 3, "4a4e50")
	_f(img, 4, 46, 36, 2, "4a4e50")
	return Px.outline(img)


static func _anvil() -> Image:
	var img := Px.new_img(26, 22)
	_f(img, 6, 13, 14, 8, "8a5a36")
	_f(img, 6, 13, 14, 1, "a06a40")
	_f(img, 7, 20, 12, 1, "4a2c18")
	_f(img, 4, 6, 18, 6, "7a8088")
	_f(img, 4, 6, 18, 2, "a8aeb4")
	_f(img, 0, 6, 5, 3, "7a8088")
	_f(img, 1, 6, 3, 1, "a8aeb4")
	_f(img, 9, 11, 8, 3, "5a6068")
	return Px.outline(img)


static func _trough() -> Image:
	var img := Px.new_img(32, 16)
	_f(img, 1, 3, 30, 12, "8a5a36")
	_f(img, 1, 3, 30, 2, "a06a40")
	_f(img, 3, 5, 26, 6, "3d5a8a")
	_f(img, 3, 5, 26, 2, "6a8ab8")
	_f(img, 6, 7, 5, 1, "a8c8e8")
	_f(img, 18, 8, 6, 1, "a8c8e8")
	_f(img, 2, 12, 28, 1, "6e4526")
	return Px.outline(img)


static func _bellows() -> Image:
	var img := Px.new_img(30, 22)
	_f(img, 2, 4, 14, 14, "8a5a36")
	_f(img, 4, 6, 10, 10, "c8b488")
	_f(img, 4, 6, 10, 1, "a89048")
	_f(img, 4, 10, 10, 1, "a89048")
	_f(img, 4, 14, 10, 1, "a89048")
	_f(img, 16, 10, 12, 3, "4a4e50")
	_f(img, 26, 9, 3, 5, "2a1810")
	_f(img, 0, 1, 2, 8, "6e4526")
	_f(img, 0, 1, 6, 2, "6e4526")
	return Px.outline(img)


static func _tool_rack(n: int) -> Image:
	var w := n * TS
	var img := Px.new_img(w, 28)
	_f(img, 1, 2, w - 2, 24, "4a3a30")
	_f(img, 1, 2, w - 2, 2, "6e4526")
	var x := 4
	var i := 0
	while x < w - 8:
		match i % 3:
			0:
				# 钳子
				_f(img, x, 6, 1, 14, "8a9098")
				_f(img, x + 3, 6, 1, 14, "8a9098")
				_f(img, x + 1, 19, 2, 3, "6a6e70")
				_f(img, x, 5, 4, 1, "5a5e60")
			1:
				# 锤子
				_f(img, x + 2, 8, 2, 15, "a06a40")
				_f(img, x, 6, 6, 4, "8a9098")
				_f(img, x, 6, 6, 1, "c8ccd0")
			_:
				# 凿子
				_f(img, x + 1, 6, 2, 8, "8a9098")
				_f(img, x, 14, 4, 8, "a06a40")
		x += 9
		i += 1
	return Px.outline(img)


static func _bin(coal: bool) -> Image:
	var img := Px.new_img(30, 20)
	_f(img, 1, 8, 28, 11, "8a5a36")
	_f(img, 1, 8, 28, 2, "a06a40")
	_f(img, 2, 12, 26, 1, "6e4526")
	_f(img, 2, 16, 26, 1, "6e4526")
	var dark := ["2a2a2e", "3a3a40", "4a4a52"] if coal else ["7a6a58", "9a8a74", "5a6a78"]
	for i in 12:
		var x := 3 + Px.h2(i, 5) % 22
		var y := 3 + Px.h2(i, 6) % 6
		_f(img, x, y, 4, 4, dark[Px.h2(i, 7) % 3])
		_f(img, x, y, 4, 1, dark[2] if coal else "c8c0a8")
	return Px.outline(img)


static func _grindstone() -> Image:
	var img := Px.new_img(26, 28)
	_f(img, 3, 12, 2, 15, "8a5a36")
	_f(img, 21, 12, 2, 15, "8a5a36")
	_f(img, 2, 25, 22, 2, "6e4526")
	_f(img, 6, 6, 14, 14, "a8aaa8")
	_f(img, 4, 8, 18, 10, "a8aaa8")
	_f(img, 6, 8, 14, 10, "c8ccd0")
	_f(img, 11, 11, 4, 4, "6a6e70")
	_f(img, 21, 6, 4, 2, "6e4526")
	_f(img, 24, 3, 2, 5, "a06a40")
	return Px.outline(img)


# ---------------------------------------------------------------- 木匠铺

static func _workbench(n: int) -> Image:
	var w := n * TS
	var img := Px.new_img(w, 28)
	_f(img, 1, 3, w - 2, 8, "c8a068")
	_f(img, 1, 3, w - 2, 1, "e0bc84")
	_f(img, 1, 11, w - 2, 2, "8a5a36")
	for x in [3, w - 6]:
		_f(img, x, 13, 3, 14, "8a5a36")
	_f(img, 4, 20, w - 8, 2, "6e4526")
	# 台钳、刨子、锯
	_f(img, 4, 1, 5, 6, "6a6e70")
	_f(img, 4, 1, 5, 1, "9a9ea0")
	_f(img, 12, 4, 10, 4, "a8764a")
	_f(img, 12, 4, 10, 1, "d8a468")
	_f(img, 14, 2, 3, 2, "6e4526")
	if n >= 3:
		_f(img, 28, 5, 14, 2, "c8ccd0")
		_f(img, 28, 5, 14, 1, "e8ecf0")
		_f(img, 41, 3, 3, 5, "a06a40")
	return Px.outline(img)


static func _lumber_rack() -> Image:
	var img := Px.new_img(36, 44)
	_f(img, 1, 1, 3, 42, "6e4526")
	_f(img, 32, 1, 3, 42, "6e4526")
	var tones := ["c8a068", "b88c58", "d8b078", "a8784a"]
	for r in 5:
		var y := 4 + r * 7
		_f(img, 4, y + 6, 28, 1, "6e4526")
		var x := 4
		while x < 32:
			var len := 9 + Px.h2(x, r) % 12
			len = mini(len, 32 - x)
			_f(img, x, y, len, 6, tones[Px.h2(x + 3, r + 1) % 4])
			_f(img, x, y, len, 1, "e0bc84")
			x += len
	return Px.outline(img)


static func _plank_pile() -> Image:
	var img := Px.new_img(32, 18)
	var tones := ["c8a068", "b88c58", "d8b078"]
	for r in 3:
		_f(img, 1 + r * 2, 3 + r * 5, 28 - r * 2, 4, tones[r])
		_f(img, 1 + r * 2, 3 + r * 5, 28 - r * 2, 1, "e0bc84")
		_f(img, 1 + r * 2, 6 + r * 5, 28 - r * 2, 1, "8a5a36")
	return Px.outline(img)


static func _saw_horse() -> Image:
	var img := Px.new_img(30, 20)
	_f(img, 1, 3, 28, 4, "a8764a")
	_f(img, 1, 3, 28, 1, "d8a468")
	_f(img, 4, 7, 2, 11, "8a5a36")
	_f(img, 24, 7, 2, 11, "8a5a36")
	_f(img, 6, 10, 2, 8, "6e4526")
	_f(img, 22, 10, 2, 8, "6e4526")
	return Px.outline(img)


static func _oar_rack(n: int) -> Image:
	var w := n * TS
	var img := Px.new_img(w, 30)
	_f(img, 1, 6, w - 2, 2, "6e4526")
	_f(img, 1, 22, w - 2, 2, "6e4526")
	var x := 5
	while x < w - 10:
		_f(img, x, 1, 2, 28, "c8a068")
		_f(img, x, 1, 1, 28, "e0bc84")
		_f(img, x - 2, 20, 6, 9, "b88c58")
		_f(img, x - 2, 20, 1, 9, "d8b078")
		x += 12
	return Px.outline(img)


static func _rope_coil() -> Image:
	var img := Px.new_img(20, 12)
	_f(img, 2, 4, 16, 7, "b8a068")
	_f(img, 4, 2, 12, 3, "c8b078")
	_f(img, 6, 5, 8, 3, "8a7448")
	for x in range(3, 18, 3):
		_f(img, x, 5, 1, 5, "8a7448")
	_f(img, 16, 8, 4, 2, "b8a068")
	return Px.outline(img)


static func _skiff_frame() -> Image:
	var img := Px.new_img(76, 40)
	var plank := ["c8a068", "b88c58"]
	for x in range(2, 74):
		var t := (x - 37.5) / 36.0
		var bottom := 34 - int(9.0 * t * t)
		var top := 16 - int(7.0 * t * t)
		# 下半截已经钉上舷板，上半截只有肋骨
		var mid := (top + bottom) / 2 + 2
		for y in range(mid, bottom + 1):
			var seam := (y - mid) % 5 == 4
			img.set_pixel(x, y, Color.html("8a5a36") if seam else Color.html(plank[((x / 11) + (y - mid) / 5) % 2]))
		img.set_pixel(x, bottom, Color.html("6e4526"))
		img.set_pixel(x, top, Color.html("e0bc84"))
		img.set_pixel(x, top + 1, Color.html("a8764a"))
		if (x - 6) % 10 == 0:
			for y in range(top + 2, mid):
				img.set_pixel(x, y, Color.html("a8764a"))
				img.set_pixel(x + 1, y, Color.html("c8a068"))
	# 船头船尾的立板
	_f(img, 1, 6, 2, 12, "a8764a")
	_f(img, 73, 6, 2, 12, "a8764a")
	# 垫船的木墩
	_f(img, 16, 35, 5, 4, "6e4526")
	_f(img, 55, 35, 5, 4, "6e4526")
	return Px.outline(img)

static func _net_wall() -> Image:
	var img := Px.new_img(40, 28)
	_f(img, 1, 1, 38, 2, "6e4526")
	for y in range(3, 26, 4):
		for x in range(2, 38, 4):
			var off := 2 if (y / 4) % 2 == 1 else 0
			_f(img, x + off, y, 3, 1, "b8a878")
			_f(img, x + off + 1, y + 1, 1, 3, "b8a878")
	for x in [6, 16, 28, 34]:
		_f(img, x, 20 + Px.h2(x, 1) % 4, 3, 3, "c8463a")
	return Px.outline(img)


static func _drawing_board() -> Image:
	var img := Px.new_img(34, 30)
	_f(img, 1, 1, 32, 28, "6e4526")
	_f(img, 3, 3, 28, 24, "ecd9a0")
	_f(img, 3, 3, 28, 1, "f4ecd0")
	_f(img, 6, 8, 10, 1, "3a4a6a")
	_f(img, 6, 8, 1, 10, "3a4a6a")
	_f(img, 6, 17, 10, 1, "3a4a6a")
	_f(img, 14, 8, 1, 6, "3a4a6a")
	_f(img, 19, 6, 9, 1, "3a4a6a")
	_f(img, 19, 6, 1, 14, "3a4a6a")
	_f(img, 24, 12, 4, 1, "3a4a6a")
	_f(img, 22, 20, 6, 1, "3a4a6a")
	return Px.outline(img)


# ---------------------------------------------------------------- 茶馆

static func _teapot_shelf(n: int) -> Image:
	var w := n * TS
	var img := Px.new_img(w, 30)
	_f(img, 1, 14, w - 2, 2, "8a5a36")
	_f(img, 1, 28, w - 2, 2, "8a5a36")
	_f(img, 1, 1, 1, 28, "6e4526")
	_f(img, w - 2, 1, 1, 28, "6e4526")
	var x := 4
	var i := 0
	while x < w - 10:
		var tone: String = ["8fc8a8", "f4f0e4", "b86a48"][i % 3]
		# 壶
		_f(img, x, 8, 8, 6, tone)
		_f(img, x + 1, 7, 6, 1, tone)
		_f(img, x + 3, 5, 2, 2, "4a2c18")
		_f(img, x + 8, 9, 3, 1, tone)
		_f(img, x - 2, 9, 2, 3, tone)
		# 杯
		_f(img, x, 24, 4, 4, "f4f0e4")
		_f(img, x + 5, 24, 4, 4, "f4f0e4")
		_f(img, x, 24, 4, 1, "c8c4b8")
		x += 14
		i += 1
	return Px.outline(img)


static func _tea_tins(n: int) -> Image:
	var w := n * TS
	var img := Px.new_img(w, 30)
	_f(img, 1, 14, w - 2, 2, "8a5a36")
	_f(img, 1, 28, w - 2, 2, "8a5a36")
	_f(img, 1, 1, 1, 28, "6e4526")
	_f(img, w - 2, 1, 1, 28, "6e4526")
	for row in 2:
		var base := 14 + row * 14
		var x := 4
		while x < w - 9:
			var tone: String = ["3d5a8a", "a83e36", "3d6a48"][Px.h2(x, row + n) % 3]
			_f(img, x, base - 11, 7, 11, tone)
			_f(img, x, base - 12, 7, 1, "d8b060")
			_f(img, x + 2, base - 8, 3, 4, "f4ecd0")
			x += 10
	return Px.outline(img)


# ---------------------------------------------------------------- 议事厅

static func _big_map() -> Image:
	var img := Px.new_img(BIG_MAP_W, BIG_MAP_H)
	_f(img, 0, 0, BIG_MAP_W, BIG_MAP_H, "6e4526")
	_f(img, 1, 1, BIG_MAP_W - 2, BIG_MAP_H - 2, "8a5a36")
	_f(img, 2, 2, BIG_MAP_W - 4, BIG_MAP_H - 4, "ecd9a0")
	for cell in BIG_MAP_CELLS:
		_f(img, cell.position.x, cell.position.y, cell.size.x, cell.size.y, "f6ecc8")
		# 一圈虚线边，空格还没补上
		for x in range(cell.position.x, cell.end.x, 3):
			_f(img, x, cell.position.y, 2, 1, "b8a478")
			_f(img, x, cell.end.y - 1, 2, 1, "b8a478")
		for y in range(cell.position.y, cell.end.y, 3):
			_f(img, cell.position.x, y, 1, 2, "b8a478")
			_f(img, cell.end.x - 1, y, 1, 2, "b8a478")
	return img
