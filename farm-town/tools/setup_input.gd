extends SceneTree
## 一次性工具：把按键映射写进 project.godot。改了 ACTIONS 后重新运行：
##   godot --headless --path . -s tools/setup_input.gd

const ACTIONS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"use": [KEY_SPACE, KEY_J, KEY_Z],
	"inventory": [KEY_E, KEY_TAB, KEY_I],
	"pause": [KEY_ESCAPE],
	"music": [KEY_M],
	"slot1": [KEY_1], "slot2": [KEY_2], "slot3": [KEY_3], "slot4": [KEY_4],
	"slot5": [KEY_5], "slot6": [KEY_6], "slot7": [KEY_7], "slot8": [KEY_8],
}


func _init() -> void:
	for action: String in ACTIONS:
		var events: Array = []
		var keys: Array = ACTIONS[action]
		for k: Key in keys:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			events.append(ev)
		ProjectSettings.set_setting("input/" + action, {"deadzone": 0.5, "events": events})
	var err := ProjectSettings.save()
	if err != OK:
		push_error("写入 project.godot 失败：%s" % error_string(err))
	quit()
