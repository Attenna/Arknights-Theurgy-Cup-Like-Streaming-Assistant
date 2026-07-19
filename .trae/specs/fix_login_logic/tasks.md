# 登录功能修复 - Implementation Plan

## [x] Task 1: 修复 PlayerSelector 节点查找逻辑
- **Priority**: high
- **Depends On**: None
- **Description**: 
  - 修改 PlayerSelector.cs，使用更可靠的节点路径查找方式获取登录相关节点
  - 当前使用 GetParentOrNull 链可能因类型不匹配而失败，改为使用 GetNode 路径或更直接的引用方式
  - 登录节点在 VBoxContainer/LoginSection 下，需要正确遍历父级节点
- **Acceptance Criteria Addressed**: AC-1, AC-2, AC-3
- **Test Requirements**:
  - `human-judgement` TR-1.1: 登录按钮点击后应触发 OnLoginPressed 方法
  - `human-judgement` TR-1.2: 登录状态应显示 "Logging in..."
- **Notes**: 需要确保节点路径与 control_panel.tscn 中的结构一致

## [x] Task 2: 修改 main.gd 移除自动调用 FetchPlayers
- **Priority**: high
- **Depends On**: None
- **Description**: 
  - 修改 setup_player_api() 函数，移除自动调用 FetchPlayers()
  - 只进行信号连接和初始化，等待用户输入凭证后手动触发登录
- **Acceptance Criteria Addressed**: AC-4
- **Test Requirements**:
  - `human-judgement` TR-2.1: 应用启动后不应自动调用 API
  - `human-judgement` TR-2.2: 信息区域应显示 "Please login to view players"
- **Notes**: 需要保留信号连接，确保登录成功后能正确处理回调

## [x] Task 3: 验证登录流程完整性
- **Priority**: high
- **Depends On**: Task 1, Task 2
- **Description**: 
  - 确保 PlayerApiClient 的信号正确连接到 PlayerSelector
  - 确保登录成功后触发 PlayersUpdated 信号并更新 UI
  - 添加调试日志帮助排查问题
- **Acceptance Criteria Addressed**: AC-1, AC-2, AC-3
- **Test Requirements**:
  - `human-judgement` TR-3.1: 登录成功后显示绿色 "✓ Logged in"
  - `human-judgement` TR-3.2: 选手列表应正确显示在信息区域
  - `human-judgement` TR-3.3: 登录失败显示红色错误信息
- **Notes**: 需要验证完整的信号链路：LoginBtn -> OnLoginPressed -> SetCredentials -> FetchPlayers -> PlayersLoaded -> LoadPlayers -> PlayersUpdated -> UpdateInfoDisplay

## [x] Task 4: 构建验证
- **Priority**: high
- **Depends On**: Task 1, Task 2, Task 3
- **Description**: 
  - 构建项目确保代码编译通过
  - 验证没有编译错误和警告
- **Acceptance Criteria Addressed**: 所有 AC
- **Test Requirements**:
  - `programmatic` TR-4.1: dotnet build 应成功，0 警告 0 错误
- **Notes**: 确保所有 C# 文件都能正确编译
