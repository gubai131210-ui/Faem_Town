class_name TermDef
extends RefCounted
## 一个节气的定义，来自 data/solar_terms.json。表里的顺序就是一年里的顺序，每个节气 4 天。

var id: StringName
var name: String
var season: StringName
## 这个节气的规则变化，一句话
var note: String = ""
## 这条规则是否已经在游戏里生效；没生效的不向玩家提示
var live := false


static func from_dict(d: Dictionary) -> TermDef:
	var def := TermDef.new()
	def.id = StringName(str(d.get("id", "")))
	def.name = str(d.get("name", ""))
	def.season = StringName(str(d.get("season", "")))
	def.note = str(d.get("note", ""))
	def.live = bool(d.get("live", false))
	return def
