extends Node
## 自动化流程：从标题画面开始真实地玩一遍，沿途截图并检查关键状态。
## 运行：godot --path . res://tests/flow/flow.tscn
## 截图在 _preview/ 下；全部通过时最后一行输出 FLOW PASS，否则 FLOW FAIL 并以非零码退出。
## 存档写在单独的目录，不会碰玩家的存档。

const SAVE_DIR := "user://flow_saves"
const CELL := 132

var is_runner := false

var _failures: PackedStringArray = []
var _checks := 0


func _ready() -> void:
	if is_runner:
		_run()
		return
	# 流程要跨场景存活，所以把真正干活的节点挂到根上，再离开本场景
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set(&"is_runner", true)
	runner.name = "FlowRunner"
	get_tree().root.add_child.call_deferred(runner)


func _run() -> void:
	SaveSystem.base_dir = SAVE_DIR
	for i in SaveSystem.SLOT_COUNT:
		SaveSystem.delete(i)
	Audio.music_on = true
	await SceneRouter.to_menu()
	await _wait(0.6)
	await _shot("01_menu")

	_check(Database.validate().is_empty(), "数据表校验通过")

	# ---- 新游戏
	var menu := get_tree().current_scene
	menu.call(&"start_new", 0)
	await _wait(1.6)
	var game := get_tree().current_scene
	_check(game != null and game.name == "Game", "进入游戏场景")
	var player: Player = game.get(&"player")
	await _shot("02_farm_start")
	_check(GameState.inventory.count_of(&"white_radish_seed") == 12, "开局有 12 颗种子")

	# ---- 走路
	Input.action_press(&"move_down")
	await _wait(0.4)
	await _strip(player, "walk_down", 8, 0.06)
	Input.action_release(&"move_down")
	Input.action_press(&"move_right")
	await _wait(0.4)
	await _strip(player, "walk_right", 8, 0.06)
	Input.action_release(&"move_right")
	Input.action_press(&"move_up")
	await _wait(0.3)
	await _strip(player, "walk_up", 8, 0.06)
	Input.action_release(&"move_up")
	Input.action_press(&"move_left")
	await _wait(0.3)
	await _strip(player, "walk_left", 8, 0.06)
	Input.action_release(&"move_left")
	await _wait(0.3)
	await _strip(player, "idle", 6, 0.12)

	# ---- 开垦、浇水、播种
	var field := Vector2i(20, 12)
	player.place(GameMap.tile_center(field + Vector2i(0, -1)), GameMap.Facing.DOWN)
	await _wait(0.4)
	_check(player.target_tile() == field, "面前的格子是目标格")
	GameState.selected_slot = 0
	var energy_before := GameState.energy
	Input.action_press(&"use")
	await _wait(0.05)
	Input.action_release(&"use")
	await _strip(player, "hoe_down", 8, 0.05)
	await _wait(0.4)
	_check(Farming.state.soil.has(field), "锄头开垦了土地")
	_check(GameState.energy < energy_before, "用锄头消耗体力")

	GameState.selected_slot = 1
	await _press(&"use")
	await _strip(player, "water_down", 7, 0.07)
	await _wait(0.4)
	_check(Farming.state.soil.get(field, false), "浇了水")

	GameState.selected_slot = 2
	await _press(&"use")
	await _wait(0.6)
	_check(Farming.state.crop_id_at(field) == &"white_radish", "种下了白萝卜")
	_check(GameState.inventory.count_of(&"white_radish_seed") == 11, "种子少了一颗")

	# 侧面的动作
	player.place(GameMap.tile_center(field + Vector2i(-1, 1)), GameMap.Facing.RIGHT)
	GameState.selected_slot = 0
	await _wait(0.2)
	await _press(&"use")
	await _strip(player, "hoe_right", 8, 0.05)
	await _wait(0.4)
	player.place(GameMap.tile_center(field + Vector2i(1, 1)), GameMap.Facing.LEFT)
	await _wait(0.2)
	await _press(&"use")
	await _strip(player, "hoe_left", 8, 0.05)
	await _wait(0.4)
	player.place(GameMap.tile_center(field + Vector2i(0, 3)), GameMap.Facing.UP)
	await _wait(0.2)
	await _press(&"use")
	await _strip(player, "hoe_up", 8, 0.05)
	await _wait(0.4)
	await _shot("03_field")

	# ---- 背包
	await _press(&"inventory")
	await _wait(0.2)
	_check(not GameClock.running, "打开背包时时间暂停")
	await _press(&"move_right")
	await _press(&"move_right")
	await _press(&"use")
	await _press(&"move_down")
	await _wait(0.1)
	await _shot("04_inventory")
	await _press(&"use")
	_check(GameState.inventory.id_at(10) == &"white_radish_seed", "背包里交换了位置")
	await _press(&"use")
	await _press(&"move_up")
	await _press(&"use")
	_check(GameState.inventory.id_at(2) == &"white_radish_seed", "又换回了物品栏")
	await _press(&"inventory")
	await _wait(0.2)
	_check(GameClock.running, "关闭背包后时间继续")

	# ---- 暂停
	await _press(&"pause")
	await _wait(0.2)
	await _shot("05_pause")
	await _press(&"pause")
	await _wait(0.2)

	# ---- 信箱对话
	player.place(GameMap.tile_center(Vector2i(10, 8)), GameMap.Facing.UP)
	await _wait(0.3)
	await _press(&"use")
	await _wait(1.2)
	await _shot("06_dialogue")
	var balloon: DialogueBalloon = game.get(&"balloon")
	_check(balloon.is_open(), "信箱打开了对话")
	for i in 40:
		if not balloon.is_open():
			break
		await _press(&"use")
		await _wait(0.12)
	_check(not balloon.is_open(), "对话能走到结束")

	# ---- 黄昏和夜晚
	GameClock.minutes = 1125.0
	await _wait(0.3)
	await _shot("07_dusk")
	GameClock.minutes = 1330.0
	player.place(GameMap.tile_center(Vector2i(9, 9)), GameMap.Facing.DOWN)
	await _wait(0.5)
	await _shot("08_night")

	# ---- 进屋
	player.place(GameMap.tile_center(Vector2i(8, 7)), GameMap.Facing.UP)
	await _wait(0.2)
	await _press(&"use")
	await _wait(1.0)
	_check(GameState.map_id == &"farmhouse", "从门进了屋")
	await _shot("09_farmhouse")
	Input.action_press(&"move_up")
	await _wait(0.5)
	Input.action_release(&"move_up")

	# ---- 桌子：带选项的对话
	player.place(GameMap.tile_center(Vector2i(7, 5)), GameMap.Facing.UP)
	await _wait(0.2)
	await _press(&"use")
	await _wait(0.8)
	for i in 3:
		await _press(&"use")
		await _wait(0.5)
	await _shot("10_choices")
	await _press(&"ui_accept")
	await _wait(0.3)
	for i in 6:
		if not balloon.is_open():
			break
		await _press(&"use")
		await _wait(0.12)
	_check(not balloon.is_open(), "带选项的对话能结束")

	# ---- 睡觉
	player.place(GameMap.tile_center(Vector2i(2, 3)), GameMap.Facing.LEFT)
	await _wait(0.2)
	await _press(&"use")
	await _wait(0.6)
	await _press(&"use")
	await _wait(0.3)
	await _shot("11_bed_prompt")
	await _press(&"ui_accept")
	await _wait(2.6)
	_check(GameClock.day == 2, "睡到了第 2 天")
	_check(SaveSystem.has_save(0), "睡觉时写了存档")
	_check(Farming.state.crop_days_at(field) == 1, "浇过水的作物长了一天")
	_check(not Farming.state.soil.get(field, true), "过夜后土地变干")
	await _shot("12_day2")

	# ---- 出门
	Input.action_press(&"move_right")
	await _wait(0.75)
	Input.action_release(&"move_right")
	Input.action_press(&"move_down")
	await _wait(1.6)
	Input.action_release(&"move_down")
	await _wait(0.8)
	_check(GameState.map_id == &"farm", "走到门垫出了屋")
	await _shot("13_outside_day2")

	# ---- 让作物成熟并收获
	for i in 5:
		Farming.state.water(field)
		Farming.state.advance_day()
	_check(Farming.state.is_ripe(field), "浇够天数后成熟")
	player = game.get(&"player")
	player.place(GameMap.tile_center(field + Vector2i(0, -1)), GameMap.Facing.DOWN)
	await _wait(0.3)
	await _shot("14_ripe")
	await _press(&"use")
	await _strip(player, "harvest", 6, 0.06)
	await _wait(0.5)
	_check(GameState.inventory.count_of(&"white_radish") == 1, "收获了一个白萝卜")

	# ---- 回标题再读档：没睡觉的进度不保存
	await _until_idle()
	await SceneRouter.to_menu()
	await _until_idle()
	await _wait(0.5)
	await _shot("15_menu_with_save")
	menu = get_tree().current_scene
	_check(menu != null and menu.name == "MainMenu", "回到了标题画面")
	_check(not SceneRouter.busy, "回到标题后转场已经结束")
	menu.call(&"load_game", 0)
	await _wait(1.6)
	_check(GameClock.day == 2, "读档后是第 2 天")
	_check(GameState.map_id == &"farmhouse", "读档后在屋里醒来")
	_check(GameState.inventory.count_of(&"white_radish") == 0, "读档回到睡觉时的背包")
	_check(Farming.state.crop_id_at(field) == &"white_radish", "读档后作物还在")
	_check(Farming.state.soil.size() == 3, "读档后三块耕地都在")
	await _shot("16_loaded")

	for i in SaveSystem.SLOT_COUNT:
		SaveSystem.delete(i)
	if _failures.is_empty():
		print("FLOW PASS  %d checks" % _checks)
	else:
		print("FLOW FAIL  %d / %d" % [_failures.size(), _checks])
		for f in _failures:
			print("  - ", f)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_failures.append(what)
		print("CHECK FAILED: ", what)


## 等转场结束。转场进行中时 SceneRouter 会忽略新的切换请求。
func _until_idle() -> void:
	for i in 300:
		if not SceneRouter.busy:
			return
		await get_tree().process_frame


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


## 按一下再松开，中间隔几帧，让轮询和事件两种读法都能收到。
func _press(action: StringName) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	await _wait(0.06)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await _wait(0.06)


func _preview_dir() -> String:
	var dir := ProjectSettings.globalize_path("res://_preview")
	DirAccess.make_dir_recursive_absolute(dir)
	if not FileAccess.file_exists(dir + "/.gdignore"):
		var f := FileAccess.open(dir + "/.gdignore", FileAccess.WRITE)
		f.close()
	return dir


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_preview_dir() + "/shot_" + shot_name + ".png")


## 连拍若干帧，把角色周围的画面拼成一条，用来检查实际运行中的动作。
func _strip(target: Node2D, strip_name: String, count: int, interval: float) -> void:
	var out := Image.create(CELL * count, CELL, false, Image.FORMAT_RGBA8)
	for i in count:
		await RenderingServer.frame_post_draw
		if not is_instance_valid(target):
			return
		var img := get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		var k := img.get_width() / get_viewport().get_visible_rect().size.x
		var c: Vector2 = target.get_global_transform_with_canvas().origin * k
		var src := Rect2i(int(c.x) - CELL / 2, int(c.y) - CELL * 3 / 4, CELL, CELL)
		out.blit_rect(img, src, Vector2i(i * CELL, 0))
		await _wait(interval)
	out.save_png(_preview_dir() + "/strip_" + strip_name + ".png")
