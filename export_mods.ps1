# export_mods.ps1 —— 一键打包所有插件为可分发 zip
# 用法：
#   .\export_mods.ps1                          # 打包 mods/ 下全部插件
#   .\export_mods.ps1 -Name streaming_arena    # 只打包指定插件
# 产物：builds/mods/<id>_<version>.zip（zip 内顶层即插件目录，解压到 {exe}/mods/ 即完成安装）

param(
    [string]$Name = ""   # 可选：只打包 id 匹配的插件
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$modsRoot = Join-Path $root "mods"
$outRoot = Join-Path $root "builds\mods"

if (-not (Test-Path $modsRoot)) {
    Write-Error "未找到插件目录: $modsRoot"
    exit 1
}
if (-not (Test-Path $outRoot)) {
    New-Item -ItemType Directory -Path $outRoot | Out-Null
}

$packed = 0
Get-ChildItem -Directory -Path $modsRoot | ForEach-Object {
    $pluginDir = $_.FullName
    $manifestPath = Join-Path $pluginDir "plugin.json"
    if (-not (Test-Path $manifestPath)) {
        Write-Host "跳过（无 plugin.json）: $($_.Name)" -ForegroundColor Yellow
        return
    }
    $manifest = Get-Content $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $id = $manifest.id
    $version = $manifest.version
    if ($Name -ne "" -and $id -ne $Name) { return }

    $zipPath = Join-Path $outRoot "${id}_${version}.zip"
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    # 压缩整个插件目录 → zip 内顶层即 <id>/，解压到 mods/ 即安装
    Compress-Archive -Path $pluginDir -DestinationPath $zipPath
    $sizeKB = [math]::Round((Get-Item $zipPath).Length / 1KB)
    Write-Host "已打包: ${id}_${version}.zip (${sizeKB} KB)" -ForegroundColor Green
    $packed++
}

Write-Host ""
Write-Host "完成：$packed 个插件 -> $outRoot"
Write-Host "安装方式：解压 zip 到可执行文件同级 mods/ 目录（.godot 缓存由 Godot 首次启动自动重建）"
