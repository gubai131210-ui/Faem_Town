extends RefCounted
## 过场的内容。播放器只负责演，这里不改游戏状态。
## 看过没有由播放器在演完或跳过时记一个标记。

const OPENING := &"opening"

static func seen_flag(id: StringName) -> StringName:
	return StringName("cutscene_" + String(id))

## 点灯的演出：先把镜头抬向灯，雾往外退的时候看一眼，再落回玩家。不盖画。
static func lamp_id(lamp: StringName) -> StringName:
	return StringName("lamp_" + String(lamp))

static func lamp_steps(text: String) -> Array[Dictionary]:
	return [
		{"id": &"rise", "picture": &"", "text": text, "sec": 1.0, "look": &"lamp"},
		{"id": &"back", "picture": &"", "text": "", "sec": 0.5, "look": &"player"},
	]

## 重要的对话开头演一下再开口。对不上的返回空，调用的地方就直接说话。
static func story_beat(path: String, title: String) -> Dictionary:
	match path.get_file().get_basename() + "/" + title:
		"jiang/the_photo":
			return {"id": &"photo", "text": "姜婆婆接过相片。看了很久，才抬起头。"}
		"lan/meet":
			return {"id": &"deer", "text": "雾里站着一头白鹿。它没有跑。"}
		"bai/the_prayer":
			return {"id": &"confess", "text": "柏先生看着山的方向，把声音放低了。"}
		"laoqin/well_key":
			return {"id": &"key", "text": "老秦从怀里摸出一把旧钥匙。"}
	return {}

## 五级忆先演再开口。十一位有忆的居民各一段旧照片。岚和小满没有。
static func memory_scene(path: String, title: String) -> Dictionary:
	if title != "memory_5":
		return {}
	var who := path.get_file().get_basename()
	if who == "jiang":
		return {"id": &"memory_jiang", "steps": _jiang_memory_steps()}
	if not _MEMORY_LINE.has(who):
		return {}
	return {"id": StringName("memory_" + who), "steps": _memory_steps(who)}

static var _MEMORY_LINE := {
	"ahe": ["招牌挂在铺子门口。", "上面写的是「禾记」。母亲叫禾娘。"],
	"egret": ["她在纸上画一条路。", "画完的那些路，镇上还没走通。"],
	"qingzhu": ["她走上南溪那座桥。", "最后一颗钉归位，桥可以走人了。"],
	"shishu": ["他站回砧子前。", "锤柄上的顺序，他想起来了。"],
	"amu": ["牧场篱笆边上，一条狗跑过来。", "牌子上是「大黄」。"],
	"laozhou": ["码头上立着一根竿。", "竿上刻着「阿海」。那是他儿子。"],
	"yunniang": ["灶上还坐着一口锅。", "她把那首歌唱完了。"],
	"bai": ["桌上摊着那张许可。", "章盖全了。溪东可以开垦。"],
	"luyuan": ["墙上钉着一份名单。", "父亲的名字在那上面。"],
	"laoqin": ["他顺着梯子往上。", "是岚把他推上去的。"],
}

static func _walker(who: String, x1: float) -> Dictionary:
	return {"who": who, "row": 4, "facing": 2, "frames": 8, "fps": 8.0, "x0": 4.0, "x1": x1, "y0": 168.0, "y1": 168.0, "scale": 4}

static func _stander(who: String, x: float, facing: int = 2) -> Dictionary:
	return {"who": who, "row": 0, "facing": facing, "frames": 4, "fps": 3.0, "x0": x, "x1": x, "y0": 168.0, "y1": 168.0, "scale": 4}

static func _memory_steps(who: String) -> Array[Dictionary]:
	var line: Array = _MEMORY_LINE[who]
	if who == "laoqin":
		var climb := {"who": "laoqin", "row": 4, "facing": 2, "frames": 8, "fps": 8.0, "x0": 128.0, "x1": 128.0, "y0": 152.0, "y1": 52.0}
		var top := {"who": "laoqin", "row": 0, "facing": 2, "frames": 4, "fps": 3.0, "x0": 128.0, "x1": 128.0, "y0": 52.0, "y1": 52.0}
		return [
			_beat(&"climb", &"end_shaft", line[0], 2.2, [climb]),
			_beat(&"top", &"end_shaft", line[1], 1.6, [top]),
		]
	var spots: Dictionary = {"qingzhu": 48.0, "shishu": 36.0, "amu": 8.0, "egret": 48.0, "laozhou": 96.0, "jiang": 56.0}
	var spot := float(spots.get(who, 56.0))
	var look: Array = [_stander(who, spot, 0 if who == "yunniang" else 2)]
	if who == "amu":
		look.append({"who": "dog", "folder": "creatures", "cell": 32, "foot": 26, "scale": 4, "row": 4, "facing": 2, "frames": 4, "fps": 6.0, "x0": 210.0, "x1": 118.0, "y0": 168.0, "y1": 168.0})
	return [
		_beat(&"walk", StringName("mem_" + who), line[0], 2.2, [_walker(who, spot)]),
		_beat(&"look", StringName("mem_" + who), line[1], 1.8, look),
	]

static func _beat(id: StringName, picture: StringName, text: String, sec: float, cast: Array) -> Dictionary:
	return {"id": id, "picture": picture, "text": text, "sec": sec, "walk": [], "cast": cast, "tint": "sepia"}

## 旧照片：她走到桌前，看着那封写给阿芸的信。
static func _jiang_memory_steps() -> Array[Dictionary]:
	var walk := {"who": "jiang", "row": 4, "facing": 2, "frames": 8, "fps": 8.0, "scale": 4, "x0": 4.0, "x1": 80.0, "y0": 168.0, "y1": 168.0}
	var look := {"who": "jiang", "row": 0, "facing": 2, "frames": 4, "fps": 3.0, "scale": 4, "x0": 80.0, "x1": 80.0, "y0": 168.0, "y1": 168.0}
	return [
		{"id": &"walk", "picture": &"memory_jiang", "text": "她把地址写成这间屋。", "sec": 2.4, "walk": [], "cast": [walk], "tint": "sepia"},
		{"id": &"letter", "picture": &"memory_jiang", "text": "收信的人是阿芸。她的女儿。", "sec": 2.0, "walk": [], "cast": [look], "tint": "sepia"},
	]

## 头一回顺着梯子下去。
static func descent_steps() -> Array[Dictionary]:
	return [{"id": &"down", "picture": &"", "text": "梯子没入黑暗。你顺着它下去了。", "sec": 0.6, "look": &"lamp"}]

## 四个首领头一回出现。对不上的返回空。
static func boss_beat(arena: StringName) -> Dictionary:
	match arena:
		&"cart":
			return {"id": &"boss_cart", "text": "一辆废矿车堵在路中间。"}
		&"catfish":
			return {"id": &"boss_catfish", "text": "水池里有个很大的影子。"}
		&"troupe":
			return {"id": &"boss_troupe", "text": "空地当中站着一个戴面具的人影。"}
		&"shade":
			return {"id": &"boss_shade", "text": "一个提灯的影子飘在前头。"}
	return {}

static func beat_steps(text: String) -> Array[Dictionary]:
	return [{"id": &"show", "picture": &"", "text": text, "sec": 0.6, "look": &"lamp"}]

## 进到节日场上时演一句，镜头朝场子中间。不盖画，人还在。
static func festival_line(id: StringName) -> String:
	match id:
		&"sowing":
			return "播种节。广场上摆开了摊子。"
		&"lantern":
			return "放河灯。人往码头上走。"
		&"firefly":
			return "萤火夜。草地里有光在飞。"
		&"harvest":
			return "丰收集。长桌摆在广场上。"
		&"dumpling":
			return "饺子宴。锅支在广场中间。"
		&"newyear":
			return "除夕。灯笼点起来了。"
	return ""

static func festival_steps(text: String) -> Array[Dictionary]:
	return [{"id": &"open", "picture": &"", "text": text, "sec": 1.6, "look": &"lamp"}]

## 守岁醒来：屋里亮了，底下一句。
static func dawn_steps() -> Array[Dictionary]:
	return [{"id": &"dawn", "picture": &"", "text": "天亮了。过年了。", "sec": 1.4, "look": &"player"}]

## 八席摆上长桌，请来的人站在各自那道菜后面。重看不撤菜，撤菜在游戏里请人的那一下。
static func feast_steps() -> Array:
	var people: Array[String] = ["farmer", "xiaoman", "ahe", "yunniang", "jiang", "shishu", "laozhou", "amu"]
	var dishes: Array[StringName] = [
		&"stir_greens", &"tomato_egg", &"oil_shrimp", &"steamed_crab",
		&"radish_soup", &"fish_soup", &"egg_fried_rice", &"osmanthus_cake",
	]
	# 盘子画在这些横坐标上，人和菜都对准自己那一只。
	var plate_x: Array[float] = [36, 72, 108, 144, 180, 216, 252, 288]
	var guests: Array = []
	var plates: Array = []
	for i in people.size():
		var px := plate_x[i]
		guests.append({
			"who": people[i], "row": 0, "facing": 0, "frames": 4, "fps": 3.0, "scale": 2,
			"x0": px - 48.0, "x1": px - 48.0, "y0": 104.0, "y1": 104.0,
		})
		plates.append({
			"who": dishes[i], "folder": "food", "cell": 32, "foot": 28, "scale": 1,
			"row": 0, "facing": 0, "frames": 4, "fps": 4.0,
			"x0": px - 16.0, "x1": px - 16.0, "y0": 148.0, "y1": 148.0,
		})
	var seated: Array = []
	seated.append_array(guests)
	seated.append_array(plates)
	return [
		{"id": &"feast_set", "picture": &"feast_hall", "text": "你把这一年的菜摆上了长桌。", "sec": 2.8, "cast": plates},
		{"id": &"feast_sit", "picture": &"feast_hall", "text": "请来的人坐下了。这一桌是镇上的。", "sec": 3.2, "cast": seated},
	]

## 请一到三位来农舍的长桌。菜是桌上实际摆的，人用各自的走路帧。
static func guest_steps(people: Array, dishes: Array, line: String) -> Array:
	var plate_x: Array[float] = [36, 72, 108, 144, 180, 216, 252, 288]
	var cast: Array = []
	var n := mini(dishes.size(), plate_x.size())
	var start := maxi(0, (plate_x.size() - n) / 2)
	for i in n:
		var px: float = plate_x[start + i]
		cast.append({
			"who": dishes[i], "folder": "food", "cell": 32, "foot": 28, "scale": 1,
			"row": 0, "facing": 0, "frames": 4, "fps": 4.0,
			"x0": px - 16.0, "x1": px - 16.0, "y0": 148.0, "y1": 148.0,
		})
	var seats := mini(people.size(), 3)
	for i in seats:
		var px: float = plate_x[start + i]
		cast.append({
			"who": people[i], "row": 0, "facing": 0, "frames": 4, "fps": 3.0, "scale": 2,
			"x0": px - 48.0, "x1": px - 48.0, "y0": 104.0, "y1": 104.0,
		})
	return [
		{"id": &"meal_sit", "picture": &"feast_hall", "text": line, "sec": 3.2, "cast": cast},
	]

## 看过的过场，按开场、忆、对话、灯、节日、结局排。手账只列这些，重看不改状态。
static func seen_entries() -> Array:
	var order: Array[StringName] = [&"opening"]
	for who in ["jiang", "ahe", "egret", "qingzhu", "shishu", "amu", "laozhou", "yunniang", "bai", "luyuan", "laoqin"]:
		order.append(StringName("memory_" + who))
	for id in ["photo", "deer", "confess", "key", "descent", "boss_cart", "boss_catfish", "boss_troupe", "boss_shade"]:
		order.append(StringName(id))
	for lamp in ["plaza", "river", "pasture", "well", "east", "shrine"]:
		order.append(StringName("lamp_" + lamp))
	for fest in ["sowing", "lantern", "firefly", "harvest", "dumpling", "newyear"]:
		for year in 5:
			order.append(StringName("fest_%s_y%d" % [fest, year + 1]))
	for year in 5:
		order.append(StringName("vigil_y%d" % (year + 1)))
	order.append(&"feast_banquet")
	for ending in ["keep", "clear", "name", "feast", "named", "estate"]:
		order.append(StringName("ending_" + ending))
	var listed: Dictionary = {}
	var out: Array = []
	for id in order:
		if not GameState.has_flag(seen_flag(id)):
			continue
		var title := _title_of(id)
		if title == "":
			continue
		out.append({"id": id, "title": title})
		listed[id] = true
	var extra: Array[String] = []
	for flag: StringName in GameState.flags:
		var name := String(flag)
		if not name.begins_with("cutscene_") or not bool(GameState.flags[flag]):
			continue
		var id := name.substr(9)
		if listed.has(StringName(id)) or _title_of(StringName(id)) == "":
			continue
		extra.append(id)
	extra.sort()
	for id in extra:
		out.append({"id": StringName(id), "title": _title_of(StringName(id))})
	return out

## 按看过的 id 把原来的步骤再排一遍。排不出来就空，调用的地方不演。
static func replay_steps(id: StringName) -> Array:
	var name := String(id)
	if name == "opening":
		return opening_steps()
	if name == "memory_jiang":
		return _jiang_memory_steps()
	if name.begins_with("memory_") and _MEMORY_LINE.has(name.substr(7)):
		return _memory_steps(name.substr(7))
	if name == "descent":
		return descent_steps()
	if name.begins_with("boss_"):
		var boss := boss_beat(StringName(name.substr(5)))
		return beat_steps(boss["text"]) if not boss.is_empty() else []
	if name.begins_with("lamp_"):
		var lamp_id := StringName(name.substr(5))
		if not Database.lamps.has(lamp_id):
			return []
		return lamp_steps(Database.lamp(lamp_id).lit_text)
	var fest := _fest_id(name)
	if fest != &"":
		var line := festival_line(fest)
		return festival_steps(line) if line != "" else []
	if name.begins_with("vigil_y") and name.substr(7).is_valid_int():
		return dawn_steps()
	if name == "feast_banquet":
		return feast_steps()
	if name.begins_with("ending_"):
		var ending := StringName(name.substr(7))
		if Story.TITLES.has(ending):
			return ending_steps(ending)
		return []
	var talk := _talk_beat(name)
	return beat_steps(talk["text"]) if not talk.is_empty() else []

static func _talk_beat(id: String) -> Dictionary:
	match id:
		"photo":
			return story_beat("res://dialogue/jiang.dialogue", "the_photo")
		"deer":
			return story_beat("res://dialogue/lan.dialogue", "meet")
		"confess":
			return story_beat("res://dialogue/bai.dialogue", "the_prayer")
		"key":
			return story_beat("res://dialogue/laoqin.dialogue", "well_key")
	return {}

static func _fest_id(name: String) -> StringName:
	if not name.begins_with("fest_"):
		return &""
	var body := name.substr(5)
	var at := body.rfind("_y")
	if at <= 0 or not body.substr(at + 2).is_valid_int():
		return &""
	return StringName(body.substr(0, at))

static func _title_of(id: StringName) -> String:
	var name := String(id)
	if name == "opening":
		return "开场"
	if name.begins_with("memory_"):
		var who := StringName(name.substr(7))
		if (who == &"jiang" or _MEMORY_LINE.has(String(who))) and Database.has_npc(who):
			return Database.npc(who).name + "想起的事"
		return ""
	var talk := _talk_beat(name)
	if not talk.is_empty():
		return talk["text"]
	if name == "descent":
		return "头一回下井"
	if name.begins_with("boss_"):
		var boss := boss_beat(StringName(name.substr(5)))
		return boss["text"] if not boss.is_empty() else ""
	if name.begins_with("lamp_"):
		var lamp_id := StringName(name.substr(5))
		if not Database.lamps.has(lamp_id):
			return ""
		return Database.lamp(lamp_id).name + "亮了"
	var fest := _fest_id(name)
	if fest != &"":
		var line := festival_line(fest)
		if line == "":
			return ""
		var year := name.substr(name.rfind("_y") + 2)
		return "%s（第%s年）" % [line.split("。")[0], year]
	if name.begins_with("vigil_y") and name.substr(7).is_valid_int():
		return "守岁天亮（第%s年）" % name.substr(7)
	if name == "feast_banquet":
		return "请大家吃饭"
	if name.begins_with("ending_"):
		var ending := StringName(name.substr(7))
		if Story.TITLES.has(ending):
			return "结局：" + Story.TITLES[ending]
	return ""

## 镜头相对玩家挪多少：朝灯那边，最远 72 像素，再往上抬 16 像素。
static func look_offset(from: Vector2, at: Vector2) -> Vector2:
	return (at - from).limit_length(72.0) + Vector2(0, -16)

## 留雾、散雾、归名各演四张，再接名单。团圆饭、山海有名、家业、远行短一些，最后也是名单。
static func ending_steps(ending: StringName) -> Array[Dictionary]:
	var beats: Array[Dictionary] = []
	if ending == &"feast":
		beats = [
			_live(&"table", &"feast_hall", "除夕。长桌摆开了。", 2.4, _feast_cast()),
			_shot(&"seats", &"end_seats", "二十八副碗筷。多出来的位子空着。"),
			_shot(&"roster", &"end_roster", "二十七行被水冲过了。最底下一行还是秦。"),
		]
	elif ending == &"named":
		beats = [
			_shot(&"names", &"end_names", "白泽把山里每一样东西的名字念了一遍。"),
			_shot(&"deer", &"end_tree", "念到最后一个，是一头白鹿。"),
		]
	elif ending == &"estate":
		beats = [
			_shot(&"plaque", &"end_plaque", "屋檐下挂上了匾。两个字：家业。"),
			_shot(&"mail", &"end_mail", "城里来信问：听说那儿有个镇子，还能去吗。"),
		]
	elif ending == &"voyage":
		beats = [
			_shot(&"dock", &"end_dock", "东滩。灯塔亮着。船往外开。"),
			_shot(&"stub", &"end_stub", "另外半张在她那儿。这半张留在码头上。"),
			_shot(&"out", &"end_dock", "她说：这回我跟你走。"),
		]
	elif ending == &"clear":
		beats = [
			_shot(&"flame", &"end_flame", "你划着了火。火苗很小，黄的。"),
			_shot(&"inward", &"end_inward", "雾从四面八方往灯里走。"),
			_live(&"funeral", &"end_funeral", "三天后，镇上办了一场迟到的葬礼。", 2.4, _funeral_cast()),
			_shot(&"empty", &"end_empty", "山里起雾的日子，祠前不再站着谁。"),
		]
	elif ending == &"name":
		beats = [
			_live(&"down", &"end_shaft", "梯子那边，一盏接着一盏往下来。", 2.4, _shaft_cast()),
			_shot(&"hands", &"end_hands", "十几只手拢着那一点火苗。"),
			_shot(&"step", &"end_step", "它从灯光里走出来。蹄子落在石头上。"),
			_shot(&"tree", &"end_tree", "桂花树底下常有一头白鹿。它不躲人。"),
		]
	else:
		beats = [
			_shot(&"unlit", &"end_unlit", "你没有点。灯还黑着。"),
			_shot(&"climb", &"end_climb", "你顺着梯子上去。井口的天已经黑了。"),
			_shot(&"hill", &"end_hill", "镇上的灯亮着。雾停在山腰上。"),
			_shot(&"bowl", &"end_bowl", "姜婆婆多摆了一副碗筷。她没有认出你。"),
		]
	beats.append(_shot(&"credits", &"credits", "《雾隐青岚》"))
	return beats

static func _shot(id: StringName, picture: StringName, text: String) -> Dictionary:
	return {"id": id, "picture": picture, "text": text, "sec": 2.6, "walk": [], "cast": [], "anim": true}

## 这一段用已经画好的序列帧在背景上走动。
static func _live(id: StringName, picture: StringName, text: String, sec: float, cast: Array) -> Dictionary:
	return {"id": id, "picture": picture, "text": text, "sec": sec, "walk": [], "cast": cast}

## 除夕长桌前站着的人。位子空着的那些不画人。
static func _feast_cast() -> Array:
	var cast: Array = []
	var who: Array[String] = ["farmer", "jiang", "laoqin", "ahe", "yunniang"]
	var xs: Array[float] = [36.0, 108.0, 180.0, 252.0, 288.0]
	for i in who.size():
		cast.append({
			"who": who[i], "row": 0, "facing": 0, "frames": 4, "fps": 3.0, "scale": 2,
			"x0": xs[i] - 48.0, "x1": xs[i] - 48.0, "y0": 104.0, "y1": 104.0,
		})
	return cast


static func _funeral_cast() -> Array:
	var cast: Array = [
		{"who": "farmer", "row": 4, "facing": 2, "frames": 8, "fps": 8.0, "x0": 4.0, "x1": 90.0, "y0": 128.0, "y1": 128.0},
	]
	for i in 5:
		var who: String = ["bai", "jiang", "laoqin", "yunniang", "ahe"][i]
		var x := 168.0 + float(i) * 30.0
		cast.append({"who": who, "row": 0, "facing": 3, "frames": 4, "fps": 3.0, "x0": x, "x1": x, "y0": 128.0, "y1": 128.0})
	return cast

## 主角面朝右，顺着梯子从井口走到井下。
static func _shaft_cast() -> Array:
	return [
		{"who": "farmer", "row": 4, "facing": 2, "frames": 8, "fps": 8.0, "x0": 128.0, "x1": 128.0, "y0": 48.0, "y1": 152.0},
	]

static var _sheets: Dictionary = {}
static var _backs: Dictionary = {}

## 把这一刻的人贴到背景上。脚底在 y，格子高 48，脚在第 40 行。aged 时整张褪成旧照片。
static func compose(picture_id: StringName, cast: Array, t: float, sec: float, aged: bool = false) -> Image:
	var img: Image = _background(picture_id, aged)
	var u := clampf(t / maxf(sec, 0.01), 0.0, 1.0)
	for actor in cast:
		var folder := str(actor.get("folder", "characters"))
		var sheet: Image = _sheet_of(str(actor["who"]), folder, aged)
		if sheet == null:
			continue
		var cell := int(actor.get("cell", 48))
		var foot := int(actor.get("foot", 40))
		var scale := int(actor.get("scale", 1))
		var frames := int(actor["frames"])
		var x0 := float(actor["x0"])
		var x1 := float(actor["x1"])
		var y0 := float(actor["y0"])
		var y1 := float(actor["y1"])
		var travel := absf(x1 - x0) + absf(y1 - y0)
		var f: int
		if travel > 3.0:
			var stride := 4.0 * float(scale)
			var gone := absf(lerpf(x0, x1, u) - x0) + absf(lerpf(y0, y1, u) - y0)
			f = int(gone / stride) % frames
		else:
			f = int(t * float(actor["fps"])) % frames
		var row := int(actor["row"]) + int(actor["facing"])
		var x := int(lerpf(x0, x1, u))
		var y := int(lerpf(y0, y1, u)) - foot * scale
		var chip := Image.create(cell, cell, false, Image.FORMAT_RGBA8)
		chip.blit_rect(sheet, Rect2i(f * cell, row * cell, cell, cell), Vector2i.ZERO)
		if scale != 1:
			chip.resize(cell * scale, cell * scale, Image.INTERPOLATE_NEAREST)
		img.blend_rect(chip, Rect2i(0, 0, chip.get_width(), chip.get_height()), Vector2i(x, y))
	return img

static func _background(picture_id: StringName, aged: bool) -> Image:
	var key := String(picture_id) + ("_old" if aged else "")
	if not _backs.has(key):
		var img: Image = picture(picture_id).duplicate()
		img.convert(Image.FORMAT_RGBA8)
		if aged:
			_age(img)
		_backs[key] = img
	return (_backs[key] as Image).duplicate()

static func _sheet_of(who: String, folder: String, aged: bool) -> Image:
	var key := folder + "/" + who + ("_old" if aged else "")
	if not _sheets.has(key):
		var sheet := Image.load_from_file(ProjectSettings.globalize_path("res://art/%s/%s.png" % [folder, who]))
		if sheet == null:
			return null
		sheet.convert(Image.FORMAT_RGBA8)
		if aged:
			_age(sheet)
		_sheets[key] = sheet
	return _sheets[key]

## 压掉颜色，留一层暖褐，像旧照片。
static func _age(img: Image) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.04:
				continue
			var l := c.r * 0.30 + c.g * 0.59 + c.b * 0.11
			img.set_pixel(x, y, Color(minf(l * 1.08 + 0.05, 1.0), minf(l * 0.84 + 0.02, 1.0), minf(l * 0.52, 1.0), c.a))

## 开场四段：城里的桌子、信和钥匙、车窗外的雾、到了农舍。最后一段不盖画，露出已经在的农舍。
static func opening_steps() -> Array[Dictionary]:
	return [
		{"id": &"desk", "picture": &"desk", "text": "城里。桌子上摊着一封信。", "sec": 2.8, "anim": true},
		{"id": &"letter", "picture": &"letter", "text": "信上说，乡里的老屋还在。钥匙夹在里面。", "sec": 2.8, "anim": true},
		{"id": &"window", "picture": &"window", "text": "车窗外全是雾。路一点点沉下去。", "sec": 2.8, "anim": true},
		{"id": &"door", "picture": &"", "text": "雾散开的地方，是农舍的门。", "sec": 2.2},
	]

## 这一段播到 t 秒时的整张画。人用走路帧，迈一步换一帧，不在原地滑。
static func picture_at(id: StringName, t: float, sec: float) -> Image:
	var u := clampf(t / maxf(sec, 0.01), 0.0, 1.0)
	var img := CutsceneArt.at(id, u, t)
	_act(img, id, u)
	return img


static func _act(img: Image, id: StringName, u: float) -> void:
	if id == &"end_flame":
		_farmer_to_lamp(img, u, true)
	elif id == &"end_unlit":
		_farmer_to_lamp(img, u, false)
	elif id == &"end_climb":
		var foot := int(lerpf(102.0, 38.0, u))
		_blit_farmer(img, 68, foot, 4, 1, int((102 - foot) / 4) % 8, 8)
	elif id == &"end_empty":
		var gone := int(lerpf(70.0, 230.0, u))
		if gone < 200:
			_place_deer(img, gone, 98, int(gone * 0.4) % 8, false, true)
	elif id == &"end_step":
		var stepped := int(lerpf(140.0, 28.0, u))
		_place_deer(img, stepped, 96, int(absi(140 - stepped) * 0.4) % 8, true, true)
	elif id == &"end_tree":
		if u < 0.7:
			var walked := int(lerpf(16.0, 112.0, u / 0.7))
			_place_deer(img, walked, 96, int(walked * 0.4) % 8, false, true)
		else:
			_place_deer(img, 112, 96, 1)
	elif id == &"end_inward":
		var approached := int(lerpf(8.0, 68.0, u))
		_place_deer(img, approached, 100, int(approached * 0.4) % 8, false, true)
	elif id == &"end_hands" or id == &"credits":
		_line_of_people(img, u)
	elif id == &"end_seats":
		_blit_who(img, "farmer", 24, 96, 0, 0, 0, 4)
		_blit_who(img, "jiang", 78, 96, 0, 0, 0, 4)
		_blit_who(img, "laoqin", 132, 96, 0, 0, 1, 4)
	elif id == &"end_dock":
		var pace := int(lerpf(4.0, 64.0, u))
		_blit_who(img, "jiang", pace - 28, 100, 4, 2, int(pace / 4) % 8, 8)
		_blit_who(img, "farmer", pace, 100, 4, 2, int(pace / 4) % 8, 8)
	elif id == &"end_names":
		_blit_baize(img, 96, 98)


## 走到灯前，再伸手。lights 为真就把手停在火上；否则伸一下又放下，灯不着。
static func _farmer_to_lamp(img: Image, u: float, lights: bool) -> void:
	var foot := 84
	var stop := 78
	if u < 0.58:
		var x := int(lerpf(0.0, float(stop), u / 0.58))
		_blit_farmer(img, x, foot, 4, 2, int(x / 4) % 8, 8)
		return
	var p := (u - 0.58) / 0.42
	if lights or p < 0.55:
		var frame := mini(int(p / (1.0 if lights else 0.55) * 3.0), 2)
		_blit_farmer(img, stop, foot, 20, 2, frame, 3)
	else:
		_blit_farmer(img, stop, foot, 0, 2, 0, 4)


static func _blit_farmer(img: Image, left: int, foot_y: int, anim_row: int, facing: int, frame: int, frames: int) -> void:
	_blit_who(img, "farmer", left, foot_y, anim_row, facing, frame, frames)


## 白鹿就是山祠前那一只，锚点在 (22, 45)。朝左走时翻转。
## walking 为真时 frame 是走路八帧里的第几帧（四条腿轮流抬起迈出）；否则是站着的两帧。
static func _place_deer(img: Image, foot_x: int, foot_y: int, frame: int, face_left: bool = false, walking: bool = false) -> void:
	var deer := ShrineArt.deer_walk(frame) if walking else ShrineArt.deer(frame % 2)
	var ax := 22
	if face_left:
		deer = Px.flipped(deer)
		ax = deer.get_width() - 22
	img.blend_rect(deer, Rect2i(0, 0, deer.get_width(), deer.get_height()), Vector2i(foot_x - ax, foot_y - 45))


## 火边和片尾站一排真人：主角、小满、阿禾、姜婆婆。错开进场，站定后面向镜头。
static func _line_of_people(img: Image, u: float) -> void:
	var who: Array[String] = ["farmer", "xiaoman", "ahe", "jiang"]
	for i in who.size():
		var slot := 8 + i * 46
		var e := clampf((u - float(i) * 0.08) / 0.72, 0.0, 1.0)
		var x := int(lerpf(float(slot - 80), float(slot), e))
		var walking := e < 0.98
		var frame := int(absi(slot - x) / 4) % 8 if walking else int(u * 3.0) % 4
		_blit_who(img, who[i], x, 102, 4 if walking else 0, 2 if walking else 0, frame, 8 if walking else 4)


static var _baize_chip: Image


static func _blit_baize(img: Image, foot_x: int, foot_y: int) -> void:
	if _baize_chip == null:
		var sheet := Image.load_from_file(ProjectSettings.globalize_path("res://art/creatures/baize.png"))
		_baize_chip = Image.create(48, 48, false, Image.FORMAT_RGBA8)
		if sheet != null:
			_baize_chip.blit_rect(sheet, Rect2i(0, 96, 48, 48), Vector2i.ZERO)
	var big := _baize_chip.duplicate()
	big.resize(96, 96, Image.INTERPOLATE_NEAREST)
	img.blend_rect(big, Rect2i(0, 0, 96, 96), Vector2i(foot_x - 48, foot_y - 80))


static func _blit_who(img: Image, who: String, left: int, foot_y: int, anim_row: int, facing: int, frame: int, frames: int) -> void:
	var sheet := _sheet_of(who, "characters", false)
	if sheet == null:
		return
	var cell := 48
	var chip := Image.create(cell, cell, false, Image.FORMAT_RGBA8)
	var row := anim_row + facing
	chip.blit_rect(sheet, Rect2i((frame % frames) * cell, row * cell, cell, cell), Vector2i.ZERO)
	img.blend_rect(chip, Rect2i(0, 0, cell, cell), Vector2i(left, foot_y - 40))


static func picture(id: StringName) -> Image:
	if String(id).begins_with("mem_"):
		return _painted(String(id))
	var img := Image.create(CutsceneArt.W, CutsceneArt.H, false, Image.FORMAT_RGBA8)
	# 决策 120：开场与结局改走 CutsceneArt 的重绘画。画面尺寸和主体位置不变，
	# 字幕的 walk 落点、镜头焦点都还按原坐标。老的色块画函数已删除。
	match id:
		&"desk":
			CutsceneArt.desk(img)
		&"letter":
			CutsceneArt.letter(img)
		&"window":
			CutsceneArt.window_scene(img, true)
		&"end_flame":
			CutsceneArt.flame_scene(img)
		&"memory_jiang":
			return _painted("mem_jiang")
		&"end_funeral":
			return _painted("funeral")
		&"end_shaft":
			return _painted("shaft")
		&"feast_hall":
			return _painted("feast_hall")
		&"end_empty":
			CutsceneArt.empty_shrine(img)
		&"end_hands", &"end_step", &"end_tree", &"end_inward", &"credits", &"end_seats", &"end_names", &"end_roster", &"end_plaque", &"end_mail", &"end_dock", &"end_stub":
			return picture_at(id, 2.6, 2.6)
		&"end_unlit":
			CutsceneArt.unlit_lamp(img)
		&"end_climb":
			CutsceneArt.shaft(img)
		&"end_hill":
			CutsceneArt.hill(img)
		&"end_bowl":
			CutsceneArt.bowl(img)
		_:
			img.fill(Color(0, 0, 0, 0))
	return img

## 画里走动的人：草帽、蓝上衣。phase 换哪只脚在前。
static func stamp_person(img: Image, x: float, y: float, phase: int) -> void:
	var px := int(x)
	var py := int(y)
	img.fill_rect(Rect2i(px - 3, py - 10, 7, 3), Color("e2b84e"))
	img.fill_rect(Rect2i(px - 2, py - 7, 5, 4), Color("f0c8a0"))
	img.fill_rect(Rect2i(px - 3, py - 3, 7, 5), Color("3f6fbf"))
	var leg := 2 if phase % 2 == 0 else -2
	img.fill_rect(Rect2i(px - 2, py + 2, 2, 4), Color("4a3428"))
	img.fill_rect(Rect2i(px + 1 + leg / 2, py + 2, 2, 4), Color("4a3428"))

static func _painted(name: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://art/cutscene/%s.png" % name))
	if img == null:
		img = Image.create(320, 180, false, Image.FORMAT_RGBA8)
	return img

