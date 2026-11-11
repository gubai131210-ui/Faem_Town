class_name CropDef
extends RefCounted
## 一种作物的定义，来自 data/crops.json。

var id: StringName
var name: String
var seed: StringName
var produce: StringName
## 每个生长阶段需要的（浇过水的）天数；阶段数 = 数组长度 + 1，最后一个阶段是成熟
var stage_days: Array[int] = []
var seasons: Array[StringName] = []


static func from_dict(d: Dictionary) -> CropDef:
	var def := CropDef.new()
	def.id = StringName(str(d.get("id", "")))
	def.name = str(d.get("name", ""))
	def.seed = StringName(str(d.get("seed", "")))
	def.produce = StringName(str(d.get("produce", "")))
	var days: Array = d.get("stage_days", [])
	for v: Variant in days:
		def.stage_days.append(int(v))
	var ss: Array = d.get("seasons", [])
	for v: Variant in ss:
		def.seasons.append(StringName(str(v)))
	return def


func total_days() -> int:
	var total := 0
	for n in stage_days:
		total += n
	return total


## 已生长 days 天时处于第几个阶段，0 是刚播种，stage_days.size() 是成熟。
func stage_for(days: int) -> int:
	var acc := 0
	for i in stage_days.size():
		acc += stage_days[i]
		if days < acc:
			return i
	return stage_days.size()


func is_ripe(days: int) -> bool:
	return days >= total_days()
