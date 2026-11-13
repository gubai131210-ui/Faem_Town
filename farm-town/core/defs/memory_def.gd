class_name MemoryDef
extends RefCounted
## 一位居民的一级忆，来自 data/memories.json。归还对应的遗物就找回这段记忆。

var npc: StringName
var level := 1
var relic: StringName
## 忆簿里的标题和“那是什么时候”
var title: String
var when: String
## 在忆簿时间线上的位置：出事那天是 0，之前为负，之后为正
var order := 0
## 忆簿里记下的一句话
var text: String


static func from_dict(d: Dictionary) -> MemoryDef:
	var def := MemoryDef.new()
	def.npc = StringName(str(d.get("npc", "")))
	def.level = int(d.get("level", 1))
	def.relic = StringName(str(d.get("relic", "")))
	def.title = str(d.get("title", ""))
	def.when = str(d.get("when", ""))
	def.order = int(d.get("order", 0))
	def.text = str(d.get("text", ""))
	return def


## 对话文件里这段记忆的段落名。
func dialogue_title() -> String:
	return "memory_%d" % level
