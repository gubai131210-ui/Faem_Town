extends GutTest
## 让居民不那么像木偶的几样东西：话题不重复、记得上次说话和送礼、头像表情、台词按标点停顿、走路有起步和收步。

func before_each() -> void:
	# 居民的张望、起步延迟都带随机，固定种子让测试每次一样（和自动流程一致，决策 035）。
	seed(20260101)
	SaveSystem.reset_all()
	Weather.today = &"sunny"
	GameClock.minutes = 600.0


func after_each() -> void:
	SaveSystem.reset_all()


func test_topic_is_stable_within_a_day_and_does_not_repeat() -> void:
	var first := Residents.topic("ahe", 5)
	assert_eq(Residents.topic("ahe", 5), first, "同一天问几次都是同一个话题")
	var seen := {first: true}
	for i in 4:
		GameClock.advance_day()
		seen[Residents.topic("ahe", 5)] = true
	assert_eq(seen.size(), 5, "五天里五个话题各聊一次")
	GameClock.advance_day()
	assert_between(Residents.topic("ahe", 5), 0, 4, "聊完一轮重新开始")
	assert_eq(Residents.topic("nobody", 0), 0)


func test_topic_bags_survive_saving() -> void:
	Residents.topic("ahe", 4)
	var data: Dictionary = JSON.parse_string(JSON.stringify(Residents.save_data()))
	var left: Array = Residents.topic_bags["ahe"].duplicate()
	Residents.reset_data()
	Residents.load_data(data)
	assert_eq(Residents.topic_bags["ahe"], left, "没聊过的话题存进了存档")


func test_away_counts_days_since_last_talk() -> void:
	Residents.talk(&"jiang", false)
	assert_eq(Residents.away("jiang"), 0, "第一次见面不算久别")
	GameClock.advance_day()
	Residents.talk(&"jiang", false)
	assert_eq(Residents.away("jiang"), 1)
	for i in 5:
		GameClock.advance_day()
	Residents.talk(&"jiang", false)
	assert_eq(Residents.away("jiang"), 5)
	Residents.talk(&"jiang", false)
	assert_eq(Residents.away("jiang"), 5, "当天再说话不变")
	assert_eq(Residents.nth("jiang"), 2)


func test_thanks_for_a_gift_come_the_next_day_once() -> void:
	Residents.give(&"xiaoman", &"strawberry")
	assert_false(Residents.owes_thanks("xiaoman"), "当天已经谢过了")
	GameClock.advance_day()
	assert_true(Residents.owes_thanks("xiaoman"))
	assert_eq(Residents.gift_name("xiaoman"), "草莓")
	Residents.thanked("xiaoman")
	assert_false(Residents.owes_thanks("xiaoman"), "只谢一次")
	Residents.give(&"xiaoman", &"fern")
	GameClock.advance_day()
	assert_false(Residents.owes_thanks("xiaoman"), "不喜欢的东西不会再提")


func test_time_of_day_and_schedule_note() -> void:
	GameClock.minutes = 420.0
	assert_true(Residents.time_is("morning"))
	GameClock.minutes = 700.0
	assert_true(Residents.time_is("noon"))
	assert_true(Residents.at("jiang", "bench"), "中午姜婆婆坐在长凳上")
	assert_false(Residents.at("jiang", "door"))
	GameClock.minutes = 900.0
	assert_true(Residents.time_is("afternoon"))
	GameClock.minutes = 1200.0
	assert_true(Residents.time_is("evening"))
	assert_false(Residents.time_is("morning"))
	assert_false(Residents.at("nobody", "bench"))
	assert_true(Residents.knows("jiang", 0))
	assert_false(Residents.knows("jiang", 10))


func test_faces_have_three_moods() -> void:
	for id: StringName in Database.npcs:
		var sheet := Database.npc(id).sheet
		var calm := UiKit.face(sheet) as AtlasTexture
		var happy := UiKit.face(sheet, "happy") as AtlasTexture
		var sad := UiKit.face(sheet, "sad") as AtlasTexture
		assert_not_null(calm, "%s 有头像" % id)
		if calm == null:
			continue
		assert_eq(calm.atlas.get_width(), 192, "%s 的头像是三格" % id)
		assert_eq(calm.region, Rect2(0, 0, 64, 64))
		assert_eq(happy.region, Rect2(64, 0, 64, 64))
		assert_eq(sad.region, Rect2(128, 0, 64, 64))
	assert_null(UiKit.face("nobody"))


func test_text_pauses_at_punctuation() -> void:
	var text := "哎，生面孔！……等等。"
	assert_eq(DialogueBalloon.pause_after(text, 0), 0.0, "普通的字不停")
	assert_eq(DialogueBalloon.pause_after(text, 1), DialogueBalloon.PAUSE_SHORT_TIME, "逗号停一下")
	assert_eq(DialogueBalloon.pause_after(text, 5), 0.0, "连着的标点只在最后一个后面停")
	assert_eq(DialogueBalloon.pause_after(text, 7), DialogueBalloon.PAUSE_LONG_TIME)
	assert_eq(DialogueBalloon.pause_after(text, text.length() - 1), 0.0, "最后一个字不用停")


## 把居民的 _process 手动跑 seconds 秒。
func _run(npc: Npc, seconds: float) -> void:
	for i in int(seconds / 0.05):
		npc._process(0.05)


func _npc(id: StringName, tile: Vector2i) -> Npc:
	var npc := Npc.new()
	add_child_autofree(npc)
	npc.setup(Database.npc(id), tile, GameMap.Facing.DOWN)
	npc.set_process(false)
	return npc


func test_npc_eases_into_a_walk_and_arrives() -> void:
	GameClock.running = true
	var npc := _npc(&"ahe", Vector2i(2, 2))
	var start := npc.position
	watch_signals(npc)
	npc.walk([Vector2i(3, 2), Vector2i(4, 2), Vector2i(4, 3)] as Array[Vector2i], GameMap.Facing.LEFT)
	npc._process(0.05)
	assert_eq(npc.position, start, "先转身顿一下，还没迈步")
	assert_eq(npc.facing, GameMap.Facing.RIGHT, "已经朝要去的方向转过去了")
	_run(npc, 0.7)
	assert_gt(npc.position.x, start.x, "走起来了")
	assert_true(npc.is_walking())
	_run(npc, 6.0)
	assert_eq(npc.tile(), Vector2i(4, 3))
	assert_eq(npc.facing, GameMap.Facing.LEFT, "到了以后朝日程里写的方向")
	assert_false(npc.is_walking())
	assert_signal_emitted_with_parameters(npc, "arrived", [npc, false])
	GameClock.running = false


func test_npc_speed_comes_from_the_table() -> void:
	assert_lt(Database.npc(&"jiang").speed, Database.npc(&"ahe").speed, "姜婆婆走得比阿禾慢")
	assert_gt(Database.npc(&"xiaoman").speed, Database.npc(&"ahe").speed, "小满跑得快")
	GameClock.running = true
	var slow := _npc(&"jiang", Vector2i(2, 2))
	var fast := _npc(&"xiaoman", Vector2i(2, 4))
	var path: Array[Vector2i] = []
	for x in range(3, 12):
		path.append(Vector2i(x, 2))
	slow.walk(path, GameMap.Facing.DOWN)
	slow._delay = 0.0
	path = []
	for x in range(3, 12):
		path.append(Vector2i(x, 4))
	fast.walk(path, GameMap.Facing.DOWN)
	fast._delay = 0.0
	_run(slow, 2.0)
	_run(fast, 2.0)
	assert_gt(fast.position.x, slow.position.x + 10.0)
	GameClock.running = false


func test_standing_npc_turns_to_watch_the_player_and_back() -> void:
	GameClock.running = true
	var npc := _npc(&"ahe", Vector2i(5, 5))
	var player_pos := [npc.position + Vector2(100, 0)]
	npc.player_position = func() -> Vector2: return player_pos[0]
	npc._glance_wait = 999.0
	_run(npc, 0.2)
	assert_eq(npc.facing, GameMap.Facing.DOWN, "离得远不理会")
	player_pos[0] = npc.position + Vector2(20, 2)
	_run(npc, 0.2)
	assert_eq(npc.facing, GameMap.Facing.RIGHT, "走近了就转过来看")
	player_pos[0] = npc.position + Vector2(-30, 2)
	_run(npc, 0.2)
	assert_eq(npc.facing, GameMap.Facing.LEFT, "跟着玩家转")
	player_pos[0] = npc.position + Vector2(-80, 0)
	npc._glance_wait = 999.0
	_run(npc, 0.2)
	assert_eq(npc.facing, GameMap.Facing.DOWN, "走远了转回原来的方向")
	GameClock.running = false


func test_leaving_npc_fades_out_before_it_is_removed() -> void:
	GameClock.running = true
	var npc := _npc(&"ahe", Vector2i(2, 2))
	watch_signals(npc)
	npc.walk([Vector2i(3, 2)] as Array[Vector2i], GameMap.Facing.UP, true)
	npc._delay = 0.0
	_run(npc, 1.0)
	assert_signal_not_emitted(npc, "arrived", "走到门口先淡出")
	assert_lt(npc.modulate.a, 1.0)
	npc.set_process(true)
	_run(npc, 0.5)
	assert_signal_emitted_with_parameters(npc, "arrived", [npc, true])
	GameClock.running = false


func test_npc_waits_behind_someone_then_asks_for_another_path() -> void:
	GameClock.running = true
	var npc := _npc(&"ahe", Vector2i(2, 2))
	watch_signals(npc)
	var who := {"there": true}
	npc.occupied = func(t: Vector2i, _me: Npc) -> bool: return who["there"] and t == Vector2i(3, 2)
	npc.walk([Vector2i(3, 2), Vector2i(4, 2)] as Array[Vector2i], GameMap.Facing.RIGHT)
	var start := npc.position
	for i in 30:
		npc._process(0.05)
	assert_eq(npc.position, start, "前面有人就站着不动")
	assert_signal_not_emitted(npc, "stuck")
	for i in 20:
		npc._process(0.05)
	assert_signal_emitted(npc, "stuck", "等了一秒半还没让开，就请地图换路")
	who["there"] = false
	for i in 60:
		npc._process(0.05)
	assert_ne(npc.position, start, "人让开了就接着走")


func test_npc_sits_when_its_spot_is_a_bench() -> void:
	GameClock.running = true
	var npc := _npc(&"jiang", Vector2i(18, 13))
	npc.spot = {"map": &"town", "tile": Vector2i(18, 13), "facing": GameMap.Facing.DOWN, "note": "bench"}
	npc._process(0.05)
	assert_true(npc.is_sitting())
	assert_eq(npc._anim, &"sit")
	assert_lt(npc._sprite.position.y, -float(npc._sheet.foot_row), "坐着时人往上挪到凳面")
	npc.spot["note"] = "door"
	npc._process(0.05)
	assert_false(npc.is_sitting())
	assert_eq(npc._anim, &"idle")
	assert_eq(npc._sprite.position.y, -float(npc._sheet.foot_row))


func test_every_resident_sheet_has_a_sit_pose() -> void:
	for id: StringName in Database.npcs:
		if id == &"farmer":
			continue
		var npc := _npc(id, Vector2i(2, 2))
		assert_true(npc._sheet.has_anim(&"sit"), "%s 的序列帧里有坐姿" % id)


func test_two_npcs_chat_face_each_other_then_go_back() -> void:
	GameClock.running = true
	var a := _npc(&"ahe", Vector2i(2, 2))
	var b := _npc(&"bai", Vector2i(4, 2))
	a.chat(b, 1.0, 0.0)
	b.chat(a, 1.0, 1.2)
	assert_true(a.is_chatting())
	assert_eq(a.facing, GameMap.Facing.RIGHT)
	assert_eq(b.facing, GameMap.Facing.LEFT)
	for i in 6:
		a._process(0.05)
		b._process(0.05)
	assert_true(a._bubble.visible != b._bubble.visible, "两个人轮流说，气泡一个亮一个灭")
	for i in 24:
		a._process(0.05)
	assert_false(a.is_chatting(), "聊够了就散")
	assert_eq(a.facing, GameMap.Facing.DOWN, "回到原来的朝向")
	assert_false(a._bubble.visible)


func test_walking_npc_breaks_off_the_chat() -> void:
	GameClock.running = true
	var a := _npc(&"ahe", Vector2i(2, 2))
	var b := _npc(&"bai", Vector2i(4, 2))
	a.chat(b, 10.0, 0.0)
	b.chat(a, 10.0, 1.2)
	b.walk([Vector2i(4, 3)] as Array[Vector2i], GameMap.Facing.DOWN)
	assert_false(b.is_chatting())
	a._process(0.05)
	assert_false(a.is_chatting(), "对方走了，这边也不聊了")


func test_map_tells_npc_which_tiles_are_taken() -> void:
	var town: OutdoorMap = load("res://maps/town/town.tscn").instantiate()
	add_child_autofree(town)
	var a := _npc(&"ahe", Vector2i(10, 10))
	var b := _npc(&"bai", Vector2i(11, 10))
	town.npcs.append(a)
	town.npcs.append(b)
	assert_true(town._occupied_by_someone(Vector2i(11, 10), a), "白先生站的那格对阿禾来说是占着的")
	assert_false(town._occupied_by_someone(Vector2i(10, 10), a), "自己站的格不算")
	assert_false(town._occupied_by_someone(Vector2i(12, 10), a))
	town.npcs.erase(a)
	town.npcs.erase(b)


func test_qingzhu_sits_on_the_plaza_bench_in_the_morning() -> void:
	GameClock.running = true
	GameClock.minutes = 600.0
	var town: OutdoorMap = load("res://maps/town/town.tscn").instantiate()
	add_child_autofree(town)
	var npc := town._npc_of(&"qingzhu")
	assert_not_null(npc, "上午青竹在镇上")
	assert_eq(npc.tile(), Vector2i(26, 13))
	assert_eq(str(npc.spot.get("note", "")), "bench")
	npc._process(0.05)
	assert_true(npc.is_sitting(), "青竹坐在长凳上")
	assert_eq(npc._anim, &"sit")

