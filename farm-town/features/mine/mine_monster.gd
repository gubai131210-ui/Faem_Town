class_name MineMonster
extends RefCounted
## 井里的一只忘形：在哪、还剩多少生命、正在干什么。纯数据，不碰节点；画它的是地图上的 MonsterView。
## 所有忘形走同一套步骤：闲逛 → 追 → 前摇 → 出招 → 歇一下，差别都在 MonsterDef 的数字里。
## 首领各有各的打法，写在继承它的 MineCart、MineCatfish 里。

## HIDDEN 装成石头；WAKING 正在起身；STUNNED 被锤砸晕（这时候没有防御）
enum State { HIDDEN, WAKING, ROAM, CHASE, WINDUP, STRIKE, REST, STUNNED, DEAD }

## 起身要多久
const WAKE_TIME := 0.5
## 被锤砸晕多久
const STUN_TIME := 1.4
## 挨了一下僵住多久
const STAGGER_TIME := 0.2
## 追丢的距离是看见的距离的几倍
const LOSE_SIGHT := 1.6
## 有防御的忘形转身多快（弧度每秒）：慢，才绕得到背后
const TURN_RATE := 2.2
## 挨打被推开的速度每秒掉多少
const KNOCK_FRICTION := 320.0
## 对方在正面多大的范围里算“从正面打”（和朝向的夹角的余弦）
const GUARD_COS := 0.2
## 绕路的时候隔多久重新找一次路（人在动）
const REROUTE := 0.35
## 远程的忘形被人贴上来以后最多往后退多久，退不开也照样出手
const RETREAT_TIME := 1.2
const BOSS_KINDS: Array[StringName] = [&"cart", &"catfish", &"troupe", &"shade"]
const BOSS_SCRIPTS: Dictionary[StringName, String] = {
	&"cart": "res://features/mine/mine_cart.gd",
	&"catfish": "res://features/mine/mine_catfish.gd",
	&"troupe": "res://features/mine/mine_troupe.gd",
	&"shade": "res://features/mine/mine_shade.gd",
}

var def: MonsterDef
var pos := Vector2.ZERO
var hp := 1
var state := State.ROAM
## 朝哪边（单位向量）
var facing := Vector2.DOWN
## 在现在这个状态里待了多久
var t := 0.0
## 刚挨了打，还要亮多久（给画面用）
var flash := 0.0
## 这一小会儿里出过的事，地图拿去放声音和特效，拿完清空：
## &"land" 跳起来落地、&"crash" 矿车撞墙、&"spit" 吐水、&"ashore" 被拉上岸、&"dive" 跳回水里
var events: Array[StringName] = []
## 刚扔出去、还没交给楼层的东西
var pending_shots: Array[MineShot] = []
var _landed := false
var _from := Vector2.ZERO
var _land := Vector2.ZERO
var _retreat := RETREAT_TIME
## 影子：人走过的地方（和各是什么时候走的），照着这个走
var _trail: Array[Vector2] = []
var _trail_t: Array[float] = []
var _clock := 0.0
var _touch_cd := 0.0
var _stagger := 0.0
var _knock := Vector2.ZERO
var _dir := Vector2.DOWN
var _hit_done := false
var _roam_to := Vector2.ZERO
var _roam_t := 0.0
## 绕路的时候正往哪一点走，还有多久重新找一次路
var _step_to := Vector2.ZERO
var _route_t := 0.0
var _rng := RandomNumberGenerator.new()


static func create(monster_def: MonsterDef, at: Vector2, seed_value: int) -> MineMonster:
	var m: MineMonster
	if BOSS_SCRIPTS.has(monster_def.boss):
		var script: GDScript = load(BOSS_SCRIPTS[monster_def.boss])
		m = script.new()
	else:
		m = MineMonster.new()
	m.def = monster_def
	m.pos = at
	m.hp = monster_def.hp
	m.state = State.HIDDEN if monster_def.hidden else State.ROAM
	m._roam_to = at
	m._rng.seed = seed_value
	m._setup()
	return m


## 刚造出来的时候各自再准备一下（首领用）。
func _setup() -> void:
	pass


## 同一只忘形有几副样子的时候，现在是哪一副（戏班的三张面具）；只有一副是空。
func skin() -> StringName:
	return &""


func is_boss() -> bool:
	return def.boss != &""


## 正跳在半空的话，跳到了这一跳的哪里（0 起跳，1 落地）；不在跳是 -1。
func air() -> float:
	if not def.leap or state != State.STRIKE:
		return -1.0
	return clampf(t / maxf(0.01, def.strike_time), 0.0, 1.0)


func alive() -> bool:
	return state != State.DEAD


## 过 delta 秒。target 是人站的地方，level 是这一层（看哪里能走）。
func update(delta: float, target: Vector2, level: MineFloor) -> void:
	if state == State.DEAD:
		return
	flash = maxf(0.0, flash - delta)
	_landed = false
	if _knock.length() > 1.0:
		_move(_knock * delta, level)
		_knock = _knock.move_toward(Vector2.ZERO, KNOCK_FRICTION * delta)
	if _stagger > 0.0:
		_stagger -= delta
		return
	t += delta
	var to := target - pos
	var dist := to.length()
	if def.echo > 0.0 and (state == State.ROAM or state == State.CHASE):
		_echo(delta, target, dist, level)
		return
	if def.shy and state == State.CHASE and level != null and dist <= level.light:
		# 被灯照着：停住不动
		_face(to, 100.0)
		return
	match state:
		State.HIDDEN:
			if dist <= def.wake:
				_enter(State.WAKING)
		State.WAKING:
			if t >= WAKE_TIME:
				_face(to, 100.0)
				_enter(State.CHASE)
		State.ROAM:
			if dist <= def.sight:
				_enter(State.CHASE)
			else:
				_roam(delta, level)
		State.CHASE:
			if dist > def.sight * LOSE_SIGHT:
				_enter(State.ROAM)
			elif def.keep_away > 0.0 and dist < def.keep_away and _retreat > 0.0 and dist > 0.01:
				# 远程的：人贴上来先往后退一退
				_retreat -= delta
				_face(to, 100.0)
				_move(-to / dist * _pace(level) * delta, level)
			elif dist <= def.reach and (def.leap or _straight(target, level)):
				# 出招的方向在前摇开始的时候就定下来：看见它抬手再躲来得及
				_dir = to.normalized() if dist > 0.01 else facing
				facing = _dir
				if def.leap:
					_aim_leap(target, level)
				_enter(State.WINDUP)
			else:
				# 伞那样撑开才有防御的转身快，绕不到背后，要等它收伞
				_face(to, TURN_RATE * delta if def.guard and not def.guard_open else 100.0)
				var go := _heading(delta, target, level)
				if go.length() > 0.01:
					_move(go.normalized() * _pace(level) * delta, level)
		State.WINDUP:
			if t >= def.windup:
				_hit_done = false
				_from = pos
				if def.shot_speed > 0.0:
					pending_shots.append(MineShot.create(pos, _dir * def.shot_speed, def.damage, &"paper"))
				_enter(State.STRIKE)
		State.STRIKE:
			if def.leap:
				# 跳起来：不管地上有什么，落到前摇时看准的那一点
				pos = _from.lerp(_land, clampf(t / maxf(0.01, def.strike_time), 0.0, 1.0))
				if t >= def.strike_time:
					_landed = true
					events.append(&"land")
					_enter(State.REST)
			else:
				if def.shot_speed <= 0.0:
					_move(_dir * def.strike_speed * delta, level)
				if t >= def.strike_time:
					_enter(State.REST)
		State.REST:
			if t >= def.rest:
				_retreat = RETREAT_TIME
				_enter(State.CHASE)
		State.STUNNED:
			if t >= STUN_TIME:
				_enter(State.CHASE)


## 这一刻撞没撞到站在 target 的人。一次出招只算一下。
func strikes(target: Vector2, target_radius: float = 5.0) -> bool:
	if def.leap:
		# 跳的：只有落地那一下，周围一圈都算
		if not _landed or _hit_done or pos.distance_to(target) > def.blast + target_radius:
			return false
		_hit_done = true
		return true
	if def.shot_speed > 0.0:
		return false
	if def.echo > 0.0:
		# 影子没有招式，碰到就算；碰过一下歇一会儿
		if state != State.CHASE or _touch_cd > 0.0 or pos.distance_to(target) > def.radius + target_radius:
			return false
		_touch_cd = def.rest
		return true
	if state != State.STRIKE or _hit_done:
		return false
	if pos.distance_to(target) > def.radius + target_radius:
		return false
	_hit_done = true
	return true


## 从 from 那边打过来的这一下会不会被挡住。
func guarded_from(from: Vector2) -> bool:
	if not def.guard or state == State.STUNNED:
		return false
	# 伞：出招和歇着的时候是收起来的
	if def.guard_open and (state == State.STRIKE or state == State.REST):
		return false
	# 装成石头的时候整个缩在壳里
	if state == State.HIDDEN or state == State.WAKING:
		return true
	var to := from - pos
	if to.length() < 0.01:
		return false
	return facing.dot(to.normalized()) > GUARD_COS


## 挨一下。返回 {"blocked": 挡住了没有, "damage": 实际扣了多少, "dead": 倒了没有}。
## breaks 为真是锤那样的重击：不管正面背面都打得进去，还把它砸晕。
func take_hit(damage: int, from: Vector2, knock: float, breaks: bool = false) -> Dictionary:
	if state == State.DEAD:
		return {"blocked": false, "damage": 0, "dead": true}
	var blocked := guarded_from(from) and not breaks
	if state == State.HIDDEN:
		# 敲到装石头的：把它吵醒
		_enter(State.WAKING)
	if blocked:
		flash = 0.1
		return {"blocked": true, "damage": 0, "dead": false}
	var dealt := mini(hp, maxi(1, damage))
	hp -= dealt
	flash = 0.18
	var away := pos - from
	_knock = (away.normalized() if away.length() > 0.01 else Vector2.DOWN) * knock
	if hp <= 0:
		_enter(State.DEAD)
		return {"blocked": false, "damage": dealt, "dead": true}
	if breaks:
		_enter(State.STUNNED)
	else:
		_stagger = STAGGER_TIME
	return {"blocked": false, "damage": dealt, "dead": false}


## 被别的忘形挤了一下。装石头的不动，正在出招的不让路。
func nudge(d: Vector2, level: MineFloor) -> void:
	if state == State.HIDDEN or state == State.WAKING or state == State.STRIKE or state == State.DEAD or is_boss():
		return
	_move(d, level)


## 影子：看见人以后，一直照着人 echo 秒以前站的地方走。人站着不动，它就走到人身上来。
func _echo(delta: float, target: Vector2, dist: float, level: MineFloor) -> void:
	_touch_cd = maxf(0.0, _touch_cd - delta)
	if state == State.ROAM:
		if dist <= def.sight:
			_trail.clear()
			_trail_t.clear()
			_enter(State.CHASE)
		else:
			_roam(delta, level)
		return
	_clock += delta
	_trail.append(target)
	_trail_t.append(_clock)
	var due := _clock - def.echo
	while _trail_t.size() > 1 and _trail_t[1] <= due:
		_trail.pop_front()
		_trail_t.pop_front()
	if _trail_t[0] > due:
		return
	var d := _trail[0] - pos
	if d.length() > 0.5:
		facing = d.normalized()
		_move(d.limit_length(def.speed * delta), level)


## 现在挪多快：水蛭那样的在水里快得多。
func _pace(level: MineFloor) -> float:
	if def.swim > 0.0 and level != null and level.water.has(GameMap.tile_of(pos)):
		return def.speed * def.swim
	return def.speed


## 起跳前看准落在哪：朝人那边最多跳 reach 这么远；落点站不住就往回收一点。
func _aim_leap(target: Vector2, level: MineFloor) -> void:
	var aim := pos + (target - pos).limit_length(def.reach)
	_land = pos
	for i in 9:
		var p := aim.lerp(pos, i / 8.0)
		if _passable(p, level):
			_land = p
			return


func _enter(next: State) -> void:
	state = next
	t = 0.0


## 朝 target 走直线过得去吗。会飞的不管石头。
func _straight(target: Vector2, level: MineFloor) -> bool:
	return level == null or def.flying or level.clear_line(pos, target)


## 追人的时候这一步往哪边走：直线过得去就直奔过去，过不去就顺着绕开石头的路一格一格走。
func _heading(delta: float, target: Vector2, level: MineFloor) -> Vector2:
	if _straight(target, level):
		_route_t = 0.0
		return target - pos
	_route_t -= delta
	if _route_t <= 0.0 or pos.distance_to(_step_to) < 2.0:
		_route_t = REROUTE
		var next := level.next_step(GameMap.tile_of(pos), GameMap.tile_of(target))
		# 四面都堵死了：照旧朝人那边挤
		_step_to = target if next == MineFloor.NONE or next == GameMap.tile_of(pos) else GameMap.tile_center(next)
	return _step_to - pos


## 朝 to 那边转，最多转 max_turn 弧度。
func _face(to: Vector2, max_turn: float) -> void:
	if to.length() < 0.01:
		return
	var want := to.angle()
	var now := facing.angle()
	var diff := wrapf(want - now, -PI, PI)
	facing = Vector2.from_angle(now + clampf(diff, -max_turn, max_turn))


func _roam(delta: float, level: MineFloor) -> void:
	_roam_t -= delta
	if _roam_t <= 0.0 or pos.distance_to(_roam_to) < 2.0:
		_roam_t = _rng.randf_range(1.2, 3.0)
		# 一半的时候站着不动
		if _rng.randf() < 0.5:
			_roam_to = pos
		else:
			_roam_to = pos + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(10.0, 28.0)
	var to := _roam_to - pos
	if to.length() < 2.0:
		return
	facing = to.normalized()
	var before := pos
	_move(facing * _pace(level) * 0.5 * delta, level)
	if pos.distance_to(before) < 0.001:
		_roam_to = pos


## 两个轴分开挪，贴着墙能滑过去。
func _move(d: Vector2, level: MineFloor) -> void:
	var nx := Vector2(pos.x + d.x, pos.y)
	if _passable(nx, level):
		pos = nx
	var ny := Vector2(pos.x, pos.y + d.y)
	if _passable(ny, level):
		pos = ny


func _passable(p: Vector2, level: MineFloor) -> bool:
	if level == null:
		return true
	var h := _half()
	for c: Vector2 in [Vector2(-h, -h), Vector2(h, -h), Vector2(-h, h), Vector2(h, h)]:
		var tile := GameMap.tile_of(p + c)
		if def.flying:
			if not level.is_open(tile):
				return false
		elif not level.walkable(tile):
			return false
	return true


## 身子占地的半宽（看能不能过用）。
func _half() -> float:
	return 3.0


## 首领那样平时打不动、晕了才打得动的挨一下：不被推开。
func _armored_hit(damage: int) -> Dictionary:
	if state == State.DEAD:
		return {"blocked": false, "damage": 0, "dead": true}
	if state != State.STUNNED:
		flash = 0.1
		return {"blocked": true, "damage": 0, "dead": false}
	var dealt := mini(hp, maxi(1, damage))
	hp -= dealt
	flash = 0.18
	if hp <= 0:
		_enter(State.DEAD)
		return {"blocked": false, "damage": dealt, "dead": true}
	return {"blocked": false, "damage": dealt, "dead": false}
