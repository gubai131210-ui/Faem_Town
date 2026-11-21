class_name TownLand
extends RefCounted
## 镇子扩大以后的分区规则（决策 149）。镇子从 46×30 扩到 84×54，只往东、往南长，
## 老镇子那一片的格子坐标一格不动。新长出来的地方分四块：
## 东市随广场灯回来（没有雾，灯亮以前是一片空地）；其余三块盖着雾，对应的灯亮了才走得进去。

const OLD_W := 46
const OLD_H := 30
const W := 84
const H := 54

const SOUTH := &"south"
const MILL := &"mill"
const HILL := &"hill"

## 盖着雾的三块：[区域, 范围, 要哪盏灯, 名字, 灯没亮时碰一下说的话, 头一回看见雾退了说的话]
const ZONES: Array = [
	[SOUTH, Rect2i(26, 31, 32, 22), &"river", "南巷",
		"南巷口的雾压得很低，里面只看得见屋檐的影子。河灯亮了，它才会退。",
		"南巷的雾退了。巷子两边是一排排老屋，有的门楣上还留着字。"],
	[MILL, Rect2i(44, 0, 14, 12), &"pasture", "河湾磨坊",
		"北边河湾那一片雾沉在水面上。牧野灯亮了，水边的路才看得清。",
		"河湾的雾退了。水磨、船坞都还在原处，像是等着人回来。"],
	[HILL, Rect2i(64, 0, 20, 13), &"well", "北岗",
		"路口的石门后面是一片白，看不出有没有台阶。井口灯亮了，雾才会往山里退。",
		"北岗的雾退了。石门后面有台阶，台阶上头是一座小祠。"],
]

## 东市：铺石板、摆摊子，广场灯亮了才有
const MARKET := Rect2i(47, 13, 10, 12)


## 这一格是不是盖着雾的区域里的格子；不是返回空串。
static func zone_of(t: Vector2i) -> StringName:
	for z: Array in ZONES:
		var rect: Rect2i = z[1]
		if rect.has_point(t):
			return z[0]
	return &""


static func _zone(id: StringName) -> Array:
	for z: Array in ZONES:
		if z[0] == id:
			return z
	return []


static func lamp_of(id: StringName) -> StringName:
	return _zone(id)[2]


static func rect_of(id: StringName) -> Rect2i:
	return _zone(id)[1]


static func zone_name(id: StringName) -> String:
	return _zone(id)[3]


static func waiting(id: StringName) -> String:
	return _zone(id)[4]


static func opened_text(id: StringName) -> String:
	return _zone(id)[5]


static func is_open(id: StringName) -> bool:
	var z := _zone(id)
	return not z.is_empty() and Lamps.is_lit(z[2])


## 这一格走不走得进去：不在雾区里就一直通；在雾区里要看灯。
static func open_tile(t: Vector2i) -> bool:
	var id := zone_of(t)
	return id == &"" or is_open(id)


## 现在开着的雾区，按 ZONES 的顺序。
static func open_zones() -> Array[StringName]:
	var out: Array[StringName] = []
	for z: Array in ZONES:
		if is_open(z[0]):
			out.append(z[0])
	return out
