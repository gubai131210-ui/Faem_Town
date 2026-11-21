extends SceneTree
## 把大地图用的野外素材（WildArt）导出成 _preview/wild_art.png，不开窗口：
##   godot --headless --path . -s tools/dump_wild.gd
## 每行一个季节：老树三种、松两种、柳两种、千年樟、茶垄、荷、芦苇、水田、林下的小东西。


func _initialize() -> void:
	var art: Script = load("res://art_gen/wild_art.gd")
	var scale := 3
	var row_h := 184
	var sheet := Image.create(900, row_h * 4, false, Image.FORMAT_RGBA8)
	var grounds: Array[String] = ["80bd4e", "72b446", "bab552", "e3ebf1"]
	for season in 4:
		sheet.fill_rect(Rect2i(0, season * row_h, 900, row_h), Color.html(grounds[season]))
		sheet.fill_rect(Rect2i(590, season * row_h + 100, 200, 80), Color.html("4aa0d8"))
		var items: Array = []
		for v in 3:
			items.append(art.call(&"old_tree", v, season))
		for v in 2:
			items.append(art.call(&"pine", v, season))
		for v in 2:
			items.append(art.call(&"willow", v, season))
		items.append(art.call(&"giant_tree", season))
		var x := 4
		for img: Image in items:
			_paste(sheet, img, x, season * row_h + row_h - 4 - img.get_height())
			x += img.get_width() + 4
		# 小件放在大树右边的两排
		var small: Array = [
			art.call(&"tea_bush", 2, season, false), art.call(&"tea_bush", 3, season, true), art.call(&"tea_bush", 1, season, true),
			art.call(&"fern", 0, season), art.call(&"fern", 1, season), art.call(&"mushroom", 0), art.call(&"mushroom", 1),
			art.call(&"mushroom", 2), art.call(&"stump"), art.call(&"fallen_log"), art.call(&"signpost"), art.call(&"stepping", 0),
		]
		x = 596
		for img: Image in small:
			_paste(sheet, img, x, season * row_h + 60 - img.get_height())
			x += img.get_width() + (0 if img.get_width() == 16 and x < 640 else 4)
		var wet: Array = [
			art.call(&"lotus", 0, 0, season), art.call(&"lotus", 1, 1, season), art.call(&"lotus", 2, 0, season),
			art.call(&"lotus", 2, 1, season), art.call(&"lotus", 3, 2, season), art.call(&"reed", 0, season),
			art.call(&"reed", 1, season), art.call(&"paddy", season, 0), art.call(&"paddy", season, 1),
		]
		x = 596
		for img: Image in wet:
			_paste(sheet, img, x, season * row_h + 170 - img.get_height())
			x += img.get_width() + 2
	sheet.resize(sheet.get_width() * scale, sheet.get_height() * scale, Image.INTERPOLATE_NEAREST)
	sheet.save_png(ProjectSettings.globalize_path("res://_preview/wild_art.png"))
	print("DUMP wild_art")
	quit()


func _paste(sheet: Image, img: Image, x: int, y: int) -> void:
	sheet.blend_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i(x, y))
