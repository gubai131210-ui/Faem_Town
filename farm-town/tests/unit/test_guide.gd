extends GutTest
## M7 第二批：第一天左下角的下一步。


func before_each() -> void:
	SaveSystem.reset_all()
	GameClock.day = 1
	GameClock.minutes = 600.0


func after_each() -> void:
	SaveSystem.reset_all()
	GameClock.day = 1


func test_the_first_day_walks_through_letter_till_plant_water_and_bed() -> void:
	assert_true(Guide.line().contains("信箱"))
	GameState.set_flag(&"read_letter")
	assert_true(Guide.line().contains("锄头"))
	Farming.state.till(Vector2i(3, 3))
	assert_true(Guide.line().contains("种子"))
	Farming.state.plant(Vector2i(3, 3), &"white_radish")
	assert_true(Guide.line().contains("水壶"))
	Farming.state.water(Vector2i(3, 3))
	assert_true(Guide.line().contains("床"))
	GameClock.day = 2
	assert_eq(Guide.line(), "")


func test_farming_before_the_letter_still_moves_on() -> void:
	Farming.state.till(Vector2i(4, 4))
	Farming.state.plant(Vector2i(4, 4), &"white_radish")
	Farming.state.water(Vector2i(4, 4))
	assert_true(Guide.line().contains("信箱"), "地种完了还没看信，就去看信")
	GameState.set_flag(&"read_letter")
	assert_true(Guide.line().contains("床"))


func test_the_hud_shows_the_line_and_hides_it_after_day_one() -> void:
	var hud := Hud.new()
	add_child_autofree(hud)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(hud.guide_text().contains("信箱"), hud.guide_text())
	GameClock.day = 2
	await get_tree().process_frame
	assert_eq(hud.guide_text(), "")
