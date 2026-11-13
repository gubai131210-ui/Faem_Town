extends Node
## 出货箱：白天把要卖的东西放进去，第二天早上按售价结算。品质越高卖得越贵。

signal changed

## 箱子里的东西：物品 id -> 三种品质各自的数量 [普通, 良, 优]
var bin: Dictionary[StringName, Array] = {}
## 最近一次结算的收入，早上的提示用
var last_income := 0
## 今年出货一共收入多少（除夕的年度总结用）。开春第一天早上结的是去年最后一天的货，算进新的一年
var year_income := 0


func _ready() -> void:
	SaveSystem.register(&"shipping", self)
	GameClock.register_daily(GameClock.ORDER_SHIPPING, settle)


## 放进出货箱。不能卖的东西不收，返回 false。
func add(id: StringName, count: int, quality: int = 0) -> bool:
	if count <= 0 or not Database.has_item(id) or not Database.item(id).sellable():
		return false
	if not bin.has(id):
		bin[id] = [0, 0, 0]
	var q := clampi(quality, 0, 2)
	bin[id][q] = int(bin[id][q]) + count
	changed.emit()
	return true


## 箱子里某种物品的数量；quality 为 -1 时不分品质。
func count_of(id: StringName, quality: int = -1) -> int:
	if not bin.has(id):
		return 0
	var counts: Array = bin[id]
	if quality >= 0:
		return int(counts[clampi(quality, 0, 2)])
	return int(counts[0]) + int(counts[1]) + int(counts[2])


## 箱子里的东西一共值多少。
func pending_value() -> int:
	var total := 0
	for id: StringName in bin:
		if not Database.has_item(id):
			continue
		var def := Database.item(id)
		for q in 3:
			total += def.price_for(q) * count_of(id, q)
	return total


## 每日结算：把钱给玩家，清空箱子。
func settle() -> void:
	last_income = pending_value()
	if GameClock.season() == 0 and GameClock.day_of_season() == 1:
		year_income = 0
	year_income += last_income
	if last_income > 0:
		GameState.money += last_income
	bin.clear()
	changed.emit()


func save_data() -> Dictionary:
	var out := {}
	for id: StringName in bin:
		out[String(id)] = [count_of(id, 0), count_of(id, 1), count_of(id, 2)]
	return {"bin": out, "last_income": last_income, "year_income": year_income}


func load_data(data: Dictionary) -> void:
	bin.clear()
	var saved: Dictionary = data.get("bin", {})
	for key: Variant in saved:
		var id := StringName(str(key))
		if not Database.has_item(id):
			continue
		var v: Variant = saved[key]
		var counts: Array = [0, 0, 0]
		if v is Array:
			var list: Array = v
			for q in mini(3, list.size()):
				counts[q] = maxi(0, int(list[q]))
		else:
			# 旧存档里每种物品只有一个数量
			counts[0] = maxi(0, int(v))
		if int(counts[0]) + int(counts[1]) + int(counts[2]) > 0:
			bin[id] = counts
	last_income = int(data.get("last_income", 0))
	year_income = int(data.get("year_income", 0))
	changed.emit()


func reset_data() -> void:
	bin.clear()
	last_income = 0
	year_income = 0
	changed.emit()
