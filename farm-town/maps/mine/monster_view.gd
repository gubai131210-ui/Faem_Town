class_name MonsterView
extends Node2D
## 把一只忘形（MineMonster）画出来：跟着它的位置走，按它正在干什么换姿势。不改它的任何状态。

## 画在脚下多高的地方：会飞的浮在半空
const FLY_HEIGHT := 9.0
## 血条连边框多宽
const BAR_W := 12
## 跳起来最高离地多少
const LEAP_HEIGHT := 14.0

var monster: MineMonster
var _sprite: Sprite2D
var _poses: Dictionary[StringName, Texture2D] = {}
var _t := 0.0
var _bar: Node2D
var _bar_fill: ColorRect


## 头顶的血条：挨过打才显示，没受伤的和装石头的不露。
## 首领的血条画在屏幕顶上，不在这。
func bar_shown() -> bool:
	return monster.alive() and monster.hp < monster.def.hp and not monster.is_boss()


## 血条里红的那一截有几个像素宽：还活着至少留一个像素。
func bar_width() -> int:
	return clampi(ceili(float(BAR_W - 2) * monster.hp / maxi(1, monster.def.hp)), 1, BAR_W - 2)


func setup(m: MineMonster) -> void:
	monster = m
	if not m.def.hidden and not m is MineCatfish:
		var shadow := Sprite2D.new()
		shadow.texture = Px.tex(PixelArt.shadow(22, 6, 0.3) if m.def.size > 16 else PixelArt.shadow(10, 4, 0.25))
		shadow.position = Vector2(0, 3)
		shadow.z_index = -1
		add_child(shadow)
	_sprite = Sprite2D.new()
	_sprite.centered = false
	add_child(_sprite)
	_bar = Node2D.new()
	_bar.z_index = 5
	add_child(_bar)
	var back := ColorRect.new()
	back.color = Color("241c1a")
	back.size = Vector2(BAR_W, 3)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(back)
	_bar_fill = ColorRect.new()
	_bar_fill.color = Color("e0564a")
	_bar_fill.position = Vector2(1, 1)
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(_bar_fill)
	# 每只的晃动错开一点
	_t = float(Px.h2(int(m.pos.x), int(m.pos.y)) % 100) / 50.0
	sync(0.0)


func _process(delta: float) -> void:
	if GameClock.running:
		sync(delta)


## 走时钟身边那一圈：进去就走不快。
func _draw() -> void:
	if monster != null and monster.def.slow_aura > 0.0:
		draw_arc(Vector2.ZERO, monster.def.slow_aura, 0.0, TAU, 48, Color(0.78, 0.74, 0.96, 0.3), 1.0)


## 现在该用哪个姿势。
func pose() -> StringName:
	# 伞歇着的时候是收起来的
	if monster.def.guard_open and monster.state == MineMonster.State.REST:
		return &"stun"
	match monster.state:
		MineMonster.State.HIDDEN:
			return &"hidden"
		MineMonster.State.WAKING, MineMonster.State.STUNNED:
			return &"stun"
		MineMonster.State.WINDUP:
			return &"windup"
		MineMonster.State.STRIKE:
			return &"strike"
	return &"idle_a" if int(_t * 4.0) % 2 == 0 else &"idle_b"


## 这个姿势的图；用到了才画，画过的留着。戏班换了面具是另一套图。
func _texture(pose_name: StringName) -> Texture2D:
	var skin := monster.skin()
	var key := StringName("%s/%s" % [skin, pose_name])
	if not _poses.has(key):
		_poses[key] = Px.tex(MineArt.monster(monster.def.id, pose_name, skin))
	return _poses[key]


func sync(delta: float) -> void:
	_t += delta
	position = monster.pos.round()
	_sprite.texture = _texture(pose())
	_sprite.flip_h = monster.facing.x < -0.3 and monster.state != MineMonster.State.HIDDEN
	var lift := 0.0
	if monster.def.flying:
		lift = FLY_HEIGHT + sin(_t * 6.0) * 1.5
		if monster.state == MineMonster.State.STRIKE:
			lift = 3.0
	var air := monster.air()
	if air >= 0.0:
		lift = sin(air * PI) * LEAP_HEIGHT
	var shake := 0.0
	if monster.state == MineMonster.State.WINDUP or monster.state == MineMonster.State.WAKING:
		shake = 1.0 if int(_t * 24.0) % 2 == 0 else -1.0
	var size := monster.def.size
	# 老鲶在水里，图的正中对着它；别的脚踩在自己的位置上
	var top := -22.0 if monster is MineCatfish else -(size - 3.0)
	_sprite.position = Vector2(-size / 2.0 + shake, top - roundf(lift))
	_bar.visible = bar_shown()
	if _bar.visible:
		_bar.position = Vector2(-BAR_W / 2.0, -17.0 - roundf(lift))
		_bar_fill.size = Vector2(bar_width(), 1)
	# 前摇时一闪一闪发红，挨打时发白
	if monster.flash > 0.0:
		_sprite.modulate = Color(2.2, 2.2, 2.2)
	elif monster.state == MineMonster.State.WINDUP and int(_t * 12.0) % 2 == 0:
		_sprite.modulate = Color(1.7, 1.0, 1.0)
	else:
		_sprite.modulate = Color.WHITE
