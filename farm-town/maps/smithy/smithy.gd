extends ShopRoom
## 石叔的铁匠铺里间。门垫回到南街门口。他仍在门外，进屋只看炉子（决策 115）。
## 扩成 24×14（决策 161）：石墙石地，后墙正中是炉膛，左边风箱和矿石，右边炭堆；炉前是铁砧和淬火的水槽，
## 墙上两排挂着钳子锤子，右边一块磨石，左前角是没打完的活计。矿工巷离得不远，矿石和炭都从井口运来。


func _setup() -> void:
	map_id = &"smithy"
	W = 24
	H = 14
	_exit = {"map": &"town", "spawn": &"smithy_door"}


func _look() -> Dictionary:
	return {"wall": "stone", "floor": "brick", "windows": [6, 16] as Array[int]}


func _lines() -> Dictionary:
	return {
		&"tools": "墙上的钳子、锤子、凿子，一样一个挂钩，没有一个挂错。",
		&"bellows": "风箱的拉杆一推一拉，炉里的炭就红一阵。",
		&"ore": "筐里是井口运来的矿石，灰的青的都有，沉得很。",
		&"coal": "炭堆黑得发亮，伸手一碰就是一手灰。",
		&"anvil": "铁砧上有几道新的锤痕，还没来得及磨平。",
		&"trough": "淬火的水槽，水面浮着一层黑灰，底下是凉的。",
		&"grind": "磨石上还是湿的，刃口磨过的地方发白。",
		&"bench": "台上一把没打完的镰刀坯子，刃口还没开。",
		&"sacks": "麻袋里装的是炭，扎口的绳子被熏成了黑的。",
	}


func _stock() -> void:
	_hang("tool_rack:4", 48, 31, &"tools", 1, 4)
	_hang("tool_rack:4", 336, 31, &"tools", 19, 4)
	# 炉子在正中，两边是风箱和炭
	_put("forge", Vector2i(10, 3), Vector2i(3, 1), &"forge")
	_put("bellows", Vector2i(8, 3), Vector2i(2, 1), &"bellows")
	_put("ore_bin", Vector2i(6, 3), Vector2i(2, 1), &"ore")
	_put("coal_bin", Vector2i(13, 3), Vector2i(2, 1), &"coal")
	# 炉前：铁砧、水槽、桶
	_put("anvil", Vector2i(9, 6), Vector2i(2, 1), &"anvil")
	_put("trough", Vector2i(13, 6), Vector2i(2, 1), &"trough")
	_put("bucket", Vector2i(15, 6))
	if Livelihood.told(&"mine") >= 1:
		var hammer := Sprite2D.new()
		hammer.name = "SpareHammer"
		hammer.texture = Px.tex(_spare_hammer())
		hammer.centered = false
		hammer.position = Vector2(8 * TS + 2, 6 * TS + 4)
		entities.add_child(hammer)
	# 右边磨石和炭
	_put("grindstone", Vector2i(20, 4), Vector2i(2, 1), &"grind")
	_put("sacks", Vector2i(20, 10), Vector2i(2, 1), &"sacks")
	# 左前：没打完的活计
	_put("workbench:3", Vector2i(1, 9), Vector2i(3, 1), &"bench")
	_put("sacks", Vector2i(1, 12), Vector2i(2, 1), &"sacks")
	_put("bucket", Vector2i(5, 9))
	_put("coal_bin", Vector2i(16, 11), Vector2i(2, 1), &"coal")


func _on_use(key: StringName, tile: Vector2i) -> void:
	if key != &"forge":
		super._on_use(key, tile)
		return
	var extra := PeopleLine.mark(&"shishu")
	var line := "炉膛是热的。铁砧一头尖着，锤子躺在旁边。"
	if extra != "":
		line += extra
	var trade := Livelihood.mark(&"mine")
	EventBus.banner_requested.emit(line if trade == "" else line + trade)


func _spare_hammer() -> Image:
	var img := Px.new_img(10, 8)
	Px.rect(img, 0, 3, 7, 2, Color.html("6a4430"))
	Px.rect(img, 6, 1, 4, 6, Color.html("8a9098"))
	Px.rect(img, 7, 2, 2, 4, Color.html("c8ccd0"))
	return img
