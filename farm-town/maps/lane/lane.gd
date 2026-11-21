extends WildMap
## 矿工巷：井口西边的一排空屋。门上的字被磨平了，屋里这轮不进（决策 114）。

## 老矿工巷是左上角 26×14；往东、往南扩到 50×34，老坐标一格不动（决策 160）。
const OLD_W := 26
const OLD_H := 14
const W := 50
const H := 34
const NEW_TREES: Array[String] = ["round0", "pine0", "round1", "old0", "round2"]
## 往南的石板路两列；南街两行
const SOUTH_COLS: Array[int] = [40, 41]
const SOUTH_ROWS: Array[int] = [22, 23]
## 新增的空屋：最西一列。东街的在街北，南街的在街北（门脸那一行比街少一行）
const EAST_HOUSES: Array[int] = [30, 34, 38, 44]
const SOUTH_HOUSES: Array[int] = [4, 9, 14, 19, 26, 31, 36]
const EAST_ROWS: Array[int] = [8, 9]
## [最西一列, 门脸那一行, 宽, 深, 说明]
const HOUSES: Array = [
	[2, 7, 3, 3, "门牌是一块光木板，字被磨平了。"],
	[6, 7, 3, 3, "门洞是空的。里面没有灯。"],
	[10, 7, 3, 3, "门槛上有干泥，很久没人踩过。"],
	[14, 7, 3, 3, "门侧的木牌只剩四边，中间是平的。"],
]

## 决策 119：能翻能看的东西。井口碑立在巷子南边空地，旧告示钉在第一间屋的侧墙。
## 文字里不写那二十七个名字——水把它们冲平了，只剩碑上一个「秦」。
const STELE_TILE := Vector2i(12, 10)
const NOTICE_TILE := Vector2i(5, 6)
const CLUES: Dictionary = {
	Vector2i(12, 10): "井口的碑。水泡了三十年，二十七个名字只剩一个还清清楚楚：秦。旁的都糊成一片，摸上去是平的。",
	Vector2i(5, 6): "墙上的旧告示。纸黄得发脆，写着下井的规矩和几条数目。落款那一行让人用水抹过，一个名字也认不出。",
	Vector2i(3, 6): "第一间屋。门牌光着。从半掩的门望进去，桌上一只碗、一盏没油的灯，床铺叠得整齐，像人只是出门没回。",
	Vector2i(7, 6): "第二间屋。门洞空着，里头黑。门槛内侧一口木箱，箱盖翘着，里头是空的。",
	Vector2i(11, 6): "第三间屋。干泥的门槛。窗台上摆着一只缺口的茶杯，杯底沉着一点水，早干了。",
	Vector2i(15, 6): "第四间屋。木牌只剩四边。窗纸破了个洞，随风一鼓一瘪，屋里有什么轻轻碰了一下。",
}
## 每处线索看过以后记下的标记，手账与重复翻看都用得上。
const CLUE_FLAGS: Dictionary = {
	Vector2i(12, 10): &"read_miner_stele",
	Vector2i(5, 6): &"read_miner_notice",
	Vector2i(3, 6): &"read_miner_house_0",
	Vector2i(7, 6): &"read_miner_house_1",
	Vector2i(11, 6): &"read_miner_house_2",
	Vector2i(15, 6): &"read_miner_house_3",
}


func _ready() -> void:
	map_id = &"lane"
	_rng.seed = 20261117
	_scatter_cols = OLD_W
	_scatter_rows = OLD_H
	_setup_wild(W, H)
	_layout()
	_layout_new()
	_build_ground()
	_make_entities()
	_place_objects()
	_place_new()


func spawn_position(spawn: StringName) -> Vector2:
	if spawn == &"from_wellhead":
		return tile_center(Vector2i(W - 2, EAST_ROWS[0]))
	return tile_center(Vector2i(W - 2, EAST_ROWS[0]))


func spawn_facing(_spawn: StringName) -> Facing:
	return Facing.LEFT


func trigger_at(tile: Vector2i) -> Dictionary:
	if tile.x == W - 1 and EAST_ROWS.has(tile.y):
		return {"map": &"wellhead", "spawn": &"from_lane"}
	return {}


func query_use(_item: ItemDef, tile: Vector2i, _facing: Facing) -> StringName:
	if clue_at(tile) != "":
		return &"interact"
	return &""


func perform(action: StringName, _item: ItemDef, tile: Vector2i, _quiet: bool = false) -> void:
	if action != &"interact":
		return
	var text: String = clue_at(tile)
	if text == "":
		return
	var flag: StringName = CLUE_FLAGS.get(tile, &"")
	if flag != &"":
		GameState.set_flag(flag)
	EventBus.banner_requested.emit(text)


## 决策 119：一处可调查物对应的一句话。游戏交互与测试读同一份，不另写示意文本。
func clue_at(tile: Vector2i) -> String:
	if clues.has(tile):
		return clues[tile]
	var text := str(CLUES.get(tile, ""))
	if tile == STELE_TILE and PeopleLine.mark(&"luyuan") != "":
		return text + PeopleLine.mark(&"luyuan")
	return text


func _layout() -> void:
	_fill(0, 6, OLD_W - 1, OLD_H - 1, DIRT)
	_fill(1, EAST_ROWS[0], OLD_W - 2, EAST_ROWS[1], PAVE)


func _place_objects() -> void:
	for house: Array in HOUSES:
		var x0: int = house[0]
		var front: int = house[1]
		var wide: int = house[2]
		var deep: int = house[3]
		var pos := Vector2((x0 + wide / 2.0) * TS, front * TS)
		_prop("miner_house", pos)
		_ground_shadow(pos + Vector2(0, -1), Px.tex(PixelArt.shadow(wide * TS - 6, 8, 0.22)))
		_block_rect(x0, front - deep, x0 + wide - 1, front - 1)

	# 决策 119：巷口的井口碑与第一间屋侧墙的旧告示。碑底边压在格子中心，告示贴墙略高一点。
	var stele_img := LaneClueArt.stele()
	var stele_pos := tile_center(STELE_TILE)
	_sprite(Px.tex(stele_img), stele_pos, Vector2(-stele_img.get_width() / 2.0, -float(stele_img.get_height())))
	_ground_shadow(stele_pos + Vector2(0, -1), Px.tex(PixelArt.shadow(16, 5, 0.22)))
	_block(STELE_TILE)
	if PeopleLine.mark(&"luyuan") != "":
		var cloth := Px.new_img(6, 10)
		Px.rect(cloth, 0, 0, 6, 10, Color.html("f4efe4"))
		Px.rect(cloth, 2, 0, 2, 10, Color.html("d8d0c4"))
		var knot := Sprite2D.new()
		knot.name = "SteleCloth"
		knot.texture = Px.tex(cloth)
		knot.centered = false
		knot.position = stele_pos + Vector2(stele_img.get_width() / 2.0, -float(stele_img.get_height()) + 6.0)
		add_child(knot)

	var notice_img := LaneClueArt.wall_notice()
	var notice_pos := tile_center(NOTICE_TILE)
	_sprite(Px.tex(notice_img), notice_pos, Vector2(-notice_img.get_width() / 2.0, -float(notice_img.get_height()) + 5.0))
	_block(NOTICE_TILE)

	_reserve(0, 4, W - 1, EAST_ROWS[1] + 1)
	_scatter_trees(4)
	_scatter_bushes(3)
	_scatter_tufts(40)
	_release_ghosts()


# ---------------------------------------------------------------- 往东、往南扩出来的部分

func _ghost_tree(t: Vector2i) -> bool:
	return _legacy_edge(t, OLD_W, OLD_H)


const EAST_LINES: Array[String] = [
	"门牌被砸过，又被人用布条仔细缠上了。",
	"窗台上的花盆里长出一棵野草，已经比窗子高。",
	"门前的石阶中间磨出一道浅沟，是常年同一个人踩的。",
	"门口挂着一副旧手套，指尖都磨破了，破处补过线。",
]
const SOUTH_LINES: Array[String] = [
	"这间的灶膛里有一点灰，一碰就散。",
	"门框上刻着一排高低不一的线，最高的一道旁边画着一顶矿帽。",
	"屋里有一张折叠整齐的工服，领口的编号被洗掉了。",
	"门楣下吊着一只风铃，是用螺丝和铁片做的，风一过就响。",
	"门前的水缸盖着盖子，盖子上放着一只小碗，碗是干的。",
	"窗纸新糊过，糊得很仔细，糊的人没留名。",
	"门没关严。里面一张桌子，桌上一只碗，碗里扣着一盏灯。",
]


func _layout_new() -> void:
	_fill(OLD_W - 1, EAST_ROWS[0], W - 1, EAST_ROWS[1], PAVE)
	_fill(SOUTH_COLS[0], EAST_ROWS[1] + 1, SOUTH_COLS[1], H - 2, PAVE)
	_fill(2, SOUTH_ROWS[0], W - 2, SOUTH_ROWS[1], PAVE)
	_fill(OLD_W, 6, W - 1, 7, DIRT)
	_fill(0, OLD_H, W - 1, 21, DIRT)


func _place_new() -> void:
	_new_edge_trees(OLD_W, OLD_H, NEW_TREES)
	for i in EAST_HOUSES.size():
		_building("miner_house", EAST_HOUSES[i], 7, 3, 3, false)
		_wall_clue(EAST_HOUSES[i], 7, 3, EAST_LINES[i])
	for i in SOUTH_HOUSES.size():
		_building("miner_house", SOUTH_HOUSES[i], 21, 3, 3, false)
		_wall_clue(SOUTH_HOUSES[i], 21, 3, SOUTH_LINES[i])
	_building("well", 22, 28, 2, 2, false)
	_wall_clue(22, 28, 2, "巷子里的公用井。井沿上有一圈小小的凹痕，是水桶放了几十年放出来的")
	_wide_prop("bench", Vector2i(14, 26), 2, "石凳。坐在这里，能同时看到四扇关着的门")
	_wide_prop("wood_pile", Vector2i(30, 26), 2, "劈好的柴，码得很整齐，像有人每天来添")
	_small_prop("jar_clay", Vector2i(18, 26), "空的咸菜坛，坛口干干净净")
	_small_prop("jar_clay", Vector2i(34, 26), "")
	for t: Vector2i in [Vector2i(7, 24), Vector2i(17, 24), Vector2i(29, 24), Vector2i(39, 24), Vector2i(33, 10), Vector2i(43, 10), Vector2i(39, 15)]:
		if _is_free(t) or terrain[idx(t)] == PAVE:
			_lamp_post(t)
	_grove(Rect2i(OLD_W, 0, W - OLD_W, 4), 20, NEW_TREES)
	_grove(Rect2i(0, OLD_H, W, 5), 14, NEW_TREES)
	_grove(Rect2i(0, 28, W, H - 28), 22, NEW_TREES)
	_sprinkle_grass(Rect2i(OLD_W, 0, W - OLD_W, OLD_H), 111)
	_sprinkle_grass(Rect2i(0, OLD_H, W, H - OLD_H), 112)
