extends SceneTree
## 把灯和烟的四帧拼成一条。无窗口：godot --headless --path . -s tools/dump_glow.gd


func _initialize() -> void:
	var glow: Script = load("res://maps/glow.gd")
	var img: Image = glow.call(&"preview")
	var dir := ProjectSettings.globalize_path("res://_preview")
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir + "/glow_frames.png")
	print("GLOW FRAMES %d x %d" % [img.get_width(), img.get_height()])
	quit()
