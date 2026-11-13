class_name FarmState
extends RefCounted
## 农场耕地的状态和规则：哪些格子开垦了、是否浇过水、施了什么肥、种了什么、长了几天。
## 不依赖任何节点；格子能不能开垦由地图判断，这里只管开垦之后的事。

signal changed

## 品质分数对应的概率：[良的概率, 优的概率]，分数超过表长按最后一项算
const QUALITY_ODDS: Array = [[0.1, 0.0], [0.4, 0.1], [0.45, 0.3], [0.4, 0.55]]

## 水渠能润到周围几格（横、竖、斜都算）
const CANAL_REACH := 2
## 巨型作物一次收几个
const GIANT_YIELD := 4
const DIRS4: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

## 已开垦的格子 -> 今天是否浇过水
var soil: Dictionary[Vector2i, bool] = {}
## 有作物的格子 -> {"crop": StringName, "days": int, "dead": bool, "bonus": int, "wilt": bool}
## days 是已经生长的天数；dead 表示枯死了，要清掉才能再种；
## bonus 是播种时得到的品质加分（春分）；wilt 表示高温天没浇水蔫了
var crops: Dictionary[Vector2i, Dictionary] = {}
## 施过肥的格子 -> 肥力（1 普通肥，2 精制肥）。作物拔掉时肥料一起用完。
var fert: Dictionary[Vector2i, int] = {}
## 挖了水渠的格子 -> 这一格是否紧挨着天然的水（溪、塘）。和水源连通的水渠才有水。
var canals: Dictionary[Vector2i, bool] = {}
## 水田：放了水的耕地，只能种稻和藕
var paddies: Dictionary[Vector2i, bool] = {}

## 有水的水渠，由 canals 算出来
var _flooded: Dictionary[Vector2i, bool] = {}
## 被有水的水渠润到的格子
var _irrigated: Dictionary[Vector2i, bool] = {}


func is_tilled(t: Vector2i) -> bool:
	return soil.has(t)


func is_wet(t: Vector2i) -> bool:
	return soil.get(t, false)


func has_crop(t: Vector2i) -> bool:
	return crops.has(t)


func till(t: Vector2i) -> bool:
	if soil.has(t) or canals.has(t):
		return false
	soil[t] = _irrigated.has(t)
	changed.emit()
	return true


func water(t: Vector2i) -> bool:
	if not soil.has(t) or soil[t]:
		return false
	soil[t] = true
	changed.emit()
	return true


func fert_at(t: Vector2i) -> int:
	return fert.get(t, 0)


func can_fertilize(t: Vector2i) -> bool:
	return soil.has(t) and not fert.has(t) and not is_dead(t)


func fertilize(t: Vector2i, power: int) -> bool:
	if power <= 0 or not can_fertilize(t):
		return false
	fert[t] = power
	changed.emit()
	return true


func is_canal(t: Vector2i) -> bool:
	return canals.has(t)


## 这格水渠里有没有水（和水源连通）。
func is_flooded(t: Vector2i) -> bool:
	return _flooded.has(t)


## 这一格是否在有水的水渠旁边，每天自动湿润。
func is_irrigated(t: Vector2i) -> bool:
	return _irrigated.has(t)


func is_paddy(t: Vector2i) -> bool:
	return paddies.has(t)


## 挖一格水渠。at_water 表示这一格紧挨着天然的水。耕地上不能挖。
func dig_canal(t: Vector2i, at_water: bool) -> bool:
	if soil.has(t) or canals.has(t):
		return false
	canals[t] = at_water
	_reflow()
	changed.emit()
	return true


func fill_canal(t: Vector2i) -> bool:
	if not canals.has(t):
		return false
	canals.erase(t)
	_reflow()
	changed.emit()
	return true


## 把空着的耕地放水成水田（要在有水的水渠旁边），或者把水放掉变回旱地。
func set_paddy(t: Vector2i, on: bool) -> bool:
	if not soil.has(t) or crops.has(t) or paddies.has(t) == on:
		return false
	if on:
		if not _irrigated.has(t):
			return false
		paddies[t] = true
		soil[t] = true
	else:
		paddies.erase(t)
	changed.emit()
	return true


## 铲掉这一格的作物，不管死活，什么都得不到。
func uproot(t: Vector2i) -> bool:
	if not crops.has(t):
		return false
	crops.erase(t)
	fert.erase(t)
	changed.emit()
	return true


## 重新算哪些水渠有水、哪些格子被润到；wet_soil 为真时被润到的耕地立刻变湿。
func _reflow(wet_soil: bool = true) -> void:
	_flooded.clear()
	_irrigated.clear()
	var queue: Array[Vector2i] = []
	for t: Vector2i in canals:
		if canals[t]:
			_flooded[t] = true
			queue.append(t)
	while not queue.is_empty():
		var t: Vector2i = queue.pop_back()
		for d in DIRS4:
			var n := t + d
			if canals.has(n) and not _flooded.has(n):
				_flooded[n] = true
				queue.append(n)
	for t: Vector2i in _flooded:
		for dy in range(-CANAL_REACH, CANAL_REACH + 1):
			for dx in range(-CANAL_REACH, CANAL_REACH + 1):
				_irrigated[t + Vector2i(dx, dy)] = true
	if wet_soil:
		for t: Vector2i in soil:
			if _irrigated.has(t):
				soil[t] = true


func can_plant(t: Vector2i) -> bool:
	return soil.has(t) and not crops.has(t)


## 这种作物能不能种在这一格：水田作物只能种水田，其他作物只能种旱地。
func can_plant_crop(t: Vector2i, crop_id: StringName) -> bool:
	return can_plant(t) and Database.has_crop(crop_id) and Database.crop(crop_id).paddy == paddies.has(t)


## bonus 是播种时的品质加分。
func plant(t: Vector2i, crop_id: StringName, bonus: int = 0) -> bool:
	if not can_plant_crop(t, crop_id):
		return false
	crops[t] = {"crop": crop_id, "days": 0, "dead": false, "bonus": bonus, "wilt": false}
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


func is_dead(t: Vector2i) -> bool:
	if not crops.has(t):
		return false
	var dead: bool = crops[t].get("dead", false)
	return dead


func is_wilted(t: Vector2i) -> bool:
	if not crops.has(t):
		return false
	var wilt: bool = crops[t].get("wilt", false)
	return wilt


func is_giant(t: Vector2i) -> bool:
	if not crops.has(t):
		return false
	var giant: bool = crops[t].get("giant", false)
	return giant


func giant_count() -> int:
	var n := 0
	for t: Vector2i in crops:
		if is_giant(t):
			n += 1
	return n


## 这一格的作物挡不挡路：搭了架子的作物出苗以后人走不过去。
func blocks_walking(t: Vector2i) -> bool:
	if not crops.has(t) or is_dead(t):
		return false
	return Database.crop(crop_id_at(t)).trellis and crop_stage_at(t) >= 1


func dead_count() -> int:
	var n := 0
	for t: Vector2i in crops:
		if is_dead(t):
			n += 1
	return n


func is_ripe(t: Vector2i) -> bool:
	if not crops.has(t) or is_dead(t):
		return false
	return Database.crop(crop_id_at(t)).is_ripe(crop_days_at(t))


## 这一格成熟的作物会收到几个：roll 是 [0, 1) 的随机数，小于多收概率时多得一个。
func yield_at(t: Vector2i, roll: float) -> int:
	if not is_ripe(t):
		return 0
	if is_giant(t):
		return GIANT_YIELD
	return 2 if roll < Database.crop(crop_id_at(t)).extra_chance else 1


## 这一格的品质分数：肥力、播种时的加分，在水渠旁边再加一分。
func quality_score(t: Vector2i) -> int:
	if not crops.has(t):
		return 0
	var bonus: int = crops[t].get("bonus", 0)
	return bonus + fert_at(t) + (1 if _irrigated.has(t) else 0)


## 由品质分数和一个 [0, 1) 的随机数决定品质：0 普通，1 良，2 优。
static func quality_for(score: int, roll: float) -> int:
	var odds: Array = QUALITY_ODDS[clampi(score, 0, QUALITY_ODDS.size() - 1)]
	var good: float = odds[0]
	var best: float = odds[1]
	if roll < best:
		return 2
	if roll < best + good:
		return 1
	return 0


## 现在收获这一格会得到的品质。extra 是收获时的额外加分（节气）。
func harvest_quality(t: Vector2i, roll: float, extra: int = 0) -> int:
	return quality_for(quality_score(t) + extra, roll)


## 收获成熟的作物，返回产物的物品 id；没有可收的返回空。
## 能再收的作物留在地里，退回到再收所需的天数之前。
func harvest(t: Vector2i) -> StringName:
	if not is_ripe(t):
		return &""
	var def := Database.crop(crop_id_at(t))
	if def.regrow_days > 0:
		crops[t]["days"] = def.total_days() - def.regrow_days
		crops[t]["giant"] = false
	else:
		crops.erase(t)
		fert.erase(t)
	changed.emit()
	return def.produce


## 清掉枯死的作物。
func clear_dead(t: Vector2i) -> bool:
	if not is_dead(t):
		return false
	crops.erase(t)
	fert.erase(t)
	changed.emit()
	return true


## 雷劈：让第 pick 株还活着的作物（按种下的先后数，超出就绕回来）死掉。没有活的作物返回 false。
func strike(pick: int) -> bool:
	var living: Array[Vector2i] = []
	for t: Vector2i in crops:
		if not is_dead(t):
			living.append(t)
	if living.is_empty():
		return false
	crops[living[posmod(pick, living.size())]]["dead"] = true
	changed.emit()
	return true


## 过夜。
##   season        新一天的季节，空表示不检查季节
##   past_weather  刚过去的这天的天气（雾天雾生作物才长）
##   wet_today     新的一天耕地是否自动湿润（下雨、露水）
##   heat          刚过去的这天是否高温（小暑）：没浇水的作物会蔫，连着两天没浇就死
##   frost         新的一天早上是否有霜：不耐寒的作物冻死
##   term_index    新的一天是一年里第几个节气，-1 表示不检查（冬小麦要等到芒种才熟）
##   rng           用来掷巨型作物；空表示不会长成巨型
## 顺序：先按昨天的状态生长，再处理枯死，最后重置耕地的干湿（水渠旁边的总是湿的）。
func advance_day(season: StringName = &"", past_weather: StringName = &"", wet_today: bool = false,
		heat: bool = false, frost: bool = false, term_index: int = -1,
		rng: RandomNumberGenerator = null) -> void:
	for t: Vector2i in crops:
		if is_dead(t):
			continue
		var crop := crops[t]
		var def := Database.crop(crop_id_at(t))
		var days := crop_days_at(t)
		var watered := is_wet(t)
		var grows := watered
		if def.needs_fog:
			grows = past_weather == &"fog"
		elif def.rainfed:
			grows = true
		else:
			if watered:
				crop["wilt"] = false
			elif heat:
				if is_wilted(t):
					crop["dead"] = true
					continue
				crop["wilt"] = true
			if is_wilted(t):
				grows = false
		if grows and not def.is_ripe(days):
			var ripens := def.is_ripe(days + 1)
			if not ripens or def.can_ripen_at(term_index):
				crop["days"] = days + 1
				if ripens and rng != null and def.giant_chance > 0.0 and rng.randf() < def.giant_chance:
					crop["giant"] = true
		if season != &"" and not def.grows_in(season):
			crop["dead"] = true
		if frost and not def.hardy:
			crop["dead"] = true
	for t: Vector2i in soil:
		soil[t] = wet_today or _irrigated.has(t)
	changed.emit()


func clear() -> void:
	soil.clear()
	crops.clear()
	fert.clear()
	canals.clear()
	paddies.clear()
	_reflow()
	changed.emit()


func to_dict() -> Dictionary:
	var soil_list: Array = []
	for t: Vector2i in soil:
		soil_list.append([t.x, t.y, soil[t]])
	var crop_list: Array = []
	for t: Vector2i in crops:
		crop_list.append([t.x, t.y, String(crop_id_at(t)), crop_days_at(t), is_dead(t),
			int(crops[t].get("bonus", 0)), is_wilted(t), is_giant(t)])
	var fert_list: Array = []
	for t: Vector2i in fert:
		fert_list.append([t.x, t.y, fert[t]])
	var canal_list: Array = []
	for t: Vector2i in canals:
		canal_list.append([t.x, t.y, canals[t]])
	var paddy_list: Array = []
	for t: Vector2i in paddies:
		paddy_list.append([t.x, t.y])
	return {"soil": soil_list, "crops": crop_list, "fert": fert_list, "canals": canal_list, "paddies": paddy_list}


func from_dict(data: Dictionary) -> void:
	soil.clear()
	crops.clear()
	fert.clear()
	canals.clear()
	paddies.clear()
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
			# 作物必须长在耕地上，且作物种类还存在；旧存档缺的字段按默认值
			if soil.has(t) and Database.has_crop(id):
				crops[t] = {
					"crop": id, "days": int(e[3]),
					"dead": e.size() >= 5 and bool(e[4]),
					"bonus": int(e[5]) if e.size() >= 6 else 0,
					"wilt": e.size() >= 7 and bool(e[6]),
					"giant": e.size() >= 8 and bool(e[7]),
				}
	var fert_list: Array = data.get("fert", [])
	for entry: Variant in fert_list:
		if entry is Array and entry.size() >= 3:
			var e: Array = entry
			var t := Vector2i(int(e[0]), int(e[1]))
			if soil.has(t) and int(e[2]) > 0:
				fert[t] = int(e[2])
	var canal_list: Array = data.get("canals", [])
	for entry: Variant in canal_list:
		if entry is Array and entry.size() >= 3:
			var e: Array = entry
			var t := Vector2i(int(e[0]), int(e[1]))
			if not soil.has(t):
				canals[t] = bool(e[2])
	var paddy_list: Array = data.get("paddies", [])
	for entry: Variant in paddy_list:
		if entry is Array and entry.size() >= 2:
			var e: Array = entry
			var t := Vector2i(int(e[0]), int(e[1]))
			if soil.has(t):
				paddies[t] = true
	# 只重算水渠，不改存档里记下的干湿
	_reflow(false)
	changed.emit()
