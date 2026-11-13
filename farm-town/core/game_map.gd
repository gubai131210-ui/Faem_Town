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
## 游戏主场景在地图载入后填上；地图用它知道玩家站在哪。单独测试地图时为空
var player: Node2D
## 正在演一小段剧情（居民走过来说话）：玩家不能动，时间照走
var cutscene := false
## 这张地图上会打起来（井里）：能翻滚；拿着武器时 query_use 返回 &"attack"，
## 打到的那一帧 Game 调地图的 weapon_hit(weapon, step, skill)
var combat := false


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
## 返回动作名：&"hoe" &"water" &"dig" &"plant" &"fertilize" &"harvest" &"cast" 会播放对应的角色动作；
## &"interact" 表示立即生效的交互（门、床、信箱）；空表示什么都不能做。
func query_use(_item: ItemDef, _tile: Vector2i, _facing: Facing) -> StringName:
	return &""


## 让 query_use 返回的动作真正生效。
## 一次作用多格时，除第一格外 quiet 为真：只生效，不再重复播放声音和震动。
func perform(_action: StringName, _item: ItemDef, _tile: Vector2i, _quiet: bool = false) -> void:
	pass


## 玩家站好以后游戏主场景调一次；要演序幕之类的剧情就覆盖它。
func entered() -> void:
	pass


## 对着 tile 甩竿时钓的是哪片水（data/fish.json 里的 waters）；不能钓返回空。
func fishing_water(_tile: Vector2i) -> StringName:
	return &""


## 玩家踩到 tile 时要去的地方：{"map": StringName, "spawn": StringName}，没有则为空。
func trigger_at(_tile: Vector2i) -> Dictionary:
	return {}


## 这一格水底沉着哪件剧情遗物（对着它钓有机会钓上来）；没有返回空。
func sunken_relic(_tile: Vector2i) -> StringName:
	return &""


## 拿着锄头对着 tile：要是能一口气开一整行（牵着牛），返回这一行的格子，第一格是 tile；不能就返回空。
func plow_row(_tile: Vector2i, _facing: Facing) -> Array[Vector2i]:
	return []


## plow_row 返回的那一行真的开了。
func plowed() -> void:
	pass


## 玩家在这张地图上钓起了一件遗物：要演剧情就覆盖它。
func relic_fished(_relic_id: StringName) -> void:
	pass


## 手里拿着 item 对着空处按了使用键。地图用掉了它（往灯里添油）就返回真。
func use_item(_item: ItemDef) -> bool:
	return false


## 这张地图要是自己定整个画面的明暗（全黑的井底），返回那个颜色；不管就返回透明色。
func forced_tint() -> Color:
	return Color(0, 0, 0, 0)


## 线甩进了水里，浮漂落在 at（像素）。水里有东西要对它起反应就覆盖（井底老鲶）。
func fishing_started(_at: Vector2) -> void:
	pass


## 收竿了（不管钓没钓到）。
func fishing_ended() -> void:
	pass


## 该咬钩的这一刻，地图要是指定咬钩的是哪条鱼就返回它（不走这片水平常的鱼）；不指定返回 null。
func fishing_bite(_at: Vector2) -> FishDef:
	return null


## 鱼遛赢了、要拎上来的这一刻。地图自己处理这条鱼（不进背包）就返回真。
func fish_landed(_fish: FishDef) -> bool:
	return false
