extends OutdoorMap
## 北坡牧场：镇子西边的老牧道上去就是。阿牧的畜棚、围起来的草场、坡上的蜂场。
## 牧野灯亮了以后才走得进来；这里的牲口是阿牧的，只能看看、摸摸。
## 路北边有一条上山的小路，山祠灯亮了以后顺着它走到头是山祠。

const W := 44
const H := 30
## 往东下去是镇子
const ROAD_ROWS: Array[int] = [14, 15]
## 阿牧的畜棚：[最西一列, 正面墙脚下面那一行, 占几格宽, 占几格深]
const BARN: Array[int] = [11, 11, 6, 4]
## 蜂箱：每组占三格宽，这里记最西边那一格
const HIVES: Array[Vector2i] = [Vector2i(29, 8), Vector2i(33, 8)]
## 围着的草场（栅栏那一圈），北边对着路留一个口
const PADDOCK := Rect2i(8, 18, 19, 9)
const GATE: Array[Vector2i] = [Vector2i(16, 18), Vector2i(17, 18)]
## 阿牧的牲口：[动物 id, 名字, 活动范围, 对着它按一下的说明]
const HERD: Array = [
	[&"buffalo", "花花", Rect2i(9, 19, 17, 7), "花花。它嚼着草看了你一眼，尾巴甩了一下"],
	[&"goat", "", Rect2i(9, 19, 17, 7), "阿牧的山羊。它想尝尝你的袖子"],
	[&"goat", "", Rect2i(9, 19, 17, 7), "阿牧的山羊。它站在最高的那块草皮上"],
	[&"sheep", "", Rect2i(9, 19, 17, 7), "阿牧的绵羊。毛厚得看不见眼睛"],
	[&"sheep", "", Rect2i(9, 19, 17, 7), "阿牧的绵羊。你一走近它就往羊堆里挤"],
	[&"chicken", "", Rect2i(10, 12, 11, 3), "阿牧的鸡。它不认识你，也不怕你"],
	[&"chicken", "", Rect2i(10, 12, 11, 3), "阿牧的鸡。在啄畜棚墙根的草籽"],
]

## 上山去山祠的小路占的两列；最北头在山祠灯亮以前被雾封着
const HILL_PATH_COLS: Array[int] = [24, 25]
const HILL_FOG := Rect2i(24, 0, 2, 3)
## 山祠灯：小路东侧的一盏石灯
const SHRINE_LAMP_TILE := Vector2i(26, 4)
const SHRINE_LAMP := &"shrine"
## 第五幕的开头：东滩灯亮了以后，起雾的日子有一头白鹿站在雾边上
const LAN_TILE := Vector2i(24, 4)
const LAN_AFTER := &"lamp_east"
const LAN_MET := &"met_lan"
const LAN_DIALOGUE := "res://dialogue/lan.dialogue"

var _shrine_lamp_sprite: Sprite2D
var _hill_fog: Array[Sprite2D] = []
var _lan: Sprite2D
var _lan_frames: Array[Texture2D] = []
var _lan_time := 0.0
var _herd: Array[Critter] = []
var _herd_notes: Dictionary[Critter, String] = {}
var _herd_minute := -1


func _ready() -> void:
	map_id = &"pasture"
	_rng.seed = 20261115
	_setup_grid(W, H)
	_layout()
	_build_ground()
	_make_entities()
	_place_objects()
	Foraging.settle(map_id, _forage_tiles(false), _forage_tiles(true))
	Foraging.changed.connect(_sync_forage)
	_sync_forage()
	_make_water_fx(20)
	_spawn_npcs()
	_sync_herd()
	_sync_lan()


func _exit_tree() -> void:
	if Foraging.changed.is_connected(_sync_forage):
		Foraging.changed.disconnect(_sync_forage)


func _process(delta: float) -> void:
	super._process(delta)
	var minute := int(GameClock.minutes)
	if minute != _herd_minute:
		_herd_minute = minute
		_sync_herd()
	for c in _herd:
		c.avoid = player
	_sync_lan()
	if _lan != null:
		_lan_time += delta
		_lan.texture = _lan_frames[1] if fmod(_lan_time, 3.2) > 2.8 else _lan_frames[0]


func spawn_position(spawn: StringName) -> Vector2:
	if spawn == &"from_shanci":
		return tile_center(Vector2i(HILL_PATH_COLS[0], 1)) + Vector2(8, 0)
	return tile_center(Vector2i(W - 2, ROAD_ROWS[0])) + Vector2(0, 8)


func spawn_facing(spawn: StringName) -> Facing:
	return Facing.DOWN if spawn == &"from_shanci" else Facing.LEFT


func trigger_at(tile: Vector2i) -> Dictionary:
	if tile.x == W - 1 and ROAD_ROWS.has(tile.y):
		return {"map": &"town", "spawn": &"from_pasture"}
	if tile.y == 0 and HILL_PATH_COLS.has(tile.x) and not _hill_closed():
		return {"map": &"shanci", "spawn": &"from_pasture"}
	return {}


## 上山的路走不走得通：山祠灯亮了才通。
func _hill_closed() -> bool:
	return not Lamps.is_lit(SHRINE_LAMP)


func _in_fog(t: Vector2i) -> bool:
	return _hill_closed() and HILL_FOG.has_point(t)


## 白鹿今天在不在雾边上：东滩灯亮了、山祠灯还没亮、还没见过它、而且起着雾。
func lan_waiting() -> bool:
	return Weather.is_foggy() and _hill_closed() and GameState.has_flag(LAN_AFTER) and not GameState.has_flag(LAN_MET)


func _tile_blocked(t: Vector2i) -> bool:
	return super._tile_blocked(t) or _in_fog(t) or (_lan != null and t == LAN_TILE)


func query_use(_item: ItemDef, tile: Vector2i, _facing: Facing) -> StringName:
	if tile == SHRINE_LAMP_TILE or _in_fog(tile) or (_lan != null and tile == LAN_TILE):
		return &"interact"
	if npc_at(tile) != null or _critter_at(tile) != null or _sign_at(tile) != "":
		return &"interact"
	if Foraging.item_at(map_id, tile) != &"":
		return &"harvest"
	return &""


func perform(action: StringName, _item: ItemDef, tile: Vector2i, _quiet: bool = false) -> void:
	match action:
		&"interact":
			if _talk_at(tile):
				return
			if _lan != null and tile == LAN_TILE:
				EventBus.dialogue_requested.emit(LAN_DIALOGUE, "meet")
				return
			if tile == SHRINE_LAMP_TILE:
				if Lamps.is_lit(SHRINE_LAMP):
					EventBus.banner_requested.emit("山祠灯。火苗是青白色的，照着上山的路")
				else:
					EventBus.lamp_requested.emit(SHRINE_LAMP)
				return
			if _in_fog(tile):
				EventBus.banner_requested.emit(_fog_text())
				return
			var critter := _critter_at(tile, 20.0)
			if critter != null:
				if player != null:
					critter.notice(player.position)
				Audio.play(critter.def.sound, 0.12, -5.0)
				Fx.burst(self, critter.position + Vector2(0, -14), Color(0.95, 0.45, 0.55, 0.95), 4, 18.0, 0.7, -30.0)
				EventBus.banner_requested.emit(_herd_notes.get(critter, ""))
			elif _sign_at(tile) != "":
				EventBus.banner_requested.emit(_sign_at(tile))
		&"harvest":
			_pick_forage(tile)


## 畜棚的正面墙和蜂箱，对着按一下有一句说明。
func _sign_at(t: Vector2i) -> String:
	if t.y == BARN[1] - 1 and t.x >= BARN[0] and t.x < BARN[0] + BARN[2]:
		return "阿牧的畜棚。门边挂着一排铃，每只上头刻着一个名字"
	for h in HIVES:
		if t.y == h.y and t.x >= h.x and t.x < h.x + 3:
			return "阿牧的蜂箱。蜂子进进出出，没空理你"
	return ""


## 对着上山的雾按一下说什么：按第五幕走到哪一步给一句提示。
func _fog_text() -> String:
	if GameState.has_flag(LAN_MET):
		return "白鹿是从这条路上山的。路口的石灯还黑着"
	if GameState.has_flag(LAN_AFTER) and not Weather.is_foggy():
		return "雾里有一串蹄印，顺着山路上去了。印子很新，草上的露水却一颗没碎。\n起雾的日子再来看看"
	return "雾太浓了，山路一步也看不清"


# ---------------------------------------------------------------- 白鹿

## 白鹿该在就放出来，不该在了（见过了、雾散了）就淡掉。
func _sync_lan() -> void:
	var want := lan_waiting()
	if want == (_lan != null):
		return
	if want:
		if _lan_frames.is_empty():
			_lan_frames = [Px.tex(ShrineArt.deer(0)), Px.tex(ShrineArt.deer(1))]
		_lan = _sprite(_lan_frames[0], tile_center(LAN_TILE) + Vector2(0, 7), Vector2(-25, -45))
		_lan.flip_h = true
	else:
		var gone := _lan
		_lan = null
		var tw := create_tween()
		tw.tween_property(gone, "modulate:a", 0.0, 1.2)
		tw.tween_callback(gone.queue_free)


## 点灯的那一下：火光，上山的雾散开。
func on_lamp_lit(lamp_id: StringName) -> void:
	if lamp_id != SHRINE_LAMP:
		return
	var at := _shrine_lamp_sprite.position + Vector2(0, -18)
	_add_night_light(_shrine_lamp_sprite.position + Vector2(0, -16), 2.0)
	Fx.burst(self, at, Color(0.8, 0.95, 1.0, 0.95), 18, 40.0, 0.7, 20.0)
	Fx.burst(self, at, Color(0.6, 0.85, 1.0, 0.8), 10, 24.0, 0.9, 12.0)
	_fade_fog(_hill_fog)


# ---------------------------------------------------------------- 牲口

## 白天不下雨下雪就放出来，傍晚收回去。
func _herd_out() -> bool:
	if GameClock.minutes < 360.0 or GameClock.minutes >= 1110.0:
		return false
	return Weather.today != Weather.RAIN and Weather.today != Weather.STORM and Weather.today != Weather.SNOW


func _sync_herd() -> void:
	var out := _herd_out()
	if out == not _herd.is_empty():
		return
	if not out:
		for c in _herd:
			c.queue_free()
		_herd.clear()
		_herd_notes.clear()
		return
	for entry: Array in HERD:
		var kind: StringName = entry[0]
		var yard: Rect2i = entry[2]
		var c := Critter.new()
		c.walkable = _critter_can_walk
		c.water = _is_water
		c.yard = yard
		c.avoid = player
		c.setup(Database.animal(kind), -1, _yard_spot(yard))
		entities.add_child(c)
		_herd.append(c)
		_herd_notes[c] = str(entry[3])


func _critter_can_walk(t: Vector2i) -> bool:
	return in_map(t) and not _tile_blocked(t)


func _yard_spot(yard: Rect2i) -> Vector2:
	for n in 20:
		var t := yard.position + Vector2i(_rng.randi() % yard.size.x, _rng.randi() % yard.size.y)
		if _critter_can_walk(t):
			return tile_center(t) + Vector2(_rng.randf_range(-4, 4), _rng.randf_range(-2, 4))
	return tile_center(yard.position)


func _critter_at(tile: Vector2i, reach: float = 13.0) -> Critter:
	var c := tile_center(tile)
	var best: Critter = null
	var best_d := reach
	for critter in _herd:
		var d := (critter.position + Vector2(0, -3)).distance_to(c)
		if d < best_d:
			best_d = d
			best = critter
	return best


# ---------------------------------------------------------------- 布局

func _layout() -> void:
	# 从镇上上来的土路，通到畜棚前的场院
	_fill(20, ROAD_ROWS[0], W - 1, ROAD_ROWS[1], DIRT)
	_fill(BARN[0] - 1, BARN[1], BARN[0] + BARN[2] + 3, ROAD_ROWS[1], DIRT)
	# 上山去山祠的小路
	_fill(HILL_PATH_COLS[0], 0, HILL_PATH_COLS[1], ROAD_ROWS[0] - 1, DIRT)
	# 草场口到路上的一小段
	_fill(GATE[0].x, ROAD_ROWS[1] + 1, GATE[1].x, PADDOCK.position.y, DIRT)
	# 东南角一口饮牛的水塘
	for y in H:
		for x in W:
			var dx := (x - 35.5) / 3.4
			var dy := (y - 22.0) / 2.2
			if dx * dx + dy * dy <= 1.0:
				_set_water(Vector2i(x, y))


## 采集物可以落在哪些格子：草场外面能走到的空草地。shore 为真时只要紧挨着水的。
func _forage_tiles(shore: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(3, H - 2):
		for x in range(2, W - 3):
			var t := Vector2i(x, y)
			if not _is_free(t) or PADDOCK.has_point(t):
				continue
			if _next_to_water(t) == shore:
				out.append(t)
	return out


func _place_objects() -> void:
	# 畜棚
	var barn_pos := Vector2((BARN[0] + BARN[2] / 2.0) * TS, BARN[1] * TS)
	_prop("barn", barn_pos)
	_block_rect(BARN[0], BARN[1] - BARN[3], BARN[0] + BARN[2] - 1, BARN[1] - 1)
	_ground_shadow(barn_pos + Vector2(0, -1), Px.tex(PixelArt.shadow(BARN[2] * TS + 4, 9, 0.22)))
	_add_night_light(barn_pos + Vector2(0, -20), 1.5)

	# 蜂箱
	for h in HIVES:
		var pos := Vector2((h.x + 1.5) * TS, (h.y + 1) * TS - 2)
		_prop("apiary", pos)
		_ground_shadow(pos + Vector2(0, -1), Px.tex(PixelArt.shadow(44, 6, 0.22)))
		_block_rect(h.x, h.y, h.x + 2, h.y)

	# 草场的栅栏
	var fence_tiles: Dictionary = {}
	for x in range(PADDOCK.position.x, PADDOCK.end.x):
		fence_tiles[Vector2i(x, PADDOCK.position.y)] = true
		fence_tiles[Vector2i(x, PADDOCK.end.y - 1)] = true
	for y in range(PADDOCK.position.y, PADDOCK.end.y):
		fence_tiles[Vector2i(PADDOCK.position.x, y)] = true
		fence_tiles[Vector2i(PADDOCK.end.x - 1, y)] = true
	for t in GATE:
		fence_tiles.erase(t)
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
		_prop("fence_%d" % m, tile_center(t))
		_block(t)

	# 山祠灯
	var lamp_pos := tile_center(SHRINE_LAMP_TILE) + Vector2(0, 6)
	_shrine_lamp_sprite = _prop("stone_lamp", lamp_pos)
	_ground_shadow(lamp_pos + Vector2(0, -1), Px.tex(PixelArt.shadow(16, 5, 0.22)))
	_block(SHRINE_LAMP_TILE)
	if Lamps.is_lit(SHRINE_LAMP):
		_add_night_light(lamp_pos + Vector2(0, -16), 2.0)
	else:
		_hill_fog = _add_fog_bank(HILL_FOG, Vector2(0, -1))
	_reserve(HILL_PATH_COLS[0] - 2, 0, HILL_PATH_COLS[1] + 2, ROAD_ROWS[0] - 1)

	# 路口、场院、草场里面、蜂箱前面都不长树
	_reserve(19, ROAD_ROWS[0] - 2, W - 1, ROAD_ROWS[1] + 2)
	_reserve(BARN[0] - 2, BARN[1], BARN[0] + BARN[2] + 4, ROAD_ROWS[1] + 2)
	_reserve(PADDOCK.position.x, PADDOCK.position.y - 1, PADDOCK.end.x - 1, PADDOCK.end.y - 1)
	_reserve(HIVES[0].x - 1, HIVES[0].y - 1, HIVES[1].x + 3, HIVES[0].y + 2)
	_scatter_trees(14)
	_scatter_bushes(18)
	_scatter_tufts(520)
