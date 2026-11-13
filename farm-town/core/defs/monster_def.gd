class_name MonsterDef
extends RefCounted
## 一种忘形（井里的怪物），来自 data/monsters.json。距离的单位是像素，时间是秒。

var id: StringName
var name: String
var hp := 10
## 撞到人扣多少生命
var damage := 5
## 平时挪动的速度
var speed := 20.0
## 离人多近开始追
var sight := 90.0
## 离人多近开始出招
var reach := 20.0
## 出招前摇多久（这段时间它不动，画面上有提示）
var windup := 0.45
## 出招时冲多快、冲多久
var strike_speed := 90.0
var strike_time := 0.3
## 出完招歇多久
var rest := 1.0
## 身子的半径
var radius := 6.0
## 会飞：不被石头挡
var flying := false
## 正面有防御：从正面打不动，要绕后或者用锤
var guard := false
## 平时装成石头，人走近才动
var hidden := false
## 装石头的时候，人走到多近它醒
var wake := 36.0
## 打倒以后掉什么：每项 {"item": 物品 id, "chance": 0 到 1}
var drops: Array[Dictionary] = []
## 出招是跳起来砸下去：落地的时候周围 blast 这么远都挨打
var leap := false
var blast := 0.0
## 防御只在撑开的时候有（追人和前摇）：出招和歇着的时候正面也打得进去
var guard_open := false
## 在水里快多少倍；0 是不分水里岸上
var swim := 0.0
## 人走进这个范围就变慢；0 是没有
var slow_aura := 0.0
## 一次出来几只（成对出现的是 2）
var pack := 1
## 大于 0：出招是隔着老远扔东西，这是扔出去的速度
var shot_speed := 0.0
## 远程的忘形不让人靠到这么近，会往后退
var keep_away := 0.0
## 打倒以后有机会掉的遗物（它原来的样子），和掉的机会
var relic: StringName = &""
var relic_chance := 0.0
## 首领的打法："cart" 废矿车、"catfish" 井底老鲶、"troupe" 无名戏班、"shade" 岚之影；普通忘形是空
var boss: StringName = &""
## 首领打倒以后记的标记
var flag: StringName = &""
## 首领晕多久（矿车撞墙、老鲶被拉上岸），这段时间才打得动
var stun := 0.0
## 矿车一次最多冲多远
var charge_len := 0.0
## 画出来多大（像素见方）
var size := 16
## 大于 0：撞到人不扣生命，吃掉这么多灯油（噬光蛾；岚之影吹出来的风也按这个数）
var eat_light := 0.0
## 大于 0：不自己找路，照着人这么多秒以前走过的地方走（影子）
var echo := 0.0
## 被灯照到就停住，只在灯照不到的地方动（忘名者）
var shy := false


static func from_dict(d: Dictionary) -> MonsterDef:
	var def := MonsterDef.new()
	def.id = StringName(str(d.get("id", "")))
	def.name = str(d.get("name", ""))
	def.hp = int(d.get("hp", 10))
	def.damage = int(d.get("damage", 5))
	def.speed = float(d.get("speed", 20.0))
	def.sight = float(d.get("sight", 90.0))
	def.reach = float(d.get("reach", 20.0))
	def.windup = float(d.get("windup", 0.45))
	def.strike_speed = float(d.get("strike_speed", 90.0))
	def.strike_time = float(d.get("strike_time", 0.3))
	def.rest = float(d.get("rest", 1.0))
	def.radius = float(d.get("radius", 6.0))
	def.flying = bool(d.get("flying", false))
	def.guard = bool(d.get("guard", false))
	def.hidden = bool(d.get("hidden", false))
	def.wake = float(d.get("wake", 36.0))
	def.leap = bool(d.get("leap", false))
	def.blast = float(d.get("blast", 0.0))
	def.guard_open = bool(d.get("guard_open", false))
	def.swim = float(d.get("swim", 0.0))
	def.slow_aura = float(d.get("slow_aura", 0.0))
	def.pack = maxi(1, int(d.get("pack", 1)))
	def.shot_speed = float(d.get("shot_speed", 0.0))
	def.keep_away = float(d.get("keep_away", 0.0))
	def.relic = StringName(str(d.get("relic", "")))
	def.relic_chance = float(d.get("relic_chance", 0.0))
	def.boss = StringName(str(d.get("boss", "")))
	def.flag = StringName(str(d.get("flag", "")))
	def.stun = float(d.get("stun", 0.0))
	def.charge_len = float(d.get("charge_len", 0.0))
	def.size = int(d.get("size", 16))
	def.eat_light = float(d.get("eat_light", 0.0))
	def.echo = float(d.get("echo", 0.0))
	def.shy = bool(d.get("shy", false))
	var list: Variant = d.get("drops", [])
	if list is Array:
		for entry: Variant in list:
			if entry is Dictionary:
				var e: Dictionary = entry
				def.drops.append({"item": StringName(str(e.get("item", ""))), "chance": float(e.get("chance", 0.0))})
	return def
