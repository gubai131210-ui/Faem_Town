class_name Bestiary
extends RefCounted
## 山海录：听说过一句，见过有画，打过或问出来才写全（决策 126、127、128、129）。
## 竹海三只，后山五只，雾岛三只，再加上年、灶君、饕餮、腓腓、耳鼠。图用已经画好的序列帧，不新画。
## 结缘只收腓腓和耳鼠。一次带一只出门。
## 见过当康的当天，成熟的非巨型庄稼多收一个。玉兔的药在药铺柜子里，喝一剂。
## 乘黄只在竹海、白天跟着，脚下轻一点。文鳐逢三的夜里飞到农场池塘上，不加收成。

const IDS: Array[StringName] = [
	&"shanxiao", &"xingxing", &"chenghuang",
	&"kui", &"baize", &"bifang", &"yutu", &"dangkang",
	&"jingwei", &"jiaoren", &"wenyao",
	&"nian", &"zaojun", &"taotie", &"feifei", &"ershu",
]
## 能结缘、能带出门的两只。
const PETS: Array[StringName] = [&"feifei", &"ershu"]
## 耳鼠只在这三张山野里翻东西。
const WILD: Array[StringName] = [&"zhuhai", &"houshan", &"wudao"]
## 饕餮吃满这么多道没吃过的菜才走。
const FEAST := 4
## 没灯的时候要把年赶这么多次；灯越多，次数越少。
const NIAN_PUSHES := 4

const HEARD: Dictionary[StringName, String] = {
	&"shanxiao": "听说竹海里的山魈夜里学人说话，把人往岔路引。",
	&"xingxing": "听说狌狌在竹海西边等一碗酒。",
	&"chenghuang": "听说乘黄会在西边留下不像鹿的蹄印。",
	&"kui": "听说后山雷雨里有夔，一只脚，声音像雷。",
	&"baize": "听说白泽在后山顶上，知道每种东西的忌讳。",
	&"bifang": "听说旱天有毕方，一只脚的鸟，能把崖洞的灯点着。",
	&"yutu": "听说月圆的夜里，玉兔在后山捣药。",
	&"dangkang": "听说秋天有当康，它一来就是个好年成。",
	&"jingwei": "听说精卫衔着石子，在东滩和雾岛之间飞。帮她一回，潮退得久一些。",
	&"jiaoren": "听说雾岛潮洞里有鲛人。拿海螺能换她的一颗珠。",
	&"wenyao": "听说文鳐夜里才飞。见着它，是个好年成。",
	&"nian": "听说除夕夜里年会闯到镇东口。灯笼越亮，越好把它赶回去。",
	&"zaojun": "听说小寒那几天灶君在灶边。祭过他，这一年试菜更容易试对。",
	&"taotie": "听说竹海里有饕餮。它不吃打，要一桌没吃过的菜。",
	&"feifei": "听说雾天的竹海里有腓腓。白尾巴，养了能忘忧。",
	&"ershu": "听说后山有耳鼠。背上有翅膀，能在山野里翻出东西。",
}
const SEEN: Dictionary[StringName, String] = {
	&"shanxiao": "见过山魈。独脚，红眼睛，张嘴的声音和你一样。",
	&"xingxing": "见过狌狌。像猿，白耳朵，蹲在碗边。",
	&"chenghuang": "见过乘黄。像一只狐，背上有一只角。白天在竹海里跟着走，脚下轻一点。",
	&"kui": "见过夔。一只脚，雷雨里才站得住。",
	&"baize": "见过白泽。它把你听说过的那些，忌讳说了一遍。",
	&"bifang": "见过毕方。一只脚的鸟，身上像有火。",
	&"yutu": "见过玉兔。月下对着石臼捣药。",
	&"dangkang": "见过当康。叫声像在叫自己的名字。",
	&"jingwei": "见过精卫。黑身子，花头，红脚，嘴里衔着石子。",
	&"jiaoren": "见过鲛人。潮退了才在洞口，眼睛是湿的。",
	&"wenyao": "见过文鳐。夜里贴着海面飞，翅膀是白的。",
	&"nian": "见过年。蓝身子，一身黄毛，白角，粉尾巴。",
	&"zaojun": "见过灶君。红袍，黑帽，胡子很长。",
	&"taotie": "见过饕餮。绿身子，黄条纹，嘴张得很大。",
	&"feifei": "见过腓腓。像一只狸，白尾巴。",
	&"ershu": "见过耳鼠。粉红的，背上有翅膀。",
}
const KNOWN: Dictionary[StringName, String] = {
	&"shanxiao": "山魈散了。它学人说话，专把人往东边的死路引。打散以后，东边还是过不去，只是不再应你。",
	&"xingxing": "拿米酒把狌狌引出来了。它说：这座桥是有人一截一截接上的，接的人自己都忘了。",
	&"chenghuang": "见过乘黄。像一只狐，背上有一只角。白天在竹海里跟着走，脚下轻一点。",
	&"kui": "夔散了。它只在雷雨里出来，一只脚，声音就是雷。散了以后雨还在下，只是不再跟着你。",
	&"baize": "白泽在山顶。见过它以后，山海录里你听说过的那些，都补上了一句忌讳。",
	&"bifang": "毕方把崖洞里的灯点着了。旱天才来，一只脚，火在身上。",
	&"yutu": "月圆夜里见过玉兔捣药。药留在山下药铺的柜子里，喝过一剂就没了。",
	&"dangkang": "当康来过。叫声像在叫自己的名字。它在的那天是个好年成，成熟的庄稼多收一个。",
	&"jingwei": "帮精卫把石子投进海里了。退潮从早上拖到傍晚。",
	&"jiaoren": "拿一只海螺换了鲛人的珠。珠留在潮洞的石上，是热的。",
	&"wenyao": "夜里见过文鳐飞起来。逢三的夜里它贴着农场的池塘飞。见着它的这天，是个好年成。",
	&"nian": "除夕夜里把年从镇东口赶回去了。灯笼越亮，它退得越快。",
	&"zaojun": "小寒祭过灶君。这一年里，差一样的菜也能试对。",
	&"taotie": "摆了四道它没吃过的菜。它吃完，自己走了。",
	&"feifei": "腓腓跟回了家。摸一摸，当天晕倒丢的少一半。",
	&"ershu": "耳鼠跟回了家。带到山野里，它会翻出藏着的东西。",
}
## 见过白泽以后，补在已经听说过的那一条后面。
const TABOO: Dictionary[StringName, String] = {
	&"shanxiao": "忌夜里应它。",
	&"xingxing": "忌空手去，它要酒。",
	&"chenghuang": "忌追出竹海。它只在竹海里、白天跟着。",
	&"kui": "忌晴天去找，只在雷雨里。",
	&"bifang": "忌雨天，旱天才来。",
	&"yutu": "忌不是月圆的夜里去。",
	&"dangkang": "忌把它留住。它来了就是个好年成。",
	&"jingwei": "忌午后才去，不帮她潮退得短。",
	&"jiaoren": "忌涨潮进洞，她要海螺。",
	&"wenyao": "忌白天找。逢三的夜里才到池塘上。",
	&"nian": "忌没有灯的夜里硬赶。",
	&"zaojun": "忌不在小寒去，他不在灶边。",
	&"taotie": "忌拿武器去，它要吃的。",
	&"feifei": "忌晴天去找，雾里才在。",
	&"ershu": "忌空手去，它要一道菜。",
}
## 素材名，以及是不是动物表（乘黄在 creatures，另外两只在 characters）。
const SHEET: Dictionary[StringName, Array] = {
	&"shanxiao": ["shanxiao", false],
	&"xingxing": ["xingxing", false],
	&"chenghuang": ["chenghuang", true],
	&"kui": ["kui", true],
	&"baize": ["baize", true],
	&"bifang": ["bifang", true],
	&"yutu": ["yutu", true],
	&"dangkang": ["dangkang", true],
	&"jingwei": ["jingwei", true],
	&"jiaoren": ["jiaoren", false],
	&"wenyao": ["wenyao", true],
	&"nian": ["nian", true],
	&"zaojun": ["zaojun", false],
	&"taotie": ["taotie", true],
	&"feifei": ["feifei", true],
	&"ershu": ["ershu", true],
}

static var _portraits: Dictionary[StringName, Texture2D] = {}


static func hear(id: StringName) -> void:
	GameState.set_flag(_flag(id, "heard"))


static func see(id: StringName) -> void:
	hear(id)
	GameState.set_flag(_flag(id, "seen"))


static func know(id: StringName) -> void:
	see(id)
	GameState.set_flag(_flag(id, "known"))


static func heard(id: StringName) -> bool:
	return GameState.has_flag(_flag(id, "heard")) or seen(id)


static func seen(id: StringName) -> bool:
	return GameState.has_flag(_flag(id, "seen"))


static func known(id: StringName) -> bool:
	return GameState.has_flag(_flag(id, "known"))


static func listed() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in IDS:
		if heard(id):
			out.append(id)
	return out


static func line(id: StringName) -> String:
	var text := ""
	if known(id):
		text = KNOWN[id]
	elif seen(id):
		text = SEEN[id]
	elif heard(id):
		text = HEARD[id]
	if text != "" and id != &"baize" and seen(&"baize") and TABOO.has(id):
		text += TABOO[id]
	return text


static func page_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for id: StringName in listed():
		lines.append(line(id))
	return lines


## 见过才有画。取站立的第一帧。
static func portrait(id: StringName) -> Texture2D:
	if not seen(id):
		return null
	if _portraits.has(id):
		return _portraits[id]
	var spec: Array = SHEET[id]
	var folder := CharacterSheet.CREATURE_DIR if bool(spec[1]) else CharacterSheet.DIR
	var sheet := CharacterSheet.load_sheet(str(spec[0]), folder)
	if not sheet.is_valid():
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet.texture
	var anim := &"flap" if id == &"jingwei" or id == &"wenyao" else &"idle"
	var side := id == &"chenghuang" or id == &"jingwei" or id == &"wenyao"
	side = side or id == &"nian" or id == &"taotie" or id == &"feifei" or id == &"ershu"
	var face := 2 if side else 0
	atlas.region = sheet.region(anim, face, 0)
	_portraits[id] = atlas
	return atlas


static func is_dish(item: ItemDef) -> bool:
	return item != null and item.id != &"odd_bowl" and Database.recipes.has(item.id)


static func bonded(id: StringName) -> bool:
	return GameState.has_flag(_pet_flag(&"bond", id))


static func bond(id: StringName) -> void:
	know(id)
	GameState.set_flag(_pet_flag(&"bond", id))


static func out_id() -> StringName:
	if GameState.has_flag(_pet_flag(&"out", &"feifei")):
		return &"feifei"
	if GameState.has_flag(_pet_flag(&"out", &"ershu")):
		return &"ershu"
	return &""


## 在家摸一下。腓腓当天晕倒少丢一半，并试着跟着走。另一只已经在外面，就带不走。
static func touch(id: StringName) -> String:
	if id == &"feifei":
		soothe()
	var cur := out_id()
	if cur == id:
		GameState.clear_flag(_pet_flag(&"out", id))
		if id == &"feifei":
			return "摸了摸它。今天要是晕倒，丢的少一半。它回家了。"
		return "它回家了。"
	if cur != &"":
		if id == &"feifei":
			return "摸了摸它。今天要是晕倒，丢的少一半。一次只能带一只。"
		return "一次只能带一只。"
	GameState.set_flag(_pet_flag(&"out", id))
	if id == &"feifei":
		return "摸了摸它。今天要是晕倒，丢的少一半。它跟着你了。"
	return "它跟着你了。"


static func soothe() -> void:
	GameState.set_flag(StringName("beast_soothe_d%d" % GameClock.day))


static func soothed() -> bool:
	return GameState.has_flag(StringName("beast_soothe_d%d" % GameClock.day))


## 带在身边时按一下。耳鼠在山野里翻东西，不回家；别的时候送回家。
static func greet_out(map_id: StringName) -> String:
	var id := out_id()
	if id == &"":
		return ""
	if id == &"ershu" and WILD.has(map_id):
		return dig()
	return touch(id)


static func dig() -> String:
	var flag := StringName("beast_dug_d%d" % GameClock.day)
	if GameState.has_flag(flag):
		return "今天已经翻过了。"
	var item := find_item()
	if item == &"" or not Database.has_item(item):
		return "它找了找，什么也没翻到。"
	if not GameState.inventory.can_add(item, 1):
		return "它翻出一样东西，背包满了。"
	GameState.set_flag(flag)
	GameState.inventory.add(item, 1)
	return "耳鼠从草里翻出%s。" % Database.item(item).name


static func find_item() -> StringName:
	var now := GameClock.season_id()
	for def in Database.forage:
		var spec: ForageDef = def
		if spec.beach or spec.shore:
			continue
		if spec.in_season(now) and spec.available(GameClock.term_index()):
			return spec.item
	return &""


static func beside(map: GameMap, tile: Vector2i) -> bool:
	if out_id() == &"" or map == null or map.player == null:
		return false
	var outdoor := map as OutdoorMap
	if outdoor == null:
		return false
	return tile == beside_tile(outdoor)


static func beside_tile(map: OutdoorMap) -> Vector2i:
	var origin := map.tile_of(map.player.position)
	var steps: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for step in steps:
		var t: Vector2i = origin + step
		if map.in_map(t) and not map.blocked(map.tile_center(t)):
			return t
	return origin


static func zaojun_helps() -> bool:
	return GameState.has_flag(StringName("beast_zaojun_y%d" % GameClock.year()))


static func appease_zaojun() -> String:
	var renew := zaojun_helps()
	know(&"zaojun")
	GameState.set_flag(StringName("beast_zaojun_y%d" % GameClock.year()))
	if renew:
		return "今年已经祭过了。"
	return "灶君收了这道菜。这一年里，差一样的菜也能试对。"


static func fed(dish: StringName) -> bool:
	return GameState.has_flag(StringName("beast_fed_%s" % dish))


static func fed_count() -> int:
	var n := 0
	for id: StringName in Database.recipes:
		if fed(id):
			n += 1
	return n


static func feed(dish: StringName) -> String:
	if fed(dish):
		return "这道它吃过了。"
	GameState.set_flag(StringName("beast_fed_%s" % dish))
	see(&"taotie")
	var left := FEAST - fed_count()
	if left <= 0:
		know(&"taotie")
		return "一桌没吃过的菜摆齐了。它吃完，自己走了。"
	var name := Database.item(dish).name
	return "它吞了%s。还差%d道没吃过的。" % [name, left]


static func nian_need() -> int:
	return maxi(1, NIAN_PUSHES - Festivals.scale())


static func nian_pushes() -> int:
	var n := 0
	for i in NIAN_PUSHES:
		if GameState.has_flag(StringName("beast_nian_%d" % (i + 1))):
			n += 1
	return n


static func push_nian() -> String:
	see(&"nian")
	var need := nian_need()
	var have := nian_pushes()
	if have < need:
		have += 1
		GameState.set_flag(StringName("beast_nian_%d" % have))
	if have >= need:
		know(&"nian")
		if Festivals.scale() >= 3:
			return "满街的灯笼和响，它掉头跑了。"
		return "灯笼亮着，它到底还是跑了。"
	return "它怕亮。灯还不够，再赶一赶。"


static func _pet_flag(kind: StringName, id: StringName) -> StringName:
	return StringName("beast_%s_%s" % [kind, id])


static func _flag(id: StringName, kind: String) -> StringName:
	return StringName("beast_%s_%s" % [kind, id])
