extends SceneTree
## 把 M9 第三批（田里和树上）的四帧拼成一条，导出到 _preview。
## 无窗口：godot --headless --path . -s tools/dump_fields.gd


func _initialize() -> void:
	var script: Script = load("res://core/field_motion.gd")
	var img: Image = script.call(&"preview")
	var dir := ProjectSettings.globalize_path("res://_preview")
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir + "/field_frames.png")
	print("FIELD FRAMES %d x %d" % [img.get_width(), img.get_height()])
	quit()
