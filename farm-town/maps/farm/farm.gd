extends GameMap
## 农场地图：程序生成的地形和物件，耕地由 FarmView 显示。

const W := 40
const H := 26
const GRASS := 0
const DIRT := 1
const WATER := 2
const HOUSE_POS := Vector2(128, 112)
const DOOR_TILES: Array[Vector2i] = [Vector2i(7, 6), Vector2i(8, 6)]
const MAILBOX_TILE := Vector2i(10, 7)
const START_TILE := Vector2i(8, 8)
const INTRO_DIALOGUE := "res://dialogue/intro.dialogue"

const SWAY_SHADER := """
shader_type canvas_item;
uniform float still_from = 0.7;
uniform float amp = 1.6;
varying float ph;
void vertex() {
	ph = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).x * 0.07;
}
void fragment() {
	float k = clamp((still_from - UV.y) / still_from, 0.0, 1.0);
	float off = (sin(TIME * 1.3 + ph) + 0.4 * sin(TIME * 2.9 + ph * 2.0)) * k * amp;
	vec2 uv = UV + vec2(round(off) * TEXTURE_PIXEL_SIZE.x, 0.0);
	COLOR = texture(TEXTURE, uv) * COLOR;
}
"""

var terrain := PackedByteArray()
var solid := PackedByteArray()
var tbuf := PackedByteArray()
## 草丛和小花，按格子记录，开垦时清掉
var decor: Dictionary = {}
var occupied: Dictionary = {}
var water_fx: Node2D

var _farm_view: FarmView
var _lights: Array[PointLight2D] = []
var _sparkles: Array = []
var _fx_t := 0.0
var _time := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	map_id = &"farm"
	_rng.seed = 20261111
	terrain.resize(W * H)
	solid.resize(W * H)
	_layout()
	var ground := Sprite2D.new()
	ground.centered = false
	ground.texture = Px.tex(_gen_ground())
	ground.z_index = -10
	add_child(ground)

	_farm_view = FarmView.new()
	_farm_view.z_index = -9
	add_child(_farm_view)

	water_fx = Node2D.new()
	water_fx.z_index = -8
	water_fx.draw.connect(_draw_water)
	add_child(water_fx)

	entities = Node2D.new()
	entities.y_sort_enabled = true
	add_child(entities)
	_farm_view.setup(Farming.state, entities)
	_place_objects()
	for t: Vector2i in Farming.state.soil:
		_clear_decor(t)
	_make_sparkles()
	_make_lights()


func _process(delta: float) -> void:
	_time += delta
	_fx_t += delta
	if _fx_t > 0.12:
		_fx_t = 0.0
		water_fx.queue_redraw()
	var night := clampf((GameClock.minutes - 1080.0) / 150.0, 0.0, 1.0)
	for l in _lights:
		l.energy = night * 0.9


func size_px() -> Vector2i:
	return Vector2i(W * TS, H * TS)


func spawn_position(spawn: StringName) -> Vector2:
	if spawn == &"house_door":
		return Vector2(HOUSE_POS.x, 7 * TS + 6)
	return tile_center(START_TILE)


func spawn_facing(_spawn: StringName) -> Facing:
	return Facing.DOWN


func blocked(p: Vector2) -> bool:
	for c: Vector2 in [Vector2(-4, -4), Vector2(4, -4), Vector2(-4, 1), Vector2(4, 1)]:
		var t := tile_of(p + c)
		if not in_map(t) or solid[idx(t)] == 1:
			return true
	return false


func query_use(item: ItemDef, tile: Vector2i, facing: Facing) -> StringName:
	if facing == Facing.UP and DOOR_TILES.has(tile):
		return &"interact"
	if tile == MAILBOX_TILE:
		return &"interact"
	var farm := Farming.state
	if farm.is_ripe(tile):
		return &"harvest"
	if item == null:
		return &""
	if item.id == &"hoe":
		return &"hoe"
	if item.id == &"watering_can":
		return &"water"
	if item.kind == &"seed" and farm.can_plant(tile):
		return &"plant"
	return &""


func perform(action: StringName, item: ItemDef, tile: Vector2i) -> void:
	var farm := Farming.state
	var c := tile_center(tile)
	match action:
		&"interact":
			if tile == MAILBOX_TILE:
				EventBus.dialogue_requested.emit(INTRO_DIALOGUE, "letter")
			else:
				SceneRouter.travel(&"farmhouse", &"door")
		&"hoe":
			Audio.play("hoe")
			if _can_till(tile) and farm.till(tile):
				_clear_decor(tile)
				Fx.burst(self, c, Color("9a6a40"), 10, 70.0)
				EventBus.screen_shake_requested.emit(1.5)
			else:
				Fx.burst(self, c, Color("c9a074"), 4, 45.0)
		&"water":
			Audio.play("water")
			Fx.burst(self, c + Vector2(0, -8), Color("8fd0ee"), 14, 30.0, 0.45, 220.0)
			farm.water(tile)
		&"plant":
			if item != null and farm.plant(tile, item.crop):
				GameState.inventory.remove(item.id, 1)
				Audio.play("plant")
		&"harvest":
			var crop_id := farm.crop_id_at(tile)
			if crop_id == &"":
				return
			var produce := Database.crop(crop_id).produce
			if not GameState.inventory.can_add(produce, 1):
				EventBus.banner_requested.emit("背包满了")
				Audio.play("deny", 0.0, -4.0)
				return
			farm.harvest(tile)
			GameState.inventory.add(produce, 1)
			Audio.play("harvest", 0.0)
			Fx.burst(self, c, Color("7cc74f"), 6, 50.0)
			Fx.pop_icon(self, c + Vector2(0, -6), Px.tex(PixelArt.icon(Database.item(produce).icon)))


func _can_till(t: Vector2i) -> bool:
	if not in_map(t) or occupied.has(t):
		return false
	# 房子前面那一排留作通道，不让开垦
	return terrain[idx(t)] != WATER and solid[idx(t)] == 0 and t.y > 6


func _clear_decor(t: Vector2i) -> void:
	if not decor.has(t):
		return
	var list: Array = decor[t]
	for n: Node in list:
		n.queue_free()
	decor.erase(t)


func _make_lights() -> void:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([Color.WHITE, Color.BLACK])
	var light_tex := GradientTexture2D.new()
	light_tex.gradient = grad
	light_tex.width = 64
	light_tex.height = 64
	light_tex.fill = GradientTexture2D.FILL_RADIAL
	light_tex.fill_from = Vector2(0.5, 0.5)
	light_tex.fill_to = Vector2(1.0, 0.5)
	for off: Vector2 in [Vector2(-24, -20), Vector2(26, -20)]:
		var l := PointLight2D.new()
		l.texture = light_tex
		l.texture_scale = 1.3
		l.color = Color(1.0, 0.82, 0.5)
		l.position = HOUSE_POS + off
		l.energy = 0.0
		add_child(l)
		_lights.append(l)


# ---------------------------------------------------------------- 布局

func idx(t: Vector2i) -> int:
	return t.y * W + t.x


func in_map(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < W and t.y < H


func _fill(x0: int, y0: int, x1: int, y1: int, v: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			terrain[y * W + x] = v


func _layout() -> void:
	_fill(15, 9, 26, 16, DIRT)
	_fill(7, 7, 8, 12, DIRT)
	_fill(7, 11, 14, 12, DIRT)
	_fill(27, 11, 29, 12, DIRT)
	for y in H:
		for x in W:
			var dx := (x - 33.0) / 4.3
			var dy := (y - 17.5) / 3.3
			if dx * dx + dy * dy <= 1.0:
				terrain[y * W + x] = WATER
				solid[y * W + x] = 1


func _t(x: int, y: int) -> int:
	return terrain[clampi(y, 0, H - 1) * W + clampi(x, 0, W - 1)]


func _gen_ground() -> Image:
	var pw := W * TS
	var ph := H * TS
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
		for px in pw:
			var fx := (px - 7.5) / 16.0
			var tx0 := floori(fx)
			var a := _t(tx0, ty0)
			var b := _t(tx0 + 1, ty0)
			var c := _t(tx0, ty0 + 1)
			var d := _t(tx0 + 1, ty0 + 1)
			var t := a
			if not (a == b and b == c and c == d):
				var wx := fx - tx0
				var n := n1.get_noise_2d(px, py) * 0.17
				var fw := (float(a == WATER) * (1.0 - wx) + float(b == WATER) * wx) * (1.0 - wy) \
					+ (float(c == WATER) * (1.0 - wx) + float(d == WATER) * wx) * wy
				if fw + n > 0.5:
					t = WATER
				else:
					var fd := (float(a == DIRT) * (1.0 - wx) + float(b == DIRT) * wx) * (1.0 - wy) \
						+ (float(c == DIRT) * (1.0 - wx) + float(d == DIRT) * wx) * wy
					t = DIRT if fd + n > 0.5 else GRASS
			tbuf[py * pw + px] = t

	# 第二遍：上色，并在地形交界处加阴影、河岸和水边高光。
	var g_l := Color.html("93cc58")
	var g_m := Color.html("80bd4e")
	var g_d := Color.html("6dab45")
	var g_blade := Color.html("a9da68")
	var g_speck := Color.html("5d9a3f")
	var g_edge := Color.html("4f8a3a")
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
				if below > 0:
					col = bank_d if below == 1 else (bank_m if below < 4 else bank_t)
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
					if dn == DIRT:
						col = g_edge
					elif lf == DIRT or rt == DIRT or up == DIRT:
						col = g_d
					elif lf == WATER or rt == WATER:
						col = g_edge
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
	return Image.create_from_data(pw, ph, false, Image.FORMAT_RGBA8, data)


func _sprite(tex: Texture2D, pos: Vector2, offset: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.offset = offset
	s.position = pos
	entities.add_child(s)
	return s


func _ground_shadow(pos: Vector2, tex: Texture2D) -> void:
	var s := Sprite2D.new()
	s.texture = tex
	s.position = pos
	s.z_index = -6
	add_child(s)


func _block(t: Vector2i) -> void:
	solid[idx(t)] = 1
	occupied[t] = true


func _is_free(t: Vector2i) -> bool:
	return in_map(t) and terrain[idx(t)] == GRASS and solid[idx(t)] == 0 and not occupied.has(t)


func _place_objects() -> void:
	var sway := Shader.new()
	sway.code = SWAY_SHADER
	var tree_mat := ShaderMaterial.new()
	tree_mat.shader = sway
	tree_mat.set_shader_parameter("still_from", 0.68)
	tree_mat.set_shader_parameter("amp", 1.5)
	var tuft_mat := ShaderMaterial.new()
	tuft_mat.shader = sway
	tuft_mat.set_shader_parameter("still_from", 1.0)
	tuft_mat.set_shader_parameter("amp", 1.2)

	# 房子
	var house := _sprite(Px.tex(PixelArt.house()), HOUSE_POS, Vector2(-48, -84))
	house.name = "House"
	for y in range(3, 7):
		for x in range(5, 11):
			_block(Vector2i(x, y))
	_ground_shadow(HOUSE_POS + Vector2(0, -1), Px.tex(PixelArt.shadow(100, 10, 0.22)))

	# 信箱
	var box_pos := tile_center(MAILBOX_TILE) + Vector2(0, 6)
	_sprite(Px.tex(PixelArt.mailbox()), box_pos, Vector2(-6, -18))
	_ground_shadow(box_pos + Vector2(0, -1), Px.tex(PixelArt.shadow(12, 4, 0.22)))
	_block(MAILBOX_TILE)

	# 栅栏：围住田地，左侧对着小路留一个口
	var fence_tiles: Dictionary = {}
	for x in range(14, 28):
		fence_tiles[Vector2i(x, 8)] = true
		fence_tiles[Vector2i(x, 17)] = true
	for y in range(8, 18):
		fence_tiles[Vector2i(14, y)] = true
		fence_tiles[Vector2i(27, y)] = true
	for t: Vector2i in [Vector2i(14, 11), Vector2i(14, 12), Vector2i(27, 11), Vector2i(27, 12)]:
		fence_tiles.erase(t)
	var fence_tex: Array = []
	for m in 16:
		fence_tex.append(Px.tex(PixelArt.fence(m)))
	for t: Vector2i in fence_tiles:
		var m := 0
		if fence_tiles.has(t + Vector2i(0, -1)):
			m |= 1
		if fence_tiles.has(t + Vector2i(1, 0)):
			m |= 2
		if fence_tiles.has(t + Vector2i(0, 1)):
			m |= 4
		if fence_tiles.has(t + Vector2i(-1, 0)):
			m |= 8
		_sprite(fence_tex[m], Vector2(t.x * TS + 8, t.y * TS + 14), Vector2(-8, -15))
		_block(t)

	# 树
	var tree_tex: Array = []
	for i in 3:
		tree_tex.append(Px.tex(PixelArt.tree(i)))
	var tree_shadow := Px.tex(PixelArt.shadow(30, 9, 0.25))
	var tree_tiles: Array[Vector2i] = []
	for y in H:
		for x in W:
			var border := x < 2 or y < 2 or x >= W - 2 or y >= H - 2
			if border and (x + y) % 2 == 0 and _rng.randf() < 0.8:
				tree_tiles.append(Vector2i(x, y))
	var tries := 0
	var inner := 0
	while inner < 16 and tries < 400:
		tries += 1
		var t := Vector2i(_rng.randi_range(2, W - 3), _rng.randi_range(2, H - 3))
		if _near_important(t, 2):
			continue
		var ok := true
		for o in tree_tiles:
			if absi(o.x - t.x) + absi(o.y - t.y) < 3:
				ok = false
				break
		if ok:
			tree_tiles.append(t)
			inner += 1
	for t in tree_tiles:
		if not _is_free(t):
			continue
		var pos := Vector2(t.x * TS + 8 + _rng.randi_range(-2, 2), t.y * TS + 14)
		var s := _sprite(tree_tex[_rng.randi_range(0, 2)], pos, Vector2(-22, -57))
		s.material = tree_mat
		s.flip_h = _rng.randf() < 0.5
		_ground_shadow(pos + Vector2(0, -1), tree_shadow)
		_block(t)

	# 灌木和石头
	var small_shadow := Px.tex(PixelArt.shadow(16, 5, 0.22))
	for i in 22:
		var t := Vector2i(_rng.randi_range(2, W - 3), _rng.randi_range(2, H - 3))
		if not _is_free(t) or _near_important(t, 1):
			continue
		var pos := tile_center(t) + Vector2(0, 6)
		if i % 3 == 0:
			_sprite(Px.tex(PixelArt.rock(i)), pos, Vector2(-9, -12))
		else:
			_sprite(Px.tex(PixelArt.bush(i)), pos, Vector2(-11, -16))
		_ground_shadow(pos + Vector2(0, -1), small_shadow)
		_block(t)

	# 草丛和小花：不挡路，耕地时会被清掉
	var tuft_tex := Px.tex(PixelArt.tuft())
	var flower_tex: Array = []
	for i in 4:
		flower_tex.append(Px.tex(PixelArt.flower(i)))
	for i in 260:
		var t := Vector2i(_rng.randi_range(0, W - 1), _rng.randi_range(0, H - 1))
		if terrain[idx(t)] != GRASS or solid[idx(t)] == 1:
			continue
		var pos := Vector2(t.x * TS + _rng.randi_range(3, 13), t.y * TS + _rng.randi_range(5, 15))
		var s: Sprite2D
		if i % 4 == 0:
			s = _sprite(flower_tex[_rng.randi_range(0, 3)], pos, Vector2(-4, -8))
		else:
			s = _sprite(tuft_tex, pos, Vector2(-6, -6))
			s.flip_h = _rng.randf() < 0.5
		s.material = tuft_mat
		if not decor.has(t):
			decor[t] = []
		var list: Array = decor[t]
		list.append(s)


func _near_important(t: Vector2i, margin: int) -> bool:
	for dy in range(-margin, margin + 1):
		for dx in range(-margin, margin + 1):
			var n := t + Vector2i(dx, dy)
			if not in_map(n):
				return true
			if terrain[idx(n)] != GRASS or solid[idx(n)] == 1:
				return true
	return absi(t.x - START_TILE.x) + absi(t.y - START_TILE.y) < 4


# ---------------------------------------------------------------- 水面

func _make_sparkles() -> void:
	var pw := W * TS
	var tries := 0
	while _sparkles.size() < 46 and tries < 4000:
		tries += 1
		var x := _rng.randi_range(27 * TS, 38 * TS)
		var y := _rng.randi_range(13 * TS, 22 * TS)
		var ok := true
		for dy in range(-4, 4):
			for dx in range(-3, 9):
				if tbuf[(y + dy) * pw + x + dx] != WATER:
					ok = false
		if ok:
			_sparkles.append([Vector2(x, y), _rng.randf(), _rng.randi_range(3, 6), 0.25 + _rng.randf() * 0.2])


func _draw_water() -> void:
	var c1 := Color.html("d6f1fb")
	var c2 := Color.html("8fd0ee")
	for sv in _sparkles:
		var s: Array = sv
		var pos: Vector2 = s[0]
		var phase: float = s[1]
		var length: int = s[2]
		var speed: float = s[3]
		var t := fmod(_time * speed + phase, 1.0)
		if t > 0.55:
			continue
		var grow := sin(t / 0.55 * PI)
		var w := maxf(1.0, roundf(length * grow))
		var x := pos.x + roundf(t * 6.0) - floorf(w * 0.5)
		water_fx.draw_rect(Rect2(x, pos.y, w, 1), c1 if grow > 0.6 else c2)
		if grow > 0.8 and length > 4:
			water_fx.draw_rect(Rect2(x + 2, pos.y + 2, w - 3, 1), c2)


