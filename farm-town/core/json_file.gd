class_name JsonFile
extends RefCounted
## 读写 JSON 文件的小工具。res:// 下的表通过资源系统读取，导出后也能用。


static func read(path: String) -> Variant:
	if path.begins_with("res://"):
		if not ResourceLoader.exists(path):
			push_error("找不到数据文件 %s" % path)
			return null
		var res := load(path) as JSON
		if res == null:
			push_error("数据文件不是合法的 JSON：%s" % path)
			return null
		return res.data
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK:
		push_warning("JSON 解析失败 %s：%s" % [path, json.get_error_message()])
		return null
	return json.data


static func read_dict(path: String) -> Dictionary:
	var data: Variant = read(path)
	if data is Dictionary:
		var d: Dictionary = data
		return d
	return {}


static func read_array(path: String) -> Array:
	var data: Variant = read(path)
	if data is Array:
		var a: Array = data
		return a
	return []
