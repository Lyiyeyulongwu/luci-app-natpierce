#!/bin/sh

uci_tool=/sbin/uci
PROG_BIN="/usr/share/natpierce/natpierce"

export update="true"

if [ -f "$(dirname $0)/update_parser.sh" ]; then
    . "$(dirname $0)/update_parser.sh"
else
    echo "错误：未找到 update_parser.sh"
    exit 1
fi

if [ ! -f "$PROG_BIN" ]; then
    $uci_tool set natpierce.status.current_version="N/A"
    $uci_tool commit natpierce
fi

if [ -n "$TARGET_VERSION" ]; then
    latest_version="v${TARGET_VERSION}"
    $uci_tool set natpierce.status.latest_version="$latest_version"
    $uci_tool commit natpierce
    echo "获取最新版本号成功：$latest_version"
    exit 0
else
    $uci_tool set natpierce.status.latest_version="N/A"
    $uci_tool commit natpierce
    echo "错误：无法获取最新版本号，请检查网络。"
    exit 1
fi