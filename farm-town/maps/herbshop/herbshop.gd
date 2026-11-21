extends ShopRoom
## 姜记药铺的堂屋。门垫出门回到镇北街。掌柜仍在门外，进屋只是看看（决策 110）。
## 见过玉兔以后，除最左边外的药柜里有一剂，喝过就没了。
## 扩成 22×14（决策 161）：后墙一整排小抽屉，柜台把前堂和药柜隔开；晒药的架子、捣药的桌子、
## 候诊的长凳、熬药的灶都在屋里，窗下挂着红纸「药」。

## 药柜正前方那一排，对着按使用键看一眼。人站不到墙里。
const COUNTER_X0 := 2
const COUNTER_X1 := 8
## 玉兔留在药柜里的一剂。只喝一次，加的体力不超过上限。
const YUTU_SIP := 40


func _setup() -> void:
	map_id = &"herbshop"
	W = 22
	H = 14
	_exit = {"map": &"town", "spawn": &"herb_door"}


func _look() -> Dictionary:
	return {"wall": "plaster", "floor": "plank", "windows": [10] as Array[int]}


func _lines() -> Dictionary:
	return {
		&"jars": "架上的青瓷罐和白罐贴着药名，字都是姜婆婆自己写的。",
		&"stove": "砂锅里的药汁熬着，苦味顺着门缝飘到街上。",
		&"counter": "柜台上一杆小秤，秤盘里还沾着一点药末。",
		&"mortar": "石臼里是半臼没捣完的药，杵子靠在边上。",
		&"racks": "架上晒着一把把草药，有绿的，也有晒黄了的。",
		&"bench": "候诊的长凳，坐的人多了，木头磨得发亮。",
		&"screen": "屏风后头是个歇脚的角落，给撑不住的人躺一躺。",
		&"sign": "红纸上一个「药」字，是门外那块旧招牌的底样。",
		&"bundles": "梁上挂着的药束，绿的新，黄的旧。",
	}


func _stock() -> void:
	# 后墙：抽屉、窗、罐子、红纸
	_hang("drawers:7", COUNTER_X0 * TS + 56, 31, &"drawers", COUNTER_X0, 7)
	_hang("herb_bundles", 207, 26, &"bundles", 12, 2)
	_hang("jar_shelf:3", 14 * TS + 24, 31, &"jars", 14, 3)
	_put("stove", Vector2i(17, 2), Vector2i(2, 1), &"stove")
	var sign := _sign()
	sign.position = Vector2(20 * TS - 4, 5)
	sign.z_index = -9
	add_child(sign)
	_mark(Vector2i(20, 1), Vector2i(2, 1), &"sign")
	# 柜台把药柜隔在里面，两头留着过人的口子
	_put("counter:8", Vector2i(7, 5), Vector2i(8, 1), &"counter")
	_atop("scale", Vector2(8 * TS + 8, 5 * TS - 14))
	_atop("mortar", Vector2(13 * TS, 5 * TS - 14))
	# 门口一条绿席通到柜台前
	_decal("runner:2:7:1", Vector2i(10, 6))
	# 左边晒药、捣药
	_put("drying_rack", Vector2i(1, 8), Vector2i(2, 1), &"racks")
	_put("drying_rack", Vector2i(1, 11), Vector2i(2, 1), &"racks")
	_put("table", Vector2i(4, 9), Vector2i(2, 1), &"mortar")
	_atop("mortar", Vector2(5 * TS + 4, 10 * TS - 16))
	_decal("herb_tray", Vector2i(4, 12))
	_decal("herb_tray", Vector2i(6, 12))
	# 右边候诊
	_put("bench", Vector2i(17, 8), Vector2i(2, 1), &"bench")
	_put("bench", Vector2i(17, 11), Vector2i(2, 1), &"bench")
	_put("folding_screen", Vector2i(18, 5), Vector2i(2, 1), &"screen")
	_put("bonsai", Vector2i(20, 12))
	_put("floor_lamp", Vector2i(21, 12))
	_put("jar_jade", Vector2i(1, 6))


func _on_use(key: StringName, tile: Vector2i) -> void:
	if key != &"drawers":
		super._on_use(key, tile)
		return
	# 最左边是旧方子，见过玉兔也不把药放进去。
	if tile.x == COUNTER_X0:
		GameState.set_flag(&"read_herb_slip")
		EventBus.banner_requested.emit("最左边的抽屉缝里露出半张方子。药名磨掉了，只剩剂量。")
		return
	# 玉兔把一剂留在其余抽屉里。喝过这一次，再看还是原来的苦味。
	if Bestiary.known(&"yutu") and not GameState.has_flag(&"yutu_medicine"):
		GameState.energy = clampi(GameState.energy + YUTU_SIP, 0, GameState.max_energy)
		GameState.set_flag(&"yutu_medicine")
		EventBus.banner_requested.emit("柜上留着玉兔捣的药。喝了，身上暖和一点。")
		return
	EventBus.banner_requested.emit("药柜上的小抽屉一格一格，闻着发苦。")


## 窗边的红纸「药」：草字头、纟、勺，缩成像素还能认。
func _sign() -> Sprite2D:
	var img := Px.new_img(20, 26)
	Px.rect(img, 0, 0, 20, 2, Color.html("6a4430"))
	Px.rect(img, 1, 2, 18, 22, Color.html("a83e36"))
	var gold := Color.html("f7dc80")
	# 艹
	Px.rect(img, 3, 5, 14, 2, gold)
	Px.rect(img, 6, 3, 2, 5, gold)
	Px.rect(img, 12, 3, 2, 5, gold)
	# 纟
	Px.rect(img, 4, 10, 4, 2, gold)
	Px.rect(img, 5, 13, 4, 2, gold)
	Px.rect(img, 4, 16, 6, 2, gold)
	Px.rect(img, 6, 18, 2, 3, gold)
	# 勺
	Px.rect(img, 11, 10, 5, 2, gold)
	Px.rect(img, 11, 10, 2, 3, gold)
	Px.rect(img, 14, 10, 2, 10, gold)
	Px.rect(img, 12, 14, 2, 2, gold)
	Px.rect(img, 12, 19, 4, 2, gold)
	var spr := Sprite2D.new()
	spr.texture = Px.tex(Px.outline(img))
	spr.centered = false
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return spr
