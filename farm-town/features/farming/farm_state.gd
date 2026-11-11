class_name FarmState
extends RefCounted
## 农场耕地的状态和规则：哪些格子开垦了、是否浇过水、种了什么、长了几天。
## 不依赖任何节点；格子能不能开垦由地图判断，这里只管开垦之后的事。

signal changed

## 已开垦的格子 -> 今天是否浇过水
var soil: Dictionary[Vector2i, bool] = {}
## 有作物的格子 -> {"crop": StringName, "days": int}，days 是浇过水的天数
var crops: Dictionary[Vector2i, Dictionary] = {}


func is_tilled(t: Vector2i) -> bool:
	return soil.has(t)


func is_wet(t: Vector2i) -> bool:
	return soil.get(t, false)


func has_crop(t: Vector2i) -> bool:
	return crops.has(t)


func till(t: Vector2i) -> bool:
	if soil.has(t):
		return false
	soil[t] = false
	changed.emit()
	return true


func water(t: Vector2i) -> bool:
	if not soil.has(t) or soil[t]:
		return false
	soil[t] = true
	changed.emit()
	return true


func can_plant(t: Vector2i) -> bool:
	return soil.has(t) and not crops.has(t)


func plant(t: Vector2i, crop_id: StringName) -> bool:
	if not can_plant(t) or not Database.has_crop(crop_id):
		return false
	crops[t] = {"crop": crop_id, "days": 0}
	changed.emit()
	return true


func crop_id_at(t: Vector2i) -> StringName:
	if not crops.has(t):
		return &""
	var id: StringName = crops[t]["crop"]
	return id


func crop_days_at(t: Vector2i) -> int:
	if not crops.has(t):
		return 0
	var n: int = crops[t]["days"]
	return n


func crop_stage_at(t: Vector2i) -> int:
	if not crops.has(t):
		return 0
	return Database.crop(crop_id_at(t)).stage_for(crop_days_at(t))


func is_ripe(t: Vector2i) -> bool:
	if not crops.has(t):
		return false
	return Database.crop(crop_id_at(t)).is_ripe(crop_days_at(t))


## 收获成熟的作物，返回产物的物品 id；没有可收的返回空。
func harvest(t: Vector2i) -> StringName:
	if not is_ripe(t):
		return &""
	var produce := Database.crop(crop_id_at(t)).produce
	crops.erase(t)
	changed.emit()
	return produce


## 过夜：浇过水的作物长一天，然后所有耕地变干。
func advance_day() -> void:
	for t: Vector2i in crops:
		if soil.get(t, false):
			crops[t]["days"] = crop_days_at(t) + 1
	for t: Vector2i in soil:
		soil[t] = false
	changed.emit()


func clear() -> void:
	soil.clear()
	crops.clear()
	changed.emit()


func to_dict() -> Dictionary:
	var soil_list: Array = []
	for t: Vector2i in soil:
		soil_list.append([t.x, t.y, soil[t]])
	var crop_list: Array = []
	for t: Vector2i in crops:
		crop_list.append([t.x, t.y, String(crop_id_at(t)), crop_days_at(t)])
	return {"soil": soil_list, "crops": crop_list}


func from_dict(data: Dictionary) -> void:
	soil.clear()
	crops.clear()
	var soil_list: Array = data.get("soil", [])
	for entry: Variant in soil_list:
		if entry is Array and entry.size() >= 3:
			var e: Array = entry
			soil[Vector2i(int(e[0]), int(e[1]))] = bool(e[2])
	var crop_list: Array = data.get("crops", [])
	for entry: Variant in crop_list:
		if entry is Array and entry.size() >= 4:
			var e: Array = entry
			var t := Vector2i(int(e[0]), int(e[1]))
			var id := StringName(str(e[2]))
			# 作物必须长在耕地上，且作物种类还存在
			if soil.has(t) and Database.has_crop(id):
				crops[t] = {"crop": id, "days": int(e[3])}
	changed.emit()
