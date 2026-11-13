class_name BoardPanel
extends CanvasLayer
## 公告栏：贴着的委托（可以接）、接了的、做完的，以及广场灯要的供品。

signal closed

const PANEL_SIZE := Vector2(300, 170)
const ROW_H := 13
const LIST_W := 132
const DETAIL_X := 146.0
const MAX_ROWS := 8

var _root: Control
var _panel: Control
var _rows: Array[Control] = []
## 现在列出来的委托，和每张的状态："posted"、"active"、"done"
var _list: Array[QuestDef] = []
var _states: Array[String] = []
var _cursor := 0
var _title: Label
var _text: Label
var _want_icon: TextureRect
var _want: Label
var _reward: Label
var _hint: Label
var _lamp: Label
var _empty: Label


func _ready() -> void:
	layer = 20
	_root = UiKit.root()
	add_child(_root)
	_root.add_child(UiKit.dim())

	var panel := UiKit.window()
	_panel = panel
	UiKit.center(panel, PANEL_SIZE)
	_root.add_child(panel)
	var head := UiKit.label("公告栏", 8)
	head.position = Vector2(8, 5)
	panel.add_child(head)
	var keys := KeyHints.new("↑↓ 选    空格 接下    E 关闭")
	keys.position = Vector2(8, 6)
	keys.size = Vector2(PANEL_SIZE.x - 16, 10)
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(keys)

	for i in MAX_ROWS:
		var row := _make_row(i)
		row.position = Vector2(8, 20 + i * ROW_H)
		panel.add_child(row)
		_rows.append(row)
	_empty = UiKit.label("今天没有新的委托。", 7, UiKit.TEXT_DIM)
	_empty.position = Vector2(10, 22)
	panel.add_child(_empty)

	_title = UiKit.label("", 9)
	_title.position = Vector2(DETAIL_X, 20)
	_title.size = Vector2(PANEL_SIZE.x - DETAIL_X - 8.0, 14)
	panel.add_child(_title)
	_text = UiKit.label("", 7, UiKit.TEXT_DIM)
	_text.position = Vector2(DETAIL_X, 36)
	_text.size = Vector2(PANEL_SIZE.x - DETAIL_X - 8.0, 44)
	_text.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	panel.add_child(_text)
	_want_icon = TextureRect.new()
	_want_icon.position = Vector2(DETAIL_X, 84)
	_want_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_want_icon)
	_want = UiKit.label("", 7)
	_want.position = Vector2(DETAIL_X + 20.0, 88)
	panel.add_child(_want)
	_reward = UiKit.label("", 7, Color("9a5a1c"))
	_reward.position = Vector2(DETAIL_X, 104)
	_reward.size = Vector2(PANEL_SIZE.x - DETAIL_X - 8.0, 12)
	panel.add_child(_reward)
	_hint = UiKit.label("", 6, Color("c8483c"))
	_hint.position = Vector2(DETAIL_X, 118)
	_hint.size = Vector2(PANEL_SIZE.x - DETAIL_X - 8.0, 12)
	panel.add_child(_hint)

	var rule := ColorRect.new()
	rule.color = Color("c9a074")
	rule.position = Vector2(8, 130)
	rule.size = Vector2(PANEL_SIZE.x - 16, 1)
	panel.add_child(rule)
	_lamp = UiKit.label("", 6, UiKit.TEXT_DIM)
	# 三行灯座上的话要放得下：一行 9 像素，底下还有 7 像素的木框
	_lamp.position = Vector2(8, 133)
	_lamp.size = Vector2(PANEL_SIZE.x - 16, 28)
	_lamp.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_lamp.max_lines_visible = 3
	panel.add_child(_lamp)

	Quests.changed.connect(_refresh)
	_root.visible = false


func is_open() -> bool:
	return _root.visible


func open() -> void:
	_cursor = 0
	_root.visible = true
	UiKit.pop(_panel)
	_refresh()


func close() -> void:
	if not _root.visible:
		return
	_root.visible = false
	closed.emit()


## 接下光标所在的委托；不是能接的返回 false。
func accept_selected() -> bool:
	if _cursor >= _list.size() or _states[_cursor] != "posted":
		return false
	if not Quests.accept(_list[_cursor].id):
		return false
	Audio.play("plant", 0.0, -4.0)
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event.is_action_pressed(&"inventory") or event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause") \
			or event.is_action_pressed(&"residents"):
		close()
	elif event.is_action_pressed(&"move_up", true):
		_move(-1)
	elif event.is_action_pressed(&"move_down", true):
		_move(1)
	elif event.is_action_pressed(&"use") or event.is_action_pressed(&"ui_accept"):
		if not accept_selected():
			Audio.play("deny", 0.0, -6.0)
	else:
		return
	get_viewport().set_input_as_handled()


func _move(d: int) -> void:
	if _list.is_empty():
		return
	_cursor = posmod(_cursor + d, _list.size())
	Audio.play("select", 0.0, -10.0)
	_refresh()


func _make_row(i: int) -> Control:
	var row := Control.new()
	row.size = Vector2(LIST_W, ROW_H)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.gui_input.connect(_on_row_input.bind(i))
	var back := UiKit.row_back()
	back.name = "Back"
	back.color = Color("e2c088")
	back.size = Vector2(LIST_W, ROW_H - 1)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(back)
	var tag := UiKit.label("", 6, Color("c8483c"))
	tag.name = "Tag"
	tag.position = Vector2(2, 1)
	row.add_child(tag)
	var text := UiKit.label("", 7)
	text.name = "Text"
	text.position = Vector2(22, 0)
	row.add_child(text)
	return row


func _on_row_input(event: InputEvent, i: int) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and i < _list.size():
		_cursor = i
		_refresh()


func _rebuild_list() -> void:
	_list.clear()
	_states.clear()
	for q in Quests.posted(GameClock.day):
		_list.append(q)
		_states.append("posted")
	for id in Quests.active:
		_list.append(Database.quest(id))
		_states.append("active")
	for id in Quests.done:
		if _list.size() >= MAX_ROWS:
			break
		_list.append(Database.quest(id))
		_states.append("done")


func _refresh() -> void:
	if not _root.visible:
		return
	_rebuild_list()
	_cursor = clampi(_cursor, 0, maxi(0, _list.size() - 1))
	_empty.visible = _list.is_empty()
	for i in _rows.size():
		var row := _rows[i]
		row.visible = i < _list.size()
		if not row.visible:
			continue
		var back: ColorRect = row.get_node("Back")
		back.visible = i == _cursor
		var tag: Label = row.get_node("Tag")
		var text: Label = row.get_node("Text")
		match _states[i]:
			"posted":
				tag.text = "新"
				tag.add_theme_color_override(&"font_color", Color("c8483c"))
			"active":
				tag.text = "接了"
				tag.add_theme_color_override(&"font_color", Color("9a5a1c"))
			_:
				tag.text = "已交"
				tag.add_theme_color_override(&"font_color", UiKit.TEXT_DIM)
		text.text = _list[i].title
		text.add_theme_color_override(&"font_color", UiKit.TEXT_DIM if _states[i] == "done" else UiKit.TEXT_DARK)

	if _list.is_empty():
		_title.text = ""
		_text.text = ""
		_want_icon.texture = null
		_want.text = ""
		_reward.text = ""
		_hint.text = ""
	else:
		var q := _list[_cursor]
		var def := Database.item(q.item)
		_title.text = q.title
		_text.text = q.text
		_want_icon.texture = UiKit.item_icon(q.item)
		_want.text = "%s × %d（身上有 %d）" % [def.name, q.count, GameState.inventory.count_of(q.item)]
		_reward.text = "报酬 %d 文" % q.money + ("，还有一样旧东西" if q.relic != &"" else "")
		match _states[_cursor]:
			"posted":
				_hint.text = "空格 接下这张"
			"active":
				_hint.text = "拿着东西去找%s" % Database.npc(q.npc).name
			_:
				_hint.text = "已经交过了"

	# 一共只有三行的地方：亮了的并成一行，没亮的只列最前面两盏
	var lines := PackedStringArray()
	var lit := PackedStringArray()
	var waiting := 0
	for lamp_id: StringName in Database.lamps:
		var lamp := Database.lamp(lamp_id)
		if Lamps.is_lit(lamp_id):
			lit.append(lamp.name)
		elif waiting < 2:
			waiting += 1
			var have := 0
			var total := 0
			for item_id in Lamps.wanted(lamp_id):
				var need := 1 if item_id == lamp.relic else lamp.offerings[item_id]
				total += need
				have += need - Lamps.missing(lamp_id, item_id)
			lines.append("%s（已供 %d / %d）" % [lamp.inscription, have, total])
	if not lit.is_empty():
		lines.insert(0, "已经亮了：%s。" % "、".join(lit))
	_lamp.text = "\n".join(lines)
