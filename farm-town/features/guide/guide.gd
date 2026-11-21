class_name Guide
extends RefCounted
## 第一天的下一步。第二天早上就不再说。不记进度，看着地里和信箱现在是什么样子。


## 现在该提示的那一句；没有要说的返回空。
static func line() -> String:
	if GameClock.day > 1:
		return ""
	var key := _use_key()
	if Farming.state.soil.is_empty():
		if GameState.has_flag(&"read_letter"):
			return "选中锄头，对着草地按%s" % key
		return "门口的信箱，对着它按%s" % key
	if Farming.state.crops.is_empty():
		return "选中种子，对着耕地按%s" % key
	if not _any_watered():
		return "选中水壶，对着种子按%s" % key
	if not GameState.has_flag(&"read_letter"):
		return "门口的信箱，对着它按%s" % key
	return "干完了。进屋，对着床按%s睡觉" % key


static func _any_watered() -> bool:
	for t: Vector2i in Farming.state.crops:
		if Farming.state.is_wet(t):
			return true
	return false


static func _use_key() -> String:
	var all := PauseMenu.keys_of(&"use")
	if all == "":
		return "空格"
	return all.split(" / ")[0]
