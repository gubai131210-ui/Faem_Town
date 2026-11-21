extends WildMap
## 后山：山祠再往上。溪夏天涨、冬天冻，春秋从踏脚的石头过（决策 127）。
## 夔只在雷雨里，毕方旱天才来点崖洞的灯，玉兔月圆夜里捣药，当康秋天出现，白泽在山顶。
## 五只用已经画好的序列帧。耳鼠在南边路上，拿一道菜就跟着回家（决策 129）。

## 老后山是左上角 32×30；往东、往南扩到 56×48，老坐标一格不动（决策 155）。
const OLD_W := 32
const OLD_H := 30
const W := 56
const H := 48
const NEW_TREES: Array[String] = ["old0", "pine0", "old1", "pine1", "round0", "old2"]
## 南边横路的两行
const SOUTH_ROWS: Array[int] = [34, 35]
const STREAM_Y := 15
const FORD_X0 := 15
const FORD_X1 := 16
const FALL := [
	Vector2i(18, 10), Vector2i(19, 10), Vector2i(18, 11), Vector2i(19, 11),
	Vector2i(18, 12), Vector2i(19, 12), Vector2i(18, 13), Vector2i(19, 13),
	Vector2i(18, 14), Vector2i(19, 14),
]
const SIGN := Vector2i(14, 16)
const CAVE := Vector2i(5, 20)
const BIFANG := Vector2i(8, 20)
const KUI := Vector2i(23, 20)
const DANG := Vector2i(26, 24)
const ER := Vector2i(16, 22)
const BAIZE := Vector2i(16, 3)
const YUTU := Vector2i(12, 5)
const KUI_HP := 30
const TREES: Array[Vector2i] = [
	Vector2i(3, 6), Vector2i(8, 4), Vector2i(24, 5), Vector2i(28, 8),
	Vector2i(9, 26), Vector2i(28, 18), Vector2i(3, 26), Vector2i(27, 27),
]

var _kui_hp := KUI_HP
var _kui: Sprite2D
var _baize: Sprite2D
var _bifang: Sprite2D
var _yutu: Sprite2D
var _dang: Sprite2D
var _er: Sprite2D
var _sheets: Dictionary = {}
var _bite_wait := 0.0


func _ready() -> void:
	map_id = &"houshan"
	combat = true
	_rng.seed = 20261127
	_setup_wild(W, H)
	_layout()
	_layout_new()
	_build_ground()
	_make_entities()
	_place()
	_place_new()
	_make_water_fx(24)
	_sync_beasts()


func _process(delta: float) -> void:
	super._process(delta)
	_sync_beasts()
	_animate()
	_bite(delta)


func spawn_position(_spawn: StringName) -> Vector2:
	return tile_center(Vector2i(FORD_X0, 26)) + Vector2(8, 0)


func spawn_facing(_spawn: StringName) -> Facing:
	return Facing.UP


func trigger_at(tile: Vector2i) -> Dictionary:
	if tile.y == H - 1 and (tile.x == FORD_X0 or tile.x == FORD_X1):
		return {"map": &"shanci", "spawn": &"from_houshan"}
	return {}


func fishing_water(_tile: Vector2i) -> StringName:
	return &""


func query_use(item: ItemDef, tile: Vector2i, _facing: Facing) -> StringName:
	if item != null and item.kind == &"weapon" and tile == KUI and _kui_out():
		return &"attack"
	if Bestiary.is_dish(item) and tile == ER and _er_out():
		return &"offer"
	if clue_at(tile) != "":
		return &"interact"
	if item != null and item.kind == &"weapon":
		return &"attack"
	return &""


func perform(action: StringName, item: ItemDef, tile: Vector2i, _quiet: bool = false) -> void:
	if action == &"offer" and tile == ER and item != null and _er_out():
		_offer_mouse(item)
		return
	if action != &"interact":
		return
	var text := clue_at(tile)
	if text == "":
		return
	if tile == SIGN:
		Bestiary.hear(&"kui")
	elif tile == BIFANG and _bifang_out():
		Bestiary.know(&"bifang")
	elif tile == BAIZE:
		Bestiary.see(&"baize")
		if Story.side_ready(Story.NAMED):
			EventBus.dialogue_requested.emit(Story.DIALOGUE, "offer_named")
			return
	elif tile == YUTU and _yutu_out():
		Bestiary.know(&"yutu")
	elif tile == DANG and _dang_out():
		Bestiary.know(&"dangkang")
		# 对着它按使用的这一天，农场多收一个；天数记在种田的存档里
		Farming.note_dangkang()
	elif tile == KUI and _kui_out():
		Bestiary.see(&"kui")
	elif tile == ER and _er_out():
		Bestiary.see(&"ershu")
	EventBus.banner_requested.emit(text)


func clue_at(tile: Vector2i) -> String:
	if clues.has(tile):
		return clues[tile]
	if tile == SIGN:
		return "石上刻着：夏天水涨。冬天冻上了就能过。"
	if tile == CAVE:
		if Bestiary.known(&"bifang"):
			return "崖洞里的灯点着了。是毕方引的火。"
		return "崖洞。口子不大，里面黑着。"
	if tile == BIFANG and _bifang_out():
		return "毕方。一只脚的鸟，身上像有火。它朝崖洞偏了偏头，洞里的灯亮了。"
	if tile == BAIZE:
		return "白泽。它把你已经听说过的那些，忌讳都说了一遍。"
	if tile == YUTU and _yutu_out():
		return "玉兔在月下捣药。捣完它把药留在石臼里，说是给药铺的。"
	if tile == DANG and _dang_out():
		return "当康。叫声像在叫自己的名字。它来的这天，是个好年成。"
	if tile == KUI and _kui_out():
		return "夔。一只脚，雷雨就是它的声音。"
	if tile == ER and _er_out():
		return "耳鼠。粉红的，背上有翅膀。它看着你手里的菜。"
	if _is_fall(tile):
		return "瀑布从崖上流下来。"
	if tile.y == STREAM_Y:
		if _winter():
			return "溪冻上了，走得过去。"
		if _summer() and _is_ford(tile):
			return "水涨过了踏脚的石头。"
		if _is_ford(tile):
			return "踏脚的石头还露出水面。"
		return "溪水从瀑布那边过来。"
	return ""


func apply_hit(damage: int) -> int:
	if not _kui_out() or damage <= 0:
		return -1
	Bestiary.see(&"kui")
	_kui_hp = maxi(0, _kui_hp - damage)
	if _kui_hp > 0:
		EventBus.banner_requested.emit("夔挨了一下，雷还响着。")
		return _kui_hp
	Bestiary.know(&"kui")
	_clear(_kui)
	_kui = null
	EventBus.banner_requested.emit("夔散了。雨还在下，只是不再跟着你。")
	return 0


func weapon_hit(weapon: WeaponDef, step: int, skill: bool) -> int:
	var who := player as Player
	if who == null or weapon == null or not _kui_out():
		return 0
	var origin := who.position
	var dir: Vector2 = Player.DIR_VECTORS[who.facing]
	if not weapon.hits(origin, dir, tile_center(KUI) + Vector2(0, -8), 8.0):
		return 0
	var damage := weapon.skill_damage() if skill else weapon.damage_at(step)
	return 1 if apply_hit(damage) >= 0 else 0


func kui_out() -> bool:
	return _kui_out()


func _layout() -> void:
	for t in FALL:
		_set_water(t)
	for x in W:
		var t := Vector2i(x, STREAM_Y)
		if _winter():
			_set_water(t)
			solid[idx(t)] = 0
		elif _is_ford(t) and not _summer():
			terrain[idx(t)] = DIRT
			solid[idx(t)] = 0
		else:
			_set_water(t)
	for y in range(4, 15):
		_dirt(Vector2i(FORD_X0, y))
		_dirt(Vector2i(FORD_X1, y))
	for y in range(16, H - 1):
		_dirt(Vector2i(FORD_X0, y))
		_dirt(Vector2i(FORD_X1, y))
	for x in range(6, FORD_X0):
		_dirt(Vector2i(x, 20))
	for x in range(12, FORD_X0):
		_dirt(Vector2i(x, 5))


func _place() -> void:
	for y in H:
		for x in W:
			if x == 0 or y == 0 or x == W - 1 or (y == H - 1 and x != FORD_X0 and x != FORD_X1):
				_block(Vector2i(x, y))
	if _winter():
		var sheet := Px.tex(MountainArt.ice())
		for x in W:
			var t := Vector2i(x, STREAM_Y)
			var ice := _sprite(sheet, Vector2(t.x * TS, t.y * TS), Vector2.ZERO)
			ice.z_index = -8
	var cave := MountainArt.cave()
	_sprite(Px.tex(cave), tile_center(CAVE) + Vector2(0, 6), Vector2(-cave.get_width() / 2.0, -float(cave.get_height())))
	_block(CAVE)
	_hang_clue(SIGN, BambooArt.marker(), 4.0)
	var tree := Px.tex(PixelArt.round_tree(0, GameClock.season()))
	for t in TREES:
		if _on_path(t) or t.y == STREAM_Y:
			continue
		var spr := _sprite(tree, tile_center(t) + Vector2(0, 8), Vector2(-22, -57))
		spr.material = _tree_mat
		_block(t)
	for t in [Vector2i(10, 18), Vector2i(21, 12), Vector2i(7, 26)]:
		var rp := tile_center(t) + Vector2(0, 6)
		_prop("rock_%d" % (t.x % 2), rp)
		_block(t)
	_block(BAIZE)


func _dirt(t: Vector2i) -> void:
	if not in_map(t) or t.y == STREAM_Y or _is_fall(t):
		return
	terrain[idx(t)] = DIRT
	solid[idx(t)] = 0


func _on_path(t: Vector2i) -> bool:
	if t.y == STREAM_Y:
		return false
	if (t.x == FORD_X0 or t.x == FORD_X1) and t.y >= 4 and t.y <= 28:
		return true
	if t.y == 20 and t.x >= 6 and t.x < FORD_X0:
		return true
	if t.y == 5 and t.x >= 12 and t.x < FORD_X0:
		return true
	return false


func _is_ford(t: Vector2i) -> bool:
	return t.y == STREAM_Y and t.x >= FORD_X0 and t.x <= FORD_X1


func _is_fall(t: Vector2i) -> bool:
	for spot in FALL:
		if spot == t:
			return true
	return false


func _summer() -> bool:
	return GameClock.season() == 1


func _winter() -> bool:
	return GameClock.season() == 3


func _drought() -> bool:
	if not _summer():
		return false
	return Weather.today == Weather.SUNNY or Weather.today == Weather.WIND or Weather.today == Weather.CLOUDY


func _full_moon() -> bool:
	return GameClock.day % 8 == 1 and GameClock.minutes >= 1140.0 + GameClock.dusk_shift()


func _kui_out() -> bool:
	return Weather.today == Weather.STORM and not Bestiary.known(&"kui")


func _bifang_out() -> bool:
	return _drought() and not Bestiary.known(&"bifang")


func _yutu_out() -> bool:
	return _full_moon() and not Bestiary.known(&"yutu")


func _dang_out() -> bool:
	return GameClock.season() == 2


func _er_out() -> bool:
	return not Bestiary.bonded(&"ershu")


func _offer_mouse(item: ItemDef) -> void:
	if not GameState.inventory.remove(item.id, 1):
		EventBus.banner_requested.emit("手里没有这道菜。")
		return
	Bestiary.bond(&"ershu")
	EventBus.banner_requested.emit("它接过菜，翅膀扇了扇，跟着你了。")


func _sync_beasts() -> void:
	_kui = _show(_kui, _kui_out(), "kui", KUI, Facing.DOWN)
	if _baize == null:
		_baize = _actor("baize", BAIZE, Facing.DOWN)
	_bifang = _show(_bifang, _bifang_out(), "bifang", BIFANG, Facing.DOWN)
	_yutu = _show(_yutu, _yutu_out(), "yutu", YUTU, Facing.DOWN)
	_dang = _show(_dang, _dang_out(), "dangkang", DANG, Facing.DOWN)
	_er = _show(_er, _er_out(), "ershu", ER, Facing.RIGHT)
	_hold(KUI, _kui != null)
	_hold(BIFANG, _bifang != null)
	_hold(YUTU, _yutu != null)
	_hold(DANG, _dang != null)
	_hold(ER, _er != null)


func _show(spr: Sprite2D, on: bool, sheet_name: String, tile: Vector2i, facing: Facing) -> Sprite2D:
	if on:
		if spr == null:
			return _actor(sheet_name, tile, facing)
		return spr
	_clear(spr)
	return null


func _hold(tile: Vector2i, on: bool) -> void:
	if on:
		_block(tile)
	elif in_map(tile):
		solid[idx(tile)] = 0
		occupied.erase(tile)


func _clear(spr: Sprite2D) -> void:
	if spr != null:
		spr.queue_free()


func _actor(sheet_name: String, tile: Vector2i, facing: Facing) -> Sprite2D:
	if not _sheets.has(sheet_name):
		_sheets[sheet_name] = CharacterSheet.load_sheet(sheet_name, CharacterSheet.CREATURE_DIR)
	var sheet: CharacterSheet = _sheets[sheet_name]
	var spr := Sprite2D.new()
	spr.texture = sheet.texture
	spr.centered = false
	spr.region_enabled = true
	spr.region_rect = sheet.region(&"idle", facing, 0)
	spr.offset = Vector2(-sheet.cell / 2.0, -float(sheet.foot_row))
	spr.position = tile_center(tile) + Vector2(0, 4)
	spr.set_meta(&"face", facing)
	entities.add_child(spr)
	return spr


func _animate() -> void:
	for spr in [_kui, _baize, _bifang, _yutu, _dang]:
		if spr == null or not is_instance_valid(spr):
			continue
		var who := ""
		if spr == _kui:
			who = "kui"
		elif spr == _baize:
			who = "baize"
		elif spr == _bifang:
			who = "bifang"
		elif spr == _yutu:
			who = "yutu"
		else:
			who = "dangkang"
		if not _sheets.has(who):
			continue
		var sheet: CharacterSheet = _sheets[who]
		var count := sheet.frame_count(&"idle")
		var frame := int(_time * sheet.fps(&"idle")) % maxi(count, 1)
		spr.region_rect = sheet.region(&"idle", int(spr.get_meta(&"face", Facing.DOWN)), frame)


func _bite(delta: float) -> void:
	_bite_wait = maxf(0.0, _bite_wait - delta)
	if player == null or _bite_wait > 0.0 or not _kui_out():
		return
	var who := player as Player
	if who == null or who.invincible():
		return
	if who.position.distance_to(tile_center(KUI)) > 22.0:
		return
	_bite_wait = 1.4
	who.hurt(who.position - tile_center(KUI))
	GameState.hurt(8)


# ---------------------------------------------------------------- 往东、往南扩出来的部分

func _layout_new() -> void:
	for x in range(FORD_X1 + 1, 52):
		for y in SOUTH_ROWS:
			_dirt(Vector2i(x, y))
	for x in range(4, FORD_X0):
		_dirt(Vector2i(x, 40))
	_lake(Vector2(41, 41), 5.0, 3.0, 0.3, 9931)


func _place_new() -> void:
	_reserve(FORD_X0, OLD_H, FORD_X1, H - 1)
	_new_edge_trees(OLD_W, OLD_H, NEW_TREES)
	_building("earth_shrine", 24, 33, 2, 2, false)
	_wall_clue(24, 33, 2, "路边小小的山神祠。供的不是神像，是一块被摸得发亮的石头")
	_wide_prop("drying_rack", Vector2i(30, 32), 2, "晾着一排叫不出名字的草药，叶子上还有水")
	_wide_prop("wood_pile", Vector2i(20, 32), 2, "柴垛上落了层松针，很久没人动过")
	_small_prop("jar_clay", Vector2i(5, 38), "药罐。盖子上用炭写了一个字，被雨水冲掉了一半")
	var cave := MountainArt.cave()
	var cave_tile := Vector2i(50, 32)
	_sprite(Px.tex(cave), tile_center(cave_tile) + Vector2(0, 6), Vector2(-cave.get_width() / 2.0, -float(cave.get_height())))
	_block(cave_tile)
	_clue(cave_tile + Vector2i(0, 1), "另一个崖洞。里面没有灯，只有一股凉气从深处吹出来")
	_small_prop("rock_0", Vector2i(36, 30), "石头上有一排小小的蹄印，一直通到溪边")
	_small_prop("rock_1", Vector2i(46, 38), "")
	for t: Vector2i in [Vector2i(18, 33), Vector2i(26, 36), Vector2i(34, 33), Vector2i(42, 36)]:
		if _is_free(t):
			_lamp_post(t)
	_grove(Rect2i(OLD_W, 0, W - OLD_W, 14), 20, NEW_TREES)
	_grove(Rect2i(OLD_W, 16, W - OLD_W, 14), 22, NEW_TREES)
	_grove(Rect2i(0, OLD_H, W, 3), 20, NEW_TREES)
	_grove(Rect2i(0, 36, W, 12), 20, NEW_TREES)
	_sprinkle_grass(Rect2i(OLD_W, 0, W - OLD_W, OLD_H), 81)
	_sprinkle_grass(Rect2i(0, OLD_H, W, H - OLD_H), 82)
