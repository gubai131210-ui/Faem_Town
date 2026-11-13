class_name RecipeDef
extends RefCounted
## 一道菜的做法，来自 data/recipes.json。id 就是做出来的那样食物的物品 id。

## 菜谱从哪儿来："start" 一开始就会，"yunniang" 云娘教，"memory" 忆到某一级就会
const SOURCES: Array[StringName] = [&"start", &"yunniang", &"memory"]

var id: StringName
var from: StringName = &"start"
## from 是 memory 时：谁的忆、到第几级
var teacher: StringName = &""
var need_level := 1
## 物品 id -> 要几个
var ingredients: Dictionary[StringName, int] = {}


static func from_dict(d: Dictionary) -> RecipeDef:
	var def := RecipeDef.new()
	def.id = StringName(str(d.get("id", "")))
	def.from = StringName(str(d.get("from", "start")))
	def.teacher = StringName(str(d.get("teacher", "")))
	def.need_level = int(d.get("need", 1))
	var raw: Variant = d.get("ingredients", {})
	if raw is Dictionary:
		var dict: Dictionary = raw
		for key: Variant in dict:
			def.ingredients[StringName(str(key))] = int(dict[key])
	return def


## 学会以后记的标记。
func known_flag() -> StringName:
	return StringName("recipe_" + String(id))


## “白萝卜 ×2、鲫鱼 ×1”
func ingredients_text() -> String:
	var parts := PackedStringArray()
	for item_id: StringName in ingredients:
		var item_name := Database.item(item_id).name if Database.has_item(item_id) else String(item_id)
		parts.append("%s ×%d" % [item_name, ingredients[item_id]])
	return "、".join(parts)
