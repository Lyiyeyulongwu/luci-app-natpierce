#!/bin/sh

uci_tool=/sbin/uci
PROG_BIN="/usr/share/natpierce/natpierce"
LOG_FILE="/var/log/natpierce.log"

log() {
    if [ -f "$LOG_FILE" ] && [ "$(wc -l < "$LOG_FILE")" -gt 1000 ]; then
        tail -n 500 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [update] $1" >> "$LOG_FILE"
}

log "=== 开始手动检查版本更新 ==="

export update="true"

if [ -f "$(dirname $0)/update_parser.sh" ]; then
    . "$(dirname $0)/update_parser.sh"
else
    log "错误：未找到 update_parser.sh 脚本。"
    exit 1
fi

if [ ! -f "$PROG_BIN" ]; then
    log "警告：未找到本地主程序 $PROG_BIN，设置当前版本为 N/A"
    $uci_tool set natpierce.status.current_version="N/A"
    $uci_tool commit natpierce
fi

if [ -n "$TARGET_VERSION" ]; then
    latest_version="v${TARGET_VERSION}"
    $uci_tool set natpierce.status.latest_version="$latest_version"
    $uci_tool commit natpierce
    log "检查成功！获取到最新版本号：$latest_version"
    exit 0
else
    $uci_tool set natpierce.status.latest_version="N/A"
    $uci_tool commit natpierce
    log "错误：无法获取最新版本号，请检查路由器网络或 DNS 设置。"
    exit 1
fi