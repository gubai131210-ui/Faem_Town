class_name LampDef
extends RefCounted
## 一盏主线石灯，来自 data/lamps.json：点亮它要供上哪些东西，再加一件关键遗物。

var id: StringName
var name: String
var map: StringName
## 供品：物品 id -> 数量，按表里的顺序
var offerings: Dictionary[StringName, int] = {}
var relic: StringName = &""
## 灯座上刻的字（供品清单的说法）和点亮时的旁白
var inscription: String
var lit_text: String


static func from_dict(d: Dictionary) -> LampDef:
	var def := LampDef.new()
	def.id = StringName(str(d.get("id", "")))
	def.name = str(d.get("name", ""))
	def.map = StringName(str(d.get("map", "")))
	var list: Variant = d.get("offerings", [])
	if list is Array:
		for e: Variant in list:
			if e is Dictionary:
				def.offerings[StringName(str(e.get("item", "")))] = int(e.get("count", 1))
	def.relic = StringName(str(d.get("relic", "")))
	def.inscription = str(d.get("inscription", ""))
	def.lit_text = str(d.get("lit_text", ""))
	return def


## 点亮以后记在 GameState 里的标记名。
func flag() -> StringName:
	return StringName("lamp_" + String(id))
