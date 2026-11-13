extends Node
## 主线石灯：每盏灯已经供上了什么、亮没亮。点亮记成 GameState 的标记（lamp_<id>），别的系统只看标记。

## 供品或点亮状态有变化（灯座界面用）
signal changed

## 灯 id -> {物品 id: 已供上的数量}
var given: Dictionary[StringName, Dictionary] = {}


func _ready() -> void:
	SaveSystem.register(&"lamps", self)


func is_lit(lamp_id: StringName) -> bool:
	return Database.lamps.has(lamp_id) and GameState.has_flag(Database.lamp(lamp_id).flag())


## 这种供品已经供上几个。
func given_count(lamp_id: StringName, item_id: StringName) -> int:
	var mine: Dictionary = given.get(lamp_id, {})
	return int(mine.get(item_id, 0))


## 这种供品还差几个（关键遗物也算一种，差 1 或 0）。
func missing(lamp_id: StringName, item_id: StringName) -> int:
	var def := Database.lamp(lamp_id)
	var need := 1 if item_id == def.relic else int(def.offerings.get(item_id, 0))
	return maxi(0, need - given_count(lamp_id, item_id))


## 灯要的全部东西，按供品表的顺序，最后是关键遗物。
func wanted(lamp_id: StringName) -> Array[StringName]:
	var def := Database.lamp(lamp_id)
	var out: Array[StringName] = []
	for item_id: StringName in def.offerings:
		out.append(item_id)
	if def.relic != &"":
		out.append(def.relic)
	return out


## 供品齐了没有。
func is_complete(lamp_id: StringName) -> bool:
	for item_id in wanted(lamp_id):
		if missing(lamp_id, item_id) > 0:
			return false
	return true


## 把 count 个 item 供上去，返回实际收下的个数（不超过还差的数量）。不动背包。
func offer(lamp_id: StringName, item_id: StringName, count: int) -> int:
	if is_lit(lamp_id):
		return 0
	var n := mini(count, missing(lamp_id, item_id))
	if n <= 0:
		return 0
	if not given.has(lamp_id):
		given[lamp_id] = {}
	given[lamp_id][item_id] = given_count(lamp_id, item_id) + n
	changed.emit()
	return n


## 点亮。供品没齐或已经亮了返回 false。
func light(lamp_id: StringName) -> bool:
	if is_lit(lamp_id) or not is_complete(lamp_id):
		return false
	GameState.set_flag(Database.lamp(lamp_id).flag())
	changed.emit()
	EventBus.lamp_lit.emit(lamp_id)
	return true


func save_data() -> Dictionary:
	var out := {}
	for lamp_id: StringName in given:
		var mine := {}
		var from: Dictionary = given[lamp_id]
		for item_id: StringName in from:
			mine[String(item_id)] = int(from[item_id])
		out[String(lamp_id)] = mine
	return {"given": out}


func load_data(data: Dictionary) -> void:
	given.clear()
	var saved: Dictionary = data.get("given", {})
	for lamp_id: Variant in saved:
		var mine: Dictionary[StringName, int] = {}
		var from: Dictionary = saved[lamp_id]
		for item_id: Variant in from:
			mine[StringName(str(item_id))] = int(from[item_id])
		given[StringName(str(lamp_id))] = mine
	changed.emit()


func reset_data() -> void:
	given.clear()
	changed.emit()
