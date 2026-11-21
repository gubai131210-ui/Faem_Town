class_name Surface
extends RefCounted
## 水面和天气的画面规则。颜色和 ground_art 里的水、湿沙、石板缝是同一套，不另开一套。
## 游戏里 OutdoorMap._draw_water / _draw_shore 和四帧预览都调用这里的函数，
## 预览才不是随手画的示意图：它核对的是同一套位移、明灭和浪形规则。


const FOAM := Color("c4e9f6")
const WATER_LIGHT := Color("62b6e4")
const WATER_MID := Color("4aa0d8")
const PAVE_WET := Color("7c807e")
const DIRT_WET := Color("6a4328")
## 雨下满两个小时，水洼到最深；雨停以后三个小时干完
const SOAK_HOURS := 2.0
const DRY_HOURS := 3.0
## 浅过这个数就不画水洼
const PUDDLE_FROM := 0.35
## 一处波光从生到灭顺着水流走多远（像素）。
const DRIFT_SPAN := 14.0

## 每种水往哪边流。池塘和井里的静水不流，只在原地明灭。
const FLOW: Dictionary[StringName, Vector2] = {
	&"pond": Vector2.ZERO,
	&"stream": Vector2(1, 0.6),
	&"river": Vector2(1, 0),
	&"lake": Vector2(0.35, 0),
	&"sea": Vector2(0.7, 0),
	&"mine_shallow": Vector2.ZERO,
	&"mine_deep": Vector2.ZERO,
}


static func flow_of(kind: StringName) -> Vector2:
	return FLOW.get(kind, Vector2.ZERO)


## 一整轮（t 从 0 到 1）波光顺流挪开的位移。t 两端由 grow() 压到看不见，
## 所以循环回原点时不会跳一下。静水返回零，长短变化交给 grow。
static func drift(kind: StringName, t: float) -> Vector2:
	var flow := flow_of(kind)
	if flow == Vector2.ZERO:
		return Vector2.ZERO
	return Vector2(roundf(t * DRIFT_SPAN * flow.x), roundf(t * DRIFT_SPAN * flow.y * 0.6))


## 波光这一刻有多显眼：两头是 0，中间是 1。游戏和预览都用。
static func grow(t: float) -> float:
	return sin(clampf(t, 0.0, 1.0) * PI)


## 整条浪线的基准起伏（保留给旧调用）。逐点的形状看 wave_at。
static func wave_shift(time: float) -> float:
	return roundf(sin(time * 0.7) * 2.0)


## 岸上 x 这一点，这一刻浪线上下挪几像素。两个不同波长叠着往前推，
## 浪才是一道有形状的线，不是整条直棍上下平移。
static func wave_at(x: float, time: float) -> float:
	var a := sin(x * 0.11 - time * 1.7) * 1.5
	var b := sin(x * 0.045 + time * 0.6) * 0.6
	return clampf(roundf(a + b), -2.0, 2.0)


## 树和草的摇幅。calm 是晴天的幅度。
static func sway_amp(weather: StringName, calm: float) -> float:
	match weather:
		&"wind":
			return calm * 2.6
		&"storm":
			return calm * 2.2
		&"rain":
			return calm * 1.45
		&"snow":
			return calm * 0.65
		_:
			return calm


## 从 noted 分钟走到 minute，雨天变湿、晴天变干。返回新的湿度和该记住的分钟。
static func soak(wet: float, noted: int, minute: int, raining: bool) -> Vector2:
	if noted < 0:
		return Vector2(wet, minute)
	var delta := minute - noted
	if delta <= 0:
		return Vector2(wet, minute)
	var hours := delta / 60.0
	if raining:
		wet = minf(1.0, wet + hours / SOAK_HOURS)
	else:
		wet = maxf(0.0, wet - hours / DRY_HOURS)
	return Vector2(wet, minute)


static func puddle_alpha(wet: float) -> float:
	if wet < PUDDLE_FROM:
		return 0.0
	return clampf((wet - PUDDLE_FROM) / (1.0 - PUDDLE_FROM), 0.0, 1.0) * 0.85


## 四帧拼在一张图上：岸、水、三处顺流走的波光、一道有形状的浪线。
## 每帧 160×72，四帧 640×72，放大后能看清波光到底走了多远。
## 画的是和游戏同一套规则的帧示意，不是游戏截图。
static func preview() -> Image:
	const FW := 160
	const FH := 72
	var img := Image.create(FW * 4, FH, false, Image.FORMAT_RGBA8)
	img.fill(Color("2d3944"))
	var bank := Color("c9b488")
	var deep := Color("4595cc")
	for frame in 4:
		var ox := frame * FW
		var time := frame * 0.75
		for y in range(3, 27):
			for x in range(ox + 2, ox + FW - 2):
				img.set_pixel(x, y, bank if y < 24 else Color("a88f68"))
		for y in range(28, FH - 2):
			for x in range(ox + 2, ox + FW - 2):
				img.set_pixel(x, y, WATER_MID if (y + int(x * 0.3)) % 17 < 8 else deep)
		# 波光：和 _draw_water 一样用 fmod 的 t、drift、grow
		for k in 3:
			var t := fmod(time * (0.25 + k * 0.09) + k * 0.27, 1.0)
			var g := grow(t)
			if g < 0.08:
				continue
			var home := Vector2(ox + 24 + k * 38, 40 + k * 9)
			var at := home + drift(&"river", t)
			# 预览是局部放大：波光画两行，相当于把游戏里 1 像素的波光放大看
			var w := maxf(1, int(roundf(10.0 * g)))
			var col: Color = WATER_MID.lerp(FOAM if g > 0.6 else WATER_LIGHT, g)
			for i in w:
				var px := clampi(int(at.x) + i, ox + 2, ox + FW - 3)
				var py := clampi(int(at.y), 28, FH - 4)
				img.set_pixel(px, py, col)
				img.set_pixel(px, py + 1, col.darkened(0.12))
		# 浪线：逐点用 wave_at，连成一道线
		for x in range(ox + 2, ox + FW - 2):
			var yy := 27 + int(wave_at(float(x - ox), time))
			img.set_pixel(x, clampi(yy, 2, FH - 3), FOAM)
		for y in FH:
			img.set_pixel(ox + FW - 1, y, Color("1b232b"))
	return img
