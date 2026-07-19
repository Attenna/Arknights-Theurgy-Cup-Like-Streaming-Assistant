# 选手信息API集成 - 实现计划

## [x] Task 1: 修复 PlayerApiClient.cs 编译错误
- **Priority**: high
- **Depends On**: None
- **Description**: 
  - 修复第151行的 `HttpClient.Method.Post` 错误，改为 `HttpRequest.Method.Post`
  - 检查其他可能的编译错误
- **Acceptance Criteria Addressed**: [AC-1]
- **Test Requirements**:
  - `programmatic` TR-1.1: 脚本编译无错误
  - `human-judgement` TR-1.2: 代码逻辑正确，无明显语法错误
- **Notes**: Godot 4 中 HTTP 请求使用 HttpRequest 类而非 HttpClient

## [/] Task 2: 在 Main.tscn 中添加 PlayerApiClient 节点
- **Priority**: high
- **Depends On**: Task 1
- **Description**: 
  - 在 Main.tscn 中添加 PlayerApiClient 节点作为 HTTPRequest 的父节点
  - 确保 HTTPRequest 节点路径正确（PlayerApiClient/HTTPRequest）
- **Acceptance Criteria Addressed**: [AC-2]
- **Test Requirements**:
  - `programmatic` TR-2.1: 运行时 PlayerApiClient 能正确获取 HTTPRequest 引用
  - `human-judgement` TR-2.2: 场景结构正确，节点层级清晰
- **Notes**: 当前 Main.tscn 已有 HTTPRequest 节点，但路径需要调整

## [ ] Task 3: 在 main.gd 中集成 PlayerApiClient
- **Priority**: medium
- **Depends On**: Task 2
- **Description**: 
  - 在 main.gd 中获取 PlayerApiClient 节点引用
  - 连接 PlayersLoaded 和 LoadFailed 事件
  - 在 _ready 中调用 FetchPlayers()
- **Acceptance Criteria Addressed**: [AC-4]
- **Test Requirements**:
  - `programmatic` TR-3.1: 事件连接成功，数据加载时触发回调
  - `human-judgement` TR-3.2: 集成逻辑合理，不阻塞主流程
- **Notes**: 需要处理 GDScript 和 C# 的互操作

## [x] Task 4: 创建 credentials.txt 示例文件
- **Priority**: low
- **Depends On**: None
- **Description**: 
  - 创建示例凭据文件，包含 username 和 password 字段
  - 文件放置在 user:// 目录
- **Acceptance Criteria Addressed**: [AC-3]
- **Test Requirements**:
  - `human-judgement` TR-4.1: 文件格式正确，能被 PlayerApiClient 正确读取
- **Notes**: 用户需要替换为真实凭据
