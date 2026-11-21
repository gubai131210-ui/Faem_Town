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


## 大片同一种地的内部用铺好的噪声上色。整图每个像素都现算噪声，进一张大地图要一秒。
## 交界（岸、路沿、湿沙、石板边）仍按像素算，形状和原来一样。噪声图 256 像素一循环，一屏里至多一道接缝。
const STAMP := 256
static var _stamps: Dictionary = {}


## 返回 {"image": Image, "tbuf": PackedByteArray}。tbuf 是每个像素最后属于哪种地形，画水面闪光时要用。
## terrain 按行存，每格一个字节；season 是 0 春 … 3 冬。
static func paint(terrain: PackedByteArray, cols: int, rows: int, season: int) -> Dictionary:
	var pw := cols * TS
	var ph := rows * TS
	var built: Array = _build_tbuf(terrain, cols, rows, pw, ph)
	var tbuf: PackedByteArray = built[0]
	var quiet: PackedByteArray = built[1]
	var images: Dictionary = _stamp_images(season)
	var stamps: Dictionary = _stamp_set(season)
	var img := Image.create(pw, ph, false, Image.FORMAT_RGBA8)
	for ty in rows:
		for tx in cols:
			if quiet[ty * cols + tx] != 1:
				continue
			var stamp: Image = images[terrain[ty * cols + tx]]
			img.blit_rect(stamp, Rect2i((tx * TS) % STAMP, (ty * TS) % STAMP, TS, TS), Vector2i(tx * TS, ty * TS))
	var g_edge := _pack(Color.html(str(SEASON_GRASS[clampi(season, 0, 3)][5])))
	var g_d := _pack(Color.html(str(SEASON_GRASS[clampi(season, 0, 3)][2])))
	var d_d := _pack(Color.html("cc955b"))
	var d_shadow := _pack(Color.html("ae7845"))
	var w_d := _pack(Color.html("3d8cc8"))
	var w_shadow := _pack(Color.html("2f73ad"))
	var w_foam := _pack(Color.html("c4e9f6"))
	var bank_t := _pack(Color.html("a8743f"))
	var bank_m := _pack(Color.html("8a5a34"))
	var bank_d := _pack(Color.html("6a4328"))
	var p_shadow := _pack(Color.html("7c807e"))
	var s_d := _pack(Color.html("dcc68e"))
	var s_wet := _pack(Color.html("c9b488"))
	var s_wet_d := _pack(Color.html("b39c72"))
	var raw := img.get_data()
	for ty in rows:
		if not _row_has_edge(quiet, cols, ty):
			continue
		var y0 := ty * TS
		var y1 := mini(y0 + TS, ph)
		for py in range(y0, y1):
			var row := py * pw
			var up_row := (py - 1) * pw if py > 0 else row
			var up2_row := (py - 2) * pw if py > 1 else row
			var dn_row := (py + 1) * pw if py < ph - 1 else row
			for tx in cols:
				if quiet[ty * cols + tx] == 1:
					continue
				var x0 := tx * TS
				var x1 := mini(x0 + TS, pw)
				for px in range(x0, x1):
					var i := row + px
					var t := tbuf[i]
					var up := tbuf[up_row + px]
					var up2 := tbuf[up2_row + px]
					var dn := tbuf[dn_row + px]
					var lf := tbuf[i - 1] if px > 0 else t
					var rt := tbuf[i + 1] if px < pw - 1 else t
					var packed := -1
					if t == WATER:
						if up != WATER:
							packed = w_shadow
						elif up2 != WATER:
							packed = w_d
						elif dn != WATER or lf != WATER or rt != WATER:
							packed = w_foam
					else:
						var below := 0
						if dn == WATER:
							below = 1
						else:
							for k in range(2, 5):
								if py + k < ph and tbuf[i + pw * k] == WATER:
									below = k
									break
						if below > 0 and t == SAND:
							packed = s_wet_d if below <= 2 else s_wet
						elif below > 0:
							packed = bank_d if below == 1 else (bank_m if below < 4 else bank_t)
						elif t == SAND:
							if lf == WATER or rt == WATER or up == WATER:
								packed = s_wet
							elif up == GRASS:
								packed = s_d
						elif t == GRASS:
							if dn == DIRT or dn == PAVE or dn == SAND or lf == WATER or rt == WATER:
								packed = g_edge
							elif lf == DIRT or rt == DIRT or up == DIRT or lf == PAVE or rt == PAVE or up == PAVE \
									or lf == SAND or rt == SAND or up == SAND:
								packed = g_d
						elif t == PAVE:
							if up != PAVE:
								packed = p_shadow
						else:
							if up == GRASS:
								packed = d_shadow
							elif up2 == GRASS:
								packed = d_d
					var o := i * 4
					if packed < 0:
						var stamp: PackedByteArray = stamps[t]
						var so := ((py % STAMP) * STAMP + (px % STAMP)) * 3
						raw[o] = stamp[so]
						raw[o + 1] = stamp[so + 1]
						raw[o + 2] = stamp[so + 2]
					else:
						raw[o] = (packed >> 16) & 255
						raw[o + 1] = (packed >> 8) & 255
						raw[o + 2] = packed & 255
					raw[o + 3] = 255
	img = Image.create_from_data(pw, ph, false, Image.FORMAT_RGBA8, raw)
	return {"image": img, "tbuf": tbuf}


static func _row_has_edge(quiet: PackedByteArray, cols: int, ty: int) -> bool:
	var row := ty * cols
	for tx in cols:
		if quiet[row + tx] != 1:
			return true
	return false


static func _stamp_images(season: int) -> Dictionary:
	var key := clampi(season, 0, 3)
	if _stamp_images_cache.has(key):
		return _stamp_images_cache[key]
	var bytes: Dictionary = _stamp_set(key)
	var imgs := {}
	for t in [GRASS, DIRT, WATER, PAVE, SAND]:
		var src: PackedByteArray = bytes[t]
		var rgba := PackedByteArray()
		rgba.resize(STAMP * STAMP * 4)
		var n := STAMP * STAMP
		for i in n:
			var s := i * 3
			var o := i * 4
			rgba[o] = src[s]
			rgba[o + 1] = src[s + 1]
			rgba[o + 2] = src[s + 2]
			rgba[o + 3] = 255
		imgs[t] = Image.create_from_data(STAMP, STAMP, false, Image.FORMAT_RGBA8, rgba)
	_stamp_images_cache[key] = imgs
	return imgs


static var _stamp_images_cache: Dictionary = {}


static func _pack(c: Color) -> int:
	return (c.r8 << 16) | (c.g8 << 8) | c.b8


static func _build_tbuf(terrain: PackedByteArray, cols: int, rows: int, pw: int, ph: int) -> Array:
	var tbuf := PackedByteArray()
	tbuf.resize(pw * ph)
	var quiet := PackedByteArray()
	quiet.resize(cols * rows)
	for ty in rows:
		for tx in cols:
			var base := terrain[ty * cols + tx]
			var same := true
			for dy in range(-1, 2):
				var ny := clampi(ty + dy, 0, rows - 1)
				for dx in range(-1, 2):
					if terrain[ny * cols + clampi(tx + dx, 0, cols - 1)] != base:
						same = false
						break
				if not same:
					break
			if not same:
				continue
			quiet[ty * cols + tx] = 1
			var y0 := ty * TS
			var x0 := tx * TS
			for py in TS:
				var at := (y0 + py) * pw + x0
				for px in TS:
					tbuf[at + px] = base
	var n1 := FastNoiseLite.new()
	n1.seed = 7
	n1.noise_type = FastNoiseLite.TYPE_SIMPLEX
	n1.frequency = 0.09
	for ty in rows:
		var y0 := ty * TS
		var y1 := mini(y0 + TS, ph)
		for tx in cols:
			if quiet[ty * cols + tx] == 1:
				continue
			var x0 := tx * TS
			var x1 := mini(x0 + TS, pw)
			for py in range(y0, y1):
				var fy := (float(py) - 7.5) / 16.0
				var ty0 := floori(fy)
				var wy := fy - float(ty0)
				var r0 := clampi(ty0, 0, rows - 1) * cols
				var r1 := clampi(ty0 + 1, 0, rows - 1) * cols
				for px in range(x0, x1):
					var fx := (float(px) - 7.5) / 16.0
					var tx0 := floori(fx)
					var c0 := clampi(tx0, 0, cols - 1)
					var c1 := clampi(tx0 + 1, 0, cols - 1)
					var a := terrain[r0 + c0]
					var b := terrain[r0 + c1]
					var c := terrain[r1 + c0]
					var d := terrain[r1 + c1]
					var t := a
					if not (a == b and b == c and c == d):
						var wx := fx - float(tx0)
						var n := n1.get_noise_2d(px, py) * 0.17
						var fw := (float(a == WATER) * (1.0 - wx) + float(b == WATER) * wx) * (1.0 - wy) \
							+ (float(c == WATER) * (1.0 - wx) + float(d == WATER) * wx) * wy
						if fw + n > 0.5:
							t = WATER
						else:
							var fp := (float(a == PAVE) * (1.0 - wx) + float(b == PAVE) * wx) * (1.0 - wy) \
								+ (float(c == PAVE) * (1.0 - wx) + float(d == PAVE) * wx) * wy
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
	return [tbuf, quiet]


static func _stamp_set(season: int) -> Dictionary:
	var key := clampi(season, 0, 3)
	if _stamps.has(key):
		return _stamps[key]
	var n2 := FastNoiseLite.new()
	n2.seed = 21
	n2.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	# 决策 118：频率减半、只留一层，色块从碎斑变成成片的明暗，地面更干净。
	# 只动 stamp（一季算一次并缓存），不碰 _build_tbuf 的边缘算法，决策 117 的性能不变。
	n2.frequency = 0.026
	n2.fractal_octaves = 2
	var grass: Array = SEASON_GRASS[key]
	var set := {
		GRASS: _field_stamp(n2, grass, 0),
		DIRT: _field_stamp(n2, ["e6b780", "dba66b", "cc955b", "b98350", "e6b780"], 1),
		WATER: _field_stamp(n2, ["62b6e4", "4aa0d8", "3d8cc8", "4aa0d8", "4aa0d8"], 2),
		PAVE: _pave_stamp(key),
		SAND: _field_stamp(n2, ["f3e6bc", "e9d8a6", "dcc68e", "c4ab74", "f3e6bc"], 4),
	}
	_stamps[key] = set
	return set


## kind：0 草、1 泥、2 水、4 沙。字节序是连续的 r,g,b。
static func _field_stamp(n2: FastNoiseLite, hexes: Array, kind: int) -> PackedByteArray:
	var cols: Array[Color] = []
	for h in hexes:
		cols.append(Color.html(str(h)))
	var out := PackedByteArray()
	out.resize(STAMP * STAMP * 3)
	for py in STAMP:
		for px in STAMP:
			var col: Color = cols[1]
			var hsh := Px.h2(px, py) % 100
			if kind == WATER:
				var v := n2.get_noise_2d(px * 1.5, py * 3.0)
				if v > 0.25:
					col = cols[0]
				elif v < -0.25:
					col = cols[2]
			elif kind == GRASS:
				var v := n2.get_noise_2d(px, py)
				if v > 0.26:
					col = cols[0]
				elif v < -0.26:
					col = cols[2]
				# 决策 118：草叶点从约 4% 收到 1%，杂点从 1% 收到 0；不再逐像素撒亮点。
				if hsh < 1:
					col = cols[3]
			elif kind == SAND:
				var v := n2.get_noise_2d(px + 700.0, py * 1.6)
				if v > 0.22:
					col = cols[0]
				elif v < -0.25:
					col = cols[2]
				if hsh < 1:
					col = cols[3]
			else:
				var v := n2.get_noise_2d(px + 300.0, py)
				if v > 0.2:
					col = cols[0]
				elif v < -0.25:
					col = cols[2]
				if hsh < 1:
					col = cols[3]
			var o := (py * STAMP + px) * 3
			out[o] = col.r8
			out[o + 1] = col.g8
			out[o + 2] = col.b8
	return out


static func _pave_stamp(season: int) -> PackedByteArray:
	var tones: Array[Color] = [Color.html("c6c8c2"), Color.html("b8bbb6"), Color.html("aaaea9")]
	var joint := Color.html("8c908c") if season != 3 else Color.html("dfe6ea")
	var chip := Color.html("9a9e9a")
	var out := PackedByteArray()
	out.resize(STAMP * STAMP * 3)
	for py in STAMP:
		var row := py >> 3
		for px in STAMP:
			var sx := px + (8 if row % 2 == 1 else 0)
			var col := tones[Px.h2(sx >> 4, row) % 3]
			var hsh := Px.h2(px, py) % 100
			if py % 8 == 0 or sx % 16 == 0:
				col = joint
			elif hsh < 2:
				col = chip
			var o := (py * STAMP + px) * 3
			out[o] = col.r8
			out[o + 1] = col.g8
			out[o + 2] = col.b8
	return out
