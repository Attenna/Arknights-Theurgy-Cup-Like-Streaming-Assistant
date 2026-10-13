# _template —— 插件模板脚手架

复制本目录为 `mods/<你的插件名>/` 即得到可加载插件（issue #7）。

## 使用步骤

1. 复制整个 `_template/` 目录，重命名为你的插件目录名（建议与 id 一致）
2. `plugin.json.example` → 改名 `plugin.json`，修改 `id` / `name` / 场景 id 等字段
3. `plugin.gd` 中 `PLUGIN_ID` 常量与元数据同步修改，删除顶部说明注释
4. 场景 / 面板按需保留或删除

## 目录约定

```
<你的插件>/
├── plugin.json            # 清单（由 .example 改名）
├── plugin.gd              # 入口（extends Plugin，含三铁律速查）
├── scenes/                # 直播场景（1920x1080 基准）
├── scripts/               # 场景脚本
├── panels/                # 控制面板二级面板（可选）
├── assets/
│   ├── textures/          # 纹理（自携带，核心不提供共享资源）
│   ├── fonts/             # 字体（自携带）
│   └── shaders/           # 着色器（自携带）
└── data/                  # 插件自有数据（可选，参与热重载监听）
```

## 硬性约定（违反必出 bug）

- `.tscn` 的 `ext_resource` 用相对场景文件的路径（如 `../scripts/xxx.gd`），手写时删除 `uid="uid://..."` 属性
- 脚本相对加载用 `get_script().resource_path.get_base_dir().path_join(...)`，且变量显式 `: String` 标注
- 搬运目录后删除 `*.import`，让 Godot 重新生成
- 依赖写在 `plugin.json` 的 `dependencies`（强制解析，缺失/环形阻塞不加载）
- 禁止硬编码 `res://plugins/...`、`res://mods/...`
