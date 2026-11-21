extends SceneTree
## 把整张地图画成一张图，存到 _preview/maps/<地图>.png。要开窗口（几秒），画完自己关。
## 用法：godot --path . -s tools/dump_map.gd -- town chaling
## 后面加 season=2 换季节（0 春 1 夏 2 秋 3 冬），加 scale=2 放大两倍。
## flags=lamp_plaza,lamp_river 先立几个剧情标记，bai=5 把柏先生的忆设到五级，tag=open 给文件名加后缀。


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var names: Array[String] = []
	var season := -1
	var zoom := 1
	var tag := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("season="):
			season = int(arg.trim_prefix("season="))
		elif arg.begins_with("scale="):
			zoom = maxi(1, int(arg.trim_prefix("scale=")))
		elif arg.begins_with("flags="):
			for flag in arg.trim_prefix("flags=").split(",", false):
				root.get_node("GameState").call(&"set_flag", StringName(flag))
		elif arg.begins_with("bai="):
			var levels: Dictionary = root.get_node("Residents").get(&"memory_levels")
			levels[&"bai"] = int(arg.trim_prefix("bai="))
		elif arg.begins_with("tag="):
			tag = "_" + arg.trim_prefix("tag=")
		else:
			names.append(arg)
	var router: Node = root.get_node("SceneRouter")
	var clock: Node = root.get_node("GameClock")
	if season >= 0:
		clock.set(&"day", season * 24 + 2)
	clock.set(&"minutes", 600.0)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_preview/maps"))
	var maps: Dictionary = router.get(&"MAPS")
	for id in names:
		if not maps.has(StringName(id)):
			print("DUMP 没有这张地图 ", id)
			continue
		var map: Node = (load(maps[StringName(id)]) as PackedScene).instantiate()
		var view := SubViewport.new()
		view.transparent_bg = false
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		root.add_child(view)
		view.add_child(map)
		var extent: Vector2i = map.call(&"size_px")
		view.size = extent
		for i in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		var image := view.get_texture().get_image()
		if zoom > 1:
			image.resize(extent.x * zoom, extent.y * zoom, Image.INTERPOLATE_NEAREST)
		var suffix := "" if season < 0 else "_s%d" % season
		image.save_png("res://_preview/maps/%s%s%s.png" % [id, suffix, tag])
		print("DUMP ", id, " ", extent)
		view.queue_free()
		await process_frame
	quit()
