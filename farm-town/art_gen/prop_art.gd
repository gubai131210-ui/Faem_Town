class_name PropArt
extends RefCounted
## Blender 渲染的大件物件（房子、家具、树……），由 tools/props.py 生成到 art/props/。
## 每张图有一个锚点：物件脚下的参考点。把精灵放在地图上的某个位置，锚点就落在那里。

const DIR := "res://art/props/"

static var _desc: Dictionary = {}


static func has(prop: String) -> bool:
	return _all().has(prop)


static func texture(prop: String) -> Texture2D:
	if not has(prop):
		push_error("没有这个物件素材：%s（先运行 tools/props.py）" % prop)
		return null
	return load(DIR + prop + ".png") as Texture2D


static func anchor(prop: String) -> Vector2:
	var info: Dictionary = _all().get(prop, {})
	var a: Array = info.get("anchor", [0, 0])
	return Vector2(float(a[0]), float(a[1]))


## 建一个精灵，锚点对齐到 pos。
static func sprite(prop: String, pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = texture(prop)
	s.centered = false
	s.offset = -anchor(prop)
	s.position = pos
	return s


static func _all() -> Dictionary:
	if _desc.is_empty():
		_desc = JsonFile.read_dict(DIR + "props.json")
	return _desc
