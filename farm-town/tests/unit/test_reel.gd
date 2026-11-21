extends GutTest
## 宣传片段的名单。不启动那段播放。


const Catalog := preload("res://tests/reel/catalog.gd")


func test_reel_names_each_stage() -> void:
	var ids: Array[String] = Catalog.ids()
	assert_eq(ids, ["field", "town", "fish", "cook", "fest", "mine", "fox", "pond"])
	assert_eq(Catalog.title("field"), "田里")
	assert_eq(Catalog.title("town"), "镇上")
	assert_eq(Catalog.title("fish"), "池塘")
	assert_eq(Catalog.title("cook"), "灶上")
	assert_eq(Catalog.title("fest"), "播种节")
	assert_eq(Catalog.title("mine"), "下井")
	assert_eq(Catalog.title("fox"), "竹海")
	assert_eq(Catalog.title("pond"), "文鳐")
	assert_true(Catalog.known("all"), "按顺序演用 all")
	assert_false(Catalog.known(""))
	assert_false(Catalog.known("nope"))
	var menu := Catalog.menu_text()
	for id in ids:
		assert_true(menu.contains(Catalog.title(id)), menu)
	assert_true(menu.contains("按顺序演"))
	assert_false(menu.contains("9  田里"))


func test_trailer_has_a_caption_and_a_tail_for_every_clip() -> void:
	assert_true(Catalog.known("trailer"), "整片用 trailer")
	var ids: Array[String] = Catalog.trailer_ids()
	assert_eq(ids[0], "title", "片头在最前")
	assert_eq(ids[ids.size() - 1], "end", "片尾在最后")
	for part in Catalog.ids():
		assert_true(ids.has(part), "整片里有 " + part)
	for id in ids:
		assert_true(Catalog.known(id), id)
		assert_ne(Catalog.caption_title(id), "", "有大字：" + id)
		assert_gt(Catalog.tail(id), 0.0, "有停顿：" + id)
	assert_eq(Catalog.caption_sub("end"), "", "片尾只有一行")
	assert_eq(Catalog.caption_title("nope"), "")


func test_full_cut_covers_every_clip_with_caption_and_tail() -> void:
	assert_true(Catalog.known("full"), "完整版用 full")
	var ids: Array[String] = Catalog.full_ids()
	assert_eq(ids[0], "title")
	assert_eq(ids[ids.size() - 1], "end")
	for part in Catalog.ids():
		assert_true(ids.has(part) or part == "fest", "完整版里有 " + part)
	for id in ids:
		assert_true(Catalog.known(id), id)
		assert_ne(Catalog.caption_title(id), "", "有大字：" + id)
		assert_gt(Catalog.tail(id), 0.0, "有停顿：" + id)
	assert_true(Catalog.is_card("card_end"))
	assert_false(Catalog.is_card("field"))
	assert_true(Catalog.is_top("letter"), "过场的字幕压在上面")
	assert_false(Catalog.is_top("field"))
