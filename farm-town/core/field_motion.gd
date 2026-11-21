class_name FieldMotion
extends RefCounted
## M9 第三批：田里和树上的画面规则。纯函数，不碰节点，方便单元测试和四帧预览。
## 作物摇晃、成熟闪光、落花落叶、图标落地弹跳都从这里取值，预览和游戏用的是同一套。


const PETAL := Color("f7b8c8")
const LEAF := Color("c8903c")
const SNOW := Color("eef3f6")
const OSMANTHUS := Color("f7d24a")
const DUST := Color("9a6a40")
## 成熟作物隔这么久闪一下
const RIPE_PERIOD := 3.4
## 一片叶子从树冠落到地面要走多高
const FALL_HEIGHT := 26.0


## 这个季节这片树落什么。夏天什么都不落。桂花林只有秋天飘桂花。
static func fall_kind(season: int, osmanthus: bool) -> StringName:
	if osmanthus:
		return &"osmanthus" if season == 2 else &""
	match season:
		0:
			return &"petal"
		2:
			return &"leaf"
		3:
			return &"snow"
		_:
			return &""


static func fall_color(kind: StringName) -> Color:
	match kind:
		&"petal":
			return PETAL
		&"leaf":
			return LEAF
		&"snow":
			return SNOW
		&"osmanthus":
			return OSMANTHUS
		_:
			return Color.TRANSPARENT


## 第 i 片从树冠出发，这一刻飘到哪。y 一直往下，x 左右打着旋，
## 走完一个周期回到树冠重来；每片速度不同，不会齐刷刷一起掉。
static func fall_pos(i: int, time: float, height: float = FALL_HEIGHT) -> Vector2:
	var speed := 0.32 + float(i % 5) * 0.05
	var t := fmod(time * speed + float(i) * 0.37, 1.0)
	var sway := sin(t * 7.0 + float(i) * 2.1) * (2.0 + float(i % 3))
	return Vector2(roundf(sway), roundf(t * height))


## 作物有风才晃，晴天站着不动。数值是 shader 的 amp，单位约等于像素。
static func crop_sway(weather: StringName) -> float:
	match weather:
		&"wind":
			return 2.2
		&"storm":
			return 1.8
		&"rain":
			return 0.9
		&"snow":
			return 0.2
		_:
			return 0.0


## 成熟作物这一刻的亮度系数。大部分时间是 1，隔一会儿一个短脉冲。
static func ripe_flash(time: float, phase: float) -> float:
	var t := fmod(time + phase, RIPE_PERIOD)
	if t > 0.28:
		return 1.0
	return 1.0 + 0.22 * sin(t / 0.28 * PI)


## 图标从手里弹起、落到地上、再小跳一下的 y 偏移（负数朝上）。
## t 从 0 到 1，Fx.pop_land 拿它驱动整个过程。
static func bounce(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	if t < 0.35:
		return -18.0 * sin(t / 0.35 * PI * 0.5)
	if t < 0.55:
		return -18.0 * (1.0 - (t - 0.35) / 0.20)
	if t < 0.78:
		return -5.0 * sin((t - 0.55) / 0.23 * PI)
	return 0.0


## 四帧拼在一张图上，每帧 160×96：左半是田（三株作物，熟的那株偶尔亮一下），
## 右半是树（春天落花瓣），底下一颗图标演示落地弹跳。
## 画的是和游戏同一套规则的帧示意，不是游戏截图。
static func preview() -> Image:
	const FW := 160
	const FH := 96
	var img := Image.create(FW * 4, FH, false, Image.FORMAT_RGBA8)
	img.fill(Color("2d3944"))
	var soil := Color("7d5230")
	var leaf := Color("6fb44a")
	for frame in 4:
		var ox := frame * FW
		var time := frame * 0.75
		# 田
		for y in range(52, FH - 2):
			for x in range(ox + 2, ox + 78):
				img.set_pixel(x, y, soil if (x + y) % 9 < 7 else Color("6a4328"))
		for k in 3:
			var cx := ox + 14 + k * 22
			# 相位让第二格正好落在闪光那一下，四帧才看得出"偶尔闪"
			var flash := ripe_flash(time, 2.79) if k == 2 else 1.0
			var c: Color = Color(leaf.r * flash, leaf.g * flash, leaf.b * flash)
			for y in range(32, 53):
				for x in range(cx - 4, cx + 5):
					if (x + y) % 5 != 0:
						img.set_pixel(x, y, c)
			# 熟的那株挂个果子
			if k == 2:
				img.set_pixel(cx, 40, Color("f7d24a"))
				img.set_pixel(cx + 1, 40, Color("f7d24a"))
		# 树：椭圆树冠加一根树干，别画成绿色的方块
		for y in range(8, 36):
			for x in range(ox + 106, ox + 144):
				var dx := float(x - (ox + 125)) / 18.0
				var dy := float(y - 21) / 13.0
				if dx * dx + dy * dy <= 1.0:
					img.set_pixel(x, y, leaf.darkened(0.18))
		for y in range(30, 56):
			for x in range(ox + 123, ox + 127):
				img.set_pixel(x, y, Color("6a4328"))
		# 飘落的花瓣
		for i in 8:
			var p := fall_pos(i, time)
			var col := fall_color(&"petal")
			col.a = clampf(1.0 - p.y / FALL_HEIGHT, 0.2, 1.0)
			var px := clampi(ox + 108 + (i * 4) % 34 + int(p.x), ox + 82, ox + FW - 3)
			var py := clampi(30 + int(p.y), 2, FH - 3)
			img.set_pixel(px, py, col)
			img.set_pixel(px + 1, py, col)
		# 落地弹跳：四帧各取一个时刻
		var bt: float = [0.0, 0.35, 0.66, 1.0][frame]
		var by := 84 + int(bounce(bt))
		for dy in 3:
			for dx in 3:
				img.set_pixel(clampi(ox + 40 + dx, ox + 2, ox + FW - 3), clampi(by + dy, 2, FH - 3),
					Color("f7dc80"))
		for y in FH:
			img.set_pixel(ox + FW - 1, y, Color("1b232b"))
	return img
