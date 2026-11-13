class_name MineShade
extends MineMonster
## 第 40 层的岚之影：不是敌人，打不着也不伤人。它飘在人附近，隔一阵朝人吹一排风，
## 被风吹到的灯会掉一大截油。考验是护着灯走到走廊尽头的灯座（MineFloor.altar）；
## 灯灭了就从头再走（Mine.restart_trial）。走到了它就散了（Mine.finish_trial）。

## 飘到离人这么近就不再靠近
const KEEP := 64.0
## 隔多久吹一回
const ATTACK_EVERY := 2.6
## 一排三口风，相邻两口差多少度
const GUSTS := 3
const SPREAD := 20.0

var _attack_t := 2.0


func update(delta: float, target: Vector2, level: MineFloor) -> void:
	if state == State.DEAD:
		return
	flash = maxf(0.0, flash - delta)
	t += delta
	var to := target - pos
	var dist := to.length()
	match state:
		State.ROAM, State.CHASE:
			if dist > KEEP:
				facing = to / dist
				_move(facing * def.speed * delta, level)
			_attack_t -= delta
			if _attack_t <= 0.0 and dist <= def.sight:
				_enter(State.WINDUP)
		State.WINDUP:
			# 吸气的时候跟着人转，吹出去那一下才定方向
			if dist > 0.01:
				_dir = to / dist
				facing = _dir
			if t >= def.windup:
				_blow()
				_enter(State.STRIKE)
		State.STRIKE:
			if t >= def.strike_time:
				_enter(State.REST)
		_:
			if t >= def.rest:
				_attack_t = ATTACK_EVERY
				_enter(State.ROAM)


## 打不着。
func take_hit(_damage: int, _from_where: Vector2, _knock_speed: float, _breaks: bool = false) -> Dictionary:
	flash = 0.1
	return {"blocked": true, "damage": 0, "dead": state == State.DEAD}


func guarded_from(_from_where: Vector2) -> bool:
	return true


## 不伤人。
func strikes(_target: Vector2, _target_radius: float = 5.0) -> bool:
	return false


func _blow() -> void:
	for i in GUSTS:
		var ang := deg_to_rad(SPREAD) * (i - (GUSTS - 1) / 2.0)
		var shot := MineShot.create(pos, _dir.rotated(ang) * def.shot_speed, 0, &"gust")
		shot.snuff = def.eat_light
		pending_shots.append(shot)
	events.append(&"blow")


## 它是飘着的：只要是挖开的地方都过得去，不管石头和灯。
func _passable(p: Vector2, level: MineFloor) -> bool:
	if level == null:
		return true
	for c: Vector2 in [Vector2(-4, -4), Vector2(4, -4), Vector2(-4, 4), Vector2(4, 4)]:
		if not level.is_open(GameMap.tile_of(p + c)):
			return false
	return true
