class_name Hud
extends CanvasLayer
## 游戏中常驻的界面：物品栏、日期和节气、时间和天气、金钱、体力、屏幕左上角的提示条。

const ENERGY_H := 40.0
## 提示条里一行字最宽多少像素，超过就折行
const TOAST_W := 196.0
## 同时最多摞几条，再来新的就把最旧的顶掉
const MAX_TOASTS := 3
const WEATHER_ICONS: Dictionary[StringName, String] = {
	&"sunny": "sun", &"cloudy": "cloud", &"rain": "rain", &"storm": "storm",
	&"fog": "fog", &"wind": "wind", &"snow": "snow", &"frost": "frost",
}

var _slots: Array[ItemSlot] = []
var _date: Label
var _time: Label
var _money: Label
var _weather: TextureRect
var _energy_fill: ColorRect
var _health_box: Control
var _health_fill: ColorRect
var _toasts: VBoxContainer
var _buff_box: Control
var _buff: Label


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
	clock.offset_left = -84.0
	clock.offset_right = -4.0
	clock.offset_top = 4.0
	clock.offset_bottom = 46.0
	root.add_child(clock)
	_date = _clock_line(clock, 3.0, UiKit.TEXT_DARK)
	_time = _clock_line(clock, 14.0, UiKit.TEXT_DARK)
	_money = _clock_line(clock, 26.0, Color("9a5a1c"))
	_weather = TextureRect.new()
	_weather.position = Vector2(58, 14)
	_weather.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clock.add_child(_weather)

	# 吃了带效果的菜：时钟下面一小条，写着效果和还剩多久
	_buff_box = UiKit.panel()
	_buff_box.anchor_left = 1.0
	_buff_box.anchor_right = 1.0
	_buff_box.offset_left = -84.0
	_buff_box.offset_right = -4.0
	_buff_box.offset_top = 48.0
	_buff_box.offset_bottom = 64.0
	_buff_box.visible = false
	root.add_child(_buff_box)
	_buff = _clock_line(_buff_box, 2.0, Color("3f7a3a"))

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

	# 生命：体力左边一根红条，只在井口、井里和受了伤的时候露出来
	_health_box = UiKit.panel()
	_health_box.anchor_left = 1.0
	_health_box.anchor_right = 1.0
	_health_box.anchor_top = 1.0
	_health_box.anchor_bottom = 1.0
	_health_box.offset_left = -30.0
	_health_box.offset_right = -18.0
	_health_box.offset_top = -(ENERGY_H + 12.0)
	_health_box.offset_bottom = -4.0
	root.add_child(_health_box)
	var health_back := ColorRect.new()
	health_back.color = Color("7d5230")
	health_back.position = Vector2(4, 4)
	health_back.size = Vector2(4, ENERGY_H)
	_health_box.add_child(health_back)
	_health_fill = ColorRect.new()
	_health_fill.color = Color("d8504a")
	_health_box.add_child(_health_fill)

	# 提示条摞在左上角，不挡屏幕中间
	_toasts = VBoxContainer.new()
	_toasts.add_theme_constant_override(&"separation", 2)
	_toasts.position = Vector2(4, 4)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toasts)

	GameState.inventory.changed.connect(_refresh_items)
	GameState.selected_changed.connect(_refresh_selected)
	GameState.money_changed.connect(_refresh_money)
	GameState.energy_changed.connect(_refresh_energy)
	GameState.buff_changed.connect(_refresh_clock)
	GameState.health_changed.connect(_refresh_health)
	GameClock.time_changed.connect(_refresh_health)
	GameClock.time_changed.connect(_refresh_clock)
	Weather.changed.connect(_refresh_clock)
	EventBus.banner_requested.connect(show_banner)
	_refresh_items()
	_refresh_selected()
	_refresh_money()
	_refresh_energy()
	_refresh_health()
	_refresh_clock()


## 在左上角出一条提示。头一行是正文，换行以后的是小一号的补充说明。
## 和正挂着的某一条一模一样就只把那一条重新亮起来，不重复摞。
func show_banner(text: String) -> void:
	if text == "":
		return
	for t in _toasts.get_children():
		if t.get_meta(&"text", "") == text:
			_arm(t as Control, text)
			return
	while _toasts.get_child_count() >= MAX_TOASTS:
		var oldest := _toasts.get_child(0)
		_toasts.remove_child(oldest)
		oldest.queue_free()
	var toast := _make_toast(text)
	toast.modulate.a = 0.0
	_toasts.add_child(toast)
	_arm(toast, text)


## 现在挂着几条提示。
func toast_count() -> int:
	return _toasts.get_child_count()


## 挂着的提示各写着什么，从上到下。
func toast_texts() -> PackedStringArray:
	var out: PackedStringArray = []
	for t in _toasts.get_children():
		out.append(String(t.get_meta(&"text", "")))
	return out


## 所有提示条加起来在屏幕上占的那一块。
func toast_rect() -> Rect2:
	return Rect2(_toasts.global_position, _toasts.get_combined_minimum_size())


func _make_toast(text: String) -> Control:
	var box := PanelContainer.new()
	box.set_meta(&"text", text)
	box.add_theme_stylebox_override(&"panel", UiKit.toast_box())
	box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(col)
	var cut := text.find("\n")
	col.add_child(_toast_label(text if cut < 0 else text.substr(0, cut), 8, UiKit.TEXT_LIGHT))
	if cut >= 0 and cut < text.length() - 1:
		col.add_child(_toast_label(text.substr(cut + 1), 7, Color("e8d6ac")))
	return box


## 提示条里的一段字：短的有多宽占多宽，长的到 TOAST_W 折行。
func _toast_label(text: String, size: int, color: Color) -> Label:
	var l := UiKit.label(text, size, color)
	var widest := 0.0
	for line in text.split("\n"):
		widest = maxf(widest, UiKit.text_width(line, size))
	l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	l.custom_minimum_size = Vector2(minf(TOAST_W, ceilf(widest) + 1.0), 0)
	return l


## 让一条提示亮起来、停一阵、淡掉、收走。
func _arm(toast: Control, text: String) -> void:
	# get_meta 的默认值给 null 等于没给，没有这个键照样报错，所以先问有没有
	if toast.has_meta(&"tween"):
		var old: Variant = toast.get_meta(&"tween")
		if old is Tween:
			(old as Tween).kill()
	var tw := toast.create_tween()
	toast.set_meta(&"tween", tw)
	tw.tween_property(toast, "modulate:a", 1.0, 0.18)
	# 字多的提示多停一会儿，不然来不及看完
	tw.tween_interval(banner_hold(text))
	tw.tween_property(toast, "modulate:a", 0.0, 0.4)
	tw.tween_callback(toast.queue_free)


## 一条提示在屏幕上停多久（不算淡入淡出）：十来个字以内 1.1 秒，往后每多一个字多停一点，最多 4 秒。
static func banner_hold(text: String) -> float:
	return clampf(1.1 + (text.length() - 14) * 0.07, 1.1, 4.0)


func _clock_line(parent: Control, y: float, color: Color) -> Label:
	var l := UiKit.label("", 8, color)
	l.position = Vector2(0, y)
	l.size = Vector2(80, 12)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


func _on_slot_clicked(index: int) -> void:
	GameState.selected_slot = index


func _refresh_items() -> void:
	var inv := GameState.inventory
	for i in _slots.size():
		_slots[i].show_item(inv.id_at(i), inv.count_at(i), inv.quality_at(i))


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


## 生命条现在该不该露出来。
func health_shown() -> bool:
	return GameState.health < GameState.max_health or GameState.map_id == &"mine" or GameState.map_id == &"wellhead"


func _refresh_health() -> void:
	_health_box.visible = health_shown()
	var ratio := float(GameState.health) / maxf(1.0, float(GameState.max_health))
	var h := roundf(ENERGY_H * ratio)
	_health_fill.position = Vector2(4, 4 + ENERGY_H - h)
	_health_fill.size = Vector2(4, h)


func _refresh_clock() -> void:
	_date.text = "%s · %s" % [GameClock.date_text(), GameClock.term_name()]
	_time.text = GameClock.time_text()
	var buff := GameState.buff_text()
	_buff_box.visible = buff != ""
	_buff.text = buff
	_weather.texture = UiKit.texture(WEATHER_ICONS.get(Weather.today, "sun"))
