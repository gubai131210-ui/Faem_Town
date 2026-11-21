extends WildMap
## 雾岛：东滩坐船娘的船过来。潮水涨落决定潮洞走不走得通（决策 128）。
## 精卫帮过以后退潮拖到傍晚。鲛人在潮洞，拿海螺换珠。文鳐夜里飞。三只用已经画好的序列帧。
## 珠不进背包。结缘、养在池塘里、收成加成都不在这一批。

## 老雾岛是左上角 32×26；往东、往南扩到 48×42，老坐标一格不动（决策 156）。
const OLD_W := 32
const OLD_H := 26
const W := 48
const H := 42
## 东南角小沙洲的圆心
const ISLET := Vector2(38.0, 33.0)
const DOCK_X0 := 16
const DOCK_X1 := 17
const CAVE := Vector2i(7, 12)
const PEARL := Vector2i(7, 13)
const JING := Vector2i(17, 9)
const JIAO := Vector2i(7, 12)
const WEN := Vector2i(21, 11)
const SIGN := Vector2i(15, 16)
const SHELL := &"conch"
## 没帮精卫，正午涨潮。帮过，拖到傍晚。
const LOW_UNTIL := 720.0
const LONG_UNTIL := 1080.0
const TIDE: Array[Vector2i] = [
	Vector2i(8, 12), Vector2i(9, 12), Vector2i(10, 12), Vector2i(11, 12),
]
const ROCKS: Array[Vector2i] = [Vector2i(13, 10), Vector2i(20, 14), Vector2i(18, 15)]

var _jing: Sprite2D
var _jiao: Sprite2D
var _wen: Sprite2D
var _pearl: Sprite2D
var _sheets: Dictionary = {}
var _covers: Dictionary[Vector2i, Sprite2D] = {}
var _tide_tex: Array[Texture2D] = []
var _tide_set := false
var _low_now := false


func _ready() -> void:
	map_id = &"wudao"
	combat = true
	_setup_wild(W, H)
	_layout()
	_layout_new()
	_build_ground()
	_make_entities()
	for i in TIDE.size():
		_tide_tex.append(_sea_patch(i))
	_place()
	_place_new()
	_make_water_fx(36)
	_sync_tide()
	_sync_beasts()
	_sync_pearl()


func _process(delta: float) -> void:
	super._process(delta)
	_sync_tide()
	_sync_beasts()
	_sync_pearl()
	_animate()


func spawn_position(_spawn: StringName) -> Vector2:
	return tile_center(Vector2i(DOCK_X0, 22)) + Vector2(8, 0)


func spawn_facing(_spawn: StringName) -> Facing:
	return Facing.UP


func trigger_at(tile: Vector2i) -> Dictionary:
	if tile.y == H - 1 and (tile.x == DOCK_X0 or tile.x == DOCK_X1):
		return {"map": &"dongtan", "spawn": &"from_wudao"}
	return {}


func fishing_water(_tile: Vector2i) -> StringName:
	return &""


func query_use(item: ItemDef, tile: Vector2i, _facing: Facing) -> StringName:
	if item != null and item.id == SHELL and tile == JIAO and _jiao_out() and not Bestiary.known(&"jiaoren"):
		return &"offer"
	if clue_at(tile) != "":
		return &"interact"
	if item != null and item.kind == &"weapon":
		return &"attack"
	return &""


func perform(action: StringName, item: ItemDef, tile: Vector2i, _quiet: bool = false) -> void:
	if action == &"offer" and tile == JIAO and item != null and item.id == SHELL and _jiao_out():
		_offer_shell()
		return
	if action != &"interact":
		return
	var text := clue_at(tile)
	if text == "":
		return
	if tile == SIGN:
		Bestiary.hear(&"jingwei")
	elif tile == JING and _jing_out():
		Bestiary.know(&"jingwei")
	elif tile == JIAO and _jiao_out():
		Bestiary.see(&"jiaoren")
	elif tile == WEN and _wen_out():
		Bestiary.know(&"wenyao")
	EventBus.banner_requested.emit(text)


func clue_at(tile: Vector2i) -> String:
	if clues.has(tile):
		return clues[tile]
	if tile == SIGN:
		return "石上刻着：早上潮退，午后涨。有鸟衔石填海。"
	if tile == JING and _jing_out():
		return "精卫。黑身子，红脚，嘴里衔着石子。你把脚边的石子捧给她，她投进海里。"
	if tile == JIAO and _jiao_out():
		if Bestiary.known(&"jiaoren"):
			return "鲛人还在洞口。珠在旁边的沙上，是热的。"
		return "鲛人。眼睛是湿的。她看着你手里，像在等一只海螺。"
	if tile == WEN and _wen_out():
		return "文鳐贴着海面飞过去。见着它的这天，是个好年成。"
	if tile == CAVE and not _low():
		return "潮水涨进洞里，走不过去。"
	if _is_tide(tile) and not _low():
		return "潮水没过了这条沙。"
	if _is_tide(tile):
		return "沙还露着，洞口走得过。"
	return ""


func jing_out() -> bool:
	return _jing_out()


func jiao_out() -> bool:
	return _jiao_out()


func wen_out() -> bool:
	return _wen_out()


func low_tide() -> bool:
	return _low()


func _layout() -> void:
	for y in H:
		for x in W:
			_set_water(Vector2i(x, y))
	for y in range(8, 17):
		for x in range(12, 23):
			_open(Vector2i(x, y), SAND)
	for y in range(10, 15):
		for x in range(14, 21):
			_open(Vector2i(x, y), GRASS)
	for y in range(8, H):
		_open(Vector2i(DOCK_X0, y), SAND)
		_open(Vector2i(DOCK_X1, y), SAND)
	for y in range(11, 14):
		_open(Vector2i(7, y), SAND)
	for t in TIDE:
		_open(t, SAND)


func _place() -> void:
	for y in H:
		for x in W:
			if x == 0 or y == 0 or x == W - 1 or (y == H - 1 and x != DOCK_X0 and x != DOCK_X1):
				_block(Vector2i(x, y))
	var cave := MountainArt.cave()
	_sprite(Px.tex(cave), tile_center(CAVE) + Vector2(0, 6), Vector2(-cave.get_width() / 2.0, -float(cave.get_height()) + 14.0))
	_hang_clue(SIGN, BambooArt.marker(), 4.0)
	for t in ROCKS:
		var rp := tile_center(t) + Vector2(0, 6)
		_prop("rock_%d" % (t.x % 2), rp)
		_block(t)


func _open(t: Vector2i, ground: int) -> void:
	if not in_map(t):
		return
	terrain[idx(t)] = ground
	solid[idx(t)] = 0


func _sync_tide() -> void:
	var low := _low()
	if _tide_set and low == _low_now:
		return
	var rising := _tide_set and _low_now and not low
	_tide_set = true
	_low_now = low
	for i in TIDE.size():
		var t: Vector2i = TIDE[i]
		if low:
			solid[idx(t)] = 0
			_uncap(t)
		else:
			solid[idx(t)] = 1
			_cap(t, i)
	if rising:
		_wash()


## 涨潮盖上去的是这张海里的一格，不另涂一种蓝。
func _sea_patch(mark: int) -> Texture2D:
	var img := _ground_image()
	var origin := Vector2i((2 + mark) * TS, 3 * TS)
	return ImageTexture.create_from_image(img.get_region(Rect2i(origin.x, origin.y, TS, TS)))


func _ground_image() -> Image:
	for child in get_children():
		var spr := child as Sprite2D
		if spr != null and spr.z_index == -10 and spr.texture != null:
			return spr.texture.get_image()
	return Image.create(TS, TS, false, Image.FORMAT_RGBA8)


func _cap(t: Vector2i, mark: int) -> void:
	if _covers.has(t):
		return
	var spr := Sprite2D.new()
	spr.texture = _tide_tex[mark]
	spr.centered = false
	spr.position = Vector2(t.x * TS, t.y * TS)
	spr.z_index = -8
	add_child(spr)
	_covers[t] = spr


func _uncap(t: Vector2i) -> void:
	if not _covers.has(t):
		return
	var spr: Sprite2D = _covers[t]
	_covers.erase(t)
	spr.queue_free()


func _wash() -> void:
	if player == null:
		return
	var who := player as Player
	if who == null or not _is_tide(tile_of(who.position)):
		return
	who.position = spawn_position(&"landing")
	EventBus.banner_requested.emit("潮水涨上来了。")


func _low() -> bool:
	var until := LONG_UNTIL if Bestiary.known(&"jingwei") else LOW_UNTIL
	return GameClock.minutes < until


func _night() -> bool:
	return GameClock.minutes >= 1140.0 + GameClock.dusk_shift()


func _is_tide(t: Vector2i) -> bool:
	for spot in TIDE:
		if spot == t:
			return true
	return false


func _jing_out() -> bool:
	return not Bestiary.known(&"jingwei")


func _jiao_out() -> bool:
	return _low() and not _is_tide(JIAO)


func _wen_out() -> bool:
	return _night()


func _sync_beasts() -> void:
	_jing = _show(_jing, _jing_out(), "jingwei", true, JING, Facing.RIGHT)
	_jiao = _show(_jiao, _jiao_out(), "jiaoren", false, JIAO, Facing.DOWN)
	_wen = _show(_wen, _wen_out(), "wenyao", true, WEN, Facing.RIGHT)
	_hold(JING, _jing != null)
	_hold(JIAO, _jiao != null)
	_hold(WEN, _wen != null)


func _sync_pearl() -> void:
	var on := Bestiary.known(&"jiaoren")
	if on and _pearl == null:
		var img := MountainArt.pearl()
		_pearl = _sprite(Px.tex(img), tile_center(PEARL) + Vector2(0, 4), Vector2(-img.get_width() / 2.0, -float(img.get_height())))
	elif not on and _pearl != null:
		_pearl.queue_free()
		_pearl = null


func _show(spr: Sprite2D, on: bool, sheet_name: String, creature: bool, tile: Vector2i, facing: Facing) -> Sprite2D:
	if on:
		if spr == null:
			return _actor(sheet_name, creature, tile, facing)
		return spr
	_clear(spr)
	return null


func _hold(tile: Vector2i, on: bool) -> void:
	if on:
		_block(tile)
	elif in_map(tile) and not _is_tide(tile):
		solid[idx(tile)] = 0
		occupied.erase(tile)


func _clear(spr: Sprite2D) -> void:
	if spr != null:
		spr.queue_free()


func _actor(sheet_name: String, creature: bool, tile: Vector2i, facing: Facing) -> Sprite2D:
	var folder := CharacterSheet.CREATURE_DIR if creature else CharacterSheet.DIR
	if not _sheets.has(sheet_name):
		_sheets[sheet_name] = CharacterSheet.load_sheet(sheet_name, folder)
	var sheet: CharacterSheet = _sheets[sheet_name]
	var anim := &"flap" if sheet.has_anim(&"flap") and not sheet.has_anim(&"idle") else &"idle"
	var spr := Sprite2D.new()
	spr.texture = sheet.texture
	spr.centered = false
	spr.region_enabled = true
	spr.region_rect = sheet.region(anim, facing, 0)
	spr.offset = Vector2(-sheet.cell / 2.0, -float(sheet.foot_row))
	spr.position = tile_center(tile) + Vector2(0, 4)
	spr.set_meta(&"who", sheet_name)
	spr.set_meta(&"face", facing)
	spr.set_meta(&"anim", anim)
	entities.add_child(spr)
	return spr


func _animate() -> void:
	for spr in [_jing, _jiao, _wen]:
		if spr == null or not is_instance_valid(spr):
			continue
		var who := str(spr.get_meta(&"who", ""))
		if not _sheets.has(who):
			continue
		var sheet: CharacterSheet = _sheets[who]
		var anim := StringName(str(spr.get_meta(&"anim", &"idle")))
		var count := sheet.frame_count(anim)
		var frame := int(_time * sheet.fps(anim)) % maxi(count, 1)
		spr.region_rect = sheet.region(anim, int(spr.get_meta(&"face", Facing.DOWN)), frame)


func _offer_shell() -> void:
	if not GameState.inventory.remove(SHELL, 1):
		EventBus.banner_requested.emit("手里没有海螺。")
		return
	Bestiary.know(&"jiaoren")
	EventBus.banner_requested.emit("她接过海螺，哭出一颗珠。珠落在旁边的沙上，是热的。")


# ---------------------------------------------------------------- 往东、往南扩出来的部分

func _layout_new() -> void:
	# 码头的沙埂接长到新的南边缘；半路往东分出一条沙埂，通到东南角的小沙洲
	for x in range(DOCK_X1 + 1, 34):
		for y in [32, 33]:
			_open(Vector2i(x, y), SAND)
	for t in _blob(ISLET, 6.5, 4.5, 0.25, 6611):
		_open(t, SAND)
	for t in _blob(ISLET, 4.5, 2.8, 0.2, 6612):
		_open(t, GRASS)


func _place_new() -> void:
	_new_edge_trees(OLD_W, OLD_H, ["pine0", "pine1"])
	_small_prop("rock_0", Vector2i(40, 31), "石头缝里夹着一只干了的海星，颜色还是红的")
	_small_prop("rock_1", Vector2i(35, 35), "")
	_wide_prop("wood_pile", Vector2i(36, 32), 2, "浮木堆成一小垛，不知道是谁堆的，也不知道要烧给谁")
	_wide_prop("bench", Vector2i(39, 35), 2, "石头和木板拼的凳子，朝着东边坐")
	_small_prop("jar_clay", Vector2i(41, 33), "坛子里是半坛清水，水面上浮着一片羽毛")
	for t: Vector2i in [Vector2i(37, 31), Vector2i(42, 34)]:
		if _is_free(t):
			_tree("pine%d" % (t.x % 2), t)
	_lamp_post(Vector2i(24, 31))
	_clue(Vector2i(29, 33), "沙埂在这里被潮水舔得很窄。再往东，脚印是新的")
	_clue(Vector2i(DOCK_X0, 40), "沙埂尽头的海水一直涨到脚边，远处有一线白，是浪还是帆，看不清")
