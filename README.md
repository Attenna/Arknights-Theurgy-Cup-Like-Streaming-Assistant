# 演播室2 - Arknights Theurgy Cup Like Streaming Assistant

基于 **Godot 4.5.1 (mono)** 的直播间管理工具：管理选手、队伍、解说员信息，
提供可切换、可热重载的直播场景显示。

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

---

## 核心认知：一切皆插件（core 2.0.0）

```
仓库（开发时）                          部署目录（运行时）
core/ + src/ ──导出──▶ exe + .pck        ← 纯核心
插件仓库 ──shiyingshi-dist 组装──▶ mods/<插件>/  ← 文件夹即安装
```

- 主核心（`core/`）只提供引导、服务总线（事件 / 数据 / 场景调度 / 插件注册 / 热重载）、
  插件契约与依赖解析；**不包含任何具体功能**。
- 所有直播场景、控制面板、编辑器均为**独立插件仓库**，共享同一份 `plugin.json` 契约；
  由 `shiyingshi-dist` 按 manifest 组装成交付文件夹。核心**零插件可正常启动**（空窗口 + 优雅降级）。
- **依赖强制解析**：`dependencies` 缺失 / 环形的插件阻塞不加载，无半加载状态。
- **热重载**：改场景 / 数据 / 脚本无需重启即可生效（`F5` 重载全部）。

插件仓库（独立维护，tag 由 dist manifest 固定）：

| 插件 | 仓库 | 类型 | 说明 |
|------|------|------|------|
| `streaming_arena` | `shiyingshi-plugin-streaming-arena` | 直播场景 | 比赛场（素材 / 字体 / 着色器全自携带的实例模板） |
| `main_vision` | `shiyingshi-plugin-main-vision` | 直播场景 | 主视觉 |
| `control_panel_base` | `shiyingshi-plugin-control-panel-base` | 面板（基底） | 控制面板骨架，装载所有 `slot="control_panel"` 二级面板 |
| `scene_manager_panel` | `shiyingshi-plugin-scene-manager-panel` | 面板（二级） | 依赖基底，列出全部已注册直播场景供选择播出 |
| `player_database` | `shiyingshi-plugin-player-database` | 面板（二级）+ 数据 | SQLite 选手 / 队伍 / 解说数据库，自动同步 `userdata` 契约 JSON（自带 Windows x64 godot-sqlite 原生扩展） |

## 快速开始

### 路线 A：开发者（从源码运行）

1. 克隆本仓库（纯核心）与 `shiyingshi-dist`
2. 用 **Godot 4.5.1 mono** 打开 `project.godot`，等待导入完成
3. 在 `shiyingshi-dist` 运行 `scripts/assemble.ps1`，或把插件仓库复制到本地 `plugins/` 后 `F5`
4. 核心单独启动时为空窗口（优雅降级）；交付形态由 dist 组装

### 路线 B：用户（发布版部署）

1. 获取 `演播室2.exe` + `.pck`（纯核心）与各插件 zip
2. 按以下结构放置（**插件永不打包进 exe**，文件夹即安装）：

```
父文件夹/
├── 演播室2.exe
├── mods/                     # 插件：解压各插件 zip 到这里，可自由增删
│   ├── streaming_arena/
│   ├── control_panel_base/
│   └── scene_manager_panel/
├── data/                     # 干员 / 分队等静态资源
│   ├── operators/            # 干员头像（按星级分目录）
│   └── squads/               # 分队图标
└── userdata/                 # 用户数据（选手 / 队伍 / 解说，首次运行可自动创建）
```

3. 运行 exe，控制面板中选择场景播出

### 无控制面板时直连场景（调试）

```powershell
# 编辑器：项目设置 → 运行 → 自定义参数：-- --scene streaming_arena
# 命令行：
godot_console.exe --path <项目> -- --scene streaming_arena
```

## 打包与分发

| 动作 | 命令 / 操作 | 产物 |
|------|------------|------|
| 导出纯核心 | 编辑器 `Project → Export` 或 `godot --headless --export-release "Windows Desktop" "builds/演播室2.exe"` | exe + pck（不含 mods） |
| 打包全部插件 | Windows：`.\export_mods.ps1`（`-Name <id>` 单个）；Linux / macOS：`./export_mods.sh <id>` | `builds/mods/<id>_<版本>.zip` |
| 安装插件 | 解压 zip 到 `{exe}/mods/` | 文件夹即安装 |

## 项目结构

```
├── AGENTS.md                  # AI 协作工作规范（Agent 先读）
├── core/                      # 内核：Kernel autoload + 六服务 + Plugin/PluginScene 契约
├── src/                       # 引导壳（main.tscn / main.gd，含 --scene 直连参数）
├── framework_cs/              # C# 内容框架（独立未接入，见插件开发指南第 7 节）
├── shared/                    # 应用图标 + 设计源（.afphoto）
├── content/ + userdata/       # 数据源与用户数据（见下方数据规范）
├── framework/docs/            # 全部文档
├── export_mods.ps1            # 插件一键打包脚本（Windows）
└── export_mods.sh             # 插件一键打包脚本（Linux / macOS）
```

## 文档索引

| 文档 | 内容 |
|------|------|
| [AGENTS.md](AGENTS.md) | AI 协作规范：最小改动原则、目录禁区、验证流程、已知坑 |
| [代码库导览](framework/docs/代码库导览.md) | 项目全貌：核心理念、启动顺序、内核服务、插件契约、数据根与阅读路径 |
| [API 契约版本](framework/docs/api-version.md) | api_version 语义、范围语法与不兼容时的阻塞行为 |
| [插件开发指南](framework/docs/插件开发指南.md) | plugin.json 契约、生命周期、资源自携带、依赖解析、热重载边界 |
| [控制面板插件约定](framework/docs/控制面板插件约定.md) | 基底 + 二级面板架构、挂载约定、新增二级面板步骤 |
| [导出指南](framework/docs/导出指南.md) | 导出纯核心、插件打包、发布布局与验证清单 |
| [Git 工作规范](framework/docs/Git工作规范.md) | 分支模型、提交信息规范、冲突预防、仓库演进路线 |

## 数据规范（DataService 契约 v1）

> 本节即正式数据契约本体（issue #4）：字段名的唯一权威是 `core/data_keys.gd`
> （`DataKeys` 常量），字段类型 / 必填定义与校验逻辑在 `core/data_schema.gd`（`DataSchema`）。
> DataService 加载时自动执行 schema 校验，问题仅告警不阻断（优雅降级）；
> 字段结构变更必须同步编写迁移函数并递增 `schema_version`。

### 版本信封与迁移

契约文件统一为带 `schema_version` 的信封结构；旧版裸格式（无信封）读取时自动迁移、
不回写文件，写入侧建议直接产出信封格式：

```json
// userdata/players/players.json            → { "schema_version": 1, "players":  [ …选手条目… ] }
// userdata/teams/teams.json                → { "schema_version": 1, "teams":    [ …队伍条目… ] }
// userdata/players/current_player.json     → { "schema_version": 1, "player":   …选手条目… }
// userdata/announcers/current_announcer.json → { "schema_version": 1, "announcer": …解说条目… }
```

### 选手条目（players.json 数组元素 / current_player.json）

```json
{
  "id": "小明",
  "name": "小明",
  "captain": 0,
  "icon_path": "{exe_path}/userdata/players/player_icons/小明.jpg",
  "team_id": "IGP",
  "starting_operator_choice": "史尔特尔",
  "starting_relic_choice": "希望时代的涂鸦",
  "starting_squad_choice": "魂灵护送分队",
  "stats": { "score": 325, "money_taken": 20, "slogan": "这是感言" }
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `id` / `name` | String | ✅ | 唯一 id / 显示名 |
| `team_id` / `icon_path` / `starting_*` | String | 可选 | 队伍 id、头像路径、开局三项选择 |
| `captain` | int | 可选 | 0 / 1 |
| `stats` | Dictionary | 可选 | 子字段 `score` / `money_taken`（int）、`slogan`（String） |

### 队伍条目（teams.json 数组元素）

```json
{
  "id": "IGP",
  "name": "集批战术分队",
  "captain": null,
  "rank": null,
  "balance": 180,
  "score": 325,
  "icon_path": "{exe_path}/userdata/teams/team_icons/IGP.jpg",
  "members": ["小明"]
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `id` / `name` | String | ✅ | 唯一 id / 显示名 |
| `balance` / `score` | int | 可选 | 资金 / 积分 |
| `captain` / `rank` | int | 可选 | 允许 null（视同缺省） |
| `icon_path` | String | 可选 | 队伍图标路径 |
| `members` | Array[String] | 可选 | 成员选手 id 列表 |

### 解说条目（current_announcer.json）

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `id` / `name` | String | ✅ | 唯一 id / 显示名 |
| `icon_path` | String | 可选 | 头像路径 |

> 校验对数字统一按数值处理（JSON 解析无整型概念）；插件内字段名一律引用 `DataKeys`
> 常量（如 `DataKeys.PLAYER_NAME`），禁止裸字符串（铁律 3）。

### SQLite 主库（`player_database` 插件）

- 存储：`userdata/player_database/player_database.db`（SQLite，表 `players` / `teams` /
  `announcers` / `app_state`）。原生扩展由插件自带并在 `on_load` 时运行时加载，核心无需安装 addon。
- 权威：所有增删改先写 SQLite，再自动导出上文的契约 JSON（含 `schema_version` 信封）；
  现有场景与其它插件继续经 `DataService` 读取，并订阅 `player_changed` /
  `announcer_changed` / `data_reloaded` 事件。
- 接口（插件内服务节点）：`list/get/create/update/delete_*`、`set_current_*` /
  `clear_current_*`、`import_from_json()` / `export_to_json()`、`set_team_members()`、
  `import_from_csv()` / `export_to_csv()` / `ensure_csv_templates()` / `get_csv_dir()`。
- 队伍成员由 `players.team_id` 派生，`teams.members` 在导出时自动生成，避免两份数据漂移。
- 原生库当前随包提供 **Windows x86_64**（debug / release）；其它平台需替换
  `native/` 下对应二进制并在 `gdsqlite.gdextension` 增加条目。

#### CSV 快速录入

1. 控制面板「数据」页点「导出 CSV 模板」或「打开 CSV 目录」，文件位于
   `userdata/player_database/csv/`：`players.csv` / `teams.csv` / `announcers.csv`。
2. 用 Excel / WPS / 文本编辑器填行（建议保存为 **CSV UTF-8**），点「从 CSV 导入（合并）」。
3. 也可用任意路径调用 `import_from_csv("D:/.../csv")` 批量导入。

- 表头支持英文契约名（`id,name,team_id,captain,score,money_taken,slogan,...`）与常用中文别名
  （`姓名 / 队伍 / 队长 / 开局干员 / 开局藏品 / 开局分队 / 积分 / 取钱 / 感言` 等）。
- 合并语义：以 `id` 为唯一键；只覆盖 CSV 中出现的列，未出现的列保持不变，空单元格清空该列。
- **自适应扩展列**：任何未识别的表头（如 `备注`、`评级`）自动写入数据库 `extra_json`，
  并出现在 JSON 导出与「导出当前数据为 CSV」中；后续 CSV 未写该列时原值保留。
- 队伍成员以选手 `team_id` 为准；CSV 的 `members` 列仅作导出参考，导入时忽略。
- 解析支持逗号 / 分号 / 制表符分隔、UTF-8 BOM、引号包裹的逗号与换行；
  空行与缺 `id` 行会被跳过，问题行汇总在导入结果的 `issues` 中。
- 配套样例 CSV：[docs/csv_testdata](https://github.com/Attenna/shiyingshi-plugin-player-database/tree/v1.0.0/docs/csv_testdata/)（含故意异常行，
  复制到 CSV 目录即可验证导入告警）。
- 完整测试用例见 [CSV 导入测试用例](https://github.com/Attenna/shiyingshi-plugin-player-database/blob/v1.0.0/docs/CSV导入测试用例.md)。

### 选手头像与队伍图标

| 资源 | 路径 | 格式 |
|------|------|------|
| 选手头像 | `userdata/players/player_icons/{选手名}.jpg` | JPG |
| 队伍图标 | `userdata/teams/team_icons/{队伍ID}.jpg` | JPG |
| 干员头像 | `data/operators/{星级}/头像_{干员名}.png`（名单 `{星级}_star_namelist.json`） | PNG |
| 分队图标 | `data/squads/{分队名}.png`（名单 `data/squads.json`） | PNG |

> 插件通过 `PluginScene` 基类读取以上数据（`get_current_player()` / `get_players()` /
> `get_team_by_id()`），并连接 `player_changed` / `announcer_changed` 信号实时刷新；
> schema 校验问题会在日志中以 `[DataService] schema 校验: …` 告警，不阻断加载。

## 开发协作

- 提交 / 分支规范见 [Git 工作规范](framework/docs/Git工作规范.md)；
  AI 助手遵循 [AGENTS.md](AGENTS.md)（最小改动原则最高优先级）。
- 重大删除 / 重构前先打备份 zip；`core/` 改动需先声明影响面。

## 未来计划

1. 可自由编辑的选手、队伍、解说数据结构
2. 实现 A to C to B 转场等更丰富的转场方式
3. 插件生态：第三方插件分发约定与更多实例模板

---

**项目状态**: 活跃开发中 | **Godot**: 4.5.1 (mono) | **内核契约**: core 2.0.0 | **许可证**: Apache 2.0
