class_name MineTroupe
extends MineMonster
## 第 30 层的首领，无名戏班：一个人影轮着戴三张面具，一张面具一种打法。
## 红脸：连着冲三回，每回冲之前顿一下。白脸：站着不动，朝四面八方撒两圈纸钱。黑脸：跳起来砸下来，落地砸一圈。
## 一轮打完歇一阵、换下一张脸。什么时候都打得动，但推不开、砸不晕。

const MASKS: Array[StringName] = [&"red", &"white", &"black"]
## 离人多近开始出招（按面具）
const RANGES: Dictionary[StringName, float] = {&"red": 90.0, &"white": 80.0, &"black": 70.0}
## 追了这么久还没够着也照样出招
const CHASE_TIME := 1.5
## 红脸一轮冲几回，后几回冲之前顿多久
const DASHES := 3
const DASH_WINDUP := 0.4
## 白脸一圈几枚纸钱，两圈之间隔多久
const RING := 8
const RING_GAP := 0.4
## 黑脸一跳最远多远、在空中多久
const LEAP_LEN := 96.0
const LEAP_TIME := 0.6

## 现在戴的是第几张面具
var mask := 0
var _dash := 0
var _second_ring := false


func skin() -> StringName:
	return MASKS[mask]


func update(delta: float, target: Vector2, level: MineFloor) -> void:
	if state == State.DEAD:
		return
	flash = maxf(0.0, flash - delta)
	_landed = false
	t += delta
	var to := target - pos
	var dist := to.length()
	match state:
		State.ROAM:
			if dist <= def.sight:
				_enter(State.CHASE)
		State.CHASE:
			if dist <= RANGES[skin()] or t >= CHASE_TIME:
				_dash = 0
				_aim(target, level)
				_enter(State.WINDUP)
			elif dist > 0.01:
				facing = to / dist
				_move(facing * def.speed * delta, level)
		State.WINDUP:
			if t >= (def.windup if _dash == 0 else DASH_WINDUP):
				_hit_done = false
				_from = pos
				_second_ring = false
				if skin() == &"white":
					_ring(0.0)
				_enter(State.STRIKE)
		State.STRIKE:
			match skin():
				&"red":
					_move(_dir * def.strike_speed * delta, level)
					if t >= def.strike_time:
						_dash += 1
						if _dash < DASHES:
							_aim(target, level)
							_enter(State.WINDUP)
						else:
							_enter(State.REST)
				&"white":
					if not _second_ring and t >= RING_GAP:
						_second_ring = true
						_ring(PI / RING)
					if t >= RING_GAP * 2.0:
						_enter(State.REST)
				_:
					pos = _from.lerp(_land, clampf(t / LEAP_TIME, 0.0, 1.0))
					if t >= LEAP_TIME:
						_landed = true
						events.append(&"land")
						_enter(State.REST)
		State.REST:
			if t >= def.rest:
				mask = (mask + 1) % MASKS.size()
				events.append(&"mask")
				_enter(State.CHASE)


func strikes(target: Vector2, target_radius: float = 5.0) -> bool:
	if _hit_done:
		return false
	var gap := pos.distance_to(target)
	var hit := false
	if skin() == &"red":
		hit = state == State.STRIKE and gap <= def.radius + target_radius
	elif skin() == &"black":
		hit = _landed and gap <= def.blast + target_radius
	if hit:
		_hit_done = true
	return hit


func air() -> float:
	if skin() != &"black" or state != State.STRIKE:
		return -1.0
	return clampf(t / LEAP_TIME, 0.0, 1.0)


func guarded_from(_from_where: Vector2) -> bool:
	return false


## 什么时候都打得动；推不开，锤也砸不晕。
func take_hit(damage: int, _from_where: Vector2, _knock_speed: float, _breaks: bool = false) -> Dictionary:
	if state == State.DEAD:
		return {"blocked": false, "damage": 0, "dead": true}
	var dealt := mini(hp, maxi(1, damage))
	hp -= dealt
	flash = 0.18
	if hp <= 0:
		_enter(State.DEAD)
	return {"blocked": false, "damage": dealt, "dead": hp <= 0}


func _half() -> float:
	return 6.0


## 出招前看准方向；黑脸还要看准落在哪。
func _aim(target: Vector2, level: MineFloor) -> void:
	var to := target - pos
	_dir = to.normalized() if to.length() > 0.01 else facing
	facing = _dir
	if skin() != &"black":
		return
	var aim := pos + to.limit_length(LEAP_LEN)
	_land = pos
	for i in 9:
		var p := aim.lerp(pos, i / 8.0)
		if _passable(p, level):
			_land = p
			return


## 朝四面八方撒一圈纸钱；turn 是整圈转过多少弧度（第二圈错开半格）。
func _ring(turn: float) -> void:
	for i in RING:
		var dir := Vector2.from_angle(TAU * i / RING + turn)
		pending_shots.append(MineShot.create(pos, dir * def.shot_speed, def.damage, &"paper"))
	events.append(&"spit")
