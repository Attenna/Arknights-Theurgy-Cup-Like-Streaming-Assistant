# 修复认证流程计划

## 问题分析

### 核心问题
1. **HTTP Basic Auth 不被支持**：服务器返回登录页面HTML而非JSON，说明服务器使用session-based认证
2. **并发请求**：`FetchPlayers()` 被调用了两次，状态机在第一次请求未完成时收到第二次调用
3. **Cookie未正确传递**：登录后获取的session cookie没有被正确保存和传递给后续API请求

### 日志证据
```
Content-Type: text/html; charset=utf-8
Set-Cookie: session=eyJjc3JmX3Rva2VuIjoiODE2YjM3NThiNjY0YmJjNzJhNTUxMmNkNDZlM2E3ZjQyNjhmODliYyJ9...
```

服务器明确使用session cookie进行认证，而非HTTP Basic Auth。

## 修复方案

### 恢复完整的登录流程
恢复原来的四步状态机：
1. **Idle** → 请求登录页面获取CSRF token
2. **GetCsrf** → 提取CSRF token后发送登录请求
3. **Login** → 登录成功后提取session cookie，请求玩家数据
4. **FetchPlayers** → 请求玩家数据
5. **FetchTeams** → 请求队伍数据

### 修复并发请求问题
- 在 `FetchPlayers()` 入口检查状态，如果非Idle则直接返回，不发出load_failed信号（避免重复错误提示）
- 确保只有用户点击登录按钮时才触发请求

### 文件修改

#### 1. PlayerApiClient.cs
- 恢复 `_csrfToken` 和 `_cookieHeader` 字段
- 恢复完整的状态机（Idle, GetCsrf, Login, FetchPlayers, FetchTeams）
- 恢复 `HandleCsrfResponse()` 和 `HandleLoginResponse()` 方法
- 每个请求都带上Cookie头
- 简化并发请求处理（只打印警告，不触发错误信号）

#### 2. PlayerSelector.cs
- 确保只在用户点击登录按钮时调用 `FetchPlayers()`
- 检查 `FetchPlayers()` 返回前是否已有请求在进行

## 实施步骤

### Step 1: 修改 PlayerApiClient.cs
1. 恢复 `_csrfToken` 和 `_cookieHeader` 字段
2. 恢复完整的状态机枚举
3. 实现 `HandleCsrfResponse()` 方法（提取CSRF token）
4. 实现 `HandleLoginResponse()` 方法（提取session cookie）
5. 修改 `FetchPlayers()` 方法（先获取CSRF，再登录）
6. 修改 `HandlePlayersResponse()` 和 `HandleTeamsResponse()`（带上Cookie头）

### Step 2: 修改 PlayerSelector.cs
1. 在 `OnLoginPressed()` 中添加状态检查
2. 确保不会重复触发登录

### Step 3: 编译验证
- 运行 `dotnet build` 确保编译通过

## 风险评估
- **低风险**：恢复原有流程，只是修复了之前的bug
- **中等风险**：如果服务器CSRF token格式变化，可能需要调整正则表达式

## 预期结果
- 用户输入账号密码后，点击登录
- 系统自动完成：获取CSRF → 登录 → 获取session cookie → 请求API数据
- 不再出现并发请求错误
- API返回正确的JSON数据