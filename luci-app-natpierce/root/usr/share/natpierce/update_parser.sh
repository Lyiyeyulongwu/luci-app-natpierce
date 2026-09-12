#!/bin/sh

LOG_FILE="/var/log/natpierce.log"

log() {
    if [ -f "$LOG_FILE" ] && [ "$(wc -l < "$LOG_FILE")" -gt 1000 ]; then
        tail -n 500 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [update_parser] $1" >> "$LOG_FILE"
}

_arch=$(uname -m)
case "$_arch" in
    x86_64)           export TARGET_ARCH="amd64" ;;
    aarch64|arm64)    export TARGET_ARCH="arm64" ;;
    armv7*)           export TARGET_ARCH="arm32" ;;
    mips|mipsel)
        if [ "$_arch" = "mipsel" ]; then
            export TARGET_ARCH="mipsel"
        else
            _first_byte=$(printf '\1' | hexdump -e '1/1 "%02x"' 2>/dev/null || printf "00")
            if [ "$_first_byte" = "01" ]; then
                export TARGET_ARCH="mipsel"
            else
                export TARGET_ARCH="mips"
            fi
        fi
        ;;
    *)                export TARGET_ARCH="unknown" ;;
esac

if [ "$TARGET_ARCH" = "unknown" ]; then
    log "错误: 无法识别系统架构 ($_arch)"
    return 1
fi

url_github="https://raw.githubusercontent.com/natpierce/update_resources/refs/heads/main/update_info.json"
url_gitee="https://raw.giteeusercontent.com/natpierce/update_resources/raw/main/update_info.json"

_json_data=""
_platform=""

export TARGET_VERSION=""
export TARGET_URL=""

fetch_url() {
    local url="$1"
    if command -v uclient-fetch >/dev/null 2>&1; then
        uclient-fetch -T 5 -q -O - "$url" 2>/dev/null
    elif command -v curl >/dev/null 2>&1; then
        curl -m 5 -s "$url" 2>/dev/null
    else
        wget -q -O - "$url" 2>/dev/null
    fi
}

if [ "x${update}" = "xtrue" ] || [ -z "${update}" ]; then
    log "正在拉取远程更新信息配置 (硬件架构: $TARGET_ARCH)..."
    
    _json_data=$(fetch_url "$url_gitee")
    if [ -n "$_json_data" ] && echo "$_json_data" | grep -q "latestVersionName" 2>/dev/null; then
        _platform="gitee"
        log "成功连通 Gitee 镜像节点源"
    else
        _json_data=$(fetch_url "$url_github")
        if [ -n "$_json_data" ] && echo "$_json_data" | grep -q "latestVersionName" 2>/dev/null; then
            _platform="github"
            log "成功连通 GitHub 节点源"
        fi
    fi

    if [ -n "$_json_data" ] && [ -n "$_platform" ]; then
        export TARGET_VERSION=$(echo "$_json_data" | grep '"latestVersionName"' | sed 's/.*"latestVersionName": *"\([^"]*\)".*/\1/' | sed 's/v//g')
        
        # 锁定目标下载直链
        export TARGET_URL=$(echo "$_json_data" | awk -v p="$_platform" -v a="$TARGET_ARCH" '
            $0 ~ "\""p"\"" { flag = 1 } 
            flag && $0 ~ "\""a"\"" { print $0; exit } 
            flag && $0 ~ "}" && c++ > 5 { flag = 0 }
        ' | sed 's/.*"'"$TARGET_ARCH"'": *"\([^"]*\)".*/\1/')

        log "解析完成: 最新版本 v${TARGET_VERSION}，直链: ${TARGET_URL:-未能匹配链接}"
    else
        log "错误: 无法从 Gitee 和 GitHub 获取版本信息，请检查网络/DNS"
    fi

elif [ "x${update}" = "xfalse" ] && [ "x${customversion}" != "xnull" ] && [ -n "${customversion}" ]; then
    export TARGET_VERSION=$(echo "${customversion}" | sed 's/v//g')
    log "使用自定义设定版本: v${TARGET_VERSION}"
fi