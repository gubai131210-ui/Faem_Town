class_name ForageDef
extends RefCounted
## 一种野外采集物的出现规则，来自 data/forage.json。

var item: StringName
var season: StringName
## 同季节里被抽中的权重
var weight := 1
## 从这个节气起才出现；空表示整季都有
var from_term: StringName = &""
## from_term 在一年里的序号，由 Database 填；-1 表示不限
var from_term_index := -1
## 长在水边
var shore := false
## 赶海的东西：只出现在沙滩上（东滩）。季节可以不写，表示一年四季都有
var beach := false
## 到了这个节气权重换成 boost_weight（蘑菇在寒露大量生长）；空表示没有这回事
var boost_term: StringName = &""
## boost_term 在一年里的序号，由 Database 填；-1 表示不限
var boost_term_index := -1
var boost_weight := 0


static func from_dict(d: Dictionary) -> ForageDef:
	var def := ForageDef.new()
	def.item = StringName(str(d.get("item", "")))
	def.season = StringName(str(d.get("season", "")))
	def.weight = int(d.get("weight", 1))
	def.from_term = StringName(str(d.get("from_term", "")))
	def.shore = bool(d.get("shore", false))
	def.beach = bool(d.get("beach", false))
	def.boost_term = StringName(str(d.get("boost_term", "")))
	def.boost_weight = int(d.get("boost_weight", 0))
	return def


## 这个季节有没有。
func in_season(now: StringName) -> bool:
	return season == &"" or season == now


## 一年里第 term_index 个节气时是否已经出现。
func available(term_index: int) -> bool:
	return from_term_index < 0 or term_index < 0 or posmod(term_index, 24) >= from_term_index


## 这个节气里被抽中的权重：到了 boost_term 那几天就换成 boost_weight。
func weight_at(term_index: int) -> int:
	if boost_weight > 0 and boost_term_index >= 0 and term_index >= 0 and posmod(term_index, 24) == boost_term_index:
		return boost_weight
	return weight
