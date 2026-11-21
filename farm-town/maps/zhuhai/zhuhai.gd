extends WildMap
## 竹海：河埠的桥接过来。夜里和雾天不一样。
## 山魈夜里学人说话，往东边的死路引；狌狌要米酒；乘黄白天蹲在西边，见过以后只在竹海里跟着走。
## 三只都用已经画好的序列帧。武器和翻滚在这张图上能用。
## 饕餮要四道没吃过的菜。雾天腓腓在路上，结缘以后回家（决策 129）。

## 老竹海是左上角 34×26；往东、往南扩到 52×42，老坐标一格不动（决策 157）。
## 竹子是按坐标哈希种的，不吃随机数，所以不需要鬼树钩子。
const OLD_W := 34
const OLD_H := 26
const W := 52
const H := 42
## 新的空地：东南一块竹林里的小广场，一条横路通到它
const PLAZA := Rect2i(30, 30, 10, 6)
const EAST_ROWS: Array[int] = [34, 35]
const SIGN := Vector2i(15, 11)
const PRINTS := Vector2i(12, 12)
const CHENG := Vector2i(7, 7)
const BOWL := Vector2i(10, 7)
const SHAN := Vector2i(22, 11)
const VOICE := Vector2i(22, 12)
const DEAD := Vector2i(26, 12)
const WINE := &"rice_wine"
const TAO := Vector2i(17, 16)
const FEI := Vector2i(16, 14)
const SHAN_HP := 24
## 见过乘黄、人还在竹海里、又是白天，走路速度再乘这个数。写在 Player.slow 上，不用食物的 swift。
const CHENG_PACE := 1.15
## 跟着走比人加快以后稍快一点，才停得住在大约一格外，一帧也迈不过一格竹子。
const CHENG_FOLLOW := 100.0

var _shan_hp := SHAN_HP
var _shan: Sprite2D
var _cheng: Sprite2D
var _xing: Sprite2D
var _tao: Sprite2D
var _fei: Sprite2D
var _bowl: Sprite2D
var _sheets: Dictionary = {}
var _said_voice := false
var _bite_wait := 0.0


func _ready() -> void:
	map_id = &"zhuhai"
	combat = true
	_rng.seed = 20261126
	_setup_wild(W, H)
	_layout()
	_build_ground()
	_make_entities()
	_place()
	_place_new()
	_make_water_fx(36)
	_sync_beasts()


func _process(delta: float) -> void:
	super._process(delta)
	_sync_beasts()
	_follow_cheng(delta)
	_apply_cheng_pace()
	_animate()
	_voice()
	_bite(delta)


func _exit_tree() -> void:
	# 加快只在竹海里。人还在这张图上，或身上仍是这一档，卸掉时收回。
	# 换图时 place() 会先把 slow 写成 1；下一张图要是已经改过步速，这里不盖。
	if is_instance_valid(player):
		var who := player as Player
		if who != null and (who.map == self or is_equal_approx(who.slow, CHENG_PACE)):
			who.slow = 1.0
	super._exit_tree()


func spawn_position(_spawn: StringName) -> Vector2:
	return tile_center(Vector2i(16, 23)) + Vector2(8, 0)


func spawn_facing(_spawn: StringName) -> Facing:
	return Facing.UP


func trigger_at(tile: Vector2i) -> Dictionary:
	if tile.y == H - 1 and (tile.x == 16 or tile.x == 17):
		return {"map": &"wharf", "spawn": &"from_zhuhai"}
	return {}


func query_use(item: ItemDef, tile: Vector2i, _facing: Facing) -> StringName:
	if item != null and item.kind == &"weapon" and tile == SHAN and _shanxiao_out():
		return &"attack"
	if item != null and item.id == WINE and tile == BOWL and not Bestiary.known(&"xingxing"):
		return &"offer"
	if Bestiary.is_dish(item) and tile == TAO and _tao_out():
		return &"offer"
	if clue_at(tile) != "":
		return &"interact"
	if item != null and item.kind == &"weapon":
		return &"attack"
	return &""


func perform(action: StringName, item: ItemDef, tile: Vector2i, _quiet: bool = false) -> void:
	if action == &"offer" and tile == BOWL and item != null and item.id == WINE:
		_offer_wine()
		return
	if action == &"offer" and tile == TAO and item != null and _tao_out():
		_offer_feast(item)
		return
	if action != &"interact":
		return
	var text := clue_at(tile)
	if text == "":
		return
	if tile == SIGN and not Weather.is_foggy():
		Bestiary.hear(&"shanxiao")
	elif tile == PRINTS:
		Bestiary.hear(&"chenghuang")
	elif tile == BOWL:
		Bestiary.hear(&"xingxing")
	elif tile == CHENG and _day_beast():
		Bestiary.see(&"chenghuang")
	elif tile == SHAN and _shanxiao_out():
		Bestiary.see(&"shanxiao")
	elif tile == FEI and _fei_out():
		Bestiary.bond(&"feifei")
	elif tile == TAO and _tao_out():
		Bestiary.see(&"taotie")
	EventBus.banner_requested.emit(text)


func clue_at(tile: Vector2i) -> String:
	if clues.has(tile):
		return clues[tile]
	if tile == SIGN:
		if Weather.is_foggy():
			return "雾太大，石上的字看不清。"
		return "石上刻着：往西。东边夜里会有人应。"
	if tile == PRINTS:
		return "泥上有一串小蹄印，不像鹿。"
	if tile == BOWL and not Bestiary.known(&"xingxing"):
		return "石台上一只空碗。碗边有酒香，像在等谁。"
	if tile == BOWL:
		return "狌狌蹲在碗边，不再开口。它已经把那段忘了的事说完了。"
	if tile == CHENG and _day_beast():
		# 第一次照面它还没跟。见过再看，才换成跟着走、脚下轻一点。
		if Bestiary.seen(&"chenghuang"):
			return "乘黄跟在后面。脚下轻一点。"
		return "乘黄。像一只狐，背上有一只角。它看了你一眼，没跟着来。"
	if tile == SHAN and _shanxiao_out():
		return "山魈。独脚，红眼睛。它学你咳了一声，朝东边偏了偏头。"
	if tile == TAO and _tao_out():
		return "饕餮。绿身子，黄条纹，嘴张得很大。它不吃打，要没吃过的菜。"
	if tile == FEI and _fei_out():
		return "腓腓。白尾巴缩在雾里。你在它旁边站了一会儿，它跟着你了。"
	if tile == DEAD:
		return "竹子密得过不去。东边到这里就断了。"
	if _is_water(tile):
		return "溪水很浅，竹叶浮在上面。"
	return ""


## 山魈还在，而且这一下打到了。返回打掉以后还剩多少；没打到返回 -1。
func apply_hit(damage: int) -> int:
	if not _shanxiao_out() or damage <= 0:
		return -1
	Bestiary.see(&"shanxiao")
	_shan_hp = maxi(0, _shan_hp - damage)
	if _shan_hp > 0:
		EventBus.banner_requested.emit("山魈挨了一下，还站着。")
		return _shan_hp
	Bestiary.know(&"shanxiao")
	_clear_shan()
	EventBus.banner_requested.emit("山魈散成一缕雾。东边的路还是死的，它不再应你。")
	return 0


func weapon_hit(weapon: WeaponDef, step: int, skill: bool) -> int:
	var who := player as Player
	if who == null or weapon == null or not _shanxiao_out():
		return 0
	var origin := who.position
	var dir: Vector2 = Player.DIR_VECTORS[who.facing]
	if not weapon.hits(origin, dir, tile_center(SHAN) + Vector2(0, -8), 8.0):
		return 0
	var damage := weapon.skill_damage() if skill else weapon.damage_at(step)
	return 1 if apply_hit(damage) >= 0 else 0


func shanxiao_out() -> bool:
	return _shanxiao_out()


## 见过而且是白天返回 1.15，否则 1。夜里乘黄不在，也是 1。不看玩家节点在不在。
func chenghuang_pace() -> float:
	if Bestiary.seen(&"chenghuang") and _day_beast():
		return CHENG_PACE
	return 1.0


func _layout() -> void:
	for y in H:
		for x in W:
			var t := Vector2i(x, y)
			if y == 18 and not _on_path(t):
				_set_water(t)
	for y in H:
		for x in W:
			var t := Vector2i(x, y)
			if _on_path(t):
				terrain[idx(t)] = DIRT
				solid[idx(t)] = 0
			elif _clearing(t) and not _is_water(t):
				terrain[idx(t)] = DIRT


func _place() -> void:
	var images: Array[Image] = []
	var tex: Array[Texture2D] = []
	for kind in 3:
		var image := BambooArt.stalk(kind)
		images.append(image)
		tex.append(Px.tex(image))
	# 竹林里的地：盖一层树荫和落叶，路、水、空地不盖
	var forest := PackedByteArray()
	forest.resize(W * H)
	for fy in H:
		for fx in W:
			var ft := Vector2i(fx, fy)
			if not _on_path(ft) and not _is_water(ft) and not _clearing(ft):
				forest[fy * W + fx] = 1
	var floor_sprite := Sprite2D.new()
	floor_sprite.centered = false
	floor_sprite.texture = Px.tex(BambooArt.floor_shade(forest, W, H))
	floor_sprite.z_index = -9
	add_child(floor_sprite)
	for y in H:
		for x in W:
			var t := Vector2i(x, y)
			if _on_path(t):
				continue
			if t == SIGN or t == CHENG or t == BOWL or t == SHAN:
				continue
			if _is_water(t):
				continue
			_block(t)
			if x == 0 or y == 0 or x == W - 1 or y == H - 1 or _clearing(t):
				continue
			var roll := Px.h2(x, y)
			if _beside_path(t):
				if roll % 4 == 0:
					continue
			elif roll % 7 >= 2:
				continue
			var kind := 2 if _covers_open(t) else (1 if roll % 2 == 0 else 0)
			var image: Image = images[kind]
			var jitter := float(roll % 7) - 3.0
			var spr := _sprite(tex[kind], tile_center(t) + Vector2(jitter, 8), Vector2(-image.get_width() / 2.0, -float(image.get_height())))
			spr.material = _tree_mat
	_hang_clue(SIGN, BambooArt.marker(), 4.0)
	_bowl = _sprite(Px.tex(BambooArt.bowl()), tile_center(BOWL) + Vector2(0, 4), Vector2(-6, -8))
	_block(BOWL)
	_block(CHENG)
	_block(SHAN)


func _beside_path(t: Vector2i) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if _on_path(t + d):
			return true
	return false


## 这一格的竹子会伸进路或溪里，就用矮的。
func _covers_open(t: Vector2i) -> bool:
	var above := t + Vector2i(0, -1)
	return _on_path(above) or _is_water(above)


## 路石、乘黄、酒碗、山魈四周留出一块空地，竹子才不会把它们盖住。
func _clearing(t: Vector2i) -> bool:
	for spot in [SIGN, CHENG, BOWL, SHAN]:
		if absi(t.x - spot.x) <= 1 and t.y >= spot.y - 1 and t.y <= spot.y + 2:
			return true
	return false


func _on_path(t: Vector2i) -> bool:
	if t.x >= 16 and t.x <= 17 and t.y >= 12 and t.y <= H - 1:
		return true
	if _new_path(t):
		return true
	if t.y == 12 and t.x >= 8 and t.x <= 26:
		return true
	if t.x >= 8 and t.x <= 9 and t.y >= 6 and t.y <= 12:
		return true
	if t.x >= 24 and t.x <= 25 and t.y >= 8 and t.y <= 12:
		return true
	return false


func _night() -> bool:
	return GameClock.minutes >= 1140.0 + GameClock.dusk_shift()


func _day_beast() -> bool:
	return not _night()


func _shanxiao_out() -> bool:
	return _night() and not Bestiary.known(&"shanxiao")


func _tao_out() -> bool:
	return not Bestiary.known(&"taotie")


func _fei_out() -> bool:
	return Weather.is_foggy() and not Bestiary.bonded(&"feifei")


func _sync_beasts() -> void:
	if _shanxiao_out():
		if _shan == null:
			_shan = _actor("shanxiao", false, SHAN, Facing.DOWN)
	else:
		_clear_shan()
	if _day_beast():
		if _cheng == null:
			_cheng = _actor("chenghuang", true, CHENG, Facing.RIGHT)
	elif _cheng != null:
		_cheng.queue_free()
		_cheng = null
	if Bestiary.known(&"xingxing"):
		if _xing == null:
			_xing = _actor("xingxing", false, BOWL, Facing.LEFT)
		if _bowl != null:
			_bowl.visible = false
	elif _bowl != null:
		_bowl.visible = true
	_tao = _show(_tao, _tao_out(), "taotie", true, TAO, Facing.RIGHT)
	_fei = _show(_fei, _fei_out(), "feifei", true, FEI, Facing.RIGHT)
	_hold(TAO, _tao != null)
	_hold(FEI, _fei != null)


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
	elif in_map(tile):
		solid[idx(tile)] = 0
		occupied.erase(tile)


func _offer_feast(item: ItemDef) -> void:
	if Bestiary.fed(item.id):
		EventBus.banner_requested.emit("这道它吃过了。")
		return
	if not GameState.inventory.remove(item.id, 1):
		EventBus.banner_requested.emit("手里没有这道菜。")
		return
	EventBus.banner_requested.emit(Bestiary.feed(item.id))


func _clear(spr: Sprite2D) -> void:
	if spr != null:
		spr.queue_free()


func _clear_shan() -> void:
	if _shan != null:
		_shan.queue_free()
		_shan = null


func _actor(sheet_name: String, creature: bool, tile: Vector2i, facing: Facing) -> Sprite2D:
	var folder := CharacterSheet.CREATURE_DIR if creature else CharacterSheet.DIR
	if not _sheets.has(sheet_name):
		_sheets[sheet_name] = CharacterSheet.load_sheet(sheet_name, folder)
	var sheet: CharacterSheet = _sheets[sheet_name]
	var spr := Sprite2D.new()
	spr.texture = sheet.texture
	spr.centered = false
	spr.region_enabled = true
	spr.region_rect = sheet.region(&"idle", facing, 0)
	spr.offset = Vector2(-sheet.cell / 2.0, -float(sheet.foot_row))
	spr.position = tile_center(tile) + Vector2(0, 4)
	spr.set_meta(&"who", sheet_name)
	spr.set_meta(&"face", facing)
	entities.add_child(spr)
	return spr


## 见过以后，白天这只精灵朝人走，停在大约一格外。没有玩家就留在原地。不改 solid，也不跟出竹海。
func _follow_cheng(delta: float) -> void:
	if _cheng == null or not is_instance_valid(_cheng):
		return
	if player == null or not is_instance_valid(player) or not Bestiary.seen(&"chenghuang") or not _day_beast():
		_cheng.set_meta(&"walk", false)
		return
	var gap := float(TS)
	var dt := minf(delta, 0.05)
	var to := player.position - _cheng.position
	var dist := to.length()
	if dist < 0.001:
		_cheng.set_meta(&"walk", false)
		return
	var dir := to / dist
	var moved := false
	if dist > gap + 0.5:
		moved = _nudge_cheng(dir * minf(CHENG_FOLLOW * dt, dist - gap))
	elif dist < gap - 0.5:
		# 人贴到身上来，就往外让到大约一格；让不开就停
		moved = _nudge_cheng(-dir * minf(CHENG_FOLLOW * dt, gap - dist))
	_cheng.set_meta(&"walk", moved)
	_face_cheng(dir)


## 朝这个方向挪一步。直线会进竹子或水，就改走横的或竖的；都不行就一步也不动。
func _nudge_cheng(delta_pos: Vector2) -> bool:
	if _cheng == null or delta_pos.length() < 0.001:
		return false
	if _cheng_can_stand(_cheng.position + delta_pos):
		_cheng.position += delta_pos
		return true
	var along_x := Vector2(delta_pos.x, 0.0)
	if absf(along_x.x) > 0.01 and _cheng_can_stand(_cheng.position + along_x):
		_cheng.position += along_x
		return true
	var along_y := Vector2(0.0, delta_pos.y)
	if absf(along_y.y) > 0.01 and _cheng_can_stand(_cheng.position + along_y):
		_cheng.position += along_y
		return true
	return false


## 跟 blocked() 一样看脚底四角。竹子和水都是 solid。
## 它起初蹲在被挡住的西边那一格，人走不上去；脚还在这一格上时，允许先迈到路上。
func _cheng_can_stand(at: Vector2) -> bool:
	if _cheng == null:
		return false
	var home := tile_of(_cheng.position)
	var foot := tile_of(at)
	if foot != home and _tile_blocked(foot):
		return false
	if not blocked(at):
		return true
	for corner: Vector2 in [Vector2(-4, -4), Vector2(4, -4), Vector2(-4, 1), Vector2(4, 1)]:
		var t := tile_of(at + corner)
		if t == home:
			continue
		if _tile_blocked(t):
			return false
	return true


func _face_cheng(dir: Vector2) -> void:
	if _cheng == null or dir.length() < 0.01:
		return
	var face := Facing.DOWN
	if absf(dir.x) > absf(dir.y):
		face = Facing.RIGHT if dir.x > 0.0 else Facing.LEFT
	else:
		face = Facing.DOWN if dir.y > 0.0 else Facing.UP
	_cheng.set_meta(&"face", face)


## 人在这张图上时，步速跟着 chenghuang_pace()。天黑或还没见过就写回 1。
## 矿洞那一档只在矿洞里写，两张图不会同时在。
func _apply_cheng_pace() -> void:
	var who := player as Player
	if who == null:
		return
	who.slow = chenghuang_pace()


func _animate() -> void:
	for who: String in ["shanxiao", "xingxing", "chenghuang"]:
		var spr: Sprite2D = _shan if who == "shanxiao" else _xing if who == "xingxing" else _cheng
		if spr == null or not _sheets.has(who):
			continue
		var sheet: CharacterSheet = _sheets[who]
		var anim := &"idle"
		if who == "chenghuang" and bool(spr.get_meta(&"walk", false)) and sheet.has_anim(&"walk"):
			anim = &"walk"
		var count := sheet.frame_count(anim)
		var frame := int(_time * sheet.fps(anim)) % maxi(count, 1)
		var facing := int(spr.get_meta(&"face", Facing.DOWN))
		spr.region_rect = sheet.region(anim, facing, frame)


func _voice() -> void:
	if player == null or _said_voice or not _shanxiao_out():
		return
	if tile_of(player.position) != VOICE:
		return
	_said_voice = true
	Bestiary.hear(&"shanxiao")
	EventBus.banner_requested.emit("有个声音和你一模一样：这边。这边近。")


func _bite(delta: float) -> void:
	_bite_wait = maxf(0.0, _bite_wait - delta)
	if player == null or _bite_wait > 0.0 or not _shanxiao_out():
		return
	var who := player as Player
	if who == null or who.invincible():
		return
	if who.position.distance_to(tile_center(SHAN)) > 22.0:
		return
	_bite_wait = 1.4
	who.hurt(who.position - tile_center(SHAN))
	GameState.hurt(6)


func _offer_wine() -> void:
	if not GameState.inventory.remove(WINE, 1):
		EventBus.banner_requested.emit("手里没有米酒。")
		return
	Bestiary.know(&"xingxing")
	_sync_beasts()
	EventBus.banner_requested.emit("狌狌喝了酒，说：这座桥是有人一截一截接上的。接的人自己都忘了。")


# ---------------------------------------------------------------- 往东、往南扩出来的部分

## 新的路：往东的横路和东南角的小广场。
func _new_path(t: Vector2i) -> bool:
	if EAST_ROWS.has(t.y) and t.x >= 18 and t.x <= 39:
		return true
	return PLAZA.has_point(t)


func _place_new() -> void:
	_building("pavilion", 30, 33, 3, 2, false)
	_wall_clue(30, 33, 3, "竹林深处的小亭。柱子上的漆是红的，亭里一片竹叶也没有")
	_building("house", 37, 33, 3, 2, true)
	_wall_clue(37, 33, 3, "竹篾编的小屋，门上贴着一张褪成白色的福字")
	_wide_prop("drying_rack", Vector2i(33, 31), 2, "晾着一捆刚劈开的竹篾，青的那面朝上")
	_wide_prop("wood_pile", Vector2i(35, 31), 2, "竹筒码得像一堵墙，每根都敲得空响")
	_wide_prop("bench", Vector2i(32, 35), 2, "竹凳。坐上去会听见整片林子在响")
	_small_prop("jar_clay", Vector2i(39, 35), "坛子里泡着竹叶，酒香里有一点苦味")
	_clue(Vector2i(24, 36), "石上刻着：东边的竹子长得更密。别在夜里数它们。")
	_small_prop("rock_0", Vector2i(22, 36), "")
	for t: Vector2i in [Vector2i(19, 33), Vector2i(26, 33), Vector2i(34, 36), Vector2i(15, 38)]:
		if t.y in EAST_ROWS or PLAZA.has_point(t) or t.x in [16, 17]:
			continue
		_lamp_post(t)
