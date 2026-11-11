extends Node
## 全局数据库：启动时读入 data/ 下的内容表，转成带类型的定义对象，并校验表之间的引用。

const ITEMS_PATH := "res://data/items.json"
const CROPS_PATH := "res://data/crops.json"
const SEASON_IDS: Array[StringName] = [&"spring", &"summer", &"autumn", &"winter"]

var items: Dictionary[StringName, ItemDef] = {}
var crops: Dictionary[StringName, CropDef] = {}


func _ready() -> void:
	reload()
	for msg in validate():
		push_error("数据表错误：" + msg)


func reload() -> void:
	items.clear()
	crops.clear()
	for entry: Variant in JsonFile.read_array(ITEMS_PATH):
		if entry is Dictionary:
			var def := ItemDef.from_dict(entry)
			items[def.id] = def
	for entry: Variant in JsonFile.read_array(CROPS_PATH):
		if entry is Dictionary:
			var def := CropDef.from_dict(entry)
			crops[def.id] = def


func item(id: StringName) -> ItemDef:
	var def: ItemDef = items.get(id)
	if def == null:
		push_error("没有这个物品：%s" % id)
	return def


func has_item(id: StringName) -> bool:
	return items.has(id)


func crop(id: StringName) -> CropDef:
	var def: CropDef = crops.get(id)
	if def == null:
		push_error("没有这个作物：%s" % id)
	return def


func has_crop(id: StringName) -> bool:
	return crops.has(id)


## 检查所有表，返回错误信息列表；空列表表示没有问题。
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if items.is_empty():
		errors.append("物品表是空的")
	for id: StringName in items:
		var it: ItemDef = items[id]
		if String(id).is_empty() or String(id) != String(id).to_snake_case():
			errors.append("物品 id 必须是小写下划线：'%s'" % id)
		if it.name.is_empty():
			errors.append("物品 %s 没有名称" % id)
		if not ItemDef.KINDS.has(it.kind):
			errors.append("物品 %s 的种类无效：%s" % [id, it.kind])
		if it.stack < 1:
			errors.append("物品 %s 的堆叠上限必须大于 0" % id)
		if it.kind == &"seed" and not crops.has(it.crop):
			errors.append("种子 %s 指向不存在的作物：%s" % [id, it.crop])
	for id: StringName in crops:
		var cr: CropDef = crops[id]
		if not items.has(cr.seed):
			errors.append("作物 %s 的种子不存在：%s" % [id, cr.seed])
		elif items[cr.seed].crop != id:
			errors.append("作物 %s 的种子 %s 没有指回这个作物" % [id, cr.seed])
		if not items.has(cr.produce):
			errors.append("作物 %s 的产物不存在：%s" % [id, cr.produce])
		if cr.stage_days.is_empty():
			errors.append("作物 %s 没有生长阶段" % id)
		for n in cr.stage_days:
			if n < 1:
				errors.append("作物 %s 的阶段天数必须大于 0" % id)
		if cr.seasons.is_empty():
			errors.append("作物 %s 没有可种植的季节" % id)
		for s in cr.seasons:
			if not SEASON_IDS.has(s):
				errors.append("作物 %s 的季节无效：%s" % [id, s])
	return errors
