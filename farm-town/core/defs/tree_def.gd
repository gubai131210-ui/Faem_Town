class_name TreeDef
extends RefCounted
## 一种果树的定义，来自 data/trees.json。

var id: StringName
var name: String
## 树苗的物品 id
var sapling: StringName
## 种下后长成要多少天
var grow_days := 24
## 常绿：冬天不落叶
var evergreen := false
## 各个季节结什么：每项是 {"season": 季节 id, "item": 物品 id, "color": 颜色, "flower": 是否是花}
var yields: Array[Dictionary] = []
## 画法参数，见 art_gen/tree_art.gd
var art: Dictionary = {}


static func from_dict(d: Dictionary) -> TreeDef:
	var def := TreeDef.new()
	def.id = StringName(str(d.get("id", "")))
	def.name = str(d.get("name", ""))
	def.sapling = StringName(str(d.get("sapling", "")))
	def.grow_days = int(d.get("grow_days", 24))
	def.evergreen = bool(d.get("evergreen", false))
	var list: Array = d.get("yields", [])
	for v: Variant in list:
		if v is Dictionary:
			def.yields.append(v)
	var a: Variant = d.get("art", {})
	if a is Dictionary:
		def.art = a
	return def


## 这个季节结的东西；不结就返回空。
func produce_in(season: StringName) -> StringName:
	for y in yields:
		if str(y.get("season", "")) == String(season):
			return StringName(str(y.get("item", "")))
	return &""


## 结某种东西时的那条记录；没有就返回空字典。
func yield_of(item: StringName) -> Dictionary:
	for y in yields:
		if str(y.get("item", "")) == String(item):
			return y
	return {}
