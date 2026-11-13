class_name GroundArt
extends RefCounted
## 室外地图的地面：把一张按格子记的地形表画成整张贴图，草、泥、石板、沙、水之间的边缘自然弯曲。

const GRASS := 0
const DIRT := 1
const WATER := 2
## 镇上铺的石板
const PAVE := 3
## 海边的沙滩：四季一个颜色，挨着水的一圈是湿沙
const SAND := 4
const TS := 16

## 四季的草地颜色：[亮, 中, 暗, 草叶, 杂点, 和泥地交界]
const SEASON_GRASS: Array = [
	["93cc58", "80bd4e", "6dab45", "a9da68", "5d9a3f", "4f8a3a"],
	["86c450", "72b446", "5fa23e", "9cd25e", "4f8f38", "458236"],
	["cfc862", "bab552", "a3a047", "e0d878", "8c8a3e", "7c7a38"],
	["f1f5f8", "e3ebf1", "d1dde7", "ffffff", "b9c9d5", "a7b8c6"],
]


## 返回 {"image": Image, "tbuf": PackedByteArray}。tbuf 是每个像素最后属于哪种地形，画水面闪光时要用。
## terrain 按行存，每格一个字节；season 是 0 春 … 3 冬。
static func paint(terrain: PackedByteArray, cols: int, rows: int, season: int) -> Dictionary:
	var pw := cols * TS
	var ph := rows * TS
	var tbuf := PackedByteArray()
	tbuf.resize(pw * ph)
	var n1 := FastNoiseLite.new()
	n1.seed = 7
	n1.noise_type = FastNoiseLite.TYPE_SIMPLEX
	n1.frequency = 0.09
	var n2 := FastNoiseLite.new()
	n2.seed = 21
	n2.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n2.frequency = 0.035
	n2.fractal_octaves = 2

	# 第一遍：按相邻格子做双线性插值再加噪声，决定每个像素属于哪种地形，边缘自然弯曲。
	for py in ph:
		var fy := (py - 7.5) / 16.0
		var ty0 := floori(fy)
		var wy := fy - ty0
		var r0 := clampi(ty0, 0, rows - 1) * cols
		var r1 := clampi(ty0 + 1, 0, rows - 1) * cols
		for px in pw:
			var fx := (px - 7.5) / 16.0
			var tx0 := floori(fx)
			var c0 := clampi(tx0, 0, cols - 1)
			var c1 := clampi(tx0 + 1, 0, cols - 1)
			var a := terrain[r0 + c0]
			var b := terrain[r0 + c1]
			var c := terrain[r1 + c0]
			var d := terrain[r1 + c1]
			var t := a
			if not (a == b and b == c and c == d):
				var wx := fx - tx0
				var n := n1.get_noise_2d(px, py) * 0.17
				var fw := (float(a == WATER) * (1.0 - wx) + float(b == WATER) * wx) * (1.0 - wy) \
					+ (float(c == WATER) * (1.0 - wx) + float(d == WATER) * wx) * wy
				if fw + n > 0.5:
					t = WATER
				else:
					var fp := (float(a == PAVE) * (1.0 - wx) + float(b == PAVE) * wx) * (1.0 - wy) \
						+ (float(c == PAVE) * (1.0 - wx) + float(d == PAVE) * wx) * wy
					# 石板的边比泥地整齐，噪声减半
					if fp + n * 0.5 > 0.5:
						t = PAVE
					else:
						var fd := (float(a == DIRT) * (1.0 - wx) + float(b == DIRT) * wx) * (1.0 - wy) \
							+ (float(c == DIRT) * (1.0 - wx) + float(d == DIRT) * wx) * wy
						if fd + n > 0.5:
							t = DIRT
						else:
							var fs := (float(a == SAND) * (1.0 - wx) + float(b == SAND) * wx) * (1.0 - wy) \
								+ (float(c == SAND) * (1.0 - wx) + float(d == SAND) * wx) * wy
							var no_grass := a != GRASS and b != GRASS and c != GRASS and d != GRASS
							t = SAND if fs + n > 0.5 or (fs > 0.0 and no_grass) else GRASS
			tbuf[py * pw + px] = t

	# 第二遍：上色，并在地形交界处加阴影、河岸和水边高光。
	var grass: Array = SEASON_GRASS[clampi(season, 0, 3)]
	var g_l := Color.html(str(grass[0]))
	var g_m := Color.html(str(grass[1]))
	var g_d := Color.html(str(grass[2]))
	var g_blade := Color.html(str(grass[3]))
	var g_speck := Color.html(str(grass[4]))
	var g_edge := Color.html(str(grass[5]))
	var d_l := Color.html("e6b780")
	var d_m := Color.html("dba66b")
	var d_d := Color.html("cc955b")
	var d_peb := Color.html("b98350")
	var d_shadow := Color.html("ae7845")
	var w_l := Color.html("62b6e4")
	var w_m := Color.html("4aa0d8")
	var w_d := Color.html("3d8cc8")
	var w_shadow := Color.html("2f73ad")
	var w_foam := Color.html("c4e9f6")
	var bank_t := Color.html("a8743f")
	var bank_m := Color.html("8a5a34")
	var bank_d := Color.html("6a4328")
	# 石板：三种深浅的板，板缝更暗；冬天缝里积一点雪
	var p_tones: Array[Color] = [Color.html("c6c8c2"), Color.html("b8bbb6"), Color.html("aaaea9")]
	var p_joint := Color.html("8c908c") if season != 3 else Color.html("dfe6ea")
	var p_chip := Color.html("9a9e9a")
	var p_shadow := Color.html("7c807e")
	var s_l := Color.html("f3e6bc")
	var s_m := Color.html("e9d8a6")
	var s_d := Color.html("dcc68e")
	var s_speck := Color.html("c4ab74")
	var s_wet := Color.html("c9b488")
	var s_wet_d := Color.html("b39c72")
	var data := PackedByteArray()
	data.resize(pw * ph * 4)
	for py in ph:
		for px in pw:
			var i := py * pw + px
			var t := tbuf[i]
			var col := g_m
			var up := tbuf[i - pw] if py > 0 else t
			var up2 := tbuf[i - pw * 2] if py > 1 else t
			var dn := tbuf[i + pw] if py < ph - 1 else t
			var lf := tbuf[i - 1] if px > 0 else t
			var rt := tbuf[i + 1] if px < pw - 1 else t
			var hsh := Px.h2(px, py) % 100
			if t == WATER:
				var v := n2.get_noise_2d(px * 1.5, py * 3.0)
				col = w_m
				if v > 0.25:
					col = w_l
				elif v < -0.25:
					col = w_d
				if up != WATER:
					col = w_shadow
				elif up2 != WATER:
					col = w_d
				elif dn != WATER or lf != WATER or rt != WATER:
					col = w_foam
			else:
				var below := 0
				for k in range(1, 5):
					if py + k < ph and tbuf[i + pw * k] == WATER:
						below = k
						break
				if below > 0 and t == SAND:
					# 沙滩没有土坎，水边是一条被浪打湿的沙
					col = s_wet_d if below <= 2 else s_wet
				elif below > 0:
					col = bank_d if below == 1 else (bank_m if below < 4 else bank_t)
				elif t == SAND:
					var v := n2.get_noise_2d(px + 700.0, py * 1.6)
					col = s_m
					if v > 0.22:
						col = s_l
					elif v < -0.28:
						col = s_d
					if hsh < 1:
						col = s_speck
					elif hsh > 98:
						col = s_l
					if lf == WATER or rt == WATER or up == WATER:
						col = s_wet
					elif up == GRASS:
						col = s_d
				elif t == GRASS:
					var v := n2.get_noise_2d(px, py)
					col = g_m
					if v > 0.22:
						col = g_l
					elif v < -0.25:
						col = g_d
					if hsh < 2 or Px.h2(px, py + 1) % 100 < 2:
						col = g_blade
					elif hsh > 98:
						col = g_speck
					if dn == DIRT or dn == PAVE or dn == SAND:
						col = g_edge
					elif lf == DIRT or rt == DIRT or up == DIRT or lf == PAVE or rt == PAVE or up == PAVE \
							or lf == SAND or rt == SAND or up == SAND:
						col = g_d
					elif lf == WATER or rt == WATER:
						col = g_edge
				elif t == PAVE:
					# 错缝铺的石板，每块 16×8
					var row := py >> 3
					var sx := px + (8 if row % 2 == 1 else 0)
					col = p_tones[Px.h2(sx >> 4, row) % 3]
					if py % 8 == 0 or sx % 16 == 0:
						col = p_joint
					elif hsh < 2:
						col = p_chip
					if up != PAVE:
						col = p_shadow
				else:
					var v := n2.get_noise_2d(px + 300.0, py)
					col = d_m
					if v > 0.2:
						col = d_l
					elif v < -0.25:
						col = d_d
					if hsh < 1:
						col = d_peb
					elif hsh > 98:
						col = d_l
					if up == GRASS:
						col = d_shadow
					elif up2 == GRASS:
						col = d_d
			var o := i * 4
			data[o] = col.r8
			data[o + 1] = col.g8
			data[o + 2] = col.b8
			data[o + 3] = 255
	return {"image": Image.create_from_data(pw, ph, false, Image.FORMAT_RGBA8, data), "tbuf": tbuf}
