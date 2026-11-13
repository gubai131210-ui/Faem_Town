class_name MineShot
extends RefCounted
## 忘形隔着老远扔过来的一样东西（纸人的纸钱、老鲶吐的水）。纯数据，直着飞，碰到墙、石头、摆设就没了。

## 最多飞多久
const LIFE := 3.0

var pos := Vector2.ZERO
var vel := Vector2.ZERO
var damage := 5
var radius := 3.0
## 画成什么：&"paper" 纸钱、&"water" 水弹、&"gust" 一口风
var kind: StringName = &"paper"
## 大于 0：打到人不扣生命，吹掉这么多灯油
var snuff := 0.0
var alive := true
var _life := LIFE


static func create(at: Vector2, velocity: Vector2, hurt: int, shot_kind: StringName) -> MineShot:
	var s := MineShot.new()
	s.pos = at
	s.vel = velocity
	s.damage = hurt
	s.kind = shot_kind
	return s


func update(delta: float, level: MineFloor) -> void:
	if not alive:
		return
	_life -= delta
	pos += vel * delta
	if _life <= 0.0:
		alive = false
		return
	if level == null:
		return
	# 暗河上面飞得过去，别的挡路的东西都拦得住
	var t := GameMap.tile_of(pos)
	if not level.is_open(t) or level.has_rock(t) or level.props.has(t) or t == level.lamp:
		alive = false


## 打没打到站在 target 的人。
func hits(target: Vector2, target_radius: float = 5.0) -> bool:
	return alive and pos.distance_to(target) <= radius + target_radius
