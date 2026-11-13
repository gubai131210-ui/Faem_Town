class_name LampPanel
extends CanvasLayer
## 灯座：列出这盏灯要的供品和已经供上的数量，从背包里把东西供上去；齐了就能点灯。

signal closed
## 玩家选了点灯，灯已经记成点亮；画面上的表现由游戏主场景做
signal lit(lamp_id: StringName)

const PANEL_W := 212
const ROW_H := 16
const LIST_TOP := 37

var _root: Control
var _panel: NinePatchRect
var _head: Label
var _inscription: Label
var _rows: Array[Control] = []
var _hint: KeyHints
var _lamp_id: StringName = &""
var _wanted: Array[StringName] = []
var _cursor := 0


func _ready() -> void:
	layer = 20
	_root = UiKit.root()
	add_child(_root)
	_root.add_child(UiKit.dim())

	_panel = UiKit.window()
	_root.add_child(_panel)
	_head = UiKit.label("", 8)
	_head.position = Vector2(8, 5)
	_panel.add_child(_head)
	_inscription = UiKit.label("", 6, UiKit.TEXT_DIM)
	_inscription.position = Vector2(8, 19)
	_inscription.size = Vector2(PANEL_W - 16, 16)
	_inscription.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_panel.add_child(_inscription)
	_hint = KeyHints.new()
	_hint.size = Vector2(PANEL_W - 16, 10)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_hint)

	Lamps.changed.connect(_refresh)
	GameState.inventory.changed.connect(_refresh)
	_root.visible = false


func is_open() -> bool:
	return _root.visible


func open(lamp_id: StringName) -> void:
	_lamp_id = lamp_id
	_wanted = Lamps.wanted(lamp_id)
	for row in _rows:
		row.queue_free()
	_rows.clear()
	# 供品各一行，最后一行是“点灯”
	for i in _wanted.size() + 1:
		var row := _make_row(i)
		row.position = Vector2(6, LIST_TOP + i * ROW_H)
		_panel.add_child(row)
		_rows.append(row)
	var height := LIST_TOP + (_wanted.size() + 1) * ROW_H + 18
	UiKit.center(_panel, Vector2(PANEL_W, height))
	_hint.position = Vector2(8, height - 16)
	_cursor = 0
	_root.visible = true
	UiKit.pop(_panel)
	_refresh()


func close() -> void:
	if not _root.visible:
		return
	_root.visible = false
	closed.emit()


## 对光标所在那一行按了确定：供品行就把身上的供上去，点灯行就点灯。返回有没有做成。
func use_selected() -> bool:
	if _cursor < _wanted.size():
		var item_id := _wanted[_cursor]
		var have := GameState.inventory.count_of(item_id)
		var n := Lamps.offer(_lamp_id, item_id, have)
		if n <= 0:
			return false
		GameState.inventory.remove(item_id, n)
		Audio.play("plant", 0.0, -4.0)
		return true
	if not Lamps.light(_lamp_id):
		return false
	close()
	lit.emit(_lamp_id)
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event.is_action_pressed(&"inventory") or event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		close()
	elif event.is_action_pressed(&"move_up", true):
		_move(-1)
	elif event.is_action_pressed(&"move_down", true):
		_move(1)
	elif event.is_action_pressed(&"use") or event.is_action_pressed(&"ui_accept"):
		if not use_selected():
			Audio.play("deny", 0.0, -6.0)
	else:
		return
	get_viewport().set_input_as_handled()


func _move(d: int) -> void:
	_cursor = posmod(_cursor + d, _rows.size())
	Audio.play("select", 0.0, -10.0)
	_refresh()


func _make_row(i: int) -> Control:
	var row := Control.new()
	row.size = Vector2(PANEL_W - 12, ROW_H)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.gui_input.connect(_on_row_input.bind(i))
	var back := UiKit.row_back()
	back.name = "Back"
	back.color = Color("e2c088")
	back.size = Vector2(PANEL_W - 12, ROW_H - 1)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(back)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.position = Vector2(2, 0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var text := UiKit.label("", 7)
	text.name = "Text"
	text.position = Vector2(22, 2)
	row.add_child(text)
	var count := UiKit.label("", 7)
	count.name = "Count"
	count.position = Vector2(PANEL_W - 92, 2)
	count.size = Vector2(76, 12)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(count)
	return row


func _on_row_input(event: InputEvent, i: int) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_cursor = i
		_refresh()


func _refresh() -> void:
	if not _root.visible or _lamp_id == &"":
		return
	var lamp := Database.lamp(_lamp_id)
	_head.text = lamp.name
	_inscription.text = lamp.inscription
	var complete := Lamps.is_complete(_lamp_id)
	for i in _rows.size():
		var row := _rows[i]
		var back: ColorRect = row.get_node("Back")
		back.visible = i == _cursor
		var icon: TextureRect = row.get_node("Icon")
		var text: Label = row.get_node("Text")
		var count: Label = row.get_node("Count")
		if i < _wanted.size():
			var item_id := _wanted[i]
			var need := 1 if item_id == lamp.relic else lamp.offerings[item_id]
			var given := need - Lamps.missing(_lamp_id, item_id)
			icon.texture = UiKit.item_icon(item_id)
			text.text = Database.item(item_id).name
			count.text = "%d / %d（身上 %d）" % [given, need, GameState.inventory.count_of(item_id)]
			var done := given >= need
			text.add_theme_color_override(&"font_color", UiKit.TEXT_DIM if done else UiKit.TEXT_DARK)
			count.add_theme_color_override(&"font_color", UiKit.TEXT_DIM if done else Color("9a5a1c"))
		else:
			icon.texture = null
			text.text = "点灯" if complete else "供品还没齐"
			text.add_theme_color_override(&"font_color", Color("c8483c") if complete else UiKit.TEXT_DIM)
			count.text = ""
	_hint.text = "空格 供上 / 点灯    E 离开"
