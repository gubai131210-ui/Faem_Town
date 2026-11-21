# 雾隐青岚（Farm_Town）

类星露谷的农场生活模拟游戏，Godot 4.7 + GDScript。所有美术和音频都由代码或脚本生成（Blender、语音合成），不使用外部素材。用户用中文交流，文档和代码注释用中文。

## 开工前先读

1. `docs/进度.md`：现在做到哪、下一步做什么。
2. `docs/架构.md`：代码怎么组织。新功能必须符合；要偏离先在决策记录里写原因。
3. `docs/设计文档.md`：玩法、剧情、内容清单。只读和当前任务相关的章节。
4. `docs/决策记录.md`：已经定下的事，不要重新讨论或悄悄推翻。
5. `docs/后续计划.md`：M7 之后要做什么、按什么顺序。只读和当前任务相关的章节。做茶岭、藕花荡、古木林时读 `docs/新地图.md`。
6. `docs/开发流程.md`：每一轮的顺序。改代码之前读完，报告完成之前再对一遍收尾。

## 目录

- `farm-town/`：Godot 项目根目录（`project.godot` 在这里）。
- `docs/`：文档。
- `farm-town/tools/`：Blender 脚本和预览导出脚本。
- `farm-town/_preview/`：自动截图和素材预览，不入库。

## 环境

- Godot：`E:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`（命令行用 console 版）
- Blender：`D:\Blender 5.3\blender.exe`
- 终端是 PowerShell。

## 命令

在 `farm-town/` 下执行，`$g` 是上面的 Godot 路径：

```powershell
& $g --headless --path . --import # 导入资源；新环境跑两次
& $g --headless --path . -s addons/gut/gut_cmdln.gd -gexit # 单元测试
& $g --headless --path . res://tests/flow/flow.tscn # 自动跑流程，只跑检查不截图，不弹窗口，约 4 分钟；输出里找 FLOW PASS / CHECK FAILED
& $g --path . res://tests/flow/flow.tscn # 自动跑流程并截图到 _preview/；会弹出游戏窗口约 4 分钟，跑完自己关
& $g --headless --path . -s tools/dump_art.gd # 把代码画的素材导出成预览图，不开窗口
& $g --path . -s tools/dump_map.gd -- chaling town season=2 # 把整张地图导出到 _preview/maps/；弹窗口几秒；season 0 春到 3 冬
& "D:\Blender 5.3\blender.exe" --background --python tools\character.py -- farmer # 重新生成角色；居民把 farmer 换成 tools/characters/ 下的名字
D:\Miniconda3\python.exe tools\portraits.py ahe # 重画这位居民的头像（三个表情）；不写名字就全部重画
D:\Miniconda3\python.exe tools\preview_characters.py ahe shishu # 把几位居民的序列帧拼成 _preview/characters.png
D:\Miniconda3\python.exe tools\preview_faces.py ahe shishu # 把几位居民的头像拼成 _preview/faces.png
D:\Miniconda3\python.exe tools\preview_creatures.py -o pets feifei yutu # 把几只动物放大拼成 _preview/pets.png，旁边有主角和鸡比个头
& "D:\Blender 5.3\blender.exe" --background --python tools\props.py # 重新生成 Blender 物件；后面加 -- coop scaffold 只生成这几个
& "D:\Blender 5.3\blender.exe" --background --python tools\animal.py -- chicken # 重新生成动物的序列帧；名字是 tools/animals/ 下的
& "D:\Blender 5.3\blender.exe" --background --python tools\stove.py # 重新生成掌勺灶间的图；后面加 -- bench bits tools fire plate 只生成这几样
D:\Miniconda3\python.exe tools\radio_voice.py # 重新生成收音机播报的人声
```

## 工作规则

- 改 `project.godot` 之前确认 Godot 编辑器没有开着这个项目，否则编辑器会把改动覆盖掉。
- 报告完成之前按 `docs/开发流程.md` 收尾：先审改动，再跑单元测试和自动流程，画面有变化就看截图。没做完不说做完。
- 改完玩家能看见的东西，就运行并截图，打开图看。这一轮改的形状、颜色、是谁、什么天气，要在图上认出来。认不出来就改，再截，直到认出来，这一轮才算做完。看单张用临时脚本，截完删掉；完整带窗口流程仍是一轮最多一两次，开之前先说一声。
- 带窗口的自动流程用户嫌它打扰：每轮改动最多跑一两次，跑之前先说一声。先用 `--headless` 跑到全过，再开窗口跑一次看截图；流程脚本中途报错时窗口不会自己关，要告诉用户关掉。平时用单元测试、`--headless` 流程和 `dump_art.gd` 检查。
- 看不到动态和听不到声音。动作、手感、音效只能请用户试玩判断，不要声称它们“流畅”或“好听”。
- 新的逻辑代码配单元测试；修 bug 先写能复现的测试。
- 每完成一项，更新 `docs/进度.md`；做了影响后续的选择，在 `docs/决策记录.md` 加一条。
- 数据表里的 `id` 一旦用过就不改名。
- 第三方代码只放 `farm-town/addons/`，不修改其源码。引入新的库之前先问用户。
- 内容规模按 `docs/后续计划.md` 扩充（决策 066）；计划没写到的作物、居民、系统不主动加。计划里的名单（菜、新居民、异兽、新结局）是提案，先给用户过目再做。
- 用脚本改文件时，先写到临时文件再替换原文件（Python 用 `os.replace`），不要直接用写模式打开原文件：打开就清空了，后面一出错内容就没了。项目很久没提交，丢了没处找。
- 没有用户要求不提交 git。
