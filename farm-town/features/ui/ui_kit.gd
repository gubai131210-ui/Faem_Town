class_name UiKit
extends RefCounted
## 界面的统一外观：字体、颜色、面板、按钮。所有界面都从这里取，不各自造。

const FACE_MOODS: Array[String] = ["", "happy", "sad"]
const TEXT_DARK := Color("4a2f1c")
const TEXT_LIGHT := Color("fff6d8")
const TEXT_DIM := Color("8a6a4a")
const OUTLINE := Color("3a2416")
const FONT_SIZE := 8
const MONEY := Color("9a5a1c")
const ACCENT := Color("c8483c")
const ROW := Color("e2c088")
## 物品种类在界面上叫什么、标签用什么颜色
const KIND_TAGS: Dictionary[StringName, Array] = {
	&"tool": ["工具", "8a6a4a"], &"seed": ["种子", "5a8a3a"], &"sapling": ["树苗", "4a7a3a"],
	&"crop": ["作物", "c8783c"], &"forage": ["山货", "7a8a3a"], &"fertilizer": ["肥料", "7a5a3a"],
	&"misc": ["杂物", "8a8078"], &"relic": ["旧物", "7a6a9a"], &"fish": ["鱼", "3a7a9a"],
	&"gear": ["器具", "6a6a7a"], &"feed": ["饲料", "a8843a"], &"product": ["加工品", "b8683a"],
	&"food": ["吃食", "c8483c"], &"ore": ["矿石", "6a7480"], &"weapon": ["武器", "9a3a3a"],
	&"accessory": ["饰品", "3a8a84"],
}

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
	var pressed := _button_box(Color("e2c088"), Color("9a6a40"), true)
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
	p.patch_margin_left = 7
	p.patch_margin_right = 7
	p.patch_margin_top = 7
	p.patch_margin_bottom = 7
	return p


## 弹出来的窗口：面板底下垫一层影子，顶上一条颜色深一点的标题栏（标题和按键提示写在里面，从 y=5 到 17）。
## 先建它、再往里加别的东西，标题栏才垫在字的下面。
static func window() -> NinePatchRect:
	var p := panel()
	var shadow := panel()
	shadow.modulate = Color(0, 0, 0, 0.3)
	shadow.show_behind_parent = true
	shadow.set_anchors_preset(Control.PRESET_FULL_RECT)
	shadow.offset_left = 2.0
	shadow.offset_top = 3.0
	shadow.offset_right = 2.0
	shadow.offset_bottom = 3.0
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(shadow)
	var band := ColorRect.new()
	band.name = "TitleBand"
	band.color = Color("eccf98")
	band.anchor_right = 1.0
	band.offset_left = 5.0
	band.offset_right = -5.0
	band.offset_top = 5.0
	band.offset_bottom = 17.0
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(band)
	var rule := ColorRect.new()
	rule.color = Color("c09a68")
	rule.anchor_right = 1.0
	rule.offset_left = 5.0
	rule.offset_right = -5.0
	rule.offset_top = 17.0
	rule.offset_bottom = 18.0
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(rule)
	return p


## 面板里凹下去的一块。
static func card() -> NinePatchRect:
	var p := NinePatchRect.new()
	p.texture = texture("card")
	p.patch_margin_left = 3
	p.patch_margin_right = 3
	p.patch_margin_top = 3
	p.patch_margin_bottom = 3
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## 列表里光标所在那一行的底：一条浅色，左边一道红。大小由用的地方定。
static func row_back() -> ColorRect:
	var back := ColorRect.new()
	back.color = ROW
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mark := ColorRect.new()
	mark.color = ACCENT
	mark.anchor_bottom = 1.0
	mark.offset_right = 2.0
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(mark)
	return back


## 窗口打开的那一下：从小一点弹到原大，同时淡入。
static func pop(c: Control) -> void:
	if c == null or not c.is_inside_tree():
		return
	c.pivot_offset = c.size / 2.0
	c.scale = Vector2(0.94, 0.94)
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, 0.1)


## 提示条的底（HUD 用）。
static func toast_box() -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = texture("toast")
	sb.set_texture_margin_all(3.0)
	sb.content_margin_left = 6.0
	sb.content_margin_right = 6.0
	sb.content_margin_top = 3.0
	sb.content_margin_bottom = 4.0
	return sb


## 一行字按界面的字体有多宽（像素）。
static func text_width(text: String, size: int = FONT_SIZE) -> float:
	return theme().default_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


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
		"card":
			tex = Px.tex(PixelArt.ui_card())
		"toast":
			tex = Px.tex(PixelArt.ui_toast())
		"coin":
			tex = Px.tex(PixelArt.coin())
		_:
			if key.begins_with("prop:"):
				# 大件物件（加工设备）缩成一个图标
				var img := PropArt.texture(key.substr(5)).get_image()
				var k := 16.0 / maxf(img.get_width(), img.get_height())
				img.resize(maxi(1, roundi(img.get_width() * k)), maxi(1, roundi(img.get_height() * k)), Image.INTERPOLATE_BILINEAR)
				tex = Px.tex(img)
			else:
				tex = Px.tex(PixelArt.icon(key))
	_textures[key] = tex
	return tex


## 居民的对话头像（tools/character.py 渲染的 64×64 近景）；没有就返回 null。
## 居民的头像。图是横着三格：平常、高兴、不高兴；mood 写 "happy" 或 "sad" 取后两格。
static func face(sheet: String, mood: String = "") -> Texture2D:
	var path := "res://art/characters/%s_face.png" % sheet
	if sheet.is_empty() or not ResourceLoader.exists(path):
		return null
	var strip := load(path) as Texture2D
	if strip == null:
		return null
	var side := strip.get_height()
	var index := maxi(FACE_MOODS.find(mood), 0)
	if (index + 1) * side > strip.get_width():
		index = 0
	var tex := AtlasTexture.new()
	tex.atlas = strip
	tex.region = Rect2(index * side, 0, side, side)
	return tex


static func item_icon(id: StringName) -> Texture2D:
	var def := Database.item(id)
	if def == null:
		return null
	if def.tiered:
		return texture("%s@%d" % [def.icon, GameState.tool_level(id)])
	return texture(def.icon)


## 品质标记；普通品质没有。
static func quality_mark(quality: int) -> Texture2D:
	if quality <= 0:
		return null
	var key := "quality_%d" % mini(quality, 2)
	if not _textures.has(key):
		_textures[key] = Px.tex(PixelArt.quality_mark(quality))
	return _textures[key]


## 按钮的底：下边厚一点，像凸起来的；按下去的时候换成上边厚。
static func _button_box(fill: Color, border: Color, sunk: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(1)
	if sunk:
		sb.border_width_top = 2
	else:
		sb.border_width_bottom = 2
	sb.content_margin_left = 6.0
	sb.content_margin_right = 6.0
	sb.content_margin_top = 2.0 if sunk else 1.0
	sb.content_margin_bottom = 1.0 if sunk else 2.0
	sb.anti_aliasing = false
	return sb
