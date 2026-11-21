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
## 农舍桌上摆着的菜，一种一道，最多八席。
const TABLE_MAX := 8
## 凑齐这八样，才能请大家吃饭。
const FEAST: Array[StringName] = [
	&"stir_greens", &"tomato_egg", &"oil_shrimp", &"steamed_crab",
	&"radish_soup", &"fish_soup", &"egg_fried_rice", &"osmanthus_cake",
]
var table_dishes: Array[StringName] = []
## 和桌上的菜一一对应，摆上去时的品质。0 普通，1 良，2 优。
var table_quality: Array[int] = []
## 头一回做成过的菜。再做只演一秒。
var made_dishes: Array[StringName] = []
## 火候正好出过锅的菜。只是食单上的一个印，不改品质和价钱（决策 101）。
var heat_dishes: Array[StringName] = []
const COOK_LONG := 2.4
const COOK_SHORT := 1.0
## 敲石头、雾天、山野，低于这个数才掉半张残页。
const SCRAP_CHANCE := 0.2
const ODD_BOWL := &"odd_bowl"
const ODD_FLAG := &"odd_bowl_made"
const TRIAL_BLOCK: Array[StringName] = [
	&"tool", &"weapon", &"accessory", &"relic", &"seed", &"sapling", &"fertilizer", &"gear",
]


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
	GameState.inventory.clear_fresh()
	for id: StringName in jobs:
		var job: Dictionary = jobs[id]
		job["days"] = maxi(0, int(job["days"]) - 1)
	changed.emit()


# ---------------------------------------------------------------- 烹饪

func knows(recipe_id: StringName) -> bool:
	if not Database.recipes.has(recipe_id):
		return false
	var def: RecipeDef = Database.recipes[recipe_id]
	if def.from == &"odd":
		return false
	if def.from == &"memory":
		if def.teacher == &"lan":
			return Story.lan_level() >= def.need_level
		return Residents.memory_level(def.teacher) >= def.need_level
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


## 今天是不是这道菜写的那个节气。
func in_term(def: RecipeDef) -> bool:
	return def.term != &"" and def.term == GameClock.term_id()


## 材料新鲜：会过季的都当季，鱼和蛋是今天拿到的。没有这类材料就不算。
## kept 的菜不要求作物当季，鱼和蛋仍要当天。
func is_fresh(def: RecipeDef) -> bool:
	var any := false
	for item_id: StringName in def.ingredients:
		if not _perishable(item_id, def.kept):
			continue
		any = true
		if not _ingredient_fresh(item_id, def.ingredients[item_id]):
			return false
	return any


## 当令高一档，新鲜再高一档，到优为止。
func plate_quality(def: RecipeDef) -> int:
	var q := 0
	if in_term(def):
		q += 1
	if is_fresh(def):
		q += 1
	return mini(q, 2)


## 做一份，放进背包。材料不够返回 false。
func cook(recipe_id: StringName) -> bool:
	if servings(recipe_id) < 1:
		return false
	var def: RecipeDef = Database.recipes[recipe_id]
	var quality := plate_quality(def)
	var term := in_term(def)
	var fresh := is_fresh(def)
	var snap: Dictionary = GameState.inventory.fresh.duplicate()
	for item_id: StringName in def.ingredients:
		GameState.inventory.remove(item_id, def.ingredients[item_id])
	if GameState.inventory.add(recipe_id, 1, quality, term, false) > 0:
		for item_id: StringName in def.ingredients:
			GameState.inventory.add(item_id, def.ingredients[item_id], 0, false, false)
		GameState.inventory.restore_fresh(snap)
		return false
	if fresh:
		_spend_fresh(def)
	if term:
		_term_pending[recipe_id] = true
	last_plate = {"id": recipe_id, "q": quality, "t": term}
	changed.emit()
	return true


## 刚出锅的那一份：哪道菜、什么品质、是不是当令。亲手做到拿手时按这个找到它，抬一档。不进存档。
var last_plate: Dictionary = {}


## 亲手做到拿手：把刚出锅的那一份抬高一档品质，到优为止。
## 已经是优、那一份已经不在背包里、或者换了档以后放不下，就不动，返回 false。
func raise_plate(id: StringName) -> bool:
	if last_plate.get("id", &"") != id:
		return false
	var q := int(last_plate["q"])
	var term := bool(last_plate["t"])
	last_plate = {}
	if q >= 2:
		return false
	var inv := GameState.inventory
	for i in inv.size:
		if inv.id_at(i) != id or inv.quality_at(i) != q or inv.term_at(i) != term:
			continue
		inv.remove_at(i, 1)
		if inv.add(id, 1, q + 1, term, false) > 0:
			inv.add(id, 1, q, term, false)
			return false
		changed.emit()
		return true
	return false


## 厨艺到了第几档：没有称呼是 0，帮厨 1，掌勺 2，大师傅 3。
func rank_level() -> int:
	return RANK_ORDER.find(rank) + 1


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


## 手上这道菜能不能摆上桌：是菜谱做出来的、背包里有、桌上还没有、没满。
func place_dish(id: StringName) -> bool:
	if not Database.recipes.has(id) or table_dishes.has(id) or table_dishes.size() >= TABLE_MAX:
		return false
	var slot := _held_slot(id)
	if slot < 0:
		return false
	var quality := GameState.inventory.quality_at(slot)
	if GameState.inventory.remove_at(slot, 1) <= 0:
		return false
	table_dishes.append(id)
	table_quality.append(quality)
	_check_sets()
	changed.emit()
	return true


## 手里这格是这道菜就用这格，否则用背包里第一格。
func _held_slot(id: StringName) -> int:
	var held := GameState.selected_slot
	if GameState.inventory.id_at(held) == id:
		return held
	for i in GameState.inventory.size:
		if GameState.inventory.id_at(i) == id:
			return i
	return -1


## 请客加的熟悉度。比送礼少，菜的好处在人，不在刷。
const HOST_POINTS: Dictionary[StringName, int] = {&"love": 20, &"like": 10, &"ok": 4, &"dislike": 0}
## 吃到最喜欢的，头一回多说一句平日不说的。
const HOST_ASIDE: Dictionary[StringName, String] = {
	&"xiaoman": "她说，这个甜，比刚摘的还想再要一碗。",
	&"jiang": "她说，这味道像药铺后头那锅。",
	&"yunniang": "她哼了一句，平日灶上不哼这个。",
	&"ahe": "他说，这种吃法城里没有。",
	&"laozhou": "他说起儿子，说这孩子以前也挑这个。",
}
## 请过几桌。以后称号用，现在只记着。
var meals := 0


func feast_ready() -> bool:
	for id: StringName in FEAST:
		if not table_dishes.has(id):
			return false
	return true


## 这一桌对这位居民是什么反应。菜本身和材料都算，就高不就低。
func taste_of_table(who: StringName, dishes: Array[StringName]) -> StringName:
	var best := &"ok"
	var hated := false
	for dish: StringName in dishes:
		if not Database.recipes.has(dish):
			continue
		var rec: RecipeDef = Database.recipes[dish]
		var ids: Array[StringName] = [dish]
		for item_id: StringName in rec.ingredients:
			ids.append(item_id)
		for item_id: StringName in ids:
			var taste := Database.npc(who).taste_of(item_id)
			if taste == &"love":
				return &"love"
			if taste == &"like":
				best = &"like"
			elif taste == &"dislike":
				hated = true
	if best == &"like":
		return &"like"
	return &"dislike" if hated else &"ok"


## 请这些人吃掉桌上的菜。一个人每天一次，一到三位，没见过面不行。八席齐了走原来的席，不从这里请。
## 成功返回每人一句，菜撤下。请不成返回空，桌上不动。
func host(ids: Array[StringName]) -> PackedStringArray:
	var lines := PackedStringArray()
	if feast_ready() or table_dishes.is_empty() or ids.is_empty() or ids.size() > 3:
		return lines
	var seen: Dictionary[StringName, bool] = {}
	for id: StringName in ids:
		if seen.has(id) or not Database.has_npc(id) or not Residents.has_met(id):
			return lines
		if Residents.hosted_today.get(id, false):
			return lines
		seen[id] = true
	var dishes: Array[StringName] = []
	dishes.assign(table_dishes)
	for id: StringName in ids:
		var taste := taste_of_table(id, dishes)
		Residents.hosted_today[id] = true
		Residents.add_familiarity(id, int(HOST_POINTS[taste]))
		lines.append(_host_line(id, taste, dishes))
	meals += 1
	clear_table()
	return lines


func _host_line(who: StringName, taste: StringName, dishes: Array[StringName]) -> String:
	var name := Database.npc(who).name
	var liked := _liked_name(who, dishes)
	var line := ""
	match taste:
		&"love":
			line = "%s吃到%s，停了一下。" % [name, liked]
			var flag := StringName("table_said_" + String(who))
			if HOST_ASIDE.has(who) and not GameState.has_flag(flag):
				GameState.set_flag(flag)
				line += HOST_ASIDE[who]
		&"like":
			line = "%s把%s吃完了。" % [name, liked]
		&"dislike":
			line = "%s动了动筷子，没怎么吃。" % name
		_:
			line = "%s坐下吃了。" % name
	return line


func _liked_name(who: StringName, dishes: Array[StringName]) -> String:
	var fallback := Database.item(dishes[0]).name
	for dish: StringName in dishes:
		var rec: RecipeDef = Database.recipes[dish]
		var ids: Array[StringName] = [dish]
		for item_id: StringName in rec.ingredients:
			ids.append(item_id)
		for item_id: StringName in ids:
			var taste := Database.npc(who).taste_of(item_id)
			if taste == &"love" or taste == &"like":
				return Database.item(item_id).name
	return fallback


## 这道菜的过程演多久。头一回长，以后短。
func cook_seconds(id: StringName) -> float:
	return COOK_SHORT if made_dishes.has(id) else COOK_LONG


## 这道菜有没有火候印。
func has_heat(id: StringName) -> bool:
	return heat_dishes.has(id)


## 火候正好出了一回锅，记下。
func mark_heat(id: StringName) -> void:
	if not Database.recipes.has(id) or heat_dishes.has(id):
		return
	heat_dishes.append(id)
	changed.emit()


## 见过面的人里谁最爱这一口（菜本身或材料）。出锅时念这个名字；没有就返回空。
func fond_of(id: StringName) -> String:
	var who := fond_id(id)
	return Database.npc(who).name if who != &"" else ""


## 同上，返回那个人的 id；没有就返回空。
func fond_id(id: StringName) -> StringName:
	if not Database.recipes.has(id):
		return &""
	var rec: RecipeDef = Database.recipes[id]
	var ids: Array[StringName] = [id]
	for item_id: StringName in rec.ingredients:
		ids.append(item_id)
	for who: StringName in Database.npcs:
		if not Residents.has_met(who):
			continue
		for item_id: StringName in ids:
			if Database.npc(who).taste_of(item_id) == &"love":
				return who
	return &""


func mark_cooked(id: StringName) -> void:
	if bool(_term_pending.get(id, false)) and not term_made.has(id):
		term_made.append(id)
	_term_pending.erase(id)
	if made_dishes.has(id):
		changed.emit()
		return
	made_dishes.append(id)
	_check_sets()
	changed.emit()


const RANK_ORDER: Array[StringName] = [&"helper", &"wok", &"master"]
const RANK_NAMES: Dictionary[StringName, String] = {
	&"helper": "帮厨", &"wok": "掌勺", &"master": "大师傅",
}
## 做过几道、其中当令几道、请过几桌。够了才轮到下一档，不能跳。
const RANK_NEED: Array[Vector3i] = [Vector3i(6, 0, 0), Vector3i(14, 3, 2), Vector3i(24, 6, 5)]
var rank: StringName = &""
var term_made: Array[StringName] = []
var _term_pending: Dictionary[StringName, bool] = {}


func rank_name() -> String:
	return RANK_NAMES.get(rank, "")


func rank_ready() -> bool:
	return pending_rank() != &""


func pending_rank() -> StringName:
	var next := RANK_ORDER.find(rank) + 1
	if next >= RANK_ORDER.size():
		return &""
	var need := RANK_NEED[next]
	if made_dishes.size() < need.x or term_made.size() < need.y or meals < need.z:
		return &""
	return RANK_ORDER[next]


func grant_rank() -> void:
	var id := pending_rank()
	if id == &"":
		return
	rank = id
	EventBus.banner_requested.emit("云娘称你为" + RANK_NAMES[id])
	changed.emit()
	if Story.side_ready(Story.ESTATE):
		Story.begin_side("estate")


func is_scrap(id: StringName) -> bool:
	return String(id).begins_with("scrap_") and Database.has_item(id)


## 这一半残页属于哪道菜。不是残页就返回空。
func scrap_recipe(id: StringName) -> StringName:
	if not is_scrap(id):
		return &""
	var body := String(id).substr(6)
	var cut := body.rfind("_")
	if cut <= 0:
		return &""
	return StringName(body.substr(0, cut))


## roll 小于 SCRAP_CHANCE 时，从还没拿到的那一半里挑一张。已经会的菜不再掉。
func offer_scrap(place: StringName, roll: float) -> StringName:
	if roll >= SCRAP_CHANCE:
		return &""
	var busy := Foraging.scrap_held()
	var pool: Array[StringName] = []
	for id: StringName in Database.recipes:
		var rec: RecipeDef = Database.recipes[id]
		if rec.scrap.size() != 2 or knows(id):
			continue
		for half in 2:
			if rec.scrap[half] != place:
				continue
			var hid := RecipeDef.scrap_item(id, half)
			if GameState.inventory.count_of(hid) > 0 or busy.has(hid):
				continue
			pool.append(hid)
	if pool.is_empty():
		return &""
	var index := int(roll / SCRAP_CHANCE * float(pool.size()))
	return pool[mini(index, pool.size() - 1)]


## 手里拿着这一半按使用。凑齐左右两半才学会，两张都收走。
func read_scrap(id: StringName) -> String:
	var recipe_id := scrap_recipe(id)
	if recipe_id == &"" or not Database.recipes.has(recipe_id):
		return ""
	var half := int(String(id).substr(String(id).rfind("_") + 1))
	var other := RecipeDef.scrap_item(recipe_id, 1 - half)
	if GameState.inventory.count_of(id) < 1:
		return ""
	if GameState.inventory.count_of(other) < 1:
		return "只有半张，看不全"
	GameState.inventory.remove(id, 1)
	GameState.inventory.remove(other, 1)
	var dish := Database.item(recipe_id).name
	if knows(recipe_id):
		return "这道你会了：" + dish
	GameState.set_flag(Database.recipes[recipe_id].known_flag())
	changed.emit()
	return "看懂了：" + dish


## 三样材料下锅。对上会做的、或云娘会教的，就做出那道并学会；忆里的菜对不上。
## 两道一样贴、或哪道都不像，得到说不上来的东西。放不下时一样都不扣，返回空。
func experiment(ids: Array[StringName]) -> StringName:
	if ids.size() != 3:
		return &""
	for id: StringName in ids:
		if not Database.has_item(id) or TRIAL_BLOCK.has(Database.item(id).kind):
			return &""
	if not _can_take(ids):
		return &""
	var best := &""
	var best_score := -1
	var best_keys := -1
	var tie := false
	for id: StringName in Database.recipes:
		var rec: RecipeDef = Database.recipes[id]
		if rec.from == &"odd":
			continue
		if rec.from == &"memory" and not knows(id):
			continue
		var score := _fit_score(rec, ids)
		if score <= 0:
			continue
		var keys := rec.ingredients.size()
		if score > best_score or (score == best_score and keys > best_keys):
			best = id
			best_score = score
			best_keys = keys
			tie = false
		elif score == best_score and keys == best_keys and id != best:
			tie = true
	var made := ODD_BOWL if tie or best == &"" else best
	if made == ODD_BOWL and not tie and Bestiary.zaojun_helps():
		var near := _near_recipe(ids)
		if near != &"":
			made = near
	var made_def: RecipeDef = Database.recipes[made]
	var quality := 0 if made == ODD_BOWL else plate_quality(made_def)
	var term := false if made == ODD_BOWL else in_term(made_def)
	var fresh := false if made == ODD_BOWL else is_fresh(made_def)
	var snap: Dictionary = GameState.inventory.fresh.duplicate()
	_take(ids)
	if GameState.inventory.add(made, 1, quality, term, false) > 0:
		for id: StringName in ids:
			GameState.inventory.add(id, 1, 0, false, false)
		GameState.inventory.restore_fresh(snap)
		return &""
	if fresh:
		_spend_fresh(made_def)
	if term:
		_term_pending[made] = true
	last_plate = {"id": made, "q": quality, "t": term}
	if made != ODD_BOWL:
		var learned: RecipeDef = Database.recipes[made]
		if not knows(made) and learned.from != &"start" and learned.from != &"memory":
			GameState.set_flag(learned.known_flag())
	else:
		GameState.set_flag(ODD_FLAG)
	changed.emit()
	return made


## 祭过灶君的这一年：没有整道对上时，差一种材料、而且比别的菜更贴的那道算试对。
func _near_recipe(ids: Array[StringName]) -> StringName:
	var best := &""
	var best_score := 0
	var tie := false
	for id: StringName in Database.recipes:
		var rec: RecipeDef = Database.recipes[id]
		if rec.from == &"odd":
			continue
		if rec.from == &"memory" and not knows(id):
			continue
		var keys := rec.ingredients.size()
		var score := _partial_score(rec, ids)
		if keys < 2 or score <= 0 or score >= keys:
			continue
		if score > best_score:
			best = id
			best_score = score
			tie = false
		elif score == best_score and id != best:
			tie = true
	if tie or best == &"":
		return &""
	return best


func _partial_score(rec: RecipeDef, ids: Array[StringName]) -> int:
	var score := 0
	for item_id: StringName in rec.ingredients:
		var have := 0
		for id: StringName in ids:
			if id == item_id:
				have += 1
		if have >= int(rec.ingredients[item_id]):
			score += 1
	return score


func _fit_score(rec: RecipeDef, ids: Array[StringName]) -> int:
	var score := 0
	for item_id: StringName in rec.ingredients:
		var have := 0
		for id: StringName in ids:
			if id == item_id:
				have += 1
		var need: int = rec.ingredients[item_id]
		if have < need:
			return 0
		score += need
	return score


func _can_take(ids: Array[StringName]) -> bool:
	var need: Dictionary[StringName, int] = {}
	for id: StringName in ids:
		need[id] = int(need.get(id, 0)) + 1
	for id: StringName in need:
		if GameState.inventory.count_of(id) < int(need[id]):
			return false
	return true


func _spend_fresh(def: RecipeDef) -> void:
	for item_id: StringName in def.ingredients:
		var item := Database.item(item_id)
		if item.kind == &"fish" or item_id == &"egg" or item_id == &"duck_egg":
			GameState.inventory.use_fresh(item_id, def.ingredients[item_id])


func _perishable(item_id: StringName, kept: bool) -> bool:
	var item := Database.item(item_id)
	if item.kind == &"fish" or item_id == &"egg" or item_id == &"duck_egg":
		return true
	if kept:
		return false
	return _season_window(item_id)


## 这种东西是不是只在部分季节才算当季。一年到头都有的不算。
func _season_window(item_id: StringName) -> bool:
	for crop_id: StringName in Database.crops:
		var crop: CropDef = Database.crops[crop_id]
		if crop.produce == item_id or crop.bonus_produce == item_id:
			return not crop.seasons.is_empty()
	var tree_seasons: Array[StringName] = []
	for tree_id: StringName in Database.trees:
		var tree: TreeDef = Database.trees[tree_id]
		for y: Dictionary in tree.yields:
			if StringName(str(y.get("item", ""))) == item_id:
				tree_seasons.append(StringName(str(y.get("season", ""))))
	if not tree_seasons.is_empty():
		return tree_seasons.size() < Database.SEASON_IDS.size()
	var limited := false
	for forage: ForageDef in Database.forage:
		if forage.item != item_id:
			continue
		if forage.season == &"":
			return false
		limited = true
	if limited:
		return true
	return Database.item(item_id).flower != &""


func _in_season(item_id: StringName) -> bool:
	var now := GameClock.season_id()
	for crop_id: StringName in Database.crops:
		var crop: CropDef = Database.crops[crop_id]
		if crop.produce == item_id or crop.bonus_produce == item_id:
			return crop.seasons.is_empty() or crop.seasons.has(now)
	var saw_tree := false
	for tree_id: StringName in Database.trees:
		var tree: TreeDef = Database.trees[tree_id]
		for y: Dictionary in tree.yields:
			if StringName(str(y.get("item", ""))) != item_id:
				continue
			saw_tree = true
			if StringName(str(y.get("season", ""))) == now:
				return true
	if saw_tree:
		return false
	var saw_forage := false
	for forage: ForageDef in Database.forage:
		if forage.item != item_id:
			continue
		saw_forage = true
		if forage.in_season(now):
			return true
	if saw_forage:
		return false
	var item := Database.item(item_id)
	if item.flower != &"":
		return item.flower == now
	return true


func _ingredient_fresh(item_id: StringName, need: int) -> bool:
	var item := Database.item(item_id)
	if item.kind == &"fish" or item_id == &"egg" or item_id == &"duck_egg":
		return GameState.inventory.fresh_of(item_id) >= need
	return _in_season(item_id)


func _take(ids: Array[StringName]) -> void:
	var need: Dictionary[StringName, int] = {}
	for id: StringName in ids:
		need[id] = int(need.get(id, 0)) + 1
	for id: StringName in need:
		GameState.inventory.remove(id, int(need[id]))


func clear_table() -> void:
	table_dishes.clear()
	table_quality.clear()
	changed.emit()


## 三块牌：节气菜做全、人家的菜做全、桌上八道都是优。挂上就留着。
const SETS: Array[StringName] = [&"terms", &"homes", &"fine"]
const SET_NAMES: Dictionary[StringName, String] = {
	&"terms": "节气牌", &"homes": "人家牌", &"fine": "优席牌",
}
var sets: Array[StringName] = []


func has_set(id: StringName) -> bool:
	return sets.has(id)


func _terms_complete() -> bool:
	var any := false
	for id: StringName in Database.recipes:
		var def: RecipeDef = Database.recipes[id]
		if def.term == &"":
			continue
		any = true
		if not made_dishes.has(id):
			return false
	return any


func _homes_complete() -> bool:
	var any := false
	for id: StringName in Database.recipes:
		var def: RecipeDef = Database.recipes[id]
		if def.from != &"memory":
			continue
		any = true
		if not made_dishes.has(id):
			return false
	return any


func _fine_complete() -> bool:
	if table_dishes.size() != TABLE_MAX or table_quality.size() != TABLE_MAX:
		return false
	for q: int in table_quality:
		if q < 2:
			return false
	return true


func _check_sets() -> void:
	var ready: Array[StringName] = []
	if _terms_complete():
		ready.append(&"terms")
	if _homes_complete():
		ready.append(&"homes")
	if _fine_complete():
		ready.append(&"fine")
	for id: StringName in ready:
		if sets.has(id):
			continue
		sets.append(id)
		EventBus.banner_requested.emit("墙上挂上了%s。" % SET_NAMES[id])


## 见过的人下一回搭话，提起一块还没对这个人说过的牌。
func mention_set(npc_id: StringName) -> void:
	if not Database.has_npc(npc_id):
		return
	for id: StringName in SETS:
		if not sets.has(id):
			continue
		var flag := StringName("set_said_%s_%s" % [npc_id, id])
		if GameState.has_flag(flag):
			continue
		GameState.set_flag(flag)
		EventBus.banner_requested.emit("%s提起墙上的%s。" % [Database.npc(npc_id).name, SET_NAMES[id]])
		return


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
	var dishes: Array[String] = []
	for id: StringName in table_dishes:
		dishes.append(String(id))
	var made: Array[String] = []
	for id: StringName in made_dishes:
		made.append(String(id))
	var terms: Array[String] = []
	for id: StringName in term_made:
		terms.append(String(id))
	var qualities: Array[int] = []
	for q: int in table_quality:
		qualities.append(q)
	var held: Array[String] = []
	for id: StringName in sets:
		held.append(String(id))
	var heats: Array[String] = []
	for id: StringName in heat_dishes:
		heats.append(String(id))
	return {"jobs": out, "lesson_day": _lesson_day, "table": dishes, "table_q": qualities, "made": made, "meals": meals, "term_made": terms, "rank": String(rank), "sets": held, "heat": heats}


func load_data(data: Dictionary) -> void:
	jobs.clear()
	table_dishes.clear()
	table_quality.clear()
	sets.clear()
	made_dishes.clear()
	term_made.clear()
	meals = maxi(0, int(data.get("meals", 0)))
	rank = StringName(str(data.get("rank", "")))
	if RANK_ORDER.find(rank) < 0:
		rank = &""
	var saved: Dictionary = data.get("jobs", {})
	for key: Variant in saved:
		var job: Dictionary = saved[key]
		var id := StringName(str(key))
		var out := StringName(str(job.get("output", "")))
		if not Database.machines.has(id) or not Database.has_item(out):
			continue
		jobs[id] = {"output": out, "quality": clampi(int(job.get("quality", 0)), 0, 2), "count": maxi(1, int(job.get("count", 1))), "days": maxi(0, int(job.get("days", 0)))}
	_lesson_day = int(data.get("lesson_day", -1))
	var saved_table: Array = data.get("table", [])
	var saved_q: Array = data.get("table_q", [])
	var table_i := 0
	for entry: Variant in saved_table:
		var dish := StringName(str(entry))
		var quality := 0
		if table_i < saved_q.size():
			quality = clampi(int(saved_q[table_i]), 0, 2)
		table_i += 1
		if Database.recipes.has(dish) and not table_dishes.has(dish) and table_dishes.size() < TABLE_MAX:
			table_dishes.append(dish)
			table_quality.append(quality)
	var saved_made: Array = data.get("made", [])
	for entry: Variant in saved_made:
		var made_id := StringName(str(entry))
		if Database.recipes.has(made_id) and not made_dishes.has(made_id):
			made_dishes.append(made_id)
	var saved_term: Array = data.get("term_made", [])
	for entry: Variant in saved_term:
		var term_id := StringName(str(entry))
		if Database.recipes.has(term_id) and not term_made.has(term_id):
			term_made.append(term_id)
	heat_dishes.clear()
	var saved_heat: Array = data.get("heat", [])
	for entry: Variant in saved_heat:
		var heat_id := StringName(str(entry))
		if Database.recipes.has(heat_id) and not heat_dishes.has(heat_id):
			heat_dishes.append(heat_id)
	var saved_sets: Array = data.get("sets", [])
	for entry: Variant in saved_sets:
		var set_id := StringName(str(entry))
		if SETS.has(set_id) and not sets.has(set_id):
			sets.append(set_id)
	_check_sets()
	changed.emit()


func reset_data() -> void:
	jobs.clear()
	last_dish = ""
	last_plate = {}
	_lesson_day = -1
	table_dishes.clear()
	table_quality.clear()
	sets.clear()
	made_dishes.clear()
	heat_dishes.clear()
	term_made.clear()
	_term_pending.clear()
	rank = &""
	meals = 0
	changed.emit()
