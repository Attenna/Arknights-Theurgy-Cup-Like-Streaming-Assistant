# 远程通信代码Bug修复 - 实现计划

## [x] Task 1: 修复PlayerApiClient.cs中的EmitSignal信号名称
- **Priority**: high
- **Depends On**: None
- **Description**: 
  - 将所有`EmitSignal("LoadFailed", ...)`改为`EmitSignal("load_failed", ...)`
  - 将所有`EmitSignal("PlayersLoaded", ...)`改为`EmitSignal("players_loaded", ...)`
- **Acceptance Criteria Addressed**: AC-1
- **Test Requirements**:
  - `programmatic` TR-1.1: 代码编译成功，无信号名称相关错误
  - `human-judgment` TR-1.2: 验证所有EmitSignal调用已使用snake_case格式

## [x] Task 2: 修复PlayerManager.cs和CommentatorManager.cs中的EmitSignal信号名称
- **Priority**: high
- **Depends On**: None
- **Description**: 
  - PlayerManager.cs: 将`EmitSignal("PlayerSelected", ...)`改为`EmitSignal("player_selected", ...)`，将`EmitSignal("PlayersUpdated", ...)`改为`EmitSignal("players_updated", ...)`
  - CommentatorManager.cs: 将`EmitSignal("CommentatorSelected", ...)`改为`EmitSignal("commentator_selected", ...)`，将`EmitSignal("CommentatorsUpdated", ...)`改为`EmitSignal("commentators_updated", ...)`
- **Acceptance Criteria Addressed**: AC-1
- **Test Requirements**:
  - `programmatic` TR-2.1: 代码编译成功
  - `human-judgment` TR-2.2: 验证所有EmitSignal调用已使用snake_case格式

## [x] Task 3: 修复PlayerSelector.cs中的EmitSignal信号名称
- **Priority**: high
- **Depends On**: None
- **Description**: 
  - 将`EmitSignal("PlayerSelected", ...)`改为`EmitSignal("player_selected", ...)`
  - 将`EmitSignal("CommentatorSelected", ...)`改为`EmitSignal("commentator_selected", ...)`
  - 将`EmitSignal("LoginStatusChanged", ...)`改为`EmitSignal("login_status_changed", ...)`
- **Acceptance Criteria Addressed**: AC-1
- **Test Requirements**:
  - `programmatic` TR-3.1: 代码编译成功
  - `human-judgment` TR-3.2: 验证所有EmitSignal调用已使用snake_case格式

## [x] Task 4: 添加Cookie会话管理机制
- **Priority**: high
- **Depends On**: Task 1
- **Description**: 
  - 在PlayerApiClient.cs中添加`_cookieHeader`字段
  - 在HandleLoginResponse中提取session cookie值并存储
  - 在FetchPlayers和FetchTeams请求中添加Cookie头
- **Acceptance Criteria Addressed**: AC-2
- **Test Requirements**:
  - `programmatic` TR-4.1: 代码编译成功
  - `human-judgment` TR-4.2: 验证Cookie头在登录后被正确提取和使用

## [x] Task 5: 改进登录成功检测逻辑
- **Priority**: medium
- **Depends On**: Task 1
- **Description**: 
  - 修改HandleLoginResponse，将HTTP 302/303状态码视为成功登录
  - 添加对重定向响应中Cookie的处理
- **Acceptance Criteria Addressed**: AC-3
- **Test Requirements**:
  - `programmatic` TR-5.1: 代码编译成功
  - `human-judgment` TR-5.2: 验证登录响应处理逻辑包含302/303状态码

## [x] Task 6: 添加并发请求保护
- **Priority**: medium
- **Depends On**: Task 1
- **Description**: 
  - 在FetchPlayers方法开头添加状态检查
  - 如果`_state != RequestState.Idle`，拒绝新请求并发出警告
- **Acceptance Criteria Addressed**: AC-4
- **Test Requirements**:
  - `programmatic` TR-6.1: 代码编译成功
  - `human-judgment` TR-6.2: 验证状态检查逻辑正确

## [x] Task 7: 增强CSRF Token提取逻辑
- **Priority**: medium
- **Depends On**: None
- **Description**: 
  - 修改ExtractCsrfToken方法，支持隐藏input字段格式（`<input type="hidden" name="csrf_token" value="...">`）
  - 支持meta标签属性的任意顺序
- **Acceptance Criteria Addressed**: AC-5
- **Test Requirements**:
  - `programmatic` TR-7.1: 代码编译成功
  - `human-judgment` TR-7.2: 验证正则表达式支持多种CSRF Token格式
