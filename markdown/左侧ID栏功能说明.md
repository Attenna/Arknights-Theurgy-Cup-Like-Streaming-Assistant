# 左侧ID栏选手信息显示功能

## 🎯 功能概述

已成功为 `left_id_bar.gd` 实现了选手信息显示功能，支持：

1. **自动信号连接** - 连接选手选择和编辑器更新信号
2. **数据读取** - 从 `current_player.json` 读取当前选手信息
3. **UI更新** - 自动刷新左侧ID栏的选手相关显示
4. **图像加载** - 支持加载选手头像等图片资源

## 📋 实现的功能

### 1. 信号连接系统

#### 自动连接
- **选手选择信号**: 连接到 `now_player.gd` 的 `player_selected` 信号
- **数据更新信号**: 连接到 `player_editor.gd` 的 `player_data_updated` 信号
- **延迟连接**: 确保所有节点准备就绪后再连接

#### 信号处理
```gdscript
func _on_player_selected(player_data: Dictionary) -> void:
    # 直接使用传入的选手数据更新显示

func _on_player_data_updated() -> void:
    # 重新从文件加载当前选手数据
    _load_current_player_data()
    _update_ui_display()
```

### 2. 数据管理

#### 文件读取
- **路径**: `user://userdata/players/current_player.json`
- **格式**: JSON 格式的选手数据字典
- **错误处理**: 完善的文件不存在和格式错误处理

#### 数据结构
```gdscript
{
    "id": "选手名称",
    "team_id": "队伍名称", 
    "icon_path": "头像文件路径",
    "starting_operator_choice": "开局干员",
    "starting_squad_choice": "开局分队",
    "starting_relic_choice": "开局藏品"
}
```

### 3. UI节点映射

基于场景结构映射到对应的UI节点：

| 数据字段 | UI节点路径 | 显示内容 |
|----------|------------|----------|
| `id` | `Player/PlayerName` | 选手姓名 |
| `icon_path` | `Player/PlayerIcon` | 选手头像 |
| `team_id` | `Team/TeamID` | 队伍名称 |
| - | `Team/TeamIcon` | 队伍图标（待扩展） |
| `starting_operator_choice` | `OpeningOperator/OperatorName` | 开局干员名称 |
| - | `OpeningOperator/OperatorIcon` | 干员图标（待扩展） |
| `starting_squad_choice` | `OpeningSquad/SquadName` | 开局分队名称 |
| - | `OpeningSquad/SquadIcon` | 分队图标（待扩展） |

### 4. 图像加载系统

#### 支持的路径格式
- **user:// 路径**: 用户数据目录中的图片文件
- **res:// 路径**: 项目资源中的图片文件
- **自动转换**: user:// 路径自动转换为 ImageTexture

#### 加载逻辑
```gdscript
func _load_texture_from_path(path: String) -> Texture2D:
    # user:// 路径处理
    if path.begins_with("user://"):
        var image = Image.new()
        image.load(path)
        return ImageTexture.create_from_image(image)
    
    # res:// 路径直接加载
    return load(path) as Texture2D
```

## 🔄 工作流程

### 自动更新流程
1. **信号触发** - 选手选择或数据更新时发射信号
2. **数据获取** - 从传入参数或文件中获取选手数据
3. **UI更新** - 调用 `_update_ui_display()` 刷新所有相关元素
4. **分模块更新** - 分别更新选手、队伍、干员、分队信息

### 手动更新流程
1. **外部调用** - 通过公共API方法触发更新
2. **数据设置** - 直接设置或重新加载选手数据
3. **UI刷新** - 立即更新所有显示元素

## 🛠️ 公共API

### 数据操作方法
```gdscript
# 刷新显示（重新从文件加载）
refresh_display()

# 直接更新选手数据
update_player_data(player_data: Dictionary)

# 获取当前选手数据
get_current_player_data() -> Dictionary
```

### 手动连接方法
```gdscript
# 连接到选手选择节点
connect_to_player_node(player_node: Node)

# 连接到编辑器节点
connect_to_editor_node(editor_node: Node)
```

## 🎯 使用场景

### 场景1: 选手选择时自动更新
1. 用户在选手选择界面选择选手
2. `now_player.gd` 发射 `player_selected` 信号
3. 左侧ID栏接收信号，立即更新显示

### 场景2: 选手数据编辑后更新
1. 用户在编辑器中修改选手信息
2. `player_editor.gd` 发射 `player_data_updated` 信号
3. 左侧ID栏重新从文件加载数据并更新显示

### 场景3: 手动刷新
1. 外部代码调用 `refresh_display()` 方法
2. 系统重新从 `current_player.json` 加载数据
3. 所有相关UI元素立即更新

## 🔍 调试输出

系统提供详细的调试信息：

```
Connected to player_selected signal from: [节点名]
Connected to player_data_updated signal from: [节点名]
🎯 接收到选手选择信号，更新左侧ID栏...
🔄 接收到选手数据更新信号，重新加载当前选手...
Loading current player data from: user://userdata/players/current_player.json
Loaded current player data: [选手名称]
Updating left ID bar UI display...
Player icon loaded: [图标路径]
Left ID bar UI updated successfully
```

## 🛡️ 错误处理

### 文件操作
- **文件不存在**: 自动清空显示，不会崩溃
- **JSON解析错误**: 输出错误信息，重置为空状态
- **图像加载失败**: 设置为空纹理，继续其他更新

### 节点引用
- **节点不存在**: 安全的空值检查，跳过对应更新
- **信号连接失败**: 输出警告信息，不影响其他功能
- **重复连接**: 自动检查避免重复连接

## 🔧 扩展性

### 图标加载系统
完整实现了各类图标的自动加载功能：

#### 选手头像
- **路径**: 从选手数据中的 `icon_path` 字段获取
- **支持格式**: 各种图片格式 (PNG, JPG等)
- **错误处理**: 文件不存在时显示空纹理

#### 干员头像
- **路径格式**: `user://data/operators/{星级}/头像_{干员名}.png`
- **星级检测**: 自动查找 `{星级}_star_namelist.json` 确定干员星级
- **搜索顺序**: 5星 → 6星 → 4星 → 3星
- **智能查找**: 星级未知时遍历所有可能路径

```gdscript
# 干员图标加载示例
func _get_operator_icon_path(op_name: String) -> String:
    var star_level = _get_operator_star_level(op_name)
    return "user://data/operators/" + str(star_level) + "/头像_" + op_name + ".png"
```

#### 分队图标
- **路径格式**: `user://data/squads/{分队名}.png`
- **直接匹配**: 根据分队名称直接构建路径

#### 战队图标
- **路径格式**: `user://userdata/teams/{战队ID}_{战队名称}.jpg`
- **智能搜索**: 如果直接路径不存在，在目录中搜索包含战队名的文件
- **格式支持**: 主要支持 JPG 格式

```gdscript
# 战队图标搜索逻辑
func _find_team_icon_file(team_name: String) -> String:
    # 在 user://userdata/teams/ 目录中搜索匹配文件
    # 支持 "ID_名称.jpg" 格式的文件名解析
```

### 动画效果
可以在更新时添加动画效果：

```gdscript
# 在 _update_ui_display() 中添加动画
func _update_ui_display() -> void:
    # 淡出效果
    var tween = create_tween()
    tween.tween_property(self, "modulate:a", 0.0, 0.2)
    await tween.finished
    
    # 更新内容
    _update_player_info()
    # ... 其他更新
    
    # 淡入效果
    tween.tween_property(self, "modulate:a", 1.0, 0.2)
```

## 🎉 总结

左侧ID栏现在完全支持：

1. **实时响应** - 选手选择或数据更新时立即刷新显示
2. **数据同步** - 自动从 `current_player.json` 加载最新数据
3. **完整显示** - 显示选手姓名、头像、队伍、开局干员、分队信息
4. **错误恢复** - 健壮的错误处理确保系统稳定
5. **易于扩展** - 模块化设计便于添加新功能

这确保了比赛界面能够实时显示当前选手的完整信息，提升了整体的用户体验和功能完整性。
