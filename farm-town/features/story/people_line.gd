class_name PeopleLine
extends RefCounted
## 人线的收束（决策 130）。十一位忆满各有一句落在镇上的话。
## 忆簿里三段排满了，小满或柏先生说一次小结。不新加 autoload。
## 不写那二十七个名字，也不写姜婆婆的母亲现在怎样。


const ELEVEN: Array[StringName] = [
	&"jiang", &"ahe", &"egret", &"qingzhu", &"shishu", &"amu",
	&"laozhou", &"yunniang", &"bai", &"luyuan", &"laoqin",
]
const SPAN_IDS: Array[StringName] = [&"year", &"morning", &"after"]


static func span_name(id: StringName) -> String:
	match id:
		&"year":
			return "出事前一年"
		&"morning":
			return "那天早上"
		&"after":
			return "之后三天"
	return ""


static func speaker(id: StringName) -> StringName:
	return &"bai" if id == &"morning" else &"xiaoman"


static func line(id: StringName) -> String:
	match id:
		&"year":
			return "出事那年春天到前一夜，老周的孩子还在码头，云娘的歌还没唱完，柏先生盖了一整天的章。"
		&"morning":
			return "那天早上井口挂着二十八只钩。上去的只有老秦，是岚推的。"
		&"after":
			return "之后三天夜里没人睡得着。信寄到这座农舍，收信的人是阿芸。"
	return ""


static func _whens(id: StringName) -> PackedStringArray:
	match id:
		&"year":
			return PackedStringArray(["事故那年春天", "事故前一夜", "事故前一天"])
		&"morning":
			return PackedStringArray(["那一天"])
		&"after":
			return PackedStringArray(["事故后", "事故之后"])
	return PackedStringArray()


static func _in_span(id: StringName) -> Array[MemoryDef]:
	var whens := _whens(id)
	var out: Array[MemoryDef] = []
	for m in Database.memories:
		if ELEVEN.has(m.npc) and whens.has(m.when):
			out.append(m)
	return out


static func full(id: StringName) -> bool:
	var list := _in_span(id)
	if list.is_empty():
		return false
	for m in list:
		if Residents.memory_level(m.npc) < m.level:
			return false
	return true


static func _flag(id: StringName) -> StringName:
	return StringName("people_span_" + String(id))


static func said(id: StringName) -> bool:
	return GameState.has_flag(_flag(id))


## 对话标题是 span_year 这种。说过就记下来。
static func told(title: String) -> void:
	if not title.begins_with("span_"):
		return
	var id := StringName(title.substr(5))
	if not SPAN_IDS.has(id):
		return
	GameState.set_flag(_flag(id))


## 这位还没说过的、已经排满的那一段。没有就空。
static func pending_title(npc: StringName) -> String:
	for id in SPAN_IDS:
		if speaker(id) == npc and full(id) and not said(id):
			return "span_" + String(id)
	return ""


static func journal_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for id in SPAN_IDS:
		if not full(id):
			continue
		var who := "柏先生" if speaker(id) == &"bai" else "小满"
		lines.append("%s。%s说，%s" % [span_name(id), who, line(id)])
	return lines


## 选中的这段正好是排满的那一段里最晚的一条，右边补上小结。
static func note_for(m: MemoryDef) -> String:
	if m == null:
		return ""
	for id in SPAN_IDS:
		if not full(id):
			continue
		var best := -999999
		var last: MemoryDef = null
		for item in _in_span(id):
			if item.order >= best:
				best = item.order
				last = item
		if last != null and last.npc == m.npc and last.level == m.level:
			return line(id)
	return ""


static func closed(npc: StringName) -> bool:
	return ELEVEN.has(npc) and Residents.memory_level(npc) >= Story.MEMORY_MAX


## 忆满以后，镇上这一处换成的那句话。还没满就空。
static func mark(npc: StringName) -> String:
	if not closed(npc):
		return ""
	match npc:
		&"ahe":
			return "招牌换回来了。上面写的是禾记。"
		&"qingzhu":
			return "最后一颗钉归位了。这座桥可以走人。"
		&"yunniang":
			return "菜牌写定了。她把那首歌唱完了。"
		&"egret":
			return "画完了。纸上的那些路，镇上还没走通。"
		&"shishu":
			return "锤柄上的顺序他想起来了。收口就按这个来。"
		&"amu":
			return "篱笆上钉着一块小牌。写的是大黄。"
		&"laozhou":
			return "桩上刻着阿海。那是他儿子。"
		&"bai":
			return "许可盖全了。农场小溪东岸可以开垦。"
		&"laoqin":
			return "梯子还在。是岚把他推上去的。"
		&"jiang":
			return "这封信寄到这座农舍。收信的人是阿芸。"
		&"luyuan":
			return "他父亲的名字也在碑上，和水冲平的那些在一起。"
	return ""
