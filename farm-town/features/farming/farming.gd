extends Node
## 种田的全局系统：持有耕地和果树的状态，负责它们的存档和每日结算。
## 玩家不在农场时作物也照常生长。

## 稻草人立起来、倒了、收走了
signal scarecrows_changed

## 雷雨过后的早上，有这么大的概率劈坏一株作物
const STRIKE_CHANCE := 0.4
## 乌鸦：每天早上有这么大的概率来，一次最多刨走几处刚种下的种子
const CROW_CHANCE := 0.35
const CROW_MAX := 2
## 稻草人护着周围几格（横竖斜都算）；大风过后每个有这么大的概率被吹倒
const SCARE_RANGE := 6
const BLOW_CHANCE := 0.25
const SCARECROW_ID := &"scarecrow"
## 家里养了猫：它守着屋门口这一格周围这么多格（起始那块田的西半边），再远就管不到了
const CAT_HOME := Vector2i(8, 8)
const CAT_RANGE := 12

var state := FarmState.new()
## 果树
var orchard := Orchard.new()
## 昨夜田里出的事，早上醒来时提示
var morning_notes := PackedStringArray()
## 稻草人：格子 -> 是不是倒了
var scarecrows: Dictionary[Vector2i, bool] = {}
## 今天早上乌鸦刨过的格子（不进存档，农场地图拿它摆乌鸦）
var raided: Array[Vector2i] = []
## 今天播了多少颗种子（不进存档：只在睡觉时存档，一觉醒来就清零。播种节的比赛看它）
var sown_today := 0

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	SaveSystem.register(&"farming", self)
	GameClock.register_daily(GameClock.ORDER_CROPS, _on_new_day)


## 每日结算。这时日期和天气都已经是新的一天了。
func _on_new_day() -> void:
	morning_notes.clear()
	sown_today = 0
	var past_term := Database.term(GameClock.term_index_of(GameClock.day - 1))
	var heat := past_term != null and past_term.id == &"xiaoshu"
	var frost := Weather.today == Weather.FROST
	# 白露：清晨有露水，耕地自动湿润
	var wet := Weather.wets_soil() or GameClock.term_id() == &"bailu"
	var dead_before := state.dead_count()
	var giants_before := state.giant_count()
	state.advance_day(GameClock.season_id(), Weather.yesterday, wet, heat, frost, GameClock.term_index(), _rng)
	if state.giant_count() > giants_before:
		morning_notes.append("地里有作物长成了巨型")
	if frost and state.dead_count() > dead_before:
		morning_notes.append("夜里下了霜，有作物冻死了")
	elif heat and state.dead_count() > dead_before:
		morning_notes.append("天太热，没浇水的作物枯死了")
	orchard.advance_day(GameClock.season_id(), Weather.yesterday == Weather.WIND)
	if orchard.fallen_total() > 0:
		morning_notes.append("大风把果子吹落了，今天不捡就烂了")
	if Weather.yesterday == Weather.STORM and _rng.randf() < STRIKE_CHANCE:
		if state.strike(_rng.randi()):
			morning_notes.append("昨夜的雷劈坏了一株作物")
	if Weather.yesterday == Weather.WIND and blow_scarecrows(_rng) > 0:
		morning_notes.append("大风把稻草人吹倒了，去扶一下")
	raided.clear()
	if crows_come() and _rng.randf() < CROW_CHANCE:
		raided = raid(_rng.randi_range(1, CROW_MAX), _rng)
		if not raided.is_empty():
			var tip := "屋子远处的地猫管不到，立个稻草人" if has_cat() else "立个稻草人，它们就不敢来"
			morning_notes.append("乌鸦刨走了 %d 处刚种下的种子。%s" % [raided.size(), tip])


# ---------------------------------------------------------------- 稻草人和乌鸦

func has_scarecrow(t: Vector2i) -> bool:
	return scarecrows.has(t)


func scarecrow_fallen(t: Vector2i) -> bool:
	return scarecrows.get(t, false)


## 在空地上立一个稻草人。这一格有耕地、水渠、果树或者已经有一个了就不行。不动背包。
func place_scarecrow(t: Vector2i) -> bool:
	if scarecrows.has(t) or state.is_tilled(t) or state.is_canal(t) or orchard.has(t):
		return false
	scarecrows[t] = false
	scarecrows_changed.emit()
	return true


## 把倒了的扶起来。
func raise_scarecrow(t: Vector2i) -> bool:
	if not scarecrow_fallen(t):
		return false
	scarecrows[t] = false
	scarecrows_changed.emit()
	return true


## 收走。不动背包。
func take_scarecrow(t: Vector2i) -> bool:
	if not scarecrows.erase(t):
		return false
	scarecrows_changed.emit()
	return true


func has_cat() -> bool:
	return GameState.has_flag(&"pet_cat")


## 这一格是不是在猫守着的那一片里。
func cat_guards(t: Vector2i) -> bool:
	return has_cat() and maxi(absi(CAT_HOME.x - t.x), absi(CAT_HOME.y - t.y)) <= CAT_RANGE


## 这一格有没有站着的稻草人或者家里的猫护着。
func is_guarded(t: Vector2i) -> bool:
	if cat_guards(t):
		return true
	for at: Vector2i in scarecrows:
		if not scarecrows[at] and maxi(absi(at.x - t.x), absi(at.y - t.y)) <= SCARE_RANGE:
			return true
	return false


## 大风过后：站着的稻草人各有一定概率被吹倒，返回倒了几个。
func blow_scarecrows(rng: RandomNumberGenerator) -> int:
	var n := 0
	for at: Vector2i in scarecrows:
		if not scarecrows[at] and rng.randf() < BLOW_CHANCE:
			scarecrows[at] = true
			n += 1
	if n > 0:
		scarecrows_changed.emit()
	return n


## 乌鸦来不来：广场灯亮了以后鸟才回到镇子周围；冬天没有。来了也不敢落在稻草人和猫守着的地方。
func crows_come() -> bool:
	return GameState.has_flag(&"lamp_plaza") and GameClock.season_id() != &"winter"


## 乌鸦能下嘴的格子：刚种下还没出苗的旱地作物，旁边没有站着的稻草人，也不在猫守着的那一片里。
func crow_targets() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for t: Vector2i in state.crops:
		if state.is_dead(t) or state.is_paddy(t) or state.crop_stage_at(t) > 0 or is_guarded(t):
			continue
		out.append(t)
	out.sort()
	return out


## 乌鸦刨走最多 count 处种子，返回被刨的格子。
func raid(count: int, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var targets := crow_targets()
	var eaten: Array[Vector2i] = []
	while eaten.size() < count and not targets.is_empty():
		var t: Vector2i = targets.pop_at(rng.randi_range(0, targets.size() - 1))
		state.uproot(t)
		eaten.append(t)
	return eaten


func save_data() -> Dictionary:
	var data := state.to_dict()
	data["trees"] = orchard.to_array()
	var list: Array = []
	for t: Vector2i in scarecrows:
		list.append([t.x, t.y, scarecrows[t]])
	data["scarecrows"] = list
	return data


func load_data(data: Dictionary) -> void:
	state.from_dict(data)
	var tree_list: Array = data.get("trees", [])
	orchard.from_array(tree_list)
	scarecrows.clear()
	raided.clear()
	var crow_list: Array = data.get("scarecrows", [])
	for entry: Variant in crow_list:
		if entry is Array and entry.size() >= 3:
			var e: Array = entry
			scarecrows[Vector2i(int(e[0]), int(e[1]))] = bool(e[2])
	scarecrows_changed.emit()


func reset_data() -> void:
	morning_notes.clear()
	state.clear()
	orchard.clear()
	scarecrows.clear()
	raided.clear()
	scarecrows_changed.emit()
