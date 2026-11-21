class_name CookShow
extends CanvasLayer
## 厨艺演出已结算成品。CookRound 认得的做法（现在是炒）进亲手做的灶台，其他菜按各自做法演出。
## 亲手做到拿手：记火候印，刚出锅的那一份品质高一档。跳过或做得一般，成品仍是原来那一份。

const STAGE := "res://art/cooking/kitchen.png"
const FIRE := "res://art/cooking/fire.png"
## 外锅中心和灶膛口在灶间图上的像素位置，跟 tools/kitchen.py 的 WOK、FIRE 对应
const WOK_AT := Vector2(256, 107)
const FIRE_AT := Vector2(240, 137)
## 人在锅沿左边。再往右，帽子会钻进锅里。锅图是 96x64，锅口在格子的 x=64。
const WHO_AT := Vector2(148, 68)
const POT_FRAME := Vector2(96, 64)
const BAR_AT := Vector2(216, 198)
const BAR_SIZE := Vector2(80, 5)
const Workbench := preload("res://features/ui/stove_workbench.gd")

var _root: Control
var _legacy: Control
var _dim: ColorRect
var _bench: Workbench
var _who: Sprite2D
var _pot: Sprite2D
var _fire: Sprite2D
var _air: Control
var _title: Label
var _hint: Label
var _say: Label
var _bar: Control
var _card: NinePatchRect
var _dish: Sprite2D
var _dish_name: Label
var _dish_note: Label
var _dish_who: Label
var _drops: Array[TextureRect] = []
var _sheet: CharacterSheet
var _heat := CookHeat.new()
var _time := 0.0
var _id: StringName = &""
var _in_term := false
## 试看：只演，不记做过、不记火候、不说「做好了」。
var _preview := false
## 切和拌不动火：灶膛里只留小火，话也换一套
var _cold := false


func _ready() -> void:
	layer = 21
	_root = UiKit.root()
	add_child(_root)
	_legacy = UiKit.root()
	_root.add_child(_legacy)
	var back := TextureRect.new()
	back.texture = _load(STAGE)
	back.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_legacy.add_child(back)
	_fire = _sprite(FIRE_AT)
	_fire.texture = _load(FIRE)
	# 人画在灶锅下面：手里那口锅藏到灶锅后面，只看见一口锅；顺序反了就像两口锅。
	_who = _sprite(WHO_AT)
	_who.scale = Vector2(2, 2)
	_pot = _sprite(WOK_AT - Vector2(64, 32))
	_air = Control.new()
	_air.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_air.draw.connect(_draw_air)
	_legacy.add_child(_air)
	var plate := UiKit.panel()
	plate.position = Vector2(6, 6)
	plate.size = Vector2(112, 18)
	_legacy.add_child(plate)
	_title = UiKit.label("", 8)
	_title.position = Vector2(6, 3)
	_title.size = Vector2(100, 12)
	plate.add_child(_title)
	_bar = Control.new()
	_bar.position = BAR_AT
	_bar.size = BAR_SIZE
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(_draw_bar)
	_legacy.add_child(_bar)
	_say = UiKit.label("", 8, UiKit.TEXT_LIGHT, true)
	_say.position = Vector2(196, 184)
	_say.size = Vector2(120, 12)
	_say.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_legacy.add_child(_say)
	_hint = UiKit.label("", 6, UiKit.TEXT_LIGHT, true)
	_hint.position = Vector2(8, 202)
	_legacy.add_child(_hint)
	# 盘子亮在左边，灶和人不挡
	_card = UiKit.panel()
	_card.position = Vector2(14, 50)
	_card.size = Vector2(150, 98)
	_legacy.add_child(_card)
	_dish = Sprite2D.new()
	_dish.centered = false
	_dish.position = Vector2(43, 4)
	_dish.scale = Vector2(2, 2)
	_dish.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_card.add_child(_dish)
	_dish_name = _card_line(62, 8, UiKit.TEXT_DARK)
	_dish_note = _card_line(73, 6, UiKit.ACCENT)
	_dish_who = _card_line(83, 6, UiKit.TEXT_DIM)
	_sheet = CharacterSheet.load_sheet("farmer")
	_dim = UiKit.dim(1.0)
	_root.add_child(_dim)
	_bench = Workbench.new()
	_bench.finished.connect(_on_workbench_finished)
	_bench.close_requested.connect(close)
	_root.add_child(_bench)
	_root.visible = false


func _sprite(at: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.position = at
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_legacy.add_child(s)
	return s


func _card_line(y: float, size: int, color: Color) -> Label:
	var l := UiKit.label("", size, color)
	l.position = Vector2(0, y)
	l.size = Vector2(150, 11)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.add_child(l)
	return l


func _load(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null


func is_open() -> bool:
	return _root != null and _root.visible


## 这一场走到哪一段了，测试和自动流程用。
func phase() -> int:
	return _heat.phase


func open(id: StringName, preview: bool = false) -> void:
	if not Database.recipes.has(id):
		return
	_id = id
	_preview = preview
	_time = 0.0
	if not preview:
		Crafting.mark_cooked(id)
	if not preview and CookRound.supports(Database.recipes[id]):
		layer = 21
		_legacy.hide()
		_dim.show()
		_root.show()
		_bench.start(Database.recipes[id])
		return
	_bench.hide()
	_dim.hide()
	_legacy.show()
	var def: RecipeDef = Database.recipes[id]
	_in_term = Crafting.in_term(def)
	_cold = def.method == &"cut" or def.method == &"mix"
	var watch := def.from != &"odd" and not Crafting.has_heat(id)
	var seconds := Crafting.cook_seconds(id)
	_heat.start(def.ingredients.size(), seconds * 1.25 if watch else seconds, watch)
	# 开场在 23 层，试看要盖在它上面
	layer = 24 if _preview else 21
	var word := str(RecipeDef.METHOD_NAMES.get(def.method, "煮"))
	_title.text = "%s · %s" % [word, Database.item(id).name]
	_pot.texture = _load("res://art/cooking/pot_%s.png" % def.method)
	for d in _drops:
		d.queue_free()
	_drops.clear()
	for item_id: StringName in def.ingredients:
		var icon := TextureRect.new()
		icon.texture = UiKit.item_icon(item_id)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.size = Vector2(16, 16)
		_legacy.add_child(icon)
		_legacy.move_child(icon, _air.get_index())
		_drops.append(icon)
	_fill_card(id)
	_root.visible = true
	_show()


func _fill_card(id: StringName) -> void:
	var path := "res://art/food/%s.png" % id
	var tex := _load(path)
	_dish.region_enabled = tex != null
	_dish.texture = tex if tex != null else UiKit.item_icon(id)
	_dish.scale = Vector2(2, 2) if tex != null else Vector2(3, 3)
	_dish.position = Vector2(43, 0) if tex != null else Vector2(51, 8)
	_dish_name.text = Database.item(id).name
	var who := Crafting.fond_of(id)
	_dish_who.text = who + "爱这一口。" if who != "" else ""


func close() -> void:
	if not is_open():
		return
	_root.visible = false
	_bench.hide()
	_heat.phase = CookHeat.OVER
	layer = 21
	if _id != &"" and not _preview:
		EventBus.banner_requested.emit("做好了：" + Database.item(_id).name)
	_id = &""
	_preview = false


func _on_workbench_finished(grade: int) -> void:
	if grade != CookRound.Grade.SIGNATURE or _id == &"" or _preview:
		return
	Crafting.mark_heat(_id)
	_bench.raised = Crafting.raise_plate(_id)


func _process(delta: float) -> void:
	if not is_open() or _bench.visible:
		return
	_time += delta
	_heat.advance(delta)
	if _heat.phase == CookHeat.OVER:
		close()
		return
	_show()


func _show() -> void:
	# 人和锅都按序列帧自己的速度走，不跟画面刷新绑死在 6 帧
	var who_rate := _sheet.fps(&"cook") if _sheet.is_valid() else 10.0
	var frame := int(_time * who_rate)
	var pot_frame := int(_time * 10.0)
	if _sheet.is_valid():
		_who.texture = _sheet.texture
		_who.region_enabled = true
		_who.region_rect = _sheet.region(&"cook", GameMap.Facing.RIGHT, frame)
	if _pot.texture != null:
		_pot.region_enabled = true
		# 材料还在往下落时灶上是空锅，落完了这道菜的锅才上来
		_pot.visible = _heat.phase != CookHeat.DROP
		_pot.region_rect = Rect2((pot_frame % 8) * POT_FRAME.x, 0, POT_FRAME.x, POT_FRAME.y)
	if _fire.texture != null:
		_fire.region_enabled = true
		_fire.region_rect = Rect2((int(_time * 8.0) % 4) * 32, (0 if _cold else _heat.fire_level()) * 24, 32, 24)
	for i in _drops.size():
		var p := _heat.drop_progress(i)
		_drops[i].visible = _heat.phase == CookHeat.DROP and p > 0.0 and p < 1.0
		var from := Vector2(WOK_AT.x - 8 + (i - (_drops.size() - 1) * 0.5) * 20, 30)
		_drops[i].position = from.lerp(WOK_AT - Vector2(8, 10), p * p)
	var serving := _heat.phase == CookHeat.SERVE
	_card.visible = serving
	_bar.visible = _heat.watch and not serving
	if serving:
		if _dish.region_enabled:
			_dish.region_rect = Rect2((int(_time * 4.0) % 4) * 32, 0, 32, 32)
		var notes := PackedStringArray()
		if _heat.just:
			notes.append("火候正好")
		if _in_term:
			notes.append("当令")
		_dish_note.text = " · ".join(notes)
		_say.text = ""
		_hint.text = "使用：收起"
	else:
		if _heat.phase == CookHeat.DROP:
			_say.text = "下锅"
		elif not _heat.watch:
			_say.text = ""
		elif _heat.in_sweet():
			_say.text = "就是现在"
		elif _heat.early_shown():
			_say.text = "还没好，再等等" if _cold else "还生着，再等等"
		else:
			_say.text = "手上稳着" if _cold else "看着火"
		_hint.text = ("使用：装盘　取消：跳过" if _cold else "使用：出锅　取消：跳过") if _heat.watch else "取消：跳过"
	_air.queue_redraw()
	_bar.queue_redraw()


## 锅上的热气，和火候到了时锅沿的一圈亮。
func _draw_air() -> void:
	if _heat.phase == CookHeat.DROP:
		return
	var heat := _heat.heat()
	# 切和拌不冒气
	var count := 0 if _cold else 3 + int(heat * 9.0)
	for i in count:
		var t := fposmod(_time * 0.55 + i * 0.37, 1.0)
		var x := WOK_AT.x + sin(i * 2.3 + t * 3.0) * (6.0 + t * 8.0) + (i % 3 - 1) * 7.0
		var y := WOK_AT.y - 8.0 - t * 52.0
		var s := 3.0 + float(i % 3)
		# 白墙前面白气看不见，底下垫一圈灰蓝
		_air.draw_rect(Rect2(roundf(x) - 1, roundf(y) - 1, s + 2, s + 2), Color(0.42, 0.48, 0.58, (1.0 - t) * 0.45))
		_air.draw_rect(Rect2(roundf(x), roundf(y), s, s), Color(1, 1, 1, (1.0 - t) * 0.85))
	if _heat.in_sweet():
		var glow := Color("ffd070")
		glow.a = 0.75 + 0.25 * sin(_time * 14.0)
		_air.draw_arc(WOK_AT, 26.0, 0.0, TAU, 40, glow, 2.0)


## 火候条：金色那一段是正好。
func _draw_bar() -> void:
	var w := BAR_SIZE.x
	var h := BAR_SIZE.y
	_bar.draw_rect(Rect2(-1, -1, w + 2, h + 2), UiKit.OUTLINE)
	_bar.draw_rect(Rect2(0, 0, w, h), Color("6b4226"))
	_bar.draw_rect(Rect2(w * CookHeat.SWEET_FROM, 0, w * (CookHeat.SWEET_TO - CookHeat.SWEET_FROM), h), Color("e2b84e"))
	var x := roundf(w * _heat.heat())
	_bar.draw_rect(Rect2(x - 1, -2, 2, h + 4), UiKit.TEXT_LIGHT)


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause") or (
			_bench.visible and event.is_action_pressed(&"inventory")):
		close()
		get_viewport().set_input_as_handled()
	elif _bench.visible:
		if _bench.handle_input(event):
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"use"):
		get_viewport().set_input_as_handled()
		var got := _heat.press()
		if got == &"just" and not _preview:
			Crafting.mark_heat(_id)
			Audio.play("harvest", 0.0, -4.0)
		elif got == &"close":
			close()
