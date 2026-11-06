# crossgate 作業守則（model-facing）

個人專案：不登 GTD。使用者說明看 `SETUP.md`；Lua API 看 `docs/api/README.md`（找函式先查這裡，不要用到才找）。

## Lua 模組：改 → 轉碼 → 檢查 → 部署

- 原始碼只改 `server-b/modules-src/*.utf8.lua`（UTF-8）。部署檔 `server-b/gmsv/lua/Modules/*.lua` 由 `python3 -I tools/convert_lua_module.py <src> <dst>` 產生：字串轉 Big5（遊戲端是台版）、其餘轉 GBK（引擎語系）。
- 轉碼失敗會留下舊檔：註解或字串裡有 GBK 沒有的字（例：`↔`）就失敗，**看 exit code**，不要接著部署。
- 語法檢查：本機只有 Lua 5.5。把非 ASCII 字元換成 `X`，再把 `for x = ... do` 改寫成 `for x_0 = ... do local x = x_0`，然後 `luac -p`。伺服器是 LuaJIT：沒有 `table.unpack`，有 `bit`／`ffi`。
- Lua 字串的反斜線：協定裡的 `\\z` 要寫成 `'\\\\z'`。
- 改 GBK／Big5 檔用 `LC_ALL=C sed`，否則 `illegal byte sequence`。
- `ModuleConfig.lua` 是 GBK＋CRLF，用 Python 以位元組附加。附加前先確認沒有重複的 `loadModule`（重複會載兩次）。

## 伺服器重啟

1. `kill -INT <pgrep -f '^cgmsv.exe'>`，等程序消失（會存檔）。
2. `sqlite3 server-b/gmsv/data.db3 'delete from tbl_lock; delete from tbl_lock2;'`
3. `bash tools/run-server.sh`，等 9030 埠。40 秒沒起來就看 `server-b.log` 開頭：`page fault ... 0x1401C877B` 是引擎偶發崩潰，`pkill -f winedbg` 後重開。
- 重啟會踢掉使用者的遊戲端，動手前先講。
- log：`server-b.log`（Big5，`LC_ALL=C grep -a | iconv -f big5 -t utf-8 -c`）；封包：`server-b/gmsv/log/packet_YYYYMMDDHH.txt`（已解碼的明文，真遊戲端的行為從這裡查）。

## 編碼

- `Iconv.ToUtf8`／`ToLocale` 只做 GBK 與 UTF-8 互轉。模組字串是 Big5，丟給 `ToUtf8` 會變亂碼或空字串。
- HTTP API：訊息回英數代碼，由網頁翻成中文；角色名回原始位元組的 hex，由網頁用 `TextDecoder('big5')` 解。地圖名是 GBK，才用 `ToUtf8`。

## 無頭角色（botlogin）＝扮演遊戲端

- 協定是明文：`指令 參數… ` 加 `\n`。`cg_protocol_notes.md` 的 xgmsv 加密不適用。
- 引擎在等遊戲端的事，bot 都要自己做，否則會卡住：每回合回兩次 `Rg N`（人物、寵物各一），戰鬥結束 `LYIm C|20` 後回 `eL 0`。新流程先對照封包記錄裡真遊戲端的行為。
- `AutoBattleCommandEvent` 要等遊戲端送了 `Rg` 才會觸發。`Battle.ActionSelect` 對有連線的玩家無效（`IsWaitingCommand`＝0）。
- `Char.SetDummy` 不能用：無法存檔，自動戰鬥也不出招。

## 引擎行為（實測）

- `NLG.WalkMove(c, dir)`：dir 0 北，順時針到 7 西北；不會帶隊員走。`Char.Warp(隊長)` 會帶整隊。
- `Char.GetPartyMember(隊長, 0..4)`：0 是隊長，沒組隊回 -1。
- 新角色下線再登入會出現在召喚之間，不是下線時的位置。

## Commit

- 訊息用日文，先跑 `python3 ~/.claude/hooks/ja_glyphs.py --strict <檔>`，再 `git commit -F`。不用 `git add -A`／`git add .`。
- `.gitignore` 是白名單：新的追蹤路徑要先加 `!` 規則。
