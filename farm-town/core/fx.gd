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
	parent.get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)


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
