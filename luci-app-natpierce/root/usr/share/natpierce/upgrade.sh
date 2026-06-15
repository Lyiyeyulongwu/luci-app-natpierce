#!/bin/sh

PROG_BIN="/usr/share/natpierce/natpierce"
WORK_DIR="/tmp/natpierce_upgrade"
uci_tool=/sbin/uci

command -v wget >/dev/null || { echo "错误: 依赖'wget'未安装."; exit 1; }
command -v tar >/dev/null || { echo "错误: 依赖'tar'未安装."; exit 1; }

current_version=$($uci_tool get natpierce.status.current_version 2>/dev/null)
latest_version=$($uci_tool get natpierce.status.latest_version 2>/dev/null)

[ -z "$current_version" ] && current_version="N/A"
[ -z "$latest_version" ] && latest_version="N/A"

if [ "$latest_version" = "N/A" ]; then
    echo "错误: 最新版本号未知。请先执行'检查更新'。"
    exit 1
fi

if [ "$(echo "$current_version" | sed 's/v//g')" = "$(echo "$latest_version" | sed 's/v//g')" ]; then
    echo "当前版本 ($current_version) 已是最新版本。无需更新。"
    exit 0
fi

echo "开始下载新版本：$latest_version"

export update="true"

if [ -f "$(dirname $0)/update_parser.sh" ]; then
    . "$(dirname $0)/update_parser.sh"
else
    echo "错误: 未找到 update_parser.sh"
    exit 1
fi

if [ -z "$TARGET_URL" ] || [ "$TARGET_ARCH" = "unknown" ]; then
    echo "错误: 升级失败。解析器未能获取到对应架构的下载直链。"
    exit 1
fi

URL="$TARGET_URL"

mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

wget -q -O natpierce.tar.gz "$URL"
if [ "$?" -ne 0 ]; then
    echo "错误: 下载失败，请检查网络连接。"
    rm -rf "$WORK_DIR"
    exit 1
fi

tar -xzvf natpierce.tar.gz >/dev/null 2>&1 || tar -xzvf natpierce.tar.gz
if [ ! -f "natpierce" ]; then
    echo "错误: 解压失败，未找到 natpierce 二进制文件。"
    rm -rf "$WORK_DIR"
    exit 1
fi

mv "natpierce" "$PROG_BIN"
chmod +x "$PROG_BIN"

$uci_tool set natpierce.status.current_version="$latest_version"
$uci_tool commit natpierce

echo "更新成功！新版本：$latest_version"

rm -rf "$WORK_DIR"
exit 0