class_name GridPath
extends RefCounted
## 格子地图上的寻路：上下左右四个方向的广度优先搜索，给居民走路用。

const DIRS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]


## 从 from 走到 to 要经过的格子（不含 from，含 to）。走不到返回空数组；from 等于 to 也返回空数组。
## passable 是 func(tile: Vector2i) -> bool；bounds 之外的格子一律不能走。终点本身不要求可走，
## 这样居民可以走到柜台后面这类平时挡着的位置。
static func find(from: Vector2i, to: Vector2i, passable: Callable, bounds: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if from == to or not bounds.has_point(from) or not bounds.has_point(to):
		return out
	var came: Dictionary[Vector2i, Vector2i] = {from: from}
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size():
		var cur := queue[head]
		head += 1
		if cur == to:
			break
		for d in DIRS:
			var n := cur + d
			if came.has(n) or not bounds.has_point(n):
				continue
			if n != to and not bool(passable.call(n)):
				continue
			came[n] = cur
			queue.append(n)
	if not came.has(to):
		return out
	var at := to
	while at != from:
		out.append(at)
		at = came[at]
	out.reverse()
	return out
