extends Node
## 钓鱼的全局状态和规则（autoload Fishing）：这片水现在有什么鱼、等多久咬钩、钓到的记录。
## 收放线的过程在 FishFight 里，画面和输入在游戏主场景的 FishingSession 里。

signal changed

## 等咬钩的时间范围（秒），鱼竿每升一级上限少一秒
const WAIT_MIN := 1.6
const WAIT_MAX := 6.0
const WAIT_PER_LEVEL := 1.0
## 咬钩后多久内按下算钩住
const BITE_WINDOW := 0.9
## 天黑的时刻（分钟）：夜行的鱼从这时起咬钩
const NIGHT_FROM := 19 * 60.0
const NIGHT_TO := 5 * 60.0
## 鱼饵：背包里有就每次甩竿用掉一个，等鱼的时间减半
const BAIT_ID := &"bait"
const BAIT_WAIT_MULT := 0.5
## 浮漂：背包里有就把咬钩后按下的窗口拉长
const BOBBER_ID := &"bobber"
const BOBBER_WINDOW := 1.6
## 蟹笼：放在水里隔天收。每晚有这么大的机会装到东西
const TRAP_ID := &"crab_trap"
const TRAP_CHANCE := 0.75
## 雾天和清明，咬钩的有这么大的机会是一件遗物
const RELIC_CHANCE := 0.2
## 对着沉着剧情遗物的水钓，每口有这么大的机会钩上它
const SUNKEN_CHANCE := 0.35
const RELIC_TERM := &"qingming"

## 每种鱼的记录：{"count": 钓到几条, "best": 最长多少厘米}
var records: Dictionary[StringName, Dictionary] = {}
## 放下的蟹笼：地图 id -> {格子: {"water": 水域, "catch": 装到的鱼或空}}
var traps: Dictionary[StringName, Dictionary] = {}

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	SaveSystem.register(&"fishing", self)
	GameClock.register_daily(GameClock.ORDER_FORAGE, _on_new_day)


## 现在算不算夜里（夜行的鱼看这个）。
static func is_night(minutes: float) -> bool:
	return minutes >= NIGHT_FROM or minutes < NIGHT_TO


## 这片水现在咬钩的鱼。
func pool(water: StringName) -> Array[FishDef]:
	var out: Array[FishDef] = []
	var night := is_night(GameClock.minutes)
	for id: StringName in Database.fish:
		var f: FishDef = Database.fish[id]
		if f.bites(water, GameClock.season_id(), night, Weather.today, GameClock.term_id()):
			out.append(f)
	return out


## 按权重抽一条；roll 是 0 到 1 的随机数。没有鱼返回 null。
func pick(water: StringName, roll: float) -> FishDef:
	var fishes := pool(water)
	if fishes.is_empty():
		return null
	var total := 0
	for f in fishes:
		total += f.weight
	var r := roll * total
	for f in fishes:
		r -= f.weight
		if r < 0.0:
			return f
	return fishes[fishes.size() - 1]


## 这次等多久咬钩；roll 是 0 到 1 的随机数。挂了鱼饵时间减半。
func bite_wait(rod_level: int, roll: float, baited: bool = false) -> float:
	var top := maxf(WAIT_MIN + 0.5, WAIT_MAX - WAIT_PER_LEVEL * rod_level)
	var t := lerpf(WAIT_MIN, top, roll)
	return t * BAIT_WAIT_MULT if baited else t


## 咬钩后多久内按下算钩住：有浮漂就长一些。
func bite_window() -> float:
	return BOBBER_WINDOW if GameState.inventory.count_of(BOBBER_ID) > 0 else BITE_WINDOW


## 甩竿时挂一个鱼饵；背包里没有就返回 false。
func use_bait() -> bool:
	if GameState.inventory.count_of(BAIT_ID) <= 0:
		return false
	GameState.inventory.remove(BAIT_ID, 1)
	return true


## 现在是不是能钓上遗物的日子（雾天或清明）。
func relic_weather() -> bool:
	return Weather.is_foggy() or GameClock.term_id() == RELIC_TERM


## 这次咬钩的是不是遗物；roll 是 0 到 1 的随机数。
func relic_bites(roll: float) -> bool:
	return relic_weather() and roll < RELIC_CHANCE


## 钓上哪件遗物：雾天地上会掉的那些和只能钓到的那些里，还没得到的随机挑一件。
## excluded 是别处已经出现、不该重复的（比如正躺在地上的），由调用方传进来。都得到了返回空。
func pick_relic(roll: float, excluded: Array[StringName] = []) -> StringName:
	var pool: Array[StringName] = []
	for id: StringName in Database.relics:
		var r: RelicDef = Database.relics[id]
		if r.found != &"fog" and r.found != &"fishing":
			continue
		if GameState.has_flag(StringName("relic_" + String(id))) or excluded.has(id):
			continue
		pool.append(id)
	if pool.is_empty():
		return &""
	return pool[mini(int(roll * pool.size()), pool.size() - 1)]


# ---------------------------------------------------------------- 蟹笼

## 这片水里蟹笼能装到的东西（trap 为真的鱼，按季节）。
func trap_pool(water: StringName) -> Array[FishDef]:
	var out: Array[FishDef] = []
	for id: StringName in Database.fish:
		var f: FishDef = Database.fish[id]
		if f.trap and f.waters.has(water) and (f.seasons.is_empty() or f.seasons.has(GameClock.season_id())):
			out.append(f)
	return out


func has_trap(map_id: StringName, tile: Vector2i) -> bool:
	return traps.has(map_id) and traps[map_id].has(tile)


## 笼子里现在装着什么；没有笼子或空笼返回空。
func trap_catch(map_id: StringName, tile: Vector2i) -> StringName:
	if not has_trap(map_id, tile):
		return &""
	return traps[map_id][tile].get("catch", &"")


## 把一个蟹笼放到这片水里。
func place_trap(map_id: StringName, tile: Vector2i, water: StringName) -> void:
	if not traps.has(map_id):
		traps[map_id] = {}
	traps[map_id][tile] = {"water": water, "catch": &""}
	changed.emit()


## 收笼子：返回里面的东西（可能为空），笼子留在原地。
func take_catch(map_id: StringName, tile: Vector2i) -> StringName:
	var id := trap_catch(map_id, tile)
	if id != &"":
		traps[map_id][tile]["catch"] = &""
		changed.emit()
	return id


## 把笼子收回来。
func remove_trap(map_id: StringName, tile: Vector2i) -> void:
	if has_trap(map_id, tile):
		traps[map_id].erase(tile)
		changed.emit()


func trap_count() -> int:
	var n := 0
	for map_id in traps:
		n += traps[map_id].size()
	return n


## 每天早上：空着的笼子各自碰运气，有机会装到东西。
func _on_new_day() -> void:
	var changed_any := false
	for map_id in traps:
		for tile: Vector2i in traps[map_id]:
			changed_any = _settle_trap(traps[map_id][tile], _rng.randf()) or changed_any
	if changed_any:
		changed.emit()


## 所有空笼子都用同一个 roll 结算，测试用。
func settle_traps(roll: float) -> void:
	var changed_any := false
	for map_id in traps:
		for tile: Vector2i in traps[map_id]:
			changed_any = _settle_trap(traps[map_id][tile], roll) or changed_any
	if changed_any:
		changed.emit()


## 一个笼子过一夜：已经装着东西的不动；roll 小于 TRAP_CHANCE 就按权重装进一样。装到了返回真。
func _settle_trap(trap: Dictionary, roll: float) -> bool:
	if trap.get("catch", &"") != &"":
		return false
	var options := trap_pool(trap["water"])
	if options.is_empty() or roll >= TRAP_CHANCE:
		return false
	var total := 0
	for f in options:
		total += f.weight
	var pick_r := roll / TRAP_CHANCE * total
	var got: FishDef = options[options.size() - 1]
	for f in options:
		pick_r -= f.weight
		if pick_r < 0.0:
			got = f
			break
	trap["catch"] = got.id
	return true


## 这条鱼这次多长；roll 是 0 到 1 的随机数，偏向小的。
static func roll_size(def: FishDef, roll: float) -> int:
	var k := roll * roll * 0.7 + roll * 0.3
	return clampi(roundi(lerpf(def.min_size, def.max_size, k)), def.min_size, def.max_size)


## 记一条钓到的鱼。
func record(fish_id: StringName, size: int) -> void:
	var r: Dictionary = records.get(fish_id, {"count": 0, "best": 0})
	r["count"] = int(r["count"]) + 1
	r["best"] = maxi(int(r["best"]), size)
	records[fish_id] = r
	changed.emit()


func caught(fish_id: StringName) -> int:
	return int(records.get(fish_id, {}).get("count", 0))


func best(fish_id: StringName) -> int:
	return int(records.get(fish_id, {}).get("best", 0))


## 钓到过几种。
func species_count() -> int:
	return records.size()


func save_data() -> Dictionary:
	var out: Dictionary = {}
	for id in records:
		out[String(id)] = records[id].duplicate()
	var trap_list: Array = []
	for map_id in traps:
		for tile: Vector2i in traps[map_id]:
			var t: Dictionary = traps[map_id][tile]
			trap_list.append({"map": String(map_id), "x": tile.x, "y": tile.y, "water": String(t["water"]), "catch": String(t.get("catch", &""))})
	return {"records": out, "traps": trap_list}


func load_data(data: Dictionary) -> void:
	records.clear()
	traps.clear()
	var recs: Dictionary = data.get("records", {})
	for key: Variant in recs:
		var r: Dictionary = recs[key]
		records[StringName(str(key))] = {"count": int(r.get("count", 0)), "best": int(r.get("best", 0))}
	var trap_list: Array = data.get("traps", [])
	for e: Variant in trap_list:
		if e is Dictionary:
			var map_id := StringName(str(e.get("map", "")))
			if not traps.has(map_id):
				traps[map_id] = {}
			traps[map_id][Vector2i(int(e.get("x", 0)), int(e.get("y", 0)))] = {
				"water": StringName(str(e.get("water", ""))), "catch": StringName(str(e.get("catch", "")))}
	changed.emit()


func reset_data() -> void:
	records.clear()
	traps.clear()
	changed.emit()
