# 魔力寶貝私服 on Mac

環境：Apple M5／macOS 26.6，Wine Staging 11.21（Gcenx 版），cgmsv 26.8d 伺服器＋台版 7.1 用戶端，全部繁體（Big5）

## 日常操作

在 Claude Code 裡請 Claude 執行（`run-*.sh` 已加入 `~/Desktop/Projects/.claude/settings.local.json` 的 allow），或自己用 `! bash ...` 執行：

| 指令 | 作用 |
|---|---|
| `bash tools/run-start.sh` | 一鍵啟動：伺服器沒在跑才啟動（同時清除殘留的帳號鎖），等 port 9030 開好後再開遊戲 |
| `bash tools/run-stop.sh` | **正常關機**：對伺服器送 Ctrl-C，讓它自己存檔後結束 → 關掉其餘 Wine 程序 → 備份 `data.db3` 到 `backups/`（保留最近 10 份） |
| `bash tools/run-status.sh` | 查看伺服器、遊戲、連線、帳號鎖、最近備份 |
| `bash tools/run-game.sh` | 只開遊戲。黑畫面或崩潰時再跑一次 |
| `bash tools/run-server.sh` | 只開伺服器 |
| `CG_SPEED=2 bash tools/run-start.sh` | **遊戲端加速**（2 倍；可用小數）。只影響遊戲程序的 `GetTickCount`／`Sleep`，見下方「加速」 |
| `bash tools/deploy-module.sh 模組名…` | 改完 `modules-src/` 的 Lua 或網頁後部署：轉碼、LuaJIT 語法檢查、熱重載，**不重啟伺服器**，不會踢掉遊戲端（需要 `brew install luajit`） |
| `python3 -I tools/pktlog.py 帳號 [regex]` | 查伺服器封包記錄：某帳號的收送順序（`<-` 遊戲端送出、`->` 伺服器送出） |
| `python3 -I tools/bot_smoke.py aitest17 aitest18` | bot 冒煙測試：登入、組隊、打一場、走回東醫、重新登入、練等，13 項 PASS／FAIL（約 3 分鐘） |
| `python3 -I tools/cg_graphic.py …` | 從本機遊戲檔解出道具、寵物、頭像、全身圖給管理頁用（輸出到 `server-b/gmsv/lua/www/img/`，不進版控） |

- 帳號：`111`。第一次登入時由 autoRegister 自動註冊
- **不要直接關視窗或強制結束伺服器**：伺服器只在正常關機時存檔（B 的設定檔沒有定期存檔的選項）
- 要看除錯 log：`CG_DEBUG=1 bash tools/run-start.sh`，輸出寫到 `server-b.log` 和 `client.log`

## 資料夾

```
crossgate/
├─ SETUP.md / cg_protocol_notes.md
├─ docs/api/     cgmsv Lua API 參考（全部函式與事件，含生態系重點與待實測清單）
├─ tools/        Wine、啟動腳本、轉碼工具、登錄檔設定
├─ wineprefix/   Wine 環境（已移除 z:，d: 指向 crossgate/，使用者資料夾不連到 Mac 家目錄）
├─ server-b/     cgmsv 26.8d（使用中）
│   └─ gmsv/     data/ 已繁化（原檔 data.gbk-orig/），lua/ 維持 GBK（備份 lua.gbk-orig/），
│                cgmsv.exe 內嵌訊息表已繁化（原檔 cgmsv.exe.orig）
├─ server-a/     Crossgate_Docker 版（僅對照用，搭配 OrbStack 容器 cg-mysql）
├─ client/CrossGate/   台版 7.1 ＋ cgmsv 包裝程式 cgmsv.exe、登陆器.exe、cgmsv.ini、gmsv → server-b/gmsv
├─ backups/      run-stop.sh 自動備份的 data.db3
└─ downloads/    原始壓縮檔
```

## 啟動方式的重點（為什麼這樣設定）

| 設定 | 位置 | 原因 |
|---|---|---|
| `ROSETTA_ADVERTISE_AVX=1` | `tools/env.sh` | cgmsv 26.8d 的 LuaJIT 需要 BMI2，Rosetta 預設不宣告 AVX／BMI2 |
| 伺服器 `LANG=zh_TW.UTF-8` | `run-server.sh` | 讓伺服器的執行環境用 Big5 |
| 遊戲 `LANG=zh_TW.UTF-8` | `run-game.sh` | 台版用戶端是 Big5 |
| `renderer=gdi`、關閉崩潰對話框 | `tools/wine-settings.reg`（每次啟動遊戲時匯入） | Wine 在 macOS 上跑 WoW64 的 OpenGL 時，遊戲會切換堆疊，導致例外無法處理（崩潰或黑畫面）。DirectDraw 改用 GDI 繪製就不會碰到 OpenGL |
| 中文字型 | `tools/cjk-fonts.reg` | 把 SimSun、PMingLiU 等字型名稱，用 `Wine\Fonts\Replacements` 指向 Wine 自帶的 Microsoft Yahei（文泉驛） |
| 直接執行包裝程式 `cgmsv.exe windowsize:1 <argument.ini 參數> IP:0:127.0.0.1:9030` | `run-game.sh` | `一键启动.exe`（Sciter 介面）在 Wine 上不會顯示視窗；官方 `cg.exe` 會卡在連線握手；`windowsize:2`（800×600）會出現兩種解析度混在一起 |

## 繁化

- `data/`：`tools/convert_big5.py`（GBK → OpenCC s2tw → cp950）。原版日服遺留的 EUC-JP／Shift-JIS 檔不轉換；`¨`→`…`、`ー`→`－`、`″`→`〃`；其餘 cp950 沒有的字換成 `?`（大多是原本就已經是亂碼的日文殘留）
- 引擎訊息（歡迎詞、頻道、交易提示等）：`tools/patch_exe_msg.py` 直接修補 `cgmsv.exe` 內嵌的 `lang/msg.yml`（引擎不讀外部的 msg.yml）。常數名稱（`xxx%`）維持 GBK；Big5 字第二個位元組是 `\` 時補成 `\\`
- **Lua 不繁化**：轉換後模組會壞掉（Big5 第二位元組 0x5C 被當成跳脫字元，加上中文常數名稱對不上，例如 autoUnlock 失效、帳號一直被鎖）。Lua 送出的訊息維持簡體亂碼
- **無法處理**：cgmsv 包裝程式（有 VMProtect 類的保護殼）的標題列、狀態列提示。論壇上也沒有繁體版（2026-11-06 查 bbs.cgmsv.com 674／1120／1202／1489 帖）
- 待觀察：`data/` 裡有 3,787 處 Big5 字的第二位元組是 `\`（功、許、餐、蓋…），目前看起來正常

## 加速

- `tools/speed/winmm.dll`：代理 winmm（轉發 Wine winmm 全部匯出），`CG_SPEED>1` 且程序是 `cg.exe`／`cgmsv.exe` 時，把 kernel32 的 `GetTickCount`／`Sleep` 開頭改成跳到加速版（時間取自 QPC）
- 包裝程式 `cgmsv.exe` 是加殼的遊戲本體，遊戲在它自己的程序裡跑（不會另開 `cg.exe`），所以改 IAT 無效，要 inline hook
- `run-game.sh` 在有 `CG_SPEED` 時才複製 DLL 並設 `WINEDLLOVERRIDES=winmm=n,b`；沒設時 Wine 用內建 winmm
- 重新編譯：`tools/speed/build.sh`（用 scratchpad venv 裡的 `ziglang`，venv 不在 repo 裡，消失時重建：`python3 -m venv v && v/bin/pip install ziglang`）
- 伺服器端已關反作弊（`anitcheatingflg=0`、`highspeedblock=0`）
- 遊戲端每 60 秒（遊戲端時鐘）送一個 `DE`，加速後送得更勤，伺服器會判定 `CHEAT!! Client Accelerate 200.00%` 而斷線，這個檢查不受 `anitcheatingflg` 控制。設定在 `setup.cf`（反組譯 `cgmsv.exe` 對出來的）：`fctime=60`（標準間隔）、`fccount=5`（連續提早幾次才判定）、`fcwait=300`（多久沒收到就斷線）、`unfairuserdown`（1＝判定後斷線）。已改 `unfairuserdown=0`，只記錄不斷線，原檔 `setup.cf.bak-unfair`（2026-11-06）

## 自動戰鬥與測試

- 補給用完（有人血不到 30% 或 2 人以上不到一半、沒人會補血、也沒有回血藥，或全隊魔力剩不到 10%）時，戰鬥結束後整隊走去補血（觸發事件是 `ResetCharaBattleStateEvent`，逃跑或打贏後角色離開戰場時觸發）：
  - 挑最近的護士：東醫、西醫、伊爾村、維諾亞村、聖拉魯卡村、亞留特村的醫院。有人受傷而且付得起 100 G 時，只去有醫師的東醫／西醫，補完再走去醫師那裡治
  - 真的一步一步走（每 0.4 秒一格），隊員照隊長走過的路晚幾格跟；地圖之間照 `data/warp.txt` 的出入口找路；路上照那一格的遇敵率遇敵，打完接著走
  - 在護士那邊補滿血魔，並賣掉背包裡戰鬥中不能用的東西
  - 在村莊醫院補血時，順便開那個村的傳點；之後從法蘭城出發時，全隊都開過、等級夠、錢夠，就會走啟程之間付費傳過去
- 玩家在聊天打 `/auto` 開關（`server-b/modules-src/autobattle.utf8.lua`）。只用畫面看得到的資訊：我方血量、魔力、倒下、異常狀態；敵方位置、血條比例、倒下、異常狀態
- 無頭測試：`ModuleConfig.lua` 打開 `loadModule('abtest')`，伺服器啟動 30 秒後 24 隊假人（隨機職業 1～4 人、隨機技能組合、Lv 5／20／40／70）各打 4 場，log 的 `summary` 行有 WIN／LOSE／ESCAPED、回合數、秒數。96 場約 70 秒
- 逃跑成功時引擎回報的勝方是敵方，要用「還有人活著」區分逃跑和全滅
- 對照實驗：每隊另有一支雙胞胎（`arm=B`，同職業、同技能等級、同樣的怪，只差不逃跑），summary 行有 `pair=`／`arm=`／`n=` 可逐場比對
- 戰鬥中用道具：`Battle.ActionSelect(角色, BATTLE_COM_ITEM, 目標位置, 背包位置 8～27)`（`modules-src/itemprobe.utf8.lua` 實測）。回血藥「戰鬥可用」＝1、參數 `LPxxx`；回魔的料理／食物戰鬥中不能用
- 倒下的角色也要給指令，否則伺服器等 420 秒逾時

## 無頭角色（真帳號，不開遊戲）

- 管理頁：伺服器啟動後打開 `http://127.0.0.1:10086/bots.html`（http 模組已改成只聽 `127.0.0.1`，原檔 `lua/Modules/http.lua.orig`）。可新增帳號（沒有的帳號由 autoRegister 自動建立，該位置沒角色時用填的名字建角色，名字限英數字）、登入／登出、自動戰鬥、練等、遇敵一次、回醫院、傳送、組隊；列表可篩選、排序
- 點角色名看詳細資料（遊戲風格，圖要先用 `tools/cg_graphic.py` 解出來）：能力（自動／手動配點）、裝備（卸下）、背包（裝備、丟棄）、寵物（出戰／待命／休息、掉檔、技能）、職業與技能（只能選遊民或見習職業，GM 直接設；技能只學到 Lv1，之後靠戰鬥升級，顯示熟練度）
- `modules-src/botlogin.utf8.lua`：模組自己用 LuaJIT FFI（Winsock）連本機 9030，走和遊戲端一樣的登入流程，連線不斷，角色就是一般在線玩家；登出＝關連線，引擎照常存檔。帳號存在 `data.db3` 的 `bot_account` 表，`autologin=1` 的在伺服器啟動 10 秒後自動登入
- 協定是明文（`指令 參數… ` 加換行，用 port 9031 的抓包代理確認），不是 xgmsv 那套加密。戰鬥中遊戲端要做的事 bot 也照做：每回合回兩次 `Rg N`（不下指令，引擎再觸發 `AutoBattleCommandEvent` 由 autobattle 出招），戰鬥結束（`LYIm C|20`）回 `eL 0` 回到地圖；不回就會一直卡在戰鬥中
- 編碼：`Iconv` 只有 GBK↔UTF-8。API 的訊息回英數代碼（網頁翻中文），角色名回 Big5 原始位元組的 hex（網頁用 `TextDecoder('big5')` 解）
- 狀態存在角色身上（ExtData），登出、重啟後自動恢復：自動戰鬥開關（玩家打 `/auto` 也算）、練等與練功地點。練等中補給用完回醫院，補滿後自己走回練功點；練等中用網頁傳送＝換練功地點
- 自動選練功點：芙蕾雅野外加上走得進去的洞（維諾亞洞穴、哈巴魯東邊洞穴、兩個海底洞窟），依區域的怪物最高等級分級。基準＝最高等級 ≤ 隊伍等級＋2 的最強一級；每趟依實戰調整：連兩趟打 6 場以上升一級，不到 3 場或有人倒下降一級，降下來的那級要等隊伍升級才再試。練功點只挑從法蘭城東門外走得到的格子
- 自動配點：人物攻敏各半、寵物全力量；寵物等級落後主人時灌經驗補上
- 新角色建立時點數是力量 15、敏捷 15
- `modules-src/botpanel.utf8.lua`：網頁用的 API（`GET /api/bots`、`POST /api/botact`／`botadd`／`botdel`）

## 卡關紀錄

- **伺服器 6 秒後結束，`ERROR: CPU NOT SUPPORTED.`** → `ROSETTA_ADVERTISE_AVX=1`（自製 CPUID 程式驗證：設定後 BMI2=1）
- **文字亂碼，之後變成方框** → 語系＋`cjk-fonts.reg`。導向 macOS 黑體的做法試了兩次都無效
- **`一键启动.exe` 崩潰** → 它開伺服器時的工作目錄不對，改為分開啟動
- **崩潰 `0x7BF41239`（wow64cpu.dll）、包裝程式黑畫面** → `renderer=gdi`
- **角色清單顯示 locked** → 異常關閉留下 `tbl_lock`；`run-start.sh` 會在伺服器沒在跑時清除
- **新伺服器卡住不載入** → 用 `pkill` 殺掉後，wineserver 還殘留舊程序；一律用 `run-stop.sh`
- **伺服器偶爾啟動就崩潰**（約 10 次 2 次）：`server-b.log` 開頭 `Unhandled page fault on read access to 0000000000000178 at address 00000001401C877B`，在開機畫面後、載入 Lua 前，引擎本體的工作執行緒。`run-start.sh` 偵測到就 `pkill -f winedbg` 自動重試一次；`run-server.sh` 啟動前把上次的崩潰 log 另存成 `server-b-crash-<時間>.log`，累積幾份再比對是不是每次同一處
- **bot 建角色偶爾 `DZ failed -1`**：引擎同時處理多個建角色時，各自寫 SQLite，搶不到鎖的那個不等待直接失敗（`server-b.log`：`db.cpp query err (database is locked)`、`err:update character`）。只有 bot 會同時建，真遊戲端不會。帳號先寫好 `tbl_user` 也一樣會失敗，所以不是 autoRegister 造成的。botlogin 收到 `DZ failed` 會重新要清單再建，最多 3 次（實測失敗 2 次後第 3 次成功）（2026-11-06）
- **bot 上線 5 分鐘被踢**：`server-b.log` 出現 `Client not send FC`。進遊戲後 5 分鐘內沒收到 `DE` 就斷線，真遊戲端每 60 秒送一次。botlogin 照樣每 60 秒送；改成 30 秒會被當成加速外掛踢掉（`CHEAT!! Client Accelerate 200.00%`），間隔要和真遊戲端一樣（2026-11-06）
- **技能一用就跳到職業上限、重開後學的技能不見**：`cgmsv.cf` 的技能等級上限是 cgmsv 預設的 15，但台版的技能經驗表每行只有 13 級左右的門檻（原版上限 10 級），啟動 log 每行都報 `skill/skill.c:999 數據不足 data/skillexp.txt`。`maxskilllevel`／`maxcraftskilllevel`／`maxtechlevel` 改回 10 後正常（每場 +10 熟練度），原檔 `cgmsv.cf.bak-skilllv`（2026-11-06）
- **bot 從村莊醫院走不出去、回程都直接傳送**：護士旁邊選的站位在櫃檯後面，出入口那格又被判定成不能走。改成先算每張地圖的連通區域，站位、出入口、練功點都只挑走得到的（2026-11-06）
- **第 6 個 bot 進不了遊戲（`hPUd failed locked`）**：`cgmsv.cf` 的 `loginnum=5` 是同一個 IP 最多 5 個連線，log 會出現 `IP exceeds login limit`，而且帳號會被鎖。bot 全部從 127.0.0.1 連，所以改成 `loginnum=0`（不限），原檔 `cgmsv.cf.bak-loginnum`（2026-11-06）

## 下一步

- [x] AI 隊友：不做傭兵，改用 bot（真帳號角色會存檔、升級、能分工；傭兵是臨時 NPC，上游也沒有授權條款）（2026-11-06）
- [ ] 只讓自己登入：組好隊後拿掉 `autoRegister`
- [ ] 就職任務：目前職業是網頁直接設；正規流程要拿信、走國營第24坑道換介紹信、找職業導師（任務鏈還沒追完）
- [ ] 傳點實際被路線用到時，確認扣款與路線（目前只驗過開傳點）
- [x] http 模組改成只聽 `127.0.0.1`（2026-11-06，bot 管理 API 不對區網開放）
- [x] 關閉反作弊：`cgmsv.cf` 的 `anitcheatingflg=0`、`highspeedblock=0`（2026-11-06，原檔 `cgmsv.cf.bak-20261106`），為遊戲端加速做準備
