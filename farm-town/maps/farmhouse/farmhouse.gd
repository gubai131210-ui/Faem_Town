extends GameMap

const DishFrames := preload("res://art_gen/dish_art.gd")
## 农舍室内：床（睡觉）、摆着两副碗筷的桌子、灶台（做菜）、柜子（上面的收音机报天气），门垫出门。
## 屋子多大、摆了什么、墙和地是哪种，都问 Home（决策 148）。下面的格子和像素都按老屋算，
## 青竹盖了西厢以后老屋整个往东挪 Home.ox() 格。

const WALL_ROWS := 2
## 小寒灶君站在灶台左边。腓腓和耳鼠结缘以后待在床下边（决策 129）。
const ZAO := Vector2i(9, 3)
const FEI_HOME := Vector2i(2, 6)
const ER_HOME := Vector2i(4, 6)
const INTRO_DIALOGUE := "res://dialogue/intro.dialogue"
const COMMON_DIALOGUE := "res://dialogue/common.dialogue"
## 固定的家具：[素材名, 锚点所在的像素位置]。占的格子在 Home.FIXED。
const FIXED_ART: Dictionary[StringName, Array] = {
	&"bed": ["bed", Vector2(32, 80)],
	&"cabinet": ["cabinet", Vector2(64, 48)],
	&"stove": ["stove", Vector2(176, 48)],
	&"table": ["table", Vector2(128, 80)],
}
## 老屋墙上原来那幅挂轴
const OLD_SCROLL := Vector2(140, 28)
## 三块牌在墙面上的位置，相对老屋。窗下那一截木墙。
const PLAQUE_SPOTS: Array[Vector2] = [Vector2(89, 45), Vector2(117, 45), Vector2(145, 45)]
## 桌上八个位置，前排更靠近人，盖过桌面。
const DISH_SPOTS: Array[Vector2] = [
	Vector2(96, 64), Vector2(116, 64), Vector2(136, 64), Vector2(156, 64),
	Vector2(96, 86), Vector2(116, 86), Vector2(136, 86), Vector2(156, 86),
]

var W := 12
var H := 9
## 老屋往东挪的格数和像素
var _ox := 0
var _o := Vector2.ZERO
var _solid: Dictionary[Vector2i, bool] = {}
var _room: Sprite2D
var _room_day: Texture2D
var _room_night: Texture2D
var _room_key := ""
var _is_night := false
var _dishes: Array[Sprite2D] = []
var _plaques: Array[Sprite2D] = []
var _decor: Array[Node2D] = []
var _zao: Sprite2D
var _fei: Sprite2D
var _er: Sprite2D
var _sheets: Dictionary = {}


func _ready() -> void:
	map_id = &"farmhouse"
	indoor = true
	W = Home.width()
	H = Home.height()
	_ox = Home.ox()
	_o = Vector2(_ox * TS, 0)

	_room = Sprite2D.new()
	_room.centered = false
	_room.z_index = -10
	add_child(_room)
	_sync_room()
	var scroll := PropArt.sprite("wall_scroll", OLD_SCROLL + _o)
	scroll.z_index = -9
	add_child(scroll)

	entities = Node2D.new()
	entities.y_sort_enabled = true
	add_child(entities)
	for key: StringName in FIXED_ART:
		var art: Array = FIXED_ART[key]
		var shown: String = art[0]
		if key == &"bed" and Residents.memory_level(&"qingzhu") >= 3:
			shown = "bed_wide"
		entities.add_child(PropArt.sprite(shown, art[1] + _o))
	Crafting.changed.connect(_sync_dishes)
	Home.changed.connect(_on_home_changed)
	_sync_decor()
	_sync_dishes()
	_sync_plaques()
	_sync_beasts()
	_sync_spoon()


func _process(_delta: float) -> void:
	_update_windows(false)
	_sync_beasts()
	_sync_spoon()
	if _dishes.is_empty():
		return
	var frame := int(Time.get_ticks_msec() / 180) % 4
	for i in _dishes.size():
		_dishes[i].texture = DishFrames.frame(Crafting.table_dishes[i], frame)


## 地图上的格子换成老屋的格子。
func _r(tile: Vector2i) -> Vector2i:
	return tile - Vector2i(_ox, 0)


func _m(t: Vector2i) -> Vector2i:
	return t + Vector2i(_ox, 0)


func _sync_spoon() -> void:
	var node := get_node_or_null("WokSpoon")
	if Livelihood.told(&"stove") < 1:
		if node != null:
			node.queue_free()
		return
	if node != null:
		return
	var spoon := Sprite2D.new()
	spoon.name = "WokSpoon"
	spoon.texture = Px.tex(_spoon_image())
	spoon.centered = false
	spoon.position = Vector2(163, 33) + _o
	spoon.z_index = 2
	add_child(spoon)


func _spoon_image() -> Image:
	var img := Px.new_img(12, 6)
	Px.rect(img, 0, 2, 8, 2, Color.html("c4a06a"))
	Px.rect(img, 7, 1, 5, 4, Color.html("d8dce0"))
	Px.rect(img, 8, 2, 3, 2, Color.html("f4f6f8"))
	return img


func _exit_tree() -> void:
	# 出了屋就听不到收音机了
	Audio.stop_radio()


func size_px() -> Vector2i:
	return Vector2i(W * TS, H * TS)


func spawn_position(spawn: StringName) -> Vector2:
	if spawn == &"bed":
		return tile_center(_m(Vector2i(3, 3)))
	return tile_center(_m(Vector2i(Home.DOOR_X[0], H - 2))) + Vector2(8, 0)


func spawn_facing(spawn: StringName) -> Facing:
	return Facing.DOWN if spawn == &"bed" else Facing.UP


func blocked(p: Vector2) -> bool:
	for c: Vector2 in [Vector2(-4, -4), Vector2(4, -4), Vector2(-4, 1), Vector2(4, 1)]:
		var t := tile_of(p + c)
		if t.x < 0 or t.x >= W or t.y < WALL_ROWS or t.y >= H or _solid.has(_r(t)):
			return true
	return false


func query_use(item: ItemDef, tile: Vector2i, _facing: Facing) -> StringName:
	var r := _r(tile)
	if r == ZAO and _zao_out():
		if Bestiary.is_dish(item):
			return &"offer"
		return &"interact"
	if _home_pet(r) != &"":
		return &"interact"
	if item != null and Home.is_decor(item.id):
		match Home.type_of(item.id):
			&"piece":
				if Home.on_floor(r):
					return &"place"
			&"wall":
				if r.y == 1:
					return &"place"
			_:
				return &"place"
	if _fixed_at(r) != &"":
		return &"interact"
	if _decor_at(r) >= 0:
		return &"interact"
	return &""


func perform(action: StringName, item: ItemDef, tile: Vector2i, _quiet: bool = false) -> void:
	var r := _r(tile)
	if action == &"offer" and r == ZAO and _zao_out():
		_offer_zao(item)
		return
	if action == &"place" and item != null:
		_place(item, r)
		return
	if action != &"interact":
		return
	if r == ZAO and _zao_out():
		Bestiary.see(&"zaojun")
		EventBus.banner_requested.emit("灶君。红袍，黑帽。小寒这几天他在灶边，收一道菜。")
		return
	var pet := _home_pet(r)
	if pet != &"":
		EventBus.banner_requested.emit(Bestiary.touch(pet))
		return
	match _fixed_at(r):
		&"bed":
			EventBus.dialogue_requested.emit(COMMON_DIALOGUE, "bed")
			return
		&"table":
			_use_table(item)
			return
		&"stove":
			EventBus.cook_requested.emit()
			return
		&"cabinet":
			# 柜子上的收音机报明天的天气，一边出字一边播报
			Audio.play_radio(Weather.report_clips())
			EventBus.dialogue_requested.emit(COMMON_DIALOGUE, "radio")
			return
	_pick_up(r)


func trigger_at(tile: Vector2i) -> Dictionary:
	var r := _r(tile)
	if r.y == H - 1 and Home.DOOR_X.has(r.x):
		return {"map": &"farm", "spawn": &"house_door"}
	return {}


func _fixed_at(r: Vector2i) -> StringName:
	for f: Array in Home.FIXED:
		if Home.fixed_tiles(f[0]).has(r):
			return f[0]
	return &""


## 这一格上能收的那件：地上的，或者对着墙的那一格挂着的。
func _decor_at(r: Vector2i) -> int:
	var i := Home.piece_at(r)
	if i >= 0:
		return i
	return -1


# ---------------------------------------------------------------- 摆设

func _stand() -> Vector2i:
	if player == null:
		return Vector2i(-99, -99)
	return _r(tile_of(player.position))


func _place(item: ItemDef, r: Vector2i) -> void:
	var id := item.id
	if GameState.inventory.count_of(id) <= 0:
		return
	match Home.type_of(id):
		&"paper", &"floor":
			var old := Home.apply_surface(id)
			if old == &"":
				EventBus.banner_requested.emit("屋里已经是%s了。" % item.name)
				return
			GameState.inventory.remove(id, 1)
			GameState.inventory.add(old, 1)
			EventBus.banner_requested.emit("换上了%s。换下来的收进了背包。" % item.name)
			Audio.play("select", 0.0, -6.0)
		_:
			var at := r
			var size := Home.size_of(id)
			if Home.type_of(id) == &"piece":
				# 对着的那一格是这件家具正面的中间：宽的往左摊，深的往里摊
				at = r - Vector2i((size.x - 1) / 2, size.y - 1)
			if not Home.place(id, at, _stand()):
				EventBus.banner_requested.emit("这里放不下，或者放了就走不过去了。")
				return
			GameState.inventory.remove(id, 1)
			Audio.play("select", 0.0, -6.0)


func _pick_up(r: Vector2i) -> void:
	var i := _decor_at(r)
	if i < 0:
		return
	var id: StringName = Home.pieces[i]["id"]
	if not GameState.inventory.can_add(id, 1):
		EventBus.banner_requested.emit("背包满了。")
		return
	Home.take(r)
	GameState.inventory.add(id, 1)
	Fx.pop_icon(self, tile_center(_m(r)) + Vector2(0, -10), Px.tex(PixelArt.icon(Database.item(id).icon)))


func _on_home_changed() -> void:
	if Home.width() != W or Home.height() != H:
		# 扩建在夜里结算，人醒来时地图会重新载入；这里只管摆设和墙地
		return
	_sync_room()
	_sync_decor()


func _sync_decor() -> void:
	for n in _decor:
		if is_instance_valid(n):
			n.queue_free()
	_decor.clear()
	_solid = Home.blocked_tiles()
	for p in Home.pieces:
		var id: StringName = p["id"]
		var at: Vector2i = p["at"]
		var size := Home.size_of(id)
		var spr: Sprite2D
		if Home.type_of(id) == &"wall":
			spr = PropArt.sprite(Home.prop_of(id), Vector2((at.x + size.x / 2.0) * TS, 28) + _o)
			spr.z_index = -9
			add_child(spr)
		else:
			var pos := Vector2((at.x + size.x / 2.0) * TS, (at.y + size.y) * TS - 4) + _o
			spr = PropArt.sprite(Home.prop_of(id), pos)
			if Home.walkable(id):
				spr.z_index = -9
				add_child(spr)
			else:
				entities.add_child(spr)
		_decor.append(spr)


func _sync_room() -> void:
	var key := "%d/%d/%s/%s" % [W, H, Home.paper, Home.floor_id]
	if key == _room_key:
		return
	_room_key = key
	var wall := Home.look_of(Home.paper)
	var ground := Home.look_of(Home.floor_id)
	_room_day = Px.tex(RoomArt.room(W, H, _ox, wall, ground, Home.windows(), Home.DOOR_X, false))
	_room_night = Px.tex(RoomArt.room(W, H, _ox, wall, ground, Home.windows(), Home.DOOR_X, true))
	_update_windows(true)


# ---------------------------------------------------------------- 桌子和牌

func _use_table(item: ItemDef) -> void:
	if item != null and Database.recipes.has(item.id):
		if Crafting.place_dish(item.id):
			EventBus.banner_requested.emit("摆上了%s。" % item.name)
		elif Crafting.table_dishes.has(item.id):
			EventBus.banner_requested.emit("这道已经在桌上了。")
		elif Crafting.table_dishes.size() >= Crafting.TABLE_MAX:
			EventBus.banner_requested.emit("桌上摆满了。")
		else:
			EventBus.banner_requested.emit("手上没有这道菜。")
		return
	if not GameState.has_flag(&"table_remark"):
		GameState.set_flag(&"table_remark")
		EventBus.dialogue_requested.emit(INTRO_DIALOGUE, "table")
		return
	EventBus.table_requested.emit()


func _sync_dishes() -> void:
	for spr in _dishes:
		spr.queue_free()
	_dishes.clear()
	for i in Crafting.table_dishes.size():
		var spr := Sprite2D.new()
		spr.texture = DishFrames.frame(Crafting.table_dishes[i], 0)
		spr.position = DISH_SPOTS[i] + _o
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.z_index = 2
		entities.add_child(spr)
		_dishes.append(spr)
	_sync_plaques()


func _sync_plaques() -> void:
	for spr in _plaques:
		if is_instance_valid(spr):
			spr.queue_free()
	_plaques.clear()
	if _room == null:
		return
	for i in Crafting.SETS.size():
		var set_id: StringName = Crafting.SETS[i]
		if not Crafting.has_set(set_id):
			continue
		var img := _plaque(set_id)
		var spr := Sprite2D.new()
		spr.texture = Px.tex(img)
		spr.centered = true
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.position = PLAQUE_SPOTS[i] + _o
		_room.add_child(spr)
		_plaques.append(spr)


## 节气牌是绿心，人家牌是红心，优席牌是金边。
static func _plaque(set_id: StringName) -> Image:
	var img := Px.new_img(16, 20)
	var wood := Color.html("6a4430")
	var rim := Color.html("e8c060") if set_id == &"fine" else Color.html("3a2820")
	Px.rect(img, 1, 1, 14, 18, wood)
	Px.rect(img, 3, 3, 10, 12, rim)
	var heart := Color.html("3d8a40")
	if set_id == &"homes":
		heart = Color.html("c8483c")
	elif set_id == &"fine":
		heart = Color.html("f4e2a0")
	Px.rect(img, 5, 5, 6, 8, heart)
	Px.rect(img, 7, 15, 2, 3, Color.html("c8a060"))
	return Px.outline(img)


func _update_windows(force: bool) -> void:
	var night := GameClock.minutes >= 1140.0 + GameClock.dusk_shift()
	if night == _is_night and not force:
		return
	_is_night = night
	_room.texture = _room_night if night else _room_day


# ---------------------------------------------------------------- 灶君和小兽

func _zao_out() -> bool:
	return GameClock.term_id() == &"xiaohan"


func _home_pet(r: Vector2i) -> StringName:
	if r == FEI_HOME and Bestiary.bonded(&"feifei") and Bestiary.out_id() != &"feifei":
		return &"feifei"
	if r == ER_HOME and Bestiary.bonded(&"ershu") and Bestiary.out_id() != &"ershu":
		return &"ershu"
	return &""


func _sync_beasts() -> void:
	_zao = _show(_zao, _zao_out(), "zaojun", false, ZAO, Facing.DOWN)
	_fei = _show(_fei, _home_pet(FEI_HOME) == &"feifei", "feifei", true, FEI_HOME, Facing.RIGHT)
	_er = _show(_er, _home_pet(ER_HOME) == &"ershu", "ershu", true, ER_HOME, Facing.RIGHT)


func _offer_zao(item: ItemDef) -> void:
	if Bestiary.zaojun_helps():
		EventBus.banner_requested.emit("今年已经祭过了。")
		return
	if not GameState.inventory.remove(item.id, 1):
		EventBus.banner_requested.emit("手里没有这道菜。")
		return
	EventBus.banner_requested.emit(Bestiary.appease_zaojun())


func _show(spr: Sprite2D, on: bool, sheet_name: String, creature: bool, tile: Vector2i, facing: Facing) -> Sprite2D:
	if on:
		if spr == null or not is_instance_valid(spr):
			return _actor(sheet_name, creature, tile, facing)
		return spr
	if spr != null and is_instance_valid(spr):
		spr.queue_free()
	return null


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
	spr.position = tile_center(_m(tile)) + Vector2(0, 4)
	entities.add_child(spr)
	return spr
