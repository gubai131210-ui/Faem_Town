extends GutTest
## M10 第一批：夏至天黑推迟两小时、冬至天黑提前两小时（夜最长）。
## 只挪黄昏这一头，天亮不动；天色、灯、窗、萤火虫、夜行的鱼和夜曲跟着挪，
## 居民作息和动物进舍按钟点走，不挪。

const Game := preload("res://game/game.gd")


func before_each() -> void:
	GameClock.day = 1
	GameClock.minutes = 600.0


func test_dusk_shift_only_on_the_two_solstices() -> void:
	GameClock.day = 1
	assert_eq(GameClock.dusk_shift(), 0.0, "立春不挪")
	# 夏至是总第 37–40 天
	GameClock.day = 37
	assert_eq(GameClock.term_id(), &"xiazhi")
	assert_eq(GameClock.dusk_shift(), GameClock.SOLSTICE_SHIFT, "夏至天黑推迟两小时")
	# 冬至是总第 85–88 天
	GameClock.day = 85
	assert_eq(GameClock.term_id(), &"dongzhi")
	assert_eq(GameClock.dusk_shift(), -GameClock.SOLSTICE_SHIFT, "冬至天黑提前两小时")
	GameClock.day = 53
	assert_eq(GameClock.term_id(), &"chushu")
	assert_eq(GameClock.dusk_shift(), 0.0, "别的节气不挪")


func test_night_fish_dusk_shifts_but_dawn_does_not() -> void:
	var shift := GameClock.SOLSTICE_SHIFT
	# 夏至：平常七点入夜，推迟到九点；凌晨五点天亮不变
	assert_true(Fishing.is_night(19 * 60.0), "平常七点算夜里")
	assert_false(Fishing.is_night(19 * 60.0, shift), "夏至七点还没黑")
	assert_true(Fishing.is_night(21 * 60.0, shift), "夏至九点入夜")
	assert_true(Fishing.is_night(5 * 60.0 - 1.0, shift), "夏至天亮前还是夜里")
	assert_false(Fishing.is_night(5 * 60.0, shift), "夏至照样五点天亮")
	# 冬至：入夜提前到五点；凌晨天亮不变
	assert_false(Fishing.is_night(17 * 60.0), "平常五点不算夜里")
	assert_true(Fishing.is_night(17 * 60.0, -shift), "冬至五点就黑了")
	assert_true(Fishing.is_night(5 * 60.0 - 1.0, -shift), "冬至天亮前还是夜里")
	assert_false(Fishing.is_night(5 * 60.0, -shift), "冬至照样五点天亮")


func test_tint_dusk_keyframes_shift_but_dawn_and_deep_night_stay() -> void:
	var shift := GameClock.SOLSTICE_SHIFT
	# 天亮两头不动
	assert_eq(Game._dusk_key(360.0, shift), 360.0)
	assert_eq(Game._dusk_key(480.0, shift), 480.0)
	assert_eq(Game._dusk_key(360.0, -shift), 360.0)
	assert_eq(Game._dusk_key(480.0, -shift), 480.0)
	# 深夜最后一帧不动
	assert_eq(Game._dusk_key(GameClock.DAY_END, shift), GameClock.DAY_END)
	assert_eq(Game._dusk_key(GameClock.DAY_END, -shift), GameClock.DAY_END)
	# 黄昏各帧跟着挪
	for t: float in [1020.0, 1110.0, 1200.0, 1320.0]:
		assert_eq(Game._dusk_key(t, shift), t + shift, "夏至黄昏推迟")
		assert_eq(Game._dusk_key(t, -shift), t - shift, "冬至黄昏提前")
	assert_eq(Game._dusk_key(1110.0, 0.0), 1110.0, "不挪时原样")