extends Node
## 宣传片段。一段一段演，不检查对错，演完停住，方便录。
##
## 开窗口，先出一张单，按 1 到 8 选一段，9 按顺序演完，Q 退出：
##   Godot 可执行文件 --path . res://tests/reel/reel.tscn
## 指定一段，不出现选单，演完自己关。PowerShell：
##   $env:REEL="field"; Godot 可执行文件 --path . res://tests/reel/reel.tscn
## 名字：field 田里，town 镇上，fish 池塘，cook 灶上，fest 播种节，
## mine 下井，fox 竹海，pond 文鳐，weather 四季天气，title 片头，end 片尾，
## all 八段按顺序，trailer 带字幕的整片（片头、各段、片尾）。
## 录视频见 tools/record_trailer.ps1。
## 存档写在 user://reel_saves，不碰玩家的档。
## REEL_SHOT=1 时，每一段把一张画面存到 _preview/reel_<名字>.png。

const Catalog := preload("res://tests/reel/catalog.gd")
const CutsceneScript := preload("res://game/cutscene.gd")
const SAVE_DIR := "user://reel_saves"

var is_runner := false
var _from_env := false
var _picking := false
var _done := false
var _dead := false
var _layer: CanvasLayer
var _cap_layer: CanvasLayer
var _cap_band: ColorRect
var _cap_dim: ColorRect
var _cap_title: Label
var _cap_sub: Label
var _cap_tween: Tween


func _ready() -> void:
	if is_runner:
		_boot()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set(&"is_runner", true)
	runner.name = "ReelRunner"
	runner.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child.call_deferred(runner)


func _boot() -> void:
	_build_picker()
	_build_caption()
	var asked := OS.get_environment("REEL").strip_edges()
	if asked == "":
		_show_picker()
		return
	if not Catalog.known(asked):
		print("REEL FAIL 没有这一段：" + asked)
		_quit(1)
		return
	_from_env = true
	var limit := 400.0
	if asked == "all":
		limit = 300.0
	if asked == "trailer":
		limit = 600.0
	if asked == "full":
		limit = 1500.0
	_watch(limit)
	_play(asked)


func _build_picker() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 120
	_layer.visible = false
	var root := UiKit.root()
	var backdrop := ColorRect.new()
	backdrop.color = Color("1c3a2a")
	backdrop.anchor_right = 1.0
	backdrop.anchor_bottom = 1.0
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(backdrop)
	var text := UiKit.label(Catalog.menu_text(), 12, Color("fff6d8"), true)
	text.position = Vector2(24, 16)
	root.add_child(text)
	_layer.add_child(root)
	add_child(_layer)


## 字幕：底部一条半透明的带子，大字加小字。片头压在变暗的画面中间，片尾是几乎全黑的卡。
func _build_caption() -> void:
	_cap_layer = CanvasLayer.new()
	_cap_layer.layer = 125
	var root := UiKit.root()
	_cap_dim = ColorRect.new()
	_cap_dim.color = Color(0.03, 0.06, 0.05, 0.0)
	_cap_dim.anchor_right = 1.0
	_cap_dim.anchor_bottom = 1.0
	_cap_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_cap_dim)
	_cap_band = ColorRect.new()
	_cap_band.color = Color(0.03, 0.06, 0.05, 0.62)
	_cap_band.anchor_top = 1.0
	_cap_band.anchor_right = 1.0
	_cap_band.anchor_bottom = 1.0
	_cap_band.offset_top = -46.0
	_cap_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_cap_band)
	_cap_title = UiKit.label("", 17, Color("fff2c4"), true)
	_cap_title.anchor_right = 1.0
	_cap_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_cap_title)
	_cap_sub = UiKit.label("", 10, Color("e8f1dc"), true)
	_cap_sub.anchor_right = 1.0
	_cap_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_cap_sub)
	_cap_layer.add_child(root)
	add_child(_cap_layer)
	_cap_band.modulate.a = 0.0
	_cap_title.modulate.a = 0.0
	_cap_sub.modulate.a = 0.0


func _caption_on(id: String) -> void:
	var big := Catalog.caption_title(id)
	if big == "":
		return
	_cap_title.text = big
	_cap_sub.text = Catalog.caption_sub(id)
	var card := Catalog.is_card(id)
	var top := Catalog.is_top(id)
	var size := 17
	if id == "title":
		size = 30
	elif id == "end" or card:
		size = 22
	_cap_title.add_theme_font_size_override(&"font_size", size)
	# 字幕带在下面（默认）或上面（过场自己的字在下面）
	_cap_band.anchor_top = 0.0 if top else 1.0
	_cap_band.anchor_bottom = 0.0 if top else 1.0
	_cap_band.offset_top = 0.0 if top else -46.0
	_cap_band.offset_bottom = 46.0 if top else 0.0
	if id == "title":
		_cap_title.position = Vector2(0, 84)
		_cap_sub.position = Vector2(0, 124)
	elif id == "end" or card:
		_cap_title.position = Vector2(0, 88)
		_cap_sub.position = Vector2(0, 124)
	elif top:
		_cap_title.position = Vector2(0, 2)
		_cap_sub.position = Vector2(0, 26)
	else:
		_cap_title.position = Vector2(0, 172)
		_cap_sub.position = Vector2(0, 196)
	if _cap_tween != null:
		_cap_tween.kill()
	_cap_tween = create_tween().set_parallel(true)
	_cap_tween.tween_property(_cap_title, "modulate:a", 1.0, 0.5)
	_cap_tween.tween_property(_cap_sub, "modulate:a", 1.0, 0.7)
	if id == "title":
		_cap_tween.tween_property(_cap_dim, "color:a", 0.55, 0.5)
	elif id == "end":
		_cap_tween.tween_property(_cap_dim, "color:a", 0.92, 0.9)
	elif card:
		_cap_tween.tween_property(_cap_dim, "color:a", 1.0, 0.4)
	else:
		_cap_tween.tween_property(_cap_band, "modulate:a", 1.0, 0.4)


func _caption_off(id: String) -> void:
	if id == "end":
		return
	if _cap_tween != null:
		_cap_tween.kill()
	_cap_tween = create_tween().set_parallel(true)
	_cap_tween.tween_property(_cap_title, "modulate:a", 0.0, 0.35)
	_cap_tween.tween_property(_cap_sub, "modulate:a", 0.0, 0.35)
	_cap_tween.tween_property(_cap_band, "modulate:a", 0.0, 0.35)
	_cap_tween.tween_property(_cap_dim, "color:a", 0.0, 0.35)


func _show_picker() -> void:
	_picking = true
	_layer.visible = true
	get_tree().paused = true


func _unhandled_input(event: InputEvent) -> void:
	if not _picking or not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	var id := _id_for(key.physical_keycode)
	if id == "":
		if key.physical_keycode == KEY_Q:
			get_viewport().set_input_as_handled()
			_quit(0)
		return
	get_viewport().set_input_as_handled()
	_picking = false
	_layer.visible = false
	get_tree().paused = false
	_play(id)


func _id_for(code: Key) -> String:
	var ids: Array[String] = Catalog.ids()
	var index := -1
	match code:
		KEY_1, KEY_KP_1:
			index = 0
		KEY_2, KEY_KP_2:
			index = 1
		KEY_3, KEY_KP_3:
			index = 2
		KEY_4, KEY_KP_4:
			index = 3
		KEY_5, KEY_KP_5:
			index = 4
		KEY_6, KEY_KP_6:
			index = 5
		KEY_7, KEY_KP_7:
			index = 6
		KEY_8, KEY_KP_8:
			index = 7
		KEY_9, KEY_KP_9:
			return "all"
		_:
			return ""
	if index < 0 or index >= ids.size():
		return ""
	return ids[index]


func _play(id: String) -> void:
	if id == "all":
		for part in Catalog.ids():
			if _dead:
				return
			await _one(part)
			await _wait(0.4)
	elif id == "trailer":
		for part in Catalog.trailer_ids():
			if _dead:
				return
			await _one(part)
	elif id == "full":
		for part in Catalog.full_ids():
			if _dead:
				return
			await _one(part)
	else:
		await _one(id)
	if _dead:
		return
	if _from_env:
		print("REEL PASS")
		_quit(0)
		return
	_show_picker()


func _one(id: String) -> void:
	if _dead:
		return
	print("REEL " + id)
	if id != "end" and not Catalog.is_card(id):
		await _begin()
	if _dead:
		return
	_caption_on(id)
	if Catalog.is_card(id):
		await _wait(0.1)
	elif id == "letter":
		await _letter()
	elif id == "ship":
		await _ship()
	elif id == "fight":
		await _fight()
	elif id == "coop":
		await _coop()
	elif id == "shop":
		await _shop()
	elif id == "lamp":
		await _lamp()
	elif id == "sowing" or id == "lanterns" or id == "fireflies" or id == "harvest" or id == "dumpling" or id == "newyear":
		await _festival(id)
	elif id == "memory":
		await _memory()
	elif id.begins_with("end_"):
		await _ending(id.trim_prefix("end_"))
	elif id == "title":
		await _title()
	elif id == "weather":
		await _weather()
	elif id == "end":
		await _wait(0.2)
	elif id == "field":
		await _field()
	elif id == "town":
		await _town()
	elif id == "fish":
		await _fish()
	elif id == "cook":
		await _cook()
	elif id == "fest":
		await _fest()
	elif id == "mine":
		await _mine()
	elif id == "fox":
		await _fox()
	elif id == "pond":
		await _pond()
	else:
		print("REEL FAIL 没有这一段：" + id)
		_quit(1)
		return
	_release_moves()
	await _wait(0.8 + Catalog.tail(id))
	_caption_off(id)


## 黑屏里开一局新的，跳过开场。亮不亮由这一段自己决定。
## 先换到标题再清空，避免上一局的地图还在时被清掉。清空之后直接进游戏，标题不亮出来。
func _begin() -> void:
	seed(20260101)
	SaveSystem.base_dir = SAVE_DIR
	Audio.music_on = true
	_release_moves()
	await SceneRouter.fade_out(0.2)
	if _dead:
		return
	get_tree().change_scene_to_file(SceneRouter.MENU_SCENE)
	var scene: Node = null
	for _menu_wait in 300:
		scene = get_tree().current_scene
		if scene != null and scene.name == "MainMenu":
			break
		await get_tree().process_frame
	if scene == null or scene.name != "MainMenu":
		print("REEL FAIL 没到标题")
		_quit(1)
		return
	SaveSystem.reset_all()
	for _slot in SaveSystem.SLOT_COUNT:
		SaveSystem.delete(_slot)
	SaveSystem.current_slot = 0
	SaveSystem.save(0, GameState.save_meta())
	Weather.today = Weather.SUNNY
	Weather.tomorrow = Weather.SUNNY
	GameClock.day = 1
	GameClock.minutes = 600.0
	GameState.energy = GameState.max_energy
	# 先留下猫：第二天起进农场会问留狗还是留猫，问话会盖住画面；留了猫，院子里也多一只活物
	GameState.set_flag(&"pet_cat")
	get_tree().change_scene_to_file(SceneRouter.GAME_SCENE)
	var game: Node = null
	for _game_wait in 300:
		scene = get_tree().current_scene
		if scene != null and scene.name == "Game":
			game = scene
			break
		await get_tree().process_frame
	if game == null:
		print("REEL FAIL 没进到游戏里")
		_quit(1)
		return
	await _frames(0.05)
	var opening: Variant = game.get(&"cutscene")
	if opening is Node and bool((opening as Node).get(&"playing")):
		(opening as Node).call(&"skip")
		await _wait(0.35)
	# 第一天的提示框盖住字幕，藏起来（它每帧只改 visible，不碰透明度）
	var hud: Variant = game.get(&"hud")
	if hud is Node:
		var guide: Variant = (hud as Node).get(&"_guide")
		if guide is CanvasItem:
			(guide as CanvasItem).modulate.a = 0.0


## 片头：天刚亮的农场，画面压暗，中间是名字。
func _title() -> void:
	GameClock.minutes = 420.0
	var who := _player()
	if who != null:
		who.place(GameMap.tile_center(Vector2i(19, 11)), GameMap.Facing.RIGHT)
	await _reveal()
	await _wait(1.2)
	await _look("title")


## 四季天气：同一块农场，换季换天气。每一站重新进一次图，地面和树才跟着变色。
func _weather() -> void:
	var who := _player()
	if who != null:
		who.place(GameMap.tile_center(Vector2i(24, 12)), GameMap.Facing.DOWN)
	await _reveal()
	await _wait(1.0)
	var stops: Array = [
		[GameClock.DAYS_PER_SEASON + 6, Weather.RAIN],
		[GameClock.DAYS_PER_SEASON * 2 + 8, Weather.FOG],
		[GameClock.DAYS_PER_SEASON * 3 + 10, Weather.SNOW],
	]
	for stop: Array in stops:
		GameClock.day = int(stop[0])
		GameClock.minutes = 600.0
		Weather.today = stop[1] as StringName
		Weather.tomorrow = Weather.SUNNY
		await SceneRouter.fade_out(0.25)
		await _go(&"farm", &"house_door")
		Weather.changed.emit()
		await _wait(1.3)
		await _look("weather_" + str(stop[1]))


func _field() -> void:
	var rows: Array[Vector2i] = [Vector2i(20, 12), Vector2i(21, 12), Vector2i(22, 12)]
	var who := _player()
	if who == null:
		return
	who.place(GameMap.tile_center(Vector2i(18, 11)), GameMap.Facing.RIGHT)
	await _reveal()
	await _hold(&"move_right", 0.45)
	await _work_row(rows, 0)
	await _work_row(rows, 1)
	await _work_row(rows, 2)
	# 一天天长大：三格一起，出苗、长叶、成熟
	var total := Database.crop(&"white_radish").total_days()
	for fraction in [0.34, 0.7, 1.0]:
		for tile in rows:
			if Farming.state.crop_id_at(tile) != &"white_radish":
				print("REEL NOTE 这一格没种上白萝卜")
				continue
			var grown: Dictionary = Farming.state.crops[tile]
			grown["days"] = maxi(1, int(round(total * float(fraction))))
			Farming.state.crops[tile] = grown
		Farming.state.changed.emit()
		await _wait(0.9)
	await _look("field")
	# 收获：一格一格走过去
	GameState.selected_slot = 0
	for i in rows.size():
		who = _player()
		if who == null:
			return
		if i > 0:
			await _step(&"move_right")
		who.place(GameMap.tile_center(rows[i] + Vector2i(0, -1)), GameMap.Facing.DOWN)
		await _frames(0.08)
		await _press(&"use")
		await _wait(0.4)
	await _wait(0.5)


func _work_row(rows: Array[Vector2i], slot: int) -> void:
	GameState.selected_slot = slot
	for i in rows.size():
		var who := _player()
		if who == null:
			return
		var stand := rows[i] + Vector2i(0, -1)
		if i > 0:
			await _step(&"move_right")
		who.place(GameMap.tile_center(stand), GameMap.Facing.DOWN)
		await _frames(0.08)
		await _press(&"use")
		await _wait(0.22)


func _town() -> void:
	GameState.set_flag(&"prologue_town")
	GameClock.minutes = 600.0
	await _go(&"town", &"from_farm")
	await _hold(&"move_left", 3.6)
	await _look("town")
	await _wait(0.6)


## 钓鱼：四处水边各钓一条。溪里的桃花鱼、雾天河上的雾鲤王、湖里的甲鱼、冬至夜海边的潮生。
## 每一条都走完整的一竿：甩竿、等浮漂、鱼影游近、咬钩提竿、遛鱼收线、举起来看。
func _fish() -> void:
	GameState.inventory.add(&"rod")
	GameState.tool_levels[&"rod"] = 3
	GameState.set_flag(&"lamp_river")
	# 第一条：农场溪里，春天才有的桃花鱼
	await _go(&"farm", &"house_door")
	_stand_on_bank()
	await _wait(0.35)
	await _cast_for(&"peach_fish", "fish_peach")
	# 第二条：河岸，起雾的日子浮上来的雾鲤王
	GameClock.day = GameClock.DAYS_PER_SEASON * 2 + 8
	GameClock.minutes = 600.0
	Weather.today = Weather.FOG
	await _go(&"riverbank", &"")
	Weather.changed.emit()
	_stand_at_water(Vector2i(22, 15))
	await _wait(0.8)
	await _cast_for(&"fog_carp_king", "fish_fogking")
	# 第三条：山祠的湖，夏天上钩的甲鱼
	GameClock.day = GameClock.DAYS_PER_SEASON + 9
	GameClock.minutes = 660.0
	Weather.today = Weather.SUNNY
	await _go(&"shanci", &"")
	Weather.changed.emit()
	_stand_at_water(Vector2i(17, 10))
	await _wait(0.8)
	await _cast_for(&"soft_turtle", "fish_turtle")
	# 第四条：冬至夜的海边，通身发光的潮生
	GameClock.day = GameClock.DAYS_PER_SEASON * 3 + 12
	GameClock.minutes = 1230.0
	Weather.today = Weather.SUNNY
	await _go(&"dongtan", &"")
	Weather.changed.emit()
	_stand_at_water(Vector2i(6, 10))
	await _wait(0.8)
	await _cast_for(&"tide_born", "fish_tide")


## 站到离 hint 最近的一格岸上：脸朝水，前面两格都是能钓的水。
func _stand_at_water(hint: Vector2i) -> void:
	var who := _player()
	if who == null or who.map == null:
		return
	var map := who.map
	var cols := int(map.get(&"cols"))
	var rows := int(map.get(&"rows"))
	var best := Vector2i(-1, -1)
	var best_face := GameMap.Facing.DOWN
	var best_d := 1.0e9
	var dirs: Array = [
		[Vector2i(0, 1), GameMap.Facing.DOWN], [Vector2i(0, -1), GameMap.Facing.UP],
		[Vector2i(1, 0), GameMap.Facing.RIGHT], [Vector2i(-1, 0), GameMap.Facing.LEFT],
	]
	for far in [2, 1]:
		if best.x >= 0:
			break
		for y in rows:
			for x in cols:
				var t := Vector2i(x, y)
				if map.blocked(GameMap.tile_center(t)) or not map.trigger_at(t).is_empty():
					continue
				for pair: Array in dirs:
					var step: Vector2i = pair[0]
					if map.fishing_water(t + step) == &"" or map.fishing_water(t + step * far) == &"":
						continue
					var d := float((t - hint).length_squared())
					if d < best_d:
						best_d = d
						best = t
						best_face = pair[1]
	if best.x >= 0:
		who.place(GameMap.tile_center(best), best_face)


## 一竿到底；鱼用 fish_id（咬钩时换成它），一直钓到举起来为止。
func _cast_for(fish_id: StringName, shot: String) -> void:
	_hold_id(&"rod")
	await _press(&"use")
	var fishing := _fishing()
	for _i in 180:
		if fishing != null and fishing.active():
			break
		await get_tree().process_frame
	if fishing == null or not fishing.active():
		print("REEL nocast ", fish_id, " ", _player().position, " ", _player().facing)
		return
	# 浮漂落水以后等鱼；为了片子紧凑，把等的时间压到两秒多一点，鱼影还是看得到
	for _i in 300:
		if not fishing.active() or fishing.phase == FishingSession.Phase.WAITING:
			break
		await get_tree().process_frame
	if fishing.phase == FishingSession.Phase.WAITING:
		fishing.set(&"_timer", 2.6)
	var swapped := false
	var reeling := false
	var shown := false
	var last_phase := -1
	var seen_fight: FishFight = null
	for _i in 7000:
		if not fishing.active():
			break
		if fishing.fight != null:
			seen_fight = fishing.fight
		if int(fishing.phase) != last_phase:
			last_phase = int(fishing.phase)
			print("REEL phase ", fish_id, " ", last_phase)
		var want := false
		if fishing.phase == FishingSession.Phase.BITE:
			if not swapped:
				swapped = true
				fishing.relic = &""
				fishing.fish = Database.fish_def(fish_id)
			want = true
		elif fishing.phase == FishingSession.Phase.FIGHT and fishing.fight != null:
			var f := fishing.fight
			want = not f.struggling and not f.warning and f.tension < 0.85
			if not shown:
				shown = true
				await _look(shot + "_fight")
		elif fishing.phase == FishingSession.Phase.SHOW:
			want = false
			if shown:
				shown = false
				await _wait(0.5)
				await _look(shot)
		if want and not reeling:
			Input.action_press(&"use")
			reeling = true
		elif not want and reeling:
			Input.action_release(&"use")
			reeling = false
		await get_tree().process_frame
	Input.action_release(&"use")
	if seen_fight != null:
		print("REEL result ", fish_id, " ", seen_fight.result, " d=", seen_fight.distance, " t=", seen_fight.tension)
	await _wait(0.4)
	if fishing.active():
		fishing.cancel()
	await _wait(0.4)


func _cook() -> void:
	await _go(&"farmhouse", &"door")
	await _wait(0.8)
	var show := _cook_show()
	if show != null:
		show.open(&"tomato_egg", true)
	await _wait(1.2)
	await _look("cook")
	for _i in 900:
		if show == null or not show.is_open():
			break
		await get_tree().process_frame
	await _wait(0.3)


func _fest() -> void:
	GameClock.day = 13
	GameClock.minutes = 600.0
	await _go(&"town", &"from_farm")
	await _until_cutscene_started()
	await _wait(0.45)
	await _look("fest")
	await _until_cutscene_finished()
	await _hold(&"move_left", 2.0)


func _mine() -> void:
	GameState.inventory.add(&"pickaxe")
	Mine.enter(1, 20260101)
	await _go(&"mine", &"down")
	await _until_cutscene_finished()
	_hold_id(&"pickaxe")
	await _wait(0.4)
	await _look("mine")
	# 一块一块敲：挑离出生点最近的几块石头，站到它旁边的空格里，面朝它
	var swung := 0
	for rock in _nearest_rocks(4):
		if not _stand_beside(rock):
			continue
		await _wait(0.2)
		for _hit in 3:
			await _press(&"use")
			await _wait(0.3)
		swung += 1
		if swung >= 3:
			break
	await _wait(0.5)


func _fox() -> void:
	GameClock.day = 10
	GameClock.minutes = 600.0
	Bestiary.see(&"chenghuang")
	await _go(&"zhuhai", &"south")
	# 站到西边空地上，乘黄就在旁边；再往东走几步，它会跟上来
	var who := _player()
	if who != null:
		who.place(GameMap.tile_center(Vector2i(9, 8)), GameMap.Facing.LEFT)
	await _wait(1.4)
	await _hold(&"move_right", 1.8)
	await _wait(1.6)
	await _look("fox")
	await _wait(0.6)


func _pond() -> void:
	GameClock.day = 3
	GameClock.minutes = 1200.0
	Bestiary.see(&"wenyao")
	# 第三天进农场会问留狗还是留猫。先留下猫，这段才不会被对话框挡住。
	GameState.set_flag(&"pet_cat")
	await _go(&"farm", &"house_door")
	_stand_on_bank()
	await _wait(0.8)
	await _look("pond")
	await _wait(2.2)


## 树冠朝北伸，南岸站人会被树盖住。北岸朝南，面前是池塘，人露在水的北边。
func _stand_on_bank() -> void:
	var spots: Array[Vector2i] = [
		Vector2i(33, 14), Vector2i(32, 14), Vector2i(34, 14),
		Vector2i(31, 14), Vector2i(35, 14), Vector2i(30, 14),
		Vector2i(36, 14), Vector2i(33, 13),
	]
	var who := _player()
	if who == null:
		return
	var map := who.map
	for t in spots:
		if map != null and map.blocked(GameMap.tile_center(t)):
			continue
		who.place(GameMap.tile_center(t), GameMap.Facing.DOWN)
		return
	who.place(GameMap.tile_center(spots[0]), GameMap.Facing.DOWN)


func _nearest_rocks(count: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var floor := Mine.current
	if floor == null:
		return out
	var tiles: Array = floor.rocks.keys()
	var origin := floor.spawn
	tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - origin).length_squared() < (b - origin).length_squared())
	for t: Vector2i in tiles:
		out.append(t)
		if out.size() >= count:
			break
	return out


## 站到石头旁边能走的格子里，朝着石头。找不到就返回 false。
func _stand_beside(rock: Vector2i) -> bool:
	var who := _player()
	if who == null or who.map == null:
		return false
	var dirs: Array[Vector2i] = [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]
	var facings: Array[GameMap.Facing] = [
		GameMap.Facing.UP, GameMap.Facing.RIGHT, GameMap.Facing.LEFT, GameMap.Facing.DOWN,
	]
	for i in dirs.size():
		var stand := rock + dirs[i]
		if who.map.blocked(GameMap.tile_center(stand)):
			continue
		who.place(GameMap.tile_center(stand), facings[i])
		return true
	return false


func _face_nearby_rock() -> void:
	var floor := Mine.current
	var who := _player()
	if floor == null or who == null:
		return
	var origin := floor.spawn
	var dirs: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]
	var facings: Array[GameMap.Facing] = [
		GameMap.Facing.DOWN, GameMap.Facing.RIGHT, GameMap.Facing.LEFT, GameMap.Facing.UP,
	]
	for i in dirs.size():
		if floor.rocks.has(origin + dirs[i]):
			who.place(GameMap.tile_center(origin), facings[i])
			return


func _go(map_id: StringName, spawn: StringName) -> void:
	SceneRouter.travel(map_id, spawn)
	await _until_idle()
	await _reveal()
	await _frames(0.1)


## ---------------------------------------------------------------- 完整版新增的段

func _game() -> Node:
	return get_tree().current_scene


func _map() -> Node:
	var g := _game()
	if g == null:
		return null
	var m: Variant = g.get(&"map")
	return m as Node


## 开场的信：把游戏里那段开场过场完整播一遍。
func _letter() -> void:
	await _reveal()
	await _play_steps(CutsceneScript.OPENING, CutsceneScript.opening_steps(), 60.0)


## 把一整段过场播完。没有在放就不等。
func _play_steps(id: StringName, steps: Array, max_sec: float) -> void:
	var cut: Variant = _game().get(&"cutscene")
	if not (cut is Node):
		return
	(cut as Node).call(&"play", id, steps)
	await _cutscene_wait(max_sec)


func _cutscene_wait(max_sec: float) -> void:
	var t := 0.0
	while t < 3.0 and not _cutscene_playing():
		await get_tree().process_frame
		t += get_process_delta_time()
	t = 0.0
	while _cutscene_playing() and t < max_sec:
		await get_tree().process_frame
		t += get_process_delta_time()


## 把几个居民、结局的过场放出来。结局最后一幕是“《雾隐青岚》”字幕，只在最后一个结局留着。
func _ending(kind: String) -> void:
	await _reveal()
	var steps: Array = CutsceneScript.ending_steps(StringName(kind))
	if kind != "name" and steps.size() > 1:
		steps.pop_back()
	await _play_steps(StringName("ending_" + kind), steps, 90.0)


## 一段忆：阿禾想起账本的事。
func _memory() -> void:
	await _reveal()
	await _play_steps(&"mem_ahe", CutsceneScript._memory_steps("ahe"), 90.0)


## 出货：把收成放进箱子，再回屋睡觉，一觉到第二天早上。
func _ship() -> void:
	GameState.inventory.add(&"white_radish", 4)
	await _go(&"farm", &"house_door")
	var who := _player()
	if who == null:
		return
	who.place(GameMap.tile_center(Vector2i(12, 8)), GameMap.Facing.UP)
	_hold_id(&"white_radish")
	await _wait(0.8)
	for _i in 4:
		await _press(&"use")
		await _wait(0.45)
	await _wait(0.8)
	await _go(&"farmhouse", &"door")
	who = _player()
	if who == null:
		return
	who.place(GameMap.tile_center(Vector2i(3, 3)), GameMap.Facing.LEFT)
	await _wait(0.8)
	await _press(&"use")
	await _wait(0.8)
	await _press(&"use")
	await _wait(0.6)
	await _press(&"ui_accept")
	await _wait(4.0)


## 重新下到第 3 层，清掉原来的忘形，在下来的地方朝某个方向 gap 格远摆一只。返回朝向，摆不开返回 -1。
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


## 井下打斗：拿镰刀砍，翻滚躲开，再砍倒。
func _fight() -> void:
	GameState.inventory.add(&"old_sickle")
	GameState.health = GameState.max_health
	GameState.energy = GameState.max_energy
	for round_i in 2:
		var dir := _arena(&"dust", 3 if round_i == 0 else 2)
		if dir < 0:
			print("REEL NOTE 摆不开打斗的地方")
			return
		_game().call(&"_load_map", &"mine", &"ladder")
		await _until_idle()
		var level: MineFloor = Mine.current
		var who := _player()
		if who == null or level == null:
			return
		who.place(GameMap.tile_center(level.spawn), dir as GameMap.Facing)
		_hold_id(&"old_sickle")
		if round_i == 0:
			await _reveal()
			await _wait(0.9)
		else:
			await _wait(0.5)
			await _press(&"roll")
			await _wait(0.5)
			who.place(GameMap.tile_center(level.spawn), dir as GameMap.Facing)
		for _i in 20:
			if level.monsters_left() == 0:
				break
			await _press(&"use")
			await _wait(0.3)
		await _until_free()
		await _wait(0.5)
		GameState.health = GameState.max_health


## 养鸡：盖鸡舍、买鸡、喂食、抚摸、第二天收蛋。
func _coop() -> void:
	GameState.set_flag(&"lamp_plaza")
	GameState.set_flag(&"lamp_river")
	GameState.money += 3000
	Animals.order("coop")
	await _go(&"farm", &"house_door")
	var who := _player()
	if who == null:
		return
	who.place(GameMap.tile_center(Vector2i(34, 11)), GameMap.Facing.UP)
	await _wait(1.6)
	for _i in 3:
		Animals.settle(false)
	await _wait(1.4)
	Animals.buy("chicken")
	Animals.buy("chicken")
	Animals.buy("duck")
	await _wait(2.4)
	GameState.inventory.add(&"feed", 5)
	_hold_id(&"feed")
	who.place(GameMap.tile_center(Vector2i(34, 10)), GameMap.Facing.UP)
	await _wait(0.5)
	await _press(&"use")
	await _wait(1.4)
	var map := _map()
	var critters: Array = map.get(&"_critters") if map != null else []
	if critters.size() > 0:
		var critter: Variant = map.call(&"_critter_at", (critters[0] as Critter).tile())
		if critter == null:
			critter = critters[0]
		map.call(&"perform", &"interact", null, (critter as Critter).tile())
		await _wait(1.2)
	Animals.settle(false)
	GameState.selected_slot = 0
	await _wait(0.8)
	if map != null:
		map.call(&"perform", &"interact", null, Vector2i(34, 9))
	await _wait(1.6)


## 杂货铺：和阿禾搭话，翻货单，买一样。
func _shop() -> void:
	GameState.set_flag(&"prologue_town")
	GameClock.minutes = 600.0
	await _go(&"town", &"from_farm")
	await _hold(&"move_left", 1.6)
	var who := _player()
	if who == null:
		return
	who.place(GameMap.tile_center(Vector2i(8, 19)), GameMap.Facing.UP)
	await _wait(0.6)
	await _press(&"use")
	await _wait(1.0)
	var game := _game()
	var balloon: DialogueBalloon = game.get(&"balloon")
	var shop: ShopPanel = game.get(&"shop_panel")
	for _i in 30:
		if shop.is_open() or not balloon.is_open():
			break
		await _press(&"use")
		await _wait(0.5)
		if balloon.is_open() and not shop.is_open():
			await _press(&"ui_accept")
			await _wait(0.4)
	await _wait(1.0)
	await _press(&"move_down")
	await _wait(0.7)
	await _press(&"move_down")
	await _wait(0.7)
	await _press(&"use")
	await _wait(1.0)
	await _press(&"inventory")
	await _wait(0.6)


## 点灯：供上四样东西，点亮，看那段过场。
func _lamp() -> void:
	GameState.set_flag(&"prologue_town")
	GameState.inventory.add(&"white_radish", 4)
	GameState.inventory.add(&"rapeseed", 3)
	GameState.inventory.add(&"shepherds_purse", 3)
	GameState.inventory.add(&"old_wick", 1)
	GameClock.minutes = 600.0
	await _go(&"town", &"from_farm")
	var who := _player()
	if who == null:
		return
	who.place(GameMap.tile_center(Vector2i(22, 16)), GameMap.Facing.UP)
	await _wait(0.8)
	await _press(&"use")
	await _wait(1.6)
	for _i in 4:
		await _press(&"use")
		await _wait(0.5)
		await _press(&"move_down")
		await _wait(0.4)
	await _wait(0.8)
	await _press(&"use")
	await _wait(0.8)
	await _cutscene_wait(60.0)
	await _talk_through(40)


## 对话翻到头。
func _talk_through(limit: int) -> void:
	var balloon: DialogueBalloon = _game().get(&"balloon")
	for _i in limit:
		if not balloon.is_open():
			return
		if not balloon.get(&"_choices").get_children().is_empty():
			return
		await _press(&"use")
		await _wait(0.35)


## 翻到出现选项，选第 index 个。follow 表示选完还有下一段，等它开出来。
func _choose(index: int, follow: bool = true) -> void:
	var balloon: DialogueBalloon = _game().get(&"balloon")
	var buttons: Array = []
	for _i in 40:
		buttons = balloon.get(&"_choices").get_children()
		if not buttons.is_empty() or not balloon.is_open():
			break
		await _press(&"use")
		await _wait(0.35)
	if buttons.size() > index:
		buttons[index].grab_focus()
		await _wait(0.5)
		await _press(&"ui_accept")
		await _wait(0.5)
		for _i in 20:
			if balloon.is_open() or not follow:
				break
			await get_tree().process_frame


## 把日子拨到某个节日那天、换到那张地图，等开场过场放完。
func _festival_day(day: int, minutes: float, map_id: StringName) -> void:
	var game := _game()
	var hud: Variant = game.get(&"hud")
	if hud is Hud:
		(hud as Hud).dismiss_toasts()
	var target := (GameClock.day - 1) / 96 * 96 + day
	if target < GameClock.day:
		target += 96
	GameClock.day = target
	GameClock.minutes = minutes
	Weather.today = Weather.SUNNY
	game.call(&"_load_map", map_id, &"from_farm" if map_id == &"town" else &"from_town")
	await _until_idle()
	await _reveal()
	await _wait(0.9)
	await _cutscene_wait(40.0)


func _festival_setup() -> void:
	for lamp: String in ["plaza", "river", "pasture", "well", "east", "shrine"]:
		GameState.set_flag(StringName("lamp_" + lamp))
	for id: StringName in Database.npcs:
		Story.told(id)
	GameState.set_flag(&"prologue_town")
	GameState.selected_slot = GameState.HOTBAR_SIZE - 1


func _festival(kind: String) -> void:
	_festival_setup()
	var who: Player = null
	match kind:
		"sowing":
			await _festival_day(13, 600.0, &"town")
			who = _player()
			who.place(GameMap.tile_center(Vector2i(17, 17)), GameMap.Facing.UP)
			await _wait(1.0)
			await _press(&"use")
			await _wait(1.0)
			await _choose(0, false)
			await _wait(1.6)
			await _press(&"inventory")
			await _wait(0.6)
			Farming.sown_today = 22
			who.place(GameMap.tile_center(Vector2i(22, 13)), GameMap.Facing.UP)
			await _wait(0.8)
			await _press(&"use")
			await _wait(0.8)
			await _choose(0)
			await _wait(0.8)
			await _talk_through(30)
		"lanterns":
			await _festival_day(17, 1140.0, &"nanxi")
			who = _player()
			who.place(GameMap.tile_center(Vector2i(20, 15)), GameMap.Facing.LEFT)
			await _wait(1.0)
			await _press(&"use")
			await _wait(0.8)
			await _choose(0)
			await _wait(0.6)
			await _talk_through(30)
			await _wait(1.6)
			who.place(GameMap.tile_center(Vector2i(20, 13)), GameMap.Facing.DOWN)
			await _wait(3.4)
		"fireflies":
			await _festival_day(45, 1200.0, &"nanxi")
			who = _player()
			who.place(GameMap.tile_center(Vector2i(20, 8)), GameMap.Facing.DOWN)
			await _wait(1.6)
			var map := _map()
			var flies: Dictionary = map.get(&"_fireflies") if map != null else {}
			var homes: Array = flies.keys()
			for i in mini(Festivals.FIREFLY_GOAL, homes.size()):
				var tile: Vector2i = homes[i]
				who.place(GameMap.tile_center(tile + Vector2i(-1, 0)), GameMap.Facing.RIGHT)
				await _wait(0.5)
				await _press(&"use")
				await _wait(0.6)
			who.place(GameMap.tile_center(Vector2i(21, 10)), GameMap.Facing.UP)
			await _wait(0.8)
			await _press(&"use")
			await _wait(0.8)
			await _choose(0)
			await _wait(0.8)
			await _talk_through(30)
			await _wait(2.0)
		"harvest":
			await _festival_day(61, 600.0, &"town")
			GameState.inventory.add(&"pumpkin", 1, 2)
			_hold_id(&"pumpkin")
			who = _player()
			who.place(GameMap.tile_center(Vector2i(22, 13)), GameMap.Facing.UP)
			await _wait(1.2)
			await _press(&"use")
			await _wait(0.8)
			await _choose(0)
			await _wait(0.8)
			await _talk_through(30)
		"dumpling":
			await _festival_day(85, 1080.0, &"town")
			GameState.inventory.add(&"bok_choy", 1)
			_hold_id(&"bok_choy")
			GameState.energy = 20
			who = _player()
			who.place(GameMap.tile_center(Vector2i(22, 13)), GameMap.Facing.UP)
			await _wait(1.4)
			await _press(&"use")
			await _wait(0.8)
			await _choose(0)
			await _wait(0.8)
			await _talk_through(30)
		"newyear":
			await _festival_day(96, 1170.0, &"town")
			who = _player()
			who.place(GameMap.tile_center(Vector2i(22, 15)), GameMap.Facing.UP)
			await _wait(2.6)
			who.place(GameMap.tile_center(Vector2i(22, 13)), GameMap.Facing.UP)
			await _wait(0.8)
			await _press(&"use")
			await _wait(0.8)
			await _choose(0)
			await _wait(0.8)
			await _talk_through(30)
			await _press(&"use")
			await _wait(0.8)
			await _choose(1)
			await _wait(0.8)
			await _talk_through(30)
			await _cutscene_wait(60.0)


func _reveal() -> void:
	await SceneRouter.fade_in(0.35)


func _player() -> Player:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var who: Variant = scene.get(&"player")
	if who is Player:
		return who as Player
	return null


func _fishing() -> FishingSession:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var node: Variant = scene.get(&"fishing")
	if node is FishingSession:
		return node as FishingSession
	return null


func _cook_show() -> CookShow:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var node: Variant = scene.get(&"cook_show")
	if node is CookShow:
		return node as CookShow
	return null


func _hold_id(id: StringName) -> void:
	var inv := GameState.inventory
	for i in inv.size:
		if inv.id_at(i) == id:
			GameState.selected_slot = i
			return


func _look(id: String) -> void:
	if OS.get_environment("REEL_SHOT") != "1":
		return
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var dir := ProjectSettings.globalize_path("res://_preview")
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir + "/reel_" + id + ".png")


func _until_cutscene_started() -> void:
	for _i in 180:
		if _cutscene_playing():
			return
		await get_tree().process_frame


func _until_cutscene_finished() -> void:
	var saw := false
	for _wait_start in 120:
		if _cutscene_playing():
			saw = true
			break
		await get_tree().process_frame
	if not saw:
		return
	for _wait_end in 600:
		if not _cutscene_playing():
			return
		await get_tree().process_frame


func _cutscene_playing() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	var opening: Variant = scene.get(&"cutscene")
	return opening is Node and bool((opening as Node).get(&"playing"))


func _until_idle() -> void:
	for _i in 300:
		if not SceneRouter.busy:
			return
		await get_tree().process_frame


func _step(action: StringName) -> void:
	var who := _player()
	if who == null:
		return
	var start := who.position
	Input.action_press(action)
	var elapsed := 0.0
	while elapsed < 0.7:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		who = _player()
		if who == null or who.position.distance_to(start) >= 12.0:
			break
	Input.action_release(action)
	await _frames(0.05)


func _hold(action: StringName, sec: float) -> void:
	Input.action_press(action)
	await _wait(sec)
	Input.action_release(action)
	await _frames(0.05)


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


func _until_free() -> void:
	for _i in 600:
		var who := _player()
		if who == null or not who.is_acting():
			return
		await get_tree().process_frame


func _until_use_released() -> void:
	for _i in 120:
		var scene := get_tree().current_scene
		if scene == null or not scene.has_method(&"is_locked") or bool(scene.call(&"is_locked")):
			return
		if not bool(scene.get(&"_use_needs_release")):
			return
		await get_tree().process_frame


func _release_moves() -> void:
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	Input.action_release(&"move_up")
	Input.action_release(&"move_down")
	Input.action_release(&"use")


func _frames(sec: float) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await _wait(sec)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _watch(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	if _done:
		return
	print("REEL TIMEOUT")
	_quit(1)


func _quit(code: int) -> void:
	if _dead:
		return
	_dead = true
	_done = true
	_release_moves()
	get_tree().paused = false
	SaveSystem.base_dir = "user://saves"
	Audio.quit_game(code)
