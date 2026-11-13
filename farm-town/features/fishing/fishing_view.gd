class_name FishingView
extends Node2D
## 钓鱼时画在地图上的东西：鱼线、浮漂、落水的涟漪、咬钩的叹号、遛鱼时的两条进度条、钓上来举着的鱼。
## 只负责画，数据每帧由 FishingSession 填进来。

const LINE := Color(0.93, 0.95, 0.97, 0.85)
const BOBBER_RED := Color("d84040")
const BOBBER_WHITE := Color("f4f0e8")
const BAR_BACK := Color(0.16, 0.12, 0.08, 0.85)
const BAR_FRAME := Color("f1e6c8")
const TENSION_OK := Color("6fc86a")
const TENSION_WARN := Color("f0c040")
const TENSION_BAD := Color("e04848")
const DISTANCE := Color("68a8d8")
const SHORE := Color("c8a060")

const SHADOW := Color(0.08, 0.14, 0.22, 0.42)

## 竿尖的位置（世界坐标）
var tip := Vector2.ZERO
## 浮漂的位置（世界坐标，水面上）
var bobber := Vector2.ZERO
var show_line := false
## 抛出去的浮漂还在空中：0 刚离手，1 落水；小于 0 表示不在飞
var flight := -1.0
var cast_from := Vector2.ZERO
## 水下的鱼影
var show_shadow := false
var shadow_at := Vector2.ZERO
## 鱼影朝哪边游（单位向量），尾巴画在反方向
var shadow_dir := Vector2.RIGHT
## 浮漂下沉的像素数（咬钩时按下去）
var dip := 0.0
## 咬钩的叹号画在哪（玩家头顶）
var alert_at := Vector2.ZERO
var show_alert := false
## 遛鱼：为空就不画进度条
var fight: FishFight
var gauge_at := Vector2.ZERO
## 举起来的鱼
var trophy: Texture2D
var trophy_at := Vector2.ZERO

var _time := 0.0
var _ripples: Array = []


func _ready() -> void:
	z_index = 20


func _process(delta: float) -> void:
	_time += delta
	for i in range(_ripples.size() - 1, -1, -1):
		_ripples[i]["t"] += delta
		if _ripples[i]["t"] > 0.7:
			_ripples.remove_at(i)
	queue_redraw()


## 在水面上荡开一圈涟漪。
func ripple(at: Vector2, strength: float = 1.0) -> void:
	_ripples.append({"at": at, "t": 0.0, "k": strength})


func clear() -> void:
	show_line = false
	show_alert = false
	show_shadow = false
	flight = -1.0
	fight = null
	trophy = null
	dip = 0.0
	_ripples.clear()


func _draw() -> void:
	if show_shadow:
		_draw_shadow()
	for r: Dictionary in _ripples:
		var t: float = r["t"]
		var k: float = r["k"]
		var radius := 2.0 + t * 9.0 * k
		var c := Color(1, 1, 1, (1.0 - t / 0.7) * 0.6)
		draw_arc(r["at"], radius, 0.0, TAU, 14, c, 1.0)
		draw_arc(r["at"] + Vector2(0, 1), radius * 0.55, 0.0, TAU, 10, c, 1.0)
	if flight >= 0.0:
		_draw_flight()
	elif show_line:
		_draw_line()
	if show_alert:
		_draw_alert()
	if fight != null:
		_draw_gauges()
	if trophy != null:
		var up := -8.0 - absf(sin(_time * 3.0)) * 1.5
		draw_texture(trophy, (trophy_at + Vector2(-8, up)).round())


func _draw_flight() -> void:
	var t := clampf(flight, 0.0, 1.0)
	var p := cast_from.lerp(bobber, t) + Vector2(0, -sin(t * PI) * (6.0 + cast_from.distance_to(bobber) * 0.25))
	draw_line(tip.round(), p.round(), LINE, 1.0)
	draw_rect(Rect2(p.round() + Vector2(-1, -2), Vector2(3, 2)), BOBBER_RED)
	draw_rect(Rect2(p.round() + Vector2(-1, 0), Vector2(3, 2)), BOBBER_WHITE)


func _draw_shadow() -> void:
	var wig := sin(_time * 9.0)
	var d := shadow_dir.normalized()
	var side := Vector2(-d.y, d.x) * 0.5
	var c := (shadow_at + side * wig).round()
	# 身子：三行横条拼出的小梭形
	draw_rect(Rect2(c + Vector2(-3, -1), Vector2(6, 3)), SHADOW)
	draw_rect(Rect2(c + Vector2(-4, 0), Vector2(8, 1)), SHADOW)
	# 尾巴在前进方向的反面，左右摆
	var tail := (c - d * 5.0 + side * wig * 3.0).round()
	draw_rect(Rect2(tail + Vector2(-1, -1), Vector2(2, 2)), SHADOW)


func _draw_line() -> void:
	var b := bobber + Vector2(0, dip)
	# 线从竿尖垂下来，中间往下坠一点
	var mid := (tip + b) * 0.5 + Vector2(0, 4.0 + absf(tip.x - b.x) * 0.08)
	var prev := tip
	for i in range(1, 9):
		var t := i / 8.0
		var p := tip.lerp(mid, t).lerp(mid.lerp(b, t), t)
		draw_line(prev.round(), p.round(), LINE, 1.0)
		prev = p
	# 浮漂：上红下白，随水面轻轻起伏
	var bob := roundf(sin(_time * 2.2) * 0.8)
	var top := (b + Vector2(0, bob - 3)).round()
	draw_rect(Rect2(top + Vector2(-1, 0), Vector2(3, 2)), BOBBER_RED)
	draw_rect(Rect2(top + Vector2(-1, 2), Vector2(3, 2)), BOBBER_WHITE)
	draw_rect(Rect2(top + Vector2(0, -1), Vector2(1, 1)), BOBBER_RED)


func _draw_alert() -> void:
	var p := (alert_at + Vector2(0, -2 + roundf(sin(_time * 12.0)))).round()
	draw_rect(Rect2(p + Vector2(-4, -12), Vector2(8, 11)), BAR_BACK)
	draw_rect(Rect2(p + Vector2(-1, -10), Vector2(2, 5)), Color("f8e060"))
	draw_rect(Rect2(p + Vector2(-1, -4), Vector2(2, 2)), Color("f8e060"))


func _draw_gauges() -> void:
	var o := gauge_at.round()
	# 横条：鱼离岸多远。左端是岸，鱼的小图标往左挪
	var w := 40.0
	draw_rect(Rect2(o + Vector2(-w / 2 - 1, -1), Vector2(w + 2, 7)), BAR_BACK)
	draw_rect(Rect2(o + Vector2(-w / 2, 0), Vector2(w, 5)), DISTANCE.darkened(0.45))
	draw_rect(Rect2(o + Vector2(-w / 2, 0), Vector2(3, 5)), SHORE)
	var fx := o.x - w / 2 + 3.0 + fight.distance * (w - 6.0)
	var fish_c := Color("f4f0e8")
	if fight.struggling:
		fish_c = TENSION_BAD if int(_time * 12.0) % 2 == 0 else Color("ffd0c0")
	elif fight.warning:
		fish_c = TENSION_WARN
	draw_rect(Rect2(Vector2(fx - 3, o.y).round(), Vector2(7, 5)), BAR_BACK)
	draw_rect(Rect2(Vector2(fx - 2, o.y + 1).round(), Vector2(4, 3)), fish_c)
	draw_rect(Rect2(Vector2(fx + 2, o.y + 1).round(), Vector2(1, 1)), fish_c)
	draw_rect(Rect2(Vector2(fx + 2, o.y + 3).round(), Vector2(1, 1)), fish_c)
	# 竖条：线的张力，从绿到红
	var h := 22.0
	var left := o + Vector2(-w / 2 - 8, -h + 5)
	draw_rect(Rect2(left + Vector2(-1, -1), Vector2(6, h + 2)), BAR_BACK)
	var fill := fight.tension * h
	var c := TENSION_OK
	if fight.tension > 0.75:
		c = TENSION_BAD
	elif fight.tension > 0.45:
		c = TENSION_WARN
	draw_rect(Rect2(left + Vector2(0, h - fill), Vector2(4, fill)), c)
	if fight.struggling and int(_time * 12.0) % 2 == 0:
		draw_rect(Rect2(left + Vector2(-1, -1), Vector2(6, h + 2)), Color(1, 0.3, 0.3, 0.5), false, 1.0)
