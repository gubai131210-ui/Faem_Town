extends SceneTree
## 把干草图标和呵气那几点放大拼成一张。无窗口：godot --headless --path . -s tools/dump_season.gd


func _initialize() -> void:
	# 画图的类会用到自动加载，要等全局系统起来再用 load，不能在文件头写类名。
	var item_art: Script = load("res://art_gen/item_art.gd")
	var npc: Script = load("res://features/npc/npc.gd")
	var hay: Image = item_art.call(&"product", &"hay")
	var breath: Image = npc.call(&"_breath_image")
	var scale := 8
	var gap := 16
	var w := hay.get_width() * scale + gap + breath.get_width() * scale
	var h := hay.get_height() * scale
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.16, 0.2, 0.18))
	_blit(out, hay, 0, 0, scale)
	_blit(out, breath, hay.get_width() * scale + gap, 40, scale)
	var dir := ProjectSettings.globalize_path("res://_preview")
	DirAccess.make_dir_recursive_absolute(dir)
	out.save_png(dir + "/season_bits.png")
	print("SEASON BITS %d x %d" % [w, h])
	var scenic: Script = load("res://maps/scenic.gd")
	var bits: Image = scenic.call(&"preview")
	var big := Image.create(bits.get_width() * scale, bits.get_height() * scale, false, Image.FORMAT_RGBA8)
	big.fill(Color(0.16, 0.22, 0.18))
	_blit(big, bits, 0, 0, scale)
	big.save_png(dir + "/scenic_bits.png")
	print("SCENIC BITS %d x %d" % [big.get_width(), big.get_height()])
	quit()


func _blit(dst: Image, src: Image, ox: int, oy: int, scale: int) -> void:
	for y in src.get_height():
		for x in src.get_width():
			var c := src.get_pixel(x, y)
			if c.a < 0.05:
				continue
			dst.fill_rect(Rect2i(ox + x * scale, oy + y * scale, scale, scale), c)
