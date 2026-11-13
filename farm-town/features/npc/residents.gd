extends Node
## 居民的全局状态：见过谁、今天和谁说过话送过礼、熟悉度、已经知道的喜好、忆的等级。
## 也是对话文件查询游戏状态的入口，和搭话时交委托、还遗物的入口。

## 熟悉度、见面、喜好有变化（名册界面用）
signal changed

const DIALOGUE_DIR := "res://dialogue/"
const COMMON_DIALOGUE := "res://dialogue/common.dialogue"
## 第一次见面、每天第一次说话加的熟悉度
const MEET_POINTS := 10
const TALK_POINTS := 8
## 送礼加的熟悉度，按对方的反应；良品、优品每档再多一点（不喜欢的东西品质再好也没用）
const GIFT_POINTS: Dictionary[StringName, int] = {&"love": 40, &"like": 20, &"ok": 10, &"dislike": -15}
const QUALITY_BONUS := 5
## 最初的灯点亮以后，每位居民头一回搭话说的那一段（对话文件里的段落名）
const ENDING_NEWS := "ending_news"
## 每一级忆对应这么多熟悉度。熟悉度最多攒到“当前忆等级 + 1”级的门槛，再往上要靠遗物
const STEP := 100

## 说过第一次话的居民
var met: Dictionary[StringName, bool] = {}
## 今天和每位居民说了几次话
var talks_today: Dictionary[StringName, int] = {}
## 今天给谁送过礼（每人每天一次）
var gifted_today: Dictionary[StringName, bool] = {}
var familiarity: Dictionary[StringName, int] = {}
## 送过以后才知道的喜好：居民 id -> {物品 id: 反应}
var known_tastes: Dictionary[StringName, Dictionary] = {}

## 上一次和每位居民说话是第几天
var last_talk_day: Dictionary[StringName, int] = {}
## 最近一次送的礼还没被道谢的：居民 id -> {"item": 物品 id, "day": 第几天, "taste": 反应}
var last_gift: Dictionary[StringName, Dictionary] = {}
## 闲聊的话题袋：每个袋子里是还没聊过的话题编号，聊完一轮再重新装（见 topic）
var topic_bags: Dictionary[String, Array] = {}
## 每位居民的忆等级（0 到 5），没记录的是 0
var memory_levels: Dictionary[StringName, int] = {}

## 今天每个话题袋抽到的是哪一个；同一天再问还是它
var _topic_today: Dictionary[String, int] = {}
## 今天第一次说话时，离上一次说话隔了几天
var _gap: Dictionary[StringName, int] = {}

## 正在问“要不要送”的那位居民，以及当时对方是不是在看铺子
var _offer_to: StringName = &""
var _offer_working := false


func _ready() -> void:
	SaveSystem.register(&"residents", self)
	GameClock.register_daily(GameClock.ORDER_NPCS, _on_new_day)


func dialogue_path(id: StringName) -> String:
	return DIALOGUE_DIR + String(id) + ".dialogue"


func has_met(id: StringName) -> bool:
	return met.get(id, false)


func talks(id: StringName) -> int:
	return talks_today.get(id, 0)


func familiarity_of(id: StringName) -> int:
	return familiarity.get(id, 0)


## 忆等级，0 到 5。归还对应的遗物才会涨。
func memory_level(id: StringName) -> int:
	return memory_levels.get(id, 0)


## 已经找回的全部记忆，按时间线排（出事那天前后）。
func recovered() -> Array[MemoryDef]:
	var out: Array[MemoryDef] = []
	for m in Database.memories:
		var got := Story.lan_level() >= m.level if m.npc == &"lan" else m.level <= memory_level(m.npc)
		if got:
			out.append(m)
	out.sort_custom(func(a: MemoryDef, b: MemoryDef) -> bool: return a.order < b.order)
	return out


## 这件遗物现在出不出现：下一级的可以找，再后面的先不出，免得池子被高阶的淹没。
func relic_available(r: RelicDef) -> bool:
	if r == null or r.npc == &"" or r.level <= 0:
		return true
	if r.npc == &"lan":
		return Story.lan_level() + 1 >= r.level
	return memory_level(r.npc) + 1 >= r.level


## 手里拿着的是不是岚的下一段忆。
func holding_lan_memory() -> bool:
	var item := GameState.selected_item()
	if item == null or not Database.has_relic(item.id):
		return false
	var r := Database.relic(item.id)
	return r.npc == &"lan" and r.level == Story.lan_level() + 1


var _lan_line := ""


## 把岚的下一段遗物还回去。对话里紧接着用 lan_line() 念这段忆。
func give_lan() -> void:
	var item := GameState.selected_item()
	if not holding_lan_memory():
		return
	var r := Database.relic(item.id)
	if GameState.inventory.remove_at(GameState.selected_slot, 1) != 1:
		return
	GameState.set_flag(StringName("memory_lan_%d" % r.level))
	var m := Database.memory(&"lan", r.level)
	_lan_line = m.text if m != null else ""
	changed.emit()


func lan_line() -> String:
	return _lan_line


## 白鹭的画：还没点亮的灯，和井底那一盏（没走过考验的时候）。
func uncharted() -> String:
	var names := PackedStringArray()
	for id: StringName in Database.lamps:
		if not Lamps.is_lit(id):
			names.append(Database.lamp(id).name)
	if not GameState.has_flag(Story.TRIAL_FLAG):
		names.append("井底的灯")
	if names.is_empty():
		return "纸上的路都通了。"
	return "还没画实的是" + "、".join(names) + "。"


## 这件东西是不是这位居民下一级忆要的遗物。
func is_relic_for(id: StringName, item: ItemDef) -> bool:
	if item == null or item.kind != &"relic" or not Database.has_relic(item.id):
		return false
	var r := Database.relic(item.id)
	return r.npc == id and r.level == memory_level(id) + 1


## 现在能不能把这件遗物还给对方：得是下一级的遗物，而且熟悉度已经攒满这一级。
func can_return(id: StringName, item: ItemDef) -> bool:
	return is_relic_for(id, item) and familiarity_of(id) >= familiarity_cap(id)


## 归还遗物：忆升一级，返回这段忆。不动背包。
func return_relic(id: StringName, relic_id: StringName) -> MemoryDef:
	var m := Database.memory_for_relic(relic_id)
	if m == null or m.npc != id or m.level != memory_level(id) + 1:
		return null
	memory_levels[id] = m.level
	GameState.set_flag(StringName("memory_%s_%d" % [id, m.level]))
	changed.emit()
	return m


## 第一次见面不经搭话（序幕里小满自己跑过来）。
func greet(id: String) -> void:
	var key := StringName(id)
	if has_met(key):
		return
	met[key] = true
	add_familiarity(key, MEET_POINTS)
	changed.emit()


## 现在熟悉度最多能攒到多少。
func familiarity_cap(id: StringName) -> int:
	return (memory_level(id) + 1) * STEP


func add_familiarity(id: StringName, points: int) -> void:
	familiarity[id] = clampi(familiarity_of(id) + points, 0, familiarity_cap(id))
	changed.emit()


## 和这位居民搭话时播放对话文件里的哪一段：
## 第一次见面是 first；正在看铺子是 work；今天第一次说话是 daily，之后是 again。
func title_for(id: StringName, working: bool) -> String:
	if not has_met(id):
		return "first"
	if Story.owes_news(id):
		return ENDING_NEWS
	if working:
		return "work"
	var festival := Festivals.passage(id, talks(id) == 0)
	if festival != "":
		return festival
	return "daily" if talks(id) == 0 else "again"


## 这一段在哪个对话文件里：节日上的话在 festival.dialogue，别的在各人自己的文件。
func path_for(id: StringName, title: String) -> String:
	return Festivals.DIALOGUE if title.begins_with("fest_") else dialogue_path(id)


## 玩家和这位居民搭话。working 表示对方正在看铺子。
## 手里拿着对方委托要的东西就交委托；拿着对方的遗物就归还；拿着能送的东西、今天还没送过，就先问要不要送。
func talk(id: StringName, working: bool) -> void:
	var item := GameState.selected_item()
	var quest := Quests.deliverable(id, item, GameState.inventory.count_of(item.id) if item != null else 0)
	if quest != null and has_met(id):
		_deliver(quest)
		return
	if item != null and has_met(id) and is_relic_for(id, item):
		if can_return(id, item):
			_return(id, item)
		else:
			_offer_to = id
			EventBus.dialogue_requested.emit(COMMON_DIALOGUE, "relic_early")
		return
	if can_gift(id, item) and not Festivals.takes_goods(id):
		_offer_to = id
		_offer_working = working
		EventBus.dialogue_requested.emit(COMMON_DIALOGUE, "gift_offer")
		return
	_chat(id, working)


func _chat(id: StringName, working: bool) -> void:
	var title := title_for(id, working)
	if not has_met(id):
		add_familiarity(id, MEET_POINTS)
	elif talks(id) == 0:
		add_familiarity(id, TALK_POINTS)
	if talks(id) == 0:
		_gap[id] = GameClock.day - int(last_talk_day.get(id, GameClock.day))
		last_talk_day[id] = GameClock.day
	met[id] = true
	talks_today[id] = talks(id) + 1
	if title == ENDING_NEWS:
		Story.told(id)
	changed.emit()
	EventBus.dialogue_requested.emit(path_for(id, title), title)


## 交委托：收走东西，给钱和遗物，加熟悉度，播对方的话。背包放不下遗物就先不交。
func _deliver(quest: QuestDef) -> void:
	if quest.relic != &"" and not GameState.inventory.can_add(quest.relic, 1):
		EventBus.banner_requested.emit("背包满了，先腾个地方再来")
		return
	if not GameState.inventory.remove(quest.item, quest.count):
		return
	var reward := Quests.deliver(quest.id)
	GameState.money += int(reward.get("money", 0))
	var relic: StringName = reward.get("relic", &"")
	if relic != &"":
		GameState.inventory.add(relic, 1)
		GameState.set_flag(StringName("relic_" + String(relic)))
	add_familiarity(quest.npc, int(reward.get("points", 0)))
	talks_today[quest.npc] = talks(quest.npc) + 1
	last_talk_day[quest.npc] = GameClock.day
	changed.emit()
	EventBus.dialogue_requested.emit(dialogue_path(quest.npc), quest.dialogue_title())


## 还遗物：从手里拿走，忆升级，播那段记忆。
func _return(id: StringName, item: ItemDef) -> void:
	var slot := GameState.selected_slot
	if GameState.inventory.remove_at(slot, 1) != 1:
		return
	var m := return_relic(id, item.id)
	if m == null:
		return
	talks_today[id] = talks(id) + 1
	EventBus.dialogue_requested.emit(dialogue_path(id), m.dialogue_title())


# ---------------------------------------------------------------- 礼物

## 这样东西能不能当礼物：地里种的和野外采的都行，工具、种子、肥料不行。
func is_giftable(item: ItemDef) -> bool:
	return item != null and (item.kind == &"crop" or item.kind == &"forage")


## 现在能不能把 item 送给这位居民：见过面、今天还没送过。
func can_gift(id: StringName, item: ItemDef) -> bool:
	return has_met(id) and is_giftable(item) and not gifted_today.get(id, false)


## 把一件东西送给居民：记下反应、加熟悉度，返回对方的反应。不动背包。
func give(id: StringName, item_id: StringName, quality: int = 0) -> StringName:
	var taste := Database.npc(id).taste_of(item_id)
	var points: int = GIFT_POINTS[taste]
	if points > 0:
		points += QUALITY_BONUS * clampi(quality, 0, 2)
	gifted_today[id] = true
	if not known_tastes.has(id):
		known_tastes[id] = {}
	known_tastes[id][item_id] = taste
	last_gift[id] = {"item": item_id, "day": GameClock.day, "taste": taste}
	add_familiarity(id, points)
	return taste


## 已经知道这位居民对哪些东西是这种反应。
func known(id: StringName, taste: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	var tastes: Dictionary = known_tastes.get(id, {})
	for item_id: StringName in tastes:
		if tastes[item_id] == taste:
			out.append(item_id)
	return out


# ---------------------------------------------------------------- 给对话文件用

func weather_is(weather: String) -> bool:
	return String(Weather.today) == weather


func season_is(season: String) -> bool:
	return String(GameClock.season_id()) == season


## 现在是不是晚上六点以后。
func is_evening() -> bool:
	return GameClock.minutes >= 1080.0


## 现在是一天里的哪一段："morning" 十一点前、"noon" 到下午两点、"afternoon" 到六点、"evening" 六点以后。
func time_is(part: String) -> bool:
	var m := GameClock.minutes
	match part:
		"morning":
			return m < 660.0
		"noon":
			return m >= 660.0 and m < 840.0
		"afternoon":
			return m >= 840.0 and m < 1080.0
		"evening":
			return m >= 1080.0
	return false


## 今天和这位居民说的是第几次话（搭上话以后从 1 开始数）。
func nth(id: String) -> int:
	return talks(StringName(id))


## 和这位居民的熟悉度有没有到 points。
func knows(id: String, points: int) -> bool:
	return familiarity_of(StringName(id)) >= points


## 今天第一次搭话时，离上一次说话隔了几天；昨天刚说过是 1。
func away(id: String) -> int:
	return _gap.get(StringName(id), 0)


## 这盏灯点亮了没有。
func lamp_lit(lamp_id: String) -> bool:
	return Lamps.is_lit(StringName(lamp_id))


## 剧情标记有没有设过。
func has_flag(flag: String) -> bool:
	return GameState.has_flag(StringName(flag))


## 居民要送玩家一样东西：背包放不放得下。
func can_hold(item_id: String) -> bool:
	return GameState.inventory.can_add(StringName(item_id), 1)


## 居民把一样东西交给玩家，并记下标记 got_<物品id>；已经给过就不再给。
func hand(item_id: String) -> void:
	var flag := StringName("got_" + item_id)
	if GameState.has_flag(flag) or not Database.has_item(StringName(item_id)):
		return
	if GameState.inventory.add(StringName(item_id), 1) == 0:
		GameState.set_flag(flag)
		EventBus.banner_requested.emit("得到了 " + Database.item(StringName(item_id)).name)


## 对话里设一个剧情标记。
func mark(flag: String) -> void:
	GameState.set_flag(StringName(flag))


## 居民帮玩家把工具升一级（老周的忆换高级鱼竿）。到顶了就什么都不做。
func upgrade(tool_id: String) -> void:
	var id := StringName(tool_id)
	if GameState.upgrade_tool(id):
		EventBus.banner_requested.emit("%s升到了 %d 级" % [Database.item(id).name, GameState.tool_level(id)])


## 这位居民的忆到了第几级。
func memory(id: String) -> int:
	return memory_level(StringName(id))


## 这盏灯点亮以后，这位居民是不是第一次和玩家说话（只有一次返回真，用来说一句“灯亮了”）。
func lamp_news(id: String, lamp_id: String) -> bool:
	if not Lamps.is_lit(StringName(lamp_id)):
		return false
	var flag := StringName("lamp_news_%s_%s" % [lamp_id, id])
	if GameState.has_flag(flag):
		return false
	GameState.set_flag(flag)
	return true


## 现在是不是这个结局："keep" 留雾、"clear" 散雾、"name" 归名。
func ending_is(id: String) -> bool:
	return String(Story.ending()) == id


## 最初的灯点亮了没有（散雾或归名）：大家都想起来了。
func fog_lifted() -> bool:
	return Story.lamp_lit()


## 归名的条件齐了没有。
func all_remembered() -> bool:
	return Story.true_ready()


## 在最初的灯跟前做了选择："light" 点，别的是不点。对话说完以后由游戏主场景播结局。
func choose_ending(choice: String) -> void:
	var id := Story.choose(choice == "light")
	if id != &"":
		EventBus.ending_requested.emit(id)


## 现在是不是正开着这个节日（"sowing" "lantern" "firefly" "harvest" "dumpling" "newyear"）。
func festival_is(id: String) -> bool:
	return Festivals.is_open(StringName(id))


## 今年节日上的这件事做过没有（"sow" "float" "release" "fill" "vigil" "judge_crop" ……）。
func fest_done(key: String) -> bool:
	return Festivals.done(key)


## 最近一次节日活动的结果里的一项（名次、奖金、东西的名字……），填进台词里。
func fest(key: String) -> String:
	return str(Festivals.said.get(key, ""))


## 今年放河灯，这位居民放不放。
func floats(id: String) -> bool:
	return Festivals.floaters().has(StringName(id))


## 今晚捉了几只萤火虫，够不够去放。
func fireflies() -> int:
	return Festivals.caught()


func fireflies_enough() -> bool:
	return Festivals.caught() >= Festivals.FIREFLY_GOAL


## 除夕灯会的规模，0 到 3。
func lantern_scale() -> int:
	return Festivals.scale()


## 在节日上做一件事（报播种数、放灯、放萤火虫、评比、交馅、听总结、守岁）。
## 算参加的，在场的居民都加一点熟悉度；有结果要说的，接着播那一段。
func festival_act(what: String) -> void:
	var result := Festivals.act(StringName(what))
	if result.is_empty():
		return
	if result.get("join", false):
		for id: StringName in Database.npcs:
			if has_met(id) and Festivals.attending(id):
				add_familiarity(id, Festivals.JOIN_POINTS)
	EventBus.dialogue_requested.emit(Festivals.DIALOGUE, str(result["title"]))


## 这位居民现在按日程在干什么（日程项里的 note）是不是 note。
func at(id: String, note: String) -> bool:
	var key := StringName(id)
	if not Database.has_npc(key):
		return false
	return str(NpcSchedule.spot_at(Database.npc(key), GameClock.minutes, Weather.today).get("note", "")) == note


## 从 count 个话题里抽今天聊哪个，返回 0 到 count-1。同一天问多少次都是同一个；
## 抽过的不放回，一轮聊完才重新装袋，所以不会连着几天说同一句。key 是话题袋的名字，一般用居民 id。
func topic(key: String, count: int) -> int:
	if count <= 0:
		return 0
	if _topic_today.has(key):
		return int(_topic_today[key]) % count
	var bag: Array = topic_bags.get(key, [])
	var valid := not bag.is_empty()
	for v: Variant in bag:
		if int(v) >= count:
			valid = false
	if not valid:
		bag = range(count)
		bag.shuffle()
	var pick := int(bag.pop_back())
	topic_bags[key] = bag
	_topic_today[key] = pick
	return pick


## 前些天送的、对方喜欢的礼物，还没当面道过谢。
func owes_thanks(id: String) -> bool:
	var gift: Dictionary = last_gift.get(StringName(id), {})
	if gift.is_empty() or int(gift["day"]) >= GameClock.day:
		return false
	return gift["taste"] == &"love" or gift["taste"] == &"like"


## 那件礼物的名字。
func gift_name(id: String) -> String:
	var gift: Dictionary = last_gift.get(StringName(id), {})
	var item := Database.item(StringName(str(gift.get("item", ""))))
	return item.name if item != null else "东西"


## 道过谢了。
func thanked(id: String) -> void:
	last_gift.erase(StringName(id))


## “要不要送”那句话里的两个名字。
func offer_name() -> String:
	return Database.npc(_offer_to).name if Database.has_npc(_offer_to) else ""


func offer_item_name() -> String:
	var item := GameState.selected_item()
	return item.name if item != null else ""


## 玩家选了“送”：从手里拿走一个，接着播对方的反应。
func give_offer() -> void:
	var id := _offer_to
	_offer_to = &""
	var item := GameState.selected_item()
	if not can_gift(id, item):
		return
	var slot := GameState.selected_slot
	var quality := GameState.inventory.quality_at(slot)
	if GameState.inventory.remove_at(slot, 1) != 1:
		return
	var taste := give(id, item.id, quality)
	EventBus.dialogue_requested.emit(dialogue_path(id), "gift_" + String(taste))


## 玩家选了“只是说说话”：照常搭话。
func decline_offer() -> void:
	var id := _offer_to
	_offer_to = &""
	if Database.has_npc(id):
		_chat(id, _offer_working)


func _on_new_day() -> void:
	talks_today.clear()
	gifted_today.clear()
	_topic_today.clear()
	_gap.clear()


func save_data() -> Dictionary:
	var list: Array = []
	for id: StringName in met:
		if met[id]:
			list.append(String(id))
	var points: Dictionary = {}
	for id: StringName in familiarity:
		points[String(id)] = familiarity[id]
	var tastes: Dictionary = {}
	for id: StringName in known_tastes:
		var mine: Dictionary = {}
		var from: Dictionary = known_tastes[id]
		for item_id: StringName in from:
			mine[String(item_id)] = String(from[item_id])
		tastes[String(id)] = mine
	var talked: Dictionary = {}
	for id: StringName in last_talk_day:
		talked[String(id)] = last_talk_day[id]
	var gifts: Dictionary = {}
	for id: StringName in last_gift:
		var gift: Dictionary = last_gift[id]
		gifts[String(id)] = {"item": String(gift["item"]), "day": int(gift["day"]), "taste": String(gift["taste"])}
	var memory_out: Dictionary = {}
	for id: StringName in memory_levels:
		memory_out[String(id)] = memory_levels[id]
	return {
		"met": list, "familiarity": points, "tastes": tastes,
		"last_talk": talked, "last_gift": gifts, "topics": topic_bags.duplicate(true), "memory": memory_out,
	}


func load_data(data: Dictionary) -> void:
	reset_data()
	Festivals.reset()
	var list: Array = data.get("met", [])
	for id: Variant in list:
		met[StringName(str(id))] = true
	var points: Dictionary = data.get("familiarity", {})
	for id: Variant in points:
		familiarity[StringName(str(id))] = int(points[id])
	var tastes: Dictionary = data.get("tastes", {})
	for id: Variant in tastes:
		var mine: Dictionary = {}
		var from: Dictionary = tastes[id]
		for item_id: Variant in from:
			mine[StringName(str(item_id))] = StringName(str(from[item_id]))
		known_tastes[StringName(str(id))] = mine
	var talked: Dictionary = data.get("last_talk", {})
	for id: Variant in talked:
		last_talk_day[StringName(str(id))] = int(talked[id])
	var gifts: Dictionary = data.get("last_gift", {})
	for id: Variant in gifts:
		var gift: Dictionary = gifts[id]
		last_gift[StringName(str(id))] = {
			"item": StringName(str(gift.get("item", ""))), "day": int(gift.get("day", 0)),
			"taste": StringName(str(gift.get("taste", "ok"))),
		}
	var bags: Dictionary = data.get("topics", {})
	for key: Variant in bags:
		var bag: Array = []
		var from: Array = bags[key]
		for v: Variant in from:
			bag.append(int(v))
		topic_bags[str(key)] = bag
	var memory_in: Dictionary = data.get("memory", {})
	for id: Variant in memory_in:
		memory_levels[StringName(str(id))] = clampi(int(memory_in[id]), 0, 5)
	changed.emit()


func reset_data() -> void:
	met.clear()
	talks_today.clear()
	gifted_today.clear()
	familiarity.clear()
	known_tastes.clear()
	last_talk_day.clear()
	last_gift.clear()
	topic_bags.clear()
	memory_levels.clear()
	_topic_today.clear()
	_gap.clear()
	_offer_to = &""
	Festivals.reset()
