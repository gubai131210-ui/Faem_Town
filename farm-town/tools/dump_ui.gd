extends SceneTree
## 把 M9 第四批（界面和头像）的四行四帧拼成一张，导出到 _preview。
## 无窗口：godot --headless --path . -s tools/dump_ui.gd
## 四行依次是：头像眨眼与嘴动、图标飞向物品栏、钱数滚动、换季名牌。


func _initialize() -> void:
	var script: Script = load("res://core/ui_motion.gd")
	var img: Image = script.call(&"preview")
	var dir := ProjectSettings.globalize_path("res://_preview")
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir + "/ui_frames.png")
	var faces: Image = script.call(&"preview_faces")
	faces.save_png(dir + "/faces_anim.png")
	print("UI FRAMES %d x %d / FACES %d x %d" % [
			img.get_width(), img.get_height(), faces.get_width(), faces.get_height()])
	quit()
