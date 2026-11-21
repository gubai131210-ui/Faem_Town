extends Node2D
## 只当风景的小东西：春天燕子、夏天水边的蜻蜓、秋天天上的雁、冬天下雪时地上的麻雀。
## 不能抓，不进背包。夏天白天室外另有蝉声，由游戏按 cicada() 接到底噪上。
## 燕和雁画在镜头上沿，跟着画面走，不钉在地图北边，否则人走到南边就看不见。
## 四样都是 Blender 序列帧（tools/animal.py），侧身朝右；往左时用朝左那一行。
## 落在地上的画在人和房子后面。天上的鸟画在屋顶前面，不然房顶会把它们盖住。幌子单独一层。


const PACE := 0.65

const _SHEET := {
	&"swallow": "swallow",
	&"dragonfly": "dragonfly",
	&"geese": "goose",
	&"sparrow": "sparrow",
}

## 室外地图拆成几层时分别关掉。单独用时都画。
## 天上的鸟要画在屋顶前面，落在地上的画在人和房子后面。
var draw_sky := true
var draw_ground := true
var draw_banner := true

static var _sheets: Dictionary = {}


static func pace(speed: float, weather: StringName) -> float:
	return speed * PACE if weather == &"fog" else speed


## 这一季这一天画面上有什么。雨和雷雨什么都不放。
static func kind(season: StringName, weather: StringName) -> StringName:
	if weather == &"rain" or weather == &"storm":
		return &""
	match season:
		&"spring":
			return &"swallow"
		&"summer":
			return &"dragonfly"
		&"autumn":
			return &"geese"
		&"winter":
			return &"sparrow" if weather == &"snow" else &""
	return &""


static func count(kind_id: StringName) -> int:
	match kind_id:
		&"swallow":
			return 2
		&"dragonfly":
			return 3
		&"geese":
			return 4
		&"sparrow":
			return 5
	return 0


## 夏天白天、室外、不是雨。海边的浪声优先，这里只回答该不该有蝉。
static func cicada(season: StringName, weather: StringName, indoor: bool, minutes: float) -> bool:
	if indoor or season != &"summer":
		return false
	if weather == &"rain" or weather == &"storm" or weather == &"snow":
		return false
	return minutes >= 8.0 * 60.0 and minutes < 18.0 * 60.0


## 第 index 只在 t 秒时的位置。燕子和雁的 bounds 用镜头大小，原点再加到镜头左上角。
## 蜻蜓、麻雀的 bounds 是整张地图。
static func spot(kind_id: StringName, index: int, t: float, bounds: Vector2) -> Vector2:
	var w := maxf(bounds.x, 64.0)
	var h := maxf(bounds.y, 64.0)
	match kind_id:
		&"swallow":
			var x := fposmod(t * 28.0 + float(index) * w * 0.42, w)
			return Vector2(x, 58.0 + float(index) * 20.0)
		&"dragonfly":
			var x := w * 0.64 + float(index - 1) * 36.0 + sin(t * 1.7 + float(index)) * 10.0
			var y := h * 0.46 + cos(t * 2.1 + float(index) * 1.3) * 10.0
			return Vector2(x, y)
		&"geese":
			var x := fposmod(t * 16.0 + float(index) * w * 0.2, w)
			var y := 64.0 + absf(float(index) - 1.5) * 14.0
			return Vector2(x, y)
		&"sparrow":
			var sx := w * 0.48 + float(index - 2) * 28.0 + sin(t * 3.0 + float(index)) * 3.0
			var sy := h * 0.76 + float(index % 2) * 4.0
			return Vector2(sx, sy)
	return Vector2.ZERO


## 朝右那一帧不透明像素的宽高。用来防止再缩回几个像素。
static func extent(kind_id: StringName) -> Vector2i:
	var sheet := _sheet(kind_id)
	if sheet == null or not sheet.is_valid():
		return Vector2i.ZERO
	var img := sheet.texture.get_image()
	if img == null:
		return Vector2i.ZERO
	var rect := sheet.region(_anim(kind_id), 2, 0)
	var min_x := 9999
	var min_y := 9999
	var max_x := -1
	var max_y := -1
	for y in range(int(rect.position.y), int(rect.end.y)):
		for x in range(int(rect.position.x), int(rect.end.x)):
			if img.get_pixel(x, y).a <= 0.1:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < 0:
		return Vector2i.ZERO
	return Vector2i(max_x - min_x + 1, max_y - min_y + 1)


static func preview() -> Image:
	var kinds: Array[StringName] = [&"swallow", &"dragonfly", &"geese", &"sparrow"]
	var img := Image.create(180, 56, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.16, 0.22, 0.18))
	var x := 4
	for kind_id in kinds:
		var sheet := _sheet(kind_id)
		if sheet == null or not sheet.is_valid():
			continue
		var src := sheet.texture.get_image()
		var rect := sheet.region(_anim(kind_id), 2, 0)
		img.blit_rect(src, Rect2i(rect), Vector2i(x, 4))
		x += sheet.cell + 4
	return img


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var bounds := _map_bounds()
	var t := Time.get_ticks_msec() / 1000.0
	if draw_banner:
		_draw_banner(t, bounds)
	var kind_id := kind(GameClock.season_id(), Weather.today)
	var n := count(kind_id)
	if n == 0:
		return
	var sky := kind_id == &"swallow" or kind_id == &"geese"
	if sky and not draw_sky:
		return
	if not sky and not draw_ground:
		return
	var sheet := _sheet(kind_id)
	if sheet == null or not sheet.is_valid():
		return
	var origin := Vector2.ZERO
	var space := bounds
	if kind_id == &"swallow" or kind_id == &"geese":
		var view := _view_rect()
		origin = view.position
		space = view.size
	var anim := _anim(kind_id)
	var frame := int(t * sheet.fps(anim)) % sheet.frame_count(anim)
	for i in n:
		var at := spot(kind_id, i, t, space) + origin
		var facing := 3 if _faces_left(kind_id, i, t) else 2
		var region := sheet.region(anim, facing, frame)
		var dest := Rect2(at.x - sheet.cell * 0.5, at.y - float(sheet.foot_row), sheet.cell, sheet.cell)
		draw_texture_rect_region(sheet.texture, dest, region)


func _map_bounds() -> Vector2:
	var parent_map := get_parent()
	if parent_map != null and parent_map.has_method(&"size_px"):
		var sz: Vector2i = parent_map.call(&"size_px")
		return Vector2(sz)
	return Vector2(320, 180)


func _view_rect() -> Rect2:
	var size := get_viewport().get_visible_rect().size
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return Rect2(Vector2.ZERO, size)
	var center := to_local(cam.get_screen_center_position())
	return Rect2(center - size * 0.5, size)


## 大风天茶馆檐下一块布幌。云娘追的就是这个，不另做动作。
func _draw_banner(t: float, bounds: Vector2) -> void:
	if Weather.today != &"wind":
		return
	if absf(bounds.x - 46.0 * 16.0) > 1.0 or absf(bounds.y - 30.0 * 16.0) > 1.0:
		return
	var sway := sin(t * 2.4)
	var pole := Vector2(34.0 * 16.0 + 4.0, 9.0 * 16.0 - 56.0)
	draw_rect(Rect2(pole, Vector2(2, 24)), Color("5c4030"))
	var cloth := pole + Vector2(2, 1 + sway)
	draw_rect(Rect2(cloth, Vector2(18, 20)), Color("c44848"))
	draw_rect(Rect2(cloth + Vector2(0, 7), Vector2(18, 4)), Color("f3e6c4"))
	draw_rect(Rect2(cloth + Vector2(0, 17), Vector2(18, 3)), Color("8a3030"))
	draw_rect(Rect2(cloth + Vector2(16, 4 + sway), Vector2(3, 8)), Color("c44848"))


static func _sheet(kind_id: StringName) -> CharacterSheet:
	if _sheets.has(kind_id):
		return _sheets[kind_id]
	var name: String = _SHEET.get(kind_id, "")
	if name.is_empty():
		return null
	var sheet := CharacterSheet.load_sheet(name, CharacterSheet.CREATURE_DIR)
	_sheets[kind_id] = sheet
	return sheet


static func _anim(kind_id: StringName) -> StringName:
	return &"walk" if kind_id == &"sparrow" else &"flap"


## 燕子和雁一直往右飞。蜻蜓和麻雀跟着自己的左右摆动转头。
static func _faces_left(kind_id: StringName, index: int, t: float) -> bool:
	match kind_id:
		&"dragonfly":
			return cos(t * 1.7 + float(index)) < 0.0
		&"sparrow":
			return cos(t * 3.0 + float(index)) < 0.0
	return false
