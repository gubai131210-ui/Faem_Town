class_name TablePanel
extends CanvasLayer

const DishFrames := preload("res://art_gen/dish_art.gd")
## 农舍桌上摆了什么。凑齐八席以后，按使用请大家吃饭。

signal closed

const COLS := 4
const SLOT := 36

var _root: Control
var _names: Array[Label] = []
var _icons: Array[TextureRect] = []
var _hint: Label
var _who: Label
var _guests: Array[StringName] = []
var _guest := 0
var _seats: Array[StringName] = []


func _ready() -> void:
	layer = 20
	_root = UiKit.root()
	add_child(_root)
	_root.add_child(UiKit.dim())
	var panel := UiKit.window()
	UiKit.center(panel, Vector2(196, 186))
	_root.add_child(panel)
	var head := UiKit.label("席面", 8)
	head.position = Vector2(8, 5)
	panel.add_child(head)
	for i in Crafting.TABLE_MAX:
		var col := i % COLS
		var row := i / COLS
		var icon := TextureRect.new()
		icon.position = Vector2(12 + col * 46, 24 + row * 58)
		icon.custom_minimum_size = Vector2(SLOT, SLOT)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(icon)
		_icons.append(icon)
		var name := UiKit.label("", 6)
		name.position = Vector2(8 + col * 46, 62 + row * 58)
		name.size = Vector2(44, 16)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.autowrap_mode = TextServer.AUTOWRAP_OFF
		name.clip_text = true
		panel.add_child(name)
		_names.append(name)
	_who = UiKit.label("", 7)
	_who.position = Vector2(8, 146)
	_who.size = Vector2(180, 14)
	panel.add_child(_who)
	_hint = UiKit.label("", 6)
	_hint.position = Vector2(8, 164)
	_hint.size = Vector2(180, 16)
	panel.add_child(_hint)
	_root.visible = false


func is_open() -> bool:
	return _root != null and _root.visible


func open() -> void:
	_seats.clear()
	_guest = 0
	_root.visible = true
	_refresh()


func close() -> void:
	if not is_open():
		return
	_root.visible = false
	closed.emit()


func _process(_delta: float) -> void:
	if not is_open():
		return
	_refresh()


func _refresh() -> void:
	var frame := int(Time.get_ticks_msec() / 180) % 4
	for i in Crafting.TABLE_MAX:
		if i < Crafting.table_dishes.size():
			var id := Crafting.table_dishes[i]
			_icons[i].texture = DishFrames.frame(id, frame)
			_names[i].text = Database.item(id).name
		else:
			_icons[i].texture = DishFrames.plate()
			_names[i].text = ""
	var hosting := not Crafting.table_dishes.is_empty() and not Crafting.feast_ready()
	_who.visible = hosting
	if Crafting.table_dishes.is_empty():
		_hint.text = "桌上本来两副碗筷，一副落了灰。"
	elif Crafting.feast_ready():
		_hint.text = "八席齐了。按使用，请大家吃饭。"
	else:
		_fill_guests()
		var seated := PackedStringArray()
		for id: StringName in _seats:
			seated.append(Database.npc(id).name)
		if _guests.is_empty():
			_who.text = "还没见过能请的人。"
			_hint.text = "先去镇上见见人。"
		else:
			_guest = clampi(_guest, 0, _guests.size() - 1)
			var name := Database.npc(_guests[_guest]).name
			_who.text = "请：%s    入座：%s" % [name, "、".join(seated) if not seated.is_empty() else "空"]
			_hint.text = "←→ 选人  使用入座  确定开席"


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause") or event.is_action_pressed(&"inventory"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"move_left"):
		_turn(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"move_right"):
		_turn(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"use"):
		if Crafting.feast_ready():
			close()
			EventBus.feast_requested.emit()
		else:
			_toggle_seat()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_accept") and not Crafting.feast_ready():
		_start_meal()
		get_viewport().set_input_as_handled()


func _fill_guests() -> void:
	_guests.clear()
	for id: StringName in Database.npcs:
		if Residents.has_met(id):
			_guests.append(id)


func _turn(d: int) -> void:
	if _guests.is_empty() or Crafting.feast_ready():
		return
	_guest = posmod(_guest + d, _guests.size())
	Audio.play("select", 0.0, -10.0)
	_refresh()


func _toggle_seat() -> void:
	if _guests.is_empty() or Crafting.table_dishes.is_empty():
		return
	var id := _guests[_guest]
	var at := _seats.find(id)
	if at >= 0:
		_seats.remove_at(at)
	elif _seats.size() >= 3:
		EventBus.banner_requested.emit("坐满了，三位")
	else:
		_seats.append(id)
	Audio.play("select", 0.0, -8.0)
	_refresh()


func _start_meal() -> void:
	if _seats.is_empty():
		EventBus.banner_requested.emit("还没请人入座")
		return
	var people: Array = []
	for id: StringName in _seats:
		people.append(id)
	var dishes: Array = []
	for id: StringName in Crafting.table_dishes:
		dishes.append(id)
	var said := Crafting.host(_seats)
	if said.is_empty():
		EventBus.banner_requested.emit("这桌请不成")
		Audio.play("deny", 0.0, -4.0)
		return
	var lines: Array = []
	for line in said:
		lines.append(line)
	close()
	EventBus.meal_requested.emit(people, dishes, lines)
