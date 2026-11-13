class_name FishFight
extends RefCounted
## 收放线小游戏的规则，不管画面和输入：每帧告诉它玩家有没有按住收线，它算出鱼离岸多远、线多紧。
## 鱼离岸的距离到 0 就钓上来；线的张力到 1 就断线；鱼跑到 1 就脱钩。

enum Result { NONE, CAUGHT, LOST_LINE, LOST_FISH }

## 收线时每秒拉近多少（按鱼竿等级加成）
const REEL_SPEED := 0.18
const REEL_PER_LEVEL := 0.02
## 收线时张力每秒涨多少；鱼挣扎时乘上倍数
const TENSION_RISE := 0.32
const STRUGGLE_MULT := 4.0
## 松手时张力每秒落多少
const TENSION_FALL := 0.9
## 鱼挣扎时往外跑得更快
const STRUGGLE_PULL_MULT := 1.5
## 挣扎前的预警时间（浮漂先抖一下）
const WARNING := 0.3
## 鱼竿每升一级，张力涨得慢一成
const TENSION_PER_LEVEL := 0.1

var fish: FishDef
var distance := 0.6
var tension := 0.0
var struggling := false
## 马上要挣扎了：画面上闪一下提醒
var warning := false
var result := Result.NONE
var elapsed := 0.0

var _rod_level := 0
var _next_struggle := 0.0
var _struggle_left := 0.0
var _rng := RandomNumberGenerator.new()


func _init(def: FishDef, rod_level: int, seed_value: int = -1) -> void:
	fish = def
	_rod_level = rod_level
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	_schedule()


## 推进一帧。reeling 是玩家按着收线。
func step(delta: float, reeling: bool) -> void:
	if result != Result.NONE:
		return
	elapsed += delta
	_update_struggle(delta)
	var pull := fish.pull * (STRUGGLE_PULL_MULT if struggling else 1.0)
	if reeling:
		distance -= (REEL_SPEED + REEL_PER_LEVEL * _rod_level) * delta
		# 收线时鱼也在往外挣，只是被拉回来得更快
		distance += pull * 0.3 * delta
		var rise := TENSION_RISE * (STRUGGLE_MULT if struggling else 1.0)
		rise *= 1.0 - TENSION_PER_LEVEL * _rod_level
		tension += rise * delta
	else:
		distance += pull * delta
		tension -= TENSION_FALL * delta
	tension = clampf(tension, 0.0, 1.0)
	if distance <= 0.0:
		distance = 0.0
		result = Result.CAUGHT
	elif tension >= 1.0:
		result = Result.LOST_LINE
	elif distance >= 1.0:
		distance = 1.0
		result = Result.LOST_FISH


func is_over() -> bool:
	return result != Result.NONE


func _update_struggle(delta: float) -> void:
	if struggling:
		_struggle_left -= delta
		if _struggle_left <= 0.0:
			struggling = false
			_schedule()
		return
	_next_struggle -= delta
	warning = _next_struggle <= WARNING
	if _next_struggle <= 0.0:
		struggling = true
		warning = false
		_struggle_left = fish.fight_len * _rng.randf_range(0.8, 1.2)


func _schedule() -> void:
	_next_struggle = fish.fights * _rng.randf_range(0.7, 1.3)
