class_name MineLayerDef
extends RefCounted
## 沉灯井的一段楼层（浅坑、水渍层……），来自 data/mine.json。

var id: StringName
var name: String
## 从第几层到第几层（含）
var from := 1
var to := 1
## 空地上有多大比例长着石头
var rock := 0.3
## 普通石头敲开掉什么
var stone: StringName = &"stone"
## 普通石头在抽签里占的份数
var stone_weight := 70
## 矿石：每项 {"item": 物品 id, "weight": 份数, "color": 石头上矿点的颜色}
var ores: Array[Dictionary] = []
## 一层里有几只忘形：这一段最浅的那层 monster_min 只上下，最深的那层 monster_max 只上下
var monster_min := 0
var monster_max := 0
## 忘形：每项 {"id": 忘形 id, "weight": 份数, "from": 从第几层开始出现}
var monsters: Array[Dictionary] = []
## 空地上有多大比例是浅水（能走，走不快）
var water := 0.0
## 一层有多大机会带一段暗河（深水，过不去，能钓鱼）
var pool := 0.0
## 空地上有多大比例摆着被忘掉的东西（街灯、家具），敲不掉
var props := 0.0
## 这一段的忘形掉遗物的机会乘多少
var relic_bonus := 1.0
## 这一段最深的那层守着哪个首领（忘形 id）；没有是空
var boss: StringName = &""
## 全黑，只有手里的灯照得见
var dark := false


static func from_dict(d: Dictionary) -> MineLayerDef:
	var def := MineLayerDef.new()
	def.id = StringName(str(d.get("id", "")))
	def.name = str(d.get("name", ""))
	def.from = int(d.get("from", 1))
	def.to = int(d.get("to", 1))
	def.rock = float(d.get("rock", 0.3))
	def.stone = StringName(str(d.get("stone", "stone")))
	def.stone_weight = int(d.get("stone_weight", 70))
	var list: Variant = d.get("ores", [])
	if list is Array:
		for entry: Variant in list:
			if entry is Dictionary:
				var e: Dictionary = entry
				def.ores.append({
					"item": StringName(str(e.get("item", ""))),
					"weight": int(e.get("weight", 0)),
					"color": str(e.get("color", "808080")),
				})
	def.water = float(d.get("water", 0.0))
	def.pool = float(d.get("pool", 0.0))
	def.props = float(d.get("props", 0.0))
	def.relic_bonus = float(d.get("relic_bonus", 1.0))
	def.boss = StringName(str(d.get("boss", "")))
	def.dark = bool(d.get("dark", false))
	var count: Variant = d.get("monster_count", [])
	if count is Array and (count as Array).size() == 2:
		def.monster_min = int((count as Array)[0])
		def.monster_max = int((count as Array)[1])
	var mlist: Variant = d.get("monsters", [])
	if mlist is Array:
		for entry: Variant in mlist:
			if entry is Dictionary:
				var e: Dictionary = entry
				def.monsters.append({
					"id": StringName(str(e.get("id", ""))),
					"weight": int(e.get("weight", 0)),
					"from": int(e.get("from", def.from)),
				})
	return def


## 第 n 层放几只忘形：越深越多，roll（0 到 1）再让它上下差一只。
func monster_count(n: int, roll: float) -> int:
	if monsters.is_empty() or monster_max <= 0:
		return 0
	var depth := 0.0
	if to > from:
		depth = clampf(float(n - from) / float(to - from), 0.0, 1.0)
	var base := lerpf(float(monster_min), float(monster_max), depth)
	return clampi(roundi(base + roll - 0.5), monster_min, monster_max)


## 按份数抽第 n 层的一只忘形是哪种：roll 在 0 到 1 之间。这一层一种都没有返回空。
func pick_monster(n: int, roll: float) -> StringName:
	var total := 0
	for m in monsters:
		if n >= int(m["from"]):
			total += int(m["weight"])
	if total <= 0:
		return &""
	var at := roll * total
	var last: StringName = &""
	for m in monsters:
		if n < int(m["from"]):
			continue
		last = m["id"]
		at -= int(m["weight"])
		if at < 0.0:
			return last
	return last


func has_floor(n: int) -> bool:
	return n >= from and n <= to


## 按份数抽一块石头里是什么：roll 在 0 到 1 之间。
func pick(roll: float) -> StringName:
	var total := stone_weight
	for ore in ores:
		total += int(ore["weight"])
	var at := roll * total
	for ore in ores:
		at -= int(ore["weight"])
		if at < 0.0:
			var item: StringName = ore["item"]
			return item
	return stone
