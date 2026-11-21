class_name NpcSchedule
extends RefCounted
## 居民的日程：给定时间和天气，算出这位居民现在该在哪。不依赖节点；只看一眼剧情标记（有的人在某盏灯亮以前是另一套日程）。
## 节日那天，节日开着的时候大家都在节日的站位上，散了就回家（Festivals.spot）。

## 这些天气用雨天的日程
const WET: Array[StringName] = [&"rain", &"storm", &"snow"]
## 不在任何地图上（在家，或者还没出门）
const HOME := {"from": 0, "map": &"", "tile": Vector2i.ZERO, "facing": 0, "work": false, "note": ""}


## 今天用哪一份日程：先按天气和灯亮选整套平常的，再盖上符合条件的例外（决策 073）。
static func plan_for(def: NpcDef, weather: StringName) -> Array[Dictionary]:
	var base := _base_plan(def, weather)
	var season := GameClock.season_id()
	var term := GameClock.term_id()
	var plan := base if def.exceptions.is_empty() else overlay(base, def.exceptions, season, term, weather)
	plan = _heat(def.id, plan, term, weather)
	plan = _tea(def.id, plan, season, weather)
	plan = _wind(def.id, plan, weather)
	plan = _winter(plan, season)
	# 雾天的晚出门放在冬天之后，避免再推迟时越过已经提前的回家
	return _fog(def.id, plan, weather)


## 按天气和“灯亮以前”选整套平常日程。没有例外时就是这一份。
static func _base_plan(def: NpcDef, weather: StringName) -> Array[Dictionary]:
	var wet := WET.has(weather)
	if def.is_early():
		return def.early_rain_schedule if wet and not def.early_rain_schedule.is_empty() else def.early_schedule
	if wet and not def.rain_schedule.is_empty():
		return def.rain_schedule
	return def.schedule


## 把符合条件的例外盖到平常日程上。每条例外占用 [from, to) 这段时间：去掉平常日程里
## 开始时间落在这段的项，换上例外自己的去处，段末再把平常的去处接回来，最后按时间排好。
## 没有一条符合就原样返回。纯函数：季节、节气、天气都由参数传进来。
static func overlay(base: Array[Dictionary], exceptions: Array[Dictionary], season: StringName, term: StringName, weather: StringName) -> Array[Dictionary]:
	var applied: Array[Dictionary] = []
	for ex: Dictionary in exceptions:
		if _matches(ex, season, term, weather):
			applied.append(ex)
	if applied.is_empty():
		return base
	var out := base.duplicate()
	for ex: Dictionary in applied:
		var lo: int = ex["from"]
		var hi: int = ex["to"]
		# 段末平常日程的去处（趁还没盖掉先记下来），用来在 hi 接回去
		var resume: Dictionary = HOME
		var best := -1
		for entry in out:
			var f: int = entry["from"]
			if f <= hi and f > best:
				best = f
				resume = entry
		for i in range(out.size() - 1, -1, -1):
			var f: int = out[i]["from"]
			if f >= lo and f < hi:
				out.remove_at(i)
		for e: Dictionary in ex["plan"]:
			out.append(e)
		var has_at_hi := false
		for entry in out:
			if int(entry["from"]) == hi:
				has_at_hi = true
				break
		if not has_at_hi:
			var back := resume.duplicate()
			back["from"] = hi
			out.append(back)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["from"]) < int(b["from"]))
	return out


## 这条例外今天生不生效：写了的条件都要对上，没写（空）的不限。
static func _matches(ex: Dictionary, season: StringName, term: StringName, weather: StringName) -> bool:
	if ex["season"] != &"" and ex["season"] != season:
		return false
	if ex["term"] != &"" and ex["term"] != term:
		return false
	if ex["weather"] != &"" and ex["weather"] != weather:
		return false
	return true


## 小暑、大暑的中午，人在镇上的去阴凉处摇扇。石叔这段不打铁，改成早上和下午打。
const HEAT: Array[StringName] = [&"xiaoshu", &"dashu"]
const SHADE: Dictionary = {
	&"jiang": Vector2i(20, 14),
	&"xiaoman": Vector2i(16, 11),
	&"bai": Vector2i(19, 11),
	&"ahe": Vector2i(24, 11),
	&"shishu": Vector2i(28, 11),
	&"qingzhu": Vector2i(16, 14),
	&"yunniang": Vector2i(30, 11),
}
const SMITH_TILE := Vector2i(37, 18)
## 冬天午后茶馆门口多站几位。码头、牧场、井口、山上的人不叫回来。
const TEA: Dictionary = {
	&"bai": Vector2i(36, 10),
	&"jiang": Vector2i(38, 10),
	&"xiaoman": Vector2i(35, 10),
}


static func _heat(id: StringName, plan: Array[Dictionary], term: StringName, weather: StringName) -> Array[Dictionary]:
	if not HEAT.has(term) or WET.has(weather) or not SHADE.has(id):
		return plan
	var shade: Vector2i = SHADE[id]
	var fan := {"from": 12 * 60, "map": &"town", "tile": shade, "facing": 0, "work": false, "note": "shade", "pose": "fan"}
	if id == &"shishu":
		var smith := {"from": 8 * 60, "map": &"town", "tile": SMITH_TILE, "facing": 0, "work": true, "note": "", "pose": "smash"}
		var again := smith.duplicate()
		again["from"] = 16 * 60
		return overlay(plan, [_span(8 * 60, 17 * 60 + 30, [smith, fan, again])], &"", term, weather)
	return overlay(plan, [_span(12 * 60, 15 * 60, [fan])], &"", term, weather)


static func _tea(id: StringName, plan: Array[Dictionary], season: StringName, weather: StringName) -> Array[Dictionary]:
	if season != &"winter" or WET.has(weather) or not TEA.has(id):
		return plan
	var tile: Vector2i = TEA[id]
	var stand := {"from": 14 * 60, "map": &"town", "tile": tile, "facing": 1, "work": false, "note": "tea", "pose": "rub"}
	return overlay(plan, [_span(14 * 60, 16 * 60, [stand])], season, &"", weather)


## 冬天出门晚一小时、回家早一小时。站着、手里没活的人搓手。
static func _winter(plan: Array[Dictionary], season: StringName) -> Array[Dictionary]:
	if season != &"winter" or plan.is_empty():
		return plan
	var out: Array[Dictionary] = []
	for entry in plan:
		out.append(entry.duplicate())
	var first := -1
	var last_home := -1
	for i in out.size():
		if str(out[i]["map"]) != "" and first < 0:
			first = i
		if str(out[i]["map"]) == "" and int(out[i]["from"]) > 0:
			last_home = i
		if str(out[i]["map"]) != "" and str(out[i]["pose"]) == "" and not bool(out[i]["work"]):
			out[i]["pose"] = "rub"
	if first >= 0:
		var later := int(out[first]["from"]) + 60
		var cap := 100000
		if first + 1 < out.size():
			cap = int(out[first + 1]["from"])
		if later < cap:
			out[first]["from"] = later
	if last_home >= 0:
		var earlier := int(out[last_home]["from"]) - 60
		var floor_from := 0 if last_home == 0 else int(out[last_home - 1]["from"])
		if earlier > floor_from:
			out[last_home]["from"] = earlier
	return out


## 大风：阿禾提前收摊，云娘离开茶馆门口去追被吹走的幌子。
static func _wind(id: StringName, plan: Array[Dictionary], weather: StringName) -> Array[Dictionary]:
	if weather != &"wind":
		return plan
	if id == &"ahe":
		var shut := {"from": 15 * 60, "map": &"", "tile": Vector2i.ZERO, "facing": 0, "work": false, "note": "", "pose": ""}
		return overlay(plan, [_span(15 * 60, 18 * 60, [shut])], &"", &"", weather)
	if id == &"yunniang":
		var chase := {"from": 10 * 60, "map": &"town", "tile": Vector2i(33, 12), "facing": 2, "work": false, "note": "banner", "pose": ""}
		return overlay(plan, [_span(10 * 60, 11 * 60 + 30, [chase])], &"", &"", weather)
	return plan


## 雾天：柏先生不出门；白鹭把白天用来画画；其余人出门晚一小时。
static func _fog(id: StringName, plan: Array[Dictionary], weather: StringName) -> Array[Dictionary]:
	if weather != &"fog":
		return plan
	if id == &"bai":
		var home := HOME.duplicate()
		home["pose"] = ""
		return [home]
	var out := plan
	if id == &"egret":
		var paint := _paint_of(plan)
		paint["from"] = 9 * 60
		paint["pose"] = "paint"
		out = overlay(plan, [_span(9 * 60, 18 * 60 + 30, [paint])], &"", &"", weather)
	return _delay_first(out, 60)


static func _paint_of(plan: Array) -> Dictionary:
	for entry in plan:
		if str(entry.get("pose", "")) == "paint":
			return entry.duplicate()
	return {"from": 9 * 60, "map": &"town", "tile": Vector2i(24, 17), "facing": 0, "work": false, "note": "sketch", "pose": "paint"}


## 把第一段出门再推迟若干分钟。推迟后若会盖过下一段，就不动。
static func _delay_first(plan: Array, minutes: int) -> Array[Dictionary]:
	if plan.is_empty() or minutes <= 0:
		return plan
	var out: Array[Dictionary] = []
	for entry in plan:
		out.append(entry.duplicate())
	var first := -1
	for i in out.size():
		if str(out[i].get("map", "")) != "" and first < 0:
			first = i
	if first < 0:
		return out
	var later := int(out[first]["from"]) + minutes
	var cap := 100000
	if first + 1 < out.size():
		cap = int(out[first + 1]["from"])
	if later < cap:
		out[first]["from"] = later
	return out


static func _span(lo: int, hi: int, plan: Array) -> Dictionary:
	return {"season": &"", "term": &"", "weather": &"", "from": lo, "to": hi, "plan": plan}


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
