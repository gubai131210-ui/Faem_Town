extends GutTest
## 常驻界面：增益那一小条、左上角的提示条。


func before_each() -> void:
	SaveSystem.reset_all()
	GameClock.day = 1
	GameClock.minutes = 600.0


func after_each() -> void:
	SaveSystem.reset_all()


func _hud() -> Hud:
	var hud := Hud.new()
	add_child_autofree(hud)
	return hud


func test_buff_left_counts_down_and_ends() -> void:
	assert_eq(GameState.buff_left(), 0)
	assert_eq(GameState.buff_text(), "")
	GameState.energy = 50
	GameState.eat(Database.item(&"plain_noodles"))
	assert_eq(GameState.buff_left(), 180)
	assert_eq(GameState.buff_text(), "脚步轻快 3:00")
	GameClock.minutes = 600.0 + 115.0
	assert_eq(GameState.buff_text(), "脚步轻快 1:05")
	GameClock.minutes = 600.0 + 180.0
	assert_eq(GameState.buff_left(), 0, "到点就没了")
	GameClock.minutes = 600.0
	GameState.eat(Database.item(&"plain_noodles"))
	GameClock.advance_day()
	GameClock.minutes = 400.0
	assert_eq(GameState.buff_text(), "", "睡一觉就没了")


func test_hud_shows_buff_only_while_it_lasts() -> void:
	var hud := _hud()
	var box: Control = hud.get(&"_buff_box")
	var label: Label = hud.get(&"_buff")
	assert_false(box.visible, "没吃东西不显示")
	GameState.energy = 50
	GameState.eat(Database.item(&"radish_soup"))
	assert_false(box.visible, "不带效果的菜不显示")
	GameState.eat(Database.item(&"egg_fried_rice"))
	assert_true(box.visible, "吃完马上显示")
	assert_string_contains(label.text, "干活省力")
	GameClock.minutes = 600.0 + float(Database.item(&"egg_fried_rice").buff_minutes) + 1.0
	GameClock.time_changed.emit()
	assert_false(box.visible, "到点就收起来")


func test_banner_is_a_small_toast_in_the_corner() -> void:
	var hud := _hud()
	await wait_frames(2)
	hud.show_banner("收了")
	await wait_frames(2)
	assert_eq(hud.toast_count(), 1)
	var small := hud.toast_rect()
	assert_lt(small.size.x, 60.0, "短的一句只占一小条")
	assert_lt(small.size.y, 20.0)
	hud.show_banner("榨油机：空着。油菜、芝麻、大豆两份榨一壶菜油；雾铃草榨灯油。再多写几个字凑够一行放不下的长度")
	await wait_frames(2)
	var both := hud.toast_rect()
	assert_eq(hud.toast_count(), 2, "新的一条摞在下面")
	assert_lt(both.end.x, 230.0, "长的折行，不伸到屏幕右半边")
	assert_lt(both.end.y, 70.0, "不盖住屏幕中间")
	assert_gt(both.size.y, small.size.y + 20.0, "折成了几行")


func test_same_banner_does_not_stack_and_old_ones_drop_off() -> void:
	var hud := _hud()
	hud.show_banner("背包满了")
	hud.show_banner("背包满了")
	assert_eq(hud.toast_count(), 1, "一样的话只挂一条")
	hud.show_banner("")
	assert_eq(hud.toast_count(), 1, "空话不挂")
	hud.show_banner("第二条")
	hud.show_banner("第三条")
	hud.show_banner("第四条")
	assert_eq(hud.toast_count(), Hud.MAX_TOASTS)
	assert_eq(Array(hud.toast_texts()), ["第二条", "第三条", "第四条"], "最旧的被顶掉")


func test_banner_after_a_line_break_is_a_smaller_note() -> void:
	var hud := _hud()
	hud.show_banner("沉灯井 · 浅坑 · 第 1 层\n拿着武器按使用键挥砍")
	var toast: Control = hud.get(&"_toasts").get_child(0)
	var labels := toast.get_child(0).get_children()
	assert_eq(labels.size(), 2)
	assert_eq((labels[0] as Label).text, "沉灯井 · 浅坑 · 第 1 层")
	assert_eq((labels[1] as Label).text, "拿着武器按使用键挥砍")
	assert_lt((labels[1] as Label).get_theme_font_size(&"font_size"), (labels[0] as Label).get_theme_font_size(&"font_size"))


func test_toast_fades_and_goes_away() -> void:
	var hud := _hud()
	hud.show_banner("收了")
	await wait_seconds(Hud.banner_hold("收了") + 0.9)
	assert_eq(hud.toast_count(), 0)


func test_silence_stops_every_sound() -> void:
	Audio.play("harvest")
	Audio.play_radio(Weather.report_clips())
	assert_true(Audio.is_radio_playing())
	Audio.silence()
	assert_false(Audio.is_radio_playing(), "收音机停了")
	for p: AudioStreamPlayer in Audio.get("_players"):
		assert_false(p.playing, "音效停了")
	var music: AudioStreamPlayer = Audio.get("_music")
	assert_false(music.playing, "音乐停了")
	# 退出途中不再放新的声音
	Audio.muted = true
	Audio.play("harvest")
	Audio.play_radio(Weather.report_clips())
	Audio.muted = false
	assert_false(Audio.is_radio_playing())
	for p: AudioStreamPlayer in Audio.get("_players"):
		assert_false(p.playing, "退出途中不出声")
