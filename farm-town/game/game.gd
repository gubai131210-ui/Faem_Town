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
## 用一次工具消耗的体力
const ENERGY_COST: Dictionary[StringName, int] = {&"hoe": 2, &"water": 1}

var map: GameMap
var player: Player
var camera: Camera2D
var hud: Hud
var inventory_panel: InventoryPanel
var pause_menu: PauseMenu
var balloon: DialogueBalloon

var _tint: CanvasModulate
var _cursor: Sprite2D
var _sleeping := false
## 刚换完地图时玩家站在触发格上，要先走开才会再次触发
var _trigger_armed := false
var _use_needs_release := false


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

	hud = Hud.new()
	add_child(hud)
	inventory_panel = InventoryPanel.new()
	add_child(inventory_panel)
	balloon = DialogueBalloon.new()
	add_child(balloon)
	pause_menu = PauseMenu.new()
	pause_menu.title_requested.connect(_on_title_requested)
	add_child(pause_menu)

	EventBus.screen_shake_requested.connect(_shake)
	EventBus.sleep_requested.connect(_sleep.bind(false))
	EventBus.dialogue_requested.connect(_on_dialogue_requested)
	GameClock.day_ran_out.connect(_sleep.bind(true))
	SceneRouter.map_change_requested.connect(_load_map)
	get_viewport().size_changed.connect(_fit_camera)

	_load_map(GameState.map_id, GameState.spawn)
	_update_tint()


func _exit_tree() -> void:
	GameClock.running = false


func _process(_delta: float) -> void:
	var locked := is_locked()
	GameClock.running = not locked
	player.input_enabled = not locked
	_update_tint()
	_update_cursor(locked)
	if locked:
		# 关掉菜单或对话的那一下按键不能同时算作一次使用
		_use_needs_release = true
		return
	_check_trigger()
	if not Input.is_action_pressed(&"use"):
		_use_needs_release = false
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
	return _sleeping or SceneRouter.busy or inventory_panel.is_open() or pause_menu.is_open() or balloon.is_open()


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
		if player.get_parent() != null:
			player.get_parent().remove_child(player)
		if _cursor.get_parent() != null:
			_cursor.get_parent().remove_child(_cursor)
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
	map.entities.add_child(player)
	player.map = map
	player.place(map.spawn_position(spawn), map.spawn_facing(spawn))
	GameState.map_id = map_id
	GameState.spawn = spawn
	_trigger_armed = false
	_fit_camera()
	_update_tint()


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
		return
	var just := Input.is_action_just_pressed(&"use")
	var item := GameState.selected_item()
	var tile := player.target_tile()
	var action := map.query_use(item, tile, player.facing)
	if action == &"":
		if just:
			Audio.play("deny", 0.0, -4.0)
		return
	if action == &"interact":
		# 交互要重新按一次，不然按住不放会在对话结束后立刻再触发
		if just:
			player.halt()
			map.perform(action, item, tile)
		return
	var cost: int = ENERGY_COST.get(action, 0)
	if GameState.energy < cost:
		if just:
			EventBus.banner_requested.emit("太累了，回去睡一觉吧")
			Audio.play("deny", 0.0, -4.0)
		return
	GameState.spend_energy(cost)
	player.start_action(action, tile)


func _on_player_acted(action: StringName, tile: Vector2i) -> void:
	map.perform(action, GameState.selected_item(), tile)


func _on_player_stepped() -> void:
	Audio.play("step", 0.2, -10.0)
	if not map.indoor:
		Fx.burst(map, player.position + Vector2(0, -1), Color(0.93, 0.87, 0.72, 0.7), 2, 14.0, 0.3, 30.0)


func _update_cursor(locked: bool) -> void:
	if locked or player.is_acting():
		_cursor.visible = false
		return
	var tile := player.target_tile()
	_cursor.position = GameMap.tile_center(tile)
	# 室内只有面前有东西可以互动时才显示
	_cursor.visible = not map.indoor or map.query_use(GameState.selected_item(), tile, player.facing) != &""


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
	_tint.color = col


## 睡到第二天。passed_out 为真表示熬到凌晨两点撑不住了，醒来体力只有一半。
func _sleep(passed_out: bool) -> void:
	if _sleeping:
		return
	_sleeping = true
	player.halt()
	Audio.play("sleep", 0.0, -4.0)
	await SceneRouter.fade_out(0.6)
	GameClock.advance_day()
	GameState.energy = GameState.max_energy / 2 if passed_out else GameState.max_energy
	_load_map(&"farmhouse", &"bed")
	if SaveSystem.current_slot >= 0:
		SaveSystem.save(SaveSystem.current_slot, GameState.save_meta())
	hud.show_banner(GameClock.date_text())
	await get_tree().create_timer(0.5).timeout
	if not is_instance_valid(self):
		return
	await SceneRouter.fade_in(0.7)
	_sleeping = false


# ---------------------------------------------------------------- 界面

func _on_dialogue_requested(path: String, title: String) -> void:
	if balloon.is_open():
		return
	player.halt()
	balloon.start(path, title)


func _on_title_requested() -> void:
	SceneRouter.to_menu()
