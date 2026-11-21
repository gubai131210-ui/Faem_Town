class_name FarmLand
## 农场的地块：哪一格属于哪一块地，这块地开了没有（决策 147）。
## 老院一开始就有；别的地块盖在雾里，镇上的灯一盏盏亮起来，雾一块块退开。
## 溪东仍要柏先生的许可（忆五级）。只有静态函数，不存状态。

## 整张农场的大小（格）
const W := 100
const H := 72
## 扩大以前的农场只有这么大。这一片里的格子坐标一格没动，老存档的地、树、棚子都在原位。
const OLD_W := 52
const OLD_H := 38
## 东岗从这一列往东
const RIDGE_X := 78

const HOME := &"home"
const SOUTH := &"south"
const MARSH := &"marsh"
const SLOPE := &"slope"
const RIDGE := &"ridge"
const EAST := &"east"

## 地块的顺序就是大致开出来的顺序
const ORDER: Array[StringName] = [HOME, SOUTH, MARSH, SLOPE, RIDGE, EAST]
const NAMES: Dictionary[StringName, String] = {
	HOME: "老院", SOUTH: "南坡", MARSH: "南洼", SLOPE: "东坡", RIDGE: "东岗", EAST: "溪东",
}
## 哪盏灯亮了，这块地的雾退开。溪东不看灯。
const LAMPS: Dictionary[StringName, StringName] = {
	SOUTH: &"lamp_plaza", MARSH: &"lamp_river", SLOPE: &"lamp_pasture", RIDGE: &"lamp_well",
}
const HINTS: Dictionary[StringName, String] = {
	SOUTH: "雾把南边的坡地盖住了。广场上的灯亮起来，这里的雾才会退。",
	MARSH: "再往南是一片洼地，雾贴着水。南溪边的河灯亮起来，这里的雾才会退。",
	SLOPE: "溪那边的坡上全是雾。牧野灯亮起来，这里的雾才会退。",
	RIDGE: "岗子上的雾最厚。井口灯亮起来，这里的雾才会退。",
	EAST: "桥那头是雾，雾里像是有一堵墙。这块地要镇公所的柏先生点头。",
}
const OPENED: Dictionary[StringName, String] = {
	SOUTH: "南坡的雾退了。屋子南边多出一大片能开垦的坡地。",
	MARSH: "南洼的雾退了。洼地里有一口苇塘，挨着水好开水田。",
	SLOPE: "东坡的雾退了。踩着溪里的石头过得去。",
	RIDGE: "东岗的雾退了。从东坡的石阶上得去。",
	EAST: "溪东的雾退了。桥那头有一座塌了的院子。",
}


## 小溪在这一行最靠西的那一格。老农场那一段和原来一样；往南慢慢偏东。
static func stream_x(y: int) -> int:
	var x := 46 + int(roundf(sin(y * 0.33) * 1.6))
	if y >= OLD_H:
		x += mini(int(roundf((y - OLD_H) * 0.22)), 7)
	return x


## 这一格在小溪东岸（水和西岸都不算）。
static func east_of_stream(t: Vector2i) -> bool:
	return t.x >= stream_x(t.y) + 2


static func region_of(t: Vector2i) -> StringName:
	var east := east_of_stream(t)
	if t.y < OLD_H:
		if not east:
			return HOME
		return RIDGE if t.x >= RIDGE_X else EAST
	if east:
		return SLOPE
	return SOUTH if t.y < 56 else MARSH


static func is_open(region: StringName) -> bool:
	if region == HOME:
		return true
	if region == EAST:
		return Residents.memory_level(&"bai") >= 5
	return GameState.has_flag(LAMPS[region])


static func open_tile(t: Vector2i) -> bool:
	return is_open(region_of(t))


## 现在开着的地块，按 ORDER 的顺序。
static func open_regions() -> Array[StringName]:
	var out: Array[StringName] = []
	for region in ORDER:
		if is_open(region):
			out.append(region)
	return out


## 这一格本来有没有乱石：只在新地块里，大约二十格里一格。能不能真的放由地图看地形。
static func rubble_roll(t: Vector2i) -> bool:
	if t.x < OLD_W and t.y < OLD_H:
		return false
	return Px.h2(t.x * 7 + 11, t.y * 13 + 5) % 100 < 5
