# 登录功能修复 - Product Requirement Document

## Overview
- **Summary**: 修复 ControlPanel 中登录功能无法正常工作的问题，确保用户能在运行时输入账号密码并成功连接 API
- **Purpose**: 当前登录按钮点击后无响应，登录状态一直显示 "Not logged in"，需要排查并修复节点查找、信号连接和初始化时序问题
- **Target Users**: 使用 ControlPanel 的直播控制人员

## Goals
- 修复登录按钮点击无响应的问题
- 确保账号密码输入后能正确调用 API 登录
- 登录成功后正确更新 UI 状态并显示选手列表

## Non-Goals (Out of Scope)
- 修改 API 端点或认证方式
- 添加记住密码功能
- 添加多用户登录支持

## Background & Context
- 当前 ControlPanel 包含 LoginSection（账号密码输入）和 PlayerSelector（选手选择）
- PlayerSelector 需要从 LoginSection 获取输入框和按钮引用
- PlayerApiClient 需要运行时设置的账号密码才能调用 API
- main.gd 在初始化时会自动调用 FetchPlayers()，但此时没有凭证

## Functional Requirements
- **FR-1**: 用户点击登录按钮后，系统应读取账号密码并尝试登录 API
- **FR-2**: 登录成功后，UI 应显示成功状态并展示选手列表
- **FR-3**: 登录失败时，UI 应显示错误信息
- **FR-4**: 初始化时不应自动调用 FetchPlayers()，等待用户输入凭证

## Non-Functional Requirements
- **NFR-1**: 登录响应时间应在 15 秒内完成（已有超时设置）
- **NFR-2**: 密码输入框应隐藏输入内容

## Constraints
- **Technical**: 使用 Godot 4.5 + C#，节点路径必须与 tscn 文件一致
- **Dependencies**: PlayerApiClient 节点必须存在于 /root/Main/PlayerApiClient

## Assumptions
- API 服务正常运行
- 用户输入的账号密码正确有效

## Acceptance Criteria

### AC-1: 登录按钮点击后触发登录流程
- **Given**: 用户在账号和密码输入框中输入了有效凭据
- **When**: 用户点击登录按钮或按回车键
- **Then**: 登录状态应显示 "Logging in..."，并尝试连接 API
- **Verification**: `human-judgment`

### AC-2: 登录成功后更新状态
- **Given**: API 返回成功，选手数据加载完成
- **When**: 数据加载完成后
- **Then**: 登录状态应显示绿色 "✓ Logged in"，选手列表应显示在信息区域
- **Verification**: `human-judgment`

### AC-3: 登录失败显示错误信息
- **Given**: API 返回失败或超时
- **When**: 加载失败时
- **Then**: 登录状态应显示红色错误信息
- **Verification**: `human-judgment`

### AC-4: 初始化时不自动调用 API
- **Given**: 应用刚启动
- **When**: 用户还未输入账号密码
- **Then**: 不应自动调用 FetchPlayers()，信息区域应显示 "Please login to view players"
- **Verification**: `human-judgment`

## Open Questions
- [ ] 是否需要添加登录超时提示？
- [ ] 是否需要添加重新登录功能？
