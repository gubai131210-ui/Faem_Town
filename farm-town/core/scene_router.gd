extends Node
## 场景切换和转场遮罩：主菜单与游戏之间、游戏内各区域之间。
## 区域的实际加载由游戏场景完成，这里只负责流程和黑屏。

## 屏幕已经全黑，可以换地图了
signal map_change_requested(map_id: StringName, spawn: StringName)

const MENU_SCENE := "res://features/ui/main_menu.tscn"
const GAME_SCENE := "res://game/game.tscn"
const MAPS: Dictionary[StringName, String] = {
	&"farm": "res://maps/farm/farm.tscn",
	&"farmhouse": "res://maps/farmhouse/farmhouse.tscn",
}

var busy := false

var _fade: ColorRect


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.05, 0.04, 0.1, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)


func fade_out(duration: float = 0.35) -> void:
	await _fade_to(1.0, duration)


func fade_in(duration: float = 0.35) -> void:
	await _fade_to(0.0, duration)


## 走到另一个区域：黑屏、换图、亮起。
func travel(map_id: StringName, spawn: StringName) -> void:
	if busy or not MAPS.has(map_id):
		return
	busy = true
	await fade_out(0.25)
	map_change_requested.emit(map_id, spawn)
	await get_tree().process_frame
	await fade_in(0.25)
	busy = false


func to_game() -> void:
	await _change_scene(GAME_SCENE)


func to_menu() -> void:
	await _change_scene(MENU_SCENE)


func _change_scene(path: String) -> void:
	if busy:
		return
	busy = true
	await fade_out(0.3)
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	await fade_in(0.4)
	busy = false


func _fade_to(alpha: float, duration: float) -> void:
	if duration <= 0.0:
		_fade.color.a = alpha
		return
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", alpha, duration)
	await tw.finished
