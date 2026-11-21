class_name RecipeDef
extends RefCounted
## 一道菜的做法，来自 data/recipes.json。id 就是做出来的那样食物的物品 id。

## 菜谱从哪儿来："start" 一开始就会，"yunniang" 云娘教，"memory" 忆到某一级就会。
## "odd" 是试失败的那一碗，不会出现在菜谱上。
const SOURCES: Array[StringName] = [&"start", &"yunniang", &"memory", &"odd"]
## 残页会掉的地方：井里、雾天的地上、山野。
const SCRAP_PLACES: Array[StringName] = [&"mine", &"fog", &"wild"]
## 四道酱料菜的残页：墨色，和给玩家看的颜色字。左右两半用同一种墨。
const SCRAP_INK: Dictionary[StringName, String] = {
	&"soy_greens": "3d7a3a", &"vinegar_napa": "6a4030",
	&"wine_perch": "a84848", &"sugar_roast": "c88820",
}
const SCRAP_WORD: Dictionary[StringName, String] = {
	&"soy_greens": "绿", &"vinegar_napa": "褐",
	&"wine_perch": "红", &"sugar_roast": "黄",
}

var id: StringName
var from: StringName = &"start"
## from 是 memory 时：谁的忆、到第几级
var teacher: StringName = &""
var need_level := 1
## 物品 id -> 要几个
var ingredients: Dictionary[StringName, int] = {}
## 灶上的做法：切、炒、蒸、炖、炸、煮、拌、烤。过程动画按这个播。
const METHODS: Array[StringName] = [&"cut", &"stir", &"steam", &"stew", &"fry", &"boil", &"mix", &"roast"]
const METHOD_NAMES := {
	&"cut": "切", &"stir": "炒", &"steam": "蒸", &"stew": "炖",
	&"fry": "炸", &"boil": "煮", &"mix": "拌", &"roast": "烤",
}
var method: StringName = &"boil"
## 这道菜算哪个季节的。空着表示一年到头都能做（鸡蛋、米、干货）。
var season: StringName = &""
## 对上节气时写节气 id，不对节气就空着。
var term: StringName = &""
## 材料是收下来存着的（秋天的豆子、桂花留到冬天），不再要求当季现采。
var kept := false
## 两张残页分别掉在哪。空着表示没有残页。下标 0 是左半，1 是右半。
var scrap: Array[StringName] = []


static func from_dict(d: Dictionary) -> RecipeDef:
	var def := RecipeDef.new()
	def.id = StringName(str(d.get("id", "")))
	def.from = StringName(str(d.get("from", "start")))
	def.teacher = StringName(str(d.get("teacher", "")))
	def.need_level = int(d.get("need", 1))
	def.method = StringName(str(d.get("method", "boil")))
	def.season = StringName(str(d.get("season", "")))
	def.term = StringName(str(d.get("term", "")))
	def.kept = bool(d.get("kept", false))
	var scrap_raw: Variant = d.get("scrap", [])
	if scrap_raw is Array:
		var scrap_list: Array = scrap_raw
		for entry: Variant in scrap_list:
			def.scrap.append(StringName(str(entry)))
	var raw: Variant = d.get("ingredients", {})
	if raw is Dictionary:
		var dict: Dictionary = raw
		for key: Variant in dict:
			def.ingredients[StringName(str(key))] = int(dict[key])
	return def


## 学会以后记的标记。
func known_flag() -> StringName:
	return StringName("recipe_" + String(id))


## 这道菜某一半残页的物品 id。half 是 0 或 1。
static func scrap_item(recipe_id: StringName, half: int) -> StringName:
	return StringName("scrap_%s_%d" % [recipe_id, half])


## “白萝卜 ×2、鲫鱼 ×1”
func ingredients_text() -> String:
	var parts := PackedStringArray()
	for item_id: StringName in ingredients:
		var item_name := Database.item(item_id).name if Database.has_item(item_id) else String(item_id)
		parts.append("%s ×%d" % [item_name, ingredients[item_id]])
	return "、".join(parts)
