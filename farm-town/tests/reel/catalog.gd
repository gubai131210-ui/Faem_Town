extends RefCounted
## 宣传片段的名单。测试只读这份名单，不启动游戏。


const ORDER: Array[String] = ["field", "town", "fish", "cook", "fest", "mine", "fox", "pond"]

## 短版（决策 142）：片头、八段、片尾。用 trailer 演。
const TRAILER: Array[String] = [
	"title", "field", "weather", "town", "fish", "cook", "fest", "mine", "fox", "pond", "end",
]

## 完整版（决策 143）：每个动作演全过程，几个盛大场景演全，幕间是文字卡。用 full 演。
const FULL: Array[String] = [
	"title",
	"card_call", "letter",
	"card_farm", "field", "ship", "weather",
	"card_work", "fish", "mine", "fight", "coop", "cook",
	"card_town", "town", "shop", "lamp",
	"card_fest", "sowing", "lanterns", "fireflies", "harvest", "dumpling", "newyear",
	"card_beast", "fox", "pond",
	"card_end", "memory", "end_feast", "end_named", "end_voyage", "end_name",
	"end",
]

const TITLES: Dictionary = {
	"field": "田里",
	"town": "镇上",
	"fish": "池塘",
	"cook": "灶上",
	"fest": "播种节",
	"mine": "下井",
	"fox": "竹海",
	"pond": "文鳐",
	"title": "片头",
	"weather": "天气",
	"end": "片尾",
	"letter": "开场的信",
	"ship": "出货和睡觉",
	"fight": "井下打斗",
	"coop": "养鸡",
	"shop": "杂货铺",
	"lamp": "点灯",
	"sowing": "播种节全程",
	"lanterns": "放河灯",
	"fireflies": "萤火夜",
	"harvest": "丰收集",
	"dumpling": "饺子宴",
	"newyear": "除夕灯会",
	"memory": "一段忆",
	"end_feast": "结局：团圆饭",
	"end_named": "结局：山海有名",
	"end_voyage": "结局：远行",
	"end_name": "结局：归名",
	"card_call": "卡：来信",
	"card_farm": "卡：种田",
	"card_work": "卡：谋生",
	"card_town": "卡：小镇",
	"card_fest": "卡：节日",
	"card_beast": "卡：异兽",
	"card_end": "卡：结局",
}

## 每段的字幕：[大字, 小字]。空串表示这一段不压字幕。
const CAPTIONS: Dictionary = {
	"title": ["雾隐青岚", "一座被“忘雾”慢慢吞掉的山谷小镇"],
	"card_call": ["你收到一封信", "雾锁山谷，镇上的人正一点点忘掉自己的东西"],
	"letter": ["一封信，把你带到山谷", "从这一天起，这里就是你的家"],
	"card_farm": ["从一小块地开始", "开垦、浇水、播种、收获、出货，睡一觉，明天接着干"],
	"field": ["春耕", "锄头开地，水壶浇水，撒下种子，一天天看它长大"],
	"ship": ["出货，然后睡觉", "把收成放进出货箱，睡一觉，早上钱就到账"],
	"weather": ["四时与风雨", "晴、雨、雾、雪，田和天都跟着变"],
	"card_work": ["靠山吃山，靠水吃水", "钓鱼、下井、养鸡、做菜，一样一样学"],
	"fish": ["垂钓", "溪里、河上、湖心、海边，各处有各处的鱼；雾天、夏天、冬至夜才露面的最稀罕"],
	"mine": ["下井", "镐子敲开石头，一层层往下找"],
	"fight": ["井下的忘形", "挥砍、翻滚，躲开它的扑撞"],
	"coop": ["养鸡", "盖鸡舍，买小鸡，喂食，抚摸，第二天收蛋"],
	"cook": ["一口小灶", "切、炒、调火，做出一桌当季的菜"],
	"card_town": ["把灯一盏一盏点亮", "认识镇上的人，供上东西，雾就退一点"],
	"town": ["小镇", "二十多位居民，各有各的日子和心事"],
	"shop": ["杂货铺", "和阿禾搭话，买种子，货单一条条往下翻"],
	"lamp": ["点灯", "供齐四样东西，灯一亮，雾退开一圈"],
	"card_fest": ["一年六个节日", "全镇的人都到场"],
	"fest": ["节日", "全镇的人都到场"],
	"sowing": ["播种节", "春分头一天，广场上摆起种子摊，比谁播得多"],
	"lanterns": ["放河灯", "清明夜里，人人往南溪放一盏灯"],
	"fireflies": ["萤火夜", "大暑夜里，在草地上捉萤火虫，再一起放掉"],
	"harvest": ["丰收集", "秋分那天，拿出最好的收成给大家评一评"],
	"dumpling": ["饺子宴", "冬至的晚上，大家一起包饺子、吃饺子"],
	"newyear": ["除夕灯会", "灯亮得越多，广场挂得越满；守岁到天亮"],
	"card_beast": ["山海里的异兽", "它们藏在雾里，你看见了，它们才肯出来"],
	"fox": ["乘黄", "像狐，背上有角，白天在竹海里跟着你走"],
	"pond": ["文鳐", "逢三的夜里，有鱼从池塘飞起来"],
	"card_end": ["七种结局", "把被忘掉的找回来，也可以选择不找"],
	"memory": ["一段忆", "把遗物还给居民，他们就想起一段往事"],
	"end_feast": ["团圆饭", "除夕，长桌摆开，给没来的人留着位子"],
	"end_named": ["山海有名", "白泽把山里的东西，一样一样叫出名字"],
	"end_voyage": ["远行", "灯塔亮着，船往海里开"],
	"end_name": ["归名", "一盏接一盏的灯，把井底照亮"],
	"end": ["把被忘掉的，一件件找回来", ""],
}

## 字幕压在画面上方的段（它们自己的画面或对话在下面）。
const TOP_CAPTIONS: Array[String] = [
	"letter", "memory", "end_feast", "end_named", "end_voyage", "end_name",
]

## 每段演完以后再停多少秒，字幕在这段时间里读得完。
const TAILS: Dictionary = {
	"title": 3.2,
	"weather": 0.4,
	"letter": 0.8,
	"ship": 1.2,
	"field": 1.6,
	"town": 1.8,
	"fish": 1.4,
	"cook": 1.0,
	"fest": 1.4,
	"mine": 1.0,
	"fight": 1.0,
	"coop": 1.4,
	"shop": 1.0,
	"lamp": 1.2,
	"sowing": 1.2,
	"lanterns": 1.4,
	"fireflies": 1.2,
	"harvest": 1.2,
	"dumpling": 1.2,
	"newyear": 1.4,
	"fox": 1.6,
	"pond": 1.6,
	"memory": 0.6,
	"end_feast": 0.4,
	"end_named": 0.4,
	"end_voyage": 0.4,
	"end_name": 0.4,
	"end": 3.4,
	"card_call": 2.6,
	"card_farm": 2.6,
	"card_work": 2.6,
	"card_town": 2.6,
	"card_fest": 2.4,
	"card_beast": 2.4,
	"card_end": 2.6,
}


static func ids() -> Array[String]:
	var copy: Array[String] = []
	copy.assign(ORDER)
	return copy


static func trailer_ids() -> Array[String]:
	var copy: Array[String] = []
	copy.assign(TRAILER)
	return copy


static func full_ids() -> Array[String]:
	var copy: Array[String] = []
	copy.assign(FULL)
	return copy


static func title(id: String) -> String:
	return str(TITLES.get(id, ""))


static func known(id: String) -> bool:
	return id == "all" or id == "trailer" or id == "full" or TITLES.has(id)


## 这一段是幕间的文字卡：黑底，只有字，不开新局。
static func is_card(id: String) -> bool:
	return id.begins_with("card_")


static func is_top(id: String) -> bool:
	return TOP_CAPTIONS.has(id)


## 这一段的大字，没有就是空串。
static func caption_title(id: String) -> String:
	var pair: Array = CAPTIONS.get(id, ["", ""])
	return str(pair[0])


static func caption_sub(id: String) -> String:
	var pair: Array = CAPTIONS.get(id, ["", ""])
	return str(pair[1])


static func tail(id: String) -> float:
	return float(TAILS.get(id, 0.0))


static func menu_text() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("宣传片段")
	lines.append("")
	var n := 1
	for id in ORDER:
		lines.append("%d  %s" % [n, title(id)])
		n += 1
	lines.append("")
	lines.append("9  按顺序演")
	lines.append("Q  退出")
	return "\n".join(lines)
