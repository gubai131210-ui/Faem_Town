extends Node
## 跨功能的全局信号。数量要少：只有“发的人不该知道谁在听”的事件才放这里。

## 请求镜头震动，amount 是像素
signal screen_shake_requested(amount: float)
## 玩家要睡觉（床、或熬到凌晨两点）
signal sleep_requested
## 请求播放一段对话；path 是 .dialogue 资源路径，title 是其中的段落名
signal dialogue_requested(path: String, title: String)
## 屏幕中央的短提示
signal banner_requested(text: String)
## 换季那天早上亮一下季节和节气；由 Hud 画一块一次性的名牌，不进存档
signal season_card_requested(text: String)
## 请求打开铺子的货单；counter 是哪家铺子（&"grocery" 杂货铺、&"smith" 铁匠铺、&"carpenter" 木匠铺）
signal shop_requested(counter: StringName)
## 请求打开公告栏
signal board_requested
## 请求打开灶台的菜谱
signal cook_requested
## 一道菜下锅了，演这段做法。id 是菜的物品 id。
signal cook_show_requested(id: StringName)
## 农舍桌子：打开席面
signal table_requested
## 八席齐了，请大家吃饭
signal feast_requested
## 请一到三位居民入座。people 是居民 id，dishes 是吃掉的菜，lines 是每人一句。
signal meal_requested(people: Array, dishes: Array, lines: Array)
## 请求打开某盏灯的灯座（供东西、点灯）
signal lamp_requested(lamp_id: StringName)
## 一盏灯点亮了
signal lamp_lit(lamp_id: StringName)
## 在井底做了选择：播结局。ending 是 Story.KEEP / CLEAR / NAME
signal ending_requested(ending: StringName)
## 手账里重看一段已经看过的过场。id 是过场自己的 id，不带 cutscene_ 前缀。
signal cutscene_replay_requested(id: StringName)


## 给对话脚本用的入口（对话里写 do EventBus.request_sleep()）。
func request_sleep() -> void:
	sleep_requested.emit()


## 对话里写 do EventBus.request_shop("grocery")。
func request_shop(counter: String) -> void:
	shop_requested.emit(StringName(counter))
