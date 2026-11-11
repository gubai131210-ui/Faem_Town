extends Node
## 存读档。各系统用 register() 登记自己，并实现三个方法：
##   save_data() -> Dictionary    把自己的状态写成可以转 JSON 的字典
##   load_data(data: Dictionary)  从字典恢复
##   reset_data()                 回到新游戏的初始状态

const VERSION := 1
const SLOT_COUNT := 3

## 存档目录；测试里会改到临时目录
var base_dir := "user://saves"
## 当前游戏使用的档位，-1 表示还没有
var current_slot := -1
## 读档失败后置真，阻止之后的自动存档覆盖掉可能还能抢救的文件
var write_blocked := false

var _providers: Dictionary[StringName, Object] = {}
var _order: Array[StringName] = []


func register(key: StringName, provider: Object) -> void:
	if not _providers.has(key):
		_order.append(key)
	_providers[key] = provider


func reset_all() -> void:
	write_blocked = false
	for key in _order:
		_providers[key].call(&"reset_data")


func slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [base_dir, slot]


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


## 档位的摘要，用于菜单显示；没有存档或读不出来时返回空字典。
func slot_meta(slot: int) -> Dictionary:
	var data := _read(slot_path(slot))
	if data.is_empty():
		return {}
	var meta: Dictionary = data.get("meta", {})
	return meta


func save(slot: int, meta: Dictionary = {}) -> bool:
	if write_blocked:
		push_warning("上次读档失败，已阻止存档以免覆盖原文件")
		return false
	var systems := {}
	for key in _order:
		var d: Dictionary = _providers[key].call(&"save_data")
		systems[String(key)] = d
	var full_meta := meta.duplicate()
	full_meta["saved_at"] = Time.get_datetime_string_from_system(false, true)
	var data := {"version": VERSION, "meta": full_meta, "systems": systems}

	DirAccess.make_dir_recursive_absolute(base_dir)
	var path := slot_path(slot)
	var tmp := path + ".tmp"
	var bak := path + ".bak"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("无法写入存档 %s" % tmp)
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	# 先写临时文件，确认写完再替换，旧档留作备份
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(bak):
			DirAccess.remove_absolute(bak)
		DirAccess.rename_absolute(path, bak)
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		push_error("存档替换失败：%s" % error_string(err))
		return false
	current_slot = slot
	return true


func load_slot(slot: int) -> bool:
	var path := slot_path(slot)
	var data := _read(path)
	if data.is_empty():
		data = _read(path + ".bak")
	if data.is_empty():
		write_blocked = FileAccess.file_exists(path)
		return false
	data = _migrate(data)
	var systems: Dictionary = data.get("systems", {})
	reset_all()
	for key in _order:
		var d: Variant = systems.get(String(key))
		if d is Dictionary:
			_providers[key].call(&"load_data", d)
	current_slot = slot
	return true


func delete(slot: int) -> void:
	for suffix: String in ["", ".bak", ".tmp"]:
		var p := slot_path(slot) + suffix
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _read(path: String) -> Dictionary:
	var data: Variant = JsonFile.read(path)
	if data is Dictionary:
		var d: Dictionary = data
		if d.has("version") and d.has("systems"):
			return d
	return {}


## 把旧版本的存档逐级升到当前版本。以后存档结构变化时在这里加步骤。
func _migrate(data: Dictionary) -> Dictionary:
	var version := int(data.get("version", 1))
	if version > VERSION:
		push_warning("存档来自更新的游戏版本（%d），可能读不全" % version)
	# 示例：if version < 2: data = _v1_to_v2(data); version = 2
	data["version"] = VERSION
	return data
