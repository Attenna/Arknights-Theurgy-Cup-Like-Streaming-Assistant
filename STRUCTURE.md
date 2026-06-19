# Streaming Assistant Framework - Project Structure

## Overview

本项目已重构为模块化架构，清晰分离 **核心框架**、**源代码**、**共享资源** 和 **用户内容**。

---

## 目录结构优化前后对比

### 优化前（旧结构）

```
项目根目录/
├── assets/              # 纹理资源（与 fonts/ 分离）
│   └── textures/
├── fonts/               # 字体文件（独立目录）
├── icons/               # 图标文件（独立目录）
├── data/                # 数据文件（位置不明确）
├── scene/               # 场景文件
│   ├── main/
│   ├── ui/
│   └── prefabs/
├── scripts/             # 脚本文件（与 scene/ 结构重复）
│   ├── main/
│   ├── ui/
│   ├── data/
│   └── prefabs/
├── markdown/            # 文档文件（独立目录）
├── core/                # 核心框架
├── framework_cs/        # C# 框架模块
├── framework/docs/      # 框架文档
├── mods/                # 模组目录
└── project.godot
```

### 优化后（新结构）

```
项目根目录/
├── src/                   # 源代码（合并原 scene/ 和 scripts/）
│   ├── scenes/            # 场景文件
│   │   ├── main/          # 主场景
│   │   ├── ui/            # UI 场景
│   │   └── prefabs/       # 预制件
│   └── scripts/           # 脚本文件
│       ├── main/          # 主逻辑脚本
│       ├── ui/            # UI 脚本
│       ├── data/          # 数据管理脚本
│       └── prefabs/       # 预制件脚本
├── shared/                # 共享资源（统一管理）
│   ├── assets/            # 纹理资源
│   ├── fonts/             # 字体文件
│   └── icons/             # 图标文件
├── content/               # 用户内容包
│   └── data/              # 游戏数据文件
├── userdata/              # 用户数据（新增）
├── core/                  # 核心框架（保留）
├── framework/             # 框架文档
│   └── docs/              # 所有文档（含原 markdown/）
├── framework_cs/          # C# 框架模块（保留）
├── mods/                  # 模组目录（保留）
└── project.godot
```

---

## 优化调整理由

### 1. 合并 scene/ 和 scripts/ 为 src/

**问题**：原结构中 `scene/` 和 `scripts/` 目录结构完全重复，导致查找文件时需要在两个目录间来回切换，降低开发效率。

**解决方案**：合并为 `src/` 目录，按功能模块组织场景和脚本，符合行业惯例。

### 2. 统一资源管理到 shared/

**问题**：原结构中 `assets/`、`fonts/`、`icons/` 分散在根目录，资源管理混乱。

**解决方案**：统一归到 `shared/` 目录下，便于查找和管理共享资源。

### 3. 数据文件归类到 content/

**问题**：原 `data/` 目录位置不明确，与用户内容和框架数据混在一起。

**解决方案**：迁移到 `content/data/`，明确标识为游戏内容数据。

### 4. 文档统一到 framework/docs/

**问题**：原 `markdown/` 目录与 `framework/docs/` 分离，文档分散。

**解决方案**：统一合并到 `framework/docs/`，便于文档管理和查阅。

### 5. 新增 userdata/ 目录

**理由**：为用户自定义数据（如存档、配置）提供明确的存放位置，便于区分框架数据和用户数据。

---

## 新目录结构详细说明

### `src/` - 源代码

```
src/
├── scenes/               # 场景文件
│   ├── main/             # 主场景（主菜单、游戏主界面等）
│   ├── ui/               # UI 场景（控制面板、编辑器等）
│   └── prefabs/          # 预制件场景
└── scripts/              # 脚本文件（与 scenes/ 对应）
    ├── main/             # 主逻辑脚本
    ├── ui/               # UI 脚本
    ├── data/             # 数据管理脚本
    └── prefabs/          # 预制件脚本
```

### `shared/` - 共享资源

```
shared/
├── assets/               # 纹理和图像资源
├── fonts/                # 字体文件
└── icons/                # 图标文件
```

### `content/` - 用户内容包

```
content/
└── data/                 # 游戏数据文件（选手、队伍、干员等）
```

### `userdata/` - 用户数据

```
userdata/
├── config/               # 用户配置文件
├── saves/                # 存档文件
└── logs/                 # 日志文件
```

### `core/` - 核心框架

```
core/
├── core_config.json      # 核心配置
├── mod_interface.gd      # 模组接口定义
└── mod_loader.gd         # 模组加载系统
```

### `framework_cs/` - C# 框架模块

```
framework_cs/
├── Core/                 # 框架核心
├── Content/              # 内容加载
├── Config/               # 配置管理
├── Validation/           # 内容验证
├── Extensions/           # 扩展点
└── framework_metadata.json
```

### `mods/` - 模组目录

```
mods/
├── mods.json             # 模组注册表
├── mod_template.gd       # 模组模板
└── example_mod/          # 示例模组
    ├── mod.json          # 模组元数据
    ├── mod.gd            # 模组脚本
    ├── scenes/           # 模组场景
    ├── scripts/          # 模组脚本
    ├── assets/           # 模组资源
    └── data/             # 模组数据
```

---

## 文件路径引用更新清单

| 原路径 | 新路径 |
|--------|--------|
| `res://scene/main/main.tscn` | `res://src/scenes/main/main.tscn` |
| `res://scripts/data/app_data.gd` | `res://src/scripts/data/app_data.gd` |
| `res://icons/icon.svg` | `res://shared/icons/icon.svg` |
| `res://fonts/` | `res://shared/fonts/` |
| `res://assets/` | `res://shared/assets/` |
| `res://data/` | `res://content/data/` |

---

## 命名规范

### 目录命名
- 使用 **小写字母** 和 **下划线**（如 `main_menu`）
- 避免使用空格和特殊字符
- 目录名应具有描述性（如 `ui`, `scripts`, `data`）

### 文件命名
- **场景文件**：使用 **小写字母** 和 **下划线**（如 `main_menu.tscn`）
- **脚本文件**：使用 **小写字母** 和 **下划线**（如 `player_editor.gd`）
- **资源文件**：保持原有命名，建议使用英文或拼音

### 代码文件命名
- GDScript 文件：`snake_case.gd`
- C# 文件：`PascalCase.cs`

---

## 最佳实践建议

1. **单一职责**：每个目录和文件应有明确的职责
2. **一致性**：保持目录结构和命名规范的一致性
3. **可扩展性**：设计时考虑未来扩展需求
4. **文档化**：为复杂模块添加 README 文档
5. **.gitignore**：确保忽略临时文件和构建产物

---

## 迁移完成验证

运行以下命令验证目录结构：

```bash
# 查看完整目录结构
ls -la

# 验证关键文件是否存在
ls -la src/scenes/main/
ls -la src/scripts/data/
ls -la shared/fonts/
ls -la content/data/
```

---

## 下一步建议

1. 更新场景文件中的脚本引用路径
2. 更新脚本中的资源引用路径
3. 运行项目验证所有路径引用正确
4. 更新项目文档以反映新结构