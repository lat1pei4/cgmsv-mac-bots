#!/bin/bash
# cgmsv 26.8d 伺服器（B）。log: server-b.log
. "$(dirname "$0")/env.sh"
export LANG=zh_TW.UTF-8 LC_ALL=zh_TW.UTF-8  # 測試：伺服器以 Big5 語系輸出
cd "$CG_ROOT/server-b/gmsv" && nohup "$WINE" cgmsv.exe > "$CG_ROOT/server-b.log" 2>&1 &
