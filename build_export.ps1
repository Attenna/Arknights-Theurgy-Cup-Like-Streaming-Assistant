# Godot 项目自动打包脚本
# 演播室2 项目导出脚本

param(
    [string]$GodotPath = "C:\Program Files (x86)\Godot\Godot_v4.3-stable_win64.exe",  # Godot 可执行文件路径
    [string]$Platform = "Windows Desktop",  # 导出平台
    [string]$OutputDir = "builds"  # 输出目录
)

Write-Host "=== Godot 项目自动打包脚本 ===" -ForegroundColor Green
Write-Host "项目名称: 演播室2" -ForegroundColor Yellow
Write-Host "目标平台: $Platform" -ForegroundColor Yellow

# 检查 Godot 是否可用
Write-Host "`n检查 Godot 环境..." -ForegroundColor Cyan
try {
    $godotVersion = & $GodotPath --version 2>$null
    if ($godotVersion) {
        Write-Host "✓ 找到 Godot: $godotVersion" -ForegroundColor Green
    } else {
        throw "Godot 未找到"
    }
} catch {
    Write-Host "✗ 错误: 未找到 Godot 可执行文件" -ForegroundColor Red
    Write-Host "请确保:" -ForegroundColor Yellow
    Write-Host "1. Godot 已正确安装" -ForegroundColor Yellow
    Write-Host "2. Godot 已添加到系统 PATH 环境变量" -ForegroundColor Yellow
    Write-Host "3. 或者使用 -GodotPath 参数指定 Godot 可执行文件路径" -ForegroundColor Yellow
    Write-Host "`n示例用法:" -ForegroundColor White
    Write-Host ".\build_export.ps1 -GodotPath 'C:\Godot\Godot_v4.x.x_win64.exe'" -ForegroundColor White
    exit 1
}

# 创建输出目录
if (!(Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    Write-Host "✓ 创建输出目录: $OutputDir" -ForegroundColor Green
}

# 检查导出模板是否存在
Write-Host "`n检查导出预设..." -ForegroundColor Cyan

# 创建基本的导出预设配置（如果不存在）
$exportPresets = @"
[preset.0]

name="Windows Desktop"
platform="Windows Desktop"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="$OutputDir/演播室2.exe"
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false

[preset.0.options]

custom_template/debug=""
custom_template/release=""
debug/export_console_wrapper=1
binary_format/embed_pck=false
texture_format/bptc=true
texture_format/s3tc=true
texture_format/etc=false
texture_format/etc2=false
binary_format/architecture="x86_64"
codesign/enable=false
codesign/identity=""
codesign/password=""
codesign/timestamp=true
codesign/timestamp_server_url=""
codesign/digest_algorithm=1
codesign/description=""
codesign/custom_options=PackedStringArray()
application/modify_resources=true
application/icon=""
application/console_wrapper_icon=""
application/icon_interpolation=4
application/file_version=""
application/product_version=""
application/company_name=""
application/product_name="演播室2"
application/file_description=""
application/copyright=""
application/trademarks=""
application/export_angle=0
ssh_remote_deploy/enabled=false
ssh_remote_deploy/host="user@host_ip"
ssh_remote_deploy/port="22"
ssh_remote_deploy/extra_args_ssh=""
ssh_remote_deploy/extra_args_scp=""
ssh_remote_deploy/run_script=""
ssh_remote_deploy/cleanup_script=""
"@

$exportPresetsPath = "export_presets.cfg"
if (!(Test-Path $exportPresetsPath)) {
    $exportPresets | Out-File -FilePath $exportPresetsPath -Encoding UTF8
    Write-Host "✓ 创建导出预设文件: export_presets.cfg" -ForegroundColor Green
} else {
    Write-Host "✓ 找到现有导出预设文件" -ForegroundColor Green
}

# 执行导出
Write-Host "`n开始导出项目..." -ForegroundColor Cyan
Write-Host "输出路径: $OutputDir\演播室2.exe" -ForegroundColor Yellow

try {
    # 使用 Godot 命令行导出项目
    $exportArgs = @(
        "--headless",
        "--export-release",
        "Windows Desktop",
        "$OutputDir\演播室2.exe"
    )
    
    Write-Host "执行命令: $GodotPath $($exportArgs -join ' ')" -ForegroundColor Gray
    & $GodotPath @exportArgs
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n✓ 项目导出成功!" -ForegroundColor Green
        Write-Host "可执行文件位置: $(Resolve-Path "$OutputDir\演播室2.exe")" -ForegroundColor Green
        
        # 检查文件大小
        $exeFile = Get-ChildItem "$OutputDir\演播室2.exe" -ErrorAction SilentlyContinue
        if ($exeFile) {
            $fileSize = [math]::Round($exeFile.Length / 1MB, 2)
            Write-Host "文件大小: ${fileSize} MB" -ForegroundColor Yellow
        }
        
        # 复制用户数据文件
        Write-Host "`n正在打包用户数据文件..." -ForegroundColor Cyan
        $userDataDir = "$OutputDir\userdata"
        
        # 创建用户数据目录结构
        if (!(Test-Path "$userDataDir\teams")) {
            New-Item -ItemType Directory -Path "$userDataDir\teams" -Force | Out-Null
        }
        if (!(Test-Path "$userDataDir\announcers")) {
            New-Item -ItemType Directory -Path "$userDataDir\announcers" -Force | Out-Null
        }
        
        # 创建示例数据文件
        $teamsData = @"
[
    {
        "name": "示例队伍1",
        "balance": 1000,
        "score": 95,
        "rank": 1,
        "icon_path": "",
        "id": "team_001"
    },
    {
        "name": "示例队伍2", 
        "balance": 800,
        "score": 88,
        "rank": 2,
        "icon_path": "",
        "id": "team_002"
    },
    {
        "name": "示例队伍3",
        "balance": 600,
        "score": 76,
        "rank": 3,
        "icon_path": "",
        "id": "team_003"
    }
]
"@
        
        $announcersData = @"
{
    "announcers": [
        {
            "icon_path": "",
            "id": "announcer_001",
            "name": "示例解说1"
        },
        {
            "icon_path": "",
            "id": "announcer_002", 
            "name": "示例解说2"
        },
        {
            "icon_path": "",
            "id": "announcer_003",
            "name": "示例解说3"
        }
    ],
    "count": 3,
    "timestamp": $([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
}
"@
        
        # 写入示例数据文件
        $teamsData | Out-File -FilePath "$userDataDir\teams\teams.json" -Encoding UTF8
        $announcersData | Out-File -FilePath "$userDataDir\announcers\current_announcer.json" -Encoding UTF8
        
        Write-Host "✓ 用户数据文件已创建" -ForegroundColor Green
        Write-Host "  - $userDataDir\teams\teams.json" -ForegroundColor Gray
        Write-Host "  - $userDataDir\announcers\current_announcer.json" -ForegroundColor Gray
        
        # 创建使用说明
        $readme = @"
# 演播室2 使用说明

## 运行程序
双击 演播室2.exe 启动程序

## 数据文件说明

### 队伍数据 (userdata/teams/teams.json)
包含队伍排行榜信息，格式：
```json
[
    {
        "name": "队伍名称",
        "balance": 余额,
        "score": 分数,
        "rank": 排名,
        "icon_path": "图标路径",
        "id": "队伍ID"
    }
]
```

### 解说员数据 (userdata/announcers/current_announcer.json)
包含当前解说员信息，格式：
```json
{
    "announcers": [
        {
            "icon_path": "头像路径",
            "id": "解说员ID",
            "name": "解说员姓名"
        }
    ],
    "count": 解说员数量,
    "timestamp": 时间戳
}
```

## 功能说明

1. **候场界面轮播**：自动在分榜、选手信息、解说信息间切换
2. **动画效果**：流畅的淡入淡出和入场动画
3. **数据驱动**：通过修改 JSON 文件更新显示内容
4. **图片支持**：支持多种图片格式的头像和图标

## 注意事项

- 程序首次运行会在用户目录创建数据文件
- 可以手动修改 userdata 文件夹中的 JSON 文件来更新数据
- 图片路径支持相对路径和绝对路径

生成时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
"@
        
        $readme | Out-File -FilePath "$OutputDir\使用说明.txt" -Encoding UTF8
        Write-Host "✓ 使用说明已创建: $OutputDir\使用说明.txt" -ForegroundColor Green
        
        Write-Host "`n您现在可以运行以下命令来启动程序:" -ForegroundColor White
        Write-Host "cd '$OutputDir' && .\演播室2.exe" -ForegroundColor White
        
    } else {
        throw "导出失败，退出代码: $LASTEXITCODE"
    }
    
} catch {
    Write-Host "`n✗ 导出失败: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`n可能的解决方案:" -ForegroundColor Yellow
    Write-Host "1. 确保 Godot 导出模板已安装" -ForegroundColor Yellow
    Write-Host "2. 在 Godot 编辑器中检查项目设置" -ForegroundColor Yellow
    Write-Host "3. 确保所有资源路径正确" -ForegroundColor Yellow
    exit 1
}

Write-Host "`n=== 导出完成 ===" -ForegroundColor Green
