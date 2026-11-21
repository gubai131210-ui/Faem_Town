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
## 从这一帧起算黄昏，跟着节气挪；天亮（360/480）和深夜（1560）两头不动
const DUSK_FROM := 1020.0
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
const ScenicScript := preload("res://maps/scenic.gd")
const CutsceneScript := preload("res://game/cutscene.gd")

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
var table_panel: TablePanel
var cook_show: CookShow
var ending_screen: EndingScreen
var cutscene: Node
var weather_fx: WeatherFx
var fishing: FishingSession
var _fishing_view: FishingView
## 上一回看到的生命值（看是不是掉了）
var _health_seen := 0

var _tint: CanvasModulate
var _cursor: Sprite2D
var _sleeping := false
## F9 跳去看节气之前的日子、天气和地图，Shift+F9 跳回来。空表示还没跳过。
var _look_back: Dictionary = {}
var _look_i := -1
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
	# 决策 120：视口偶尔会露出地图外一点边。原来用近黑的 1a1420，露出来是一块生硬的黑；
	# 改用 palette 的 e（深灰紫），仍是暗色、夜里不刺眼，但不再像纯黑洞。
	# 这是观感缓解，不是根治：露边的时机仍需带窗口取证确认。
	RenderingServer.set_default_clear_color(Palette.c("e"))
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
	table_panel = TablePanel.new()
	add_child(table_panel)
	cook_show = CookShow.new()
	add_child(cook_show)
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
	EventBus.cook_show_requested.connect(_on_cook_show_requested)
	EventBus.table_requested.connect(_on_table_requested)
	EventBus.feast_requested.connect(_on_feast_requested)
	EventBus.meal_requested.connect(_on_meal_requested)
	EventBus.ending_requested.connect(_on_ending_requested)
	EventBus.cutscene_replay_requested.connect(_on_cutscene_replay)
	GameClock.day_ran_out.connect(_sleep.bind(true))
	GameState.knocked_out.connect(_faint)
	GameState.health_changed.connect(_on_health_changed)
	_health_seen = GameState.health
	SceneRouter.map_change_requested.connect(_load_map)
	get_viewport().size_changed.connect(_fit_camera)

	cutscene = (load("res://game/cutscene_player.gd") as GDScript).new()
	cutscene.step_shown.connect(_on_cutscene_step)
	cutscene.finished.connect(_on_cutscene_finished)
	add_child(cutscene)
	_load_map(GameState.map_id, GameState.spawn)
	_update_tint()
	if _opening_due():
		cutscene.play(CutsceneScript.OPENING, CutsceneScript.opening_steps())


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
	if _debug_look(event):
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


## 调试运行里按 F9 轮流去四个节气看人和动物，Shift+F9 回到按之前的日子。正式版没有这个键。
## 跳过去之后睡觉会把这一天存下来，所以提示里写了别睡觉。
func _debug_look(event: InputEvent) -> bool:
	if not OS.is_debug_build():
		return false
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_F9:
		return false
	if key.shift_pressed:
		_look_restore()
	else:
		_look_next()
	get_viewport().set_input_as_handled()
	return true


func _look_next() -> void:
	if _look_back.is_empty():
		_look_back = {
			"day": GameClock.day,
			"minutes": GameClock.minutes,
			"today": Weather.today,
			"yesterday": Weather.yesterday,
			"wet": Weather.wet,
			"map": GameState.map_id,
			"spawn": GameState.spawn,
		}
	_look_i = (_look_i + 1) % GameClock.LOOK_STOPS.size()
	_look_apply(GameClock.LOOK_STOPS[_look_i])


func _look_restore() -> void:
	if _look_back.is_empty():
		hud.show_banner("还没跳过节气")
		return
	var back := _look_back
	back["text"] = "回到原来的日子"
	_look_back = {}
	_look_i = -1
	_look_apply(back)


func _look_apply(stop: Dictionary) -> void:
	Weather.today = stop.get("today", Weather.SUNNY)
	Weather.yesterday = stop.get("yesterday", Weather.SUNNY)
	Weather.wet = float(stop.get("wet", 0.0))
	GameClock.day = int(stop["day"])
	GameClock.minutes = float(stop["minutes"])
	GameClock.time_changed.emit()
	if bool(stop.get("hay", false)) and GameState.inventory.count_of(&"hay") == 0:
		GameState.inventory.add(&"hay", 4)
	hud.show_banner(str(stop.get("text", GameClock.term_name())))
	_load_map(stop["map"], stop["spawn"])


## 有菜单、对话或转场时，玩家不能动，时间也不走。
func is_locked() -> bool:
	return _sleeping or SceneRouter.busy or inventory_panel.is_open() or pause_menu.is_open() \
		or balloon.is_open() or shop_panel.is_open() or residents_panel.is_open() \
		or board_panel.is_open() or lamp_panel.is_open() or cook_panel.is_open() \
		or table_panel.is_open() or cook_show.is_open() \
		or _cutscene_on()


func _cutscene_on() -> bool:
	return cutscene != null and bool(cutscene.get(&"playing"))


## 新游戏第一天、人还在农场门口、这段没看过，才演开场。人已经出门或读到别的地图，不补演。
func _opening_due() -> bool:
	if GameState.has_flag(CutsceneScript.seen_flag(CutsceneScript.OPENING)):
		return false
	return GameClock.day == 1 and GameState.map_id == &"farm"


func _open_modal() -> void:
	player.halt()


func _select(slot: int) -> void:
	var before := GameState.selected_slot
	GameState.selected_slot = slot
	if GameState.selected_slot != before:
		Audio.play("select", 0.0, -6.0)


# ---------------------------------------------------------------- 地图

func _load_map(map_id: StringName, spawn: StringName) -> void:
	# 换地图时把没演完的过场跳过。它下一帧才收尾，新地图上同一次进入不再另起一段。
	if cutscene != null and bool(cutscene.get(&"playing")):
		cutscene.call(&"skip")
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
	_play_mine_arrival()
	_play_festival_opening()


## 镜头不超出地图；地图比屏幕小时居中显示。
## Camera2D 的 limit_* 夹的是视口边缘（世界坐标），所以直接给地图边界即可；
## 地图比视口小的那一边加 pad，让多出来的视口对称居中。
## 决策 120 曾误当成「夹镜头中心」改过一次，会让镜头滚不到地图边缘、室内错位，已撤回。
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
	if Bestiary.beside(map, tile):
		action = &"interact"
	if action == &"attack":
		_try_attack(item, tile)
		return
	if action == &"":
		if just and item != null and item.kind == &"food":
			_eat(item)
		elif just and item != null and Crafting.is_scrap(item.id):
			var said := Crafting.read_scrap(item.id)
			if said != "":
				EventBus.banner_requested.emit(said)
				Audio.play("deny" if said.begins_with("只有") else "select", 0.0, -4.0)
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
			if Bestiary.beside(map, tile):
				var said := Bestiary.greet_out(map.map_id)
				if said != "":
					EventBus.banner_requested.emit(said)
				return
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


## 翻滚：井里、竹海、后山和雾岛能滚，花体力，滚的这一小段打不着。按着方向就朝那边滚，没按就朝面前滚。
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
	var text := GameState.eat(item, GameState.inventory.term_at(GameState.selected_slot))
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
	var spent := GameState.tool_cost(cost, action, charge, GameClock.term_id(), GameState.buff_active(&"hearty"))
	var cut := Livelihood.energy_cut(action)
	if cut <= 0:
		return spent
	return maxi(0 if action == &"cast" else 1, spent - cut)


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
	if Bestiary.beside(map, tile):
		use = &"interact"
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
		Audio.ambience("")
		return
	var m := GameClock.minutes
	var shift := GameClock.dusk_shift()
	weather_fx.show_weather(&"" if map.indoor else Weather.today)
	Audio.ambience(_ambience_for())
	var forced := map.forced_tint()
	if forced.a > 0.0:
		_tint.color = forced
		return
	if map.indoor:
		_tint.color = INDOOR_DAY.lerp(INDOOR_NIGHT, clampf((m - shift - 1080.0) / 150.0, 0.0, 1.0))
		return
	var col: Color = TINTS[0][1]
	for i in range(TINTS.size() - 1):
		var a: Array = TINTS[i]
		var b: Array = TINTS[i + 1]
		var ta := _dusk_key(float(a[0]), shift)
		var tb := _dusk_key(float(b[0]), shift)
		if m >= ta and m <= tb:
			var ca: Color = a[1]
			var cb: Color = b[1]
			col = ca.lerp(cb, (m - ta) / (tb - ta))
			break
	var weather_tint: Color = WEATHER_TINTS.get(Weather.today, Color.WHITE)
	_tint.color = col * weather_tint


## 黄昏的关键帧跟着节气挪，天亮和深夜两头不动（夏至夜最短、冬至夜最长）。
static func _dusk_key(t: float, shift: float) -> float:
	return t + shift if t >= DUSK_FROM and t < GameClock.DAY_END else t


## 室外的底噪。雨声盖过海浪；进了屋子就静下来。
func _ambience_for() -> String:
	if map == null or map.indoor:
		return ""
	if Weather.today == Weather.RAIN or Weather.today == Weather.STORM:
		return "rain"
	if map.map_id == &"dongtan":
		return "waves"
	if ScenicScript.cicada(GameClock.season_id(), Weather.today, false, GameClock.minutes):
		return "cicada"
	return ""


## 睡到第二天。passed_out 为真表示熬到凌晨两点撑不住了，醒来体力只有一半。
func _sleep(passed_out: bool) -> void:
	if _sleeping:
		return
	_sleeping = true
	fishing.cancel()
	player.halt()
	Audio.play("sleep", 0.0, -4.0)
	await SceneRouter.fade_out(0.6)
	var prev_day := GameClock.day
	GameClock.advance_day()
	GameState.energy = GameState.max_energy / 2 if passed_out else GameState.max_energy
	GameState.health = GameState.max_health
	_load_map(&"farmhouse", &"bed")
	_play_new_year_dawn(prev_day)
	if SaveSystem.current_slot >= 0:
		SaveSystem.save(SaveSystem.current_slot, GameState.save_meta())
	hud.show_banner(_morning_text())
	await get_tree().create_timer(0.5).timeout
	if not is_instance_valid(self):
		return
	await SceneRouter.fade_in(0.7)
	if not is_instance_valid(self):
		return
	# 换季名牌等画面亮了再亮。黑屏和淡入这段如果也算进 2.4 秒，醒来时名牌已经在淡，像一层字铺在地板上
	if UiMotion.season_first_day(prev_day, GameClock.day):
		EventBus.season_card_requested.emit(UiMotion.season_card_text(
				GameClock.SEASON_NAMES[GameClock.season()], GameClock.term_name()))
	_sleeping = false


## 在井里生命掉到 0：晕倒，被人背回井口，这一趟得来的东西丢一半，醒来生命回一半、过去两个钟头。
func _faint() -> void:
	if _sleeping:
		return
	if GameState.map_id == &"zhuhai":
		await _faint_outdoors(&"zhuhai", &"bridge", "醒来的时候还在竹林边上。刚才那一下是真的。")
		return
	if GameState.map_id == &"houshan":
		await _faint_outdoors(&"houshan", &"slope", "醒来的时候还在山路上。雷声远了。")
		return
	if GameState.map_id == &"wudao":
		await _faint_outdoors(&"wudao", &"landing", "醒来的时候还在岛边上。潮声近了。")
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


## 竹海里被打散：醒来还在林子边上，不回井口，也不丢井里的东西。
func _faint_outdoors(map_id: StringName, spawn: StringName, text: String) -> void:
	_sleeping = true
	_charge_action = &""
	fishing.cancel()
	player.halt()
	Audio.play("hurt", 0.0, -2.0)
	await SceneRouter.fade_out(0.6)
	GameState.health = GameState.max_health / 2
	GameClock.minutes = minf(GameClock.minutes + FAINT_MINUTES, GameClock.DAY_END - 1.0)
	_load_map(map_id, spawn)
	hud.show_banner(text)
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
	if Home.morning_note != "":
		text += "\n" + Home.morning_note
	if Shipping.last_income > 0:
		text += "\n出货收入 %d 文" % Shipping.last_income
	var journal := Journal.morning_line()
	if journal != "":
		text += "\n" + journal
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


func _on_cook_show_requested(id: StringName) -> void:
	cook_show.open(id)


func _on_table_requested() -> void:
	if table_panel.is_open():
		return
	player.halt()
	Audio.play("select", 0.0, -6.0)
	table_panel.open()


func _on_feast_requested() -> void:
	if not Crafting.feast_ready() or _cutscene_on():
		return
	Crafting.clear_table()
	player.halt()
	cutscene.play(&"feast_banquet", CutsceneScript.feast_steps())


func _on_meal_requested(people: Array, dishes: Array, lines: Array) -> void:
	if _cutscene_on() or lines.is_empty():
		return
	player.halt()
	var line := str(lines[0])
	for entry: Variant in lines:
		var text := str(entry)
		if text.contains("她说") or text.contains("他说"):
			line = text
	cutscene.play(&"table_meal", CutsceneScript.guest_steps(people, dishes, line))


func _on_lamp_requested(lamp_id: StringName) -> void:
	if lamp_panel.is_open():
		return
	player.halt()
	Audio.play("select", 0.0, -6.0)
	lamp_panel.open(lamp_id)


var _lamp_focus := Vector2.INF
var _look_tween: Tween


## 灯点亮了：镜头抬向灯，雾往外退，再落回玩家，然后原来的那段旁白。
func _on_lamp_lit(lamp_id: StringName) -> void:
	player.halt()
	Audio.play("harvest", 0.0, -2.0)
	_shake(2.0)
	if map.has_method(&"on_lamp_lit"):
		map.call(&"on_lamp_lit", lamp_id)
	_lamp_focus = player.global_position
	if map.has_method(&"lamp_focus"):
		var at: Vector2 = map.call(&"lamp_focus", lamp_id)
		if at.is_finite():
			_lamp_focus = at
	var steps := CutsceneScript.lamp_steps(Database.lamp(lamp_id).lit_text)
	cutscene.play(CutsceneScript.lamp_id(lamp_id), steps)
	await cutscene.finished
	if not is_instance_valid(self) or GameState.map_id != Database.lamp(lamp_id).map:
		return
	EventBus.dialogue_requested.emit(Residents.COMMON_DIALOGUE, "lamp_" + String(lamp_id))


func _on_cutscene_step(step: Dictionary) -> void:
	var look := StringName(step.get("look", &""))
	if look == &"lamp":
		_glide_camera(CutsceneScript.look_offset(player.global_position, _lamp_focus), 0.9)
	elif look == &"player":
		_glide_camera(Vector2(0, -10), 0.45)


func _on_cutscene_finished() -> void:
	if _look_tween != null:
		_look_tween.kill()
	camera.position = Vector2(0, -10)
	camera.position_smoothing_enabled = true


func _glide_camera(to: Vector2, sec: float) -> void:
	if _look_tween != null:
		_look_tween.kill()
	camera.position_smoothing_enabled = false
	_look_tween = create_tween()
	_look_tween.tween_property(camera, "position", to, sec)
	_look_tween.tween_callback(func() -> void: camera.position_smoothing_enabled = true)


func _on_dialogue_requested(path: String, title: String) -> void:
	if balloon.is_open():
		_next_dialogue = [path, title]
		return
	player.halt()
	var memory := CutsceneScript.memory_scene(path, title)
	if not memory.is_empty() and not GameState.has_flag(CutsceneScript.seen_flag(memory["id"])):
		cutscene.play(memory["id"], memory["steps"])
		if bool(cutscene.get(&"playing")):
			await cutscene.finished
		if not is_instance_valid(self):
			return
	var beat := CutsceneScript.story_beat(path, title)
	if not beat.is_empty() and not GameState.has_flag(CutsceneScript.seen_flag(beat["id"])):
		if beat["id"] == &"confess" and not Residents.knows(&"bai", 40):
			beat = {}
		elif beat["id"] == &"key" and not Residents.can_hold(&"well_key"):
			beat = {}
	if not beat.is_empty() and not GameState.has_flag(CutsceneScript.seen_flag(beat["id"])):
		_aim_at_speaker()
		cutscene.play(beat["id"], CutsceneScript.beat_steps(beat["text"]))
		if bool(cutscene.get(&"playing")):
			await cutscene.finished
		if not is_instance_valid(self):
			return
	balloon.start(path, title)


## 镜头朝面前这个人（或白鹿）。没有就朝上看一截。
func _aim_at_speaker() -> void:
	_lamp_focus = player.global_position + Vector2(0, -28)
	if map != null and map.has_method(&"npc_at"):
		var npc: Node = map.call(&"npc_at", player.target_tile())
		if npc is Node2D:
			_lamp_focus = (npc as Node2D).global_position
	if map != null and map.get(&"_lan") is Node2D:
		var deer := map.get(&"_lan") as Node2D
		if deer.visible:
			_lamp_focus = deer.global_position


## 节日正开着、人进了场子、今年还没看过：黑边加一句，镜头朝场子中间。
func _play_festival_opening() -> void:
	if _cutscene_on() or map == null:
		return
	var id := Festivals.opening_id()
	var def := Festivals.today()
	if id == &"" or def == null or GameState.map_id != def.map:
		return
	if GameState.has_flag(CutsceneScript.seen_flag(id)):
		return
	var line := CutsceneScript.festival_line(def.id)
	if line == "":
		return
	_lamp_focus = map.tile_center(def.focus) if def.focus != FestivalDef.NO_TILE else player.global_position
	cutscene.play(id, CutsceneScript.festival_steps(line))


## 昨晚守了岁：醒来时在屋里停一下，说一句过年了。
func _play_new_year_dawn(prev_day: int) -> void:
	if _cutscene_on() or not GameState.has_flag(Festivals.flag("vigil", prev_day)):
		return
	var id := StringName("vigil_y%d" % Festivals.year_of(prev_day))
	if GameState.has_flag(CutsceneScript.seen_flag(id)):
		return
	cutscene.play(id, CutsceneScript.dawn_steps())


## 进井：头一回下到第 1 层，以及四个首领头一回出现，各演一下。
func _play_mine_arrival() -> void:
	if GameState.map_id != &"mine" or Mine.current == null or cutscene == null:
		return
	if bool(cutscene.get(&"playing")):
		return
	var floor: MineFloor = Mine.current
	if floor.floor_no == 1 and not GameState.has_flag(CutsceneScript.seen_flag(&"descent")):
		_lamp_focus = player.global_position + Vector2(0, -36)
		cutscene.play(&"descent", CutsceneScript.descent_steps())
		return
	if not floor.boss_alive():
		return
	var beat := CutsceneScript.boss_beat(floor.arena)
	if beat.is_empty() or GameState.has_flag(CutsceneScript.seen_flag(beat["id"])):
		return
	var boss: MineMonster = floor.boss
	_lamp_focus = boss.pos if boss != null else player.global_position
	cutscene.play(beat["id"], CutsceneScript.beat_steps(beat["text"]))


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


## 手账重看：把看过的步骤再演一遍。不改忆、节日和结局。
func _on_cutscene_replay(id: StringName) -> void:
	if cutscene == null or bool(cutscene.get(&"playing")):
		return
	var steps: Array = CutsceneScript.replay_steps(id)
	if steps.is_empty():
		return
	player.halt()
	cutscene.play(id, steps)


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
	if _cutscene_on():
		cutscene.skip()
		await cutscene.finished
	cutscene.play(StringName("ending_" + String(ending)), CutsceneScript.ending_steps(ending))
	await SceneRouter.fade_in(0.6)
	await cutscene.finished
	if not is_instance_valid(self):
		return
	ending_screen.open(ending)
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
