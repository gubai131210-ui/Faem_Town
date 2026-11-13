extends Node
## 全局数据库：启动时读入 data/ 下的内容表，转成带类型的定义对象，并校验表之间的引用。

const ITEMS_PATH := "res://data/items.json"
const CROPS_PATH := "res://data/crops.json"
const TREES_PATH := "res://data/trees.json"
const FORAGE_PATH := "res://data/forage.json"
const TERMS_PATH := "res://data/solar_terms.json"
const NPCS_PATH := "res://data/npcs.json"
const RELICS_PATH := "res://data/relics.json"
const MEMORIES_PATH := "res://data/memories.json"
const QUESTS_PATH := "res://data/quests.json"
const LAMPS_PATH := "res://data/lamps.json"
const FESTIVALS_PATH := "res://data/festivals.json"
const FISH_PATH := "res://data/fish.json"
const BUILDINGS_PATH := "res://data/buildings.json"
const ANIMALS_PATH := "res://data/animals.json"
const MACHINES_PATH := "res://data/machines.json"
const RECIPES_PATH := "res://data/recipes.json"
const MINE_PATH := "res://data/mine.json"
const WEAPONS_PATH := "res://data/weapons.json"
const MONSTERS_PATH := "res://data/monsters.json"
const ACCESSORIES_PATH := "res://data/accessories.json"
const CREATURE_DIR := "res://art/creatures/"
const SHEET_DIR := "res://art/characters/"
const TERMS_PER_SEASON := 6
const SEASON_IDS: Array[StringName] = [&"spring", &"summer", &"autumn", &"winter"]

var items: Dictionary[StringName, ItemDef] = {}
var crops: Dictionary[StringName, CropDef] = {}
var trees: Dictionary[StringName, TreeDef] = {}
var forage: Array[ForageDef] = []
## 居民，按表里的顺序
var npcs: Dictionary[StringName, NpcDef] = {}
## 二十四节气，按一年里的顺序
var terms: Array[TermDef] = []
## 遗物（同时也登记进 items）
var relics: Dictionary[StringName, RelicDef] = {}
## 每位居民的各级忆，按表里的顺序
var memories: Array[MemoryDef] = []
## 公告栏的委托，按表里的顺序
var quests: Dictionary[StringName, QuestDef] = {}
## 主线石灯
var lamps: Dictionary[StringName, LampDef] = {}
## 节日，按一年里的先后
var festivals: Dictionary[StringName, FestivalDef] = {}
## 鱼（同时也登记进 items），按表里的顺序
var fish: Dictionary[StringName, FishDef] = {}
var buildings: Dictionary[StringName, BuildingDef] = {}
var animals: Dictionary[StringName, AnimalDef] = {}
## 加工设备和菜谱，按表里的顺序
var machines: Dictionary[StringName, MachineDef] = {}
var recipes: Dictionary[StringName, RecipeDef] = {}
## 沉灯井的各段楼层，从浅到深
var mine_layers: Array[MineLayerDef] = []
## 武器（同时也登记进 items）和井里的忘形
var weapons: Dictionary[StringName, WeaponDef] = {}
var monsters: Dictionary[StringName, MonsterDef] = {}
## 饰品（同时也登记进 items）
var accessories: Dictionary[StringName, AccessoryDef] = {}


func _ready() -> void:
	reload()
	for msg in validate():
		push_error("数据表错误：" + msg)


func reload() -> void:
	items.clear()
	crops.clear()
	trees.clear()
	forage.clear()
	terms.clear()
	npcs.clear()
	relics.clear()
	memories.clear()
	quests.clear()
	lamps.clear()
	festivals.clear()
	fish.clear()
	buildings.clear()
	animals.clear()
	machines.clear()
	recipes.clear()
	mine_layers.clear()
	weapons.clear()
	accessories.clear()
	monsters.clear()
	for entry: Variant in JsonFile.read_array(MINE_PATH):
		if entry is Dictionary:
			mine_layers.append(MineLayerDef.from_dict(entry))
	for entry: Variant in JsonFile.read_array(MONSTERS_PATH):
		if entry is Dictionary:
			var def := MonsterDef.from_dict(entry)
			monsters[def.id] = def
	for entry: Variant in JsonFile.read_array(MACHINES_PATH):
		if entry is Dictionary:
			var def := MachineDef.from_dict(entry)
			machines[def.id] = def
	for entry: Variant in JsonFile.read_array(RECIPES_PATH):
		if entry is Dictionary:
			var def := RecipeDef.from_dict(entry)
			recipes[def.id] = def
	for entry: Variant in JsonFile.read_array(BUILDINGS_PATH):
		if entry is Dictionary:
			var def := BuildingDef.from_dict(entry)
			buildings[def.id] = def
	for entry: Variant in JsonFile.read_array(ANIMALS_PATH):
		if entry is Dictionary:
			var def := AnimalDef.from_dict(entry)
			animals[def.id] = def
	for entry: Variant in JsonFile.read_array(NPCS_PATH):
		if entry is Dictionary:
			var def := NpcDef.from_dict(entry)
			npcs[def.id] = def
	for entry: Variant in JsonFile.read_array(TERMS_PATH):
		if entry is Dictionary:
			terms.append(TermDef.from_dict(entry))
	for entry: Variant in JsonFile.read_array(ITEMS_PATH):
		if entry is Dictionary:
			var def := ItemDef.from_dict(entry)
			items[def.id] = def
	for entry: Variant in JsonFile.read_array(RELICS_PATH):
		if entry is Dictionary:
			var def := RelicDef.from_dict(entry)
			relics[def.id] = def
			items[def.id] = def.as_item()
	for entry: Variant in JsonFile.read_array(WEAPONS_PATH):
		if entry is Dictionary:
			var def := WeaponDef.from_dict(entry)
			weapons[def.id] = def
			items[def.id] = def.as_item()
	for entry: Variant in JsonFile.read_array(ACCESSORIES_PATH):
		if entry is Dictionary:
			var def := AccessoryDef.from_dict(entry)
			accessories[def.id] = def
			items[def.id] = def.as_item()
	for entry: Variant in JsonFile.read_array(MEMORIES_PATH):
		if entry is Dictionary:
			memories.append(MemoryDef.from_dict(entry))
	for entry: Variant in JsonFile.read_array(FISH_PATH):
		if entry is Dictionary:
			var def := FishDef.from_dict(entry)
			fish[def.id] = def
			items[def.id] = def.as_item()
	for entry: Variant in JsonFile.read_array(QUESTS_PATH):
		if entry is Dictionary:
			var def := QuestDef.from_dict(entry)
			quests[def.id] = def
	for entry: Variant in JsonFile.read_array(LAMPS_PATH):
		if entry is Dictionary:
			var def := LampDef.from_dict(entry)
			lamps[def.id] = def
	for entry: Variant in JsonFile.read_array(FESTIVALS_PATH):
		if entry is Dictionary:
			var def := FestivalDef.from_dict(entry)
			festivals[def.id] = def
	for entry: Variant in JsonFile.read_array(CROPS_PATH):
		if entry is Dictionary:
			var def := CropDef.from_dict(entry)
			for i in terms.size():
				if def.ripe_term != &"" and terms[i].id == def.ripe_term:
					def.ripe_term_index = i
			crops[def.id] = def
	for entry: Variant in JsonFile.read_array(TREES_PATH):
		if entry is Dictionary:
			var def := TreeDef.from_dict(entry)
			trees[def.id] = def
	for entry: Variant in JsonFile.read_array(FORAGE_PATH):
		if entry is Dictionary:
			var def := ForageDef.from_dict(entry)
			for i in terms.size():
				if def.from_term != &"" and terms[i].id == def.from_term:
					def.from_term_index = i
			forage.append(def)


func item(id: StringName) -> ItemDef:
	var def: ItemDef = items.get(id)
	if def == null:
		push_error("没有这个物品：%s" % id)
	return def


func has_item(id: StringName) -> bool:
	return items.has(id)


func crop(id: StringName) -> CropDef:
	var def: CropDef = crops.get(id)
	if def == null:
		push_error("没有这个作物：%s" % id)
	return def


func has_crop(id: StringName) -> bool:
	return crops.has(id)


func tree(id: StringName) -> TreeDef:
	var def: TreeDef = trees.get(id)
	if def == null:
		push_error("没有这种果树：%s" % id)
	return def


func has_tree(id: StringName) -> bool:
	return trees.has(id)


func npc(id: StringName) -> NpcDef:
	var def: NpcDef = npcs.get(id)
	if def == null:
		push_error("没有这位居民：%s" % id)
	return def


func has_npc(id: StringName) -> bool:
	return npcs.has(id)


## 按显示的名字找居民（对话框用它找头像）；没有这个人返回 null。
func npc_by_name(npc_name: String) -> NpcDef:
	for id: StringName in npcs:
		if npcs[id].name == npc_name:
			return npcs[id]
	return null


func relic(id: StringName) -> RelicDef:
	var def: RelicDef = relics.get(id)
	if def == null:
		push_error("没有这件遗物：%s" % id)
	return def


func has_relic(id: StringName) -> bool:
	return relics.has(id)


## 这位居民第 level 级的忆；没有返回 null。
func memory(npc_id: StringName, level: int) -> MemoryDef:
	for m in memories:
		if m.npc == npc_id and m.level == level:
			return m
	return null


## 归还这件遗物对应哪段忆；不对应任何忆返回 null。
func memory_for_relic(relic_id: StringName) -> MemoryDef:
	for m in memories:
		if m.relic == relic_id:
			return m
	return null


func quest(id: StringName) -> QuestDef:
	var def: QuestDef = quests.get(id)
	if def == null:
		push_error("没有这张委托：%s" % id)
	return def


func festival(id: StringName) -> FestivalDef:
	return festivals.get(id)


## 节气 id 是一年里的第几个（0 是立春）；没有这个节气返回 -1。
func term_index_of_id(id: StringName) -> int:
	for i in terms.size():
		if terms[i].id == id:
			return i
	return -1


## 第 day 天是不是节日；不是返回 null。
func festival_on(day: int) -> FestivalDef:
	var days_per_term := GameClock.DAYS_PER_TERM
	var in_year := posmod(day - 1, days_per_term * terms.size()) if not terms.is_empty() else -1
	for id: StringName in festivals:
		var def: FestivalDef = festivals[id]
		var term_index := term_index_of_id(def.term)
		if term_index >= 0 and in_year == term_index * days_per_term + def.day - 1:
			return def
	return null


func lamp(id: StringName) -> LampDef:
	var def: LampDef = lamps.get(id)
	if def == null:
		push_error("没有这盏灯：%s" % id)
	return def


func fish_def(id: StringName) -> FishDef:
	var def: FishDef = fish.get(id)
	if def == null:
		push_error("没有这种鱼：%s" % id)
	return def


func has_fish(id: StringName) -> bool:
	return fish.has(id)


func building(id: StringName) -> BuildingDef:
	var def: BuildingDef = buildings.get(id)
	if def == null:
		push_error("没有这栋建筑：%s" % id)
	return def


func has_building(id: StringName) -> bool:
	return buildings.has(id)


func animal(id: StringName) -> AnimalDef:
	var def: AnimalDef = animals.get(id)
	if def == null:
		push_error("没有这种动物：%s" % id)
	return def


func has_animal(id: StringName) -> bool:
	return animals.has(id)


## 第 n 层属于井里的哪一段；没有这一层返回空。
func mine_layer(n: int) -> MineLayerDef:
	for layer in mine_layers:
		if layer.has_floor(n):
			return layer
	return null


## 这种矿石在石头上的矿点是什么颜色；不是矿石返回灰色。
func ore_color(item_id: StringName) -> Color:
	for layer in mine_layers:
		for ore in layer.ores:
			if ore["item"] == item_id:
				return Color.html(str(ore["color"]))
	return Color.html("808080")


## 这件东西要是武器，返回它的招式和伤害；不是返回 null。
func weapon(id: StringName) -> WeaponDef:
	return weapons.get(id)


## 这件东西要是饰品，返回它的效果；不是返回 null。
func accessory(id: StringName) -> AccessoryDef:
	return accessories.get(id)


func monster(id: StringName) -> MonsterDef:
	var def: MonsterDef = monsters.get(id)
	if def == null:
		push_error("没有这种忘形：%s" % id)
	return def


func machine(id: StringName) -> MachineDef:
	var def: MachineDef = machines.get(id)
	if def == null:
		push_error("没有这台设备：%s" % id)
	return def


## 一年里第 index 个节气（0 是立春）。
func term(index: int) -> TermDef:
	if terms.is_empty():
		return null
	return terms[posmod(index, terms.size())]


## 检查所有表，返回错误信息列表；空列表表示没有问题。
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if items.is_empty():
		errors.append("物品表是空的")
	for id: StringName in items:
		var it: ItemDef = items[id]
		if String(id).is_empty() or String(id) != String(id).to_snake_case():
			errors.append("物品 id 必须是小写下划线：'%s'" % id)
		if it.name.is_empty():
			errors.append("物品 %s 没有名称" % id)
		if not ItemDef.KINDS.has(it.kind):
			errors.append("物品 %s 的种类无效：%s" % [id, it.kind])
		if it.stack < 1:
			errors.append("物品 %s 的堆叠上限必须大于 0" % id)
		if it.kind == &"fertilizer" and it.power < 1:
			errors.append("肥料 %s 的肥力必须大于 0" % id)
		if it.kind == &"sapling" and not trees.has(it.tree):
			errors.append("树苗 %s 指向不存在的果树：%s" % [id, it.tree])
		if it.flower != &"" and not SEASON_IDS.has(it.flower):
			errors.append("花 %s 的季节无效：%s" % [id, it.flower])
		if it.kind == &"seed" and not crops.has(it.crop):
			errors.append("种子 %s 指向不存在的作物：%s" % [id, it.crop])
	for id: StringName in crops:
		var cr: CropDef = crops[id]
		if not items.has(cr.seed):
			errors.append("作物 %s 的种子不存在：%s" % [id, cr.seed])
		elif items[cr.seed].crop != id:
			errors.append("作物 %s 的种子 %s 没有指回这个作物" % [id, cr.seed])
		if not items.has(cr.produce):
			errors.append("作物 %s 的产物不存在：%s" % [id, cr.produce])
		if cr.stage_days.is_empty():
			errors.append("作物 %s 没有生长阶段" % id)
		for n in cr.stage_days:
			if n < 1:
				errors.append("作物 %s 的阶段天数必须大于 0" % id)
		if cr.seasons.is_empty():
			errors.append("作物 %s 没有可种植的季节" % id)
		for s in cr.seasons:
			if not SEASON_IDS.has(s):
				errors.append("作物 %s 的季节无效：%s" % [id, s])
		for s in cr.sow_seasons:
			if not cr.seasons.has(s):
				errors.append("作物 %s 的播种季节 %s 不在它能活的季节里" % [id, s])
		if cr.ripe_term != &"" and cr.ripe_term_index < 0:
			errors.append("作物 %s 的成熟节气不存在：%s" % [id, cr.ripe_term])
		if cr.bonus_produce != &"" and not items.has(cr.bonus_produce):
			errors.append("作物 %s 的附带产物不存在：%s" % [id, cr.bonus_produce])
		for key: Variant in cr.term_bonus:
			var found := false
			for term_def in terms:
				if String(term_def.id) == str(key):
					found = true
			if not found:
				errors.append("作物 %s 的节气加分指向不存在的节气：%s" % [id, key])
		if cr.giant_chance < 0.0 or cr.giant_chance > 1.0:
			errors.append("作物 %s 的巨型概率必须在 0 到 1 之间" % id)
		if cr.regrow_days < 0 or cr.regrow_days > cr.total_days():
			errors.append("作物 %s 的再收天数无效" % id)
		if cr.extra_chance < 0.0 or cr.extra_chance > 1.0:
			errors.append("作物 %s 的多收概率必须在 0 到 1 之间" % id)
	for id: StringName in trees:
		var tr: TreeDef = trees[id]
		if not items.has(tr.sapling) or items[tr.sapling].tree != id:
			errors.append("果树 %s 的树苗不存在或没有指回这棵树：%s" % [id, tr.sapling])
		if tr.grow_days < 1:
			errors.append("果树 %s 的生长天数必须大于 0" % id)
		if tr.yields.is_empty():
			errors.append("果树 %s 什么都不结" % id)
		for y in tr.yields:
			if not SEASON_IDS.has(StringName(str(y.get("season", "")))):
				errors.append("果树 %s 的结果季节无效" % id)
			if not items.has(StringName(str(y.get("item", "")))):
				errors.append("果树 %s 结的东西不存在：%s" % [id, y.get("item", "")])
	for f in forage:
		if not items.has(f.item):
			errors.append("采集物不存在：%s" % f.item)
		if not SEASON_IDS.has(f.season) and not (f.beach and f.season == &""):
			errors.append("采集物 %s 的季节无效：%s" % [f.item, f.season])
		if f.beach and f.shore:
			errors.append("采集物 %s 不能既在沙滩又在水边" % f.item)
		if f.weight < 1:
			errors.append("采集物 %s 的权重必须大于 0" % f.item)
		if f.from_term != &"" and f.from_term_index < 0:
			errors.append("采集物 %s 的起始节气不存在：%s" % [f.item, f.from_term])
	for id: StringName in npcs:
		errors.append_array(validate_npc(npcs[id]))
	errors.append_array(_validate_story())
	errors.append_array(_validate_ranch())
	errors.append_array(_validate_crafting())
	errors.append_array(_validate_mine())
	if terms.size() != TERMS_PER_SEASON * SEASON_IDS.size():
		errors.append("节气表应该有 %d 条，现在是 %d 条" % [TERMS_PER_SEASON * SEASON_IDS.size(), terms.size()])
	for i in terms.size():
		var term_def := terms[i]
		if term_def.name.is_empty():
			errors.append("第 %d 个节气没有名称" % (i + 1))
		if term_def.season != SEASON_IDS[mini(i / TERMS_PER_SEASON, SEASON_IDS.size() - 1)]:
			errors.append("节气 %s 的季节和它在表里的位置对不上" % term_def.id)
	return errors


## 检查矿井的层段、忘形和武器。
func _validate_mine() -> PackedStringArray:
	var errors := PackedStringArray()
	if mine_layers.is_empty():
		errors.append("矿井表是空的")
	var next := 1
	for layer in mine_layers:
		if String(layer.id).is_empty() or String(layer.id) != String(layer.id).to_snake_case():
			errors.append("矿井层段 id 必须是小写下划线：'%s'" % layer.id)
		if layer.from != next or layer.to < layer.from:
			errors.append("矿井层段 %s 的层数接不上：%d–%d" % [layer.id, layer.from, layer.to])
		next = layer.to + 1
		if layer.rock <= 0.0 or layer.rock >= 0.9:
			errors.append("矿井层段 %s 的石头比例不对：%s" % [layer.id, layer.rock])
		if not items.has(layer.stone):
			errors.append("矿井层段 %s 的石头不是物品：%s" % [layer.id, layer.stone])
		for ore in layer.ores:
			var item: StringName = ore["item"]
			if not items.has(item) or items[item].kind != &"ore":
				errors.append("矿井层段 %s 的矿石不是矿石类物品：%s" % [layer.id, item])
			if int(ore["weight"]) <= 0:
				errors.append("矿井层段 %s 的矿石 %s 份数必须大于 0" % [layer.id, item])
			if not str(ore["color"]).is_valid_html_color():
				errors.append("矿井层段 %s 的矿石 %s 颜色无效" % [layer.id, item])
		if layer.monster_min < 0 or layer.monster_max < layer.monster_min:
			errors.append("矿井层段 %s 的忘形数量不对：%d–%d" % [layer.id, layer.monster_min, layer.monster_max])
		for m in layer.monsters:
			if not monsters.has(m["id"]):
				errors.append("矿井层段 %s 的忘形不存在：%s" % [layer.id, m["id"]])
			if int(m["weight"]) <= 0:
				errors.append("矿井层段 %s 的忘形 %s 份数必须大于 0" % [layer.id, m["id"]])
			if not layer.has_floor(int(m["from"])):
				errors.append("矿井层段 %s 的忘形 %s 从第 %d 层出现，不在这一段里" % [layer.id, m["id"], int(m["from"])])
			if monsters.has(m["id"]) and monsters[m["id"]].boss != &"":
				errors.append("矿井层段 %s 把首领 %s 当成了普通忘形" % [layer.id, m["id"]])
		if layer.water < 0.0 or layer.water > 0.5 or layer.pool < 0.0 or layer.pool > 1.0 or layer.props < 0.0 or layer.props > 0.2:
			errors.append("矿井层段 %s 的水和摆设比例不对" % layer.id)
		if layer.boss != &"" and (not monsters.has(layer.boss) or monsters[layer.boss].boss == &""):
			errors.append("矿井层段 %s 的首领不存在或者不是首领：%s" % [layer.id, layer.boss])
	for id: StringName in monsters:
		var mon: MonsterDef = monsters[id]
		if String(id).is_empty() or String(id) != String(id).to_snake_case():
			errors.append("忘形 id 必须是小写下划线：'%s'" % id)
		if mon.name.is_empty():
			errors.append("忘形 %s 没有名称" % id)
		if mon.hp < 1 or mon.damage < 1:
			errors.append("忘形 %s 的生命和伤害必须大于 0" % id)
		if mon.speed <= 0.0 or mon.strike_speed <= 0.0 or mon.strike_time <= 0.0:
			errors.append("忘形 %s 的速度和出招时间必须大于 0" % id)
		if mon.windup < 0.3:
			errors.append("忘形 %s 的前摇太短，看不清：%s 秒" % [id, mon.windup])
		if mon.reach <= 0.0 or mon.sight < mon.reach:
			errors.append("忘形 %s 看得没有打得远" % id)
		if mon.hidden and mon.wake <= mon.reach:
			errors.append("忘形 %s 醒得比出招的距离还近" % id)
		for drop in mon.drops:
			if not items.has(drop["item"]):
				errors.append("忘形 %s 掉的东西不存在：%s" % [id, drop["item"]])
			if float(drop["chance"]) <= 0.0 or float(drop["chance"]) > 1.0:
				errors.append("忘形 %s 掉 %s 的概率必须在 0 到 1 之间" % [id, drop["item"]])
		if mon.relic != &"" and (not relics.has(mon.relic) or relics[mon.relic].found != &"mine"):
			errors.append("忘形 %s 掉的遗物不存在或者来源不是井里：%s" % [id, mon.relic])
		if mon.relic != &"" and (mon.relic_chance <= 0.0 or mon.relic_chance > 1.0):
			errors.append("忘形 %s 掉遗物的概率必须在 0 到 1 之间" % id)
		if mon.leap and mon.blast <= 0.0:
			errors.append("忘形 %s 会跳却没写落地砸多大一片" % id)
		if mon.boss != &"" and (not MineMonster.BOSS_KINDS.has(mon.boss) or mon.stun <= 0.0 or mon.flag == &""):
			errors.append("首领 %s 的打法、晕多久、标记没写全" % id)
		if mon.boss == &"cart" and mon.charge_len <= 0.0:
			errors.append("首领 %s 没写一次冲多远" % id)
	for id: StringName in accessories:
		var acc: AccessoryDef = accessories[id]
		if String(id).is_empty() or String(id) != String(id).to_snake_case():
			errors.append("饰品 id 必须是小写下划线：'%s'" % id)
		if acc.name.is_empty() or acc.desc.is_empty():
			errors.append("饰品 %s 没有名称或说明" % id)
		if not AccessoryDef.EFFECTS.has(acc.effect) or acc.value <= 0.0:
			errors.append("饰品 %s 的效果无效：%s %s" % [id, acc.effect, acc.value])
		if (acc.price > 0) != (not acc.materials.is_empty()):
			errors.append("饰品 %s：石叔打的要同时写价钱和材料，首领掉的两样都不写" % id)
		for m in acc.materials:
			if not items.has(m["item"]) or int(m["count"]) <= 0:
				errors.append("饰品 %s 的材料不对：%s" % [id, m["item"]])
	for id: StringName in weapons:
		var w: WeaponDef = weapons[id]
		if String(id).is_empty() or String(id) != String(id).to_snake_case():
			errors.append("武器 id 必须是小写下划线：'%s'" % id)
		if not WeaponDef.KINDS.has(w.kind):
			errors.append("武器 %s 的种类无效：%s" % [id, w.kind])
		if w.damage < 1:
			errors.append("武器 %s 的伤害必须大于 0" % id)
	return errors


func _validate_crafting() -> PackedStringArray:
	var errors := PackedStringArray()
	for id: StringName in machines:
		var m: MachineDef = machines[id]
		if String(id) != String(id).to_snake_case() or String(id).is_empty():
			errors.append("设备 id 必须是小写下划线：'%s'" % id)
		if m.name.is_empty() or m.price <= 0:
			errors.append("设备 %s 缺名称或价钱" % id)
		if not FileAccess.file_exists("res://art/props/%s.png" % m.prop):
			errors.append("设备 %s 的物件不存在：%s（先运行 tools/props.py）" % [id, m.prop])
		if m.recipes.is_empty():
			errors.append("设备 %s 什么都做不了" % id)
		for r in m.recipes:
			var inputs: Array[StringName] = r["inputs"]
			if inputs.is_empty():
				errors.append("设备 %s 有一项没写原料" % id)
			for item_id in inputs:
				if not items.has(item_id):
					errors.append("设备 %s 的原料不存在：%s" % [id, item_id])
			if not items.has(r["output"]):
				errors.append("设备 %s 的成品不存在：%s" % [id, r["output"]])
			if int(r["count"]) < 1 or int(r["days"]) < 1:
				errors.append("设备 %s 的原料数量和天数必须大于 0" % id)
	for id: StringName in recipes:
		var rec: RecipeDef = recipes[id]
		if not items.has(id) or items[id].kind != &"food":
			errors.append("菜谱 %s 做出来的不是食物" % id)
		if not RecipeDef.SOURCES.has(rec.from):
			errors.append("菜谱 %s 的来源无效：%s" % [id, rec.from])
		if rec.ingredients.is_empty():
			errors.append("菜谱 %s 没有材料" % id)
		for item_id: StringName in rec.ingredients:
			if not items.has(item_id):
				errors.append("菜谱 %s 的材料不存在：%s" % [id, item_id])
			if rec.ingredients[item_id] < 1:
				errors.append("菜谱 %s 的材料数量必须大于 0" % id)
	for id: StringName in items:
		var it: ItemDef = items[id]
		if it.kind != &"food":
			continue
		if it.energy <= 0:
			errors.append("食物 %s 不回体力" % id)
		if it.buff != &"" and (not GameState.BUFF_NAMES.has(it.buff) or it.buff_minutes <= 0):
			errors.append("食物 %s 的增益无效" % id)
		if not recipes.has(id):
			errors.append("食物 %s 没有菜谱" % id)
	return errors


## 检查建筑和动物。
func _validate_ranch() -> PackedStringArray:
	var errors := PackedStringArray()
	for id: StringName in buildings:
		var b: BuildingDef = buildings[id]
		if String(id) != String(id).to_snake_case() or String(id).is_empty():
			errors.append("建筑 id 必须是小写下划线：'%s'" % id)
		if b.name.is_empty():
			errors.append("建筑 %s 没有名称" % id)
		if b.price <= 0 or b.days < 1:
			errors.append("建筑 %s 的价钱和工期必须大于 0" % id)
		if b.width < 1 or b.depth < 1:
			errors.append("建筑 %s 的占地无效" % id)
		if b.door < 0 or b.door >= b.width:
			errors.append("建筑 %s 的门不在正面墙上" % id)
		if b.capacity > 0 and b.yard.size.x * b.yard.size.y <= 0:
			errors.append("建筑 %s 住动物却没有院子" % id)
		if b.requires != &"" and not buildings.has(b.requires):
			errors.append("建筑 %s 的前置建筑不存在：%s" % [id, b.requires])
		if not FileAccess.file_exists("res://art/props/%s.png" % b.prop):
			errors.append("建筑 %s 的物件不存在：%s（先运行 tools/props.py）" % [id, b.prop])
	for id: StringName in animals:
		var a: AnimalDef = animals[id]
		if String(id) != String(id).to_snake_case() or String(id).is_empty():
			errors.append("动物 id 必须是小写下划线：'%s'" % id)
		if a.name.is_empty():
			errors.append("动物 %s 没有名称" % id)
		if not buildings.has(a.building):
			errors.append("动物 %s 住的建筑不存在：%s" % [id, a.building])
		elif buildings[a.building].capacity < 1:
			errors.append("动物 %s 住的建筑 %s 不能住动物" % [id, a.building])
		if not items.has(a.produce):
			errors.append("动物 %s 的产物不存在：%s" % [id, a.produce])
		if a.extra != &"" and not items.has(a.extra):
			errors.append("动物 %s 的附带产物不存在：%s" % [id, a.extra])
		if a.extra_chance < 0.0 or a.extra_chance > 1.0:
			errors.append("动物 %s 的附带产物概率必须在 0 到 1 之间" % id)
		if a.price <= 0:
			errors.append("动物 %s 没有价钱" % id)
		if a.names.is_empty():
			errors.append("动物 %s 没有候选名字" % id)
		if a.feed != &"" and not items.has(a.feed):
			errors.append("动物 %s 吃的东西不存在：%s" % [id, a.feed])
		for flower: StringName in a.honeys:
			if not crops.has(flower):
				errors.append("动物 %s 的蜜对应的花不存在：%s" % [id, flower])
			if not items.has(a.honeys[flower]):
				errors.append("动物 %s 的蜜不存在：%s" % [id, a.honeys[flower]])
		if a.outdoor and not FileAccess.file_exists(CREATURE_DIR + a.sheet + ".json"):
			errors.append("动物 %s 的序列帧不存在：%s（先运行 tools/animal.py）" % [id, a.sheet])
	return errors


## 检查遗物、忆、委托、灯之间的引用。
func _validate_story() -> PackedStringArray:
	var errors := PackedStringArray()
	for id: StringName in relics:
		var r: RelicDef = relics[id]
		if String(id) != String(id).to_snake_case() or String(id).is_empty():
			errors.append("遗物 id 必须是小写下划线：'%s'" % id)
		if r.name.is_empty():
			errors.append("遗物 %s 没有名称" % id)
		if not RelicDef.SOURCES.has(r.found):
			errors.append("遗物 %s 的来源无效：%s" % [id, r.found])
		if r.npc != &"":
			if not npcs.has(r.npc):
				errors.append("遗物 %s 属于不存在的居民：%s" % [id, r.npc])
			if r.level < 1 or r.level > 5:
				errors.append("遗物 %s 的忆等级必须在 1 到 5 之间" % id)
			if memory_for_relic(id) == null:
				errors.append("遗物 %s 属于居民 %s，但忆表里没有对应的记忆" % [id, r.npc])
	var seen: Dictionary[String, bool] = {}
	for m in memories:
		var key := "%s:%d" % [m.npc, m.level]
		if seen.has(key):
			errors.append("居民 %s 的第 %d 级忆写了两次" % [m.npc, m.level])
		seen[key] = true
		if not npcs.has(m.npc):
			errors.append("忆指向不存在的居民：%s" % m.npc)
		if m.level < 1 or m.level > 5:
			errors.append("居民 %s 的忆等级无效：%d" % [m.npc, m.level])
		if m.level > 1 and memory(m.npc, m.level - 1) == null:
			errors.append("居民 %s 有第 %d 级忆却没有第 %d 级" % [m.npc, m.level, m.level - 1])
		if not relics.has(m.relic):
			errors.append("居民 %s 第 %d 级忆的遗物不存在：%s" % [m.npc, m.level, m.relic])
		elif relics[m.relic].npc != m.npc or relics[m.relic].level != m.level:
			errors.append("遗物 %s 和居民 %s 第 %d 级忆没有互相指向" % [m.relic, m.npc, m.level])
		if m.title.is_empty() or m.text.is_empty():
			errors.append("居民 %s 第 %d 级忆缺标题或正文" % [m.npc, m.level])
	for id: StringName in quests:
		var q: QuestDef = quests[id]
		if String(id) != String(id).to_snake_case() or String(id).is_empty():
			errors.append("委托 id 必须是小写下划线：'%s'" % id)
		if not npcs.has(q.npc):
			errors.append("委托 %s 来自不存在的居民：%s" % [id, q.npc])
		if not items.has(q.item):
			errors.append("委托 %s 要的东西不存在：%s" % [id, q.item])
		if q.count < 1:
			errors.append("委托 %s 要的数量必须大于 0" % id)
		if q.relic != &"" and not relics.has(q.relic):
			errors.append("委托 %s 给的遗物不存在：%s" % [id, q.relic])
		if q.title.is_empty():
			errors.append("委托 %s 没有标题" % id)
	for id: StringName in lamps:
		var l: LampDef = lamps[id]
		if not SceneRouter.MAPS.has(l.map):
			errors.append("灯 %s 在不存在的地图上：%s" % [id, l.map])
		if l.offerings.is_empty():
			errors.append("灯 %s 没有供品" % id)
		for item_id: StringName in l.offerings:
			if not items.has(item_id):
				errors.append("灯 %s 的供品不存在：%s" % [id, item_id])
			if l.offerings[item_id] < 1:
				errors.append("灯 %s 的供品数量必须大于 0" % id)
		if l.relic != &"" and not relics.has(l.relic):
			errors.append("灯 %s 的关键遗物不存在：%s" % [id, l.relic])
	errors.append_array(_validate_festivals())
	for id: StringName in fish:
		var f: FishDef = fish[id]
		if String(id) != String(id).to_snake_case() or String(id).is_empty():
			errors.append("鱼 id 必须是小写下划线：'%s'" % id)
		if f.name.is_empty():
			errors.append("鱼 %s 没有名称" % id)
		if f.waters.is_empty():
			errors.append("鱼 %s 没有水域" % id)
		for w in f.waters:
			if not FishDef.WATERS.has(w):
				errors.append("鱼 %s 的水域无效：%s" % [id, w])
		for s in f.seasons:
			if not SEASON_IDS.has(s):
				errors.append("鱼 %s 的季节无效：%s" % [id, s])
		if not FishDef.TIMES.has(f.time):
			errors.append("鱼 %s 的时辰无效：%s" % [id, f.time])
		if f.weather != &"" and not Weather.NAMES.has(f.weather):
			errors.append("鱼 %s 的天气无效：%s" % [id, f.weather])
		if f.term != &"":
			var found := false
			for t in terms:
				if t.id == f.term:
					found = true
			if not found:
				errors.append("鱼 %s 的节气无效：%s" % [id, f.term])
		if f.min_size < 1 or f.max_size <= f.min_size:
			errors.append("鱼 %s 的体长范围无效" % id)
		if f.price <= 0:
			errors.append("鱼 %s 没有价钱" % id)
		if not f.trap and (f.pull <= 0.0 or f.fights <= 0.0 or f.fight_len <= 0.0):
			errors.append("鱼 %s 的遛鱼参数必须大于 0" % id)
	return errors


## 检查节日表。
func _validate_festivals() -> PackedStringArray:
	var errors := PackedStringArray()
	var days: Dictionary[int, StringName] = {}
	for id: StringName in festivals:
		var f: FestivalDef = festivals[id]
		if String(id).is_empty() or String(id) != String(id).to_snake_case():
			errors.append("节日 id 必须是小写下划线：'%s'" % id)
		if f.name.is_empty():
			errors.append("节日 %s 没有名称" % id)
		var term_index := term_index_of_id(f.term)
		if term_index < 0:
			errors.append("节日 %s 的节气不存在：%s" % [id, f.term])
		if f.day < 1 or f.day > GameClock.DAYS_PER_TERM:
			errors.append("节日 %s 在节气的第 %d 天，应该是 1 到 %d" % [id, f.day, GameClock.DAYS_PER_TERM])
		var at := term_index * GameClock.DAYS_PER_TERM + f.day
		if days.has(at):
			errors.append("节日 %s 和 %s 撞在同一天" % [id, days[at]])
		days[at] = id
		if not SceneRouter.MAPS.has(f.map):
			errors.append("节日 %s 在不存在的地图上：%s" % [id, f.map])
		if f.from < GameClock.DAY_START or f.to <= f.from or f.to > GameClock.DAY_END:
			errors.append("节日 %s 的时间不对" % id)
		if not npcs.has(f.host) or f.host_tile == FestivalDef.NO_TILE:
			errors.append("节日 %s 的主持人或他站的格子没写对：%s" % [id, f.host])
		if f.keeper != &"" and (not npcs.has(f.keeper) or f.keeper_tile == FestivalDef.NO_TILE or f.counter.is_empty()):
			errors.append("节日 %s 的摊主、他站的格子或摊子没写对：%s" % [id, f.keeper])
		if f.focus == FestivalDef.NO_TILE:
			errors.append("节日 %s 没写大家朝哪一格站" % id)
		var others := npcs.size() - (1 if f.keeper == &"" or f.keeper == f.host else 2)
		if f.crowd.size() < others:
			errors.append("节日 %s 的站位不够：要 %d 个，只有 %d 个" % [id, others, f.crowd.size()])
		var taken: Dictionary[Vector2i, bool] = {}
		var spots: Array[Vector2i] = [f.host_tile]
		if f.keeper != &"" and f.keeper != f.host:
			spots.append(f.keeper_tile)
		spots.append_array(f.crowd)
		spots.append_array(f.counter)
		for t in spots:
			if taken.has(t):
				errors.append("节日 %s 的格子 %s 用了两次" % [id, t])
			taken[t] = true
		for npc_id: StringName in npcs:
			var door_missing: bool = not npcs[npc_id].enter.has(f.map) and f.gate == FestivalDef.NO_TILE
			if door_missing:
				errors.append("节日 %s：%s 在 %s 上没有进出的格子，节日也没写 gate" % [id, npc_id, f.map])
		for item_id in f.goods:
			if not items.has(item_id):
				errors.append("节日 %s 卖的东西不存在：%s" % [id, item_id])
		for event: StringName in f.rivals:
			var last := 1 << 30
			for r: Dictionary in f.rivals[event]:
				if not npcs.has(r["npc"]):
					errors.append("节日 %s 的对手不存在：%s" % [id, r["npc"]])
				if int(r["score"]) > last:
					errors.append("节日 %s 的对手 %s 要按成绩从高到低排" % [id, event])
				last = int(r["score"])
		for fl in f.floaters:
			if not npcs.has(fl["npc"]):
				errors.append("节日 %s 放灯的人不存在：%s" % [id, fl["npc"]])
			if fl["lamp"] != &"" and not lamps.has(fl["lamp"]):
				errors.append("节日 %s 放灯要的灯不存在：%s" % [id, fl["lamp"]])
		for flavor: StringName in f.fillings:
			for item_id: StringName in f.fillings[flavor]:
				if not items.has(item_id):
					errors.append("节日 %s 的馅不存在：%s" % [id, item_id])
	return errors


## 检查一位居民的定义。地图名只查 SceneRouter 里登记过的。
func validate_npc(def: NpcDef) -> PackedStringArray:
	var errors := PackedStringArray()
	if String(def.id).is_empty() or String(def.id) != String(def.id).to_snake_case():
		errors.append("居民 id 必须是小写下划线：'%s'" % def.id)
	if def.name.is_empty():
		errors.append("居民 %s 没有名字" % def.id)
	if not NpcDef.SERVICES.has(def.service):
		errors.append("居民 %s 的铺子无效：%s" % [def.id, def.service])
	if not FileAccess.file_exists(SHEET_DIR + def.sheet + ".json"):
		errors.append("居民 %s 的序列帧不存在：%s（先运行 tools/character.py）" % [def.id, def.sheet])
	if not FileAccess.file_exists(SHEET_DIR + def.sheet + "_face.png"):
		errors.append("居民 %s 的头像不存在：%s_face.png（先运行 tools/portraits.py）" % [def.id, def.sheet])
	var seen: Dictionary[StringName, bool] = {}
	for list: Array[StringName] in [def.loves, def.likes, def.dislikes]:
		for item_id in list:
			if not items.has(item_id):
				errors.append("居民 %s 的喜好里有不存在的物品：%s" % [def.id, item_id])
			if seen.has(item_id):
				errors.append("居民 %s 的喜好里 %s 出现了两次" % [def.id, item_id])
			seen[item_id] = true
	if def.schedule.is_empty():
		errors.append("居民 %s 没有日程" % def.id)
	for map_id: StringName in def.enter:
		if not SceneRouter.MAPS.has(map_id):
			errors.append("居民 %s 的出入口在不存在的地图上：%s" % [def.id, map_id])
	if def.early_until != &"" and def.early_schedule.is_empty():
		errors.append("居民 %s 写了 early_until，但没有 early_schedule" % def.id)
	for plan: Array[Dictionary] in [def.schedule, def.rain_schedule, def.early_schedule, def.early_rain_schedule]:
		var last := -1
		for entry in plan:
			var from: int = entry["from"]
			var where: StringName = entry["map"]
			if from < 0 or from <= last:
				errors.append("居民 %s 的日程时间必须从早到晚：第 %d 分钟" % [def.id, from])
			last = from
			if where == &"":
				continue
			if not SceneRouter.MAPS.has(where):
				errors.append("居民 %s 的日程指向不存在的地图：%s" % [def.id, where])
			elif not def.enter.has(where):
				errors.append("居民 %s 会去 %s，但没写从哪一格进出" % [def.id, where])
	return errors
