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


## 给对话脚本用的入口（对话里写 do EventBus.request_sleep()）。
func request_sleep() -> void:
	sleep_requested.emit()
