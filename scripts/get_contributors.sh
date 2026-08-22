#!/bin/sh

REPO="natpierce/luci-app-natpierce"
API_URL="https://api.github.com/repos/${REPO}/contributors"

OUTPUT_LUA_FILE="luci-app-natpierce/luasrc/model/cbi/natpierce/contributors.lua"
AVATAR_DIR="luci-app-natpierce/htdocs/luci-static/natpierce/avatars"

chmod +x "$0"

command -v curl >/dev/null || { echo "错误: 需要'curl'工具"; exit 1; }
command -v jq >/dev/null || { echo "错误: 需要'jq'工具"; exit 1; }

DATA=$(curl -s -H "Accept: application/vnd.github.v3+json" "${API_URL}")

if [ -z "$DATA" ]; then
    echo "错误: 无法获取数据"
    exit 1
fi

if ! echo "$DATA" | jq empty 2>/dev/null; then
    echo "错误: API 返回无效 JSON"
    exit 1
fi

CONTRIBUTOR_COUNT=$(echo "$DATA" | jq 'length')
if [ "$CONTRIBUTOR_COUNT" -eq 0 ]; then
    echo "return {}" > "${OUTPUT_LUA_FILE}"
    exit 0
fi

rm -rf "${AVATAR_DIR}"
mkdir -p "${AVATAR_DIR}"

echo "return {" > "${OUTPUT_LUA_FILE}"

echo "$DATA" | jq -c '.[]' | while read -r contributor; do
    LOGIN=$(echo "$contributor" | jq -r '.login')
    HTML_URL=$(echo "$contributor" | jq -r '.html_url')
    AVATAR_URL=$(echo "$contributor" | jq -r '.avatar_url')
    
    [ -z "$LOGIN" ] && continue
    
    if echo "$AVATAR_URL" | grep -q '?'; then
        AVATAR_URL_RESIZED="${AVATAR_URL}&s=64"
    else
        AVATAR_URL_RESIZED="${AVATAR_URL}?s=64"
    fi
    
    AVATAR_PATH="luci-static/natpierce/avatars/${LOGIN}.png"
    
    curl -s --connect-timeout 10 -o "${AVATAR_DIR}/${LOGIN}.png" "${AVATAR_URL_RESIZED}"
    
    if [ -f "${AVATAR_DIR}/${LOGIN}.png" ] && [ -s "${AVATAR_DIR}/${LOGIN}.png" ]; then
        cat >> "${OUTPUT_LUA_FILE}" <<-EOF
  {
    name = "${LOGIN}",
    url = "${HTML_URL}",
    avatar = "${AVATAR_PATH}"
  },
EOF
    fi
done

echo "}" >> "${OUTPUT_LUA_FILE}"

if [ "$(wc -l < "${OUTPUT_LUA_FILE}")" -eq 2 ]; then
    echo "return {}" > "${OUTPUT_LUA_FILE}"
fi