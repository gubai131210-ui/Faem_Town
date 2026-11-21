class_name Story
extends RefCounted
## 终幕和结局的规则。留雾、散雾、归名，再加上团圆饭、山海有名、家业、远行。自己不存东西：选了什么都记在 GameState 的标记里。
##
## 井底的考验走完以后，灯座的龛里露出“最初的灯”。对着它选：
## - 不点：留雾（keep）。以后还能下来改主意。
## - 点：散雾（clear）；要是全镇的忆都满了、岚的忆也满了，就是归名（name）。点了就不能再改成留雾。
## - 先点成了散雾、后来才把忆找全：可以再下来，把结局补成归名（决策 067）。

const KEEP := &"keep"
const CLEAR := &"clear"
const NAME := &"name"
## 另外四个结局，和留雾、散雾、归名不互相覆盖。一局里可以都看到（决策 132、137）。
const FEAST := &"feast"
const NAMED := &"named"
const ESTATE := &"estate"
## 另外半张船票在阿芸走时带走了。信退回空信封，灯亮了她也没回来。远行是拿着这半张从东滩出去找（决策 137）。
const VOYAGE := &"voyage"
const TITLES: Dictionary[StringName, String] = {
	KEEP: "留雾", CLEAR: "散雾", NAME: "归名",
	FEAST: "团圆饭", NAMED: "山海有名", ESTATE: "家业", VOYAGE: "远行",
}
const DIALOGUE := "res://dialogue/ending.dialogue"
## 走完岚之影的考验立的标记
const TRIAL_FLAG := &"boss_shade"
## 忆的满级
const MEMORY_MAX := 5
## 岚的忆满了（第五段交还以后）
const LAN_FLAG := &"memory_lan_5"
## 六位新居民各有三段忆，不计入归名。归名仍是原来的十一位加岚。
const ASIDE: Array[StringName] = [
	&"shuoshu", &"jiangyuan", &"huolang", &"chuanniang", &"miaozhu", &"shanliren",
]


## 现在是哪个结局：点过灯的算点灯的那个，只选过不点的是 keep，都没有是空。
static func ending() -> StringName:
	if GameState.has_flag(&"ending_name"):
		return NAME
	if GameState.has_flag(&"ending_clear"):
		return CLEAR
	if GameState.has_flag(&"ending_keep"):
		return KEEP
	return &""


## 最初的灯点亮了没有（散雾或归名）。
static func lamp_lit() -> bool:
	var e := ending()
	return e == CLEAR or e == NAME


## 选过“不点”，灯还黑着。
static func kept() -> bool:
	return ending() == KEEP


## 现在能不能对着最初的灯做选择：考验走完了，灯还没点。
static func can_choose() -> bool:
	return GameState.has_flag(TRIAL_FLAG) and not lamp_lit()


## 散雾以后忆找全了，可以回井底把结局补成归名。
static func can_name() -> bool:
	return ending() == CLEAR and true_ready()


## 补成归名。现在不能补就什么都不做，返回 false。
static func complete_name() -> bool:
	if not can_name():
		return false
	GameState.set_flag(StringName("ending_" + String(NAME)))
	# 散雾那天说过的话里，归名才有的那两句还没机会说
	GameState.clear_flag(_news_flag(&"bai"))
	GameState.clear_flag(_news_flag(&"xiaoman"))
	return true


## 有忆可找、还没找全的居民。
static func unfinished() -> Array[StringName]:
	var has_memory: Dictionary[StringName, bool] = {}
	for m in Database.memories:
		has_memory[m.npc] = true
	var out: Array[StringName] = []
	for id: StringName in Database.npcs:
		if has_memory.has(id) and not ASIDE.has(id) and Residents.memory_level(id) < MEMORY_MAX:
			out.append(id)
	return out


## 岚的忆现在到第几级。必须一级级来，中间断了就停在断掉的前一级。
static func lan_level() -> int:
	var n := 0
	for i in range(1, MEMORY_MAX + 1):
		if not GameState.has_flag(StringName("memory_lan_%d" % i)):
			break
		n = i
	return n


## 归名的条件：有忆的居民都满级，岚的忆也满级。
static func true_ready() -> bool:
	return GameState.has_flag(LAN_FLAG) and unfinished().is_empty()


## 做了选择，返回是哪个结局；现在不能选返回空。
static func choose(light: bool) -> StringName:
	if not can_choose():
		return &""
	var id := KEEP
	if light:
		id = NAME if true_ready() else CLEAR
	GameState.set_flag(StringName("ending_" + String(id)))
	return id


## 灯点亮以后，这位居民还没跟玩家说过那天的事。
static func owes_news(id: StringName) -> bool:
	return lamp_lit() and not GameState.has_flag(_news_flag(id))


static func told(id: StringName) -> void:
	GameState.set_flag(_news_flag(id))


static func _news_flag(id: StringName) -> StringName:
	return StringName("ending_news_" + String(id))


## 团圆饭、山海有名、家业、远行。条件齐了、还没看过，返回真。不改原来的三个结局。
static func side_ready(id: StringName) -> bool:
	if GameState.has_flag(StringName("ending_" + String(id))):
		return false
	if id == FEAST:
		return Crafting.has_set(&"terms") and Crafting.has_set(&"homes") and GameState.has_flag(&"relic_miner_roster")
	if id == NAMED:
		return _beasts_seen() and GameState.has_flag(&"relic_miner_roster")
	if id == ESTATE:
		return _trades_done()
	if id == VOYAGE:
		return GameState.has_flag(&"memory_jiang_5") and GameState.has_flag(&"got_ferry_stub") and Lamps.is_lit(&"east")
	return false


## 记下这个结局，等当前这句说完再演。条件不够就什么都不做。
static func begin_side(id: String) -> void:
	var key := StringName(id)
	if not side_ready(key):
		return
	GameState.set_flag(StringName("ending_" + id))
	EventBus.ending_requested.emit(key)


static func _beasts_seen() -> bool:
	for id: StringName in Bestiary.IDS:
		if not Bestiary.seen(id):
			return false
	return true


static func _trades_done() -> bool:
	for id: StringName in Livelihood.IDS:
		if Livelihood.told(id) < 3:
			return false
	return true
