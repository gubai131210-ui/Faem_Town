# 雾隐青岚（Farm_Town）

类星露谷的农场生活模拟游戏，Godot 4.7 + GDScript。所有美术和音频都由代码或 Blender 脚本生成，不使用外部素材。用户用中文交流，文档和代码注释用中文。

## 开工前先读

1. `docs/进度.md`：现在做到哪、下一步做什么。
2. `docs/架构.md`：代码怎么组织。新功能必须符合；要偏离先在决策记录里写原因。
3. `docs/设计文档.md`：玩法、剧情、内容清单。只读和当前任务相关的章节。
4. `docs/决策记录.md`：已经定下的事，不要重新讨论或悄悄推翻。

## 目录

- `farm-town/`：Godot 项目根目录（`project.godot` 在这里）。
- `docs/`：文档。
- `farm-town/tools/`：Blender 脚本，Godot 不导入。
- `farm-town/_preview/`：自动截图和素材预览，不入库。

## 环境

- Godot：`E:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`（命令行用 console 版）
- Blender：`D:\Blender 5.3\blender.exe`
- 终端是 PowerShell。

## 命令

在 `farm-town/` 下执行，`$g` 是上面的 Godot 路径：

```powershell
& $g --headless --path . --import                              # 导入资源；新环境跑两次
& $g --headless --path . -s addons/gut/gut_cmdln.gd -gexit     # 单元测试
& $g --path . -- --shots                                       # 自动跑流程并截图到 _preview/
& "D:\Blender 5.3\blender.exe" --background --python tools\farmer.py   # 重新生成角色
```

## 工作规则

- 改 `project.godot` 之前确认 Godot 编辑器没有开着这个项目，否则编辑器会把改动覆盖掉。
- 报告完成之前：单元测试通过，自动流程跑过且没有报错，看过截图。
- 看不到动态和听不到声音。动作、手感、音效只能请用户试玩判断，不要声称它们“流畅”或“好听”。
- 新的逻辑代码配单元测试；修 bug 先写能复现的测试。
- 每完成一项，更新 `docs/进度.md`；做了影响后续的选择，在 `docs/决策记录.md` 加一条。
- 数据表里的 `id` 一旦用过就不改名。
- 第三方代码只放 `farm-town/addons/`，不修改其源码。引入新的库之前先问用户。
- 内容规模已经定稿，不主动加新的作物、居民、系统。
- 没有用户要求不提交 git。
