# xgmsv protocol notes (iriselia/xgmsv, last push 2024-01-21)
Note: xg_crypto.h is at Source/xgmsv/crossgate/xg_crypto.h (capital S), not source/.
## Wire
- TCP, listens 127.0.0.1:9030 : source/xgmsv/crossgate/xgmsv.cpp:~166-171 (spawn_network_service)
- line framing: encrypt_message appends '\n' xg_crypto.h:649
- plaintext = space-separated tokens, 'opcode arg arg ... ' trailing space, '\n' end: xg_packet.cpp:13-63
## Decrypt (xg_crypto.h decrypt_message :306-347)
1 util_64to256 :65 custom base64, table "ABC..Zabc..z0-9+-" :8 (6bit->8bit, MSB first)
2 remove_salt :91 SEED=4595 (:5); seed=4595%len; checksum byte at src[seed]; i<seed: -sum*(i*i%3); i>seed: -sum*(i*i%7)
3 remove_conditional_bit_reverse :118 ~byte when (4595%7==i%5 || 4595%2==i%2)
4 if buffer[0]%2 (header odd) -> decompress_message :137 (LZW-like, 9-bit codes, EOF 0x100, dict 256); else memcpy; header byte skipped (workbuf+1)
- Encrypt mirror :586-655; compress when len>=100; header = length parity trick.
- Key = fixed constant SEED 4595 (compile-time), no per-session key exchange visible.
## Opcodes xg_packet.cpp:167-316
- Opcode strings are obfuscated per direction: e.g. ClientLogin recv "JFVf" send "whV"; CharList recv "Gp" send "Daj"; Echo "Or"/"LOh"; M "UUN"/"aBS". recv table :169-260 ; send-only :261-315.
- xg_recv matches by strncmp prefix of obfuscated opcode :318-336 ; xg_begin_packet writes send_op :338-345
- 92 recv entries :68-162 (names W,w,EV,M,EN,...,ClientLogin,CreateNewChar,CharLogin,CharList,StallStart/End/Browse/Buy ...)
## Version / region
- config.h:3-8 defines XG_PACKET_PROTOCOL_CN/TW/KR/JP and sets TW(1); no #if uses found in repo (code search only hits config.h) -> selector is not actually used.
- xgmsv.cpp:7-25 utf8ToGBK uses codepage 936 (GBK) though comment says Big5(950); utf8ToBig5 (950) is commented out :47-66.
- decode_test/main.cpp:14,27 sample "ClientLogin jpark730 abCD1212 ..." ; CharList sample contains GBK bytes (e.g. "ÓÎÃñ" = 游民 in GBK) => samples captured from CN (simplified) client/server; opcode table likely from that capture.
- No client version string, no 7.1 / 20220101 mention anywhere. commits 2020-03..2024-01, msg "." mostly.
## Others
- hzqst/CGAssistant (C++/Qt, pushed 2024-07-21): CGAHook DLL injection (cgahook/Inject.cpp, gameservice.cpp) + rest_rpc/msgpack IPC (CGALib/gameinterface.cpp:1-60). Not packet layer, no crypto code.
- hzqst/CGAssistantJS (JS, 2024-11-22): scripts on top of cgaapi.js.
- Muscipular/cgmsv-lua: Lua modules for cgmsv 24.x (README). No protocol docs.
- shiliangcn/cg_bot (2023-06-29): README only "CrossGate Bot", empty.
- i2534/cgaid (Rust, 2024-04-12): log file watcher only.
- bbs.cgmsv.com fetched: only titles, nothing on protocol. WebSearch (2 queries) found nothing.
