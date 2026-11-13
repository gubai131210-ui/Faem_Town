class_name PauseMenu
extends CanvasLayer
## 暂停菜单，里面带一页按键说明。进度在睡觉时保存，所以这里没有单独的“保存”。

signal closed
signal title_requested

## 按键说明里的每一行：[干什么, 对应的输入动作]。键名从输入设置里现读，改了键位这里跟着变。
const KEY_ROWS: Array = [
	["走动", [&"move_up", &"move_left", &"move_down", &"move_right"]],
	["使用、搭话（按住蓄力）", [&"use"]],
	["翻滚（井里）", [&"roll"]],
	["换手里的东西", [&"slot1", &"slot8"]],
	["背包", [&"inventory"]],
	["名册和忆簿", [&"residents"]],
	["音乐开关", [&"music"]],
	["暂停", [&"pause"]],
]
## 键名换成更好认的写法
const KEY_NAMES: Dictionary[String, String] = {
	"Up": "↑", "Down": "↓", "Left": "←", "Right": "→",
	"Space": "空格", "Escape": "Esc",
}

var _root: Control
var _panel: Control
var _keys_panel: Control
var _resume: Button
var _music: Button
var _keys: Button
var _back: Button


func _ready() -> void:
	layer = 30
	_root = UiKit.root()
	add_child(_root)
	_root.add_child(UiKit.dim(0.55))

	_panel = UiKit.window()
	UiKit.center(_panel, Vector2(120, 134))
	_root.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 3)
	box.position = Vector2(12, 22)
	box.size = Vector2(96, 104)
	_panel.add_child(box)

	var head := UiKit.label("暂停", 8)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.position = Vector2(0, 5)
	head.size = Vector2(120, 12)
	_panel.add_child(head)
	_resume = UiKit.button("继续")
	_resume.pressed.connect(close)
	box.add_child(_resume)
	_keys = UiKit.button("按键说明")
	_keys.pressed.connect(show_keys)
	box.add_child(_keys)
	_music = UiKit.button("")
	_music.pressed.connect(_on_music_pressed)
	box.add_child(_music)
	var title := UiKit.button("回到标题")
	title.pressed.connect(_on_title_pressed)
	box.add_child(title)
	var quit := UiKit.button("退出游戏")
	quit.pressed.connect(_on_quit_pressed)
	box.add_child(quit)
	var note := UiKit.label("睡觉时保存进度", 6, UiKit.TEXT_DIM)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)

	_build_keys()
	_root.visible = false


## 按键说明的每一行：[干什么, 按哪些键]。
static func key_rows() -> Array:
	var rows: Array = []
	for row: Array in KEY_ROWS:
		var actions: Array = row[1]
		var parts: PackedStringArray = []
		for action: StringName in actions:
			parts.append(keys_of(action))
		# 物品栏那一行只写头尾两个键
		var sep := " – " if String(actions[0]).begins_with("slot") else "  "
		rows.append([row[0], sep.join(parts)])
	return rows


## 一个输入动作绑了哪些键，写成 “空格 / J / Z” 这样。
static func keys_of(action: StringName) -> String:
	var names: PackedStringArray = []
	if InputMap.has_action(action):
		for ev in InputMap.action_get_events(action):
			var key := ev as InputEventKey
			if key == null:
				continue
			var code := key.physical_keycode if key.physical_keycode != 0 else key.keycode
			var text := OS.get_keycode_string(code)
			names.append(KEY_NAMES.get(text, text))
	return " / ".join(names)


func is_open() -> bool:
	return _root.visible


func keys_open() -> bool:
	return _root.visible and _keys_panel.visible


func open() -> void:
	_root.visible = true
	_panel.visible = true
	UiKit.pop(_panel)
	_keys_panel.visible = false
	_refresh_music()
	_resume.grab_focus()


func close() -> void:
	if not _root.visible:
		return
	_root.visible = false
	closed.emit()


func show_keys() -> void:
	_panel.visible = false
	_keys_panel.visible = true
	UiKit.pop(_keys_panel)
	_back.grab_focus()


func hide_keys() -> void:
	_keys_panel.visible = false
	_panel.visible = true
	_keys.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _root.visible and (event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel")):
		get_viewport().set_input_as_handled()
		# 在按键说明那一页：先退回菜单
		if _keys_panel.visible:
			hide_keys()
		else:
			close()


func _build_keys() -> void:
	var rows := key_rows()
	var row_h := 12
	var size := Vector2(236, 48 + rows.size() * row_h)
	_keys_panel = UiKit.window()
	UiKit.center(_keys_panel, size)
	_root.add_child(_keys_panel)
	var head := UiKit.label("按键说明", 8)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.position = Vector2(0, 5)
	head.size = Vector2(size.x, 12)
	_keys_panel.add_child(head)
	for i in rows.size():
		var y := 23 + i * row_h
		var what := UiKit.label(String(rows[i][0]))
		what.position = Vector2(12, y)
		_keys_panel.add_child(what)
		var keys := UiKit.label(String(rows[i][1]), UiKit.FONT_SIZE, UiKit.TEXT_DIM)
		keys.position = Vector2(108, y)
		_keys_panel.add_child(keys)
	_back = UiKit.button("返回")
	_back.pressed.connect(hide_keys)
	_keys_panel.add_child(_back)
	# 进了树、套上主题以后再定大小：之前定的话按默认字号算，按钮会高出一倍
	_back.position = Vector2((size.x - 72) / 2.0, size.y - 23)
	_back.size = Vector2(72, 16)
	_keys_panel.visible = false


func _refresh_music() -> void:
	_music.text = "音乐：开" if Audio.music_on else "音乐：关"


func _on_music_pressed() -> void:
	Audio.toggle_music()
	_refresh_music()


func _on_title_pressed() -> void:
	_root.visible = false
	title_requested.emit()


func _on_quit_pressed() -> void:
	Audio.quit_game()
