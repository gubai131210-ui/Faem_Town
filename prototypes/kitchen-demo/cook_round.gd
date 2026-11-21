extends RefCounted
## 从切配到装盘。火力是输入，锅温和食材状态在时间中变化。

enum Phase { CUT, WHISK, STOVE, SERVED }

const CUTS := 4
const WHISKS := 5
const TARGET_HEAT := [0.13, 0.43, 0.73, 1.0]
const ORDERS := [
	{"name": "嫩蛋多汁", "egg": 0.68, "sauce": 0.54, "color": 0.19},
	{"name": "焦香收汁", "egg": 0.88, "sauce": 0.83, "color": 0.42},
]

var phase := Phase.CUT
var order := 0
var cuts := 0
var whisks := 0
var fire := 0
var heat := 0.13
var egg_in := false
var tomato_in := false
var egg := 0.0
var sauce := 0.0
var color := 0.0
var scorch := 0.0
var uneven := 0.0
var salt := 0
var tosses := 0
var toss_cooldown := 0.0
var result := {}


func choose(index: int) -> void:
	if phase == Phase.CUT and cuts == 0 and index >= 0 and index < ORDERS.size():
		order = index


func cut() -> bool:
	if phase != Phase.CUT:
		return false
	cuts += 1
	if cuts == CUTS:
		phase = Phase.WHISK
	return true


func whisk() -> bool:
	if phase != Phase.WHISK:
		return false
	whisks += 1
	if whisks == WHISKS:
		phase = Phase.STOVE
		fire = 2
	return true


func set_fire(level: int) -> void:
	if phase == Phase.STOVE:
		fire = clampi(level, 0, 3)


func add_egg() -> bool:
	if phase != Phase.STOVE or egg_in:
		return false
	egg_in = true
	return true


func add_tomato() -> bool:
	if phase != Phase.STOVE or tomato_in:
		return false
	tomato_in = true
	return true


func season_food() -> bool:
	if phase != Phase.STOVE or not (egg_in or tomato_in) or salt >= 3:
		return false
	salt += 1
	return true


func toss() -> bool:
	if phase != Phase.STOVE or not (egg_in or tomato_in) or toss_cooldown > 0.0:
		return false
	tosses += 1
	uneven *= 0.28
	toss_cooldown = 0.46
	return true


func step(delta: float) -> void:
	if phase != Phase.STOVE:
		return
	toss_cooldown = maxf(0.0, toss_cooldown - delta)
	heat = move_toward(heat, TARGET_HEAT[fire], delta * (0.20 if fire > 0 else 0.27))
	if not (egg_in or tomato_in):
		return
	uneven = minf(1.0, uneven + maxf(heat - 0.35, 0.0) * delta * 0.25)
	if egg_in:
		egg = minf(1.45, egg + maxf(heat - 0.25, 0.0) * delta * 0.15)
	if tomato_in:
		sauce = minf(1.35, sauce + maxf(heat - 0.26, 0.0) * delta * 0.15)
	color = minf(1.0, color + maxf(heat - 0.51, 0.0) * delta * 0.085)
	scorch = minf(1.0, scorch + maxf(heat - 0.72 + uneven * 0.18, 0.0) * delta * 0.13)


func finish() -> bool:
	if phase != Phase.STOVE or not (egg_in and tomato_in):
		return false
	var recipe: Dictionary = ORDERS[order]
	var texture := clampf(1.0 - absf(egg - float(recipe["egg"])) * 1.8, 0.0, 1.0)
	var juice := clampf(1.0 - absf(sauce - float(recipe["sauce"])) * 1.65, 0.0, 1.0)
	var browning := clampf(1.0 - absf(color - float(recipe["color"])) * 1.6, 0.0, 1.0)
	var evenness := clampf(1.0 - scorch * 2.1 - uneven * 0.26, 0.0, 1.0)
	var flavor := 1.0 if salt == 1 else (0.55 if salt == 0 else 0.25)
	var score := roundi(28 * texture + 26 * juice + 19 * browning + 15 * evenness + 12 * flavor)
	if egg < 0.34 or sauce < 0.23:
		score = mini(49, score)
	result = {
		"score": score, "egg": texture, "sauce": juice, "color": browning,
		"even": evenness, "salt": flavor,
	}
	phase = Phase.SERVED
	return true
