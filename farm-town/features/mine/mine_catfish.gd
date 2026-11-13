class_name MineCatfish
extends MineMonster
## 第 20 层的首领，井底老鲶：待在水池里，武器够不着，隔一阵朝岸上吐一排水弹。
## 要对着水池甩竿：它不戒备的时候会游过来咬钩，遛赢了就被拉上岸，晕一阵，这时候才打得动；
## 晕完跳回水里，戒备一阵（不咬钩、只吐水），然后再来。

## 被拉上岸又跳回去以后，多久不咬钩
const WARY_AFTER_LAND := 6.0
## 咬了钩又挣脱以后，多久不咬钩
const WARY_AFTER_SLIP := 2.5
## 隔多久吐一次水
const ATTACK_EVERY := 2.4
## 离浮漂多近算游到了（这时候才咬）
const BITE_DIST := 14.0
## 一排水弹相邻两颗差多少度
const SPREAD := 16.0
## 咬了钩以后遛它的手感：比钓鱼图鉴里那条传说鱼（old_well_catfish）好对付得多，
## 最普通的竿也遛得上来——这里是打首领的一步，不是考钓鱼
const FISH_ID := &"old_well_catfish"
const FIGHT_PULL := 0.08
const FIGHT_EVERY := 3.0
const FIGHT_LEN := 0.7

## 水池中间，跳回水里落在这
var home := Vector2.ZERO
## 浮漂在哪、水里现在有没有线
var lure := Vector2.ZERO
var lured := false
var _wary := 3.0
var _attack_t := 2.0
var _swim_to := Vector2.ZERO
var _swim_t := 0.0


func _setup() -> void:
	home = pos
	_swim_to = pos


func in_water() -> bool:
	return state != State.STUNNED and state != State.DEAD


## 还要戒备多久（这段时间不咬钩）。
func wary() -> float:
	return _wary


## 有人把线甩进了水池。
func cast_line(at: Vector2) -> void:
	lure = at
	lured = true


## 线收走了（没钓上来）。咬过钩的话戒备一小会儿。
func line_gone() -> void:
	if lured and state == State.CHASE:
		_wary = maxf(_wary, WARY_AFTER_SLIP)
	lured = false


## 是不是已经游到浮漂底下、可以咬钩了。
func at_bait() -> bool:
	return state == State.CHASE and pos.distance_to(lure) <= BITE_DIST


## 咬钩以后交给收放线小游戏的那条“鱼”。
func as_fish() -> FishDef:
	var fish := FishDef.new()
	fish.id = FISH_ID
	fish.name = def.name
	fish.pull = FIGHT_PULL
	fish.fights = FIGHT_EVERY
	fish.fight_len = FIGHT_LEN
	return fish


## 被拉上岸，摔在 at 这里。
func land(at: Vector2) -> void:
	if state == State.DEAD:
		return
	pos = at
	lured = false
	events.append(&"ashore")
	_enter(State.STUNNED)


func update(delta: float, target: Vector2, level: MineFloor) -> void:
	if state == State.DEAD:
		return
	flash = maxf(0.0, flash - delta)
	t += delta
	_wary = maxf(0.0, _wary - delta)
	var to := target - pos
	match state:
		State.ROAM:
			_swim(delta, level)
			_attack_t -= delta
			if lured and _wary <= 0.0:
				_enter(State.CHASE)
			elif _attack_t <= 0.0 and to.length() <= def.sight:
				_enter(State.WINDUP)
		State.CHASE:
			if not lured:
				_enter(State.ROAM)
			else:
				var d := lure - pos
				if d.length() > 2.0:
					facing = d.normalized()
					_move(facing * minf(d.length(), def.speed * 1.5 * delta), level)
		State.WINDUP:
			# 抬着头跟着人转，吐出去的那一下才定方向
			if to.length() > 0.01:
				_dir = to.normalized()
				facing = _dir
			if t >= def.windup:
				_spit()
				_enter(State.STRIKE)
		State.STRIKE:
			if t >= def.strike_time:
				_enter(State.REST)
		State.REST:
			if t >= def.rest:
				_attack_t = ATTACK_EVERY
				_enter(State.ROAM)
		State.STUNNED:
			if t >= def.stun:
				pos = home
				_swim_to = home
				_wary = WARY_AFTER_LAND
				_attack_t = 1.0
				events.append(&"dive")
				_enter(State.ROAM)


## 在水里武器够不着；上了岸才打得动，不被推开。
func take_hit(damage: int, _from_where: Vector2, _knock_speed: float, _breaks: bool = false) -> Dictionary:
	return _armored_hit(damage)


func guarded_from(_from_where: Vector2) -> bool:
	return state != State.STUNNED


## 它自己不撞人，伤人的只有水弹。
func strikes(_target: Vector2, _target_radius: float = 5.0) -> bool:
	return false


## 一排水弹：三颗，生命掉了一半以后五颗。
func _spit() -> void:
	var n := 3 if hp * 2 > def.hp else 5
	for i in n:
		var ang := deg_to_rad(SPREAD) * (i - (n - 1) / 2.0)
		pending_shots.append(MineShot.create(pos, _dir.rotated(ang) * def.shot_speed, def.damage, &"water"))
	events.append(&"spit")


func _swim(delta: float, level: MineFloor) -> void:
	_swim_t -= delta
	if _swim_t <= 0.0 or pos.distance_to(_swim_to) < 2.0:
		_swim_t = _rng.randf_range(1.5, 3.0)
		_swim_to = home + Vector2(_rng.randf_range(-40.0, 40.0), _rng.randf_range(-20.0, 20.0))
	var d := _swim_to - pos
	if d.length() > 2.0:
		facing = d.normalized()
		_move(facing * def.speed * delta, level)


## 只在水池里游。
func _passable(p: Vector2, level: MineFloor) -> bool:
	if level == null:
		return true
	for c: Vector2 in [Vector2(-4, -4), Vector2(4, -4), Vector2(-4, 4), Vector2(4, 4)]:
		if not level.pools.has(GameMap.tile_of(p + c)):
			return false
	return true
