class_name OutdoorMap
extends GameMap
## 室外地图的公共部分：按格子记的地形、整张地面贴图、挡路的格子、随季节变色的树和草、按日程走动的居民。
## 具体的地图（农场、镇广场）继承它，在 _ready 里先调 _setup_grid，再排地形和物件。

const GRASS := GroundArt.GRASS
const DIRT := GroundArt.DIRT
const WATER := GroundArt.WATER
const PAVE := GroundArt.PAVE
const SAND := GroundArt.SAND

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

## 灌木是渲染好的图，换季只能整体染色
const BUSH_TINTS: Array[Color] = [Color.WHITE, Color.WHITE, Color(1.0, 0.86, 0.6), Color(0.74, 0.86, 0.9)]

## 地图的宽和高，单位是格
var cols := 0
var rows := 0
var terrain := PackedByteArray()
var solid := PackedByteArray()
## 地面贴图上每个像素属于哪种地形
var tbuf := PackedByteArray()
## 草丛和小花，按格子记录，开垦或种东西时清掉
var decor: Dictionary = {}
var occupied: Dictionary = {}
## 两个居民离得这么近（像素）就可能聊起来，以及每次检查开聊的概率
const CHAT_DISTANCE := 38.0
const CHAT_CHANCE := 0.1

var npcs: Array[Npc] = []
var water_fx: Node2D
## 地上的采集物：格子 -> 精灵
var _forage_sprites: Dictionary[Vector2i, Sprite2D] = {}
## 水里的蟹笼：格子 -> 精灵（子节点 Catch 是装到东西时露出来的鱼）
var _trap_sprites: Dictionary[Vector2i, Sprite2D] = {}

## 地图载入时的季节（0 春 … 3 冬），决定地面和树的颜色。换季总是发生在睡觉时，醒来会重新载入地图。
var _season := 0
var _rng := RandomNumberGenerator.new()
var _tree_mat: ShaderMaterial
var _tuft_mat: ShaderMaterial
var _tree_shadow: Texture2D
var _small_shadow: Texture2D
var _npc_minute := -1
var _chat_t := 0.0
var _sparkles: Array = []
var _lights: Array[PointLight2D] = []
var _light_tex: GradientTexture2D
var _fx_t := 0.0
var _time := 0.0

## 地面贴图画一次要一两秒，按“地图:季节”存下来，同一局里再进这张地图就不用重画。
static var _ground_cache: Dictionary[String, Array] = {}


## 定下地图大小，准备好各张表和共用的材质。要在排地形之前调。
func _setup_grid(new_cols: int, new_rows: int) -> void:
	cols = new_cols
	rows = new_rows
	terrain.resize(cols * rows)
	solid.resize(cols * rows)
	_season = GameClock.season()
	var sway := Shader.new()
	sway.code = SWAY_SHADER
	_tree_mat = ShaderMaterial.new()
	_tree_mat.shader = sway
	_tree_mat.set_shader_parameter("still_from", 0.68)
	_tree_mat.set_shader_parameter("amp", 1.5)
	_tuft_mat = ShaderMaterial.new()
	_tuft_mat.shader = sway
	_tuft_mat.set_shader_parameter("still_from", 1.0)
	_tuft_mat.set_shader_parameter("amp", 1.2)
	_tree_shadow = Px.tex(PixelArt.shadow(30, 9, 0.25))
	_small_shadow = Px.tex(PixelArt.shadow(16, 5, 0.22))


## 地形排好以后调：画地面，建好按 y 排序的图层。
func _build_ground() -> void:
	var key := "%s:%d" % [map_id, _season]
	if not _ground_cache.has(key):
		var painted := GroundArt.paint(terrain, cols, rows, _season)
		var img: Image = painted["image"]
		_ground_cache[key] = [Px.tex(img), painted["tbuf"]]
	var cached: Array = _ground_cache[key]
	tbuf = cached[1]
	var ground := Sprite2D.new()
	ground.centered = false
	ground.texture = cached[0]
	ground.z_index = -10
	add_child(ground)


func _make_entities() -> void:
	entities = Node2D.new()
	entities.y_sort_enabled = true
	add_child(entities)


func _process(delta: float) -> void:
	_time += delta
	_fx_t += delta
	if water_fx != null and _fx_t > 0.12:
		_fx_t = 0.0
		water_fx.queue_redraw()
	_update_npcs()
	_chat_t += delta
	if _chat_t >= 0.5:
		_chat_t = 0.0
		_start_chats()
	var night := clampf((GameClock.minutes - 1080.0) / 150.0, 0.0, 1.0)
	for l in _lights:
		l.energy = night * 0.9


func size_px() -> Vector2i:
	return Vector2i(cols * TS, rows * TS)


func idx(t: Vector2i) -> int:
	return t.y * cols + t.x


func in_map(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < cols and t.y < rows


func blocked(p: Vector2) -> bool:
	for c: Vector2 in [Vector2(-4, -4), Vector2(4, -4), Vector2(-4, 1), Vector2(4, 1)]:
		if _tile_blocked(tile_of(p + c)):
			return true
	return false


## 这一格玩家能不能站。子类有别的挡路的东西（作物架子、果树）就接着加。
func _tile_blocked(t: Vector2i) -> bool:
	if not in_map(t) or solid[idx(t)] == 1:
		return true
	for npc in npcs:
		if npc.solid_tile() == t:
			return true
	return false


# ---------------------------------------------------------------- 地形

func _fill(x0: int, y0: int, x1: int, y1: int, v: int) -> void:
	for y in range(maxi(0, y0), mini(rows - 1, y1) + 1):
		for x in range(maxi(0, x0), mini(cols - 1, x1) + 1):
			terrain[y * cols + x] = v


## 把一格变成不能走的水。
func _set_water(t: Vector2i) -> void:
	if in_map(t):
		terrain[idx(t)] = WATER
		solid[idx(t)] = 1


func _is_water(t: Vector2i) -> bool:
	return in_map(t) and terrain[idx(t)] == WATER


func _next_to_water(t: Vector2i) -> bool:
	for d in GridPath.DIRS:
		if _is_water(t + d):
			return true
	return false


# ---------------------------------------------------------------- 物件

func _sprite(tex: Texture2D, pos: Vector2, offset: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.offset = offset
	s.position = pos
	entities.add_child(s)
	return s


## 放一个 Blender 渲染的物件，锚点对齐到 pos。
func _prop(prop: String, pos: Vector2) -> Sprite2D:
	var s := PropArt.sprite(prop, pos)
	entities.add_child(s)
	return s


func _ground_shadow(pos: Vector2, tex: Texture2D) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.position = pos
	s.z_index = -6
	add_child(s)
	return s


func _block(t: Vector2i) -> void:
	if in_map(t):
		solid[idx(t)] = 1
		occupied[t] = true


## 这一片不放树、灌木和采集物，但人能走（出入口两边，免得树冠把路挡住）。
func _reserve(x0: int, y0: int, x1: int, y1: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if in_map(Vector2i(x, y)):
				occupied[Vector2i(x, y)] = true


func _block_rect(x0: int, y0: int, x1: int, y1: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			_block(Vector2i(x, y))


func _is_free(t: Vector2i) -> bool:
	return in_map(t) and terrain[idx(t)] == GRASS and solid[idx(t)] == 0 and not occupied.has(t)


func _clear_decor(t: Vector2i) -> void:
	if not decor.has(t):
		return
	var list: Array = decor[t]
	for n: Node in list:
		n.queue_free()
	decor.erase(t)


## 这一格周围 margin 格之内要留空（靠近路、水、房子、出生点），不放树和灌木。子类可以再加条件。
func _keep_clear(t: Vector2i, margin: int) -> bool:
	for dy in range(-margin, margin + 1):
		for dx in range(-margin, margin + 1):
			var n := t + Vector2i(dx, dy)
			if not in_map(n):
				return true
			if terrain[idx(n)] != GRASS or solid[idx(n)] == 1:
				return true
	return false


## 这一格不许长野生的树、灌木、石头（留给以后盖的房子）。子类覆盖。
## 和 _reserve 不同：它不改变别处随机撒出来的位置。
func _no_scatter(_t: Vector2i) -> bool:
	return false


## 种野生的树：地图四边围一圈，里面再随机放 inner 棵。树挡路。
func _scatter_trees(inner: int) -> void:
	# 树是脚本画的（见 PixelArt.round_tree / plum_tree），每项是 [贴图, 锚点偏移]
	var tree_kinds: Array = [
		[Px.tex(PixelArt.round_tree(0, _season)), Vector2(-22, -57)],
		[Px.tex(PixelArt.round_tree(1, _season)), Vector2(-22, -57)],
		[Px.tex(PixelArt.round_tree(0, _season)), Vector2(-22, -57)],
		[Px.tex(PixelArt.round_tree(1, _season)), Vector2(-22, -57)],
		[Px.tex(PixelArt.round_tree(2, _season)), Vector2(-22, -57)],
		[Px.tex(PixelArt.plum_tree(0, _season)), Vector2(-24, -57)],
		[Px.tex(PixelArt.plum_tree(1, _season)), Vector2(-24, -57)],
	]
	var tree_tiles: Array[Vector2i] = []
	for y in rows:
		for x in cols:
			var border := x < 2 or y < 2 or x >= cols - 2 or y >= rows - 2
			if border and (x + y) % 2 == 0 and _rng.randf() < 0.8:
				tree_tiles.append(Vector2i(x, y))
	var tries := 0
	var placed := 0
	while placed < inner and tries < 800:
		tries += 1
		var t := Vector2i(_rng.randi_range(2, cols - 3), _rng.randi_range(2, rows - 3))
		if _keep_clear(t, 2):
			continue
		var ok := true
		for o in tree_tiles:
			if absi(o.x - t.x) + absi(o.y - t.y) < 3:
				ok = false
				break
		if ok:
			tree_tiles.append(t)
			placed += 1
	for t in tree_tiles:
		if not _is_free(t):
			continue
		var pos := Vector2(t.x * TS + 8 + _rng.randi_range(-2, 2), t.y * TS + 14)
		var kind: Array = tree_kinds[_rng.randi_range(0, tree_kinds.size() - 1)]
		# 随机数照常取完再跳过，别处的树位置不变
		if _no_scatter(t):
			continue
		var s := _sprite(kind[0], pos, kind[1])
		s.material = _tree_mat
		_ground_shadow(pos + Vector2(0, -1), _tree_shadow)
		_block(t)


## 灌木和石头，每三个里有一块石头。挡路。
func _scatter_bushes(count: int) -> void:
	for i in count:
		var t := Vector2i(_rng.randi_range(2, cols - 3), _rng.randi_range(2, rows - 3))
		if not _is_free(t) or _keep_clear(t, 1) or _no_scatter(t):
			continue
		var pos := tile_center(t) + Vector2(0, 6)
		if i % 3 == 0:
			_prop("rock_%d" % (i % 2), pos)
		else:
			_prop("bush_%d" % (i % 2), pos).modulate = BUSH_TINTS[_season]
		_ground_shadow(pos + Vector2(0, -1), _small_shadow)
		_block(t)


## 草丛和小花：不挡路，记在 decor 里。花春夏多，秋天少，冬天没有；随机数照常取，这样四季物件的位置不变。
func _scatter_tufts(count: int) -> void:
	var tuft_tex := Px.tex(PixelArt.tuft(_season))
	var flower_every := [4, 4, 9, 0][_season] as int
	var flower_tex: Array = []
	for i in 4:
		flower_tex.append(Px.tex(PixelArt.flower(i)))
	for i in count:
		var t := Vector2i(_rng.randi_range(0, cols - 1), _rng.randi_range(0, rows - 1))
		if terrain[idx(t)] != GRASS or solid[idx(t)] == 1:
			continue
		var pos := Vector2(t.x * TS + _rng.randi_range(3, 13), t.y * TS + _rng.randi_range(5, 15))
		var s: Sprite2D
		if flower_every > 0 and i % flower_every == 0:
			s = _sprite(flower_tex[_rng.randi_range(0, 3)], pos, Vector2(-4, -8))
		else:
			s = _sprite(tuft_tex, pos, Vector2(-6, -6))
			s.flip_h = _rng.randf() < 0.5
		s.material = _tuft_mat
		if not decor.has(t):
			decor[t] = []
		var list: Array = decor[t]
		list.append(s)


## 一盏傍晚以后慢慢亮起来的暖光（窗户、门口的灯笼）。
func _add_night_light(pos: Vector2, light_scale: float) -> void:
	var l := _glow(light_scale, Color(1.0, 0.82, 0.5), 0.0)
	l.position = pos
	add_child(l)
	_lights.append(l)


## 一团一直亮着的小光（河灯、萤火虫），自己挂到要跟着的东西上。不随傍晚渐亮。
func _glow(light_scale: float, color: Color, energy: float) -> PointLight2D:
	if _light_tex == null:
		var grad := Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 1.0])
		grad.colors = PackedColorArray([Color.WHITE, Color.BLACK])
		_light_tex = GradientTexture2D.new()
		_light_tex.gradient = grad
		_light_tex.width = 64
		_light_tex.height = 64
		_light_tex.fill = GradientTexture2D.FILL_RADIAL
		_light_tex.fill_from = Vector2(0.5, 0.5)
		_light_tex.fill_to = Vector2(1.0, 0.5)
	var l := PointLight2D.new()
	l.texture = _light_tex
	l.texture_scale = light_scale
	l.color = color
	l.energy = energy
	return l


## 在一片格子上盖三团雾，往 out 那个方向（地图外面）偏一点；返回这几团雾，散雾时用 _fade_fog。
func _add_fog_bank(fog: Rect2i, out: Vector2) -> Array[Sprite2D]:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 0.95), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var mid := Vector2(fog.position + fog.end) * TS / 2.0
	var puffs: Array[Sprite2D] = []
	for k in 3:
		var puff := Sprite2D.new()
		puff.texture = tex
		puff.position = mid + out * 10.0 + Vector2(out.y, out.x) * (k - 1) * 26.0
		puff.scale = Vector2(1.5, 1.5) if k == 1 else Vector2(1.2, 1.2)
		puff.z_index = 5
		add_child(puff)
		puffs.append(puff)
	return puffs


## 雾慢慢散掉。
func _fade_fog(puffs: Array[Sprite2D]) -> void:
	for puff in puffs:
		var tw := create_tween()
		tw.tween_property(puff, "modulate:a", 0.0, 1.5)
		tw.tween_callback(puff.queue_free)
	puffs.clear()


# ---------------------------------------------------------------- 采集物

## 把 Foraging 里这张地图的采集物画出来、捡走的删掉。地图 _ready 里连上 Foraging.changed。
func _sync_forage() -> void:
	for t: Vector2i in _forage_sprites.keys():
		if Foraging.item_at(map_id, t) == &"":
			_forage_sprites[t].queue_free()
			_forage_sprites.erase(t)
	var on_map: Dictionary = Foraging.items.get(map_id, {})
	for t: Vector2i in on_map:
		if _forage_sprites.has(t):
			continue
		var id: StringName = on_map[t]
		var pos := tile_center(t) + Vector2(0, 5)
		_forage_sprites[t] = _sprite(Px.tex(PixelArt.icon(Database.item(id).icon)), pos, Vector2(-8, -14))
		_clear_decor(t)


## 捡这一格的采集物。这一格有东西就返回真（背包满了没捡成也算）。
func _pick_forage(tile: Vector2i) -> bool:
	var id := Foraging.item_at(map_id, tile)
	if id == &"":
		return false
	if not GameState.inventory.can_add(id, 1):
		EventBus.banner_requested.emit("背包满了")
		Audio.play("deny", 0.0, -4.0)
		return true
	Foraging.take(map_id, tile)
	GameState.inventory.add(id, 1)
	Audio.play("harvest", 0.0)
	Fx.pop_icon(self, tile_center(tile) + Vector2(0, -6), Px.tex(PixelArt.icon(Database.item(id).icon)))
	return true


# ---------------------------------------------------------------- 蟹笼

## 这一格和蟹笼有关的动作：有笼子就能收（interact），拿着笼子对着水能放（place_trap）。
func _trap_query(item: ItemDef, tile: Vector2i) -> StringName:
	if Fishing.has_trap(map_id, tile):
		return &"interact"
	if item != null and item.id == Fishing.TRAP_ID and fishing_water(tile) != &"":
		return &"place_trap"
	return &""


## 放笼子或收笼子。这一下和笼子有关就返回真。
func _trap_perform(action: StringName, tile: Vector2i, item: ItemDef = null) -> bool:
	if action == &"place_trap":
		if item == null or item.id != Fishing.TRAP_ID or fishing_water(tile) == &"" or Fishing.has_trap(map_id, tile):
			return false
		GameState.inventory.remove(Fishing.TRAP_ID, 1)
		Fishing.place_trap(map_id, tile, fishing_water(tile))
		Audio.play("cast", 0.0, -8.0)
		return true
	if action != &"interact" or not Fishing.has_trap(map_id, tile):
		return false
	var caught := Fishing.trap_catch(map_id, tile)
	if caught != &"":
		var def := Database.fish_def(caught)
		var size := Fishing.roll_size(def, _rng.randf())
		var quality := def.quality_for(size)
		if not GameState.inventory.can_add(caught, 1, quality):
			EventBus.banner_requested.emit("背包满了")
			Audio.play("deny", 0.0, -4.0)
			return true
		Fishing.take_catch(map_id, tile)
		GameState.inventory.add(caught, 1, quality)
		Fishing.record(caught, size)
		EventBus.banner_requested.emit("笼子里有一只%s · %d 厘米" % [def.name, size])
		Audio.play("harvest", 0.0)
		Fx.pop_icon(self, tile_center(tile) + Vector2(0, -8), Px.tex(PixelArt.icon(Database.item(caught).icon)))
		return true
	if not GameState.inventory.can_add(Fishing.TRAP_ID, 1):
		EventBus.banner_requested.emit("背包满了")
		Audio.play("deny", 0.0, -4.0)
		return true
	Fishing.remove_trap(map_id, tile)
	GameState.inventory.add(Fishing.TRAP_ID, 1)
	Audio.play("select", 0.0, -6.0)
	Fx.pop_icon(self, tile_center(tile) + Vector2(0, -8), Px.tex(PixelArt.icon("crab_trap")))
	return true


## 把 Fishing 里这张地图的蟹笼画出来。地图 _ready 里连上 Fishing.changed。
func _sync_traps() -> void:
	var on_map: Dictionary = Fishing.traps.get(map_id, {})
	for t: Vector2i in _trap_sprites.keys():
		if not on_map.has(t):
			_trap_sprites[t].queue_free()
			_trap_sprites.erase(t)
	for t: Vector2i in on_map:
		if not _trap_sprites.has(t):
			var s := _sprite(Px.tex(PixelArt.crab_trap()), tile_center(t) + Vector2(0, 6), Vector2(-8, -12))
			var mark := Sprite2D.new()
			mark.name = "Catch"
			mark.position = Vector2(0, -16)
			s.add_child(mark)
			_trap_sprites[t] = s
		var caught: StringName = on_map[t].get("catch", &"")
		var mark: Sprite2D = _trap_sprites[t].get_node("Catch")
		mark.visible = caught != &""
		if mark.visible:
			mark.texture = Px.tex(PixelArt.icon(Database.item(caught).icon))


# ---------------------------------------------------------------- 水面

## 水面上一闪一闪的波光，count 是最多放几处。要在 _build_ground 之后调。
func _make_water_fx(count: int) -> void:
	water_fx = Node2D.new()
	water_fx.z_index = -8
	water_fx.draw.connect(_draw_water)
	add_child(water_fx)
	var pw := cols * TS
	var ph := rows * TS
	var tries := 0
	while _sparkles.size() < count and tries < 30000:
		tries += 1
		var x := _rng.randi_range(4, pw - 10)
		var y := _rng.randi_range(4, ph - 5)
		if tbuf[y * pw + x] != WATER:
			continue
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


# ---------------------------------------------------------------- 居民

## 地图载入时调：按现在的时间把该在这张地图上的居民直接放到位。
func _spawn_npcs() -> void:
	for id: StringName in Database.npcs:
		var def := Database.npc(id)
		var spot := NpcSchedule.spot_at(def, GameClock.minutes, Weather.today)
		var where: StringName = spot["map"]
		if where == map_id:
			var tile: Vector2i = spot["tile"]
			var facing: int = spot["facing"]
			_add_npc(def, tile, facing).spot = spot
	_npc_minute = int(GameClock.minutes)


## 每过一分钟看一遍日程：该来的从出入口走进来，该换地方的走过去，该走的走到出入口再消失。
func _update_npcs() -> void:
	var minute := int(GameClock.minutes)
	if minute == _npc_minute or cutscene:
		return
	_npc_minute = minute
	for id: StringName in Database.npcs:
		var def := Database.npc(id)
		var spot := NpcSchedule.spot_at(def, GameClock.minutes, Weather.today)
		var here: bool = spot["map"] == map_id
		var npc := _npc_of(id)
		if npc == null:
			if here and _door(def) != FestivalDef.NO_TILE:
				npc = _add_npc(def, _door(def), GameMap.Facing.DOWN)
				npc.appear()
				_send(npc, spot)
		elif npc.spot != spot:
			if here:
				_send(npc, spot)
			else:
				npc.spot = spot
				npc.walk(find_path(npc.tile(), def_door(npc)), GameMap.Facing.UP, true)


func _send(npc: Npc, spot: Dictionary) -> void:
	npc.spot = spot
	var tile: Vector2i = spot["tile"]
	var facing: int = spot["facing"]
	var path := find_path(npc.tile(), tile)
	if path.is_empty() and npc.tile() != tile:
		# 走不过去就直接出现在那里，总比卡在半路好
		npc.position = tile_center(tile) + Vector2(0, 4)
	npc.walk(path, facing)


func _add_npc(def: NpcDef, tile: Vector2i, facing: int) -> Npc:
	var npc := Npc.new()
	npc.setup(def, tile, facing)
	npc.player_position = _player_position
	npc.occupied = _occupied_by_someone
	npc.arrived.connect(_on_npc_arrived)
	npc.stuck.connect(_on_npc_stuck)
	entities.add_child(npc)
	npcs.append(npc)
	return npc


func _on_npc_arrived(npc: Npc, vanish: bool) -> void:
	if vanish:
		npcs.erase(npc)
		npc.queue_free()


## 居民被人挡住太久：绕开站着的人和玩家重新找路。
func _on_npc_stuck(npc: Npc) -> void:
	# 过场里居民正朝玩家走：不把他叫回日程上的位置
	if npc.spot.is_empty() or cutscene:
		return
	var here: bool = npc.spot["map"] == map_id
	var goal: Vector2i = npc.spot["tile"] if here else def_door(npc)
	var avoid := func(t: Vector2i) -> bool: return _walkable(t) and not _occupied_by_someone(t, npc)
	var path := GridPath.find(npc.tile(), goal, avoid, Rect2i(0, 0, cols, rows))
	if path.is_empty():
		return
	npc.walk(path, int(npc.spot["facing"]) if here else GameMap.Facing.UP, not here)


func def_door(npc: Npc) -> Vector2i:
	var door := _door(npc.def)
	return door if door != FestivalDef.NO_TILE else npc.tile()


## 这位居民从哪一格进出这张地图：自己的家门或路口；没有的话，节日那天走节日写的路口。都没有返回 NO_TILE。
func _door(def: NpcDef) -> Vector2i:
	if def.enter.has(map_id):
		return def.enter[map_id]
	var festival := Festivals.today()
	if festival != null and festival.map == map_id:
		return festival.gate
	return FestivalDef.NO_TILE


## 这一格有没有别人站着（站定的居民，或者玩家）。
func _occupied_by_someone(t: Vector2i, me: Npc) -> bool:
	for other in npcs:
		if other != me and other.solid_tile() == t:
			return true
	return player != null and tile_of(player.position) == t


## 站得近的两个居民偶尔面对面说几句。
func _start_chats() -> void:
	if not GameClock.running or cutscene:
		return
	for i in npcs.size():
		var a := npcs[i]
		if a.is_walking() or a.is_chatting():
			continue
		for j in range(i + 1, npcs.size()):
			var b := npcs[j]
			if b.is_walking() or b.is_chatting():
				continue
			if a.position.distance_to(b.position) > CHAT_DISTANCE:
				continue
			# 每半秒有一成的机会开聊，聊上八到十五秒
			if randf() < CHAT_CHANCE:
				var seconds := randf_range(8.0, 15.0)
				a.chat(b, seconds, 0.0)
				b.chat(a, seconds, 1.2)


func _npc_of(id: StringName) -> Npc:
	for npc in npcs:
		if npc.def.id == id:
			return npc
	return null


## 站在或正走过这一格的居民。
func npc_at(t: Vector2i) -> Npc:
	for npc in npcs:
		if npc.tile() == t:
			return npc
	return null


## 和这一格上的居民搭话；没有人就返回 false。
func _talk_at(t: Vector2i) -> bool:
	var npc := npc_at(t)
	if npc == null:
		return false
	npc.face_toward(_player_position())
	var working: bool = npc.spot.get("work", false) and not npc.is_walking()
	Residents.talk(npc.def.id, working)
	return true


func _player_position() -> Vector2:
	return player.position if player != null else Vector2(-9999, -9999)


## 居民从 from 走到 to 的路。树、房子、水不能走；别的居民不算障碍。
func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	return GridPath.find(from, to, _walkable, Rect2i(0, 0, cols, rows))


func _walkable(t: Vector2i) -> bool:
	return solid[idx(t)] == 0
