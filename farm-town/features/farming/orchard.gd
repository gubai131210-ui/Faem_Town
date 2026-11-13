class_name Orchard
extends RefCounted
## 果树的状态和规则：种在哪、长了几天、树上挂着几个果、地上落了几个。不依赖节点。

signal changed

## 树上最多挂几个果
const MAX_FRUIT := 3

## 有树的格子 -> {"kind": StringName, "age": int, "fruit": int, "fallen": int, "item": StringName}
## item 是现在结着的东西（换季时换）；fallen 是被风吹落在地上的，当天不捡第二天就烂了
var trees: Dictionary[Vector2i, Dictionary] = {}


func has(t: Vector2i) -> bool:
	return trees.has(t)


## 这一格能不能种树：自己和周围一圈都不能有别的果树。
func can_plant(t: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if trees.has(t + Vector2i(dx, dy)):
				return false
	return true


func plant(t: Vector2i, kind: StringName) -> bool:
	if not can_plant(t) or not Database.has_tree(kind):
		return false
	trees[t] = {"kind": kind, "age": 0, "fruit": 0, "fallen": 0, "item": &""}
	changed.emit()
	return true


func remove(t: Vector2i) -> bool:
	if not trees.has(t):
		return false
	trees.erase(t)
	changed.emit()
	return true


func kind_at(t: Vector2i) -> StringName:
	if not trees.has(t):
		return &""
	var kind: StringName = trees[t]["kind"]
	return kind


func age_at(t: Vector2i) -> int:
	return int(trees[t]["age"]) if trees.has(t) else 0


## 0 树苗，1 小树，2 长成。
func stage_at(t: Vector2i) -> int:
	if not trees.has(t):
		return 0
	var grow := Database.tree(kind_at(t)).grow_days
	var age := age_at(t)
	if age >= grow:
		return 2
	return 1 if age * 2 >= grow else 0


func is_mature(t: Vector2i) -> bool:
	return stage_at(t) == 2


func fruit_at(t: Vector2i) -> int:
	return int(trees[t]["fruit"]) if trees.has(t) else 0


func fallen_at(t: Vector2i) -> int:
	return int(trees[t]["fallen"]) if trees.has(t) else 0


## 现在结着的东西的物品 id；没结就为空。
func item_at(t: Vector2i) -> StringName:
	if not trees.has(t):
		return &""
	var item: StringName = trees[t]["item"]
	return item


## 树上和地上一共能捡几个。
func ready_at(t: Vector2i) -> int:
	return fruit_at(t) + fallen_at(t)


func fallen_total() -> int:
	var n := 0
	for t: Vector2i in trees:
		n += fallen_at(t)
	return n


## 把树上和地上的果子都收走，返回数量；物品 id 用 item_at 先取。
func collect(t: Vector2i) -> int:
	var n := ready_at(t)
	if n <= 0:
		return 0
	trees[t]["fruit"] = 0
	trees[t]["fallen"] = 0
	changed.emit()
	return n


## 过夜。season 是新一天的季节；windy 表示刚过去的这天刮大风。
## 顺序：昨天落在地上的烂掉 → 大风把树上的吹落 → 换季时清掉上一季的果 → 长一天，长成的树当季再结一个。
func advance_day(season: StringName, windy: bool = false) -> void:
	for t: Vector2i in trees:
		var tree := trees[t]
		var def := Database.tree(kind_at(t))
		tree["fallen"] = 0
		if windy:
			tree["fallen"] = int(tree["fruit"])
			tree["fruit"] = 0
		var item := def.produce_in(season)
		if item != item_at(t):
			tree["fruit"] = 0
			tree["fallen"] = 0
			tree["item"] = item
		tree["age"] = int(tree["age"]) + 1
		if item != &"" and int(tree["age"]) >= def.grow_days:
			tree["fruit"] = mini(MAX_FRUIT, int(tree["fruit"]) + 1)
	changed.emit()


func clear() -> void:
	trees.clear()
	changed.emit()


func to_array() -> Array:
	var out: Array = []
	for t: Vector2i in trees:
		out.append([t.x, t.y, String(kind_at(t)), age_at(t), fruit_at(t), fallen_at(t), String(item_at(t))])
	return out


func from_array(data: Array) -> void:
	trees.clear()
	for entry: Variant in data:
		if entry is Array and entry.size() >= 7:
			var e: Array = entry
			var kind := StringName(str(e[2]))
			if Database.has_tree(kind):
				trees[Vector2i(int(e[0]), int(e[1]))] = {
					"kind": kind, "age": int(e[3]),
					"fruit": clampi(int(e[4]), 0, MAX_FRUIT), "fallen": clampi(int(e[5]), 0, MAX_FRUIT),
					"item": StringName(str(e[6])),
				}
	changed.emit()
