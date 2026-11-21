extends Node
## 时间和日期。一天从 6:00 到次日 2:00；一季 24 天，一年四季。
## 每季 6 个节气，每个节气 4 天，定义在 data/solar_terms.json。

## 分钟数发生了可见的变化（每 10 分钟一次）
signal time_changed
## 新的一天开始，所有每日结算已经完成
signal day_started(day: int)
## 熬到了凌晨两点
signal day_ran_out

const DAY_START := 360.0
const DAY_END := 1560.0
const DAYS_PER_SEASON := 24
const SEASONS_PER_YEAR := 4
const DAYS_PER_TERM := 4
const SEASON_NAMES: Array[String] = ["春", "夏", "秋", "冬"]
## 现实一秒对应的游戏分钟数；一天约 14 分钟。暂停菜单里调慢时再乘 pace
const MINUTES_PER_SECOND := 1.4
## 把一天调慢时用的倍率。平常是 1
const PACE_SLOW := 0.5
## 夏至天黑推迟、冬至天黑提前的分钟数（两小时）
const SOLSTICE_SHIFT := 120.0

## 每日结算的固定顺序，数字小的先执行
const ORDER_WEATHER := 10
const ORDER_CROPS := 20
const ORDER_FORAGE := 25
const ORDER_ANIMALS := 30
const ORDER_MACHINES := 40
const ORDER_NPCS := 50
const ORDER_SHIPPING := 60

## 从 1 开始的总天数
var day := 1
var minutes := DAY_START
## 为假时时间不流动（菜单、对话、转场）
var running := false
## 一天走多快。1 是平常，PACE_SLOW 是慢。跟着时钟存档
var pace := 1.0

var _daily: Array[Dictionary] = []
var _last_shown := -1


func _ready() -> void:
	SaveSystem.register(&"clock", self)


func _process(delta: float) -> void:
	if not running:
		return
	# 卡顿时限制单帧步长，避免一下跳过很多时间
	minutes += minf(delta, 0.05) * MINUTES_PER_SECOND * pace
	if minutes >= DAY_END:
		minutes = DAY_END
		running = false
		time_changed.emit()
		day_ran_out.emit()
		return
	var shown := int(minutes) / 10
	if shown != _last_shown:
		_last_shown = shown
		time_changed.emit()


func season() -> int:
	return ((day - 1) / DAYS_PER_SEASON) % SEASONS_PER_YEAR


func season_id() -> StringName:
	return Database.SEASON_IDS[season()]


func year() -> int:
	return (day - 1) / (DAYS_PER_SEASON * SEASONS_PER_YEAR) + 1


func day_of_season() -> int:
	return (day - 1) % DAYS_PER_SEASON + 1


## 第 d 天是一年里的第几个节气，0 是立春。
static func term_index_of(d: int) -> int:
	return posmod(d - 1, DAYS_PER_SEASON * SEASONS_PER_YEAR) / DAYS_PER_TERM


func term_index() -> int:
	return term_index_of(day)


func term() -> TermDef:
	return Database.term(term_index())


func term_id() -> StringName:
	var def := term()
	return def.id if def != null else &""


func term_name() -> String:
	var def := term()
	return def.name if def != null else ""


## 黄昏相对平常挪多少分钟：夏至推迟两小时、冬至提前两小时，别的节气不挪。
## 只挪天黑这一头，不挪天亮，所以夏至夜最短、冬至夜最长。
## 天色的明暗、灯、窗、萤火虫、夜行的鱼和夜晚的曲子都按这个挪；
## 居民作息和动物进舍按钟点走，不跟着挪。
func dusk_shift() -> float:
	var id := term_id()
	if id == &"xiazhi":
		return SOLSTICE_SHIFT
	if id == &"dongzhi":
		return -SOLSTICE_SHIFT
	return 0.0


## 试玩用的四段日子。只在调试运行里用 F9 跳，正式版没有这个键。
## day 是一年里的第几天（立春是 1），minutes 是当天的钟点。
const LOOK_STOPS: Array[Dictionary] = [
	{"day": 41, "minutes": 13 * 60, "term": &"xiaoshu", "map": &"town", "spawn": &"from_farm",
		"text": "小暑中午。人要走一会儿才到阴凉处摇扇。别睡觉，Shift+F9 回到原来的日子。"},
	{"day": 73, "minutes": 10 * 60, "term": &"lidong", "map": &"farm", "spawn": &"house_door",
		"hay": true,
		"text": "立冬。家畜整天在舍里，背包里放了干草。别睡觉，Shift+F9 回去。"},
	{"day": 81, "minutes": 10 * 60, "term": &"daxue", "map": &"shanci", "spawn": &"steps",
		"text": "大雪。往上走到山顶湖，银鱼只在这四天咬钩。别睡觉，Shift+F9 回去。"},
	{"day": 77, "minutes": 15 * 60, "term": &"xiaoxue", "map": &"town", "spawn": &"from_farm",
		"text": "冬天午后。站着的人搓手、呵白气，茶馆门口人多。别睡觉，Shift+F9 回去。"},
	{"day": 1, "minutes": 11 * 60, "term": &"lichun", "map": &"town", "spawn": &"from_farm", "today": &"fog",
		"text": "雾天。人走得慢、出门晚，柏先生在家，白鹭在画画。别睡觉，Shift+F9 回去。"},
	{"day": 49, "minutes": 10 * 60 + 30, "term": &"liqiu", "map": &"town", "spawn": &"from_farm", "today": &"wind",
		"text": "大风。云娘这会儿在街上追幌子，阿禾下午收摊。别睡觉，Shift+F9 回去。"},
]


func date_text() -> String:
	return "%s %d日" % [SEASON_NAMES[season()], day_of_season()]


func time_text() -> String:
	var m := int(minutes)
	return "%02d:%02d" % [(m / 60) % 24, (m % 60) / 10 * 10]


## 登记一个每日结算步骤。order 用上面的 ORDER_ 常量。
func register_daily(order: int, step: Callable) -> void:
	_daily.append({"order": order, "step": step})
	_daily.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var oa: int = a["order"]
		var ob: int = b["order"]
		return oa < ob)


## 进入下一天：日期加一，按固定顺序跑完所有每日结算，然后通知。
func advance_day() -> void:
	day += 1
	minutes = DAY_START
	_last_shown = -1
	for entry in _daily:
		var step: Callable = entry["step"]
		if step.is_valid():
			step.call()
	time_changed.emit()
	day_started.emit(day)


func is_slow() -> bool:
	return pace < 0.75


func set_slow_day(on: bool) -> void:
	pace = PACE_SLOW if on else 1.0


func save_data() -> Dictionary:
	return {"day": day, "minutes": minutes, "pace": pace}


func load_data(data: Dictionary) -> void:
	day = maxi(1, int(data.get("day", 1)))
	minutes = clampf(float(data.get("minutes", DAY_START)), DAY_START, DAY_END)
	pace = PACE_SLOW if float(data.get("pace", 1.0)) < 0.75 else 1.0
	_last_shown = -1
	time_changed.emit()


func reset_data() -> void:
	day = 1
	minutes = DAY_START
	pace = 1.0
	running = false
	_last_shown = -1
	time_changed.emit()
