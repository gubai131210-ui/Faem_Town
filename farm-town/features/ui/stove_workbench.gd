extends Control
## 亲手做一道菜的那一屏（掌勺）：左边案板备料，中间一口锅掌火，右边一根火候条。
## 规则在 CookRound 里，这里只管画和收输入。背景和器具是 tools/stove.py 用 Blender 画的，
## 锅心、案板、灶膛口的位置跟那个脚本里的 WOK、BOARD、MOUTH 对应。
## 一个使用键：备料时落刀，掌火时按住添火、松开收火，起锅时按一下。上方向键提鲜。

signal finished(grade: int)
signal close_requested

const DIR := "res://art/cooking/bench/"
const WOK_AT := Vector2(256, 124)
const WOK_RX := 56.0
const WOK_RY := 34.0
const BOARD_AT := Vector2(80, 124)
const BOARD_HALF := 40.0
const FIRE_RECT := Rect2(224, 160, 64, 40)
const WINDOW := Rect2(37, 19, 80, 42)
const GAUGE := Rect2(364, 68, 10, 96)
const BITS_EACH := 7
const COOKED := Color("d9a05a")
const GOLD := Color("ffd070")

var round: CookRound
## 拿手时这一份有没有真的抬了一档品质，由 CookShow 结算以后告诉这里
var raised := false

var _def: RecipeDef
var _clock := 0.0
var _stir := 0.0
var _chop_flash := 0.0
var _toast_left := 0.0
var _season_fly := 0.0
var _held := false
var _mouse_down := false
var _sear_wait := 0.0
var _colors: Array[Color] = []
var _shapes: Array[int] = []
var _icons: Array[Texture2D] = []
var _in_term := false
var _fond: StringName = &""
var _fond_sheet: CharacterSheet
var _tex: Dictionary = {}
var _title: Label
var _toast: Label
var _hint: Label
var _tip: Label
var _result: Array[Label] = []


func _ready() -> void:
	theme = UiKit.theme()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	for id: String in ["bench", "bits", "spatula", "knife", "fire", "plate"]:
		var path := DIR + id + ".png"
		_tex[id] = load(path) if ResourceLoader.exists(path) else null
	_title = _label(Vector2(120, 1), Vector2(144, 12), 8)
	_toast = _label(Vector2(196, 66), Vector2(120, 12), 8)
	_tip = _label(Vector2(120, 16), Vector2(184, 12), 6)
	_hint = _label(Vector2(4, 205), Vector2(376, 10), 6)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	for i in 4:
		_result.append(_label(Vector2(72, 138 + i * 13), Vector2(240, 12), 8 if i < 2 else 6))
	hide()


func _label(at: Vector2, extent: Vector2, pixels: int) -> Label:
	var label := UiKit.label("", pixels, UiKit.TEXT_LIGHT, true)
	label.position = at
	label.size = extent
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


## 开一局。seed_value 给测试用。
func start(def: RecipeDef, seed_value: int = -1) -> void:
	_def = def
	round = CookRound.new(def.method, def.ingredients.size(), Crafting.rank_level(), seed_value)
	raised = false
	_clock = 0.0
	_stir = 0.0
	_chop_flash = 0.0
	_toast_left = 0.0
	_season_fly = 0.0
	_mouse_down = false
	_colors.clear()
	_shapes.clear()
	_icons.clear()
	for item_id: StringName in def.ingredients:
		var icon := UiKit.item_icon(item_id)
		_icons.append(icon)
		var tint := _tint_of(icon)
		_colors.append(tint)
		_shapes.append(_shape_of(item_id, tint))
	_in_term = Crafting.in_term(def)
	_fond = Crafting.fond_id(def.id)
	_fond_sheet = CharacterSheet.load_sheet(Database.npc(_fond).sheet) if _fond != &"" else null
	_title.text = "%s · %s" % [str(RecipeDef.METHOD_NAMES.get(def.method, "炒")), Database.item(def.id).name]
	_toast.text = ""
	for line in _result:
		line.text = ""
	_refresh_text()
	show()


## 食材图标里最鲜的那一路颜色：按饱和度加权平均。锅里的碎料用它染。
func _tint_of(icon: Texture2D) -> Color:
	if icon == null:
		return Color("e8c070")
	var img := icon.get_image()
	if img == null:
		return Color("e8c070")
	var sum := Vector3.ZERO
	var weight := 0.0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.5 or c.v < 0.25:
				continue
			var w := 0.15 + c.s * c.v
			sum += Vector3(c.r, c.g, c.b) * w
			weight += w
	if weight <= 0.0:
		return Color("e8c070")
	var mean := sum / weight
	var out := Color(mean.x, mean.y, mean.z)
	out.s = minf(1.0, out.s * 1.25)
	out.v = minf(1.0, out.v * 1.12 + 0.05)
	return out


## 0 丁、1 片、2 叶、3 蛋块。
func _shape_of(item_id: StringName, tint: Color) -> int:
	if String(item_id).contains("egg"):
		return 3
	if tint.g > tint.r * 1.08 and tint.g > tint.b * 1.08:
		return 2
	return Px.h2(String(item_id).length(), String(item_id).unicode_at(0)) % 2


func _process(delta: float) -> void:
	if not visible or round == null:
		return
	var step := minf(delta, 0.05)
	_clock += step
	_held = round.step == CookRound.Step.FIRE and (Input.is_action_pressed(&"use") or _mouse_down)
	round.advance(step, _held)
	_stir += step * (4.2 if _held else 0.5) if round.step == CookRound.Step.FIRE else 0.0
	_chop_flash = maxf(0.0, _chop_flash - step)
	_season_fly = maxf(0.0, _season_fly - step)
	if _toast_left > 0.0:
		_toast_left -= step
		_toast.modulate.a = clampf(_toast_left / 0.3, 0.0, 1.0)
	if round.step == CookRound.Step.FIRE and _held:
		_sear_wait -= step
		if _sear_wait <= 0.0:
			_sear_wait = 0.32
			Audio.play("sear", 0.25, lerpf(-22.0, -12.0, round.temp))
	_take_events()
	queue_redraw()


func _take_events() -> void:
	if round.events.is_empty():
		return
	for event: StringName in round.events:
		match event:
			&"chop_good":
				_chop_flash = 0.16
				_say("准！", GOLD)
				Audio.play("chop", 0.05, -6.0)
			&"chop_off":
				_chop_flash = 0.16
				_say("偏了", UiKit.TEXT_LIGHT)
				Audio.play("chop", 0.2, -10.0)
			&"drop":
				_say("下锅", UiKit.TEXT_LIGHT)
				Audio.play("sizzle", 0.1, -8.0)
			&"season_open":
				Audio.play("select", 0.0, -6.0)
			&"season_hit":
				_season_fly = 0.5
				_say("提鲜！", GOLD)
				Audio.play("season", 0.0, -6.0)
			&"cooked":
				_say("熟了，起锅！", GOLD)
				Audio.play("bite", 0.0, -8.0)
			&"serve_good":
				Audio.play("plate_up", 0.0, -5.0)
			&"serve_late":
				Audio.play("harvest", 0.0, -8.0)
	round.events.clear()
	if round.step == CookRound.Step.DONE and _result[0].text == "":
		finished.emit(round.grade)
		_fill_result()
	_refresh_text()


func _say(text: String, color: Color) -> void:
	_toast.text = text
	_toast.add_theme_color_override(&"font_color", color)
	_toast.modulate.a = 1.0
	_toast_left = 0.9
	_toast.position = (BOARD_AT if round.step == CookRound.Step.PREP else WOK_AT) + Vector2(-60, -58)


func _refresh_text() -> void:
	_toast.visible = round.step != CookRound.Step.DONE
	_title.visible = round.step != CookRound.Step.DONE
	match round.step:
		CookRound.Step.PREP:
			_tip.text = "备料：刀走到案板中间那一段，落刀　%d / %d" % [round.cuts, round.cuts_total]
			_hint.text = "使用：落刀　　取消：跳过，直接出菜"
		CookRound.Step.FIRE:
			_tip.text = "掌火：让锅温跟着金色那一段走"
			_hint.text = "按住使用：添火　　松开：收火　　上：提鲜　　取消：跳过"
		CookRound.Step.SERVE:
			_tip.text = "起锅：光圈收到锅沿时按下"
			_hint.text = "使用：起锅　　取消：跳过"
		CookRound.Step.DONE:
			_tip.text = ""
			_hint.text = "使用：收起"


func _fill_result() -> void:
	var notes := PackedStringArray()
	if round.grade == CookRound.Grade.SIGNATURE:
		notes.append("品质高了一档" if raised else "火候印记入食单")
	if _in_term:
		notes.append("当令")
	_result[0].text = Database.item(_def.id).name
	_result[1].text = " · ".join(notes)
	_result[1].add_theme_color_override(&"font_color", GOLD)
	_result[2].text = round.remark()
	_result[3].text = Database.npc(_fond).name + "爱这一口。趁热送去吧。" if _fond != &"" else ""


## 返回真时，CookShow 拦住这次输入，灶台下层不会同时收到。
func handle_input(event: InputEvent) -> bool:
	if round == null:
		return false
	var keyed: bool = event is InputEventKey or event is InputEventJoypadButton or event is InputEventAction
	if not keyed:
		return false
	if event.is_echo():
		return true
	if event.is_action_pressed(&"use"):
		_use()
	elif event.is_action_pressed(&"move_up"):
		round.season()
	return true


func _use() -> void:
	match round.step:
		CookRound.Step.PREP:
			round.chop()
		CookRound.Step.SERVE:
			round.serve()
		CookRound.Step.DONE:
			close_requested.emit()
	_take_events()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_mouse_down = event.pressed
			if event.pressed:
				_use()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			round.season()
		accept_event()


# ---------------------------------------------------------------- 画

func _draw() -> void:
	if round == null:
		return
	if _tex["bench"] != null:
		draw_texture(_tex["bench"], Vector2.ZERO)
	_draw_window()
	_draw_fire()
	_draw_board()
	_draw_wok()
	if round.step == CookRound.Step.FIRE or round.step == CookRound.Step.SERVE:
		_draw_gauge()
	if round.season_left > 0.0:
		_draw_season()
	if round.step == CookRound.Step.SERVE:
		_draw_serve_ring()
	if round.step == CookRound.Step.DONE:
		_draw_result()


## 窗外：夜里发蓝，雨雪天发灰。爱这一口的人趴在窗口等着。
func _draw_window() -> void:
	var night := GameClock.minutes >= 1140.0 + GameClock.dusk_shift() or GameClock.minutes < GameClock.DAY_START
	if night:
		draw_rect(WINDOW, Color(0.10, 0.14, 0.34, 0.72))
	elif Weather.today in [Weather.RAIN, Weather.STORM, Weather.SNOW, Weather.FOG]:
		draw_rect(WINDOW, Color(0.55, 0.62, 0.70, 0.5))
	if _fond_sheet == null or not _fond_sheet.is_valid():
		return
	var frame := int(_clock * _fond_sheet.fps(&"idle"))
	var cell := _fond_sheet.region(&"idle", GameMap.Facing.DOWN, frame)
	# 只画头和肩膀：序列帧一格 48，人从第 8 行到第 28 行，放大两倍塞进窗框
	var rows := 20.0
	var src := Rect2(cell.position + Vector2(0, 8), Vector2(cell.size.x, rows))
	var bob := 1.0 if round.step == CookRound.Step.FIRE and round.in_zone() and int(_clock * 3.0) % 2 == 0 else 0.0
	var dst := Rect2(WINDOW.position.x + WINDOW.size.x / 2.0 - cell.size.x, WINDOW.end.y - rows * 2.0 - bob, cell.size.x * 2.0, rows * 2.0)
	draw_texture_rect_region(_fond_sheet.texture, dst, src)
	if round.step == CookRound.Step.FIRE and round.done > 0.3:
		# 闻到香了：头顶冒一个小点点的泡
		var at := Vector2(WINDOW.end.x - 16, WINDOW.position.y + 5)
		draw_rect(Rect2(at, Vector2(13, 9)), UiKit.OUTLINE)
		draw_rect(Rect2(at + Vector2.ONE, Vector2(11, 7)), UiKit.TEXT_LIGHT)
		for i in mini(3, 1 + int(round.done * 3.0)):
			draw_rect(Rect2(at + Vector2(2 + i * 3, 3), Vector2(2, 2)), UiKit.ACCENT)


func _fire_level() -> int:
	if round.step == CookRound.Step.PREP or round.step == CookRound.Step.DONE:
		return 0
	if round.temp < 0.25:
		return 0
	if round.temp < 0.5:
		return 1
	return 2 if round.temp < 0.75 else 3


func _draw_fire() -> void:
	if _tex["fire"] == null:
		return
	var frame := int(_clock * (12.0 if _held else 7.0)) % 4
	draw_texture_rect_region(_tex["fire"], FIRE_RECT, Rect2(frame * 64, _fire_level() * 40, 64, 40))


## 案板：还没切的整只摆在中间，切过的变成一小堆碎料摆在右边。刀跟着节拍来回走。
func _draw_board() -> void:
	if round.step != CookRound.Step.PREP:
		return
	# 中间那一段：落刀算准
	var half := BOARD_HALF * 2.0 * CookRound.BEAT_HALF
	var lane := Rect2(BOARD_AT.x - half, BOARD_AT.y - 17, half * 2.0, 34)
	var glow := GOLD
	glow.a = 0.28 + (0.2 if round.beat_in_window() else 0.0)
	draw_rect(lane, glow)
	draw_rect(lane, GOLD, false, 1.0)
	var which := mini(int(float(round.cuts) / float(round.cuts_total) * _icons.size()), _icons.size() - 1)
	var cut_into := float(round.cuts) / float(round.cuts_total) * _icons.size() - which
	# 切好的
	for k in which:
		for i in 4:
			_bit(BOARD_AT + Vector2(-34 + k * 12 + (i % 2) * 6, 6 + (i / 2) * 6 - k * 3), k, 0.0)
	# 正在切的这一只
	if _icons[which] != null:
		var shrink := 1.0 - cut_into * 0.5
		var edge := Vector2(32, 32) * Vector2(shrink, 1.0)
		draw_texture_rect(_icons[which], Rect2(BOARD_AT - Vector2(edge.x / 2.0 - 4, 18), edge), false)
		for i in int(cut_into * 6.0):
			_bit(BOARD_AT + Vector2(-16 - i * 5, 2 + (i % 2) * 5), which, 0.0)
	# 还排着的
	for k in range(which + 1, _icons.size()):
		if _icons[k] != null:
			draw_texture_rect(_icons[k], Rect2(BOARD_AT + Vector2(22 + (k - which - 1) * 14, -14), Vector2(16, 16)), false)
	if _tex["knife"] != null:
		var x := BOARD_AT.x + (round.beat_pos() - 0.5) * BOARD_HALF * 2.0
		var drop := 14.0 if _chop_flash > 0.0 else 0.0
		draw_texture(_tex["knife"], Vector2(roundf(x) - 16, BOARD_AT.y - 52 + drop))
		draw_rect(Rect2(roundf(x) - 16, BOARD_AT.y + 20, 28, 2), Color(0, 0, 0, 0.18))


func _bit(at: Vector2, kind: int, lift: float) -> void:
	if _tex["bits"] == null:
		return
	var tint := _colors[kind].lerp(COOKED, round.done * 0.3).darkened(round.scorch * 0.65)
	draw_texture_rect_region(_tex["bits"], Rect2((at - Vector2(8, 8 + lift)).round(), Vector2(16, 16)),
		Rect2(_shapes[kind] * 16, 0, 16, 16), tint)


func _ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(points, color)


func _ring(center: Vector2, rx: float, ry: float, from: float, to: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	var n := maxi(2, int(absf(to - from) / TAU * 48.0))
	for i in n + 1:
		var a := lerpf(from, to, float(i) / n)
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(points, color, width)


func _draw_wok() -> void:
	var plated := round.step == CookRound.Step.DONE
	var center := WOK_AT
	if round.drops > 0 and not plated:
		# 锅底的油和汁：越熟越浓
		var juice := Color(0, 0, 0)
		for k in round.drops:
			juice += _colors[k]
		juice = (juice / float(round.drops)).darkened(0.25 + round.scorch * 0.5)
		juice.a = 0.22 + 0.5 * round.done
		_ellipse(center + Vector2(0, 1), 38, 22, juice)
		var toss := _held or round.step == CookRound.Step.SERVE
		for k in round.drops:
			for i in BITS_EACH:
				var a := i * 2.39996 + k * 1.3 + _stir * 0.6
				var r := sqrt((i + 0.5) / BITS_EACH) * 32.0
				var lift := absf(sin(_clock * 11.0 + i * 1.7 + k)) * 4.0 if toss else 0.0
				_bit(center + Vector2(cos(a) * r, sin(a) * r * 0.58), k, lift)
		if _tex["spatula"] != null and round.step == CookRound.Step.FIRE:
			var head := center + Vector2(cos(_stir) * 22.0, sin(_stir) * 11.0)
			draw_texture(_tex["spatula"], (head - Vector2(10, 38)).round())
	if round.step == CookRound.Step.FIRE or round.step == CookRound.Step.SERVE:
		_draw_air()
		# 熟了几成：沿着锅沿走一圈
		_ring(center, WOK_RX + 5, WOK_RY + 4, -PI / 2.0, -PI / 2.0 + TAU, Color(0, 0, 0, 0.35), 3.0)
		_ring(center, WOK_RX + 5, WOK_RY + 4, -PI / 2.0, -PI / 2.0 + TAU * round.done, GOLD, 3.0)
		if round.step == CookRound.Step.FIRE and round.in_zone():
			var glow := GOLD
			glow.a = 0.45 + 0.3 * sin(_clock * 14.0)
			_ring(center, WOK_RX - 3, WOK_RY - 2, 0.0, TAU, glow, 2.0)
	if _season_fly > 0.0:
		for i in 6:
			var t := 1.0 - _season_fly / 0.5
			var from := Vector2(176, 92)
			var at := from.lerp(center + Vector2((i - 3) * 6, (i % 2) * 5), t) - Vector2(0, sin(t * PI) * 24.0)
			draw_rect(Rect2(at.round(), Vector2(2, 2)), Color("7cc74f"))


## 锅上的气：锅温越高越多。正好时带金色的火星，烧过头冒黑烟。
func _draw_air() -> void:
	var over := round.step == CookRound.Step.FIRE and round.temp > round.zone + round.half
	var count := 2 + int(round.temp * 10.0)
	for i in count:
		var t := fposmod(_clock * 0.6 + i * 0.37, 1.0)
		var x := WOK_AT.x + sin(i * 2.3 + t * 3.0) * (8.0 + t * 12.0) + (i % 5 - 2) * 9.0
		var y := WOK_AT.y - 6.0 - t * 58.0
		var s := 3.0 + float(i % 3)
		var puff := Color(0.2, 0.18, 0.2, (1.0 - t) * 0.7) if over else Color(1, 1, 1, (1.0 - t) * 0.8)
		draw_rect(Rect2(roundf(x) - 1, roundf(y) - 1, s + 2, s + 2), Color(0.42, 0.48, 0.58, (1.0 - t) * 0.35))
		draw_rect(Rect2(roundf(x), roundf(y), s, s), puff)
	if round.step == CookRound.Step.FIRE and round.in_zone():
		for i in 6:
			var t := fposmod(_clock * 1.3 + i * 0.29, 1.0)
			var x := WOK_AT.x + (i - 2.5) * 13.0 + sin(t * 6.0 + i) * 4.0
			var spark := GOLD
			spark.a = 1.0 - t
			draw_rect(Rect2(roundf(x), roundf(WOK_AT.y - 10.0 - t * 34.0), 2, 2), spark)


## 火候条：金色那一段是正好，白色的横杠是现在的锅温。
func _draw_gauge() -> void:
	var g := GAUGE
	draw_rect(Rect2(g.position.x - 7, g.position.y - 6, g.size.x + 14, g.size.y + 22), Color(0.10, 0.06, 0.05, 0.55))
	draw_rect(g.grow(3), UiKit.OUTLINE)
	draw_rect(g.grow(2), Color("c08a52"))
	draw_rect(g.grow(1), UiKit.OUTLINE)
	for i in int(g.size.y):
		var t := 1.0 - float(i) / g.size.y
		draw_rect(Rect2(g.position.x, g.position.y + i, g.size.x, 1), Color("3d5a80").lerp(Color("a03a32"), t))
	var top := g.end.y - (round.zone + round.half) * g.size.y
	var bottom := g.end.y - (round.zone - round.half) * g.size.y
	var band := Rect2(g.position.x, maxf(top, g.position.y), g.size.x, minf(bottom, g.end.y) - maxf(top, g.position.y))
	var gold := GOLD
	gold.a = 0.95 if round.in_zone() else 0.75
	draw_rect(band, gold)
	draw_rect(band, Color("fff6d8"), false, 1.0)
	var y := roundf(g.end.y - round.temp * g.size.y)
	draw_rect(Rect2(g.position.x - 5, y - 2, g.size.x + 10, 4), UiKit.OUTLINE)
	draw_rect(Rect2(g.position.x - 4, y - 1, g.size.x + 8, 2), Color.WHITE)
	# 焦了几分：条底下三个点
	for i in 3:
		var lit := round.scorch > 0.1 + i * 0.15
		draw_rect(Rect2(g.position.x - 2 + i * 5, g.end.y + 6, 4, 4), UiKit.OUTLINE)
		draw_rect(Rect2(g.position.x - 1 + i * 5, g.end.y + 7, 2, 2), Color("2a2a30") if lit else Color("c8b89a"))


## 提鲜的机会：调料那边亮一个泡，底下一条在缩的时间。
func _draw_season() -> void:
	var at := Vector2(146, 60)
	var blink := 0.75 + 0.25 * sin(_clock * 16.0)
	draw_rect(Rect2(at, Vector2(58, 26)), UiKit.OUTLINE)
	draw_rect(Rect2(at + Vector2.ONE, Vector2(56, 24)), Color(1.0, 0.96, 0.85, blink))
	draw_string(get_theme_default_font(), at + Vector2(6, 12), "提鲜  按上", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiKit.ACCENT)
	var left := round.season_left / CookRound.SEASON_SECONDS
	draw_rect(Rect2(at + Vector2(4, 18), Vector2(50, 4)), UiKit.OUTLINE)
	draw_rect(Rect2(at + Vector2(5, 19), Vector2(48 * left, 2)), Color("7cc74f"))
	draw_rect(Rect2(at + Vector2(24, 26), Vector2(4, 4)), UiKit.OUTLINE)


func _draw_serve_ring() -> void:
	var p := round.serve_ring()
	var k := 1.0 + p * 0.9
	var good := p <= CookRound.SERVE_GOOD
	var color := GOLD if good else Color.WHITE
	color.a = 0.95 if good else 0.7
	_ring(WOK_AT, (WOK_RX + 5) * k, (WOK_RY + 4) * k, 0.0, TAU, color, 3.0 if good else 2.0)


## 出锅：暗下来，大盘端上来，盘里就是刚才锅里那些。右上盖一个评语的章。
func _draw_result() -> void:
	draw_rect(Rect2(0, 0, 384, 216), Color(0.10, 0.06, 0.05, 0.72))
	var center := Vector2(192, 78)
	if _tex["plate"] != null:
		draw_texture(_tex["plate"], center - Vector2(80, 48))
	var juice := Color(0, 0, 0)
	for k in _colors.size():
		juice += _colors[k]
	juice = (juice / float(_colors.size())).darkened(0.2 + round.scorch * 0.5)
	juice.a = 0.6
	_ellipse(center + Vector2(0, -3), 34, 17, juice)
	for k in _colors.size():
		for i in BITS_EACH + 2:
			var a := i * 2.39996 + k * 1.3
			var r := sqrt((i + 0.5) / (BITS_EACH + 2.0)) * 30.0
			_bit(center + Vector2(cos(a) * r, sin(a) * r * 0.5 - 4.0 - (1.0 - r / 30.0) * 5.0), k, 0.0)
	for i in 5:
		var t := fposmod(_clock * 0.45 + i * 0.23, 1.0)
		var x := center.x + (i - 2) * 12.0 + sin(t * 4.0 + i) * 3.0
		draw_rect(Rect2(roundf(x), roundf(center.y - 14.0 - t * 30.0), 3, 3), Color(1, 1, 1, (1.0 - t) * 0.7))
	# 章
	var seal := Rect2(center + Vector2(64, -52), Vector2(34, 18))
	var ink := UiKit.ACCENT if round.grade == CookRound.Grade.SIGNATURE else (Color("b8762c") if round.grade == CookRound.Grade.TASTY else Color("7a6a58"))
	draw_rect(seal, ink)
	draw_rect(seal.grow(-2), UiKit.TEXT_LIGHT, false, 1.0)
	draw_string(get_theme_default_font(), seal.position + Vector2(5, 13), round.grade_name(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiKit.TEXT_LIGHT)
	if round.grade == CookRound.Grade.SIGNATURE:
		draw_texture(UiKit.quality_mark(2 if raised else 1), seal.position + Vector2(36, 4))
