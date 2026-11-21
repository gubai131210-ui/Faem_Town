extends SceneTree
## 把水面四帧拼成一条，导出到 _preview。无窗口：godot --headless --path . -s tools/dump_surface.gd


func _initialize() -> void:
	var surface: Script = load("res://maps/surface.gd")
	var img: Image = surface.call(&"preview")
	var dir := ProjectSettings.globalize_path("res://_preview")
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir + "/surface_frames.png")
	print("SURFACE FRAMES %d x %d" % [img.get_width(), img.get_height()])
	quit()
