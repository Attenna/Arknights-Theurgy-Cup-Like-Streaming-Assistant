# GitHub 上传指南

## 📋 上传步骤

您需要在命令行中按顺序执行以下命令：

### 1. 切换到项目目录

```bash
cd "c:\Users\duck1\Desktop\演播室2"
```

### 2. 配置Git用户信息

```bash
git config user.name "Attenna"
git config user.email "george_5298@outlook.com"
```

### 3. 检查Git状态

```bash
git status
```

### 4. 添加所有文件到暂存区

```bash
git add .
```

### 5. 创建初始提交

```bash
git commit -m "Initial commit: Arknights Theurgy Cup Like Streaming Assistant

- Complete Godot-based streaming assistant for Arknights tournaments
- Player, team, and announcer management systems
- Real-time UI updates with signal-based communication
- Image loading system for player icons, team logos, operator portraits
- Opening relic display system with detailed descriptions
- Left ID bar with player information display
- Score tracking and team balance management
- Multi-language support (Chinese)
- Apache 2.0 licensed"
```

### 6. 添加GitHub远程仓库

```bash
git remote add origin https://github.com/Attenna/Arknights-Theurgy-Cup-Like-Streaming-Assistant.git
```

### 7. 设置主分支

```bash
git branch -M main
```

### 8. 推送到GitHub

```bash
git push -u origin main
```

## ⚠️ 注意事项

1. **确保GitHub仓库已创建**: 请先在GitHub网站上创建名为 `Arknights-Theurgy-Cup-Like-Streaming-Assistant` 的仓库
2. **认证**: 如果是第一次推送，可能需要GitHub的用户名和Personal Access Token
3. **网络连接**: 确保网络连接正常

## 🔐 GitHub认证

如果需要Personal Access Token：

1. 访问 GitHub > Settings > Developer settings > Personal access tokens
2. 创建新的token，给予repo权限
3. 在推送时使用token作为密码

## 📁 项目结构

项目包含以下主要组件：

- Godot项目文件 (project.godot)
- 脚本系统 (scripts/)
- UI场景 (scene/)
- 资源文件 (assets/, data/, userdata/)
- 文档和许可证 (README.md, LICENSE)

项目已配置为Apache 2.0许可证，包含完整的明日方舟类锦标赛直播助手功能。
