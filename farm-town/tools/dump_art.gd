extends SceneTree
## 把代码画的素材导出成预览图，不用打开游戏窗口：
##   godot --headless --path . -s tools/dump_art.gd
## 画图的类要等全局系统就绪后再加载（它们会查数据表），所以这里用 load 而不是直接写类名。
## 类的缓存有时要第二次运行才更新；改完画法后图没变就再跑一次。

var _pixel: Script
var _crop: Script
var _px: Script


func _initialize() -> void:
	_pixel = load("res://art_gen/pixel_art.gd")
	_crop = load("res://art_gen/crop_art.gd")
	_px = load("res://art_gen/pixel.gd")
	var dir := ProjectSettings.globalize_path("res://_preview")
	DirAccess.make_dir_recursive_absolute(dir)

	# 树：每行一个季节
	var trees: Array = []
	for season in 4:
		for v in 3:
			trees.append(_pixel.call(&"round_tree", v, season))
		for v in 2:
			trees.append(_pixel.call(&"plum_tree", v, season))
	_save(trees, 5, Vector2i(56, 66), 3, "9ab86a", dir + "/trees.png")

	# 作物：每行两种，每种依次是出苗、长叶、成熟、枯死、产物图标、种子袋
	var db: Node = root.get_node("Database")
	# 这时全局系统的 _ready 还没跑，表要自己读一遍
	db.call(&"reload")
	var crops: Array = []
	var table: Dictionary = db.get(&"crops")
	for id: StringName in table:
		for stage in range(1, 4):
			crops.append(_pixel.call(&"crop", id, stage))
		crops.append(_pixel.call(&"crop", id, 0, true))
		crops.append(_pad(_crop.call(&"icon", id)))
		crops.append(_pad(_crop.call(&"seed_icon", id)))
	_save(crops, 12, Vector2i(18, 26), 5, "b47a4c", dir + "/crops.png")

	var misc: Array = [_pad(_pixel.call(&"ship_bin"))]
	for n: String in ["sun", "cloud", "rain", "storm", "fog", "wind", "snow", "frost"]:
		misc.append(_pad(_pixel.call(&"weather_icon", n)))
	for level in 4:
		misc.append(_pad(_pixel.call(&"icon", "hoe@%d" % level)))
	for level in 4:
		misc.append(_pad(_pixel.call(&"icon", "can@%d" % level)))
	for n: String in ["fert:1", "fert:2"]:
		misc.append(_pad(_pixel.call(&"icon", n)))
	for n: String in ["shovel", "lotus_flower"]:
		misc.append(_pad(_pixel.call(&"icon", n)))
	for q in [1, 2]:
		misc.append(_pad(_pixel.call(&"quality_mark", q)))
	_save(misc, 8, Vector2i(20, 26), 6, "80bd4e", dir + "/misc.png")
	var giants: Array = [_crop.call(&"giant", &"watermelon"), _crop.call(&"giant", &"pumpkin")]
	_save(giants, 2, Vector2i(36, 36), 6, "b47a4c", dir + "/giants.png")

	# 果树：每种一行，依次是树苗、小树，然后四季长成的样子（当季挂满果），最后是大风落果
	var tree_art: Script = load("res://art_gen/tree_art.gd")
	var season_ids: Array[StringName] = [&"spring", &"summer", &"autumn", &"winter"]
	var orchard: Array = []
	var tree_table: Dictionary = db.get(&"trees")
	for id: StringName in tree_table:
		var def: RefCounted = tree_table[id]
		orchard.append(tree_art.call(&"tree", id, 0, 0))
		orchard.append(tree_art.call(&"tree", id, 1, 1))
		var last_item: StringName = &""
		var last_season := 0
		for season in 4:
			var item: StringName = def.call(&"produce_in", season_ids[season])
			orchard.append(tree_art.call(&"tree", id, 2, season, item, 3 if item != &"" else 0, 0))
			if item != &"":
				last_item = item
				last_season = season
		orchard.append(tree_art.call(&"tree", id, 2, last_season, last_item, 1, 2))
	_save(orchard, 7, Vector2i(40, 52), 4, "80bd4e", dir + "/orchard.png")

	# 水果、采集物、树苗的图标
	var wild: Array = []
	var item_table: Dictionary = db.get(&"items")
	for id: StringName in item_table:
		var icon: String = item_table[id].get(&"icon")
		if icon.begins_with("wild:") or icon.begins_with("sapling:"):
			wild.append(_pad(_pixel.call(&"icon", icon)))
	_save(wild, 10, Vector2i(20, 26), 6, "80bd4e", dir + "/wild.png")

	# 鱼、遗物和鱼竿的图标
	var fish: Array = []
	for id: StringName in item_table:
		var icon: String = item_table[id].get(&"icon")
		if icon.begins_with("fish:") or icon.begins_with("relic:") or icon == "rod" or item_table[id].get(&"kind") == &"gear":
			fish.append(_pad(_pixel.call(&"icon", icon)))
	_save(fish, 10, Vector2i(20, 26), 6, "6a9ac8", dir + "/fish.png")

	# 畜产、加工品、菜，最后一行是加工设备在铺子里的图标
	var goods: Array = []
	for id: StringName in item_table:
		var icon: String = item_table[id].get(&"icon")
		if icon.begins_with("product:") or icon.begins_with("food:"):
			goods.append(_pad(_pixel.call(&"icon", icon)))
	while goods.size() % 10 != 0:
		goods.append(_px.call(&"new_img", 16, 24))
	var machine_table: Dictionary = db.get(&"machines")
	for id: StringName in machine_table:
		goods.append(_pad(_pixel.call(&"icon", "machine:" + String(id))))
	_save(goods, 10, Vector2i(20, 26), 6, "e8d2a0", dir + "/goods.png")

	# 沉灯井：一层的样子（地面、石头、梯子、井灯），井口和升降机，镐子和矿石的图标
	var mine_art: Script = load("res://art_gen/mine_art.gd")
	var floor_gen: Script = load("res://features/mine/mine_floor.gd")
	var layer: Object = db.call(&"mine_layer", 5)
	var level: Object = floor_gen.call(&"generate", 5, layer, 77, true, true)
	var open: Dictionary = level.get(&"open")
	var level_img: Image = mine_art.call(&"ground", open, 22, 14)
	var rocks: Dictionary = level.get(&"rocks")
	for t: Vector2i in rocks:
		var fleck := Color(0, 0, 0, 0)
		if rocks[t] != &"stone":
			fleck = db.call(&"ore_color", rocks[t])
		_px.call(&"blit", level_img, mine_art.call(&"rock", fleck, _px.call(&"h2", t.x, t.y)), t.x * 16, t.y * 16 - 1)
	var entry: Vector2i = level.get(&"entry")
	_px.call(&"blit", level_img, mine_art.call(&"ladder_up"), entry.x * 16, entry.y * 16 - 12)
	var lamp_at: Vector2i = level.get(&"lamp")
	_px.call(&"blit", level_img, mine_art.call(&"lamp", true), lamp_at.x * 16, lamp_at.y * 16 - 10)
	var ladder_at: Vector2i = level.get(&"ladder")
	_px.call(&"blit", level_img, mine_art.call(&"ladder_down"), ladder_at.x * 16, ladder_at.y * 16)
	level_img.resize(level_img.get_width() * 3, level_img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	level_img.save_png(dir + "/mine_floor.png")
	var mine_bits: Array = [mine_art.call(&"mouth"), mine_art.call(&"lift"), mine_art.call(&"lamp", false), mine_art.call(&"lamp", true),
		mine_art.call(&"ladder_up"), mine_art.call(&"ladder_down"), mine_art.call(&"hut")]
	for icon_name: String in ["mine:pickaxe", "mine:pickaxe@1", "mine:pickaxe@2", "mine:pickaxe@3", "relic:well_key", "mine:stone", "mine:copper_ore", "mine:coal"]:
		mine_bits.append(_pixel.call(&"icon", icon_name))
	_save(mine_bits, 5, Vector2i(68, 56), 4, "80bd4e", dir + "/mine.png")
	# 东滩：灯塔（黑着、亮着）、白鹭的画室和画架，赶海的四样，第四幕的三件遗物
	var beach_art: Script = load("res://art_gen/beach_art.gd")
	var beach_bits: Array = [beach_art.call(&"lighthouse", false), beach_art.call(&"lighthouse", true), beach_art.call(&"studio"), beach_art.call(&"easel")]
	for icon_name: String in ["wild:clam", "wild:kelp", "wild:conch", "wild:oyster", "relic:miner_roster", "relic:family_photo", "relic:ferry_stub"]:
		beach_bits.append(_pixel.call(&"icon", icon_name))
	_save(beach_bits, 6, Vector2i(68, 104), 4, "e9d8a6", dir + "/beach.png")
	# 山祠：古祠、挂祈愿牌的木架、桂花树四季、岚的两帧、祈愿的木牌
	var shrine_art: Script = load("res://art_gen/shrine_art.gd")
	var shrine_bits: Array = [shrine_art.call(&"shrine"), shrine_art.call(&"plaque_rack"), shrine_art.call(&"deer", 0), shrine_art.call(&"deer", 1)]
	for s in 4:
		shrine_bits.append(shrine_art.call(&"osmanthus", s))
	shrine_bits.append(_pixel.call(&"icon", "relic:prayer_tablet"))
	_save(shrine_bits, 4, Vector2i(92, 84), 4, "6f9a52", dir + "/shrine.png")
	# 岚站在雪地上：白鹿在白底上要看得见
	_save([shrine_art.call(&"deer", 0), shrine_art.call(&"deer", 1)], 2, Vector2i(56, 52), 6, "eef3f7", dir + "/deer_snow.png")
	# 节日：种子摊、丰收集和饺子宴的长桌、灯笼杆（灭、亮）、河灯两帧、萤火虫两帧
	var festival_art: Script = load("res://art_gen/festival_art.gd")
	var festival_bits: Array = [festival_art.call(&"stall"), festival_art.call(&"table", "harvest"), festival_art.call(&"table", "dumpling"),
		festival_art.call(&"lantern_pole", false), festival_art.call(&"lantern_pole", true),
		festival_art.call(&"river_lantern", 0), festival_art.call(&"river_lantern", 1), festival_art.call(&"firefly", 0), festival_art.call(&"firefly", 1)]
	_save(festival_bits, 5, Vector2i(60, 44), 6, "8a9a6a", dir + "/festival.png")
	_save(festival_bits.slice(3), 6, Vector2i(22, 40), 8, "1c2436", dir + "/festival_night.png")
	# 三个结局的画，和井底灯座的三个样子（没放灯、放了灯、最初的灯也亮了）
	var ending_art: Script = load("res://art_gen/ending_art.gd")
	var ending_bits: Array = []
	for ending_id: StringName in [&"keep", &"clear", &"name"]:
		ending_bits.append(ending_art.call(&"scene", ending_id))
	_save(ending_bits, 1, Vector2i(196, 112), 4, "000000", dir + "/endings.png")
	var altar_art: Script = load("res://art_gen/mine_dark_art.gd")
	_save([altar_art.call(&"altar", false), altar_art.call(&"altar", true), altar_art.call(&"altar", true, true)], 3, Vector2i(20, 28), 8, "2a2834", dir + "/altar.png")
	# 沙地：一半草一半沙，底下一条水，看沙和草、沙和水的接边
	var ground_art: Script = load("res://art_gen/ground_art.gd")
	var sand_terrain := PackedByteArray()
	sand_terrain.resize(12 * 8)
	for i in 12 * 8:
		var sx := i % 12
		var sy := i / 12
		sand_terrain[i] = 2 if sx >= 9 or sy >= 7 else (4 if sx >= 4 + (sy % 3) else 0)
	var sand_img: Image = (ground_art.call(&"paint", sand_terrain, 12, 8, 3) as Dictionary)["image"]
	sand_img.resize(sand_img.get_width() * 4, sand_img.get_height() * 4, Image.INTERPOLATE_NEAREST)
	sand_img.save_png(dir + "/sand.png")
	# 界面的几块底图：面板、格子（平常、选中）、凹下去的一块、提示条的底、铜钱
	var ui_bits: Array = [_pixel.call(&"ui_panel"), _pixel.call(&"ui_slot", false), _pixel.call(&"ui_slot", true),
		_pixel.call(&"ui_card"), _pixel.call(&"ui_toast"), _pixel.call(&"coin")]
	_save(ui_bits, 6, Vector2i(28, 28), 8, "6a8a5a", dir + "/ui.png")
	# 忘形的各个姿势（一行一种）、武器图标、挥砍的白光
	var monster_bits: Array = []
	for monster_id: String in ["dust", "stone_crab", "bat"]:
		for pose: StringName in [&"idle_a", &"idle_b", &"windup", &"strike", &"stun", &"hidden"]:
			monster_bits.append(mine_art.call(&"monster", StringName(monster_id), pose))
	for kind: String in ["sickle", "dagger", "hammer"]:
		monster_bits.append(_pixel.call(&"icon", "weapon:" + kind))
	monster_bits.append(mine_art.call(&"slash", 28.0, 75.0))
	monster_bits.append(mine_art.call(&"slash", 26.0, 24.0))
	monster_bits.append(mine_art.call(&"slash", 30.0, 180.0))
	_save(monster_bits, 6, Vector2i(64, 64), 5, "5c4b3d", dir + "/monsters.png")
	# 水渍层、遗落层的忘形和两个首领（一行一种，五个姿势），摆设、飞着的东西、六件遗物
	var deep_art: Script = load("res://art_gen/mine_deep_art.gd")
	var deep_bits: Array = []
	for monster_id: String in ["moss_frog", "leech_swarm", "leaky_umbrella", "empty_shoes", "walking_clock", "faceless_paper", "mine_cart", "well_catfish"]:
		for pose: StringName in [&"idle_a", &"idle_b", &"windup", &"strike", &"stun"]:
			deep_bits.append(mine_art.call(&"monster", StringName(monster_id), pose))
	for kind: StringName in [&"street_lamp", &"cabinet", &"chair", &"table"]:
		deep_bits.append(deep_art.call(&"prop", kind))
	deep_bits.append(deep_art.call(&"shot", &"paper"))
	deep_bits.append(deep_art.call(&"shot", &"water"))
	deep_bits.append(deep_art.call(&"spare_rod"))
	for weapon_icon: String in ["weapon:rail_hammer", "weapon:hammer", "weapon:fishbone_sickle", "weapon:sickle"]:
		deep_bits.append(_pixel.call(&"icon", weapon_icon))
	for icon_name: String in ["relic:frog_weight", "relic:hemp_rope", "relic:oil_umbrella", "relic:cloth_shoes", "relic:stopped_clock", "relic:paper_figure",
			"mine:iron_ore", "mine:quartz", "mine:silver_ore"]:
		deep_bits.append(_pixel.call(&"icon", icon_name))
	_save(deep_bits, 5, Vector2i(36, 36), 5, "4c5e62", dir + "/monsters_deep.png")
	# 无光层的三种忘形、戏班的三张面具、岚之影（一行一种，五个姿势），灯座、风、饰品、新遗物和矿石
	var dark_art: Script = load("res://art_gen/mine_dark_art.gd")
	var dark_bits: Array = []
	for monster_id: String in ["light_moth", "shadow", "nameless"]:
		for pose: StringName in [&"idle_a", &"idle_b", &"windup", &"strike", &"stun"]:
			dark_bits.append(mine_art.call(&"monster", StringName(monster_id), pose))
	for mask: StringName in [&"red", &"white", &"black"]:
		for pose: StringName in [&"idle_a", &"idle_b", &"windup", &"strike", &"stun"]:
			dark_bits.append(mine_art.call(&"monster", &"nameless_troupe", pose, mask))
	for pose: StringName in [&"idle_a", &"idle_b", &"windup", &"strike", &"stun"]:
		dark_bits.append(mine_art.call(&"monster", &"lan_shade", pose))
	dark_bits.append(dark_art.call(&"altar", false))
	dark_bits.append(dark_art.call(&"altar", true))
	dark_bits.append(dark_art.call(&"gust"))
	for icon_name: String in ["accessory:silver_guard", "accessory:leech_tooth", "accessory:oilcloth_wraps", "accessory:soft_soles",
			"accessory:lan_wick", "accessory:mask_shard", "accessory:lan_tassel",
			"relic:lamp_shade", "relic:old_photo", "relic:name_tag", "mine:gold_ore", "mine:lan_crystal"]:
		dark_bits.append(_pixel.call(&"icon", icon_name))
	_save(dark_bits, 5, Vector2i(36, 36), 5, "464458", dir + "/monsters_dark.png")
	# 几层的样子：水渍层、遗落层、无光层各一层，四间首领房
	for spec: Array in [[14, 31, false], [24, 31, false], [34, 31, false], [10, 1, true], [20, 1, true], [30, 1, true], [40, 1, true]]:
		var n: int = spec[0]
		var deep_layer: Object = db.call(&"mine_layer", n)
		var deep: Object
		if spec[2]:
			deep = floor_gen.call(&"generate_arena", n, deep_layer, spec[1], true, true)
		else:
			deep = floor_gen.call(&"generate", n, deep_layer, spec[1], true, n % 5 == 0)
		var img: Image = mine_art.call(&"ground", deep.get(&"open"), 22, 14, deep_layer.get(&"id"), deep.get(&"water"), deep.get(&"pools"))
		var deep_rocks: Dictionary = deep.get(&"rocks")
		for t: Vector2i in deep_rocks:
			var fleck := Color(0, 0, 0, 0)
			if deep_rocks[t] != &"stone":
				fleck = db.call(&"ore_color", deep_rocks[t])
			_px.call(&"blit", img, mine_art.call(&"rock", fleck, _px.call(&"h2", t.x, t.y)), t.x * 16, t.y * 16 - 1)
		var deep_props: Dictionary = deep.get(&"props")
		for t: Vector2i in deep_props:
			var prop_img: Image = deep_art.call(&"prop", deep_props[t])
			_px.call(&"blit", img, prop_img, t.x * 16, t.y * 16 + 16 - prop_img.get_height())
		var at: Vector2i = deep.get(&"entry")
		_px.call(&"blit", img, mine_art.call(&"ladder_up"), at.x * 16, at.y * 16 - 12)
		var monsters: Array = deep.get(&"monsters")
		for m: Object in monsters:
			var def: Object = m.get(&"def")
			var side: int = def.get(&"size")
			var pos: Vector2 = m.get(&"pos")
			_px.call(&"blit", img, mine_art.call(&"monster", def.get(&"id"), &"idle_a"), int(pos.x) - side / 2, int(pos.y) - side + 3)
		img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
		img.save_png(dir + "/mine_floor_%d.png" % n)
	quit()


func _save(images: Array, cols: int, cell: Vector2i, scale: int, bg: String, path: String) -> void:
	var sheet: Image = _pixel.call(&"sheet", images, cols, cell, scale, Color.html(bg))
	sheet.save_png(path)


## 把小图放到 24 高的格子底部，和地里的作物对齐。
func _pad(img: Image) -> Image:
	var out: Image = _px.call(&"new_img", maxi(16, img.get_width()), 24)
	_px.call(&"blit", out, img, 0, 24 - img.get_height() - 2)
	return out
