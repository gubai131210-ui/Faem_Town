extends Node
## M9 第四批的带窗口短截图：换季名牌 + 对话头像的眨眼和嘴动。
## 运行：godot --path . res://tests/flow/shots_ui.tscn（弹窗约十几秒，跑完自己关）
## 产出：_preview/shot_season_card.png、shot_face.png（8×6 连拍）、shot_face_dialogue.png。
## 存档写在单独的目录，不会碰玩家的存档。

const SAVE_DIR := "user://shots_saves"
## 到点自己退出，免得脚本中途报错时窗口没人关
const TIMEOUT := 60.0
## 头像连拍：0.1 秒一帧共 4.8 秒。眨眼最长周期 4.1 秒、闭 0.13 秒，这个密度一定拍得到
const FACE_FRAMES := 48
const FACE_COLS := 8
const CELL := 72

var is_runner := false


func _ready() -> void:
	if is_runner:
		_watchdog()
		_run()
		return
	# 要跨场景存活，把真正干活的节点挂到根上，再离开本场景
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set(&"is_runner", true)
	runner.name = "ShotsRunner"
	get_tree().root.add_child.call_deferred(runner)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("SHOTS FAIL  这个脚本要带窗口跑：godot --path . res://tests/flow/shots_ui.tscn")
		Audio.quit_game(1)
		return
	seed(20260101)
	SaveSystem.base_dir = SAVE_DIR
	for i in SaveSystem.SLOT_COUNT:
		SaveSystem.delete(i)
	await SceneRouter.to_menu()
	await _wait(0.5)
	var menu := get_tree().current_scene
	menu.call(&"start_new", 0)
	await _wait(1.6)
	var game := get_tree().current_scene
	if game == null or game.name != "Game":
		print("SHOTS FAIL  没进入游戏场景")
		Audio.quit_game(1)
		return
	Weather.tomorrow = Weather.SUNNY

	# ---- 换季名牌：拨到春末睡一觉，走真实的 _sleep → season_first_day → 名牌 路径
	var hud: Hud = game.get(&"hud")
	var card: Control = hud.get(&"_season_card")
	var fade: ColorRect = SceneRouter.get(&"_fade")
	GameClock.day = 24
	game.call(&"_sleep", false)
	# 名牌等画面亮起来才发；等淡入走完、名牌还在停留窗口里再拍
	var seen := false
	var caught := false
	for i in 300:
		await _wait(0.03)
		if card.visible:
			seen = true
		if seen and fade.color.a < 0.05 and card.modulate.a > 0.95:
			caught = true
			break
	if not caught:
		# 载入慢错过了停留窗口：直接再亮一次，只为截图
		EventBus.season_card_requested.emit(UiMotion.season_card_text(
				GameClock.SEASON_NAMES[GameClock.season()], GameClock.term_name()))
		await _wait(0.6)
	await _shot("season_card")
	var label: Label = card.get_child(0)
	print("换季名牌「%s」%s" % [label.text, "实拍" if caught else "补拍"])
	# 名牌该自己收起来，不占着屏幕
	var hid := false
	for i in 100:
		await _wait(0.03)
		if not card.visible:
			hid = true
			break
	print("名牌自己收起了" if hid else "SHOTS WARN  名牌 3 秒还没收起")

	# ---- 头像：走真实的对话信号；第一段台词逐字时嘴动，说完等眨眼
	EventBus.dialogue_requested.emit("res://dialogue/ahe.dialogue", "memory_1")
	await _wait(0.3)
	var balloon: DialogueBalloon = game.get(&"balloon")
	var face_frame: Control = balloon.get(&"_face_frame")
	if not balloon.is_open() or not face_frame.visible:
		print("SHOTS FAIL  对话没开或头像没显示")
		Audio.quit_game(1)
		return
	var rows := ceili(float(FACE_FRAMES) / FACE_COLS)
	var grid := Image.create(FACE_COLS * CELL, rows * CELL, false, Image.FORMAT_RGBA8)
	for i in FACE_FRAMES:
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		var k := img.get_width() / get_viewport().get_visible_rect().size.x
		var pos := face_frame.global_position * k
		var cell := img.get_region(Rect2i(int(pos.x), int(pos.y), int(CELL * k), int(CELL * k)))
		cell.resize(CELL, CELL, Image.INTERPOLATE_NEAREST)
		grid.blit_rect(cell, Rect2i(0, 0, CELL, CELL), Vector2i((i % FACE_COLS) * CELL, (i / FACE_COLS) * CELL))
		await _wait(0.1)
	grid.save_png(_preview_dir() + "/shot_face.png")
	await _shot("face_dialogue")
	# 把这段对话说完收掉
	for i in 14:
		if not balloon.is_open():
			break
		await _press(&"use")
		await _wait(0.12)
	print("SHOTS DONE")
	Audio.quit_game(0)


func _watchdog() -> void:
	await get_tree().create_timer(TIMEOUT).timeout
	print("SHOTS TIMEOUT  跑了 %d 秒还没结束，多半是脚本中途报错了" % int(TIMEOUT))
	Audio.quit_game(2)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


## 按一下再松开，中间隔几帧，让轮询和事件两种读法都能收到。
func _press(action: StringName) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	await get_tree().process_frame
	await _wait(0.06)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)


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