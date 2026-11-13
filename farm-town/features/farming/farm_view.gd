class_name FarmView
extends Node2D
## 把 FarmState 画出来：耕地画在地面上，作物是参与遮挡排序的精灵。

const TS := GameMap.TS
const FERT_BASIC := Color("efe6cf")
const FERT_FINE := Color("f2c14e")
## 蔫了的作物整体发黄
const WILT_TINT := Color(0.86, 0.78, 0.45)

const CANAL_BANK := Color("8a5a34")
const CANAL_BED := Color("6a4328")
const CANAL_WATER := Color("4aa0d8")
const CANAL_SHINE := Color("a6dcf2")
const PADDY_WATER := Color(0.33, 0.66, 0.88, 0.62)
const PADDY_BUND := Color("7d5030")

## 地图给的函数：这一格是不是天然的水。水渠朝着水的那一边要接过去。
var water_at := Callable()

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
		# 施过肥的地上撒着几粒肥
		var power := _state.fert_at(t)
		if power > 0:
			var grain := FERT_FINE if power > 1 else FERT_BASIC
			for i in 9:
				var gx := 2 + Px.h2(t.x * 7 + i, t.y) % 12
				var gy := 3 + Px.h2(t.x, t.y * 5 + i) % 10
				draw_rect(Rect2(t.x * TS + gx, t.y * TS + gy, 1, 1), grain)


	for t: Vector2i in _state.paddies:
		var x := t.x * TS
		var y := t.y * TS
		draw_rect(Rect2(x, y, TS, TS), PADDY_BUND, false, 1.0)
		if _state.is_wet(t):
			draw_rect(Rect2(x + 1, y + 1, TS - 2, TS - 2), PADDY_WATER)
			var hx := 2 + Px.h2(t.x, t.y) % 8
			draw_rect(Rect2(x + hx, y + 4 + Px.h2(t.y, t.x) % 3, 4, 1), CANAL_SHINE)
			draw_rect(Rect2(x + 12 - hx, y + 10 + Px.h2(t.x + 5, t.y) % 3, 3, 1), CANAL_SHINE)
	for t: Vector2i in _state.canals:
		_draw_canal(t)


## 一格水渠：中间一块，朝有水渠或天然水的方向伸出去。先画岸再画水，接缝处不留岸。
func _draw_canal(t: Vector2i) -> void:
	var x := t.x * TS
	var y := t.y * TS
	var fill := CANAL_WATER if _state.is_flooded(t) else CANAL_BED
	var arms: Array[bool] = []
	for d in FarmState.DIRS4:
		var n := t + d
		arms.append(_state.is_canal(n) or (water_at.is_valid() and bool(water_at.call(n))))
	draw_rect(Rect2(x + 3, y + 3, 10, 10), CANAL_BANK)
	if arms[0]:
		draw_rect(Rect2(x + 3, y, 10, 3), CANAL_BANK)
	if arms[1]:
		draw_rect(Rect2(x + 13, y + 3, 3, 10), CANAL_BANK)
	if arms[2]:
		draw_rect(Rect2(x + 3, y + 13, 10, 3), CANAL_BANK)
	if arms[3]:
		draw_rect(Rect2(x, y + 3, 3, 10), CANAL_BANK)
	draw_rect(Rect2(x + 5, y + 5, 6, 6), fill)
	if arms[0]:
		draw_rect(Rect2(x + 5, y, 6, 5), fill)
	if arms[1]:
		draw_rect(Rect2(x + 11, y + 5, 5, 6), fill)
	if arms[2]:
		draw_rect(Rect2(x + 5, y + 11, 6, 5), fill)
	if arms[3]:
		draw_rect(Rect2(x, y + 5, 5, 6), fill)
	if _state.is_flooded(t):
		draw_rect(Rect2(x + 6 + Px.h2(t.x, t.y) % 3, y + 6 + Px.h2(t.y, t.x) % 3, 2, 1), CANAL_SHINE)


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
			# 作物图是 16×24，根部在第 20 行，对到格子中间偏下的位置
			sprite.offset = Vector2(-8, -22)
			sprite.position = Vector2(t.x * TS + 8, t.y * TS + 12)
			_entities.add_child(sprite)
			_sprites[t] = sprite
		var giant := _state.is_giant(t) and not _state.is_dead(t)
		# 巨型作物的图是 32×32，根部在第 28 行
		sprite.offset = Vector2(-16, -30) if giant else Vector2(-8, -22)
		if giant:
			sprite.texture = _giant_texture(_state.crop_id_at(t))
		else:
			sprite.texture = _texture_for(_state.crop_id_at(t), _state.crop_stage_at(t), _state.is_dead(t))
		sprite.modulate = WILT_TINT if _state.is_wilted(t) and not _state.is_dead(t) else Color.WHITE


func _giant_texture(crop_id: StringName) -> Texture2D:
	var key := "giant:%s" % crop_id
	if not _crop_tex.has(key):
		_crop_tex[key] = Px.tex(CropArt.giant(crop_id))
	return _crop_tex[key]


func _texture_for(crop_id: StringName, stage: int, dead: bool) -> Texture2D:
	var key := "dead" if dead else "%s:%d" % [crop_id, stage]
	if not _crop_tex.has(key):
		# 作物图固定画了 4 个阶段，把任意阶段数映射过去
		var def := Database.crop(crop_id)
		var last := def.stage_days.size()
		var art_stage := 3 if stage >= last else mini(stage, 2)
		_crop_tex[key] = Px.tex(PixelArt.crop(crop_id, art_stage, dead))
	return _crop_tex[key]
