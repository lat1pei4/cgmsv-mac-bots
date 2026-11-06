# 共用環境（被其他腳本 source）
CG_ROOT="$HOME/Desktop/Personal/crossgate"
export WINEPREFIX="$CG_ROOT/wineprefix"
export ROSETTA_ADVERTISE_AVX=1
export LANG=zh_CN.UTF-8 LC_ALL=zh_CN.UTF-8
WINE="$CG_ROOT/tools/Wine Staging.app/Contents/Resources/wine/bin/wine"
# 除錯 log：平常關閉；CG_DEBUG=1 時記錄 DLL 載入／例外／程序（崩潰時 winedbg 會把堆疊寫進 log）
if [ "$CG_DEBUG" = 1 ]; then export WINEDEBUG="+pid,+timestamp,+loaddll,+seh,+process"; else export WINEDEBUG="-all"; fi
