class_name RanchLink
extends RefCounted
## 养殖和种田之间的那点联系：蜂场附近开着什么花。养殖不认识种田，所以放在 game/ 里接。

## 离蜂场几格以内的花算数
const RANGE := 6
const APIARY := &"apiary"


## 蜂场附近长得最多的那种花（作物 id）；没有花、没有蜂场返回空。还没出苗的不算。
static func nectar() -> StringName:
	if not Database.has_building(APIARY):
		return &""
	var site := Database.building(APIARY).site
	var farm := Farming.state
	var counts: Dictionary[StringName, int] = {}
	for t: Vector2i in farm.crops:
		if maxi(absi(t.x - site.x), absi(t.y - site.y)) > RANGE or farm.is_dead(t) or farm.crop_stage_at(t) < 1:
			continue
		var id := farm.crop_id_at(t)
		if Database.has_crop(id) and Database.item(Database.crop(id).produce).flower != &"":
			counts[id] = int(counts.get(id, 0)) + 1
	var best: StringName = &""
	var most := 0
	for id: StringName in counts:
		if counts[id] > most:
			most = counts[id]
			best = id
	return best
