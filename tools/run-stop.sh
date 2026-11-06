#!/bin/bash
# 正常關機：Ctrl-C 讓伺服器自己存檔結束 → 關掉其餘 Wine 程序 → 備份 data.db3（保留最近 10 份）
. "$(dirname "$0")/env.sh"
GMSV="$CG_ROOT/server-b/gmsv"
S=$(pgrep -f '^cgmsv.exe' | head -1)
if [ -n "$S" ]; then
  kill -INT "$S"
  for i in $(seq 1 60); do kill -0 "$S" 2>/dev/null || break; sleep 1; done
  if kill -0 "$S" 2>/dev/null; then echo "警告：伺服器 60 秒內沒有結束，改為強制關閉（可能未存檔）"; else echo "伺服器已存檔並結束（${i} 秒）"; fi
fi
"$(dirname "$WINE")/wineserver" -k 2>/dev/null
sleep 2
mkdir -p "$CG_ROOT/backups"
cp -p "$GMSV/data.db3" "$CG_ROOT/backups/data-$(date +%Y%m%d-%H%M%S).db3"
ls -1t "$CG_ROOT"/backups/data-*.db3 | tail -n +11 | xargs rm -f
pgrep -fl 'cgmsv|cg\.exe|wineserver' >/dev/null && echo "警告：仍有程序殘留" || echo "全部已關閉，已備份 data.db3"
