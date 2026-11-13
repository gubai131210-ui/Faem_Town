class_name ItemDef
extends RefCounted
## 一种物品的定义，来自 data/items.json。

const KINDS: Array[StringName] = [&"tool", &"seed", &"sapling", &"crop", &"forage", &"fertilizer", &"misc", &"relic", &"fish", &"gear", &"feed", &"product", &"food", &"ore", &"weapon", &"accessory"]
## 品质对售价的倍数：普通、良、优
const QUALITY_MULT: Array[float] = [1.0, 1.25, 1.5]
const QUALITY_NAMES: Array[String] = ["", "良", "优"]

var id: StringName
var name: String
var kind: StringName
var icon: String
var stack: int = 99
var price: int = 0
var desc: String = ""
## 种子对应的作物 id，其他物品为空
var crop: StringName = &""
## 树苗种出来的果树 id，其他物品为空
var tree: StringName = &""
## 这是哪个季节的花（养蜂时用）；不是花就为空
var flower: StringName = &""
## 能升级的工具（锄头、水壶）：名字和图标带材质
var tiered := false
## 肥料的肥力，其他物品为 0
var power := 0
## 食物：吃了回多少体力；是不是热食（小寒那几天翻倍）；带什么增益、管多少分钟
var energy := 0
var hot := false
var buff: StringName = &""
var buff_minutes := 0


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
	def.power = int(d.get("power", 0))
	def.tiered = bool(d.get("tiered", false))
	def.tree = StringName(str(d.get("tree", "")))
	def.flower = StringName(str(d.get("flower", "")))
	def.energy = int(d.get("energy", 0))
	def.hot = bool(d.get("hot", false))
	def.buff = StringName(str(d.get("buff", "")))
	def.buff_minutes = int(d.get("buff_minutes", 0))
	return def


## 某个品质的售价。
func price_for(quality: int) -> int:
	return roundi(price * QUALITY_MULT[clampi(quality, 0, 2)])


## 能不能放进出货箱卖掉。工具和种子不收。
func sellable() -> bool:
	return price > 0 and (kind == &"crop" or kind == &"forage" or kind == &"misc" or kind == &"fish" or kind == &"product" or kind == &"food" or kind == &"ore")
