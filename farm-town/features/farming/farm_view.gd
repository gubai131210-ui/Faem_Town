class_name FarmView
extends Node2D
## 把 FarmState 画出来：耕地画在地面上，作物是参与遮挡排序的精灵。

const TS := GameMap.TS

var _state: FarmState
var _entities: Node2D
var _soil_tex: Array = [[], []]
var _crop_tex: Dictionary[String, Texture2D] = {}
var _sprites: Dictionary[Vector2i, Sprite2D] = {}


## entities 是地图上按 y 排序的图层，作物精灵放在里面。
func setup(state: FarmState, entities: Node2D) -> void:
	_state = state
	_entities = entities
	for wet in 2:
		for mask in 16:
			_soil_tex[wet].append(Px.tex(PixelArt.soil(mask, wet == 1)))
	_state.changed.connect(_sync)
	_sync()


func _exit_tree() -> void:
	if _state != null and _state.changed.is_connected(_sync):
		_state.changed.disconnect(_sync)


func _draw() -> void:
	if _state == null:
		return
	for t: Vector2i in _state.soil:
		var mask := 0
		if _state.soil.has(t + Vector2i(0, -1)):
			mask |= 1
		if _state.soil.has(t + Vector2i(1, 0)):
			mask |= 2
		if _state.soil.has(t + Vector2i(0, 1)):
			mask |= 4
		if _state.soil.has(t + Vector2i(-1, 0)):
			mask |= 8
		var tex: Texture2D = _soil_tex[1 if _state.is_wet(t) else 0][mask]
		draw_texture(tex, Vector2(t.x * TS, t.y * TS))


func _sync() -> void:
	queue_redraw()
	for t: Vector2i in _sprites.keys():
		if not _state.has_crop(t):
			_sprites[t].queue_free()
			_sprites.erase(t)
	for t: Vector2i in _state.crops:
		var sprite: Sprite2D = _sprites.get(t)
		if sprite == null:
			sprite = Sprite2D.new()
			sprite.centered = false
			sprite.offset = Vector2(-8, -14)
			sprite.position = Vector2(t.x * TS + 8, t.y * TS + 12)
			_entities.add_child(sprite)
			_sprites[t] = sprite
		sprite.texture = _texture_for(_state.crop_id_at(t), _state.crop_stage_at(t))


func _texture_for(crop_id: StringName, stage: int) -> Texture2D:
	var key := "%s:%d" % [crop_id, stage]
	if not _crop_tex.has(key):
		# 作物图固定画了 4 个阶段，把任意阶段数映射过去
		var def := Database.crop(crop_id)
		var last := def.stage_days.size()
		var art_stage := 3 if stage >= last else mini(stage, 2)
		_crop_tex[key] = Px.tex(PixelArt.crop(crop_id, art_stage))
	return _crop_tex[key]
