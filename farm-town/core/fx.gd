class_name Fx
extends RefCounted
## 一次性的小特效。


## 在 parent 下的 pos 位置喷出一小团粒子，播完自动删除。
static func burst(parent: Node, pos: Vector2, color: Color, amount: int, speed: float,
		life: float = 0.4, gravity: float = 260.0) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.z_index = 10
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.9
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.gravity = Vector2(0, gravity)
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = color
	p.emitting = true
	parent.add_child(p)
	# tween 挂在粒子自己身上：场景一换，它跟着粒子一起停，不会回过头
	# 对已经释放的对象调 queue_free
	var tw := p.create_tween()
	tw.tween_interval(life + 0.3)
	tw.tween_callback(p.queue_free)


## 一个图标从 pos 弹起再淡出，用于收获等反馈。
static func pop_icon(parent: Node, pos: Vector2, tex: Texture2D) -> void:
	var s := Sprite2D.new()
	s.texture = tex
	s.position = pos
	s.z_index = 20
	parent.add_child(s)
	var tw := s.create_tween()
	tw.tween_property(s, "position:y", pos.y - 18.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "position:y", pos.y - 12.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(s, "modulate:a", 0.0, 0.25)
	tw.tween_callback(s.queue_free)


## 贴地扬起又落回去的一小团尘土，用于锄地、敲石头和图标落地。
## 比 burst 散得更开、重力更大，看着是从地上弹起来的。
static func dust_puff(parent: Node, pos: Vector2, color: Color = FieldMotion.DUST) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.z_index = 9
	p.amount = 6
	p.lifetime = 0.34
	p.one_shot = true
	p.explosiveness = 0.7
	p.direction = Vector2(0, -1)
	p.spread = 130.0
	p.gravity = Vector2(0, 320.0)
	p.initial_velocity_min = 18.0
	p.initial_velocity_max = 42.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 1.0
	p.color = color
	p.emitting = true
	parent.add_child(p)
	var tw := p.create_tween()
	tw.tween_interval(0.7)
	tw.tween_callback(p.queue_free)


## 图标弹起、落地、再小跳一下，落地那刻扬一点尘土。
## M9 第三批：收获、收果子、敲石头用这个，别的弹出反馈仍用 pop_icon。
static func pop_land(parent: Node, pos: Vector2, tex: Texture2D) -> void:
	var s := Sprite2D.new()
	s.texture = tex
	s.position = pos
	s.z_index = 20
	parent.add_child(s)
	var tw := s.create_tween()
	tw.tween_method(_bounce_step.bind([s, pos.y]), 0.0, 1.0, 0.62)
	tw.tween_callback(_dust_at.bind(parent, pos + Vector2(0, 6)))
	tw.tween_property(s, "modulate:a", 0.0, 0.2)
	tw.tween_callback(s.queue_free)


static func _bounce_step(t: float, args: Array) -> void:
	var s: Sprite2D = args[0]
	if is_instance_valid(s):
		s.position.y = float(args[1]) + FieldMotion.bounce(t)


static func _dust_at(parent: Node, pos: Vector2) -> void:
	if is_instance_valid(parent):
		dust_puff(parent, pos)
