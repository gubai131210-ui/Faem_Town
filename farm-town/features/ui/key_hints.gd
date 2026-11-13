class_name KeyHints
extends HBoxContainer
## 一行按键提示：“空格 买 1 个    E 关闭”这样的一句话，每一段的头一个词画成一个键帽，后面是说明。
## 用起来和 Label 差不多：给 text 赋值就重画，horizontal_alignment 定靠哪边。

var text := "":
	set(value):
		if value == text:
			return
		text = value
		if is_inside_tree():
			_rebuild()

var horizontal_alignment := HORIZONTAL_ALIGNMENT_LEFT:
	set(value):
		horizontal_alignment = value
		match value:
			HORIZONTAL_ALIGNMENT_CENTER:
				alignment = BoxContainer.ALIGNMENT_CENTER
			HORIZONTAL_ALIGNMENT_RIGHT:
				alignment = BoxContainer.ALIGNMENT_END
			_:
				alignment = BoxContainer.ALIGNMENT_BEGIN

static var _cap: StyleBoxFlat


func _init(hint: String = "") -> void:
	add_theme_constant_override(&"separation", 2)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	text = hint


## 进了场景树才摆键帽：在外面摆的话字还没拿到主题，按引擎默认字号算，
## 这一行会被撑到二十多像素高，之后再设 size 也缩不回去，提示就掉到面板外面了。
func _enter_tree() -> void:
	_rebuild()


## 把一句提示拆开：两个以上空格隔开的是一段，每段头一个空格前面是键、后面是说明。返回 [[键, 说明], ...]。
static func parse(hint: String) -> Array:
	var out: Array = []
	var part := ""
	var spaces := 0
	var parts: PackedStringArray = []
	for ch in hint:
		if ch == " ":
			spaces += 1
			continue
		if spaces >= 2 and part != "":
			parts.append(part)
			part = ""
		elif spaces == 1 and part != "":
			part += " "
		spaces = 0
		part += ch
	if part != "":
		parts.append(part)
	for p in parts:
		var cut := p.find(" ")
		if cut < 0:
			out.append(["", p])
		else:
			out.append([p.substr(0, cut), p.substr(cut + 1)])
	return out


func _rebuild() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var groups := parse(text)
	for i in groups.size():
		var key: String = groups[i][0]
		if key != "":
			var cap := PanelContainer.new()
			cap.add_theme_stylebox_override(&"panel", _cap_box())
			cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			cap.add_child(UiKit.label(key, 6, UiKit.TEXT_DARK))
			add_child(cap)
		var what := UiKit.label(String(groups[i][1]), 6, UiKit.TEXT_DIM)
		what.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(what)
		if i < groups.size() - 1:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(5, 0)
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(gap)


static func _cap_box() -> StyleBoxFlat:
	if _cap == null:
		_cap = StyleBoxFlat.new()
		_cap.bg_color = Color("fff6d8")
		_cap.border_color = Color("9a6a40")
		_cap.set_border_width_all(1)
		_cap.border_width_bottom = 2
		_cap.content_margin_left = 2.0
		_cap.content_margin_right = 2.0
		_cap.content_margin_top = 0.0
		_cap.content_margin_bottom = 0.0
		_cap.anti_aliasing = false
	return _cap
