extends Node
## 天气：每天一种，前一晚就定好第二天的，所以可以预报。
## 现在生效的规则：雨和雷雨自动浇地；雷雨夜可能劈坏作物；雾天雾生作物才生长；
## 有霜的早上不耐寒的作物冻死。多云和大风暂时只有画面区别。

signal changed

const SUNNY := &"sunny"
const CLOUDY := &"cloudy"
const RAIN := &"rain"
const STORM := &"storm"
const FOG := &"fog"
const WIND := &"wind"
const SNOW := &"snow"
const FROST := &"frost"

const NAMES: Dictionary[StringName, String] = {
	SUNNY: "晴", CLOUDY: "多云", RAIN: "雨", STORM: "雷雨", FOG: "雾", WIND: "大风", SNOW: "雪", FROST: "霜",
}
## 各季节的基础权重，顺序是春夏秋冬
const BASE: Array[Dictionary] = [
	{SUNNY: 45, CLOUDY: 20, RAIN: 18, STORM: 4, FOG: 13},
	{SUNNY: 50, CLOUDY: 15, RAIN: 15, STORM: 12, FOG: 8},
	{SUNNY: 42, CLOUDY: 18, RAIN: 12, FOG: 14, WIND: 14},
	{SUNNY: 38, CLOUDY: 22, SNOW: 22, FOG: 8, FROST: 10},
]

var today: StringName = SUNNY
var tomorrow: StringName = SUNNY
var yesterday: StringName = SUNNY

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	SaveSystem.register(&"weather", self)
	GameClock.register_daily(GameClock.ORDER_WEATHER, _on_new_day)
	reset_data()


## 第 day 天各种天气的权重，包含节气的修正。
static func weights_for(day: int) -> Dictionary:
	# 节日那天不下雨不起雾：大家要在外头待一整天
	if Database.festival_on(day) != null:
		return {SUNNY: 70, CLOUDY: 30}
	var term := GameClock.term_index_of(day)
	var w: Dictionary = BASE[term / Database.TERMS_PER_SEASON].duplicate()
	match term:
		1:  # 雨水：降雨概率大增
			w[RAIN] = int(w[RAIN]) * 3
		2:  # 惊蛰：多雷雨
			w[STORM] = int(w[STORM]) * 4
		5:  # 谷雨：必定有雨
			w = {RAIN: 80, STORM: 20}
		17:  # 霜降：夜里可能有霜
			w[FROST] = 40
		11:  # 大暑：多雷暴
			w[STORM] = int(w[STORM]) * 3
	return w


## 按权重选一种天气；roll 是 [0, 1) 的随机数。
static func pick(weights: Dictionary, roll: float) -> StringName:
	var total := 0
	for k: StringName in weights:
		total += int(weights[k])
	var at := roll * total
	var last: StringName = SUNNY
	for k: StringName in weights:
		last = k
		at -= int(weights[k])
		if at < 0.0:
			return k
	return last


func name_of(kind: StringName) -> String:
	return NAMES.get(kind, "")


func today_text() -> String:
	return name_of(today)


## 给对话用：明天的天气。
func forecast_text() -> String:
	return name_of(tomorrow)


## 收音机播报要念的几段，对应 audio/radio/ 下的文件名：今天的节气和天气，明天的天气。
func report_clips() -> PackedStringArray:
	return PackedStringArray([
		"today_%s" % GameClock.term_id(), "w_%s" % today, "tomorrow", "w_%s" % tomorrow,
	])


## 今天的天气会不会把耕地淋湿。
func wets_soil() -> bool:
	return today == RAIN or today == STORM


func is_foggy() -> bool:
	return today == FOG


func _on_new_day() -> void:
	yesterday = today
	today = tomorrow
	tomorrow = pick(weights_for(GameClock.day + 1), _rng.randf())
	changed.emit()


func save_data() -> Dictionary:
	return {
		"today": String(today),
		"tomorrow": String(tomorrow),
		"yesterday": String(yesterday),
		"rng": str(_rng.state),
	}


func load_data(data: Dictionary) -> void:
	today = _kind(data.get("today"))
	tomorrow = _kind(data.get("tomorrow"))
	yesterday = _kind(data.get("yesterday"))
	var st := str(data.get("rng", ""))
	if st.is_valid_int():
		_rng.state = st.to_int()
	changed.emit()


func reset_data() -> void:
	_rng.randomize()
	# 第一天固定是晴天
	today = SUNNY
	yesterday = SUNNY
	tomorrow = pick(weights_for(2), _rng.randf())
	changed.emit()


func _kind(v: Variant) -> StringName:
	var k := StringName(str(v))
	return k if NAMES.has(k) else SUNNY
