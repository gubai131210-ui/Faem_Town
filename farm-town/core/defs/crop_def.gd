class_name CropDef
extends RefCounted
## 一种作物的定义，来自 data/crops.json。

var id: StringName
var name: String
var seed: StringName
var produce: StringName
## 每个生长阶段需要的（浇过水的）天数；阶段数 = 数组长度 + 1，最后一个阶段是成熟
var stage_days: Array[int] = []
var seasons: Array[StringName] = []
## 大于 0 表示收获后不拔掉，过这么多天再熟一次
var regrow_days := 0
## 一次收获多得一个的概率
var extra_chance := 0.0
## 只在雾天生长（不看有没有浇水）
var needs_fog := false
## 耐寒：有霜的早上不会冻死
var hardy := false
## 只能种在水田里（其他作物不能种在水田里）
var paddy := false
## 不用浇水，每天都长，高温也不会蔫
var rainfed := false
## 只能在这些季节播种；空表示和 seasons 一样
var sow_seasons: Array[StringName] = []
## 要到这个节气才会成熟（冬小麦等到芒种）；空表示不限
var ripe_term: StringName = &""
## ripe_term 在一年里的序号，由 Database 填；-1 表示不限
var ripe_term_index := -1
## 成熟时长成巨型的概率
var giant_chance := 0.0
## 收获时额外得到的一件物品（莲藕带荷花）；空表示没有
var bonus_produce: StringName = &""
## 在这些节气收获时的品质加分：节气 id -> 分数
var term_bonus: Dictionary = {}
## 搭了架子，长出来以后人走不过去
var trellis := false
## 是否在种子目录里出售
var shop := true
## 画法参数，见 art_gen/crop_art.gd
var art: Dictionary = {}


static func from_dict(d: Dictionary) -> CropDef:
	var def := CropDef.new()
	def.id = StringName(str(d.get("id", "")))
	def.name = str(d.get("name", ""))
	def.seed = StringName(str(d.get("seed", "")))
	def.produce = StringName(str(d.get("produce", "")))
	var days: Array = d.get("stage_days", [])
	for v: Variant in days:
		def.stage_days.append(int(v))
	var ss: Array = d.get("seasons", [])
	for v: Variant in ss:
		def.seasons.append(StringName(str(v)))
	def.regrow_days = int(d.get("regrow_days", 0))
	def.extra_chance = float(d.get("extra_chance", 0.0))
	def.needs_fog = bool(d.get("needs_fog", false))
	def.shop = bool(d.get("shop", true))
	def.hardy = bool(d.get("hardy", false))
	def.paddy = bool(d.get("paddy", false))
	def.rainfed = bool(d.get("rainfed", false))
	var sow: Array = d.get("sow_seasons", [])
	for v: Variant in sow:
		def.sow_seasons.append(StringName(str(v)))
	def.ripe_term = StringName(str(d.get("ripe_term", "")))
	def.giant_chance = float(d.get("giant_chance", 0.0))
	def.bonus_produce = StringName(str(d.get("bonus_produce", "")))
	var tb: Variant = d.get("term_bonus", {})
	if tb is Dictionary:
		def.term_bonus = tb
	def.trellis = bool(d.get("trellis", false))
	var a: Variant = d.get("art", {})
	if a is Dictionary:
		def.art = a
	return def


func grows_in(season: StringName) -> bool:
	return seasons.has(season)


## 这个季节能不能播种。
func can_sow(season: StringName) -> bool:
	return seasons.has(season) if sow_seasons.is_empty() else sow_seasons.has(season)


## 到了一年里第 term_index 个节气时能不能成熟。只在 ripe_term 所在的季节、从那个节气起可以。
func can_ripen_at(term_index: int) -> bool:
	if ripe_term_index < 0 or term_index < 0:
		return true
	var per_season := 6
	var ti := posmod(term_index, per_season * 4)
	return ti >= ripe_term_index and ti < (ripe_term_index / per_season + 1) * per_season


## 在某个节气收获时的品质加分。
func bonus_in_term(term_id: StringName) -> int:
	return int(term_bonus.get(String(term_id), 0))


func total_days() -> int:
	var total := 0
	for n in stage_days:
		total += n
	return total


## 已生长 days 天时处于第几个阶段，0 是刚播种，stage_days.size() 是成熟。
func stage_for(days: int) -> int:
	var acc := 0
	for i in stage_days.size():
		acc += stage_days[i]
		if days < acc:
			return i
	return stage_days.size()


func is_ripe(days: int) -> bool:
	return days >= total_days()
