class_name CookRound
extends RefCounted
## 亲手做一道菜的规则，不管画面和输入：备料踩刀、掌火、起锅，最后评成家常、够味、拿手。
## 每帧告诉它玩家有没有按住添火，它算出锅温、火候正好的那一段、熟了几成、焦了几分。
## 不会失败：最差是家常，菜照样是原来那一份。各种做法的手感写在 PROFILES 里，现在只有炒。

enum Step { PREP, FIRE, SERVE, DONE }
enum Grade { HOME, TASTY, SIGNATURE }

const GRADE_NAMES: Array[String] = ["家常", "够味", "拿手"]
## 得分到这个数是够味、拿手
const TASTY_FROM := 0.45
const SIGNATURE_FROM := 0.72

## 各种做法的手感。
## seconds：锅温一直在正好那一段里，要多久熟。zone：那一段的中心在哪两个数之间走。
## hop：隔多久换一个地方。drift：每秒挪多远。half：那一段的半宽。
## thrust / gravity / drag：按住往上的劲、松手往下掉的劲、阻力。
## chill：下一样料锅温掉多少。scorch：烧过头时每秒焦多少（再乘上超出的量）。
const PROFILES: Dictionary[StringName, Dictionary] = {
	&"stir": {
		"seconds": 9.0, "zone": Vector2(0.5, 0.84), "hop": Vector2(1.3, 2.4), "drift": 0.5,
		"half": 0.13, "thrust": 2.5, "gravity": 1.7, "drag": 2.4, "chill": 0.2, "scorch": 1.1,
	},
}

## 备料：刀在案板上来回走，走到中间那一段落刀算准。一个来回多少秒，中间那一段的半宽。
const BEAT_SECONDS := 1.5
const BEAT_HALF := 0.15
## 厨艺每高一档，正好那一段宽一点；备料全准再宽一点
const HALF_PER_RANK := 0.02
const HALF_FOR_PREP := 0.03
## 提鲜的机会开多久；撒下去锅温掉多少
const SEASON_SECONDS := 2.6
const SEASON_CHILL := 0.1
## 起锅：一圈光往锅沿收，收到沿上按下算利落。一圈多少秒，利落的那一段，最多等几圈，每多等一圈焦多少
const SERVE_SECONDS := 1.15
const SERVE_GOOD := 0.26
const SERVE_ROUNDS := 3
const SERVE_SCORCH := 0.05
## 掌火最久多少秒。一直不添火也会熟，只是没有锅气。
const FIRE_LIMIT := 40.0
## 锅温低于正好那一段时也慢慢熟，是正好时的几分之几
const COLD_RATE := 0.12

var method: StringName = &"stir"
var step := Step.PREP
var grade := Grade.HOME
var score := 0.0

## 备料
var cuts_total := 3
var cuts := 0
var cuts_good := 0
var beat := 0.0

## 掌火
var temp := 0.0
var vel := 0.0
var zone := 0.6
var half := 0.13
var done := 0.0
var scorch := 0.0
var in_time := 0.0
var fire_time := 0.0
var drop_total := 1
var drops := 0
var season_left := 0.0
var seasoned := false

## 起锅
var serve_time := 0.0
var serve_good := false

## 这一帧里发生的事，画面拿去配声音和字，读完自己清掉。
## chop_good、chop_off、drop、season_open、season_hit、season_gone、cooked、serve_good、serve_late
var events: Array[StringName] = []

var _profile: Dictionary = {}
var _zone_to := 0.6
var _hop_left := 0.0
var _season_at := 0.5
var _season_opened := false
var _rank := 0
var _rng := RandomNumberGenerator.new()


static func supports(def: RecipeDef) -> bool:
	return def != null and PROFILES.has(def.method)


## ingredients 是这道菜几样材料；rank 是厨艺到了第几档（0 到 3）；seed_value 给测试用。
func _init(cook_method: StringName = &"stir", ingredients: int = 2, rank: int = 0, seed_value: int = -1) -> void:
	method = cook_method if PROFILES.has(cook_method) else &"stir"
	_profile = PROFILES[method]
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	_rank = clampi(rank, 0, 3)
	drop_total = maxi(1, ingredients)
	cuts_total = clampi(ingredients + 2, 3, 5)
	half = float(_profile["half"]) + HALF_PER_RANK * _rank
	var span: Vector2 = _profile["zone"]
	zone = lerpf(span.x, span.y, 0.35)
	_zone_to = zone
	_season_at = _rng.randf_range(0.4, 0.7)


## 刀现在走到案板的哪儿，0 到 1 来回。
func beat_pos() -> float:
	return pingpong(beat / BEAT_SECONDS * 2.0, 1.0)


func beat_in_window() -> bool:
	return absf(beat_pos() - 0.5) <= BEAT_HALF


## 落一刀。准不准都算一刀，准的多了，掌火时正好那一段宽一点。
func chop() -> bool:
	if step != Step.PREP:
		return false
	cuts += 1
	var good := beat_in_window()
	if good:
		cuts_good += 1
	events.append(&"chop_good" if good else &"chop_off")
	if cuts >= cuts_total:
		half += HALF_FOR_PREP * prep_ratio()
		step = Step.FIRE
		drops = 1
		temp = 0.22
		events.append(&"drop")
	return true


func prep_ratio() -> float:
	return float(cuts_good) / float(maxi(cuts_total, 1))


func in_zone() -> bool:
	return absf(temp - zone) <= half


## 现在该下锅的料下了几样（画面按这个数往锅里放）。
func advance(delta: float, held: bool) -> void:
	match step:
		Step.PREP:
			beat += delta
		Step.FIRE:
			_fire(delta, held)
		Step.SERVE:
			_wait_serve(delta)


func _fire(delta: float, held: bool) -> void:
	vel += (float(_profile["thrust"]) if held else -float(_profile["gravity"])) * delta
	vel -= vel * float(_profile["drag"]) * delta
	temp += vel * delta
	if temp <= 0.0:
		temp = 0.0
		vel = maxf(vel, 0.0)
	elif temp >= 1.0:
		temp = 1.0
		vel = minf(vel, 0.0)
	_hop_left -= delta
	if _hop_left <= 0.0:
		var hop: Vector2 = _profile["hop"]
		var span: Vector2 = _profile["zone"]
		_hop_left = _rng.randf_range(hop.x, hop.y)
		_zone_to = _rng.randf_range(span.x, span.y)
	zone = move_toward(zone, _zone_to, float(_profile["drift"]) * delta)
	fire_time += delta
	var rate := 1.0 / float(_profile["seconds"])
	if in_zone():
		in_time += delta
		done += rate * delta
	elif temp > zone + half:
		scorch = minf(1.0, scorch + (temp - zone - half) * float(_profile["scorch"]) * delta)
		done += rate * 0.5 * delta
	else:
		done += rate * COLD_RATE * delta
	if fire_time >= FIRE_LIMIT:
		done = 1.0
	while drops < drop_total and done >= float(drops) / float(drop_total):
		drops += 1
		temp = maxf(0.0, temp - float(_profile["chill"]))
		vel = minf(vel, 0.0)
		events.append(&"drop")
	if not _season_opened and done >= _season_at:
		_season_opened = true
		season_left = SEASON_SECONDS
		events.append(&"season_open")
	elif season_left > 0.0:
		season_left -= delta
		if season_left <= 0.0:
			season_left = 0.0
			events.append(&"season_gone")
	if done >= 1.0:
		done = 1.0
		season_left = 0.0
		step = Step.SERVE
		serve_time = 0.0
		events.append(&"cooked")


## 提鲜：机会开着的时候撒一把。锅温会掉一点。
func season() -> bool:
	if step != Step.FIRE or season_left <= 0.0:
		return false
	seasoned = true
	season_left = 0.0
	temp = maxf(0.0, temp - SEASON_CHILL)
	vel = minf(vel, 0.0)
	events.append(&"season_hit")
	return true


## 起锅那圈光收到哪儿了：1 在外头，0 收到锅沿。
func serve_ring() -> float:
	return 1.0 - fposmod(serve_time, SERVE_SECONDS) / SERVE_SECONDS


func _wait_serve(delta: float) -> void:
	var before := int(serve_time / SERVE_SECONDS)
	serve_time += delta
	var after := int(serve_time / SERVE_SECONDS)
	if after > before:
		scorch = minf(1.0, scorch + SERVE_SCORCH)
		if after >= SERVE_ROUNDS:
			events.append(&"serve_late")
			_finish()


## 起锅。光收到锅沿那一下按算利落。
func serve() -> bool:
	if step != Step.SERVE:
		return false
	serve_good = serve_ring() <= SERVE_GOOD
	events.append(&"serve_good" if serve_good else &"serve_late")
	_finish()
	return true


## 锅气：掌火的时间里有几成在正好那一段。
func aroma() -> float:
	return clampf(in_time / maxf(fire_time, 0.01), 0.0, 1.0)


func _finish() -> void:
	score = 0.2 * prep_ratio() + 0.45 * aroma() + (0.15 if serve_good else 0.0) \
		+ (0.2 if seasoned else 0.0) - 0.6 * scorch
	if score >= SIGNATURE_FROM:
		grade = Grade.SIGNATURE
	elif score >= TASTY_FROM:
		grade = Grade.TASTY
	else:
		grade = Grade.HOME
	step = Step.DONE


func grade_name() -> String:
	return GRADE_NAMES[grade]


## 出锅以后说的一句：夸最好的一处，或者点最该改的一处。
func remark() -> String:
	if scorch >= 0.3:
		return "锅底有点焦。火候条冲过金色那一段就松手。"
	if grade == Grade.SIGNATURE:
		return "锅气足，起锅利落。" if serve_good else "锅气足，火候一直稳着。"
	if aroma() < 0.5:
		return "火忽大忽小。让锅温跟着金色那一段走。"
	if not seasoned:
		return "差一把提鲜。看到调料亮起来就按上。"
	if prep_ratio() < 0.6:
		return "刀落得急了。等刀走到中间再落。"
	return "差一点起锅的利落。等那圈光收到锅沿再按。"
