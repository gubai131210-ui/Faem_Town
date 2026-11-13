class_name MineFloor
extends RefCounted
## 沉灯井的一层：哪里是空地、哪里有石头、梯子在哪。纯数据，不碰节点。
## 每次下来都重新生成，不进存档。

const W := 22
const H := 14
const NONE := Vector2i(-1, -1)
## 空地占里面那一圈的多少
const OPEN_SHARE := 0.5
## 往下的梯子有多大机会压在石头底下
const HIDDEN_LADDER := 0.65
## 矿石比普通石头多敲一下
const ORE_HP := 2
## 敲开矿石多掉一份的机会
const DOUBLE_CHANCE := 0.35
## 忘形离下来的地方至少这么多步，刚下梯子不会被围住
const MONSTER_KEEP_OFF := 5
## 查直线挡不挡的时候隔几个像素看一下
const LINE_STEP := 4.0
## 挤在一起的忘形每秒互相推开多少像素
const PUSH_SPEED := 40.0
const DIRS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
## 遗落层里被忘掉的东西
const PROP_KINDS: Array[StringName] = [&"street_lamp", &"cabinet", &"chair", &"table"]
## 首领房：空地的范围（含），下来的梯子、井灯、往下的梯子各在哪
const ARENA := Rect2i(3, 3, 16, 9)
const ARENA_ENTRY := Vector2i(4, 3)
const ARENA_LAMP := Vector2i(6, 3)
const ARENA_LADDER := Vector2i(17, 3)
## 老鲶的水池（含）和矿车一开始停的地方
const ARENA_POOL := Rect2i(8, 6, 7, 4)
const ARENA_CART := Vector2i(14, 7)
## 岚之影的考验：三段横着的走廊（两格宽）首尾相接，从左上走到右下。每段走廊最上面一排是哪一行
const TRIAL_ROWS: Array[int] = [3, 7, 11]
const TRIAL_X := Vector2i(2, 19)
const TRIAL_ENTRY := Vector2i(2, 3)
const TRIAL_LAMP := Vector2i(5, 3)
const TRIAL_ALTAR := Vector2i(19, 12)
const TRIAL_SHADE := Vector2i(11, 7)
const TRIAL_MOTHS: Array[Vector2i] = [Vector2i(12, 4), Vector2i(7, 8), Vector2i(12, 11)]
const TRIAL_MOTH := &"light_moth"

var floor_no := 1
## 空地（能走的格子）
var open: Dictionary[Vector2i, bool] = {}
## 石头：格子 -> 敲开掉的物品 id
var rocks: Dictionary[Vector2i, StringName] = {}
## 石头还要敲几下
var hp: Dictionary[Vector2i, int] = {}
## 往上的梯子靠着的那一格（挡路），和下来以后站的那一格
var entry := NONE
var spawn := NONE
## 往下的梯子；这一层没有就是 NONE
var ladder := NONE
var ladder_found := false
## 井灯（逢五的层才有）
var lamp := NONE
## 这一层的忘形（倒下的也留在里面，用 alive() 分）
var monsters: Array[MineMonster] = []
## 浅水：能走，走不快
var water: Dictionary[Vector2i, bool] = {}
## 暗河（深水）：过不去，能钓鱼
var pools: Dictionary[Vector2i, bool] = {}
## 被忘掉的东西（街灯、家具）：格子 -> 哪一种。挡路，敲不掉
var props: Dictionary[Vector2i, StringName] = {}
## 正在飞的纸钱、水弹
var shots: Array[MineShot] = []
## 首领房是哪一种（"cart"、"catfish"）；普通的一层是空
var arena: StringName = &""
## 这一层的首领；没有或者早就打倒了是 null
var boss: MineMonster
## 全黑的一层
var dark := false
## 人手里的灯现在照多远（像素），地图每帧写；不黑的层是一个很大的数
var light := 100000.0
## 井底的灯座（岚之影的考验走到这算完）；别的层是 NONE
var altar := NONE
var _rng := RandomNumberGenerator.new()


## extra_monsters：在这一层该有的忘形之外再多放几只（惊蛰）。
static func generate(n: int, layer: MineLayerDef, seed_value: int, with_ladder: bool, with_lamp: bool,
		extra_monsters: int = 0) -> MineFloor:
	var f := MineFloor.new()
	f.floor_no = n
	f._rng.seed = seed_value
	f.dark = layer.dark
	f._carve()
	f._place_entry()
	if with_lamp:
		f._place_lamp()
	if with_ladder:
		f._place_ladder()
	# 下面三样只有写了比例的层段才抽签：浅坑的楼层和原来一个种子一个样
	if layer.pool > 0.0 and f._rng.randf() < layer.pool:
		f._place_pool()
	if layer.props > 0.0:
		f._place_props(layer.props)
	if layer.water > 0.0:
		f._place_water(layer.water)
	f._place_rocks(layer)
	f._place_monsters(layer, extra_monsters)
	return f


## 首领房：一间方方正正的大屋子，没有石头。boss_alive 为假是首领早就打倒了：屋子空着，往下的梯子露着。
static func generate_arena(n: int, layer: MineLayerDef, seed_value: int, with_ladder: bool, boss_alive: bool) -> MineFloor:
	var f := MineFloor.new()
	f.floor_no = n
	f._rng.seed = seed_value
	var def := Database.monster(layer.boss)
	f.arena = def.boss
	f.dark = layer.dark
	if f.arena == &"shade":
		f._lay_trial(def, boss_alive)
		return f
	for x in range(ARENA.position.x, ARENA.end.x):
		for y in range(ARENA.position.y, ARENA.end.y):
			f.open[Vector2i(x, y)] = true
	f.entry = ARENA_ENTRY
	f.spawn = ARENA_ENTRY + Vector2i(0, 1)
	f.lamp = ARENA_LAMP
	if with_ladder:
		f.ladder = ARENA_LADDER
		f.ladder_found = not boss_alive
	var at := tile_center_of(ARENA_CART)
	if f.arena == &"catfish":
		for x in range(ARENA_POOL.position.x, ARENA_POOL.end.x):
			for y in range(ARENA_POOL.position.y, ARENA_POOL.end.y):
				f.pools[Vector2i(x, y)] = true
		at = Vector2(ARENA_POOL.position + ARENA_POOL.end) * GameMap.TS / 2.0
	if boss_alive:
		f.boss = MineMonster.create(def, at, int(f._rng.randi()))
		f.monsters.append(f.boss)
	return f


## 岚之影的考验：一条来回折的长走廊，尽头是灯座。影子在中间飘着，路上有几只噬光蛾。
func _lay_trial(def: MonsterDef, boss_alive: bool) -> void:
	for i in TRIAL_ROWS.size():
		var y0 := TRIAL_ROWS[i]
		for x in range(TRIAL_X.x, TRIAL_X.y + 1):
			open[Vector2i(x, y0)] = true
			open[Vector2i(x, y0 + 1)] = true
		if i + 1 < TRIAL_ROWS.size():
			# 奇数段在右头接下去，偶数段在左头
			var x0 := TRIAL_X.y - 1 if i % 2 == 0 else TRIAL_X.x
			for y in range(y0 + 2, TRIAL_ROWS[i + 1]):
				open[Vector2i(x0, y)] = true
				open[Vector2i(x0 + 1, y)] = true
	entry = TRIAL_ENTRY
	spawn = TRIAL_ENTRY + Vector2i(0, 1)
	lamp = TRIAL_LAMP
	altar = TRIAL_ALTAR
	# 灯座上的灯点着以后，井底就不黑了
	dark = boss_alive
	if not boss_alive:
		return
	boss = MineMonster.create(def, GameMap.tile_center(TRIAL_SHADE), int(_rng.randi()))
	monsters.append(boss)
	var moth := Database.monster(TRIAL_MOTH)
	for t in TRIAL_MOTHS:
		monsters.append(MineMonster.create(moth, GameMap.tile_center(t), int(_rng.randi())))


static func tile_center_of(t: Vector2i) -> Vector2:
	return GameMap.tile_center(t)


func is_open(t: Vector2i) -> bool:
	return open.has(t)


## 这一格是不是敲不掉的障碍（暗河、摆设）。
func solid(t: Vector2i) -> bool:
	return pools.has(t) or props.has(t)


## 首领还在不在。
func boss_alive() -> bool:
	return boss != null and boss.alive()


func has_rock(t: Vector2i) -> bool:
	return rocks.has(t)


## 这一格人能不能站：空地，而且没有石头、梯子、井灯。
func walkable(t: Vector2i) -> bool:
	if not open.has(t) or rocks.has(t) or t == entry or t == lamp or t == altar or pools.has(t) or props.has(t):
		return false
	return not (t == ladder and ladder_found)


## 敲一下 t 上的石头。没有石头返回空；没敲开返回 {"broken": false}；
## 敲开返回 {"broken": true, "item": 掉什么, "count": 几个, "ladder": 底下是不是梯子}。
## power：这一下顶几下；luck：敲开矿石多掉一份的机会。
func hit(t: Vector2i, power: int = 1, luck: float = DOUBLE_CHANCE) -> Dictionary:
	if not rocks.has(t):
		return {}
	hp[t] = int(hp.get(t, 1)) - maxi(1, power)
	if hp[t] > 0:
		return {"broken": false}
	var item := rocks[t]
	var count := 1
	if hp_of(item) > 1 and _rng.randf() < luck:
		count = 2
	rocks.erase(t)
	hp.erase(t)
	var under := t == ladder
	if under:
		ladder_found = true
	return {"broken": true, "item": item, "count": count, "ladder": under}


## 下一下会不会敲开。
func breaks_next(t: Vector2i, power: int = 1) -> bool:
	return rocks.has(t) and int(hp.get(t, 1)) - maxi(1, power) <= 0


## 这种石头要敲几下：普通石头一下，矿石两下。
func hp_of(item: StringName) -> int:
	return 1 if item == &"stone" else ORE_HP


## 从 spawn 出发，不管石头（敲得掉），绕开暗河和摆设（敲不掉），走到每块空地要几步。
func distances() -> Dictionary[Vector2i, int]:
	var dist: Dictionary[Vector2i, int] = {spawn: 0}
	var queue: Array[Vector2i] = [spawn]
	var head := 0
	while head < queue.size():
		var t := queue[head]
		head += 1
		for d in DIRS:
			var n := t + d
			if open.has(n) and not dist.has(n) and not solid(n):
				dist[n] = dist[t] + 1
				queue.append(n)
	return dist


# ---------------------------------------------------------------- 生成

## 从中间开始乱走着挖，挖够一半为止。乱走挖出来的洞一定连成一片。
func _carve() -> void:
	var target := int((W - 2) * (H - 3) * OPEN_SHARE)
	var t := Vector2i(W / 2, H / 2)
	open[t] = true
	var guard := 0
	while open.size() < target and guard < 20000:
		guard += 1
		var n := t + DIRS[_rng.randi() % 4]
		# 四周留一圈墙，最上面留两排（画墙面用）
		if n.x < 1 or n.x > W - 2 or n.y < 2 or n.y > H - 2:
			continue
		t = n
		open[t] = true
		# 偶尔跳回已经挖开的地方，免得挖成一条长虫
		if _rng.randf() < 0.04:
			t = open.keys()[_rng.randi() % open.size()]


## 往上的梯子靠在一面朝南的墙上，人站在它下面那一格。
func _place_entry() -> void:
	var spots: Array[Vector2i] = []
	for t: Vector2i in open:
		if not open.has(t + Vector2i(0, -1)) and open.has(t + Vector2i(0, 1)):
			spots.append(t)
	if spots.is_empty():
		for t: Vector2i in open:
			if open.has(t + Vector2i(0, 1)):
				spots.append(t)
	spots.sort()
	entry = spots[_rng.randi() % spots.size()]
	spawn = entry + Vector2i(0, 1)


## 井灯立在离下来的地方两三步的空地上。
func _place_lamp() -> void:
	var dist := distances()
	var spots: Array[Vector2i] = []
	for t: Vector2i in dist:
		if t != entry and dist[t] >= 2 and dist[t] <= 4:
			spots.append(t)
	spots.sort()
	# 别堵在只有一条路的地方：挑周围空地最多的
	var best := NONE
	var best_n := -1
	for t in spots:
		var n := 0
		for d in DIRS:
			if open.has(t + d):
				n += 1
		if n > best_n:
			best_n = n
			best = t
	lamp = best


## 往下的梯子放在离下来的地方最远的那一批空地里。
func _place_ladder() -> void:
	var dist := distances()
	var far := 0
	for t: Vector2i in dist:
		far = maxi(far, dist[t])
	var spots: Array[Vector2i] = []
	for t: Vector2i in dist:
		if t != entry and t != spawn and t != lamp and dist[t] >= int(far * 0.7) and dist[t] >= 3:
			spots.append(t)
	if spots.is_empty():
		return
	spots.sort()
	ladder = spots[_rng.randi() % spots.size()]
	ladder_found = _rng.randf() >= HIDDEN_LADDER


func _place_rocks(layer: MineLayerDef) -> void:
	var tiles: Array[Vector2i] = []
	for t: Vector2i in open:
		tiles.append(t)
	tiles.sort()
	for t in tiles:
		if t == entry or t == spawn or t == lamp or absi(t.x - spawn.x) + absi(t.y - spawn.y) <= 1:
			continue
		if water.has(t) or solid(t):
			continue
		if t == ladder:
			if not ladder_found:
				_add_rock(t, layer.pick(_rng.randf()))
			continue
		if _rng.randf() < layer.rock:
			_add_rock(t, layer.pick(_rng.randf()))


## 忘形放在离下来的地方够远的空地上，一格最多一只。
func _place_monsters(layer: MineLayerDef, extra: int) -> void:
	var want := layer.monster_count(floor_no, _rng.randf())
	if want > 0 or not layer.monsters.is_empty():
		want += maxi(0, extra)
	if want <= 0:
		return
	var dist := distances()
	var spots: Array[Vector2i] = []
	for t: Vector2i in dist:
		if dist[t] >= MONSTER_KEEP_OFF and walkable(t) and t != ladder:
			spots.append(t)
	spots.sort()
	for i in want:
		if spots.is_empty():
			return
		var id := layer.pick_monster(floor_no, _rng.randf())
		if id == &"":
			return
		var at := _rng.randi() % spots.size()
		var t := spots[at]
		spots.remove_at(at)
		var def := Database.monster(id)
		monsters.append(MineMonster.create(def, GameMap.tile_center(t), int(_rng.randi())))
		# 成对出现的：同伴放在旁边最近的空位上
		for k in def.pack - 1:
			var near := -1
			for j in spots.size():
				var gap := absi(spots[j].x - t.x) + absi(spots[j].y - t.y)
				if gap <= 3 and (near < 0 or gap < absi(spots[near].x - t.x) + absi(spots[near].y - t.y)):
					near = j
			if near < 0:
				break
			monsters.append(MineMonster.create(def, GameMap.tile_center(spots[near]), int(_rng.randi())))
			spots.remove_at(near)


## 这一格能不能改成暗河或者摆上东西：是空地，不是梯子、井灯、下来的地方和它身边。
func _free_for_solid(t: Vector2i) -> bool:
	if not open.has(t) or solid(t) or t == entry or t == spawn or t == lamp or t == ladder:
		return false
	return absi(t.x - spawn.x) + absi(t.y - spawn.y) > 1


## 剩下的空地是不是还连成一片（暗河和摆设敲不掉，不能把路堵死）。
func _connected() -> bool:
	return distances().size() == open.size() - pools.size() - props.size()


## 一段暗河：离下来的地方远一点，四到七格连在一起；会把路堵死就换个地方。
func _place_pool() -> void:
	var dist := distances()
	var spots: Array[Vector2i] = []
	for t: Vector2i in dist:
		if dist[t] >= 4 and _free_for_solid(t):
			spots.append(t)
	spots.sort()
	for attempt in 6:
		if spots.is_empty():
			return
		var blob: Array[Vector2i] = [spots[_rng.randi() % spots.size()]]
		var want := 4 + _rng.randi() % 4
		for i in 40:
			if blob.size() >= want:
				break
			var n := blob[_rng.randi() % blob.size()] + DIRS[_rng.randi() % 4]
			if _free_for_solid(n) and not blob.has(n):
				blob.append(n)
		for t in blob:
			pools[t] = true
		if blob.size() >= 3 and _connected():
			return
		for t in blob:
			pools.erase(t)


## 被忘掉的东西：一格一件，不堵路。
func _place_props(share: float) -> void:
	var tiles: Array[Vector2i] = []
	for t: Vector2i in open:
		tiles.append(t)
	tiles.sort()
	var want := int(open.size() * share)
	for i in want * 4:
		if props.size() >= want:
			return
		var t := tiles[_rng.randi() % tiles.size()]
		var kind := PROP_KINDS[_rng.randi() % PROP_KINDS.size()]
		if not _free_for_solid(t):
			continue
		props[t] = kind
		if not _connected():
			props.erase(t)


## 浅水：一小片一小片的，暗河边上也渗出来一些。
func _place_water(share: float) -> void:
	var tiles: Array[Vector2i] = []
	for t: Vector2i in open:
		tiles.append(t)
	tiles.sort()
	var want := int(open.size() * share)
	for t in tiles:
		if not pools.has(t):
			continue
		for d in DIRS:
			if _wettable(t + d) and _rng.randf() < 0.5:
				water[t + d] = true
	for i in 60:
		if water.size() >= want:
			return
		var t := tiles[_rng.randi() % tiles.size()]
		for k in 5:
			if _wettable(t):
				water[t] = true
			t += DIRS[_rng.randi() % 4]


func _wettable(t: Vector2i) -> bool:
	return open.has(t) and not solid(t) and t != entry and t != spawn and t != lamp and t != ladder


## 从 from 走到 to（都是格子），下一步该踩哪一格。只走能站的格子；to 自己不管能不能站都算走得到。
## 已经在同一格返回 from；走不通返回 NONE。
func next_step(from: Vector2i, to: Vector2i) -> Vector2i:
	if from == to:
		return from
	# 从终点往回找：最先碰到 from 的那一格就在最短的路上
	var seen: Dictionary[Vector2i, bool] = {to: true}
	var queue: Array[Vector2i] = [to]
	var head := 0
	while head < queue.size():
		var t := queue[head]
		head += 1
		for d in DIRS:
			var n := t + d
			if n == from:
				return t
			if seen.has(n) or not walkable(n):
				continue
			seen[n] = true
			queue.append(n)
	return NONE


## 从 a 到 b（像素）走直线会不会被挡住。half 是身子的半宽；最后 stop_short 这一截不查
## （人贴着石头站的时候，人脚下那一点对忘形来说算在石头里）。
func clear_line(a: Vector2, b: Vector2, half: float = 3.0, stop_short: float = 6.0) -> bool:
	var length := a.distance_to(b) - stop_short
	if length <= 0.0:
		return true
	var dir := a.direction_to(b)
	var steps := ceili(length / LINE_STEP)
	for i in range(1, steps + 1):
		var p := a + dir * minf(length, i * LINE_STEP)
		for c: Vector2 in [Vector2(-half, -half), Vector2(half, -half), Vector2(-half, half), Vector2(half, half)]:
			if not walkable(GameMap.tile_of(p + c)):
				return false
	return true


## 挤在一起的忘形互相推开一点。会飞的和地上的互不相干。
func separate(delta: float) -> void:
	for i in monsters.size():
		var a := monsters[i]
		if not a.alive():
			continue
		for j in range(i + 1, monsters.size()):
			var b := monsters[j]
			if not b.alive() or a.def.flying != b.def.flying:
				continue
			var want := float(a.def.radius + b.def.radius)
			var gap := a.pos.distance_to(b.pos)
			if gap >= want:
				continue
			var away := (b.pos - a.pos) / gap if gap > 0.01 else Vector2.RIGHT
			var push := minf(want - gap, PUSH_SPEED * delta) * 0.5
			a.nudge(-away * push, self)
			b.nudge(away * push, self)


## 飞着的纸钱、水弹往前走 delta 秒，没了的清掉。
func step_shots(delta: float) -> void:
	for s in shots:
		s.update(delta, self)
	for i in range(shots.size() - 1, -1, -1):
		if not shots[i].alive:
			shots.remove_at(i)


## 还活着的忘形有几只。
func monsters_left() -> int:
	var n := 0
	for m in monsters:
		if m.alive():
			n += 1
	return n


func _add_rock(t: Vector2i, item: StringName) -> void:
	rocks[t] = item
	hp[t] = hp_of(item)
