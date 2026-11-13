class_name RelicDef
extends RefCounted
## 一件遗物，来自 data/relics.json。遗物同时也是一种物品（kind 是 relic），物品部分由 Database 一起登记。

## 从哪儿来："fog" 雾天在地上捡到（雾天和清明也能钓到）、"fishing" 只能钓到、"quest" 委托的报酬、"mine" 井里的忘形掉的、"story" 主线里固定的地方得到、"later" 以后的玩法才出
const SOURCES: Array[StringName] = [&"fog", &"fishing", &"quest", &"mine", &"story", &"later"]

var id: StringName
var name: String
var desc: String
## 图标的形状名，交给 ItemArt.relic 画
var shape: String
## 对应哪位居民的第几级忆；纯收藏或点灯用的遗物没有居民，level 为 0
var npc: StringName = &""
var level := 0
var found: StringName = &"later"


static func from_dict(d: Dictionary) -> RelicDef:
	var def := RelicDef.new()
	def.id = StringName(str(d.get("id", "")))
	def.name = str(d.get("name", ""))
	def.desc = str(d.get("desc", ""))
	def.shape = str(d.get("shape", ""))
	def.npc = StringName(str(d.get("npc", "")))
	def.level = int(d.get("level", 0))
	def.found = StringName(str(d.get("found", "later")))
	return def


## 这件遗物作为物品的定义。
func as_item() -> ItemDef:
	var item := ItemDef.new()
	item.id = id
	item.name = name
	item.kind = &"relic"
	item.icon = "relic:" + String(id)
	item.stack = 1
	item.price = 0
	item.desc = desc
	return item
