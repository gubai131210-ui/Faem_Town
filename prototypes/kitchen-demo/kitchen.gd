extends Control

const Round := preload("res://cook_round.gd")
const ART := Rect2(32, 108, 810, 581.087)
const ART_SCALE := 810.0 / 920.0
const BOARD := Vector2(249, 341)
const PAN := Vector2(527, 305)
const EGG_TRAY := Vector2(755, 274)
const TOMATO_TRAY := Vector2(755, 406)
const PALE := Color("f2e7cd")
const MUTED := Color("aec0ad")
const INK := Color("10231d")
const PANEL := Color("192b24")
const LINE := Color("3b5144")
const AMBER := Color("ffc17a")
const SAGE := Color("add0a4")

const ARTWORK := {
	"stage": preload("res://art/kitchen.png"),
	"tomato": preload("res://art/tomato.png"),
	"wedge": preload("res://art/wedge.png"),
	"egg": preload("res://art/egg.png"),
	"bowl": preload("res://art/bowl.png"),
	"curd": preload("res://art/curd.png"),
	"plate": preload("res://art/plate.png"),
	"spatula": preload("res://art/spatula.png"),
	"knife": preload("res://art/knife.png"),
}

var pot := Round.new()
var best: Array[int] = [0, 0]
var labels: Dictionary = {}
var buttons: Dictionary = {}
var amounts: Array[float] = [0, 0, 0, 0, 0]
var elapsed := 0.0
var move_flash := 0.0
var toss_flash := 0.0
var salt_flash := 0.0
var drag := &""
var travel := 0.0
var cursor := Vector2.ZERO
var sound: AudioStreamPlayer
var stove_audio: AudioStreamPlayer
var clips: Dictionary = {}


func _ready() -> void:
	var interface := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
	interface.default_font = font
	theme = interface
	_build()
	if DisplayServer.get_name() != "headless":
		_make_sound()
	_sync()


func _box(color: Color, border: Color, radius: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style


func _label(id: String, value: String, at: Vector2, size_px: int, tint: Color = PALE, width: float = 290.0) -> Label:
	var label := Label.new()
	label.position = at
	label.custom_minimum_size.x = width
	label.text = value
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", tint)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	labels[id] = label
	return label


func _button(id: String, at: Vector2, dimensions: Vector2, action: Callable, primary: bool = false) -> void:
	var button := Button.new()
	button.position = at
	button.size = dimensions
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", _box(AMBER if primary else Color("253a30"), LINE, 8))
	button.add_theme_stylebox_override("hover", _box(Color("ffd298") if primary else Color("365345"), SAGE, 8))
	button.add_theme_stylebox_override("pressed", _box(Color("e99b5b") if primary else Color("456653"), AMBER, 8))
	button.add_theme_stylebox_override("disabled", _box(Color("1e3028"), Color("293c33"), 8))
	button.add_theme_color_override("font_color", INK if primary else PALE)
	button.add_theme_color_override("font_hover_color", INK if primary else PALE)
	button.add_theme_color_override("font_pressed_color", INK if primary else PALE)
	button.add_theme_color_override("font_disabled_color", Color("91a49a"))
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(action)
	add_child(button)
	buttons[id] = button


func _build() -> void:
	_label("series", "一口小灶   /   试玩原型", Vector2(35, 18), 14, SAGE)
	_label("title", "番茄炒蛋", Vector2(32, 39), 39)
	_label("top_note", "", Vector2(633, 62), 16, MUTED, 210).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label("title_side", "", Vector2(881, 130), 25)
	var instructions := _label("instruction", "", Vector2(882, 172), 16, MUTED, 264)
	instructions.size.x = 264
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label("order_goal", "", Vector2(882, 220), 14, SAGE, 264)
	_button("order0", Vector2(880, 262), Vector2(129, 38), _choose.bind(0))
	_button("order1", Vector2(1017, 262), Vector2(129, 38), _choose.bind(1))
	_label("practice", "", Vector2(883, 327), 16, SAGE)
	for i in range(4):
		_button("fire%d" % i, Vector2(880 + 67 * i, 265), Vector2(62, 33), _fire.bind(i))
	_meters()
	_button("egg", Vector2(880, 475), Vector2(129, 38), _egg)
	_button("tomato", Vector2(1017, 475), Vector2(129, 38), _tomato)
	_button("salt", Vector2(880, 522), Vector2(129, 38), _salt)
	_button("toss", Vector2(1017, 522), Vector2(129, 38), _toss)
	_button("action", Vector2(880, 620), Vector2(266, 44), _advance, true)
	_label("note", "", Vector2(883, 575), 14, MUTED)
	_label("stage_note", "", Vector2(34, 709), 14, MUTED, 810)
	_label("best", "", Vector2(888, 710), 14, SAGE, 260).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _meters() -> void:
	for i in range(5):
		var y := 308 + i * 29
		_label("metric%d" % i, "", Vector2(882, y), 13, MUTED, 52)
		_label("reading%d" % i, "", Vector2(1066, y), 13, PALE, 80).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _choose(order: int) -> void:
	pot.choose(order)
	_sync()


func _fire(level: int) -> void:
	pot.set_fire(level)
	_sync()


func _egg() -> void:
	if pot.add_egg():
		_fx("sizzle")
	_sync()


func _tomato() -> void:
	if pot.add_tomato():
		_fx("sizzle")
	_sync()


func _salt() -> void:
	if pot.season_food():
		salt_flash = 0.65
		_fx("cut")
	_sync()


func _toss() -> void:
	if pot.toss():
		toss_flash = 0.52
		_fx("sizzle")
	_sync()


func _advance() -> void:
	match pot.phase:
		Round.Phase.CUT:
			if pot.cut():
				move_flash = 0.24
				_fx("cut")
		Round.Phase.WHISK:
			if pot.whisk():
				move_flash = 0.28
				_fx("stir")
		Round.Phase.STOVE:
			if pot.finish():
				best[pot.order] = maxi(best[pot.order], int(pot.result["score"]))
				_fx("plate")
		Round.Phase.SERVED:
			var order: int = pot.order
			pot = Round.new()
			pot.choose(order)
			drag = &""
			move_flash = 0.0
			toss_flash = 0.0
			salt_flash = 0.0
	_sync()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_SPACE:
			if pot.phase == Round.Phase.STOVE:
				_toss()
			else:
				_advance()
		KEY_ENTER, KEY_KP_ENTER:
			if pot.phase in [Round.Phase.STOVE, Round.Phase.SERVED]:
				_advance()
		KEY_Q: _egg()
		KEY_W: _tomato()
		KEY_S: _salt()
		KEY_1, KEY_2, KEY_3, KEY_4: _fire(event.keycode - KEY_1)
		_: return
	get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		cursor = (event.position - ART.position) / ART_SCALE
		if event.pressed:
			drag = _touch_zone(cursor)
			travel = 0.0
			if drag != &"":
				accept_event()
		elif drag != &"":
			if drag in [&"egg", &"tomato"] and cursor.distance_to(PAN) < 133.0:
				if drag == &"egg":
					_egg()
				else:
					_tomato()
			elif drag == &"pan" and travel < 10.0 and cursor.distance_to(PAN) < 120.0:
				_toss()
			drag = &""
			accept_event()
	elif event is InputEventMouseMotion and drag != &"":
		if not (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			drag = &""
			return
		var next: Vector2 = (event.position - ART.position) / ART_SCALE
		if drag == _touch_zone(next) and drag in [&"cut", &"whisk", &"pan"]:
			travel += absf(next.x - cursor.x) if drag == &"cut" else next.distance_to(cursor)
			var distance := 44.0 if drag != &"whisk" else 34.0
			if travel >= distance:
				travel = fmod(travel, distance)
				if drag == &"pan":
					_toss()
				else:
					_advance()
		cursor = next
		accept_event()


func _touch_zone(at: Vector2) -> StringName:
	match pot.phase:
		Round.Phase.CUT:
			if Rect2(122, 275, 250, 136).has_point(at):
				return &"cut"
		Round.Phase.WHISK:
			if at.distance_to(BOARD) < 109.0:
				return &"whisk"
		Round.Phase.STOVE:
			if not pot.egg_in and at.distance_to(EGG_TRAY) < 53.0:
				return &"egg"
			if not pot.tomato_in and at.distance_to(TOMATO_TRAY) < 53.0:
				return &"tomato"
			if at.distance_to(PAN) < 120.0:
				return &"pan"
	return &""


func _process(delta: float) -> void:
	pot.step(minf(delta, 0.05))
	elapsed += delta
	move_flash = maxf(0.0, move_flash - delta)
	toss_flash = maxf(0.0, toss_flash - delta)
	salt_flash = maxf(0.0, salt_flash - delta)
	if pot.phase == Round.Phase.STOVE:
		_readings()
	var sizzling: bool = pot.phase == Round.Phase.STOVE and (pot.egg_in or pot.tomato_in) and pot.heat > 0.26
	if stove_audio != null:
		stove_audio.volume_db = move_toward(stove_audio.volume_db, (-35.0 + pot.heat * 20.0) if sizzling else -65.0, delta * 52.0)
	queue_redraw()


func _control(id: String, value: String, shown: bool, enabled: bool = true) -> void:
	var button: Button = buttons[id]
	button.text = value
	button.visible = shown
	button.disabled = not enabled


func _sync() -> void:
	var stove: bool = pot.phase == Round.Phase.STOVE
	var served: bool = pot.phase == Round.Phase.SERVED
	var prep: bool = pot.phase in [Round.Phase.CUT, Round.Phase.WHISK]
	var order: Dictionary = Round.ORDERS[pot.order]
	labels["top_note"].text = str(order["name"])
	labels["best"].text = "本次最佳  %d 分" % best[pot.order] if best[pot.order] else "同一道菜，两种口味"
	for i in range(2):
		_control("order%d" % i, ("✓ " if pot.order == i else "") + Round.ORDERS[i]["name"], prep, pot.cuts == 0)
	for i in range(4):
		_control("fire%d" % i, ("%s%d %s" % ["• " if pot.fire == i else "", i + 1, ["关", "小", "中", "大"][i]]), stove)
	_control("egg", "Q  已下蛋液" if pot.egg_in else "Q  下蛋液", stove, not pot.egg_in)
	_control("tomato", "W  已下番茄" if pot.tomato_in else "W  下番茄", stove, not pot.tomato_in)
	_control("salt", "S  撒盐 %d" % pot.salt, stove, (pot.egg_in or pot.tomato_in) and pot.salt < 3)
	_control("toss", "空格  翻锅", stove, pot.egg_in or pot.tomato_in)
	labels["practice"].visible = prep
	labels["order_goal"].text = "口味要求   蛋刚凝，留一点番茄汁" if pot.order == 0 else "口味要求   边缘金黄，番茄汁收浓"
	labels["order_goal"].visible = prep
	for i in range(5):
		labels["metric%d" % i].visible = not prep
		labels["reading%d" % i].visible = not prep
	match pot.phase:
		Round.Phase.CUT:
			labels["title_side"].text = "切番茄"
			labels["instruction"].text = "在砧板上按住左键，横着来回划。"
			labels["practice"].text = "刀工  " + "●".repeat(pot.cuts) + "○".repeat(Round.CUTS - pot.cuts)
			labels["note"].text = "切好后打蛋，开火后才计火候。"
			labels["stage_note"].text = "切配  /  拖动砧板上的小刀，或按空格"
			_control("action", "切一刀   [空格]", true)
		Round.Phase.WHISK:
			labels["title_side"].text = "打蛋液"
			labels["instruction"].text = "在砧板中央的碗里按住左键画圈。"
			labels["practice"].text = "搅打  " + "●".repeat(pot.whisks) + "○".repeat(Round.WHISKS - pot.whisks)
			labels["note"].text = "打好蛋液后中火预热。"
			labels["stage_note"].text = "切配  /  在碗里画圈，或按空格"
			_control("action", "打一下   [空格]", true)
		Round.Phase.STOVE:
			labels["title_side"].text = "看锅"
			labels["instruction"].text = "蛋液先下、略凝后加番茄更容易做嫩。大火上色快，要多翻锅。" if pot.order == 0 else "用更高的火收汁。上色之后及时关火，锅里的余热还能继续加热。"
			labels["note"].text = "火力改变后，锅温会慢一点跟上。"
			labels["stage_note"].text = "灶上  /  拖食材入锅，扫过锅内翻炒，也可用右侧按钮"
			_control("action", "装盘   [回车]", true, pot.egg_in and pot.tomato_in)
			_readings()
		Round.Phase.SERVED:
			var score := int(pot.result["score"])
			labels["title_side"].text = "%d 分   ·   %s" % [score, "合口味" if score >= 85 else "还可再练"]
			labels["instruction"].text = _feedback()
			labels["note"].text = "再开一锅可换口味。"
			labels["stage_note"].text = "上桌  /  盘里的颜色与汁量保留这锅的结果"
			_control("action", "再做一锅   [回车]", true)
			for i in range(5):
				var value := float(pot.result[["egg", "sauce", "color", "even", "salt"][i]])
				_reading(i, ["嫩度", "汁量", "焦香", "均匀", "咸淡"][i], "%d%%" % roundi(value * 100), value)
	queue_redraw()


func _feedback() -> String:
	if pot.egg < 0.34 or pot.sauce < 0.23:
		return "出锅偏早。再等蛋液凝住、番茄开始出汁。"
	var order: Dictionary = Round.ORDERS[pot.order]
	var weakest := ""
	var fit := 0.85
	for metric: String in ["egg", "sauce", "color", "even", "salt"]:
		if float(pot.result[metric]) < fit:
			fit = float(pot.result[metric])
			weakest = metric
	match weakest:
		"egg":
			return "蛋有点老。下次晚些下蛋，或早些关火。" if pot.egg > float(order["egg"]) else "蛋还偏软。下次多给蛋液一点凝固时间。"
		"sauce":
			return "收得有点干。番茄晚一点下锅能留住汁。" if pot.sauce > float(order["sauce"]) else "汁还偏多。让番茄先收一会儿，再下蛋。"
		"color":
			return "边缘上色过深。提早降火，用余温炒完。" if pot.color > float(order["color"]) else "焦香偏浅。短暂开大火，边缘变金就降火。"
		"even":
			return "锅底有焦味。大火下勤翻，收汁后改小火。" if pot.scorch > 0.19 else "受热有点不匀。翻锅能把贴底的食材换到上层。"
		"salt":
			return "这锅%s。下一锅试着只撒一次盐。" % ("没调味" if pot.salt == 0 else "偏咸")
		_:
			return "上色、汁量和嫩度已接近这份口味。"


func _reading(index: int, caption: String, reading: String, amount: float) -> void:
	labels["metric%d" % index].text = caption
	labels["reading%d" % index].text = reading
	amounts[index] = clampf(amount, 0.0, 1.0)


func _readings() -> void:
	_reading(0, "锅温", "烫" if pot.heat > 0.79 else ("温" if pot.heat > 0.35 else "凉"), pot.heat)
	_reading(1, "蛋液", "未下锅" if not pot.egg_in else ("液态" if pot.egg < 0.34 else ("嫩凝" if pot.egg < 0.89 else "全熟")), pot.egg)
	_reading(2, "番茄", "未下锅" if not pot.tomato_in else ("切片" if pot.sauce < 0.24 else ("出汁" if pot.sauce < 0.73 else "收浓")), pot.sauce)
	_reading(3, "上色", "深金" if pot.color > 0.33 else ("浅金" if pot.color > 0.16 else "淡"), pot.color)
	_reading(4, "焦底", "有焦味" if pot.scorch > 0.40 else ("需翻锅" if pot.uneven > 0.53 else "正常"), maxf(pot.scorch, pot.uneven * 0.45))


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1200, 750), Color("13221c"))
	draw_line(Vector2(32, 95), Vector2(1168, 95), LINE)
	draw_style_box(_box(PANEL, LINE, 14), Rect2(856, 108, 312, 581))
	if pot.phase in [Round.Phase.STOVE, Round.Phase.SERVED]:
		for i in range(amounts.size()):
			var at := Vector2(941, 317 + 29 * i)
			draw_rect(Rect2(at, Vector2(114, 7)), LINE)
			if amounts[i] > 0.0:
				draw_rect(Rect2(at, Vector2(114 * amounts[i], 7)), AMBER if i == 4 and pot.phase == Round.Phase.STOVE else SAGE)
	draw_rect(ART.grow(1), LINE)
	draw_set_transform(ART.position, 0.0, Vector2.ONE * ART_SCALE)
	draw_texture_rect(ARTWORK["stage"], Rect2(0, 0, 920, 660), false)
	match pot.phase:
		Round.Phase.CUT: _prep(false)
		Round.Phase.WHISK: _prep(true)
		Round.Phase.STOVE: _cooking()
		Round.Phase.SERVED: _serving()
	draw_set_transform(Vector2.ZERO)


func _art(name: String, at: Vector2, size_px: float, rotation: float = 0.0, tint: Color = Color.WHITE) -> void:
	draw_set_transform(ART.position + at * ART_SCALE, rotation, Vector2.ONE * ART_SCALE)
	draw_texture_rect(ARTWORK[name], Rect2(-Vector2.ONE * size_px / 2, Vector2.ONE * size_px), false, tint)
	draw_set_transform(ART.position, 0.0, Vector2.ONE * ART_SCALE)


func _station(at: Vector2, radius: float) -> void:
	draw_arc(at, radius, 0, TAU, 64, Color(1.0, 0.89, 0.66, 0.38 + sin(elapsed * 2.0) * 0.10), 1.4, true)


func _prep(whisking: bool) -> void:
	_art("egg", Vector2(746, 280), 114)
	if whisking:
		_station(BOARD, 76.0)
		_art("bowl", BOARD, 158.0, sin(elapsed * 10.0) * move_flash)
		var orbit := Vector2(cos(elapsed * 14.0), sin(elapsed * 14.0)) * move_flash * 122.0
		_art("spatula", BOARD + orbit + Vector2(6, 41), 133.0, -0.8 + orbit.x * 0.04)
		for i in range(pot.whisks):
			draw_circle(BOARD + Vector2(-32 + i * 16, 4 + (i % 2) * 10), 3 + i % 2, Color("ffe0a0"))
	else:
		_station(BOARD, 79)
		_art("tomato", BOARD + Vector2(-27, -3), 131.0 - pot.cuts * 19, pot.cuts * 0.19)
		for i in range(pot.cuts):
			_art("wedge", BOARD + Vector2(19 + i * 24, 11 - i % 2 * 27), 67, i * 0.15)
		_art("knife", (cursor if drag == &"cut" else BOARD + Vector2(79, 55)) + Vector2(0, -move_flash * 75.0), 126, -0.95)
	_art("plate", Vector2(747, 447), 175)


func _cooking() -> void:
	var glow := float(pot.fire) / 3.0
	if glow > 0.0:
		for i in range(6):
			var w := float(i) / 5.0
			draw_circle(Vector2(527, 396), 13.0 + w * 29, Color(1, 0.27, 0.06, glow * (1.0 - w) * 0.14))
		for i in range(7):
			var a := sin(elapsed * 13.0 + i * 2.1)
			var at := Vector2(502 + i * 8, 400)
			draw_colored_polygon(PackedVector2Array([at + Vector2(-5, 0), at + Vector2(a * 4, -5 - glow * (10 + a * 7)), at + Vector2(5, 0)]), Color(1.0, 0.55 + a * 0.15, 0.11, 0.85))
	if not pot.egg_in:
		_station(EGG_TRAY, 48)
		_art("bowl", cursor if drag == &"egg" else EGG_TRAY, 116)
	if not pot.tomato_in:
		_station(TOMATO_TRAY, 48)
		_art("wedge", cursor if drag == &"tomato" else TOMATO_TRAY, 99, 0.2)
		_art("wedge", (cursor if drag == &"tomato" else TOMATO_TRAY) + Vector2(-17, 14), 69, -0.3)
	if pot.egg_in or pot.tomato_in:
		_meal(PAN, 1.0, false)
		var flip := sin((1.0 - toss_flash / 0.52) * PI) if toss_flash > 0.0 else 0.0
		_art("spatula", PAN + Vector2(111 - flip * 68, 115 - flip * 57), 182, -0.54 + flip * 0.85)
		_steam(PAN)
	else:
		_station(PAN - Vector2(0, 20), 104)


func _serving() -> void:
	draw_rect(Rect2(0, 0, 920, 660), Color(0.05, 0.10, 0.08, 0.50))
	var center := Vector2(455, 329)
	_art("plate", center, 530)
	_meal(center + Vector2(0, 8), 1.42, true)
	_steam(center)


func _oval(at: Vector2, rx: float, ry: float, color: Color) -> void:
	var outline := PackedVector2Array()
	for i in range(48):
		var a := TAU * i / 48.0
		outline.append(at + Vector2(rx * cos(a), ry * sin(a)))
	draw_colored_polygon(outline, color)


func _meal(center: Vector2, size_mult: float, served: bool) -> void:
	var offset := 0.0 if served else sin((1.0 - toss_flash / 0.52) * PI) * 51.0
	if pot.tomato_in:
		var juice := clampf(pot.sauce * 2.5, 0.0, 1.0) * (1.0 - clampf(pot.sauce / 1.6, 0, 0.8))
		_oval(center, (68 + juice * 46) * size_mult, (30 + juice * 25) * size_mult, Color("b13c27").darkened(pot.scorch * 0.65))
	elif pot.egg < 0.47:
		_oval(center, 95, 45, Color("eeae3f"))
	for i in range(16):
		var is_egg := i % 2 == 0
		if is_egg and not pot.egg_in or not is_egg and not pot.tomato_in:
			continue
		if is_egg and pot.egg < 0.22:
			continue
		var a := i * 2.39996 + pot.tosses * 0.57
		var radius := sqrt((i + 1) / 17.0) * 105.0
		var at := center + Vector2(cos(a) * radius * 0.87, sin(a) * radius * 0.52) * size_mult
		at.y -= offset * (0.5 + i % 4 * 0.19)
		var tint := Color.WHITE.lerp(Color("b57444") if is_egg else Color("a55036"), pot.color * 0.65)
		tint = tint.darkened(pot.scorch * (0.43 + i % 3 * 0.13))
		var pixels := (62.0 - (i % 3) * 7.0) * size_mult
		if is_egg:
			pixels *= 0.55 + clampf(pot.egg * 0.73, 0.0, 0.45)
		_art("curd" if is_egg else "wedge", at, pixels, a, tint)
	if not served and salt_flash > 0.0:
		for i in range(11):
			draw_circle(center + Vector2((i % 6 - 3) * 17, (i % 4) * 11 - 108 * salt_flash), 2, Color(1, 0.97, 0.80, salt_flash))


func _steam(center: Vector2) -> void:
	var heat := clampf((pot.heat - 0.30) * 1.9, 0.0, 1.0)
	for i in range(13):
		var t := fmod(elapsed * (0.42 + i % 3 * 0.17) + i * 0.168, 1.0)
		var point := center + Vector2((i % 7 - 3) * 19 + sin(t * 4.0 + i) * 13, -t * 107)
		draw_circle(point, 6 + t * 15, Color(1, 0.94, 0.79, sin(t * PI) * heat * 0.10))


func _make_sound() -> void:
	sound = AudioStreamPlayer.new()
	sound.volume_db = -16
	add_child(sound)
	stove_audio = AudioStreamPlayer.new()
	stove_audio.volume_db = -65
	add_child(stove_audio)
	clips = {
		"cut": _wave(0.075, 204.0, 0.55, false), "stir": _wave(0.11, 154.0, 0.60, false),
		"sizzle": _wave(0.24, 87.0, 0.88, false), "plate": _wave(0.42, 560.0, 0.09, false),
	}
	stove_audio.stream = _wave(0.69, 245.0, 0.92, true)
	stove_audio.play()


func _wave(seconds: float, pitch: float, noise: float, looped: bool) -> AudioStreamWAV:
	var rate := 22050
	var frames := int(seconds * rate)
	var track := PackedByteArray()
	track.resize(frames * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 458
	for i in range(frames):
		var t := i / float(rate)
		var amp := 0.43 if looped else minf(t * 310, 1) * pow(1.0 - i / float(frames), 2.25)
		var voice := sin(TAU * pitch * t) * (1 - noise) * 0.65 + random.randf_range(-1, 1) * noise
		track.encode_s16(i * 2, roundi(voice * amp * 20000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = track
	if looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = frames
	return stream


func _fx(id: String) -> void:
	if sound == null:
		return
	sound.stream = clips[id]
	sound.play()
