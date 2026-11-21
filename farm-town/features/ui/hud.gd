class_name Hud
extends CanvasLayer
## 游戏中常驻的界面：物品栏、手里这件东西的名字、日期和节气、时间和天气、金钱、体力、屏幕左上角的提示条。

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
var _guide: NinePatchRect
var _guide_label: Label
var _held_name: Label
var _fly_layer: Node2D
var _season_card: Control
var _season_label: Label
var _season_tween: Tween
var _money_tween: Tween
var _shown_money := 0
var _money_first := true


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

	# 手里这件东西的名字，贴在物品栏正上方；空格就不写
	_held_name = UiKit.label("", 8, UiKit.TEXT_LIGHT, true)
	_held_name.anchor_left = 0.5
	_held_name.anchor_right = 0.5
	_held_name.anchor_top = 1.0
	_held_name.anchor_bottom = 1.0
	_held_name.offset_left = -80.0
	_held_name.offset_right = 80.0
	_held_name.offset_top = -40.0
	_held_name.offset_bottom = -28.0
	_held_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_held_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_held_name.clip_text = true
	root.add_child(_held_name)

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

	# 第一天的下一步，贴在左下角、物品栏左边
	_guide = UiKit.panel()
	_guide.anchor_top = 1.0
	_guide.anchor_bottom = 1.0
	_guide.offset_left = 4.0
	_guide.offset_top = -48.0
	_guide.offset_right = 108.0
	_guide.offset_bottom = -28.0
	_guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guide.visible = false
	root.add_child(_guide)
	_guide_label = UiKit.label("", 6, UiKit.TEXT_DARK)
	_guide_label.position = Vector2(6, 4)
	_guide_label.size = Vector2(92, 14)
	_guide_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_guide.add_child(_guide_label)

	# 提示条摞在左上角，不挡屏幕中间
	_toasts = VBoxContainer.new()
	_toasts.add_theme_constant_override(&"separation", 2)
	_toasts.position = Vector2(4, 4)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toasts)

	# 换季那天早上在上半屏亮一下，避开左上角的提示条，也不压到画面中间
	_season_card = UiKit.panel()
	_season_card.anchor_left = 0.5
	_season_card.anchor_right = 0.5
	_season_card.offset_left = -86.0
	_season_card.offset_right = 86.0
	_season_card.offset_top = 74.0
	_season_card.offset_bottom = 104.0
	_season_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_season_card.visible = false
	root.add_child(_season_card)
	_season_label = UiKit.label("", 10, UiKit.TEXT_LIGHT, true)
	_season_label.position = Vector2(0, 6)
	_season_label.size = Vector2(172, 16)
	_season_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_season_card.add_child(_season_label)

	# 飞向物品栏的图标单独放一层，压在界面上、跟着 Hud 一起换场景
	_fly_layer = Node2D.new()
	root.add_child(_fly_layer)

	GameState.inventory.changed.connect(_refresh_items)
	GameState.inventory.gained.connect(_on_item_gained)
	GameState.selected_changed.connect(_refresh_selected)
	GameState.money_changed.connect(_refresh_money)
	GameState.energy_changed.connect(_refresh_energy)
	GameState.buff_changed.connect(_refresh_clock)
	GameState.health_changed.connect(_refresh_health)
	GameClock.time_changed.connect(_refresh_health)
	GameClock.time_changed.connect(_refresh_clock)
	Weather.changed.connect(_refresh_clock)
	EventBus.banner_requested.connect(show_banner)
	EventBus.season_card_requested.connect(show_season_card)
	_refresh_items()
	_refresh_selected()
	_refresh_money()
	_refresh_energy()
	_refresh_health()
	_refresh_clock()


## 在左上角出一条提示。头一行是正文，换行以后的是小一号的补充说明。
## 和正挂着的某一条一模一样就只把那一条重新亮起来，不重复摞。
func _process(_delta: float) -> void:
	var text := Guide.line()
	_guide.visible = text != ""
	if _guide_label.text != text:
		_guide_label.text = text


## 左下角现在写着的下一步；没有时是空的。
func guide_text() -> String:
	return _guide_label.text if _guide.visible else ""


## 物品栏正上方现在写的名字；空手时是空的。和背包详情同一套叫法。
func held_name() -> String:
	return _held_name.text


func _held_caption() -> String:
	var inv := GameState.inventory
	var id := inv.id_at(GameState.selected_slot)
	if id == &"":
		return ""
	var title := GameState.display_name(Database.item(id))
	var quality := inv.quality_at(GameState.selected_slot)
	if quality > 0:
		title += "（%s）" % ItemDef.QUALITY_NAMES[quality]
	return title


## 换季那天早上亮一下季节和节气；亮完自己收起来，不占着屏幕。
func show_season_card(text: String) -> void:
	if text == "":
		return
	_season_label.text = text
	_season_card.visible = true
	_season_card.modulate.a = 0.0
	if _season_tween != null and _season_tween.is_valid():
		_season_tween.kill()
	var tw := _season_card.create_tween()
	_season_tween = tw
	tw.tween_method(_season_step.bind([_season_card]), 0.0, 1.0, UiMotion.SEASON_CARD_TIME)
	tw.tween_callback(_season_hide.bind(_season_card))


static func _season_step(t: float, args: Array) -> void:
	var card: Control = args[0]
	if is_instance_valid(card):
		card.modulate.a = UiMotion.season_card_alpha(t * UiMotion.SEASON_CARD_TIME)


static func _season_hide(card: Control) -> void:
	if is_instance_valid(card):
		card.visible = false


## 现在正有几个图标在往物品栏飞。
func fly_count() -> int:
	return _fly_layer.get_child_count() if _fly_layer != null else 0


## 收进一件东西就飞一个图标过去。落在超出物品栏的格子时，飞到最后一格。
func _on_item_gained(id: StringName, slot: int) -> void:
	var tex := UiKit.item_icon(id)
	if tex == null or _fly_layer == null or _slots.is_empty():
		return
	# 读档站在井里、有欠着的首领掉落时，gained 会在建 Hud 的同一帧触发，
	# 那时格子还没排序、落点是 (0,0)；等一帧排好版再取落点
	await get_tree().process_frame
	if not is_instance_valid(self) or _fly_layer == null or _slots.is_empty():
		return
	var target := clampi(slot, 0, _slots.size() - 1)
	var to := _slots[target].global_position + Vector2(ItemSlot.SIZE / 2.0, ItemSlot.SIZE / 2.0)
	var vp := get_viewport().get_visible_rect().size
	var from := Vector2(vp.x * 0.5, vp.y * 0.62)
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = true
	s.position = from
	_fly_layer.add_child(s)
	# tween 挂在图标自己身上：换场景时跟着一起停，不会回头找已释放的节点
	var tw := s.create_tween()
	tw.tween_method(_fly_step.bind([s, from, to]), 0.0, 1.0, 0.5)
	tw.tween_property(s, "modulate:a", 0.0, 0.12)
	tw.tween_callback(s.queue_free)


static func _fly_step(t: float, args: Array) -> void:
	var s: Sprite2D = args[0]
	if is_instance_valid(s):
		s.position = UiMotion.fly_pos(args[1], args[2], t)


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


## 把还挂着的提示收掉。换日子、换地方时，上一幕的句子不该跟着过去。
func dismiss_toasts() -> void:
	for t in _toasts.get_children():
		if t.has_meta(&"tween"):
			var old: Variant = t.get_meta(&"tween")
			if old is Tween:
				(old as Tween).kill()
		t.queue_free()


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
	_held_name.text = _held_caption()


func _refresh_selected() -> void:
	for i in _slots.size():
		_slots[i].set_selected(i == GameState.selected_slot)
	_held_name.text = _held_caption()


## 钱变了就滚过去，先快后慢，落点一定是准确的数。第一次刷新不滚，
## 免得开局从 0 滚到手里的钱。
func _refresh_money() -> void:
	var to := GameState.money
	if _money_first:
		_money_first = false
		_shown_money = to
		_money.text = "%d 文" % to
		return
	var from := _shown_money
	if from == to:
		return
	if _money_tween != null and _money_tween.is_valid():
		_money_tween.kill()
	var tw := _money.create_tween()
	_money_tween = tw
	tw.tween_method(_money_step.bind([from, to]), 0.0, 1.0, 0.45)
	tw.tween_callback(_money_land.bind(to))


func _money_step(t: float, args: Array) -> void:
	_shown_money = UiMotion.money_shown(int(args[0]), int(args[1]), t)
	_money.text = "%d 文" % _shown_money


func _money_land(to: int) -> void:
	_shown_money = to
	_money.text = "%d 文" % to


func _refresh_energy() -> void:
	var ratio := float(GameState.energy) / maxf(1.0, float(GameState.max_energy))
	var h := roundf(ENERGY_H * ratio)
	_energy_fill.position = Vector2(4, 4 + ENERGY_H - h)
	_energy_fill.size = Vector2(4, h)
	_energy_fill.color = Color("7cc74f") if ratio > 0.3 else Color("e0903a") if ratio > 0.12 else Color("c8483c")


## 生命条现在该不该露出来。
func health_shown() -> bool:
	return GameState.health < GameState.max_health or GameState.map_id == &"mine" or GameState.map_id == &"wellhead" or GameState.map_id == &"zhuhai" or GameState.map_id == &"houshan" or GameState.map_id == &"wudao"


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
