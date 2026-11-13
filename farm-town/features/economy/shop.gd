class_name Shop
extends RefCounted
## 镇上铺子的货单。杂货铺（grocery）卖当季能种的种子、肥料、果树苗、还没有的工具；铁匠铺（smith）做工具升级、卖加工设备。

## 把工具从第 n 级升到下一级的价格
const UPGRADE_PRICES: Array[int] = [1000, 3000, 8000]
const TOOLS: Array[StringName] = [&"hoe", &"watering_can", &"pickaxe"]
## 升级以后能按住蓄力、一次作用多格的工具
const CHARGE_TOOLS: Array[StringName] = [&"hoe", &"watering_can"]
## 升到下一级除了钱还要的矿石：第 n 项是从第 n 级往上升要的
const UPGRADE_MATERIALS: Array = [
	[{"item": &"iron_ore", "count": 5}, {"item": &"copper_ore", "count": 5}],
	[{"item": &"silver_ore", "count": 5}, {"item": &"coal", "count": 8}],
	[{"item": &"gold_ore", "count": 5}, {"item": &"coal", "count": 10}],
]
## 镐子每升一级多一条好处：第 n 项是升到第 n+1 级得到的
const PICKAXE_NOTES: Array[String] = ["带矿的石头也一下敲开。", "每一镐只花 1 点体力。", "敲开矿石多掉一份的机会更大。"]
const GROCERY := &"grocery"
const SMITH := &"smith"
## 货单的标题
const COUNTER_NAMES: Dictionary[StringName, String] = {GROCERY: "阿禾杂货铺", SMITH: "石叔铁匠铺"}


## 这个季节在卖的种子，按价格从低到高。
static func stock(season: StringName) -> Array[ItemDef]:
	var seasons: Array[StringName] = [season]
	# 阿禾忆到五级：货架上多摆前后各一季的种子
	if Residents.memory_level(&"ahe") >= 5:
		var i := Database.SEASON_IDS.find(season)
		if i >= 0:
			seasons.append(Database.SEASON_IDS[(i + 3) % 4])
			seasons.append(Database.SEASON_IDS[(i + 1) % 4])
	var out: Array[ItemDef] = []
	var seen: Dictionary[StringName, bool] = {}
	for s: StringName in seasons:
		for id: StringName in Database.crops:
			var crop: CropDef = Database.crops[id]
			if crop.shop and crop.can_sow(s) and Database.has_item(crop.seed) and not seen.has(crop.seed):
				seen[crop.seed] = true
				out.append(Database.item(crop.seed))
	out.sort_custom(_by_price)
	return out


## 杂货铺的货架齐不齐：点亮广场灯以前，树苗、好肥料和工具都不上架（序幕的解锁）。
static func full_shelves() -> bool:
	return GameState.has_flag(&"lamp_plaza")


## 一家铺子的货单。counter 为空时两家的合在一起。
static func entries(season: StringName, counter: StringName = &"") -> Array[ShopEntry]:
	var out: Array[ShopEntry] = []
	if counter != SMITH:
		out.append_array(_goods(season))
	if counter != GROCERY:
		out.append_array(_upgrades())
		out.append_array(_weapons())
		out.append_array(_accessories())
		out.append_array(_machines())
	return out


static func _goods(season: StringName) -> Array[ShopEntry]:
	var out: Array[ShopEntry] = []
	# 节日的摊子上多卖的东西排在最前面
	for id in Festivals.goods():
		out.append(_item_entry(Database.item(id)))
	for def in stock(season):
		out.append(_item_entry(def))
	var ferts: Array[ItemDef] = []
	for id: StringName in Database.items:
		if Database.items[id].kind == &"fertilizer":
			ferts.append(Database.items[id])
	ferts.sort_custom(_by_price)
	for def in ferts:
		if def.power > 1 and not full_shelves():
			continue
		out.append(_item_entry(def))
	if not full_shelves():
		return out
	var saplings: Array[ItemDef] = []
	for id: StringName in Database.items:
		if Database.items[id].kind == &"sapling":
			saplings.append(Database.items[id])
	saplings.sort_custom(_by_price)
	for def in saplings:
		out.append(_item_entry(def))
	# 还没有的工具，只卖一件
	for id: StringName in Database.items:
		var def: ItemDef = Database.items[id]
		if def.kind == &"tool" and def.price > 0 and GameState.inventory.count_of(id) == 0:
			var e := _item_entry(def)
			e.once = true
			out.append(e)
	# 钓具：鱼饵和蟹笼随便买，浮漂只卖一个
	var gear: Array[ItemDef] = []
	for id: StringName in Database.items:
		if Database.items[id].kind == &"gear" or Database.items[id].kind == &"feed":
			gear.append(Database.items[id])
	gear.sort_custom(_by_price)
	for def in gear:
		if def.stack == 1 and GameState.inventory.count_of(def.id) > 0:
			continue
		var e := _item_entry(def)
		e.once = def.stack == 1
		out.append(e)
	return out


static func _upgrades() -> Array[ShopEntry]:
	var out: Array[ShopEntry] = []
	for tool in TOOLS:
		var level := GameState.tool_level(tool)
		if level >= GameState.MAX_TOOL_LEVEL or not Database.has_item(tool) or not Database.item(tool).tiered:
			continue
		# 镐子是井口拿的，没拿到以前不列
		if tool == Mine.PICKAXE and not GameState.has_flag(Mine.PICKAXE_FLAG):
			continue
		var e := ShopEntry.new()
		e.item_id = tool
		e.upgrade = true
		e.name = "升级：%s%s" % [GameState.TIER_NAMES[level + 1], Database.item(tool).name]
		e.price = UPGRADE_PRICES[level]
		for m: Dictionary in UPGRADE_MATERIALS[level]:
			var copy: Dictionary = m.duplicate()
			# 石叔想起最后一道工序：每种矿少要一块（至少留一块）
			if Residents.memory_level(&"shishu") >= 5 and int(copy["count"]) > 1:
				copy["count"] = int(copy["count"]) - 1
			e.materials.append(copy)
		var gain := PICKAXE_NOTES[level] if tool == Mine.PICKAXE else "按住蓄力，一次作用 %d 格。" % ToolArea.COUNTS[level + 1]
		e.desc = "要%s。%s" % [materials_text(e.materials), gain]
		e.icon = "%s@%d" % [Database.item(tool).icon, level + 1]
		out.append(e)
	return out


## 材料写成一句话：“铁矿石 ×5、铜矿石 ×5”。
static func materials_text(list: Array[Dictionary]) -> String:
	var parts := PackedStringArray()
	for m in list:
		parts.append("%s ×%d" % [Database.item(m["item"]).name, int(m["count"])])
	return "、".join(parts)


## 石叔打的武器：到过井口以后上架，每样只卖一件，手里有了就不再卖。
static func _weapons() -> Array[ShopEntry]:
	var out: Array[ShopEntry] = []
	if not GameState.has_flag(&"got_pickaxe"):
		return out
	var list: Array[ItemDef] = []
	for id: StringName in Database.weapons:
		var def := Database.item(id)
		if def.price > 0 and GameState.inventory.count_of(id) == 0:
			list.append(def)
	list.sort_custom(_by_price)
	for def in list:
		var e := _item_entry(def)
		e.once = true
		out.append(e)
	return out


## 石叔打的饰品：打倒废矿车以后上架，除了钱还要矿石；每样只打一件，手里有了就不再打。
static func _accessories() -> Array[ShopEntry]:
	var out: Array[ShopEntry] = []
	if not GameState.has_flag(&"boss_cart"):
		return out
	var list: Array[ItemDef] = []
	for id: StringName in Database.accessories:
		if Database.accessory(id).price > 0 and GameState.inventory.count_of(id) == 0:
			list.append(Database.item(id))
	list.sort_custom(_by_price)
	for def in list:
		var acc := Database.accessory(def.id)
		var e := _item_entry(def)
		e.once = true
		e.materials = acc.materials
		e.desc = "要%s。%s" % [acc.materials_text(), acc.desc]
		out.append(e)
	return out


## 这一行要的材料背包里够不够。
static func has_materials(e: ShopEntry) -> bool:
	for m in e.materials:
		if GameState.inventory.count_of(m["item"]) < int(m["count"]):
			return false
	return true


## 还没买的加工设备：买了石叔送到农场上，不进背包。
static func _machines() -> Array[ShopEntry]:
	var out: Array[ShopEntry] = []
	for id: StringName in Database.machines:
		var def := Database.machine(id)
		if GameState.has_flag(def.owned_flag()) or not GameState.has_flag(def.flag):
			continue
		var e := ShopEntry.new()
		e.flag = def.owned_flag()
		e.once = true
		e.name = def.name
		e.price = def.price
		e.desc = def.desc
		e.icon = "machine:" + String(def.id)
		out.append(e)
	return out


## 现在最多买得起、放得下几个（不超过 want）。
static func affordable(item_id: StringName, want: int) -> int:
	if not Database.has_item(item_id):
		return 0
	var def := Database.item(item_id)
	var n := want
	if def.price > 0:
		n = mini(n, GameState.money / asking_price(def))
	while n > 0 and not GameState.inventory.can_add(item_id, n):
		n -= 1
	return maxi(n, 0)


## 买 count 个；钱不够或背包放不下时什么都不做并返回 false。
static func buy(item_id: StringName, count: int) -> bool:
	if count <= 0 or affordable(item_id, count) < count:
		return false
	GameState.money -= asking_price(Database.item(item_id)) * count
	GameState.inventory.add(item_id, count)
	return true


## 目录里这一行现在最多能买几个。升级一次只能买一个。
static func affordable_entry(e: ShopEntry, want: int) -> int:
	if e.flag != &"":
		return 1 if want > 0 and GameState.money >= e.price and not GameState.has_flag(e.flag) else 0
	if not e.materials.is_empty() and not has_materials(e):
		return 0
	if not e.upgrade:
		return affordable(e.item_id, 1 if e.once else want)
	if want <= 0 or GameState.money < e.price or GameState.tool_level(e.item_id) >= GameState.MAX_TOOL_LEVEL:
		return 0
	return 1


static func buy_entry(e: ShopEntry, count: int) -> bool:
	if e.flag != &"":
		if affordable_entry(e, count) < 1:
			return false
		GameState.money -= e.price
		GameState.set_flag(e.flag)
		return true
	if e.upgrade:
		if count != 1 or affordable_entry(e, 1) < 1:
			return false
		GameState.money -= e.price
		for m in e.materials:
			GameState.inventory.remove(m["item"], int(m["count"]))
		GameState.upgrade_tool(e.item_id)
		return true
	if not e.materials.is_empty():
		# 先看买不买得成，成了再收材料
		if affordable_entry(e, 1) < 1 or not buy(e.item_id, 1):
			return false
		for m in e.materials:
			GameState.inventory.remove(m["item"], int(m["count"]))
		return true
	return buy(e.item_id, 1 if e.once else count)


static func _item_entry(def: ItemDef) -> ShopEntry:
	var e := ShopEntry.new()
	e.item_id = def.id
	e.name = def.name
	e.price = asking_price(def)
	e.desc = def.desc
	e.icon = def.icon
	return e


## 标价。阿禾忆到四级，种子打八折。
static func asking_price(def: ItemDef) -> int:
	if def != null and def.kind == &"seed" and Residents.memory_level(&"ahe") >= 4:
		return maxi(1, int(round(float(def.price) * 0.8)))
	return def.price if def != null else 0


static func _by_price(a: ItemDef, b: ItemDef) -> bool:
	if a.price != b.price:
		return a.price < b.price
	return String(a.id) < String(b.id)
