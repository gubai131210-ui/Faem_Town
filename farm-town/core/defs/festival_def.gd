class_name FestivalDef
extends RefCounted
## 一个节日，来自 data/festivals.json：哪一天、在哪张地图、几点到几点，谁主持，大家站在哪。

const NO_TILE := Vector2i(-1, -1)

var id: StringName
var name: String
## 在哪个节气的第几天（1 到 4）
var term: StringName
var day := 1
var map: StringName
## 开始和结束的时刻（分钟）。过了半夜写 "25:00"
var from := 0
var to := 0
## 早上的提示里说的时间地点
var note: String
## 主持人和他站的格子：和他搭话就是参加节日的活动
var host: StringName
var host_tile := NO_TILE
## 看摊的人（可以就是主持人）和摊子占的格子：对着摊子按使用键等于和他搭话
var keeper: StringName = &""
var keeper_tile := NO_TILE
var counter: Array[Vector2i] = []
## 大家朝着哪一格站
var focus := NO_TILE
## 其余居民站的格子，按居民表的顺序分
var crowd: Array[Vector2i] = []
## 这张地图上没有家门的居民从哪一格进出
var gate := NO_TILE
## 只在这一天、摊子上卖的东西
var goods: Array[StringName] = []
## 比赛的对手：项目 -> [{"npc": 居民 id, "score": 成绩}]，成绩从高到低
var rivals: Dictionary[StringName, Array] = {}
## 第一、二、三名的奖金
var prizes: Array[int] = []
## 放河灯：谁会放一盏。lamp 为空是年年都放，否则要那盏灯亮了以后
var floaters: Array[Dictionary] = []
## 饺子宴：口味 -> 算这种口味的物品 id；没列出来的按物品种类算
var fillings: Dictionary[StringName, Array] = {}
## 摆装饰的格子，从里到外；摆多少由地图决定
var decor: Array[Vector2i] = []


static func from_dict(d: Dictionary) -> FestivalDef:
	var def := FestivalDef.new()
	def.id = StringName(str(d.get("id", "")))
	def.name = str(d.get("name", ""))
	def.term = StringName(str(d.get("term", "")))
	def.day = int(d.get("day", 1))
	def.map = StringName(str(d.get("map", "")))
	def.from = NpcDef.parse_time(str(d.get("from", "")))
	def.to = NpcDef.parse_time(str(d.get("to", "")))
	def.note = str(d.get("note", ""))
	def.host = StringName(str(d.get("host", "")))
	def.host_tile = _tile(d.get("host_tile"))
	def.keeper = StringName(str(d.get("keeper", "")))
	def.keeper_tile = _tile(d.get("keeper_tile"))
	if def.keeper == def.host:
		def.keeper_tile = def.host_tile
	def.counter = _tiles(d.get("counter"))
	def.focus = _tile(d.get("focus"))
	def.crowd = _tiles(d.get("crowd"))
	def.gate = _tile(d.get("gate"))
	def.decor = _tiles(d.get("decor"))
	var goods_in: Variant = d.get("goods", [])
	if goods_in is Array:
		for v: Variant in goods_in:
			def.goods.append(StringName(str(v)))
	var rivals_in: Variant = d.get("rivals", {})
	if rivals_in is Dictionary:
		for key: Variant in rivals_in:
			var list: Array = []
			var from_list: Variant = rivals_in[key]
			if from_list is Array:
				for e: Variant in from_list:
					if e is Dictionary:
						list.append({"npc": StringName(str(e.get("npc", ""))), "score": int(e.get("score", 0))})
			def.rivals[StringName(str(key))] = list
	var prizes_in: Variant = d.get("prizes", [])
	if prizes_in is Array:
		for v: Variant in prizes_in:
			def.prizes.append(int(v))
	var floaters_in: Variant = d.get("floaters", [])
	if floaters_in is Array:
		for e: Variant in floaters_in:
			if e is Dictionary:
				def.floaters.append({"npc": StringName(str(e.get("npc", ""))), "lamp": StringName(str(e.get("lamp", "")))})
	var fillings_in: Variant = d.get("fillings", {})
	if fillings_in is Dictionary:
		for key: Variant in fillings_in:
			var ids: Array = []
			var from_ids: Variant = fillings_in[key]
			if from_ids is Array:
				for v: Variant in from_ids:
					ids.append(StringName(str(v)))
			def.fillings[StringName(str(key))] = ids
	return def


## 这位居民在节日上站哪一格；others 是除了主持人和看摊的以外，他排第几个。没有位置返回 NO_TILE。
func tile_for(npc_id: StringName, others: int) -> Vector2i:
	if npc_id == host:
		return host_tile
	if npc_id == keeper:
		return keeper_tile
	return crowd[others] if others >= 0 and others < crowd.size() else NO_TILE


static func _tile(v: Variant) -> Vector2i:
	if v is Array and v.size() >= 2:
		return Vector2i(int(v[0]), int(v[1]))
	return NO_TILE


static func _tiles(v: Variant) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if v is Array:
		for e: Variant in v:
			var t := _tile(e)
			if t != NO_TILE:
				out.append(t)
	return out
