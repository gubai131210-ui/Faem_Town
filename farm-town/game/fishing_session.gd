class_name FishingSession
extends Node
## 一次钓鱼从甩竿到收竿的过程：把玩家、地图、Fishing 的规则和 FishingView 的画面接在一起。
## 游戏主场景在抛竿动作生效时调 begin()，之后每帧调 update()，结束时发 finished。

signal finished

enum Phase { IDLE, CASTING, WAITING, BITE, FIGHT, SHOW }

## 钓上来以后举着看多久
const SHOW_TIME := 1.6
## 浮漂飞到落点要多久
const FLIGHT_TIME := 0.42
## 提竿的那一下保持多久，然后才进入收线姿势
const HOOK_TIME := 0.22
## 咬钩前多久鱼影开始靠近浮漂
const SHADOW_LEAD := 2.4

var player: Player
var map: GameMap
var view: FishingView

var phase := Phase.IDLE
var fight: FishFight
var fish: FishDef
## 这一口咬的是遗物（雾天、清明）：fish 为空，relic 是哪一件
var relic: StringName = &""
var water: StringName = &""
var bobber := Vector2.ZERO
## 这一竿挂了鱼饵
var baited := false

var _timer := 0.0
var _hook_t := 0.0
## 刚钓上来的遗物，举完以后告诉地图
var _fished_relic: StringName = &""
## 鱼影从这边游过来（相对浮漂）
var _shadow_from := Vector2.ZERO
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


func active() -> bool:
	return phase != Phase.IDLE


## 抛竿动作生效：线落到 tile 那格水里；再往前一格也是水的话就落得远一点，线才看得出来。
func begin(tile: Vector2i, water_kind: StringName) -> void:
	if active():
		return
	water = water_kind
	var dir := Vector2i(Player.DIR_VECTORS[player.facing])
	if map != null and map.fishing_water(tile + dir) != &"":
		tile += dir
	bobber = GameMap.tile_center(tile) + Vector2(0, 2)
	fish = null
	relic = &""
	fight = null
	baited = Fishing.use_bait()
	phase = Phase.CASTING
	_timer = 0.0
	view.clear()
	view.bobber = bobber
	view.tip = player.rod_tip()
	view.cast_from = view.tip
	view.flight = 0.0
	Audio.play("cast")
	if map != null:
		map.fishing_started(bobber)


func update(delta: float) -> void:
	if not active():
		return
	view.tip = player.rod_tip()
	var pressed := Input.is_action_pressed(&"use")
	var just := Input.is_action_just_pressed(&"use")
	var moving := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down").length() > 0.3
	match phase:
		Phase.CASTING:
			if view.flight >= 0.0:
				view.flight += delta / FLIGHT_TIME
				if view.flight >= 1.0:
					view.flight = -1.0
					view.show_line = true
					view.ripple(bobber, 1.0)
			if not player.is_acting():
				_hold(&"fish")
			if view.flight < 0.0 and not player.is_acting():
				phase = Phase.WAITING
				_timer = Fishing.bite_wait(GameState.tool_level(&"rod"), _rng.randf(), baited)
				_pick_shadow_side()
		Phase.WAITING:
			if just or moving:
				_end()
				return
			_timer -= delta
			_update_shadow_approach()
			if _timer <= 0.0:
				# 地图指定了咬钩的是谁（井底老鲶）就是它，不然按这片水平常的来
				var forced := map.fishing_bite(bobber) if map != null else null
				relic = &"" if forced != null else _roll_relic()
				fish = forced if forced != null else (null if relic != &"" else Fishing.pick(water, _rng.randf()))
				if fish == null and relic == &"":
					# 这片水现在没有鱼：鱼影游走，浮漂动一下，什么都没咬
					view.show_shadow = false
					view.ripple(bobber, 0.6)
					_timer = Fishing.bite_wait(GameState.tool_level(&"rod"), _rng.randf(), baited)
					_pick_shadow_side()
					return
				phase = Phase.BITE
				_timer = Fishing.bite_window()
				view.dip = 3.0
				view.show_alert = true
				view.alert_at = player.position + Vector2(0, -34)
				view.ripple(bobber, 1.2)
				Audio.play("bite")
		Phase.BITE:
			_timer -= delta
			if just:
				fight = FishFight.new(fish if fish != null else _relic_as_fish(), GameState.tool_level(&"rod"))
				phase = Phase.FIGHT
				_hook_t = HOOK_TIME
				_hold(&"hook")
				view.show_alert = false
				view.dip = 1.0
				view.fight = fight
				view.gauge_at = player.position + Vector2(0, -38)
				view.ripple(bobber, 1.0)
				return
			if _timer <= 0.0:
				# 没来得及：鱼吐钩跑了
				view.show_alert = false
				view.show_shadow = false
				view.dip = 0.0
				view.ripple(bobber, 0.8)
				EventBus.banner_requested.emit("跑了……")
				Audio.play("deny", 0.0, -6.0)
				_end()
		Phase.FIGHT:
			var was_struggling := fight.struggling
			fight.step(delta, pressed)
			if fight.struggling and not was_struggling:
				view.ripple(bobber, 1.0)
				Audio.play("struggle", 0.1, -4.0)
			view.dip = 2.0 if fight.struggling else 1.0
			_hook_t -= delta
			if _hook_t <= 0.0:
				if fight.struggling:
					_hold(&"strain")
				elif pressed:
					_hold(&"reel")
				else:
					_hold(&"fish")
			_update_shadow_fight()
			if fight.is_over():
				_resolve()
		Phase.SHOW:
			_timer -= delta
			if _timer <= 0.0 or just:
				_end()


## 睡觉、转场时中断。
func cancel() -> void:
	if active():
		_end()


func _resolve() -> void:
	view.fight = null
	match fight.result:
		FishFight.Result.CAUGHT:
			_catch()
		FishFight.Result.LOST_LINE:
			EventBus.banner_requested.emit("线断了")
			Audio.play("snap")
			_end()
		_:
			EventBus.banner_requested.emit("脱钩了……")
			Audio.play("deny", 0.0, -6.0)
			_end()


func _catch() -> void:
	if relic != &"":
		_catch_relic()
		return
	if map != null and map.fish_landed(fish):
		# 这条鱼归地图处理（首领被拉上岸）
		view.ripple(bobber, 1.6)
		_end()
		return
	var size := Fishing.roll_size(fish, _rng.randf())
	var quality := fish.quality_for(size)
	if not GameState.inventory.can_add(fish.id, 1, quality):
		EventBus.banner_requested.emit("背包满了，%s 放回了水里" % fish.name)
		Audio.play("deny", 0.0, -6.0)
		_end()
		return
	GameState.inventory.add(fish.id, 1, quality)
	Fishing.record(fish.id, size)
	var note := "钓到了 %s · %d 厘米" % [fish.name, size]
	if quality > 0:
		note += " · " + ItemDef.QUALITY_NAMES[quality]
	if fish.legend:
		note = "！" + note
	EventBus.banner_requested.emit(note)
	Audio.play("harvest")
	view.show_line = false
	view.show_shadow = false
	view.ripple(bobber, 1.4)
	view.trophy = Px.tex(PixelArt.icon(Database.item(fish.id).icon))
	view.trophy_at = player.position + Vector2(0, -34)
	_hold(&"trophy")
	phase = Phase.SHOW
	_timer = SHOW_TIME


## 钓上来的是一件遗物。
func _catch_relic() -> void:
	if not GameState.inventory.can_add(relic, 1):
		EventBus.banner_requested.emit("背包满了，%s 又沉回了水里" % Database.relic(relic).name)
		Audio.play("deny", 0.0, -6.0)
		_end()
		return
	GameState.inventory.add(relic, 1)
	GameState.set_flag(StringName("relic_" + String(relic)))
	EventBus.banner_requested.emit("！钓上来一件东西：" + Database.relic(relic).name)
	_fished_relic = relic
	Audio.play("harvest")
	view.show_line = false
	view.show_shadow = false
	view.ripple(bobber, 1.4)
	view.trophy = Px.tex(PixelArt.icon(Database.item(relic).icon))
	view.trophy_at = player.position + Vector2(0, -34)
	_hold(&"trophy")
	phase = Phase.SHOW
	_timer = SHOW_TIME


## 沉在这片水底的剧情遗物最优先（Fishing.SUNKEN_CHANCE）；再看雾天和清明的随机遗物。躺在地上等着捡的那件不重复。
func _roll_relic() -> StringName:
	var sunken := map.sunken_relic(GameMap.tile_of(bobber)) if map != null else &""
	if sunken != &"" and _rng.randf() < Fishing.SUNKEN_CHANCE:
		return sunken
	if not Fishing.relic_bites(_rng.randf()):
		return &""
	var excluded: Array[StringName] = []
	if Foraging.pending_relic != &"":
		excluded.append(Foraging.pending_relic)
	for map_id: StringName in Foraging.items:
		for id: Variant in Foraging.items[map_id].values():
			excluded.append(id)
	return Fishing.pick_relic(_rng.randf(), excluded)


## 遗物在水里像一件沉重的死物：不挣扎，但往回收得慢。
func _relic_as_fish() -> FishDef:
	var def := FishDef.new()
	def.id = relic
	def.name = Database.relic(relic).name
	def.pull = 0.12
	def.fights = 999.0
	def.fight_len = 0.0
	return def


func _end() -> void:
	phase = Phase.IDLE
	fight = null
	fish = null
	relic = &""
	view.clear()
	player.release()
	if map != null:
		map.fishing_ended()
	finished.emit()
	if _fished_relic != &"":
		var id := _fished_relic
		_fished_relic = &""
		if map != null:
			map.relic_fished(id)


## 换姿势；已经是这个姿势就不重头播。
func _hold(anim: StringName) -> void:
	if player.held_anim() != anim:
		player.hold(anim)


func _pick_shadow_side() -> void:
	var a := _rng.randf_range(0.0, TAU)
	_shadow_from = Vector2(cos(a), sin(a) * 0.6) * 26.0


## 等鱼时：快咬钩了，鱼影从远处游到浮漂底下。
func _update_shadow_approach() -> void:
	if _timer > SHADOW_LEAD:
		view.show_shadow = false
		return
	var k := 1.0 - clampf(_timer / SHADOW_LEAD, 0.0, 1.0)
	var at := bobber + Vector2(0, 3) + _shadow_from * (1.0 - k)
	view.show_shadow = true
	view.shadow_dir = -_shadow_from
	view.shadow_at = at


## 遛鱼时：鱼影在浮漂附近，离岸越远（distance 越大）游得越远，挣扎时乱窜。
func _update_shadow_fight() -> void:
	var away := Vector2(_shadow_from.x, _shadow_from.y).normalized()
	if away == Vector2.ZERO:
		away = Vector2.RIGHT
	var r := (fight.distance - 0.6) * 30.0
	var at := bobber + Vector2(0, 3) + away * r
	if fight.struggling:
		at += Vector2(sin(fight.elapsed * 17.0), cos(fight.elapsed * 13.0) * 0.5) * 3.0
	view.show_shadow = true
	view.shadow_at = at
	view.shadow_dir = away if fight.struggling else -away
