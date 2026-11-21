class_name Inventory
extends RefCounted
## 背包：固定数量的格子，每格放一种物品、数量和品质。不依赖节点。
## 品质：0 普通，1 良，2 优。同一种物品不同品质不叠在一起。

signal changed
## 用 add() 真的收进了一件东西。参数落到哪一格，供界面画一个飞向物品栏的图标。
## 读档、整理、交换、移除都不发，免得一次冒出一串图标。
signal gained(id: StringName, slot: int)

var size: int
## 每格是 {"id": StringName, "count": int, "q": int}，当令做的菜多一个 "t"。空格是空字典。
var _slots: Array[Dictionary] = []
## 今天拿到的鱼和蛋还剩多少。过夜清掉。不跟格子绑在一起，卖光了才跟着少。
var fresh: Dictionary[StringName, int] = {}


func _init(slot_count: int = 24) -> void:
	size = slot_count
	_slots.resize(size)
	for i in size:
		_slots[i] = {}


func is_empty_slot(i: int) -> bool:
	return _slots[i].is_empty()


func id_at(i: int) -> StringName:
	if i < 0 or i >= size or _slots[i].is_empty():
		return &""
	var id: StringName = _slots[i]["id"]
	return id


func count_at(i: int) -> int:
	if i < 0 or i >= size or _slots[i].is_empty():
		return 0
	var n: int = _slots[i]["count"]
	return n


func quality_at(i: int) -> int:
	if i < 0 or i >= size or _slots[i].is_empty():
		return 0
	var q: int = _slots[i].get("q", 0)
	return q


## 这格是不是节气里做出来的那一档。
func term_at(i: int) -> bool:
	if i < 0 or i >= size or _slots[i].is_empty():
		return false
	return bool(_slots[i].get("t", false))


func fresh_of(id: StringName) -> int:
	return int(fresh.get(id, 0))


## 做了一道用到今天的鱼或蛋，扣掉这份额度。
func use_fresh(id: StringName, count: int) -> void:
	var left := fresh_of(id) - count
	if left <= 0:
		fresh.erase(id)
	else:
		fresh[id] = left


func clear_fresh() -> void:
	fresh.clear()


func restore_fresh(data: Dictionary) -> void:
	fresh.clear()
	for key: Variant in data:
		var n := int(data[key])
		if n > 0:
			fresh[StringName(str(key))] = n


func _note_fresh(id: StringName, count: int) -> void:
	if count <= 0 or not Database.has_item(id):
		return
	var def := Database.item(id)
	if def.kind != &"fish" and id != &"egg" and id != &"duck_egg":
		return
	fresh[id] = fresh_of(id) + count


func _clamp_fresh(id: StringName) -> void:
	if not fresh.has(id):
		return
	var left := mini(fresh_of(id), count_of(id))
	if left <= 0:
		fresh.erase(id)
	else:
		fresh[id] = left


## 某种物品的总数；quality 为 -1 时不分品质。
func count_of(id: StringName, quality: int = -1) -> int:
	var total := 0
	for i in size:
		if id_at(i) == id and (quality < 0 or quality_at(i) == quality):
			total += count_at(i)
	return total


## 能否完整放下这么多物品。
func can_add(id: StringName, count: int = 1, quality: int = 0, in_term: bool = false) -> bool:
	if not Database.has_item(id):
		return false
	var def := Database.item(id)
	var room := 0
	for i in size:
		if _slots[i].is_empty():
			room += def.stack
		elif id_at(i) == id and quality_at(i) == quality and term_at(i) == in_term:
			room += def.stack - count_at(i)
		if room >= count:
			return true
	return false


## 放入物品，先叠到已有的同类同品质格子，再占用空格。返回放不下的数量。
## caught 为真时，鱼和蛋记进今天的新鲜额度。退回材料时传假，免得把旧的算成今天的。
func add(id: StringName, count: int = 1, quality: int = 0, in_term: bool = false, caught: bool = true) -> int:
	if count <= 0:
		return 0
	var def := Database.item(id)
	if def == null:
		return count
	var left := count
	var first_slot := -1
	for i in size:
		if left <= 0:
			break
		if id_at(i) == id and quality_at(i) == quality and term_at(i) == in_term and count_at(i) < def.stack:
			var put := mini(left, def.stack - count_at(i))
			_slots[i]["count"] = count_at(i) + put
			left -= put
			if first_slot < 0:
				first_slot = i
	for i in size:
		if left <= 0:
			break
		if _slots[i].is_empty():
			var put := mini(left, def.stack)
			var slot := {"id": id, "count": put, "q": quality}
			if in_term:
				slot["t"] = true
			_slots[i] = slot
			left -= put
			if first_slot < 0:
				first_slot = i
	if caught:
		_note_fresh(id, count - left)
	if left != count:
		changed.emit()
		if first_slot >= 0:
			gained.emit(id, first_slot)
	return left


## 从指定格子取走若干个，返回实际取走的数量。
func remove_at(i: int, count: int = 1) -> int:
	var have := count_at(i)
	var take := mini(have, count)
	if take <= 0:
		return 0
	var id := id_at(i)
	if take == have:
		_slots[i] = {}
	else:
		_slots[i]["count"] = have - take
	_clamp_fresh(id)
	changed.emit()
	return take


## 取走若干个某种物品（不分品质）；数量不够时什么都不做并返回 false。
func remove(id: StringName, count: int = 1) -> bool:
	if count_of(id) < count:
		return false
	var left := count
	for i in size:
		if left <= 0:
			break
		if id_at(i) == id:
			left -= remove_at(i, left)
	return true


## 整理从 start 开始往后的格子：同样的东西并到一起（不超过一格能叠的数），再按种类、名字、品质排好，空格都挪到最后。
## start 前面的格子（物品栏）不动。
func tidy(start: int = 0) -> void:
	var piles: Array[Dictionary] = []
	for i in range(maxi(0, start), size):
		if _slots[i].is_empty():
			continue
		var left := count_at(i)
		var cap := Database.item(id_at(i)).stack
		for p in piles:
			if left <= 0:
				break
			if p["id"] == id_at(i) and int(p["q"]) == quality_at(i) and bool(p.get("t", false)) == term_at(i) and int(p["count"]) < cap:
				var put := mini(left, cap - int(p["count"]))
				p["count"] = int(p["count"]) + put
				left -= put
		if left > 0:
			var pile := {"id": id_at(i), "count": left, "q": quality_at(i)}
			if term_at(i):
				pile["t"] = true
			piles.append(pile)
	piles.sort_custom(_tidy_before)
	for i in range(maxi(0, start), size):
		var k := i - maxi(0, start)
		_slots[i] = piles[k] if k < piles.size() else {}
	changed.emit()


static func _tidy_before(a: Dictionary, b: Dictionary) -> bool:
	var ka := ItemDef.KINDS.find(Database.item(a["id"]).kind)
	var kb := ItemDef.KINDS.find(Database.item(b["id"]).kind)
	if ka != kb:
		return ka < kb
	if a["id"] != b["id"]:
		return String(a["id"]) < String(b["id"])
	if int(a["q"]) != int(b["q"]):
		return int(a["q"]) > int(b["q"])
	return int(a["count"]) > int(b["count"])


func swap(a: int, b: int) -> void:
	if a == b or a < 0 or b < 0 or a >= size or b >= size:
		return
	var tmp := _slots[a]
	_slots[a] = _slots[b]
	_slots[b] = tmp
	changed.emit()


func clear() -> void:
	for i in size:
		_slots[i] = {}
	fresh.clear()
	changed.emit()


func to_array() -> Array:
	var out: Array = []
	for i in size:
		if _slots[i].is_empty():
			out.append(null)
		else:
			var d := {"id": String(id_at(i)), "count": count_at(i)}
			if quality_at(i) > 0:
				d["q"] = quality_at(i)
			if term_at(i):
				d["t"] = true
			out.append(d)
	return out


func from_array(data: Array) -> void:
	for i in size:
		_slots[i] = {}
		if i >= data.size() or not (data[i] is Dictionary):
			continue
		var d: Dictionary = data[i]
		var id := StringName(str(d.get("id", "")))
		var count := int(d.get("count", 0))
		# 存档里的物品在新版本被删掉时直接丢弃，不让坏数据进背包
		if count > 0 and Database.has_item(id):
			var slot := {"id": id, "count": count, "q": clampi(int(d.get("q", 0)), 0, 2)}
			if bool(d.get("t", false)):
				slot["t"] = true
			_slots[i] = slot
	changed.emit()
