class_name WeatherFx
extends CanvasLayer
## 天气的画面效果：雨丝、雪花、雾、风。只在室外显示，画在游戏画面之上、界面之下。

const RAIN_COLOR := Color(0.78, 0.88, 1.0, 0.55)
const SNOW_COLOR := Color(1.0, 1.0, 1.0, 0.85)
const FOG_COLOR := Color(0.88, 0.92, 0.94)
const WIND_COLOR := Color(1.0, 1.0, 1.0, 0.35)
## 雾气图放大的倍数
const FOG_SCALE := 4.0

## 当前显示的天气，空表示不显示（晴天、多云、室内）
var kind: StringName = &""

var _canvas: Node2D
var _time := 0.0
var _fog_tex: ImageTexture


func _ready() -> void:
	layer = 5
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_fx)
	add_child(_canvas)


func show_weather(weather: StringName) -> void:
	if kind == weather:
		return
	kind = weather
	_canvas.queue_redraw()


func _process(delta: float) -> void:
	if kind == &"":
		return
	_time += delta
	_canvas.queue_redraw()


func _draw_fx() -> void:
	var size := _canvas.get_viewport_rect().size
	match kind:
		&"rain":
			_rain(size, 70, 260.0)
		&"storm":
			_rain(size, 130, 330.0)
		&"snow":
			_snow(size)
		&"fog":
			_fog(size)
		&"wind":
			_wind(size)


func _rain(size: Vector2, count: int, speed: float) -> void:
	for i in count:
		var x0 := float(Px.h2(i, 1) % 1000) / 1000.0 * (size.x + 60.0)
		var y0 := float(Px.h2(i, 2) % 1000) / 1000.0 * (size.y + 20.0)
		var v := speed * (0.8 + float(Px.h2(i, 3) % 100) / 250.0)
		var y := fposmod(y0 + _time * v, size.y + 20.0) - 10.0
		var x := fposmod(x0 - _time * v * 0.3, size.x + 60.0) - 10.0
		_canvas.draw_line(Vector2(roundf(x), roundf(y)), Vector2(roundf(x) - 2.0, roundf(y) + 6.0), RAIN_COLOR, 1.0)


func _snow(size: Vector2) -> void:
	for i in 60:
		var x0 := float(Px.h2(i, 4) % 1000) / 1000.0 * size.x
		var y0 := float(Px.h2(i, 5) % 1000) / 1000.0 * size.y
		var v := 14.0 + float(Px.h2(i, 6) % 100) / 5.0
		var y := fposmod(y0 + _time * v, size.y + 4.0) - 2.0
		var x := fposmod(x0 + sin(_time * 0.8 + i) * 6.0, size.x)
		var big := i % 4 == 0
		_canvas.draw_rect(Rect2(roundf(x), roundf(y), 2.0 if big else 1.0, 2.0 if big else 1.0), SNOW_COLOR)


func _fog(size: Vector2) -> void:
	if _fog_tex == null:
		_fog_tex = _make_fog()
	# 一张左右能接上的雾气图，慢慢横移；画两遍把接缝补上
	var w := float(_fog_tex.get_width()) * FOG_SCALE
	var x := -fposmod(roundf(_time * 5.0), w)
	while x < size.x:
		_canvas.draw_texture_rect(_fog_tex, Rect2(x, 0.0, w, size.y), false)
		x += w


## 生成雾气图：浓淡分成几档，横向首尾相接。
static func _make_fog() -> ImageTexture:
	var w := 160
	var h := 54
	var noise := FastNoiseLite.new()
	noise.seed = 31
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var radius := w / TAU
	for y in h:
		for x in w:
			# 把 x 绕成一个圆来取样，这样左右两边是连着的
			var a := x / float(w) * TAU
			var n := noise.get_noise_3d(cos(a) * radius * 2.0, sin(a) * radius * 2.0, y * 3.0) * 0.5 + 0.5
			var alpha := 0.2 + floorf(clampf(n, 0.0, 0.999) * 5.0) / 5.0 * 0.3
			img.set_pixel(x, y, Color(FOG_COLOR, alpha))
	return ImageTexture.create_from_image(img)


func _wind(size: Vector2) -> void:
	for i in 14:
		var y := float(Px.h2(i, 10) % 1000) / 1000.0 * size.y
		var v := 150.0 + float(Px.h2(i, 11) % 100)
		var length := 10.0 + float(Px.h2(i, 12) % 14)
		var x := fposmod(float(Px.h2(i, 13) % 1000) / 1000.0 * size.x + _time * v, size.x + 80.0) - 40.0
		_canvas.draw_rect(Rect2(roundf(x), roundf(y), length, 1.0), WIND_COLOR)
