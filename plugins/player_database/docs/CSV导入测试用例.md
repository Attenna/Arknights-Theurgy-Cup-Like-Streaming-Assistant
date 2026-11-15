# CSV 导入测试用例

> 插件：`player_database` v1.0.0
> 测试日期：2026-10-25
> 环境：Godot 4.5.1 mono / Windows x86_64 / godot-sqlite v4.7
> 数据库：`userdata/player_database/player_database.db`
> CSV 目录：`userdata/player_database/csv/`
> CSV 文件：`players.csv` / `teams.csv` / `announcers.csv`

---

## 1. 目的与范围

验证用户通过 CSV 批量写入选手、队伍、解说时的以下行为：

1. 标准表头与中文别名表头均可正确映射到契约字段。
2. 新增加的列无需改代码即可自适应保存，并能随 JSON / CSV 导出。
3. 合并导入只覆盖 CSV 中出现的列，未出现列保留，空单元格清空。
4. 异常数据（缺 id、悬空队伍、非法数值、重复表头）有明确告警且不阻断其它行。
5. CSV 导入后契约 JSON、DataService、直播场景与当前选中状态保持正确。

不覆盖：Excel「Unicode 文本（UTF-16）」、任意新建实体表、超大 CSV 性能压测。

---

## 2. 前置条件

- `player_database` 与 `control_panel_base` 插件已加载，数据页可见。
- 测试数据自带队伍 `csv_t1`；先导入 `teams.csv`，再导入 `players.csv`，保证队伍引用可解析。
- 样例 CSV 位于 `mods/player_database/docs/csv_testdata/`，可直接复制到
  `userdata/player_database/csv/` 后点「从 CSV 导入」。
- 测试统一使用 `csv_` 前缀的 id，便于清理。
- 每次执行前建议清空 CSV 目录中的旧测试文件，避免行间干扰。

---

## 3. 测试数据

> 以下三个 CSV 已作为真实文件随插件提供：
> `mods/player_database/docs/csv_testdata/players.csv`、
> `teams.csv`、`announcers.csv`（均带 UTF-8 BOM）。
> 其中包含故意保留的异常行（缺 id、悬空队伍），用于验证 `issues` 告警。

### 3.1 players.csv（中文别名 + 扩展列 + 异常行）

```csv
id,姓名,队伍,是否队长,开局干员,积分,取钱,感言,备注,评级
csv_p1,CSV选手一,csv_t1,是,银灰,150,20,"感言,含逗号",备注一,A
csv_p2,CSV选手二,no_team,否,闪灵,80,10,,备注二,B
,缺id,,0,,,,,,
```

### 3.2 teams.csv

```csv
id,队名,资金,排名,备注
csv_t1,CSV队伍,777,2,队伍备注
```

### 3.3 announcers.csv

```csv
id,名称,头像路径,备注
csv_a1,CSV解说,,解说备注
```

### 3.4 执行方式

面板：数据页 →「从 CSV 导入（合并）」。

也可以直接把 `docs/csv_testdata/` 下的三个 CSV 复制到
`userdata/player_database/csv/`（覆盖同名文件）后导入。

代码：

```gdscript
var service = get_tree().get_first_node_in_group(&"player_database_service")
var result = service.call("import_from_csv")
print(result)
```

---

## 4. 用例清单

| 编号 | 优先级 | 场景 | 预期摘要 | 本次结果 |
|------|--------|------|----------|----------|
| CSV-001 | P0 | 生成 CSV 模板 | 新建 3 个带 BOM 的表头文件，不覆盖已有文件 | 通过 |
| CSV-002 | P0 | 英文表头导入 | 选手 / 队伍 / 解说字段正确入库 | 通过 |
| CSV-003 | P0 | 中文别名导入 | `姓名/队伍/队长/开局干员/积分/取钱/感言` 正确映射 | 通过 |
| CSV-004 | P1 | 分号 / 制表符分隔 | 自动识别分隔符并正确解析 | 通过 |
| CSV-005 | P1 | 引号内逗号 / 换行 / BOM / CRLF | 字段内容完整保留，不串行 | 通过 |
| CSV-006 | P0 | 队伍与解说批量导入 | 对应表新增记录，扩展列入库 | 通过 |
| CSV-007 | P0 | 新增列自适应 | 未识别表头写入 `extra_json`，无需改代码 | 通过 |
| CSV-008 | P0 | 扩展列进入 JSON | `players.json` 等导出包含扩展键 | 通过 |
| CSV-009 | P1 | 扩展列进入 CSV 导出 | 导出表头包含扩展列，可再次导入 | 通过 |
| CSV-010 | P0 | 部分更新保留 | 只覆盖 CSV 出现的列，其它字段与扩展列保留 | 通过 |
| CSV-011 | P0 | 空单元格清空 | 队伍 / 积分 / 感言 / 扩展列清空；`name` 例外 | 通过 |
| CSV-012 | P1 | 未出现列保留 | 第二次 CSV 未写姓名、取钱时原值不变 | 通过 |
| CSV-013 | P1 | `members` 列 | 导入时忽略，成员仍由选手 `team_id` 派生 | 通过 |
| CSV-014 | P0 | 缺 `id` 行 | 跳过该行并写入 `issues`，其它行继续 | 通过 |
| CSV-015 | P0 | 悬空 `team_id` | 清空该选手队伍引用并写入 `issues` | 通过 |
| CSV-016 | P1 | 非法数值 | 积分按 0、队长按 0、队伍排名按 null，并告警 | 通过 |
| CSV-017 | P2 | 重复表头映射 | 后者覆盖前者，并产生重复映射告警 | 通过 |
| CSV-018 | P1 | 无 CSV 文件 | 返回 `ok=false` 与「未找到 CSV 文件」提示 | 通过 |
| CSV-019 | P1 | 面板按钮与状态 | 导入 / 模板 / 导出 / 刷新均有状态反馈 | 通过 |
| CSV-020 | P0 | 契约同步与场景 | `DataService` 可读到新数据，直播场景正常显示 | 通过 |
| CSV-021 | P1 | 当前选中 | 导入不改变当前选中；当前选手数据更新后同步导出 | 通过 |

---

## 5. 详细用例

### CSV-001 生成 CSV 模板

**步骤**

1. 数据页点击「导出 CSV 模板」。
2. 点击「打开 CSV 目录」查看文件。
3. 再次点击「导出 CSV 模板」。

**预期**

- 首次生成 `players.csv`、`teams.csv`、`announcers.csv` 三个文件。
- 文件带 UTF-8 BOM，仅含表头，无数据行。
- 第二次不覆盖已有文件，`created` 为空。
- 状态栏显示 CSV 目录与新建数量。

---

### CSV-002 英文表头标准导入

**输入**：`id,name,team_id,captain,icon_path,starting_operator_choice,starting_relic_choice,starting_squad_choice,score,money_taken,slogan`

**预期**

- `get_player(id)` 返回对应字段。
- `captain` 的 `1/0` 转为整数；`score/money_taken` 转为整数。
- `slogan` 写入 `stats.slogan`。

---

### CSV-003 中文别名导入

**输入**：3.1 的 `players.csv`。

**预期**

- `姓名 → name`、`队伍 → team_id`、`是否队长 → captain`、`开局干员 → starting_operator_choice`。
- `积分 → stats.score`、`取钱 → stats.money_taken`、`感言 → stats.slogan`。
- `csv_p1` 的队长为 1，积分为 150，取钱为 20。

---

### CSV-004 分号 / 制表符分隔

**输入示例**

```csv
id;名称;备注
csv_a2;解说二;备注A
```

```csv
id	队名	资金	排名
csv_t2	队伍二	500	1
```

**预期**

- 分号与制表符均被自动识别。
- 解说与队伍字段正确入库，扩展列正常保存。

---

### CSV-005 引号内逗号 / 换行 / BOM / CRLF

**输入**

```csv
id,姓名,感言
csv_p3,选手三,"第一行
第二行"
```

**预期**

- `感言` 保留内部换行，不拆成两行。
- 含逗号的字段（如 `"感言,含逗号"`）完整保留。
- 文件带 UTF-8 BOM、CRLF 时解析正常。

---

### CSV-006 队伍与解说批量导入

**输入**：3.2、3.3。

**预期**

- `get_team("csv_t1")` 资金 777、排名 2、扩展列 `备注=队伍备注`。
- `get_announcer("csv_a1")` 名称与扩展列正确。
- `counts.teams=1`、`counts.announcers=1`。

---

### CSV-007 新增列自适应

**输入**：players.csv 增加 `备注,评级` 两列。

**预期**

- 数据库无需改表，扩展列写入 `extra_json`。
- `get_player("csv_p1")` 可直接读到 `备注=备注一`、`评级=A`。
- 再次导入只写 `评级` 时，`备注` 保留。

---

### CSV-008 扩展列进入 JSON

**步骤**：导入后调用 `export_to_json` 或等待自动同步，读取 `players.json`。

**预期**

- `csv_p1` 条目包含 `"备注": "备注一"`、`"评级": "A"`。
- `DataService.get_players()` 同样可读到扩展键。
- 现有使用 `DataKeys` 的插件不受影响（未知键被忽略）。

---

### CSV-009 扩展列进入 CSV 导出

**步骤**：点击「导出当前数据为 CSV」，打开 `players.csv`。

**预期**

- 表头包含 `备注,评级` 等扩展列。
- 数据行包含对应值。
- 文件带 UTF-8 BOM。
- 再次导入无新增问题，数据保持一致。

---

### CSV-010 部分更新保留

**输入**

```csv
id,姓名,评级
csv_p1,CSV选手一改,S
```

**预期**

- 姓名更新为 `CSV选手一改`，评级更新为 `S`。
- 积分 150、取钱 20、备注 `备注一` 保留。
- 导出 JSON 同步更新。

---

### CSV-011 空单元格清空

**输入**

```csv
id,队伍,积分,感言,备注
csv_p3,,,,
```

**预期**

- `team_id` 变为空，积分变为 0。
- `slogan` 清空；JSON 中可省略该字段。
- 扩展列 `备注` 变为空字符串。
- 未出现的姓名、取钱保持原值。
- `name` / `id` 为空会导致该行校验失败并跳过，不会“清空姓名”。

---

### CSV-012 未出现列保留

**预期**

- CSV 中没有的表头对应的数据库字段不被修改。
- 扩展列同理：未出现的扩展键保留旧值。

---

### CSV-013 `members` 列

**前置**：先导入一支队伍 `csv_t2`。

**输入**

```csv
id,队名,members
csv_t2,队伍二,csv_p3|fake
```

**预期**

- 队伍名更新。
- 队伍成员仍由 `players.team_id` 派生，`members` 列的 `fake` 不会写入。
- `members` 不会成为扩展列。

---

### CSV-014 缺 `id` 行

**预期**

- 该行跳过，不写入数据库。
- `issues` 包含「缺少 id」。
- 其它行继续导入。
- 整体 `ok=false`，但已成功行仍已写入并同步 JSON。

---

### CSV-015 悬空 `team_id`

**预期**

- 该选手仍导入，但 `team_id` 被清空。
- `issues` 包含「队伍不存在」。
- 导出 JSON 中该选手队伍为空。

---

### CSV-016 非法数值

**输入**

players.csv：

```csv
id,姓名,积分,队长
csv_p4,选手四,abc,maybe
```

teams.csv：

```csv
id,队名,排名
csv_t2,队伍二,xyz
```

**预期**

- 选手积分按 0，队长按 0。
- 队伍排名按 null（可空整数）。
- `issues` 分别提示数值 / 布尔值无法识别。

---

### CSV-017 重复表头映射

**输入**

```csv
id,姓名,编号
csv_p5,选手五,csv_p5
```

**预期**

- `id` 与 `编号` 都映射到 id。
- `issues` 提示重复映射，后者覆盖前者。
- 建议实际使用时不重复映射同一字段。

---

### CSV-018 无 CSV 文件

**步骤**：清空 CSV 目录后点击导入。

**预期**

- 返回 `ok=false`。
- 错误信息包含「未找到 CSV 文件」与期望目录。
- 数据库不发生任何修改。

---

### CSV-019 面板按钮与状态

**步骤**

1. 数据页依次点击「从 CSV 导入（合并）」「导出 CSV 模板」「导出当前数据为 CSV」「刷新状态」。

**预期**

- 导入状态显示选手 / 队伍 / 解说数量与新建数量。
- 模板与导出按钮有成功状态。
- CSV 路径标签显示实际目录。
- 问题数据在状态栏显示前 3 条 `issues`。

---

### CSV-020 契约同步与场景

**前置**：已通过面板或 CSV 更新一名选手，并在面板中「设为当前」。

**步骤**

1. 通过 CSV 导入或修改当前选手。
2. 切换/打开 `streaming_arena` 场景。

**预期**

- `players.json` / `teams.json` / `current_player.json` / `current_announcer.json` 自动更新。
- `DataService.get_players()` 返回 CSV 数据。
- 直播场景左侧 ID 栏显示当前选手，不出现 `Unknown Player`。
- `data_reloaded` / `player_changed` / `announcer_changed` 事件正常分发。

---

### CSV-021 当前选中

**预期**

- CSV 导入本身不改变当前选手 / 解说。
- 若 CSV 更新了当前选手的姓名、队伍、积分等字段，导入后的 `current_player.json` 随之更新。
- 删除当前选手仍需通过面板或接口操作，CSV 导入不会隐式删除记录。

---

## 6. 本次执行记录

| 检查项 | 结果 |
|--------|------|
| CSV 全链路检查（38 项） | 全部通过 |
| CSV 边界检查（26 项） | 全部通过 |
| 随包样例 CSV 本体导入（11 项） | 全部通过 |
| CSV 解析器单元检查（分隔符 / 引号 / CRLF / 转义） | 通过 |
| 核心契约测试 `res://tests/test_main.tscn`（5 个文件） | 全部通过 |
| 无头冒烟启动 | 通过，仅有无头模式已知伪错误 `Window spawned at invalid position` |
| `--scene streaming_arena` | 通过，当前选手与解说正常读取 |
| 导出纯核心 + 外部 `mods/` 插件加载 | 通过，原生扩展与 `csv_codec.gd` preload 正常 |
| 插件热重载（数据库关闭 / 重开） | 通过 |
| 插件打包 | 通过，zip 顶层为 `player_database/` |

> 说明：以上 CSV 自动化检查为临时验证场景，执行后已清理；本仓库的常驻契约测试仍为 `tests/test_main.tscn`。

---

## 7. 已知限制

1. **扩展列按文本保存**：`备注`、`评级` 等新列写入 `extra_json` 时为字符串；需要数字类型请用 JSON 导入。
2. **不自动建实体表**：只支持 `players` / `teams` / `announcers` 三类；新增 CSV 文件名不会自动建新表。
3. **不自动后台导入**：CSV 放入目录后需点击「从 CSV 导入」或调用接口；启动时只做 JSON 合并导入。
4. **`name` 不能清空**：空姓名行会被校验拒绝；如需改名请填写新名称。
5. **`members` 只导出**：队伍成员以选手 `team_id` 为准，CSV 的 `members` 列不作为导入依据。
6. **编码**：仅支持 UTF-8（含 BOM）；Excel 的「Unicode 文本（UTF-16）」需另存为 CSV UTF-8。
7. **大文件**：未做性能压测；建议单次控制在数千行以内。
8. **重复导入幂等**：同一份 CSV 重复导入结果一致，但 `counts.changed` 仍按处理行数统计。

---

## 8. 回归执行清单

```powershell
# 1. 导入资源
D:\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64_console.exe --headless --path . --import

# 2. 核心契约测试
D:\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64_console.exe --headless --path . res://tests/test_main.tscn

# 3. 无头冒烟
D:\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64_console.exe --headless --path . --quit-after 300

# 4. 直播场景
D:\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64_console.exe --headless --path . --quit-after 300 -- --scene streaming_arena

# 5. 打包插件
.\export_mods.ps1 -Name player_database
```

手工 CSV 回归：按第 3 节数据导入 → 检查面板三个列表 → 导出 JSON / CSV → 再次导入 → 检查状态与问题列表。
