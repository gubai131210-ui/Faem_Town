extends GutTest
## 核心系统：数据表、背包、时钟、耕种状态、存读档。

const TMP_SAVES := "user://test_saves"

var _old_dir := ""


func before_each() -> void:
	_old_dir = SaveSystem.base_dir
	SaveSystem.base_dir = TMP_SAVES
	SaveSystem.reset_all()


func after_each() -> void:
	for i in SaveSystem.SLOT_COUNT:
		SaveSystem.delete(i)
	SaveSystem.base_dir = _old_dir
	SaveSystem.current_slot = -1
	SaveSystem.reset_all()


# ---------------------------------------------------------------- 数据表

func test_database_has_no_validation_errors() -> void:
	var problems := Database.validate()
	assert_eq(problems.size(), 0, "数据表问题：%s" % ", ".join(problems))


func test_seed_points_to_its_crop_and_back() -> void:
	var seed := Database.item(&"white_radish_seed")
	assert_not_null(seed)
	var crop := Database.crop(seed.crop)
	assert_not_null(crop)
	assert_eq(crop.produce, &"white_radish")


func test_palette_is_shared_by_code_art() -> void:
	assert_true(Palette.colors().has("s"))
	assert_eq(Palette.c("e"), Color.html(str(JsonFile.read_dict("res://data/palette.json")["e"])))


# ---------------------------------------------------------------- 作物定义

func test_crop_stage_follows_watered_days() -> void:
	var crop := Database.crop(&"white_radish")
	assert_eq(crop.total_days(), 5)
	assert_eq(crop.stage_for(0), 0)
	assert_eq(crop.stage_for(1), 1)
	assert_eq(crop.stage_for(2), 1)
	assert_eq(crop.stage_for(3), 2)
	assert_eq(crop.stage_for(5), 3)
	assert_false(crop.is_ripe(4))
	assert_true(crop.is_ripe(5))


# ---------------------------------------------------------------- 背包

func test_inventory_stacks_then_uses_empty_slots() -> void:
	var inv := Inventory.new(2)
	assert_eq(inv.add(&"white_radish", 60), 0)
	assert_eq(inv.add(&"white_radish", 60), 0)
	assert_eq(inv.count_at(0), 99)
	assert_eq(inv.count_at(1), 21)
	assert_eq(inv.count_of(&"white_radish"), 120)


func test_inventory_reports_leftover_when_full() -> void:
	var inv := Inventory.new(1)
	assert_eq(inv.add(&"hoe"), 0)
	assert_false(inv.can_add(&"hoe"))
	assert_eq(inv.add(&"hoe"), 1, "放不下的数量要返回")
	assert_eq(inv.count_of(&"hoe"), 1)


func test_inventory_can_add_counts_partial_stacks() -> void:
	var inv := Inventory.new(1)
	inv.add(&"white_radish", 90)
	assert_true(inv.can_add(&"white_radish", 9))
	assert_false(inv.can_add(&"white_radish", 10))
	assert_false(inv.can_add(&"no_such_item"))


func test_inventory_remove_and_swap() -> void:
	var inv := Inventory.new(3)
	inv.add(&"hoe")
	inv.add(&"white_radish_seed", 5)
	assert_true(inv.remove(&"white_radish_seed", 2))
	assert_eq(inv.count_of(&"white_radish_seed"), 3)
	assert_false(inv.remove(&"white_radish_seed", 4), "不够时不扣")
	assert_eq(inv.count_of(&"white_radish_seed"), 3)
	inv.swap(0, 2)
	assert_eq(inv.id_at(2), &"hoe")
	assert_eq(inv.id_at(0), &"")
	assert_true(inv.remove(&"white_radish_seed", 3))
	assert_eq(inv.id_at(1), &"", "扣完后格子清空")


func test_inventory_round_trips_through_array() -> void:
	var inv := Inventory.new(4)
	inv.add(&"hoe")
	inv.add(&"white_radish_seed", 7)
	inv.swap(1, 3)
	var copy := Inventory.new(4)
	copy.from_array(inv.to_array())
	assert_eq(copy.id_at(0), &"hoe")
	assert_eq(copy.id_at(1), &"")
	assert_eq(copy.id_at(3), &"white_radish_seed")
	assert_eq(copy.count_at(3), 7)


# ---------------------------------------------------------------- 时钟

func test_clock_calendar() -> void:
	GameClock.day = 1
	assert_eq(GameClock.date_text(), "春 1日")
	assert_eq(GameClock.season_id(), &"spring")
	GameClock.day = 25
	assert_eq(GameClock.date_text(), "夏 1日")
	assert_eq(GameClock.year(), 1)
	GameClock.day = 96
	assert_eq(GameClock.date_text(), "冬 24日")
	GameClock.day = 97
	assert_eq(GameClock.date_text(), "春 1日")
	assert_eq(GameClock.year(), 2)


func test_clock_time_text_rounds_to_ten_minutes_and_wraps_midnight() -> void:
	GameClock.minutes = 367.0
	assert_eq(GameClock.time_text(), "06:00")
	GameClock.minutes = 1475.0
	assert_eq(GameClock.time_text(), "00:30")


func test_advance_day_runs_daily_steps_in_order() -> void:
	var calls: Array[int] = []
	GameClock.register_daily(GameClock.ORDER_SHIPPING, func() -> void: calls.append(2))
	GameClock.register_daily(GameClock.ORDER_WEATHER, func() -> void: calls.append(1))
	GameClock.minutes = 1200.0
	watch_signals(GameClock)
	GameClock.advance_day()
	assert_eq(GameClock.day, 2)
	assert_eq(GameClock.minutes, GameClock.DAY_START)
	assert_eq(calls, [1, 2] as Array[int])
	assert_signal_emitted(GameClock, "day_started")


# ---------------------------------------------------------------- 耕种

func test_crop_only_grows_on_watered_soil() -> void:
	var farm := FarmState.new()
	var t := Vector2i(3, 4)
	assert_false(farm.can_plant(t), "没开垦不能种")
	assert_true(farm.till(t))
	assert_false(farm.till(t), "不能重复开垦")
	assert_true(farm.plant(t, &"white_radish"))
	assert_false(farm.can_plant(t), "已经有作物")
	farm.advance_day()
	assert_eq(farm.crop_days_at(t), 0, "没浇水不长")
	farm.water(t)
	farm.advance_day()
	assert_eq(farm.crop_days_at(t), 1)
	assert_false(farm.soil[t], "过夜后变干")


func test_harvest_returns_crop_and_clears_tile() -> void:
	var farm := FarmState.new()
	var t := Vector2i(1, 1)
	farm.till(t)
	farm.plant(t, &"white_radish")
	assert_eq(farm.harvest(t), &"", "没熟不能收")
	for i in 5:
		farm.water(t)
		farm.advance_day()
	assert_true(farm.is_ripe(t))
	assert_eq(farm.harvest(t), &"white_radish")
	assert_eq(farm.crop_id_at(t), &"")
	assert_true(farm.can_plant(t), "收完可以再种")


func test_farm_state_round_trips_through_dict() -> void:
	var farm := FarmState.new()
	farm.till(Vector2i(2, 9))
	farm.till(Vector2i(-1, 5))
	farm.water(Vector2i(2, 9))
	farm.plant(Vector2i(2, 9), &"white_radish")
	farm.advance_day()
	farm.water(Vector2i(-1, 5))
	var data: Variant = JSON.parse_string(JSON.stringify(farm.to_dict()))
	var copy := FarmState.new()
	copy.from_dict(data)
	assert_eq(copy.soil.size(), 2)
	assert_true(copy.soil[Vector2i(-1, 5)])
	assert_false(copy.soil[Vector2i(2, 9)])
	assert_eq(copy.crop_id_at(Vector2i(2, 9)), &"white_radish")
	assert_eq(copy.crop_days_at(Vector2i(2, 9)), 1)


# ---------------------------------------------------------------- 存读档

func test_save_and_load_restore_every_system() -> void:
	GameClock.day = 30
	GameState.money = 1234
	GameState.energy = 40
	GameState.selected_slot = 3
	GameState.set_flag(&"read_letter")
	GameState.map_id = &"farmhouse"
	GameState.spawn = &"bed"
	GameState.inventory.add(&"white_radish", 8)
	Farming.state.till(Vector2i(5, 5))
	Farming.state.plant(Vector2i(5, 5), &"white_radish")
	assert_true(SaveSystem.save(1, GameState.save_meta()))

	SaveSystem.reset_all()
	assert_eq(GameClock.day, 1)
	assert_eq(Farming.state.soil.size(), 0)
	assert_false(GameState.has_flag(&"read_letter"))

	assert_true(SaveSystem.load_slot(1))
	assert_eq(GameClock.day, 30)
	assert_eq(GameState.money, 1234)
	assert_eq(GameState.energy, 40)
	assert_eq(GameState.selected_slot, 3)
	assert_true(GameState.has_flag(&"read_letter"))
	assert_eq(GameState.map_id, &"farmhouse")
	assert_eq(GameState.spawn, &"bed")
	assert_eq(GameState.inventory.count_of(&"white_radish"), 8)
	assert_eq(GameState.inventory.count_of(&"white_radish_seed"), 12)
	assert_eq(Farming.state.crop_id_at(Vector2i(5, 5)), &"white_radish")
	assert_eq(SaveSystem.current_slot, 1)


func test_slot_meta_is_readable_without_loading() -> void:
	GameClock.day = 26
	GameState.money = 77
	SaveSystem.save(2, GameState.save_meta())
	SaveSystem.reset_all()
	var meta := SaveSystem.slot_meta(2)
	assert_eq(str(meta.get("date")), "夏 2日")
	assert_eq(int(meta.get("money")), 77)
	assert_eq(GameClock.day, 1, "读摘要不应该改动游戏状态")
	assert_true(SaveSystem.slot_meta(0).is_empty())


func test_corrupt_save_falls_back_to_backup() -> void:
	GameState.money = 111
	SaveSystem.save(0)
	GameState.money = 222
	SaveSystem.save(0)
	var f := FileAccess.open(SaveSystem.slot_path(0), FileAccess.WRITE)
	f.store_string("{ 这不是合法的存档")
	f.close()
	assert_true(SaveSystem.load_slot(0), "主文件坏了应该读备份")
	assert_eq(GameState.money, 111)
	assert_false(SaveSystem.write_blocked)


func test_unreadable_save_blocks_overwrite() -> void:
	DirAccess.make_dir_recursive_absolute(TMP_SAVES)
	var f := FileAccess.open(SaveSystem.slot_path(0), FileAccess.WRITE)
	f.store_string("坏的")
	f.close()
	assert_false(SaveSystem.load_slot(0))
	assert_true(SaveSystem.write_blocked)
	assert_false(SaveSystem.save(0), "读不出来的存档不能被自动覆盖")
	assert_push_warning("阻止存档")


func test_delete_removes_save_and_backup() -> void:
	SaveSystem.save(0)
	SaveSystem.save(0)
	SaveSystem.delete(0)
	assert_false(SaveSystem.has_save(0))
	assert_false(FileAccess.file_exists(SaveSystem.slot_path(0) + ".bak"))
