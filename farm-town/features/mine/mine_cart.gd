class_name MineCart
extends MineMonster
## 第 10 层的首领，废矿车：只走横平竖直的直线。先挪到和人对齐，抖一阵（前摇），然后一头冲过去。
## 冲出去 charge_len 这么远还没撞到东西就自己停下；撞上墙就晕一阵，只有这时候才打得动。
## 所以要背靠着墙站，等它冲过来再滚开。

## 和人差多少像素以内算对齐了
const ALIGN := 4.0
## 对不齐（被挡住、人一直跑）最多磨蹭多久，到点就照现在的方向冲
const ALIGN_TIMEOUT := 2.5

## 这一冲已经冲了多远
var _run := 0.0


func _setup() -> void:
	facing = Vector2.LEFT


func update(delta: float, target: Vector2, level: MineFloor) -> void:
	if state == State.DEAD:
		return
	flash = maxf(0.0, flash - delta)
	t += delta
	var to := target - pos
	match state:
		State.ROAM:
			if to.length() <= def.sight:
				_enter(State.CHASE)
		State.CHASE:
			# 沿着离得远的那个方向冲，先把另一个方向对齐
			var along_x := absf(to.x) >= absf(to.y)
			var off := to.y if along_x else to.x
			if absf(off) <= ALIGN or t >= ALIGN_TIMEOUT:
				_dir = Vector2(signf(to.x), 0.0) if along_x else Vector2(0.0, signf(to.y))
				if _dir == Vector2.ZERO:
					_dir = facing
				facing = _dir
				_enter(State.WINDUP)
			else:
				var step := minf(absf(off), def.speed * delta) * signf(off)
				var before := pos
				_move(Vector2(0.0, step) if along_x else Vector2(step, 0.0), level)
				if pos == before:
					t = ALIGN_TIMEOUT
				if along_x and absf(to.x) > 0.01:
					facing = Vector2(signf(to.x), 0.0)
		State.WINDUP:
			if t >= def.windup:
				_hit_done = false
				_run = 0.0
				_enter(State.STRIKE)
		State.STRIKE:
			var want := def.strike_speed * delta
			var before := pos
			_move(_dir * want, level)
			var moved := pos.distance_to(before)
			_run += moved
			if moved < want * 0.5:
				events.append(&"crash")
				_enter(State.STUNNED)
			elif _run >= def.charge_len:
				_enter(State.REST)
		State.REST:
			if t >= def.rest:
				_enter(State.CHASE)
		State.STUNNED:
			if t >= def.stun:
				_enter(State.CHASE)


## 铁皮车：没晕的时候什么都砍不动，锤也一样。
func take_hit(damage: int, _from_where: Vector2, _knock_speed: float, _breaks: bool = false) -> Dictionary:
	return _armored_hit(damage)


func guarded_from(_from_where: Vector2) -> bool:
	return state != State.STUNNED


func _half() -> float:
	return 7.0
