extends GutTest
## 五间里间扩大以后（决策 161）：尺寸、出口、每个能看的东西都走得到，每间有自己的东西。

const ROOMS := {
	&"hall": {"size": Vector2i(26, 15), "back": &"hall_door", "keys": [&"map", &"desk", &"archive", &"table", &"bench", &"notice", &"tea"]},
	&"herbshop": {"size": Vector2i(22, 14), "back": &"herb_door", "keys": [&"drawers", &"counter", &"racks", &"mortar", &"stove", &"bench", &"jars"]},
	&"smithy": {"size": Vector2i(24, 14), "back": &"smithy_door", "keys": [&"forge", &"anvil", &"trough", &"bellows", &"ore", &"coal", &"grind", &"tools"]},
	&"teahouse": {"size": Vector2i(26, 15), "back": &"teahouse_door", "keys": [&"cabinet", &"cups", &"stage", &"pots", &"trays", &"kettle", &"counter"]},
	&"workshop": {"size": Vector2i(24, 14), "back": &"carpenter_door", "keys": [&"skiff", &"oars", &"net", &"drawings", &"lumber", &"bench", &"rope"]},
}


func before_each() -> void:
	SaveSystem.base_dir = "user://test_saves_shop_rooms"
	SaveSystem.reset_all()


func test_each_room_is_bigger_than_the_old_twelve_by_nine() -> void:
	for id: StringName in ROOMS:
		var room := _room(id)
		var want: Vector2i = ROOMS[id]["size"]
		assert_eq(Vector2i(room.W, room.H), want, "%s 的大小" % id)
		assert_eq(room.size_px(), want * 16)
		assert_gt(room.W * room.H, 12 * 9 * 2, "%s 至少是原来的两倍大" % id)


func test_the_door_is_the_middle_of_the_bottom_row_and_leads_back_to_town() -> void:
	for id: StringName in ROOMS:
		var room := _room(id)
		var mid: int = room.W / 2
		var back: Dictionary = room.trigger_at(Vector2i(mid - 1, room.H - 1))
		assert_eq(back, room.trigger_at(Vector2i(mid, room.H - 1)), "%s 门是两格" % id)
		assert_eq(back["spawn"], ROOMS[id]["back"], "%s 回到哪扇门" % id)
		assert_eq(room.trigger_at(Vector2i(mid - 2, room.H - 1)), {}, "%s 门旁边不是门" % id)
		assert_eq(room.trigger_at(Vector2i(mid, room.H - 2)), {}, "%s 门里面一格不是门" % id)
		var spawn := room.spawn_position(&"door")
		assert_false(room.blocked(spawn), "%s 进门的位置没被挡" % id)
		assert_eq(room.tile_of(spawn), Vector2i(mid, room.H - 2))
		assert_eq(room.spawn_facing(&"door"), GameMap.Facing.UP)


func test_every_thing_you_can_look_at_can_be_reached() -> void:
	for id: StringName in ROOMS:
		var room := _room(id)
		var reach := _reach(room, room.tile_of(room.spawn_position(&"door")))
		assert_true(reach.has(Vector2i(room.W / 2, room.H - 2)), "%s 门口是通的" % id)
		for t in room.use_tiles():
			var ok := false
			for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
				if reach.has(t + d):
					ok = true
			assert_true(ok, "%s 的 %s（%s）站不到跟前" % [id, t, room.use_key(t)])
			assert_eq(room.query_use(null, t, GameMap.Facing.UP), &"interact")


func test_each_room_has_its_own_things_to_look_at() -> void:
	for id: StringName in ROOMS:
		var room := _room(id)
		var keys: Array[StringName] = []
		for t in room.use_tiles():
			if not keys.has(room.use_key(t)):
				keys.append(room.use_key(t))
		for k: StringName in ROOMS[id]["keys"]:
			assert_true(keys.has(k), "%s 里该有 %s" % [id, k])
		assert_gte(keys.size(), 7, "%s 能看的东西不少于七样" % id)


func test_furniture_never_blocks_the_way_from_the_door_to_the_back_wall() -> void:
	for id: StringName in ROOMS:
		var room := _room(id)
		var reach := _reach(room, room.tile_of(room.spawn_position(&"door")))
		var floor_tiles := (room.W) * (room.H - 2)
		assert_gt(reach.size(), floor_tiles / 2, "%s 一半以上的地能走" % id)
		assert_true(reach.has(Vector2i(room.W / 2 - 1, 2)), "%s 后墙前面走得到" % id)


func test_the_rooms_look_like_where_they_are() -> void:
	assert_eq(_room(&"smithy")._look()["wall"], "stone", "铁匠铺是石墙")
	assert_eq(_room(&"smithy")._look()["floor"], "brick")
	assert_eq(_room(&"workshop")._look()["wall"], "bamboo", "河埠的木匠铺是竹墙")
	assert_eq(_room(&"workshop")._look()["floor"], "dark")
	assert_eq(_room(&"teahouse")._look()["wall"], "timber")
	assert_eq(_room(&"herbshop")._look()["wall"], "plaster")
	assert_eq(_room(&"hall")._look()["wall"], "plaster")


func test_the_hall_map_patches_follow_the_lamps() -> void:
	var hall := _room(&"hall")
	assert_eq(hall.map_filled(), 0)
	assert_false(hall.patch_visible(0))
	GameState.set_flag(&"lamp_plaza")
	GameState.set_flag(&"lamp_shrine")
	assert_eq(hall.map_filled(), 2)
	assert_true(hall.patch_visible(0))
	assert_true(hall.patch_visible(5))
	assert_false(hall.patch_visible(3))


func test_interior_art_draws_every_piece() -> void:
	for name in InteriorArt.KNOWN:
		var arg := name
		match name:
			"counter", "long_table", "desk", "drawers", "jar_shelf", "tool_rack", "workbench", "oar_rack", \
			"teapot_shelf", "tea_tins", "pigeon_holes":
				arg = name + ":3"
			"stage", "runner":
				arg = name + ":3:2"
		var img := InteriorArt.image(arg)
		assert_gt(img.get_width(), 6, arg)
		assert_gt(img.get_height(), 6, arg)
		var painted := 0
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a > 0.5:
					painted += 1
					assert_false(c.r > 0.9 and c.g < 0.1 and c.b > 0.9, "%s 画出了品红" % arg)
		assert_gt(painted, 30, "%s 不能是空的" % arg)


func _room(id: StringName) -> ShopRoom:
	var scene: PackedScene = load(SceneRouter.MAPS[id])
	var room: ShopRoom = scene.instantiate()
	add_child_autofree(room)
	return room


## 从 from 出发走得到的格子。
func _reach(room: ShopRoom, from: Vector2i) -> Dictionary:
	var seen := {from: true}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var t: Vector2i = queue.pop_back()
		for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var n := t + d
			if seen.has(n) or room.blocked(GameMap.tile_center(n)):
				continue
			seen[n] = true
			queue.append(n)
	return seen
