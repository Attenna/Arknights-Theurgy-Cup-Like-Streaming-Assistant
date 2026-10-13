# 演播室2 - Arknights Theurgy Cup Like Streaming Assistant

基于 **Godot 4.5.1 (mono)** 的直播间管理工具：管理选手、队伍、解说员信息，
提供可切换、可热重载的直播场景显示。

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

---

## 核心认知：一切皆插件（core 2.0.0）

```
仓库（开发时）                 部署目录（运行时）
core/ + src/  ──导出──▶        演播室2.exe + .pck   ← 纯核心
mods/<插件>/  ──拷贝/解压──▶   mods/<插件>/         ← 文件夹即安装
```

- 主核心（`core/`）只提供引导、服务总线（事件 / 数据 / 场景调度 / 插件注册 / 热重载）、
  插件契约与依赖解析；**不包含任何具体功能**。
- 所有直播场景、控制面板、编辑器均为 `mods/` 下的外部插件，共享同一份
  `plugin.json` 契约；核心**零插件可正常启动**（空窗口 + 优雅降级）。
- **依赖强制解析**：`dependencies` 缺失 / 环形的插件阻塞不加载，无半加载状态。
- **热重载**：改场景 / 数据 / 脚本无需重启即可生效（`F5` 重载全部）。

当前随仓库提供的插件：

| 插件 | 类型 | 说明 |
|------|------|------|
| `streaming_arena` | 直播场景 | 比赛场（素材 / 字体 / 着色器全自携带的实例模板） |
| `control_panel_base` | 面板（基底） | 控制面板骨架，装载所有 `slot="control_panel"` 二级面板 |
| `scene_manager_panel` | 面板（二级） | 依赖基底，列出全部已注册直播场景供选择播出 |

## 快速开始

### 路线 A：开发者（从源码运行）

1. 克隆仓库
2. 用 **Godot 4.5.1 mono** 打开 `project.godot`，等待导入完成
3. 直接 `F5` 运行：控制面板弹出，含「直播场景」列表，可切换比赛场

### 路线 B：用户（发布版部署）

1. 获取 `演播室2.exe` + `.pck`（纯核心）与各插件 zip
2. 按以下结构放置（**mods 永不打包进 exe**，文件夹即安装）：

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
| 打包全部插件 | `.\export_mods.ps1`（`-Name <id>` 打包单个） | `builds/mods/<id>_<版本>.zip` |
| 安装插件 | 解压 zip 到 `{exe}/mods/` | 文件夹即安装 |

## 项目结构

```
├── AGENTS.md                  # AI 协作工作规范（Agent 先读）
├── core/                      # 内核：Kernel autoload + 六服务 + Plugin/PluginScene 契约
├── src/                       # 引导壳（main.tscn / main.gd，含 --scene 直连参数）
├── mods/                      # 插件根目录（开发时插件放这里）
├── framework_cs/              # C# 内容框架（独立未接入，见插件开发指南第 7 节）
├── shared/                    # 应用图标 + 设计源（.afphoto）
├── content/ + userdata/       # 数据源与用户数据（见下方数据规范）
├── framework/docs/            # 全部文档
└── export_mods.ps1            # 插件一键打包脚本
```

## 文档索引

| 文档 | 内容 |
|------|------|
| [AGENTS.md](AGENTS.md) | AI 协作规范：最小改动原则、目录禁区、验证流程、已知坑 |
| [插件开发指南](framework/docs/插件开发指南.md) | plugin.json 契约、生命周期、资源自携带、依赖解析、热重载边界 |
| [控制面板插件约定](framework/docs/控制面板插件约定.md) | 基底 + 二级面板架构、挂载约定、新增二级面板步骤 |
| [导出指南](framework/docs/导出指南.md) | 导出纯核心、插件打包、发布布局与验证清单 |
| [Git 工作规范](framework/docs/Git工作规范.md) | 分支模型、提交信息规范、冲突预防、仓库演进路线 |

## 数据规范（DataService 契约）

### 选手头像与队伍图标

| 资源 | 路径 | 格式 |
|------|------|------|
| 选手头像 | `userdata/players/player_icons/{选手名}.jpg` | JPG |
| 队伍图标 | `userdata/teams/team_icons/{队伍ID}.jpg` | JPG |
| 干员头像 | `data/operators/{星级}/头像_{干员名}.png`（名单 `{星级}_star_namelist.json`） | PNG |
| 分队图标 | `data/squads/{分队名}.png`（名单 `data/squads.json`） | PNG |

### 选手数据 `userdata/players/players.json`

```json
[
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
]
```

### 队伍数据 `userdata/teams/teams.json`

```json
[
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
]
```

> 插件通过 `PluginScene` 基类读取以上数据（`get_current_player()` / `get_players()` /
> `get_team_by_id()`），并连接 `player_changed` / `announcer_changed` 信号实时刷新。

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
