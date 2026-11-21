extends GutTest
## 背景音乐：季节、夜晚、节日、井下，再加上竹海、后山、雾岛和室内。


func before_each() -> void:
	SaveSystem.reset_all()
	GameClock.day = 1
	GameClock.minutes = 600.0


func after_each() -> void:
	SaveSystem.reset_all()
	GameClock.day = 1
	GameClock.minutes = 600.0


func test_music_follows_season_then_night_festival_and_the_mine() -> void:
	assert_eq(Audio.music_cue(), &"spring")
	GameClock.day = 30
	assert_eq(Audio.music_cue(), &"summer")
	GameClock.day = 50
	assert_eq(Audio.music_cue(), &"autumn")
	GameClock.day = 80
	assert_eq(Audio.music_cue(), &"winter")
	GameClock.minutes = 1100.0
	assert_eq(Audio.music_cue(), &"night", "傍晚六点以后是夜晚")
	GameClock.minutes = 60.0
	assert_eq(Audio.music_cue(), &"night", "清晨以前也是夜晚")
	GameClock.day = 13
	GameClock.minutes = 600.0
	assert_eq(Audio.music_cue(), &"festival", "播种节开着时盖过春天")
	GameClock.day = 17
	GameClock.minutes = 1140.0
	assert_eq(Audio.music_cue(), &"festival", "夜里的放河灯仍是节日")
	GameState.map_id = &"mine"
	assert_eq(Audio.music_cue(), &"mine", "井下盖过节日")


func test_place_tunes_cover_the_night_and_a_festival() -> void:
	GameClock.minutes = 1100.0
	GameState.map_id = &"zhuhai"
	assert_eq(Audio.music_cue(), &"zhuhai", "竹海里夜里也是竹海")
	GameState.map_id = &"houshan"
	assert_eq(Audio.music_cue(), &"houshan")
	GameClock.day = 13
	GameClock.minutes = 600.0
	GameState.map_id = &"wudao"
	assert_eq(Audio.music_cue(), &"wudao", "雾岛盖过节日")
	GameState.map_id = &"farmhouse"
	assert_eq(Audio.music_cue(), &"indoor")
	GameState.map_id = &"teahouse"
	assert_eq(Audio.music_cue(), &"indoor", "茶馆和农舍是同一首")
	GameState.map_id = &"mine"
	assert_eq(Audio.music_cue(), &"mine", "井下仍盖过屋里")


func test_eleven_loops_get_synthesized() -> void:
	for _i in 100:
		if Audio.track_count() >= 11:
			break
		await wait_seconds(0.05)
	assert_eq(Audio.track_count(), 11)
	var seen: Array[PackedByteArray] = []
	for id: String in ["spring", "summer", "autumn", "winter", "mine", "festival", "night",
			"zhuhai", "houshan", "wudao", "indoor"]:
		var stream: AudioStreamWAV = Audio.get("_tracks")[StringName(id)]
		assert_gt(stream.data.size(), 1000, "%s 有一段循环" % id)
		assert_false(seen.has(stream.data), "%s 跟别的曲子不是同一段" % id)
		seen.append(stream.data)


func test_radio_clips_differ() -> void:
	var spring_term := load("res://audio/radio/today_lichun.wav") as AudioStreamWAV
	var rain_term := load("res://audio/radio/today_yushui.wav") as AudioStreamWAV
	var sunny := load("res://audio/radio/w_sunny.wav") as AudioStreamWAV
	assert_gt(spring_term.data.size(), 4000, "立春这一句有声音")
	assert_ne(spring_term.data, rain_term.data)
	assert_ne(spring_term.data, sunny.data)
