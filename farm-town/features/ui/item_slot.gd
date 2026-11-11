class_name ItemSlot
extends Control
## 一个物品格：底框、图标、数量，可选的快捷键数字。物品栏和背包共用。

signal clicked(index: int)

const SIZE := 22

var index := 0

var _bg: TextureRect
var _icon: TextureRect
var _count: Label
var _selected := false


func _init(slot_index: int = 0, key_hint: String = "") -> void:
	index = slot_index
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_bg = TextureRect.new()
	_bg.texture = UiKit.texture("slot")
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_icon = TextureRect.new()
	_icon.position = Vector2(3, 3)
	_icon.pivot_offset = Vector2(8, 8)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	if key_hint != "":
		var key := UiKit.label(key_hint, 5, UiKit.TEXT_LIGHT, true)
		key.position = Vector2(3, 0)
		add_child(key)
	_count = UiKit.label("", 6, UiKit.TEXT_LIGHT, true)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.position = Vector2(2, 12)
	_count.size = Vector2(18, 9)
	add_child(_count)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(index)
		accept_event()


func show_item(id: StringName, count: int) -> void:
	var changed := count > 0 and _count.text != "" and str(count) != _count.text
	_icon.texture = UiKit.item_icon(id) if id != &"" else null
	_count.text = str(count) if count > 1 else ""
	if changed:
		pulse()


func set_selected(selected: bool) -> void:
	_selected = selected
	_bg.texture = UiKit.texture("slot_selected" if selected else "slot")
	_icon.position = Vector2(3, 2 if selected else 3)


## 被拿起、等待交换时变淡。
func set_held(held: bool) -> void:
	_icon.modulate.a = 0.45 if held else 1.0


func pulse() -> void:
	_icon.scale = Vector2(1.4, 1.4)
	var tw := create_tween()
	tw.tween_property(_icon, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
