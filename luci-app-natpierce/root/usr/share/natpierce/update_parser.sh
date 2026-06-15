#!/bin/sh

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

[ "$TARGET_ARCH" = "unknown" ] && return 1


url_github="https://raw.githubusercontent.com/natpierce/update_resources/refs/heads/main/update_info.json"
url_gitee="https://raw.giteeusercontent.com/natpierce/update_resources/raw/main/update_info.json"

_json_data=""
_platform=""

export TARGET_VERSION=""
export TARGET_URL=""


if [ "x${update}" = "xtrue" ] || [ -z "${update}" ]; then
    _json_data=$(wget -T 3 -t 1 -qO- "$url_gitee" 2>/dev/null)
    if [ -n "$_json_data" ] && echo "$_json_data" | grep -q "latestVersionName" 2>/dev/null; then
        _platform="gitee"
    else
        _json_data=$(wget -T 3 -t 1 -qO- "$url_github" 2>/dev/null)
        if [ -n "$_json_data" ] && echo "$_json_data" | grep -q "latestVersionName" 2>/dev/null; then
            _platform="github"
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
    fi

elif [ "x${update}" = "xfalse" ] && [ "x${customversion}" != "xnull" ] && [ -n "${customversion}" ]; then
    export TARGET_VERSION=$(echo "${customversion}" | sed 's/v//g')
fi