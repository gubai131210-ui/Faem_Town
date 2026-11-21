class_name DishArt
extends RefCounted
## 菜的四帧图。桌上和席面用同一张，帧在动（热气、油光）。


static var _sheets: Dictionary = {}
static var _frames: Dictionary = {}
static var _plate: ImageTexture


static func frame(id: StringName, index: int) -> Texture2D:
	var key := String(id) + "/%d" % (index % 4)
	if _frames.has(key):
		return _frames[key]
	var sheet := _sheet(id)
	if sheet == null:
		return plate()
	var chip := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	chip.blit_rect(sheet, Rect2i((index % 4) * 32, 0, 32, 32), Vector2i.ZERO)
	var tex := ImageTexture.create_from_image(chip)
	_frames[key] = tex
	return tex


static func plate() -> Texture2D:
	if _plate != null:
		return _plate
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 32:
		for x in 32:
			var dx := x - 15
			var dy := y - 18
			if dx * dx + dy * dy * 2 < 90:
				img.set_pixel(x, y, Color("f4efe4"))
			elif dx * dx + dy * dy * 2 < 130:
				img.set_pixel(x, y, Color("c8bfb0"))
	_plate = ImageTexture.create_from_image(img)
	return _plate


static func _sheet(id: StringName) -> Image:
	if _sheets.has(id):
		return _sheets[id]
	var path := "res://art/food/%s.png" % id
	var img: Image = null
	if FileAccess.file_exists(path):
		img = Image.load_from_file(ProjectSettings.globalize_path(path))
	_sheets[id] = img
	return img
