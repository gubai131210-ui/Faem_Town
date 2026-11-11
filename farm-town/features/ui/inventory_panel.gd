class_name InventoryPanel
extends CanvasLayer
## 背包面板：查看全部物品，选两格交换位置。第一行就是物品栏。

signal closed

const COLS := 8

var _root: Control
var _slots: Array[ItemSlot] = []
var _title: Label
var _desc: Label
var _cursor := 0
## 已经拿起、等待放下的格子，-1 表示没有
var _held := -1


func _ready() -> void:
	layer = 20
	_root = UiKit.root()
	add_child(_root)
	_root.add_child(UiKit.dim())

	var panel := UiKit.panel()
	UiKit.center(panel, Vector2(COLS * 23 + 13, 128))
	_root.add_child(panel)

	var head := UiKit.label("背包", 8)
	head.position = Vector2(8, 5)
	panel.add_child(head)
	var hint := UiKit.label("空格 拿起/放下    E 关闭", 6, UiKit.TEXT_DIM)
	hint.position = Vector2(8, 7)
	hint.size = Vector2(COLS * 23 - 3, 10)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(hint)

	var rows := GameState.INVENTORY_SIZE / COLS
	for i in GameState.INVENTORY_SIZE:
		var slot := ItemSlot.new(i, str(i + 1) if i < GameState.HOTBAR_SIZE else "")
		var row := i / COLS
		# 物品栏那一行和下面隔开一点
		slot.position = Vector2(7 + (i % COLS) * 23, 19 + row * 23 + (3 if row > 0 else 0))
		slot.clicked.connect(_on_slot_clicked)
		panel.add_child(slot)
		_slots.append(slot)

	var info_y := 19.0 + rows * 23.0 + 7.0
	_title = UiKit.label("", 8)
	_title.position = Vector2(8, info_y)
	panel.add_child(_title)
	_desc = UiKit.label("", 7, UiKit.TEXT_DIM)
	_desc.position = Vector2(8, info_y + 12.0)
	_desc.size = Vector2(COLS * 23 - 3, 12)
	panel.add_child(_desc)

	GameState.inventory.changed.connect(_refresh)
	_root.visible = false


func is_open() -> bool:
	return _root.visible


func open() -> void:
	_held = -1
	_cursor = GameState.selected_slot
	_root.visible = true
	_refresh()


func close() -> void:
	if not _root.visible:
		return
	_root.visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event.is_action_pressed(&"inventory") or event.is_action_pressed(&"ui_cancel"):
		if _held >= 0 and event.is_action_pressed(&"ui_cancel"):
			_held = -1
			_refresh()
		else:
			close()
	elif event.is_action_pressed(&"move_left", true):
		_move_cursor(-1, 0)
	elif event.is_action_pressed(&"move_right", true):
		_move_cursor(1, 0)
	elif event.is_action_pressed(&"move_up", true):
		_move_cursor(0, -1)
	elif event.is_action_pressed(&"move_down", true):
		_move_cursor(0, 1)
	elif event.is_action_pressed(&"use"):
		_pick(_cursor)
	else:
		return
	get_viewport().set_input_as_handled()


func _move_cursor(dx: int, dy: int) -> void:
	var rows := GameState.INVENTORY_SIZE / COLS
	var x := posmod(_cursor % COLS + dx, COLS)
	var y := posmod(_cursor / COLS + dy, rows)
	_cursor = y * COLS + x
	Audio.play("select", 0.0, -10.0)
	_refresh()


func _on_slot_clicked(index: int) -> void:
	_cursor = index
	_pick(index)


func _pick(index: int) -> void:
	var inv := GameState.inventory
	if _held < 0:
		if inv.id_at(index) == &"":
			return
		_held = index
		Audio.play("select", 0.0, -6.0)
		_refresh()
		return
	var from := _held
	_held = -1
	if from != index:
		inv.swap(from, index)
		Audio.play("plant", 0.0, -6.0)
	_refresh()


func _refresh() -> void:
	if not _root.visible:
		return
	var inv := GameState.inventory
	for i in _slots.size():
		_slots[i].show_item(inv.id_at(i), inv.count_at(i))
		_slots[i].set_selected(i == _cursor)
		_slots[i].set_held(i == _held)
	var def := Database.item(inv.id_at(_cursor)) if inv.id_at(_cursor) != &"" else null
	if def == null:
		_title.text = ""
		_desc.text = ""
		return
	var count := inv.count_at(_cursor)
	_title.text = def.name if count <= 1 else "%s ×%d" % [def.name, count]
	_desc.text = def.desc if def.price <= 0 else "%s  售价 %d 文" % [def.desc, def.price]
