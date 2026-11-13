class_name InventoryPanel
extends CanvasLayer
## 背包面板：上面是全部格子（第一行就是物品栏），下面一块写着光标所在那样东西的名字、种类、说明和售价。
## 选两格交换位置；翻滚键把物品栏以外的格子整理一遍。

signal closed

const COLS := 8
const W := 206
const H := 162
const GRID_X := 11
const GRID_Y := 21
const CARD_Y := 97
const CARD_H := 46

var _root: Control
var _panel: Control
var _slots: Array[ItemSlot] = []
var _money: Label
var _big_icon: TextureRect
var _title: Label
var _tag: ColorRect
var _tag_text: Label
var _price: Label
var _desc: Label
var _cursor := 0
## 已经拿起、等待放下的格子，-1 表示没有
var _held := -1


func _ready() -> void:
	layer = 20
	_root = UiKit.root()
	add_child(_root)
	_root.add_child(UiKit.dim())

	var panel := UiKit.window()
	_panel = panel
	UiKit.center(panel, Vector2(W, H))
	_root.add_child(panel)

	var head := UiKit.label("背包", 8)
	head.position = Vector2(8, 5)
	panel.add_child(head)
	var tidy := UiKit.button("整理")
	tidy.add_theme_font_size_override(&"font_size", 6)
	tidy.custom_minimum_size = Vector2(26, 11)
	tidy.focus_mode = Control.FOCUS_NONE
	tidy.pressed.connect(tidy_up)
	panel.add_child(tidy)
	tidy.position = Vector2(32, 6)
	tidy.size = Vector2(26, 11)
	var coin := TextureRect.new()
	coin.texture = UiKit.texture("coin")
	coin.position = Vector2(W - 19, 7)
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(coin)
	_money = UiKit.label("", 8, UiKit.MONEY)
	_money.position = Vector2(W - 104, 5)
	_money.size = Vector2(82, 12)
	_money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(_money)

	for i in GameState.INVENTORY_SIZE:
		var slot := ItemSlot.new(i, str(i + 1) if i < GameState.HOTBAR_SIZE else "")
		var row := i / COLS
		# 物品栏那一行和下面隔开一点
		slot.position = Vector2(GRID_X + (i % COLS) * 23, GRID_Y + row * 23 + (3 if row > 0 else 0))
		slot.clicked.connect(_on_slot_clicked)
		slot.hovered.connect(_on_slot_hovered)
		panel.add_child(slot)
		_slots.append(slot)

	var card := UiKit.card()
	card.position = Vector2(8, CARD_Y)
	card.size = Vector2(W - 16, CARD_H)
	panel.add_child(card)
	var frame := NinePatchRect.new()
	frame.texture = UiKit.texture("slot")
	frame.patch_margin_left = 3
	frame.patch_margin_right = 3
	frame.patch_margin_top = 3
	frame.patch_margin_bottom = 3
	frame.position = Vector2(4, 4)
	frame.size = Vector2(38, 38)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(frame)
	# 图标放大一倍
	_big_icon = TextureRect.new()
	_big_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_big_icon.position = Vector2(3, 3)
	_big_icon.scale = Vector2(2, 2)
	_big_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_big_icon)
	_title = UiKit.label("", 8)
	_title.position = Vector2(47, 3)
	card.add_child(_title)
	_tag = ColorRect.new()
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(_tag)
	_tag_text = UiKit.label("", 6, UiKit.TEXT_LIGHT)
	_tag_text.position = Vector2(3, -1)
	_tag.add_child(_tag_text)
	_price = UiKit.label("", 7, UiKit.MONEY)
	_price.position = Vector2(W - 16 - 74, 4)
	_price.size = Vector2(70, 11)
	_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	card.add_child(_price)
	_desc = UiKit.label("", 7, UiKit.TEXT_DIM)
	_desc.position = Vector2(47, 15)
	_desc.size = Vector2(W - 16 - 51, 29)
	_desc.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_desc.max_lines_visible = 3
	card.add_child(_desc)

	var hint := KeyHints.new("空格 拿起/放下    %s 整理    E 关闭" % PauseMenu.keys_of(&"roll").split(" / ")[0])
	hint.position = Vector2(8, H - 17)
	hint.size = Vector2(W - 16, 11)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(hint)

	GameState.inventory.changed.connect(_refresh)
	GameState.money_changed.connect(_refresh)
	_root.visible = false


func is_open() -> bool:
	return _root.visible


func open() -> void:
	_held = -1
	_cursor = GameState.selected_slot
	_root.visible = true
	UiKit.pop(_panel)
	_refresh()


func close() -> void:
	if not _root.visible:
		return
	_root.visible = false
	closed.emit()


## 把物品栏以外的格子整理一遍。
func tidy_up() -> void:
	_held = -1
	GameState.inventory.tidy(GameState.HOTBAR_SIZE)
	Audio.play("plant", 0.0, -6.0)
	_refresh()


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
	elif event.is_action_pressed(&"roll"):
		tidy_up()
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


## 鼠标移到哪一格，说明就跟到哪一格。
func _on_slot_hovered(index: int) -> void:
	if not _root.visible or index == _cursor:
		return
	_cursor = index
	_refresh()


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
	_money.text = "%d 文" % GameState.money
	for i in _slots.size():
		_slots[i].show_item(inv.id_at(i), inv.count_at(i), inv.quality_at(i))
		_slots[i].set_selected(i == _cursor)
		_slots[i].set_held(i == _held)
	var def := Database.item(inv.id_at(_cursor)) if inv.id_at(_cursor) != &"" else null
	_big_icon.texture = UiKit.item_icon(def.id) if def != null else null
	_tag.visible = def != null
	if def == null:
		_title.text = ""
		_price.text = ""
		_desc.text = "这一格是空的。" if _held < 0 else "放到这一格。"
		return
	var count := inv.count_at(_cursor)
	var quality := inv.quality_at(_cursor)
	var title := GameState.display_name(def)
	if quality > 0:
		title += "（%s）" % ItemDef.QUALITY_NAMES[quality]
	_title.text = title if count <= 1 else "%s ×%d" % [title, count]
	var tag: Array = UiKit.KIND_TAGS.get(def.kind, ["杂物", "8a8078"])
	_tag_text.text = tag[0]
	_tag.color = Color(String(tag[1]))
	_tag.position = Vector2(47.0 + ceilf(UiKit.text_width(_title.text)) + 5.0, 5)
	_tag.size = Vector2(ceilf(UiKit.text_width(_tag_text.text, 6)) + 6.0, 9)
	_price.text = "售价 %d 文" % def.price_for(quality) if def.sellable() else ""
	var level := GameState.tool_level(def.id)
	if Shop.CHARGE_TOOLS.has(def.id) and level > 0:
		_desc.text = "%s按住蓄力，最多 %d 格。" % [def.desc, ToolArea.COUNTS[level]]
	elif def.id == Mine.PICKAXE and level > 0:
		_desc.text = "敲开沉灯井里的石头。" + "".join(Shop.PICKAXE_NOTES.slice(0, level))
	else:
		_desc.text = def.desc
