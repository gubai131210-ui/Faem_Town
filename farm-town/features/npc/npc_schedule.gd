class_name NpcSchedule
extends RefCounted
## 居民的日程：给定时间和天气，算出这位居民现在该在哪。不依赖节点；只看一眼剧情标记（有的人在某盏灯亮以前是另一套日程）。
## 节日那天，节日开着的时候大家都在节日的站位上，散了就回家（Festivals.spot）。

## 这些天气用雨天的日程
const WET: Array[StringName] = [&"rain", &"storm", &"snow"]
## 不在任何地图上（在家，或者还没出门）
const HOME := {"from": 0, "map": &"", "tile": Vector2i.ZERO, "facing": 0, "work": false, "note": ""}


## 今天用哪一份日程。
static func plan_for(def: NpcDef, weather: StringName) -> Array[Dictionary]:
	var wet := WET.has(weather)
	if def.is_early():
		return def.early_rain_schedule if wet and not def.early_rain_schedule.is_empty() else def.early_schedule
	if wet and not def.rain_schedule.is_empty():
		return def.rain_schedule
	return def.schedule


## minutes 时刻这位居民该在的地方：日程里开始时间不晚于现在的最后一项；还没到第一项就是在家。
static func spot_at(def: NpcDef, minutes: float, weather: StringName) -> Dictionary:
	var festival := Festivals.spot(def.id, minutes)
	if not festival.is_empty():
		return festival
	var spot: Dictionary = HOME
	for entry in plan_for(def, weather):
		if int(entry["from"]) <= int(minutes):
			spot = entry
	return spot


## 这位居民现在是否在 map_id 这张地图上。
static func is_on(def: NpcDef, minutes: float, weather: StringName, map_id: StringName) -> bool:
	var where: StringName = spot_at(def, minutes, weather)["map"]
	return where != &"" and where == map_id
