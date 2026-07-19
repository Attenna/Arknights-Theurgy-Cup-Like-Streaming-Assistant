# 远程通信代码Bug修复 - 产品需求文档

## Overview
- **Summary**: 修复项目中远程通信代码的多个关键bug，包括信号发射名称不匹配、会话Cookie管理缺失、登录成功检测逻辑缺陷等问题。
- **Purpose**: 解决登录流程失败、数据无法加载、信号无法传递等核心功能问题。
- **Target Users**: 项目开发人员和最终用户，修复后系统能够正常登录并获取玩家/解说员数据。

## Goals
- 修复所有EmitSignal信号名称大小写不匹配问题，使信号能够正确传递
- 添加完整的Cookie/Session管理机制，确保登录状态在请求间持续
- 改进登录成功检测逻辑，支持HTTP 302/303重定向响应
- 添加并发请求保护，防止状态机被破坏
- 增强CSRF Token提取的鲁棒性

## Non-Goals (Out of Scope)
- 不修改项目的UI布局或场景结构
- 不更改现有API端点地址
- 不添加新的功能模块
- 不修改Godot项目设置

## Background & Context
项目使用Godot 4 C#编写，通过HTTP请求与远程API通信。现有代码存在多个通信bug导致登录流程失败：
1. 信号名称大小写不匹配（PascalCase vs snake_case）
2. 缺少Cookie持久化机制
3. 登录成功检测不完整
4. 缺少并发请求保护

## Functional Requirements
- **FR-1**: 修复所有C#脚本中的EmitSignal调用，使用正确的信号名称格式
- **FR-2**: 在PlayerApiClient中实现Cookie提取、存储和发送机制
- **FR-3**: 改进登录响应处理，正确识别HTTP 302/303重定向作为成功登录
- **FR-4**: 在FetchPlayers方法中添加状态检查，防止并发请求
- **FR-5**: 增强CSRF Token提取逻辑，支持多种HTML格式

## Non-Functional Requirements
- **NFR-1**: 修复后的代码应保持与现有GDScript信号连接的兼容性
- **NFR-2**: 修复应最小化代码改动，保持原有逻辑结构
- **NFR-3**: 所有修复应通过编译验证

## Constraints
- **Technical**: Godot 4 C#环境，信号名称必须使用snake_case或SignalName常量
- **Dependencies**: 依赖Godot的HttpRequest节点进行HTTP通信

## Assumptions
- 远程API使用标准的set-cookie头进行会话管理
- 服务器登录成功后可能返回HTTP 302/303重定向
- CSRF Token可能以meta标签或隐藏input字段形式存在

## Acceptance Criteria

### AC-1: EmitSignal信号名称修复
- **Given**: C#脚本中有EmitSignal调用
- **When**: 信号被发射时
- **Then**: GDScript端使用snake_case连接的信号能够正确接收
- **Verification**: `human-judgment`

### AC-2: Cookie会话管理
- **Given**: 登录请求成功并返回set-cookie头
- **When**: 后续请求（获取玩家、获取队伍）发送时
- **Then**: 请求包含正确的Cookie头，服务器认证成功
- **Verification**: `programmatic`

### AC-3: 登录成功检测改进
- **Given**: 登录请求返回HTTP 302/303状态码
- **When**: 处理登录响应时
- **Then**: 正确识别为登录成功并继续后续请求
- **Verification**: `programmatic`

### AC-4: 并发请求保护
- **Given**: 当前正在执行请求链（获取CSRF/登录/获取数据）
- **When**: 再次调用FetchPlayers()时
- **Then**: 新请求被拒绝或排队，状态机不被破坏
- **Verification**: `programmatic`

### AC-5: CSRF Token提取增强
- **Given**: HTML响应中包含CSRF Token（meta标签或隐藏input）
- **When**: 提取CSRF Token时
- **Then**: 能够正确提取Token值，不受属性顺序影响
- **Verification**: `programmatic`

## Open Questions
- [ ] 服务器是否支持Cookie会话管理？（假设支持）
- [ ] CSRF Token的具体格式是什么？（支持多种格式）
