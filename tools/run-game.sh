#!/bin/bash
# cgmsv 遊戲包裝程式（client/CrossGate/cgmsv.exe）＋台版 7.1，繁體語系。log: client.log
# 偶爾會在啟動時崩潰（0x7BF41239），再跑一次即可
. "$(dirname "$0")/env.sh"
export LANG=zh_TW.UTF-8 LC_ALL=zh_TW.UTF-8
"$WINE" regedit /S "$CG_ROOT/tools/wine-settings.reg" >/dev/null 2>&1
cd "$CG_ROOT/client/CrossGate" || exit 1
# 遊戲端加速：CG_SPEED=2 bash tools/run-game.sh（只影響 cg.exe 的 GetTickCount／Sleep，見 tools/speed/）
if [ -n "$CG_SPEED" ]; then
  cp "$CG_ROOT/tools/speed/winmm.dll" . && export WINEDLLOVERRIDES="winmm=n,b"
fi
ARGS=$(tr -d '\r' < data/argument.ini | tr ' ' '\n' | grep -v '^IP:' | grep -v '^$' | tr '\n' ' ')
nohup "$WINE" cgmsv.exe windowsize:1 $ARGS IP:0:127.0.0.1:9030 > "$CG_ROOT/client.log" 2>&1 &
