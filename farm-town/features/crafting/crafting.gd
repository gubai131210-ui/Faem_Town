extends Node
## 加工和烹饪。加工设备在石叔那儿买（记成 GameState 的标记 machine_<id>），摆在农场固定的位置，
## 放进原料过几天出成品；做菜在农舍的灶台，按菜谱把材料换成食物。
## 这里只存状态和规则，设备怎么画、灶台在哪儿由地图决定。

signal changed

const IDLE := 0
const WORKING := 1
const READY := 2

## 设备 id -> {"output": 物品 id, "quality": 品质, "count": 几个, "days": 还要几天}
var jobs: Dictionary[StringName, Dictionary] = {}
## 刚学会的那道菜叫什么（给对话用）
var last_dish := ""
## 今天已经学过一道了
var _lesson_day := -1


func _ready() -> void:
	SaveSystem.register(&"crafting", self)
	GameClock.register_daily(GameClock.ORDER_MACHINES, _on_new_day)


# ---------------------------------------------------------------- 加工设备

func owned(id: StringName) -> bool:
	return Database.machines.has(id) and GameState.has_flag(Database.machine(id).owned_flag())


func state(id: StringName) -> int:
	if not jobs.has(id):
		return IDLE
	return READY if int(jobs[id]["days"]) <= 0 else WORKING


func days_left(id: StringName) -> int:
	return int(jobs[id]["days"]) if jobs.has(id) else 0


## 里面正在做（或做好了）的东西；空着返回空。
func output_of(id: StringName) -> StringName:
	if not jobs.has(id):
		return &""
	var out: StringName = jobs[id]["output"]
	return out


## 背包第 slot 格的东西能不能放进这台设备：设备空着、收这样东西、数量够。
func can_put(id: StringName, slot: int) -> bool:
	if not owned(id) or state(id) != IDLE:
		return false
	var inv := GameState.inventory
	var recipe := Database.machine(id).recipe_for(inv.id_at(slot))
	return not recipe.is_empty() and inv.count_at(slot) >= int(recipe["count"])


## 这样东西这台设备收不收（不管数量够不够）。
func accepts(id: StringName, item_id: StringName) -> bool:
	return owned(id) and not Database.machine(id).recipe_for(item_id).is_empty()


## 一次要放几个。
func need(id: StringName, item_id: StringName) -> int:
	var recipe := Database.machine(id).recipe_for(item_id)
	return int(recipe.get("count", 0))


## 把背包第 slot 格的原料放进去，成品的品质跟着原料。
func put(id: StringName, slot: int) -> bool:
	if not can_put(id, slot):
		return false
	var inv := GameState.inventory
	var recipe := Database.machine(id).recipe_for(inv.id_at(slot))
	var quality := inv.quality_at(slot)
	var count: int = recipe["count"]
	if inv.remove_at(slot, count) != count:
		return false
	jobs[id] = {"output": recipe["output"], "quality": quality, "count": 1, "days": int(recipe["days"])}
	changed.emit()
	return true


## 把做好的成品收进背包，返回 [物品 id, 个数, 品质]；没做好或背包满了返回空数组。
func take(id: StringName) -> Array:
	if state(id) != READY:
		return []
	var job: Dictionary = jobs[id]
	var out: StringName = job["output"]
	var count: int = job["count"]
	var quality: int = job["quality"]
	if not GameState.inventory.can_add(out, count, quality):
		return []
	GameState.inventory.add(out, count, quality)
	jobs.erase(id)
	changed.emit()
	return [out, count, quality]


func _on_new_day() -> void:
	for id: StringName in jobs:
		var job: Dictionary = jobs[id]
		job["days"] = maxi(0, int(job["days"]) - 1)
	changed.emit()


# ---------------------------------------------------------------- 烹饪

func knows(recipe_id: StringName) -> bool:
	if not Database.recipes.has(recipe_id):
		return false
	var def: RecipeDef = Database.recipes[recipe_id]
	return def.from == &"start" or GameState.has_flag(def.known_flag())


## 已经会的菜，按表里的顺序。
func known_recipes() -> Array[RecipeDef]:
	var out: Array[RecipeDef] = []
	for id: StringName in Database.recipes:
		if knows(id):
			out.append(Database.recipes[id])
	return out


## 手头的材料够做几份。
func servings(recipe_id: StringName) -> int:
	if not knows(recipe_id):
		return 0
	var def: RecipeDef = Database.recipes[recipe_id]
	var n := 99
	for item_id: StringName in def.ingredients:
		n = mini(n, GameState.inventory.count_of(item_id) / def.ingredients[item_id])
	return n


## 做一份，放进背包。材料不够返回 false。
func cook(recipe_id: StringName) -> bool:
	if servings(recipe_id) < 1:
		return false
	var def: RecipeDef = Database.recipes[recipe_id]
	for item_id: StringName in def.ingredients:
		GameState.inventory.remove(item_id, def.ingredients[item_id])
	if GameState.inventory.add(recipe_id, 1) > 0:
		# 放不下：材料还回去
		for item_id: StringName in def.ingredients:
			GameState.inventory.add(item_id, def.ingredients[item_id])
		return false
	changed.emit()
	return true


## who 现在有没有菜可以教：还有没教的，而且今天没教过。
func has_lesson(who: String) -> bool:
	return _lesson_day != GameClock.day and _next_lesson(who) != &""


## who 教下一道菜，记在 last_dish 里。
func learn(who: String) -> bool:
	if not has_lesson(who):
		return false
	var id := _next_lesson(who)
	var def: RecipeDef = Database.recipes[id]
	GameState.set_flag(def.known_flag())
	last_dish = Database.item(id).name
	_lesson_day = GameClock.day
	changed.emit()
	return true


func _next_lesson(who: String) -> StringName:
	for id: StringName in Database.recipes:
		var def: RecipeDef = Database.recipes[id]
		if String(def.from) == who and not knows(id):
			return id
	return &""


# ---------------------------------------------------------------- 存档

func save_data() -> Dictionary:
	var out := {}
	for id: StringName in jobs:
		var job: Dictionary = jobs[id]
		out[String(id)] = {"output": String(job["output"]), "quality": int(job["quality"]), "count": int(job["count"]), "days": int(job["days"])}
	return {"jobs": out, "lesson_day": _lesson_day}


func load_data(data: Dictionary) -> void:
	jobs.clear()
	var saved: Dictionary = data.get("jobs", {})
	for key: Variant in saved:
		var job: Dictionary = saved[key]
		var id := StringName(str(key))
		var out := StringName(str(job.get("output", "")))
		if not Database.machines.has(id) or not Database.has_item(out):
			continue
		jobs[id] = {"output": out, "quality": clampi(int(job.get("quality", 0)), 0, 2), "count": maxi(1, int(job.get("count", 1))), "days": maxi(0, int(job.get("days", 0)))}
	_lesson_day = int(data.get("lesson_day", -1))
	changed.emit()


func reset_data() -> void:
	jobs.clear()
	last_dish = ""
	_lesson_day = -1
	changed.emit()
