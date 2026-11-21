extends ShopRoom
## 云来茶馆的堂屋。门垫出门回到镇广场。掌柜仍在门外，进屋只是坐一坐（决策 109）。
## 扩成 26×15（决策 161）：云来的茶是茶岭的茶，所以后墙是一排排茶罐，角落叠着晒茶的竹匾；
## 靠里一座矮台是说书的地方（下雨天说书人在茶馆，决策 075），右边柜台后是烧水的灶。

const CABINET_X := 24
## 靠墙那只柜子占的两格。对着按一下看里面，和茶桌上的空杯不是一句。
const CABINET_TILES: Array[Vector2i] = [Vector2i(24, 2), Vector2i(25, 2)]
## 茶桌：左上角。每张桌子两边各一条凳子。
const TABLES: Array[Vector2i] = [Vector2i(3, 7), Vector2i(3, 11), Vector2i(7, 9), Vector2i(17, 9), Vector2i(21, 12)]

var _table_tiles: Array[Vector2i] = []


func _setup() -> void:
	map_id = &"teahouse"
	W = 26
	H = 15
	_exit = {"map": &"town", "spawn": &"teahouse_door"}


func _look() -> Dictionary:
	return {"wall": "timber", "floor": "plank", "windows": [5, 19] as Array[int]}


func _lines() -> Dictionary:
	return {
		&"cloth": "红布上一个「茶」字，金线都磨淡了。",
		&"pots": "架上的壶和杯一套一套摆着，没有一只是脏的。",
		&"tins_a": "茶罐上贴着产地：茶岭，春芽。多数罐子是空的。",
		&"tins_b": "茶罐上贴着产地：茶岭，秋茶。罐底还剩一点碎末。",
		&"stage": "矮台上一张小桌，桌角放着一块醒木。下雨天有人在这儿说书。",
		&"counter": "柜台上摊着一本账。最后一页的墨还没干透，像是前几年的。",
		&"kettle": "灶上的铜壶是温的，壶嘴里还冒着一点白气。",
		&"trays": "竹匾一层层叠着，晒过茶叶的地方还留着清香。",
	}


func _stock() -> void:
	# 后墙：茶具、茶罐、红布
	_hang("teapot_shelf:4", 32, 31, &"pots", 0, 4)
	_hang("tea_tins:3", 152, 31, &"tins_a", 8, 3)
	var cloth := _cloth()
	cloth.position = Vector2(W * TS / 2.0 - 10, 3)
	cloth.z_index = -9
	add_child(cloth)
	_mark(Vector2i(12, 1), Vector2i(2, 1), &"cloth")
	_hang("tea_tins:3", 264, 31, &"tins_b", 15, 3)
	_hang("lantern", 112, 24)
	_hang("lantern", 304, 24)
	# 右后角：灶和柜
	_put("stove", Vector2i(22, 2), Vector2i(2, 1), &"kettle")
	_put("cabinet", Vector2i(CABINET_X, 2), Vector2i(2, 1), &"cabinet")
	# 说书的矮台
	_decal("stage:8:2", Vector2i(9, 3))
	_put("table", Vector2i(12, 3), Vector2i(2, 1), &"stage")
	# 茶桌和凳子
	for t in TABLES:
		_put("table", t, Vector2i(2, 1), &"cups")
		_table_tiles.append(t)
		_table_tiles.append(t + Vector2i(1, 0))
		_put("stool", t + Vector2i(-1, 0))
		_put("stool", t + Vector2i(2, 0))
	# 柜台
	_put("counter:5", Vector2i(19, 5), Vector2i(5, 1), &"counter")
	for x in [19, 21, 23]:
		_put("stool", Vector2i(x, 6))
	# 左前角晒茶的竹匾，右前角灯和盆景
	_put("tea_tray_stack", Vector2i(0, 13), Vector2i(2, 1), &"trays")
	_put("bonsai", Vector2i(24, 13))
	_put("floor_lamp", Vector2i(25, 13))
	_put("jar_clay", Vector2i(10, 13), Vector2i(1, 1), &"", true)


func _on_use(key: StringName, tile: Vector2i) -> void:
	match key:
		&"cabinet":
			GameState.set_flag(&"read_tea_cabinet")
			EventBus.banner_requested.emit("柜子里是空茶罐。盖掀开，里面一层灰。")
		&"cups":
			EventBus.banner_requested.emit("茶桌上摆着两只空杯。")
		_:
			super._on_use(key, tile)


## 墙上的红布，写一个「茶」：草字头、人、木，三截分开，缩成像素还能认。
func _cloth() -> Sprite2D:
	var img := Px.new_img(20, 28)
	Px.rect(img, 0, 0, 20, 3, Color.html("6a4430"))
	Px.rect(img, 1, 3, 18, 24, Color.html("a83e36"))
	var gold := Color.html("f7dc80")
	# 艹
	Px.rect(img, 3, 5, 2, 3, gold)
	Px.rect(img, 8, 5, 2, 3, gold)
	Px.rect(img, 13, 5, 2, 3, gold)
	Px.rect(img, 5, 6, 3, 2, gold)
	Px.rect(img, 11, 6, 3, 2, gold)
	# 人
	Px.rect(img, 9, 9, 2, 2, gold)
	Px.rect(img, 6, 11, 2, 2, gold)
	Px.rect(img, 12, 11, 2, 2, gold)
	# 木
	Px.rect(img, 4, 14, 12, 2, gold)
	Px.rect(img, 9, 14, 2, 8, gold)
	Px.rect(img, 5, 18, 3, 2, gold)
	Px.rect(img, 12, 18, 3, 2, gold)
	Px.rect(img, 6, 21, 8, 2, gold)
	var spr := Sprite2D.new()
	spr.texture = Px.tex(Px.outline(img))
	spr.centered = false
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return spr
