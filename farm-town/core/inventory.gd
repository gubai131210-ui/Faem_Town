class_name Inventory
extends RefCounted
## 背包：固定数量的格子，每格放一种物品、数量和品质。不依赖节点。
## 品质：0 普通，1 良，2 优。同一种物品不同品质不叠在一起。

signal changed

var size: int
## 每格是 {"id": StringName, "count": int, "q": int}，空格是空字典
var _slots: Array[Dictionary] = []


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


## 某种物品的总数；quality 为 -1 时不分品质。
func count_of(id: StringName, quality: int = -1) -> int:
	var total := 0
	for i in size:
		if id_at(i) == id and (quality < 0 or quality_at(i) == quality):
			total += count_at(i)
	return total


## 能否完整放下这么多物品。
func can_add(id: StringName, count: int = 1, quality: int = 0) -> bool:
	if not Database.has_item(id):
		return false
	var def := Database.item(id)
	var room := 0
	for i in size:
		if _slots[i].is_empty():
			room += def.stack
		elif id_at(i) == id and quality_at(i) == quality:
			room += def.stack - count_at(i)
		if room >= count:
			return true
	return false


## 放入物品，先叠到已有的同类同品质格子，再占用空格。返回放不下的数量。
func add(id: StringName, count: int = 1, quality: int = 0) -> int:
	if count <= 0:
		return 0
	var def := Database.item(id)
	if def == null:
		return count
	var left := count
	for i in size:
		if left <= 0:
			break
		if id_at(i) == id and quality_at(i) == quality and count_at(i) < def.stack:
			var put := mini(left, def.stack - count_at(i))
			_slots[i]["count"] = count_at(i) + put
			left -= put
	for i in size:
		if left <= 0:
			break
		if _slots[i].is_empty():
			var put := mini(left, def.stack)
			_slots[i] = {"id": id, "count": put, "q": quality}
			left -= put
	if left != count:
		changed.emit()
	return left


## 从指定格子取走若干个，返回实际取走的数量。
func remove_at(i: int, count: int = 1) -> int:
	var have := count_at(i)
	var take := mini(have, count)
	if take <= 0:
		return 0
	if take == have:
		_slots[i] = {}
	else:
		_slots[i]["count"] = have - take
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
			if p["id"] == id_at(i) and int(p["q"]) == quality_at(i) and int(p["count"]) < cap:
				var put := mini(left, cap - int(p["count"]))
				p["count"] = int(p["count"]) + put
				left -= put
		if left > 0:
			piles.append({"id": id_at(i), "count": left, "q": quality_at(i)})
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
			_slots[i] = {"id": id, "count": count, "q": clampi(int(d.get("q", 0)), 0, 2)}
	changed.emit()
