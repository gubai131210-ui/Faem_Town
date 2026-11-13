extends Node
## 野外采集：每天早上各张地图攒下几份“待长出来”的采集物，等地图载入时再落到具体的空地上。
## 每日结算时地图通常没有载入，不知道哪里是空地，所以分成两步。

signal changed

## 会长采集物的地图。
const MAPS: Array[StringName] = [&"farm", &"nanxi", &"riverbank", &"pasture", &"dongtan", &"shanci"]
## 每天新长几份
const DAILY := 2
## 刮过大风的第二天多掉几份
const WIND_BONUS := 2
## 一张地图上最多同时有几份（已经长出来的加上待长的）
const MAX_PER_MAP := 6
## 开新档时先放几份
const START_PENDING := 3
## 有水边采集物可选时，抽到水边的概率
const SHORE_CHANCE := 0.3
## 雾天在这张地图上掉一件遗物
const RELIC_MAP: StringName = &"farm"

## 地图 id -> {格子 Vector2i: 物品 id}
var items: Dictionary[StringName, Dictionary] = {}
## 地图 id -> 还没落地的份数
var pending: Dictionary[StringName, int] = {}
## 雾天攒下的、还没落地的遗物（最多一件）
var pending_relic: StringName = &""

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	SaveSystem.register(&"foraging", self)
	GameClock.register_daily(GameClock.ORDER_FORAGE, _on_new_day)
	reset_data()


## 这个季节、这个节气能出现的采集物。shore 为真只要水边的，为假只要陆地上的；beach 为真只要沙滩上赶海的。
static func options(season: StringName, term_index: int, shore: bool, beach: bool = false) -> Array[ForageDef]:
	var out: Array[ForageDef] = []
	for def in Database.forage:
		if def.beach != beach:
			continue
		if def.in_season(season) and (beach or def.shore == shore) and def.available(term_index):
			out.append(def)
	return out


## 按权重选一种；roll 是 [0, 1) 的随机数。没有可选的返回空。
static func pick(list: Array[ForageDef], roll: float) -> StringName:
	var total := 0
	for def in list:
		total += def.weight
	if total <= 0:
		return &""
	var at := roll * total
	for def in list:
		at -= def.weight
		if at < 0.0:
			return def.item
	return list[list.size() - 1].item


func count_on(map_id: StringName) -> int:
	var on_map: Dictionary = items.get(map_id, {})
	return on_map.size()


func pending_on(map_id: StringName) -> int:
	return pending.get(map_id, 0)


func item_at(map_id: StringName, t: Vector2i) -> StringName:
	var on_map: Dictionary = items.get(map_id, {})
	var id: StringName = on_map.get(t, &"")
	return id


## 捡走这一格的采集物，返回物品 id；没有就返回空。
func take(map_id: StringName, t: Vector2i) -> StringName:
	var id := item_at(map_id, t)
	if id == &"":
		return &""
	items[map_id].erase(t)
	if Database.has_relic(id):
		GameState.set_flag(StringName("relic_" + String(id)))
	changed.emit()
	return id


## 地图载入时调用：把攒着的份数落到空地上。land 是能放的陆地格子，shore 是水边的格子。
## 没有合适的东西或没有空位时，这一份就作废。beach 为真时 land 是沙滩，落的是赶海的东西。
func settle(map_id: StringName, land: Array[Vector2i], shore: Array[Vector2i], beach: bool = false) -> void:
	var n := pending_on(map_id)
	if n <= 0:
		return
	pending[map_id] = 0
	if not items.has(map_id):
		items[map_id] = {}
	var on_map: Dictionary = items[map_id]
	if map_id == RELIC_MAP and pending_relic != &"" and not land.is_empty():
		for attempt in 8:
			var t := land[_rng.randi() % land.size()]
			if not on_map.has(t):
				on_map[t] = pending_relic
				break
		pending_relic = &""
	var season := GameClock.season_id()
	var term := GameClock.term_index()
	var shore_options := options(season, term, true)
	var land_options := options(season, term, false, beach)
	for i in n:
		var use_shore := not shore.is_empty() and not shore_options.is_empty() and _rng.randf() < SHORE_CHANCE
		var id := pick(shore_options if use_shore else land_options, _rng.randf())
		var spots := shore if use_shore else land
		if id == &"" or spots.is_empty():
			continue
		# 试几次找一个没被占的格子
		for attempt in 8:
			var t := spots[_rng.randi() % spots.size()]
			if not on_map.has(t):
				on_map[t] = id
				break
	changed.emit()


## 每日结算：换季时上一季的采集物消失；每张地图攒几份新的。
func _on_new_day() -> void:
	var new_season := GameClock.day_of_season() == 1
	var extra := WIND_BONUS if Weather.yesterday == Weather.WIND else 0
	for map_id in MAPS:
		if new_season:
			items[map_id] = {}
		var room := maxi(0, MAX_PER_MAP - count_on(map_id))
		pending[map_id] = mini(room, pending_on(map_id) + DAILY + extra)
	if Weather.is_foggy() and pending_relic == &"":
		pending_relic = pick_relic(_rng.randf())
	changed.emit()


## 雾天掉哪件遗物：还没捡到过、也没躺在地上的那些里随机挑一件；都捡完了返回空。
func pick_relic(roll: float) -> StringName:
	var pool: Array[StringName] = []
	for id: StringName in Database.relics:
		var r: RelicDef = Database.relics[id]
		if r.found != &"fog" or not Residents.relic_available(r) or GameState.has_flag(StringName("relic_" + String(id))):
			continue
		var lying := false
		for map_id: StringName in items:
			if items[map_id].values().has(id):
				lying = true
		if not lying:
			pool.append(id)
	if pool.is_empty():
		return &""
	return pool[mini(int(roll * pool.size()), pool.size() - 1)]


func save_data() -> Dictionary:
	var out_items := {}
	for map_id: StringName in items:
		var list: Array = []
		var on_map: Dictionary = items[map_id]
		for t: Vector2i in on_map:
			list.append([t.x, t.y, String(on_map[t])])
		out_items[String(map_id)] = list
	var out_pending := {}
	for map_id: StringName in pending:
		out_pending[String(map_id)] = pending[map_id]
	return {"items": out_items, "pending": out_pending, "pending_relic": String(pending_relic)}


func load_data(data: Dictionary) -> void:
	items.clear()
	pending.clear()
	var saved_items: Dictionary = data.get("items", {})
	for key: Variant in saved_items:
		var on_map := {}
		var list: Array = saved_items[key]
		for entry: Variant in list:
			if entry is Array and entry.size() >= 3:
				var e: Array = entry
				var id := StringName(str(e[2]))
				if Database.has_item(id):
					on_map[Vector2i(int(e[0]), int(e[1]))] = id
		items[StringName(str(key))] = on_map
	var saved_pending: Dictionary = data.get("pending", {})
	for key: Variant in saved_pending:
		pending[StringName(str(key))] = clampi(int(saved_pending[key]), 0, MAX_PER_MAP)
	pending_relic = StringName(str(data.get("pending_relic", "")))
	if not Database.has_relic(pending_relic):
		pending_relic = &""
	changed.emit()


func reset_data() -> void:
	_rng.randomize()
	items.clear()
	pending.clear()
	pending_relic = &""
	for map_id in MAPS:
		pending[map_id] = START_PENDING
	changed.emit()
