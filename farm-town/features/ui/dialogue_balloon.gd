class_name DialogueBalloon
extends CanvasLayer
## 对话框：逐字显示 Dialogue Manager 给出的台词，有选项时列出选项。说话的是居民时左边显示头像。

signal finished

const CHARS_PER_SECOND := 30.0
## 说到这些标点时停一下，像人说话换气；句末停得久一点
const PAUSE_SHORT := "，、；："
const PAUSE_LONG := "。！？…—"
const PAUSE_SHORT_TIME := 0.11
const PAUSE_LONG_TIME := 0.2
## 台词左边留的空：没有头像时、有头像时
const TEXT_LEFT := 12.0
const TEXT_LEFT_FACE := 82.0
const TEXT_RIGHT := 288.0

var _root: Control
var _name_tag: NinePatchRect
var _name: Label
var _face_frame: NinePatchRect
var _face: TextureRect
var _text: Label
var _more: Label
var _choices: VBoxContainer
var _resource: DialogueResource
var _line: DialogueLine
var _shown := 0.0
var _waiting_choice := false
var _blink := 0.0
var _pause := 0.0


func _ready() -> void:
	layer = 25
	_root = UiKit.root()
	add_child(_root)

	var panel := UiKit.panel()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -150.0
	panel.offset_right = 150.0
	panel.offset_top = -62.0
	panel.offset_bottom = -6.0
	_root.add_child(panel)

	_name_tag = UiKit.panel()
	_name_tag.position = Vector2(8, -11)
	_name_tag.size = Vector2(48, 16)
	panel.add_child(_name_tag)
	_name = UiKit.label("", 8)
	_name.position = Vector2(0, 1)
	_name.size = Vector2(48, 13)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_tag.add_child(_name)

	_text = UiKit.label("", 9)
	_text.position = Vector2(12, 9)
	_text.size = Vector2(276, 40)
	_text.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_text.add_theme_constant_override(&"line_spacing", 3)
	panel.add_child(_text)

	_face_frame = UiKit.panel()
	_face_frame.position = Vector2(4, -20)
	_face_frame.size = Vector2(72, 72)
	_face_frame.visible = false
	panel.add_child(_face_frame)
	_face = TextureRect.new()
	_face.position = Vector2(4, 4)
	_face.size = Vector2(64, 64)
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face_frame.add_child(_face)

	_more = UiKit.label("▼", 6, Color("c8483c"))
	_more.position = Vector2(284, 43)
	panel.add_child(_more)

	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override(&"separation", 2)
	_choices.anchor_left = 0.5
	_choices.anchor_right = 0.5
	_choices.anchor_top = 1.0
	_choices.anchor_bottom = 1.0
	_choices.offset_left = 10.0
	_choices.offset_right = 150.0
	_choices.offset_bottom = -66.0
	_choices.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(_choices)

	_root.visible = false


func _process(delta: float) -> void:
	if not _root.visible or _line == null:
		return
	var total := _text.get_total_character_count()
	if _shown < total:
		if _pause > 0.0:
			_pause -= delta
		else:
			var before := int(_shown)
			_shown = minf(_shown + delta * CHARS_PER_SECOND, total)
			var now := int(_shown)
			if now > before:
				_pause = pause_after(_text.text, now - 1)
			_text.visible_characters = now
		if _shown >= total:
			_on_line_fully_shown()
	_blink += delta
	_more.visible = _shown >= total and not _waiting_choice and fmod(_blink, 0.8) < 0.5


func _unhandled_input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event.is_action_pressed(&"use") or event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		advance()


func is_open() -> bool:
	return _root.visible


## 从 path 这个对话文件的 title 段落开始播放。
func start(path: String, title: String) -> void:
	_resource = load(path) as DialogueResource
	if _resource == null:
		push_error("找不到对话文件：%s" % path)
		finished.emit()
		return
	_root.visible = true
	_show_next(title)


## 相当于玩家按了一次确认：没显示完就补全，显示完了就下一句。
func advance() -> void:
	if _line == null or _waiting_choice:
		return
	var total := _text.get_total_character_count()
	if _shown < total:
		_shown = total
		_text.visible_characters = -1
		_on_line_fully_shown()
		return
	_show_next(_line.next_id)


func _show_next(key: String) -> void:
	_clear_choices()
	_waiting_choice = false
	var line: DialogueLine = await DialogueManager.get_next_dialogue_line(_resource, key)
	if not is_instance_valid(self):
		return
	if line == null:
		_line = null
		_root.visible = false
		finished.emit()
		return
	_line = line
	_name.text = line.character
	_name_tag.visible = line.character != ""
	var who := Database.npc_by_name(line.character)
	var mood := "happy" if line.has_tag("happy") else ("sad" if line.has_tag("sad") else "")
	var face := UiKit.face(who.sheet, mood) if who != null else null
	_face.texture = face
	_face_frame.visible = face != null
	var left := TEXT_LEFT_FACE if face != null else TEXT_LEFT
	_text.position.x = left
	_text.size.x = TEXT_RIGHT - left
	_name_tag.position.x = left - 4.0
	_text.text = line.text
	_text.visible_characters = 0
	_shown = 0.0
	_blink = 0.0
	_pause = 0.0
	Audio.play("select", 0.1, -12.0)


## 显示到 text 的第 index 个字以后要停多久。连着的标点（“……”“？！”）只在最后一个后面停。
static func pause_after(text: String, index: int) -> float:
	if index < 0 or index >= text.length() - 1:
		return 0.0
	var c := text[index]
	var next := text[index + 1]
	if PAUSE_LONG.contains(next) or PAUSE_SHORT.contains(next) or next == "”":
		return 0.0
	if PAUSE_LONG.contains(c):
		return PAUSE_LONG_TIME
	if PAUSE_SHORT.contains(c):
		return PAUSE_SHORT_TIME
	return 0.0


func _on_line_fully_shown() -> void:
	if _line == null or _line.responses.is_empty():
		return
	_waiting_choice = true
	var first: Button = null
	for r: DialogueResponse in _line.responses:
		if not r.is_allowed:
			continue
		var b := UiKit.button(r.text)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_on_choice_pressed.bind(r.next_id))
		_choices.add_child(b)
		if first == null:
			first = b
	if first != null:
		first.grab_focus()
	else:
		_waiting_choice = false


func _on_choice_pressed(next_id: String) -> void:
	Audio.play("select", 0.0, -6.0)
	_show_next(next_id)


func _clear_choices() -> void:
	for c in _choices.get_children():
		c.queue_free()
