class_name Ledger
extends RefCounted
## 一年六种过法各挣多少、体力花在哪。不是 autoload，不进存档。
## 用表里的物价、耕地、鱼和矿层自己的规则来算。工具不升级，行当的省力不算。
## 种田的人在池塘边挖两条水渠；钓鱼的人在池塘、小溪和河里钓；
## 养殖的人盖鸡舍和畜棚；下井的人走到最深。做菜拿去卖，不比把材料卖掉多。


const YEAR_DAYS := 96
const ENERGY := 100
## 和 game.gd 里的消耗一致：锄 2、浇 1、挖 2、甩竿 1、敲矿 2。升过级的镐子这里不算。
const HOE_COST := 2
const WATER_COST := 1
const DIG_COST := 2
const CAST_COST := 1
const MINE_COST := 2
## 收线、起竿以外，咬钩和挣扎按鱼自己的数字。
const CAST_EXTRA := 1.2
const CANAL_A := Vector2i(2, 2)
const CANAL_B := Vector2i(10, 2)
const QUALITY_MULT := 1.15


static func lines() -> PackedStringArray:
	var report := run()
	var out := PackedStringArray()
	for id: StringName in report:
		var row: Dictionary = report[id]
		out.append("%s：每天 %d 文（一年卖 %d，花 %d）。%s" % [
			row["name"], row["per_day"], row["sales"], row["cost"], row["energy_text"]])
	return out


## 六行的结果。键是 farm、fish、herd、mine、cook、mixed。
static func run() -> Dictionary:
	var saved_day := GameClock.day
	var saved_minutes := GameClock.minutes
	var weathers := _weathers()
	var report := {
		&"farm": _farm(weathers, [CANAL_A, CANAL_B]),
		&"fish": _fish(weathers, ENERGY, _day_seconds()),
		&"herd": _herd(weathers, 4, 4),
		&"mine": _mine(),
		&"cook": _cook(),
		&"mixed": _mixed(weathers),
	}
	GameClock.day = saved_day
	GameClock.minutes = saved_minutes
	return report


## 这道菜的材料按卖价加起来是多少。
static func ingredient_sum(rec: RecipeDef) -> int:
	var total := 0
	for item_id: StringName in rec.ingredients:
		total += Database.item(item_id).price * int(rec.ingredients[item_id])
	return total


static func _day_seconds() -> float:
	return (GameClock.DAY_END - GameClock.DAY_START) / GameClock.MINUTES_PER_SECOND


static func _weathers() -> Array[StringName]:
	var rng := RandomNumberGenerator.new()
	rng.seed = 13402
	var out: Array[StringName] = []
	for day in YEAR_DAYS:
		out.append(Weather.pick(Weather.weights_for(day + 1), rng.randf()))
	return out


static func _row(name: String, sales: int, cost: int, energy_text: String) -> Dictionary:
	var net := sales - cost
	return {
		"name": name,
		"sales": sales,
		"cost": cost,
		"net": net,
		"per_day": net / YEAR_DAYS,
		"energy_text": energy_text,
	}


static func _ring(origin: Vector2i) -> Array[Vector2i]:
	var plots: Array[Vector2i] = []
	for y in range(-FarmState.CANAL_REACH, FarmState.CANAL_REACH + 1):
		for x in range(-FarmState.CANAL_REACH, FarmState.CANAL_REACH + 1):
			var t := origin + Vector2i(x, y)
			if t != origin:
				plots.append(t)
	return plots


static func _crop_score(def: CropDef) -> int:
	var grow := def.total_days()
	var left := GameClock.DAYS_PER_SEASON
	var harvests := 0
	if def.regrow_days > 0:
		if left >= grow:
			harvests = 1 + (left - grow) / def.regrow_days
	else:
		harvests = left / grow
	if harvests <= 0:
		return -1
	var produce := Database.item(def.produce).price
	var each := int(round(float(produce) * (1.0 + def.extra_chance) * QUALITY_MULT))
	var bonus := 0
	if def.bonus_produce != &"" and Database.has_item(def.bonus_produce):
		bonus = Database.item(def.bonus_produce).price
	var seed := Database.item(def.seed).price
	var cost := seed if def.regrow_days > 0 else seed * harvests
	return harvests * (each + bonus) - cost


static func _best_crop(season: StringName) -> StringName:
	var best := &""
	var best_score := -1
	for id: StringName in Database.crops:
		var def := Database.crop(id)
		if not def.shop or def.needs_fog or not def.can_sow(season):
			continue
		var score := _crop_score(def)
		if score > best_score:
			best_score = score
			best = def.id
	return best


static func _farm(weathers: Array[StringName], origins: Array[Vector2i]) -> Dictionary:
	var state := FarmState.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 13401
	var sales := 0
	var cost := Database.item(&"shovel").price
	var hoe := 0
	var water := 0
	var dig := 0
	var energy := ENERGY
	for origin: Vector2i in origins:
		if energy < DIG_COST:
			break
		energy -= DIG_COST
		dig += DIG_COST
		state.dig_canal(origin, true)
	var plots: Array[Vector2i] = []
	for origin: Vector2i in origins:
		for t: Vector2i in _ring(origin):
			if state.is_canal(t) or not state.is_irrigated(t):
				continue
			plots.append(t)
			if energy < HOE_COST:
				continue
			energy -= HOE_COST
			hoe += HOE_COST
			state.till(t)
	for day in YEAR_DAYS:
		GameClock.day = day + 1
		if day > 0:
			var past := Database.term(GameClock.term_index_of(day))
			var heat := past != null and past.id == &"xiaoshu"
			var today_w: StringName = weathers[day]
			var yest_w: StringName = weathers[day - 1]
			var wet := today_w == Weather.RAIN or today_w == Weather.STORM or GameClock.term_id() == &"bailu"
			var frost := today_w == Weather.FROST
			state.advance_day(GameClock.season_id(), yest_w, wet, heat, frost, GameClock.term_index(), rng)
			energy = ENERGY
		var choice := _best_crop(GameClock.season_id())
		for t: Vector2i in plots:
			if not state.is_tilled(t):
				continue
			if state.is_ripe(t):
				var grown := Database.crop(state.crop_id_at(t))
				var count := state.yield_at(t, rng.randf())
				var quality := state.harvest_quality(t, rng.randf(), grown.bonus_in_term(GameClock.term_id()))
				var produce := state.harvest(t)
				if produce != &"":
					sales += Database.item(produce).price_for(quality) * count
					if grown.bonus_produce != &"" and Database.has_item(grown.bonus_produce):
						var extra := Database.item(grown.bonus_produce)
						if extra.sellable():
							sales += extra.price
			elif state.is_dead(t):
				state.clear_dead(t)
			if state.has_crop(t) and not state.is_wet(t) and energy >= WATER_COST:
				var crop := Database.crop(state.crop_id_at(t))
				if not crop.rainfed and not crop.needs_fog:
					energy -= WATER_COST
					water += WATER_COST
					state.water(t)
			if choice == &"" or state.has_crop(t):
				continue
			var chosen := Database.crop(choice)
			if state.is_paddy(t) != chosen.paddy:
				state.set_paddy(t, chosen.paddy)
			if state.can_plant_crop(t, chosen.id) and state.plant(t, chosen.id):
				cost += Database.item(chosen.seed).price
	return _row("种田", sales, cost, "地 %d，挖 %d，锄 %d，浇 %d" % [plots.size(), dig, hoe, water])


static func _fish_pool(season: StringName, weather: StringName, term: StringName) -> Array[FishDef]:
	var out: Array[FishDef] = []
	for id: StringName in Database.fish:
		var fish := Database.fish[id]
		if fish.trap:
			continue
		var in_water := false
		for water: StringName in [&"pond", &"stream", &"river"]:
			if fish.bites(water, season, false, weather, term) or fish.bites(water, season, true, weather, term):
				in_water = true
				break
		if in_water:
			out.append(fish)
	return out


static func _pick_fish(pool: Array[FishDef], roll: float) -> FishDef:
	var total := 0
	for fish: FishDef in pool:
		total += fish.weight
	var at := roll * float(total)
	for fish: FishDef in pool:
		at -= float(fish.weight)
		if at < 0.0:
			return fish
	return pool[pool.size() - 1]


static func _fish_seconds(fish: FishDef) -> float:
	return Fishing.bite_wait(0, 0.5) + fish.fights * fish.fight_len + CAST_EXTRA


static func _fish(weathers: Array[StringName], energy_cap: int, seconds_cap: float) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 13403
	var sales := 0
	var casts := 0
	for day in YEAR_DAYS:
		GameClock.day = day + 1
		var pool := _fish_pool(GameClock.season_id(), weathers[day], GameClock.term_id())
		if pool.is_empty():
			continue
		var energy := energy_cap
		var seconds := seconds_cap
		while energy >= CAST_COST and seconds > 0.0:
			var fish := _pick_fish(pool, rng.randf())
			var take := _fish_seconds(fish)
			if take > seconds:
				break
			seconds -= take
			energy -= CAST_COST
			casts += CAST_COST
			sales += fish.price
	return _row("钓鱼", sales, 0, "甩竿 %d" % casts)


static func _herd(weathers: Array[StringName], ducks: int, goats: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 13404
	var sales := 0
	var cost := 0
	var coop_left := 0
	var barn_left := 0
	var duck_mood: Array[int] = []
	var duck_days: Array[int] = []
	var goat_mood: Array[int] = []
	var goat_days: Array[int] = []
	var duck_def := Database.animal(&"duck")
	var goat_def := Database.animal(&"goat")
	if ducks > 0:
		cost += Database.building(&"coop").price
		coop_left = Database.building(&"coop").days
	if goats > 0:
		cost += Database.building(&"barn").price
		barn_left = Database.building(&"barn").days
	for day in YEAR_DAYS:
		GameClock.day = day + 1
		if day > 0:
			if coop_left > 0:
				coop_left -= 1
			if barn_left > 0:
				barn_left -= 1
		if ducks > 0 and coop_left == 0 and duck_mood.is_empty():
			while duck_mood.size() < ducks:
				cost += duck_def.price
				duck_mood.append(Animals.START_MOOD)
				duck_days.append(0)
		if goats > 0 and barn_left == 0 and goat_mood.is_empty():
			while goat_mood.size() < goats:
				cost += goat_def.price
				goat_mood.append(Animals.START_MOOD)
				goat_days.append(0)
		var rainy: bool = weathers[day] == Weather.RAIN or weathers[day] == Weather.STORM
		var shade: bool = GameClock.term_id() == &"xiaoshu" or GameClock.term_id() == &"dashu"
		var hay: bool = GameClock.term_id() == &"lidong"
		sales += _tend(duck_def, duck_mood, duck_days, rainy, shade, rng)
		sales += _tend(goat_def, goat_mood, goat_days, rainy, shade, rng)
		cost += _feed_cost(duck_def, duck_mood.size(), hay) + _feed_cost(goat_def, goat_mood.size(), hay)
	return _row("养殖", sales, cost, "喂和摸不花体力")


static func _feed_cost(def: AnimalDef, count: int, hay: bool) -> int:
	if count <= 0 or def.feed == &"":
		return 0
	var ration: StringName = &"hay" if hay and def.outdoor and def.feed == &"feed" else def.feed
	return Database.item(ration).price * count


static func _tend(def: AnimalDef, mood: Array[int], days: Array[int], rainy: bool, shade: bool, rng: RandomNumberGenerator) -> int:
	var sales := 0
	for i in mood.size():
		mood[i] = mini(Animals.MAX_MOOD, mood[i] + Animals.PET_MOOD)
		if mood[i] >= Animals.SULK_MOOD:
			days[i] += 1
			if days[i] >= def.every:
				days[i] = 0
				var item := def.produce
				if item != &"":
					var quality := Animals.quality_for(mood[i], rng.randf())
					sales += Database.item(item).price_for(quality)
				if def.extra != &"" and rng.randf() < def.extra_chance:
					sales += Database.item(def.extra).price
		if def.feed != &"":
			mood[i] += Animals.FED_MOOD
		if rainy and def.outdoor:
			mood[i] += def.rain_mood
		if def.outdoor and shade:
			mood[i] += Animals.SHADE_MOOD
		mood[i] = clampi(mood[i], 0, Animals.MAX_MOOD)
	return sales


static func _mine() -> Dictionary:
	var sales := 0
	var hits := 0
	var floor_no := 1
	for day in YEAR_DAYS:
		var energy := ENERGY
		var guard := 0
		while energy >= MINE_COST and guard < Mine.OPEN_FLOORS:
			guard += 1
			if floor_no > Mine.OPEN_FLOORS:
				floor_no = Mine.OPEN_FLOORS - 1
			if Mine.has_boss_room(floor_no):
				floor_no += 1
				continue
			var layer := Database.mine_layer(floor_no)
			if layer == null:
				break
			var floor := MineFloor.generate(floor_no, layer, 13400 + day * 80 + floor_no * 3 + guard, true, false)
			var tiles: Array[Vector2i] = []
			for t: Vector2i in floor.rocks:
				tiles.append(t)
			for t: Vector2i in tiles:
				if not floor.has_rock(t) or floor.rocks[t] == &"stone":
					continue
				while floor.has_rock(t) and energy >= MINE_COST:
					energy -= MINE_COST
					hits += MINE_COST
					var res: Dictionary = floor.hit(t, 1, MineFloor.DOUBLE_CHANCE)
					if bool(res.get("broken", false)):
						var item := StringName(res["item"])
						sales += Database.item(item).price * int(res["count"])
			if energy < MINE_COST:
				break
			# 还没到最深就往下；到了最深的非首领层就再下一趟同一层。
			if floor_no < Mine.OPEN_FLOORS - 1:
				floor_no += 1
	return _row("下井", sales, 0, "敲矿 %d" % hits)


static func _cook() -> Dictionary:
	var best := 0
	var best_seconds := 4.0
	for id: StringName in Database.recipes:
		var rec: RecipeDef = Database.recipes[id]
		if rec.from == &"odd":
			continue
		var profit := Database.item(rec.id).price - ingredient_sum(rec)
		if profit <= best:
			continue
		best = profit
		var heat := float(Crafting.COOK_SHORT) * 1.25
		best_seconds = CookHeat.DROP_EACH * float(rec.ingredients.size()) + heat + CookHeat.SERVE_SECONDS
	var sales := 0
	if best > 0 and best_seconds > 0.0:
		var dishes := int(_day_seconds() / best_seconds)
		sales = best * dishes * YEAR_DAYS
	return _row("做菜", sales, 0, "做菜不花体力")


static func _mixed(weathers: Array[StringName]) -> Dictionary:
	var farm: Dictionary = _farm(weathers, [CANAL_A])
	var fish: Dictionary = _fish(weathers, ENERGY / 2, _day_seconds() * 0.5)
	var herd: Dictionary = _herd(weathers, 2, 0)
	return _row("混着", int(farm["sales"]) + int(fish["sales"]) + int(herd["sales"]),
		int(farm["cost"]) + int(fish["cost"]) + int(herd["cost"]),
		"种田（%s）；钓鱼（%s）" % [farm["energy_text"], fish["energy_text"]])
