#!/bin/bash
# 一鍵啟動：伺服器（沒在跑才啟動）→ 等 port 9030 → 遊戲
. "$(dirname "$0")/env.sh"
GMSV="$CG_ROOT/server-b/gmsv"
if ! lsof -nP -iTCP:9030 -sTCP:LISTEN >/dev/null 2>&1; then
  # 伺服器沒在跑時，殘留的帳號鎖一定是上次異常結束留下的
  sqlite3 "$GMSV/data.db3" "delete from tbl_lock; delete from tbl_lock2;"
  bash "$CG_ROOT/tools/run-server.sh"
  for i in $(seq 1 30); do
    lsof -nP -iTCP:9030 -sTCP:LISTEN >/dev/null 2>&1 && break
    sleep 2
  done
  lsof -nP -iTCP:9030 -sTCP:LISTEN >/dev/null 2>&1 || { echo "伺服器 60 秒內沒有起來，請看 server-b.log"; exit 1; }
  echo "伺服器已啟動"
else
  echo "伺服器已在執行"
fi
bash "$CG_ROOT/tools/run-game.sh"
echo "遊戲已啟動（若黑畫面或崩潰，再跑一次 run-game.sh）"
