# 演播室2 - 项目打包说明

## 快速打包步骤

由于您的系统中未安装 Godot，建议使用以下方法：

### 方法一：使用 Godot 编辑器（最简单）

1. **下载 Godot 4.x**
   - 访问 https://godotengine.org/download
   - 下载 Windows 版本

2. **打开项目**
   - 运行 Godot 编辑器
   - 点击 "Import" 导入现有项目
   - 选择 `project.godot` 文件

3. **安装导出模板**
   - 菜单：Editor → Manage Export Templates
   - 点击 "Download and Install"

4. **导出项目**
   - 菜单：Project → Export
   - 添加 "Windows Desktop" 预设
   - 设置输出路径：`builds/演播室2.exe`
   - 点击 "Export Project"

## 项目功能

- ✅ 候场界面轮播系统（分榜/选手信息/解说信息）
- ✅ 分榜动画效果（并行显示）
- ✅ 选手信息展示
- ✅ 解说员信息显示
- ✅ JSON 数据驱动
- ✅ 图片加载支持
- ✅ 淡入淡出过渡动画

## 输出文件

导出成功后将生成：
- `演播室2.exe` - 主程序（约30-50MB）
- 内嵌所有资源文件

## 数据文件路径

程序运行时会访问：
- `user://userdata/teams/teams.json` - 队伍数据
- `user://userdata/announcers/current_announcer.json` - 解说员数据

实际位置：`%APPDATA%\Godot\app_userdata\演播室2\`
