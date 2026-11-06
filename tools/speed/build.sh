#!/bin/sh
# winmm.dll (PE32 i386) をこのフォルダに作る
cd "$(dirname "$0")" || exit 1
V=/private/tmp/claude-501/-Users-trisoft-Desktop-Projects/16d8a491-ed16-4f45-aeca-d6bc6a4c2a91/scratchpad/speed/v
"$V/bin/python" -m ziglang cc -target x86-windows-gnu -shared -O2 -o winmm.dll winmm_speed.c winmm_speed.def
