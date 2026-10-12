# 演播室 - Arknights Theurgy Cup Like Streaming Assistant - A Godot-based rouge-like Streaming scene helper

一个基于 Godot 4.6 开发的直播间管理工具，用于管理选手、队伍、解说员信息，并提供实时的界面显示功能。
## 许可证
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://github.com/Attenna/Arknights-Theurgy-Cup-Like-Streaming-Assistant/blob/main/LICENSE)
本项目使用 [Apache License 2.0](https://github.com/Attenna/Arknights-Theurgy-Cup-Like-Streaming-Assistant/blob/main/LICENSE) 许可证。

## 🎯 主要功能

### 核心管理功能
- **选手管理**: 选手信息录入、编辑和实时选择
- **队伍管理**: 队伍信息管理和实时显示
- **解说员管理**: 解说员信息录入和选择
- **藏品系统**: 选手开局藏品选择和显示
- **干员系统**: 选手选取开局干员头像和信息显示
- **分队系统**: 选手选取开局分队图标和信息显示

### 界面功能
- **控制面板**: 集中的管理界面
- **场景切换**: 主视觉、比赛场、候场页切换
- **实时显示**: 左侧ID栏实时显示当前选手信息
- **图像管理**: 支持选手头像、队伍图标、干员头像、分队图标

## 🧩 插件系统（一切皆插件 · 支持热重载）

程序采用 **「一切皆插件」** 架构：主核心（`core/`）只提供服务与场景调度，内置直播场景、
控制面板、编辑器本身就是插件，任何人都可以开发自己的**直播场景 / 面板**并一键切换，
无需改动核心代码。

- 内置插件位于 `plugins/`（随程序分发），第三方插件位于 `mods/`，二者**同构**
- 在 `plugin.json` 的 `provides.scenes` 中声明直播场景（`id` / `name` / `scene` / `type=live`）
- 场景根脚本继承 `PluginScene`，即可读取当前选手、队伍、解说数据并响应实时变化
- 提供 `type=live` 场景的插件会自动出现在控制面板导航区，点击即可切换
- **热重载**：修改插件场景 / 数据 / 脚本后无需重启即可生效；`F5` 重载全部插件，
  控制面板提供单插件「重载」按钮（详见开发指南）

示例插件见 `mods/example_mod/`，完整开发说明见 [`framework/docs/插件开发指南.md`](framework/docs/插件开发指南.md)。

## 🏗️ 项目结构

```
演播室2/
├── core/                      # 主核心（唯一保留）：Kernel + 服务 + 插件契约
│   ├── kernel.gd              # autoload 入口
│   ├── plugin.gd              # 插件契约基类
│   ├── plugin_scene.gd        # 场景插件基类
│   ├── plugin_manager.gd      # 插件加载 / 生命周期 / 热重载
│   └── services/              # EventBus / DataService / SceneDirector / FileWatcher / PluginRegistry
├── plugins/                   # 内置插件（随包分发，与 mods/ 同构）
├── mods/                      # 第三方插件（用户安装）
├── src/                       # 引导壳与遗留辅助脚本（main.tscn / main.gd 等）
├── shared/                    # 共享资源（字体、图标、纹理）
├── content/                   # 内容数据包
├── userdata/                  # 用户数据（选手 / 队伍 / 解说等）
└── framework/docs/            # 文档
```

## 🚀 快速开始

### 环境要求
- **Godot 4.3** 或更高版本
- **操作系统**: Windows (已测试)

### 安装步骤
1. 克隆仓库到本地
2. 使用 Godot 4.3 打开 `project.godot` 文件
3. 等待项目导入完成
4. 导出项目为.exe文件，默认文件路径是.exe可执行文件的同目录下/userdata
5. 选择data.zip，解压缩，放置进.exe同意目录内。目录：{exe}/data
6. 确保目录如下所示：
	```
	父文件夹/
	 ├── Streaming Assistant.exe   # 可执行文件
	 ├── data/                    # 游戏数据，包含干员和分队信息
	 │    ├── operators/          # 干员数据目录
	 │    └── squads/             # 分队数据目录
	 └── userdata/                # 用户数据
   	```
8. 运行可执行文件并开始使用

### 数据文件设置
项目运行后会自动创建所需的数据目录结构：
- `userdata/players/` - 选手数据和头像
- `userdata/teams/` - 队伍数据和图标  
- `userdata/announcers/` - 解说员数据
- `data/operators/` - 干员头像按星级分类
- `data/squads/` - 分队图标

## 📁 图像资源规范

### 选手头像
- **路径**: `userdata/players/player_icons/{选手名字}.jpg`
- **格式**: JPG
- **命名**: 使用选手姓名

### 队伍图标  
- **路径**: `userdata/teams/team_icons/{队伍ID}.jpg`
- **格式**: JPG
- **命名**: 使用队伍ID

### 干员头像
- **路径**: `data/operators/{星级}/头像_{干员名}.png`
- **格式**: PNG
- **分类**: 按星级(5-6)分目录存放
- **数据结构**：由JSON文件管理名单，JSON文件目录：`data/operators/{星级}_star_name_list.json`

### 分队图标
- **路径**: `data/squads/{分队名}.png`
- **格式**: PNG
- **命名**: 使用分队名称
- **数据结构**：由JSON文件管理名单，JSON文件目录：`data/squads.json`

## 📁 文本资源规范

## 选手数据
- **路径**：`userdata/players/players.json`
- **格式**：JSON
- **数据结构**：
  ```
  [
	{
		"captain": 0,
		"icon_path": "{exe_path}/userdata/players/player_icons/小明.jpg",
		"id": "小明",
		"name": "小明",
		"starting_operator_choice": "史尔特尔",
		"starting_relic_choice": "希望时代的涂鸦",
		"starting_squad_choice": "魂灵护送分队",
		"stats": {
      "money_taken": 20,
			"score": 325,
			"slogan": "这是感言"
		},
		"team_id": "IGP"
	}//以此类推
  ]
  ```

## 队伍数据
- **路径**：`userdata/teams/teams.json`
- **格式**：JSON
- **数据结构**：
  ```
  [
	{
		"balance": 180,
		"captain": null,
		"icon_path": "C:/Users/duck1/Desktop/LiveStreaming/userdata/teams/team_icons/IGP.jpg",
		"id": "IGP",
		"members": [
			"小明"
		],
		"name": "集批战术分队",
		"rank": null,
		"score": 325
	}
  ]
  ```

## 🎮 使用说明

### 基本操作
1. **启动项目** - 运行编译后的可执行文件或在Godot中运行
2. **打开控制面板** - 使用界面上的控制面板进行管理
3. **录入数据** - 通过各个编辑器录入选手、队伍、解说员信息
4. **选择选手** - 在控制面板中选择当前参赛选手
5. **场景切换** - 使用场景管理器切换不同的直播场景

### 数据管理
- 所有数据以JSON格式存储在 `userdata/` 目录下
- 支持实时编辑和保存
- 自动备份当前选择状态

## 🔧 技术特性

- **Godot 4.3** 引擎开发
- **模块化设计** - 各功能模块独立开发
- **信号系统** - 使用Godot信号实现模块间通信
- **JSON数据存储** - 易于编辑和备份的数据格式
- **路径统一管理** - 基于可执行文件目录的统一路径系统
- **错误处理** - 完善的错误处理和调试输出

## 📝 开发历史

### 最近更新 (2025年7月6日)
- ✅ 修复了所有数据文件路径，统一使用 `AppData.get_exe_dir()` 基准
- ✅ 完善了选手、队伍、解说员的选择和显示系统
- ✅ 增强了左侧ID栏的图像加载功能
- ✅ 添加了藏品系统的完整实现
- ✅ 创建了完整的测试数据和目录结构
- ✅ 清理了未使用的冗余脚本文件

## 🤝 贡献指南

欢迎提交Issue和Pull Request来改进这个项目！

### 开发环境设置
1. 安装 Godot 4.3
2. 克隆仓库
3. 打开项目文件
4. 开始开发

## 📞 联系方式

如有问题或建议，请通过GitHub Issues联系。

## 未来开发计划
1. 文件路径软编码，可以任意修改
2. 直播场景软编码，提供默认资源下载，用户可自定义场景（已实现：见「插件系统」，内置场景已插件化）
3. 可自由编辑的选手，队伍，解说数据结构
4. 实现 A to C to B 转场等更丰富的转场方式

---

**项目状态**: 🟢 活跃开发中  
**Godot版本**: 4.3+  
**最后更新**: 2025年7月7日
