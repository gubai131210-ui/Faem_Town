extends ShopRoom
## 青竹的木匠铺里间。门垫回到河埠门口。她人还在镇上，进屋只看图纸（决策 113）。
## 扩成 24×14（决策 161）：河埠的木匠，活计是船和桥。屋中间是一条才搭出骨架的小船，
## 后墙挂着桨、渔网和两张图纸，右边是工作台、锯马和一堆木料，地是深色木板，踩上去一层刨花。

const DRAWING_X0 := 8
const DRAWING_X1 := 12


func _setup() -> void:
	map_id = &"workshop"
	W = 24
	H = 14
	_exit = {"map": &"wharf", "spawn": &"carpenter_door"}


func _look() -> Dictionary:
	return {"wall": "bamboo", "floor": "dark", "windows": [5, 18] as Array[int]}


func _lines() -> Dictionary:
	return {
		&"oars": "靠墙的桨一根根立着，桨叶上还沾着河泥。",
		&"drawings": "墙上钉着两张图纸，墨线是一座还没接上的桥。",
		&"net": "旧渔网挂在墙上，补到一半，梭子还别在网眼里。",
		&"sign": "红纸上一个「木」，是门外幌子的底样。",
		&"lumber": "杉木、松木、楠木，各有各的纹路，摞得整整齐齐。",
		&"skiff": "一条小船才搭出骨架，舷板钉了两道。等河水涨了就能下水。",
		&"bench": "台上摆着刨子和一把拉锯，刨花卷还是新的。",
		&"horse": "锯马上架着一根没锯完的横梁，墨线弹得笔直。",
		&"planks": "一摞晾着的木板，板缝里垫着小木条。",
		&"shavings": "麻袋里装满了刨花，冬天拿来引火。",
		&"rope": "缆绳盘成一圈，是系船用的。",
	}


func _stock() -> void:
	_hang("oar_rack:2", 32, 31, &"oars", 1, 2)
	var sign := _sign()
	sign.position = Vector2(54, 5)
	sign.z_index = -9
	add_child(sign)
	_mark(Vector2i(3, 1), Vector2i(2, 1), &"sign")
	_hang("drawing_board", 8 * TS + 16, 31, &"drawings", 8, 2)
	_hang("drawing_board", 11 * TS + 16, 31, &"drawings", 11, 2)
	_hang("net_wall", 14 * TS + 24, 30, &"net", 14, 3)
	_put("lumber_rack", Vector2i(21, 2), Vector2i(2, 1), &"lumber")
	# 屋中间的小船
	_put("skiff_frame", Vector2i(2, 7), Vector2i(5, 2), &"skiff")
	# 右边：工作台、锯马、木料
	_put("workbench:3", Vector2i(15, 6), Vector2i(3, 1), &"bench")
	_put("saw_horse", Vector2i(19, 7), Vector2i(2, 1), &"horse")
	_put("plank_pile", Vector2i(19, 11), Vector2i(2, 1), &"planks")
	_put("rope_coil", Vector2i(15, 11), Vector2i(1, 1), &"rope")
	_put("bucket", Vector2i(17, 11))
	_put("jar_clay", Vector2i(2, 12))
	_put("plank_pile", Vector2i(7, 11), Vector2i(2, 1), &"planks")
	_put("sacks", Vector2i(9, 12), Vector2i(2, 1), &"shavings")
	_put("floor_lamp", Vector2i(22, 12))


## 红纸「木」：一竖穿过一横，撇和捺在底下分开。
func _sign() -> Sprite2D:
	var img := Px.new_img(20, 26)
	Px.rect(img, 0, 0, 20, 2, Color.html("6a4430"))
	Px.rect(img, 1, 2, 18, 22, Color.html("a83e36"))
	var gold := Color.html("f7dc80")
	Px.rect(img, 9, 4, 2, 17, gold)
	Px.rect(img, 4, 9, 12, 2, gold)
	Px.rect(img, 7, 12, 2, 2, gold)
	Px.rect(img, 6, 14, 2, 2, gold)
	Px.rect(img, 5, 16, 2, 2, gold)
	Px.rect(img, 4, 18, 2, 2, gold)
	Px.rect(img, 11, 12, 2, 2, gold)
	Px.rect(img, 12, 14, 2, 2, gold)
	Px.rect(img, 13, 16, 2, 2, gold)
	Px.rect(img, 14, 18, 2, 2, gold)
	var spr := Sprite2D.new()
	spr.texture = Px.tex(Px.outline(img))
	spr.centered = false
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return spr
