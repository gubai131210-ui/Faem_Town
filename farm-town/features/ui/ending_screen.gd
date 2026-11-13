class_name EndingScreen
extends CanvasLayer
## 结局的画面：一张画铺满屏幕，对话框在它上面念旁白；念完亮出结局的名字，按一下收起。
## 只管显示，什么时候开、关了以后做什么由游戏主场景定。

## 结局名字亮出来以后玩家按了确认
signal closed

var _root: Control
var _art: TextureRect
var _shade: ColorRect
var _title: Label
var _sub: Label
var _hint: Label
var _waiting := false
var _blink := 0.0


func _ready() -> void:
	# 盖住地图和别的界面，在对话框（25）底下
	layer = 24
	_root = UiKit.root()
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var back := ColorRect.new()
	back.color = Color("0d0b14")
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(back)
	_art = TextureRect.new()
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_art)
	_shade = ColorRect.new()
	_shade.color = Color(0.05, 0.04, 0.1, 0.0)
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_shade)
	_title = _line(22, -34.0, 30.0)
	_sub = _line(9, 0.0, 14.0)
	_hint = _line(7, 78.0, 12.0)
	_hint.add_theme_color_override(&"font_color", Color("c8c0b0"))
	_root.visible = false


func _line(font_size: int, top: float, height: float) -> Label:
	var l := UiKit.label("", font_size, UiKit.TEXT_LIGHT, true)
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = 0.5
	l.anchor_bottom = 0.5
	l.offset_top = top
	l.offset_bottom = top + height
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.visible = false
	_root.add_child(l)
	return l


func _process(delta: float) -> void:
	if _waiting:
		_blink += delta
		_hint.visible = fmod(_blink, 1.0) < 0.65


func _unhandled_input(event: InputEvent) -> void:
	if not _waiting:
		return
	if event.is_action_pressed(&"use") or event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		_waiting = false
		_hint.visible = false
		closed.emit()


func is_open() -> bool:
	return _root.visible


## 现在是不是亮着结局的名字、等玩家按键。
func is_waiting() -> bool:
	return _waiting


func title_text() -> String:
	return _title.text


## 铺上这个结局的画。
func open(ending: StringName) -> void:
	_art.texture = Px.tex(EndingArt.scene(ending))
	_shade.color.a = 0.0
	_title.text = Story.TITLES.get(ending, "")
	_sub.text = "《雾隐青岚》"
	_hint.text = "日子照旧过下去 · 按使用键继续"
	_title.visible = false
	_sub.visible = false
	_hint.visible = false
	_waiting = false
	_root.visible = true


## 旁白念完了：压暗画面，亮出结局的名字，等玩家按键。
func show_title() -> void:
	_title.visible = true
	_sub.visible = true
	_title.modulate.a = 0.0
	_sub.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_shade, "color:a", 0.45, 0.8)
	tw.parallel().tween_property(_title, "modulate:a", 1.0, 0.8)
	tw.tween_property(_sub, "modulate:a", 1.0, 0.5)
	await tw.finished
	_blink = 0.0
	_waiting = true


func close() -> void:
	_waiting = false
	_root.visible = false
