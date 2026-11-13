class_name ShopEntry
extends RefCounted
## 目录里的一行：一种可以买的物品，或者一次工具升级。

## 要买的物品；升级时是被升级的工具
var item_id: StringName
## 为真表示这一行是工具升级，买了不进背包
var upgrade := false
## 只能买一件（工具），买完就从目录里消失
var once := false
## 不为空表示买的是一件送货上门的大件（加工设备）：不进背包，记一个 GameState 标记
var flag: StringName = &""
var name: String
var price := 0
## 除了钱还要的材料：[{"item": 物品 id, "count": 几个}]（石叔打饰品）
var materials: Array[Dictionary] = []
var desc: String
## 图标名，交给 UiKit.texture
var icon: String
