class_name CookPanel
extends CanvasLayer
## 灶台的菜谱：列出已经会的菜，材料够就能做，做好的食物进背包。

signal closed

const ROW_H := 18
const VISIBLE_ROWS := 6
const PANEL_W := 196
const LIST_TOP := 20

var _root: Control
var _panel: Control
var _head: Label
var _desc: Label
var _need: Label
var _more: Label
var _rows: Array[Control] = []
var _list: Array[RecipeDef] = []
var _cursor := 0
var _scroll := 0


func _ready() -> void:
	layer = 20
	_root = UiKit.root()
	add_child(_root)
	_root.add_child(UiKit.dim())

	var panel := UiKit.window()
	_panel = panel
	UiKit.center(panel, Vector2(PANEL_W, LIST_TOP + VISIBLE_ROWS * ROW_H + 50))
	_root.add_child(panel)

	_head = UiKit.label("灶台", 8)
	_head.position = Vector2(8, 5)
	panel.add_child(_head)

	for i in VISIBLE_ROWS:
		var row := _make_row(i)
		row.position = Vector2(6, LIST_TOP + i * ROW_H)
		panel.add_child(row)
		_rows.append(row)

	var info_y := float(LIST_TOP + VISIBLE_ROWS * ROW_H + 2)
	_more = UiKit.label("", 6, UiKit.TEXT_DIM)
	_more.position = Vector2(8, info_y - 1.0)
	_more.size = Vector2(PANEL_W - 16, 9)
	_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(_more)
	_need = UiKit.label("", 7)
	_need.position = Vector2(8, info_y + 8.0)
	_need.size = Vector2(PANEL_W - 16, 12)
	panel.add_child(_need)
	_desc = UiKit.label("", 7, UiKit.TEXT_DIM)
	_desc.position = Vector2(8, info_y + 19.0)
	_desc.size = Vector2(PANEL_W - 16, 12)
	panel.add_child(_desc)
	var hint := KeyHints.new("空格 做一份    E 关闭")
	hint.position = Vector2(8, info_y + 32.0)
	hint.size = Vector2(PANEL_W - 16, 10)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(hint)

	GameState.inventory.changed.connect(_refresh)
	_root.visible = false


func is_open() -> bool:
	return _root.visible


func open() -> void:
	_list = Crafting.known_recipes()
	_cursor = 0
	_scroll = 0
	_root.visible = true
	UiKit.pop(_panel)
	_refresh()


func close() -> void:
	if not _root.visible:
		return
	_root.visible = false
	closed.emit()


## 做光标所在的那道菜。材料不够或背包满了就提示。
func cook_selected() -> bool:
	if _cursor < 0 or _cursor >= _list.size():
		return false
	var def := _list[_cursor]
	if not Crafting.cook(def.id):
		Audio.play("deny", 0.0, -4.0)
		_desc.text = "材料不够" if Crafting.servings(def.id) < 1 else "背包放不下了"
		return false
	Audio.play("harvest", 0.0, -4.0)
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
	elif event.is_action_pressed(&"use"):
		cook_selected()
	else:
		return
	get_viewport().set_input_as_handled()


func _move(d: int) -> void:
	if _list.is_empty():
		return
	_cursor = posmod(_cursor + d, _list.size())
	_scroll = clampi(_scroll, _cursor - VISIBLE_ROWS + 1, _cursor)
	Audio.play("select", 0.0, -10.0)
	_refresh()


func _make_row(i: int) -> Control:
	var row := Control.new()
	row.custom_minimum_size = Vector2(PANEL_W - 12, ROW_H)
	row.size = row.custom_minimum_size
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
	var dish := UiKit.label("", 8)
	dish.name = "Dish"
	dish.position = Vector2(22, 3)
	row.add_child(dish)
	var can := UiKit.label("", 7, UiKit.TEXT_DIM)
	can.name = "Can"
	can.position = Vector2(120, 4)
	can.size = Vector2(60, 12)
	can.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(can)
	return row


func _on_row_input(event: InputEvent, i: int) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var index := _scroll + i
	if index >= _list.size():
		return
	if index == _cursor:
		cook_selected()
	else:
		_cursor = index
		_refresh()


func _refresh() -> void:
	if not _root.visible:
		return
	for i in _rows.size():
		var row := _rows[i]
		var index := _scroll + i
		row.visible = index < _list.size()
		if not row.visible:
			continue
		var def := _list[index]
		var item := Database.item(def.id)
		var back: ColorRect = row.get_node("Back")
		back.visible = index == _cursor
		var icon: TextureRect = row.get_node("Icon")
		icon.texture = UiKit.texture(item.icon)
		var dish: Label = row.get_node("Dish")
		dish.text = item.name
		var can: Label = row.get_node("Can")
		var n := Crafting.servings(def.id)
		can.text = "能做 %d 份" % n if n > 0 else "材料不够"
		can.add_theme_color_override(&"font_color", UiKit.TEXT_DIM if n > 0 else Color("c8483c"))
	if _list.is_empty():
		_need.text = ""
		_desc.text = "还不会做什么菜。"
		_more.text = ""
		return
	var cur := _list[_cursor]
	_more.text = "%d / %d" % [_cursor + 1, _list.size()] if _list.size() > VISIBLE_ROWS else ""
	_need.text = "要：" + cur.ingredients_text()
	_desc.text = Database.item(cur.id).desc
