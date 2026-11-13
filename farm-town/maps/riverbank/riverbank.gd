extends OutdoorMap
## 河岸：坐老周的船顺溪而下到的大河边。河灯亮了以后才来得了。
## 北边是一整条河（河钓的鱼都在这儿），南岸是老周的船屋和竹林；对着系船的木桩按使用键坐船回南溪。
## 船屋门前有一条往东的土路，东滩灯亮了以后顺着它走到头是东滩。

const W := 44
const H := 30
## 河占的行：北边几行全是水，岸线弯弯曲曲
const RIVER_BASE := 8
## 靠岸的小码头
const DOCK_TILES: Array[Vector2i] = [Vector2i(14, 9), Vector2i(15, 9), Vector2i(14, 10), Vector2i(15, 10)]
const BOAT_POS := Vector2(16 * TS + 22, 10 * TS + 4)
const BOAT_TILES: Array[Vector2i] = [Vector2i(16, 10), Vector2i(17, 10)]
## 码头前的水湾：这几列的岸线往南凹进去
const INLET_X := Vector2i(12, 19)
const INLET_Y := 10
## 老周的船屋：正面墙脚那一行、最西一列、占几格宽
const BOATHOUSE_X := 22
const BOATHOUSE_FRONT := 15
const BOATHOUSE_W := 4
## 往东去东滩的路占的两行；路的最东头在东滩灯亮以前被雾封着
const EAST_ROAD_ROWS: Array[int] = [16, 17]
const EAST_FOG := Rect2i(41, 16, 3, 2)
## 东滩灯：路口北侧的一盏石灯。点亮以后雾散开，顺着路走到头是东滩
const EAST_LAMP_TILE := Vector2i(39, 15)
const EAST_LAMP := &"east"

var _east_lamp_sprite: Sprite2D
var _east_fog: Array[Sprite2D] = []


func _ready() -> void:
	map_id = &"riverbank"
	_rng.seed = 20261114
	_setup_grid(W, H)
	_layout()
	_build_ground()
	_make_entities()
	_place_objects()
	Foraging.settle(map_id, _forage_tiles(false), _forage_tiles(true))
	Foraging.changed.connect(_sync_forage)
	_sync_forage()
	Fishing.changed.connect(_sync_traps)
	_sync_traps()
	_make_water_fx(120)
	_spawn_npcs()


func _exit_tree() -> void:
	if Foraging.changed.is_connected(_sync_forage):
		Foraging.changed.disconnect(_sync_forage)
	if Fishing.changed.is_connected(_sync_traps):
		Fishing.changed.disconnect(_sync_traps)


func spawn_position(spawn: StringName) -> Vector2:
	if spawn == &"from_dongtan":
		return tile_center(Vector2i(W - 2, EAST_ROAD_ROWS[0])) + Vector2(0, 8)
	return tile_center(Vector2i(15, 10)) + Vector2(0, 2)


func spawn_facing(spawn: StringName) -> Facing:
	return Facing.LEFT if spawn == &"from_dongtan" else Facing.DOWN


func trigger_at(tile: Vector2i) -> Dictionary:
	if tile.x == W - 1 and EAST_ROAD_ROWS.has(tile.y) and not _east_closed():
		return {"map": &"dongtan", "spawn": &"from_riverbank"}
	return {}


## 往东滩的路走不走得通：东滩灯亮了才通。
func _east_closed() -> bool:
	return not Lamps.is_lit(EAST_LAMP)


func _in_fog(t: Vector2i) -> bool:
	return _east_closed() and EAST_FOG.has_point(t)


func _tile_blocked(t: Vector2i) -> bool:
	return super._tile_blocked(t) or _in_fog(t)


## 河里全是河水；码头的木板不算。
func fishing_water(tile: Vector2i) -> StringName:
	if not _is_water(tile) or DOCK_TILES.has(tile):
		return &""
	return &"river"


func query_use(item: ItemDef, tile: Vector2i, _facing: Facing) -> StringName:
	if npc_at(tile) != null or BOAT_TILES.has(tile) or _is_boathouse_wall(tile) or tile == EAST_LAMP_TILE or _in_fog(tile):
		return &"interact"
	if Foraging.item_at(map_id, tile) != &"":
		return &"harvest"
	var trap := _trap_query(item, tile)
	if trap != &"":
		return trap
	if item != null and item.id == &"rod" and fishing_water(tile) != &"":
		return &"cast"
	return &""


func perform(action: StringName, item: ItemDef, tile: Vector2i, _quiet: bool = false) -> void:
	match action:
		&"interact":
			if _talk_at(tile) or _trap_perform(action, tile):
				return
			if BOAT_TILES.has(tile):
				SceneRouter.travel(&"nanxi", &"from_boat")
			elif _is_boathouse_wall(tile):
				EventBus.banner_requested.emit("老周的船屋。门虚掩着，里面只有一张床和一堆网")
			elif tile == EAST_LAMP_TILE:
				if Lamps.is_lit(EAST_LAMP):
					EventBus.banner_requested.emit("东滩灯。火苗被风吹得横着，就是不灭")
				else:
					EventBus.lamp_requested.emit(EAST_LAMP)
			elif _in_fog(tile):
				EventBus.banner_requested.emit("雾太浓了，前面的路一步也看不清。风里有一点咸味")
		&"harvest":
			_pick_forage(tile)
		&"place_trap":
			_trap_perform(action, tile, item)


func _is_boathouse_wall(t: Vector2i) -> bool:
	return t.y == BOATHOUSE_FRONT - 1 and t.x >= BOATHOUSE_X and t.x < BOATHOUSE_X + BOATHOUSE_W


# ---------------------------------------------------------------- 布局

## 河的南岸在这一列到哪一行（这一行以上都是水）
func _shore_y(x: int) -> int:
	if x >= INLET_X.x and x <= INLET_X.y:
		return INLET_Y
	return RIVER_BASE + int(roundf(sin(x * 0.19 + 1.2) * 1.5 + sin(x * 0.53) * 0.6))


func _layout() -> void:
	for x in W:
		for y in range(0, _shore_y(x) + 1):
			_set_water(Vector2i(x, y))
	for t in DOCK_TILES:
		solid[idx(t)] = 0
	# 船屋门前的一小块土地和通往码头的小径
	_fill(BOATHOUSE_X, BOATHOUSE_FRONT, BOATHOUSE_X + BOATHOUSE_W - 1, BOATHOUSE_FRONT + 1, DIRT)
	_fill(14, 11, 15, 12, DIRT)
	for x in range(15, BOATHOUSE_X + 1):
		var y := 12 + (x - 15) / 3
		_fill(x, y, x, y + 1, DIRT)
	# 从船屋门前往东去东滩的土路
	_fill(BOATHOUSE_X + BOATHOUSE_W - 1, EAST_ROAD_ROWS[0], W - 1, EAST_ROAD_ROWS[1], DIRT)


## 采集物长在岸边和竹林里能走到的空草地。
func _forage_tiles(shore: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(RIVER_BASE - 2, H - 2):
		for x in range(2, W - 2):
			var t := Vector2i(x, y)
			if not _is_free(t):
				continue
			if _next_to_water(t) == shore:
				out.append(t)
	return out


func _place_objects() -> void:
	# 靠岸的小码头和船
	for t in DOCK_TILES:
		var m := 0
		if DOCK_TILES.has(t + Vector2i(0, -1)):
			m |= 1
		if DOCK_TILES.has(t + Vector2i(1, 0)):
			m |= 2
		if DOCK_TILES.has(t + Vector2i(0, 1)) or not _is_water(t + Vector2i(0, 1)):
			m |= 4
		if DOCK_TILES.has(t + Vector2i(-1, 0)):
			m |= 8
		var plank := Sprite2D.new()
		plank.texture = Px.tex(PixelArt.dock_tile(m))
		plank.centered = false
		plank.position = Vector2(t.x * TS, t.y * TS)
		plank.z_index = -7
		add_child(plank)
		occupied[t] = true
	var post_tex := Px.tex(PixelArt.dock_post())
	for p: Vector2 in [Vector2(14 * TS + 1, 9 * TS - 12), Vector2(16 * TS - 5, 9 * TS - 12)]:
		var post := Sprite2D.new()
		post.texture = post_tex
		post.centered = false
		post.position = p
		post.z_index = -7
		add_child(post)
	var boat := _sprite(Px.tex(PixelArt.boat()), BOAT_POS, Vector2(-16, -10))
	boat.z_index = -7
	for t in BOAT_TILES:
		occupied[t] = true

	# 老周的船屋
	var pos := Vector2((BOATHOUSE_X + BOATHOUSE_W / 2.0) * TS, BOATHOUSE_FRONT * TS)
	_prop("boathouse", pos)
	_block_rect(BOATHOUSE_X, BOATHOUSE_FRONT - 4, BOATHOUSE_X + BOATHOUSE_W - 1, BOATHOUSE_FRONT - 1)
	_ground_shadow(pos + Vector2(0, -1), Px.tex(PixelArt.shadow(BOATHOUSE_W * TS - 8, 10, 0.22)))
	_add_night_light(pos + Vector2(-8, -18), 1.3)

	# 岸边的石头
	for t: Vector2i in [Vector2i(8, 11), Vector2i(30, 10), Vector2i(37, 12), Vector2i(4, 9)]:
		if _is_free(t):
			var rp := tile_center(t) + Vector2(0, 6)
			_prop("rock_%d" % (t.x % 2), rp)
			_ground_shadow(rp + Vector2(0, -1), _small_shadow)
			_block(t)

	var lamp_pos := tile_center(EAST_LAMP_TILE) + Vector2(0, 6)
	_east_lamp_sprite = _prop("stone_lamp", lamp_pos)
	_ground_shadow(lamp_pos + Vector2(0, -1), Px.tex(PixelArt.shadow(16, 5, 0.22)))
	_block(EAST_LAMP_TILE)
	if Lamps.is_lit(EAST_LAMP):
		_add_night_light(lamp_pos + Vector2(0, -16), 2.0)
	else:
		_east_fog = _add_fog_bank(EAST_FOG, Vector2(1, 0))

	_reserve(BOATHOUSE_X + BOATHOUSE_W, EAST_ROAD_ROWS[0] - 2, W - 1, EAST_ROAD_ROWS[1] + 1)
	_reserve(13, 9, 18, 13)
	_reserve(BOATHOUSE_X - 1, BOATHOUSE_FRONT - 5, BOATHOUSE_X + BOATHOUSE_W, BOATHOUSE_FRONT + 2)
	_scatter_trees(34)
	_scatter_bushes(20)
	_scatter_tufts(320)


## 点灯的那一下：火光，往东的雾散开。
func on_lamp_lit(lamp_id: StringName) -> void:
	if lamp_id != EAST_LAMP:
		return
	var at := _east_lamp_sprite.position + Vector2(0, -18)
	_add_night_light(_east_lamp_sprite.position + Vector2(0, -16), 2.0)
	Fx.burst(self, at, Color(1.0, 0.85, 0.45, 0.95), 18, 40.0, 0.7, 20.0)
	Fx.burst(self, at, Color(1.0, 0.6, 0.25, 0.8), 10, 24.0, 0.9, 12.0)
	_fade_fog(_east_fog)
