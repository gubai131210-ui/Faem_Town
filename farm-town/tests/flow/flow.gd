extends Node
## 自动化流程：从标题画面开始真实地玩一遍，沿途截图并检查关键状态。
## 运行：godot --path . res://tests/flow/flow.tscn；加 --headless 不开窗口、只跑检查不截图
## 截图在 _preview/ 下；全部通过时最后一行输出 FLOW PASS，否则 FLOW FAIL 并以非零码退出。
## 存档写在单独的目录，不会碰玩家的存档。

const SAVE_DIR := "user://flow_saves"
const CELL := 132
## 整个流程最多跑这么多秒。脚本中途报错会停在半路，窗口没人关：到点自己退出。
const TIMEOUT := 780.0

var is_runner := false

var _failures: PackedStringArray = []
var _checks := 0


func _ready() -> void:
	if is_runner:
		_watchdog()
		_run()
		return
	# 流程要跨场景存活，所以把真正干活的节点挂到根上，再离开本场景
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set(&"is_runner", true)
	runner.name = "FlowRunner"
	get_tree().root.add_child.call_deferred(runner)


func _run() -> void:
	# 固定随机种子：居民闲聊、野菜位置这些随机的东西每次都一样，流程才可重复
	seed(20260101)
	SaveSystem.base_dir = SAVE_DIR
	for i in SaveSystem.SLOT_COUNT:
		SaveSystem.delete(i)
	Audio.music_on = true
	await SceneRouter.to_menu()
	await _wait(0.6)
	await _shot("01_menu")

	_check(Database.validate().is_empty(), "数据表校验通过")

	# ---- 新游戏
	var menu := get_tree().current_scene
	menu.call(&"start_new", 0)
	await _wait(1.6)
	var game := get_tree().current_scene
	_check(game != null and game.name == "Game", "进入游戏场景")
	var player: Player = game.get(&"player")
	await _shot("02_farm_start")
	_check(GameState.inventory.count_of(&"white_radish_seed") == 12, "开局有 12 颗种子")
	# 天气是随机的，流程里固定成晴天，不然“过夜后土地变干”这类检查会时灵时不灵
	Weather.tomorrow = Weather.SUNNY
	_check(Weather.today == Weather.SUNNY, "第一天是晴天")

	# ---- 走路
	Input.action_press(&"move_down")
	await _wait(0.4)
	await _strip(player, "walk_down", 8, 0.06)
	Input.action_release(&"move_down")
	Input.action_press(&"move_right")
	await _wait(0.4)
	await _strip(player, "walk_right", 8, 0.06)
	Input.action_release(&"move_right")
	Input.action_press(&"move_up")
	await _wait(0.3)
	await _strip(player, "walk_up", 8, 0.06)
	Input.action_release(&"move_up")
	Input.action_press(&"move_left")
	await _wait(0.3)
	await _strip(player, "walk_left", 8, 0.06)
	Input.action_release(&"move_left")
	await _wait(0.3)
	await _strip(player, "idle", 6, 0.12)

	# ---- 开垦、浇水、播种
	var field := Vector2i(20, 12)
	player.place(GameMap.tile_center(field + Vector2i(0, -1)), GameMap.Facing.DOWN)
	await _wait(0.4)
	_check(player.target_tile() == field, "面前的格子是目标格")
	GameState.selected_slot = 0
	var energy_before := GameState.energy
	Input.action_press(&"use")
	await _wait(0.05)
	Input.action_release(&"use")
	await _strip(player, "hoe_down", 8, 0.05)
	await _wait(0.4)
	_check(Farming.state.soil.has(field), "锄头开垦了土地")
	_check(GameState.energy < energy_before, "用锄头消耗体力")

	GameState.selected_slot = 1
	await _press(&"use")
	await _strip(player, "water_down", 7, 0.07)
	await _wait(0.4)
	_check(Farming.state.soil.get(field, false), "浇了水")

	GameState.selected_slot = 2
	await _press(&"use")
	await _wait(0.6)
	_check(Farming.state.crop_id_at(field) == &"white_radish", "种下了白萝卜")
	_check(GameState.inventory.count_of(&"white_radish_seed") == 11, "种子少了一颗")

	# 侧面的动作
	player.place(GameMap.tile_center(field + Vector2i(-1, 1)), GameMap.Facing.RIGHT)
	GameState.selected_slot = 0
	await _wait(0.2)
	await _press(&"use")
	await _strip(player, "hoe_right", 8, 0.05)
	await _wait(0.4)
	player.place(GameMap.tile_center(field + Vector2i(1, 1)), GameMap.Facing.LEFT)
	await _wait(0.2)
	await _press(&"use")
	await _strip(player, "hoe_left", 8, 0.05)
	await _wait(0.4)
	player.place(GameMap.tile_center(field + Vector2i(0, 3)), GameMap.Facing.UP)
	await _wait(0.2)
	await _press(&"use")
	await _strip(player, "hoe_up", 8, 0.05)
	await _wait(0.4)
	await _until_free()
	_check(Farming.state.soil.size() == 3, "侧面几下又开出两格（实际 %s）" % [Farming.state.soil.keys()])
	await _shot("03_field")

	# ---- 背包
	await _press(&"inventory")
	await _wait(0.2)
	_check(not GameClock.running, "打开背包时时间暂停")
	await _press(&"move_right")
	await _press(&"move_right")
	await _press(&"use")
	await _press(&"move_down")
	await _wait(0.1)
	await _shot("04_inventory")
	await _press(&"use")
	_check(GameState.inventory.id_at(10) == &"white_radish_seed", "背包里交换了位置")
	await _press(&"use")
	await _press(&"move_up")
	await _press(&"use")
	_check(GameState.inventory.id_at(2) == &"white_radish_seed", "又换回了物品栏")
	await _press(&"inventory")
	await _wait(0.2)
	_check(GameClock.running, "关闭背包后时间继续")

	# ---- 暂停
	await _press(&"pause")
	await _wait(0.2)
	await _shot("05_pause")
	var pause_menu: PauseMenu = game.get(&"pause_menu")
	pause_menu.show_keys()
	await _wait(0.2)
	_check(pause_menu.keys_open(), "暂停菜单里打开了按键说明")
	await _shot("05c_keys")
	await _press(&"pause")
	await _wait(0.2)
	_check(pause_menu.is_open() and not pause_menu.keys_open(), "按暂停键从按键说明退回菜单")
	await _press(&"pause")
	await _wait(0.2)
	_check(not pause_menu.is_open(), "再按一下关掉暂停菜单")

	# ---- 天气画面
	Weather.today = Weather.RAIN
	Weather.changed.emit()
	await _wait(0.5)
	await _shot("05b_rain")
	Weather.today = Weather.FOG
	Weather.changed.emit()
	await _wait(0.5)
	await _shot("05c_fog")
	Weather.today = Weather.SUNNY
	Weather.changed.emit()
	await _wait(0.2)

	# ---- 信箱对话
	player.place(GameMap.tile_center(Vector2i(11, 8)), GameMap.Facing.UP)
	await _wait(0.3)
	await _press(&"use")
	await _wait(1.2)
	await _shot("06_dialogue")
	_check((game.get(&"balloon") as DialogueBalloon).is_open(), "信箱打开了对话")
	for i in 40:
		if not (game.get(&"balloon") as DialogueBalloon).is_open():
			break
		await _press(&"use")
		await _wait(0.12)
	_check(not (game.get(&"balloon") as DialogueBalloon).is_open(), "对话能走到结束")

	# ---- 去镇上：沿门口的路往西走到头
	GameClock.minutes = 600.0
	player.place(GameMap.tile_center(Vector2i(2, 11)) + Vector2(0, 8), GameMap.Facing.LEFT)
	await _wait(0.3)
	await _shot("06a_road_west")
	Input.action_press(&"move_left")
	for i in 40:
		if GameState.map_id == &"town":
			break
		await _wait(0.1)
	Input.action_release(&"move_left")
	await _until_idle()
	await _wait(0.5)
	_check(GameState.map_id == &"town", "往西走到了镇上")
	var town: OutdoorMap = game.get(&"map")
	_check(town.npcs.size() == 10, "上午镇上有十位居民")
	var balloon: DialogueBalloon = game.get(&"balloon")
	# ---- 序幕：小满跑过来搭话
	for i in 150:
		if balloon.is_open():
			break
		await _wait(0.1)
	_check(balloon.is_open(), "第一次进镇小满跑过来搭话")
	await _shot("06b0_prologue")
	for i in 20:
		if not balloon.is_open():
			break
		await _press(&"use")
		await _wait(0.12)
	_check(not balloon.is_open(), "序幕说得完")
	_check(GameState.has_flag(&"prologue_town"), "序幕只演一次")
	_check(Residents.has_met(&"xiaoman"), "序幕里算是见过小满了")
	await _shot("06b_town_gate")
	player.place(GameMap.tile_center(Vector2i(22, 18)), GameMap.Facing.UP)
	await _wait(0.5)
	await _shot("06c_plaza")
	player.place(GameMap.tile_center(Vector2i(24, 11)), GameMap.Facing.UP)
	await _wait(0.5)
	await _shot("06d_hall")

	# ---- 杂货铺：和阿禾说话，第一次见面先自我介绍，然后买种子
	player.place(GameMap.tile_center(Vector2i(8, 19)), GameMap.Facing.UP)
	await _wait(0.4)
	await _press(&"use")
	await _wait(1.0)
	_check(balloon.is_open(), "和阿禾搭上了话")
	await _shot("06e_ahe")
	var shop: ShopPanel = game.get(&"shop_panel")
	for i in 30:
		if shop.is_open() or not balloon.is_open():
			break
		await _press(&"use")
		await _wait(0.15)
		if balloon.is_open() and not shop.is_open():
			await _press(&"ui_accept")
			await _wait(0.15)
	await _wait(0.3)
	_check(shop.is_open(), "对话里选买东西打开了货单")
	_check(not balloon.is_open(), "货单打开后对话结束了")
	_check(not GameClock.running, "打开货单时时间暂停")
	_check(Residents.has_met(&"ahe"), "记下了见过阿禾")
	var money_before := GameState.money
	await _press(&"use")
	await _wait(0.1)
	_check(GameState.inventory.count_of(&"bok_choy_seed") == 1, "买到一包小白菜种子")
	_check(GameState.money == money_before - Database.item(&"bok_choy_seed").price, "买种子扣了钱")
	await _press(&"move_down")
	await _press(&"move_down")
	await _wait(0.1)
	await _shot("06f_grocery")
	await _press(&"inventory")
	await _wait(0.2)
	_check(not shop.is_open(), "货单可以关掉")

	# ---- 铁匠铺：石叔只管升级工具
	player.place(GameMap.tile_center(Vector2i(37, 19)), GameMap.Facing.UP)
	await _wait(0.4)
	await _press(&"use")
	await _wait(1.0)
	for i in 30:
		if shop.is_open() or not balloon.is_open():
			break
		await _press(&"use")
		await _wait(0.15)
		if balloon.is_open() and not shop.is_open():
			await _press(&"ui_accept")
			await _wait(0.15)
	await _wait(0.3)
	_check(shop.is_open(), "石叔那里能打开升级单")
	await _shot("06g_smith")
	await _press(&"inventory")
	await _wait(0.2)

	# ---- 小满：每天报明天的天气
	var xiaoman: Npc = town.call(&"_npc_of", &"xiaoman")
	_check(xiaoman != null and not xiaoman.is_walking(), "小满在广场上站着")
	if xiaoman != null:
		Residents.met[&"xiaoman"] = true
		player.place(GameMap.tile_center(xiaoman.tile() + Vector2i(0, 1)), GameMap.Facing.UP)
		await _wait(0.4)
		await _press(&"use")
		await _wait(1.4)
		await _shot("06h_xiaoman")
		for i in 12:
			if not balloon.is_open():
				break
			await _press(&"use")
			await _wait(0.12)
		_check(not balloon.is_open(), "小满的话能说完")

		# ---- 送礼：手里拿着草莓再搭话，先问要不要送
		GameState.inventory.add(&"strawberry", 2)
		_hold(&"strawberry")
		var familiar_before := Residents.familiarity_of(&"xiaoman")
		await _wait(0.3)
		await _press(&"use")
		await _wait(1.2)
		_check(balloon.is_open(), "拿着草莓搭话先问要不要送")
		await _shot("06h2_gift_offer")
		await _press(&"ui_accept")
		await _wait(1.2)
		_check(balloon.is_open(), "送完接着是小满的反应")
		await _shot("06h3_gift_love")
		for i in 12:
			if not balloon.is_open():
				break
			await _press(&"use")
			await _wait(0.12)
		_check(not balloon.is_open(), "送礼的对话能结束")
		_check(GameState.inventory.count_of(&"strawberry") == 1, "草莓送出去一个")
		_check(Residents.familiarity_of(&"xiaoman") == familiar_before + 40, "送了最喜欢的东西，熟悉度加 40")
		GameState.selected_slot = 0

		# ---- 名册
		await _press(&"residents")
		await _wait(0.3)
		var roster: ResidentsPanel = game.get(&"residents_panel")
		_check(roster.is_open(), "按 R 打开名册")
		await _press(&"move_down")
		await _wait(0.2)
		await _shot("06h4_roster")
		await _press(&"residents")
		await _wait(0.2)
		_check(not roster.is_open(), "名册可以关掉")

	# ---- 柏先生：镇公所门口，对话框带头像
	player.place(GameMap.tile_center(Vector2i(22, 11)), GameMap.Facing.UP)
	await _wait(0.4)
	await _press(&"use")
	await _wait(1.2)
	_check(balloon.is_open(), "和柏先生搭上了话")
	await _shot("06h5_bai")
	for i in 12:
		if not balloon.is_open():
			break
		await _press(&"use")
		await _wait(0.12)

	# ---- 南边的路通到南溪
	GameClock.minutes = 600.0
	player.place(GameMap.tile_center(Vector2i(22, 26)), GameMap.Facing.DOWN)
	await _wait(0.4)
	Input.action_press(&"move_down")
	for i in 40:
		if GameState.map_id == &"nanxi":
			break
		await _wait(0.1)
	Input.action_release(&"move_down")
	await _until_idle()
	await _wait(0.5)
	_check(GameState.map_id == &"nanxi", "往南走到了南溪")
	var nanxi: OutdoorMap = game.get(&"map")
	await _shot("06h6_nanxi_road")
	_check(nanxi.npc_at(Vector2i(20, 16)) != null, "上午老周站在码头上")
	# 走到码头上和老周说话
	player.place(GameMap.tile_center(Vector2i(19, 16)) + Vector2(0, 2), GameMap.Facing.RIGHT)
	await _wait(0.4)
	await _shot("06h7_dock")
	await _press(&"use")
	await _wait(1.0)
	_check(balloon.is_open(), "和码头上的老周搭上了话")
	await _shot("06h8_laozhou_dock")
	for i in 12:
		if not balloon.is_open():
			break
		await _press(&"use")
		await _wait(0.12)
	# 蟹笼：放到溪里，隔天的事由 Fishing 结算，这里直接结算一次再收
	GameState.inventory.add(&"crab_trap", 1)
	_hold(&"crab_trap")
	player.place(GameMap.tile_center(Vector2i(12, 16)) + Vector2(0, 4), GameMap.Facing.DOWN)
	await _wait(0.3)
	var trap_tile := player.target_tile()
	_check(nanxi.fishing_water(trap_tile) == &"stream", "码头西边对着的是溪水")
	_check(nanxi.query_use(GameState.selected_item(), trap_tile, player.facing) == &"place_trap", "拿着蟹笼对着水能放")
	await _press(&"use")
	await _wait(0.8)
	_check(Fishing.has_trap(&"nanxi", trap_tile), "蟹笼放到了水里")
	_check(GameState.inventory.count_of(&"crab_trap") == 0, "手里的蟹笼用掉了")
	await _shot("06h9_trap")
	Fishing.settle_traps(0.1)
	await _wait(0.3)
	_check(Fishing.trap_catch(&"nanxi", trap_tile) != &"", "过一夜笼子里有东西")
	await _shot("06i0_trap_full")
	GameState.selected_slot = 0
	var trap_got := Fishing.trap_catch(&"nanxi", trap_tile)
	await _press(&"use")
	await _wait(0.5)
	_check(GameState.inventory.count_of(trap_got) == 1, "收到了笼子里的东西")
	_check(Fishing.has_trap(&"nanxi", trap_tile), "笼子还留在水里")
	await _press(&"use")
	await _wait(0.5)
	_check(not Fishing.has_trap(&"nanxi", trap_tile), "空笼子收回来了")
	# 鱼谱：翻到第三页
	await _press(&"residents")
	await _wait(0.3)
	var roster2: ResidentsPanel = game.get(&"residents_panel")
	await _press(&"move_left")
	await _wait(0.2)
	_check(roster2._page == 2, "名册往左翻一页是鱼谱")
	await _shot("06i1_fishbook")
	await _press(&"residents")
	await _wait(0.2)

	# ---- 河底的灯盏：有了竿子以后老周在码头上提一句
	GameState.inventory.add(&"rod", 1)
	GameState.set_flag(&"got_rod")
	GameState.selected_slot = 0
	player.place(GameMap.tile_center(Vector2i(19, 16)) + Vector2(0, 2), GameMap.Facing.RIGHT)
	await _wait(0.3)
	await _press(&"use")
	await _wait(1.0)
	_check(balloon.is_open(), "再找老周说话")
	await _shot("06i2_lantern_hint")
	for i in 12:
		if not balloon.is_open():
			break
		await _press(&"use")
		await _wait(0.12)
	_check(GameState.has_flag(&"lantern_hint"), "老周说了潭底沉着灯")
	_check(nanxi.sunken_relic(Vector2i(17, 18)) == &"river_lantern", "说过以后潭底就有灯盏可钓")
	# 钓起来的过程由单元测试和钓鱼段落覆盖；这里直接当作钓到了，看老周走过来
	GameState.inventory.add(&"river_lantern", 1)
	GameState.set_flag(&"relic_river_lantern")
	nanxi.relic_fished(&"river_lantern")
	for i in 60:
		if balloon.is_open():
			break
		await _wait(0.1)
	_check(balloon.is_open(), "钓起灯盏老周走过来开口")
	await _shot("06i3_laozhou_lantern")
	for i in 14:
		if not balloon.is_open():
			break
		await _press(&"use")
		await _wait(0.12)
	_check(GameState.has_flag(&"lantern_found"), "老周认出了那盏灯")
	# ---- 河灯：供上三样鱼和灯盏，点亮
	_check(nanxi.query_use(null, nanxi.BOAT_TILES[0], GameMap.Facing.LEFT) == &"interact", "站在码头上朝西就是船")
	player.place(GameMap.tile_center(Vector2i(19, 16)) + Vector2(0, 2), GameMap.Facing.LEFT)
	await _wait(0.3)
	await _press(&"use")
	await _wait(0.6)
	_check(GameState.map_id == &"nanxi", "灯没亮以前船坐不了")
	GameState.inventory.add(&"crucian", 3)
	GameState.inventory.add(&"stream_grouper", 2)
	GameState.inventory.add(&"river_shrimp", 4)
	player.place(GameMap.tile_center(Vector2i(23, 14)), GameMap.Facing.UP)
	await _wait(0.4)
	await _press(&"use")
	await _wait(0.4)
	var river_lamp_panel: LampPanel = game.get(&"lamp_panel")
	_check(river_lamp_panel.is_open(), "对着河灯按使用打开灯座")
	for i in 4:
		await _press(&"use")
		await _press(&"move_down")
		await _wait(0.1)
	_check(Lamps.is_complete(&"river"), "河灯的供品都供上了")
	await _press(&"use")
	await _wait(0.5)
	_check(Lamps.is_lit(&"river"), "河灯点亮了")
	await _shot("06i4_river_lamp_lit")
	await _wait(1.8)
	_check(balloon.is_open(), "河灯亮了有一段旁白")
	for i in 12:
		if not balloon.is_open():
			break
		await _press(&"use")
		await _wait(0.12)
	# 老周送竿子
	player.place(GameMap.tile_center(Vector2i(19, 16)) + Vector2(0, 2), GameMap.Facing.RIGHT)
	await _wait(0.3)
	await _press(&"use")
	await _wait(1.0)
	_check(balloon.is_open(), "灯亮了以后找老周")
	for i in 12:
		if not balloon.is_open():
			break
		await _press(&"use")
		await _wait(0.12)
	_check(GameState.tool_level(&"rod") == 1, "老周把自己的竿子给了玩家")
	# ---- 坐船去河岸
	player.place(GameMap.tile_center(Vector2i(19, 16)) + Vector2(0, 2), GameMap.Facing.LEFT)
	await _wait(0.3)
	await _press(&"use")
	for i in 30:
		if GameState.map_id == &"riverbank":
			break
		await _wait(0.1)
	await _wait(0.8)
	_check(GameState.map_id == &"riverbank", "坐船到了河岸")
	var bank: OutdoorMap = game.get(&"map")
	await _shot("06i5_riverbank")
	_check(bank.fishing_water(Vector2i(14, 8)) == &"river", "码头前面是河水")
	player.place(GameMap.tile_center(Vector2i(bank.BOATHOUSE_X + 1, bank.BOATHOUSE_FRONT + 1)), GameMap.Facing.UP)
	await _wait(0.4)
	await _shot("06i6_boathouse")
	# 坐船回南溪
	player.place(GameMap.tile_center(Vector2i(15, 10)) + Vector2(0, 2), GameMap.Facing.RIGHT)
	await _wait(0.3)
	await _press(&"use")
	for i in 30:
		if GameState.map_id == &"nanxi":
			break
		await _wait(0.1)
	await _wait(0.8)
	_check(GameState.map_id == &"nanxi", "坐船回到了南溪")
	nanxi = game.get(&"map")
	# 回镇上
	player.place(GameMap.tile_center(Vector2i(19, 2)) + Vector2(8, 0), GameMap.Facing.UP)
	await _wait(0.3)
	Input.action_press(&"move_up")
	for i in 40:
		if GameState.map_id == &"town":
			break
		await _wait(0.1)
	Input.action_release(&"move_up")
	await _until_idle()
	await _wait(0.5)
	_check(GameState.map_id == &"town", "从南溪走回了镇上")
	town = game.get(&"map")

	# ---- 公告栏：接下姜婆婆的委托
	GameClock.minutes = 610.0
	player.place(GameMap.tile_center(Vector2i(27, 9)), GameMap.Facing.UP)
	await _wait(0.4)
	await _press(&"use")
	await _wait(0.4)
	var board: BoardPanel = game.get(&"board_panel")
	_check(board.is_open(), "对着公告栏按使用打开委托")
	await _shot("06k_board")
	await _press(&"use")
	await _wait(0.2)
	_check(Quests.is_active(&"jiang_radish"), "接下了求白萝卜的委托")
	await _press(&"inventory")
	await _wait(0.2)
	_check(not board.is_open(), "公告栏可以关掉")

	# ---- 交委托：拿着白萝卜去找姜婆婆，拿到旧灯芯
	var jiang: Npc = town.call(&"_npc_of", &"jiang")
	_check(jiang != null and not jiang.is_walking(), "上午姜婆婆在药铺门口")
	if jiang != null:
		Residents.met[&"jiang"] = true
		GameState.inventory.add(&"white_radish", 7)
		_hold(&"white_radish")
		player.place(GameMap.tile_center(jiang.tile() + Vector2i(0, 1)), GameMap.Facing.UP)
		await _wait(0.4)
		var money_q := GameState.money
		await _press(&"use")
		await _wait(1.2)
		_check(balloon.is_open(), "交委托时姜婆婆开口")
		await _shot("06l_quest_done")
		_check(Quests.is_done(&"jiang_radish"), "委托记成做完")
		_check(GameState.inventory.count_of(&"old_wick") == 1, "拿到旧灯芯")
		_check(GameState.inventory.count_of(&"white_radish") == 4, "收走了三个白萝卜")
		_check(GameState.money == money_q + 80, "委托给了 80 文")
		for i in 12:
			if not balloon.is_open():
				break
			await _press(&"use")
			await _wait(0.12)
		GameState.selected_slot = 0

	# ---- 广场灯：供上东西，点灯
	GameState.inventory.add(&"rapeseed", 3)
	GameState.inventory.add(&"shepherds_purse", 3)
	player.place(GameMap.tile_center(Vector2i(22, 16)), GameMap.Facing.UP)
	await _wait(0.4)
	await _press(&"use")
	await _wait(0.4)
	var lamp_panel: LampPanel = game.get(&"lamp_panel")
	_check(lamp_panel.is_open(), "对着广场灯按使用打开灯座")
	await _shot("06m_lamp")
	for i in 4:
		await _press(&"use")
		await _press(&"move_down")
		await _wait(0.1)
	_check(Lamps.is_complete(&"plaza"), "四样供品都供上了")
	_check(GameState.inventory.count_of(&"old_wick") == 0 and GameState.inventory.count_of(&"rapeseed") == 0, "供品从背包里拿走了")
	await _press(&"use")
	await _wait(0.5)
	_check(Lamps.is_lit(&"plaza"), "广场灯点亮了")
	_check(not lamp_panel.is_open(), "点完灯灯座关掉")
	await _shot("06n_lamp_lit")
	await _wait(1.8)
	_check(balloon.is_open(), "点灯以后有一段旁白")
	for i in 12:
		if not balloon.is_open():
			break
		await _press(&"use")
		await _wait(0.12)
	_check(Shop.full_shelves(), "点灯以后杂货铺货架齐了")

	# ---- 还遗物：和阿禾够熟了，把账本残页还给她
	var ahe_npc: Npc = town.call(&"_npc_of", &"ahe")
	if ahe_npc != null:
		Residents.met[&"ahe"] = true
		Residents.add_familiarity(&"ahe", 100)
		GameState.inventory.add(&"ledger_page", 1)
		_hold(&"ledger_page")
		player.place(GameMap.tile_center(ahe_npc.tile() + Vector2i(0, 1)), GameMap.Facing.UP)
		await _wait(0.4)
		await _press(&"use")
		await _wait(1.2)
		_check(balloon.is_open(), "还遗物时阿禾开口")
		await _shot("06o_memory")
		_check(Residents.memory_level(&"ahe") == 1, "阿禾的忆到了一级")
		_check(Residents.familiarity_cap(&"ahe") == 200, "熟悉度上限跟着涨")
		for i in 12:
			if not balloon.is_open():
				break
			await _press(&"use")
			await _wait(0.12)
		GameState.selected_slot = 0
		await _press(&"residents")
		await _wait(0.2)
		await _press(&"move_right")
		await _wait(0.2)
		await _shot("06p_memory_book")
		await _press(&"residents")
		await _wait(0.2)

	# ---- 傍晚收铺：掌柜离开门口，镇上亮灯
	GameClock.minutes = 1100.0
	await _wait(0.4)
	var ahe: Npc = town.call(&"_npc_of", &"ahe")
	_check(ahe != null and ahe.is_walking(), "傍晚阿禾收铺往广场走")
	player.place(GameMap.tile_center(Vector2i(14, 19)), GameMap.Facing.UP)
	await _strip(ahe, "npc_walk", 8, 0.12)
	GameClock.minutes = 1180.0
	player.place(GameMap.tile_center(Vector2i(22, 17)), GameMap.Facing.UP)
	await _wait(0.5)
	await _shot("06i_town_dusk")

	# ---- 回农场
	GameClock.minutes = 620.0
	player.place(GameMap.tile_center(Vector2i(43, 18)) + Vector2(0, 8), GameMap.Facing.RIGHT)
	await _wait(0.3)
	Input.action_press(&"move_right")
	for i in 40:
		if GameState.map_id == &"farm":
			break
		await _wait(0.1)
	Input.action_release(&"move_right")
	await _until_idle()
	await _wait(0.5)
	_check(GameState.map_id == &"farm", "往东走回了农场")
	await _shot("06j_back_on_farm")

	# ---- 养殖：订鸡舍、盖好、买鸡鸭、喂、收蛋
	var weather_was := Weather.today
	Weather.today = &"sunny"
	GameState.set_flag(&"lamp_plaza")
	GameState.set_flag(&"lamp_river")
	GameState.money += 3000
	_check(Animals.order("coop"), "订了鸡舍")
	player.place(GameMap.tile_center(Vector2i(34, 11)), GameMap.Facing.UP)
	await _wait(0.5)
	await _shot("06j2_scaffold")
	for i in 3:
		Animals.settle(false)
	_check(Animals.is_built(&"coop"), "三天后鸡舍盖好")
	_check(Animals.buy("chicken") and Animals.buy("chicken") and Animals.buy("duck"), "买了两只鸡一只鸭")
	await _wait(1.5)
	var critters: Array = game.map.get(&"_critters")
	_check(critters.size() == 3, "鸡鸭白天在院子里")
	await _shot("06j3_coop")
	if critters.size() > 0:
		await _strip(critters[0], "critter", 8, 0.15)
	GameState.inventory.add(&"feed", 5)
	_hold(&"feed")
	player.place(GameMap.tile_center(Vector2i(34, 10)), GameMap.Facing.UP)
	await _wait(0.3)
	_check(game.map.query_use(GameState.selected_item(), player.target_tile(), player.facing) == &"tend", "拿着饲料对着鸡舍的墙是伸手添料")
	await _press(&"use")
	await _wait(0.6)
	_check(Animals.hungry_in(&"coop") == 0, "拿着饲料对着鸡舍按一下，全喂上了")
	await _shot("06j4_fed")
	critters = game.map.get(&"_critters")
	if critters.size() > 0:
		# 几只挤在一块的时候，对着这一格摸到的是离格子中心最近的那只，不一定是第一只
		var critter: Critter = game.map.call(&"_critter_at", (critters[0] as Critter).tile())
		if critter == null:
			critter = critters[0]
		game.map.perform(&"interact", null, critter.tile())
		_check(Animals.is_petted(critter.index), "摸了一下")
		await _wait(0.25)
		await _shot("06j5_pet")
	await _wait(1.2)
	Animals.settle(false)
	_check(Animals.stored(&"coop") >= 3, "第二天鸡舍里有蛋")
	var eggs_before := GameState.inventory.count_of(&"egg")
	GameState.selected_slot = 0
	game.map.perform(&"interact", null, Vector2i(34, 9))
	_check(GameState.inventory.count_of(&"egg") == eggs_before + 2, "收了两个鸡蛋")
	await _wait(0.4)
	await _shot("06j6_eggs")
	await _wait(1.0)

	# ---- 猫狗：门口蹲着一条狗一只猫，留下花猫（猫守着屋子周围 12 格，流程里种的那格在里面，过夜不会被乌鸦刨）
	EventBus.dialogue_requested.emit("res://dialogue/common.dialogue", "pet_choice")
	await _wait(0.8)
	for i in 6:
		await _press(&"use")
		await _wait(0.45)
	await _shot("06k1_pet_choice")
	var pet_buttons: Array = balloon.get(&"_choices").get_children()
	_check(pet_buttons.size() == 2, "狗和猫两个选项")
	if pet_buttons.size() == 2:
		pet_buttons[1].grab_focus()
	await _wait(0.15)
	await _press(&"ui_accept")
	await _wait(0.4)
	for i in 12:
		if not balloon.is_open():
			break
		await _press(&"use")
		await _wait(0.3)
	_check(not balloon.is_open(), "猫狗的对话能结束")
	_check(Animals.pet_kind() == &"cat", "留下了花猫")
	if Animals.pet_kind() != &"cat":
		GameState.flags.erase(&"pet_dog")
		GameState.set_flag(&"pet_cat")
	GameClock.minutes += 2.0
	await _wait(0.6)
	var pet: Critter = game.map.get(&"_pet")
	_check(pet != null, "花猫白天在屋前转")
	if pet != null:
		player.place(pet.position + Vector2(20, 6), GameMap.Facing.LEFT)
		await _wait(0.4)
		await _shot("06k2_cat")
		game.map.perform(&"tend", null, pet.tile())
		_check(Animals.pet_day == GameClock.day, "摸了摸猫")
		await _wait(0.3)
		await _strip(pet, "cat", 8, 0.15)
	await _wait(1.0)
	Weather.today = weather_was

	# ---- 钓鱼：在池塘西岸对着水甩竿，等咬钩，收放线
	var fishing: FishingSession = game.get(&"fishing")
	fishing._rng.seed = 7
	if GameState.inventory.count_of(&"rod") == 0:
		GameState.inventory.add(&"rod", 1)
	_hold(&"rod")
	GameState.energy = 100
	player.place(GameMap.tile_center(Vector2i(28, 17)) + Vector2(0, 8), GameMap.Facing.RIGHT)
	await _wait(0.3)
	_check(game.map.query_use(GameState.selected_item(), player.target_tile(), player.facing) == &"cast", "拿着鱼竿对着池塘能甩竿")
	var species_before := Fishing.species_count()
	var fish_before := 0
	for id: StringName in Database.fish:
		fish_before += GameState.inventory.count_of(id)
	await _press(&"use")
	await _wait(0.45)
	_check(fishing.active(), "甩竿动作生效，浮漂飞出去了")
	await _shot("06p_cast")
	await _wait(0.9)
	_check(fishing.phase == FishingSession.Phase.WAITING, "浮漂落水，玩家持竿站着")
	_check(player.held_anim() == &"fish", "持竿用的是等鱼的姿势")
	_check(player.rod_tip() != player.position, "竿尖位置来自序列帧")
	fishing._timer = 1.4
	await _wait(0.6)
	_check(fishing.view.show_shadow, "快咬钩时水里有鱼影游过来")
	await _shot("06q_fishing_wait")
	await _wait(1.0)
	_check(fishing.phase == FishingSession.Phase.BITE, "浮漂动了")
	await _shot("06r_bite")
	await _press(&"use")
	await _wait(0.1)
	_check(fishing.phase == FishingSession.Phase.FIGHT, "按下去钩住了")
	var shot_fight := false
	var shot_strain := false
	for i in 1500:
		if fishing.phase != FishingSession.Phase.FIGHT:
			break
		var f: FishFight = fishing.fight
		var reel := f != null and not f.struggling and not f.warning and f.tension < 0.6
		if reel:
			Input.action_press(&"use")
		else:
			Input.action_release(&"use")
		if not shot_fight and f != null and f.elapsed > 1.0 and player.held_anim() == &"reel":
			shot_fight = true
			await _shot("06s_fight")
		if not shot_strain and f != null and f.struggling and player.held_anim() == &"strain":
			shot_strain = true
			await _shot("06s2_strain")
		await get_tree().process_frame
	_check(shot_fight, "收线时换成了摇轮的姿势")
	_check(shot_strain, "鱼挣扎时换成了绷竿的姿势")
	Input.action_release(&"use")
	_check(fishing.phase == FishingSession.Phase.SHOW, "鱼遛上来了")
	if fishing.phase == FishingSession.Phase.FIGHT:
		fishing.cancel()
	_check(Fishing.species_count() >= species_before + 1, "钓鱼的记录里多了一种鱼")
	var fish_count := 0
	for id: StringName in Database.fish:
		fish_count += GameState.inventory.count_of(id)
	_check(fish_count == fish_before + 1, "背包里多了一条鱼")
	_check(player.held_anim() == &"trophy", "钓上来举着鱼")
	await _wait(0.3)
	await _shot("06t_caught")
	await _wait(1.6)
	_check(not fishing.active(), "举完鱼收竿")
	_check(player.state == Player.State.FREE, "收竿后能动")

	# ---- 黄昏和夜晚
	GameClock.minutes = 1125.0
	await _wait(0.3)
	await _shot("07_dusk")
	GameClock.minutes = 1330.0
	player.place(GameMap.tile_center(Vector2i(9, 9)), GameMap.Facing.DOWN)
	await _wait(0.5)
	await _shot("08_night")

	# ---- 进屋
	player.place(GameMap.tile_center(Vector2i(8, 7)), GameMap.Facing.UP)
	await _wait(0.2)
	await _press(&"use")
	await _wait(1.0)
	_check(GameState.map_id == &"farmhouse", "从门进了屋")
	await _shot("09_farmhouse")
	Input.action_press(&"move_up")
	await _wait(0.5)
	Input.action_release(&"move_up")

	# ---- 收音机：报天气
	player.place(GameMap.tile_center(Vector2i(4, 3)), GameMap.Facing.UP)
	await _wait(0.2)
	await _press(&"use")
	await _wait(0.8)
	_check(balloon.is_open(), "柜子上的收音机能用")
	await _press(&"use")
	await _wait(0.8)
	await _shot("09b_radio")
	for i in 6:
		if not balloon.is_open():
			break
		await _press(&"use")
		await _wait(0.12)
	_check(not balloon.is_open(), "收音机的对话能结束")

	# ---- 桌子：带选项的对话
	player.place(GameMap.tile_center(Vector2i(7, 5)), GameMap.Facing.UP)
	await _wait(0.2)
	await _press(&"use")
	await _wait(0.8)
	for i in 3:
		await _press(&"use")
		await _wait(0.5)
	await _shot("10_choices")
	await _press(&"ui_accept")
	await _wait(0.3)
	for i in 6:
		if not balloon.is_open():
			break
		await _press(&"use")
		await _wait(0.12)
	_check(not balloon.is_open(), "带选项的对话能结束")

	# ---- 睡觉
	player.place(GameMap.tile_center(Vector2i(3, 3)), GameMap.Facing.LEFT)
	await _wait(0.2)
	await _press(&"use")
	await _wait(0.6)
	await _press(&"use")
	await _wait(0.3)
	await _shot("11_bed_prompt")
	await _press(&"ui_accept")
	await _wait(2.6)
	_check(GameClock.day == 2, "睡到了第 2 天")
	_check(SaveSystem.has_save(0), "睡觉时写了存档")
	_check(Farming.state.crop_days_at(field) == 1, "浇过水的作物长了一天")
	_check(not Farming.state.soil.get(field, true), "过夜后土地变干")
	await _shot("12_day2")

	# ---- 出门
	# 直接站到门垫正上方再往下走，不依赖家具之间的走位
	player = game.get(&"player")
	player.place(GameMap.tile_center(Vector2i(5, 5)), GameMap.Facing.DOWN)
	await _wait(0.2)
	Input.action_press(&"move_down")
	await _wait(1.2)
	Input.action_release(&"move_down")
	await _wait(0.8)
	_check(GameState.map_id == &"farm", "走到门垫出了屋")
	await _shot("13_outside_day2")

	# ---- 让作物成熟并收获
	for i in 5:
		Farming.state.water(field)
		Farming.state.advance_day()
	_check(Farming.state.is_ripe(field), "浇够天数后成熟")
	player = game.get(&"player")
	player.place(GameMap.tile_center(field + Vector2i(0, -1)), GameMap.Facing.DOWN)
	await _wait(0.3)
	await _shot("14_ripe")
	await _press(&"use")
	await _strip(player, "harvest", 6, 0.06)
	await _wait(0.5)
	_check(GameState.inventory.count_of(&"white_radish") == 1, "收获了一个白萝卜")

	# ---- 出货箱
	_hold(&"white_radish")
	player.place(GameMap.tile_center(Vector2i(12, 8)), GameMap.Facing.UP)
	await _wait(0.3)
	await _press(&"use")
	await _wait(0.4)
	await _shot("14b_shipping")
	_check(Shipping.count_of(&"white_radish") == 1, "白萝卜放进了出货箱")
	_check(GameState.inventory.count_of(&"white_radish") == 0, "背包里的白萝卜没了")

	# ---- 升级后的工具：按住蓄力，松开一次开垦多格
	GameState.upgrade_tool(&"hoe")
	GameState.upgrade_tool(&"hoe")
	GameState.selected_slot = 0
	player.place(GameMap.tile_center(Vector2i(16, 10)), GameMap.Facing.RIGHT)
	await _wait(0.3)
	var soil_before := Farming.state.soil.size()
	energy_before = GameState.energy
	Input.action_press(&"use")
	await _wait(1.3)
	await _shot("14c_charge")
	_check(Farming.state.soil.size() == soil_before, "蓄力时还没动手")
	Input.action_release(&"use")
	await _wait(0.9)
	_check(Farming.state.soil.size() == soil_before + 5, "银锄头蓄满一次开垦 5 格")
	_check(Farming.state.is_tilled(Vector2i(21, 10)), "最远开垦到第 5 格")
	_check(GameState.energy < energy_before - 2, "蓄力多花体力")

	# ---- 施肥
	GameState.inventory.add(&"fertilizer", 1)
	_hold(&"fertilizer")
	await _press(&"use")
	await _wait(0.6)
	_check(Farming.state.fert_at(Vector2i(17, 10)) == 1, "给耕地施了肥")
	_check(GameState.inventory.count_of(&"fertilizer") == 0, "肥料用掉了")
	await _shot("14d_fertilized")

	# ---- 铁锹：从池塘边挖水渠，水渠边开垦出来的地是湿的，再放水成水田
	GameState.inventory.add(&"shovel")
	_hold(&"shovel")
	player.place(GameMap.tile_center(Vector2i(28, 16)), GameMap.Facing.DOWN)
	await _wait(0.3)
	await _press(&"use")
	await _wait(0.9)
	_check(Farming.state.is_flooded(Vector2i(28, 17)), "池塘边挖的水渠里有水")
	player.place(GameMap.tile_center(Vector2i(28, 14)), GameMap.Facing.DOWN)
	GameState.selected_slot = 0
	await _wait(0.3)
	await _press(&"use")
	await _wait(0.9)
	_check(Farming.state.is_wet(Vector2i(28, 15)), "水渠旁边开垦出来的地是湿的")
	_hold(&"shovel")
	await _press(&"use")
	await _wait(0.9)
	_check(Farming.state.is_paddy(Vector2i(28, 15)), "用铁锹放水成了水田")

	# ---- 采集：开局农场上就有几份野菜，面对着按一下就捡起来
	var map: GameMap = game.get(&"map")
	var wild: Dictionary = Foraging.items.get(&"farm", {})
	_check(not wild.is_empty(), "农场上长出了采集物")
	if not wild.is_empty():
		var wild_tile: Vector2i = wild.keys()[0]
		var wild_id: StringName = wild[wild_tile]
		var had := GameState.inventory.count_of(wild_id)
		player.place(GameMap.tile_center(wild_tile + Vector2i(0, -1)), GameMap.Facing.DOWN)
		GameState.selected_slot = 0
		await _wait(0.3)
		await _shot("14g_forage")
		await _press(&"use")
		await _wait(0.6)
		_check(GameState.inventory.count_of(wild_id) == had + 1, "捡到了采集物")
		_check(Foraging.item_at(&"farm", wild_tile) == &"", "捡过的地方空了")

	# ---- 果树：在田地南边找几块空地，亲手种一棵，其余几棵直接放下去
	var spots: Array[Vector2i] = []
	for y in range(20, 26):
		for x in range(14, 30):
			var t := Vector2i(x, y)
			var near := false
			for o in spots:
				if absi(o.x - x) < 3 and absi(o.y - y) < 3:
					near = true
			if not near and spots.size() < 4 and bool(map.call(&"_can_plant_tree", t)):
				spots.append(t)
	_check(spots.size() == 4, "田地南边有地方种树")
	GameState.inventory.add(&"peach_sapling", 1)
	_hold(&"peach_sapling")
	player.place(GameMap.tile_center(spots[0] + Vector2i(0, -1)), GameMap.Facing.DOWN)
	await _wait(0.3)
	await _press(&"use")
	await _wait(0.6)
	_check(Farming.orchard.kind_at(spots[0]) == &"peach", "种下了桃树苗")
	_check(GameState.inventory.count_of(&"peach_sapling") == 0, "树苗用掉了")
	await _shot("14h_sapling")
	var kinds: Array[StringName] = [&"loquat", &"persimmon", &"mandarin"]
	for i in 3:
		Farming.orchard.plant(spots[i + 1], kinds[i])
	for i in 26:
		Farming.orchard.advance_day(&"spring")
	_check(Farming.orchard.ready_at(spots[0]) > 0, "长成的桃树春天开花")
	player.place(GameMap.tile_center(spots[0] + Vector2i(0, 1)), GameMap.Facing.UP)
	await _wait(0.3)
	await _shot("14i_orchard_0")
	GameState.selected_slot = 0
	await _press(&"use")
	await _wait(0.6)
	_check(GameState.inventory.count_of(&"peach_blossom") == 3, "收了三枝桃花")
	_check(Farming.orchard.ready_at(spots[0]) == 0, "树上的花收完了")
	player.place(GameMap.tile_center(Vector2i(42, 20)), GameMap.Facing.RIGHT)
	await _wait(0.3)
	await _shot("14j_stream")

	# ================================================================ M4 后半
	Weather.today = Weather.SUNNY
	GameClock.minutes = 620.0
	GameState.money += 30000
	GameState.energy = 100
	var ranch: OutdoorMap = game.get(&"map")

	# ---- 加工设备：在石叔那儿买下，放两棵小白菜进腌缸，两天后收腌菜
	for e in Shop.entries(GameClock.season_id(), Shop.SMITH):
		if e.flag != &"":
			Shop.buy_entry(e, 1)
	Crafting.changed.emit()
	_check(Crafting.owned(&"pickle_vat") and Crafting.owned(&"silk_reel"), "石叔的设备买得到")
	_check(not Crafting.owned(&"cheese_rack"), "奶酪架要等牧野灯")
	GameState.inventory.add(&"bok_choy", 2)
	_hold(&"bok_choy")
	player.place(GameMap.tile_center(Vector2i(13, 6)), GameMap.Facing.UP)
	await _wait(0.3)
	_check(ranch.query_use(GameState.selected_item(), player.target_tile(), player.facing) == &"tend", "拿着小白菜对着腌缸能放")
	await _press(&"use")
	await _wait(0.8)
	_check(Crafting.state(&"pickle_vat") == Crafting.WORKING, "小白菜放进了腌缸")
	Crafting._on_new_day()
	Crafting._on_new_day()
	player.place(GameMap.tile_center(Vector2i(17, 7)), GameMap.Facing.UP)
	await _wait(0.4)
	await _shot("14l_machines")
	player.place(GameMap.tile_center(Vector2i(13, 6)), GameMap.Facing.UP)
	await _wait(0.3)
	await _press(&"use")
	await _wait(0.8)
	_check(GameState.inventory.count_of(&"pickles") == 1, "两天后收了腌菜")
	# 空着的榨油机：说明那句很长，提示条要折成两行
	GameState.selected_slot = 0
	player.place(GameMap.tile_center(Vector2i(17, 6)), GameMap.Facing.UP)
	await _wait(1.6)
	await _press(&"use")
	await _wait(0.5)
	await _shot("14l2_long_banner")
	await _wait(1.2)

	# ---- 稻草人和乌鸦
	var scare_spot := Vector2i(-1, -1)
	for y in range(27, 33):
		for x in range(8, 16):
			if scare_spot.x < 0 and bool(ranch.call(&"_can_plant_tree", Vector2i(x, y))) and not ranch.blocked(GameMap.tile_center(Vector2i(x, y - 1))):
				scare_spot = Vector2i(x, y)
	_check(scare_spot.x >= 0, "农场上有地方立稻草人")
	GameState.inventory.add(&"scarecrow", 1)
	_hold(&"scarecrow")
	player.place(GameMap.tile_center(scare_spot + Vector2i(0, -1)), GameMap.Facing.DOWN)
	await _wait(0.3)
	await _press(&"use")
	await _wait(0.8)
	_check(Farming.has_scarecrow(scare_spot), "立起了稻草人")
	await _shot("14m_scarecrow")
	GameClock.minutes = 480.0
	var raided: Array[Vector2i] = [Vector2i(18, 11), Vector2i(20, 12)]
	Farming.raided = raided
	ranch.call(&"_spawn_crows")
	player.place(GameMap.tile_center(Vector2i(25, 14)), GameMap.Facing.LEFT)
	await _wait(0.8)
	var crows: Array = ranch.get(&"_crows")
	_check(crows.size() == 2, "早上被刨过的地里站着乌鸦")
	await _shot("14m2_crows")
	player.place(GameMap.tile_center(Vector2i(19, 11)), GameMap.Facing.LEFT)
	await _wait(0.3)
	crows = ranch.get(&"_crows")
	_check(crows.size() == 0, "人走近乌鸦就飞了")
	await _wait(0.9)
	Farming.raided.clear()

	# ---- 第二幕：西边的雾里摸到花花的牛铃
	GameState.set_flag(&"bell_hint")
	GameClock.minutes = 840.0
	game.call(&"_load_map", &"town", &"from_farm")
	await _wait(0.6)
	player.place(GameMap.tile_center(Vector2i(2, 18)), GameMap.Facing.LEFT)
	await _wait(0.4)
	await _shot("14n_west_fog")
	await _press(&"use")
	await _wait(0.8)
	_check(GameState.inventory.count_of(&"cowbell") == 1, "阿牧提过以后，在西边的雾里摸到了牛铃")
	_check(balloon.is_open(), "摸到牛铃有一段旁白")
	for i in 12:
		if not balloon.is_open():
			break
		await _press(&"use")
		await _wait(0.2)

	# ---- 牧野灯：供上东西，点灯，雾散
	GameState.inventory.add(&"egg", 4)
	GameState.inventory.add(&"duck_egg", 2)
	GameState.inventory.add(&"corn", 3)
	GameState.inventory.add(&"bayberry", 3)
	player.place(GameMap.tile_center(Vector2i(3, 19)), GameMap.Facing.DOWN)
	await _wait(0.4)
	await _press(&"use")
	await _wait(0.4)
	var west_lamp_panel: LampPanel = game.get(&"lamp_panel")
	_check(west_lamp_panel.is_open(), "对着牧野灯按使用打开灯座")
	await _shot("14o_pasture_lamp_panel")
	for i in 5:
		await _press(&"use")
		await _press(&"move_down")
		await _wait(0.1)
	_check(Lamps.is_complete(&"pasture"), "牧野灯的供品都供上了")
	await _press(&"use")
	await _wait(0.5)
	_check(Lamps.is_lit(&"pasture"), "牧野灯点亮了")
	await _shot("14o2_pasture_lamp_lit")
	await _wait(1.8)
	_check(balloon.is_open(), "牧野灯亮了有一段旁白")
	for i in 12:
		if not balloon.is_open():
			break
		await _press(&"use")
		await _wait(0.2)

	# ---- 往西走上北坡牧场
	player.place(GameMap.tile_center(Vector2i(3, 18)) + Vector2(0, 8), GameMap.Facing.LEFT)
	await _wait(0.3)
	Input.action_press(&"move_left")
	for i in 40:
		if GameState.map_id == &"pasture":
			break
		await _wait(0.1)
	Input.action_release(&"move_left")
	await _until_idle()
	await _wait(0.6)
	_check(GameState.map_id == &"pasture", "灯亮了以后往西走到了北坡牧场")
	await _shot("14p_pasture_gate")
	var pasture: OutdoorMap = game.get(&"map")
	var herd: Array = pasture.get(&"_herd")
	_check(herd.size() == 7, "阿牧的牲口白天在外面")
	player.place(GameMap.tile_center(Vector2i(19, 16)), GameMap.Facing.LEFT)
	await _wait(0.5)
	await _shot("14q_pasture_paddock")
	_check(pasture.npc_at(Vector2i(18, 16)) != null, "下午阿牧站在草场口")
	await _press(&"use")
	await _wait(1.0)
	_check(balloon.is_open(), "在牧场和阿牧搭上了话")
	await _shot("14q2_amu")
	for i in 20:
		if not balloon.is_open():
			break
		await _press(&"use")
		await _wait(0.2)
	_check(not balloon.is_open(), "阿牧的话能说完")
	player.place(GameMap.tile_center(Vector2i(13, 13)), GameMap.Facing.UP)
	await _wait(0.5)
	await _shot("14r_pasture_barn")
	if herd.size() > 0:
		await _strip(herd[0], "buffalo", 8, 0.15)
		await _strip(herd[1], "goat", 8, 0.15)
		await _strip(herd[3], "sheep", 8, 0.15)

	# ---- 畜棚、蚕房、蜂场：盖好，买齐，牵牛犁地
	GameClock.minutes = 620.0
	game.call(&"_load_map", &"farm", &"house_door")
	await _wait(0.6)
	ranch = game.get(&"map")
	_check(Animals.order("barn") and Animals.order("silk_house") and Animals.order("apiary"), "牧野灯亮了以后三栋都能订")
	for i in 5:
		Animals.settle(false)
	_check(Animals.buy("goat") and Animals.buy("sheep") and Animals.buy("buffalo") and Animals.buy("bee") and Animals.buy("silkworm"), "羊、牛、蜂、蚕都买到了")
	await _wait(1.5)
	player.place(GameMap.tile_center(Vector2i(21, 28)), GameMap.Facing.UP)
	await _wait(0.5)
	await _shot("14s_barn")
	player.place(GameMap.tile_center(Vector2i(9, 23)), GameMap.Facing.UP)
	await _wait(0.5)
	await _shot("14s2_silk_house")
	player.place(GameMap.tile_center(Vector2i(37, 29)), GameMap.Facing.UP)
	await _wait(0.5)
	await _shot("14s3_apiary")
	var cow: Critter = null
	for c: Critter in ranch.get(&"_critters"):
		if c.def.plows:
			cow = c
	_check(cow != null, "水牛白天在畜棚前")
	if cow != null:
		Animals.pet(cow.index)
		ranch.call(&"_toggle_lead", cow)
		_check(ranch.get(&"_led") == cow, "喂过摸过再拍一下，牛跟着走")
		_hold(&"hoe")
		var tilled_before := Farming.state.soil.size()
		var row: Array[Vector2i] = []
		for dy in range(-1, 4):
			for facing: int in [GameMap.Facing.RIGHT, GameMap.Facing.LEFT]:
				if row.size() > 2:
					continue
				var stand := GameMap.tile_of(cow.position) + Vector2i(1, dy)
				if ranch.blocked(GameMap.tile_center(stand)):
					continue
				player.place(GameMap.tile_center(stand), facing)
				row = ranch.plow_row(player.target_tile(), facing)
		_check(row.size() > 2, "牵着牛，面前有一行能开的地")
		await _wait(0.3)
		# 畜棚前别的牲口也在乱走，没摸过的晃到面前，这一下按规则是摸它：请到一边去。牛自己挡着不要紧
		var front := GameMap.tile_center(player.target_tile())
		for c: Critter in ranch.get(&"_critters"):
			if c != cow and c.position.distance_to(front) < 30.0:
				c.position += Vector2(0, 64)
		row = ranch.plow_row(player.target_tile(), player.facing)
		var plow_dbg := "动作 %s，行长 %d，牛离人 %d 像素，还能犁 %d 行" % [
			ranch.query_use(GameState.selected_item(), player.target_tile(), player.facing), row.size(),
			int(cow.position.distance_to(player.position)), Animals.plows_left(cow.index)]
		await _press(&"use")
		await _wait(1.0)
		await _until_free()
		_check(row.size() > 1 and Farming.state.soil.size() == tilled_before + row.size(), "一锄头开了一整行（%s，开了 %d 格）" % [plow_dbg, Farming.state.soil.size() - tilled_before])
		await _shot("14t_plow")
		await _strip(cow, "led_buffalo", 8, 0.15)

	# ---- 灶台：做一碗萝卜汤，吃掉回体力
	game.call(&"_load_map", &"farmhouse", &"door")
	await _wait(0.6)
	GameState.inventory.add(&"white_radish", 2)
	player.place(GameMap.tile_center(Vector2i(10, 3)), GameMap.Facing.UP)
	await _wait(0.3)
	await _press(&"use")
	await _wait(0.5)
	var cook_panel: CookPanel = game.get(&"cook_panel")
	_check(cook_panel.is_open(), "对着灶台按使用打开菜谱")
	await _shot("14u_cook")
	var soup_before := GameState.inventory.count_of(&"radish_soup")
	await _press(&"use")
	await _wait(0.3)
	_check(GameState.inventory.count_of(&"radish_soup") == soup_before + 1, "做了一碗萝卜汤")
	await _press(&"inventory")
	await _wait(0.3)
	_check(not cook_panel.is_open(), "菜谱能关上")
	_hold(&"radish_soup")
	GameState.energy = 50
	player.place(GameMap.tile_center(Vector2i(6, 6)), GameMap.Facing.DOWN)
	await _wait(0.3)
	await _press(&"use")
	await _wait(0.4)
	_check(GameState.energy == 80, "吃了萝卜汤回 30 体力")
	_check(GameState.inventory.count_of(&"radish_soup") == soup_before, "汤吃掉了")
	await _shot("14v_eat")
	# 带效果的菜：时钟下面多一小条，写着还剩多久
	GameState.inventory.add(&"egg_fried_rice", 1)
	_hold(&"egg_fried_rice")
	await _wait(0.3)
	await _press(&"use")
	await _wait(0.4)
	_check(GameState.buff_active(&"hearty"), "吃了蛋炒饭干活省力")
	_check(GameState.buff_text() != "", "界面上有剩余时间")
	await _wait(1.6)
	await _shot("14v2_buff")
	await _wait(0.5)
	game.call(&"_load_map", &"farm", &"house_door")
	await _wait(0.6)

	# ---- 四季的农场；夏天在水田里种稻
	for d: int in [30, 55, 80]:
		GameClock.day = d
		# 果树过三天（最后一天刮大风），看当季的果子和落果
		for i in 3:
			Farming.orchard.advance_day(GameClock.season_id(), i == 2)
		game.call(&"_load_map", &"farm", &"house_door")
		await _wait(0.6)
		if d == 30:
			GameState.inventory.add(&"rice_seed", 1)
			_hold(&"rice_seed")
			player.place(GameMap.tile_center(Vector2i(28, 14)), GameMap.Facing.DOWN)
			await _wait(0.3)
			await _press(&"use")
			await _wait(0.6)
			_check(Farming.state.crop_id_at(Vector2i(28, 15)) == &"rice", "水田里种下了水稻")
			await _shot("14e_paddy")
			player.place(GameMap.tile_center(Vector2i(16, 13)), GameMap.Facing.DOWN)
			await _wait(0.3)
		await _shot("14f_season_%d" % GameClock.season())
		player.place(GameMap.tile_center(spots[0] + Vector2i(0, 1)), GameMap.Facing.UP)
		await _wait(0.3)
		await _shot("14i_orchard_%d" % GameClock.season())

	# ---- 冬天的镇广场
	GameClock.minutes = 600.0
	game.call(&"_load_map", &"town", &"from_farm")
	await _wait(0.6)
	player.place(GameMap.tile_center(Vector2i(22, 18)), GameMap.Facing.UP)
	await _wait(0.5)
	await _shot("14k_town_winter")

	# ---- 第三幕：牧野灯亮了北边的雾还在；老秦给钥匙，点井口灯，雾才散
	GameState.set_flag(&"lamp_pasture")
	GameState.energy = GameState.max_energy
	GameClock.minutes = 990.0
	game.call(&"_load_map", &"town", &"from_farm")
	await _wait(0.6)
	town = game.map
	GameState.selected_slot = 0
	player.place(GameMap.tile_center(Vector2i(13, 2)), GameMap.Facing.UP)
	await _wait(0.3)
	_check(town.trigger_at(Vector2i(13, 0)).is_empty(), "牧野灯亮了，北边的路还走不通")
	await _press(&"use")
	await _wait(0.4)
	_check(GameState.has_flag(&"well_warned"), "对着北边的雾按使用，被老秦喝住")
	await _shot("16a_north_fog")
	var qin_npc: Npc = town.call(&"_npc_of", &"laoqin")
	_check(qin_npc != null, "傍晚老秦在茶馆门口")
	if qin_npc != null:
		Residents.met[&"laoqin"] = true
		Residents.add_familiarity(&"laoqin", 60)
		player.place(GameMap.tile_center(qin_npc.tile() + Vector2i(0, 1)), GameMap.Facing.UP)
		await _wait(0.4)
		await _press(&"use")
		await _wait(1.4)
		await _shot("16b_laoqin_key")
		for i in 20:
			if not balloon.is_open():
				break
			await _press(&"use")
			await _wait(0.12)
		_check(GameState.inventory.count_of(&"well_key") == 1, "老秦把井口的钥匙给了出来")
	GameState.inventory.add(&"sweet_potato", 4)
	GameState.inventory.add(&"chestnut", 3)
	GameState.inventory.add(&"hawthorn", 3)
	GameState.inventory.add(&"perch", 2)
	player.place(GameMap.tile_center(Vector2i(15, 8)), GameMap.Facing.UP)
	await _wait(0.4)
	await _shot("16c_well_lamp")
	await _press(&"use")
	await _wait(0.4)
	_check(lamp_panel.is_open(), "对着井口灯按使用打开灯座")
	await _shot("16d_well_lamp_panel")
	for i in 5:
		await _press(&"use")
		await _press(&"move_down")
		await _wait(0.1)
	_check(Lamps.is_complete(&"well"), "井口灯的供品和钥匙都供上了")
	await _press(&"use")
	await _wait(0.5)
	_check(Lamps.is_lit(&"well"), "井口灯点亮了")
	await _wait(1.8)
	_check(balloon.is_open(), "点井口灯以后有一段旁白")
	for i in 12:
		if not balloon.is_open():
			break
		await _press(&"use")
		await _wait(0.12)
	await _shot("16e_well_lamp_lit")
	_check(not town.trigger_at(Vector2i(13, 0)).is_empty(), "井口灯亮了，北边的路通了")

	# ---- 沉灯井：顺着北边的路到井口；拿镐子、下井、敲石头、点井灯、坐升降机
	GameClock.minutes = 600.0
	player.place(GameMap.tile_center(Vector2i(13, 2)) + Vector2(8, 0), GameMap.Facing.UP)
	await _wait(0.3)
	Input.action_press(&"move_up")
	for i in 40:
		if GameState.map_id == &"wellhead":
			break
		await _wait(0.1)
	Input.action_release(&"move_up")
	await _wait(0.8)
	_check(GameState.map_id == &"wellhead", "顺着北边的路走到了井口")
	GameState.selected_slot = 0
	player.place(GameMap.tile_center(Vector2i(12, 8)) + Vector2(8, 0), GameMap.Facing.UP)
	await _wait(0.4)
	_check(game.map.call(&"_npc_of", &"laoqin") != null, "井口灯亮了，老秦守在井口")
	await _shot("17a_wellhead")
	player.place(GameMap.tile_center(Vector2i(12, 7)), GameMap.Facing.UP)
	await _wait(0.3)
	await _press(&"use")
	await _wait(0.4)
	_check(GameState.inventory.count_of(&"pickaxe") == 1, "在洞口拿到了镐子")
	_check(GameState.inventory.count_of(&"old_sickle") == 1, "镰刀也一起拿上了")
	_check(game.hud.health_shown(), "到了井口，生命条露出来")
	await _press(&"use")
	for i in 30:
		if GameState.map_id == &"mine":
			break
		await _wait(0.1)
	await _wait(0.8)
	_check(GameState.map_id == &"mine" and Mine.floor_no == 1, "顺着梯子下到了第 1 层")
	await _shot("17b_mine_floor_1")
	# 换到第 5 层（固定种子），敲一块石头、点井灯
	# 这一段只看敲石头和点灯，忘形先清掉，免得撞过来把人挤开
	Mine.enter(5, 77)
	Mine.current.monsters.clear()
	game.call(&"_load_map", &"mine", &"ladder")
	await _wait(0.6)
	var level: MineFloor = Mine.current
	_hold(&"pickaxe")
	var rock_tile := MineFloor.NONE
	for t: Vector2i in level.rocks:
		if level.rocks[t] == &"stone" and t != level.ladder and rock_tile == MineFloor.NONE and _stand_facing(player, level, t):
			rock_tile = t
	_check(rock_tile != MineFloor.NONE, "找到一块够得着的石头")
	await _wait(0.3)
	_check(game.map.query_use(GameState.selected_item(), player.target_tile(), player.facing) == &"mine", "拿着镐子对着石头是敲")
	var energy_in_mine := GameState.energy
	await _press(&"use")
	await _strip(player, "mine", 8, 0.05)
	await _until_free()
	_check(not level.has_rock(rock_tile), "一镐子敲开了石头")
	_check(GameState.inventory.count_of(&"stone") == 1, "石头进了背包")
	_check(GameState.energy < energy_in_mine, "敲石头花体力")
	_check(_stand_facing(player, level, level.lamp), "走得到井灯跟前")
	await _wait(0.3)
	await _press(&"use")
	await _wait(0.5)
	_check(Mine.lamp_lit(5), "点亮了第 5 层的井灯")
	await _shot("17c_mine_floor_5")
	# 顺着梯子回井口，再坐升降机下来
	player.place(GameMap.tile_center(level.spawn), GameMap.Facing.UP)
	await _wait(0.3)
	await _press(&"use")
	for i in 30:
		if GameState.map_id == &"wellhead":
			break
		await _wait(0.1)
	await _wait(0.8)
	_check(GameState.map_id == &"wellhead" and Mine.floor_no == 0, "顺着梯子回到了井口")
	player.place(GameMap.tile_center(Vector2i(17, 8)), GameMap.Facing.UP)
	await _wait(0.3)
	await _press(&"use")
	for i in 30:
		if GameState.map_id == &"mine":
			break
		await _wait(0.1)
	await _wait(0.8)
	_check(GameState.map_id == &"mine" and Mine.floor_no == 5, "升降机直接下到了第 5 层")
	await _shot("17d_lift_floor_5")

	# ---- 井里打起来：镰刀砍尘团、翻滚、挨打、晕倒被背回井口
	GameState.energy = GameState.max_energy
	GameState.health = GameState.max_health
	var fight_dir := _arena(&"dust", 2)
	_check(fight_dir >= 0, "找到一块能摆开打的空地")
	game.call(&"_load_map", &"mine", &"ladder")
	level = Mine.current
	player.place(GameMap.tile_center(level.spawn), fight_dir as GameMap.Facing)
	_hold(&"old_sickle")
	await _wait(0.2)
	_check(game.map.query_use(GameState.selected_item(), player.target_tile(), player.facing) == &"attack", "拿着镰刀是挥砍")
	await _shot("18a_mine_fight")
	await _press(&"use")
	await _strip(player, "slash", 6, 0.04)
	_check(level.monsters_left() == 1 and level.monsters[0].hp < level.monsters[0].def.hp, "第一下砍掉了尘团一截生命")
	await _shot("18a2_mine_bar")
	for i in 12:
		if level.monsters_left() == 0:
			break
		await _press(&"use")
		await _wait(0.2)
	_check(level.monsters_left() == 0, "几下镰刀打倒了尘团")
	await _until_free()
	# 翻滚：花体力，人滚出去一截
	GameState.health = GameState.max_health
	player.place(GameMap.tile_center(level.spawn), fight_dir as GameMap.Facing)
	await _wait(0.2)
	var roll_from := player.position
	var energy_before_roll := GameState.energy
	await _press(&"roll")
	await _strip(player, "roll", 6, 0.04)
	await _wait(0.4)
	_check(GameState.energy == energy_before_roll - 3, "翻滚花了 3 点体力（实际 %d）" % (energy_before_roll - GameState.energy))
	_check(player.position.distance_to(roll_from) > 12.0, "人滚出去了")
	_check(not game.map.blocked(player.position), "没滚进墙里")
	# 一只尘团贴过来：挨一下，生命掉了
	_check(_arena(&"dust", 1) >= 0, "又摆了一只尘团")
	game.call(&"_load_map", &"mine", &"ladder")
	level = Mine.current
	for i in 50:
		if GameState.health < GameState.max_health:
			break
		await _wait(0.1)
	_check(GameState.health < GameState.max_health, "尘团撞到人，生命掉了")
	await _shot("18b_mine_hurt")

	# ---- 往深处：水渍层、遗落层各看一眼
	GameState.health = GameState.max_health
	Mine.enter(14, 31)
	game.call(&"_load_map", &"mine", &"ladder")
	await _wait(0.4)
	_check(Mine.current.water.size() > 0, "水渍层地上有水")
	await _shot("18d_mine_waterlogged")
	Mine.enter(24, 31)
	game.call(&"_load_map", &"mine", &"ladder")
	await _wait(0.4)
	_check(Mine.current.props.size() > 0, "遗落层里有被忘掉的东西")
	await _shot("18e_mine_forgotten")
	# 第 10 层：废矿车。站在西墙根等它冲过来撞墙，晕了再打
	GameState.health = GameState.max_health
	Mine.enter(10, 1)
	game.call(&"_load_map", &"mine", &"ladder")
	level = Mine.current
	var cart := level.boss
	_check(cart != null and bool(game.map.call(&"boss_bar_shown")), "第 10 层是首领房，屏幕顶上有首领的血条")
	player.place(GameMap.tile_center(Vector2i(3, 7)), GameMap.Facing.RIGHT)
	await _wait(0.3)
	await _shot("18f_cart_arena")
	for i in 150:
		if cart.state == MineMonster.State.STUNNED:
			break
		await _wait(0.1)
	_check(cart.state == MineMonster.State.STUNNED, "矿车冲过来撞上墙，晕了")
	await _shot("18g_cart_stunned")
	_check(not level.ladder_found, "首领还在，往下的梯子不露")
	cart.hp = 1
	GameState.health = GameState.max_health
	player.place(cart.pos + Vector2(18, 0), GameMap.Facing.LEFT)
	_hold(&"old_sickle")
	await _wait(0.9)
	await _until_use_released()
	await _press(&"use")
	await _wait(0.6)
	_check(not level.boss_alive() and Mine.bosses.has(10), "趁它晕着打倒了矿车")
	_check(GameState.inventory.count_of(&"rail_hammer") == 1, "矿车掉了道钉锤")
	_check(level.ladder_found and not bool(game.map.call(&"boss_bar_shown")), "往下的梯子露出来，血条收掉")
	await _shot("18h_cart_down")
	await _until_free()
	# 背包这时候快满了：腾出几格，首领留下的东西才放得进（放不下会先欠着，那条路单元测试里测过）
	var keep: Array[StringName] = [&"rod", &"old_sickle", &"pickaxe", &"stone", &"rail_hammer", &"fishbone_sickle"]
	var freed := 0
	for i in range(GameState.inventory.size - 1, -1, -1):
		if freed >= 6:
			break
		if GameState.inventory.is_empty_slot(i):
			freed += 1
		elif not keep.has(GameState.inventory.id_at(i)) and Database.item(GameState.inventory.id_at(i)).kind != &"tool":
			GameState.inventory.remove_at(i, GameState.inventory.count_at(i))
			freed += 1
	# 第 20 层：井底老鲶。对着水池甩竿，它咬钩，遛上岸再打
	GameState.health = GameState.max_health
	GameState.energy = GameState.max_energy
	# 先当作没带鱼竿：岸边有一根旧的，手里不拿武器对着水池就能甩
	var rods_owned := GameState.inventory.count_of(&"rod")
	GameState.inventory.remove(&"rod", rods_owned)
	Mine.enter(20, 1)
	game.call(&"_load_map", &"mine", &"ladder")
	player.place(GameMap.tile_center(Vector2i(7, 7)), GameMap.Facing.RIGHT)
	_hold(&"pickaxe")
	await _wait(0.3)
	_check(bool(game.map.call(&"spare_rod")), "没带鱼竿，水池边有一根旧竿")
	_check(game.map.query_use(GameState.selected_item(), player.target_tile(), player.facing) == &"cast", "没带鱼竿也能对着水池甩竿")
	await _shot("18i0_spare_rod")
	GameState.inventory.add(&"rod", rods_owned)
	Mine.enter(20, 1)
	game.call(&"_load_map", &"mine", &"ladder")
	level = Mine.current
	var catfish := level.boss as MineCatfish
	player.place(GameMap.tile_center(Vector2i(7, 7)), GameMap.Facing.RIGHT)
	_hold(&"rod")
	catfish._wary = 0.0
	await _wait(0.2)
	_check(game.map.query_use(GameState.selected_item(), player.target_tile(), player.facing) == &"cast", "拿着鱼竿对着水池能甩竿")
	await _until_use_released()
	await _press(&"use")
	await _wait(1.4)
	_check(fishing.phase == FishingSession.Phase.WAITING and catfish.lured, "线甩进了水池，老鲶看见了")
	for i in 80:
		if catfish.at_bait():
			break
		await _wait(0.1)
	_check(catfish.at_bait(), "老鲶游到了浮漂底下")
	await _shot("18i_catfish_bait")
	fishing._timer = 0.2
	await _wait(0.4)
	_check(fishing.phase == FishingSession.Phase.BITE and fishing.fish != null and fishing.fish.id == &"old_well_catfish", "咬钩的是老鲶")
	await _press(&"use")
	await _wait(0.1)
	for i in 3000:
		if fishing.phase != FishingSession.Phase.FIGHT:
			break
		var cf: FishFight = fishing.fight
		if cf != null and not cf.struggling and not cf.warning and cf.tension < 0.6:
			Input.action_press(&"use")
		else:
			Input.action_release(&"use")
		await get_tree().process_frame
	Input.action_release(&"use")
	_check(catfish.state == MineMonster.State.STUNNED and not fishing.active(), "遛赢了，老鲶被拉上岸")
	_check(GameState.inventory.count_of(&"old_well_catfish") == 0, "首领不进背包")
	await _wait(0.2)
	await _shot("18j_catfish_ashore")
	catfish.hp = 1
	if absf(catfish.pos.y - player.position.y) > 4.0:
		player.place(player.position, GameMap.Facing.DOWN if catfish.pos.y > player.position.y else GameMap.Facing.UP)
	_hold(&"old_sickle")
	await _until_use_released()
	await _press(&"use")
	await _wait(0.6)
	_check(not level.boss_alive() and Mine.bosses.has(20), "趁它在岸上打倒了老鲶")
	_check(GameState.inventory.count_of(&"fishbone_sickle") == 1, "老鲶掉了鱼骨镰")
	_check(game.map.fishing_water(Vector2i(8, 7)) == &"mine_deep", "打倒以后水池里能钓深处的鱼")
	await _shot("18k_catfish_down")
	await _until_free()
	# 第 30 层：无名戏班。看它换一张脸、撒一圈纸钱，再打倒
	GameState.health = GameState.max_health
	Mine.enter(30, 1)
	game.call(&"_load_map", &"mine", &"ladder")
	level = Mine.current
	var troupe := level.boss as MineTroupe
	_check(troupe != null and bool(game.map.call(&"boss_bar_shown")), "第 30 层是无名戏班，有血条")
	player.place(GameMap.tile_center(Vector2i(5, 8)), GameMap.Facing.RIGHT)
	await _wait(0.3)
	await _shot("18l_troupe_arena")
	for i in 200:
		if troupe.skin() == &"white" and troupe.state == MineMonster.State.STRIKE:
			break
		GameState.health = GameState.max_health
		await _wait(0.05)
	_check(troupe.skin() == &"white", "戏班打完一轮换了一张脸")
	await _wait(0.5)
	_check(int(game.map.call(&"shot_count")) > 0, "白脸撒出了纸钱")
	await _shot("18m_troupe_white")
	troupe.hp = 1
	_hold(&"old_sickle")
	for attempt in 8:
		if not level.boss_alive():
			break
		GameState.health = GameState.max_health
		await _until_free()
		player.place(troupe.pos + Vector2(16, 0), GameMap.Facing.LEFT)
		await _until_use_released()
		await _press(&"use")
		await _wait(0.5)
	_check(not level.boss_alive() and Mine.bosses.has(30), "打倒了无名戏班")
	_check(GameState.inventory.count_of(&"opera_blade") == 1 and GameState.inventory.count_of(&"mask_shard") == 1, "戏班留下了戏刀和半张面具")
	await _until_free()
	# 饰品：拿在手里按使用键戴上
	GameState.health = GameState.max_health
	player.place(GameMap.tile_center(Vector2i(8, 8)), GameMap.Facing.DOWN)
	_hold(&"mask_shard")
	await _wait(0.2)
	await _until_use_released()
	await _press(&"use")
	await _wait(0.3)
	_check(Mine.wearing(&"mask_shard"), "按使用键戴上了半张面具")
	await _shot("18n_accessory_worn")
	# 无光层：整层是黑的，只有手里的灯照着一圈；拿着灯油按使用键添油
	Mine.enter(34, 31)
	Mine.current.monsters.clear()
	game.call(&"_load_map", &"mine", &"ladder")
	level = Mine.current
	await _wait(0.4)
	_check(level.dark and game.map.forced_tint().a > 0.0, "无光层是黑的")
	_check(bool(game.map.call(&"oil_bar_shown")), "无光层屏幕顶上有灯油的条")
	await _shot("18o_mine_dark")
	Mine.oil = 12.0
	await _wait(0.3)
	await _shot("18o2_mine_dark_low_oil")
	GameState.inventory.add(&"lamp_oil", 1)
	_hold(&"lamp_oil")
	for dir: GameMap.Facing in [GameMap.Facing.DOWN, GameMap.Facing.RIGHT, GameMap.Facing.LEFT, GameMap.Facing.UP]:
		player.place(player.position, dir)
		if game.map.query_use(GameState.selected_item(), player.target_tile(), player.facing) == &"":
			break
	await _wait(0.1)
	await _until_use_released()
	await _press(&"use")
	await _wait(0.3)
	_check(Mine.oil > 60.0 and GameState.inventory.count_of(&"lamp_oil") == 0, "拿着灯油按使用键添了油（现在 %d）" % int(Mine.oil))
	# 第 40 层：岚之影的考验。灯灭了从头再走；走到灯座就算完
	Mine.enter(40, 1)
	game.call(&"_load_map", &"mine", &"ladder")
	level = Mine.current
	await _wait(0.4)
	_check(Mine.trial_running() and Mine.oil > Mine.OIL_MAX - 2.0, "井底是岚之影的考验，进来灯是满的")
	_check(not bool(game.map.call(&"boss_bar_shown")), "岚之影没有血条")
	await _shot("18p_trial_start")
	player.place(GameMap.tile_center(Vector2i(12, 8)), GameMap.Facing.RIGHT)
	await _wait(1.2)
	await _shot("18p2_trial_midway")
	Mine.oil = 0.0
	await _wait(0.3)
	_check(GameMap.tile_of(player.position) == level.spawn and Mine.oil > Mine.OIL_MAX - 2.0 and Mine.trial_running(), "灯灭了：回到梯子底下，灯重新点满")
	player.place(GameMap.tile_center(level.altar + Vector2i(-1, 0)), GameMap.Facing.RIGHT)
	await _wait(0.2)
	await _until_use_released()
	await _press(&"use")
	await _wait(0.6)
	_check(not Mine.trial_running() and GameState.has_flag(&"boss_shade"), "把灯放上灯座，考验走完了")
	_check(GameState.inventory.count_of(&"lan_tassel") == 1, "得到了岚的灯穗")
	_check(game.map.forced_tint().a == 0.0, "井底亮了")
	await _wait(0.5)
	await _shot("18q_trial_done")
	await _until_free()
	GameState.health = GameState.max_health
	# 生命掉到 0：晕倒，回井口，这一趟得来的石头丢一半
	var stones_before := GameState.inventory.count_of(&"stone")
	GameState.inventory.add(&"stone", 4)
	Mine.haul[&"stone"] = 4
	var clock_before := GameClock.minutes
	GameState.hurt(999)
	for i in 60:
		if GameState.map_id == &"wellhead" and not game.is_locked():
			break
		await _wait(0.1)
	_check(GameState.map_id == &"wellhead" and Mine.floor_no == 0, "晕倒以后被背回了井口")
	_check(GameState.health == GameState.max_health / 2, "醒来生命回了一半（实际 %d）" % GameState.health)
	_check(GameState.inventory.count_of(&"stone") == stones_before + 2, "这一趟得来的石头丢了一半")
	_check(GameClock.minutes >= clock_before + 100.0, "醒来已经过去了两个钟头")
	await _shot("18c_fainted_wellhead")

	# ---- 第四幕：遗落层井灯底下的铁盒，姜婆婆认出相片，点东滩灯，去东滩
	# 背包先腾出八格（这一段的东西回标题以后不保存，后面读档不受影响）
	var bag_room := 0
	for i in range(GameState.inventory.size - 1, 9, -1):
		if bag_room >= 8:
			break
		if GameState.inventory.is_empty_slot(i):
			bag_room += 1
		elif Database.item(GameState.inventory._slots[i]["id"]).kind != &"tool":
			GameState.inventory._slots[i] = {}
			bag_room += 1
	GameState.health = GameState.max_health
	GameState.energy = GameState.max_energy
	GameState.selected_slot = 0
	Mine.enter(Mine.BOX_FLOOR, 7)
	game.call(&"_load_map", &"mine", &"ladder")
	await _wait(0.4)
	level = Mine.current
	level.monsters.clear()
	_check(_stand_facing(player, level, level.lamp), "站到第 25 层的井灯跟前")
	await _wait(0.3)
	await _press(&"use")
	await _wait(1.6)
	_check(Mine.lamp_lit(Mine.BOX_FLOOR), "第 25 层的井灯点亮了")
	_check(balloon.is_open(), "灯座底下的铁盒：有一段旁白")
	await _shot("19a_box")
	for i in 20:
		if not balloon.is_open():
			break
		await _press(&"use")
		await _wait(0.12)
	_check(GameState.inventory.count_of(&"miner_roster") == 1 and GameState.inventory.count_of(&"family_photo") == 1, "拿到了下井的名单和全家福")
	_check(not Mine.box_waiting(), "铁盒只有一只")
	Mine.leave()
	weather_was = Weather.today
	Weather.today = &"sunny"
	GameClock.minutes = 600.0
	game.call(&"_load_map", &"town", &"from_farm")
	await _wait(0.6)
	town = game.map
	GameState.selected_slot = 0
	var granny: Npc = town.call(&"_npc_of", &"jiang")
	_check(granny != null and not granny.is_walking(), "上午姜婆婆在药铺门口")
	if granny != null:
		player.place(GameMap.tile_center(granny.tile() + Vector2i(0, 1)), GameMap.Facing.UP)
		await _wait(0.4)
		await _press(&"use")
		await _wait(1.4)
		_check(balloon.is_open(), "带着全家福找姜婆婆，她开口了")
		await _shot("19b_jiang_photo")
		for i in 40:
			if not balloon.is_open():
				break
			await _press(&"use")
			await _wait(0.12)
		_check(GameState.inventory.count_of(&"ferry_stub") == 1, "姜婆婆把半张船票给了出来")
	GameState.inventory.add(&"potherb_mustard", 4)
	GameState.inventory.add(&"wintersweet", 3)
	GameState.inventory.add(&"silver_ore", 3)
	GameState.inventory.add(&"carp", 2)
	game.call(&"_load_map", &"riverbank", &"from_boat")
	await _wait(0.6)
	bank = game.map
	player.place(GameMap.tile_center(Vector2i(40, 16)), GameMap.Facing.RIGHT)
	await _wait(0.4)
	_check(bank.trigger_at(Vector2i(43, 16)).is_empty() and bank.blocked(GameMap.tile_center(Vector2i(42, 16))), "河岸往东的路被雾封着")
	await _shot("19c_east_fog")
	player.place(GameMap.tile_center(Vector2i(39, 16)), GameMap.Facing.UP)
	await _wait(0.3)
	await _press(&"use")
	await _wait(0.4)
	_check(lamp_panel.is_open(), "对着东滩灯按使用打开灯座")
	await _shot("19d_east_lamp_panel")
	for i in 5:
		await _press(&"use")
		await _press(&"move_down")
		await _wait(0.1)
	_check(Lamps.is_complete(&"east"), "东滩灯的供品和船票都供上了")
	await _press(&"use")
	await _wait(0.5)
	_check(Lamps.is_lit(&"east"), "东滩灯点亮了")
	await _wait(1.8)
	_check(balloon.is_open(), "点东滩灯以后有一段旁白")
	for i in 12:
		if not balloon.is_open():
			break
		await _press(&"use")
		await _wait(0.12)
	await _shot("19e_east_lamp_lit")
	_check(not bank.blocked(GameMap.tile_center(Vector2i(42, 16))), "东滩灯亮了，往东的雾散了")
	GameClock.minutes = 600.0
	player.place(GameMap.tile_center(Vector2i(41, 16)) + Vector2(0, 8), GameMap.Facing.RIGHT)
	await _wait(0.3)
	Input.action_press(&"move_right")
	for i in 40:
		if GameState.map_id == &"dongtan":
			break
		await _wait(0.1)
	Input.action_release(&"move_right")
	await _wait(0.8)
	_check(GameState.map_id == &"dongtan", "顺着河岸往东走到了东滩")
	await _until_idle()
	var beach: OutdoorMap = game.map
	await _shot("19f_dongtan_road")
	var painter: Npc = beach.call(&"_npc_of", &"egret")
	_check(painter != null, "东滩灯亮了，上午白鹭在滩上画画")
	player.place(GameMap.tile_center(Vector2i(26, 21)), GameMap.Facing.RIGHT)
	await _wait(0.5)
	await _shot("19g_dongtan_beach")
	if painter != null:
		Residents.met[&"egret"] = true
		player.place(GameMap.tile_center(painter.tile() + Vector2i(0, 1)), GameMap.Facing.UP)
		await _wait(0.4)
		await _press(&"use")
		await _wait(1.4)
		_check(balloon.is_open(), "在滩上跟白鹭说得上话")
		await _shot("19h_egret_beach")
		for i in 20:
			if not balloon.is_open():
				break
			await _press(&"use")
			await _wait(0.12)
	player.place(GameMap.tile_center(Vector2i(36, 8)), GameMap.Facing.UP)
	await _wait(0.5)
	await _press(&"use")
	await _wait(0.4)
	await _shot("19i_lighthouse")
	player.place(GameMap.tile_center(Vector2i(12, 11)), GameMap.Facing.UP)
	await _wait(0.5)
	await _shot("19j_studio")
	var pier_end: Vector2i = (beach.get(&"_pier") as Array)[-1]
	player.place(GameMap.tile_center(pier_end), GameMap.Facing.RIGHT)
	_hold(&"rod")
	await _wait(0.5)
	_check(beach.query_use(GameState.selected_item(), player.target_tile(), player.facing) == &"cast", "站在栈桥头上能往海里甩竿")
	await _shot("19k_pier")
	Foraging.pending[&"dongtan"] = 5
	game.call(&"_load_map", &"dongtan", &"from_riverbank")
	await _wait(0.5)
	beach = game.map
	_check(Foraging.count_on(&"dongtan") > 0, "沙滩上有东西可捡")
	if Foraging.count_on(&"dongtan") > 0:
		var shell_at: Vector2i = (Foraging.items[&"dongtan"] as Dictionary).keys()[0]
		var shell_id: StringName = Foraging.items[&"dongtan"][shell_at]
		var shells_before := GameState.inventory.count_of(shell_id)
		GameState.selected_slot = 0
		player.place(GameMap.tile_center(shell_at + Vector2i(-1, 0)), GameMap.Facing.RIGHT)
		await _wait(0.4)
		await _shot("19l_beachcombing")
		await _press(&"use")
		await _wait(0.6)
		_check(GameState.inventory.count_of(shell_id) == shells_before + 1, "赶海捡到了一样东西")
	Weather.today = weather_was
	GameState.selected_slot = 0

	# ---- 第五幕：起雾那天牧场山路口的白鹿，柏先生坦白，点山祠灯，上山祠见岚
	weather_was = Weather.today
	Weather.today = &"fog"
	GameClock.minutes = 600.0
	game.call(&"_load_map", &"pasture", &"from_town")
	await _wait(0.6)
	var slope: OutdoorMap = game.map
	_check(slope.trigger_at(Vector2i(24, 0)).is_empty() and slope.blocked(GameMap.tile_center(Vector2i(24, 1))), "牧场上山的路被雾封着")
	_check(slope.get(&"_lan") != null, "起雾的日子白鹿站在山路口")
	# 截图时站远两格，别把鹿挡住
	player.place(GameMap.tile_center(Vector2i(25, 7)), GameMap.Facing.UP)
	await _wait(0.5)
	await _shot("20a_deer")
	player.place(GameMap.tile_center(Vector2i(24, 5)), GameMap.Facing.UP)
	await _wait(0.3)
	await _press(&"use")
	await _wait(1.4)
	_check(balloon.is_open(), "对着白鹿按使用，有一段话")
	await _shot("20b_deer_talk")
	for i in 30:
		if not balloon.is_open():
			break
		await _press(&"use")
		await _wait(0.12)
	_check(GameState.has_flag(&"met_lan"), "见过白鹿了")
	await _wait(1.5)
	_check(slope.get(&"_lan") == null, "说完话白鹿走了")
	Weather.today = &"sunny"
	GameClock.minutes = 600.0
	game.call(&"_load_map", &"town", &"from_farm")
	await _wait(0.6)
	town = game.map
	GameState.selected_slot = 0
	var mayor: Npc = town.call(&"_npc_of", &"bai")
	_check(mayor != null and not mayor.is_walking(), "上午柏先生在镇公所门口")
	if mayor != null:
		Residents.met[&"bai"] = true
		Residents.add_familiarity(&"bai", 40)
		player.place(GameMap.tile_center(mayor.tile() + Vector2i(0, 1)), GameMap.Facing.UP)
		await _wait(0.4)
		await _press(&"use")
		await _wait(1.4)
		_check(balloon.is_open(), "见过白鹿以后找柏先生，他开口了")
		await _shot("20c_bai_confess")
		for i in 50:
			if not balloon.is_open():
				break
			await _press(&"use")
			await _wait(0.12)
		_check(GameState.inventory.count_of(&"prayer_tablet") == 1, "柏先生把祈愿的木牌给了出来")
	_make_room(5, [&"prayer_tablet"])
	var shrine_left := 0
	for offering: Array in [[&"tea_leaf", 4], [&"spring_bamboo_shoot", 3], [&"quartz", 3], [&"yellow_croaker", 2]]:
		shrine_left += GameState.inventory.add(offering[0], offering[1])
	_check(shrine_left == 0, "山祠灯的供品都放进了背包（放不下 %d 个）" % shrine_left)
	game.call(&"_load_map", &"pasture", &"from_town")
	await _wait(0.6)
	slope = game.map
	player.place(GameMap.tile_center(Vector2i(26, 5)), GameMap.Facing.UP)
	await _wait(0.4)
	await _shot("20d_hill_fog")
	await _press(&"use")
	await _wait(0.4)
	_check(lamp_panel.is_open(), "对着山祠灯按使用打开灯座")
	await _shot("20e_shrine_lamp_panel")
	for i in 5:
		await _press(&"use")
		await _press(&"move_down")
		await _wait(0.1)
	var shrine_missing: PackedStringArray = []
	for wanted_id: StringName in Lamps.wanted(&"shrine"):
		if Lamps.missing(&"shrine", wanted_id) > 0:
			shrine_missing.append("%s 差 %d" % [wanted_id, Lamps.missing(&"shrine", wanted_id)])
	_check(Lamps.is_complete(&"shrine"), "山祠灯的供品和木牌都供上了（%s）" % "，".join(shrine_missing))
	await _press(&"use")
	await _wait(0.5)
	_check(Lamps.is_lit(&"shrine"), "山祠灯点亮了")
	await _wait(1.8)
	_check(balloon.is_open(), "点山祠灯以后有一段旁白")
	for i in 12:
		if not balloon.is_open():
			break
		await _press(&"use")
		await _wait(0.12)
	await _shot("20f_shrine_lamp_lit")
	_check(not slope.blocked(GameMap.tile_center(Vector2i(24, 1))), "山祠灯亮了，上山的雾散了")
	GameClock.minutes = 600.0
	player.place(GameMap.tile_center(Vector2i(24, 3)) + Vector2(8, 0), GameMap.Facing.UP)
	await _wait(0.3)
	Input.action_press(&"move_up")
	for i in 40:
		if GameState.map_id == &"shanci":
			break
		await _wait(0.1)
	Input.action_release(&"move_up")
	await _wait(0.8)
	_check(GameState.map_id == &"shanci", "顺着山路走到了山祠")
	await _until_idle()
	var hill: OutdoorMap = game.map
	await _shot("20g_shanci_steps")
	player.place(GameMap.tile_center(Vector2i(21, 12)) + Vector2(8, 0), GameMap.Facing.UP)
	await _wait(0.5)
	_check(hill.get(&"_lan") == null, "晴天岚不在祠前")
	await _shot("20h_shrine")
	Weather.today = &"fog"
	await _wait(0.5)
	_check(hill.get(&"_lan") != null, "起雾了，岚站在祠前")
	var lan_tile: Vector2i = hill.get(&"LAN_TILE")
	player.place(GameMap.tile_center(lan_tile + Vector2i(-3, 2)), GameMap.Facing.UP)
	await _wait(0.5)
	await _shot("20i_lan")
	player.place(GameMap.tile_center(lan_tile + Vector2i(0, 1)), GameMap.Facing.UP)
	await _wait(0.3)
	await _press(&"use")
	await _wait(1.4)
	_check(balloon.is_open(), "在祠前跟岚说得上话")
	await _shot("20j_lan_talk")
	for i in 30:
		if not balloon.is_open():
			break
		await _press(&"use")
		await _wait(0.12)
	_check(GameState.has_flag(&"lan_talked"), "和岚说过话了")
	Weather.today = &"sunny"
	player.place(GameMap.tile_center(Vector2i(9, 16)), GameMap.Facing.UP)
	await _wait(1.6)
	await _shot("20k_grove")
	var lake_edge := Vector2i(-1, -1)
	for x in range(26, 35):
		if hill.fishing_water(Vector2i(x + 1, 19)) == &"lake":
			lake_edge = Vector2i(x, 19)
			break
	player.place(GameMap.tile_center(lake_edge), GameMap.Facing.RIGHT)
	_hold(&"rod")
	await _wait(0.5)
	_check(hill.query_use(GameState.selected_item(), player.target_tile(), player.facing) == &"cast", "站在湖边能往山顶湖里甩竿")
	await _shot("20l_lake")
	Weather.today = weather_was
	GameState.selected_slot = 0

	# ---- 回标题再读档：没睡觉的进度不保存
	await _until_idle()
	await SceneRouter.to_menu()
	await _until_idle()
	await _wait(0.5)
	await _shot("15_menu_with_save")
	menu = get_tree().current_scene
	_check(menu != null and menu.name == "MainMenu", "回到了标题画面")
	_check(not SceneRouter.busy, "回到标题后转场已经结束")
	menu.call(&"load_game", 0)
	await _wait(1.6)
	_check(GameClock.day == 2, "读档后是第 2 天")
	_check(GameState.map_id == &"farmhouse", "读档后在屋里醒来")
	_check(GameState.inventory.count_of(&"white_radish") == 0, "读档回到睡觉时的背包")
	_check(Farming.state.crop_id_at(field) == &"white_radish", "读档后作物还在")
	_check(Farming.state.soil.size() == 3, "读档后三块耕地都在（实际 %s）" % [Farming.state.soil.keys()])
	_check(Farming.orchard.trees.is_empty(), "没睡觉种的树不保存")
	_check(Shipping.count_of(&"white_radish") == 0, "没睡觉的出货不保存")
	_check(GameState.inventory.count_of(&"bok_choy_seed") == 1, "睡觉前买的种子还在")
	await _shot("16_loaded")

	# ---- 终幕：井底最初的灯。头一回选不点（留雾），第二回下去点亮（散雾）。
	# 放在读档之后：结局会睡到第二天并存档，不能搅了上面读档的检查。
	var fin_game: Node = get_tree().current_scene
	var fin_player: Player = fin_game.get(&"player")
	var fin_balloon: DialogueBalloon = fin_game.get(&"balloon")
	var fin_screen: EndingScreen = fin_game.get(&"ending_screen")
	GameState.set_flag(&"boss_shade")
	Mine.bosses.append(40)
	for fin_id: StringName in Database.npcs:
		Residents.met[fin_id] = true
	for fin_round in 2:
		var fin_title := "留雾" if fin_round == 0 else "散雾"
		Mine.enter(40)
		fin_game.call(&"_load_map", &"mine", &"ladder")
		await _wait(0.8)
		var fin_level: MineFloor = Mine.current
		fin_player.place(GameMap.tile_center(fin_level.altar + Vector2i(-1, 0)), GameMap.Facing.RIGHT)
		await _wait(0.4)
		if fin_round == 0:
			await _shot("21a_first_lamp")
		await _press(&"use")
		await _wait(1.0)
		_check(fin_balloon.is_open(), "考验走完以后对着灯座按使用，进终幕（%s）" % fin_title)
		var fin_buttons: Array = []
		for i in 40:
			fin_buttons = fin_balloon.get(&"_choices").get_children()
			if not fin_buttons.is_empty() or not fin_balloon.is_open():
				break
			await _press(&"use")
			await _wait(0.2)
		_check(fin_buttons.size() == 3, "最初的灯跟前有三个选项（实际 %d）" % fin_buttons.size())
		if fin_round == 0:
			await _shot("21b_choice")
		if fin_buttons.size() == 3:
			fin_buttons[1 if fin_round == 0 else 0].grab_focus()
		await _wait(0.15)
		await _press(&"ui_accept")
		for i in 100:
			if fin_screen.is_open() and fin_balloon.is_open():
				break
			await _wait(0.1)
		_check(fin_screen.is_open() and fin_balloon.is_open(), "结局的画铺上了，开始念旁白（%s）" % fin_title)
		await _wait(1.5)
		await _shot("21c_end_keep" if fin_round == 0 else "21e_end_clear")
		for i in 140:
			if fin_screen.is_waiting():
				break
			if fin_balloon.is_open():
				await _press(&"use")
			await _wait(0.12)
		_check(fin_screen.is_waiting() and fin_screen.title_text() == fin_title, "旁白念完亮出结局的名字：%s" % fin_title)
		await _shot("21d_title_keep" if fin_round == 0 else "21f_title_clear")
		var fin_day := GameClock.day
		await _press(&"ui_accept")
		await _wait(3.2)
		_check(not fin_screen.is_open() and not fin_game.call(&"is_locked"), "结局播完回到游戏（%s）" % fin_title)
		_check(GameState.map_id == &"farmhouse" and GameClock.day == fin_day + 1, "结局以后第二天早上在屋里醒来（%s）" % fin_title)
		if fin_round == 0:
			_check(Story.ending() == Story.KEEP and Story.can_choose(), "留雾以后还能下去改主意")
			_check(Residents.title_for(&"jiang", false) != Residents.ENDING_NEWS, "留雾：姜婆婆没有新的话")
	_check(Story.ending() == Story.CLEAR and not Story.can_choose(), "点亮了最初的灯：散雾")
	_check(Residents.title_for(&"jiang", false) == Residents.ENDING_NEWS, "散雾以后姜婆婆头一回搭话说那天的事")
	fin_game.call(&"_load_map", &"dongtan", &"from_riverbank")
	await _wait(0.8)
	fin_player.place(GameMap.tile_center(Vector2i(36, 9)), GameMap.Facing.UP)
	await _wait(0.6)
	await _shot("21g_lighthouse_lit")
	Mine.enter(40)
	fin_game.call(&"_load_map", &"mine", &"ladder")
	await _wait(0.8)
	fin_player.place(GameMap.tile_center(Mine.current.altar + Vector2i(-1, 0)), GameMap.Facing.RIGHT)
	await _wait(0.4)
	await _press(&"use")
	await _wait(0.5)
	_check(not fin_balloon.is_open(), "灯点亮以后灯座不再问")
	await _shot("21h_both_lamps")
	Mine.leave()

	# ---- 六个节日：把日子拨到节日那天，到场上各做一遍主要的活动。
	# 放在终幕之后：居民都见过面。前面读过档，路上的六盏灯这里直接记成亮的，河灯和灯笼是最全的样子；
	# 散雾以后各人头一回搭话要说那天的事，这里也记成说过了，免得盖住节日的话。
	for fes_lamp: String in ["plaza", "river", "pasture", "well", "east", "shrine"]:
		GameState.set_flag(StringName("lamp_" + fes_lamp))
	for fes_id: StringName in Database.npcs:
		Story.told(fes_id)
	var fes_game: Node = get_tree().current_scene
	var fes_player: Player = fes_game.get(&"player")
	var fes_balloon: DialogueBalloon = fes_game.get(&"balloon")
	GameState.selected_slot = GameState.HOTBAR_SIZE - 1
	_make_room(4)

	# 播种节
	await _festival_day(13, 600.0, &"town")
	var fes_map: OutdoorMap = fes_game.get(&"map")
	_check(Festivals.is_open(&"sowing"), "春分头一天上午是播种节")
	_check(fes_map.npcs.size() == Database.npcs.size(), "播种节十二位居民都在广场上（实际 %d）" % fes_map.npcs.size())
	fes_player.place(GameMap.tile_center(Vector2i(17, 17)), GameMap.Facing.UP)
	await _wait(0.4)
	await _shot("22a_sowing_stall")
	await _press(&"use")
	await _wait(0.8)
	_check(fes_balloon.is_open(), "对着种子摊按使用，阿禾招呼")
	await _choose(0, false)
	await _wait(0.5)
	var fes_shop: ShopPanel = fes_game.get(&"shop_panel")
	_check(fes_shop.is_open() and Shop.entries(&"spring", Shop.GROCERY)[0].item_id == &"strawberry_seed", "摊子上选买东西打开货单，头一样是草莓种子")
	await _shot("22b_sowing_shop")
	await _press(&"inventory")
	await _wait(0.4)
	_check(not fes_shop.is_open(), "摊子的货单关上了")
	Farming.sown_today = 22
	var fes_money := GameState.money
	fes_player.place(GameMap.tile_center(Vector2i(22, 13)), GameMap.Facing.UP)
	await _wait(0.3)
	await _press(&"use")
	await _wait(0.6)
	await _choose(0)
	await _wait(0.6)
	_check(Festivals.done("sow") and GameState.money == fes_money + 500, "播了 22 颗报数：头名，拿到 500 文")
	await _shot("22c_sowing_result")
	await _close_talk()

	# 放河灯
	await _festival_day(17, 1140.0, &"nanxi")
	fes_map = fes_game.get(&"map")
	_check(fes_map.npcs.size() == Database.npcs.size(), "放河灯的晚上居民都到了南溪（实际 %d）" % fes_map.npcs.size())
	fes_player.place(GameMap.tile_center(Vector2i(20, 15)), GameMap.Facing.LEFT)
	await _wait(0.5)
	await _press(&"use")
	await _wait(0.6)
	_check(fes_balloon.is_open(), "码头上和老周搭话")
	await _choose(0)
	await _wait(0.5)
	_check(Festivals.done("float"), "把河灯放进了水里")
	await _close_talk()
	await _wait(1.0)
	var fes_lanterns: Array = fes_map.get(&"_river_lanterns")
	_check(fes_lanterns.size() == Database.npcs.size() + 1, "灯都亮了：人人放一盏，加上自己的（实际 %d）" % fes_lanterns.size())
	fes_player.place(GameMap.tile_center(Vector2i(20, 13)), GameMap.Facing.DOWN)
	await _wait(2.0)
	await _shot("22d_river_lanterns")

	# 萤火夜
	await _festival_day(45, 1200.0, &"nanxi")
	fes_map = fes_game.get(&"map")
	await _wait(0.6)
	var fes_flies: Dictionary = fes_map.get(&"_fireflies")
	_check(fes_flies.size() == Festivals.FIREFLY_TOTAL, "萤火夜草地上有 %d 只萤火虫（实际 %d）" % [Festivals.FIREFLY_TOTAL, fes_flies.size()])
	fes_player.place(GameMap.tile_center(Vector2i(20, 8)), GameMap.Facing.DOWN)
	await _wait(0.5)
	await _shot("22e_fireflies")
	var fes_homes: Array = fes_flies.keys()
	for fes_i in mini(Festivals.FIREFLY_GOAL, fes_homes.size()):
		var fes_tile: Vector2i = fes_homes[fes_i]
		fes_player.place(GameMap.tile_center(fes_tile + Vector2i(-1, 0)), GameMap.Facing.RIGHT)
		await _wait(0.3)
		await _press(&"use")
		await _wait(0.4)
	_check(Festivals.caught() == Festivals.FIREFLY_GOAL, "走到跟前按使用，捉了 %d 只（实际 %d）" % [Festivals.FIREFLY_GOAL, Festivals.caught()])
	fes_player.place(GameMap.tile_center(Vector2i(21, 10)), GameMap.Facing.UP)
	await _wait(0.4)
	await _press(&"use")
	await _wait(0.6)
	await _choose(0)
	await _wait(0.5)
	_check(Festivals.done("release"), "和小满一起把萤火虫放了")
	await _shot("22f_firefly_release")
	await _close_talk()
	if Festivals.heart_npc() != &"":
		for i in 150:
			if fes_balloon.is_open():
				break
			await _wait(0.1)
		_check(fes_balloon.is_open() and Festivals.done("heart"), "放完萤火虫，忆最深的居民走过来说话")
		await _wait(0.5)
		await _shot("22g_firefly_heart")
		await _close_talk()

	# 丰收集
	await _festival_day(61, 600.0, &"town")
	GameState.inventory.add(&"pumpkin", 1, 2)
	_hold(&"pumpkin")
	var fes_pumpkins := GameState.inventory.count_of(&"pumpkin")
	fes_player.place(GameMap.tile_center(Vector2i(22, 13)), GameMap.Facing.UP)
	await _wait(0.4)
	await _shot("22h_harvest_fair")
	await _press(&"use")
	await _wait(0.6)
	_check(fes_balloon.is_open(), "拿着南瓜对着长桌按使用，柏先生接话（不问送不送礼）")
	await _choose(0)
	await _wait(0.5)
	_check(Festivals.done("judge_crop") and GameState.inventory.count_of(&"pumpkin") == fes_pumpkins - 1, "南瓜评过了，留在台上一个")
	await _shot("22i_harvest_result")
	await _close_talk()

	# 饺子宴
	await _festival_day(85, 1080.0, &"town")
	GameState.inventory.add(&"bok_choy", 1)
	_hold(&"bok_choy")
	GameState.energy = 20
	fes_player.place(GameMap.tile_center(Vector2i(22, 13)), GameMap.Facing.UP)
	await _wait(0.4)
	await _press(&"use")
	await _wait(0.6)
	await _choose(0)
	await _wait(0.5)
	_check(Festivals.done("fill") and GameState.energy == GameState.max_energy, "交了一样馅，吃完饺子体力回满")
	await _shot("22j_dumpling_feast")
	await _close_talk()

	# 除夕灯会
	GameState.selected_slot = GameState.HOTBAR_SIZE - 1
	await _festival_day(96, 1170.0, &"town")
	fes_map = fes_game.get(&"map")
	_check(int(fes_map.get(&"_lanterns")) == 20, "七盏灯都亮着：广场挂满二十只灯笼（实际 %d）" % int(fes_map.get(&"_lanterns")))
	fes_player.place(GameMap.tile_center(Vector2i(22, 15)), GameMap.Facing.UP)
	await _wait(0.6)
	await _shot("22k_newyear_lanterns")
	fes_player.place(GameMap.tile_center(Vector2i(22, 13)), GameMap.Facing.UP)
	await _wait(0.3)
	await _press(&"use")
	await _wait(0.6)
	await _choose(0)
	await _wait(0.5)
	_check(fes_balloon.is_open() and Festivals.said.has("income"), "柏先生念这一年的账")
	await _shot("22l_newyear_summary")
	await _close_talk()
	var fes_day := GameClock.day
	await _press(&"use")
	await _wait(0.6)
	await _choose(1)
	await _wait(0.5)
	_check(GameState.has_flag(Festivals.flag("vigil", fes_day)), "和大家一起守岁")
	await _close_talk()
	for i in 80:
		if GameClock.day == fes_day + 1 and not fes_game.call(&"is_locked"):
			break
		await _wait(0.1)
	_check(GameClock.day == fes_day + 1 and GameState.map_id == &"farmhouse", "守完岁，新年头一天早上在屋里醒来")
	await _wait(0.8)
	await _shot("22m_new_year_morning")

	for i in SaveSystem.SLOT_COUNT:
		SaveSystem.delete(i)
	if _failures.is_empty():
		print("FLOW PASS  %d checks" % _checks)
	else:
		print("FLOW FAIL  %d / %d" % [_failures.size(), _checks])
		for f in _failures:
			print("  - ", f)
	Audio.quit_game(0 if _failures.is_empty() else 1)


## 把日子拨到这一年的第 day 天（已经过了就拨到明年的）、几点，天晴，然后进这张地图。
func _festival_day(day: int, minutes: float, map_id: StringName) -> void:
	var game: Node = get_tree().current_scene
	var target := (GameClock.day - 1) / 96 * 96 + day
	if target < GameClock.day:
		target += 96
	GameClock.day = target
	GameClock.minutes = minutes
	Weather.today = Weather.SUNNY
	game.call(&"_load_map", map_id, &"from_farm" if map_id == &"town" else &"from_town")
	await _wait(0.9)


## 按使用键把对话往下翻，直到出现选项，选第 index 个。follow 表示选完会接着开下一段对话，等它开出来。
func _choose(index: int, follow: bool = true) -> void:
	var balloon: DialogueBalloon = get_tree().current_scene.get(&"balloon")
	var buttons: Array = []
	for i in 40:
		buttons = balloon.get(&"_choices").get_children()
		if not buttons.is_empty() or not balloon.is_open():
			break
		await _press(&"use")
		await _wait(0.2)
	_check(buttons.size() > index, "对话里出现了选项（要第 %d 个，实际 %d 个）" % [index + 1, buttons.size()])
	if buttons.size() > index:
		buttons[index].grab_focus()
		await _wait(0.15)
		await _press(&"ui_accept")
		# 选完以后这一段收掉、下一段（结果）接着开，中间隔几帧
		await _wait(0.3)
		for i in 20:
			if balloon.is_open() or not follow:
				break
			await _wait(0.1)


## 按使用键把对话翻完。
func _close_talk() -> void:
	var balloon: DialogueBalloon = get_tree().current_scene.get(&"balloon")
	for i in 60:
		if not balloon.is_open():
			return
		if not balloon.get(&"_choices").get_children().is_empty():
			break
		await _press(&"use")
		await _wait(0.2)
	_check(not balloon.is_open(), "对话翻到头关上了")


## 环境变量 FLOW_TIMEOUT 可以临时改秒数（用来检查这个超时本身管不管用）。
func _watchdog() -> void:
	var limit := TIMEOUT
	if OS.get_environment("FLOW_TIMEOUT").is_valid_float():
		limit = float(OS.get_environment("FLOW_TIMEOUT"))
	await get_tree().create_timer(limit).timeout
	print("FLOW TIMEOUT  跑了 %d 秒还没结束，多半是脚本中途报错了；已做 %d 项检查" % [int(limit), _checks])
	Audio.quit_game(2)


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_failures.append(what)
		print("CHECK FAILED: ", what)


## 从背包后头腾出 n 个空格（物品栏那一行、工具、keep 里的东西不动）。这些改动回标题以后不保存。
func _make_room(n: int, keep: Array[StringName] = []) -> void:
	var room := 0
	for i in range(GameState.inventory.size - 1, 9, -1):
		if room >= n:
			break
		if GameState.inventory.is_empty_slot(i):
			room += 1
		elif not keep.has(GameState.inventory.id_at(i)) and Database.item(GameState.inventory.id_at(i)).kind != &"tool":
			GameState.inventory.remove_at(i, GameState.inventory.count_at(i))
			room += 1


## 等转场结束。转场进行中时 SceneRouter 会忽略新的切换请求。
func _until_idle() -> void:
	for i in 300:
		if not SceneRouter.busy:
			return
		await get_tree().process_frame


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


## 按一下再松开，中间隔几帧，让轮询和事件两种读法都能收到。
func _press(action: StringName) -> void:
	await _until_free()
	if action == &"use":
		await _until_use_released()
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	await _frames(0.06)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(0.06)


## 等人物把手头的动作做完。画面卡的时候动作比写死的等待时间长（人物每帧最多走 0.05 秒的动作），
## 这时候按键会被当成“还在忙”吞掉，所以每次按键前都先等一下。
func _until_free() -> void:
	for i in 600:
		var scene := get_tree().current_scene
		var p: Variant = scene.get(&"player") if scene != null else null
		if not (p is Player) or not (p as Player).is_acting():
			return
		await get_tree().process_frame


## 游戏在菜单、对话、转场刚结束的那一帧会要求“使用”键先松开一次，这时候按下去不算数。
## 画面卡的时候流程里写死的等待可能正好落在这一帧上，所以按之前等它认了“已经松开”。
## 真等过的话在输出里记一笔（FLOW NOTE），以后检查偶发失败时好对上是不是这个原因。
func _until_use_released() -> void:
	var waited := 0
	for i in 120:
		var scene := get_tree().current_scene
		if scene == null or not scene.has_method(&"is_locked") or scene.call(&"is_locked"):
			break
		if not bool(scene.get(&"_use_needs_release")):
			break
		waited += 1
		await get_tree().process_frame
	if waited > 0:
		print("FLOW NOTE  按使用键之前等了 %d 帧，游戏才认上一次已经松开" % waited)


## 重新下到第 3 层（固定种子），清掉原来的忘形，在下来的地方朝某个方向 gap 格远摆一只 id 这种忘形，
## 中间的石头也清掉。返回那个方向（GameMap.Facing 的编号）；四面都摆不开返回 -1。之后要重新载入地图。
func _arena(id: StringName, gap: int) -> int:
	Mine.enter(3, 21)
	var lvl: MineFloor = Mine.current
	lvl.monsters.clear()
	var dirs: Array = [[Vector2i(0, 1), GameMap.Facing.DOWN], [Vector2i(1, 0), GameMap.Facing.RIGHT], [Vector2i(-1, 0), GameMap.Facing.LEFT]]
	for entry: Array in dirs:
		var d: Vector2i = entry[0]
		var ok := true
		for k in range(1, gap + 2):
			if not lvl.is_open(lvl.spawn + d * k) or lvl.spawn + d * k == lvl.lamp:
				ok = false
		if not ok:
			continue
		for k in range(1, gap + 2):
			lvl.rocks.erase(lvl.spawn + d * k)
			lvl.hp.erase(lvl.spawn + d * k)
		lvl.monsters.append(MineMonster.create(Database.monster(id), GameMap.tile_center(lvl.spawn + d * gap), 5))
		return int(entry[1])
	return -1


## 让主角站到矿井里 target 这一格旁边的空地上、面朝它；四面都站不了返回假。
func _stand_facing(who: Player, level: MineFloor, target: Vector2i) -> bool:
	var facings: Array = [[Vector2i(0, 1), GameMap.Facing.UP], [Vector2i(0, -1), GameMap.Facing.DOWN], [Vector2i(1, 0), GameMap.Facing.LEFT], [Vector2i(-1, 0), GameMap.Facing.RIGHT]]
	for entry: Array in facings:
		var at: Vector2i = target + (entry[0] as Vector2i)
		if level.walkable(at):
			who.place(GameMap.tile_center(at), entry[1])
			return true
	return false


## 至少等 sec 秒，而且至少过两帧：画面卡一下的时候，按下和松开不会落进同一帧被游戏漏掉。
func _frames(sec: float) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await _wait(sec)


func _preview_dir() -> String:
	var dir := ProjectSettings.globalize_path("res://_preview")
	DirAccess.make_dir_recursive_absolute(dir)
	if not FileAccess.file_exists(dir + "/.gdignore"):
		var f := FileAccess.open(dir + "/.gdignore", FileAccess.WRITE)
		f.close()
	return dir


func _shot(shot_name: String) -> void:
	# 无窗口方式跑（--headless）没有画面：只跑检查，不截图
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_preview_dir() + "/shot_" + shot_name + ".png")


## 连拍若干帧，把角色周围的画面拼成一条，用来检查实际运行中的动作。
func _strip(target: Node2D, strip_name: String, count: int, interval: float) -> void:
	if DisplayServer.get_name() == "headless":
		await _wait(interval * count)
		return
	var out := Image.create(CELL * count, CELL, false, Image.FORMAT_RGBA8)
	for i in count:
		await RenderingServer.frame_post_draw
		if not is_instance_valid(target):
			return
		var img := get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		var k := img.get_width() / get_viewport().get_visible_rect().size.x
		var c: Vector2 = target.get_global_transform_with_canvas().origin * k
		var src := Rect2i(int(c.x) - CELL / 2, int(c.y) - CELL * 3 / 4, CELL, CELL)
		out.blit_rect(img, src, Vector2i(i * CELL, 0))
		await _wait(interval)
	out.save_png(_preview_dir() + "/strip_" + strip_name + ".png")


## 把某样东西拿在手里；它排在快捷栏外面时先换到快捷栏最后一格。
func _hold(id: StringName) -> void:
	var inv := GameState.inventory
	for i in inv.size:
		if inv.id_at(i) != id:
			continue
		var slot := i
		if slot >= GameState.HOTBAR_SIZE:
			slot = GameState.HOTBAR_SIZE - 1
			inv.swap(i, slot)
		GameState.selected_slot = slot
		return
