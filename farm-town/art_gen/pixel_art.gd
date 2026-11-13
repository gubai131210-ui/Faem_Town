class_name PixelArt
extends RefCounted
## 用代码逐像素绘制的素材：作物、图标、植物、建筑、地面、界面。
## 文件变大以后按类别拆开。

static var P: Dictionary = Palette.colors()

const ICONS := {
	"turnip": [
		"................",
		"......l..ll.....",
		".....lLl.lL.....",
		"......lLLL......",
		".......LL.......",
		".....vvvvvv.....",
		"....vvvvvvvv....",
		"...vvxxxxxxvv...",
		"...xxxxxxxxxx...",
		"...xxxxxxxxxX...",
		"....xxxxxxxX....",
		".....xxxxxX.....",
		"......xxXX......",
		".......xX.......",
		"................",
		"................",
	],
	"can": [
		"................",
		"................",
		"....ggggg.......",
		"...g.....g......",
		"...g.....g...gg.",
		"..ggggggggg.gg..",
		"..gGGGGGGGGgg...",
		"..gGGGGGGGGg....",
		"..gGGGGGGGG.....",
		"..gGGGGGGGG.....",
		"..GGGGGGGGG.....",
		"..GGGGGGGGG.....",
		"...GGGGGGG......",
		"................",
		"................",
		"................",
	],
	"seeds": [
		"................",
		"................",
		"......kkkk......",
		".....kkKKkk.....",
		"......rrrr......",
		".....kkkkkk.....",
		"....kkkkkkkk....",
		"...kkkllkkkkK...",
		"...kkllLlkkkK...",
		"...kkklLkkkkK...",
		"...kkkkLkkkkK...",
		"...kkkkkkkkKK...",
		"....kkkkkkKK....",
		"................",
		"................",
		"................",
	],
}

## 工具四个等级的金属色 [亮, 暗]：铜、铁、银、金
const TIER_COLORS: Array = [["d8925e", "a8623a"], ["8a94a3", "5e6873"], ["eef2f6", "aab4c0"], ["f7dc80", "d0a23c"]]

const TUFT := [
	"..l.....l...",
	".lL..l..Ll..",
	".lL.lL..Ll.l",
	"..LllL.lLlL.",
	"..LLLLLLLL..",
]

const FLOWER := [
	"..fff...",
	".ffqff..",
	"..fff...",
	"...L....",
	".l.L....",
	"..LL.l..",
	"...LL...",
]

# ---------------------------------------------------------------- 作物与图标

## 作物某个生长阶段的图，画法见 CropArt。
static func crop(crop_id: StringName, stage: int, dead: bool = false) -> Image:
	return CropArt.field(crop_id, stage, dead)


## 图标。"crop:作物id" 和 "seeds:作物id" 交给 CropArt 画，"wild:物品id" 交给 ItemArt，
## "sapling:果树id" 交给 TreeArt，其余是这里的固定图标。
static func icon(n: String) -> Image:
	if n.begins_with("crop:"):
		return CropArt.icon(StringName(n.substr(5)))
	if n.begins_with("seeds:"):
		return CropArt.seed_icon(StringName(n.substr(6)))
	if n.begins_with("wild:"):
		return ItemArt.icon(n.substr(5))
	if n.begins_with("relic:"):
		return ItemArt.relic(StringName(n.substr(6)))
	if n.begins_with("fish:"):
		return ItemArt.fish(StringName(n.substr(5)))
	if n.begins_with("food:"):
		return ItemArt.food(StringName(n.substr(5)))
	if n.begins_with("mine:"):
		# "mine:pickaxe@2" 是银镐子
		var mine_name := n.substr(5)
		var mine_at := mine_name.find("@")
		if mine_at >= 0:
			return MineArt.icon(StringName(mine_name.substr(0, mine_at)), int(mine_name.substr(mine_at + 1)))
		return MineArt.icon(StringName(mine_name))
	if n.begins_with("accessory:"):
		return MineDarkArt.accessory(StringName(n.substr(10)))
	if n.begins_with("weapon:"):
		return MineArt.weapon_icon(StringName(n.substr(7)))
	if n.begins_with("machine:"):
		return ItemArt.machine(StringName(n.substr(8)))
	if n.begins_with("product:"):
		return ItemArt.product(StringName(n.substr(8)))
	if n.begins_with("sapling:"):
		return TreeArt.sapling_icon(StringName(n.substr(8)))
	if n == "sun" or n == "cloud" or n == "rain" or n == "storm" or n == "fog" or n == "wind" \
			or n == "snow" or n == "frost":
		return weather_icon(n)
	if n.begins_with("fert:"):
		return _fert_icon(int(n.substr(5)))
	# 工具图标可以带等级："hoe@2" 是银锄头；不带就是 0 级
	var tier := 0
	var at := n.find("@")
	if at >= 0:
		tier = clampi(int(n.substr(at + 1)), 0, TIER_COLORS.size() - 1)
		n = n.substr(0, at)
	var metal: Array = TIER_COLORS[tier]
	var hi := Color.html(str(metal[0]))
	var lo := Color.html(str(metal[1]))
	if n == "lotus_flower":
		var img := Px.new_img(16, 16)
		var petal := CropArt.ramp(Color.html("f4a9be"))
		Px.line(img, Vector2i(8, 10), Vector2i(8, 14), Color.html("4a9a3c"))
		CropArt.ball(img, 4.5, 8.5, 2.6, 2.0, petal)
		CropArt.ball(img, 11.5, 8.5, 2.6, 2.0, petal)
		CropArt.ball(img, 6.0, 6.0, 2.2, 3.2, petal)
		CropArt.ball(img, 10.0, 6.0, 2.2, 3.2, petal)
		CropArt.ball(img, 8.0, 6.5, 2.0, 3.6, [Color.html("fde4ea"), petal[0], petal[1]])
		Px.rect(img, 7, 8, 2, 1, Color.html("f4d23c"))
		return Px.outline(img)
	if n == "shovel":
		var img := Px.new_img(16, 16)
		var steel := Color.html("c3ccd6")
		var steel_d := Color.html("8a94a3")
		Px.rect(img, 6, 1, 4, 1, P["W"])
		Px.rect(img, 7, 2, 1, 7, P["w"])
		Px.rect(img, 8, 2, 1, 7, P["W"])
		Px.rect(img, 5, 9, 6, 4, steel)
		Px.rect(img, 6, 13, 4, 1, steel)
		Px.rect(img, 7, 14, 2, 1, steel_d)
		Px.rect(img, 10, 9, 1, 4, steel_d)
		Px.rect(img, 9, 13, 1, 1, steel_d)
		Px.rect(img, 5, 9, 6, 1, Color.html("eef2f6"))
		return Px.outline(img)
	if n == "rod":
		# 鱼竿：一根斜着的细竹竿，手柄处一只小线轮，竿尖垂一截线
		var img := Px.new_img(16, 16)
		Px.line(img, Vector2i(2, 14), Vector2i(13, 3), Color.html("c8a860"))
		Px.line(img, Vector2i(2, 13), Vector2i(8, 7), Color.html("8a6a34"))
		Px.px(img, 13, 2, Color.html("e8d8a0"))
		Px.rect(img, 4, 10, 3, 3, hi)
		Px.px(img, 5, 11, lo)
		Px.line(img, Vector2i(13, 3), Vector2i(14, 9), Color.html("e8eef2"))
		Px.px(img, 14, 10, Color.html("d04040"))
		return Px.outline(img)
	if n == "bait":
		# 鱼饵：一小团麸皮，上面趴两条蚯蚓
		var img := Px.new_img(16, 16)
		CropArt.ball(img, 8.0, 10.0, 5.0, 3.2, CropArt.ramp(Color.html("b89860")))
		Px.line(img, Vector2i(4, 7), Vector2i(9, 9), Color.html("c8706a"))
		Px.line(img, Vector2i(9, 6), Vector2i(12, 9), Color.html("b05e5a"))
		Px.px(img, 4, 7, Color.html("e0908a"))
		return Px.outline(img)
	if n == "bobber":
		# 浮漂：上红下白的梭子，顶上一截细杆
		var img := Px.new_img(16, 16)
		Px.rect(img, 7, 1, 2, 3, Color.html("e8d8a0"))
		for y in range(4, 13):
			var w := 2 if y < 5 or y > 11 else (4 if y > 6 and y < 10 else 3)
			var c := Color.html("d84040") if y < 8 else Color.html("f4f0e8")
			Px.rect(img, 8 - w / 2, y, w, 1, c)
		Px.rect(img, 7, 13, 2, 2, Color.html("5a5a60"))
		return Px.outline(img)
	if n == "crab_trap":
		var img := Px.new_img(16, 16)
		Px.blit(img, crab_trap(), 0, 1)
		return img
	if n == "hoe":
		var img := Px.new_img(16, 16)
		Px.line(img, Vector2i(3, 13), Vector2i(11, 5), P["w"])
		Px.line(img, Vector2i(4, 13), Vector2i(12, 5), P["W"])
		Px.rect(img, 8, 2, 6, 3, hi)
		Px.rect(img, 11, 4, 3, 4, hi)
		Px.rect(img, 13, 3, 1, 5, lo)
		Px.rect(img, 11, 7, 3, 1, lo)
		return Px.outline(img)
	var rows: Array = ICONS[n]
	if n == "can":
		var pal: Dictionary = P.duplicate()
		pal["g"] = hi
		pal["G"] = lo
		return Px.outline(Px.ascii(rows, pal))
	return Px.outline(Px.ascii(rows, P))


## 肥料袋：1 是草木灰（灰白），2 是饼肥（金黄）。
static func _fert_icon(power: int) -> Image:
	var img := Px.new_img(16, 16)
	var cols: Array = [Color.html("ecd9a8"), Color.html("d4b87e"), Color.html("a88c58")]
	CropArt.ball(img, 8.0, 9.5, 4.6, 4.4, cols)
	Px.rect(img, 6, 3, 4, 2, cols[1])
	Px.rect(img, 5, 5, 6, 1, P["r"] if power > 1 else P["W"])
	var grain := Color.html("f2c14e") if power > 1 else Color.html("8a8478")
	for p: Vector2i in [Vector2i(7, 8), Vector2i(9, 9), Vector2i(6, 10), Vector2i(8, 11), Vector2i(10, 11)]:
		Px.px(img, p.x, p.y, grain)
	return Px.outline(img)


## 品质标记，7×7（含描边）：1 是银色，2 是金色。
static func quality_mark(quality: int) -> Image:
	var img := Px.new_img(7, 7)
	var hi := Color.html("fff3a8") if quality > 1 else Color.html("ffffff")
	var mid := Color.html("f2c14e") if quality > 1 else Color.html("c3ccd6")
	Px.rect(img, 3, 1, 1, 5, mid)
	Px.rect(img, 1, 3, 5, 1, mid)
	Px.rect(img, 2, 2, 3, 3, mid)
	Px.px(img, 3, 3, hi)
	Px.px(img, 2, 2, hi)
	return Px.outline(img)


## 天气小图标，11×11（含一圈描边），显示在时钟旁边。
static func weather_icon(n: String) -> Image:
	var out := Px.new_img(11, 11)
	Px.blit(out, _weather_glyph(n), 1, 1)
	return Px.outline(out)


static func _weather_glyph(n: String) -> Image:
	var img := Px.new_img(9, 9)
	var sun := Color.html("f4c542")
	var cloud := Color.html("eef2f6")
	var cloud_d := Color.html("b9c4d0")
	var drop := Color.html("5aa6e0")
	if n == "sun":
		Px.rect(img, 3, 3, 3, 3, sun)
		for p: Vector2i in [Vector2i(4, 0), Vector2i(4, 8), Vector2i(0, 4), Vector2i(8, 4),
				Vector2i(1, 1), Vector2i(7, 1), Vector2i(1, 7), Vector2i(7, 7)]:
			Px.px(img, p.x, p.y, Color.html("e09a2e"))
		return img
	if n == "wind":
		Px.rect(img, 0, 2, 6, 1, cloud)
		Px.rect(img, 2, 4, 7, 1, cloud)
		Px.rect(img, 0, 6, 5, 1, cloud)
		Px.px(img, 6, 1, cloud)
		Px.px(img, 5, 7, cloud)
		return img
	if n == "frost":
		# 六角的霜花
		var ice := Color.html("bfe6f7")
		Px.rect(img, 4, 0, 1, 9, ice)
		Px.rect(img, 0, 4, 9, 1, ice)
		for i in range(1, 4):
			Px.px(img, 4 - i, 4 - i, ice)
			Px.px(img, 4 + i, 4 - i, ice)
			Px.px(img, 4 - i, 4 + i, ice)
			Px.px(img, 4 + i, 4 + i, ice)
		Px.px(img, 4, 4, Color.WHITE)
		return img
	if n == "fog":
		for y: int in [1, 3, 5, 7]:
			Px.rect(img, 0 if y % 4 == 1 else 2, y, 7, 1, cloud if y < 5 else cloud_d)
		return img
	# 其余都带一朵云
	Px.rect(img, 1, 3, 7, 2, cloud)
	Px.rect(img, 2, 2, 3, 1, cloud)
	Px.rect(img, 5, 2, 2, 1, cloud)
	Px.rect(img, 3, 1, 2, 1, cloud)
	Px.rect(img, 1, 5, 7, 1, cloud_d)
	match n:
		"rain":
			for x: int in [2, 4, 6]:
				Px.px(img, x, 7, drop)
				Px.px(img, x - 1, 8, drop)
		"storm":
			Px.px(img, 2, 7, drop)
			Px.px(img, 7, 7, drop)
			Px.px(img, 5, 6, sun)
			Px.px(img, 4, 7, sun)
			Px.px(img, 5, 8, sun)
		"snow":
			for x: int in [2, 4, 6]:
				Px.px(img, x, 7 + (x / 2) % 2, Color.WHITE)
	return img


## 出货箱：一只带盖的木箱，18×18，锚点在 (9, 16)。
static func ship_bin() -> Image:
	var img := Px.new_img(18, 18)
	var w0 := Color.html("c08a52")
	var w1 := Color.html("9a6a40")
	var w2 := Color.html("6e4526")
	var iron := Color.html("5b626b")
	# 盖子：比箱体略宽，上面亮
	Px.rect(img, 1, 3, 16, 4, w0)
	Px.rect(img, 1, 6, 16, 1, w1)
	Px.rect(img, 2, 2, 14, 1, Color.html("d6a468"))
	# 箱体
	Px.rect(img, 2, 7, 14, 9, w1)
	Px.rect(img, 2, 7, 14, 1, w2)
	for x: int in [6, 11]:
		Px.rect(img, x, 8, 1, 8, w2)
	Px.rect(img, 2, 15, 14, 1, w2)
	Px.rect(img, 14, 8, 2, 8, w2)
	# 铁箍和搭扣
	Px.rect(img, 3, 3, 1, 13, iron)
	Px.rect(img, 13, 3, 1, 13, iron)
	Px.rect(img, 8, 6, 2, 3, Color.html("e2b84e"))
	Px.px(img, 8, 8, Color.html("b08a34"))
	return Px.outline(img)


## 码头的一格木板（16×16）：横着铺的板子，板缝深色。mask 位 1 上、2 右、4 下、8 左 表示那一边还是木板；不是木板的边描一道边框。
static func dock_tile(mask: int) -> Image:
	var img := Px.new_img(16, 16)
	var w0 := Color.html("b98a58")
	var w1 := Color.html("a37648")
	var w2 := Color.html("6e4526")
	for y in 16:
		var c := w0 if (y / 4) % 2 == 0 else w1
		Px.rect(img, 0, y, 16, 1, c)
		if y % 4 == 3:
			Px.rect(img, 0, y, 16, 1, w2)
	# 板子之间偶尔的钉子
	Px.px(img, 3, 1, w2)
	Px.px(img, 12, 9, w2)
	if mask & 1 == 0:
		Px.rect(img, 0, 0, 16, 1, w2)
	if mask & 4 == 0:
		Px.rect(img, 0, 15, 16, 1, w2)
	if mask & 2 == 0:
		Px.rect(img, 15, 0, 1, 16, w2)
	if mask & 8 == 0:
		Px.rect(img, 0, 0, 1, 16, w2)
	return img


## 码头下面露出水面的木桩，一根 4×10。
static func dock_post() -> Image:
	var img := Px.new_img(4, 10)
	Px.rect(img, 0, 0, 4, 10, Color.html("8a5e36"))
	Px.rect(img, 0, 0, 1, 10, Color.html("a37648"))
	Px.rect(img, 3, 0, 1, 10, Color.html("5a3a20"))
	Px.rect(img, 0, 9, 4, 1, Color.html("4a3018"))
	return Px.outline(img)


## 系在码头边的小木船，船头朝左，32×14。
static func boat() -> Image:
	var img := Px.new_img(32, 14)
	var hull := Color.html("8a5e36")
	var hull_d := Color.html("5a3a20")
	var rim := Color.html("b98a58")
	var inside := Color.html("c9a070")
	for y in range(3, 11):
		var k := (y - 3) / 7.0
		var x0 := int(roundf(2.0 + k * 5.0))
		var x1 := int(roundf(30.0 - k * 4.0))
		Px.rect(img, x0, y, x1 - x0, 1, hull if y < 9 else hull_d)
	Px.rect(img, 2, 3, 28, 1, rim)
	Px.rect(img, 6, 4, 22, 3, inside)
	# 两条横板和一根桨
	Px.rect(img, 10, 4, 2, 3, hull)
	Px.rect(img, 20, 4, 2, 3, hull)
	Px.line(img, Vector2i(14, 2), Vector2i(26, 6), Color.html("d6a468"))
	return Px.outline(img)


## 蟹笼：一个竹编的小笼子，16×14。
static func crab_trap() -> Image:
	var img := Px.new_img(16, 14)
	var bamboo := Color.html("c9b068")
	var bamboo_d := Color.html("8a7a3a")
	var gap := Color.html("4a4a3a")
	for y in range(4, 13):
		var k := absf((y - 8.0) / 5.0)
		var x0 := int(roundf(2.0 + k * k * 2.0))
		var x1 := int(roundf(14.0 - k * k * 2.0))
		Px.rect(img, x0, y, x1 - x0, 1, bamboo if y % 3 != 0 else bamboo_d)
	for x in range(4, 13, 3):
		Px.rect(img, x, 5, 1, 7, gap)
	# 笼口和提绳
	Px.rect(img, 6, 6, 4, 3, gap)
	Px.line(img, Vector2i(8, 4), Vector2i(8, 0), bamboo_d)
	return Px.outline(img)


## 四季的草丛颜色 [浅, 深]
const TUFT_COLORS: Array = [["5fa043", "4a8a3a"], ["529a3c", "3f7f34"], ["a09a40", "84803a"], ["c3d1dc", "a7b8c6"]]


static func tuft(season: int = 0) -> Image:
	# 草丛不描边，只用比地面略深的两档颜色，避免满地黑边显得脏
	var tc: Array = TUFT_COLORS[clampi(season, 0, 3)]
	var pal := {"l": Color.html(str(tc[0])), "L": Color.html(str(tc[1]))}
	return Px.ascii(TUFT, pal)


static func flower(variant: int) -> Image:
	var pal := P.duplicate()
	var cols := [Color.html("f6f1ea"), Color.html("f28fb0"), Color.html("f4c542"), Color.html("9d8cf0")]
	pal["f"] = cols[variant % cols.size()]
	if variant % cols.size() == 2:
		pal["q"] = Color.html("e07a2e")
	return Px.outline(Px.ascii(FLOWER, pal))


# ---------------------------------------------------------------- 树

static func _put(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


## 画一段由粗到细的枝干，cols 是 [亮, 中, 暗]。
static func _limb(img: Image, a: Vector2, b: Vector2, w0: float, w1: float, cols: Array) -> void:
	var n := int(a.distance_to(b)) + 1
	for i in n + 1:
		var t := i / float(n)
		var p := a.lerp(b, t)
		var wd := maxi(1, int(roundf(lerpf(w0, w1, t))))
		var x0 := int(roundf(p.x - wd * 0.5))
		for k in wd:
			var c: Color = cols[1]
			if k == 0 and wd > 1:
				c = cols[0]
			if k == wd - 1 and wd > 2:
				c = cols[2]
			_put(img, x0 + k, int(roundf(p.y)), c)


## 递归分叉的枝干，ang 为 0 时朝正上方。分叉点和枝梢记到 tips 里。
static func _branches(img: Image, rng: RandomNumberGenerator, a: Vector2, ang: float, ln: float,
		wd: float, depth: int, cols: Array, tips: Array) -> void:
	var b := a + Vector2(sin(ang), -cos(ang)) * ln
	var w1 := maxf(1.0, wd * 0.62)
	_limb(img, a, b, wd, w1, cols)
	tips.append(b)
	if depth <= 0:
		return
	var spread := rng.randf_range(0.42, 0.7)
	var tilt := rng.randf_range(-0.15, 0.15)
	_branches(img, rng, b, clampf(ang - spread + tilt, -1.35, 1.35), ln * rng.randf_range(0.68, 0.8),
		w1, depth - 1, cols, tips)
	_branches(img, rng, b, clampf(ang + spread + tilt, -1.35, 1.35), ln * rng.randf_range(0.68, 0.8),
		w1, depth - 1, cols, tips)


## 圆冠树四季的树冠颜色，每季三种，每种是 [高光, 亮, 中, 暗]。冬天落叶，不用这张表。
const CROWN_COLORS: Array = [
	[["a9d95a", "78bd48", "4f9a42", "35763d"], ["8fcf6a", "5fae56", "3f8a50", "2c6747"], ["f4c0cc", "e89ab0", "cf7896", "a85a7c"]],
	[["9ccf58", "68b046", "3f8a3e", "2a6a38"], ["7fc264", "4f9e50", "34804a", "245f42"], ["a4d468", "72b84c", "4a9644", "32743c"]],
	[["f6cc62", "e6a23e", "c47830", "8f4e28"], ["ecdc70", "cdbb4a", "a0963a", "706c30"], ["f4a070", "dc6e4a", "b44a3a", "823230"]],
]


## 圆冠树：整团树冠先铺底色，再叠几团带高光的叶簇，不加杂色。锚点在 (22, 57)。
## season：0 春 1 夏 2 秋 3 冬。冬天只剩枝干，枝上有雪。
static func round_tree(variant: int, season: int = 0) -> Image:
	var img := Px.new_img(44, 60)
	var bark := [Color.html("a06a3c"), Color.html("84532d"), Color.html("653d20")]
	if season == 3:
		var rng := RandomNumberGenerator.new()
		rng.seed = 77 + variant * 13
		var tips: Array = []
		_branches(img, rng, Vector2(22, 57), rng.randf_range(-0.06, 0.06), 19.0, 6.0, 4, bark, tips)
		for x in range(18, 26):
			_put(img, x, 56, bark[1] if x < 24 else bark[2])
		_snow_on(img, rng)
		return Px.outline(img)
	var bx := 22
	for y in range(34, 57):
		var half := 3 if y < 53 else (4 if y < 55 else 5)
		for x in range(bx - half, bx + half):
			var c: Color = bark[1]
			if x <= bx - half + 1:
				c = bark[0]
			if x >= bx + half - 2 or y < 42:
				c = bark[2]
			img.set_pixel(x, y, c)
	var sets: Array = CROWN_COLORS[clampi(season, 0, 2)]
	var cols: Array = []
	for hex: String in sets[variant % sets.size()]:
		cols.append(Color.html(hex))
	var body: Array = [Vector3(22, 20, 14), Vector3(11, 25, 8), Vector3(33, 25, 8), Vector3(22, 30, 10)]
	for y in 44:
		for x in 44:
			var inside := false
			for cv in body:
				var c: Vector3 = cv
				if Vector2(x + 0.5 - c.x, y + 0.5 - c.y).length() < c.z:
					inside = true
					break
			if not inside:
				continue
			var n := Vector2(x + 0.5 - 22.0, y + 0.5 - 22.0) / 17.0
			var col: Color = cols[2]
			if n.dot(Vector2(0.5, 0.86)) > 0.52:
				col = cols[3]
			img.set_pixel(x, y, col)
	# [x, y, 半径, 亮度档]：左上的叶簇亮，右下的暗
	var clumps: Array = [[14, 14, 7, 0], [26, 11, 7, 0], [9, 24, 6, 0], [21, 21, 7, 0],
		[33, 20, 6, 1], [15, 31, 6, 1], [28, 30, 6, 1]]
	for cv in clumps:
		var c: Array = cv
		var cc := Vector2(c[0], c[1])
		var r: float = c[2]
		var sh: int = c[3]
		for y in range(int(cc.y - r), int(cc.y + r) + 1):
			for x in range(int(cc.x - r), int(cc.x + r) + 1):
				if x < 0 or y < 0 or x >= 44 or y >= 60 or img.get_pixel(x, y).a == 0.0:
					continue
				var p := Vector2(x + 0.5, y + 0.5)
				if p.distance_to(cc) >= r:
					continue
				# 叶簇右下留一圈底色当作阴影
				if p.distance_to(cc + Vector2(-1.5, -1.5)) >= r - 1.0:
					continue
				var col: Color = cols[1 + sh]
				# 高光是左上的一弯月牙，不是整块
				if p.distance_to(cc + Vector2(-2.0, -2.0)) < r - 2.5 \
						and p.distance_to(cc + Vector2(0.5, 1.0)) >= r - 3.0:
					col = cols[sh]
				img.set_pixel(x, y, col)
	return Px.outline(img)


## 在枝干朝上的那一面落一层雪：上面是空的枝干像素，隔几个放一粒白。
static func _snow_on(img: Image, rng: RandomNumberGenerator) -> void:
	var spots: Array[Vector2i] = []
	for y in range(1, img.get_height() - 6):
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.0 and img.get_pixel(x, y - 1).a == 0.0 and rng.randf() < 0.55:
				spots.append(Vector2i(x, y - 1))
	for s in spots:
		img.set_pixel(s.x, s.y, Color.html("f4f8fb"))


## 梅树：只有分叉的枝干。冬天和春天枝头开花（冬天花色深、枝上有雪），夏天是小绿叶，秋天剩几片黄叶。
## 锚点在 (24, 57)。season：0 春 1 夏 2 秋 3 冬。
static func plum_tree(variant: int, season: int = 0) -> Image:
	var img := Px.new_img(48, 60)
	var rng := RandomNumberGenerator.new()
	rng.seed = 310 + variant * 29
	var bark := [Color.html("8a6a52"), Color.html("64493a"), Color.html("463228")]
	var tips: Array = []
	_branches(img, rng, Vector2(24, 57), rng.randf_range(-0.08, 0.08), 17.0, 6.0, 4, bark, tips)
	# 树根加宽一点
	for x in range(20, 28):
		_put(img, x, 56, bark[1] if x < 26 else bark[2])
	var pink := [Color.html("fde4ea"), Color.html("f4a9be"), Color.html("d97a9a")]
	if season == 1:
		pink = [Color.html("a4d468"), Color.html("72b84c"), Color.html("4a9644")]
	elif season == 2:
		pink = [Color.html("f6dc7a"), Color.html("e0b44a"), Color.html("b88a34")]
	elif season == 3:
		pink = [Color.html("fbd0d8"), Color.html("e8607e"), Color.html("b83e5c")]
	for i in range(4, tips.size()):
		# 秋天叶子掉了大半
		if season == 2 and i % 3 != 0:
			continue
		var t: Vector2 = tips[i]
		var x := int(t.x) + rng.randi_range(-1, 1)
		var y := int(t.y) + rng.randi_range(-1, 1)
		_put(img, x, y - 1, pink[1])
		_put(img, x - 1, y, pink[1])
		_put(img, x + 1, y, pink[2])
		_put(img, x, y + 1, pink[2])
		_put(img, x, y, pink[0])
	if season == 3:
		_snow_on(img, rng)
	return Px.outline(img)


# ---------------------------------------------------------------- 地面

## mask 位：1=上 2=右 4=下 8=左 有相邻耕地，用来决定哪一边画田埂。
static func soil(mask: int, wet: bool) -> Image:
	var img := Px.new_img(16, 16)
	var base := Color.html("b47a4c")
	var dark := Color.html("96623c")
	var light := Color.html("c99060")
	var rim := Color.html("7d5030")
	if wet:
		base = Color.html("74503a")
		dark = Color.html("5b3c2d")
		light = Color.html("8a6045")
		rim = Color.html("4a3026")
	var n := (mask & 1) != 0
	var e := (mask & 2) != 0
	var s := (mask & 4) != 0
	var w := (mask & 8) != 0
	for y in 16:
		for x in 16:
			var c := base
			var fy := (y + 1) % 4
			if fy == 3:
				c = dark
			elif fy == 0:
				c = light
			var hh := Px.h2(x + 31, y + 17) % 29
			if hh == 0:
				c = dark
			elif hh == 1:
				c = light
			if (not n and y == 0) or (not s and y == 15) or (not w and x == 0) or (not e and x == 15):
				c = rim
			var cx := -1
			var cy := -1
			if not n and not w:
				cx = 0
				cy = 0
				if x == 1 and y == 1:
					c = rim
			if x == cx and y == cy:
				continue
			if not n and not e:
				if x == 15 and y == 0:
					continue
				if x == 14 and y == 1:
					c = rim
			if not s and not w:
				if x == 0 and y == 15:
					continue
				if x == 1 and y == 14:
					c = rim
			if not s and not e:
				if x == 15 and y == 15:
					continue
				if x == 14 and y == 14:
					c = rim
			img.set_pixel(x, y, c)
	return img


static func shadow(w: int, h: int, alpha: float) -> Image:
	var img := Px.new_img(w, h)
	for y in h:
		for x in w:
			var dx := (x + 0.5 - w * 0.5) / (w * 0.5)
			var dy := (y + 0.5 - h * 0.5) / (h * 0.5)
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, Color(0.1, 0.12, 0.2, alpha))
	return img


# ---------------------------------------------------------------- 界面

## 木框纸底的面板，24×24 九宫格（四边各留 7）：深色描边、三层木框、四角一颗铜钉，里面是纸。
static func ui_panel() -> Image:
	var n := 24
	var img := Px.new_img(n, n)
	for y in n:
		for x in n:
			var ex := mini(x, n - 1 - x)
			var ey := mini(y, n - 1 - y)
			var d := mini(ex, ey)
			# 左上半边受光，右下半边背光
			var lit := x + y < n - 1
			if ex + ey < 2:
				continue
			var c := Color.html("f7e3b5")
			match d:
				0:
					c = Color.html("3a2416")
				1:
					c = Color.html("ecbd7c") if lit else Color.html("9a6233")
				2:
					c = Color.html("c98a4b")
				3:
					c = Color.html("8a5630") if lit else Color.html("b47a42")
				4:
					c = Color.html("5b3a21")
				5:
					c = Color.html("e4c890") if lit else Color.html("fbecc8")
			if ex == 1 and ey == 1:
				c = Color.html("3a2416")
			img.set_pixel(x, y, c)
	# 四角的铜钉
	for corner: Vector2i in [Vector2i(2, 2), Vector2i(n - 5, 2), Vector2i(2, n - 5), Vector2i(n - 5, n - 5)]:
		Px.rect(img, corner.x, corner.y, 3, 3, Color.html("e8c264"))
		Px.px(img, corner.x, corner.y, Color.html("fff2b0"))
		Px.px(img, corner.x + 2, corner.y + 2, Color.html("a8782c"))
	return img


## 物品格，22×22：往里凹的一格。选中的描红边、底色更亮。
static func ui_slot(selected: bool) -> Image:
	var n := 22
	var img := Px.new_img(n, n)
	for y in n:
		for x in n:
			var ex := mini(x, n - 1 - x)
			var ey := mini(y, n - 1 - y)
			var d := mini(ex, ey)
			var lit := x + y < n - 1
			if ex + ey < 1:
				continue
			var c := Color.html("fbe7b6") if selected else Color.html("e9c98e")
			match d:
				0:
					c = Color.html("c8483c") if selected else Color.html("5b3a21")
				1:
					if selected:
						c = Color.html("fff2b0")
					else:
						c = Color.html("a8743e") if lit else Color.html("f3d9a4")
				2:
					if lit:
						c = Color.html("efd29a") if selected else Color.html("d2aa6e")
			img.set_pixel(x, y, c)
	return img


## 面板里凹下去的一块（放物品说明），12×12 九宫格（四边各留 3）。
static func ui_card() -> Image:
	var n := 12
	var img := Px.new_img(n, n)
	for y in n:
		for x in n:
			var ex := mini(x, n - 1 - x)
			var ey := mini(y, n - 1 - y)
			var d := mini(ex, ey)
			if ex + ey < 1:
				continue
			var c := Color.html("efd6a4")
			if d == 0:
				c = Color.html("c09a68")
			elif d == 1 and x + y < n - 1:
				c = Color.html("dcbc86")
			img.set_pixel(x, y, c)
	return img


## 屏幕角上那种提示条的底，12×12 九宫格（四边各留 3）：半透明的深色，一圈木色的边。
static func ui_toast() -> Image:
	var n := 12
	var img := Px.new_img(n, n)
	for y in n:
		for x in n:
			var ex := mini(x, n - 1 - x)
			var ey := mini(y, n - 1 - y)
			if ex + ey < 1:
				continue
			var c := Color(0.12, 0.085, 0.07, 0.86)
			if mini(ex, ey) == 0 or (ex == 1 and ey == 1):
				c = Color(0.85, 0.63, 0.4, 0.95)
			img.set_pixel(x, y, c)
	return img


## 一枚铜钱，8×8。
static func coin() -> Image:
	var img := Px.new_img(8, 8)
	CropArt.ball(img, 4.0, 4.0, 3.2, 3.2, CropArt.ramp(Color.html("e0b040")))
	Px.rect(img, 3, 3, 2, 2, Color.html("7a5218"))
	return Px.outline(img)


static func cursor() -> Image:
	var img := Px.new_img(18, 18)
	var c := Color.html("fff6d8")
	for k in 4:
		for corner in [Vector2i(1, 1), Vector2i(16, 1), Vector2i(1, 16), Vector2i(16, 16)]:
			var cv: Vector2i = corner
			var sx := 1 if cv.x == 1 else -1
			var sy := 1 if cv.y == 1 else -1
			img.set_pixel(cv.x + sx * k, cv.y, c)
			img.set_pixel(cv.x, cv.y + sy * k, c)
	return Px.outline(img)


# ---------------------------------------------------------------- 预览图

static func sheet(images: Array, cols: int, cell: Vector2i, scale: int, bg: Color) -> Image:
	var rows := int(ceil(images.size() / float(cols)))
	var img := Image.create(cols * cell.x, rows * cell.y, false, Image.FORMAT_RGBA8)
	img.fill(bg)
	for i in images.size():
		var src: Image = images[i]
		var cx := (i % cols) * cell.x + (cell.x - src.get_width()) / 2
		var cy := (i / cols) * cell.y + (cell.y - src.get_height()) / 2
		Px.blit(img, src, cx, cy)
	img.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)
	return img
