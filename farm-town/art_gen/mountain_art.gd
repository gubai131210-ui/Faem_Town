class_name MountainArt
extends RefCounted
## 后山的冰面和崖洞口（决策 127）。颜色只从 palette.json 取。


## 一格冻上的溪，16×16。薄冰，中间一道裂纹。
static func ice() -> Image:
	var img := Px.new_img(16, 16)
	var pale: Color = Palette.c("x")
	var shade: Color = Palette.c("g")
	Px.rect(img, 0, 0, 16, 16, pale)
	Px.rect(img, 0, 14, 16, 2, shade)
	Px.px(img, 4, 6, shade)
	Px.px(img, 5, 7, shade)
	Px.px(img, 6, 8, shade)
	Px.px(img, 7, 8, shade)
	Px.px(img, 8, 9, shade)
	return img


## 崖洞口，18×22。石头围着一个黑口。
static func cave() -> Image:
	var img := Px.new_img(18, 22)
	var stone: Color = Palette.c("m")
	var dark: Color = Palette.c("M")
	var hole: Color = Palette.c("e")
	Px.rect(img, 2, 6, 14, 14, stone)
	Px.rect(img, 4, 8, 10, 10, dark)
	Px.rect(img, 6, 10, 6, 8, hole)
	Px.rect(img, 3, 18, 12, 2, dark)
	return Px.outline(img)


## 鲛人换下来的珠，8×8。留在洞口的沙上。
static func pearl() -> Image:
	var img := Px.new_img(8, 8)
	var shine: Color = Palette.c("x")
	var warm: Color = Palette.c("b")
	Px.rect(img, 2, 2, 4, 4, shine)
	Px.px(img, 3, 3, warm)
	return Px.outline(img)
