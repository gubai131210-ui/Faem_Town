class_name Journal
extends RefCounted
## 手账：名册里的一页。只写已经发生过的事，和下一条居民亲口说过的线索。
## 不记进度、不标百分比。看过的过场在「看过」里，确定键再演一遍，不改状态。
## 灶这一页写残页、试过的失败，以及云娘给过的称呼。食单是右边的格子，不写进这一页的正文。


const HINT_FLAG := &"journal_hint"
const HINT := "想不起来做什么，翻翻手账。"
const BLANK := "这一页还是空白的。"
const CutsceneScript := preload("res://game/cutscene.gd")
const PAGE_IDS: Array[StringName] = [&"lamps", &"people", &"livelihood", &"stove", &"menu", &"seen", &"beasts", &"endings"]
const PAGE_NAMES: Dictionary[StringName, String] = {
	&"lamps": "灯", &"people": "人", &"livelihood": "家业", &"stove": "灶",
	&"menu": "食单", &"seen": "看过", &"beasts": "山海录", &"endings": "结局",
}
const ENDING_IDS: Array[StringName] = [&"keep", &"clear", &"name", &"feast", &"named", &"estate", &"voyage"]
const SEASON_WHEN: Dictionary[StringName, String] = {
	&"spring": "春天", &"summer": "夏天", &"autumn": "秋天", &"winter": "冬天",
}


static func page_count() -> int:
	return PAGE_IDS.size()


static func page_name(index: int) -> String:
	return PAGE_NAMES[PAGE_IDS[index]]


static func page_id(index: int) -> StringName:
	return PAGE_IDS[index]


static func page_text(index: int) -> String:
	var lines := _lines(PAGE_IDS[index])
	if lines.is_empty():
		return BLANK
	return "\n".join(lines)


## 看过的过场标题，顺序和播放器的名单一样。
static func seen_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for item in CutsceneScript.seen_entries():
		lines.append(item["title"])
	return lines


## 三个结局一直列着。看过的写全名，能重看；没看过的只有名字的头一个字。
static func ending_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for id in ENDING_IDS:
		lines.append(ending_line(id))
	return lines


static func ending_seen(id: StringName) -> bool:
	return GameState.has_flag(StringName("ending_" + String(id)))


static func ending_line(id: StringName) -> String:
	var title := String(Story.TITLES[id])
	if ending_seen(id):
		return title
	return title.substr(0, 1) + "…"


static func ending_replay(index: int) -> StringName:
	if index < 0 or index >= ENDING_IDS.size():
		return &""
	var id: StringName = ENDING_IDS[index]
	if not ending_seen(id):
		return &""
	return StringName("ending_" + String(id))


static func seen_id(index: int) -> StringName:
	var entries: Array = CutsceneScript.seen_entries()
	if index < 0 or index >= entries.size():
		return &""
	return entries[index]["id"]


## 第二天以后的第一个早上说一次。第一天不说，说过就再也不说。
static func morning_line() -> String:
	if GameClock.day <= 1 or GameState.has_flag(HINT_FLAG):
		return ""
	GameState.set_flag(HINT_FLAG)
	return HINT


static func _lines(id: StringName) -> PackedStringArray:
	match id:
		&"lamps":
			return _lamps()
		&"people":
			return _people()
		&"livelihood":
			return _livelihood()
		&"stove":
			return _stove()
		&"seen":
			return seen_lines()
		&"beasts":
			return Bestiary.page_lines()
		&"endings":
			return ending_lines()
		&"menu":
			return PackedStringArray()
	return PackedStringArray()


static func _heard_xiaoman() -> bool:
	return GameState.has_flag(&"prologue_town") or Residents.has_met(&"xiaoman")


static func _lamps() -> PackedStringArray:
	var facts := PackedStringArray()
	var clue := ""
	if Lamps.is_lit(&"plaza"):
		facts.append("广场灯亮了。雾退开了一小圈。")
	elif _heard_xiaoman():
		clue = "小满说，广场中间那盏灯以前是亮的。要供的东西刻在灯座上，公告栏上也有。"
	if Lamps.is_lit(&"river"):
		facts.append("河灯亮了。雾顺着水退开。")
	elif clue == "" and GameState.has_flag(&"lantern_hint"):
		clue = "老周说，南溪水底沉着一盏灯。钓上来别扔。"
	if Lamps.is_lit(&"pasture"):
		facts.append("牧野灯亮了。西边的雾往坡上退。")
	elif clue == "" and (GameState.has_flag(&"bell_hint") or GameState.has_flag(&"amu_bell")):
		clue = "阿牧说，花花的铃丢在西边的雾里。道口有盏石灯，灯座上刻着要它。" if GameState.has_flag(&"amu_bell") else "阿牧说，花花的铃丢在西边的雾里。他站在路口听得见，不敢进去找。"
	if Lamps.is_lit(&"well"):
		facts.append("井口灯亮了。北边的雾贴着地往回缩。")
	elif clue == "":
		if GameState.has_flag(&"got_well_key"):
			clue = "老秦给了井口的钥匙。他说灯座上刻着要它。"
		elif GameState.has_flag(&"well_warned"):
			clue = "老秦喝过一声：那边是井，回去。"
	if Lamps.is_lit(&"east"):
		facts.append("东滩灯亮了。下游的雾被风吹向海上。")
	elif clue == "" and GameState.has_flag(&"got_ferry_stub"):
		clue = "姜婆婆说，东滩在河的下游，顺着河岸往东走到头。路口有一盏灭了三十年的灯。"
	if Lamps.is_lit(&"shrine"):
		facts.append("山祠灯亮了。山路上的雾往山顶收。")
	elif clue == "" and GameState.has_flag(&"bai_confessed"):
		clue = "柏先生说，山路口那盏灯要那块牌子。点不点，你比他有资格定。"
	if clue != "":
		facts.append(clue)
	return facts


static func _people() -> PackedStringArray:
	var facts := PackedStringArray()
	if _heard_xiaoman():
		facts.append("小满说，旧东西别扔。大人们看见会愣一下，想起一点什么。")
	var who := PackedStringArray()
	var seen: Dictionary[StringName, bool] = {}
	for memory in Residents.recovered():
		if seen.has(memory.npc):
			continue
		seen[memory.npc] = true
		who.append("岚" if memory.npc == &"lan" else Database.npc(memory.npc).name)
	if not who.is_empty():
		facts.append("想起过事的人：" + "、".join(who) + "。")
	if Story.lan_level() > 0 and not seen.has(&"lan"):
		facts.append("岚也想起事来了。")
	var stuck := _stuck_person()
	if stuck != "" and _heard_xiaoman():
		facts.append("%s熟悉到头了。小满说过，旧东西能让人想起点什么。" % stuck)
	facts.append_array(PeopleLine.journal_lines())
	return facts


static func _stuck_person() -> String:
	for id: StringName in Database.npcs:
		if not Residents.has_met(id):
			continue
		var cap := _memory_cap(id)
		if cap > 0 and Residents.memory_level(id) < cap and Residents.familiarity_of(id) >= Residents.familiarity_cap(id):
			return Database.npc(id).name
	return ""


static func _memory_cap(id: StringName) -> int:
	var n := 0
	while Database.memory(id, n + 1) != null:
		n += 1
	return n


static func _livelihood() -> PackedStringArray:
	var facts := PackedStringArray()
	if GameState.has_flag(&"read_letter"):
		facts.append("信上说：趁我还记得，回来吧。地还是好地。")
	if GameState.has_flag(&"got_rod"):
		facts.append("老周给了一根竿子。他说对着水甩，浮漂一沉就按一下，然后慢慢收。")
	var built := false
	for id: StringName in Database.buildings:
		if Animals.building_state(String(id)) >= 0:
			built = true
			break
	if built:
		facts.append("青竹在农场上盖过房子。")
	if Animals.total() > 0:
		facts.append("家里养上牲口了。")
	if GameState.has_flag(&"amu_chicks"):
		facts.append("阿牧说，小鸡小鸭能分给你了。")
	var barn_open := Animals.building_state("barn") < 0 and Animals.building_state("apiary") < 0
	if GameState.has_flag(&"amu_pasture") and barn_open:
		facts.append("阿牧说，大牲口和蜂也能分了。先找青竹盖畜棚、搭蜂场。")
	facts.append_array(Livelihood.journal_lines())
	return facts


## 食单上的菜，去掉试失败的那一碗。顺序跟菜谱表一样。
static func menu_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in Database.recipes:
		var rec: RecipeDef = Database.recipes[id]
		if rec.from == &"odd":
			continue
		ids.append(id)
	return ids


## 做过的写出菜名。没做过的只写做法和大概时候，不写名字，不写材料。
static func menu_line(id: StringName) -> String:
	if Crafting.made_dishes.has(id):
		return Database.item(id).name
	var rec: RecipeDef = Database.recipes[id]
	var how := String(RecipeDef.METHOD_NAMES.get(rec.method, "做"))
	var when := "平时"
	if rec.term != &"":
		var index := Database.term_index_of_id(rec.term)
		if index >= 0:
			when = Database.term(index).name + "前后"
	elif SEASON_WHEN.has(rec.season):
		when = SEASON_WHEN[rec.season]
	return "%s的，%s" % [how, when]


## 残页不写菜名，凑齐并看懂了才写。不写在哪一格。
static func _stove() -> PackedStringArray:
	var lines := PackedStringArray()
	var half := false
	var both := false
	for id: StringName in Database.recipes:
		var rec: RecipeDef = Database.recipes[id]
		if rec.scrap.size() != 2:
			continue
		var left := GameState.inventory.count_of(RecipeDef.scrap_item(id, 0)) > 0
		var right := GameState.inventory.count_of(RecipeDef.scrap_item(id, 1)) > 0
		if left and right:
			both = true
		elif left or right:
			half = true
		if Crafting.knows(id):
			lines.append("会做%s了。" % Database.item(id).name)
	if half:
		lines.append("有半张旧菜谱，字看不全。另一半也许在井里、雾天的地上，或者山野里。")
	if both:
		lines.append("左右两半都在手里，凑一凑就看得懂。")
	if GameState.has_flag(Crafting.ODD_FLAG):
		lines.append("做过一碗说不上来的东西。")
	if Crafting.rank_name() != "":
		lines.append("云娘叫你%s。" % Crafting.rank_name())
	for set_id: StringName in Crafting.SETS:
		if Crafting.has_set(set_id):
			lines.append("墙上挂着%s。" % Crafting.SET_NAMES[set_id])
	return lines
