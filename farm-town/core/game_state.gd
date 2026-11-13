extends Node
## 玩家的全局数据：背包、金钱、体力、剧情标记、所在位置。

signal money_changed
signal energy_changed
signal selected_changed
## 吃了带效果的菜，或者读档、开新档换了一份状态
signal buff_changed
signal health_changed
## 生命掉到 0：晕倒
signal knocked_out

const HOTBAR_SIZE := 8
const INVENTORY_SIZE := 24
## 工具最高升到第几级（0 是开局的铜制工具）
const MAX_TOOL_LEVEL := 3
const TIER_NAMES: Array[String] = ["铜", "铁", "银", "金"]
## 食物给的增益：swift 走得快，hearty 干活省力
const BUFF_NAMES: Dictionary[StringName, String] = {&"swift": "脚步轻快", &"hearty": "干活省力"}
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
## 生命：只在井里挨打才掉，睡一觉回满，所以不进存档
var max_health := 100
var health := 100:
	set(value):
		health = clampi(value, 0, max_health)
		health_changed.emit()
## 物品栏里当前选中的格子
var selected_slot := 0:
	set(value):
		selected_slot = posmod(value, HOTBAR_SIZE)
		selected_changed.emit()
## 工具的等级：物品 id -> 0..MAX_TOOL_LEVEL，没记录的是 0
var tool_levels: Dictionary[StringName, int] = {}
## 剧情和一次性事件的标记
var flags: Dictionary[StringName, bool] = {}
## 现在带着的增益，以及它是哪一天吃的、到几点（当天的分钟数）为止；睡一觉就没了
var buff: StringName = &""
var buff_day := -1
var buff_end := 0.0
var map_id: StringName = START_MAP
var spawn: StringName = START_SPAWN


func _ready() -> void:
	SaveSystem.register(&"state", self)


func selected_item() -> ItemDef:
	var id := inventory.id_at(selected_slot)
	if id == &"":
		return null
	return Database.item(id)


func tool_level(id: StringName) -> int:
	return tool_levels.get(id, 0)


## 工具升一级；已经满级返回 false。
func upgrade_tool(id: StringName) -> bool:
	if tool_level(id) >= MAX_TOOL_LEVEL:
		return false
	tool_levels[id] = tool_level(id) + 1
	# 图标和名字变了，让界面刷新
	inventory.changed.emit()
	return true


## 显示给玩家的名字：工具带上材质（铜锄头、铁锄头……）。
func display_name(def: ItemDef) -> String:
	if def == null:
		return ""
	if def.tiered:
		return TIER_NAMES[tool_level(def.id)] + def.name
	if def.kind == &"accessory" and Mine.wearing(def.id):
		return def.name + "（戴着）"
	return def.name


## 消耗体力；不够时不扣并返回 false。
func spend_energy(amount: int) -> bool:
	if energy < amount:
		return false
	energy -= amount
	return true


## 挨了一下，扣 amount 点生命；掉到 0 发 knocked_out。已经是 0 时不再发。
func hurt(amount: int) -> void:
	if health <= 0 or amount <= 0:
		return
	health -= amount
	if health <= 0:
		knocked_out.emit()


## 现在是不是带着这种增益。
func buff_active(kind: StringName) -> bool:
	return buff == kind and buff_day == GameClock.day and GameClock.minutes < buff_end


## 现在带着的增益还剩几分钟；没有就是 0。
func buff_left() -> int:
	if buff == &"" or buff_day != GameClock.day:
		return 0
	return maxi(0, ceili(buff_end - GameClock.minutes))


## 给界面用的一句：“脚步轻快 2:30”；没有增益返回空。
func buff_text() -> String:
	var left := buff_left()
	if left <= 0:
		return ""
	return "%s %d:%02d" % [BUFF_NAMES.get(buff, ""), left / 60, left % 60]


## 吃一份食物：回体力、带上增益，受了伤的话也回生命（回的体力的一半），返回要显示的一句话。
## 不饿（体力和生命都满了、这样东西也不带增益）返回空，什么都不发生。
## 不动背包。
func eat(def: ItemDef) -> String:
	if def == null or def.kind != &"food":
		return ""
	if energy >= max_energy and health >= max_health and def.buff == &"":
		return ""
	# 小寒：热食效果翻倍
	var gain := def.energy * (2 if def.hot and GameClock.term_id() == &"xiaohan" else 1)
	var before := energy
	energy += gain
	var text := "吃了%s，体力 +%d" % [def.name, energy - before]
	if health < max_health:
		var health_before := health
		health += maxi(1, gain / 2)
		text += "，生命 +%d" % (health - health_before)
	if def.buff != &"":
		buff = def.buff
		buff_day = GameClock.day
		buff_end = GameClock.minutes + def.buff_minutes
		buff_changed.emit()
		text += "，%s %d 小时" % [BUFF_NAMES.get(buff, ""), def.buff_minutes / 60]
	return text


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
	var levels := {}
	for id: StringName in tool_levels:
		levels[String(id)] = tool_levels[id]
	return {
		"inventory": inventory.to_array(),
		"money": money,
		"energy": energy,
		"max_energy": max_energy,
		"selected_slot": selected_slot,
		"flags": flag_list,
		"tool_levels": levels,
		"buff": String(buff),
		"buff_day": buff_day,
		"buff_end": buff_end,
		"map_id": String(map_id),
		"spawn": String(spawn),
	}


func load_data(data: Dictionary) -> void:
	var inv: Array = data.get("inventory", [])
	inventory.from_array(inv)
	max_energy = int(data.get("max_energy", 100))
	money = int(data.get("money", 0))
	energy = int(data.get("energy", max_energy))
	health = max_health
	selected_slot = int(data.get("selected_slot", 0))
	tool_levels.clear()
	var levels: Dictionary = data.get("tool_levels", {})
	for key: Variant in levels:
		tool_levels[StringName(str(key))] = clampi(int(levels[key]), 0, MAX_TOOL_LEVEL)
	flags.clear()
	var flag_list: Array = data.get("flags", [])
	for f: Variant in flag_list:
		flags[StringName(str(f))] = true
	buff = StringName(str(data.get("buff", "")))
	buff_day = int(data.get("buff_day", -1))
	buff_end = float(data.get("buff_end", 0.0))
	buff_changed.emit()
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
	health = max_health
	selected_slot = 0
	tool_levels.clear()
	flags.clear()
	buff = &""
	buff_day = -1
	buff_end = 0.0
	buff_changed.emit()
	map_id = START_MAP
	spawn = START_SPAWN
