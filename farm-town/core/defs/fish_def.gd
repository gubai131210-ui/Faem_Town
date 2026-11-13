class_name FishDef
extends RefCounted
## 一种鱼的定义，来自 data/fish.json：在哪片水、什么季节和时辰咬钩、多难遛，以及作为物品的名字和价钱。

const WATERS: Array[StringName] = [&"pond", &"stream", &"river", &"lake", &"sea", &"mine_shallow", &"mine_deep"]
const TIMES: Array[StringName] = [&"any", &"day", &"night"]

var id: StringName
var name: String
var waters: Array[StringName] = []
## 空表示全年
var seasons: Array[StringName] = []
var time: StringName = &"any"
## 只在这种天气咬钩；空表示不限
var weather: StringName = &""
## 只在这个节气咬钩；空表示不限
var term: StringName = &""
## 要有这个剧情标记才会出现；空表示不限
var flag: StringName = &""
var weight := 10
var price := 0
## 体长范围（厘米）
var min_size := 10
var max_size := 20
## 不收线时鱼每秒带走多少线（0 到 1 的比例）
var pull := 0.1
## 平均隔几秒挣扎一次、每次挣扎几秒
var fights := 3.0
var fight_len := 1.0
var legend := false
## 只能用蟹笼收，钓不到
var trap := false
## 图标的形状和配色
var shape := "carp"
var body := Color.GRAY
var belly := Color.WHITE
var desc := ""


static func from_dict(d: Dictionary) -> FishDef:
	var def := FishDef.new()
	def.id = StringName(str(d.get("id", "")))
	def.name = str(d.get("name", ""))
	for w: Variant in d.get("waters", []):
		def.waters.append(StringName(str(w)))
	for s: Variant in d.get("seasons", []):
		def.seasons.append(StringName(str(s)))
	def.time = StringName(str(d.get("time", "any")))
	def.weather = StringName(str(d.get("weather", "")))
	def.term = StringName(str(d.get("term", "")))
	def.flag = StringName(str(d.get("flag", "")))
	def.weight = int(d.get("weight", 10))
	def.price = int(d.get("price", 0))
	var size: Array = d.get("size", [10, 20])
	if size.size() >= 2:
		def.min_size = int(size[0])
		def.max_size = int(size[1])
	def.pull = float(d.get("pull", 0.1))
	def.fights = float(d.get("fights", 3.0))
	def.fight_len = float(d.get("fight_len", 1.0))
	def.legend = bool(d.get("legend", false))
	def.trap = bool(d.get("trap", false))
	var art: Dictionary = d.get("art", {})
	def.shape = str(art.get("shape", "carp"))
	def.body = Color.html(str(art.get("body", "8a9a7a")))
	def.belly = Color.html(str(art.get("belly", "d8dcc8")))
	def.desc = str(d.get("desc", ""))
	return def


## 鱼作为背包里的物品。
func as_item() -> ItemDef:
	var item := ItemDef.new()
	item.id = id
	item.name = name
	item.kind = &"fish"
	item.icon = "fish:" + String(id)
	item.stack = 99
	item.price = price
	item.desc = desc
	return item


## 这种鱼现在在这片水里咬不咬钩。
func bites(water: StringName, season: StringName, night: bool, today: StringName, term_id: StringName) -> bool:
	if trap or not waters.has(water):
		return false
	if not seasons.is_empty() and not seasons.has(season):
		return false
	if time == &"day" and night or time == &"night" and not night:
		return false
	if weather != &"" and weather != today:
		return false
	if term != &"" and term != term_id:
		return false
	if flag != &"" and not GameState.has_flag(flag):
		return false
	return true


## 体长在这种鱼里算什么品质：最大的一成半是优，再往下三成是良。
func quality_for(size: int) -> int:
	var k := float(size - min_size) / maxf(1.0, float(max_size - min_size))
	if k >= 0.85:
		return 2
	if k >= 0.55:
		return 1
	return 0
