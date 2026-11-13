class_name MachineDef
extends RefCounted
## 一台加工设备，来自 data/machines.json。在石叔那儿买，他送到农场上固定的位置。

var id: StringName
var name: String
var price := 0
var desc: String
## 用的物件名（art/props）
var prop: String
## 摆在农场的哪一格
var tile := Vector2i.ZERO
## 哪盏灯亮了石叔才卖（GameState 的标记）
var flag: StringName = &"lamp_plaza"
## 能做的东西：每项 {"inputs": [物品 id...], "count": 一次放几个, "output": 出什么, "days": 要几天}
var recipes: Array[Dictionary] = []


static func from_dict(d: Dictionary) -> MachineDef:
	var def := MachineDef.new()
	def.id = StringName(str(d.get("id", "")))
	def.name = str(d.get("name", ""))
	def.price = int(d.get("price", 0))
	def.desc = str(d.get("desc", ""))
	def.prop = str(d.get("prop", def.id))
	def.flag = StringName(str(d.get("flag", "lamp_plaza")))
	var t: Variant = d.get("tile", [0, 0])
	if t is Array and t.size() >= 2:
		def.tile = Vector2i(int(t[0]), int(t[1]))
	var list: Variant = d.get("recipes", [])
	if list is Array:
		for entry: Variant in list:
			if not entry is Dictionary:
				continue
			var e: Dictionary = entry
			var inputs: Array[StringName] = []
			var raw: Variant = e.get("inputs", [])
			if raw is Array:
				for v: Variant in raw:
					inputs.append(StringName(str(v)))
			def.recipes.append({
				"inputs": inputs,
				"count": int(e.get("count", 1)),
				"output": StringName(str(e.get("output", ""))),
				"days": int(e.get("days", 1)),
			})
	return def


## 买下以后记的标记。
func owned_flag() -> StringName:
	return StringName("machine_" + String(id))


## 这样东西放进来做什么；不收返回空字典。
func recipe_for(item_id: StringName) -> Dictionary:
	for r in recipes:
		var inputs: Array[StringName] = r["inputs"]
		if inputs.has(item_id):
			return r
	return {}
