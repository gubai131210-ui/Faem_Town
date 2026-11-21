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
## 随手试试放进去的三样。关上不扣。
var _trial: Array[StringName] = []


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
	_trial.clear()
	_root.visible = true
	UiKit.pop(_panel)
	_refresh()


func close() -> void:
	if not _root.visible:
		return
	_trial.clear()
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
	EventBus.cook_show_requested.emit(def.id)
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
		if _on_trial():
			_add_trial()
		else:
			cook_selected()
	else:
		return
	get_viewport().set_input_as_handled()


func _on_trial() -> bool:
	return _cursor == _list.size()


func _span() -> int:
	return _list.size() + 1


func _move(d: int) -> void:
	_cursor = posmod(_cursor + d, _span())
	_scroll = clampi(_scroll, _cursor - VISIBLE_ROWS + 1, _cursor)
	Audio.play("select", 0.0, -10.0)
	_refresh()


func _trial_text() -> String:
	if _trial.is_empty():
		return "手里拿着材料，按使用放进去"
	var parts := PackedStringArray()
	for id: StringName in _trial:
		parts.append(Database.item(id).name)
	return "锅里：" + "、".join(parts)


func _add_trial() -> void:
	if _trial.size() >= 3:
		_finish_trial()
		return
	var item := GameState.selected_item()
	if item == null:
		_desc.text = "手里空着"
		Audio.play("deny", 0.0, -4.0)
		return
	if Crafting.TRIAL_BLOCK.has(item.kind):
		_desc.text = "这个不能下锅"
		Audio.play("deny", 0.0, -4.0)
		return
	var have := 0
	for id: StringName in _trial:
		if id == item.id:
			have += 1
	if GameState.inventory.count_of(item.id) < have + 1:
		_desc.text = "手里不够"
		Audio.play("deny", 0.0, -4.0)
		return
	_trial.append(item.id)
	if _trial.size() >= 3:
		_finish_trial()
	else:
		_refresh()


func _finish_trial() -> void:
	var made := Crafting.experiment(_trial)
	if made == &"":
		_desc.text = "背包放不下了"
		Audio.play("deny", 0.0, -4.0)
		return
	_trial.clear()
	_refresh()
	if made == Crafting.ODD_BOWL:
		_desc.text = "说不上来是什么"
		EventBus.banner_requested.emit("做出来一碗说不上来的东西")
		Audio.play("deny", 0.0, -4.0)
		return
	Audio.play("harvest", 0.0, -4.0)
	EventBus.cook_show_requested.emit(made)


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
	if index >= _span():
		return
	if index == _cursor:
		if _on_trial():
			_add_trial()
		else:
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
		row.visible = index < _span()
		if not row.visible:
			continue
		if index == _list.size():
			var trial_back: ColorRect = row.get_node("Back")
			trial_back.visible = index == _cursor
			var trial_icon: TextureRect = row.get_node("Icon")
			trial_icon.texture = null
			var trial_dish: Label = row.get_node("Dish")
			trial_dish.text = "随手试试"
			var trial_can: Label = row.get_node("Can")
			trial_can.text = "%d/3" % _trial.size()
			trial_can.add_theme_color_override(&"font_color", UiKit.TEXT_DIM)
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
	if _on_trial():
		_more.text = "%d / %d" % [_cursor + 1, _span()] if _span() > VISIBLE_ROWS else ""
		_need.text = _trial_text()
		_desc.text = "齐了就出锅。对了学会，不对是糊的。"
		return
	if _list.is_empty():
		_need.text = ""
		_desc.text = "还不会做什么菜。"
		_more.text = ""
		return
	var cur := _list[_cursor]
	_more.text = "%d / %d" % [_cursor + 1, _list.size()] if _list.size() > VISIBLE_ROWS else ""
	var mark := ""
	if Crafting.in_term(cur):
		mark += " · 当令"
	if Crafting.is_fresh(cur):
		mark += " · 新鲜"
	if Crafting.has_heat(cur.id):
		mark += " · 火候到过"
	_need.text = "要：" + cur.ingredients_text() + mark
	_desc.text = "切配、控火、翻炒。随时可跳过。" if cur.id == &"tomato_egg" else Database.item(cur.id).desc
