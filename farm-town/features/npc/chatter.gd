class_name Chatter
extends RefCounted
## 两个居民面对面时，走近能听见的那一两句。不是 autoload。
## 有共同的事就说那件事，没有就各说各的。一天一对只听见一次。


const VOICE: Dictionary[StringName, String] = {
	&"jiang": "碗还要多摆一副",
	&"xiaoman": "雾从西边来",
	&"bai": "章先盖着",
	&"ahe": "账还差一页",
	&"shishu": "锤子还热着",
	&"qingzhu": "图上还差一笔",
	&"yunniang": "菜名还没想好",
	&"laozhou": "船系好了",
	&"amu": "牲口都在",
	&"laoqin": "井口风大",
	&"luyuan": "手臂上还有字",
	&"egret": "纸上还有路",
	&"shuoshu": "这段还没说完",
	&"jiangyuan": "缸还盖着",
	&"huolang": "担子还没放下",
	&"chuanniang": "船还在棚里",
	&"miaozhu": "香还点着",
	&"shanliren": "山路还通",
}

const PAIRS: Dictionary = {
	"ahe|jiang": "姜婆婆问招牌原来的字。\n阿禾说，缺的那页也许写着。",
	"laozhou|yunniang": "老周说船系好了。\n云娘哼了半句，没唱完。",
	"laoqin|shishu": "老秦说井口的风大。\n石叔说，锤子还热着。",
	"bai|laoqin": "柏先生问梯子还在不在。\n老秦说，钥匙在他手里。",
	"ahe|qingzhu": "青竹说桥上还差一颗钉。\n阿禾说，木料她记下了。",
	"amu|xiaoman": "小满问大黄去哪了。\n阿牧说，哨音它还认得。",
	"egret|xiaoman": "白鹭说有条路还没画实。\n小满说，雾从西边来。",
	"bai|xiaoman": "柏先生让她别往井边去。\n小满说，大人把记得的事藏着。",
	"jiang|luyuan": "陆远看了看手臂上的字。\n姜婆婆说，药碾好了。",
	"ahe|yunniang": "云娘又给菜起了个名。\n阿禾说，这个名不进账。",
	"qingzhu|shishu": "石叔问钉子够不够。\n青竹说，图上画了。",
	"laozhou|qingzhu": "老周说码头的板松了。\n青竹说，她去看看。",
	"bai|egret": "白鹭说有的地方纸上有。\n柏先生没有接话。",
	"amu|laozhou": "阿牧说牲口今天都在。\n老周说，河里也有。",
	"jiang|yunniang": "姜婆婆说晚饭多一副碗。\n云娘说，菜名还没想好。",
	"ahe|xiaoman": "小满说货架后面还有一排。\n阿禾说，那排她找过。",
	"laoqin|luyuan": "陆远问井下的人怎么记。\n老秦说，名牌是平的。",
	"egret|laoqin": "白鹭问井口那排人。\n老秦说，脸看不清。",
	"jiangyuan|qingzhu": "青竹问酱还在不在。\n酱园掌柜说，缸盖着。",
	"jiangyuan|laozhou": "老周问渡口的板。\n酱园掌柜说，缸没动。",
	"amu|huolang": "货郎问今天有没有人买。\n阿牧说，牲口比人多。",
	"chuanniang|egret": "船娘说船还在棚里。\n白鹭说，她画过出海的船。",
	"miaozhu|shanliren": "庙祝说香还点着。\n山里人说，山路还通。",
	"bai|shuoshu": "说书人说这段还没说完。\n柏先生说，台上的事先放着。",
	"shuoshu|xiaoman": "小满问后来呢。\n说书人说，这段还没说完。",
	"shuoshu|yunniang": "云娘哼了半句。\n说书人说，歌也是一段故事。",
}

static var _day := -1
static var _heard: Dictionary = {}


static func reset() -> void:
	_day = -1
	_heard.clear()


static func line(a: StringName, b: StringName) -> String:
	var key := _key(a, b)
	if PAIRS.has(key):
		return String(PAIRS[key])
	return "%s说，%s。\n%s应了一声，%s。" % [
		Database.npc(a).name, String(VOICE[a]), Database.npc(b).name, String(VOICE[b]),
	]


## 今天这一对还没听见，就返回那一句并记下。听见过了返回空。
static func notice(a: StringName, b: StringName) -> String:
	if GameClock.day != _day:
		_day = GameClock.day
		_heard.clear()
	var key := _key(a, b)
	if _heard.has(key):
		return ""
	_heard[key] = true
	return line(a, b)


static func _key(a: StringName, b: StringName) -> String:
	if String(a) < String(b):
		return "%s|%s" % [String(a), String(b)]
	return "%s|%s" % [String(b), String(a)]
