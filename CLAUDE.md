# crossgate 作業守則（model-facing）

個人專案：不登 GTD。使用者說明看 `SETUP.md`；Lua API 看 `docs/api/README.md`（找函式先查這裡，不要用到才找）。

## Lua 模組：改 → 部署（不重啟）

- 原始碼只改 `server-b/modules-src/*.utf8.lua`（UTF-8）與 `modules-src/www/*.html`。
- 部署一律 `bash tools/deploy-module.sh 模組名…`：轉碼（`convert_lua_module.py`：字串轉 Big5、其餘轉 GBK）→ `luajit -b` 語法檢查（本機 LuaJIT 2.1，和伺服器同一套）→ 複製 → 經 `devreload` 模組的 `/api/reload` 熱重載。任何一個失敗就整批不部署。
- 新模組或臨時探針也用它：沒載入過的會直接載入，不必改 ModuleConfig、不必重啟（探針用完刪掉原始碼與部署檔，下次啟動就不會再載入）。
- 註解或字串裡有 GBK 沒有的字（例：`↔`）會轉碼失敗。
- 伺服器是 LuaJIT：沒有 `table.unpack`，有 `bit`／`ffi`。
- 改完 botlogin／botpanel／autobattle 跑 `python3 -I tools/bot_smoke.py aitest17 aitest18`（登入、組隊、打一場、走回東醫、重新登入、練等，13 項 PASS／FAIL，約 3 分鐘；不要用正在練功的 aitest01／02）。
- 熱重載會清掉模組內的狀態：走到一半的路、等待中的回醫院都會中斷，練功的第一趟會標成 partial 不判斷。部署前看一下兩隊是不是在路上。
- `deploy-module.sh` 不帶參數＝只部署網頁。
- Lua 字串的反斜線：協定裡的 `\\z` 要寫成 `'\\\\z'`。
- 改 GBK／Big5 檔用 `LC_ALL=C sed`，否則 `illegal byte sequence`。
- `ModuleConfig.lua` 是 GBK＋CRLF，用 Python 以位元組附加。附加前先確認沒有重複的 `loadModule`（重複會載兩次）。

## 伺服器重啟（只有改 ModuleConfig、http、devreload、引擎設定時才需要）

1. `kill -INT <pgrep -f '^cgmsv.exe'>`，等程序消失（會存檔）。
2. `sqlite3 server-b/gmsv/data.db3 'delete from tbl_lock; delete from tbl_lock2;'`
3. `bash tools/run-server.sh`，等 9030 埠。`server-b.log` 出現 `Unhandled`（引擎偶發崩潰，`0x1401C877B`）就 `pkill -f winedbg` 後重開；崩潰 log 在下次啟動時另存成 `server-b-crash-*.log`。`run-start.sh` 會自動重試一次。
- 重啟會踢掉使用者的遊戲端，動手前先講。
- log：`server-b.log`（Big5，`LC_ALL=C grep -a | iconv -f big5 -t utf-8 -c`）。
- 封包：`python3 -I tools/pktlog.py <帳號|all> [regex] [-A 行數] [-f 檔案]`，讀 `server-b/gmsv/log/packet_*.txt`（已解碼的明文）。真遊戲端在某情境送了什麼，從這裡查（例：`pktlog.py 111 'LYIm C\|20' -A 10`）。

## 編碼

- `data/*.txt` 已繁化，是 Big5（名字用 Python 解要 `big5`，不是 gbk）；`data/map/*` 檔頭的地圖名是 GBK；`server-b.log` 是 Big5。

- `Iconv.ToUtf8`／`ToLocale` 只做 GBK 與 UTF-8 互轉。模組字串是 Big5，丟給 `ToUtf8` 會變亂碼或空字串。
- HTTP API：訊息回英數代碼，由網頁翻成中文；角色名回原始位元組的 hex，由網頁用 `TextDecoder('big5')` 解。地圖名是 GBK，才用 `ToUtf8`。

## 無頭角色（botlogin）＝扮演遊戲端

- 協定是明文：`指令 參數… ` 加 `\n`。`cg_protocol_notes.md` 的 xgmsv 加密不適用。
- 引擎在等遊戲端的事，bot 都要自己做，否則會卡住：每回合回兩次 `Rg N`（人物、寵物各一），戰鬥結束 `LYIm C|20` 後回 `eL 0`；每 60 秒送 `DE`（引擎稱 FC，進遊戲 5 分鐘沒收到就踢；送太勤會被判加速外掛；`setup.cf` 的 `fctime`／`fccount`／`fcwait`／`unfairuserdown` 控制，已設 `unfairuserdown=0` 只記錄不踢）。定期送的封包，間隔要照真遊戲端。
- 引擎設定分兩檔：`cgmsv.cf`（遊戲規則）與 `setup.cf`（連線、檢查、資源上限）。找設定時兩檔都看；鍵名找不到時，從 `cgmsv.exe` 引用的設定結構位移對回鍵名的順序。新流程先對照封包記錄裡真遊戲端的行為。
- 引擎同時建多個角色會撞 SQLite 鎖，回 `DZ failed -1`（botlogin 自動重試）。同一 IP 的連線數受 `cgmsv.cf` 的 `loginnum` 限制（已改 0＝不限）。
- `AutoBattleCommandEvent` 要等遊戲端送了 `Rg` 才會觸發。`Battle.ActionSelect` 對有連線的玩家無效（`IsWaitingCommand`＝0）。
- `Char.SetDummy` 不能用：無法存檔，自動戰鬥也不出招。

## 引擎行為（實測）

- `NLG.WalkMove(c, dir)`：dir 0 北，順時針到 7 西北；不會帶隊員走。`Char.Warp(隊長)` 會帶整隊。
- `Char.GetPartyMember(隊長, 0..4)`：0 是隊長，沒組隊回 -1。
- 要跨登出／重啟保存的角色狀態一律存 `Char.SetExtData`（表 `hook_charaext`），寫完要 `Char.SaveToDb`，否則不會馬上進資料庫。登入時在 `LoginEvent(c)` 讀回。現用鍵：`autobattle`（自動戰鬥開關）、`grind`（練功點 `[floor,x,y,自動?,adj,ceil 最高等級,ceil 隊伍等級]`）、`manualpoints`（手動配點）、`magmoved`（舊建角魔法點已搬到力量）、`LastLogoutPoint`（loginGate 模組）。
- 引擎的自動戰鬥開關（`对象_自动战斗开关`）不會存檔。
- 新角色下線再登入會出現在召喚之間，不是下線時的位置。
- `NLG.Walkable` 對出入口（warp）那格回 0：找路時終點要另外放行；同一個門有好幾格時，有的格只從隔壁出入口格進得去，走到旁邊就好。
- NPC 旁邊的格子可能在櫃檯後面（伊爾村、亞留特村的護士），站位要挑和門口同一個連通區域的格子（autobattle 的 `standBy`）。
- `Map.GetMapSize(0, floor)` 可用（芙蕾雅 840×610）。載入時對 `TRAVEL_FLOORS` 做 flood fill 只要約 0.1 秒；路線用的直線估計看不出被圍起來的小區域，要靠區域編號判斷走不走得到。
- `NLG.WalkMove` 不會觸發遇敵，也不確定踩到出入口會不會自己傳送：autobattle 的走路兩種都處理（每步自己擲遇敵率；到出入口沒被傳就自己 `Char.Warp`）。
- 技能：`Char.AddSkill` 學到的是 0 級，自動戰鬥挑不到招式，要再 `Char.SetSkillLevel(c, slot, 1)`。戰鬥技能熟練度每場 +10（Lv1→2 要 1000）。職業用 `对象_职业`／`对象_职类ID`／`对象_职阶` 三個一起設；能學的技能與上限在 `data/skilllv.txt`（序號, 技能, 職業, 最高等級）。
- `cgmsv.cf` 的 `maxskilllevel`／`maxcraftskilllevel`／`maxtechlevel` 必須是 10：台版 `skillexp.txt` 每行只有 13 級左右的門檻（原版上限 10 級），設 15（cgmsv 預設）時啟動 log 會出 `skill/skill.c:999 數據不足`，技能一用就跳到職業上限、學的技能也存不進 `tbl_skill`。
- 村莊傳點：在村裡傳送點房間跟傳送石說話就記 `NowEvent` 旗標（伊爾 94、聖拉魯卡 95、亞留特 96、維諾亞 97）；法蘭城啟程之間（1522）的傳送石要旗標、單人、等級、錢才傳。bot 在村莊醫院補血時代開，路線用到時扣每人傳送費（不真的離隊）。
- 寵物升級：直接設等級不會長能力；灌經驗（`Char.GetLevelExp(k)` 是 k-1→k 要的量）打完一場引擎會連升好幾級。成長檔：`Pet.FullArtRank - Pet.GetArtRank`＝掉檔。
- `Char.MoveItem` 會檢查裝備欄位：鎧甲只能進身體欄（1），就算頭欄空著；裝不上的（例：紙靴）回失敗。GM 給的寵物、斧、盾、水晶存進 DB 的名字是空的（網頁用 itemset／enemybase 補名字）。
- Lua 坑：`hex()` 這種 gsub 包裝會回兩個值，放進 `table.insert(t, hex(x))` 會變三個參數而出錯，要 `(hex(x))`。

## Commit

- 這個 repo 是 public（github.com/lat1pei4/cgmsv-mac-bots）：**commit 訊息用英文、README 用繁體中文，都不用日文**（使用者 2026-11-06 指示，優先於全域的「commit 用日文」）。用 `git commit -F`，不用 `git add -A`／`git add .`。
- 別人的程式碼沒有授權條款就不進版控：`modules-src/merc.utf8.lua` 改自 xmancheng/cgmsv-lua（沒有 LICENSE），只留在本機，已從歷史移除。有授權的要附上授權全文（例：`docs/api/upstream/LICENSE`）。
- `.gitignore` 是白名單：新的追蹤路徑要先加 `!` 規則。
