# 一口小灶

独立的 Godot 4.7 试玩原型。用四档火力做一锅番茄炒蛋，分别练习「嫩蛋多汁」和「焦香收汁」。料理评语会指出最值得重试的步骤。

## 试玩

打开 `build/一口小灶.exe`，或者用 Godot 4.7 导入本目录的 `project.godot` 后运行。每次打开都是空锅，最佳分保留到关闭程序。

- 在砧板按住左键横划四刀，在碗里画圈五次。也可以点右侧按钮或按空格。
- 拖蛋液和番茄入锅，或按 Q 和 W。两份食材可以依次下锅。按 1 到 4 调火，按 S 撒盐。
- 在锅里扫动、单击锅内或按空格翻锅。观察蛋液、番茄汁、上色和焦底，再决定是否降火。
- 两样都进锅后回车装盘。看完评语，再按一次回车重开。

嫩口可先用中火预热，蛋液先下，约两秒后再加番茄，撒一次盐，勤翻至蛋凝、番茄出汁。收汁口可先大火预热，蛋液略凝后下番茄并转中火，待汁收浓、边缘变金时关火，利用一点余温出锅。锅温读数会比火档晚变。

## Blender 来源

`tools/kitchen.blend` 是可编辑的灶间模型。用 `tools/render_kitchen.py` 在 Blender 内重建场景和八张食材、器皿及工具贴图。Godot 把贴图和实时火苗、蒸汽、料汁、翻锅位移合成，切配、翻锅和出锅的声音由脚本合成。

```powershell
& 'D:/Blender 5.3/blender.exe' --background --factory-startup --python tools/render_kitchen.py -- blend
```

## 验证

```powershell
$godot = 'E:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe'
& $godot --headless --path . --import
& $godot --headless --fixed-fps 60 --path . --script res://tests/check.gd
& $godot --path . --script res://tests/check.gd -- --shots
```

规则检查覆盖两种口味的高分做法、过早出锅、余热、过咸、焦底，以及暂停拖动后恢复。输入流程用鼠标和键盘事件模拟从切配到装盘；固定推进锅温用于复现同一火候。带窗口的流程截图写入 `_preview/`。

## 交互参考

- 借鉴可操作食材与物理反馈的方向，把它收敛成锅温、余热和局部焦底的规则。[Cooking Simulator](https://store.steampowered.com/app/641320/Cooking_Simulator/)
- 借鉴工序清晰和备料、烹调、上桌各有操作的节奏。[Overcooked](https://www.team17.com/games/overcooked)
- 借鉴鼠标直接摆弄食材和练习同一菜品的方式。[Papa’s Pancakeria](https://www.flipline.com/games/papaspancakeria/index.html)
