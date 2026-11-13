class_name Festivals
extends RefCounted
## 六个节日的规则。节日的日子、地点、站位在 data/festivals.json；这里只有静态函数，不是 autoload。
## 做过什么都记在 GameState 的标记里（fest_<事>_y<第几年>），所以每年能再来一回。
##
## - 播种节 sowing：阿禾的摊子多卖草莓种子；找柏先生报今天播了多少颗，和三位居民比。
## - 放河灯 lantern：找老周领一盏放下去；镇上有几个人放灯跟着主线的灯走。
## - 萤火夜 firefly：在草地上捉够萤火虫，找小满一起放掉；忆最深的那位居民会走过来说一段话。
## - 丰收集 harvest：拿着作物、鱼、畜产找柏先生评，各评一回，按售价和品质算分。
## - 饺子宴 dumpling：拿一样东西给云娘做馅，是什么口味决定席上说什么。
## - 除夕灯会 newyear：柏先生念这一年的账；守岁就是一觉到新年。灯笼挂多少看亮了几盏灯。

const DIALOGUE := "res://dialogue/festival.dialogue"
## 节日站位的日程项里的 note
const NOTE := "festival"
## 参加了节日的正事，在场的每位居民加这么多熟悉度
const JOIN_POINTS := 10
## 萤火夜：草地上一共这么多只，捉够这么多只就能去放
const FIREFLY_TOTAL := 8
const FIREFLY_GOAL := 5
## 除夕挂多少灯笼：亮着的灯不超过第 n 项就是第 n 档
const LANTERN_STEPS: Array[int] = [1, 3, 5]
const LANTERN_COUNTS: Array[int] = [4, 8, 14, 20]
const CATEGORY_NAMES: Dictionary[StringName, String] = {&"crop": "作物", &"fish": "鱼", &"animal": "畜产"}
## 没在馅料表里列出来的东西，按物品种类算口味；不在这里的种类包不了
const FLAVOR_BY_KIND: Dictionary[StringName, StringName] = {
	&"crop": &"veg", &"fish": &"fish", &"forage": &"wild", &"product": &"odd", &"food": &"odd", &"ore": &"odd",
}

## 最近一次活动的结果，给对话文件填空用（Residents.fest(key)）。不进存档。
static var said: Dictionary[String, String] = {}
## 今晚捉了几只萤火虫：[第几天, 只数]。只在睡觉时存档，所以不用存。
static var _caught: Array[int] = [-1, 0]
## 算好的站位：节日 id:居民 id -> 日程项
static var _spots: Dictionary[String, Dictionary] = {}


## 这位居民现在是不是守着台子收东西（丰收集评比、饺子宴收馅）：这时候手里的东西是交给台子的，不当礼物问。
static func takes_goods(npc_id: StringName) -> bool:
	var def := today()
	return def != null and is_open() and def.host == npc_id and def.keeper == npc_id


## 把不进存档的东西清掉（读档、新开一局时由 Residents 调）。
static func reset() -> void:
	said = {}
	_caught = [-1, 0]


# ---------------------------------------------------------------- 哪天、几点、谁在哪

## 今天的节日；不是节日返回 null。
static func today() -> FestivalDef:
	return Database.festival_on(GameClock.day)


## 节日是不是正开着。id 不为空时还要是这个节日。
static func is_open(id: StringName = &"") -> bool:
	var def := today()
	if def == null or (id != &"" and def.id != id):
		return false
	return GameClock.minutes >= def.from and GameClock.minutes < def.to


## 节日当天这位居民 minutes 时刻该在哪：开始以前返回空（照平常的日程），开着时是节日的站位，散了就回家。
static func spot(npc_id: StringName, minutes: float) -> Dictionary:
	var def := today()
	if def == null or int(minutes) < def.from or not Database.has_npc(npc_id):
		return {}
	if int(minutes) >= def.to:
		return NpcSchedule.HOME
	var key := "%s:%s" % [def.id, npc_id]
	if not _spots.has(key):
		var tile := def.tile_for(npc_id, _crowd_index(def, npc_id))
		if tile == FestivalDef.NO_TILE:
			_spots[key] = {}
		else:
			_spots[key] = {
				"from": def.from, "map": def.map, "tile": tile, "facing": _facing(tile, def.focus),
				"work": npc_id == def.keeper and npc_id != def.host, "note": NOTE,
			}
	return _spots[key]


## 这位居民现在是不是在节日上。
static func attending(npc_id: StringName) -> bool:
	return str(spot(npc_id, GameClock.minutes).get("note", "")) == NOTE


## 和节日上的居民搭话，播 festival.dialogue 里的哪一段；不归节日管返回空。
## 主持人每次都是 fest_<节日>_host；别人今天头一回搭话是 fest_<节日>_<居民>，之后照平常的说。
static func passage(npc_id: StringName, first_talk: bool) -> String:
	if not attending(npc_id):
		return ""
	var def := today()
	if npc_id == def.host:
		return "fest_%s_host" % def.id
	return "fest_%s_%s" % [def.id, npc_id] if first_talk else ""


## 节日摊子上多卖的东西。
static func goods() -> Array[StringName]:
	return today().goods if is_open() else ([] as Array[StringName])


## 早上醒来的提示：今天是什么节，昨晚有没有守岁。
static func morning_note() -> String:
	var lines := PackedStringArray()
	var last := Database.festival_on(GameClock.day - 1)
	if last != null and last.id == &"newyear" and GameState.has_flag(flag("vigil", GameClock.day - 1)):
		lines.append("守了一夜的岁。新的一年开始了")
	var def := today()
	if def != null:
		lines.append("今天是%s：%s" % [def.name, def.note])
	return "\n".join(lines)


## 这一年做没做过某件事的标记名。
static func flag(key: String, day: int = -1) -> StringName:
	var d := GameClock.day if day < 0 else day
	var year := (d - 1) / (GameClock.DAYS_PER_SEASON * GameClock.SEASONS_PER_YEAR) + 1
	return StringName("fest_%s_y%d" % [key, year])


static func done(key: String) -> bool:
	return GameState.has_flag(flag(key))


# ---------------------------------------------------------------- 各个节日

## 做一件节日上的事。返回 {"title": 接着播 festival.dialogue 的哪一段, "join": 是不是算参加了}；现在做不了返回空。
static func act(what: StringName) -> Dictionary:
	match what:
		&"sow":
			return _sow()
		&"float":
			return _once(&"lantern", "float", "fest_lantern_float")
		&"release":
			return _release()
		&"judge":
			return _judge()
		&"fill":
			return _fill()
		&"summary":
			return _summary()
		&"vigil":
			return _once(&"newyear", "vigil", "fest_newyear_vigil")
	return {}


## 名次：比自己成绩高的对手有几个，再加一。打平算玩家赢。
static func rank(score: int, rivals: Array) -> int:
	var place := 1
	for r: Dictionary in rivals:
		if int(r["score"]) > score:
			place += 1
	return place


static func prize(def: FestivalDef, place: int) -> int:
	return def.prizes[place - 1] if place >= 1 and place <= def.prizes.size() else 0


## 放河灯：今年哪些居民会放一盏。小满年年放；别人要等对应的灯亮了；最初的灯亮了以后人人都放。
static func floaters() -> Array[StringName]:
	var out: Array[StringName] = []
	var def := Database.festival(&"lantern")
	if def == null:
		return out
	for f in def.floaters:
		var lamp: StringName = f["lamp"]
		if lamp == &"" or Lamps.is_lit(lamp) or Story.lamp_lit():
			out.append(f["npc"])
	if Story.lamp_lit():
		for id: StringName in Database.npcs:
			if not out.has(id):
				out.append(id)
	return out


## 今晚捉了几只萤火虫。
static func caught() -> int:
	return _caught[1] if _caught[0] == GameClock.day else 0


## 捉到一只。节日没开、已经放过了、捉完了返回假。
static func catch_firefly() -> bool:
	if not is_open(&"firefly") or done("release") or caught() >= FIREFLY_TOTAL:
		return false
	_caught = [GameClock.day, caught() + 1]
	return true


## 草地上还飞着几只。
static func fireflies_left() -> int:
	if not is_open(&"firefly") or done("release"):
		return 0
	return FIREFLY_TOTAL - caught()


## 萤火夜来说心里话的居民：忆最深的那位（一样深取居民表里靠前的）；谁的忆都没找回过就没有人来。
static func heart_npc() -> StringName:
	var best: StringName = &""
	var level := 0
	for id: StringName in Database.npcs:
		if Residents.memory_level(id) > level:
			level = Residents.memory_level(id)
			best = id
	return best


## 萤火虫放掉了，那位居民还没来说话。
static func heart_due() -> bool:
	return is_open(&"firefly") and done("release") and not done("heart") and heart_npc() != &""


static func heart_told() -> void:
	GameState.set_flag(flag("heart"))


## 丰收集：这样东西归哪一项评；不收返回空。
static func category(item: ItemDef) -> StringName:
	if item == null:
		return &""
	if item.kind == &"crop" or item.kind == &"fish":
		return item.kind
	if item.kind == &"product" and _animal_goods().has(item.id):
		return &"animal"
	return &""


## 饺子宴：这样东西包进去算什么口味（veg 菜、fish 鱼、wild 野味、rich 蛋奶、sweet 甜、odd 怪）；包不了返回空。
static func flavor(item: ItemDef) -> StringName:
	if item == null:
		return &""
	var def := Database.festival(&"dumpling")
	if def != null:
		for kind: StringName in def.fillings:
			if def.fillings[kind].has(item.id):
				return kind
	return FLAVOR_BY_KIND.get(item.kind, &"")


## 主线的灯亮了几盏（最初的灯也算一盏）。
static func lit_count() -> int:
	var n := 0
	for id: StringName in Database.lamps:
		if Lamps.is_lit(id):
			n += 1
	return n + (1 if Story.lamp_lit() else 0)


## 除夕灯会的规模，0 到 3。
static func scale() -> int:
	var lit := lit_count()
	for i in LANTERN_STEPS.size():
		if lit <= LANTERN_STEPS[i]:
			return i
	return LANTERN_STEPS.size()


static func lantern_count() -> int:
	return LANTERN_COUNTS[scale()]


# ---------------------------------------------------------------- 内部

static func _crowd_index(def: FestivalDef, npc_id: StringName) -> int:
	var i := 0
	for id: StringName in Database.npcs:
		if id == def.host or id == def.keeper:
			continue
		if id == npc_id:
			return i
		i += 1
	return -1


## 站在 tile 上朝 focus 看，是 GameMap.Facing 的哪个方向（下 0、上 1、右 2、左 3）。
static func _facing(tile: Vector2i, focus: Vector2i) -> int:
	var d := focus - tile
	if absi(d.x) > absi(d.y):
		return 2 if d.x > 0 else 3
	return 1 if d.y < 0 else 0


static func _animal_goods() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in Database.animals:
		var a: AnimalDef = Database.animals[id]
		out.append(a.produce)
		if a.extra != &"":
			out.append(a.extra)
		for flower: StringName in a.honeys:
			out.append(a.honeys[flower])
	return out


## 一年做一回、做了就算参加的事。
static func _once(festival: StringName, key: String, title: String) -> Dictionary:
	if not is_open(festival) or done(key):
		return {}
	GameState.set_flag(flag(key))
	return {"title": title, "join": true}


## 播种比赛：今天在自家地里播了多少颗。一颗都没播不算数，可以播了再来。
static func _sow() -> Dictionary:
	if not is_open(&"sowing") or done("sow"):
		return {}
	var def := today()
	var count := Farming.sown_today
	if count <= 0:
		return {"title": "fest_sowing_none", "join": false}
	var rivals: Array = def.rivals.get(&"sow", [])
	var place := rank(count, rivals)
	var money := prize(def, place)
	GameState.money += money
	GameState.set_flag(flag("sow"))
	said = {"count": str(count), "rank": str(place), "prize": str(money), "best": _rival_text(rivals, "颗")}
	return {"title": "fest_sowing_result_%d" % mini(place, 4), "join": true}


## 萤火虫捉够了，和小满一起放掉。
static func _release() -> Dictionary:
	if not is_open(&"firefly") or done("release") or caught() < FIREFLY_GOAL:
		return {}
	said = {"count": str(caught())}
	GameState.set_flag(flag("release"))
	return {"title": "fest_firefly_release", "join": true}


## 丰收集评手里的这样东西：收走一个，按售价（带品质）和对手比。每项一年评一回。
static func _judge() -> Dictionary:
	if not is_open(&"harvest"):
		return {}
	var item := GameState.selected_item()
	var kind := category(item)
	if kind == &"":
		return {"title": "fest_harvest_reject", "join": false}
	var key := "judge_" + String(kind)
	said = {"item": item.name, "category": CATEGORY_NAMES[kind]}
	if done(key):
		return {"title": "fest_harvest_twice", "join": false}
	var def := today()
	var slot := GameState.selected_slot
	var score := item.price_for(GameState.inventory.quality_at(slot))
	if GameState.inventory.remove_at(slot, 1) != 1:
		return {}
	var rivals: Array = def.rivals.get(kind, [])
	var place := rank(score, rivals)
	var money := prize(def, place)
	GameState.money += money
	GameState.set_flag(flag(key))
	said["rank"] = str(place)
	said["prize"] = str(money)
	said["best"] = _rival_text(rivals, "分")
	return {"title": "fest_harvest_result_%d" % mini(place, 4), "join": true}


## 饺子宴：把手里的东西交给云娘做馅。吃完一桌饺子，体力回满。
static func _fill() -> Dictionary:
	if not is_open(&"dumpling") or done("fill"):
		return {}
	var item := GameState.selected_item()
	var kind := flavor(item)
	if kind == &"":
		return {"title": "fest_dumpling_reject", "join": false}
	if GameState.inventory.remove_at(GameState.selected_slot, 1) != 1:
		return {}
	said = {"item": item.name}
	GameState.set_flag(flag("fill"))
	GameState.energy = GameState.max_energy
	return {"title": "fest_dumpling_feast_" + String(kind), "join": true}


## 除夕：柏先生念这一年的账。
static func _summary() -> Dictionary:
	if not is_open(&"newyear"):
		return {}
	var met := 0
	for id: StringName in Database.npcs:
		if Residents.has_met(id):
			met += 1
	said = {
		"year": str(GameClock.year()), "income": str(Shipping.year_income), "lamps": str(lit_count()),
		"memories": str(Residents.recovered().size()), "fish": str(Fishing.records.size()),
		"depth": str(Mine.deepest), "met": str(met), "lanterns": str(lantern_count()),
	}
	return {"title": "fest_newyear_summary", "join": false}


## 对手里成绩最好的那位：“阿禾（20 颗）”。
static func _rival_text(rivals: Array, unit: String) -> String:
	if rivals.is_empty():
		return ""
	var top: Dictionary = rivals[0]
	return "%s（%d %s）" % [Database.npc(top["npc"]).name, int(top["score"]), unit]
