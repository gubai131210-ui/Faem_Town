extends GutTest
## M11 第一批的开头：开场有四段，跳过只记下看过，不改别的状态。


const CutsceneScript := preload("res://game/cutscene.gd")
const PlayerScript := preload("res://game/cutscene_player.gd")


func before_each() -> void:
	SaveSystem.reset_all()


func after_each() -> void:
	SaveSystem.reset_all()


func test_opening_is_four_beats_and_the_last_shows_the_house() -> void:
	var steps := CutsceneScript.opening_steps()
	assert_eq(steps.size(), 4)
	assert_eq(steps[0]["picture"], &"desk")
	assert_eq(steps[1]["picture"], &"letter")
	assert_eq(steps[2]["picture"], &"window")
	assert_eq(steps[3]["picture"], &"", "最后一段露出已经在的农舍")
	assert_eq(CutsceneScript.seen_flag(CutsceneScript.OPENING), &"cutscene_opening")


func test_pictures_are_not_blank() -> void:
	for id in [&"desk", &"letter", &"window"]:
		var img: Image = CutsceneScript.picture(id)
		var colors := {}
		for y in range(0, img.get_height(), 4):
			for x in range(0, img.get_width(), 4):
				colors[img.get_pixel(x, y)] = true
		assert_gt(colors.size(), 3, "%s 不只一种颜色" % id)
	# 钥匙在信纸右下（约 x114..132、y60..72），区域内应有明显暖金色，不是单点碰运气
	var letter := CutsceneScript.picture(&"letter")
	var gold := 0
	for y in range(60, 73):
		for x in range(113, 133):
			var c: Color = letter.get_pixel(x, y)
			if c.r > c.b + 0.2 and c.r > 0.5:
				gold += 1
	assert_gt(gold, 20, "信上有一把黄钥匙")


func test_skip_only_marks_the_opening_seen() -> void:
	var money := GameState.money
	var day := GameClock.day
	var player: Node = PlayerScript.new()
	add_child(player)
	player.play(CutsceneScript.OPENING, CutsceneScript.opening_steps())
	assert_true(player.playing)
	player.skip()
	for _i in 8:
		if not player.playing:
			break
		await get_tree().process_frame
	assert_false(player.playing, "跳过以后演完")
	assert_true(GameState.has_flag(&"cutscene_opening"))
	assert_eq(GameState.money, money)
	assert_eq(GameClock.day, day)
	player.queue_free()


func test_lamp_shot_rises_then_returns_without_a_picture() -> void:
	var steps := CutsceneScript.lamp_steps("灯亮了，雾退开了一小圈。")
	assert_eq(steps.size(), 2)
	assert_eq(steps[0]["look"], &"lamp")
	assert_eq(steps[0]["picture"], &"")
	assert_eq(steps[0]["text"], "灯亮了，雾退开了一小圈。")
	assert_eq(steps[1]["look"], &"player")
	assert_eq(CutsceneScript.lamp_id(&"plaza"), &"lamp_plaza")
	assert_eq(CutsceneScript.seen_flag(CutsceneScript.lamp_id(&"plaza")), &"cutscene_lamp_plaza")
	var up := CutsceneScript.look_offset(Vector2(100, 200), Vector2(100, 40))
	assert_lt(up.y, -16.0, "灯在北边，镜头往上抬")
	assert_eq(up.x, 0.0)
	var far := CutsceneScript.look_offset(Vector2.ZERO, Vector2(400, 0))
	assert_lte(far.x, 72.0, "再远也不超过 72 像素")


func test_each_ending_plays_four_pictures_and_then_the_credits() -> void:
	for ending in [&"keep", &"clear", &"name"]:
		var steps := CutsceneScript.ending_steps(ending)
		assert_eq(steps.size(), 5, ending)
		assert_eq(steps[4]["picture"], &"credits")
		assert_eq(steps[4]["text"], "《雾隐青岚》")
		for step in steps:
			var img: Image = CutsceneScript.picture(step["picture"])
			var colors := {}
			for y in range(0, img.get_height(), 6):
				for x in range(0, img.get_width(), 6):
					colors[img.get_pixel(x, y)] = true
			assert_gt(colors.size(), 2, "%s 的 %s 不只一种颜色" % [ending, step["id"]])
	var funeral: Dictionary = CutsceneScript.ending_steps(&"clear")[2]
	assert_eq(funeral["id"], &"funeral")
	var plaque := CutsceneScript.picture(&"end_funeral").get_pixel(132, 84)
	assert_gt(plaque.r, 0.8, "葬礼的碑上有一块浅色的牌")
	assert_eq(funeral["cast"].size(), 6, "葬礼上有主角和五位居民")
	assert_eq(funeral["sec"], 2.4)
	var start: Image = CutsceneScript.compose(&"end_funeral", funeral["cast"], 0.0, 2.4)
	var later: Image = CutsceneScript.compose(&"end_funeral", funeral["cast"], 2.4, 2.4)
	assert_lt(_hat_x(start), _hat_x(later), "主角的草帽从左边走到碑前")
	var down: Dictionary = CutsceneScript.ending_steps(&"name")[0]
	var high: Image = CutsceneScript.compose(&"end_shaft", down["cast"], 0.0, 2.4)
	var low: Image = CutsceneScript.compose(&"end_shaft", down["cast"], 2.4, 2.4)
	assert_lt(_hat_y(high), _hat_y(low), "草帽顺着梯子往下")
	var stood := CutsceneScript.picture(&"end_funeral")
	var moved := stood.duplicate()
	CutsceneScript.stamp_person(moved, 40, 70, 0)
	assert_false(stood.get_pixel(40, 64) == moved.get_pixel(40, 64), "人画上去以后，那一格变了")


func _hat_x(img: Image) -> int:
	var best := -1
	for y in img.get_height():
		for x in range(140):
			if _straw(img.get_pixel(x, y)) and x > best:
				best = x
	return best


func _hat_y(img: Image) -> int:
	var best := 999
	for y in img.get_height():
		for x in range(120, 175):
			if _straw(img.get_pixel(x, y)) and y < best:
				best = y
	return best


func _straw(c: Color) -> bool:
	return c.r > 0.9 and c.g > 0.75 and c.b < 0.55 and c.g > c.b + 0.25


func test_fog_drifts_away_from_the_lamp() -> void:
	var drift := OutdoorMap.fog_drift(Vector2(80, 10), Vector2(20, 10))
	assert_gt(drift.x, 40.0, "雾在灯的东边，就往东退")
	assert_almost_eq(drift.y, 0.0, 0.01)
	var still := OutdoorMap.fog_drift(Vector2(5, 5), Vector2(5, 5))
	assert_lt(still.y, 0.0, "雾和灯叠在一起时往上退")


func test_story_beats_cover_the_four_talks_and_the_bosses() -> void:
	var photo := CutsceneScript.story_beat("res://dialogue/jiang.dialogue", "the_photo")
	assert_eq(photo["id"], &"photo")
	assert_false(str(photo["text"]).is_empty())
	assert_eq(CutsceneScript.story_beat("res://dialogue/jiang.dialogue", "daily").size(), 0, "平常说话不演")
	assert_eq(CutsceneScript.story_beat("res://dialogue/lan.dialogue", "meet")["id"], &"deer")
	assert_eq(CutsceneScript.story_beat("res://dialogue/bai.dialogue", "the_prayer")["id"], &"confess")
	assert_eq(CutsceneScript.story_beat("res://dialogue/laoqin.dialogue", "well_key")["id"], &"key")
	assert_eq(CutsceneScript.descent_steps().size(), 1)
	assert_eq(CutsceneScript.descent_steps()[0]["picture"], &"")
	for arena in [&"cart", &"catfish", &"troupe", &"shade"]:
		var beat := CutsceneScript.boss_beat(arena)
		assert_eq(beat["id"], StringName("boss_" + arena))
		assert_false(str(beat["text"]).is_empty(), "%s 有一句登场" % arena)
	assert_eq(CutsceneScript.boss_beat(&"dust").size(), 0)


func test_jiang_memory_is_an_old_photo_and_the_others_stay_words() -> void:
	var scene := CutsceneScript.memory_scene("res://dialogue/jiang.dialogue", "memory_5")
	assert_eq(scene["id"], &"memory_jiang")
	assert_eq(scene["steps"].size(), 2)
	assert_eq(scene["steps"][0]["tint"], "sepia")
	assert_eq(CutsceneScript.memory_scene("res://dialogue/xiaoman.dialogue", "memory_5").size(), 0, "小满没有忆")
	assert_eq(CutsceneScript.memory_scene("res://dialogue/lan.dialogue", "memory_5").size(), 0, "岚的五级忆这轮不演")
	assert_eq(CutsceneScript.story_beat("res://dialogue/jiang.dialogue", "memory_5").size(), 0)
	var step: Dictionary = scene["steps"][0]
	var start: Image = CutsceneScript.compose(step["picture"], step["cast"], 0.0, 2.4, true)
	var later: Image = CutsceneScript.compose(step["picture"], step["cast"], 2.4, 2.4, true)
	var moved := _shifted(start, later)
	assert_gt(moved["left"], 20, "她离开了左边")
	assert_gt(moved["right"], 20, "她走到了桌子那边")
	var plain: Image = CutsceneScript.picture(&"memory_jiang")
	var window := plain.get_pixel(50, 50)
	var aged := start.get_pixel(50, 50)
	assert_gt(window.b, aged.b, "窗户的蓝褪成旧照片")
	assert_gt(aged.r, aged.b, "旧照片偏暖")


func test_the_other_ten_memories_play_their_own_picture() -> void:
	for who in ["ahe", "egret", "qingzhu", "shishu", "amu", "laozhou", "yunniang", "bai", "laoqin", "luyuan"]:
		var scene := CutsceneScript.memory_scene("res://dialogue/%s.dialogue" % who, "memory_5")
		assert_eq(scene["id"], StringName("memory_" + who), who)
		assert_eq(scene["steps"].size(), 2, who)
		assert_eq(scene["steps"][0]["tint"], "sepia", who)
		var pic: Image = CutsceneScript.picture(scene["steps"][0]["picture"])
		assert_gt(pic.get_width(), 200, "%s 的场景不是空的" % who)
	var ahe: Dictionary = CutsceneScript.memory_scene("res://dialogue/ahe.dialogue", "memory_5")["steps"][0]
	var moved := _shifted(CutsceneScript.compose(ahe["picture"], ahe["cast"], 0.0, 2.2, true), CutsceneScript.compose(ahe["picture"], ahe["cast"], 2.2, 2.2, true))
	assert_gt(moved["left"], 20, "阿禾离开了左边")
	assert_gt(moved["right"], 20, "阿禾走到招牌那边")
	var climb: Dictionary = CutsceneScript.memory_scene("res://dialogue/laoqin.dialogue", "memory_5")["steps"][0]
	var rose := _rose(CutsceneScript.compose(climb["picture"], climb["cast"], 0.0, 2.2, true), CutsceneScript.compose(climb["picture"], climb["cast"], 2.2, 2.2, true))
	assert_gt(rose["high"], 10, "老秦爬到了梯子上段")
	assert_gt(rose["low"], 10, "老秦离开了梯子下段")


func _rose(a: Image, b: Image) -> Dictionary:
	var high := 0
	var low := 0
	for y in a.get_height():
		for x in range(110, 180):
			if a.get_pixel(x, y) == b.get_pixel(x, y):
				continue
			if y < 80:
				high += 1
			elif y > 110:
				low += 1
	return {"high": high, "low": low}


func test_cutscenes_move_continuously() -> void:
	var open := CutsceneScript.opening_steps()
	assert_true(open[0].get("anim", false), "开场的桌子是播出来的")
	assert_eq(open[3].get("picture"), &"", "最后一段仍露出农舍")
	var early: Image = CutsceneScript.picture_at(&"desk", 0.1, 2.8)
	var late: Image = CutsceneScript.picture_at(&"desk", 2.8, 2.8)
	assert_gt(_red_right(early), _red_right(late), "信从右边滑到桌上")
	var ink_early := _ink(CutsceneScript.picture_at(&"letter", 0.15, 2.8))
	var ink_late := _ink(CutsceneScript.picture_at(&"letter", 2.8, 2.8))
	assert_gt(ink_late, ink_early + 30, "信上的字一行行写出来")
	var win0: Image = CutsceneScript.picture_at(&"window", 0.0, 2.8)
	var win1: Image = CutsceneScript.picture_at(&"window", 2.6, 2.8)
	assert_eq(win0.get_pixel(16, 24), win1.get_pixel(16, 24), "窗框不动")
	assert_gt(_diff(win0, win1), 30, "窗外的树和雾在往后退")
	var flame: Dictionary = CutsceneScript.ending_steps(&"clear")[0]
	assert_true(flame.get("anim", false))
	assert_eq(flame["walk"], [], "结局不再用色块小人滑过去")
	var hat_x: Array[int] = []
	for i in 4:
		hat_x.append(_straw_x(CutsceneScript.picture_at(&"end_flame", 0.12 + float(i) * 0.28, 2.6)))
	assert_lt(hat_x[0], hat_x[1], "人朝灯走")
	assert_lt(hat_x[1], hat_x[2], "人还在朝灯走")
	assert_lt(hat_x[2], hat_x[3], "走到灯前才停")
	var hat_y: Array[int] = []
	for i in 4:
		var seconds := float(i) * 0.7
		var shaft := CutsceneArt.at(&"end_climb", seconds / 2.6, seconds)
		hat_y.append(_climber_y(CutsceneScript.picture_at(&"end_climb", seconds, 2.6), shaft))
	assert_gt(hat_y[0], hat_y[1], "人顺着梯子往上")
	assert_gt(hat_y[1], hat_y[2])
	assert_gt(hat_y[2], hat_y[3])
	var prev: Image = CutsceneScript.picture_at(&"end_step", 0.0, 2.6)
	for i in 4:
		var cur: Image = CutsceneScript.picture_at(&"end_step", float(i + 1) * 0.55, 2.6)
		var changed := _diff(prev, cur)
		assert_gt(changed, 15, "鹿的腿在换")
		assert_lt(changed, 4000, "背景没有整张换掉")
		prev = cur


func _red_right(img: Image) -> int:
	var best := -1
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.r > 0.55 and c.r > c.g + 0.2 and c.r > c.b + 0.2 and x > best:
				best = x
	return best


func _ink(img: Image) -> int:
	var n := 0
	for y in range(26, 82):
		for x in range(40, 140):
			var c := img.get_pixel(x, y)
			if c.b > c.r + 0.02:
				n += 1
	return n


func _diff(a: Image, b: Image) -> int:
	var n := 0
	for y in range(0, a.get_height(), 2):
		for x in range(0, a.get_width(), 2):
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				n += 1
	return n


func _straw_x(img: Image) -> int:
	var best := -1
	for y in range(30, 100):
		for x in range(0, 120):
			if _straw(img.get_pixel(x, y)) and x > best:
				best = x
	return best


func _climber_y(img: Image, shaft: Image) -> int:
	# 同一个时间点只差人物图层，换服装颜色也能测出攀登高度。
	for y in img.get_height():
		for x in range(60, 130):
			if img.get_pixel(x, y) != shaft.get_pixel(x, y):
				return y
	return img.get_height()


func _straw_y(img: Image) -> int:
	var best := 999
	for y in img.get_height():
		for x in range(50, 140):
			if _straw(img.get_pixel(x, y)) and y < best:
				best = y
	return best


func _shifted(a: Image, b: Image) -> Dictionary:
	var left := 0
	var right := 0
	for y in range(80, 160):
		for x in a.get_width():
			if a.get_pixel(x, y) == b.get_pixel(x, y):
				continue
			if x < 80:
				left += 1
			elif x > 120:
				right += 1
	return {"left": left, "right": right}
