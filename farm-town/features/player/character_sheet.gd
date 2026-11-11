class_name CharacterSheet
extends RefCounted
## 一张角色序列帧和它的帧描述（由 tools/character.py 生成）。
## 贴图里每个动画占 4 行（下、上、右、左），每列一帧。

const DIR := "res://art/characters/"

var texture: Texture2D
var cell := 48
var foot_row := 40
var _anims: Dictionary = {}


static func load_sheet(sheet_name: String) -> CharacterSheet:
	var s := CharacterSheet.new()
	s.texture = load(DIR + sheet_name + ".png") as Texture2D
	var desc := JsonFile.read_dict(DIR + sheet_name + ".json")
	if s.texture == null or desc.is_empty():
		push_error("角色素材缺失：%s（先运行 tools/character.py）" % sheet_name)
		return s
	s.cell = int(desc.get("cell", 48))
	s.foot_row = int(desc.get("foot_row", 40))
	var anims: Dictionary = desc.get("anims", {})
	s._anims = anims
	return s


func is_valid() -> bool:
	return texture != null and not _anims.is_empty()


func has_anim(anim: StringName) -> bool:
	return _anims.has(String(anim))


func frame_count(anim: StringName) -> int:
	var info: Dictionary = _anims.get(String(anim), {})
	return int(info.get("frames", 1))


## 动作时间表：每项是 [帧, 秒]。循环动画没有时间表，返回空数组。
func sequence(anim: StringName) -> Array:
	var info: Dictionary = _anims.get(String(anim), {})
	var seq: Array = info.get("seq", [])
	return seq


## 时间表里动作生效的那一步。
func strike_index(anim: StringName) -> int:
	var info: Dictionary = _anims.get(String(anim), {})
	return int(info.get("strike", 0))


func fps(anim: StringName) -> float:
	var info: Dictionary = _anims.get(String(anim), {})
	return float(info.get("fps", 8.0))


## 走路时脚落地的帧，用来配脚步声。
func step_frames(anim: StringName) -> Array:
	var info: Dictionary = _anims.get(String(anim), {})
	var frames: Array = info.get("step_frames", [])
	return frames


func region(anim: StringName, facing: int, frame: int) -> Rect2:
	var info: Dictionary = _anims.get(String(anim), {})
	var row := int(info.get("row", 0)) + facing
	var count := int(info.get("frames", 1))
	return Rect2(posmod(frame, count) * cell, row * cell, cell, cell)
