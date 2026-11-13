class_name NpcDef
extends RefCounted
## 一位居民的定义，来自 data/npcs.json。

const FACINGS := {"down": 0, "up": 1, "right": 2, "left": 3}
## 开的铺子：空表示不做买卖
const SERVICES: Array[StringName] = [&"", &"grocery", &"smith"]
## 收到礼物的四种反应，从最喜欢到不喜欢
const TASTES: Array[StringName] = [&"love", &"like", &"ok", &"dislike"]

var id: StringName
var name: String
## 序列帧的名字，在 art/characters/ 下
var sheet: String
## 名册里显示的身份，比如“铁匠”
var role: String = ""
## 最喜欢、喜欢、不喜欢的物品 id；没列出来的东西都算“还行”
var loves: Array[StringName] = []
var likes: Array[StringName] = []
var dislikes: Array[StringName] = []
var service: StringName = &""
## 走路的速度，像素每秒
var speed := 34.0
## 每张地图上这位居民从哪一格出现和离开（家门口，或者地图的出入口）：地图 id -> 格子
var enter: Dictionary[StringName, Vector2i] = {}
## 平常的日程，按时间从早到晚。每项见 parse_schedule
var schedule: Array[Dictionary] = []
## 下雨、下雪、打雷的日子的日程；空表示和平常一样
var rain_schedule: Array[Dictionary] = []
## 这个剧情标记立起来以前用下面两份日程（自己住的地方还被雾封着，只能到镇上来）；空表示没有这回事
var early_until: StringName = &""
var early_schedule: Array[Dictionary] = []
var early_rain_schedule: Array[Dictionary] = []


static func from_dict(d: Dictionary) -> NpcDef:
	var def := NpcDef.new()
	def.id = StringName(str(d.get("id", "")))
	def.name = str(d.get("name", ""))
	def.sheet = str(d.get("sheet", String(def.id)))
	def.service = StringName(str(d.get("service", "")))
	def.role = str(d.get("role", ""))
	def.speed = float(d.get("speed", 34.0))
	def.loves = _ids(d.get("loves", []))
	def.likes = _ids(d.get("likes", []))
	def.dislikes = _ids(d.get("dislikes", []))
	var doors: Dictionary = d.get("enter", {})
	for key: Variant in doors:
		def.enter[StringName(str(key))] = _tile(doors[key])
	var plan: Variant = d.get("schedule", [])
	if plan is Array:
		def.schedule = parse_schedule(plan)
	var rain_plan: Variant = d.get("rain_schedule", [])
	if rain_plan is Array:
		def.rain_schedule = parse_schedule(rain_plan)
	def.early_until = StringName(str(d.get("early_until", "")))
	var early_plan: Variant = d.get("early_schedule", [])
	if early_plan is Array:
		def.early_schedule = parse_schedule(early_plan)
	var early_rain_plan: Variant = d.get("early_rain_schedule", [])
	if early_rain_plan is Array:
		def.early_rain_schedule = parse_schedule(early_rain_plan)
	return def


## 现在是不是还在用早先那套日程。
func is_early() -> bool:
	return early_until != &"" and not GameState.has_flag(early_until)


## 这位居民收到 item_id 是什么反应：&"love" &"like" &"ok" &"dislike"。
func taste_of(item_id: StringName) -> StringName:
	if loves.has(item_id):
		return &"love"
	if likes.has(item_id):
		return &"like"
	if dislikes.has(item_id):
		return &"dislike"
	return &"ok"


## 把表里的日程转成 {"from": 分钟, "map": StringName, "tile": Vector2i, "facing": int, "work": bool, "note": String}。
## note 是这段时间在干什么（"bench" 坐长凳、"board" 看告示……），对话文件用 Residents.at() 查，可以不写。
## 表里的写法：{"from": "8:00", "map": "town", "tile": [10, 12], "facing": "down", "work": true}；
## map 不写或为空表示回家（不在任何地图上）。
static func parse_schedule(list: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for v: Variant in list:
		if not v is Dictionary:
			continue
		var e: Dictionary = v
		out.append({
			"from": parse_time(str(e.get("from", "6:00"))),
			"map": StringName(str(e.get("map", ""))),
			"tile": _tile(e.get("tile", [0, 0])),
			"facing": int(FACINGS.get(str(e.get("facing", "down")), 0)),
			"work": bool(e.get("work", false)),
			"note": str(e.get("note", "")),
		})
	return out


## "8:30" -> 510。过了半夜写 "25:00"。
static func parse_time(text: String) -> int:
	var parts := text.split(":")
	if parts.size() != 2:
		return -1
	return int(parts[0]) * 60 + int(parts[1])


static func _tile(v: Variant) -> Vector2i:
	if v is Array and v.size() >= 2:
		return Vector2i(int(v[0]), int(v[1]))
	return Vector2i.ZERO


static func _ids(v: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	if v is Array:
		for id: Variant in v:
			out.append(StringName(str(id)))
	return out
