class_name WildMap
extends OutdoorMap
## 大地图的基类（茶岭、藕花荡、古木林）：在室外地图上加高低地、密林、栈道和成片种树。
## 子类先排地形和高度，再调 _finish_relief()，之后才 _build_ground() 和摆东西。
##
## 高低地的规矩：每格一个高度。北边比自己高的那一格下面是崖面（挡路），高一级画一格高。
## 崖面上标了石阶的格子能走。高地的西、东、北三边挨着能走的低地时，高地那一格是崖沿（挡路）。
## 所以上下只能走石阶，不用在别处另外堵。

## 每格的高度，0 是谷底
var level := PackedByteArray()
## 0 不是崖面；否则是从崖沿往下数第几格
var face := PackedByteArray()
## 崖沿：位 1 北边低、2 西边低、4 东边低
var rim := PackedByteArray()
var stair := PackedByteArray()
var fall := PackedByteArray()
## 1 是进不去的密林
var woods := PackedByteArray()
## 架在水上的木板，人能走
var planks: Dictionary[Vector2i, bool] = {}
## 水里踩脚的石头，人能走
var stones: Dictionary[Vector2i, bool] = {}

var _kinds: Dictionary = {}
var _tree_tiles: Dictionary[Vector2i, bool] = {}
var _big_shadow: Texture2D


func _setup_wild(new_cols: int, new_rows: int) -> void:
	_setup_grid(new_cols, new_rows)
	var n := cols * rows
	level.resize(n)
	face.resize(n)
	rim.resize(n)
	stair.resize(n)
	fall.resize(n)
	woods.resize(n)
	_big_shadow = Px.tex(PixelArt.shadow(40, 11, 0.25))


# ---------------------------------------------------------------- 排地形

func _lv(t: Vector2i) -> int:
	return level[idx(t)] if in_map(t) else 0


func _raise(x0: int, y0: int, x1: int, y1: int, lv: int) -> void:
	for y in range(maxi(0, y0), mini(rows - 1, y1) + 1):
		for x in range(maxi(0, x0), mini(cols - 1, x1) + 1):
			level[y * cols + x] = lv


## 一团不规则的格子：椭圆的边按噪声进进出出。
func _blob(center: Vector2, rx: float, ry: float, wobble: float, seed_value: int) -> Array[Vector2i]:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.11
	var out: Array[Vector2i] = []
	for y in range(int(center.y - ry - 2), int(center.y + ry + 3)):
		for x in range(int(center.x - rx - 2), int(center.x + rx + 3)):
			var t := Vector2i(x, y)
			if not in_map(t):
				continue
			var p := Vector2((x + 0.5 - center.x) / rx, (y + 0.5 - center.y) / ry)
			if p.length() < 1.0 + noise.get_noise_2d(x, y) * wobble:
				out.append(t)
	return out


func _lake(center: Vector2, rx: float, ry: float, wobble: float, seed_value: int) -> void:
	for t in _blob(center, rx, ry, wobble, seed_value):
		_set_water(t)


## 沿着一串点铺一条路（或一条溪）。width 是几格宽。kind 是地形；WATER 的话挡路。
func _trail(points: Array, width: int, kind: int) -> void:
	for k in range(points.size() - 1):
		var a: Vector2i = points[k]
		var b: Vector2i = points[k + 1]
		var steps := maxi(absi(b.x - a.x), absi(b.y - a.y))
		for s in steps + 1:
			var f := s / float(maxi(steps, 1))
			var cx := int(roundf(lerpf(a.x, b.x, f)))
			var cy := int(roundf(lerpf(a.y, b.y, f)))
			for dy in width:
				for dx in width:
					var t := Vector2i(cx + dx - (width - 1) / 2, cy + dy - (width - 1) / 2)
					if not in_map(t):
						continue
					if kind == WATER:
						_set_water(t)
					else:
						terrain[idx(t)] = kind
						solid[idx(t)] = 0


## 和 _trail 一样铺路，碰到水不填：窄的架木板，use_stones 为真就摆踩脚石。
func _walk(points: Array, width: int, kind: int, use_stones: bool) -> void:
	for k in range(points.size() - 1):
		var a: Vector2i = points[k]
		var b: Vector2i = points[k + 1]
		var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
		for s in n + 1:
			var f := s / float(maxi(n, 1))
			var c := Vector2i(int(roundf(lerpf(a.x, b.x, f))), int(roundf(lerpf(a.y, b.y, f))))
			for dy in width:
				for dx in width:
					var t := c + Vector2i(dx, dy)
					if not in_map(t):
						continue
					if _is_water(t):
						if use_stones:
							_stone(t)
						else:
							_plank(t)
					elif not planks.has(t) and not stones.has(t):
						terrain[idx(t)] = kind


## 水上的一格木板。
func _plank(t: Vector2i) -> void:
	if not in_map(t):
		return
	_set_water(t)
	solid[idx(t)] = 0
	planks[t] = true
	occupied[t] = true


## 水里踩脚的石头。
func _stone(t: Vector2i) -> void:
	if not in_map(t):
		return
	_set_water(t)
	solid[idx(t)] = 0
	stones[t] = true
	occupied[t] = true


## 这几列上、从 y 往下数的崖面改成石阶。要在 _finish_relief() 之前调。
func _steps(x0: int, x1: int, y: int) -> void:
	for x in range(x0, x1 + 1):
		for dy in range(-1, 4):
			var t := Vector2i(x, y + dy)
			if in_map(t):
				stair[idx(t)] = 2


## 地图四边往里长一圈密林，深浅按噪声变。gaps 里的格子不长（出入口）。
func _fringe(depth: int, extra: int, seed_value: int, gaps: Array[Rect2i] = []) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.07
	for y in rows:
		for x in cols:
			var t := Vector2i(x, y)
			var edge := mini(mini(x, y), mini(cols - 1 - x, rows - 1 - y))
			var reach := depth + int((noise.get_noise_2d(x * 1.0, y * 1.0) * 0.5 + 0.5) * extra)
			if edge >= reach:
				continue
			var skip := false
			for g in gaps:
				if g.has_point(t):
					skip = true
					break
			if not skip:
				woods[idx(t)] = 1


func _wood_rect(x0: int, y0: int, x1: int, y1: int) -> void:
	for y in range(maxi(0, y0), mini(rows - 1, y1) + 1):
		for x in range(maxi(0, x0), mini(cols - 1, x1) + 1):
			woods[y * cols + x] = 1


## 算出崖面、崖沿、瀑布，把该挡的格子挡上。地形和高度都排好以后调一次。
func _finish_relief() -> void:
	var src := PackedByteArray()
	src.resize(cols * rows)
	for y in rows:
		for x in cols:
			var i := y * cols + x
			src[i] = level[i]
			if y == 0:
				continue
			var up := i - cols
			var top := src[up] if face[up] > 0 else level[up]
			var d := face[up] + 1
			if top - level[i] >= d:
				face[i] = d
				src[i] = top
	for y in rows:
		for x in cols:
			var i := y * cols + x
			var t := Vector2i(x, y)
			if face[i] > 0:
				# 石阶只在崖面上算数
				stair[i] = 1 if stair[i] == 2 else 0
				var edge := Vector2i(x, y - face[i])
				if stair[i] == 0 and in_map(edge) and terrain[idx(edge)] == WATER:
					fall[i] = 1
				if stair[i] == 1:
					solid[i] = 0
					if terrain[i] == WATER:
						terrain[i] = GRASS
				else:
					solid[i] = 1
				occupied[t] = true
				continue
			stair[i] = 0
			if terrain[i] == WATER:
				continue
			var bits := 0
			var block := false
			if y > 0 and face[i - cols] == 0 and level[i - cols] < level[i]:
				bits |= 1
				block = true
			if x > 0 and level[i - 1] < level[i]:
				bits |= 2
				if face[i - 1] == 0:
					block = true
			if x < cols - 1 and level[i + 1] < level[i]:
				bits |= 4
				if face[i + 1] == 0:
					block = true
			rim[i] = bits
			if block:
				solid[i] = 1
				occupied[t] = true


## 把高低地画出来，盖在地面上。_build_ground() 之后调。
func _add_relief(style: int) -> void:
	var img := WildArt.relief(cols, rows, face, rim, stair, fall, _season, style)
	var spr := Sprite2D.new()
	spr.centered = false
	spr.texture = Px.tex(img)
	spr.z_index = -9
	add_child(spr)


## 密林的地面盖一层暗，林子里密密种上树。_make_entities() 之后调。
func _add_woods(kinds: Array[String]) -> void:
	var shade := Sprite2D.new()
	shade.centered = false
	shade.texture = Px.tex(WildArt.floor_shade(woods, cols, rows, _season))
	shade.z_index = -9
	add_child(shade)
	for y in rows:
		for x in cols:
			var t := Vector2i(x, y)
			if woods[idx(t)] != 1:
				continue
			if terrain[idx(t)] == WATER or face[idx(t)] > 0:
				continue
			_block(t)
			var odd := (y / 2) % 2
			if y % 2 != 0 or (x + odd) % 2 != 0:
				continue
			var roll := Px.h2(x * 3 + 1, y * 5 + 2)
			if roll % 9 == 0:
				continue
			_tree_sprite(kinds[roll % kinds.size()], t, roll)


## 摆水上的木板和踩脚石。_build_ground() 之后调。
func _add_planks() -> void:
	var post := Px.tex(PixelArt.dock_post())
	for t: Vector2i in planks:
		var m := 0
		if planks.has(t + Vector2i(0, -1)) or not _is_water(t + Vector2i(0, -1)):
			m |= 1
		if planks.has(t + Vector2i(1, 0)) or not _is_water(t + Vector2i(1, 0)):
			m |= 2
		if planks.has(t + Vector2i(0, 1)) or not _is_water(t + Vector2i(0, 1)):
			m |= 4
		if planks.has(t + Vector2i(-1, 0)) or not _is_water(t + Vector2i(-1, 0)):
			m |= 8
		var plank := Sprite2D.new()
		plank.texture = _plank_tex(m)
		plank.centered = false
		plank.position = Vector2(t.x * TS, t.y * TS)
		plank.z_index = -7
		add_child(plank)
		# 朝南露在水上的一边立两根桩
		if m & 4 == 0 and (t.x + t.y) % 2 == 0:
			var p := Sprite2D.new()
			p.texture = post
			p.centered = false
			p.position = Vector2(t.x * TS + 2, t.y * TS + 13)
			p.z_index = -7
			add_child(p)
	var kinds: Array[Texture2D] = [Px.tex(WildArt.stepping(0)), Px.tex(WildArt.stepping(1))]
	for t: Vector2i in stones:
		var s := Sprite2D.new()
		s.texture = kinds[(t.x + t.y) % 2]
		s.centered = false
		s.position = Vector2(t.x * TS + 1, t.y * TS + 4)
		s.z_index = -7
		add_child(s)


var _plank_cache: Dictionary[int, Texture2D] = {}


func _plank_tex(mask: int) -> Texture2D:
	if not _plank_cache.has(mask):
		_plank_cache[mask] = Px.tex(PixelArt.dock_tile(mask))
	return _plank_cache[mask]


# ---------------------------------------------------------------- 树

## 树的种类：old0–2 老树，pine0–1 松，willow0–1 柳，round0–2 圆冠树，plum0–1 梅。
## 返回 [贴图, 锚点偏移, 影子]。
func _kind(kind: String) -> Array:
	if _kinds.has(kind):
		return _kinds[kind]
	var v := int(kind.right(1))
	var entry: Array = []
	if kind.begins_with("old"):
		entry = [Px.tex(WildArt.old_tree(v, _season)), Vector2(-32, -77), _big_shadow]
	elif kind.begins_with("pine"):
		entry = [Px.tex(WildArt.pine(v, _season)), Vector2(-18, -69), _tree_shadow]
	elif kind.begins_with("willow"):
		entry = [Px.tex(WildArt.willow(v, _season)), Vector2(-30, -65), _big_shadow]
	elif kind.begins_with("plum"):
		entry = [Px.tex(PixelArt.plum_tree(v, _season)), Vector2(-24, -57), _tree_shadow]
	else:
		entry = [Px.tex(PixelArt.round_tree(v, _season)), Vector2(-22, -57), _tree_shadow]
	_kinds[kind] = entry
	return entry


func _tree_sprite(kind: String, t: Vector2i, roll: int) -> Sprite2D:
	var entry := _kind(kind)
	var pos := Vector2(t.x * TS + 8 + (roll % 5) - 2, t.y * TS + 14 - (roll / 7) % 3)
	var s := _sprite(entry[0], pos, entry[1])
	s.material = _tree_mat
	_ground_shadow(pos + Vector2(0, -1), entry[2])
	return s


## 在这一格种一棵树，挡路。
func _tree(kind: String, t: Vector2i) -> void:
	if not in_map(t):
		return
	_tree_sprite(kind, t, Px.h2(t.x, t.y))
	_block(t)
	_tree_tiles[t] = true


## 一片能走进去的林子：范围里的空草地按 chance（百分比）种树，树和树之间至少隔一格。
func _grove(area: Rect2i, chance: int, kinds: Array[String], margin: int = 1) -> void:
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var t := Vector2i(x, y)
			if not _is_free(t) or _keep_clear(t, margin) or _no_scatter(t):
				continue
			var roll := Px.h2(x * 7 + 3, y * 11 + 5)
			if roll % 100 >= chance:
				continue
			var near := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if _tree_tiles.has(t + Vector2i(dx, dy)):
						near = true
			if near:
				continue
			_tree(kinds[(roll / 100) % kinds.size()], t)


## 撒不挡路的小东西（蕨、蘑菇）。make 返回一张贴图；记在 decor 里。
func _sprinkle(area: Rect2i, chance: int, textures: Array[Texture2D], salt: int, mat: Material = null) -> void:
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var t := Vector2i(x, y)
			if not in_map(t) or terrain[idx(t)] != GRASS or solid[idx(t)] == 1 or occupied.has(t):
				continue
			var roll := Px.h2(x * 13 + salt, y * 17 + salt * 3)
			if roll % 1000 >= chance:
				continue
			var tex: Texture2D = textures[(roll / 1000) % textures.size()]
			var pos := Vector2(t.x * TS + 4 + roll % 9, t.y * TS + 8 + (roll / 9) % 7)
			var s := _sprite(tex, pos, Vector2(-tex.get_width() / 2.0, -float(tex.get_height())))
			s.material = mat
			if not decor.has(t):
				decor[t] = []
			var list: Array = decor[t]
			list.append(s)


## 放一个挡路的小件（树桩、倒木、石头），占 w 格宽。
func _thing(tex: Texture2D, t: Vector2i, w: int = 1) -> Sprite2D:
	var pos := Vector2(t.x * TS + w * TS / 2.0, t.y * TS + 14)
	var s := _sprite(tex, pos, Vector2(-tex.get_width() / 2.0, -float(tex.get_height())))
	for k in w:
		_block(t + Vector2i(k, 0))
	return s


## 放一栋 Blender 画的房子，和镇上一个摆法：x0 是最西一列，front 是正面墙脚下面那一行，占 w 格宽；
## 正面往北的 d 行挡路。傍晚门口亮一盏灯。
func _building(prop: String, x0: int, front: int, w: int, d: int, lit: bool = true) -> Sprite2D:
	var pos := Vector2((x0 + w / 2.0) * TS, front * TS)
	var s := _prop(prop, pos)
	_block_rect(x0, front - d, x0 + w - 1, front - 1)
	_ground_shadow(pos + Vector2(0, -1), Px.tex(PixelArt.shadow(w * TS - 8, 10, 0.22)))
	if lit:
		_add_night_light(pos + Vector2(0, -22), 1.5)
	return s


## 能看的东西：格子 → 一句话。子类在摆东西时往里填，query_use / perform 用 _clue_use() 接上。
var clues: Dictionary[Vector2i, String] = {}


func _clue(t: Vector2i, text: String) -> void:
	clues[t] = text


func clue_at(tile: Vector2i) -> String:
	return clues.get(tile, "")


# ---------------------------------------------------------------- 往东南扩大的地图

## 新长出来的三条边（老地图那一块不算）围一圈树，和老地图的边界一个意思。出入口先 _reserve 好，空草地才种。
func _new_edge_trees(old_cols: int, old_rows: int, kinds: Array[String]) -> void:
	for y in rows:
		for x in cols:
			if x < old_cols and y < old_rows:
				continue
			if mini(mini(x, y), mini(cols - 1 - x, rows - 1 - y)) >= 2:
				continue
			if (x + y) % 2 != 0 or Px.h2(x * 3 + 1, y * 5 + 2) % 10 >= 8:
				continue
			var t := Vector2i(x, y)
			if _is_free(t):
				_tree(kinds[Px.h2(x + 7, y + 3) % kinds.size()], t)


## 新长出来的地方撒草丛和小花，不挡路。花春夏多，秋天少，冬天没有。
func _sprinkle_grass(area: Rect2i, salt: int) -> void:
	var tuft := Px.tex(PixelArt.tuft(_season))
	var kinds: Array[Texture2D] = [tuft, tuft, tuft, tuft]
	for i in ([4, 4, 1, 0][_season] as int):
		kinds.append(Px.tex(PixelArt.flower(i % 4)))
	_sprinkle(area, 140, kinds, salt, _tuft_mat)


## 一格大的小件（缸、罐、稻草人、石灯），挡路。text 不空就能看。
func _small_prop(prop: String, t: Vector2i, text: String = "") -> void:
	var pos := tile_center(t) + Vector2(0, 6)
	_prop(prop, pos)
	_ground_shadow(pos + Vector2(0, -1), _small_shadow)
	_block(t)
	if text != "":
		_clue(t, text)


## 占 w 格宽、一格深的小件（晒匾、柴垛、长凳），挡路。text 不空就能看。
func _wide_prop(prop: String, t: Vector2i, w: int, text: String = "") -> void:
	var s := _thing(PropArt.texture(prop), t, w)
	s.offset = -PropArt.anchor(prop)
	_ground_shadow(s.position + Vector2(0, -1), Px.tex(PixelArt.shadow(w * TS - 6, 5, 0.2)))
	if text != "":
		for k in w:
			_clue(t + Vector2i(k, 0), text)


## 一栋房子正面那一排墙：正中的格子（偶数宽两格都算）按使用键说一句话。
func _wall_clue(x0: int, front: int, w: int, text: String) -> void:
	_clue(Vector2i(x0 + w / 2, front - 1), text)
	if w % 2 == 0:
		_clue(Vector2i(x0 + w / 2 - 1, front - 1), text)


## 路边的石灯，傍晚亮。
func _lamp_post(t: Vector2i) -> void:
	var pos := tile_center(t) + Vector2(0, 6)
	_prop("stone_lamp", pos)
	_ground_shadow(pos + Vector2(0, -1), Px.tex(PixelArt.shadow(16, 5, 0.22)))
	_block(t)
	_add_night_light(pos + Vector2(0, -16), 1.8)
