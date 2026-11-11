class_name Px
extends RefCounted
## 像素绘制的底层工具：字符画转图片、自动描边、画线等。

const DIRS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]


static func new_img(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


## 把字符画转成图片，"." 为透明，其余字符查调色板。
static func ascii(rows: Array, pal: Dictionary) -> Image:
	var h := rows.size()
	var first: String = rows[0]
	var w := first.length()
	var img := new_img(w, h)
	for y in h:
		var row: String = rows[y]
		for x in mini(w, row.length()):
			var ch := row[x]
			if ch != "." and pal.has(ch):
				var c: Color = pal[ch]
				img.set_pixel(x, y, c)
	return img


static func blit(dst: Image, src: Image, x: int, y: int) -> void:
	dst.blend_rect(src, Rect2i(0, 0, src.get_width(), src.get_height()), Vector2i(x, y))


static func px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


static func rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			px(img, xx, yy, c)


static func line(img: Image, a: Vector2i, b: Vector2i, c: Color) -> void:
	var x0 := a.x
	var y0 := a.y
	var dx := absi(b.x - x0)
	var dy := -absi(b.y - y0)
	var sx := 1 if x0 < b.x else -1
	var sy := 1 if y0 < b.y else -1
	var err := dx + dy
	while true:
		px(img, x0, y0, c)
		if x0 == b.x and y0 == b.y:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy


static func darken(c: Color) -> Color:
	return Color(c.r * 0.36 + 0.03, c.g * 0.3 + 0.01, c.b * 0.38 + 0.06, 1.0)


## 给不透明区域外侧加一圈描边，描边颜色取相邻像素的暗色，比纯黑柔和。
static func outline(img: Image) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var out: Image = img.duplicate()
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.0:
				continue
			for d in DIRS:
				var nx := x + d.x
				var ny := y + d.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var n := img.get_pixel(nx, ny)
				if n.a > 0.5:
					out.set_pixel(x, y, darken(n))
					break
	return out


static func h2(x: int, y: int) -> int:
	var n := x * 374761393 + y * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	return (n ^ (n >> 16)) & 0x7fffffff


static func tex(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)


static func flipped(img: Image) -> Image:
	var o: Image = img.duplicate()
	o.flip_x()
	return o
