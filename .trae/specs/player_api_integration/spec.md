# 选手信息API集成 - 产品需求文档

## Overview
- **Summary**: 将 PlayerApiClient.cs 集成到冷水坑#3项目中，实现从远程服务器获取选手信息的功能。
- **Purpose**: 实现赛事直播导播软件的选手数据展示功能，支持从API获取选手和队伍信息。
- **Target Users**: 赛事导播人员，用于在直播画面中显示选手信息。

## Goals
- 成功将 PlayerApiClient.cs 集成到项目中
- 修复脚本中的编译错误
- 在主场景中正确配置 HTTPRequest 节点
- 实现选手信息的获取和回调机制

## Non-Goals (Out of Scope)
- 选手信息的UI展示（仅集成API客户端）
- 选手信息的编辑和管理功能
- 自动刷新选手信息

## Background & Context
- 项目使用 Godot 4.5 + C# + GDScript 混合开发
- PlayerApiClient.cs 是一个 HTTP 客户端，用于从 `https://lskb.cc.cd` 获取选手信息
- 需要通过 CSRF 认证和登录流程获取数据
- 项目已有 `dotnet` 配置和 C# 支持

## Functional Requirements
- **FR-1**: PlayerApiClient.cs 脚本能正确编译和运行
- **FR-2**: 主场景中正确配置 HTTPRequest 子节点供 PlayerApiClient 使用
- **FR-3**: 支持通过 credentials.txt 文件加载登录凭据
- **FR-4**: 实现完整的登录流程（获取CSRF -> 登录 -> 获取选手 -> 获取队伍）
- **FR-5**: 通过事件回调通知数据加载完成或失败

## Non-Functional Requirements
- **NFR-1**: 请求超时时间可配置（默认15秒）
- **NFR-2**: 错误处理完善，提供清晰的错误信息
- **NFR-3**: 资源清理，退出时正确断开事件绑定

## Constraints
- **Technical**: Godot 4.5, C# 10.0
- **Dependencies**: 需要远程服务器 `https://lskb.cc.cd` 可访问

## Assumptions
- 项目已正确配置 C# 开发环境
- HTTPRequest 节点已存在于场景中
- credentials.txt 文件需要用户手动创建

## Acceptance Criteria

### AC-1: 脚本编译通过
- **Given**: PlayerApiClient.cs 已修复并集成到项目
- **When**: 构建项目
- **Then**: 无编译错误
- **Verification**: `programmatic`

### AC-2: HTTPRequest 节点配置正确
- **Given**: 主场景已添加 PlayerApiClient 节点和 HTTPRequest 子节点
- **When**: 运行项目
- **Then**: PlayerApiClient 能正确获取 HTTPRequest 节点引用
- **Verification**: `programmatic`

### AC-3: 登录流程完整
- **Given**: 正确的登录凭据
- **When**: 调用 FetchPlayers()
- **Then**: 依次完成 CSRF 获取、登录、选手数据获取、队伍数据获取
- **Verification**: `human-judgment`

### AC-4: 事件回调正常工作
- **Given**: 监听 PlayersLoaded 和 LoadFailed 事件
- **When**: 数据加载成功或失败
- **Then**: 正确触发相应事件回调
- **Verification**: `programmatic`

## Open Questions
- [ ] 是否需要在控制面板中添加"刷新选手信息"按钮？
- [ ] 选手信息获取后如何与现有场景集成？
