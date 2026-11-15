# API 契约版本（api_version）

插件与内核之间的兼容性由 `api_version` 显式声明并由加载器强制校验。版本不兼容是**硬错误**：
插件被阻塞、不执行 `on_load`，不会出现"加载了一半"的状态。

## 当前版本

唯一权威来源是 `core/api_version.gd` 的 `ApiVersion.CURRENT`，当前为 **`2.0.0`**。
`kernel.gd` 的 `CORE_VERSION` 是内核自身版本，与 API 契约版本是两个概念。

## 版本语义（semver）

| 变更 | 版本位 | 例子 |
|---|---|---|
| 破坏性变更 | **major** | 删除 / 重命名清单字段、生命周期钩子、服务公开方法或信号；修改事件名 / payload 必填字段；修改数据 schema 语义 |
| 向后兼容新增 | **minor** | 新增可选清单字段、新事件、新服务方法、新钩子 |
| 向后兼容修正 | **patch** | 文档修正、实现修复，不改变契约 |

规则：同一 major 内，内核保证向后兼容；插件声明的最低版本不得高于内核版本。
跨 major 一律视为不兼容，除非插件显式放宽范围。

## 声明方式

`plugin.json` 的 `api_version` 是一个**范围**，支持空白分隔的比较式（全部满足才兼容）：

```json
"api_version": ">=2.0.0 <3.0.0"
```

支持的操作符：`>=`、`>`、`<=`、`<`、`=`。推荐始终写成显式上下界。

裸版本是简写，等价于同一 major 的闭开区间：

```json
"api_version": "2.0.0"
```

等价于 `>=2.0.0 <3.0.0`。低于声明版本的内核（如内核 `1.9.0`、插件 `2.0.0`）不兼容。

不支持 `^`、`~`、`*`、逗号分隔等写法；解析失败按不兼容处理。

## 加载行为

1. `PluginManager` 在依赖解析阶段校验每个清单：
   - 缺少 `api_version` → 阻塞，原因 `缺少 api_version（需声明兼容范围）`；
   - 范围非法或不满足 → 阻塞，原因 `API 版本不兼容: 声明 <范围>，核心 <版本>`；
   - 依赖了被阻塞插件的插件 → 传递阻塞。
2. 阻塞信息以 `push_error` 输出（可读的插件 id、声明范围、核心版本），并进入
   `PluginManager.get_blocked_plugins()`；不会注册任何场景 / 面板能力。
3. 直接调用 `_load_plugin`（热重载、测试、补加载）时再次校验；不兼容返回 `false`，
   热重载失败会回滚到旧注册。
4. 替换为兼容版本后按 `F5`（`reload_all`）会重试补加载被阻塞的插件，无需重启。

## 哪些东西属于契约

- `plugin.json` 的字段与语义（`provides.scenes` / `provides.panels`、`dependencies`、`watch` 等）；
- `Plugin` / `PluginScene` 的生命周期钩子与基类 getter；
- 内核服务的公开方法 / 信号：`EventBus`、`DataService`、`SceneDirector`、`PluginRegistry`、`FileWatcher`；
- `EventCatalog` 的事件名与 payload 契约；
- `DataKeys` 字段名与 `DataSchema` 的类型 / 必填 / 迁移语义。

插件内部的实现、私有方法、资源布局不属于契约，可自由调整。

## 升级流程

1. 修改契约时先判断变更级别（major / minor / patch）；
2. 更新 `ApiVersion.CURRENT`；
3. 同步本文件与 `framework/docs/插件开发指南.md`；
4. major 升级时，所有官方插件的 `api_version` 范围需要显式放宽或跟随升级；
5. 在 PR 中说明影响面（哪些插件会被阻塞）。

## 迁移说明

阶段 2 之前 `api_version` 只是展示字段，不参与校验。现在缺失或不可解析都会阻塞加载；
存量插件请补上显式范围（推荐 `>=2.0.0 <3.0.0`）。
