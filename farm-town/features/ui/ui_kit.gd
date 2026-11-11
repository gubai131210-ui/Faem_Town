class_name UiKit
extends RefCounted
## 界面的统一外观：字体、颜色、面板、按钮。所有界面都从这里取，不各自造。

const TEXT_DARK := Color("4a2f1c")
const TEXT_LIGHT := Color("fff6d8")
const TEXT_DIM := Color("8a6a4a")
const OUTLINE := Color("3a2416")
const FONT_SIZE := 8

static var _theme: Theme
static var _textures: Dictionary[String, Texture2D] = {}


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "PingFang SC", "SimHei", "Noto Sans CJK SC", "sans-serif"])
	font.font_weight = 600
	_theme = Theme.new()
	_theme.default_font = font
	_theme.default_font_size = FONT_SIZE

	_theme.set_color(&"font_color", &"Label", TEXT_DARK)
	_theme.set_constant(&"line_spacing", &"Label", 1)

	var normal := _button_box(Color("f3dcae"), Color("9a6a40"))
	var hover := _button_box(Color("fff0c4"), Color("c8483c"))
	var pressed := _button_box(Color("e2c088"), Color("9a6a40"))
	var disabled := _button_box(Color("d9c9a8"), Color("b89f7c"))
	_theme.set_stylebox(&"normal", &"Button", normal)
	_theme.set_stylebox(&"hover", &"Button", hover)
	_theme.set_stylebox(&"focus", &"Button", hover)
	_theme.set_stylebox(&"pressed", &"Button", pressed)
	_theme.set_stylebox(&"disabled", &"Button", disabled)
	for state: StringName in [&"font_color", &"font_hover_color", &"font_focus_color", &"font_pressed_color", &"font_hover_pressed_color"]:
		_theme.set_color(state, &"Button", TEXT_DARK)
	_theme.set_color(&"font_disabled_color", &"Button", Color("a89070"))
	return _theme


## 全屏的界面根节点，带统一主题。
static func root() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.theme = theme()
	return c


static func label(text: String, size: int = FONT_SIZE, color: Color = TEXT_DARK, outlined: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	if outlined:
		l.add_theme_color_override(&"font_outline_color", OUTLINE)
		l.add_theme_constant_override(&"outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## 木框纸底的面板。
static func panel() -> NinePatchRect:
	var p := NinePatchRect.new()
	p.texture = texture("panel")
	p.patch_margin_left = 5
	p.patch_margin_right = 5
	p.patch_margin_top = 5
	p.patch_margin_bottom = 5
	return p


static func button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(72, 16)
	b.focus_mode = Control.FOCUS_ALL
	return b


## 压暗背景的半透明遮罩。
static func dim(alpha: float = 0.45) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.08, 0.06, 0.12, alpha)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	return r


## 把控件按给定尺寸放在父节点正中。
static func center(c: Control, size: Vector2) -> void:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_top = 0.5
	c.anchor_bottom = 0.5
	c.offset_left = -floorf(size.x / 2.0)
	c.offset_right = c.offset_left + size.x
	c.offset_top = -floorf(size.y / 2.0)
	c.offset_bottom = c.offset_top + size.y


## 界面用到的贴图，生成一次后缓存。
static func texture(key: String) -> Texture2D:
	if _textures.has(key):
		return _textures[key]
	var tex: Texture2D
	match key:
		"panel":
			tex = Px.tex(PixelArt.ui_panel())
		"slot":
			tex = Px.tex(PixelArt.ui_slot(false))
		"slot_selected":
			tex = Px.tex(PixelArt.ui_slot(true))
		_:
			tex = Px.tex(PixelArt.icon(key))
	_textures[key] = tex
	return tex


static func item_icon(id: StringName) -> Texture2D:
	var def := Database.item(id)
	if def == null:
		return null
	return texture(def.icon)


static func _button_box(fill: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.content_margin_left = 6.0
	sb.content_margin_right = 6.0
	sb.content_margin_top = 2.0
	sb.content_margin_bottom = 2.0
	sb.anti_aliasing = false
	return sb
