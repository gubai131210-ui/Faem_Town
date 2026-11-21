extends CanvasLayer
## 按顺序演一段过场。跳过和看完记同一个标记，不改别的状态。
## 取消键或 pause 跳过。force_next 只给截图脚本把这一段拨过去。

signal finished
signal step_shown(step: Dictionary)

var playing := false
var beat: StringName = &""

var _skipped := false
var _advance := false
var _caption: Label
var _art: TextureRect
var _shade: ColorRect
var _root: Control

const _Script := preload("res://game/cutscene.gd")


func _ready() -> void:
	layer = 23
	visible = false
	_root = UiKit.root()
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	_shade = ColorRect.new()
	_shade.color = Color("1a1816")
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_shade)
	_art = TextureRect.new()
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.offset_top = 18
	_art.offset_bottom = -36
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_art)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color("0c0a10")
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		if top:
			bar.offset_bottom = 16
		else:
			bar.offset_top = -28
		_root.add_child(bar)
	_caption = UiKit.label("", 12, Color("f4f0e6"), true)
	_caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_caption.offset_top = -26
	_caption.offset_bottom = -6
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_caption)


func play(id: StringName, steps: Array) -> void:
	if playing:
		return
	playing = true
	_skipped = false
	visible = true
	for step in steps:
		if _skipped:
			break
		beat = step["id"]
		_show(step)
		await _hold(step)
	beat = &""
	visible = false
	playing = false
	GameState.set_flag(_Script.seen_flag(id))
	finished.emit()


func skip() -> void:
	_skipped = true


func force_next() -> void:
	_advance = true


func _show(step: Dictionary) -> void:
	_caption.text = str(step.get("text", ""))
	var pic: StringName = step.get("picture", &"")
	if pic == &"":
		_art.texture = null
		_shade.color = Color(0, 0, 0, 0)
	else:
		_shade.color = Color("1a1816")
		var cast: Array = step.get("cast", [])
		var aged := str(step.get("tint", "")) == "sepia"
		var img: Image
		if bool(step.get("anim", false)):
			img = _Script.picture_at(pic, 0.0, float(step["sec"]))
		elif not cast.is_empty() or aged:
			img = _Script.compose(pic, cast, 0.0, float(step["sec"]), aged)
		else:
			img = _Script.picture(pic)
		_art.texture = ImageTexture.create_from_image(img)
	step_shown.emit(step)


func _hold(step: Dictionary) -> void:
	var sec := float(step["sec"])
	var walk: Array = step.get("walk", [])
	var cast: Array = step.get("cast", [])
	var anim := bool(step.get("anim", false))
	var base: Image = _Script.picture(step.get("picture", &"")) if walk.size() == 4 else null
	var t := 0.0
	_advance = false
	while t < sec and not _skipped and not _advance:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		t += get_process_delta_time()
		if not cast.is_empty():
			var played: Image = _Script.compose(step["picture"], cast, t, sec, str(step.get("tint", "")) == "sepia")
			_art.texture = ImageTexture.create_from_image(played)
		elif anim:
			var moving: Image = _Script.picture_at(step["picture"], t, sec)
			_art.texture = ImageTexture.create_from_image(moving)
		elif base != null:
			var frame := base.duplicate()
			var u := clampf(t / sec, 0.0, 1.0)
			_Script.stamp_person(frame, lerpf(float(walk[0]), float(walk[2]), u), lerpf(float(walk[1]), float(walk[3]), u), int(t * 8.0))
			_art.texture = ImageTexture.create_from_image(frame)


func _unhandled_input(event: InputEvent) -> void:
	if not playing:
		return
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		skip()
		get_viewport().set_input_as_handled()
