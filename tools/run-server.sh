#!/bin/bash
# cgmsv 26.8d 伺服器（B）。log: server-b.log
. "$(dirname "$0")/env.sh"
export LANG=zh_TW.UTF-8 LC_ALL=zh_TW.UTF-8  # 測試：伺服器以 Big5 語系輸出
LOG="$CG_ROOT/server-b.log"
# 上次是啟動崩潰（引擎偶發，見 SETUP.md 卡關紀錄）的話，log 另存一份，否則會被這次啟動覆寫
if [ -f "$LOG" ] && LC_ALL=C grep -aq 'Unhandled' "$LOG"; then
  cp "$LOG" "$CG_ROOT/server-b-crash-$(date +%Y%m%d-%H%M%S).log"
fi
: > "$LOG"  # 先清空，等待啟動的腳本才不會讀到上次的崩潰記錄
cd "$CG_ROOT/server-b/gmsv" && nohup "$WINE" cgmsv.exe > "$LOG" 2>&1 &
