extends Control
## 标题画面：新游戏、读取存档、退出。

enum Mode { NEW, LOAD }

var _main_box: VBoxContainer
var _slot_panel: NinePatchRect
var _slot_title: Label
var _slot_buttons: Array[Button] = []
var _new_button: Button
var _load_button: Button
var _mode := Mode.NEW
## 新游戏选到已有存档的档位时，要再按一次才覆盖
var _confirm_slot := -1
var _time := 0.0
var _fog: Array[Sprite2D] = []


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	GameClock.running = false
	_build_backdrop()

	var title := UiKit.label("雾隐青岚", 26, UiKit.TEXT_LIGHT, true)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 30.0
	title.offset_bottom = 70.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override(&"outline_size", 5)
	add_child(title)
	var sub := UiKit.label("一封没有落款的信，一个没人记得你的镇子", 7, UiKit.TEXT_LIGHT, true)
	sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = 70.0
	sub.offset_bottom = 84.0
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)

	_main_box = VBoxContainer.new()
	_main_box.add_theme_constant_override(&"separation", 4)
	UiKit.center(_main_box, Vector2(88, 60))
	_main_box.offset_top += 42.0
	_main_box.offset_bottom += 42.0
	add_child(_main_box)
	_new_button = UiKit.button("新的开始")
	_new_button.pressed.connect(_open_slots.bind(Mode.NEW))
	_main_box.add_child(_new_button)
	_load_button = UiKit.button("继续")
	_load_button.pressed.connect(_open_slots.bind(Mode.LOAD))
	_main_box.add_child(_load_button)
	var quit := UiKit.button("退出")
	quit.pressed.connect(get_tree().quit)
	_main_box.add_child(quit)

	_slot_panel = UiKit.panel()
	UiKit.center(_slot_panel, Vector2(190, 104))
	_slot_panel.offset_top += 36.0
	_slot_panel.offset_bottom += 36.0
	add_child(_slot_panel)
	_slot_title = UiKit.label("", 8)
	_slot_title.position = Vector2(0, 5)
	_slot_title.size = Vector2(190, 12)
	_slot_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slot_panel.add_child(_slot_title)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 3)
	box.position = Vector2(10, 20)
	box.size = Vector2(170, 76)
	_slot_panel.add_child(box)
	for i in SaveSystem.SLOT_COUNT:
		var b := UiKit.button("")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_on_slot_pressed.bind(i))
		box.add_child(b)
		_slot_buttons.append(b)
	var back := UiKit.button("返回")
	back.pressed.connect(_close_slots)
	box.add_child(back)

	var ver := UiKit.label("M0 · 基础框架", 6, UiKit.TEXT_LIGHT, true)
	ver.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ver.offset_left = 5.0
	ver.offset_top = -14.0
	add_child(ver)

	_close_slots()


func _process(delta: float) -> void:
	_time += delta
	for i in _fog.size():
		var f := _fog[i]
		f.position.x = fposmod(_time * (4.0 + i * 2.5) + i * 130.0, 384.0 + 220.0) - 220.0


func _unhandled_input(event: InputEvent) -> void:
	if _slot_panel.visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_slots()


## 自动化流程用：直接在指定档位开始新游戏。
func start_new(slot: int) -> void:
	SaveSystem.reset_all()
	SaveSystem.delete(slot)
	SaveSystem.current_slot = slot
	SaveSystem.save(slot, GameState.save_meta())
	SceneRouter.to_game()


func load_game(slot: int) -> void:
	if not SaveSystem.load_slot(slot):
		_slot_title.text = "这个存档读不出来"
		Audio.play("deny", 0.0, -4.0)
		return
	SceneRouter.to_game()


func _has_any_save() -> bool:
	for i in SaveSystem.SLOT_COUNT:
		if SaveSystem.has_save(i):
			return true
	return false


func _open_slots(mode: Mode) -> void:
	_mode = mode
	_confirm_slot = -1
	_main_box.visible = false
	_slot_panel.visible = true
	_refresh_slots()
	for b in _slot_buttons:
		if not b.disabled:
			b.grab_focus()
			break
	Audio.play("select", 0.0, -6.0)


func _close_slots() -> void:
	_slot_panel.visible = false
	_main_box.visible = true
	_load_button.disabled = not _has_any_save()
	if _load_button.disabled:
		_new_button.grab_focus()
	else:
		_load_button.grab_focus()


func _refresh_slots() -> void:
	_slot_title.text = "选一个位置开始" if _mode == Mode.NEW else "读取存档"
	for i in _slot_buttons.size():
		var b := _slot_buttons[i]
		var meta := SaveSystem.slot_meta(i)
		if meta.is_empty():
			b.text = "存档 %d    空" % (i + 1)
			b.disabled = _mode == Mode.LOAD
		elif i == _confirm_slot:
			b.text = "存档 %d    再按一次，覆盖这个存档" % (i + 1)
			b.disabled = false
		else:
			b.text = "存档 %d    第%d年 %s    %d 文" % [
				i + 1, int(meta.get("year", 1)), str(meta.get("date", "")), int(meta.get("money", 0))]
			b.disabled = false


func _on_slot_pressed(slot: int) -> void:
	if SceneRouter.busy:
		return
	if _mode == Mode.LOAD:
		load_game(slot)
		return
	if SaveSystem.has_save(slot) and _confirm_slot != slot:
		_confirm_slot = slot
		_refresh_slots()
		return
	start_new(slot)


## 标题背景：远山、雾、草地，全部用代码画。
func _build_backdrop() -> void:
	var img := Px.new_img(384, 216)
	var sky_top := Color("7fb7d6")
	var sky_low := Color("f3e2c0")
	for y in 216:
		var c := sky_top.lerp(sky_low, clampf(y / 150.0, 0.0, 1.0))
		Px.rect(img, 0, y, 384, 1, c)
	var layers: Array = [
		[96.0, 26.0, 0.021, Color("a9c4c9")],
		[118.0, 20.0, 0.034, Color("7fa79a")],
		[142.0, 14.0, 0.052, Color("5e9070")],
	]
	for l: Array in layers:
		var base: float = l[0]
		var amp: float = l[1]
		var freq: float = l[2]
		var col: Color = l[3]
		for x in 384:
			var h := base - amp * (0.6 * sin(x * freq + base) + 0.4 * sin(x * freq * 2.7 + 1.3))
			Px.rect(img, x, int(h), 1, 216 - int(h), col)
	Px.rect(img, 0, 168, 384, 48, Color("80bd4e"))
	for x in 384:
		var edge := 168 + (Px.h2(x / 3, 7) % 3)
		Px.rect(img, x, edge, 1, 2, Color("5fa03c"))
	for i in 90:
		var px := Px.h2(i, 31) % 384
		var py := 174 + Px.h2(i, 57) % 40
		Px.rect(img, px, py, 1, 2, Color("5fa03c"))
	var back := TextureRect.new()
	back.texture = Px.tex(img)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)

	var fog_img := Px.new_img(220, 26)
	for y in 26:
		for x in 220:
			var d := Vector2((x - 110) / 110.0, (y - 13) / 13.0).length()
			if d < 1.0 and (Px.h2(x / 2, y / 2) % 100) < int((1.0 - d) * 135.0):
				fog_img.set_pixel(x, y, Color(1, 1, 1, 0.34))
	var fog_tex := Px.tex(fog_img)
	for i in 4:
		var f := Sprite2D.new()
		f.texture = fog_tex
		f.centered = false
		f.position.y = 92.0 + i * 19.0
		add_child(f)
		_fog.append(f)
