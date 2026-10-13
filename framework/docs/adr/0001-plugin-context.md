# ADR-0001：PluginContext 插件服务访问层（issue #2）

状态：**已实施（2026-10-13）** ｜ 关联：[架构演进路线.md](../架构演进路线.md) 铁律 2、issue #2、issue #3 ｜ 日期：2026-10-13

## 背景

插件获取内核服务的现状是各处硬编码 autoload 路径 `get_node_or_null("/root/Kernel")`。
`git grep "root/Kernel" -- '*.gd'` 实测 21 行命中，其中**代码 13 处**（文档/注释 8 处不计）：

| 位置 | 处数 | 说明 |
|------|------|------|
| `core/plugin.gd:79` | 1 | Plugin 基类 `get_kernel()`（访问层雏形，实现仍是路径硬编码） |
| `core/mod_loader.gd:12` | 1 | 兼容别名层 `_kernel()`（autoload，非 Plugin 派生） |
| `core/plugin_scene.gd:99` | 1 | PluginScene 契约 `_get_data_service()`（extends Node2D，非 Plugin 派生） |
| `mods/_template/plugin.gd:29` | 1 | 模板 `_ctx()`（line 7 注释自述为过渡期写法） |
| `mods/control_panel_base/panels/control_panel.gd:44` | 1 | 基底面板 `_mount_all()`（extends Window，非 Plugin 派生） |
| `mods/scene_manager_panel/plugin.gd:43` | 1 | 二级面板插件入口 |
| `mods/scene_manager_panel/panels/scene_manager_panel.gd:13,21,31,58` | 4 | 面板脚本（extends VBoxContainer，非 Plugin 派生） |
| `src/scripts/main/main.gd:26,66,122` | 3 | 引导壳装配层（**白名单豁免**，见影响面） |

问题：路径字符串散落、无法机械化拦截（CI grep 无法区分「合法访问层实现点」与「违例」）、
非 Plugin 派生脚本（面板 UI、场景根节点）没有统一访问入口。

## 方案

1. **新增 `core/plugin_context.gd`**（`class_name PluginContext extends RefCounted`）：
   - `const KERNEL_GROUP := "kernel"`（组名常量化，铁律 3 精神延伸）；
   - `_init(kernel: Node)` 持有内核引用，构造时填充只读属性：
     `kernel` / `event_bus` / `data_service` / `scene_director` / `plugin_registry` /
     `file_watcher` / `plugin_manager` / `core_version`（与 issue 契约
     `context.scene_director / context.event_bus` 一致，属性式访问）；
   - 静态兜底入口 `PluginContext.for_node(node) -> PluginContext`：经
     `node.get_tree().get_first_node_in_group(KERNEL_GROUP)` 查找构造——
     **不出现任何节点路径字符串**，覆盖 PluginScene、面板等非 PluginManager 创建的
     脚本与 F6 场景预览场景；内核不存在时各属性为 null（空安全）。
2. **Kernel 入组**：`core/kernel.gd` 的 `_ready()` 增加
   `add_to_group(PluginContext.KERNEL_GROUP)`。autoload `_ready` 先于主场景与任何
   插件加载执行，组查找时机早于全部使用点。
3. **Plugin 基类暴露上下文**（`core/plugin.gd`）：
   - `var context: PluginContext`（由 PluginManager 注入）；
   - 现有 `get_kernel()` / `get_event_bus()` / `get_data_service()` 改走 context
     （内部 `context` 为空时经 `PluginContext.for_node(self)` 兜底重建并回填）；
   - 新增 `get_scene_director()` / `get_plugin_registry()` / `get_file_watcher()` /
     `get_plugin_manager()` 便捷 getter；
   - **向后兼容**：存量 getter 签名不变，旧插件代码无需改动即可继续工作。
4. **注入点**（`core/plugin_manager.gd`）：`_instantiate_entry()` 内 `set_script` 成功后
   `node.set("context", PluginContext.new(self))`。该函数是**唯一实例创建点**
   （初载 :78、热重载 :521、阻塞补载 :617 三路径均经 `_load_plugin:287` →
   `_instantiate_entry:354`），注入一处即覆盖全部生命周期路径。
5. **存量迁移**（代码 13 处中迁移 10 处、白名单 3 处）：
   - `core/plugin.gd:79`：实现改走 context（自身即访问层，经注入不再硬编码）；
   - `core/mod_loader.gd:12`：`_kernel()` 改为组查找（autoload 非 Plugin，无法注入）；
   - `core/plugin_scene.gd:99`：`_get_data_service()` 改走
     `PluginContext.for_node(self).data_service`；
   - `mods/control_panel_base/panels/control_panel.gd:44`、
     `mods/scene_manager_panel/panels/scene_manager_panel.gd`（4 处）：
     非 Plugin 派生面板脚本，改走 `PluginContext.for_node(self)`；
   - `mods/scene_manager_panel/plugin.gd:43`：Plugin 派生，改走基类 getter；
   - `mods/_template/plugin.gd`：`_ctx()` 删除，line 7-8 注释改为正式约定
     （「服务一律经 `context` / 基类 getter 获取」）；
   - `src/scripts/main/main.gd`（3 处）：**不动**。引导壳负责装配 Kernel 本体，
     属 CI 白名单（issue #3：`core/`、`src/`），非插件代码。
6. **CI 联动**（issue #3）：workflow 建立时 `/root/Kernel` 禁令对 `mods/` 设为
   **warn**（存量未清）；本迁移合入后 `mods/` 命中清零，同批将规则升为 **error**；
   `core/` 因组查找实现亦无路径字符串，白名单仅剩 `src/` 引导壳 3 处。
7. **文档同步**：`framework/docs/插件开发指南.md:149` 示例更新；
   `framework/docs/架构演进路线.md` 铁律 2 过渡期注记删除；
   `AGENTS.md` 铁律 2 过渡期注记删除（issue #2 验收项）。

## 影响面

- `core/plugin_context.gd`（新增，约 40 行）
- `core/kernel.gd`（+1 行入组）
- `core/plugin.gd`（context 属性 + getter 改造，签名不变）
- `core/plugin_manager.gd`（注入 1 处）
- `core/mod_loader.gd`、`core/plugin_scene.gd`（内部获取改造）
- `mods/`：control_panel_base、scene_manager_panel、_template 共 7 处
- 文档：插件开发指南、架构演进路线、AGENTS.md
- `api_version`：纯增量（新类 + 新属性 + 新 getter，存量签名不变），维持 2.0.0

## 备选被否

- **继续 `/root/Kernel` 硬编码 + CI 仅 warn**：路径字符串永远无法清零，
  grep 无法区分实现点与违例，铁律 2 形同虚设；
- **autoload PluginContext 单例**：上下文生命周期应跟随插件实例（热重载语义），
  单例无法表达「每个插件自己的上下文」，且面板等非 Plugin 脚本无法被注入；
- **ServiceRegistry 登记制**：决策顺序三项未全满足——服务获取本质是「入口封装」，
  Kernel 装配已存在，缺的只是访问入口，不构成引入新注册服务的理由；
- **面板/场景脚本改为 extends Plugin**：破坏 UI 契约（Window / VBoxContainer /
  Node2D 基类不可更换），改动面远大于收益。

## 验收（对齐 issue #2）

- [x] 本 ADR 评审合入
- [x] `mods/` 与 `core/` 中 `/root/Kernel` 硬编码清零（`git grep` 证明，白名单仅 `src/` 3 处）
- [x] 全插件无头冒烟 + `--scene streaming_arena` 验证通过（三插件加载、二级面板挂载、场景进入无 SCRIPT ERROR）
- [x] AGENTS.md 铁律 2 过渡期注记删除
- [x] CI 禁令（issue #3 workflow）对 `mods/`、`core/` 生效为 error
