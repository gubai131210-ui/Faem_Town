class_name Glow
extends RefCounted
## 灯、窗、烟和萤火虫的画面规则。闪烁只改已有灯的亮度，不加新的灯（决策 061）。
## 游戏里 OutdoorMap._glow_pass 和四帧预览共用这里的明灭、位置与角度函数。


## 亮度在这两头之间晃。比第一版收窄一点，免得看久了烦。
const FLICKER_LO := 0.84
const FLICKER_HI := 1.0
## 早饭、午饭、晚饭。每段是 [起, 止)，单位是一天里的分钟
const MEALS: Array = [[420, 480], [690, 780], [1050, 1140]]
## 石叔在铺子里的钟点，和他的日程同一段
const FORGE_FROM := 480
const FORGE_TO := 1050
## 第一扇窗从傍晚五点开始亮，后面每扇隔这么多分钟
const WINDOW_FROM := 1020
const WINDOW_STEP := 12
const WINDOW_RAMP := 20.0
## 夏天晚上水边的萤火虫，晚上七点到十点
const FLY_FROM := 1140
const FLY_TO := 1320
const FLY_COUNT := 4
const SMOKE := Color(0.62, 0.66, 0.72, 0.55)
const SPARK := Color(1.0, 0.62, 0.22, 0.95)
const WINDOW := Color("ffd76a")
const BEAM := Color(1.0, 0.86, 0.45, 0.5)


## 已有那盏灯这一刻的亮度系数，乘在原来的 energy 上。
## 两个不同频率叠着，不是一条严格的正弦，看着才不像机器在闪。
static func flicker(time: float, phase: float) -> float:
	var slow := sin(time * 2.1 + phase)
	var fast := sin(time * 5.7 + phase * 1.7)
	var v := clampf((slow * 0.58 + fast * 0.42 + 1.0) * 0.5, 0.0, 1.0)
	return lerpf(FLICKER_LO, FLICKER_HI, v)


## 这分钟是不是做饭的钟点。
static func cooking(minutes: float) -> bool:
	var m := int(minutes)
	for span: Array in MEALS:
		if m >= int(span[0]) and m < int(span[1]):
			return true
	return false


## 铁匠铺这分钟开不开工。
static func forge(minutes: float) -> bool:
	var m := int(minutes)
	return m >= FORGE_FROM and m < FORGE_TO


## 第 order 扇窗亮到哪。0 是灭，1 是全亮。
static func window_alpha(order: int, minutes: float) -> float:
	var start := float(WINDOW_FROM + order * WINDOW_STEP)
	return clampf((minutes - start) / WINDOW_RAMP, 0.0, 1.0)


## 这个季节、这个钟点，水边该有几只萤火虫。入夜和收工都按钟点渐着来，
## 不再一到七点就四只齐刷刷冒出来、十点齐刷刷消失。
static func firefly_count(season: int, minutes: float) -> int:
	if season != 1:
		return 0
	var m := int(minutes)
	if m < FLY_FROM or m >= FLY_TO:
		return 0
	var enter := clampf(float(m - FLY_FROM) / 60.0, 0.0, 1.0)
	var leave := clampf(float(FLY_TO - m) / 60.0, 0.0, 1.0)
	return maxi(1, int(roundf(minf(enter, leave) * float(FLY_COUNT))))


## 萤火虫这一刻整体有多亮，用来淡入淡出，避免"啪"地出现。
static func firefly_alpha(minutes: float) -> float:
	var m := int(minutes)
	if m < FLY_FROM or m >= FLY_TO:
		return 0.0
	return minf(clampf(float(m - FLY_FROM) / 45.0, 0.0, 1.0),
		clampf(float(FLY_TO - m) / 45.0, 0.0, 1.0))


## 第 i 只萤火虫相对它在水边的窝，这一刻飘到哪。游戏和预览共用。
static func fly_pos(i: int, time: float) -> Vector2:
	return Vector2(roundf(sin(time * 1.4 + float(i)) * 3.0),
		roundf(cos(time * 1.1 + float(i)) * 2.0))


## 第 i 只萤火虫用两帧里的哪一帧。
static func fly_frame(i: int, time: float) -> int:
	return 0 if fmod(time * 1.6 + float(i), 2.0) < 1.3 else 1


## 屋脊上第 k 团烟飘到哪。预览用；游戏里由 CPUParticles2D 按同一方向发射。
static func smoke_puff(k: int, time: float) -> Vector2:
	var t := fmod(time * 0.42 + float(k) / 6.0, 1.0)
	return Vector2(roundf(sin(float(k) * 2.3 + time * 0.8) * 3.0 * t), -roundf(t * 22.0))


## 灯塔光柱转到哪一度。十六秒转一圈。
static func beam_angle(time: float) -> float:
	return fmod(time * 22.5, 360.0)


## 一扇小窗，5×6，木框配暖黄的光。
static func window_image() -> Image:
	var img := Px.new_img(5, 6)
	Px.rect(img, 0, 0, 5, 6, Color("6a4a2c"))
	Px.rect(img, 1, 1, 3, 4, WINDOW)
	Px.px(img, 2, 2, Color("fff6c8"))
	return img


## 光柱在灯自己的坐标里：从灯室指向右边，转的是节点。
static func beam_points() -> PackedVector2Array:
	return PackedVector2Array([Vector2.ZERO, Vector2(46, -3), Vector2(46, 3)])


## 四帧拼在一张图上，每帧 160×80：房子和屋脊、三扇依次亮的窗、往上飘的烟、
## 转过去的光柱、水边两只萤火虫。调用的都是游戏里那几个函数。
## 这是按同一套规则画的帧示意，不是游戏截图。
static func preview() -> Image:
	const FW := 160
	const FH := 80
	var img := Image.create(FW * 4, FH, false, Image.FORMAT_RGBA8)
	img.fill(Color("20262e"))
	var wall := Color("4a4038")
	var roof := Color("3b4650")
	for frame in 4:
		var ox := frame * FW
		var time := frame * 1.4
		var minutes := 1020.0 + frame * 14.0
		for y in range(30, FH - 4):
			for x in range(ox + 8, ox + 92):
				img.set_pixel(x, y, wall)
		for y in range(24, 31):
			for x in range(ox + 4, ox + 96):
				img.set_pixel(x, y, roof)
		# 三扇窗，亮度直接取 window_alpha
		for i in 3:
			var a := window_alpha(i, minutes)
			var c: Color = Color("3a3028").lerp(WINDOW, a)
			for y in 10:
				for x in 12:
					img.set_pixel(ox + 18 + i * 22 + x, 40 + y, c)
			img.set_pixel(ox + 23 + i * 22, 45, Color("fff6c8") if a > 0.6 else Color("3a3028"))
		# 屋脊上的烟
		for k in 6:
			var p := smoke_puff(k, time)
			var px := clampi(ox + 62 + int(p.x), ox + 2, ox + FW - 3)
			var py := clampi(22 + int(p.y), 2, FH - 3)
			var c: Color = Color("5a6470").lerp(SMOKE, 0.6)
			img.set_pixel(px, py, c)
			img.set_pixel(px + 1, py, c)
			img.set_pixel(px, py + 1, c.darkened(0.15))
			img.set_pixel(px + 1, py + 1, c.darkened(0.15))
		# 灯塔光柱：从右上角按 beam_angle 扫一道
		var ang := deg_to_rad(beam_angle(time))
		for s in 30:
			var f := float(s) / 30.0
			var dx := cos(ang) * f * 40.0
			var dy := sin(ang) * f * 40.0
			for w in range(-2, 3):
				var bx := clampi(ox + 126 + int(dx) + int(dy * 0.2 * float(w)), ox + 94, ox + FW - 3)
				var by := clampi(14 + int(dy) + w, 2, FH - 3)
				img.set_pixel(bx, by, Color("20262e").lerp(BEAM, 0.55 * (1.0 - f)))
		# 水边两只萤火虫，位置取 fly_pos
		for i in 2:
			var p := fly_pos(i, time)
			var fx := clampi(ox + 108 + int(p.x), ox + 96, ox + FW - 3)
			var fy := clampi(66 + int(p.y), 2, FH - 3)
			var fc: Color = Color("f4ffa0") if fly_frame(i, time) == 0 else Color("c8e070")
			img.set_pixel(fx, fy, fc)
			img.set_pixel(fx + 1, fy, fc)
			img.set_pixel(fx, fy + 1, fc.darkened(0.2))
			img.set_pixel(fx + 1, fy + 1, fc.darkened(0.2))
		for y in FH:
			img.set_pixel(ox + FW - 1, y, Color("121820"))
	return img
