class_name Palette
extends RefCounted
## 全项目唯一的调色板，来自 data/palette.json。Blender 脚本读的是同一个文件。

const PATH := "res://data/palette.json"

static var _colors: Dictionary = {}


## 返回 {单字符键: Color}，字符画里的每个字符对应一种颜色。
static func colors() -> Dictionary:
	if _colors.is_empty():
		var raw: Dictionary = JsonFile.read_dict(PATH)
		for key: String in raw:
			# "ramps" 是 Blender 物件用的三段明暗色，不属于字符画
			if raw[key] is String:
				var hex: String = raw[key]
				_colors[key] = Color.html(hex)
	return _colors


static func c(key: String) -> Color:
	var all := colors()
	if not all.has(key):
		push_error("调色板里没有颜色 '%s'" % key)
		return Color.MAGENTA
	var col: Color = all[key]
	return col
