@echo off
echo === Godot 项目快速导出脚本 ===
echo 项目名称: 演播室2
echo.

REM 检查 Godot 是否在 PATH 中
where godot >nul 2>&1
if %errorlevel% neq 0 (
    echo 错误: 未找到 Godot 可执行文件
    echo 请确保 Godot 已添加到系统 PATH 环境变量
    echo 或者修改此脚本中的 GODOT_PATH 变量
    echo.
    echo 按任意键退出...
    pause >nul
    exit /b 1
)

REM 创建构建目录
if not exist "builds" mkdir builds

REM 创建基本的导出预设（如果不存在）
if not exist "export_presets.cfg" (
    echo 创建导出预设文件...
    (
        echo [preset.0]
        echo.
        echo name="Windows Desktop"
        echo platform="Windows Desktop"
        echo runnable=true
        echo dedicated_server=false
        echo custom_features=""
        echo export_filter="all_resources"
        echo include_filter=""
        echo exclude_filter=""
        echo export_path="builds/演播室2.exe"
        echo encryption_include_filters=""
        echo encryption_exclude_filters=""
        echo encrypt_pck=false
        echo encrypt_directory=false
        echo.
        echo [preset.0.options]
        echo.
        echo custom_template/debug=""
        echo custom_template/release=""
        echo debug/export_console_wrapper=1
        echo binary_format/embed_pck=false
        echo texture_format/bptc=true
        echo texture_format/s3tc=true
        echo texture_format/etc=false
        echo texture_format/etc2=false
        echo binary_format/architecture="x86_64"
        echo application/product_name="演播室2"
        echo application/file_description="演播室管理系统"
        echo application/company_name=""
        echo application/copyright=""
    ) > export_presets.cfg
)

echo 开始导出项目...
echo 输出路径: builds\演播室2.exe
echo.

REM 执行导出
godot --headless --export-release "Windows Desktop" "builds\演播室2.exe"

if %errorlevel% equ 0 (
    echo.
    echo ✓ 项目导出成功!
    echo 可执行文件位置: %cd%\builds\演播室2.exe
    echo.
    echo 您现在可以运行以下命令来启动程序:
    echo cd builds ^&^& 演播室2.exe
    echo.
) else (
    echo.
    echo ✗ 导出失败
    echo 请检查 Godot 导出模板是否已安装
    echo 可以在 Godot 编辑器中通过 Editor -^> Manage Export Templates 安装
    echo.
)

echo 按任意键退出...
pause >nul
