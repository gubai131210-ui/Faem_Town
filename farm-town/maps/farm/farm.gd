extends WildMap
## 农场地图：程序生成的地形和物件，耕地由 FarmView 显示。

const W := FarmLand.W
const H := FarmLand.H
const HOUSE_POS := Vector2(128, 112)
const DOOR_TILES: Array[Vector2i] = [Vector2i(7, 6), Vector2i(8, 6)]
const MAILBOX_TILE := Vector2i(11, 7)
## 老屋两边加盖的两间（决策 148）：[第几级盖好, 物件, 正面墙根中点, 挡路的格子]。信箱和出货箱在东边那间门前。
const WINGS: Array = [
	[1, "house_wing_e", Vector2(200, 111), Rect2i(11, 4, 3, 3)],
	[2, "house_wing_w", Vector2(56, 111), Rect2i(2, 4, 3, 3)],
]
const BIN_TILE := Vector2i(12, 7)
const START_TILE := Vector2i(8, 8)
## 往西出去是镇广场：路通到地图边上，踩到最西边那一格就走
const TOWN_EXIT_ROWS: Array[int] = [11, 12]
const INTRO_DIALOGUE := "res://dialogue/intro.dialogue"
const COMMON_DIALOGUE := "res://dialogue/common.dialogue"
## 家里的猫狗在屋前这一片转
const PET_YARD := Rect2i(4, 7, 10, 4)
const PET_NAMES: Dictionary[StringName, String] = {&"dog": "阿黄", &"cat": "小花"}
## 乌鸦见人走到这么近就飞
const CROW_SHY := 44.0
## 池塘中心的水面格。那一块水以 (33, 17.5) 为中心，东边小溪不算池塘。
const WENYAO_TILE := Vector2i(33, 17)
const WENYAO_LINE := "文鳐贴着池塘飞。翅膀是白的。"

## 溪上的旧木桥
const BRIDGE_TILES: Array[Vector2i] = [Vector2i(45, 11), Vector2i(46, 11), Vector2i(45, 12), Vector2i(46, 12)]
## 溪东塌了的院子：[最西一列, 正面墙脚下面那一行, 宽, 深]，院里的井，外面那圈旧篱笆，几棵老果树
const RUIN := [59, 13, 5, 3]
const WELL := Vector2i(67, 16)
const OLD_YARD := Rect2i(54, 7, 19, 13)
const OLD_TREES: Array[Vector2i] = [Vector2i(56, 23), Vector2i(62, 25), Vector2i(68, 23), Vector2i(74, 26), Vector2i(52, 30), Vector2i(66, 31)]
const BIG_TREE := Vector2i(14, 45)
const MARSH_POND := Vector2(20, 63)
const SLOPE_POND := Vector2(84, 61)
const THRESH := Vector2(72, 50)
const LOOKOUT := [87, 10, 3, 2]
const FOG_SHADER := """
shader_type canvas_item;
uniform vec2 tiles = vec2(100.0, 72.0);
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y);
}
void fragment() {
	float shut = texture(TEXTURE, UV).a;
	vec2 p = floor(UV * tiles * 16.0) / 16.0 * 0.4;
	float v = n(p + vec2(TIME * 0.03, TIME * 0.012)) * 0.6 + n(p * 2.3 - vec2(TIME * 0.02, 0.0)) * 0.4;
	float a = smoothstep(0.3, 0.7, shut + (v - 0.5) * 0.45);
	COLOR = vec4(mix(vec3(0.84, 0.89, 0.92), vec3(0.98, 0.99, 1.0), v), a * (0.9 + 0.08 * v));
}
"""

var _farm_view: FarmView
var _fog: Sprite2D
var _fog_key := "?"
var _fence_sprites: Dictionary[Vector2i, Sprite2D] = {}
## 正在照老农场的样子撒树撒草
var _legacy_scatter := false
var _orchard_tex: Dictionary[String, Texture2D] = {}
## 果树的格子 -> [树的精灵, 影子]
var _orchard_nodes: Dictionary[Vector2i, Array] = {}
## 建筑 id -> 物件精灵，以及现在画的是工地还是盖好的样子
var _building_sprites: Dictionary[StringName, Sprite2D] = {}
var _building_shown: Dictionary[StringName, String] = {}
var _critters: Array[Critter] = []
## 正牵着的那头牛
var _led: Critter
var _ranch_minute := -1
## 加工设备 id -> 物件精灵（子节点 Ready 是做好时露出来的成品）
var _machine_sprites: Dictionary[StringName, Sprite2D] = {}
var _scarecrow_sprites: Dictionary[Vector2i, Sprite2D] = {}
var _pet: Critter
## 早上还在地里刨种子的乌鸦
var _crows: Array[Critter] = []
## 铁锹对着这棵果树问过一次。再按一次才挖掉
var _tree_ask := Vector2i(-1, -1)
## 贴着池塘飞的文鳐。不在的时候不留着这只精灵
var _wenyao: Sprite2D
var _wenyao_sheet: CharacterSheet


func _ready() -> void:
	map_id = &"farm"
	_rng.seed = 20261111
	_scatter_cols = FarmLand.OLD_W
	_scatter_rows = FarmLand.OLD_H
	_setup_wild(W, H)
	_layout()
	_finish_relief()
	_build_ground()
	_add_relief(WildArt.ROCK)

	_farm_view = FarmView.new()
	_farm_view.z_index = -9
	add_child(_farm_view)
	_make_entities()
	_farm_view.water_at = _is_water
	_farm_view.sway_material = _crop_mat
	_farm_view.setup(Farming.state, entities)
	_place_objects()
	_place_new_land()
	_add_planks()
	_apply_cleared()
	Farming.fences_changed.connect(_sync_fences)
	_sync_fences()
	_sync_fog()
	for t: Vector2i in Farming.state.soil:
		_clear_decor(t)
	for t: Vector2i in Farming.state.canals:
		_clear_decor(t)
	for t: Vector2i in Farming.orchard.trees:
		_clear_decor(t)
	Farming.orchard.changed.connect(_sync_orchard)
	_sync_orchard()
	Foraging.settle(map_id, _forage_tiles(false), _forage_tiles(true))
	Foraging.changed.connect(_sync_forage)
	_sync_forage()
	Fishing.changed.connect(_sync_traps)
	_sync_traps()
	Animals.changed.connect(_sync_ranch)
	Animals.roster_changed.connect(_reset_critters)
	_sync_ranch()
	Crafting.changed.connect(_sync_machines)
	_sync_machines()
	Farming.scarecrows_changed.connect(_sync_scarecrows)
	_sync_scarecrows()
	_spawn_crows()
	_make_water_fx(150)
	for off: Vector2 in [Vector2(-32, -26), Vector2(32, -26)]:
		_add_night_light(HOUSE_POS + off, 1.3)
	_spawn_npcs()
	_sync_wenyao()


func _exit_tree() -> void:
	super._exit_tree()
	if Farming.orchard.changed.is_connected(_sync_orchard):
		Farming.orchard.changed.disconnect(_sync_orchard)
	if Foraging.changed.is_connected(_sync_forage):
		Foraging.changed.disconnect(_sync_forage)
	if Fishing.changed.is_connected(_sync_traps):
		Fishing.changed.disconnect(_sync_traps)
	if Animals.changed.is_connected(_sync_ranch):
		Animals.changed.disconnect(_sync_ranch)
	if Animals.roster_changed.is_connected(_reset_critters):
		Animals.roster_changed.disconnect(_reset_critters)
	if Crafting.changed.is_connected(_sync_machines):
		Crafting.changed.disconnect(_sync_machines)
	if Farming.scarecrows_changed.is_connected(_sync_scarecrows):
		Farming.scarecrows_changed.disconnect(_sync_scarecrows)
	if Farming.fences_changed.is_connected(_sync_fences):
		Farming.fences_changed.disconnect(_sync_fences)


func _process(delta: float) -> void:
	super._process(delta)
	_sync_stake()
	_sync_plaque()
	# 鸡鸭早上出来、傍晚回窝，每过一分钟看一眼
	var minute := int(GameClock.minutes)
	if minute != _ranch_minute:
		_ranch_minute = minute
		_sync_critters()
		_sync_pet()
	for c in _critters:
		c.avoid = player
	if _pet != null:
		_pet.avoid = player
	if player != null:
		for k in range(_crows.size() - 1, -1, -1):
			if _crows[k].position.distance_to(player.position) < CROW_SHY:
				_flee(_crows[k])
				_crows.remove_at(k)
	_sync_wenyao()
	_animate_wenyao()
	_sync_fog()


## 第二天起，头一回走到院子里：门口蹲着一条狗和一只猫，留一个。
func entered() -> void:
	if player != null:
		_announce_land()
	if player == null or Animals.pet_kind() != &"" or GameClock.day < 2:
		return
	EventBus.dialogue_requested.emit(COMMON_DIALOGUE, "pet_choice")


func spawn_position(spawn: StringName) -> Vector2:
	if spawn == &"house_door":
		return Vector2(HOUSE_POS.x, 7 * TS + 6)
	if spawn == &"from_town":
		return tile_center(Vector2i(1, TOWN_EXIT_ROWS[0])) + Vector2(0, 8)
	return tile_center(START_TILE)


func spawn_facing(spawn: StringName) -> Facing:
	return Facing.RIGHT if spawn == &"from_town" else Facing.DOWN


func trigger_at(tile: Vector2i) -> Dictionary:
	if tile.x == 0 and TOWN_EXIT_ROWS.has(tile.y):
		return {"map": &"town", "spawn": &"from_farm"}
	return {}


func _tile_blocked(t: Vector2i) -> bool:
	return super._tile_blocked(t) or Farming.state.blocks_walking(t) or Farming.orchard.has(t) or Farming.has_scarecrow(t) \
		or Farming.has_fence(t) or not FarmLand.open_tile(t)


func query_use(item: ItemDef, tile: Vector2i, facing: Facing) -> StringName:
	if facing == Facing.UP and DOOR_TILES.has(tile):
		return &"interact"
	if tile == MAILBOX_TILE or tile == BIN_TILE:
		return &"interact"
	# 雾里的地：只能看一眼
	if in_map(tile) and not FarmLand.open_tile(tile):
		return &"interact"
	if Farming.has_fence(tile) and (item == null or item.id == Farming.FENCE_ID):
		return &"interact"
	if Farming.has_scarecrow(tile):
		return &"interact"
	if _pet_at(tile):
		return &"tend"
	var machine := _machine_at(tile)
	if machine != null:
		var busy := Crafting.state(machine.id) == Crafting.READY or Crafting.can_put(machine.id, GameState.selected_slot)
		return &"tend" if busy else &"interact"
	var ranch := _ranch_query(item, tile)
	# 牵着的牛总跟在身边，常常正好站在要开的那一格上：拿着锄头、面前开得出一行，就是锄地，不是放开它
	if ranch == &"interact" and item != null and item.id == &"hoe" and _led != null and _critter_at(tile) == _led and plow_row(tile, facing).size() > 1:
		return &"hoe"
	if ranch != &"":
		return ranch
	var farm := Farming.state
	if item != null and item.id == &"straw" and farm.has_crop(tile) and not farm.is_dead(tile):
		return &"place"
	# 枯死的作物也用“收”的动作拔掉
	if farm.is_ripe(tile) or farm.is_dead(tile):
		return &"harvest"
	# 野外的采集物、果树上和树下的果子，空手也能捡
	if Foraging.item_at(map_id, tile) != &"" or Farming.orchard.ready_at(tile) > 0:
		return &"harvest"
	var trap := _trap_query(item, tile)
	if trap != &"":
		return trap
	if item == null:
		return _look_use(tile)
	if item.id == &"pickaxe" and _rubble_at(tile):
		return &"mine"
	if item.id == Farming.FENCE_ID and _can_fence(tile):
		return &"place"
	if item.id == &"hoe":
		return &"hoe"
	if item.id == &"watering_can":
		return &"water"
	if item.id == &"shovel":
		if Farming.orchard.has(tile) and _tree_ask != tile:
			return &"interact"
		return &"dig"
	if item.id == &"rod" and fishing_water(tile) != &"":
		return &"cast"
	if item.kind == &"seed" and farm.can_plant(tile):
		return &"plant"
	if item.kind == &"sapling" and _can_plant_tree(tile):
		return &"plant"
	if item.id == Farming.SCARECROW_ID and _can_plant_tree(tile):
		return &"place"
	if item.kind == &"fertilizer" and farm.can_fertilize(tile):
		return &"fertilize"
	return _look_use(tile)


func perform(action: StringName, item: ItemDef, tile: Vector2i, quiet: bool = false) -> void:
	var farm := Farming.state
	var c := tile_center(tile)
	if action == &"interact" and in_map(tile) and not FarmLand.open_tile(tile):
		EventBus.banner_requested.emit(FarmLand.HINTS[FarmLand.region_of(tile)])
		return
	if action == &"interact" and _use_fence(tile, item):
		return
	match action:
		&"mine":
			_break_rock(tile, quiet)
		&"place_trap":
			_trap_perform(action, tile, item)
		&"place":
			if item != null and item.id == &"straw":
				_cover_straw(tile)
			elif item != null and item.id == Farming.SCARECROW_ID and _can_plant_tree(tile) and Farming.place_scarecrow(tile):
				GameState.inventory.remove(item.id, 1)
				Audio.play("plant")
				Fx.burst(self, c, Color("d8b45a"), 8, 40.0)
			elif item != null and item.id == Farming.FENCE_ID and _can_fence(tile) and Farming.place_fence(tile):
				GameState.inventory.remove(item.id, 1)
				Audio.play("plant", 0.0, -2.0)
		&"tend":
			if not _use_machine(tile, item) and not _use_pet(tile):
				_use_ranch(tile, item)
		&"interact":
			# 顺序和 query_use 一致：门、信箱、出货箱在前。猫狗摸得到的范围比一格大，
			# 它蹲在箱子或门边的时候，不能把这一下抢成摸它
			if tile == MAILBOX_TILE:
				_use_mailbox()
			elif tile == BIN_TILE:
				_use_bin(item)
			elif DOOR_TILES.has(tile):
				SceneRouter.travel(&"farmhouse", &"door")
			elif _trap_perform(action, tile) or _use_scarecrow(tile) or _use_machine(tile, item) or _use_pet(tile) or _use_ranch(tile, item):
				return
			elif _ask_tree(item, tile):
				return
			elif tile == WENYAO_TILE and wenyao_out():
				# 这一格不是门。钓鱼和蟹笼没接走这一下，才说到飞过的文鳐。
				EventBus.banner_requested.emit(WENYAO_LINE)
			elif clue_at(tile) != "":
				EventBus.banner_requested.emit(clue_at(tile))
		&"hoe":
			if not quiet:
				Audio.play("hoe")
			if _clear_shrub(tile):
				pass
			elif _can_till(tile) and farm.till(tile):
				_clear_decor(tile)
				# 锄头翻起来的土先弹起再落回地面
				Fx.dust_puff(self, c)
				if not quiet:
					EventBus.screen_shake_requested.emit(1.5)
			elif not quiet:
				Fx.burst(self, c, Color("c9a074"), 4, 45.0)
		&"water":
			if not quiet:
				Audio.play("water")
			Fx.burst(self, c + Vector2(0, -8), Color("8fd0ee"), 14, 30.0, 0.45, 220.0)
			farm.water(tile)
		&"dig":
			_dig(tile)
		&"plant":
			if item != null and item.kind == &"sapling":
				_plant_tree(item, tile)
				return
			if item == null or not Database.has_crop(item.crop):
				return
			var crop_def := Database.crop(item.crop)
			var refuse := ""
			if not crop_def.can_sow(GameClock.season_id()):
				refuse = "这个季节种不活"
			elif crop_def.paddy and not farm.is_paddy(tile):
				refuse = "%s要种在水田里" % crop_def.name
			elif farm.is_paddy(tile) and not crop_def.paddy:
				refuse = "水田里只能种稻和藕"
			if refuse != "":
				EventBus.banner_requested.emit(refuse)
				Audio.play("deny", 0.0, -4.0)
				return
			# 春分：这几天播下的种子品质更高
			var bonus := 1 if GameClock.term_id() == &"chunfen" else 0
			if farm.plant(tile, item.crop, bonus):
				Farming.sown_today += 1
				GameState.inventory.remove(item.id, 1)
				Audio.play("plant")
		&"fertilize":
			if item != null and farm.fertilize(tile, item.power):
				GameState.inventory.remove(item.id, 1)
				Audio.play("plant", 0.08, -3.0)
				Fx.burst(self, c, Color("e8dcc0"), 6, 30.0)
		&"harvest":
			if _pick_forage(tile) or _pick_fruit(tile):
				return
			if farm.clear_dead(tile):
				Audio.play("hoe", 0.0, -6.0)
				Fx.burst(self, c, Color("7d5230"), 6, 45.0)
				return
			var crop_id := farm.crop_id_at(tile)
			if crop_id == &"":
				return
			var crop_def := Database.crop(crop_id)
			var produce := crop_def.produce
			var count := farm.yield_at(tile, _rng.randf())
			if count <= 0:
				return
			var giant := farm.is_giant(tile)
			var quality := farm.harvest_quality(tile, _rng.randf(), crop_def.bonus_in_term(GameClock.term_id()))
			if not GameState.inventory.can_add(produce, count, quality):
				EventBus.banner_requested.emit("背包满了")
				Audio.play("deny", 0.0, -4.0)
				return
			farm.harvest(tile)
			GameState.inventory.add(produce, count, quality)
			# 附带的产物（荷花）放不下就算了，不拦着收主产物
			if crop_def.bonus_produce != &"":
				GameState.inventory.add(crop_def.bonus_produce, 1)
			if giant:
				EventBus.banner_requested.emit("巨型%s！收了 %d 个" % [Database.item(produce).name, count])
				EventBus.screen_shake_requested.emit(2.0)
			if quality > 0:
				Fx.burst(self, c + Vector2(0, -6), Color("f7d24a") if quality == 2 else Color("dfe6ee"), 8, 60.0)
			Audio.play("harvest", 0.0)
			Fx.burst(self, c, Color("7cc74f"), 6, 50.0)
			var icon_tex := Px.tex(PixelArt.icon(Database.item(produce).icon))
			Fx.pop_land(self, c + Vector2(0, -6), icon_tex)
			if count > 1:
				Fx.pop_land(self, c + Vector2(7, -9), icon_tex)


## 种果树：要一块没开垦的空地，周围一圈不能有别的果树。
func _can_plant_tree(t: Vector2i) -> bool:
	var farm := Farming.state
	return _can_till(t) and not farm.is_tilled(t) and not farm.is_canal(t) and Farming.orchard.can_plant(t)


func _plant_tree(item: ItemDef, tile: Vector2i) -> void:
	if not Database.has_tree(item.tree) or not _can_plant_tree(tile):
		return
	if Farming.orchard.plant(tile, item.tree):
		GameState.inventory.remove(item.id, 1)
		_clear_decor(tile)
		Audio.play("plant")
		Fx.burst(self, tile_center(tile), Color("9a6a40"), 8, 50.0)


## 收这棵树上和树下的果子。
func _pick_fruit(tile: Vector2i) -> bool:
	var orchard := Farming.orchard
	var count := orchard.ready_at(tile)
	if count <= 0:
		return false
	var id := orchard.item_at(tile)
	if not GameState.inventory.can_add(id, count):
		EventBus.banner_requested.emit("背包满了")
		Audio.play("deny", 0.0, -4.0)
		return true
	orchard.collect(tile)
	GameState.inventory.add(id, count)
	Audio.play("harvest", 0.0)
	var c := tile_center(tile)
	Fx.burst(self, c + Vector2(0, -20), Color("7cc74f"), 8, 60.0)
	var icon_tex := Px.tex(PixelArt.icon(Database.item(id).icon))
	for i in count:
		Fx.pop_land(self, c + Vector2(-7 + i * 7, -14 - i * 3), icon_tex)
	return true


## 拿着稻草对着还活着的庄稼按一下，盖上一格。已经盖着就不再收一份。
func _cover_straw(tile: Vector2i) -> void:
	var farm := Farming.state
	if farm.is_covered(tile):
		EventBus.banner_requested.emit("这格已经盖着稻草")
		Audio.play("deny", 0.0, -4.0)
		return
	if GameState.inventory.count_of(&"straw") < 1 or not farm.cover(tile):
		return
	GameState.inventory.remove(&"straw", 1)
	Audio.play("plant")
	Fx.burst(self, tile_center(tile), Color("e2c56a"), 8, 40.0)
	EventBus.banner_requested.emit("盖上了稻草。霜冻不着，收到为止")


## 铁锹第一次对着果树，只问一句。再按一次才挖。
func _ask_tree(item: ItemDef, tile: Vector2i) -> bool:
	if item == null or item.id != &"shovel" or not Farming.orchard.has(tile):
		return false
	_tree_ask = tile
	EventBus.banner_requested.emit("这棵树挖掉就没了。再按一次")
	Audio.play("deny", 0.0, -4.0)
	return true


## 铁锹：果树问过再挖掉；有作物就铲掉；水渠填平；水渠边的空耕地放水成水田（再铲一次放掉）；荒地挖成水渠。
func _dig(tile: Vector2i) -> void:
	var farm := Farming.state
	var c := tile_center(tile)
	Audio.play("hoe", 0.0, -2.0)
	var asked := _tree_ask == tile
	_tree_ask = Vector2i(-1, -1)
	if Farming.orchard.has(tile):
		if asked and Farming.orchard.remove(tile):
			Fx.burst(self, c, Color("7d5230"), 10, 60.0)
		return
	elif farm.uproot(tile):
		Fx.burst(self, c, Color("7d5230"), 8, 50.0)
	elif farm.fill_canal(tile):
		Fx.burst(self, c, Color("c9a074"), 8, 50.0)
	elif farm.is_tilled(tile):
		if farm.set_paddy(tile, not farm.is_paddy(tile)):
			Fx.burst(self, c + Vector2(0, -4), Color("8fd0ee"), 10, 40.0, 0.4, 200.0)
		else:
			EventBus.banner_requested.emit("离有水的水渠太远，放不进水")
			Audio.play("deny", 0.0, -4.0)
	elif _can_till(tile) and farm.dig_canal(tile, _next_to_water(tile)):
		_clear_decor(tile)
		Fx.burst(self, c, Color("9a6a40"), 10, 70.0)
		EventBus.screen_shake_requested.emit(1.5)
		if farm.is_flooded(tile):
			Audio.play("water", 0.0, -4.0)
			Fx.burst(self, c + Vector2(0, -4), Color("8fd0ee"), 12, 40.0, 0.45, 200.0)
	else:
		Fx.burst(self, c, Color("c9a074"), 4, 45.0)



## 信箱：第一次是那封信，之后提醒去镇上买东西（种子在阿禾的杂货铺，工具升级找石叔）。
func _use_mailbox() -> void:
	if not GameState.has_flag(&"read_letter"):
		GameState.set_flag(&"read_letter")
		EventBus.dialogue_requested.emit(INTRO_DIALOGUE, "letter")
	elif GameState.has_flag(&"ending_estate") and not GameState.has_flag(&"estate_mail"):
		GameState.set_flag(&"estate_mail")
		EventBus.banner_requested.emit("城里来的信。信上问：听说那儿有个镇子，还能去吗")
		Audio.play("select", 0.0, -8.0)
	else:
		var extra := PeopleLine.mark(&"jiang")
		if extra != "":
			EventBus.banner_requested.emit(extra)
		else:
			EventBus.banner_requested.emit("信箱是空的。买种子去镇上的杂货铺，沿门口的路往西走")
		Audio.play("select", 0.0, -8.0)


## 出货箱：把手里拿着的那一整格放进去，第二天早上结算。
func _use_bin(item: ItemDef) -> void:
	if item == null or not item.sellable():
		var pending := Shipping.pending_value()
		if pending > 0:
			EventBus.banner_requested.emit(_with_trade("出货箱里的东西值 %d 文，明早结算" % pending, &"farm"))
		else:
			EventBus.banner_requested.emit(_with_trade("出货箱：拿着要卖的东西再来", &"farm"))
		Audio.play("deny", 0.0, -8.0)
		return
	var slot := GameState.selected_slot
	var count := GameState.inventory.count_at(slot)
	var quality := GameState.inventory.quality_at(slot)
	if GameState.inventory.remove_at(slot, count) != count or not Shipping.add(item.id, count, quality):
		return
	Audio.play("plant", 0.0, -2.0)
	Fx.pop_icon(self, tile_center(BIN_TILE) + Vector2(0, -10), Px.tex(PixelArt.icon(item.icon)))
	EventBus.banner_requested.emit("出货：%s ×%d，明早到账 %d 文" % [item.name, count, item.price_for(quality) * count])


func _with_trade(line: String, id: StringName) -> String:
	var extra := Livelihood.mark(id)
	return line if extra == "" else line + extra


func _sync_stake() -> void:
	var node := get_node_or_null("FarmStake")
	if Livelihood.told(&"farm") < 1:
		if node != null:
			node.queue_free()
		return
	if node != null:
		return
	var spr := Sprite2D.new()
	spr.name = "FarmStake"
	spr.texture = Px.tex(_stake_image())
	spr.centered = false
	spr.position = tile_center(BIN_TILE) + Vector2(12, -6)
	spr.z_index = 2
	add_child(spr)


func _sync_plaque() -> void:
	if entities == null:
		return
	var house := entities.get_node_or_null("House")
	if house == null:
		return
	var node := house.get_node_or_null("EstatePlaque")
	if not GameState.has_flag(&"ending_estate"):
		if node != null:
			node.queue_free()
		return
	if node != null:
		return
	var spr := Sprite2D.new()
	spr.name = "EstatePlaque"
	spr.texture = Px.tex(EndingArt.plaque())
	spr.centered = false
	spr.position = Vector2(-15, -48)
	spr.z_index = 2
	house.add_child(spr)


func _stake_image() -> Image:
	var img := Px.new_img(7, 16)
	Px.rect(img, 3, 4, 1, 12, Color.html("6a4430"))
	Px.rect(img, 2, 3, 3, 2, Color.html("c4a06a"))
	Px.rect(img, 1, 0, 5, 3, Color.html("e8c878"))
	Px.rect(img, 0, 1, 1, 1, Color.html("f7dc80"))
	Px.rect(img, 6, 1, 1, 1, Color.html("f7dc80"))
	return img


# ---------------------------------------------------------------- 建筑和动物

## 盖好了的厢房；正在盖的那一间搭着脚手架。不挡别的东西，撒树的随机数不受影响。
func _place_wings() -> void:
	for w: Array in WINGS:
		var built := Home.tier >= int(w[0])
		var building := Home.days_left > 0 and Home.tier + 1 == int(w[0])
		if not built and not building:
			continue
		var pos: Vector2 = w[2]
		var area: Rect2i = w[3]
		if built:
			_prop(String(w[1]), pos)
			_ground_shadow(pos + Vector2(0, -1), Px.tex(PixelArt.shadow(52, 8, 0.22)))
			_add_window_at(pos + Vector2(-6 * (1 if int(w[0]) == 1 else -1), -22))
		else:
			_prop("scaffold_3", pos + Vector2(0, 1))
		for y in range(area.position.y, area.end.y):
			for x in range(area.position.x, area.end.x):
				_block(Vector2i(x, y))


## 厢房的那扇窗傍晚也亮。
func _add_window_at(pos: Vector2) -> void:
	var house := entities.get_node_or_null("House")
	if house != null:
		_add_window(house, pos - HOUSE_POS, 0)


func _wing_area(t: Vector2i) -> bool:
	for w: Array in WINGS:
		if Home.tier >= int(w[0]) or (Home.days_left > 0 and Home.tier + 1 == int(w[0])):
			var area: Rect2i = w[3]
			if area.grow_individual(0, 1, 0, 0).has_point(t):
				return true
	return false


func _no_scatter(t: Vector2i) -> bool:
	if _wing_area(t):
		return true
	# 老农场东、南两边原来各有两排树当边界。地图扩大以后那里是通路，不种；随机数照常取
	if _legacy_scatter and ((t.x >= FarmLand.OLD_W - 2 and t.y >= 2) or (t.y >= FarmLand.OLD_H - 2 and t.x >= 2)):
		return true
	# 新铺的路和碾场上不长树、不落石头
	if not _legacy_scatter and in_map(t) and (terrain[idx(t)] == DIRT or terrain[idx(t)] == PAVE):
		return true
	for id: StringName in Database.machines:
		var at := Database.machine(id).tile
		if absi(t.x - at.x) <= 1 and absi(t.y - at.y) <= 1:
			return true
	for id: StringName in Database.buildings:
		if Database.building(id).keeps_clear(t):
			return true
	return false


## 订了的建筑画出来（没盖好是工地），占地挡路；再看看动物该不该在外面。
func _sync_ranch() -> void:
	for id: StringName in Database.buildings:
		if not Animals.has_building(id):
			continue
		var def := Database.building(id)
		var prop := def.prop if Animals.is_built(id) else _scaffold_for(def)
		if _building_shown.get(id, "") == prop:
			continue
		if _building_sprites.has(id):
			_building_sprites[id].queue_free()
		else:
			for t in def.footprint():
				_clear_site(t)
				_block(t)
			_ground_shadow(def.anchor_px() + Vector2(0, -1), Px.tex(PixelArt.shadow(def.width * TS + 4, 9, 0.22)))
		_building_sprites[id] = _prop(prop, def.anchor_px())
		_building_shown[id] = prop
	_sync_critters()


## 工地的样子按建筑宽度挑。
func _scaffold_for(def: BuildingDef) -> String:
	var sized := "scaffold_%d" % def.width
	return sized if PropArt.has(sized) else "scaffold"


## 盖房子的地方原来有什么都清掉。
func _clear_site(t: Vector2i) -> void:
	_clear_decor(t)
	Farming.take_fence(t)
	if Farming.orchard.has(t):
		Farming.orchard.remove(t)
	if Farming.state.has_crop(t):
		Farming.state.uproot(t)
	if Foraging.item_at(map_id, t) != &"":
		Foraging.take(map_id, t)


## 这只动物现在在不在外面：白天，而且天气合它的意（喜欢雨的下雨也出来）。
func _is_out(def: AnimalDef) -> bool:
	if not def.outdoor or not Animals.is_built(def.building):
		return false
	if GameClock.minutes < 360.0 or GameClock.minutes >= 1080.0:
		return false
	if Weather.today == Weather.SNOW or Weather.today == Weather.STORM:
		return false
	if Animals.stays_in(GameClock.term_id()):
		return false
	return Weather.today != Weather.RAIN or def.rain_mood > 0


## 该在外面的放出来，该回去的收回去；已经在外面的不动它。
func _sync_critters() -> void:
	var want: Dictionary[int, bool] = {}
	for i in Animals.animals.size():
		if _is_out(Animals.def_of(i)):
			want[i] = true
	for k in range(_critters.size() - 1, -1, -1):
		var c := _critters[k]
		if want.has(c.index):
			want.erase(c.index)
			continue
		if c == _led:
			_led = null
		c.queue_free()
		_critters.remove_at(k)
	for i: int in want:
		var def := Animals.def_of(i)
		var home := Database.building(def.building)
		var c := Critter.new()
		c.walkable = _critter_can_walk
		c.water = _is_water
		c.yard = home.yard
		c.swim_area = home.swim
		c.avoid = player
		c.setup(def, i, _yard_spot(home.yard))
		entities.add_child(c)
		_critters.append(c)


## 有动物被送走了，下标都变了：全部收回去重放。
func _reset_critters() -> void:
	for c in _critters:
		c.queue_free()
	_critters.clear()
	_led = null
	_sync_critters()


func _critter_can_walk(t: Vector2i) -> bool:
	return in_map(t) and not _tile_blocked(t)


func _yard_spot(yard: Rect2i) -> Vector2:
	for n in 20:
		var t := yard.position + Vector2i(randi() % yard.size.x, randi() % yard.size.y)
		if _critter_can_walk(t):
			return tile_center(t) + Vector2(randf_range(-4, 4), randf_range(-2, 4))
	return tile_center(yard.position)


## 对着的这一格附近有没有动物。reach 是离格子中心多远以内算数。
func _critter_at(tile: Vector2i, reach: float = 13.0) -> Critter:
	var c := tile_center(tile)
	var best: Critter = null
	var best_d := reach
	for critter in _critters:
		var d := (critter.position + Vector2(0, -3)).distance_to(c)
		if d < best_d:
			best_d = d
			best = critter
	return best


## 这一格是不是哪栋建筑的正面墙。
func _building_at(tile: Vector2i) -> BuildingDef:
	for id: StringName in Animals.buildings:
		var def := Database.building(id)
		if tile.y == def.site.y and def.footprint().has(tile):
			return def
	return null


## 对着动物或建筑按使用键是什么动作：要伸手的（喂、摸、收）是 tend，只是看看、牵牛是 interact。
func _ranch_query(item: ItemDef, tile: Vector2i) -> StringName:
	# 对着建筑的墙就是建筑：动物站不进墙里，晃到墙根下的那只不该把这一下抢走
	var def := _building_at(tile)
	if def == null:
		var critter := _critter_at(tile)
		if critter == null:
			return &""
		var i := critter.index
		if _feeds(item, i) or not Animals.is_petted(i):
			return &"tend"
		return &"interact"
	if not Animals.is_built(def.id):
		return &"interact"
	if (item != null and item.kind == &"feed" and Animals.hungry_in(def.id, item.id) > 0) or Animals.stored(def.id) > 0:
		return &"tend"
	return &"interact"


## 手里这样东西是不是它吃的、它今天还没吃。
func _feeds(item: ItemDef, index: int) -> bool:
	return item != null and item.id == Animals.def_of(index).feed and not Animals.is_fed(index)


func _use_ranch(tile: Vector2i, item: ItemDef) -> bool:
	# 伸手的动作要一会儿，这期间它可能挪了两步：找的范围放宽一点
	var def := _building_at(tile)
	if def != null:
		_use_building(def, item)
		return true
	var critter := _critter_at(tile, 20.0)
	if critter != null:
		_use_critter(critter, item)
		return true
	return false


## 对着动物按一下：拿着它吃的就喂，不然摸一摸；都做过了，牛可以牵起来，别的看看心情。
func _use_critter(critter: Critter, item: ItemDef) -> void:
	var i := critter.index
	var def := Animals.def_of(i)
	if player != null:
		critter.notice(player.position)
	var top := critter.position + Vector2(0, -14)
	if _feeds(item, i):
		Animals.feed(i)
		Audio.play("plant", 0.0, -4.0)
		Audio.play(def.sound, 0.12, -6.0)
		Fx.burst(self, top, Color(0.97, 0.82, 0.3, 0.9), 6, 22.0, 0.5, 60.0)
		EventBus.banner_requested.emit("喂了%s" % Animals.name_of(i))
	elif Animals.pet(i):
		Audio.play(def.sound, 0.12, -4.0)
		Fx.burst(self, top, Color(0.95, 0.45, 0.55, 0.95), 5, 18.0, 0.7, -30.0)
		EventBus.banner_requested.emit("%s · 心情%s" % [Animals.name_of(i), Animals.mood_text(i)])
	elif def.plows:
		_toggle_lead(critter)
	else:
		EventBus.banner_requested.emit("%s · 心情%s · 今天%s" % [
			Animals.name_of(i), Animals.mood_text(i), "喂过了" if Animals.is_fed(i) else "还没喂"])


## 牵起牛，或者放开它。
func _toggle_lead(critter: Critter) -> void:
	var i := critter.index
	if _led == critter:
		_release_led()
		EventBus.banner_requested.emit("放开了%s" % Animals.name_of(i))
		return
	if not Animals.can_plow(i):
		var why := "今天干够了，不肯再走" if Animals.plows_left(i) <= 0 else "闷闷不乐，不肯跟你走"
		EventBus.banner_requested.emit("%s%s" % [Animals.name_of(i), why])
		Audio.play("deny", 0.0, -4.0)
		return
	_release_led()
	_led = critter
	critter.leader = player
	Audio.play(Animals.def_of(i).sound, 0.1, -4.0)
	EventBus.banner_requested.emit("牵着%s。锄头一下开一整行，今天还能犁 %d 行" % [Animals.name_of(i), Animals.plows_left(i)])


func _release_led() -> void:
	if _led != null and is_instance_valid(_led):
		_led.leader = null
	_led = null


## 牵着牛、牛就在身边的时候，一锄头开一整行：从 tile 顺着朝向数，到挡住的地方为止。
func plow_row(tile: Vector2i, facing: Facing) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if _led == null or not is_instance_valid(_led) or not Animals.can_plow(_led.index):
		return out
	if player != null and _led.position.distance_to(player.position) > 48.0:
		return out
	var step := Vector2i(Player.DIR_VECTORS[facing])
	for k in Animals.PLOW_LENGTH:
		var t := tile + step * k
		if not _can_till(t) or Farming.state.is_canal(t):
			break
		out.append(t)
	return out


func plowed() -> void:
	if _led == null or not is_instance_valid(_led):
		return
	var i := _led.index
	Animals.plowed(i)
	Audio.play(Animals.def_of(i).sound, 0.1, -6.0)
	if not Animals.can_plow(i):
		EventBus.banner_requested.emit("%s今天干够了" % Animals.name_of(i))
		_release_led()


## 对着建筑的正面墙按一下：拿着饲料把没喂的都喂上；有攒着的东西就收；不然看看情况。
func _use_building(def: BuildingDef, item: ItemDef) -> void:
	if not Animals.is_built(def.id):
		EventBus.banner_requested.emit("青竹正在盖%s，还要 %d 天" % [def.name, Animals.days_left(def.id)])
		return
	if item != null and item.kind == &"feed" and Animals.hungry_in(def.id, item.id) > 0:
		var n := Animals.feed_all(def.id, item.id)
		Audio.play("plant", 0.0, -4.0)
		EventBus.banner_requested.emit("往%s里添了%s，喂了 %d 份" % [def.name, item.name, n])
		return
	if Animals.stored(def.id) > 0:
		var got := Animals.collect(def.id)
		if got.is_empty():
			EventBus.banner_requested.emit("背包满了")
			Audio.play("deny", 0.0, -4.0)
			return
		var counts: Dictionary[StringName, int] = {}
		for e: Array in got:
			counts[e[0]] = int(counts.get(e[0], 0)) + 1
		var parts := PackedStringArray()
		for id: StringName in counts:
			parts.append("%s ×%d" % [Database.item(id).name, counts[id]])
		Audio.play("harvest")
		var first: StringName = got[0][0]
		Fx.pop_icon(self, def.anchor_px() + Vector2(0, -20), Px.tex(PixelArt.icon(Database.item(first).icon)))
		EventBus.banner_requested.emit("从%s里收了 %s" % [def.name, "、".join(parts)])
		return
	var living := Animals.count_in(def.id)
	if living == 0:
		EventBus.banner_requested.emit("%s：还空着。去问问阿牧" % def.name)
	elif Animals.hungry_in(def.id) > 0:
		EventBus.banner_requested.emit("%s：住着 %d / %d，今天还有 %d 份没喂" % [def.name, living, def.capacity, Animals.hungry_in(def.id)])
	else:
		EventBus.banner_requested.emit("%s：住着 %d / %d，今天都照看过了" % [def.name, living, def.capacity])


# ---------------------------------------------------------------- 稻草人、乌鸦、猫狗

func _sync_scarecrows() -> void:
	for t: Vector2i in _scarecrow_sprites:
		_scarecrow_sprites[t].queue_free()
	_scarecrow_sprites.clear()
	for t: Vector2i in Farming.scarecrows:
		_clear_decor(t)
		var s := _prop("scarecrow", tile_center(t) + Vector2(0, 6))
		if Farming.scarecrow_fallen(t):
			# 倒了：整个横过来躺在地上
			s.rotation = PI / 2.0
			s.position += Vector2(-10, -3)
		_scarecrow_sprites[t] = s


## 对着稻草人按一下：倒了的扶起来，站着的收回背包。这一格有稻草人就返回真。
func _use_scarecrow(tile: Vector2i) -> bool:
	if not Farming.has_scarecrow(tile):
		return false
	if Farming.raise_scarecrow(tile):
		Audio.play("plant")
		EventBus.banner_requested.emit("把稻草人扶起来了")
	elif not GameState.inventory.can_add(Farming.SCARECROW_ID, 1):
		EventBus.banner_requested.emit("背包满了")
		Audio.play("deny", 0.0, -4.0)
	elif Farming.take_scarecrow(tile):
		GameState.inventory.add(Farming.SCARECROW_ID, 1)
		Audio.play("select", 0.0, -6.0)
		EventBus.banner_requested.emit("把稻草人收起来了")
	return true


## 早上十点以前，被刨过的地里还站着乌鸦；人一走近就飞。
func _spawn_crows() -> void:
	if GameClock.minutes >= 600.0:
		return
	for t in Farming.raided:
		var def := AnimalDef.new()
		def.id = &"crow"
		def.name = "乌鸦"
		def.sheet = "crow"
		def.speed = 14.0
		var crow := Critter.new()
		crow.walkable = _critter_can_walk
		crow.yard = Rect2i(t - Vector2i(1, 1), Vector2i(3, 3))
		crow.setup(def, -1, tile_center(t) + Vector2(0, 3))
		entities.add_child(crow)
		_crows.append(crow)


func _flee(crow: Critter) -> void:
	Audio.play("caw", 0.1, -6.0)
	crow.set_process(false)
	var side := 1.0 if player == null or crow.position.x >= player.position.x else -1.0
	var tw := create_tween().set_parallel()
	tw.tween_property(crow, "position", crow.position + Vector2(side * 70.0, -90.0), 0.7)
	tw.tween_property(crow, "modulate:a", 0.0, 0.7)
	tw.chain().tween_callback(crow.queue_free)


## 猫狗白天在屋前转，下雨下雪和夜里回屋。
func _sync_pet() -> void:
	var kind := Animals.pet_kind()
	var out := kind != &"" and GameClock.minutes >= 360.0 and GameClock.minutes < 1260.0 \
		and Weather.today != Weather.RAIN and Weather.today != Weather.STORM and Weather.today != Weather.SNOW
	if out == (_pet != null):
		return
	if not out:
		_pet.queue_free()
		_pet = null
		return
	var def := AnimalDef.new()
	def.id = kind
	def.name = PET_NAMES[kind]
	def.sheet = String(kind)
	def.speed = 26.0 if kind == &"dog" else 20.0
	def.sound = "bark" if kind == &"dog" else "meow"
	_pet = Critter.new()
	_pet.walkable = _critter_can_walk
	_pet.yard = PET_YARD
	_pet.avoid = player
	_pet.setup(def, -1, _yard_spot(PET_YARD))
	entities.add_child(_pet)


func _pet_at(tile: Vector2i, reach: float = 13.0) -> bool:
	return _pet != null and (_pet.position + Vector2(0, -3)).distance_to(tile_center(tile)) < reach


## 摸摸家里的猫狗。雾天头一回摸狗，它钻进雾里叼一件遗物回来。对着的是它就返回真。
func _use_pet(tile: Vector2i) -> bool:
	if not _pet_at(tile, 20.0):
		return false
	var kind := Animals.pet_kind()
	var pet_name: String = PET_NAMES[kind]
	if player != null:
		_pet.notice(player.position)
	var first := Animals.stroke_pet()
	Audio.play(_pet.def.sound, 0.12, -5.0)
	Fx.burst(self, _pet.position + Vector2(0, -14), Color(0.95, 0.45, 0.55, 0.95), 5, 18.0, 0.7, -30.0)
	if first and kind == &"dog" and Weather.is_foggy():
		var relic := _dog_find()
		if relic != &"":
			GameState.inventory.add(relic, 1)
			GameState.set_flag(StringName("relic_" + String(relic)))
			Audio.play("harvest", 0.0, -2.0)
			Fx.pop_icon(self, _pet.position + Vector2(0, -18), Px.tex(PixelArt.icon(Database.item(relic).icon)))
			EventBus.banner_requested.emit("%s钻进雾里，叼回来一样东西：%s" % [pet_name, Database.item(relic).name])
			return true
	if kind == &"dog":
		EventBus.banner_requested.emit("%s摇着尾巴往你手心里拱" % pet_name if first else "%s趴下了，尾巴还在摇" % pet_name)
	else:
		EventBus.banner_requested.emit("%s眯起眼睛，呼噜呼噜" % pet_name if first else "%s舔了舔爪子，不理你了" % pet_name)
	return true


## 狗在雾里找到哪件遗物：还没找到过、也不是今天地上要掉的那件；背包放不下或都找完了返回空。
func _dog_find() -> StringName:
	for n in 8:
		var id := Foraging.pick_relic(randf())
		if id != &"" and id != Foraging.pending_relic and GameState.inventory.can_add(id, 1):
			return id
	return &""


# ---------------------------------------------------------------- 加工设备

## 买下的设备摆出来，占一格挡路；做好了头顶露出成品。
func _sync_machines() -> void:
	for id: StringName in Database.machines:
		if not Crafting.owned(id):
			continue
		var def := Database.machine(id)
		if not _machine_sprites.has(id):
			_clear_site(def.tile)
			_block(def.tile)
			var pos := tile_center(def.tile) + Vector2(0, 6)
			var s := _prop(def.prop, pos)
			_ground_shadow(pos + Vector2(0, -1), _small_shadow)
			var mark := Sprite2D.new()
			mark.name = "Ready"
			mark.position = Vector2(0, -38)
			s.add_child(mark)
			_machine_sprites[id] = s
		var done: Sprite2D = _machine_sprites[id].get_node("Ready")
		done.visible = Crafting.state(id) == Crafting.READY
		if done.visible:
			done.texture = Px.tex(PixelArt.icon(Database.item(Crafting.output_of(id)).icon))


func _machine_at(tile: Vector2i) -> MachineDef:
	for id: StringName in Database.machines:
		if Database.machine(id).tile == tile and Crafting.owned(id):
			return Database.machine(id)
	return null


## 对着设备按一下：做好了就收；手里的原料够就放进去；不然说说它现在怎么样。这一格是设备就返回真。
func _use_machine(tile: Vector2i, item: ItemDef) -> bool:
	var def := _machine_at(tile)
	if def == null:
		return false
	var id := def.id
	var top := tile_center(tile) + Vector2(0, -14)
	if Crafting.state(id) == Crafting.READY:
		var got := Crafting.take(id)
		if got.is_empty():
			EventBus.banner_requested.emit("背包满了")
			Audio.play("deny", 0.0, -4.0)
			return true
		var out_id: StringName = got[0]
		var out := Database.item(out_id)
		Audio.play("harvest")
		Fx.pop_icon(self, top, Px.tex(PixelArt.icon(out.icon)))
		EventBus.banner_requested.emit("从%s里收了 %s" % [def.name, out.name])
	elif Crafting.can_put(id, GameState.selected_slot):
		var n := Crafting.need(id, item.id)
		Crafting.put(id, GameState.selected_slot)
		Audio.play("plant", 0.0, -3.0)
		Fx.burst(self, top, Color("e8dcc0"), 6, 30.0)
		EventBus.banner_requested.emit("放进%s：%s ×%d，%d 天后来收%s" % [
			def.name, item.name, n, Crafting.days_left(id), Database.item(Crafting.output_of(id)).name])
	elif Crafting.state(id) == Crafting.WORKING:
		EventBus.banner_requested.emit("%s：%s还要 %d 天" % [def.name, Database.item(Crafting.output_of(id)).name, Crafting.days_left(id)])
	elif item != null and Crafting.accepts(id, item.id):
		EventBus.banner_requested.emit("%s一次要放 %d 个%s" % [def.name, Crafting.need(id, item.id), item.name])
		Audio.play("deny", 0.0, -6.0)
	else:
		EventBus.banner_requested.emit("%s：空着。%s" % [def.name, def.desc])
	return true


func _can_till(t: Vector2i) -> bool:
	if not in_map(t) or occupied.has(t) or Farming.orchard.has(t) or Foraging.item_at(map_id, t) != &"" or Farming.has_scarecrow(t):
		return false
	# 雾里的地块开不了：溪东要柏先生的许可（忆五级），别的看灯（决策 147）。栅栏底下也不行
	if not FarmLand.open_tile(t) or Farming.has_fence(t):
		return false
	if terrain[idx(t)] == WATER or terrain[idx(t)] == PAVE or solid[idx(t)] != 0:
		return false
	# 房子前面那一排留作通道，不让开垦
	return t.y > 6 or t.x >= FarmLand.OLD_W


# ---------------------------------------------------------------- 布局

func _layout() -> void:
	_fill(15, 9, 26, 16, DIRT)
	_fill(7, 7, 8, 12, DIRT)
	_fill(7, 11, 14, 12, DIRT)
	_fill(27, 11, 29, 12, DIRT)
	_fill(0, TOWN_EXIT_ROWS[0], 6, TOWN_EXIT_ROWS[1], DIRT)
	for y in H:
		for x in W:
			var dx := (x - 33.0) / 4.3
			var dy := (y - 17.5) / 3.3
			if dx * dx + dy * dy <= 1.0:
				terrain[y * W + x] = WATER
				solid[y * W + x] = 1
	# 一条弯弯曲曲的小溪，从北流到南
	for y in H:
		var x0 := _stream_x(y)
		var x1 := x0
		if y >= FarmLand.OLD_H:
			# 新的一段溪拐得急，和上一行接上，不留斜角的断口
			x0 = mini(x0, _stream_x(y - 1))
			x1 = maxi(x1, _stream_x(y - 1))
		for x in range(x0, x1 + 2):
			terrain[y * W + x] = WATER
			solid[y * W + x] = 1
	_layout_new()


## 池塘按池塘算，东边的小溪按溪水算（和南溪一样的鱼）。
func fishing_water(tile: Vector2i) -> StringName:
	if not _is_water(tile) or planks.has(tile) or stones.has(tile):
		return &""
	if tile.x >= _stream_x(tile.y) - 1 and tile.x <= _stream_x(tile.y) + 2:
		return &"stream"
	return &"pond"


## 见过文鳐以后，天数能被 3 整除的夜里，飞到池塘这一格上。
## 夜里和竹海、雾岛一样从 19:00 起，夏至推迟、冬至提前。
## 凌晨还没到天亮（DAY_START，6:00）也算夜里。白天、没见过、别的日子都不来。
func wenyao_out() -> bool:
	var after_dusk := GameClock.minutes >= 1140.0 + GameClock.dusk_shift()
	var before_dawn := GameClock.minutes < GameClock.DAY_START
	return Bestiary.seen(&"wenyao") and (after_dusk or before_dawn) and GameClock.day % 3 == 0


## 这一格本来没有别的事可做，才让人看文鳐。拿着鱼竿、蟹笼时不抢。
func _wenyao_use(tile: Vector2i) -> StringName:
	if tile == WENYAO_TILE and wenyao_out():
		return &"interact"
	return &""


func _sync_wenyao() -> void:
	if entities == null:
		return
	if wenyao_out():
		if _wenyao == null:
			_wenyao = _make_wenyao()
		return
	if _wenyao == null:
		return
	_wenyao.queue_free()
	_wenyao = null


## 贴帧和竹海的 _actor 一样。文鳐没有站立，用 flap、朝右。不改 solid，也不占格子。
func _make_wenyao() -> Sprite2D:
	if _wenyao_sheet == null:
		_wenyao_sheet = CharacterSheet.load_sheet("wenyao", CharacterSheet.CREATURE_DIR)
	var spr := Sprite2D.new()
	spr.texture = _wenyao_sheet.texture
	spr.centered = false
	spr.region_enabled = true
	spr.region_rect = _wenyao_sheet.region(&"flap", Facing.RIGHT, 0)
	spr.offset = Vector2(-_wenyao_sheet.cell / 2.0, -float(_wenyao_sheet.foot_row))
	spr.position = tile_center(WENYAO_TILE) + Vector2(0, 4)
	spr.set_meta(&"who", "wenyao")
	spr.set_meta(&"face", Facing.RIGHT)
	spr.set_meta(&"anim", &"flap")
	entities.add_child(spr)
	return spr


func _animate_wenyao() -> void:
	if _wenyao == null or not is_instance_valid(_wenyao) or _wenyao_sheet == null:
		return
	var count := _wenyao_sheet.frame_count(&"flap")
	var frame := int(_time * _wenyao_sheet.fps(&"flap")) % maxi(count, 1)
	_wenyao.region_rect = _wenyao_sheet.region(&"flap", Facing.RIGHT, frame)


## 小溪在这一行最靠西的那一格
func _stream_x(y: int) -> int:
	return FarmLand.stream_x(y)


## 采集物可以落在哪些格子：能走到的空草地。shore 为真时只要紧挨着水的。
func _forage_tiles(shore: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var farm := Farming.state
	for y in range(2, H - 2):
		for x in range(2, W - 2):
			var t := Vector2i(x, y)
			# 老农场那一片还是原来的范围；新地块开了才长东西
			var old := y >= 7 and y < FarmLand.OLD_H - 2 and x < _stream_x(y)
			if not old and (FarmLand.region_of(t) == FarmLand.HOME or not FarmLand.open_tile(t)):
				continue
			if not _is_free(t) or farm.is_tilled(t) or farm.is_canal(t) or Farming.orchard.has(t) or Farming.has_fence(t):
				continue
			if absi(x - START_TILE.x) + absi(y - START_TILE.y) < 2:
				continue
			if _next_to_water(t) == shore:
				out.append(t)
	return out


func _orchard_texture(t: Vector2i) -> Texture2D:
	var orchard := Farming.orchard
	var stage := orchard.stage_at(t)
	var fruit := orchard.fruit_at(t) if stage == 2 else 0
	var fallen := orchard.fallen_at(t) if stage == 2 else 0
	var item := orchard.item_at(t) if fruit + fallen > 0 else &""
	var key := "%s:%d:%d:%s:%d:%d" % [orchard.kind_at(t), stage, _season, item, fruit, fallen]
	if not _orchard_tex.has(key):
		_orchard_tex[key] = Px.tex(TreeArt.tree(orchard.kind_at(t), stage, _season, item, fruit, fallen))
	return _orchard_tex[key]


func _sync_orchard() -> void:
	var orchard := Farming.orchard
	for t: Vector2i in _orchard_nodes.keys():
		if not orchard.has(t):
			for n: Node in _orchard_nodes[t]:
				n.queue_free()
			_orchard_nodes.erase(t)
	for t: Vector2i in orchard.trees:
		var pos := Vector2(t.x * TS + 8, t.y * TS + 14)
		if not _orchard_nodes.has(t):
			var sprite := _sprite(null, pos, Vector2(-TreeArt.AX, -TreeArt.AY))
			var shade := _ground_shadow(pos + Vector2(0, -1), null)
			_orchard_nodes[t] = [sprite, shade]
		var nodes: Array = _orchard_nodes[t]
		var s: Sprite2D = nodes[0]
		var shadow: Sprite2D = nodes[1]
		var stage := orchard.stage_at(t)
		s.texture = _orchard_texture(t)
		s.material = _tree_mat if stage == 2 else null
		shadow.texture = _tree_shadow if stage == 2 else _small_shadow
		shadow.visible = stage > 0
	_refresh_orchard_falling()


## 果树按季节落东西：春天花瓣、秋天落叶、冬天掉雪，夏天不落。
## 只给长成的树挂，树增减时跟着重摆一次。
func _refresh_orchard_falling() -> void:
	_clear_falling()
	var kind := FieldMotion.fall_kind(GameClock.season(), false)
	if kind == &"":
		return
	var homes: Array = []
	for t: Vector2i in Farming.orchard.trees:
		if Farming.orchard.stage_at(t) == 2:
			homes.append(tile_center(t) + Vector2(0, -20))
	_add_falling(kind, homes, 2)


func _place_objects() -> void:
	# 房子
	var house := _prop("house", HOUSE_POS)
	_add_window(house, Vector2(-34, -46), 0)
	_add_window(house, Vector2(34, -46), 1)
	_add_plume(house, Vector2(-18, -84), false)
	house.name = "House"
	_sync_plaque()
	_place_wings()
	# 屋顶后面那两排也挡住，免得人走到屋顶底下看不见
	for y in range(2, 7):
		for x in range(5, 11):
			_block(Vector2i(x, y))
	_ground_shadow(HOUSE_POS + Vector2(0, -1), Px.tex(PixelArt.shadow(108, 10, 0.22)))

	# 信箱
	var box_pos := tile_center(MAILBOX_TILE) + Vector2(0, 6)
	_prop("mailbox", box_pos)
	_ground_shadow(box_pos + Vector2(0, -1), Px.tex(PixelArt.shadow(12, 4, 0.22)))
	_block(MAILBOX_TILE)

	# 出货箱
	var bin_pos := tile_center(BIN_TILE) + Vector2(0, 6)
	_sprite(Px.tex(PixelArt.ship_bin()), bin_pos, Vector2(-9, -16))
	_ground_shadow(bin_pos + Vector2(0, -1), Px.tex(PixelArt.shadow(18, 5, 0.22)))
	_block(BIN_TILE)
	_sync_stake()

	# 栅栏现在是人自己摆的（Farming.fences）。原来那一圈先占着格子撒树撒草，
	# 撒出来的位置才和扩大以前一样；撒完放开。
	var ring := Farming.old_fence()
	for t: Vector2i in ring:
		_block(t)
	_reserve(0, TOWN_EXIT_ROWS[0] - 1, 1, TOWN_EXIT_ROWS[1] + 3)
	_legacy_scatter = true
	_scatter_trees(30)
	_scatter_bushes(40)
	_scatter_tufts(500)
	_legacy_scatter = false
	for t: Vector2i in ring:
		solid[idx(t)] = 0
		occupied.erase(t)


func _keep_clear(t: Vector2i, margin: int) -> bool:
	return super._keep_clear(t, margin) or absi(t.x - START_TILE.x) + absi(t.y - START_TILE.y) < 4


# ---------------------------------------------------------------- 扩出来的地（决策 147）

## 老农场以外的地形。老农场那一片（52×38）的地形一格不动。
func _layout_new() -> void:
	# 东岗：两层的山岗，边上进进出出，每层两格高的石崖，各一道石阶
	_raise(81, 3, 96, 28, 2)
	_raise(79, 8, 80, 24, 2)
	_raise(80, 5, 80, 7, 2)
	_raise(82, 29, 94, 31, 2)
	_raise(84, 32, 91, 33, 2)
	_steps(86, 87, 34)
	_raise(83, 3, 94, 15, 4)
	_raise(82, 6, 82, 12, 4)
	_raise(84, 16, 92, 17, 4)
	_raise(85, 18, 90, 19, 4)
	_steps(87, 88, 20)
	# 南洼的苇塘，一条沟通到小溪
	_lake(MARSH_POND, 9.5, 4.2, 0.5, 61)
	_trail([Vector2i(29, 64), Vector2i(40, 66), Vector2i(FarmLand.stream_x(66), 66)], 1, WATER)
	# 东坡角上的小塘
	_lake(SLOPE_POND, 4.2, 2.6, 0.4, 62)
	# 碾场：一圈石板地
	for t in _blob(THRESH, 5.2, 3.2, 0.25, 63):
		terrain[idx(t)] = PAVE
	# 往南的大路：穿过南坡、南洼，到通古木林的口子
	_walk([Vector2i(30, 38), Vector2i(30, 44), Vector2i(34, 50), Vector2i(38, 57), Vector2i(40, 63), Vector2i(40, 71)], 2, DIRT, false)
	# 岔到溪边，踩石头过溪上东坡，到碾场
	_walk([Vector2i(32, 46), Vector2i(40, 47), Vector2i(52, 47), Vector2i(62, 48), Vector2i(68, 50)], 1, DIRT, true)
	# 碾场往北到东岗的石阶，再上到亭子
	_walk([Vector2i(72, 47), Vector2i(80, 42), Vector2i(86, 38), Vector2i(86, 35)], 1, DIRT, false)
	_walk([Vector2i(86, 33), Vector2i(87, 24), Vector2i(87, 21)], 1, DIRT, false)
	_walk([Vector2i(87, 19), Vector2i(88, 12)], 1, DIRT, false)
	# 溪上的旧木桥，桥那头的路通到塌了的院子，再绕到东岗脚下
	for t: Vector2i in BRIDGE_TILES:
		_plank(t)
	_walk([Vector2i(47, 11), Vector2i(55, 12), Vector2i(60, 14)], 2, DIRT, false)
	_walk([Vector2i(62, 15), Vector2i(70, 24), Vector2i(78, 32), Vector2i(85, 36)], 1, DIRT, false)
	# 苇塘北岸伸进去一截钓台
	for y in range(56, 63):
		if _is_water(Vector2i(20, y)):
			_plank(Vector2i(20, y))
	for x in range(19, 22):
		if _is_water(Vector2i(x, 62)):
			_plank(Vector2i(x, 62))
	# 四边的林子。老农场那一片的边还是原来撒的那两排树
	_fringe(3, 3, 21, [Rect2i(38, 64, 6, 8)])
	for y in FarmLand.OLD_H:
		for x in FarmLand.OLD_W:
			woods[y * W + x] = 0


func _place_new_land() -> void:
	_add_woods(["round0", "old0", "round1", "plum0", "round2", "pine0"])
	# 溪东：一座塌了的院子。这家人被忘了。
	_building("relay_ruin", RUIN[0], RUIN[1], RUIN[2], RUIN[3], false)
	_clue(Vector2i(RUIN[0] + 1, RUIN[1] - 1), "塌了一半的屋子。灶台还在，锅里长出了一棵小树。")
	_clue(Vector2i(RUIN[0] + 2, RUIN[1] - 1), "门框上刻着几道身高线。旁边原来写着名字，现在是一片白。")
	_clue(Vector2i(RUIN[0] + 3, RUIN[1] - 1), "墙上钉着一排钉子，挂过农具。钉子的间距和你家墙上的一样。")
	_prop("well", tile_center(WELL) + Vector2(8, 8))
	_block_rect(WELL.x, WELL.y - 1, WELL.x + 1, WELL.y)
	for dx in 2:
		_clue(WELL + Vector2i(dx, 0), "井沿磨得很亮。有人在这里打了很多年的水。")
	_place_old_fence()
	var pear := ["一棵老梨树。没人管，还在结果，果子落了一地。", "树干上钉着一块小木牌，牌上的字化开了。", "老树。树下有一圈石头，像是谁给它垒的。"]
	for k in OLD_TREES.size():
		var at: Vector2i = OLD_TREES[k]
		if _is_free(at):
			_tree("old%d" % (k % 3), at)
			_clue(at, pear[k % 3])
	_lamp_post(Vector2i(57, 15))
	_hang_clue(Vector2i(49, 10), WildArt.signpost(), 2.0)
	_clue(Vector2i(49, 10), "路牌。字全没了，只剩一个往东的箭头。")
	# 南坡：坡顶一棵大树，树下一条凳
	_tree("old1", BIG_TREE)
	_clue(BIG_TREE, "老槐树。树荫底下的地是凉的。")
	_prop("bench", tile_center(BIG_TREE + Vector2i(2, 1)) + Vector2(8, 4))
	_block_rect(BIG_TREE.x + 2, BIG_TREE.y + 1, BIG_TREE.x + 3, BIG_TREE.y + 1)
	_hang_clue(Vector2i(28, 40), WildArt.signpost(), 2.0)
	_clue(Vector2i(28, 40), "路牌。往南：南洼、古木林。往东：过溪上东坡。")
	# 南洼：通古木林的口子，雾堵着
	_block_rect(40, 69, 41, 71)
	_add_fog_bank(Rect2i(39, 69, 4, 3), Vector2(0, 1))
	for x in range(40, 42):
		_clue(Vector2i(x, 69), "往古木林去的路。雾堵在路口，看不见那头。")
	_lamp_post(Vector2i(38, 60))
	var reeds: Array[Texture2D] = [Px.tex(WildArt.reed(0, _season)), Px.tex(WildArt.reed(1, _season))]
	for pond: Array in [[MARSH_POND, 12, 6], [SLOPE_POND, 6, 4]]:
		var c: Vector2 = pond[0]
		for y in range(int(c.y) - int(pond[2]), int(c.y) + int(pond[2]) + 1):
			for x in range(int(c.x) - int(pond[1]), int(c.x) + int(pond[1]) + 1):
				var t := Vector2i(x, y)
				var roll := Px.h2(x * 5 + 1, y * 3 + 8)
				if _is_water(t) and not planks.has(t) and not _is_water(t + Vector2i(0, 1)) and roll % 5 < 3:
					var r: Texture2D = reeds[roll % 2]
					_sprite(r, Vector2(x * TS + 8 + roll % 5 - 2, y * TS + 13), Vector2(-8, -30))
	_tree("willow0", Vector2i(88, 59))
	_tree("willow1", Vector2i(8, 62))
	# 东坡：碾场上的石碌碡，坡上一棵老树
	_thing(Px.tex(WildArt.roller()), Vector2i(72, 50))
	_clue(Vector2i(72, 50), "石碌碡。碾场很久没人用了，石板缝里长了草。")
	_tree("old2", Vector2i(62, 43))
	_clue(Vector2i(62, 43), "树上还挂着半截秋千的绳子。")
	# 东岗：岗顶一座亭子，望得见镇子
	_building("pavilion", LOOKOUT[0], LOOKOUT[1], LOOKOUT[2], LOOKOUT[3], false)
	_clue(Vector2i(LOOKOUT[0] + 1, LOOKOUT[1] - 1), "岗顶的亭子。往西望，自家的屋顶、镇上的灯都在脚下。")
	_prop("bench", tile_center(Vector2i(91, 13)) + Vector2(8, 4))
	_block_rect(91, 13, 92, 13)
	# 疏林：留出大片空地给人开垦
	_grove(Rect2i(3, 39, 12, 16), 6, ["round0", "plum0", "round1"])
	_grove(Rect2i(3, 56, 46, 14), 5, ["willow0", "round2", "round0"])
	_grove(Rect2i(15, 39, 32, 17), 2, ["round1", "plum1"])
	_grove(Rect2i(50, 38, 47, 32), 4, ["old0", "round0", "plum0", "round2"])
	_grove(Rect2i(80, 3, 16, 31), 7, ["pine0", "pine1", "old2"])
	_grove(Rect2i(48, 3, 30, 34), 5, ["old0", "round1", "plum1"])
	# 乱石：镐子敲得开
	for y in H:
		for x in W:
			var t := Vector2i(x, y)
			if FarmLand.rubble_roll(t) and not Farming.is_cleared(t) and _is_free(t) and not _keep_clear(t, 1) and not _no_scatter(t):
				_wild_thing(t, true, Px.h2(x, y) % 2)
	# 草丛和小花
	var tuft := Px.tex(PixelArt.tuft(_season))
	var bits: Array[Texture2D] = [tuft, tuft, tuft]
	if _season < 3:
		for i in (2 if _season < 2 else 1):
			bits.append(Px.tex(PixelArt.flower(i * 2 + _season % 2)))
	_sprinkle(Rect2i(FarmLand.OLD_W, 0, W - FarmLand.OLD_W, FarmLand.OLD_H), 190, bits, 7, _tuft_mat)
	_sprinkle(Rect2i(0, FarmLand.OLD_H, W, H - FarmLand.OLD_H), 190, bits, 9, _tuft_mat)


func _lamp_post(t: Vector2i) -> void:
	var pos := tile_center(t) + Vector2(0, 6)
	_prop("stone_lamp", pos)
	_block(t)
	_add_night_light(pos + Vector2(0, -16), 1.8)


## 塌院子外面那一圈旧篱笆：缺了一半，剩下的还立着。
func _place_old_fence() -> void:
	var kept: Dictionary[Vector2i, bool] = {}
	var r := OLD_YARD
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var edge := x == r.position.x or y == r.position.y or x == r.end.x - 1 or y == r.end.y - 1
			var t := Vector2i(x, y)
			if edge and _is_free(t) and Px.h2(x * 3 + 2, y * 7 + 1) % 100 < 58:
				kept[t] = true
	for t: Vector2i in kept:
		_prop("fence_%d" % _fence_mask(kept, t), tile_center(t))
		_block(t)
		_clue(t, "别人家的旧篱笆。扎法和你家那一圈一模一样。")


static func _fence_mask(tiles: Dictionary, t: Vector2i) -> int:
	var m := 0
	if tiles.has(t + Vector2i(0, -1)):
		m |= 1
	if tiles.has(t + Vector2i(1, 0)):
		m |= 2
	if tiles.has(t + Vector2i(0, 1)):
		m |= 4
	if tiles.has(t + Vector2i(-1, 0)):
		m |= 8
	return m


# ---------------------------------------------------------------- 雾、栅栏、清地

## 没开的地块盖着雾。开着的地块有变化才重画。
func _sync_fog() -> void:
	var key := ""
	for region in FarmLand.open_regions():
		key += String(region) + ","
	if key == _fog_key:
		return
	_fog_key = key
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var any := false
	for y in H:
		for x in W:
			var shut := not FarmLand.open_tile(Vector2i(x, y))
			any = any or shut
			img.set_pixel(x, y, Color(1, 1, 1, 1.0 if shut else 0.0))
	if _fog == null:
		_fog = Sprite2D.new()
		_fog.name = "LandFog"
		_fog.centered = false
		_fog.scale = Vector2(TS, TS)
		_fog.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_fog.z_index = 5
		var shader := Shader.new()
		shader.code = FOG_SHADER
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter(&"tiles", Vector2(W, H))
		_fog.material = mat
		add_child(_fog)
	_fog.texture = ImageTexture.create_from_image(img)
	_fog.visible = any


## 头一回看见一块地的雾退了，说一句。一次只说一块。
func _announce_land() -> void:
	for region in FarmLand.open_regions():
		var flag := StringName("farm_land_" + String(region))
		if region == FarmLand.HOME or GameState.has_flag(flag):
			continue
		GameState.set_flag(flag)
		var line: String = FarmLand.OPENED[region]
		if not GameState.has_flag(&"farm_land_tip"):
			GameState.set_flag(&"farm_land_tip")
			line += "地里的乱石用镐子敲，灌木用锄头刨。"
		EventBus.banner_requested.emit(line)
		return


func _sync_fences() -> void:
	for t: Vector2i in _fence_sprites:
		_fence_sprites[t].queue_free()
	_fence_sprites.clear()
	if entities == null:
		return
	for t: Vector2i in Farming.fences:
		_clear_decor(t)
		_fence_sprites[t] = _prop("fence_%d" % _fence_mask(Farming.fences, t), tile_center(t))


## 能不能在这一格摆栅栏：能开垦的空地，没有耕地和水渠。
func _can_fence(t: Vector2i) -> bool:
	return _can_till(t) and not Farming.state.is_tilled(t) and not Farming.state.is_canal(t)


## 空手或拿着栅栏对着一段栅栏按一下：收回背包。这一格是栅栏就返回真。
func _use_fence(tile: Vector2i, item: ItemDef) -> bool:
	if not Farming.has_fence(tile) or (item != null and item.id != Farming.FENCE_ID):
		return false
	if not GameState.inventory.can_add(Farming.FENCE_ID, 1):
		EventBus.banner_requested.emit("背包满了")
		Audio.play("deny", 0.0, -4.0)
	elif Farming.take_fence(tile):
		GameState.inventory.add(Farming.FENCE_ID, 1)
		Audio.play("select", 0.0, -6.0)
	return true


func _rubble_at(t: Vector2i) -> bool:
	return _bush_nodes.has(t) and bool(_bush_nodes[t][2])


func _shrub_at(t: Vector2i) -> bool:
	return _bush_nodes.has(t) and not bool(_bush_nodes[t][2])


## 锄头刨掉一丛灌木。这一格是灌木就返回真。
func _clear_shrub(tile: Vector2i) -> bool:
	if not _shrub_at(tile):
		return false
	Farming.clear_wild(tile)
	_remove_wild(tile)
	Fx.burst(self, tile_center(tile), Color("5f9a4a"), 10, 55.0)
	return true


## 镐子敲开一块石头，得一块石头。
func _break_rock(tile: Vector2i, quiet: bool) -> void:
	if not _rubble_at(tile):
		return
	if not GameState.inventory.can_add(&"stone", 1):
		EventBus.banner_requested.emit("背包满了")
		Audio.play("deny", 0.0, -4.0)
		return
	Farming.clear_wild(tile)
	_remove_wild(tile)
	GameState.inventory.add(&"stone", 1)
	if not quiet:
		Audio.play("hoe", 0.0, -2.0)
		EventBus.screen_shake_requested.emit(1.5)
	var c := tile_center(tile)
	Fx.burst(self, c, Color("9aa0a8"), 10, 60.0)
	Fx.pop_land(self, c + Vector2(0, -6), Px.tex(PixelArt.icon(Database.item(&"stone").icon)))


## 存档里清掉过的石头和灌木，载入时拿掉。
func _apply_cleared() -> void:
	for t: Vector2i in Farming.cleared:
		_remove_wild(t)


## 这一格没有别的事可做时：有能看的东西就看，不然看文鳐。
func _look_use(tile: Vector2i) -> StringName:
	if clue_at(tile) != "":
		return &"interact"
	return _wenyao_use(tile)


func _walkable(t: Vector2i) -> bool:
	return super._walkable(t) and not Farming.has_fence(t)
