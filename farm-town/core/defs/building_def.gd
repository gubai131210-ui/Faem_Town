class_name BuildingDef
extends RefCounted
## 农场上能请青竹盖的一栋建筑，来自 data/buildings.json。
## 每栋建筑在农场上有固定的位置（site 是正面墙根中点所在的格子），盖好以后不能挪。

var id: StringName
var name: String
## 盖好以后用的物件名（art/props）
var prop: String
## 盖之前要多少钱、盖几天
var price := 0
var days := 1
## 占地几格宽、几格深（从 site 那一行往北数；屋顶遮住的那几排也算进去，免得人走到屋顶后面）
var width := 1
var depth := 1
## 正面墙根中点在农场的哪一格；门在正面墙的哪一格（x 偏移，相对最西一格）
var site := Vector2i.ZERO
var door := 0
## 能住几只动物
var capacity := 0
## 动物白天在哪片草地上活动：农场上的格子矩形，表里写 [x0, y0, x1, y1]
var yard := Rect2i()
## 会水的动物还能去的那片水面，同样是 [x0, y0, x1, y1]；没有就是空
var swim := Rect2i()
## 青竹要哪盏灯亮了才接这个活（GameState 的标记）
var flag: StringName = &"lamp_plaza"
## 要先有哪栋建筑（空表示不用）
var requires: StringName = &""
var desc: String


static func from_dict(d: Dictionary) -> BuildingDef:
	var def := BuildingDef.new()
	def.id = StringName(str(d.get("id", "")))
	def.name = str(d.get("name", ""))
	def.prop = str(d.get("prop", def.id))
	def.price = int(d.get("price", 0))
	def.days = int(d.get("days", 1))
	def.width = int(d.get("width", 1))
	def.depth = int(d.get("depth", 1))
	var s: Variant = d.get("site", [0, 0])
	if s is Array and s.size() >= 2:
		def.site = Vector2i(int(s[0]), int(s[1]))
	def.door = int(d.get("door", 0))
	def.capacity = int(d.get("capacity", 0))
	var y: Variant = d.get("yard", [])
	if y is Array and y.size() >= 4:
		def.yard = Rect2i(int(y[0]), int(y[1]), int(y[2]) - int(y[0]) + 1, int(y[3]) - int(y[1]) + 1)
	var w: Variant = d.get("swim", [])
	if w is Array and w.size() >= 4:
		def.swim = Rect2i(int(w[0]), int(w[1]), int(w[2]) - int(w[0]) + 1, int(w[3]) - int(w[1]) + 1)
	def.flag = StringName(str(d.get("flag", "lamp_plaza")))
	def.requires = StringName(str(d.get("requires", "")))
	def.desc = str(d.get("desc", ""))
	return def


## 占地的格子：site 那一行往北 depth 行、从 site.x - width/2 起 width 列。
func footprint() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var x0 := site.x - width / 2
	for y in range(site.y - depth + 1, site.y + 1):
		for x in range(x0, x0 + width):
			out.append(Vector2i(x, y))
	return out


## 占地加上院子、再往外一圈：这里不长野生的树和石头。
func keeps_clear(t: Vector2i) -> bool:
	var x0 := site.x - width / 2
	var around := Rect2i(x0 - 1, site.y - depth, width + 2, depth + 2)
	return around.has_point(t) or yard.has_point(t)


## 门口那一格（正面墙外、人站的地方）。
func door_tile() -> Vector2i:
	return Vector2i(site.x - width / 2 + door, site.y + 1)


## 正面墙根中点的像素位置，物件的锚点放这里。
func anchor_px() -> Vector2:
	var x0 := site.x - width / 2
	return Vector2((x0 + width / 2.0) * GameMap.TS, (site.y + 1) * GameMap.TS)
