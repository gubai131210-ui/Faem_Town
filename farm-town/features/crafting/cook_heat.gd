class_name CookHeat
extends RefCounted
## 灶上这一场的三段：下锅、看火、出锅。只算时间和火候，不碰背包和存档。
## 没有失败：按早了什么也不丢，一直不按到时候自己出锅，只是没有“正好”。

enum { DROP, HEAT, SERVE, OVER }

## 每样材料落进锅里隔多久
const DROP_EACH := 0.32
## 火候条走到这一段之间按下算正好
const SWEET_FROM := 0.58
const SWEET_TO := 0.9
## 出锅以后盘子亮多久
const SERVE_SECONDS := 1.8
## 按早了那句话留多久
const EARLY_SECONDS := 0.9

var phase := OVER
## 这一场要不要看火。已经有火候印的菜只演，不用再按。
var watch := true
var just := false
var _t := 0.0
var _count := 0
var _heat_seconds := 1.0
var _early_left := 0.0


## count 是材料有几样，heat_seconds 是看火这段多长，watch 是这回要不要按。
func start(count: int, heat_seconds: float, watch_fire: bool) -> void:
	_count = maxi(count, 0)
	_heat_seconds = maxf(heat_seconds, 0.1)
	watch = watch_fire
	just = false
	_t = 0.0
	_early_left = 0.0
	phase = DROP if _count > 0 else HEAT


func advance(delta: float) -> void:
	if phase == OVER:
		return
	_t += delta
	_early_left = maxf(0.0, _early_left - delta)
	if phase == DROP and _t >= _count * DROP_EACH:
		_enter(HEAT)
	elif phase == HEAT and _t >= _heat_seconds:
		_enter(SERVE)
	elif phase == SERVE and _t >= SERVE_SECONDS:
		_enter(OVER)


## 已经落进锅里的材料有几样。
func dropped() -> int:
	if phase != DROP:
		return _count
	return mini(_count, int(_t / DROP_EACH) + 1)


## 第 i 样材料往锅里落到哪了：0 还没动，1 已经进锅。
func drop_progress(i: int) -> float:
	if phase != DROP:
		return 1.0
	return clampf((_t - i * DROP_EACH) / DROP_EACH, 0.0, 1.0)


## 火候走到哪了，0 到 1。
func heat() -> float:
	if phase == DROP:
		return 0.0
	if phase == HEAT:
		return clampf(_t / _heat_seconds, 0.0, 1.0)
	return 1.0


## 现在按下去算不算正好。
func in_sweet() -> bool:
	return phase == HEAT and watch and heat() >= SWEET_FROM and heat() <= SWEET_TO


## 灶膛里的火：0 小、1 中、2 旺。
func fire_level() -> int:
	if phase == DROP:
		return 0
	if phase == HEAT:
		return 1 if heat() < SWEET_FROM else 2
	return 1


## 刚按早了，那句“还生着”还挂着。
func early_shown() -> bool:
	return _early_left > 0.0


## 按一下使用键。返回 &"just" 正好出锅、&"early" 还生着、&"close" 看完了收起来，别的时候返回空。
func press() -> StringName:
	if phase == SERVE:
		_enter(OVER)
		return &"close"
	if phase != HEAT or not watch:
		return &""
	if in_sweet():
		just = true
		_enter(SERVE)
		return &"just"
	if heat() < SWEET_FROM:
		_early_left = EARLY_SECONDS
		return &"early"
	return &""


func _enter(next: int) -> void:
	phase = next
	_t = 0.0
