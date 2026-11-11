extends Node
## 种田的全局系统：持有农场状态，负责它的存档和每日结算。
## 玩家不在农场时作物也照常生长。

var state := FarmState.new()


func _ready() -> void:
	SaveSystem.register(&"farming", self)
	GameClock.register_daily(GameClock.ORDER_CROPS, state.advance_day)


func save_data() -> Dictionary:
	return state.to_dict()


func load_data(data: Dictionary) -> void:
	state.from_dict(data)


func reset_data() -> void:
	state.clear()
