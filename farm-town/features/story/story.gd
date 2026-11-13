class_name Story
extends RefCounted
## 终幕和三个结局的规则。自己不存东西：选了什么都记在 GameState 的标记里。
##
## 井底的考验走完以后，灯座的龛里露出“最初的灯”。对着它选：
## - 不点：留雾（keep）。以后还能下来改主意。
## - 点：散雾（clear）；要是全镇的忆都满了、岚的忆也满了，就是归名（name）。点了就不能再选。

const KEEP := &"keep"
const CLEAR := &"clear"
const NAME := &"name"
const TITLES: Dictionary[StringName, String] = {KEEP: "留雾", CLEAR: "散雾", NAME: "归名"}
const DIALOGUE := "res://dialogue/ending.dialogue"
## 走完岚之影的考验立的标记
const TRIAL_FLAG := &"boss_shade"
## 忆的满级
const MEMORY_MAX := 5
## 岚的忆满了（第五段交还以后）
const LAN_FLAG := &"memory_lan_5"


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


## 有忆可找、还没找全的居民。
static func unfinished() -> Array[StringName]:
	var has_memory: Dictionary[StringName, bool] = {}
	for m in Database.memories:
		has_memory[m.npc] = true
	var out: Array[StringName] = []
	for id: StringName in Database.npcs:
		if has_memory.has(id) and Residents.memory_level(id) < MEMORY_MAX:
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
