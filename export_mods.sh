#!/usr/bin/env bash
# export_mods.sh —— 一键打包所有插件为可分发 zip（Linux / macOS 版，对齐 export_mods.ps1）
# 依赖：bash、zip、python3
# 用法：
#   ./export_mods.sh                    # 打包 mods/ 下全部插件
#   ./export_mods.sh streaming_arena    # 只打包指定插件
# 产物：builds/mods/<id>_<version>.zip（zip 内顶层即插件目录，解压到 {exe}/mods/ 即完成安装）
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODS_ROOT="$ROOT/mods"
OUT_ROOT="$ROOT/builds/mods"
NAME="${1:-}"   # 可选：只打包 id 匹配的插件

if [ ! -d "$MODS_ROOT" ]; then
    echo "错误：未找到插件目录: $MODS_ROOT" >&2
    exit 1
fi
command -v zip >/dev/null 2>&1 || { echo "错误：未找到 zip 命令（请先安装 zip）" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "错误：未找到 python3（用于解析 plugin.json）" >&2; exit 1; }

mkdir -p "$OUT_ROOT"

packed=0
for plugin_dir in "$MODS_ROOT"/*/; do
    [ -d "$plugin_dir" ] || continue
    dir_name="$(basename "$plugin_dir")"

    # 跳过模板 / 测试目录（_ 前缀）
    case "$dir_name" in
        _*) echo "跳过（模板/测试目录）: $dir_name"; continue ;;
    esac

    manifest="$plugin_dir/plugin.json"
    if [ ! -f "$manifest" ]; then
        echo "跳过（无 plugin.json）: $dir_name"
        continue
    fi

    id="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8")).get("id", ""))' "$manifest")"
    version="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8")).get("version", ""))' "$manifest")"

    if [ -z "$id" ]; then
        echo "跳过（清单缺少 id）: $dir_name" >&2
        continue
    fi
    if [ -n "$NAME" ] && [ "$id" != "$NAME" ]; then
        continue
    fi

    zip_path="$OUT_ROOT/${id}_${version}.zip"
    rm -f "$zip_path"
    # 压缩整个插件目录 → zip 内顶层即 <目录名>/，解压到 mods/ 即安装；.godot 缓存不打包
    ( cd "$MODS_ROOT" && zip -rq "$zip_path" "$dir_name" -x "$dir_name/.godot/*" )

    size_kb=$(( $(wc -c < "$zip_path") / 1024 ))
    echo "已打包: ${id}_${version}.zip (${size_kb} KB)"
    packed=$((packed + 1))
done

echo ""
echo "完成：$packed 个插件 -> $OUT_ROOT"
echo "安装方式：解压 zip 到可执行文件同级 mods/ 目录（.godot 缓存由 Godot 首次启动自动重建）"
