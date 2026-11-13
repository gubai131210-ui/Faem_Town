class_name ResidentsPanel
extends CanvasLayer
## 名册：见过的居民、熟悉度、忆的等级、今天有没有说过话送过礼、送过以后知道的喜好。
## 按 ←→ 翻页：第二页“忆簿”，找回的记忆按那一天前后的顺序排成一条线；第三页“鱼谱”，钓到过的鱼和最长记录。

signal closed

const PANEL_SIZE := Vector2(324, 178)
const ROW_H := 12
const LIST_W := 112
const DETAIL_X := 128.0
const BAR_W := 100.0
const MAX_ICONS := 8
## 喜好分三行显示：[反应, 标题]
const TASTE_ROWS: Array = [[&"love", "最喜欢"], [&"like", "喜欢"], [&"dislike", "不喜欢"]]
const PAGES := 3
const PAGE_NAMES: Array[String] = ["名册", "忆簿", "鱼谱"]
## 鱼谱的格子：每行几条、每格多大
const FISH_COLS := 6
const FISH_CELL := 20
const WATER_NAMES: Dictionary[StringName, String] = {
	&"pond": "池塘", &"stream": "溪", &"river": "河", &"lake": "山顶湖", &"sea": "东滩",
	&"mine_shallow": "井下暗河", &"mine_deep": "井下深处",
}
const SEASON_NAMES: Dictionary[StringName, String] = {&"spring": "春", &"summer": "夏", &"autumn": "秋", &"winter": "冬"}

var _root: Control
var _panel: Control
var _head: Label
var _hint: KeyHints
## 第一页名册，第二页忆簿
var _page := 0
var _roster: Control
var _book: Control
var _book_rows: Array[Control] = []
var _book_cursor := 0
var _book_title: Label
var _book_when: Label
var _book_text: Label
var _book_empty: Label
var _memory: Label
## 第三页鱼谱
var _fishbook: Control
var _fish_ids: Array[StringName] = []
var _fish_cells: Array[Control] = []
var _fish_cursor := 0
var _fish_name: Label
var _fish_where: Label
var _fish_record: Label
var _fish_desc: Label
var _fish_total: Label
var _fish_big: TextureRect
var _ids: Array[StringName] = []
var _rows: Array[Control] = []
var _cursor := 0
var _face: TextureRect
var _name: Label
var _role: Label
var _points: Label
var _bar: ColorRect
var _today: Label
var _note: Label
## 反应 -> 那一行的图标
var _taste_icons: Dictionary[StringName, Array] = {}
var _taste_empty: Dictionary[StringName, Label] = {}


func _ready() -> void:
	layer = 20
	_root = UiKit.root()
	add_child(_root)
	_root.add_child(UiKit.dim())

	var panel := UiKit.window()
	_panel = panel
	UiKit.center(panel, PANEL_SIZE)
	_root.add_child(panel)
	_head = UiKit.label("名册", 8)
	_head.position = Vector2(8, 5)
	panel.add_child(_head)
	_hint = KeyHints.new()
	_hint.position = Vector2(8, 6)
	_hint.size = Vector2(PANEL_SIZE.x - 16, 10)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(_hint)

	_roster = Control.new()
	_roster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_roster.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(_roster)
	_book = Control.new()
	_book.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.set_anchors_preset(Control.PRESET_FULL_RECT)
	_book.visible = false
	panel.add_child(_book)
	_build_book()
	_fishbook = Control.new()
	_fishbook.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fishbook.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fishbook.visible = false
	panel.add_child(_fishbook)
	_build_fishbook()

	for id: StringName in Database.npcs:
		_ids.append(id)
	for i in _ids.size():
		var row := _make_row(i)
		row.position = Vector2(8, 20 + i * ROW_H)
		_roster.add_child(row)
		_rows.append(row)

	var frame := UiKit.panel()
	frame.position = Vector2(DETAIL_X, 20)
	frame.size = Vector2(72, 72)
	_roster.add_child(frame)
	_face = TextureRect.new()
	_face.position = Vector2(4, 4)
	_face.size = Vector2(64, 64)
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_face)

	var x := DETAIL_X + 80.0
	_name = UiKit.label("", 10)
	_name.position = Vector2(x, 20)
	_roster.add_child(_name)
	_role = UiKit.label("", 7, UiKit.TEXT_DIM)
	_role.position = Vector2(x, 36)
	_roster.add_child(_role)
	_points = UiKit.label("", 7)
	_points.position = Vector2(x, 50)
	_roster.add_child(_points)
	var bar_back := ColorRect.new()
	bar_back.color = Color("c9a074")
	bar_back.position = Vector2(x, 62)
	bar_back.size = Vector2(BAR_W, 5)
	_roster.add_child(bar_back)
	_bar = ColorRect.new()
	_bar.color = Color("d8584a")
	_bar.position = Vector2(x, 62)
	_bar.size = Vector2(0, 5)
	_roster.add_child(_bar)
	_today = UiKit.label("", 6, UiKit.TEXT_DIM)
	_today.position = Vector2(x, 70)
	_roster.add_child(_today)
	_memory = UiKit.label("", 6, Color("9a5a1c"))
	_memory.position = Vector2(x + 60.0, 50)
	_roster.add_child(_memory)
	_note = UiKit.label("", 6, Color("9a5a1c"))
	_note.position = Vector2(x, 80)
	_note.size = Vector2(PANEL_SIZE.x - x - 8.0, 20)
	_note.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_roster.add_child(_note)

	for k in TASTE_ROWS.size():
		var taste: StringName = TASTE_ROWS[k][0]
		var y := 100.0 + k * 24.0
		var title := UiKit.label(str(TASTE_ROWS[k][1]), 7)
		title.position = Vector2(DETAIL_X, y + 3.0)
		_roster.add_child(title)
		var empty := UiKit.label("还不知道", 6, UiKit.TEXT_DIM)
		empty.position = Vector2(DETAIL_X + 40.0, y + 4.0)
		_roster.add_child(empty)
		_taste_empty[taste] = empty
		var icons: Array = []
		for i in MAX_ICONS:
			var icon := TextureRect.new()
			icon.position = Vector2(DETAIL_X + 40.0 + i * 18.0, y)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_roster.add_child(icon)
			icons.append(icon)
		_taste_icons[taste] = icons

	Residents.changed.connect(_refresh)
	Fishing.changed.connect(_refresh)
	_root.visible = false


func is_open() -> bool:
	return _root.visible


func open() -> void:
	_root.visible = true
	UiKit.pop(_panel)
	_refresh()


## 直接翻到忆簿那一页。
func open_book() -> void:
	_page = 1
	open()


func close() -> void:
	if not _root.visible:
		return
	_root.visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event.is_action_pressed(&"residents") or event.is_action_pressed(&"inventory") \
			or event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		close()
	elif event.is_action_pressed(&"move_up", true):
		_move(-1)
	elif event.is_action_pressed(&"move_down", true):
		_move(1)
	elif event.is_action_pressed(&"move_left") or event.is_action_pressed(&"move_right"):
		_page = posmod(_page + (1 if event.is_action_pressed(&"move_right") else -1), PAGES)
		Audio.play("select", 0.0, -10.0)
		_refresh()
	else:
		return
	get_viewport().set_input_as_handled()


func _move(d: int) -> void:
	if _page == 2:
		if not _fish_ids.is_empty():
			_fish_cursor = posmod(_fish_cursor + d, _fish_ids.size())
			Audio.play("select", 0.0, -10.0)
			_refresh()
		return
	if _page == 1:
		var n := Residents.recovered().size()
		if n > 0:
			_book_cursor = posmod(_book_cursor + d, n)
			Audio.play("select", 0.0, -10.0)
			_refresh()
		return
	if _ids.is_empty():
		return
	_cursor = posmod(_cursor + d, _ids.size())
	Audio.play("select", 0.0, -10.0)
	_refresh()


## 忆簿那一页的控件：左边一条时间线，右边是选中那段的全文。
func _build_book() -> void:
	for i in 11:
		var row := Control.new()
		row.size = Vector2(LIST_W + 20, ROW_H)
		row.position = Vector2(8, 20 + i * ROW_H)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var back := ColorRect.new()
		back.name = "Back"
		back.color = Color("e2c088")
		back.size = Vector2(LIST_W + 20, ROW_H - 1)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(back)
		var dot := ColorRect.new()
		dot.name = "Dot"
		dot.color = Color("c8483c")
		dot.position = Vector2(3, 4)
		dot.size = Vector2(3, 3)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(dot)
		var when := UiKit.label("", 6, UiKit.TEXT_DIM)
		when.name = "When"
		when.position = Vector2(10, 1)
		row.add_child(when)
		var who := UiKit.label("", 7)
		who.name = "Who"
		who.position = Vector2(64, 0)
		row.add_child(who)
		_book.add_child(row)
		_book_rows.append(row)
	var line := ColorRect.new()
	line.color = Color("c9a074")
	line.position = Vector2(12, 20)
	line.size = Vector2(1, 11 * ROW_H)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.add_child(line)
	line.z_index = -1
	_book_empty = UiKit.label("还没有找回任何记忆。\n把旧物还给它的主人，这里就会多一行。", 7, UiKit.TEXT_DIM)
	_book_empty.position = Vector2(20, 24)
	_book_empty.size = Vector2(LIST_W, 40)
	_book.add_child(_book_empty)
	var x := LIST_W + 40.0
	_book_title = UiKit.label("", 10)
	_book_title.position = Vector2(x, 22)
	_book.add_child(_book_title)
	_book_when = UiKit.label("", 7, UiKit.TEXT_DIM)
	_book_when.position = Vector2(x, 38)
	_book.add_child(_book_when)
	_book_text = UiKit.label("", 7)
	_book_text.position = Vector2(x, 54)
	_book_text.size = Vector2(PANEL_SIZE.x - x - 10.0, 110)
	_book_text.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_book.add_child(_book_text)


## 鱼谱那一页的控件：左边一格一条鱼的图标，右边是选中那条的名字、水域、记录。
func _build_fishbook() -> void:
	for id: StringName in Database.fish:
		_fish_ids.append(id)
	for i in _fish_ids.size():
		var cell := Control.new()
		cell.size = Vector2(FISH_CELL, FISH_CELL)
		cell.position = Vector2(8 + (i % FISH_COLS) * FISH_CELL, 20 + (i / FISH_COLS) * FISH_CELL)
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		cell.gui_input.connect(_on_fish_input.bind(i))
		var back := ColorRect.new()
		back.name = "Back"
		back.color = Color("e2c088")
		back.size = Vector2(FISH_CELL - 1, FISH_CELL - 1)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(back)
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.position = Vector2(2, 2)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = UiKit.item_icon(_fish_ids[i])
		cell.add_child(icon)
		_fishbook.add_child(cell)
		_fish_cells.append(cell)
	_fish_total = UiKit.label("", 6, UiKit.TEXT_DIM)
	_fish_total.position = Vector2(8, 22 + ceili(_fish_ids.size() / float(FISH_COLS)) * FISH_CELL)
	_fishbook.add_child(_fish_total)

	var x := 8.0 + FISH_COLS * FISH_CELL + 12.0
	var frame := UiKit.panel()
	frame.position = Vector2(x, 20)
	frame.size = Vector2(40, 40)
	_fishbook.add_child(frame)
	_fish_big = TextureRect.new()
	_fish_big.position = Vector2(4, 4)
	_fish_big.size = Vector2(32, 32)
	_fish_big.stretch_mode = TextureRect.STRETCH_SCALE
	_fish_big.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fish_big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_fish_big)
	_fish_name = UiKit.label("", 10)
	_fish_name.position = Vector2(x + 48.0, 22)
	_fishbook.add_child(_fish_name)
	_fish_where = UiKit.label("", 7, UiKit.TEXT_DIM)
	_fish_where.position = Vector2(x + 48.0, 38)
	_fish_where.size = Vector2(PANEL_SIZE.x - x - 56.0, 20)
	_fish_where.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_fishbook.add_child(_fish_where)
	_fish_record = UiKit.label("", 7, Color("9a5a1c"))
	_fish_record.position = Vector2(x, 66)
	_fishbook.add_child(_fish_record)
	_fish_desc = UiKit.label("", 7)
	_fish_desc.position = Vector2(x, 80)
	_fish_desc.size = Vector2(PANEL_SIZE.x - x - 8.0, 90)
	_fish_desc.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_fishbook.add_child(_fish_desc)


func _on_fish_input(event: InputEvent, i: int) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_fish_cursor = i
		_refresh()


## 这条鱼在哪儿、什么时候：水域、季节、时辰、天气。
static func fish_where(def: FishDef) -> String:
	var waters := PackedStringArray()
	for w in def.waters:
		waters.append(WATER_NAMES.get(w, String(w)))
	var parts := PackedStringArray(["、".join(waters)])
	if def.seasons.is_empty():
		parts.append("全年")
	else:
		var seasons := ""
		for s in def.seasons:
			seasons += SEASON_NAMES.get(s, "")
		parts.append(seasons)
	if def.time == &"night":
		parts.append("夜里")
	elif def.time == &"day":
		parts.append("白天")
	if def.weather == &"rain":
		parts.append("雨天")
	elif def.weather == &"fog":
		parts.append("雾天")
	if def.trap:
		parts.append("蟹笼")
	return " · ".join(parts)


func _refresh_fishbook() -> void:
	_fish_cursor = clampi(_fish_cursor, 0, maxi(0, _fish_ids.size() - 1))
	var seen := 0
	for i in _fish_cells.size():
		var id := _fish_ids[i]
		var got := Fishing.caught(id) > 0
		if got:
			seen += 1
		var cell := _fish_cells[i]
		var back: ColorRect = cell.get_node("Back")
		back.visible = i == _fish_cursor
		var icon: TextureRect = cell.get_node("Icon")
		icon.modulate = Color.WHITE if got else Color(0.25, 0.22, 0.2, 0.55)
	_fish_total.text = "钓到过 %d / %d 种 · 鱼竿 %d 级" % [seen, _fish_ids.size(), GameState.tool_level(&"rod") + 1]
	if _fish_ids.is_empty():
		return
	var id := _fish_ids[_fish_cursor]
	var def := Database.fish_def(id)
	var got := Fishing.caught(id) > 0
	_fish_big.texture = UiKit.item_icon(id)
	_fish_big.modulate = Color.WHITE if got else Color(0.25, 0.22, 0.2, 0.55)
	_fish_name.text = def.name if got else "？？？"
	var hint := ""
	if not def.waters.is_empty():
		hint = String(WATER_NAMES.get(def.waters[0], "")) + "里有这么一种"
	_fish_where.text = fish_where(def) if got else hint
	_fish_record.text = "钓到 %d 条 · 最长 %d 厘米" % [Fishing.caught(id), Fishing.best(id)] if got else "还没钓到过"
	_fish_desc.text = def.desc if got else ""


func _refresh_book() -> void:
	var list := Residents.recovered()
	_book_cursor = clampi(_book_cursor, 0, maxi(0, list.size() - 1))
	_book_empty.visible = list.is_empty()
	for i in _book_rows.size():
		var row := _book_rows[i]
		row.visible = i < list.size()
		if not row.visible:
			continue
		var m := list[i]
		var back: ColorRect = row.get_node("Back")
		back.visible = i == _book_cursor
		var when: Label = row.get_node("When")
		when.text = m.when
		var who: Label = row.get_node("Who")
		who.text = "%s · %s" % [Database.npc(m.npc).name, m.title]
	if list.is_empty():
		_book_title.text = ""
		_book_when.text = ""
		_book_text.text = ""
		return
	var cur := list[_book_cursor]
	_book_title.text = cur.title
	_book_when.text = "%s · %s" % [cur.when, Database.npc(cur.npc).name]
	_book_text.text = cur.text


func _make_row(i: int) -> Control:
	var row := Control.new()
	row.size = Vector2(LIST_W, ROW_H)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.gui_input.connect(_on_row_input.bind(i))
	var back := UiKit.row_back()
	back.name = "Back"
	back.color = Color("e2c088")
	back.size = Vector2(LIST_W, ROW_H - 1)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(back)
	var who := UiKit.label("", 7)
	who.name = "Who"
	who.position = Vector2(4, 0)
	row.add_child(who)
	var bar_back := ColorRect.new()
	bar_back.name = "BarBack"
	bar_back.color = Color("c9a074")
	bar_back.position = Vector2(62, 4)
	bar_back.size = Vector2(44, 3)
	bar_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar_back)
	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.color = Color("d8584a")
	fill.position = Vector2(62, 4)
	fill.size = Vector2(0, 3)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(fill)
	return row


func _on_row_input(event: InputEvent, i: int) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_cursor = i
		_refresh()


## 熟悉度占“现在最多能攒到的量”的几成。
func _ratio(id: StringName) -> float:
	return clampf(float(Residents.familiarity_of(id)) / Residents.familiarity_cap(id), 0.0, 1.0)


func _refresh() -> void:
	if not _root.visible or _ids.is_empty():
		return
	_roster.visible = _page == 0
	_book.visible = _page == 1
	_fishbook.visible = _page == 2
	_head.text = PAGE_NAMES[_page]
	_hint.text = ["↑↓ 选人", "↑↓ 选一段", "↑↓ 选鱼"][_page] + "    ←→ 翻页    R 关闭"
	if _page == 2:
		_refresh_fishbook()
		return
	if _page == 1:
		_refresh_book()
		return
	for i in _rows.size():
		var row := _rows[i]
		var row_id := _ids[i]
		var seen := Residents.has_met(row_id)
		var back: ColorRect = row.get_node("Back")
		back.visible = i == _cursor
		var who: Label = row.get_node("Who")
		who.text = Database.npc(row_id).name if seen else "？？？"
		var bar_back: ColorRect = row.get_node("BarBack")
		bar_back.visible = seen
		var fill: ColorRect = row.get_node("Fill")
		fill.visible = seen
		fill.size.x = roundf(44.0 * _ratio(row_id))

	var id := _ids[_cursor]
	var def := Database.npc(id)
	var met := Residents.has_met(id)
	_face.texture = UiKit.face(def.sheet) if met else null
	_name.text = def.name if met else "？？？"
	_role.text = def.role if met else "还没见过这个人"
	_points.visible = met
	_bar.visible = met
	_points.text = "熟悉 %d / %d" % [Residents.familiarity_of(id), Residents.familiarity_cap(id)]
	_bar.size.x = roundf(BAR_W * _ratio(id))
	var today := PackedStringArray()
	if Residents.talks(id) > 0:
		today.append("今天说过话")
	if Residents.gifted_today.get(id, false):
		today.append("今天送过礼")
	_today.text = " · ".join(today) if met else ""
	_memory.text = "忆 %d / 5" % Residents.memory_level(id) if met else ""
	var full := met and Residents.familiarity_of(id) >= Residents.familiarity_cap(id)
	_note.text = "再熟也只能到这儿了，还缺一件能让对方想起什么的旧物。" if full else ""
	for row_def: Array in TASTE_ROWS:
		var taste: StringName = row_def[0]
		var items := Residents.known(id, taste) if met else ([] as Array[StringName])
		_taste_empty[taste].visible = items.is_empty()
		var icons: Array = _taste_icons[taste]
		for i in icons.size():
			var icon: TextureRect = icons[i]
			icon.visible = i < items.size()
			if icon.visible:
				icon.texture = UiKit.item_icon(items[i])
