extends Node
## 沉灯井：下到过第几层、点亮了哪几层的井灯、打倒了哪几层的首领、现在在第几层、这一层长什么样。
## 手里那盏灯还有多少油、身上戴着哪两件饰品也记在这（都进存档）。
## 楼层每次下来重新生成（MineFloor），不进存档；存的只有最深到过哪、亮着的井灯、倒下的首领和还没拿走的首领掉落。

signal changed

## 井一共多少层
const OPEN_FLOORS := 40
## 手里的灯：油最多这么多；在全黑的层里每秒烧掉多少；从地面下来时井口给添到多少
const OIL_MAX := 100.0
const OIL_DRAIN := 0.3
const ENTRY_OIL := 40.0
## 能往灯里添的东西：添一份加多少油
const FUELS: Dictionary[StringName, float] = {&"lamp_oil": 60.0, &"cooking_oil": 25.0}
## 灯照多远（像素）：油满的时候和快没油的时候。油烧光了是 0（什么都照不见）
const LIGHT_MAX := 78.0
const LIGHT_MIN := 24.0
## 灯被吃掉、吹掉一口以后，这么多秒里不会再掉
const SNUFF_GAP := 0.6
## 身上能戴几件饰品
const SLOTS := 2
## 每隔几层有一盏井灯
const LAMP_EVERY := 5
const PICKAXE := &"pickaxe"
## 头一回到井口，从门边拿到镐子
const PICKAXE_FLAG := &"got_pickaxe"
## 金镐敲开矿石多掉一份的机会
const GOLD_PICK_LUCK := 0.6
## 镐子旁边还挂着一把旧镰刀：下井前拿上
const FIRST_WEAPON := &"old_sickle"
const WEAPON_FLAG := &"got_sickle"
## 第四幕：遗落层的井灯底下压着一只铁盒，里面是名单和全家福；拿过就记这个标记
const BOX_FLOOR := 25
const BOX_RELICS: Array[StringName] = [&"miner_roster", &"family_photo"]
const BOX_FLAG := &"act4_box"
## 第五幕：第 30 层往下的梯子被雾封着，山祠灯亮了才下得去（无光层）。
## 这条规矩做出来以前就下去过的旧存档不拦。
const DEEP_GATE := 30
const DEEP_FLAG := &"lamp_shrine"
## 晕倒以后这一趟得来的东西丢掉多少
const FAINT_LOSS := 0.5
## 惊蛰那几天：每层多一只忘形，掉东西的机会乘这么多
const JINGZHE := &"jingzhe"
const JINGZHE_DROPS := 1.5

## 最深到过第几层
var deepest := 0
## 点亮了井灯的层
var lit: Array[int] = []
## 首领已经打倒了的层
var bosses: Array[int] = []
## 首领掉的东西当时背包放不下，先记在这，下回进井再给
var owed: Array[StringName] = []
## 灯里的油
var oil := 0.0
## 戴着的饰品（最多 SLOTS 件）
var equipped: Array[StringName] = []
var _snuff_cd := 0.0
## 现在在第几层；不在井里是 0
var floor_no := 0
var current: MineFloor
## 这一趟（从地面下来到回地面）得来的东西：物品 id -> 个数。晕倒丢的就是这里面的
var haul: Dictionary[StringName, int] = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	SaveSystem.register(&"mine", self)
	GameClock.register_daily(GameClock.ORDER_MACHINES + 5, _on_new_day)


## 下到第 n 层（重新生成一层）。到不了返回假。
func enter(n: int, seed_value: int = -1) -> bool:
	if n < 1 or n > OPEN_FLOORS:
		return false
	var layer := Database.mine_layer(n)
	if layer == null:
		return false
	if seed_value < 0:
		seed_value = int(_rng.randi())
	if floor_no == 0:
		haul.clear()
		# 从地面下来：井口的油壶给添一点底油
		oil = maxf(oil, ENTRY_OIL)
	floor_no = n
	if has_boss_room(n):
		current = MineFloor.generate_arena(n, layer, seed_value, n < OPEN_FLOORS, not bosses.has(n))
	else:
		var extra := 1 if GameClock.term_id() == JINGZHE else 0
		current = MineFloor.generate(n, layer, seed_value, n < OPEN_FLOORS, n % LAMP_EVERY == 0, extra)
	if trial_running():
		# 岚之影的考验：进来的时候灯是满的，中途添不了油
		oil = OIL_MAX
	if n > deepest:
		deepest = n
		changed.emit()
	return true


## 第 n 层是不是首领房（每一段最深的那层，表里写了首领的）。
func has_boss_room(n: int) -> bool:
	var layer := Database.mine_layer(n)
	return layer != null and layer.boss != &"" and n == layer.to


## 顺着梯子再下一层。
func descend() -> bool:
	if current == null or not current.ladder_found or ladder_fogged():
		return false
	return enter(floor_no + 1)


## 无光层还下不下得去：山祠灯没亮、以前也没下去过，就是封着的。
func deep_closed() -> bool:
	return deepest <= DEEP_GATE and not GameState.has_flag(DEEP_FLAG)


## 现在站的这一层，往下的梯子是不是被雾封着。
func ladder_fogged() -> bool:
	return floor_no == DEEP_GATE and deep_closed()


## 回到地面。
func leave() -> void:
	floor_no = 0
	current = null
	haul.clear()


## 升降机能到的最深一层：亮着井灯的最深那层；一盏都没亮是 0。
func lift_floor() -> int:
	var best := 0
	for n in lit:
		best = maxi(best, n)
	return best


func lamp_lit(n: int) -> bool:
	return lit.has(n)


## 点亮这一层的井灯。这一层没有灯或者已经亮了返回假。
func light_lamp() -> bool:
	if current == null or current.lamp == MineFloor.NONE or lit.has(floor_no):
		return false
	lit.append(floor_no)
	changed.emit()
	return true


## 第四幕：遗落层那盏井灯（第 25 层）点亮以后，灯座底下的铁盒还在不在。
func box_waiting() -> bool:
	return floor_no == BOX_FLOOR and lit.has(BOX_FLOOR) and not GameState.has_flag(BOX_FLAG)


## 拿走铁盒里的名单和全家福。背包放不下两样就不拿，返回假。
func take_box() -> bool:
	if not box_waiting():
		return false
	var free := 0
	for i in GameState.inventory.size:
		if GameState.inventory.is_empty_slot(i):
			free += 1
	if free < BOX_RELICS.size():
		return false
	for id in BOX_RELICS:
		GameState.inventory.add(id, 1)
		GameState.set_flag(StringName("relic_" + String(id)))
	GameState.set_flag(BOX_FLAG)
	return true


## 拿镐子敲一下 tile 上的石头，敲开的东西直接进背包。
## 返回 MineFloor.hit 的结果；背包放不下时不敲开，返回 {"full": true}。
func strike(tile: Vector2i) -> Dictionary:
	if current == null or not current.has_rock(tile):
		return {}
	var item := current.rocks[tile]
	var power := pick_power()
	if current.breaks_next(tile, power) and not GameState.inventory.can_add(item, 2):
		return {"full": true}
	var res := current.hit(tile, power, pick_luck())
	if bool(res.get("broken", false)):
		_gain(item, int(res["count"]))
	return res


## 镐子一下顶几下：铁镐起带矿的石头也一下敲开。
func pick_power() -> int:
	return 2 if GameState.tool_level(PICKAXE) >= 1 else 1


## 每一镐花多少体力：银镐起只花 1 点。
func pick_cost(base: int) -> int:
	return mini(base, 1) if GameState.tool_level(PICKAXE) >= 2 else base


## 敲开矿石多掉一份的机会：金镐更大。
func pick_luck() -> float:
	return GOLD_PICK_LUCK if GameState.tool_level(PICKAXE) >= 3 else MineFloor.DOUBLE_CHANCE


## 打倒了一只忘形：按它的表掉东西，直接进背包（放不下的那样就不掉）。返回掉了什么：物品 id 的列表。
## 它要是什么东西变的，还有机会掉出原来的样子（遗物，每件只掉一回）。
## 首领：记下这一层打过了，往下的梯子露出来；它掉的东西背包放不下就先欠着（owed），不会丢。
func defeat(monster: MineMonster) -> Array[StringName]:
	var got: Array[StringName] = []
	if monster == null:
		return got
	var def := monster.def
	var mult := JINGZHE_DROPS if GameClock.term_id() == JINGZHE else 1.0
	for drop in def.drops:
		var item: StringName = drop["item"]
		if _rng.randf() >= float(drop["chance"]) * mult:
			continue
		if GameState.inventory.can_add(item, 1):
			_gain(item, 1)
			got.append(item)
		elif def.boss != &"":
			owed.append(item)
	var relic := roll_relic(def, _rng.randf())
	var heal := int(bonus(&"lifesteal"))
	if heal > 0 and GameState.health > 0:
		GameState.health += heal
	if relic != &"":
		GameState.inventory.add(relic, 1)
		GameState.set_flag(StringName("relic_" + String(relic)))
		got.append(relic)
	if def.boss != &"":
		if floor_no > 0 and not bosses.has(floor_no):
			bosses.append(floor_no)
		if def.flag != &"":
			GameState.set_flag(def.flag)
		if current != null and current.ladder != MineFloor.NONE:
			current.ladder_found = true
		changed.emit()
	return got


## 这只忘形这回掉不掉遗物：掉的话返回是哪件。已经得到过的、背包放不下的不掉。
func roll_relic(def: MonsterDef, roll: float) -> StringName:
	if def.relic == &"" or GameState.has_flag(StringName("relic_" + String(def.relic))):
		return &""
	var chance := def.relic_chance
	var layer := Database.mine_layer(floor_no)
	if layer != null:
		chance *= layer.relic_bonus
	if GameClock.term_id() == JINGZHE:
		chance *= JINGZHE_DROPS
	if roll >= chance or not GameState.inventory.can_add(def.relic, 1):
		return &""
	return def.relic


# ---------------------------------------------------------------- 灯

## 这一层是不是岚之影的考验，而且还没走完。
func trial_running() -> bool:
	return current != null and current.arena == &"shade" and current.boss_alive()


## 在井里过了 delta 秒：全黑的层里灯油往下掉。
func burn(delta: float) -> void:
	_snuff_cd = maxf(0.0, _snuff_cd - delta)
	if current == null or not current.dark or oil <= 0.0:
		return
	oil = maxf(0.0, oil - OIL_DRAIN * (1.0 - clampf(bonus(&"oil_saver"), 0.0, 0.9)) * delta)


## 灯被吃掉、吹掉 amount 这么多油。刚掉过一口的那一小会儿不算，返回假。
func snuff(amount: float) -> bool:
	if amount <= 0.0 or _snuff_cd > 0.0 or oil <= 0.0:
		return false
	_snuff_cd = SNUFF_GAP
	oil = maxf(0.0, oil - amount)
	return true


## 往灯里添一份 item。不是油、灯是满的、考验当中、背包里没有，都添不了，返回假。
func refuel(item: StringName) -> bool:
	if not FUELS.has(item) or oil >= OIL_MAX - 1.0 or trial_running():
		return false
	if not GameState.inventory.remove(item, 1):
		return false
	oil = minf(OIL_MAX, oil + FUELS[item])
	return true


## 灯现在照多远（像素）。没油了是 0。
func light_radius() -> float:
	if oil <= 0.0:
		return 0.0
	return lerpf(LIGHT_MIN, LIGHT_MAX, oil / OIL_MAX) * (1.0 + bonus(&"glow"))


## 走完了岚之影的考验（把灯放上了井底的灯座）。返回得了什么。
func finish_trial() -> Array[StringName]:
	if not trial_running():
		return []
	var shade := current.boss
	shade.state = MineMonster.State.DEAD
	return defeat(shade)


## 考验当中灯灭了：灯重新点满，飞着的风清掉，从头再走。
func restart_trial() -> void:
	oil = OIL_MAX
	_snuff_cd = 0.0
	if current != null:
		current.shots.clear()
		if current.boss_alive():
			current.boss.pos = GameMap.tile_center(MineFloor.TRIAL_SHADE)


# ---------------------------------------------------------------- 饰品

func wearing(id: StringName) -> bool:
	return equipped.has(id) and GameState.inventory.count_of(id) > 0


## 戴着的饰品里这种效果加起来有多少。饰品不在背包里了就不算。
func bonus(effect: StringName) -> float:
	var total := 0.0
	for id in equipped:
		var def := Database.accessory(id)
		if def != null and def.effect == effect and GameState.inventory.count_of(id) > 0:
			total += def.value
	return total


## 戴上或者摘下一件饰品。返回要告诉玩家的一句话。
func toggle_accessory(id: StringName) -> String:
	var def := Database.accessory(id)
	if def == null or GameState.inventory.count_of(id) == 0:
		return ""
	# 已经不在背包里的顺手清掉
	for i in range(equipped.size() - 1, -1, -1):
		if GameState.inventory.count_of(equipped[i]) == 0:
			equipped.remove_at(i)
	if equipped.has(id):
		equipped.erase(id)
		changed.emit()
		return "摘下了%s" % def.name
	if equipped.size() >= SLOTS:
		var names: PackedStringArray = []
		for worn in equipped:
			names.append(Database.item(worn).name)
		return "身上只能戴 %d 件，已经戴着%s。先摘一件" % [SLOTS, "和".join(names)]
	equipped.append(id)
	changed.emit()
	return "戴上了%s。%s" % [def.name, def.desc]


## 把欠着的首领掉落补给玩家（背包有地方的话）。返回这回给了什么。
func collect_owed() -> Array[StringName]:
	var got: Array[StringName] = []
	for i in range(owed.size() - 1, -1, -1):
		var item := owed[i]
		if Database.has_item(item) and GameState.inventory.can_add(item, 1):
			GameState.inventory.add(item, 1)
			got.append(item)
			owed.remove_at(i)
	if not got.is_empty():
		changed.emit()
	return got


## 在井里晕倒：这一趟得来的东西每样丢一半（单数的多丢一个），人回地面。返回丢了什么：物品 id -> 个数。
func faint() -> Dictionary[StringName, int]:
	var lost: Dictionary[StringName, int] = {}
	for item: StringName in haul:
		var n := mini(ceili(haul[item] * FAINT_LOSS), GameState.inventory.count_of(item))
		if n > 0 and GameState.inventory.remove(item, n):
			lost[item] = n
	haul.clear()
	leave()
	return lost


func _gain(item: StringName, count: int) -> void:
	GameState.inventory.add(item, count)
	# 武器这样只有一件的东西不算在“这一趟得来的”里，晕倒不会丢
	if Database.item(item).stack > 1:
		haul[item] = int(haul.get(item, 0)) + count


func _on_new_day() -> void:
	# 在井里熬到半夜晕倒，醒来是在家里
	leave()


func save_data() -> Dictionary:
	var owed_out: Array = []
	for item in owed:
		owed_out.append(String(item))
	var worn: Array = []
	for id in equipped:
		worn.append(String(id))
	return {"deepest": deepest, "lit": lit.duplicate(), "bosses": bosses.duplicate(), "owed": owed_out,
		"oil": oil, "equipped": worn}


func load_data(data: Dictionary) -> void:
	leave()
	deepest = clampi(int(data.get("deepest", 0)), 0, OPEN_FLOORS)
	lit.clear()
	var saved: Variant = data.get("lit", [])
	if saved is Array:
		for v: Variant in saved:
			var n := int(v)
			if n > 0 and n <= OPEN_FLOORS and n % LAMP_EVERY == 0 and not lit.has(n):
				lit.append(n)
	bosses.clear()
	var beaten: Variant = data.get("bosses", [])
	if beaten is Array:
		for v: Variant in beaten:
			var n := int(v)
			if has_boss_room(n) and not bosses.has(n):
				bosses.append(n)
	owed.clear()
	var owed_in: Variant = data.get("owed", [])
	if owed_in is Array:
		for v: Variant in owed_in:
			if Database.has_item(StringName(str(v))):
				owed.append(StringName(str(v)))
	oil = clampf(float(data.get("oil", 0.0)), 0.0, OIL_MAX)
	equipped.clear()
	var worn: Variant = data.get("equipped", [])
	if worn is Array:
		for v: Variant in worn:
			var id := StringName(str(v))
			if Database.accessory(id) != null and not equipped.has(id) and equipped.size() < SLOTS:
				equipped.append(id)
	changed.emit()


func reset_data() -> void:
	leave()
	deepest = 0
	lit.clear()
	bosses.clear()
	owed.clear()
	oil = 0.0
	_snuff_cd = 0.0
	equipped.clear()
	changed.emit()
