class_name PauseMenu
extends CanvasLayer
## 暂停菜单。进度在睡觉时保存，所以这里没有单独的“保存”。

signal closed
signal title_requested

var _root: Control
var _resume: Button
var _music: Button


func _ready() -> void:
	layer = 30
	_root = UiKit.root()
	add_child(_root)
	_root.add_child(UiKit.dim(0.55))

	var panel := UiKit.panel()
	UiKit.center(panel, Vector2(120, 112))
	_root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 3)
	box.position = Vector2(12, 8)
	box.size = Vector2(96, 96)
	panel.add_child(box)

	var head := UiKit.label("暂停", 9)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	_resume = UiKit.button("继续")
	_resume.pressed.connect(close)
	box.add_child(_resume)
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

	_root.visible = false


func is_open() -> bool:
	return _root.visible


func open() -> void:
	_root.visible = true
	_refresh_music()
	_resume.grab_focus()


func close() -> void:
	if not _root.visible:
		return
	_root.visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if _root.visible and (event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel")):
		get_viewport().set_input_as_handled()
		close()


func _refresh_music() -> void:
	_music.text = "音乐：开" if Audio.music_on else "音乐：关"


func _on_music_pressed() -> void:
	Audio.toggle_music()
	_refresh_music()


func _on_title_pressed() -> void:
	_root.visible = false
	title_requested.emit()


func _on_quit_pressed() -> void:
	get_tree().quit()
