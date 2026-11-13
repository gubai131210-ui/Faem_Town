extends OutdoorMap
## 农场地图：程序生成的地形和物件，耕地由 FarmView 显示。

const W := 52
const H := 38
const HOUSE_POS := Vector2(128, 112)
const DOOR_TILES: Array[Vector2i] = [Vector2i(7, 6), Vector2i(8, 6)]
const MAILBOX_TILE := Vector2i(11, 7)
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

var _farm_view: FarmView
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


func _ready() -> void:
	map_id = &"farm"
	_rng.seed = 20261111
	_setup_grid(W, H)
	_layout()
	_build_ground()

	_farm_view = FarmView.new()
	_farm_view.z_index = -9
	add_child(_farm_view)
	_make_entities()
	_farm_view.water_at = _is_water
	_farm_view.setup(Farming.state, entities)
	_place_objects()
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
	_make_water_fx(80)
	for off: Vector2 in [Vector2(-32, -26), Vector2(32, -26)]:
		_add_night_light(HOUSE_POS + off, 1.3)
	_spawn_npcs()


func _exit_tree() -> void:
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


func _process(delta: float) -> void:
	super._process(delta)
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


## 第二天起，头一回走到院子里：门口蹲着一条狗和一只猫，留一个。
func entered() -> void:
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
	return super._tile_blocked(t) or Farming.state.blocks_walking(t) or Farming.orchard.has(t) or Farming.has_scarecrow(t)


func query_use(item: ItemDef, tile: Vector2i, facing: Facing) -> StringName:
	if facing == Facing.UP and DOOR_TILES.has(tile):
		return &"interact"
	if tile == MAILBOX_TILE or tile == BIN_TILE:
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
		return &""
	if item.id == &"hoe":
		return &"hoe"
	if item.id == &"watering_can":
		return &"water"
	if item.id == &"shovel":
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
	return &""


func perform(action: StringName, item: ItemDef, tile: Vector2i, quiet: bool = false) -> void:
	var farm := Farming.state
	var c := tile_center(tile)
	match action:
		&"place_trap":
			_trap_perform(action, tile, item)
		&"place":
			if item != null and item.id == Farming.SCARECROW_ID and _can_plant_tree(tile) and Farming.place_scarecrow(tile):
				GameState.inventory.remove(item.id, 1)
				Audio.play("plant")
				Fx.burst(self, c, Color("d8b45a"), 8, 40.0)
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
			else:
				SceneRouter.travel(&"farmhouse", &"door")
		&"hoe":
			if not quiet:
				Audio.play("hoe")
			if _can_till(tile) and farm.till(tile):
				_clear_decor(tile)
				Fx.burst(self, c, Color("9a6a40"), 10, 70.0)
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
			Fx.pop_icon(self, c + Vector2(0, -6), icon_tex)
			if count > 1:
				Fx.pop_icon(self, c + Vector2(7, -9), icon_tex)


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
		Fx.pop_icon(self, c + Vector2(-7 + i * 7, -14 - i * 3), icon_tex)
	return true


## 铁锹：果树挖掉；有作物就铲掉；水渠填平；水渠边的空耕地放水成水田（再铲一次放掉）；荒地挖成水渠。
func _dig(tile: Vector2i) -> void:
	var farm := Farming.state
	var c := tile_center(tile)
	Audio.play("hoe", 0.0, -2.0)
	if Farming.orchard.remove(tile):
		Fx.burst(self, c, Color("7d5230"), 10, 60.0)
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
	else:
		EventBus.banner_requested.emit("信箱是空的。买种子去镇上的杂货铺，沿门口的路往西走")
		Audio.play("select", 0.0, -8.0)


## 出货箱：把手里拿着的那一整格放进去，第二天早上结算。
func _use_bin(item: ItemDef) -> void:
	if item == null or not item.sellable():
		var pending := Shipping.pending_value()
		if pending > 0:
			EventBus.banner_requested.emit("出货箱里的东西值 %d 文，明早结算" % pending)
		else:
			EventBus.banner_requested.emit("出货箱：拿着要卖的东西再来")
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


# ---------------------------------------------------------------- 建筑和动物

func _no_scatter(t: Vector2i) -> bool:
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
	# 房子前面那一排留作通道，不让开垦。小溪东岸要柏先生的许可（忆五级）
	if t.x >= _stream_x(t.y) + 2 and Residents.memory_level(&"bai") < 5:
		return false
	return terrain[idx(t)] != WATER and solid[idx(t)] == 0 and t.y > 6


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
	# 东边一条弯弯曲曲的小溪，从北流到南
	for y in H:
		for x in range(_stream_x(y), _stream_x(y) + 2):
			terrain[y * W + x] = WATER
			solid[y * W + x] = 1


## 池塘按池塘算，东边的小溪按溪水算（和南溪一样的鱼）。
func fishing_water(tile: Vector2i) -> StringName:
	if not _is_water(tile):
		return &""
	return &"stream" if tile.x >= _stream_x(tile.y) - 1 else &"pond"


## 小溪在这一行最靠西的那一格
func _stream_x(y: int) -> int:
	return 46 + int(roundf(sin(y * 0.33) * 1.6))


## 采集物可以落在哪些格子：能走到的空草地。shore 为真时只要紧挨着水的。
func _forage_tiles(shore: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var farm := Farming.state
	for y in range(7, H - 2):
		for x in range(2, _stream_x(y)):
			var t := Vector2i(x, y)
			if not _is_free(t) or farm.is_tilled(t) or farm.is_canal(t) or Farming.orchard.has(t):
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


func _place_objects() -> void:
	# 房子
	var house := _prop("house", HOUSE_POS)
	house.name = "House"
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
	_reserve(0, TOWN_EXIT_ROWS[0] - 1, 1, TOWN_EXIT_ROWS[1] + 3)
	_scatter_trees(30)
	_scatter_bushes(40)
	_scatter_tufts(500)


func _keep_clear(t: Vector2i, margin: int) -> bool:
	return super._keep_clear(t, margin) or absi(t.x - START_TILE.x) + absi(t.y - START_TILE.y) < 4
