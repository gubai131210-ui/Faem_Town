class_name Hud
extends CanvasLayer
## 游戏中常驻的界面：物品栏、日期时间、金钱、体力、屏幕中央的提示。

const ENERGY_H := 40.0

var _slots: Array[ItemSlot] = []
var _date: Label
var _time: Label
var _money: Label
var _energy_fill: ColorRect
var _banner: Label
var _banner_tween: Tween


func _ready() -> void:
	layer = 10
	var root := UiKit.root()
	add_child(root)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override(&"separation", 1)
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.offset_bottom = -4.0
	root.add_child(bar)
	for i in GameState.HOTBAR_SIZE:
		var slot := ItemSlot.new(i, str(i + 1))
		slot.clicked.connect(_on_slot_clicked)
		bar.add_child(slot)
		_slots.append(slot)

	var clock := UiKit.panel()
	clock.anchor_left = 1.0
	clock.anchor_right = 1.0
	clock.offset_left = -76.0
	clock.offset_right = -4.0
	clock.offset_top = 4.0
	clock.offset_bottom = 46.0
	root.add_child(clock)
	_date = _clock_line(clock, 3.0, UiKit.TEXT_DARK)
	_time = _clock_line(clock, 14.0, UiKit.TEXT_DARK)
	_money = _clock_line(clock, 26.0, Color("9a5a1c"))

	var energy_box := UiKit.panel()
	energy_box.anchor_left = 1.0
	energy_box.anchor_right = 1.0
	energy_box.anchor_top = 1.0
	energy_box.anchor_bottom = 1.0
	energy_box.offset_left = -16.0
	energy_box.offset_right = -4.0
	energy_box.offset_top = -(ENERGY_H + 12.0)
	energy_box.offset_bottom = -4.0
	root.add_child(energy_box)
	var energy_back := ColorRect.new()
	energy_back.color = Color("7d5230")
	energy_back.position = Vector2(4, 4)
	energy_back.size = Vector2(4, ENERGY_H)
	energy_box.add_child(energy_back)
	_energy_fill = ColorRect.new()
	_energy_fill.color = Color("7cc74f")
	energy_box.add_child(_energy_fill)

	_banner = UiKit.label("", 16, UiKit.TEXT_LIGHT, true)
	_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.modulate.a = 0.0
	root.add_child(_banner)

	GameState.inventory.changed.connect(_refresh_items)
	GameState.selected_changed.connect(_refresh_selected)
	GameState.money_changed.connect(_refresh_money)
	GameState.energy_changed.connect(_refresh_energy)
	GameClock.time_changed.connect(_refresh_clock)
	EventBus.banner_requested.connect(show_banner)
	_refresh_items()
	_refresh_selected()
	_refresh_money()
	_refresh_energy()
	_refresh_clock()


func show_banner(text: String) -> void:
	_banner.text = text
	if _banner_tween != null:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.25)
	_banner_tween.tween_interval(1.1)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.5)


func _clock_line(parent: Control, y: float, color: Color) -> Label:
	var l := UiKit.label("", 8, color)
	l.position = Vector2(0, y)
	l.size = Vector2(72, 12)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


func _on_slot_clicked(index: int) -> void:
	GameState.selected_slot = index


func _refresh_items() -> void:
	var inv := GameState.inventory
	for i in _slots.size():
		_slots[i].show_item(inv.id_at(i), inv.count_at(i))


func _refresh_selected() -> void:
	for i in _slots.size():
		_slots[i].set_selected(i == GameState.selected_slot)


func _refresh_money() -> void:
	_money.text = "%d 文" % GameState.money


func _refresh_energy() -> void:
	var ratio := float(GameState.energy) / maxf(1.0, float(GameState.max_energy))
	var h := roundf(ENERGY_H * ratio)
	_energy_fill.position = Vector2(4, 4 + ENERGY_H - h)
	_energy_fill.size = Vector2(4, h)
	_energy_fill.color = Color("7cc74f") if ratio > 0.3 else Color("e0903a") if ratio > 0.12 else Color("c8483c")


func _refresh_clock() -> void:
	_date.text = "%s · 第%d年" % [GameClock.date_text(), GameClock.year()]
	_time.text = GameClock.time_text()
