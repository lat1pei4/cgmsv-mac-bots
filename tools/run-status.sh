#!/bin/bash
# 狀態：伺服器／遊戲／port／帳號鎖／最近備份
. "$(dirname "$0")/env.sh"
pgrep -f '^cgmsv.exe' >/dev/null && echo "伺服器：執行中" || echo "伺服器：未執行"
pgrep -f 'D:.client.CrossGate.cgmsv.exe' >/dev/null && echo "遊戲：執行中" || echo "遊戲：未執行"
lsof -nP -iTCP:9030 -sTCP:ESTABLISHED 2>/dev/null | grep -q cgmsv && echo "連線：遊戲已連上伺服器" || echo "連線：無"
echo "帳號鎖：$(sqlite3 "$CG_ROOT/server-b/gmsv/data.db3" 'select count(*) from tbl_lock;') 筆"
echo "最近備份：$(ls -1t "$CG_ROOT"/backups/data-*.db3 2>/dev/null | head -1 | xargs -n1 basename 2>/dev/null || echo 無)"
