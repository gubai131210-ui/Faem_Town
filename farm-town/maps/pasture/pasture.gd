extends WildMap
## 北坡牧场：镇子西边的老牧道上去就是。阿牧的畜棚、围起来的草场、坡上的蜂场。
## 牧野灯亮了以后才走得进来；这里的牲口是阿牧的，只能看看、摸摸。
## 路北边有一条上山的小路，山祠灯亮了以后顺着它走到头是山祠。

## 老牧场是左上角 44×30；往东、往南扩到 76×48，老坐标一格不动（决策 151）。
const OLD_W := 44
const OLD_H := 30
const W := 76
const H := 48
const NEW_TREES: Array[String] = ["round0", "round1", "round2", "pine0", "round0", "willow0"]
## 往东走的第二块草场（歇着，没有牲口）和往南的羊圈
const PADDOCK2 := Rect2i(56, 18, 16, 9)
const GATE2: Array[Vector2i] = [Vector2i(63, 18), Vector2i(64, 18)]
const PADDOCK3 := Rect2i(36, 34, 13, 10)
const GATE3: Array[Vector2i] = [Vector2i(48, 38), Vector2i(48, 39)]
## 往南去的土路占的两列
const SOUTH_COLS: Array[int] = [50, 51]
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
## 牧野灯亮了才能走到这儿，所以老牧道、磨坊和土地庙一直在（决策 114）
## 磨坊：[最西一列, 门脸那一行, 宽, 深]
const MILL: Array[int] = [1, 12, 4, 3]
## 路边的土地庙
const SHRINE: Array[int] = [18, 13, 2, 2]
const TRACK_MARK := Vector2i(7, 13)
## 磨坊东墙的记数木牌。货郎站在门口那一格，不占这格。
const MILL_TALLY := Vector2i(5, 11)
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
	_scatter_cols = OLD_W
	_scatter_rows = OLD_H
	_setup_wild(W, H)
	_layout()
	_layout_new()
	_build_ground()
	_make_entities()
	_place_objects()
	_place_new()
	Foraging.settle(map_id, _forage_tiles(false), _forage_tiles(true))
	Foraging.changed.connect(_sync_forage)
	_sync_forage()
	_make_water_fx(20)
	_spawn_npcs()
	_sync_herd()
	_sync_lan()


func _exit_tree() -> void:
	super._exit_tree()
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
	if npc_at(tile) != null or _critter_at(tile) != null or _sign_at(tile) != "" or _returned_text(tile) != "":
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
			elif _returned_text(tile) != "":
				if tile == MILL_TALLY:
					GameState.set_flag(&"read_mill_tally")
				EventBus.banner_requested.emit(_returned_text(tile))
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


func clue_at(t: Vector2i) -> String:
	if clues.has(t):
		return clues[t]
	if t == MILL_TALLY:
		return "磨坊侧墙钉着一块木牌。磨了多少记到一半，后头是空的。"
	return ""


func _returned_text(t: Vector2i) -> String:
	var clue := clue_at(t)
	if clue != "":
		return clue
	if t == TRACK_MARK:
		var extra := PeopleLine.mark(&"amu")
		var line := "老牧道。蹄印嵌在土里，雨也冲不掉。"
		if extra != "":
			line += extra
		var trade := Livelihood.mark(&"herd")
		return line if trade == "" else line + trade
	if t.y == MILL[1] - 1 and t.x >= MILL[0] and t.x < MILL[0] + MILL[2]:
		return "老磨坊。门口的石磨还在，侧面架着一架水车。"
	if t.y == SHRINE[1] - 1 and t.x >= SHRINE[0] and t.x < SHRINE[0] + SHRINE[2]:
		return "路边的土地庙。供桌上有一只香炉，红布是新的。"
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
	_fade_fog(_hill_fog, _shrine_lamp_sprite.position)


func lamp_focus(lamp_id: StringName) -> Vector2:
	if lamp_id == SHRINE_LAMP and _shrine_lamp_sprite != null:
		return _shrine_lamp_sprite.global_position
	return Vector2.INF


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
	_fill(20, ROAD_ROWS[0], OLD_W - 1, ROAD_ROWS[1], DIRT)
	_fill(BARN[0] - 1, BARN[1], BARN[0] + BARN[2] + 3, ROAD_ROWS[1], DIRT)
	# 上山去山祠的小路
	_fill(HILL_PATH_COLS[0], 0, HILL_PATH_COLS[1], ROAD_ROWS[0] - 1, DIRT)
	# 草场口到路上的一小段
	_fill(GATE[0].x, ROAD_ROWS[1] + 1, GATE[1].x, PADDOCK.position.y, DIRT)
	# 老牧道：从场院往西，通到磨坊门口
	_fill(MILL[0], MILL[1], 10, ROAD_ROWS[1], DIRT)
	# 东南角一口饮牛的水塘
	for y in OLD_H:
		for x in OLD_W:
			var dx := (x - 35.5) / 3.4
			var dy := (y - 22.0) / 2.2
			if dx * dx + dy * dy <= 1.0:
				_set_water(Vector2i(x, y))


## 采集物可以落在哪些格子：草场外面能走到的空草地。shore 为真时只要紧挨着水的。
func _forage_tiles(shore: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(3, OLD_H - 2):
		for x in range(2, OLD_W - 3):
			var t := Vector2i(x, y)
			if not _is_free(t) or PADDOCK.has_point(t):
				continue
			if _next_to_water(t) == shore:
				out.append(t)
	return out


func _place_objects() -> void:
	# 老磨坊和路边的土地庙
	var mill_pos := Vector2((MILL[0] + MILL[2] / 2.0) * TS, MILL[1] * TS)
	_prop("mill", mill_pos)
	_ground_shadow(mill_pos + Vector2(0, -1), Px.tex(PixelArt.shadow(MILL[2] * TS - 4, 8, 0.22)))
	_block_rect(MILL[0], MILL[1] - MILL[3], MILL[0] + MILL[2] - 1, MILL[1] - 1)
	_hang_clue(MILL_TALLY, PlaceClueArt.tally(), 6.0)
	var shrine_pos := Vector2((SHRINE[0] + SHRINE[2] / 2.0) * TS, SHRINE[1] * TS)
	_prop("earth_shrine", shrine_pos)
	_ground_shadow(shrine_pos + Vector2(0, -1), Px.tex(PixelArt.shadow(28, 6, 0.22)))
	_block_rect(SHRINE[0], SHRINE[1] - SHRINE[3], SHRINE[0] + SHRINE[2] - 1, SHRINE[1] - 1)
	var mark_pos := tile_center(TRACK_MARK) + Vector2(0, 6)
	_prop("rock_0", mark_pos)
	if PeopleLine.mark(&"amu") != "":
		var tag := Sprite2D.new()
		tag.name = "DogTag"
		tag.texture = Px.tex(_dog_tag())
		tag.centered = false
		tag.position = mark_pos + Vector2(6, -16)
		tag.z_index = 1
		add_child(tag)
	if Livelihood.told(&"herd") >= 1:
		var sack := Sprite2D.new()
		sack.name = "FeedSack"
		sack.texture = Px.tex(_feed_sack())
		sack.centered = false
		sack.position = mark_pos + Vector2(-14, -10)
		sack.z_index = 1
		add_child(sack)
	_ground_shadow(mark_pos + Vector2(0, -1), Px.tex(PixelArt.shadow(14, 4, 0.2)))
	_block(TRACK_MARK)

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
	_reserve(MILL[0] - 1, MILL[1] - MILL[3], 10, ROAD_ROWS[1] + 1)
	_reserve(SHRINE[0] - 1, SHRINE[1] - SHRINE[3], SHRINE[0] + SHRINE[2] + 1, SHRINE[1] + 1)
	_reserve(19, ROAD_ROWS[0] - 2, OLD_W - 1, ROAD_ROWS[1] + 2)
	_reserve(BARN[0] - 2, BARN[1], BARN[0] + BARN[2] + 4, ROAD_ROWS[1] + 2)
	_reserve(PADDOCK.position.x, PADDOCK.position.y - 1, PADDOCK.end.x - 1, PADDOCK.end.y - 1)
	_reserve(HIVES[0].x - 1, HIVES[0].y - 1, HIVES[1].x + 3, HIVES[0].y + 2)
	_scatter_trees(14)
	_scatter_bushes(18)
	_scatter_tufts(520)
	_release_ghosts()


func _dog_tag() -> Image:
	var img := Px.new_img(10, 8)
	Px.rect(img, 0, 1, 10, 6, Color.html("c4a06a"))
	Px.rect(img, 4, 0, 2, 2, Color.html("f7dc80"))
	Px.rect(img, 2, 3, 6, 1, Color.html("6a4430"))
	Px.rect(img, 2, 5, 4, 1, Color.html("6a4430"))
	return img


func _feed_sack() -> Image:
	var img := Px.new_img(8, 10)
	Px.rect(img, 1, 2, 6, 8, Color.html("c4a06a"))
	Px.rect(img, 2, 0, 4, 2, Color.html("6a4430"))
	Px.rect(img, 2, 5, 4, 1, Color.html("e8c878"))
	return img


# ---------------------------------------------------------------- 往东、往南扩出来的部分

func _ghost_tree(t: Vector2i) -> bool:
	return _legacy_edge(t, OLD_W, OLD_H)


func _layout_new() -> void:
	_fill(OLD_W, ROAD_ROWS[0], W - 1, ROAD_ROWS[1], DIRT)
	_fill(SOUTH_COLS[0], ROAD_ROWS[1] + 1, SOUTH_COLS[1], 44, DIRT)
	_fill(GATE2[0].x, ROAD_ROWS[1] + 1, GATE2[1].x, PADDOCK2.position.y, DIRT)
	_fill(PADDOCK3.end.x - 1, 38, SOUTH_COLS[0], 39, DIRT)
	_lake(Vector2(62, 39), 5.5, 3.2, 0.3, 4471)


## 围一圈栅栏，gates 里的格子留口。
func _fence_rect(r: Rect2i, gates: Array[Vector2i]) -> void:
	var f: Dictionary = {}
	for x in range(r.position.x, r.end.x):
		f[Vector2i(x, r.position.y)] = true
		f[Vector2i(x, r.end.y - 1)] = true
	for y in range(r.position.y, r.end.y):
		f[Vector2i(r.position.x, y)] = true
		f[Vector2i(r.end.x - 1, y)] = true
	for g in gates:
		f.erase(g)
	for t: Vector2i in f:
		var m := 0
		if f.has(t + Vector2i(0, -1)):
			m |= 1
		if f.has(t + Vector2i(1, 0)):
			m |= 2
		if f.has(t + Vector2i(0, 1)):
			m |= 4
		if f.has(t + Vector2i(-1, 0)):
			m |= 8
		_prop("fence_%d" % m, tile_center(t))
		_block(t)


func _place_new() -> void:
	_reserve(PADDOCK2.position.x, PADDOCK2.position.y - 1, PADDOCK2.end.x - 1, PADDOCK2.end.y - 1)
	_reserve(PADDOCK3.position.x, PADDOCK3.position.y, PADDOCK3.end.x - 1, PADDOCK3.end.y - 1)
	_new_edge_trees(OLD_W, OLD_H, NEW_TREES)
	# 路北：新草料棚和蜂箱
	_building("barn", 58, 13, 6, 4, true)
	_wall_clue(58, 13, 6, "新盖的草料棚。梁上还留着锯末的味道，里面的草堆到了顶")
	for hx in [46, 50]:
		var pos := Vector2((hx + 1.5) * TS, 9 * TS - 2)
		_prop("apiary", pos)
		_ground_shadow(pos + Vector2(0, -1), Px.tex(PixelArt.shadow(44, 6, 0.22)))
		_block_rect(hx, 8, hx + 2, 8)
		_clue(Vector2i(hx + 1, 9), "新分出来的蜂箱。盖子上用炭画了个圈，大概是记号")
	_wide_prop("drying_rack", Vector2i(68, 12), 2, "架子上晾着一排割下来的牧草，翻得很匀")
	# 歇着的草场和羊圈
	_fence_rect(PADDOCK2, GATE2)
	_small_prop("stool", Vector2i(62, 17), "门口的木墩上放着一只豁口的碗。草场歇着，草长到了膝盖")
	_fence_rect(PADDOCK3, GATE3)
	_small_prop("stool", Vector2i(47, 37), "羊圈的门闩上挂着一只铜铃，铃舌用布条缠住了")
	_scatter_inside(PADDOCK3)
	# 南边：水塘、井、石灯、长凳
	_building("well", 52, 31, 2, 2, false)
	_wall_clue(52, 31, 2, "牧场的井，绳子磨得发亮。井沿上有一圈圈蹄子大小的湿印")
	_wide_prop("bench", Vector2i(55, 35), 2, "长凳对着水塘。坐在这儿，能同时看到两只鸭子打架")
	_small_prop("scarecrow", Vector2i(54, 41), "稻草人戴着一顶旧斗笠，帽檐底下什么也没有")
	_wide_prop("wood_pile", Vector2i(46, 44), 2, "码好的木柴，最上面一根还带着树皮")
	for t: Vector2i in [Vector2i(49, 20), Vector2i(49, 28), Vector2i(53, 40), Vector2i(53, 20), Vector2i(66, 16)]:
		if _is_free(t) and terrain[idx(t)] != WATER:
			_lamp_post(t)
	for t: Vector2i in [Vector2i(57, 36), Vector2i(58, 43), Vector2i(66, 36), Vector2i(67, 40), Vector2i(60, 35)]:
		if _is_free(t) and terrain[idx(t)] != WATER:
			_tree("willow%d" % (t.x % 2), t)
	for t: Vector2i in [Vector2i(69, 34), Vector2i(40, 46)]:
		if _is_free(t):
			_small_prop("rock_%d" % (t.x % 2), t)
	_grove(Rect2i(OLD_W, 0, W - OLD_W, 7), 22, NEW_TREES)
	_grove(Rect2i(0, OLD_H, 34, H - OLD_H), 18, NEW_TREES)
	_grove(Rect2i(70, 28, 6, 20), 22, NEW_TREES)
	_grove(Rect2i(52, 44, 24, 4), 22, NEW_TREES)
	_sprinkle_grass(Rect2i(OLD_W, 0, W - OLD_W, OLD_H), 41)
	_sprinkle_grass(Rect2i(0, OLD_H, W, H - OLD_H), 42)


## 圈里不长树，只撒点草，免得秃着。
func _scatter_inside(r: Rect2i) -> void:
	_sprinkle_grass(r.grow(-1), 43)
