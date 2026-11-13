class_name QuestDef
extends RefCounted
## 公告栏上的一张委托，来自 data/quests.json：某位居民要几个什么东西，送到给钱，有的还给一件遗物。

var id: StringName
var npc: StringName
var item: StringName
var count := 1
var money := 0
var relic: StringName = &""
## 第几天起会贴到公告栏上
var from_day := 1
var title: String
var text: String


static func from_dict(d: Dictionary) -> QuestDef:
	var def := QuestDef.new()
	def.id = StringName(str(d.get("id", "")))
	def.npc = StringName(str(d.get("npc", "")))
	def.item = StringName(str(d.get("item", "")))
	def.count = int(d.get("count", 1))
	def.money = int(d.get("money", 0))
	def.relic = StringName(str(d.get("relic", "")))
	def.from_day = int(d.get("from_day", 1))
	def.title = str(d.get("title", ""))
	def.text = str(d.get("text", ""))
	return def


## 交付时对方说的话在对话文件里的段落名。
func dialogue_title() -> String:
	return "quest_" + String(id)
