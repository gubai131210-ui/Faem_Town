extends GameMap
## 沉灯井里的一层。长什么样由 Mine.current（MineFloor）决定，这里只负责画出来和接按键：
## 拿镐子敲石头，顺着梯子上下，逢五的层点井灯；这一层的忘形也在这里动、在这里挨打。
## 首领房里还管首领的血条，和把老鲶钓上岸这件事（接 FishingSession 的几个钩子）。
## 无光层整个画面压黑，只有人手里的灯照着的一圈看得见；灯油的条也画在这。

const W := MineFloor.W
const H := MineFloor.H
## 蹚着浅水走路的速度乘这么多
const WADE := 0.7
## 在走时钟身边那一圈里再乘这么多
const CLOCK_SLOW := 0.6
const BOSS_BAR_W := 120
## 老鲶的水池边插着的那根旧鱼竿画在哪一格（水池西北角外面）
const SPARE_ROD_AT := Vector2i(7, 5)
## 全黑的层整个画面乘上的颜色
const DARK_TINT := Color(0.05, 0.06, 0.1)
const OIL_BAR_W := 60
## 灯油剩这么多以下，条变红
const OIL_LOW := 20.0

var _floor: MineFloor
var _rock_sprites: Dictionary[Vector2i, Sprite2D] = {}
var _lamp_sprite: Sprite2D
var _lamp_light: PointLight2D
var _views: Dictionary[MineMonster, MonsterView] = {}
var _shot_sprites: Dictionary[MineShot, Sprite2D] = {}
var _boss_bar: CanvasLayer
var _boss_fill: ColorRect
var _hand_light: PointLight2D
var _oil_bar: CanvasLayer
var _oil_fill: ColorRect
var _altar_sprite: Sprite2D
## 这一趟已经提醒过的事，不重复说
var _told: Dictionary[StringName, bool] = {}


func _ready() -> void:
	map_id = &"mine"
	indoor = true
	combat = true
	# 读档、单独测试时井里还没有生成过楼层：从第一层开始
	if Mine.current == null:
		Mine.enter(1)
	_floor = Mine.current

	var ground := Sprite2D.new()
	var layer := Database.mine_layer(_floor.floor_no)
	var ground_img := MineArt.ground(_floor.open, W, H, layer.id if layer != null else &"shallow", _floor.water, _floor.pools)
	if _floor.arena == &"cart":
		_lay_rails(ground_img)
	ground.texture = Px.tex(ground_img)
	ground.centered = false
	ground.z_index = -10
	add_child(ground)

	entities = Node2D.new()
	entities.y_sort_enabled = true
	add_child(entities)

	_add_sprite(MineArt.ladder_up(), _floor.entry, Vector2(-8, -20))
	if _floor.lamp != MineFloor.NONE:
		_lamp_sprite = _add_sprite(MineArt.lamp(Mine.lamp_lit(_floor.floor_no)), _floor.lamp, Vector2(-8, -18))
		if Mine.lamp_lit(_floor.floor_no):
			_glow()
	for t: Vector2i in _floor.rocks:
		_add_rock(t)
	for t: Vector2i in _floor.props:
		var prop_img := MineDeepArt.prop(_floor.props[t])
		_add_sprite(prop_img, t, Vector2(-8, -(prop_img.get_height() - 8)))
	if _floor.ladder != MineFloor.NONE and _floor.ladder_found:
		_show_ladder()
	for m in _floor.monsters:
		if m.alive():
			var view := MonsterView.new()
			entities.add_child(view)
			view.setup(m)
			_views[m] = view
	if _floor.boss_alive() and _floor.arena != &"shade":
		_add_boss_bar()
	if _floor.altar != MineFloor.NONE:
		_altar_sprite = _add_sprite(MineDarkArt.altar(not _floor.boss_alive(), Story.lamp_lit()), _floor.altar, Vector2(-8, -16))
		if not _floor.boss_alive():
			_add_light(tile_center(_floor.altar) + Vector2(0, -10), 0.9, 2.0)
	if _floor.dark:
		_hand_light = _add_light(Vector2.ZERO, 1.0, 1.0)
		_hand_light.visible = false
		_add_oil_bar()
	if spare_rod():
		_add_sprite(MineDeepArt.spare_rod(), SPARE_ROD_AT, Vector2(-8, -16))


func _process(delta: float) -> void:
	# 开着菜单、转场的时候忘形也停下
	if GameClock.running and player is Player:
		tick(minf(delta, 0.05))


## 过 delta 秒：忘形各走各的，撞到人就扣生命。
func tick(delta: float) -> void:
	var who := player as Player
	if who == null:
		return
	for m in _floor.monsters:
		if not m.alive():
			continue
		m.update(delta, who.position, _floor)
		_drain(m)
		# 翻滚中和刚挨过打的时候撞不着；这一招照样算出过了
		if m.strikes(who.position) and not who.invincible():
			if m.def.eat_light > 0.0:
				# 噬光蛾不咬人，扑上来吃灯油
				_snuff(who, m.def.eat_light)
			else:
				_hurt_player(who, m.def.damage, who.position - m.pos)
	_floor.separate(delta)
	_floor.step_shots(delta)
	for s in _floor.shots:
		if s.hits(who.position) and not who.invincible():
			s.alive = false
			if s.snuff > 0.0:
				_snuff(who, s.snuff)
			else:
				_hurt_player(who, s.damage, s.vel)
	_sync_shots()
	who.slow = slow_at(who.position)
	who.roll_grace = Mine.bonus(&"roll_grace")
	_sync_boss_bar()
	Mine.burn(delta)
	if Mine.trial_running() and Mine.oil <= 0.0:
		_trial_failed(who)
	_sync_light(who)


## 灯现在照多远，写给楼层（怕光的忘形要看），手里那圈光和灯油的条跟着变。
func _sync_light(who: Player) -> void:
	if not _floor.dark:
		_floor.light = 100000.0
		return
	var r := Mine.light_radius()
	_floor.light = r
	if _hand_light != null:
		_hand_light.visible = r > 0.0
		_hand_light.position = who.position + Vector2(0, -8)
		_hand_light.texture_scale = maxf(0.1, r / 40.0)
	if _oil_fill != null:
		_oil_fill.size = Vector2(oil_bar_width(), 3)
		_oil_fill.color = Color("e0564a") if Mine.oil < OIL_LOW else Color("f0c050")
	if Mine.oil <= 0.0 and not Mine.trial_running():
		_tell(&"oil_out", "灯灭了，什么都看不见。拿着灯油或者菜油按使用键添上")
	elif Mine.oil < OIL_LOW:
		_tell(&"oil_low", "灯油快烧完了")


## 灯被吃掉、吹掉一口油。
func _snuff(who: Player, amount: float) -> void:
	if not Mine.snuff(amount):
		return
	Audio.play("spit", 0.1, -5.0)
	Fx.burst(self, who.position + Vector2(0, -10), Color("f0c050"), 8, 50.0, 0.4)
	_tell(&"snuffed", "灯暗了一截：灯油被弄掉了。翻滚能躲开")


## 考验当中灯灭了：回到梯子底下，灯重新点满，从头再走。不算晕倒。
func _trial_failed(who: Player) -> void:
	Mine.restart_trial()
	who.halt()
	who.position = tile_center(_floor.spawn)
	Audio.play("deny", 0.0, -4.0)
	EventBus.banner_requested.emit("灯灭了。四下一黑，再睁眼又站在梯子底下，灯是满的。再走一回")


func _hurt_player(who: Player, damage: int, away: Vector2) -> void:
	# 护腕挡掉一部分
	damage = maxi(1, roundi(damage * (1.0 - clampf(Mine.bonus(&"armor"), 0.0, 0.8))))
	GameState.hurt(damage)
	who.hurt(away)
	Audio.play("hurt", 0.05, -3.0)
	EventBus.screen_shake_requested.emit(2.5)
	Fx.burst(self, who.position + Vector2(0, -8), Color("e0564a"), 8, 60.0)


## 站在 p 走路的速度要乘多少：浅水里慢，走时钟身边更慢。
func slow_at(p: Vector2) -> float:
	var k := 1.0
	if _floor.water.has(tile_of(p)) and Mine.bonus(&"wade") <= 0.0:
		k *= WADE
	for m in _floor.monsters:
		if m.alive() and m.def.slow_aura > 0.0 and m.pos.distance_to(p) <= m.def.slow_aura:
			k *= CLOCK_SLOW
			break
	return k


## 把这只忘形刚扔出来的东西交给楼层，刚出的事配上声音和特效。
func _drain(m: MineMonster) -> void:
	for s in m.pending_shots:
		_floor.shots.append(s)
	m.pending_shots.clear()
	for e in m.events:
		match e:
			&"land":
				Fx.burst(self, m.pos, Color("9ab0a0"), 6, 45.0, 0.3)
				Audio.play("thump", 0.1, -3.0)
				EventBus.screen_shake_requested.emit(1.0)
			&"crash":
				Fx.burst(self, m.pos + m.facing * 10.0, Color("d8d2c8"), 16, 85.0)
				Audio.play("crash", 0.03)
				EventBus.screen_shake_requested.emit(5.0)
				_tell(&"cart_down", "它撞晕了！趁现在打")
			&"spit":
				Audio.play("spit", 0.1, -2.0)
			&"ashore":
				Fx.burst(self, m.pos, Color("7ab8c4"), 18, 80.0)
				Audio.play("plunge", 0.0, -1.0)
				EventBus.screen_shake_requested.emit(3.0)
				_tell(&"catfish_down", "拉上来了！趁它还没跳回去，打")
			&"dive":
				Fx.burst(self, m.pos, Color("7ab8c4"), 14, 70.0)
				Audio.play("plunge", 0.1, -4.0)
			&"mask":
				Fx.burst(self, m.pos + Vector2(0, -14), Color("f0ead8"), 10, 50.0, 0.4)
				Audio.play("select", 0.2, -6.0)
				_tell(&"troupe_mask", "它换了一张脸。红脸连着冲三回，白脸撒纸钱，黑脸跳起来砸")
			&"blow":
				Audio.play("spit", 0.2, -4.0)
	m.events.clear()


## 这一趟里头一回才说的话。
func _tell(key: StringName, text: String) -> void:
	if _told.has(key):
		return
	_told[key] = true
	EventBus.banner_requested.emit(text)


## 飞着的纸钱、水弹：一颗一张图，没了的收掉。
func _sync_shots() -> void:
	for s in _floor.shots:
		if not s.alive:
			continue
		if not _shot_sprites.has(s):
			var sprite := Sprite2D.new()
			sprite.texture = Px.tex(MineDarkArt.gust() if s.kind == &"gust" else MineDeepArt.shot(s.kind))
			sprite.z_index = 12
			add_child(sprite)
			_shot_sprites[s] = sprite
		_shot_sprites[s].position = s.pos.round() + Vector2(0, -6)
	for s: MineShot in _shot_sprites.keys():
		if not s.alive or not _floor.shots.has(s):
			if s.kind == &"water":
				Fx.burst(self, s.pos + Vector2(0, -6), Color("7ab8c4"), 4, 40.0, 0.25)
			_shot_sprites[s].queue_free()
			_shot_sprites.erase(s)


## 现在画着几颗飞着的东西。
func shot_count() -> int:
	return _shot_sprites.size()


## 武器挥到的这一帧：算打到了哪几只。step 是连段里的第几下，skill 为真是蓄力技。返回打到几只。
func weapon_hit(weapon: WeaponDef, step: int, skill: bool) -> int:
	var who := player as Player
	if who == null or weapon == null:
		return 0
	var origin := who.position
	var dir: Vector2 = Player.DIR_VECTORS[who.facing]
	var end := origin
	if skill and weapon.kind == &"dagger":
		# 突进：人先冲过去，一路上的都算打到
		end = who.shove(dir * weapon.skill_reach())
	var damage := weapon.skill_damage() if skill else weapon.damage_at(step)
	damage = roundi(damage * (1.0 + Mine.bonus(&"power")))
	var knock := weapon.knock() * (1.5 if skill else 1.0)
	_swing_fx(weapon, origin, end, dir, skill)
	var count := 0
	for m in _floor.monsters:
		if not m.alive():
			continue
		# 水里的老鲶够不着
		if m is MineCatfish and (m as MineCatfish).in_water():
			continue
		var reached := weapon.skill_hits(origin, end, m.pos, m.def.radius) if skill \
			else weapon.hits(origin, dir, m.pos, m.def.radius)
		if not reached:
			continue
		count += 1
		_hit_fx(m, m.take_hit(damage, origin, knock, weapon.breaks_guard()))
	if skill or step == weapon.combo_len() - 1:
		EventBus.screen_shake_requested.emit(2.0 if count > 0 else 1.0)
	return count


func _hit_fx(m: MineMonster, res: Dictionary) -> void:
	if bool(res["blocked"]):
		Audio.play("clang", 0.05, -4.0)
		Fx.burst(self, m.pos + Vector2(0, -6), Color("fff2b0"), 5, 55.0, 0.25)
		if m is MineShade:
			_tell(&"shade_untouchable", "刀从它身上穿了过去。它不是来打架的：护着灯，走到走廊尽头的灯座")
		elif m is MineCart:
			_tell(&"cart_armor", "铁皮砍不动。它只会直着冲：背靠着墙等它冲过来，躲开，让它撞上去")
		elif m.def.guard_open:
			_tell(&"umbrella_guard", "伞撑着的时候砍不动。等它收了伞扑过来，或者用锤砸")
		elif not GameState.has_flag(&"hint_guard"):
			GameState.set_flag(&"hint_guard")
			EventBus.banner_requested.emit("%s的壳正面砍不动。绕到它背后，或者用锤砸" % m.def.name)
		return
	Audio.play("hit", 0.1, -4.0)
	if not bool(res["dead"]):
		Fx.burst(self, m.pos + Vector2(0, -6), Color("d8d2c8"), 5, 50.0, 0.25)
		return
	Fx.burst(self, m.pos + Vector2(0, -6), Color("8d8a86"), 14, 70.0)
	if _views.has(m):
		_views[m].queue_free()
		_views.erase(m)
	var got := Mine.defeat(m)
	for i in got.size():
		Fx.pop_icon(self, m.pos + Vector2(i * 8.0 - (got.size() - 1) * 4.0, -10), Px.tex(PixelArt.icon(Database.item(got[i]).icon)))
	if not got.is_empty():
		Audio.play("harvest", 0.0, -8.0)
	if m.is_boss():
		_boss_down(m, got)
		return
	for id in got:
		if Database.has_relic(id):
			EventBus.banner_requested.emit("它倒下的地方留着一件东西：" + Database.relic(id).name)


## 首领倒了：血条收掉，往下的梯子露出来，说一声得了什么。
func _boss_down(m: MineMonster, got: Array[StringName]) -> void:
	EventBus.screen_shake_requested.emit(6.0)
	# 它扔出来还在飞的东西跟着没了
	_floor.shots.clear()
	Fx.burst(self, m.pos + Vector2(0, -8), Color("fff2b0"), 30, 110.0, 0.8)
	Audio.play("sleep", 0.0, -4.0)
	if _boss_bar != null:
		_boss_bar.queue_free()
		_boss_bar = null
	var text := "%s不动了" % m.def.name
	var names: PackedStringArray = []
	for id in got:
		names.append(Database.item(id).name)
	if not names.is_empty():
		text += "。得到：" + "、".join(names)
	if not Mine.owed.is_empty():
		text += "\n背包满了，放不下的先留在井里，下回进井再给你"
	if _floor.ladder != MineFloor.NONE:
		_show_ladder()
		text += "\n往下的梯子露出来了"
	EventBus.banner_requested.emit(text)


## 挥出去的那一道白光：普通的一下是面前一段弧，镰刀和锤的蓄力技是一整圈，短剑的突进是一条线。
func _swing_fx(weapon: WeaponDef, origin: Vector2, end: Vector2, dir: Vector2, skill: bool) -> void:
	var s := Sprite2D.new()
	s.z_index = 15
	s.position = origin + Vector2(0, -6)
	if skill and weapon.kind == &"dagger":
		var length := maxf(8.0, origin.distance_to(end) + 10.0)
		s.texture = Px.tex(MineArt.streak(int(length)))
		s.position = (origin + end) / 2.0 + Vector2(0, -6)
	elif skill:
		s.texture = Px.tex(MineArt.slash(weapon.skill_reach(), 180.0))
	else:
		var style := weapon.style()
		s.texture = Px.tex(MineArt.slash(float(style["reach"]), float(style["arc"])))
	s.rotation = dir.angle()
	add_child(s)
	var tw := s.create_tween()
	tw.tween_property(s, "modulate:a", 0.0, 0.16)
	tw.tween_callback(s.queue_free)


func entered() -> void:
	var layer := Database.mine_layer(_floor.floor_no)
	var text := "沉灯井 · %s · 第 %d 层" % [layer.name if layer != null else "", _floor.floor_no]
	if _floor.floor_no >= Mine.OPEN_FLOORS:
		text += "。这里是井底"
	elif _floor.ladder == MineFloor.NONE:
		text += "。再往下的路被塌下来的石头堵死了"
	if Mine.ladder_fogged() and not _floor.boss_alive():
		text += "。往下的梯子口往外冒着雾"
	if _floor.altar != MineFloor.NONE and not _floor.boss_alive():
		text += "。龛里那盏旧矿灯也亮着" if Story.lamp_lit() else "。灯座的龛里嵌着一盏旧矿灯，还黑着"
	if Mine.box_waiting():
		# 铁盒做出来以前就点过这盏灯的旧存档：提醒一句
		text += "。井灯的灯座底下像是压着什么东西"
	if _floor.dark and not _floor.boss_alive() and not GameState.has_flag(&"hint_dark"):
		GameState.set_flag(&"hint_dark")
		text += "
这里一点光都没有，只有手里的灯照着的一圈。灯油一直在烧；拿着灯油或者菜油按使用键能添"
	if _floor.boss_alive():
		if _floor.arena == &"troupe":
			text += "
空地当中站着一个戴面具的人影。它每歇一回换一张脸，一张脸一种打法"
		elif _floor.arena == &"shade":
			text += "
一个提灯的影子飘在前头，不像要打架。灯添满了，这一层里添不了油。
护着灯走到走廊尽头的灯座；它吹过来的风会吹掉灯油，翻滚能躲"
		elif _floor.arena == &"cart":
			text += "\n一辆废矿车堵在路中间。它只会直着冲"
		elif _floor.arena == &"catfish":
			if spare_rod():
				text += "\n水池里有个很大的影子，武器够不着。岸边插着一根旧鱼竿：手里别拿武器，对着水按使用键甩一竿"
			else:
				text += "\n水池里有个很大的影子，武器够不着。拿鱼竿对着水甩一竿"
	var back := Mine.collect_owed()
	if not back.is_empty():
		var names: PackedStringArray = []
		for id in back:
			names.append(Database.item(id).name)
		text += "\n上回放不下的拿回来了：" + "、".join(names)
	# 头一回下井：说一遍怎么打
	if not GameState.has_flag(&"hint_combat"):
		GameState.set_flag(&"hint_combat")
		text += "\n拿着武器按使用键挥砍，按住蓄力；Shift 或 X 翻滚。按 Esc 能再看按键"
	EventBus.banner_requested.emit(text)


func size_px() -> Vector2i:
	return Vector2i(W * TS, H * TS)


func spawn_position(_spawn: StringName) -> Vector2:
	return tile_center(_floor.spawn)


func spawn_facing(_spawn: StringName) -> Facing:
	return Facing.DOWN


func blocked(p: Vector2) -> bool:
	for c: Vector2 in [Vector2(-4, -4), Vector2(4, -4), Vector2(-4, 1), Vector2(4, 1)]:
		if not _floor.walkable(tile_of(p + c)):
			return true
	return false


func query_use(item: ItemDef, tile: Vector2i, _facing: Facing) -> StringName:
	if tile == _floor.entry or tile == _floor.lamp or tile == _floor.altar or (tile == _floor.ladder and _floor.ladder_found):
		return &"interact"
	# 拿着能添灯的油：按使用键是添油（use_item）
	if item != null and Mine.FUELS.has(item.id) and not _floor.has_rock(tile):
		return &""
	if item != null and item.id == &"rod" and fishing_water(tile) != &"":
		return &"cast"
	# 没带鱼竿：手里不是武器的时候对着水池按，用的是岸边那根旧竿
	if spare_rod() and _floor.pools.has(tile) and (item == null or item.kind != &"weapon"):
		return &"cast"
	# 拿着武器：对着哪都是挥
	if item != null and item.kind == &"weapon":
		return &"attack"
	if _floor.has_rock(tile):
		return &"mine" if item != null and item.id == Mine.PICKAXE else &"interact"
	return &""


func perform(action: StringName, _item: ItemDef, tile: Vector2i, _quiet: bool = false) -> void:
	if action == &"mine":
		_strike(tile)
		return
	if action != &"interact":
		return
	if tile == _floor.entry:
		Mine.leave()
		SceneRouter.travel(&"wellhead", &"from_mine")
	elif tile == _floor.lamp:
		_use_lamp()
	elif tile == _floor.altar:
		_use_altar()
	elif tile == _floor.ladder and _floor.ladder_found:
		if Mine.ladder_fogged():
			EventBus.banner_requested.emit("梯子底下的雾浓得像水，灯照不进去，脚也探不到下一级。\n雾是从山上来的。山里的事没弄明白，这底下去不得")
			Audio.play("deny", 0.0, -6.0)
		elif Mine.descend():
			Audio.play("select", 0.0, -6.0)
			SceneRouter.travel(&"mine", &"ladder")
	elif _floor.has_rock(tile):
		EventBus.banner_requested.emit("石头。得拿镐子敲")
		Audio.play("deny", 0.0, -6.0)


# ---------------------------------------------------------------- 灯

func forced_tint() -> Color:
	return DARK_TINT if _floor != null and _floor.dark else Color(0, 0, 0, 0)


## 拿着灯油、菜油按使用键：往手里的灯里添。
func use_item(item: ItemDef) -> bool:
	if not Mine.FUELS.has(item.id):
		return false
	if Mine.refuel(item.id):
		Audio.play("water", 0.1, -6.0)
		EventBus.banner_requested.emit("往灯里添了%s。灯油 %d / %d" % [item.name, int(Mine.oil), int(Mine.OIL_MAX)])
	elif Mine.trial_running():
		EventBus.banner_requested.emit("这一层里灯添不了油")
		Audio.play("deny", 0.0, -6.0)
	else:
		EventBus.banner_requested.emit("灯是满的")
		Audio.play("deny", 0.0, -6.0)
	return true


## 灯油的条现在是不是画着。
func oil_bar_shown() -> bool:
	return _oil_bar != null and _oil_bar.visible


## 灯油的条亮的那一截有多宽。
func oil_bar_width() -> int:
	return clampi(ceili(OIL_BAR_W * Mine.oil / Mine.OIL_MAX), 0, OIL_BAR_W)


## 井底的灯座：把灯放上去，考验就算走完了。
func _use_altar() -> void:
	if not Mine.trial_running():
		if Story.can_choose():
			# 终幕：龛里那盏最初的灯，点还是不点
			EventBus.dialogue_requested.emit(Story.DIALOGUE, "first_lamp")
		elif Story.lamp_lit():
			EventBus.banner_requested.emit("两盏灯都亮着。龛里那盏的提梁上，二十八个名字一个一个看得清了")
		else:
			EventBus.banner_requested.emit("灯座上的灯亮着，照得井底一片暖黄")
		return
	var shade := _floor.boss
	var got := Mine.finish_trial()
	_floor.shots.clear()
	for m in _floor.monsters:
		if m != shade and m.alive():
			m.state = MineMonster.State.DEAD
	for m: MineMonster in _views.keys():
		Fx.burst(self, m.pos + Vector2(0, -8), Color("7fe0d8"), 12, 60.0, 0.6)
		_views[m].queue_free()
	_views.clear()
	_floor.dark = false
	if _hand_light != null:
		_hand_light.visible = false
	if _oil_bar != null:
		_oil_bar.visible = false
	_altar_sprite.texture = Px.tex(MineDarkArt.altar(true))
	_add_light(tile_center(_floor.altar) + Vector2(0, -10), 0.9, 2.0)
	Audio.play("sleep", 0.0, -4.0)
	EventBus.screen_shake_requested.emit(3.0)
	Fx.burst(self, tile_center(_floor.altar) + Vector2(0, -14), Color(1.0, 0.85, 0.45, 0.95), 30, 90.0, 1.0, -20.0)
	var text := "把灯放上了灯座。火苗一下蹿高，井底亮了。那个影子看了你一会儿，散了"
	text += "\n亮光里看得见石台正面有个龛，里头嵌着一盏旧矿灯，是黑的"
	var names: PackedStringArray = []
	for id in got:
		names.append(Database.item(id).name)
	if not names.is_empty():
		text += "
灯座底下留着：" + "、".join(names)
	if not Mine.owed.is_empty():
		text += "
背包满了，放不下的先留在井里，下回进井再给你"
	EventBus.banner_requested.emit(text)


func _add_oil_bar() -> void:
	_oil_bar = CanvasLayer.new()
	_oil_bar.layer = 9
	add_child(_oil_bar)
	var root := UiKit.root()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_oil_bar.add_child(root)
	var title := UiKit.label("灯油", UiKit.FONT_SIZE, UiKit.TEXT_LIGHT, true)
	# 画在物品栏上面一点：屏幕上边留给提示条
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.anchor_top = 1.0
	title.anchor_bottom = 1.0
	title.offset_left = -OIL_BAR_W / 2.0 - 30.0
	title.offset_right = -OIL_BAR_W / 2.0 - 3.0
	title.offset_top = -41.0
	title.offset_bottom = -30.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title)
	var back := ColorRect.new()
	back.color = Color("241c1a")
	back.anchor_left = 0.5
	back.anchor_right = 0.5
	back.anchor_top = 1.0
	back.anchor_bottom = 1.0
	back.offset_left = -OIL_BAR_W / 2.0 - 1.0
	back.offset_right = OIL_BAR_W / 2.0 + 1.0
	back.offset_top = -37.0
	back.offset_bottom = -32.0
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(back)
	_oil_fill = ColorRect.new()
	_oil_fill.color = Color("f0c050")
	_oil_fill.position = Vector2(1, 1)
	_oil_fill.size = Vector2(oil_bar_width(), 3)
	_oil_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(_oil_fill)


# ---------------------------------------------------------------- 钓鱼和老鲶

## 暗河里能钓鱼。首领房的水池：老鲶还在的时候只有它（别的鱼不咬），打倒以后是深处的鱼。
func fishing_water(tile: Vector2i) -> StringName:
	if not _floor.pools.has(tile):
		return &""
	if _floor.arena == &"catfish":
		return &"mine_boss" if _floor.boss_alive() else &"mine_deep"
	return &"mine_shallow"


## 老鲶还在、人又没有鱼竿的时候，水池边有一根谁留下的旧竿可以用（不进背包，按最普通的竿算）。
func spare_rod() -> bool:
	return _floor.arena == &"catfish" and _floor.boss_alive() and GameState.inventory.count_of(&"rod") == 0


func fishing_started(at: Vector2) -> void:
	var fish := _catfish()
	if fish != null:
		fish.cast_line(at)


func fishing_ended() -> void:
	var fish := _catfish()
	if fish != null:
		fish.line_gone()


## 老鲶游到了浮漂底下：这一口是它。
func fishing_bite(_at: Vector2) -> FishDef:
	var fish := _catfish()
	if fish == null or not fish.at_bait():
		return null
	return fish.as_fish()


## 遛赢了：老鲶被拉上岸，摔在人身边，不进背包。
func fish_landed(_fish: FishDef) -> bool:
	var fish := _catfish()
	if fish == null:
		return false
	fish.land(shore_spot(fish.pos))
	return true


## 人身边离 from 最近的一块能站的地（把鱼拉上来摔在这）。
func shore_spot(from: Vector2) -> Vector2:
	var base := tile_of(player.position) if player != null else _floor.spawn
	var best := tile_center(base)
	var best_d := INF
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var t := base + Vector2i(dx, dy)
			if t == base or not _floor.walkable(t):
				continue
			var d := tile_center(t).distance_to(from)
			if d < best_d:
				best_d = d
				best = tile_center(t)
	return best


func _catfish() -> MineCatfish:
	if not _floor.boss_alive():
		return null
	return _floor.boss as MineCatfish


# ---------------------------------------------------------------- 首领的血条

func _add_boss_bar() -> void:
	_boss_bar = CanvasLayer.new()
	_boss_bar.layer = 9
	add_child(_boss_bar)
	var root := UiKit.root()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_bar.add_child(root)
	var title := UiKit.label(_floor.boss.def.name, UiKit.FONT_SIZE, UiKit.TEXT_LIGHT, true)
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	# 画在物品栏上面一点：屏幕上边留给提示条
	title.anchor_top = 1.0
	title.anchor_bottom = 1.0
	title.offset_left = -BOSS_BAR_W / 2.0
	title.offset_right = BOSS_BAR_W / 2.0
	title.offset_top = -50.0
	title.offset_bottom = -38.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title)
	var back := ColorRect.new()
	back.color = Color("241c1a")
	back.anchor_left = 0.5
	back.anchor_right = 0.5
	back.anchor_top = 1.0
	back.anchor_bottom = 1.0
	back.offset_left = -BOSS_BAR_W / 2.0 - 1.0
	back.offset_right = BOSS_BAR_W / 2.0 + 1.0
	back.offset_top = -37.0
	back.offset_bottom = -32.0
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(back)
	_boss_fill = ColorRect.new()
	_boss_fill.color = Color("e0564a")
	_boss_fill.position = Vector2(1, 1)
	_boss_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(_boss_fill)
	_sync_boss_bar()


## 首领的血条现在是不是画着。
func boss_bar_shown() -> bool:
	return _boss_bar != null


## 首领血条红的那一截有多宽。
func boss_bar_width() -> int:
	if not _floor.boss_alive():
		return 0
	return clampi(ceili(float(BOSS_BAR_W) * _floor.boss.hp / maxi(1, _floor.boss.def.hp)), 1, BOSS_BAR_W)


func _sync_boss_bar() -> void:
	if _boss_fill != null and _boss_bar != null:
		_boss_fill.size = Vector2(boss_bar_width(), 3)


## 矿车那一层地上的铁轨：横一道竖一道（只是画着，矿车不认轨）。
func _lay_rails(img: Image) -> void:
	var area := MineFloor.ARENA
	for x in range(area.position.x, area.end.x):
		Px.blit(img, MineDeepArt.rail(true), x * TS, MineFloor.ARENA_CART.y * TS)
	for y in range(area.position.y, area.end.y):
		if y != MineFloor.ARENA_CART.y:
			Px.blit(img, MineDeepArt.rail(false), 10 * TS, y * TS)


func _strike(tile: Vector2i) -> void:
	var res := Mine.strike(tile)
	if res.is_empty():
		return
	if bool(res.get("full", false)):
		EventBus.banner_requested.emit("背包满了")
		Audio.play("deny", 0.0, -4.0)
		return
	var c := tile_center(tile)
	Audio.play("hoe")
	EventBus.screen_shake_requested.emit(1.5)
	if not bool(res["broken"]):
		Fx.burst(self, c, Color("b8b4ae"), 5, 50.0)
		var sprite: Sprite2D = _rock_sprites.get(tile)
		if sprite != null:
			# 敲了一下还没开：晃一晃
			var tw := create_tween()
			tw.tween_property(sprite, "offset:x", sprite.offset.x + 1.0, 0.04)
			tw.tween_property(sprite, "offset:x", sprite.offset.x, 0.06)
		return
	Fx.burst(self, c, Color("8d8a86"), 12, 75.0)
	if _rock_sprites.has(tile):
		_rock_sprites[tile].queue_free()
		_rock_sprites.erase(tile)
	var item: StringName = res["item"]
	Fx.pop_icon(self, c + Vector2(0, -10), Px.tex(PixelArt.icon(Database.item(item).icon)))
	if item != &"stone":
		Audio.play("harvest", 0.0, -6.0)
	if bool(res["ladder"]):
		_show_ladder()
		EventBus.banner_requested.emit("石头底下露出一架往下的梯子")


func _use_lamp() -> void:
	if Mine.lamp_lit(_floor.floor_no):
		if Mine.box_waiting():
			_open_box()
			return
		EventBus.banner_requested.emit("第 %d 层的井灯亮着。井口的升降机能直接下到这里" % _floor.floor_no)
		return
	if not Mine.light_lamp():
		return
	_lamp_sprite.texture = Px.tex(MineArt.lamp(true))
	_glow()
	Audio.play("sleep", 0.0, -6.0)
	Fx.burst(self, _lamp_sprite.position + Vector2(0, -14), Color(1.0, 0.85, 0.45, 0.95), 14, 40.0, 0.8, -20.0)
	EventBus.banner_requested.emit("点亮了第 %d 层的井灯。往后坐井口的升降机能直接下到这里" % _floor.floor_no)
	if Mine.box_waiting():
		_open_box()


## 第四幕：灯一亮，照见灯座底下压着的铁盒。背包放不下就留着，再对着灯按一下还能拿。
func _open_box() -> void:
	if not Mine.take_box():
		EventBus.banner_requested.emit("灯座底下压着一只生锈的铁盒。背包满了，得腾出两格")
		Audio.play("deny", 0.0, -4.0)
		return
	Audio.play("harvest", 0.0, -2.0)
	for i in Mine.BOX_RELICS.size():
		Fx.pop_icon(self, tile_center(_floor.lamp) + Vector2(-8 + i * 16, -14), Px.tex(PixelArt.icon(Database.item(Mine.BOX_RELICS[i]).icon)))
	EventBus.dialogue_requested.emit(Residents.COMMON_DIALOGUE, "act4_box")


func _glow() -> void:
	if _lamp_light != null:
		return
	_lamp_light = _add_light(tile_center(_floor.lamp) + Vector2(0, -12), 0.7, 1.0)


## 一团暖黄的光。贴图 96 像素见方，scale 是 1 的时候大约照亮半径 40 像素。
func _add_light(at: Vector2, energy: float, scale_by: float) -> PointLight2D:
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 96
	tex.height = 96
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var light := PointLight2D.new()
	light.texture = tex
	light.color = Color(1.0, 0.82, 0.5)
	light.energy = energy
	light.texture_scale = scale_by
	light.position = at
	add_child(light)
	return light


func _show_ladder() -> void:
	_add_sprite(MineArt.ladder_down(), _floor.ladder, Vector2(-8, -8)).z_index = -1


func _add_rock(t: Vector2i) -> void:
	var item := _floor.rocks[t]
	var fleck := Color(0, 0, 0, 0) if item == &"stone" else Database.ore_color(item)
	_rock_sprites[t] = _add_sprite(MineArt.rock(fleck, Px.h2(t.x, t.y)), t, Vector2(-8, -9))


## 在 t 这一格放一张图：节点放在格子中心偏下（按 y 排序用），图按 offset 摆。
func _add_sprite(img: Image, t: Vector2i, offset: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = Px.tex(img)
	s.centered = false
	s.position = tile_center(t) + Vector2(0, 6)
	s.offset = offset + Vector2(0, -6)
	entities.add_child(s)
	return s
