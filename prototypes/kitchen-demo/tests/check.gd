extends SceneTree
## 独立试玩的规则与输入流程检查。带窗口加 -- --shots 时一起截图。

const Round := preload("res://cook_round.gd")
const Kitchen := preload("res://kitchen.tscn")
var failures := 0
var checks := 0
var game: Control


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _stove(order: int = 0) -> RefCounted:
	var pot := Round.new()
	pot.choose(order)
	for i in range(Round.CUTS):
		pot.cut()
	for i in range(Round.WHISKS):
		pot.whisk()
	return pot


func _tick(pot: RefCounted, seconds: float, toss: bool = false) -> void:
	for i in roundi(seconds * 60):
		if toss and i % 120 == 0:
			pot.toss()
		pot.step(1.0 / 60.0)


func _rules() -> void:
	var pot := Round.new()
	_check(not pot.add_egg() and not pot.finish(), "切配阶段不能下蛋或装盘")
	pot.choose(1)
	pot.cut()
	pot.choose(0)
	_check(pot.order == 1 and not pot.whisk(), "切配中途口味与工序都受到约束")
	pot = _stove()
	_tick(pot, 4)
	_check(is_equal_approx(pot.heat, 0.73) and pot.egg == 0.0, "锅可以空锅预热，未下锅的蛋不熟")
	pot.add_egg()
	_check(not pot.add_egg() and not pot.finish(), "同一份蛋不可重复下锅，两样齐了才能装盘")
	_tick(pot, 2)
	pot.add_tomato()
	pot.season_food()
	_tick(pot, 7.5, true)
	pot.finish()
	_check(pot.result["score"] >= 90, "嫩蛋多汁有可重复的高分做法")
	pot = _stove(1)
	pot.set_fire(3)
	_tick(pot, 5)
	pot.add_egg()
	_tick(pot, 0.5, true)
	pot.add_tomato()
	pot.season_food()
	pot.set_fire(2)
	_tick(pot, 10.75, true)
	pot.set_fire(0)
	var before: float = pot.egg
	_tick(pot, 0.5, true)
	_check(pot.egg > before and pot.heat < 0.70, "关火以后余热还能让蛋继续凝固")
	pot.finish()
	_check(pot.result["score"] >= 85, "预热、转中火和余热可以达到焦香的合口味评价")
	var scorched := _stove(1)
	scorched.set_fire(3)
	scorched.add_tomato()
	scorched.add_egg()
	for i in 4:
		scorched.season_food()
	_tick(scorched, 28)
	_check(scorched.salt == 3 and scorched.scorch > 0.75, "过量调味和不翻锅的焦底都进入状态")
	scorched.finish()
	_check(scorched.result["score"] < pot.result["score"], "评分区分干焦和收汁")
	pot = _stove()
	pot.add_egg()
	pot.add_tomato()
	pot.finish()
	_check(pot.result["score"] <= 49, "生蛋不能成为高分成品")


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)


func _point(at: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.position = at
	e.global_position = at
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	root.push_input(e, true)


func _motion(at: Vector2, held: bool = true) -> void:
	var e := InputEventMouseMotion.new()
	e.position = at
	e.global_position = at
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	root.push_input(e, true)


func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless" or not OS.get_cmdline_user_args().has("--shots"):
		return
	var dest := ProjectSettings.globalize_path("res://_preview")
	DirAccess.make_dir_recursive_absolute(dest)
	await process_frame
	await RenderingServer.frame_post_draw
	var saved := root.get_texture().get_image().save_png(dest.path_join(name + ".png"))
	_check(saved == OK, "截图已写入 " + name)


func _run() -> void:
	_rules()
	game = Kitchen.instantiate()
	root.add_child(game)
	await process_frame
	await _shot("01-切配")
	var center := Vector2(251, 408)
	_point(center, true)
	_motion(center + Vector2(65, 0), false)
	_check(game.pot.cuts == 0 and game.drag == &"", "没有按着左键时取消手势")
	_point(center, false)
	_point(center - Vector2(40, 0), true)
	for i in range(4):
		_motion(center + Vector2(40 if i % 2 == 0 else -40, 0))
	_point(center, false)
	_check(game.pot.phase == Round.Phase.WHISK, "拖动砧板横切四次进入打蛋")
	_point(center + Vector2(29, 0), true)
	_motion(center + Vector2(0, 29))
	_point(center + Vector2(0, 29), false)
	_check(game.pot.whisks == 1, "碗里划弧能打蛋")
	# 键盘和鼠标都走场景输入。固定模拟时间为火候检查提供可重复的结果。
	for i in range(Round.WHISKS - 1):
		_key(KEY_SPACE)
	_check(game.pot.phase == Round.Phase.STOVE, "空格打蛋后进入灶上")
	_tick(game.pot, 4.0)
	_point(Vector2(697, 349), true)
	_motion(Vector2(496, 378))
	_point(Vector2(496, 378), false)
	_check(game.pot.egg_in, "从备料区拖蛋液入锅")
	_tick(game.pot, 2)
	_key(KEY_W)
	_key(KEY_S)
	_tick(game.pot, 6.6, true)
	_key(KEY_SPACE)
	_tick(game.pot, 0.9)
	await _shot("02-翻炒")
	_key(KEY_ENTER)
	_check(game.pot.phase == Round.Phase.SERVED and game.best[0] >= 90, "回车装盘并更新本次最佳")
	await _shot("03-装盘")
	_key(KEY_ENTER)
	_check(game.pot.cuts == 0 and game.pot.fire == 0 and game.best[0] >= 90, "可开新锅，保留本次最佳成绩")
	if failures:
		print("KITCHEN FAIL ", failures, " / ", checks)
	else:
		print("KITCHEN PASS ", checks)
	game.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures else 0)
