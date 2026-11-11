class_name ItemDef
extends RefCounted
## 一种物品的定义，来自 data/items.json。

const KINDS: Array[StringName] = [&"tool", &"seed", &"crop", &"misc"]

var id: StringName
var name: String
var kind: StringName
var icon: String
var stack: int = 99
var price: int = 0
var desc: String = ""
## 种子对应的作物 id，其他物品为空
var crop: StringName = &""


static func from_dict(d: Dictionary) -> ItemDef:
	var def := ItemDef.new()
	def.id = StringName(str(d.get("id", "")))
	def.name = str(d.get("name", ""))
	def.kind = StringName(str(d.get("kind", "misc")))
	def.icon = str(d.get("icon", ""))
	def.stack = int(d.get("stack", 99))
	def.price = int(d.get("price", 0))
	def.desc = str(d.get("desc", ""))
	def.crop = StringName(str(d.get("crop", "")))
	return def
