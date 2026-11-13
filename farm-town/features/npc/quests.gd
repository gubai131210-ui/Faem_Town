extends Node
## 公告栏的委托：哪些贴着、接了哪些、做完哪些。交付本身由 Residents 在搭话时发起（它排在后面，能调这里）。

## 接了、交了委托（公告栏界面用）
signal changed

## 公告栏同时最多贴几张
const POSTED := 3
## 交付时加的熟悉度
const DELIVER_POINTS := 20

var active: Array[StringName] = []
var done: Array[StringName] = []


func _ready() -> void:
	SaveSystem.register(&"quests", self)


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
	if not Database.quests.has(id) or is_active(id) or is_done(id):
		return false
	active.append(id)
	changed.emit()
	return true


## 拿着 item 去找这位居民，能交哪张委托；没有返回 null。
func deliverable(npc_id: StringName, item: ItemDef, count: int) -> QuestDef:
	if item == null:
		return null
	for id in active:
		var q := Database.quest(id)
		if q.npc == npc_id and q.item == item.id and count >= q.count:
			return q
	return null


## 交付：记成做完，返回报酬 {"money": 文, "relic": 遗物 id 或空, "points": 熟悉度}。不动背包和钱。
func deliver(id: StringName) -> Dictionary:
	if not is_active(id):
		return {}
	var q := Database.quest(id)
	active.erase(id)
	done.append(id)
	changed.emit()
	return {"money": q.money, "relic": q.relic, "points": DELIVER_POINTS}


func save_data() -> Dictionary:
	var a: Array = []
	for id in active:
		a.append(String(id))
	var d: Array = []
	for id in done:
		d.append(String(id))
	return {"active": a, "done": d}


func load_data(data: Dictionary) -> void:
	active.clear()
	done.clear()
	for id: Variant in data.get("active", []):
		if Database.quests.has(StringName(str(id))):
			active.append(StringName(str(id)))
	for id: Variant in data.get("done", []):
		if Database.quests.has(StringName(str(id))):
			done.append(StringName(str(id)))
	changed.emit()


func reset_data() -> void:
	active.clear()
	done.clear()
	changed.emit()
