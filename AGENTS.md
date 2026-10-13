# AGENTS.md — AI 协作工作规范

本文件面向在本仓库工作的 AI 助手（Agent）。遵守以下规则可避免绝大多数历史已踩过的坑。
人类协作者同样适用。开发约定详见 [`framework/docs/插件开发指南.md`](framework/docs/插件开发指南.md)，
控制面板约定见 [`framework/docs/控制面板插件约定.md`](framework/docs/控制面板插件约定.md)，
分支与提交规范见 [`framework/docs/Git工作规范.md`](framework/docs/Git工作规范.md)。

---

## 1. 项目定位（先读）

- **演播室2**：Godot 4.5.1 mono 直播场景助手，`Windows Desktop` 平台。
- 架构：**一切皆插件（core 2.0.0）**。仓库是**纯核心**——`plugins/` 内置插件已全部移出，
  所有直播场景、控制面板、编辑器均为 `mods/` 下的外部插件。
- 核心零插件可正常启动（优雅降级），这是设计行为，不是 bug。
- 历史完整内容（旧内置插件、示例）在备份包 `d:\Projects\Arknights-Streaming-Assistant_backup_2026-10-13.zip`。

## 2. 最小改动原则（最高优先级）

- **只做用户明确要求的改动**。不顺手重构、不加未要求的"改进"、不扩展任务范围。
- 修 bug 不动周边代码；加功能不加多余配置项与抽象。
- 内核（`core/`）改动是**大事**：先说明影响面，获得确认再动手；改后必须同步
  `framework/docs/` 相应文档并考虑 `api_version` 兼容性。

## 3. 目录职责与禁区

| 目录 | 职责 | 禁止 |
|------|------|------|
| `core/` | 内核：Kernel autoload + 六服务 + Plugin/PluginScene 契约 | 勿在内核代码里认识任何具体插件 id；勿随意改公开接口 |
| `src/` | 引导壳（main.tscn / main.gd） | 勿在此注册/认识具体场景 |
| `mods/` | 全部插件（每个子目录一个独立插件） | 勿跨插件互相引用对方内部文件（只走 manifest 能力） |
| `shared/` | 仅应用图标 + 设计源（.afphoto） | 勿恢复共享字体/纹理——插件资源必须自携带 |
| `.godot/` `builds/` | 缓存与导出产物 | 永不提交、永不手工修改 |
| `framework/docs/` | 全部文档 | 改约定必须同步文档 |

## 4. 插件开发硬性约定（违反必出 bug）

1. **资源自携带**：纹理/字体/着色器放本插件 `assets/{textures,fonts,shaders}/`，
   核心不提供任何共享资源。
2. **`.tscn` 相对路径**：`ext_resource` 一律相对场景文件目录（如 `../assets/...`），
   手写时删除 `uid="uid://..."` 属性（旧 uid 跨目录失效反而报错）。
3. **脚本相对加载**：以 `get_script().resource_path.get_base_dir().path_join(...)` 为基准。
   ⚠️ `get_script()` 返回 Variant，变量必须显式 `: String` 标注，`:=` 推断会编译失败。
4. **禁止硬编码** `res://plugins/...`、`res://mods/...`——导出后插件在 exe 同级真实目录，
   这类路径无法解析。场景/面板路径只写在 `plugin.json` 中（相对插件目录）。
5. **`.import` 文件不复制**：搬运插件目录后删除 `*.import`，让 Godot 重新生成（避免旧 uid 残留）。
6. **依赖声明**：`plugin.json` 的 `dependencies` 是强制解析——缺失/环形依赖的插件会被
   **阻塞不加载**（无半加载）。声明前确认对方插件存在。
7. **插件间协作**：通过 manifest 能力（scenes/panels）与内核服务（EventBus /
   SceneDirector / PluginRegistry / DataService），不直接访问其它插件的节点。
   控制面板二级面板用组 `control_panel_base` + `mount_panel` 约定（见文档）。

## 5. 验证流程（提交前必做）

```powershell
# 1. 导入新资源（新增文件后必须）
D:\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64_console.exe --headless --path . --import

# 2. 冒烟启动（观察日志）
... --headless --path . --quit-after 300

# 3. 需要验证某直播场景时
... --headless --path . --quit-after 300 -- --scene <场景id>
```

**健康日志基线**：`[PluginManager] 插件已加载并启用: <id>`、`[Kernel] 内核就绪（core 2.0.0）`；
日志中不得出现 `ERROR` / `SCRIPT ERROR`（无头模式特有的
`Window spawned at invalid position` 除外——无真实屏幕所致，窗口运行无此问题）。

**已知伪错误**（勿据此改代码）：`-s` 脚本模式下报 `Identifier not found`（autoload 缺失，
真实启动正常）。无头验证结论必须用真实启动日志复核。

## 6. 环境注意

- 本机 Shell 为 **PowerShell 5**：不支持 `&&` / `||`，用 `;` 分隔；不支持 heredoc，
  多行提交信息用单行 `-m`。
- Godot 可执行文件：`D:\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64_console.exe`。
- 文档、注释、提交信息一律**中文**（与用户交流语言一致）。

## 7. 重大操作前

- 大规模删除/重构前：先打备份 zip 到 `d:\Projects\`（命名
  `Arknights-Streaming-Assistant_backup_<日期>.zip`，排除 `.godot/` 与 `builds/`）。
- 提交与推送规范见 [`framework/docs/Git工作规范.md`](framework/docs/Git工作规范.md)。

## 8. 仓库与分发结构（核心认知）

**核心与插件是「运行时拼装」关系，不是打包关系**：

```
仓库（开发时）                 部署目录（运行时，如用户的"大集合"）
core/ + src/ ──导出──▶         演播室2.exe + .pck   ← 纯核心（mods 永不进 pck）
mods/<插件>/ ──拷贝/解压──▶    mods/<插件>/         ← 文件夹即安装
```

- 「插件」=「模组」：同一份 plugin.json 契约、同一个 mods/ 根目录，仅来源不同。
- **纯核心导出**：`export_filter="all_resources"` + `exclude_filter="mods/*, framework_cs/*"`
  已固化在 `export_presets.cfg`，勿改动；核心零插件可启动（优雅降级）是设计行为。
- **插件打包**：`.\export_mods.ps1`（可 `-Name <id>` 指定单个）→ `builds/mods/<id>_<version>.zip`，
  zip 内顶层即插件目录，解压到 `{exe}/mods/` 即完成安装。`.import` 随插件走，`.godot` 缓存不带走。
- **部署目录（大集合）不进 git**：它是拼装产物，不是仓库。更新 = 重新导出核心覆盖 exe/pck、
  替换对应 mods/<id>/ 文件夹；试验性插件直接丢进部署目录的 mods/ 试，不污染仓库。
- **分支管时间，不管模块**：禁止用分支隔离 core / 插件。仓库演进（何时拆分、怎么拆）
  见 [`framework/docs/Git工作规范.md`](framework/docs/Git工作规范.md) 第 7 节。
