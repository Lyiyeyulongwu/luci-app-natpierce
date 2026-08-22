#!/bin/sh

PROG_BIN="/usr/share/natpierce/natpierce"
WORK_DIR="/tmp/natpierce_upgrade"
LOG_FILE="/var/log/natpierce.log"
uci_tool=/sbin/uci

# 统一日志输出函数
log() {
    if [ -f "$LOG_FILE" ] && [ "$(wc -l < "$LOG_FILE")" -gt 1000 ]; then
        tail -n 500 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [upgrade] $1" >> "$LOG_FILE"
}

log "=== 开始执行后台升级任务 ==="

# 检查基础解压依赖
command -v tar >/dev/null 2>&1 || { log "错误: 依赖 'tar' 未安装。"; exit 1; }

current_version=$($uci_tool get natpierce.status.current_version 2>/dev/null)
latest_version=$($uci_tool get natpierce.status.latest_version 2>/dev/null)

[ -z "$current_version" ] && current_version="N/A"
[ -z "$latest_version" ] && latest_version="N/A"

if [ "$latest_version" = "N/A" ]; then
    log "错误: 最新版本号未知。请先点击页面上的 '检查更新'。"
    exit 1
fi

if [ "$(echo "$current_version" | sed 's/v//g')" = "$(echo "$latest_version" | sed 's/v//g')" ]; then
    log "当前版本 ($current_version) 已是最新版本，无需再次升级。"
    exit 0
fi

export update="true"

if [ -f "$(dirname $0)/update_parser.sh" ]; then
    . "$(dirname $0)/update_parser.sh"
else
    log "错误: 未找到 update_parser.sh 解析脚本。"
    exit 1
fi

if [ -z "$TARGET_URL" ] || [ "$TARGET_ARCH" = "unknown" ]; then
    log "错误: 升级失败。解析器未能获取到架构 ($TARGET_ARCH) 对应的下载直链。"
    exit 1
fi

URL="$TARGET_URL"
log "准备下载目标架构: $TARGET_ARCH，直链地址: $URL"

mkdir -p "$WORK_DIR"
cd "$WORK_DIR" || exit 1

# 兼容 OpenWrt 环境的下载逻辑 (优先 uclient-fetch / curl，最后回退到 wget)
log "正在下载最新版本压缩包..."
if command -v uclient-fetch >/dev/null 2>&1; then
    uclient-fetch -T 15 -q -O natpierce.tar.gz "$URL"
elif command -v curl >/dev/null 2>&1; then
    curl -m 15 -s -L -o natpierce.tar.gz "$URL"
else
    wget -q -O natpierce.tar.gz "$URL"
fi

if [ $? -ne 0 ] || [ ! -f natpierce.tar.gz ]; then
    log "错误: 下载二进制安装包失败，请检查路由器网络连接。"
    rm -rf "$WORK_DIR"
    exit 1
fi

log "文件下载完成，开始解压软件包..."
tar -xzvf natpierce.tar.gz >/dev/null 2>&1 || tar -xzvf natpierce.tar.gz

if [ ! -f "natpierce" ]; then
    log "错误: 解压失败，压缩包内未包含 natpierce 二进制文件。"
    rm -rf "$WORK_DIR"
    exit 1
fi

log "正在停止当前运行的 natpierce 服务..."
/etc/init.d/natpierce stop >/dev/null 2>&1

log "正在覆盖替换主程序文件..."
mv "natpierce" "$PROG_BIN"
chmod +x "$PROG_BIN"

$uci_tool set natpierce.status.current_version="$latest_version"
$uci_tool commit natpierce

log "正在重启 natpierce 服务..."
/etc/init.d/natpierce restart >/dev/null 2>&1

log "升级成功！软件已成功更新至新版本：$latest_version"

rm -rf "$WORK_DIR"
exit 0