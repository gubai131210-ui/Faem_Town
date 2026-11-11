class_name GameMap
extends Node2D
## 所有区域地图的基类。玩家和游戏主场景只通过这里的方法和地图打交道。

const TS := 16

## 朝向编号，和角色序列帧的行顺序一致
enum Facing { DOWN, UP, RIGHT, LEFT }

var map_id: StringName
## 按 y 排序的图层，玩家和有遮挡关系的物件都放在这里
var entities: Node2D
## 室内不受昼夜色调影响
var indoor := false


static func tile_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TS), floori(p.y / TS))


static func tile_center(t: Vector2i) -> Vector2:
	return Vector2(t.x * TS + TS / 2.0, t.y * TS + TS / 2.0)


## 地图的像素尺寸，用来限制镜头。
func size_px() -> Vector2i:
	return Vector2i.ZERO


func spawn_position(_spawn: StringName) -> Vector2:
	return Vector2.ZERO


func spawn_facing(_spawn: StringName) -> Facing:
	return Facing.DOWN


## 玩家脚底在 p 时是否被挡住。
func blocked(_p: Vector2) -> bool:
	return false


## 玩家拿着 item（可能为空）对着 tile 按下使用键时会发生什么。
## 返回动作名：&"hoe" &"water" &"plant" &"harvest" 会播放对应的角色动作；
## &"interact" 表示立即生效的交互（门、床、信箱）；空表示什么都不能做。
func query_use(_item: ItemDef, _tile: Vector2i, _facing: Facing) -> StringName:
	return &""


## 让 query_use 返回的动作真正生效。
func perform(_action: StringName, _item: ItemDef, _tile: Vector2i) -> void:
	pass


## 玩家踩到 tile 时要去的地方：{"map": StringName, "spawn": StringName}，没有则为空。
func trigger_at(_tile: Vector2i) -> Dictionary:
	return {}
