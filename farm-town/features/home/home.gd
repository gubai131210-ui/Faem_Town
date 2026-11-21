extends Node
## 农舍：扩了几回、正在扩的还要几天、屋里摆的家具、墙和地（决策 148）。
## 格子都按老屋算：老屋左上角是 (0, 0)，往西扩出来的那一截 x 是负的，老存档里的东西不挪窝。

signal changed

const FURNITURE_PATH := "res://data/furniture.json"
const WALL_ROWS := 2
## 每一级屋子的大小：宽、高、老屋往东挪了几格（西边扩出来多少）
const TIERS: Array[Dictionary] = [
	{"w": 12, "h": 9, "ox": 0},
	{"w": 18, "h": 10, "ox": 0},
	{"w": 24, "h": 11, "ox": 6},
]
## 从第 n 级扩到 n+1 级：青竹接活，付钱和材料，几天盖好。flag 那盏灯亮了，或者和她熟了，她才接。
const UPGRADES: Array[Dictionary] = [
	{"name": "东边的灶屋", "price": 3000, "days": 3, "flag": &"lamp_plaza",
		"materials": [{"item": &"stone", "count": 50}]},
	{"name": "西厢房", "price": 8000, "days": 4, "flag": &"lamp_river",
		"materials": [{"item": &"stone", "count": 100}, {"item": &"iron_ore", "count": 20}]},
]
## 老屋里固定的几样：[名字, 左上角, 宽, 深]。床、柜子（收音机）、灶、桌子不挪。
const FIXED: Array = [
	[&"bed", Vector2i(1, 2), 2, 3],
	[&"cabinet", Vector2i(3, 2), 2, 1],
	[&"stove", Vector2i(10, 2), 2, 1],
	[&"table", Vector2i(7, 4), 2, 1],
]
## 不让摆东西的格子：小寒灶君站的地方、两只结缘的小兽睡的地方
const KEEP_FREE: Array[Vector2i] = [Vector2i(9, 3), Vector2i(2, 6), Vector2i(4, 6)]
## 门在老屋的这两列，最下面一行
const DOOR_X: Array[int] = [5, 6]
## 墙上不能挂东西的列：窗、老挂轴、三块牌
const OLD_WALL_TAKEN: Array[int] = [1, 2, 5, 6, 7, 8, 9]
## 新游戏屋里原来就有的几件
const START_PIECES: Array = [
	[&"stool", Vector2i(6, 4)], [&"stool", Vector2i(9, 4)],
	[&"jar_jade", Vector2i(11, 6)], [&"jar_clay", Vector2i(10, 7)],
]

var tier := 0
## 正在扩的还要几天；0 表示没在扩
var days_left := 0
## 摆着的家具：{"id": StringName, "at": Vector2i}；墙上挂的 at.y 是 1
var pieces: Array[Dictionary] = []
var paper: StringName = &"paper_plaster"
var floor_id: StringName = &"floor_plank"
var morning_note := ""

var _defs: Dictionary[StringName, Dictionary] = {}


func _ready() -> void:
	_load_defs()
	reset_data()
	SaveSystem.register(&"home", self)
	GameClock.register_daily(GameClock.ORDER_ANIMALS + 1, _on_new_day)


func _load_defs() -> void:
	_defs.clear()
	for e: Variant in JsonFile.read(FURNITURE_PATH):
		var d: Dictionary = e
		_defs[StringName(str(d["id"]))] = d


# ---------------------------------------------------------------- 表

func is_decor(id: StringName) -> bool:
	return _defs.has(id)


func type_of(id: StringName) -> StringName:
	return StringName(str(_defs.get(id, {}).get("type", "")))


func prop_of(id: StringName) -> String:
	return str(_defs.get(id, {}).get("prop", ""))


func look_of(id: StringName) -> String:
	return str(_defs.get(id, {}).get("look", ""))


## 占地：宽、深。墙上挂的深为 1。
func size_of(id: StringName) -> Vector2i:
	var d: Dictionary = _defs.get(id, {})
	return Vector2i(int(d.get("w", 1)), int(d.get("d", 1)))


## 人能踩在上面走（毯子）。
func walkable(id: StringName) -> bool:
	return bool(_defs.get(id, {}).get("walk", false))


func all_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(_defs.keys())
	return out


# ---------------------------------------------------------------- 屋子的大小

func width() -> int:
	return int(TIERS[tier]["w"])


func height() -> int:
	return int(TIERS[tier]["h"])


## 老屋往东挪了几格。地图上的格子 = 老屋格子 + (ox, 0)。
func ox() -> int:
	return int(TIERS[tier]["ox"])


## 地板上这一格（老屋坐标）在不在屋里。
func on_floor(t: Vector2i) -> bool:
	return t.x >= -ox() and t.x < width() - ox() and t.y >= WALL_ROWS and t.y < height()


func door_tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in DOOR_X:
		out.append(Vector2i(x, height() - 1))
	return out


## 墙上的窗：老屋两扇，东边灶屋一扇，西厢一扇。按窗中线的格子算（窗占两列）。
func windows() -> Array[int]:
	var out: Array[int] = [1, 5]
	if tier >= 1:
		out.append(14)
	if tier >= 2:
		out.append(-4)
	return out


func fixed_tiles(name: StringName) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for f: Array in FIXED:
		if f[0] != name:
			continue
		var at: Vector2i = f[1]
		for dy in int(f[3]):
			for dx in int(f[2]):
				out.append(at + Vector2i(dx, dy))
	return out


# ---------------------------------------------------------------- 扩建

## 下一回扩建的条目；扩满了返回空字典。
func next_upgrade() -> Dictionary:
	if tier >= UPGRADES.size():
		return {}
	return UPGRADES[tier]


## 青竹肯不肯接：没在扩、没扩满、灯亮了或和她熟了。
func can_offer() -> bool:
	var up := next_upgrade()
	if up.is_empty() or days_left > 0:
		return false
	return Residents.opened(String(up["flag"]), "qingzhu")


func upgrade_price() -> int:
	var up := next_upgrade()
	if up.is_empty():
		return 0
	var p := int(up["price"])
	# 青竹想起全套手法：和别的建筑一样打八折
	if Residents.memory_level(&"qingzhu") >= 3:
		p = maxi(1, int(round(float(p) * 0.8)))
	return p


func upgrade_name() -> String:
	var up := next_upgrade()
	return "" if up.is_empty() else str(up["name"])


func upgrade_days() -> int:
	var up := next_upgrade()
	return 0 if up.is_empty() else int(up["days"])


func upgrade_materials() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var up := next_upgrade()
	if not up.is_empty():
		out.assign(up["materials"])
	return out


## 给对话用的一句：“石头 ×50”
func materials_text() -> String:
	return Shop.materials_text(upgrade_materials())


func has_materials() -> bool:
	for m in upgrade_materials():
		if GameState.inventory.count_of(m["item"]) < int(m["count"]):
			return false
	return true


## 订下一回扩建。钱或材料不够、不肯接返回 false，什么都不收。
func order() -> bool:
	if not can_offer() or GameState.money < upgrade_price() or not has_materials():
		return false
	GameState.money -= upgrade_price()
	for m in upgrade_materials():
		GameState.inventory.remove(m["item"], int(m["count"]))
	days_left = maxi(1, upgrade_days())
	changed.emit()
	return true


## 正在盖的叫什么、还要几天；没在盖返回空。
func building_now() -> String:
	if days_left <= 0:
		return ""
	return "%s还要 %d 天" % [upgrade_name(), days_left]


func _on_new_day() -> void:
	morning_note = ""
	if days_left <= 0:
		return
	days_left -= 1
	if days_left == 0:
		morning_note = "青竹把%s盖好了" % upgrade_name()
		tier += 1
		changed.emit()


# ---------------------------------------------------------------- 摆家具

## 这一件占的格子（老屋坐标）。
func footprint(id: StringName, at: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var s := size_of(id)
	var deep := 1 if type_of(id) == &"wall" else s.y
	for dy in deep:
		for dx in s.x:
			out.append(at + Vector2i(dx, dy))
	return out


## 这一格上的那件（不算毯子；只有毯子时给毯子）。没有返回 -1。
func piece_at(t: Vector2i) -> int:
	var rug := -1
	for i in pieces.size():
		var p := pieces[i]
		if not footprint(p["id"], p["at"]).has(t):
			continue
		if walkable(p["id"]):
			rug = i
		else:
			return i
	return rug


## 挡路的格子：固定的、摆着的（毯子不算）。
func blocked_tiles(skip: int = -1) -> Dictionary[Vector2i, bool]:
	var out: Dictionary[Vector2i, bool] = {}
	for f: Array in FIXED:
		for t in fixed_tiles(f[0]):
			out[t] = true
	for i in pieces.size():
		var p := pieces[i]
		if i == skip or type_of(p["id"]) != &"piece" or walkable(p["id"]):
			continue
		for t in footprint(p["id"], p["at"]):
			out[t] = true
	return out


## 墙上这一列能不能挂。
func wall_free(x: int, skip: int = -1) -> bool:
	if x < -ox() or x >= width() - ox():
		return false
	if x >= 0 and x < 12 and OLD_WALL_TAKEN.has(x):
		return false
	for w in windows():
		if x == w or x == w + 1:
			return false
	for i in pieces.size():
		var p := pieces[i]
		if i != skip and type_of(p["id"]) == &"wall" and footprint(p["id"], p["at"]).has(Vector2i(x, 1)):
			return false
	return true


## 能不能把 id 放在 at（老屋坐标，左上角）。stand 是人站的格子，不能压在人身上。
func can_place(id: StringName, at: Vector2i, stand: Vector2i = Vector2i(-99, -99)) -> bool:
	var kind := type_of(id)
	if kind == &"wall":
		if at.y != 1:
			return false
		for t in footprint(id, at):
			if not wall_free(t.x):
				return false
		return true
	if kind != &"piece":
		return false
	var tiles := footprint(id, at)
	var blocked := blocked_tiles()
	var keep := door_tiles()
	for t in door_tiles():
		keep.append(t + Vector2i(0, -1))
	keep.append_array(KEEP_FREE)
	for t in tiles:
		if not on_floor(t) or keep.has(t) or t == stand:
			return false
		if walkable(id):
			# 毯子不叠毯子，也不铺到固定的家具底下
			var other := piece_at(t)
			if other >= 0 and walkable(pieces[other]["id"]):
				return false
			for f: Array in FIXED:
				if fixed_tiles(f[0]).has(t):
					return false
		elif blocked.has(t):
			return false
	if walkable(id):
		return true
	for t in tiles:
		blocked[t] = true
	return _all_reachable(blocked)


## 摆上去。成了返回 true。
func place(id: StringName, at: Vector2i, stand: Vector2i = Vector2i(-99, -99)) -> bool:
	if not can_place(id, at, stand):
		return false
	pieces.append({"id": id, "at": at})
	changed.emit()
	return true


## 收起这一格上的那件，返回它的 id；没有返回空。
func take(t: Vector2i) -> StringName:
	var i := piece_at(t)
	if i < 0:
		return &""
	var id: StringName = pieces[i]["id"]
	pieces.remove_at(i)
	changed.emit()
	return id


## 换墙或地，返回换下来的那一种；不是墙纸地板返回空。
func apply_surface(id: StringName) -> StringName:
	var old: StringName = &""
	match type_of(id):
		&"paper":
			if paper == id:
				return &""
			old = paper
			paper = id
		&"floor":
			if floor_id == id:
				return &""
			old = floor_id
			floor_id = id
		_:
			return &""
	changed.emit()
	return old


## 从门口走得到每样固定家具的跟前、每件摆着的家具的跟前。
func _all_reachable(blocked: Dictionary[Vector2i, bool]) -> bool:
	var seen: Dictionary[Vector2i, bool] = {}
	var queue: Array[Vector2i] = []
	for t in door_tiles():
		if not blocked.has(t):
			seen[t] = true
			queue.append(t)
	while not queue.is_empty():
		var t: Vector2i = queue.pop_front()
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n := t + d
			if seen.has(n) or blocked.has(n) or not on_floor(n):
				continue
			seen[n] = true
			queue.append(n)
	for t in KEEP_FREE:
		if not seen.has(t):
			return false
	var groups: Array = []
	for f: Array in FIXED:
		groups.append(fixed_tiles(f[0]))
	for p in pieces:
		if type_of(p["id"]) == &"piece" and not walkable(p["id"]):
			groups.append(footprint(p["id"], p["at"]))
	for tiles: Array in groups:
		if not _touches(tiles, seen):
			return false
	return true


func _touches(tiles: Array, seen: Dictionary[Vector2i, bool]) -> bool:
	for t: Vector2i in tiles:
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if seen.has(t + d):
				return true
	return false


# ---------------------------------------------------------------- 存档

func save_data() -> Dictionary:
	var out: Array = []
	for p in pieces:
		var at: Vector2i = p["at"]
		out.append({"id": String(p["id"]), "x": at.x, "y": at.y})
	return {"tier": tier, "days_left": days_left, "pieces": out, "paper": String(paper), "floor": String(floor_id)}


func load_data(data: Dictionary) -> void:
	tier = clampi(int(data.get("tier", 0)), 0, TIERS.size() - 1)
	days_left = maxi(0, int(data.get("days_left", 0)))
	var p := StringName(str(data.get("paper", "paper_plaster")))
	paper = p if type_of(p) == &"paper" else &"paper_plaster"
	var f := StringName(str(data.get("floor", "floor_plank")))
	floor_id = f if type_of(f) == &"floor" else &"floor_plank"
	if data.has("pieces"):
		pieces.clear()
		for e: Variant in data["pieces"]:
			if not (e is Dictionary):
				continue
			var d: Dictionary = e
			var id := StringName(str(d.get("id", "")))
			if is_decor(id):
				pieces.append({"id": id, "at": Vector2i(int(d.get("x", 0)), int(d.get("y", 0)))})
	changed.emit()


func reset_data() -> void:
	tier = 0
	days_left = 0
	paper = &"paper_plaster"
	floor_id = &"floor_plank"
	morning_note = ""
	pieces.clear()
	for e: Array in START_PIECES:
		pieces.append({"id": e[0], "at": e[1]})
	changed.emit()
