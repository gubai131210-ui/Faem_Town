class_name LaneClueArt
extends RefCounted
## 矿工巷能翻能看的两样小东西：井口碑、墙上的旧告示（决策 119）。
## 纯代码逐像素画，颜色只从 palette.json 取（单字母键），描边走 Px.outline。

const STONE_DARK := "M"
const STONE := "m"
const INK := "e"
const WOOD := "T"
const PAPER := "x"
const RED := "R"


## 井口碑，16×24：碑座、碑身、水泡出的白痕，只剩一个像「秦」的残字。
## 不写别人的名字——故事里那二十七个字被水冲平了。
static func stele() -> Image:
	var img := Px.new_img(16, 24)
	var dark: Color = Palette.c(STONE_DARK)
	var mid: Color = Palette.c(STONE)
	var light: Color = _stone_light()
	var ink: Color = Palette.c(INK)
	# 碑座
	Px.rect(img, 2, 21, 12, 3, dark)
	Px.rect(img, 3, 20, 10, 1, mid)
	# 碑身：上圆下方，两侧压暗
	Px.rect(img, 4, 2, 8, 19, mid)
	Px.rect(img, 3, 4, 1, 17, dark)
	Px.rect(img, 12, 4, 1, 17, dark)
	Px.rect(img, 5, 1, 6, 1, mid)
	Px.rect(img, 6, 0, 4, 1, light)
	# 水泡的白痕，歪歪地横过碑面（不用三元，按列算高度）
	for x in range(5, 12):
		var y := 13
		if x % 3 == 0:
			y = 12
		Px.px(img, x, y, light)
	# 只剩一个还认得出的刻字：一横、一竖、一点，像「秦」的残笔
	Px.rect(img, 6, 6, 4, 1, ink)
	Px.rect(img, 7, 7, 1, 4, ink)
	Px.rect(img, 9, 8, 1, 3, ink)
	Px.px(img, 8, 11, ink)
	return Px.outline(img)


static func _stone_light() -> Color:
	# 从 m 提亮一档，仍落在灰石色系，不引入新色相
	return Palette.c(STONE).lightened(0.28)


## 钉在侧墙的旧告示，14×16：泛黄的纸、卷角、图钉、几行看不清的字。
## 落款那行特意涂掉，一个名字都不留。
static func wall_notice() -> Image:
	var img := Px.new_img(14, 16)
	var paper: Color = Palette.c(PAPER)
	var wood: Color = Palette.c(WOOD)
	var ink: Color = Palette.c(INK)
	var red: Color = Palette.c(RED)
	# 纸
	Px.rect(img, 1, 1, 12, 14, paper)
	Px.rect(img, 0, 2, 1, 12, paper)
	Px.rect(img, 13, 3, 1, 11, paper)
	# 卷角
	Px.px(img, 12, 14, wood)
	Px.px(img, 11, 14, wood)
	# 图钉
	Px.px(img, 6, 1, red)
	# 三行模糊的字：断断续续，不是真字
	for row in 3:
		var y := 4 + row * 3
		for x in range(2, 12):
			if (x + row * 2) % 3 != 0:
				Px.px(img, x, y, ink)
	# 落款一行：整片抹掉
	Px.rect(img, 4, 13, 8, 1, ink)
	return Px.outline(img)
