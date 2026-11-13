class_name ShopPanel
extends CanvasLayer
## 铺子的货单：杂货铺卖种子、肥料、树苗，铁匠铺升级工具，用键盘或鼠标购买。

signal closed

const ROW_H := 18
const VISIBLE_ROWS := 6
const PANEL_W := 196
const LIST_TOP := 20

var _root: Control
var _panel: Control
var _head: Label
var _money: Label
var _desc: Label
var _more: Label
var _rows: Array[Control] = []
var _stock: Array[ShopEntry] = []
var _cursor := 0
var _scroll := 0
var _counter: StringName = &""


func _ready() -> void:
	layer = 20
	_root = UiKit.root()
	add_child(_root)
	_root.add_child(UiKit.dim())

	var panel := UiKit.window()
	_panel = panel
	UiKit.center(panel, Vector2(PANEL_W, LIST_TOP + VISIBLE_ROWS * ROW_H + 40))
	_root.add_child(panel)

	_head = UiKit.label("", 8)
	_head.position = Vector2(8, 5)
	panel.add_child(_head)
	_money = UiKit.label("", 8, Color("9a5a1c"))
	_money.position = Vector2(8, 5)
	_money.size = Vector2(PANEL_W - 16, 12)
	_money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(_money)

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
	_desc = UiKit.label("", 7, UiKit.TEXT_DIM)
	_desc.position = Vector2(8, info_y + 8.0)
	_desc.size = Vector2(PANEL_W - 16, 12)
	panel.add_child(_desc)
	var hint := KeyHints.new("空格 买 1 个    → 买 5 个    E 关闭")
	hint.position = Vector2(8, info_y + 22.0)
	hint.size = Vector2(PANEL_W - 16, 10)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(hint)

	GameState.money_changed.connect(_refresh)
	GameState.inventory.changed.connect(_refresh)
	_root.visible = false


func is_open() -> bool:
	return _root.visible


func open(counter: StringName = &"") -> void:
	_counter = counter
	_stock = Shop.entries(GameClock.season_id(), _counter)
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


## 买光标所在的那种种子；钱不够或放不下时能买几个买几个，一个都买不了就提示。
func buy_selected(want: int) -> bool:
	if _cursor < 0 or _cursor >= _stock.size():
		return false
	var entry := _stock[_cursor]
	var n := Shop.affordable_entry(entry, want)
	if n <= 0 or not Shop.buy_entry(entry, n):
		Audio.play("deny", 0.0, -4.0)
		if GameState.money < entry.price:
			_desc.text = "钱不够"
		elif not Shop.has_materials(entry):
			_desc.text = "材料不够"
		else:
			_desc.text = "背包放不下了"
		return false
	Audio.play("plant", 0.0, -4.0)
	if entry.flag != &"":
		EventBus.banner_requested.emit("%s买下了，石叔会送到农场屋子东边" % entry.name)
	if entry.upgrade or entry.once:
		# 升完一级，目录里换成下一级（或者没有了）；工具买过就不再卖
		_stock = Shop.entries(GameClock.season_id(), _counter)
		_cursor = clampi(_cursor, 0, maxi(0, _stock.size() - 1))
		_scroll = clampi(_scroll, maxi(0, _cursor - VISIBLE_ROWS + 1), _cursor)
		_refresh()
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
		buy_selected(1)
	elif event.is_action_pressed(&"move_right"):
		buy_selected(5)
	else:
		return
	get_viewport().set_input_as_handled()


func _move(d: int) -> void:
	if _stock.is_empty():
		return
	_cursor = posmod(_cursor + d, _stock.size())
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
	back.position = Vector2(0, 0)
	back.size = Vector2(PANEL_W - 12, ROW_H - 1)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(back)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.position = Vector2(2, 0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var item_name := UiKit.label("", 8)
	item_name.name = "ItemName"
	item_name.position = Vector2(22, 3)
	row.add_child(item_name)
	var owned := UiKit.label("", 6, UiKit.TEXT_DIM)
	owned.name = "Owned"
	owned.position = Vector2(104, 5)
	owned.size = Vector2(32, 10)
	owned.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(owned)
	var price := UiKit.label("", 8, Color("9a5a1c"))
	price.name = "Price"
	price.position = Vector2(138, 3)
	price.size = Vector2(42, 12)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(price)
	return row


func _on_row_input(event: InputEvent, i: int) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var index := _scroll + i
	if index >= _stock.size():
		return
	if index == _cursor:
		buy_selected(1)
	else:
		_cursor = index
		_refresh()


func _refresh() -> void:
	if not _root.visible:
		return
	var title: String = Shop.COUNTER_NAMES.get(_counter, "货单")
	_head.text = "%s · %s季" % [title, GameClock.SEASON_NAMES[GameClock.season()]]
	_money.text = "%d 文" % GameState.money
	for i in _rows.size():
		var row := _rows[i]
		var index := _scroll + i
		row.visible = index < _stock.size()
		if not row.visible:
			continue
		var def := _stock[index]
		var back: ColorRect = row.get_node("Back")
		back.visible = index == _cursor
		var icon: TextureRect = row.get_node("Icon")
		icon.texture = UiKit.texture(def.icon)
		var item_name: Label = row.get_node("ItemName")
		item_name.text = def.name
		var owned: Label = row.get_node("Owned")
		var have := 0 if def.upgrade or def.flag != &"" else GameState.inventory.count_of(def.item_id)
		owned.text = "已有 %d" % have if have > 0 else ""
		var price: Label = row.get_node("Price")
		price.text = "%d 文" % def.price
		price.add_theme_color_override(&"font_color", Color("9a5a1c") if GameState.money >= def.price else Color("c8483c"))
	if _stock.is_empty():
		_desc.text = "眼下没有可做的买卖。"
		_more.text = ""
		return
	_more.text = "%d / %d" % [_cursor + 1, _stock.size()] if _stock.size() > VISIBLE_ROWS else ""
	_desc.text = _stock[_cursor].desc
