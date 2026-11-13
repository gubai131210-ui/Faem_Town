class_name AnimalDef
extends RefCounted
## 一种能养的动物，来自 data/animals.json。

var id: StringName
var name: String
## 住在哪栋建筑里
var building: StringName
## 序列帧（art/creatures）
var sheet: String
var price := 0
## 喂饱了第二天早上下的东西，以及偶尔附带的东西和它的概率
var produce: StringName
var extra: StringName = &""
var extra_chance := 0.0
## 下雨天心情：+ 喜欢雨，- 讨厌雨
var rain_mood := 0
## 走路的速度（像素/秒）
var speed := 18.0
## 取名字用的候选名
var names: Array[String] = []
var desc: String
## 喂几天产一次（绵羊三天一剪）
var every := 1
## 吃什么（物品 id）；空就是不用喂（蜜蜂）
var feed: StringName = &"feed"
## 白天会不会到院子里来；不出门的（蜜蜂、蚕）没有序列帧，也摸不着
var outdoor := true
## 会不会下水（鸭）
var swims := false
## 能不能牵去犁地（水牛）
var plows := false
## 被喂、被摸时叫一声用的音效名
var sound := ""
## 阿牧要哪盏灯亮了才卖（GameState 的标记）
var flag: StringName = &"lamp_river"
## 量词
var unit := "只"
## 蜜蜂：附近开着哪种花（作物 id）就出哪种蜜（物品 id）；都不是就出 produce
var honeys: Dictionary[StringName, StringName] = {}


static func from_dict(d: Dictionary) -> AnimalDef:
	var def := AnimalDef.new()
	def.id = StringName(str(d.get("id", "")))
	def.name = str(d.get("name", ""))
	def.building = StringName(str(d.get("building", "")))
	def.sheet = str(d.get("sheet", def.id))
	def.price = int(d.get("price", 0))
	def.produce = StringName(str(d.get("produce", "")))
	def.extra = StringName(str(d.get("extra", "")))
	def.extra_chance = float(d.get("extra_chance", 0.0))
	def.rain_mood = int(d.get("rain_mood", 0))
	def.speed = float(d.get("speed", 18.0))
	var list: Variant = d.get("names", [])
	if list is Array:
		for n: Variant in list:
			def.names.append(str(n))
	def.desc = str(d.get("desc", ""))
	def.every = maxi(1, int(d.get("every", 1)))
	def.feed = StringName(str(d.get("feed", "feed")))
	def.outdoor = bool(d.get("outdoor", true))
	def.swims = bool(d.get("swims", false))
	def.plows = bool(d.get("plows", false))
	def.sound = str(d.get("sound", ""))
	def.flag = StringName(str(d.get("flag", "lamp_river")))
	def.unit = str(d.get("unit", "只"))
	var h: Variant = d.get("honeys", {})
	if h is Dictionary:
		for key: Variant in h:
			def.honeys[StringName(str(key))] = StringName(str(h[key]))
	return def
