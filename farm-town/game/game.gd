extends Node2D
## 游戏主场景：把地图、玩家、镜头和界面装到一起，并在它们之间传话。
## 这里只做“接线”，具体规则在各自的系统里。

## 昼夜色调关键帧：[分钟, 颜色]
const TINTS: Array = [
	[360.0, Color(1.0, 0.93, 0.86)],
	[480.0, Color(1.0, 1.0, 1.0)],
	[1020.0, Color(1.0, 1.0, 1.0)],
	[1110.0, Color(1.0, 0.8, 0.66)],
	[1200.0, Color(0.6, 0.56, 0.8)],
	[1320.0, Color(0.36, 0.4, 0.68)],
	[1560.0, Color(0.3, 0.34, 0.62)],
]
const INDOOR_DAY := Color(1.0, 0.97, 0.92)
const INDOOR_NIGHT := Color(0.8, 0.72, 0.66)
## 天气给室外画面再乘一层颜色；没列出的天气不变
const WEATHER_TINTS: Dictionary[StringName, Color] = {
	&"cloudy": Color(0.93, 0.94, 0.97),
	&"rain": Color(0.76, 0.82, 0.93),
	&"storm": Color(0.62, 0.68, 0.84),
	&"fog": Color(0.9, 0.93, 0.95),
	&"snow": Color(0.92, 0.95, 1.0),
	&"frost": Color(0.93, 0.96, 1.0),
}
## 按住这么久蓄一档力
const CHARGE_STEP := 0.45
## 用一次工具消耗的体力
const ENERGY_COST: Dictionary[StringName, int] = {&"hoe": 2, &"water": 1, &"dig": 2, &"cast": 1, &"mine": 2}
## 翻滚一次、放一次蓄力技花的体力；普通的挥砍不花
const ROLL_COST := 3
const SKILL_COST := 4
## 武器按住这么久蓄好力
const SKILL_CHARGE := 0.5
## 在井里晕倒，被背回井口，醒来过去了这么多分钟
const FAINT_MINUTES := 120.0

var map: GameMap
var player: Player
var camera: Camera2D
var hud: Hud
var inventory_panel: InventoryPanel
var pause_menu: PauseMenu
var balloon: DialogueBalloon
var shop_panel: ShopPanel
var residents_panel: ResidentsPanel
var board_panel: BoardPanel
var lamp_panel: LampPanel
var cook_panel: CookPanel
var ending_screen: EndingScreen
var weather_fx: WeatherFx
var fishing: FishingSession
var _fishing_view: FishingView
## 上一回看到的生命值（看是不是掉了）
var _health_seen := 0

var _tint: CanvasModulate
var _cursor: Sprite2D
var _sleeping := false
## 刚换完地图时玩家站在触发格上，要先走开才会再次触发
var _trigger_armed := false
var _use_needs_release := false
## 对话还没说完时又来了一段对话的请求（送礼之后的反应），等这一段说完接着播：[路径, 段落名]
var _next_dialogue: Array = []
## 对话里选定了结局，等这段对话说完就播
var _ending_due: StringName = &""
## 正在蓄力的动作，空表示没在蓄力
var _charge_action: StringName = &""
var _charge_t := 0.0
var _charge := 0
## 这次工具动作要作用的全部格子
var _act_tiles: Array[Vector2i] = []
## 蓄力时标出其余格子的光标，挂在 _cursor 下面
var _area_marks: Array[Sprite2D] = []
## 武器的连段数到第几下；这一下是不是蓄力技；一下打完使用键还没松（接着按住就是蓄力）
var _combo := Combo.new()
var _attack_step := 0
var _attack_skill := false
var _attack_held := false
var _skill_ready := false
## 上一下还没挥完就又按了一次：挥完马上接下一下
var _attack_queued := false


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("1a1420"))
	_tint = CanvasModulate.new()
	add_child(_tint)

	player = Player.new()
	player.acted.connect(_on_player_acted)
	player.stepped.connect(_on_player_stepped)
	camera = Camera2D.new()
	camera.position = Vector2(0, -10)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	player.add_child(camera)

	_cursor = Sprite2D.new()
	_cursor.texture = Px.tex(PixelArt.cursor())
	_cursor.z_index = -7
	for i in 8:
		var mark := Sprite2D.new()
		mark.texture = _cursor.texture
		mark.visible = false
		_cursor.add_child(mark)
		_area_marks.append(mark)

	Animals.nectar = RanchLink.nectar
	weather_fx = WeatherFx.new()
	add_child(weather_fx)
	_fishing_view = FishingView.new()
	fishing = FishingSession.new()
	fishing.player = player
	fishing.view = _fishing_view
	fishing.finished.connect(_on_fishing_finished)
	add_child(fishing)
	hud = Hud.new()
	add_child(hud)
	shop_panel = ShopPanel.new()
	add_child(shop_panel)
	inventory_panel = InventoryPanel.new()
	add_child(inventory_panel)
	residents_panel = ResidentsPanel.new()
	add_child(residents_panel)
	board_panel = BoardPanel.new()
	add_child(board_panel)
	lamp_panel = LampPanel.new()
	lamp_panel.lit.connect(_on_lamp_lit)
	add_child(lamp_panel)
	cook_panel = CookPanel.new()
	add_child(cook_panel)
	ending_screen = EndingScreen.new()
	add_child(ending_screen)
	balloon = DialogueBalloon.new()
	balloon.finished.connect(_on_dialogue_finished)
	add_child(balloon)
	pause_menu = PauseMenu.new()
	pause_menu.title_requested.connect(_on_title_requested)
	add_child(pause_menu)

	EventBus.screen_shake_requested.connect(_shake)
	EventBus.sleep_requested.connect(_sleep.bind(false))
	EventBus.dialogue_requested.connect(_on_dialogue_requested)
	EventBus.shop_requested.connect(_on_shop_requested)
	EventBus.board_requested.connect(_on_board_requested)
	EventBus.lamp_requested.connect(_on_lamp_requested)
	EventBus.cook_requested.connect(_on_cook_requested)
	EventBus.ending_requested.connect(_on_ending_requested)
	GameClock.day_ran_out.connect(_sleep.bind(true))
	GameState.knocked_out.connect(_faint)
	GameState.health_changed.connect(_on_health_changed)
	_health_seen = GameState.health
	SceneRouter.map_change_requested.connect(_load_map)
	get_viewport().size_changed.connect(_fit_camera)

	_load_map(GameState.map_id, GameState.spawn)
	_update_tint()


func _exit_tree() -> void:
	GameClock.running = false


func _process(delta: float) -> void:
	var locked := is_locked()
	GameClock.running = not locked
	player.input_enabled = not locked and not map.cutscene and _charge_action == &""
	_update_tint()
	_update_cursor(locked or map.cutscene or fishing.active())
	if locked or map.cutscene:
		# 关掉菜单或对话的那一下按键不能同时算作一次使用
		_use_needs_release = true
		_charge_action = &""
		return
	_combo.tick(delta)
	if fishing.active():
		fishing.update(delta)
		return
	if _charge_action != &"":
		_update_charge(delta)
		return
	_check_trigger()
	if Input.is_action_just_pressed(&"roll"):
		_try_roll()
	if _attack_queued and not player.is_acting():
		_attack_queued = false
		_attack_held = false
		_try_use()
	elif not Input.is_action_pressed(&"use"):
		_use_needs_release = false
		_attack_held = false
	elif not _use_needs_release:
		_try_use()


func _unhandled_input(event: InputEvent) -> void:
	if is_locked():
		return
	if event.is_action_pressed(&"pause"):
		_open_modal()
		pause_menu.open()
	elif event.is_action_pressed(&"inventory"):
		_open_modal()
		Audio.play("select", 0.0, -6.0)
		inventory_panel.open()
	elif event.is_action_pressed(&"residents"):
		_open_modal()
		Audio.play("select", 0.0, -6.0)
		residents_panel.open()
	elif event.is_action_pressed(&"music"):
		Audio.toggle_music()
	else:
		for i in GameState.HOTBAR_SIZE:
			if event.is_action_pressed("slot%d" % (i + 1)):
				_select(i)
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_select(GameState.selected_slot + 1)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_select(GameState.selected_slot - 1)


## 有菜单、对话或转场时，玩家不能动，时间也不走。
func is_locked() -> bool:
	return _sleeping or SceneRouter.busy or inventory_panel.is_open() or pause_menu.is_open() \
		or balloon.is_open() or shop_panel.is_open() or residents_panel.is_open() \
		or board_panel.is_open() or lamp_panel.is_open() or cook_panel.is_open()


func _open_modal() -> void:
	player.halt()


func _select(slot: int) -> void:
	var before := GameState.selected_slot
	GameState.selected_slot = slot
	if GameState.selected_slot != before:
		Audio.play("select", 0.0, -6.0)


# ---------------------------------------------------------------- 地图

func _load_map(map_id: StringName, spawn: StringName) -> void:
	if map != null:
		fishing.cancel()
		if player.get_parent() != null:
			player.get_parent().remove_child(player)
		if _cursor.get_parent() != null:
			_cursor.get_parent().remove_child(_cursor)
		if _fishing_view.get_parent() != null:
			_fishing_view.get_parent().remove_child(_fishing_view)
		map.queue_free()
		map = null
	var path: String = SceneRouter.MAPS.get(map_id, "")
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("找不到地图：%s" % map_id)
		return
	map = scene.instantiate() as GameMap
	add_child(map)
	move_child(map, 0)
	map.add_child(_cursor)
	map.add_child(_fishing_view)
	fishing.map = map
	map.entities.add_child(player)
	player.map = map
	map.player = player
	player.place(map.spawn_position(spawn), map.spawn_facing(spawn))
	GameState.map_id = map_id
	GameState.spawn = spawn
	_trigger_armed = false
	_fit_camera()
	_update_tint()
	map.entered()


## 镜头不超出地图；地图比屏幕小时居中显示。
func _fit_camera() -> void:
	if map == null:
		return
	var view := get_viewport_rect().size
	var size := map.size_px()
	var pad_x := maxi(0, ceili((view.x - size.x) / 2.0))
	var pad_y := maxi(0, ceili((view.y - size.y) / 2.0))
	camera.limit_left = -pad_x
	camera.limit_right = size.x + pad_x
	camera.limit_top = -pad_y
	camera.limit_bottom = size.y + pad_y
	camera.reset_smoothing()


func _check_trigger() -> void:
	var target := map.trigger_at(GameMap.tile_of(player.position))
	if target.is_empty():
		_trigger_armed = true
		return
	if not _trigger_armed:
		return
	_trigger_armed = false
	player.halt()
	var to_map: StringName = target["map"]
	var to_spawn: StringName = target["spawn"]
	Audio.play("select", 0.0, -8.0)
	SceneRouter.travel(to_map, to_spawn)


# ---------------------------------------------------------------- 使用与动作

func _try_use() -> void:
	if player.is_acting():
		if map.combat and Input.is_action_just_pressed(&"use"):
			_attack_queued = true
		return
	var just := Input.is_action_just_pressed(&"use")
	var item := GameState.selected_item()
	var tile := player.target_tile()
	var action := map.query_use(item, tile, player.facing)
	if action == &"attack":
		_try_attack(item, tile)
		return
	if action == &"":
		if just and item != null and item.kind == &"food":
			_eat(item)
		elif just and item != null and item.kind == &"accessory":
			# 饰品：拿在手里按一下戴上，再按一下摘下
			var said := Mine.toggle_accessory(item.id)
			if said != "":
				EventBus.banner_requested.emit(said)
				Audio.play("select", 0.0, -4.0)
		elif just and item != null and map.use_item(item):
			pass
		elif just:
			Audio.play("deny", 0.0, -4.0)
		return
	if action == &"interact":
		# 交互要重新按一次，不然按住不放会在对话结束后立刻再触发
		if just:
			player.halt()
			map.perform(action, item, tile)
		return
	var cost := _energy_cost(action, 0)
	if GameState.energy < cost:
		if just:
			EventBus.banner_requested.emit("太累了，回去睡一觉吧")
			Audio.play("deny", 0.0, -4.0)
		return
	# 牵着牛：一锄头开一整行，不用蓄力
	if action == &"hoe":
		var row := map.plow_row(tile, player.facing)
		if row.size() > 1:
			GameState.spend_energy(cost)
			_act_tiles = row
			map.plowed()
			player.start_action(action, tile)
			return
	# 升过级的锄头和水壶：按住蓄力，松开才动手
	if item != null and (action == &"hoe" or action == &"water") and GameState.tool_level(item.id) > 0:
		_charge_action = action
		_charge_t = 0.0
		_charge = 0
		player.halt()
		return
	GameState.spend_energy(cost)
	_act_tiles = [tile]
	player.start_action(action, tile)


## 拿着武器按使用键：挥一下。一下一下按是连段；按住不松，这一下打完就开始蓄力。
func _try_attack(item: ItemDef, tile: Vector2i) -> void:
	var weapon := Database.weapon(item.id)
	if weapon == null or player.is_rolling():
		return
	if _attack_held:
		_charge_action = &"attack"
		_charge_t = 0.0
		_skill_ready = false
		player.halt()
		return
	_attack_held = true
	_attack_step = _combo.advance(weapon.combo_len())
	_attack_skill = false
	Audio.play("swing", 0.1, -6.0)
	player.start_action(weapon.anim(), tile, weapon.speed())


## 按住武器蓄力：蓄够了松手放蓄力技，没蓄够松手什么都不发生；蓄力时按翻滚直接滚开。
func _update_skill_charge(delta: float) -> void:
	var item := GameState.selected_item()
	var weapon := Database.weapon(item.id) if item != null else null
	if weapon == null or not map.combat:
		_charge_action = &""
		return
	if Input.is_action_just_pressed(&"roll"):
		_charge_action = &""
		_try_roll()
		return
	if Input.is_action_pressed(&"use"):
		_charge_t += delta
		if not _skill_ready and _charge_t >= SKILL_CHARGE and GameState.energy >= SKILL_COST:
			_skill_ready = true
			Audio.play("select", 0.0, -4.0)
			Fx.burst(map, player.position + Vector2(0, -14), Color(1.0, 0.95, 0.6, 0.9), 6, 30.0, 0.3, -10.0)
		return
	_charge_action = &""
	_attack_held = false
	if not _skill_ready:
		if _charge_t >= SKILL_CHARGE:
			EventBus.banner_requested.emit("太累了，使不出这一下")
		return
	_skill_ready = false
	GameState.spend_energy(SKILL_COST)
	_attack_skill = true
	_combo.reset()
	Audio.play("swing", 0.1, -3.0)
	player.start_action(weapon.anim(), player.target_tile(), weapon.speed())


## 翻滚：只在井里能滚，花体力，滚的这一小段打不着。按着方向就朝那边滚，没按就朝面前滚。
func _try_roll() -> void:
	if not map.combat or player.state != Player.State.FREE:
		return
	if GameState.energy < ROLL_COST:
		EventBus.banner_requested.emit("太累了，滚不动了")
		Audio.play("deny", 0.0, -4.0)
		return
	var dir := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if dir.length() < 0.1:
		dir = Player.DIR_VECTORS[player.facing]
	if player.roll(dir):
		GameState.spend_energy(ROLL_COST)
		Audio.play("roll", 0.1, -8.0)


## 吃掉手里的这份食物。
func _eat(item: ItemDef) -> void:
	var text := GameState.eat(item)
	_use_needs_release = true
	if text == "":
		EventBus.banner_requested.emit("现在不饿")
		Audio.play("deny", 0.0, -4.0)
		return
	GameState.inventory.remove_at(GameState.selected_slot, 1)
	Audio.play("harvest", 0.0, -4.0)
	EventBus.banner_requested.emit(text)


## 用一次工具的体力：蓄力每多一档多花一份。
func _energy_cost(action: StringName, charge: int) -> int:
	var cost: int = ENERGY_COST.get(action, 0)
	if action == &"mine":
		cost = Mine.pick_cost(cost)
	# 吃饱了干活省力：减半，至少 1
	if cost > 1 and GameState.buff_active(&"hearty"):
		cost = maxi(1, cost / 2)
	# 立春：开垦荒地体力消耗减半
	if action == &"hoe" and GameClock.term_id() == &"lichun":
		cost = maxi(1, cost / 2)
	return cost * (charge + 1)


## 体力够用的前提下，这次蓄力最高到几档。
func _charge_limit() -> int:
	var item := GameState.selected_item()
	var limit := GameState.tool_level(item.id) if item != null else 0
	while limit > 0 and GameState.energy < _energy_cost(_charge_action, limit):
		limit -= 1
	return limit


func _update_charge(delta: float) -> void:
	if _charge_action == &"attack":
		_update_skill_charge(delta)
		return
	var item := GameState.selected_item()
	if item == null or map.query_use(item, player.target_tile(), player.facing) != _charge_action:
		_charge_action = &""
		return
	if Input.is_action_pressed(&"use"):
		_charge_t += delta
		var level := mini(_charge_limit(), int(_charge_t / CHARGE_STEP))
		if level > _charge:
			Audio.play("select", 0.0, -8.0)
		_charge = level
		return
	var action := _charge_action
	_charge_action = &""
	GameState.spend_energy(_energy_cost(action, _charge))
	_act_tiles = ToolArea.tiles(player.target_tile(), player.facing, _charge)
	player.start_action(action, _act_tiles[0])


func _on_player_acted(action: StringName, tile: Vector2i) -> void:
	if action == &"cast":
		_act_tiles = []
		fishing.begin(tile, map.fishing_water(tile))
		return
	var item := GameState.selected_item()
	if action == &"slash" or action == &"stab" or action == &"smash":
		# 武器挥到了：打到谁由地图算
		_act_tiles = []
		var weapon := Database.weapon(item.id) if item != null else null
		if weapon != null and map.has_method(&"weapon_hit"):
			map.call(&"weapon_hit", weapon, _attack_step, _attack_skill)
		_attack_skill = false
		return
	var tiles := _act_tiles
	_act_tiles = []
	if tiles.is_empty() or tiles[0] != tile:
		tiles = [tile]
	for i in tiles.size():
		map.perform(action, item, tiles[i], i > 0)


## 钓着鱼挨了打：竿脱手，这一竿作废。
func _on_health_changed() -> void:
	var dropped := GameState.health < _health_seen
	_health_seen = GameState.health
	if dropped and GameState.health > 0 and fishing != null and fishing.active():
		fishing.cancel()
		EventBus.banner_requested.emit("挨了一下，竿脱手了")


## 收竿以后按着的使用键不算新的一次甩竿。
func _on_fishing_finished() -> void:
	_use_needs_release = true


func _on_player_stepped() -> void:
	Audio.play("step", 0.2, -10.0)
	if not map.indoor:
		Fx.burst(map, player.position + Vector2(0, -1), Color(0.93, 0.87, 0.72, 0.7), 2, 14.0, 0.3, 30.0)


func _update_cursor(locked: bool) -> void:
	if locked or player.is_acting():
		_cursor.visible = false
		return
	for mark in _area_marks:
		mark.visible = false
	var tile := player.target_tile()
	_cursor.position = GameMap.tile_center(tile)
	# 室内只有面前有东西可以互动时才显示；拿着武器不用框出哪一格
	var use := map.query_use(GameState.selected_item(), tile, player.facing)
	_cursor.visible = use != &"attack" and (not map.indoor or use != &"")
	var area: Array[Vector2i] = []
	if _charge_action != &"":
		area = ToolArea.tiles(tile, player.facing, _charge)
	for i in _area_marks.size():
		var mark := _area_marks[i]
		mark.visible = i + 1 < area.size()
		if mark.visible:
			mark.position = Vector2((area[i + 1] - tile) * GameMap.TS)


func _shake(amount: float) -> void:
	var tw := create_tween()
	tw.tween_property(camera, "offset", Vector2(0, amount), 0.04)
	tw.tween_property(camera, "offset", Vector2(0, -amount * 0.5), 0.05)
	tw.tween_property(camera, "offset", Vector2.ZERO, 0.06)


# ---------------------------------------------------------------- 时间

func _update_tint() -> void:
	if map == null:
		return
	var m := GameClock.minutes
	weather_fx.show_weather(&"" if map.indoor else Weather.today)
	var forced := map.forced_tint()
	if forced.a > 0.0:
		_tint.color = forced
		return
	if map.indoor:
		_tint.color = INDOOR_DAY.lerp(INDOOR_NIGHT, clampf((m - 1080.0) / 150.0, 0.0, 1.0))
		return
	var col: Color = TINTS[0][1]
	for i in range(TINTS.size() - 1):
		var a: Array = TINTS[i]
		var b: Array = TINTS[i + 1]
		var ta: float = a[0]
		var tb: float = b[0]
		if m >= ta and m <= tb:
			var ca: Color = a[1]
			var cb: Color = b[1]
			col = ca.lerp(cb, (m - ta) / (tb - ta))
			break
	var weather_tint: Color = WEATHER_TINTS.get(Weather.today, Color.WHITE)
	_tint.color = col * weather_tint


## 睡到第二天。passed_out 为真表示熬到凌晨两点撑不住了，醒来体力只有一半。
func _sleep(passed_out: bool) -> void:
	if _sleeping:
		return
	_sleeping = true
	fishing.cancel()
	player.halt()
	Audio.play("sleep", 0.0, -4.0)
	await SceneRouter.fade_out(0.6)
	GameClock.advance_day()
	GameState.energy = GameState.max_energy / 2 if passed_out else GameState.max_energy
	GameState.health = GameState.max_health
	_load_map(&"farmhouse", &"bed")
	if SaveSystem.current_slot >= 0:
		SaveSystem.save(SaveSystem.current_slot, GameState.save_meta())
	hud.show_banner(_morning_text())
	await get_tree().create_timer(0.5).timeout
	if not is_instance_valid(self):
		return
	await SceneRouter.fade_in(0.7)
	_sleeping = false


## 在井里生命掉到 0：晕倒，被人背回井口，这一趟得来的东西丢一半，醒来生命回一半、过去两个钟头。
func _faint() -> void:
	if _sleeping:
		return
	_sleeping = true
	_charge_action = &""
	fishing.cancel()
	player.halt()
	Audio.play("hurt", 0.0, -2.0)
	await SceneRouter.fade_out(0.6)
	var lost := Mine.faint()
	GameState.health = GameState.max_health / 2
	GameClock.minutes = minf(GameClock.minutes + FAINT_MINUTES, GameClock.DAY_END - 1.0)
	_load_map(&"wellhead", &"from_mine")
	hud.show_banner(_faint_text(lost))
	await get_tree().create_timer(0.5).timeout
	if not is_instance_valid(self):
		return
	await SceneRouter.fade_in(0.7)
	_sleeping = false


func _faint_text(lost: Dictionary[StringName, int]) -> String:
	var text := "醒来的时候躺在井口，不知道是谁把你背上来的"
	if Lamps.is_lit(&"well"):
		text = "醒来的时候躺在井口。老秦蹲在旁边：“背你上来的。下回自己走上来。”"
	var parts := PackedStringArray()
	for item: StringName in lost:
		parts.append("%s ×%d" % [Database.item(item).name, lost[item]])
	if not parts.is_empty():
		text += "\n路上丢了：" + "、".join(parts)
	return text


## 早上醒来时的提示：日期、节气、天气，以及昨天出货的收入。
func _morning_text() -> String:
	var text := "%s · %s · %s" % [GameClock.date_text(), GameClock.term_name(), Weather.today_text()]
	if GameClock.day_of_season() % GameClock.DAYS_PER_TERM == 1:
		var def := GameClock.term()
		if def != null and def.live:
			text += "\n%s：%s" % [def.name, def.note]
	var festival := Festivals.morning_note()
	if festival != "":
		text += "\n" + festival
	for note in Farming.morning_notes:
		text += "\n" + note
	for note in Animals.morning_notes:
		text += "\n" + note
	if Shipping.last_income > 0:
		text += "\n出货收入 %d 文" % Shipping.last_income
	return text


# ---------------------------------------------------------------- 界面

func _on_shop_requested(counter: StringName) -> void:
	if shop_panel.is_open():
		return
	player.halt()
	Audio.play("select", 0.0, -6.0)
	shop_panel.open(counter)


func _on_board_requested() -> void:
	if board_panel.is_open():
		return
	player.halt()
	Audio.play("select", 0.0, -6.0)
	board_panel.open()


func _on_cook_requested() -> void:
	if cook_panel.is_open():
		return
	player.halt()
	Audio.play("select", 0.0, -6.0)
	cook_panel.open()


func _on_lamp_requested(lamp_id: StringName) -> void:
	if lamp_panel.is_open():
		return
	player.halt()
	Audio.play("select", 0.0, -6.0)
	lamp_panel.open(lamp_id)


## 灯点亮了：地图换画面、放火光，然后一句旁白。
func _on_lamp_lit(lamp_id: StringName) -> void:
	player.halt()
	Audio.play("harvest", 0.0, -2.0)
	_shake(2.0)
	if map.has_method(&"on_lamp_lit"):
		map.call(&"on_lamp_lit", lamp_id)
	hud.show_banner(Database.lamp(lamp_id).lit_text)
	await get_tree().create_timer(1.6).timeout
	if not is_instance_valid(self) or GameState.map_id != Database.lamp(lamp_id).map:
		return
	EventBus.dialogue_requested.emit(Residents.COMMON_DIALOGUE, "lamp_" + String(lamp_id))


func _on_dialogue_requested(path: String, title: String) -> void:
	if balloon.is_open():
		_next_dialogue = [path, title]
		return
	player.halt()
	balloon.start(path, title)


func _on_dialogue_finished() -> void:
	if _next_dialogue.is_empty():
		if _ending_due != &"":
			var ending := _ending_due
			_ending_due = &""
			_play_ending(ending)
		return
	var path: String = _next_dialogue[0]
	var title: String = _next_dialogue[1]
	_next_dialogue = []
	balloon.start(path, title)


func _on_ending_requested(ending: StringName) -> void:
	_ending_due = ending


## 播结局：黑屏，铺上结局的画，对话框念旁白，亮出结局的名字；玩家按键以后睡到第二天早上，在屋里醒来，存档。
func _play_ending(ending: StringName) -> void:
	if _sleeping:
		return
	_sleeping = true
	_charge_action = &""
	fishing.cancel()
	player.halt()
	Audio.play("sleep", 0.0, -4.0)
	await SceneRouter.fade_out(1.0)
	ending_screen.open(ending)
	await SceneRouter.fade_in(1.0)
	balloon.start(Story.DIALOGUE, "end_" + String(ending))
	await balloon.finished
	if not is_instance_valid(self):
		return
	await ending_screen.show_title()
	await ending_screen.closed
	if not is_instance_valid(self):
		return
	await SceneRouter.fade_out(0.8)
	Mine.leave()
	GameClock.advance_day()
	GameState.energy = GameState.max_energy
	GameState.health = GameState.max_health
	_load_map(&"farmhouse", &"bed")
	ending_screen.close()
	if SaveSystem.current_slot >= 0:
		SaveSystem.save(SaveSystem.current_slot, GameState.save_meta())
	hud.show_banner(_morning_text())
	await get_tree().create_timer(0.5).timeout
	if not is_instance_valid(self):
		return
	await SceneRouter.fade_in(0.7)
	_sleeping = false


func _on_title_requested() -> void:
	SceneRouter.to_menu()
