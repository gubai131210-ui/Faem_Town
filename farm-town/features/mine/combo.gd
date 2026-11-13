class_name Combo
extends RefCounted
## 连段计数：一下接一下按得够紧，就是连段里的下一下；隔久了或者打完最后一下，从头来。

## 两下之间最多隔多久（秒，从上一下出手算起）
const WINDOW := 0.9

var _step := -1
var _since := 0.0


func tick(delta: float) -> void:
	_since += delta


## 出一下手：返回这是连段里的第几下（从 0 数）。length 是这件武器的连段有几下。
func advance(length: int) -> int:
	if _step < 0 or _since > WINDOW or _step + 1 >= length:
		_step = 0
	else:
		_step += 1
	_since = 0.0
	return _step


func reset() -> void:
	_step = -1
	_since = 0.0
