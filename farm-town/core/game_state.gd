extends Node
## 玩家的全局数据：背包、金钱、体力、剧情标记、所在位置。

signal money_changed
signal energy_changed
signal selected_changed

const HOTBAR_SIZE := 8
const INVENTORY_SIZE := 24
const START_MAP := &"farm"
const START_SPAWN := &"start"

var inventory := Inventory.new(INVENTORY_SIZE)
var money := 0:
	set(value):
		money = maxi(0, value)
		money_changed.emit()
var max_energy := 100
var energy := 100:
	set(value):
		energy = clampi(value, 0, max_energy)
		energy_changed.emit()
## 物品栏里当前选中的格子
var selected_slot := 0:
	set(value):
		selected_slot = posmod(value, HOTBAR_SIZE)
		selected_changed.emit()
## 剧情和一次性事件的标记
var flags: Dictionary[StringName, bool] = {}
var map_id: StringName = START_MAP
var spawn: StringName = START_SPAWN


func _ready() -> void:
	SaveSystem.register(&"state", self)


func selected_item() -> ItemDef:
	var id := inventory.id_at(selected_slot)
	if id == &"":
		return null
	return Database.item(id)


## 消耗体力；不够时不扣并返回 false。
func spend_energy(amount: int) -> bool:
	if energy < amount:
		return false
	energy -= amount
	return true


func has_flag(flag: StringName) -> bool:
	return flags.get(flag, false)


func set_flag(flag: StringName) -> void:
	flags[flag] = true


## 存档摘要，显示在读档菜单里。
func save_meta() -> Dictionary:
	return {"day": GameClock.day, "date": GameClock.date_text(), "year": GameClock.year(), "money": money}


func save_data() -> Dictionary:
	var flag_list: Array = []
	for f: StringName in flags:
		if flags[f]:
			flag_list.append(String(f))
	return {
		"inventory": inventory.to_array(),
		"money": money,
		"energy": energy,
		"max_energy": max_energy,
		"selected_slot": selected_slot,
		"flags": flag_list,
		"map_id": String(map_id),
		"spawn": String(spawn),
	}


func load_data(data: Dictionary) -> void:
	var inv: Array = data.get("inventory", [])
	inventory.from_array(inv)
	max_energy = int(data.get("max_energy", 100))
	money = int(data.get("money", 0))
	energy = int(data.get("energy", max_energy))
	selected_slot = int(data.get("selected_slot", 0))
	flags.clear()
	var flag_list: Array = data.get("flags", [])
	for f: Variant in flag_list:
		flags[StringName(str(f))] = true
	map_id = StringName(str(data.get("map_id", START_MAP)))
	spawn = StringName(str(data.get("spawn", START_SPAWN)))


func reset_data() -> void:
	inventory.clear()
	inventory.add(&"hoe")
	inventory.add(&"watering_can")
	inventory.add(&"white_radish_seed", 12)
	max_energy = 100
	money = 500
	energy = max_energy
	selected_slot = 0
	flags.clear()
	map_id = START_MAP
	spawn = START_SPAWN
