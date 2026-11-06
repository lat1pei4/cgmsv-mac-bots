#!/bin/bash
# 模組部署：modules-src/<名>.utf8.lua → 轉碼 → LuaJIT 語法檢查 → 複製到 lua/Modules/ → 熱重載（不重啟伺服器）
# 用法：bash tools/deploy-module.sh 模組名…   （不帶模組名＝只更新 modules-src/www/ 的網頁）
# - 全部先轉碼＋檢查，有一個失敗就整批不部署
# - 熱重載走 devreload 模組的 /api/reload；沒載入過的模組會直接載入（臨時探針不必改 ModuleConfig）
# - 伺服器沒在跑時只複製檔案，下次啟動生效
# - 重載 botlogin 時 bot 會斷線，10 秒後自動登回
set -eo pipefail  # 不用 -u：env.sh 會讀未設定的 CG_DEBUG
. "$(dirname "$0")/env.sh"
SRC="$CG_ROOT/server-b/modules-src"
DST="$CG_ROOT/server-b/gmsv/lua"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

for m in "$@"; do
  python3 -I "$CG_ROOT/tools/convert_lua_module.py" "$SRC/$m.utf8.lua" "$TMP/$m.lua" >/dev/null
  luajit -b "$TMP/$m.lua" /dev/null
done
for m in "$@"; do cp "$TMP/$m.lua" "$DST/Modules/$m.lua"; done
cp "$SRC"/www/*.html "$DST/www/"
echo "已複製：$* 與網頁"

if ! nc -z 127.0.0.1 10086 2>/dev/null; then
  echo "伺服器沒在跑：下次啟動生效"
  exit 0
fi
fail=0
for m in "$@"; do
  r=$(curl -s -m 10 -X POST http://127.0.0.1:10086/api/reload -d "{\"module\":\"$m\"}")
  echo "$m: $r"
  case "$r" in
    *'"ok":true'*) ;;
    *'failed_see_log'*) echo "  → 載入失敗，看 server-b.log"; fail=1 ;;
    *) echo "  → 重載 API 沒回應：devreload 沒載入？（要重啟一次）"; fail=1 ;;
  esac
done
exit $fail
