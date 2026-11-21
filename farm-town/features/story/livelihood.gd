class_name Livelihood
extends RefCounted
## 家业线（决策 131）。六个行当各三级，师傅当面说一句。
## 条件用已经记下的数：优品作物、鱼种、养过的牲口、井深和工具、采过的野物、灶台称号。
## 不是 autoload。说过的等级记在 GameState 的标记里。不给钱，不加物品，不新增结局。


const IDS: Array[StringName] = [&"farm", &"fish", &"herd", &"mine", &"pick", &"stove"]
const NAMES: Dictionary[StringName, String] = {
	&"farm": "种田", &"fish": "钓鱼", &"herd": "养殖",
	&"mine": "打铁和下井", &"pick": "采集", &"stove": "灶台",
}
const SPEAKER_NAME: Dictionary[StringName, String] = {
	&"farm": "阿禾", &"fish": "老周", &"herd": "阿牧",
	&"mine": "石叔", &"pick": "姜婆婆", &"stove": "云娘",
}
const LEVEL_NAME: PackedStringArray = ["一级", "二级", "三级"]
## 种田、钓鱼、养殖、采集：够这个数升到下一级。打铁和灶台另算。
const NEED: Dictionary[StringName, Array] = {
	&"farm": [2, 6, 12],
	&"fish": [3, 8, 16],
	&"herd": [1, 3, 5],
	&"pick": [3, 7, 12],
}


static func name_of(id: StringName) -> String:
	return String(NAMES.get(id, ""))


static func speakers(id: StringName) -> Array[StringName]:
	match id:
		&"farm":
			return [&"ahe"]
		&"fish":
			return [&"laozhou"]
		&"herd":
			return [&"amu"]
		&"mine":
			return [&"shishu", &"laoqin"]
		&"pick":
			return [&"jiang"]
		&"stove":
			return [&"yunniang"]
	return []


static func line(id: StringName, level: int) -> String:
	var lines: Array[String] = []
	match id:
		&"farm":
			lines = ["地认你了。锄头我给你磨轻了一点。", "优品出过这么多种，桩上给你记着。", "这片地算你的家业了。"]
		&"fish":
			lines = ["竿使得顺了。甩出去不那么费劲。", "鱼认得你的线。它们来得快一点。", "这河算你跑熟了。"]
		&"herd":
			lines = ["牲口认你的手。摸的时候多给一点。", "养过这么几种，棚里有你的位子。", "这摊畜生算你的家业了。"]
		&"mine":
			lines = ["井下到过第五层。梯子还在，人得自己下。", "工具升过，井也深了。锤子认你的手。", "井下到过三十层，镐子也跟得上。"]
		&"pick":
			lines = ["这几样草你认得了。路过药铺，我给你续一口。", "山里的东西你捡进来了。篮子给你留着。", "当季的野物，你闭着眼也摸得着。"]
		&"stove":
			lines = ["云娘叫你帮厨。灶边给你留了一把木勺。", "云娘叫你掌勺。火候你看一眼就知道。", "云娘叫你大师傅。这口灶算你的。"]
	if level < 1 or level > lines.size():
		return ""
	return lines[level - 1]


## 镇上或农场上多出来的那一句。还没说过就空。
static func mark(id: StringName) -> String:
	var n := told(id)
	if n <= 0:
		return ""
	match id:
		&"farm":
			return "界桩立在出货箱旁边。锄头轻了一点。"
		&"fish":
			return "渡口多了一只浮子。甩竿省一点力气。"
		&"herd":
			return "棚边多了一只料袋。摸牲口更管用。"
		&"mine":
			return "砧边多了一把备用锤。下井省一点力气。"
		&"pick":
			return "药铺墙边多了一只篮子。路过能续一口。"
		&"stove":
			return "灶边多了一把木勺。"
	return ""


static func progress(id: StringName) -> int:
	match id:
		&"farm":
			return Shipping.gold_crops.size()
		&"fish":
			return Fishing.species_count()
		&"herd":
			return Animals.raised.size()
		&"pick":
			return Foraging.found.size()
		&"stove":
			return _stove_level()
	return 0


static func ready(id: StringName) -> int:
	if id == &"mine":
		return _mine_ready()
	if id == &"stove":
		return _stove_level()
	if not NEED.has(id):
		return 0
	var n := progress(id)
	var steps: Array = NEED[id]
	var level := 0
	for i in steps.size():
		if n >= int(steps[i]):
			level = i + 1
	return level


static func _mine_ready() -> int:
	var depth := Mine.deepest
	var ups := 0
	for tool in [&"hoe", &"watering_can", &"pickaxe"]:
		if GameState.tool_level(tool) >= 1:
			ups += 1
	var level := 0
	if depth >= 5:
		level = 1
	if depth >= 15 and ups >= 1:
		level = 2
	if depth >= 30 and GameState.tool_level(&"pickaxe") >= 2:
		level = 3
	return level


static func _stove_level() -> int:
	var n := Crafting.RANK_ORDER.find(Crafting.rank)
	return n + 1 if n >= 0 else 0


static func _flag(id: StringName, level: int) -> StringName:
	return StringName("trade_%s_%d" % [String(id), level])


## 师傅已经说出口的等级。灶台跟云娘的称号是同一档。
static func told(id: StringName) -> int:
	if id == &"stove":
		return _stove_level()
	var n := 0
	for level in [1, 2, 3]:
		if GameState.has_flag(_flag(id, level)):
			n = level
	return n


## 下一次见面该说的那一档。不能跳。没有就 0。
static func pending_level(id: StringName) -> int:
	if id == &"stove":
		return 0
	var have := told(id)
	if ready(id) > have:
		return have + 1
	return 0


static func pending_title(npc: StringName) -> String:
	for id in IDS:
		if not speakers(id).has(npc):
			continue
		var n := pending_level(id)
		if n > 0:
			return "trade_%s_%d" % [String(id), n]
	return ""


## 对话标题是 trade_farm_1 这种。对得上才记下。
static func grant(title: String) -> void:
	if not title.begins_with("trade_"):
		return
	var body := title.substr(6)
	var under := body.rfind("_")
	if under <= 0:
		return
	var id := StringName(body.substr(0, under))
	var n := int(body.substr(under + 1))
	if pending_level(id) != n:
		return
	GameState.set_flag(_flag(id, n))
	if Story.side_ready(Story.ESTATE):
		Story.begin_side("estate")


static func journal_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for id in IDS:
		var n := told(id)
		if n <= 0:
			continue
		lines.append("%s，%s。%s说，%s" % [name_of(id), LEVEL_NAME[n - 1], SPEAKER_NAME[id], line(id, n)])
	return lines


## 除夕念账时接在后面。一个行当都没说过就空。
static func year_line() -> String:
	var parts := PackedStringArray()
	for id in IDS:
		var n := told(id)
		if n > 0:
			parts.append("%s到%s" % [name_of(id), LEVEL_NAME[n - 1]])
	if parts.is_empty():
		return ""
	return "家里的行当，" + "、".join(parts) + "。"


## 这一下工具少花的体力。浇地本来就是 1，不再减。
static func energy_cut(action: StringName) -> int:
	if action == &"hoe" and told(&"farm") >= 1:
		return 1
	if action == &"cast" and told(&"fish") >= 1:
		return 1
	if action == &"mine" and told(&"mine") >= 1:
		return 1
	if action == &"dig" and told(&"mine") >= 3:
		return 1
	return 0


## 钓鱼二级以后，鱼来得快一点。一级只是甩竿省力。
static func fish_wait_mult() -> float:
	var n := told(&"fish")
	if n >= 3:
		return 0.72
	if n >= 2:
		return 0.85
	return 1.0


## 养殖以后，每天第一次摸，心情多加这么多。
static func herd_extra() -> int:
	var n := told(&"herd")
	if n >= 2:
		return 4
	if n >= 1:
		return 2
	return 0


## 采集以后，每天头一回看药铺的墙，续一口体力。续过就返回假。
static func offer_sip() -> bool:
	if told(&"pick") < 1 or GameState.has_flag(&"trade_pick_sipped"):
		return false
	GameState.set_flag(&"trade_pick_sipped")
	GameState.energy += 4
	return true
