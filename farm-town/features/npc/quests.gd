extends Node
## 公告栏的委托：哪些贴着、接了哪些、做完哪些。八张正事做完以后，隔几天再贴一张随手的小事。
## 交付本身由 Residents 在搭话时发起（它排在后面，能调这里）。

## 接了、交了委托（公告栏界面用）
signal changed

## 公告栏同时最多贴几张
const POSTED := 3
## 交付时加的熟悉度
const DELIVER_POINTS := 20
## 八张正事做完以后，随手的小事隔这么多天再贴一张
const ERRAND_GAP := 3
## 小事给的熟悉度：比正事少，免得交鸡蛋就把忆撑满
const ERRAND_POINTS := 8
## 小事在对话里的段落。不进委托表，做完也不记成“已交”
const ERRAND_ID := &"errand"

var active: Array[StringName] = []
var done: Array[StringName] = []
## 现在贴着或已经接下的那张小事；没有是 null
var errand: QuestDef
var errand_taken := false
## 下一张最早哪一天的早上贴出来。0 表示八张一做完，下一个早上就贴
var errand_next := 0
## 上一张小事用的是表里的哪一条，避免连着同一张
var errand_src: StringName = &""
## 刚交掉的那张是谁的，对话里还要叫出名字
var errand_who: StringName = &""


func _ready() -> void:
	SaveSystem.register(&"quests", self)
	GameClock.register_daily(GameClock.ORDER_NPCS, _settle)


func is_active(id: StringName) -> bool:
	return active.has(id)


func is_done(id: StringName) -> bool:
	return done.has(id)


## 现在贴在公告栏上的委托：到了日子、没接也没做完的，按表里的顺序取前几张。
func posted(day: int) -> Array[QuestDef]:
	var out: Array[QuestDef] = []
	for id: StringName in Database.quests:
		var q: QuestDef = Database.quests[id]
		if q.from_day <= day and not is_active(id) and not is_done(id):
			out.append(q)
			if out.size() >= POSTED:
				break
	return out


func accept(id: StringName) -> bool:
	if id == ERRAND_ID:
		if errand == null or errand_taken:
			return false
		errand_taken = true
		changed.emit()
		return true
	if not Database.quests.has(id) or is_active(id) or is_done(id):
		return false
	active.append(id)
	changed.emit()
	return true


## 拿着 item 去找这位居民，能交哪张委托；没有返回 null。正事优先于小事。
func deliverable(npc_id: StringName, item: ItemDef, count: int) -> QuestDef:
	if item == null:
		return null
	for id in active:
		var q := Database.quest(id)
		if q.npc == npc_id and q.item == item.id and count >= q.count:
			return q
	if errand != null and errand_taken and errand.npc == npc_id and errand.item == item.id and count >= errand.count:
		return errand
	return null


## 交付：正事记成做完；小事摘下来，隔几天再贴下一张。返回报酬 {"money": 文, "relic": 遗物 id 或空, "points": 熟悉度}。不动背包和钱。
func deliver(id: StringName) -> Dictionary:
	if id == ERRAND_ID:
		if errand == null or not errand_taken:
			return {}
		var money := errand.money
		errand_who = errand.npc
		errand = null
		errand_taken = false
		errand_next = GameClock.day + ERRAND_GAP
		changed.emit()
		return {"money": money, "relic": &"", "points": ERRAND_POINTS}
	if not is_active(id):
		return {}
	var q := Database.quest(id)
	active.erase(id)
	done.append(id)
	changed.emit()
	return {"money": q.money, "relic": q.relic, "points": DELIVER_POINTS}


## 八张正事都交过、栏上没有还接着的，才算空出来。
func story_cleared() -> bool:
	return active.is_empty() and done.size() >= Database.quests.size()


func _settle() -> void:
	if errand != null or not story_cleared() or GameClock.day < errand_next:
		return
	var pool: Array[QuestDef] = []
	for slip in Database.errands:
		if Residents.has_met(slip.npc):
			pool.append(slip)
	if pool.is_empty():
		for slip in Database.errands:
			pool.append(slip)
	if pool.is_empty():
		return
	var choices: Array[QuestDef] = []
	for slip in pool:
		if slip.id != errand_src or pool.size() == 1:
			choices.append(slip)
	if choices.is_empty():
		choices = pool
	var rng := RandomNumberGenerator.new()
	rng.seed = GameClock.day * 997 + 13
	var pick := choices[rng.randi() % choices.size()]
	var slip := QuestDef.new()
	slip.id = ERRAND_ID
	slip.npc = pick.npc
	slip.item = pick.item
	slip.count = pick.count
	slip.money = pick.money
	slip.title = pick.title
	slip.text = pick.text
	errand = slip
	errand_src = pick.id
	errand_taken = false
	changed.emit()


func save_data() -> Dictionary:
	var a: Array = []
	for id in active:
		a.append(String(id))
	var d: Array = []
	for id in done:
		d.append(String(id))
	var errand_out: Variant = null
	if errand != null:
		errand_out = {
			"src": String(errand_src), "npc": String(errand.npc), "item": String(errand.item),
			"count": errand.count, "money": errand.money, "title": errand.title, "text": errand.text,
		}
	return {"active": a, "done": d, "errand": errand_out, "errand_taken": errand_taken,
		"errand_next": errand_next, "errand_src": String(errand_src)}


func load_data(data: Dictionary) -> void:
	active.clear()
	done.clear()
	for id: Variant in data.get("active", []):
		if Database.quests.has(StringName(str(id))):
			active.append(StringName(str(id)))
	for id: Variant in data.get("done", []):
		if Database.quests.has(StringName(str(id))):
			done.append(StringName(str(id)))
	errand = null
	errand_taken = bool(data.get("errand_taken", false))
	errand_next = int(data.get("errand_next", 0))
	errand_src = StringName(str(data.get("errand_src", "")))
	errand_who = &""
	var raw: Variant = data.get("errand", null)
	if raw is Dictionary:
		var slip := QuestDef.new()
		slip.id = ERRAND_ID
		slip.npc = StringName(str(raw.get("npc", "")))
		slip.item = StringName(str(raw.get("item", "")))
		slip.count = int(raw.get("count", 1))
		slip.money = int(raw.get("money", 0))
		slip.title = str(raw.get("title", ""))
		slip.text = str(raw.get("text", ""))
		if Database.has_npc(slip.npc) and Database.items.has(slip.item) and slip.count > 0:
			errand = slip
			if raw.has("src"):
				errand_src = StringName(str(raw.get("src", "")))
		else:
			errand_taken = false
	changed.emit()


func reset_data() -> void:
	active.clear()
	done.clear()
	errand = null
	errand_taken = false
	errand_next = 0
	errand_src = &""
	errand_who = &""
	changed.emit()
