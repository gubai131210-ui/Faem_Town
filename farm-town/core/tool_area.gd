class_name ToolArea
extends RefCounted
## 工具蓄力后作用到哪些格子。

## 各蓄力档作用的格数，用于界面说明
const COUNTS: Array[int] = [1, 3, 5, 9]
const DIRS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]


## origin 是面前的那一格，facing 用 GameMap.Facing 的编号。
## 蓄力 0 档 1 格；1 档向前 3 格；2 档向前 5 格；3 档向前 3 排、每排 3 格。
## 返回的第一格总是 origin。
static func tiles(origin: Vector2i, facing: int, charge: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = [origin]
	var fwd := DIRS[clampi(facing, 0, 3)]
	match clampi(charge, 0, 3):
		1:
			for i in range(1, 3):
				out.append(origin + fwd * i)
		2:
			for i in range(1, 5):
				out.append(origin + fwd * i)
		3:
			var side := Vector2i(fwd.y, fwd.x)
			for i in 3:
				for s: int in [0, -1, 1]:
					var t := origin + fwd * i + side * s
					if t != origin:
						out.append(t)
	return out
