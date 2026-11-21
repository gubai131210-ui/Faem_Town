class_name PlaceClueArt
extends RefCounted
## 灯亮以后各处能翻能看的小东西（决策 125）。
## 纯代码逐像素画，颜色只从 palette.json 取。不写人名，匾上也不添字。

const PAPER := "x"
const PAPER_DK := "X"
const INK := "e"
const RED := "R"
const WOOD := "w"
const WOOD_DK := "T"
const STONE := "m"
const STONE_DK := "M"
const SKY := "b"
const SEA := "g"
const SEA_DK := "G"
const LAMP := "q"


## 钉在墙上的小纸，12×16：卷角、图钉、几行看不清的字，落款涂掉。
static func slip() -> Image:
	var img := Px.new_img(12, 16)
	var paper: Color = Palette.c(PAPER)
	var ink: Color = Palette.c(INK)
	Px.rect(img, 1, 1, 10, 13, paper)
	Px.rect(img, 2, 14, 8, 1, paper)
	Px.px(img, 10, 14, Palette.c(WOOD_DK))
	Px.px(img, 9, 14, Palette.c(WOOD))
	Px.px(img, 5, 2, Palette.c(RED))
	for row in 3:
		var y := 4 + row * 3
		for x in range(2, 10):
			if (x + row) % 3 != 0:
				Px.px(img, x, y, ink)
	Px.rect(img, 3, 13, 6, 1, ink)
	return Px.outline(img)


## 戏台边的一叠折纸，14×12：两层纸，中间一道红线，没有字。
static func booklet() -> Image:
	var img := Px.new_img(14, 12)
	Px.rect(img, 3, 1, 9, 8, Palette.c(PAPER_DK))
	Px.rect(img, 2, 3, 9, 8, Palette.c(PAPER))
	Px.rect(img, 2, 6, 9, 1, Palette.c(RED))
	Px.rect(img, 3, 8, 7, 1, Palette.c(INK))
	return Px.outline(img)


## 磨坊侧墙的木牌，18×16：左边两组记满的道道，右边只画了两笔，后头是空木板。
static func tally() -> Image:
	var img := Px.new_img(18, 16)
	var wood: Color = Palette.c(WOOD)
	var edge: Color = Palette.c(WOOD_DK)
	var ink: Color = Palette.c(INK)
	Px.rect(img, 1, 1, 16, 14, wood)
	Px.rect(img, 1, 1, 16, 1, edge)
	Px.rect(img, 1, 14, 16, 1, edge)
	Px.rect(img, 1, 1, 1, 14, edge)
	Px.rect(img, 16, 1, 1, 14, edge)
	for g in 2:
		var x0 := 3 + g * 4
		for i in 4:
			Px.rect(img, x0, 3 + i * 2, 1, 2, ink)
		Px.line(img, Vector2i(x0, 11), Vector2i(x0 + 2, 3), ink)
	Px.rect(img, 11, 3, 1, 2, ink)
	Px.rect(img, 11, 6, 1, 2, ink)
	return Px.outline(img)


## 画室东墙的一角，20×16：左边一座石塔，塔顶一点黄，右边是海。
static func canvas() -> Image:
	var img := Px.new_img(20, 16)
	var paper: Color = Palette.c(PAPER)
	Px.rect(img, 1, 1, 18, 14, paper)
	Px.rect(img, 2, 2, 16, 6, Palette.c(SKY))
	Px.rect(img, 2, 8, 16, 6, Palette.c(SEA))
	Px.rect(img, 2, 8, 16, 1, Palette.c(SEA_DK))
	Px.rect(img, 4, 4, 5, 9, Palette.c(STONE))
	Px.rect(img, 4, 4, 1, 9, Palette.c(STONE_DK))
	Px.rect(img, 5, 3, 3, 2, Palette.c(STONE_DK))
	Px.rect(img, 5, 5, 2, 2, Palette.c(LAMP))
	Px.px(img, 15, 3, Palette.c(LAMP))
	Px.px(img, 17, 13, Palette.c(WOOD_DK))
	Px.px(img, 16, 13, Palette.c(WOOD))
	return Px.outline(img)
