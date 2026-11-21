extends GutTest
## M16 第三批：一年六种过法的账（决策 135）。
## 没有一种过法的每天净收入高出另外几种一大截；最挣钱的不是最闷的种田或下井；
## 菜拿去卖不超过材料卖价。说不上来的那碗仍是亏的。


const LIVES: Array[StringName] = [&"farm", &"fish", &"herd", &"mine", &"mixed"]


func before_each() -> void:
	SaveSystem.reset_all()
	GameClock.running = false
	GameClock.minutes = 600.0
	GameClock.day = 1


func after_each() -> void:
	GameClock.running = false
	SaveSystem.reset_all()


func test_dishes_do_not_sell_above_their_ingredients() -> void:
	assert_eq(Database.item(&"odd_bowl").price, 8, "说不上来的那碗仍是亏本的试验")
	assert_eq(Database.item(&"straw").price, 0, "稻草不卖钱")
	for id: StringName in Database.recipes:
		var rec: RecipeDef = Database.recipes[id]
		if rec.from == &"odd":
			continue
		var total := Ledger.ingredient_sum(rec)
		assert_gt(total, 0, "%s 的材料卖价加起来不该是 0" % id)
		assert_lte(Database.item(rec.id).price, total, "%s 卖 %d，材料 %d" % [id, Database.item(rec.id).price, total])


func test_a_year_of_six_lives_stays_in_range() -> void:
	var report := Ledger.run()
	var text := _text(report)
	print(text)
	for id: StringName in LIVES:
		assert_gt(int(report[id]["per_day"]), 0, text)
	assert_lte(int(report[&"cook"]["net"]), 0, text)
	var per: Array[int] = []
	for id: StringName in LIVES:
		per.append(int(report[id]["per_day"]))
	per.sort()
	var median: int = per[2]
	var top: int = per[per.size() - 1]
	assert_lte(top, median * 2, "每天净收入差了一大截\n%s" % text)
	assert_lte(top, per[0] * 2, "最低的过法被拉开了\n%s" % text)
	var best := &"farm"
	var best_n := -1
	for id: StringName in LIVES:
		var n := int(report[id]["per_day"])
		if n > best_n:
			best_n = n
			best = id
	if best == &"farm" or best == &"mine":
		assert_gte(int(report[&"fish"]["per_day"]) * 5, best_n * 4, "最挣钱的是最闷的\n%s" % text)
	assert_true(String(report[&"farm"]["energy_text"]).begins_with("地 48"), text)


func _text(report: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for id: StringName in [&"farm", &"fish", &"herd", &"mine", &"cook", &"mixed"]:
		var row: Dictionary = report[id]
		lines.append("%s：每天 %d 文（一年卖 %d，花 %d）。%s" % [
			row["name"], row["per_day"], row["sales"], row["cost"], row["energy_text"]])
	return "\n".join(lines)
