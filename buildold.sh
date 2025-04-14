#!/bin/bash

set -e  # 遇到错误立即退出

BASE_DIR="$(dirname "$(realpath "$0")")"
MM_DIR="$BASE_DIR/mmsource-1.12"
SM_DIR="$BASE_DIR/sourcemod"
SERVER_DIR="/home/steam/Steam/cs_source_original"
CS_TYPE="cstrike"
CS_DIR="$SERVER_DIR/$CS_TYPE"
SERVER_EXEC="$SERVER_DIR/srcds_run"
DELETE_BUILD=false
START_SERVER=false

# 解析参数
while getopts "cd" opt; do
    case $opt in
        c) DELETE_BUILD=true ;;
        d) START_SERVER=true ;;
        *) echo "使用: $0 [-c] [-d]"; exit 1 ;;
    esac
done

build_and_copy() {
    local SRC_DIR="$1"
    local BUILD_DIR="$SRC_DIR/build"
    local PACKAGE_DIR="$BUILD_DIR/package"
    local IS_SOURCEMOD="$2"
    
    # 只有加了 -c 参数才删除 build 目录
    if [ "$DELETE_BUILD" = true ]; then
        rm -rf "$BUILD_DIR"
        mkdir -p "$BUILD_DIR"
    fi
    
    cd "$BUILD_DIR"
    
    # 执行构建
    python3 ../configure.py --sdks css --targets x86_64
    ambuild
    
    # 复制文件
    if [ "$IS_SOURCEMOD" = true ]; then
        rsync -av --mkpath --ignore-existing "$PACKAGE_DIR/addons/sourcemod/configs/" "$CS_DIR/addons/sourcemod/configs/"
        rsync -av --mkpath --ignore-existing "$PACKAGE_DIR/addons/sourcemod/gamedata/" "$CS_DIR/addons/sourcemod/gamedata/"
        rsync -av --mkpath --ignore-existing "$PACKAGE_DIR/addons/sourcemod/scripting/" "$CS_DIR/addons/sourcemod/scripting/"
        rsync -av --mkpath --ignore-existing "$PACKAGE_DIR/addons/sourcemod/plugins/" "$CS_DIR/addons/sourcemod/plugins/"
        rsync -av --mkpath --ignore-existing "$PACKAGE_DIR/addons/sourcemod/translations/" "$CS_DIR/addons/sourcemod/translations/"
    fi
    
    # 复制其余文件（正常覆盖，但排除已处理的 Sourcemod 目录）
    rsync -av --exclude="addons/sourcemod/configs" \
              --exclude="addons/sourcemod/gamedata" \
              --exclude="addons/sourcemod/scripting" \
              --exclude="addons/sourcemod/plugins" \
              --exclude="addons/sourcemod/translations" \
              "$PACKAGE_DIR/" "$CS_DIR/"
}

# 构建并复制 Metamod（不需要特殊处理）
build_and_copy "$MM_DIR" false

# 构建并复制 Sourcemod（包含特殊目录处理）
build_and_copy "$SM_DIR" true

# 替换 metamod.2.css.so
sed -i 's/_ZNV16CThreadFastMutex4LockEyj/_ZNV16CThreadFastMutex4LockEjj/g' "$CS_DIR/addons/metamod/bin/linux64/metamod.2.css.so"

# 替换 sourcemod.2.css.so
sed -i 's/_ZNV16CThreadFastMutex4LockEyj/_ZNV16CThreadFastMutex4LockEjj/g' "$CS_DIR/addons/sourcemod/bin/x64/sourcemod.2.css.so"

echo "构建和替换完成！"

# 如果加了 -d 参数，启动服务器
if [ "$START_SERVER" = true ]; then
    echo "正在启动服务器..."
    cd "$SERVER_DIR"
    "$SERVER_EXEC"
fi

