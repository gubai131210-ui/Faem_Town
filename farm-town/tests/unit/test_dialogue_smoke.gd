extends GutTest
## 确认 Dialogue Manager 插件能导入并读出对话。


func test_reads_first_line_of_dialogue_file() -> void:
	var res: Resource = load("res://tests/fixtures/smoke.dialogue")
	assert_not_null(res, "对话文件应该能被导入")
	if res == null:
		return
	var line: Variant = await DialogueManager.get_next_dialogue_line(res, "start")
	assert_not_null(line)
	if line == null:
		return
	assert_eq(str(line.character), "小满")
	assert_eq(str(line.text), "你就是新来的那个人吧？")
