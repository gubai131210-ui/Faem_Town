class_name WeaponDef
extends RefCounted
## 一件武器，来自 data/weapons.json。三类武器各自的招式（几段、多远、多宽）写在 STYLES 里，
## 表里的一件武器只说自己是哪一类、一下打多少。

const KINDS: Array[StringName] = [&"sickle", &"dagger", &"hammer"]
## anim 主角的动作；speed 动作放多快；combo 连段里每一下的伤害倍数；
## reach 够多远（像素）、arc 左右各多少度；knock 把忘形推开多快；breaks 能不能破防和打断；
## skill 蓄力技的伤害倍数，skill_reach 蓄力技的范围（镰刀和锤是半径，短剑是突进的距离）
const STYLES: Dictionary[StringName, Dictionary] = {
	&"sickle": {"anim": &"slash", "speed": 1.0, "combo": [1.0, 1.0, 1.6], "reach": 28.0, "arc": 75.0,
		"knock": 60.0, "breaks": false, "skill": 2.0, "skill_reach": 30.0},
	&"dagger": {"anim": &"stab", "speed": 1.0, "combo": [1.0, 1.0, 1.0, 1.8], "reach": 26.0, "arc": 24.0,
		"knock": 30.0, "breaks": false, "skill": 2.2, "skill_reach": 56.0},
	&"hammer": {"anim": &"smash", "speed": 1.0, "combo": [1.0, 1.8], "reach": 24.0, "arc": 50.0,
		"knock": 90.0, "breaks": true, "skill": 2.0, "skill_reach": 40.0},
}
## 突进时刀尖扫过的宽度的一半
const DASH_HALF_WIDTH := 10.0

var id: StringName
var name: String
var kind: StringName = &"sickle"
## 图标单独画的话写在这（MineArt.weapon_icon 认的名字）；不写用这一类武器通用的
var icon := ""
var damage := 1
var price := 0
var desc := ""


static func from_dict(d: Dictionary) -> WeaponDef:
	var def := WeaponDef.new()
	def.id = StringName(str(d.get("id", "")))
	def.name = str(d.get("name", ""))
	def.kind = StringName(str(d.get("kind", "sickle")))
	def.icon = str(d.get("icon", ""))
	def.damage = int(d.get("damage", 1))
	def.price = int(d.get("price", 0))
	def.desc = str(d.get("desc", ""))
	return def


## 登记进物品表的那一份。
func as_item() -> ItemDef:
	var item := ItemDef.new()
	item.id = id
	item.name = name
	item.kind = &"weapon"
	item.icon = "weapon:" + (icon if icon != "" else String(kind))
	item.stack = 1
	item.price = price
	item.desc = desc
	return item


func style() -> Dictionary:
	return STYLES.get(kind, STYLES[&"sickle"])


func anim() -> StringName:
	return style()["anim"]


func speed() -> float:
	return float(style()["speed"])


func breaks_guard() -> bool:
	return bool(style()["breaks"])


func knock() -> float:
	return float(style()["knock"])


func combo_len() -> int:
	var combo: Array = style()["combo"]
	return combo.size()


## 连段里第 step 下（从 0 数）打多少。
func damage_at(step: int) -> int:
	var combo: Array = style()["combo"]
	return maxi(1, roundi(damage * float(combo[posmod(step, combo.size())])))


func skill_damage() -> int:
	return maxi(1, roundi(damage * float(style()["skill"])))


func skill_reach() -> float:
	return float(style()["skill_reach"])


## 普通的一下打不打得到：人在 origin、面朝 dir，对方在 point、身子半径 radius。
func hits(origin: Vector2, dir: Vector2, point: Vector2, radius: float = 0.0) -> bool:
	var v := point - origin
	var dist := v.length()
	if dist > float(style()["reach"]) + radius:
		return false
	# 贴在身上的不管朝向都算打到
	if dist <= radius + 4.0:
		return true
	return absf(rad_to_deg(dir.angle_to(v))) <= float(style()["arc"])


## 蓄力技打不打得到。镰刀和锤是身边一圈；短剑是从 origin 冲到 end 这一路。
func skill_hits(origin: Vector2, end: Vector2, point: Vector2, radius: float = 0.0) -> bool:
	if kind != &"dagger":
		return origin.distance_to(point) <= skill_reach() + radius
	var seg := end - origin
	var t := 0.0
	if seg.length_squared() > 0.001:
		t = clampf((point - origin).dot(seg) / seg.length_squared(), 0.0, 1.0)
	return (origin + seg * t).distance_to(point) <= DASH_HALF_WIDTH + radius
