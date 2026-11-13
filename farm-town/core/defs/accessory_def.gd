class_name AccessoryDef
extends RefCounted
## 一件饰品，来自 data/accessories.json。同时也是一种物品（kind 是 accessory）。
## 身上能戴两件（Mine.equipped）；一件饰品只有一种效果，效果的大小是 value。

## armor 挨打少掉多少（比例）、lifesteal 打倒一只回多少生命、wade 蹚水不减速、roll_grace 翻滚完多几秒打不着、
## oil_saver 灯油少烧多少（比例）、power 武器多打多少（比例）、glow 灯多照多远（比例）
const EFFECTS: Array[StringName] = [&"armor", &"lifesteal", &"wade", &"roll_grace", &"oil_saver", &"power", &"glow"]

var id: StringName
var name: String
var effect: StringName
var value := 0.0
## 石叔打这一件收多少钱；0 是不打（首领掉的）
var price := 0
## 石叔打这一件还要的材料：[{"item": 物品 id, "count": 几个}]
var materials: Array[Dictionary] = []
var desc := ""


static func from_dict(d: Dictionary) -> AccessoryDef:
	var def := AccessoryDef.new()
	def.id = StringName(str(d.get("id", "")))
	def.name = str(d.get("name", ""))
	def.effect = StringName(str(d.get("effect", "")))
	def.value = float(d.get("value", 0.0))
	def.price = int(d.get("price", 0))
	def.desc = str(d.get("desc", ""))
	var list: Variant = d.get("materials", [])
	if list is Array:
		for entry: Variant in list:
			if entry is Dictionary:
				var e: Dictionary = entry
				def.materials.append({"item": StringName(str(e.get("item", ""))), "count": int(e.get("count", 1))})
	return def


## 登记进物品表的那一份。
func as_item() -> ItemDef:
	var item := ItemDef.new()
	item.id = id
	item.name = name
	item.kind = &"accessory"
	item.icon = "accessory:" + String(id)
	item.stack = 1
	item.price = price
	item.desc = desc + "拿在手里按使用键戴上或摘下。"
	return item


## 材料写成一句话：“银矿石×5、石英×2”。
func materials_text() -> String:
	var parts: PackedStringArray = []
	for m in materials:
		var item: StringName = m["item"]
		parts.append("%s×%d" % [Database.item(item).name if Database.has_item(item) else String(item), int(m["count"])])
	return "、".join(parts)
