# 演播室2 项目结构（STRUCTURE）

## 一、概览

演播室2 采用 **纯核心 + 一切皆插件** 架构（内核版本 `core 2.0.0`）：

- **仓库是纯核心**：只保留运行时内核（`core/`）与引导壳（`src/`），
  **不含任何内置插件**；所有直播场景 / 控制面板 / 编辑器都是 `mods/` 下的外部插件。
- **核心与插件是「运行时拼装」关系，不是打包关系**：`mods/` 永不进 pck，
  导出后插件以真实文件夹形式与可执行文件同级，用户解压即安装。
- 核心零插件可正常启动（优雅降级），这是设计行为。

约定细则见 [`AGENTS.md`](AGENTS.md) 与 [`framework/docs/插件开发指南.md`](framework/docs/插件开发指南.md)。

---

## 二、目录总览

```
项目根目录/
├── core/                    # 内核：Kernel autoload + 服务 + 插件契约
├── src/                     # 引导壳（main.tscn / main.gd），不含任何业务场景
├── mods/                    # 全部插件（每个子目录一个独立插件）
├── shared/                  # 仅应用图标 + 设计源（.afphoto / .afdesign）
├── content/                 # 只读内置内容数据（干员名单 / 藏品等）
├── userdata/                # 首次运行播种到 user:// 的示例用户数据
├── tests/                   # 契约测试（无头运行）
├── framework/               # 框架文档
│   └── docs/                # 全部文档（含 adr/）
├── framework_cs/            # C# 内容框架模块（独立，未接插件系统）
├── .github/workflows/       # CI 门禁（grep 禁令 + 契约测试，Linux runner）
├── export_presets.cfg       # 导出预设（Windows Desktop，纯核心 exclude_filter 已固化）
├── export_mods.ps1          # 插件打包脚本（Windows PowerShell）
├── export_mods.sh           # 插件打包脚本（Linux / macOS）
├── project.godot            # 项目配置（autoload：AppData → Kernel → ModLoader）
├── AGENTS.md                # AI 协作规范
├── README.md                # 架构现状与快速开始
├── STRUCTURE.md             # 本文件
└── LICENSE
```

> `.godot/`（导入缓存）、`builds/`（导出产物）**永不提交**，已在 `.gitignore` 排除。

---

## 三、各目录说明

### `core/` — 主核心（一切皆插件）

主核心只保留服务与契约，**不含任何业务场景**，且不认识任何具体插件 id。

```
core/
├── kernel.gd             # autoload 入口：初始化服务、扫描并启动插件
├── plugin.gd             # 插件契约基类（Plugin）
├── plugin_scene.gd       # 场景插件基类（PluginScene）
├── plugin_manager.gd     # 发现 / 加载 / 启用 / 卸载 / 热重载（扫描 mods/）
├── plugin_context.gd     # 插件服务访问层（PluginContext，ADR-0001）
├── event_catalog.gd      # 事件目录（事件名常量化 + payload 契约）
├── data_keys.gd          # 数据字段常量
├── data_schema.gd        # 数据 schema 定义与校验 / 版本迁移
├── mod_interface.gd      # 【兼容别名】ModInterface -> Plugin
├── mod_scene.gd          # 【兼容别名】ModScene -> PluginScene
├── mod_loader.gd         # 【兼容别名】旧 ModLoader autoload，转发 Kernel
└── services/             # EventBus / DataService / SceneDirector / FileWatcher / PluginRegistry
```

### `src/` — 引导壳

只负责装配内核并注入控制面板，**不得认识任何具体场景**。

```
src/
├── scenes/main/main.tscn     # 入口场景
└── scripts/
    ├── main/main.gd          # 纯引导壳：从 PluginRegistry 注入 main_window 面板
    └── data/app_data.gd      # AppData autoload：exe 目录 / 用户数据目录 / 首运行播种
```

### `mods/` — 全部插件

每个子目录即一个独立插件（同一份 `plugin.json` 契约、同一套生命周期与热重载管线）。

```
mods/
├── control_panel_base/     # 控制面板基底（一级面板容器 + mount_panel 挂载协议）
├── scene_manager_panel/    # 场景管理二级面板（dependencies: control_panel_base）
├── streaming_arena/        # 比赛场直播场景（实例模板：素材/字体/着色器全自携带）
├── _template/              # 插件脚手架骨架（plugin.json.example，复制即用）
├── _test_pair_a/           # 契约测试插件对（`_` 前缀，打包时排除）
└── _test_pair_b/
```

> 插件无需注册表：`PluginManager` 自动扫描 `mods/` 下带 `plugin.json`（或旧 `mod.json`）的目录。
> **资源自携带**：纹理 / 字体 / 着色器必须放在插件自身 `assets/` 下，核心不提供共享资源。

### `shared/` — 仅应用图标 + 设计源

```
shared/
├── icons/icon.svg              # 应用图标
└── assets/textures/*.afphoto   # 设计源文件（Affinity），不参与运行时
```

> 禁止在此恢复共享字体 / 纹理 —— 插件资源必须自携带。

### `content/` — 只读内置内容数据

```
content/
└── data/
    ├── relics.json             # 藏品数据
    └── operators/*.json        # 干员星级名单
```

### `userdata/` — 示例用户数据（播种源）

首次运行时由 `AppData.seed_userdata_if_missing()` 复制到用户数据目录
（Linux：`~/.local/share/godot/app_userdata/演播室2/userdata/`；
Windows：`%APPDATA%\Godot\app_userdata\演播室2\userdata\`）。

```
userdata/
├── players/players.json
├── teams/teams.json
└── announcers/                 # 解说相关缓存（空占位文件不会被播种）
```

### `tests/` — 契约测试

无头运行 `res://tests/test_main.tscn`，覆盖事件目录 / 数据 schema / EventBus 契约 / 集成场景。

```
tests/
├── test_main.tscn / test_main.gd      # 测试入口
├── test_case.gd                        # 轻量断言框架
├── test_event_catalog.gd
├── test_event_bus.gd
├── test_data_contract.gd
├── test_data_schema.gd
└── test_integration.gd                # 纯事件协作 / 热重载订阅守恒 / 依赖阻塞补加载
```

### `framework/` — 框架文档

```
framework/docs/
├── 插件开发指南.md            # 插件契约、生命周期、资源自携带、热重载
├── 控制面板插件约定.md        # 面板挂载协议（control_panel_base + mount_panel）
├── 架构演进路线.md            # 三铁律与分阶段演进
├── 导出指南.md                # 导出与用户数据位置
├── Git工作规范.md             # 分支与提交规范
└── adr/                       # 架构决策记录 0001~0003
```

### `framework_cs/` — C# 内容框架模块

独立模块（`Core/` `Content/` `Config/` `Validation/` `Extensions/`），
**尚未接入插件系统**；集成说明见插件开发指南 §C# 框架。

---

## 四、插件打包与分发

| 平台 | 脚本 | 用法 |
|------|------|------|
| Windows | `export_mods.ps1` | `.\export_mods.ps1` / `.\export_mods.ps1 -Name <id>` |
| Linux / macOS | `export_mods.sh` | `./export_mods.sh` / `./export_mods.sh <id>` |

- 产物：`builds/mods/<id>_<version>.zip`，**zip 内顶层即插件目录**，
  解压到 `{exe}/mods/` 即完成安装；`.import` 随插件走，`.godot` 缓存不带走。
- 打包时自动跳过 `_` 前缀目录（脚手架 / 测试插件）与无 `plugin.json` 的目录。

---

## 五、命名规范

### 目录命名
- 使用 **小写字母** 和 **下划线**（如 `main_menu`），避免空格与特殊字符。

### 文件命名
- **场景文件**：小写 + 下划线（如 `main_menu.tscn`）
- **脚本文件**：小写 + 下划线（如 `player_editor.gd`）
- **GDScript**：`snake_case.gd`；**C#**：`PascalCase.cs`

---

## 六、最佳实践

1. **单一职责**：每个目录与文件职责明确。
2. **资源自携带**：插件所需的字体 / 纹理 / 着色器随插件分发，不依赖核心共享资源。
3. **协作走官方通道**：`EventBus` 事件 / `plugin.json` provides / `DataService` / `mount_panel`，
   禁止跨插件 `preload` 或跨插件 `get_node`（见 AGENTS.md 三铁律）。
4. **服务从访问层获取**：`PluginContext` / `Plugin` 基类 getter，禁止硬编码 `/root/Kernel`。
5. **分支管时间，不管模块**：禁止用分支隔离 core / 插件。

---

## 七、验证流程（提交前必做）

```bash
# 1. 导入资源（新增文件后必须）
godot4 --headless --path . --import

# 2. 冒烟启动（观察日志，不得出现 ERROR / SCRIPT ERROR）
godot4 --headless --path . --quit-after 300

# 3. 契约测试
godot4 --headless --path . res://tests/test_main.tscn
```

> 无头模式特有的 `Window spawned at invalid position` 属伪错误（无真实屏幕所致），窗口运行无此问题。
