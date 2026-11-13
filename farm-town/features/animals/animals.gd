extends Node
## 养殖：农场上的建筑（请青竹盖）和住在里面的动物（找阿牧买）。蜜蜂和蚕也算“动物”，只是不出门、不用摸。
## 这里只存状态和规则；建筑和动物怎么画、站在哪儿由农场地图决定（动物的位置不进存档）。

signal changed
## 有动物被送走了：下标都变了，地图上的要重新放
signal roster_changed

const START_MOOD := 60
const MAX_MOOD := 100
## 喂了、摸了、没喂，心情各变多少
const FED_MOOD := 6
const PET_MOOD := 8
const HUNGRY_MOOD := -15
## 心情低于这个数，喂了也不产东西，牛也不肯干活
const SULK_MOOD := 20
## 心情到这两档，产物有机会是良、优
const GOOD_MOOD := 60
const GREAT_MOOD := 85
const FEED_ID := &"feed"
## 建筑里攒着没收的东西最多是容量的几倍
const STORE_PER_ANIMAL := 3
## 送回给阿牧按原价的几成算
const SELL_BACK := 0.5
## 一头牛一天最多犁几行、一行最多几格
const PLOW_ROWS := 6
const PLOW_LENGTH := 8

## 建筑 id -> 还要盖几天（0 是盖好了）
var buildings: Dictionary[StringName, int] = {}
## 每只动物：{"kind", "name", "mood", "fed", "petted", "days"（攒了几天没产）, "work"（今天犁了几行）}
var animals: Array[Dictionary] = []
## 建筑 id -> 攒着的产物 [[物品 id, 品质], ...]
var stores: Dictionary[StringName, Array] = {}
var morning_notes := PackedStringArray()
## 刚买的那只叫什么（给对话用）
var last_name := ""
## 蜂场附近现在开着什么花：func() -> StringName（作物 id，没有花是空）。由 game/ 接上，这里不认识种田。
var nectar := Callable()
## 哪一天摸过家里的猫狗（它不在 animals 里：养猫还是狗记在 GameState 的标记 pet_dog / pet_cat 上）
var pet_day := -1

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	SaveSystem.register(&"animals", self)
	GameClock.register_daily(GameClock.ORDER_ANIMALS, _on_new_day)
	_rng.randomize()


# ---------------------------------------------------------------- 建筑

func has_building(id: StringName) -> bool:
	return buildings.has(id)


func is_built(id: StringName) -> bool:
	return buildings.get(id, -1) == 0


func days_left(id: StringName) -> int:
	return buildings.get(id, 0)


## 给对话用：-1 没盖，0 盖好了，正数是还要几天。
func building_state(id: String) -> int:
	return buildings.get(StringName(id), -1)


## 青竹现在肯不肯接这栋建筑的活：对应的灯亮了、还没盖过、前置建筑有了。
func can_offer(id: String) -> bool:
	var key := StringName(id)
	if not Database.has_building(key) or buildings.has(key):
		return false
	var def := Database.building(key)
	if not GameState.has_flag(def.flag):
		return false
	return def.requires == &"" or is_built(def.requires)


## 青竹手上有没有能接的活。
func any_offer() -> bool:
	for id: StringName in Database.buildings:
		if can_offer(String(id)):
			return true
	return false


## 正在盖的那一栋叫什么、还要几天；没有在盖的返回空。
func building_now() -> String:
	for id: StringName in buildings:
		if buildings[id] > 0:
			return "%s还要 %d 天" % [Database.building(id).name, buildings[id]]
	return ""


func price(id: String) -> int:
	return Database.building(StringName(id)).price


func build_days(id: String) -> int:
	return Database.building(StringName(id)).days


## 订一栋建筑：付钱，第二天起开工。钱不够返回 false。
func order(id: String) -> bool:
	if not can_offer(id):
		return false
	var def := Database.building(StringName(id))
	if GameState.money < def.price:
		return false
	GameState.money -= def.price
	buildings[def.id] = maxi(1, def.days)
	changed.emit()
	return true


# ---------------------------------------------------------------- 动物

## 阿牧现在卖不卖这种：对应的灯亮了，而且有地方住。
func sells_kind(kind: String) -> bool:
	var key := StringName(kind)
	if not Database.has_animal(key):
		return false
	var def := Database.animal(key)
	return GameState.has_flag(def.flag) and room(String(def.building)) > 0


## 阿牧现在有没有能卖给你的。
func any_for_sale() -> bool:
	for id: StringName in Database.animals:
		if sells_kind(String(id)):
			return true
	return false


func count_in(building: StringName) -> int:
	var n := 0
	for a in animals:
		if Database.animal(a["kind"]).building == building:
			n += 1
	return n


## 这栋建筑还能住几只；没盖好就是 0。
func room(building: String) -> int:
	var key := StringName(building)
	if not is_built(key):
		return 0
	return maxi(0, Database.building(key).capacity - count_in(key))


func animal_price(kind: String) -> int:
	return Database.animal(StringName(kind)).price


## 买一只：要有地方住、付得起。成功后 last_name 是它的名字。
func buy(kind: String) -> bool:
	if not sells_kind(kind):
		return false
	var def := Database.animal(StringName(kind))
	if GameState.money < def.price:
		return false
	GameState.money -= def.price
	last_name = _pick_name(def)
	animals.append({"kind": def.id, "name": last_name, "mood": START_MOOD, "fed": false, "petted": false, "days": 0, "work": 0})
	changed.emit()
	return true


func _pick_name(def: AnimalDef) -> String:
	var used: Dictionary[String, bool] = {}
	for a in animals:
		used[str(a["name"])] = true
	var free: Array[String] = []
	for n in def.names:
		if not used.has(n):
			free.append(n)
	if free.is_empty():
		return "%s%d" % [def.name, animals.size() + 1]
	return free[_rng.randi() % free.size()]


## 这栋建筑里第 n 只（从 0 数）在 animals 里的下标；没有返回 -1。给对话里“送回哪一只”用。
func nth_in(building: String, n: int) -> int:
	var key := StringName(building)
	var k := 0
	for i in animals.size():
		if def_of(i).building == key:
			if k == n:
				return i
			k += 1
	return -1


func has_nth(building: String, n: int) -> bool:
	return nth_in(building, n) >= 0


## “咕咕（鸡，200 文）”
func nth_label(building: String, n: int) -> String:
	var i := nth_in(building, n)
	if i < 0:
		return ""
	return "%s（%s，%d 文）" % [name_of(i), def_of(i).name, sell_price(i)]


func sell_price(index: int) -> int:
	return int(def_of(index).price * SELL_BACK)


## 把这栋建筑里第 n 只送回给阿牧，拿回一半的钱。
func sell_nth(building: String, n: int) -> bool:
	var i := nth_in(building, n)
	if i < 0:
		return false
	last_name = name_of(i)
	GameState.money += sell_price(i)
	animals.remove_at(i)
	roster_changed.emit()
	changed.emit()
	return true


func def_of(index: int) -> AnimalDef:
	return Database.animal(animals[index]["kind"])


## 一共养了几只（蜂和蚕也算）。
func total() -> int:
	return animals.size()


## 心情最好的那只有多高兴；一只都没有是 0。
func happiest() -> int:
	var best := 0
	for a in animals:
		best = maxi(best, int(a["mood"]))
	return best


## 家里养的是猫还是狗：&"dog"、&"cat"，还没养是空。
func pet_kind() -> StringName:
	if GameState.has_flag(&"pet_dog"):
		return &"dog"
	return &"cat" if GameState.has_flag(&"pet_cat") else &""


## 摸一下家里的猫狗。今天头一回摸返回真。
func stroke_pet() -> bool:
	if pet_day == GameClock.day:
		return false
	pet_day = GameClock.day
	return true


func name_of(index: int) -> String:
	return str(animals[index]["name"])


func mood_of(index: int) -> int:
	return int(animals[index]["mood"])


## 今天不用再喂了：喂过，或者它本来就不用喂（蜜蜂）。
func is_fed(index: int) -> bool:
	return bool(animals[index]["fed"]) or def_of(index).feed == &""


func is_petted(index: int) -> bool:
	return bool(animals[index]["petted"])


## 心情的说法。
func mood_text(index: int) -> String:
	var m := mood_of(index)
	if m >= GREAT_MOOD:
		return "很高兴"
	if m >= GOOD_MOOD:
		return "挺好"
	if m >= SULK_MOOD:
		return "不太高兴"
	return "闷闷不乐"


## 喂一只：用掉一份它吃的东西。今天喂过了、没有饲料返回 false。
func feed(index: int) -> bool:
	if index < 0 or index >= animals.size() or is_fed(index):
		return false
	if not GameState.inventory.remove(def_of(index).feed, 1):
		return false
	animals[index]["fed"] = true
	changed.emit()
	return true


## 把这栋建筑里吃 item 又还没喂的都喂上，有几份喂几只。返回喂了几只。
func feed_all(building: StringName, item: StringName = FEED_ID) -> int:
	var n := 0
	for i in animals.size():
		var def := def_of(i)
		if def.building == building and def.feed == item and not is_fed(i) and GameState.inventory.remove(item, 1):
			animals[i]["fed"] = true
			n += 1
	if n > 0:
		changed.emit()
	return n


## 这栋建筑里今天还有几只没喂。给了 item 就只数吃这样东西的。
func hungry_in(building: StringName, item: StringName = &"") -> int:
	var n := 0
	for i in animals.size():
		var def := def_of(i)
		if def.building == building and not is_fed(i) and (item == &"" or def.feed == item):
			n += 1
	return n


## 摸一下：每天第一次加心情。
func pet(index: int) -> bool:
	if index < 0 or index >= animals.size() or is_petted(index):
		return false
	animals[index]["petted"] = true
	animals[index]["mood"] = mini(MAX_MOOD, mood_of(index) + PET_MOOD)
	changed.emit()
	return true


## 这头牛今天还肯不肯犁地。
func can_plow(index: int) -> bool:
	if index < 0 or index >= animals.size() or not def_of(index).plows:
		return false
	return mood_of(index) >= SULK_MOOD and int(animals[index].get("work", 0)) < PLOW_ROWS


func plows_left(index: int) -> int:
	return maxi(0, PLOW_ROWS - int(animals[index].get("work", 0)))


func plowed(index: int) -> void:
	if index >= 0 and index < animals.size():
		animals[index]["work"] = int(animals[index].get("work", 0)) + 1


# ---------------------------------------------------------------- 产物

func stored(building: StringName) -> int:
	var list: Array = stores.get(building, [])
	return list.size()


## 把建筑里攒的东西拿进背包，放不下的留着。返回拿到的 [物品 id, 品质] 列表。
func collect(building: StringName) -> Array:
	var list: Array = stores.get(building, [])
	var got: Array = []
	var left: Array = []
	for e: Array in list:
		var id: StringName = e[0]
		var q: int = e[1]
		if GameState.inventory.can_add(id, 1, q):
			GameState.inventory.add(id, 1, q)
			got.append(e)
		else:
			left.append(e)
	stores[building] = left
	if not got.is_empty():
		changed.emit()
	return got


## 心情换成产物的品质。
static func quality_for(mood: int, roll: float) -> int:
	if mood >= GREAT_MOOD:
		return 2 if roll < 0.5 else 1
	if mood >= GOOD_MOOD:
		return 1 if roll < 0.4 else 0
	return 0


## 这种动物今天产什么。蜜蜂看附近的花：有认得的花出那种蜜，没有就是野花蜜，冬天没花不出蜜。
func produce_of(def: AnimalDef) -> StringName:
	if def.honeys.is_empty():
		return def.produce
	var flower: StringName = nectar.call() if nectar.is_valid() else &""
	if def.honeys.has(flower):
		return def.honeys[flower]
	return &"" if GameClock.season_id() == &"winter" else def.produce


# ---------------------------------------------------------------- 每日结算

func _on_new_day() -> void:
	morning_notes.clear()
	settle(Weather.yesterday == Weather.RAIN or Weather.yesterday == Weather.STORM)


## 过一夜：盖房子的进度、昨天喂过的产东西、心情涨落。rainy 是昨天下没下雨。
func settle(rainy: bool) -> void:
	for id: StringName in buildings.keys():
		if buildings[id] > 0:
			buildings[id] -= 1
			if buildings[id] == 0:
				morning_notes.append("青竹把%s盖好了" % Database.building(id).name)
	var laid: Dictionary[StringName, int] = {}
	for i in animals.size():
		var a := animals[i]
		var def := def_of(i)
		var mood := int(a["mood"])
		if is_fed(i):
			if mood >= SULK_MOOD:
				a["days"] = int(a.get("days", 0)) + 1
				if int(a["days"]) >= def.every:
					a["days"] = 0
					var item := produce_of(def)
					if item != &"":
						_store(def.building, item, quality_for(mood, _rng.randf()))
						laid[def.building] = int(laid.get(def.building, 0)) + 1
					if def.extra != &"" and _rng.randf() < def.extra_chance:
						_store(def.building, def.extra, 0)
			if def.feed != &"":
				mood += FED_MOOD
		else:
			mood += HUNGRY_MOOD
		if rainy and def.outdoor:
			mood += def.rain_mood
		a["mood"] = clampi(mood, 0, MAX_MOOD)
		a["fed"] = false
		a["petted"] = false
		a["work"] = 0
	for building: StringName in laid:
		morning_notes.append("%s里有东西可以收" % Database.building(building).name)
	changed.emit()


func _store(building: StringName, item: StringName, quality: int) -> void:
	if not stores.has(building):
		stores[building] = []
	var list: Array = stores[building]
	if list.size() < Database.building(building).capacity * STORE_PER_ANIMAL:
		list.append([item, quality])


# ---------------------------------------------------------------- 存档

func save_data() -> Dictionary:
	var out_buildings := {}
	for id: StringName in buildings:
		out_buildings[String(id)] = buildings[id]
	var out_animals: Array = []
	for a in animals:
		out_animals.append({"kind": String(a["kind"]), "name": a["name"], "mood": a["mood"], "fed": a["fed"],
			"petted": a["petted"], "days": a.get("days", 0), "work": a.get("work", 0)})
	var out_stores := {}
	for id: StringName in stores:
		var list: Array = []
		for e: Array in stores[id]:
			list.append([String(e[0]), e[1]])
		out_stores[String(id)] = list
	return {"buildings": out_buildings, "animals": out_animals, "stores": out_stores, "pet_day": pet_day}


func load_data(data: Dictionary) -> void:
	buildings.clear()
	animals.clear()
	stores.clear()
	pet_day = int(data.get("pet_day", -1))
	var saved_buildings: Dictionary = data.get("buildings", {})
	for key: Variant in saved_buildings:
		var id := StringName(str(key))
		if Database.has_building(id):
			buildings[id] = maxi(0, int(saved_buildings[key]))
	var saved_animals: Array = data.get("animals", [])
	for entry: Variant in saved_animals:
		if not (entry is Dictionary):
			continue
		var e: Dictionary = entry
		var kind := StringName(str(e.get("kind", "")))
		if not Database.has_animal(kind):
			continue
		animals.append({
			"kind": kind,
			"name": str(e.get("name", Database.animal(kind).name)),
			"mood": clampi(int(e.get("mood", START_MOOD)), 0, MAX_MOOD),
			"fed": bool(e.get("fed", false)),
			"petted": bool(e.get("petted", false)),
			"days": maxi(0, int(e.get("days", 0))),
			"work": maxi(0, int(e.get("work", 0))),
		})
	var saved_stores: Dictionary = data.get("stores", {})
	for key: Variant in saved_stores:
		var id := StringName(str(key))
		if not Database.has_building(id):
			continue
		var list: Array = []
		for entry: Variant in saved_stores[key]:
			if entry is Array and entry.size() >= 2:
				var item := StringName(str(entry[0]))
				if Database.has_item(item):
					list.append([item, clampi(int(entry[1]), 0, 2)])
		stores[id] = list
	roster_changed.emit()
	changed.emit()


func reset_data() -> void:
	buildings.clear()
	animals.clear()
	stores.clear()
	morning_notes.clear()
	last_name = ""
	pet_day = -1
	roster_changed.emit()
	changed.emit()
