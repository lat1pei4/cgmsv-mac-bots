# cgmsv 26.8d Lua API：Data / Protocol / Recipe / Skill / Stall / Tech / TechArea / Guild / SQL / Cron / Setup / Http / Func / BattleCommands / BT 與全部事件

產出日期 2026-11-06。唯讀整理，未啟動伺服器。

**依據欄路徑基準**：`lua参考/…` = `~/Desktop/Personal/crossgate/server-b/lua参考/`（官方 EmmyLua 風格註解，GBK，行號為原檔行號）；`gmsv/lua/…` = `~/Desktop/Personal/crossgate/server-b/gmsv/lua/`；`apidump.txt` = `docs/api/apidump.txt`；`exe_strings.txt` 不進版控，要對照時用 `strings -n 3 server-b/gmsv/cgmsv.exe > exe_strings.txt` 重建（行號以此指令產生的檔為準）；`data/…` = `server-b/gmsv/data/`。

**狀態欄定義**：已確認＝文件註解或原始碼有明確依據（附 `檔案:行`），其中標【實測】者為使用者實測過；推測＝依資料表／命名推得，文中以「推測」標明；未驗證＝只有名稱。

**事件鏈規則（重要）**：用 `self:regCallback(事件名, fn[, extSign])`（`gmsv/lua/libs/Module/ModuleBase.lua:104`）註冊的回呼會進 `gmsv/lua/libs/GlobalEvents.lua` 的鏈。多個模組註冊同一事件時，依 `OrderedCallback(fn, order)` 的 order 由大到小執行（`GlobalEvents.lua:389` 起 `regGlobalEvent`）；各事件的合併規則寫在「回傳值意義」欄。沒有特別規則的事件走 `defaultChain`（`GlobalEvents.lua:321`，回傳最後一個回呼的值）。回呼內丟錯會被 pcall 攔住並回 nil（`GlobalEvents.lua:401`）。


## BT

| 函式 | 參數 | 回傳 | 用途 | 依據 | 標籤 | 狀態 |
|---|---|---|---|---|---|---|
| `BT.createTree` | `(name, path, env)` | table（行為樹） | 載入 lua/Modules/BehaviorTree/trees/<path> 的 JSON 建行為樹（behavior3lua）；目前 Modules/ 下沒有 BehaviorTree 目錄，需自備樹檔 | lua参考/BT.lua:8；gmsv/lua/libs/BehaviorTree.lua:21 | 其他 | 已確認 |
| `BT.reInitProcess` | `(func)` | 無 | 重置行為樹節點處理器列表（傳入產生新節點列表的函式） | lua参考/BT.lua:12；gmsv/lua/libs/BehaviorTree.lua:27 | 其他 | 已確認 |

## BattleCommands

| 函式 | 參數 | 回傳 | 用途 | 依據 | 標籤 | 狀態 |
|---|---|---|---|---|---|---|
| `BattleCommands.GetTargets` | `(未知)` | targets（可攻擊站位）, allowTargets（可指定站位） | 依攻擊者站位算可攻擊目標：攻擊者站位 <5 且非遠程武器只能打對面 10-14（反之 0-4），站位>=5 或遠程武器可打 10-19（反之 0-9）；allowTargets 另含己方整列 | gmsv/lua/libs/Gmsv/BattleEx.lua:4 | 戰鬥 | 已確認 |
| `BattleCommands.Attack` | `(battleIndex, attackerSlot, action, slot)` | 0=成功、-1=攻擊者無效 | 幫角色下「攻擊」指令（寫 CHAR_BattleCom1/2/3；action==1 寫第二動 Battle2Com）；目標無效則隨機挑 | gmsv/lua/libs/Gmsv/BattleEx.lua:33；疑似 off-by-one：targets[math.random(0,#targets)] 的 0 號索引為 nil（推測，未實測） | 戰鬥 | 已確認 |

## Cron

| 函式 | 參數 | 回傳 | 用途 | 依據 | 標籤 | 狀態 |
|---|---|---|---|---|---|---|
| `Cron.AddCron` | `(cron, fn, _repeat)` | number（任務 id，0=失敗） | 以 cron 字串（分 時 日 月 星期）排程；_repeat 1=重複、0=只一次 | lua参考/Cron.lua:6 | 排程 | 已確認 |
| `Cron.AddInterval` | `(interval, fn, _repeat)` | number（任務 id，0=失敗） | 每隔 interval 毫秒執行；_repeat 1=重複、0=一次 | lua参考/Cron.lua:13 | 排程 | 已確認 |
| `Cron.RunAt` | `(timestamp, fn)` | number（任務 id，0=失敗） | 在指定 unix 時間戳執行一次（用法 Cron.RunAt(os.time()+秒, fn)） | lua参考/Cron.lua:19；實測；gmsv/lua/Modules/autobattle.lua:652、itemprobe.lua:99、areaprobe.lua:99 | 排程 | 已確認 |
| `Cron.RemoveTask` | `(id)` | number（移除的數量） | 依任務 id 取消排程 | lua参考/Cron.lua:24 | 排程 | 已確認 |

## Data

| 函式 | 參數 | 回傳 | 用途 | 依據 | 標籤 | 狀態 |
|---|---|---|---|---|---|---|
| `Data.GetMessage` | `(msgId)` | string（訊息內容） | 讀 msg 訊息表第 msgId 條（data/msg.txt） | lua参考/Data.lua:6 | 資料表 | 已確認 |
| `Data.SetMessage` | `(msgId, val)` | 無 | 改寫訊息第 msgId 條 | lua参考/Data.lua:11 | 資料表 | 已確認 |
| `Data.SetTribeMapValue` | `(a, b, rate)` | number（傷害比率） | 設定種族相剋表：進攻種族 a→防守種族 b 的克制比率（-128~127，種族 0~19） | lua参考/Data.lua:18 | 戰鬥 | 已確認 |
| `Data.EnemyGetDataIndex` | `(enemyId)` | number（EnemyDataIndex） | 由 enemyId 換 index（data/enemy.txt，4433 列） | lua参考/Data.lua:23 | 資料表 | 已確認 |
| `Data.EnemyGetData` | `(enemyIndex, DataPos)` | number\|string | 讀 enemy 欄位（CONST.DATA_ENEMY_*：TEMPNO=1、LV_MIN/MAX=2/3、EXP=7、DUELPOINT=8、PETFLG=10、ITEM1..=11…） | lua参考/Data.lua:29 | 資料表 | 已確認 |
| `Data.EnemySetData` | `(enemyIndex, DataPos, val)` | 0=成功 | 改 enemy 欄位 | lua参考/Data.lua:36 | 資料表 | 已確認 |
| `Data.EnemyBaseGetDataIndex` | `(enemyBaseId)` | number | 由 enemyBaseId 換 index（data/enemybase.txt，1587 列） | lua参考/Data.lua:41 | 資料表 | 已確認 |
| `Data.EnemyBaseGetData` | `(enemyBaseIndex, DataPos)` | number\|string | 讀 enemybase 欄位（CONST.DATA_ENEMYBASE_*；lua参考/CONST.lua:1199 起） | lua参考/Data.lua:47 | 資料表 | 已確認 |
| `Data.EnemyBaseSetData` | `(enemyBaseIndex, DataPos, val)` | 0=成功 | 改 enemybase 欄位 | lua参考/Data.lua:54 | 資料表 | 已確認 |
| `Data.ItemsetGetIndex` | `(ItemID)` | number | 由道具 id 換 itemset index（data/itemset.txt，8783 列） | lua参考/Data.lua:59 | 資料表 | 已確認 |
| `Data.ItemsetGetData` | `(ItemsetIndex, DataPos)` | number\|string | 讀 itemset 欄位（CONST.ITEMSET_*）；改 itemset 影響之後生成的道具 | lua参考/Data.lua:65 | 資料表 | 已確認 |
| `Data.ItemsetSetData` | `(ItemsetIndex, DataPos, val)` | 0=成功 | 改 itemset 欄位 | lua参考/Data.lua:72 | 資料表 | 已確認 |
| `Data.GetEncountIndex` | `(encountId)` | number | 由 encountId 換 index（data/encount.txt，2983 列） | lua参考/Data.lua:77 | 資料表 | 已確認 |
| `Data.GetEncountData` | `(encountIndex,DataPos)` | number\|string | 讀遇敵設定欄位（CONST.ENCOUNT_*） | lua参考/Data.lua:83 | 資料表 | 已確認 |
| `Data.SetEncountData` | `(encountIndex,DataPos,val)` | 0=成功 | 改遇敵設定欄位 | lua参考/Data.lua:90 | 資料表 | 已確認 |
| `Data.GetJobIndex` | `(jobId)` | number | 由職業 id 換 JobIndex（data/jobs.txt，324 列） | lua参考/Data.lua:95 | 資料表 | 已確認 |
| `Data.GetJobData` | `(jobIndex, dataPos)` | number\|string | 讀職業欄位（CONST.JOBS_*） | lua参考/Data.lua:101 | 資料表 | 已確認 |
| `Data.SetJobData` | `(jobIndex, dataPos, data)` | 0=成功 | 改職業欄位 | lua参考/Data.lua:108 | 資料表 | 已確認 |
| `Data.GetJobAncestryIndex` | `(jobAncestryId)` | number | 由職系 id 換 index（data/jobsancestry.txt，48 列） | lua参考/Data.lua:113 | 資料表 | 已確認 |
| `Data.GetJobAncestryData` | `(jobAncestryIndex, dataPos)` | number\|string | 讀職系欄位（CONST.JOBS_ANCESTRY_*） | lua参考/Data.lua:119 | 資料表 | 已確認 |
| `Data.SetJobAncestryData` | `(jobAncestryIndex, dataPos, data)` | 0=成功 | 改職系欄位 | lua参考/Data.lua:126 | 資料表 | 已確認 |
| `Data.GetEncountGroupIndex` | `(groupId)` | number | 由 group.txt 的 id 換 groupIndex（group.txt 2385 列） | lua参考/Data.lua:132 | 資料表 | 已確認 |
| `Data.GetEncountGroupData` | `(groupIndex, dataline)` | number\|string | 讀遇敵組欄位（CONST.ENCOUNT_GROUP_*） | lua参考/Data.lua:139 | 資料表 | 已確認 |
| `Data.SetEncountGroupData` | `(groupIndex, dataline, val)` | 0=成功 | 改遇敵組欄位 | lua参考/Data.lua:147 | 資料表 | 已確認 |
| `Data.GetEnemyBaseIdByEnemyId` | `(enemyId)` | number\|nil | 包裝：enemyId→enemy 表的 TEMPNO 欄（對應 enemybase id）；找不到回 nil | gmsv/lua/libs/Gmsv/DataEx.lua:3 | 資料表 | 已確認 |
| `Data.GetEnemyBaseIndexByEnemyId` | `(enemyId)` | number\|nil | 包裝：enemyId→EnemyBase index（連呼叫上一個再 EnemyBaseGetDataIndex） | gmsv/lua/libs/Gmsv/DataEx.lua:15 | 資料表 | 已確認 |

## Func

| 函式 | 參數 | 回傳 | 用途 | 依據 | 標籤 | 狀態 |
|---|---|---|---|---|---|---|
| `Func.bind` | `(fn, ...)` | function | 把參數預先綁定進函式（regCallback 常用 Func.bind(self.onX, self)） | gmsv/lua/libs/functions.lua:8 | 其他 | 已確認 |

## Guild

| 函式 | 參數 | 回傳 | 用途 | 依據 | 標籤 | 狀態 |
|---|---|---|---|---|---|---|
| `Guild.GetBrief` | `(未知)` | 未驗證 | 未驗證；字面推測：查公會簡介／成員／名稱／房間／伺服器／狀態／稱號名；參數推測為 guildId（Char.GetGuildID 見 lua参考/Char.lua:311） | 僅名稱（exe_strings.txt:180194）；lua参考 沒有 Guild.lua | 其他 | 未驗證 |
| `Guild.GetMember` | `(未知)` | 未驗證 | 未驗證；字面推測：查公會簡介／成員／名稱／房間／伺服器／狀態／稱號名；參數推測為 guildId（Char.GetGuildID 見 lua参考/Char.lua:311） | 僅名稱（exe_strings.txt:180196）；lua参考 沒有 Guild.lua | 其他 | 未驗證 |
| `Guild.GetName` | `(未知)` | 未驗證 | 未驗證；字面推測：查公會簡介／成員／名稱／房間／伺服器／狀態／稱號名；參數推測為 guildId（Char.GetGuildID 見 lua参考/Char.lua:311） | 僅名稱（exe_strings.txt:180192）；lua参考 沒有 Guild.lua | 其他 | 未驗證 |
| `Guild.GetRoomName` | `(未知)` | 未驗證 | 未驗證；字面推測：查公會簡介／成員／名稱／房間／伺服器／狀態／稱號名；參數推測為 guildId（Char.GetGuildID 見 lua参考/Char.lua:311） | 僅名稱（exe_strings.txt:180193）；lua参考 沒有 Guild.lua | 其他 | 未驗證 |
| `Guild.GetRoomType` | `(未知)` | 未驗證 | 未驗證；字面推測：查公會簡介／成員／名稱／房間／伺服器／狀態／稱號名；參數推測為 guildId（Char.GetGuildID 見 lua参考/Char.lua:311） | 僅名稱（exe_strings.txt:180191）；lua参考 沒有 Guild.lua | 其他 | 未驗證 |
| `Guild.GetServer` | `(未知)` | 未驗證 | 未驗證；字面推測：查公會簡介／成員／名稱／房間／伺服器／狀態／稱號名；參數推測為 guildId（Char.GetGuildID 見 lua参考/Char.lua:311） | 僅名稱（apidump.txt:224-232）；lua参考 沒有 Guild.lua | 其他 | 未驗證 |
| `Guild.GetStatus` | `(未知)` | 未驗證 | 未驗證；字面推測：查公會簡介／成員／名稱／房間／伺服器／狀態／稱號名；參數推測為 guildId（Char.GetGuildID 見 lua参考/Char.lua:311） | 僅名稱（apidump.txt:224-232）；lua参考 沒有 Guild.lua | 其他 | 未驗證 |
| `Guild.GetTitleName` | `(未知)` | 未驗證 | 未驗證；字面推測：查公會簡介／成員／名稱／房間／伺服器／狀態／稱號名；參數推測為 guildId（Char.GetGuildID 見 lua参考/Char.lua:311） | 僅名稱（exe_strings.txt:180195）；lua参考 沒有 Guild.lua | 其他 | 未驗證 |

## Http

| 函式 | 參數 | 回傳 | 用途 | 依據 | 標籤 | 狀態 |
|---|---|---|---|---|---|---|
| `Http.Init` | `()` | 無 | 初始化 Http 伺服器（使用前必須先呼叫） | lua参考/Http.lua:4；gmsv/lua/Modules/http.lua:16 | 網路 | 已確認 |
| `Http.Start` | `(addr, port)` | 1=成功 | 在 addr:port 啟動 Http 服務（port 建議 10000 以上） | lua参考/Http.lua:10；gmsv/lua/Modules/http.lua:23（0.0.0.0:10086） | 網路 | 已確認 |
| `Http.Send` | `(url, httpMethod, contentType, body, timeout)` | reqId | 發出 Http 請求（不支援 https），結果由 HttpResultEvent 回報 | lua参考/Http.lua:19 | 網路 | 已確認 |
| `Http.Stop` | `()` | 1=成功 | 關閉 Http 伺服器（請求處理中停止會回 502 並強制關閉未完成的請求） | lua参考/Http.lua:23；gmsv/lua/Modules/http.lua:123 | 網路 | 已確認 |
| `Http.GetStatus` | `()` | 0 未初始化／1 未啟動／2 執行中 | 查 Http 服務狀態 | lua参考/Http.lua:27；gmsv/lua/Modules/http.lua:12 | 網路 | 已確認 |
| `Http.AddMountPoint` | `(path, dir)` | 1=成功 | 把本機目錄掛成靜態資源路徑 | lua参考/Http.lua:33；gmsv/lua/Modules/http.lua:18（"/" → ./lua/www/） | 網路 | 已確認 |
| `Http.RemoveMountPoint` | `(path)` | 1=成功 | 移除靜態資源掛載 | lua参考/Http.lua:38 | 網路 | 已確認 |
| `Http.RegApi` | `(api)` | 1=成功 | 註冊 API 路徑；沒註冊的路徑不會以 HttpRequestEvent 交給 Lua | lua参考/Http.lua:43；gmsv/lua/Modules/http.lua:111 | 網路 | 已確認 |
| `Http.UnregApi` | `(api)` | 1=成功 | 取消註冊 API 路徑 | lua参考/Http.lua:48；gmsv/lua/Modules/http.lua:119 | 網路 | 已確認 |

## Protocol

| 函式 | 參數 | 回傳 | 用途 | 依據 | 標籤 | 狀態 |
|---|---|---|---|---|---|---|
| `Protocol.FlushBuffer` | `(未知)` | 未驗證 | 未驗證；字面推測：立刻送出該連線的發送緩衝 | 僅名稱（exe_strings.txt:180202；apidump.txt:572-583） | 網路 | 未驗證 |
| `Protocol.GetCharByFd` | `(Fd)` | charIndex，失敗 -1 | 由連線 fd 取玩家 charIndex（與 GetCharIndexFromFd 等價） | lua参考/Protocol.lua:22；gmsv/lua/Module/nofix/Captcha.lua:118 | 網路 | 已確認 |
| `Protocol.GetCharIndexFromFd` | `(fd)` | charIndex，失敗 -1 | 同上 | lua参考/Protocol.lua:27；gmsv/lua/Modules/bagSwitch.lua:44 | 網路 | 已確認 |
| `Protocol.GetFdByCharIndex` | `(charIndex)` | fd | 由 charIndex 取連線 fd | lua参考/Protocol.lua:51 | 網路 | 已確認 |
| `Protocol.GetIp` | `(fd)` | ip | 取客戶端 IP | lua参考/Protocol.lua:46 | 網路 | 已確認 |
| `Protocol.OnRecv` | `(Dofile, FuncName, PacketID)` | any | 註冊「收到指定封包頭」的回呼（回呼 (Fd, Head, Packet)，回 0 放行、1 攔截）；模組請用 regCallback('ProtocolOnRecv', fn, 封包頭) | lua参考/Protocol.lua:9；gmsv/lua/libs/GlobalEvents.lua:363 | 網路 | 已確認 |
| `Protocol.Send` | `(CharIndex, header, ...)` | 1=成功、0=失敗 | 對指定角色自訂送出封包（header + 內容） | lua参考/Protocol.lua:34；gmsv/lua/Modules/adminCommands.lua:143 | 網路 | 已確認 |
| `Protocol.SendToFd` | `(fd, header, ...)` | 1=成功、0=失敗 | 對指定 fd 自訂送出封包 | lua参考/Protocol.lua:41 | 網路 | 已確認 |
| `Protocol.makeEscapeString` | `(str)` | string | 把內容字串編碼成封包用的跳脫字串 | lua参考/Protocol.lua:56 | 網路 | 已確認 |
| `Protocol.makeStringFromEscaped` | `(str)` | string | 把封包跳脫字串解碼 | lua参考/Protocol.lua:61 | 網路 | 已確認 |
| `Protocol.nrprotoEscapeString` | `(str)` | string | 封包字串編碼（nrproto 版） | lua参考/Protocol.lua:66 | 網路 | 已確認 |
| `Protocol.nrprotoUnescapeString` | `(str)` | string | 封包字串解碼（nrproto 版） | lua参考/Protocol.lua:71 | 網路 | 已確認 |

## Recipe

| 函式 | 參數 | 回傳 | 用途 | 依據 | 標籤 | 狀態 |
|---|---|---|---|---|---|---|
| `Recipe.GetData` | `(recipeNo, dataLine)` | string\|number | 讀配方欄位（資料表 itemrecipe.txt，dataLine 用 CONST.ITEM_RECIPE_*：ID=0 配方 id、ITEMID=1 成品道具 id、SKILLID=2 所需製造技能、EXP=3、A~E=4~8 材料道具 id、REQUIRE_A~E=9~13 材料數量、NAME=4000） | lua参考/Recipe.lua:7；gmsv/lua/Modules/adminCommands.lua:56；欄位對照已用 data/itemrecipe.txt 與 data/itemset.txt 比對（長劍 id0→成品 itemset id 8、技能 200 鑄劍、材料 9611 銅條） | 製造 | 已確認 |
| `Recipe.SetData` | `(recipeNo, dataLine,val)` | number（0=成功） | 改配方欄位（推測：只改記憶體，不寫回 itemrecipe.txt，未驗證） | lua参考/Recipe.lua:14 | 製造 | 已確認 |
| `Recipe.GiveRecipe` | `(charIndex, recipeNo)` | 1=成功、0=失敗、-1 charIndex 無效、-2 配方無效、-3 已擁有 | 讓角色學會配方（角色最多 64 個配方槽：tbl_character 有 Recipe1..Recipe64 欄，exe_strings.txt:181138） | lua参考/Recipe.lua:20；gmsv/lua/Modules/adminCommands.lua:50 | 製造 | 已確認 |
| `Recipe.RemoveRecipe` | `(charIndex, recipeNo)` | 同 GiveRecipe（文件複製了同一份，-3 疑為「未擁有」，推測） | 刪除角色的配方 | lua参考/Recipe.lua:26；gmsv/lua/Modules/adminCommands.lua:46 | 製造 | 已確認 |
| `Recipe.HasRecipe` | `(charIndex, recipeNo)` | 1=有、0=無、-1 charIndex 無效、-2 配方無效 | 判斷角色是否已學會配方 | lua参考/Recipe.lua:32；（無伺服器端用例） | 製造 | 已確認 |

## SQL

| 函式 | 參數 | 回傳 | 用途 | 依據 | 標籤 | 狀態 |
|---|---|---|---|---|---|---|
| `SQL.Run` | `(QueryString)` | number\|table（INSERT/DELETE 等 0=成功；SELECT 無結果 nil，有結果 table，鍵為 "列_欄" 如 ["0_0"]，另有 row／field） | 執行 MySQL 語句（伺服器資料庫，可直接查 tbl_character 等） | lua参考/SQL.lua:6；gmsv/lua/Module/namechanger.lua:142；返回格式見 gmsv/lua/libs/sql.lua:27-45 | 存檔掛機 | 已確認 |
| `SQL.Query` | `(QueryString)` | 同 Run | 同 Run（別名） | lua参考/SQL.lua:11 | 存檔掛機 | 已確認 |
| `SQL.QueryEx` | `(sql, ...)` | {status, effectRows, rows} | 帶參數綁定（? 佔位，最多 40 個）的查詢，rows 為列表可用欄名取值 | lua参考/SQL.lua:17；gmsv/lua/Modules/http.lua:69 | 存檔掛機 | 已確認 |
| `SQL.GetConn` | `()` | MysqlConn | 取得連線物件（:Query、:BeginTrans、:Commit、:Rollback、:Release）；用完必須 Release，否則連線池耗盡 | lua参考/SQL.lua:21 | 存檔掛機 | 已確認 |
| `SQL.querySQL` | `(sql, returnNil)` | table[row][col]（1 起算）｜無列時回 SQL.CONST_RET_NO_ROW(-3)（returnNil=true 則回 nil） | 包裝 SQL.Run，把 "列_欄" 鍵轉成二維陣列 | gmsv/lua/libs/sql.lua:27 | 存檔掛機 | 已確認 |
| `SQL.sqlValue` | `(s)` | string | 把 Lua 值轉成 SQL 字面值（字串加引號並跳脫 \ 與 '，nil→null） | gmsv/lua/libs/sql.lua:4 | 存檔掛機 | 已確認 |

## Setup

| 函式 | 參數 | 回傳 | 用途 | 依據 | 標籤 | 狀態 |
|---|---|---|---|---|---|---|
| `Setup.GetJobFameLimit` | `(job)` | number | 取職業／職系聲望上限 | lua参考/Setup.lua:6 | 資料表 | 已確認 |
| `Setup.SetJobFameLimit` | `(job, limit)` | 1=成功 | 設職業／職系聲望上限 | lua参考/Setup.lua:12 | 資料表 | 已確認 |

## Skill

| 函式 | 參數 | 回傳 | 用途 | 依據 | 標籤 | 狀態 |
|---|---|---|---|---|---|---|
| `Skill.GetData` | `(skillIndex, dataLine)` | string\|number | 讀技能欄位（data/skill.txt，CONST.SKILL_*：ID=0、DEFAULTMAXLEVEL=3、EXPTABLE=4、COST=5、DIFFICULTY=6、JOBS=16、RATE=17、NAME=4000）；skill.txt 內 200~220 製造、223 急救、224 治療、225 伐木、226 狩獵、227 挖掘 | lua参考/Skill.lua:7；欄位順序已與 data/skill.txt 逐欄比對（200 鑄劍→ id200、EXPTABLE=5 對 skillexp.txt 第 5 列） | 技能 | 已確認 |
| `Skill.SetData` | `(skillIndex, dataLine, val)` | number（0=成功） | 改技能欄位 | lua参考/Skill.lua:14 | 技能 | 已確認 |
| `Skill.GetSkillIndex` | `(id)` | number（skillIndex） | 由技能 id 換 skillIndex（Skill.GetData/SetData 要的是 index，不是 id） | lua参考/Skill.lua:19 | 技能 | 已確認 |
| `Skill.GetMaxSkillLevelOfJob` | `(skillIndex, job)` | number | 取某職業對某技能的最高等級（推測資料來源 data/skilllv.txt：欄位為 序號、技能id、職業id、最高等級；例 技能200 在職業 11→1、16→5、17→6） | lua参考/Skill.lua:25；data/skilllv.txt（51591 列 4 欄）的規律推得；函式本身回傳值依文件 | 技能 | 推測 |
| `Skill.CheckInGroup` | `(未知，推測 skillId, groupId)` | 未驗證（推測 1/0） | 未驗證；推測：檢查技能是否屬於 data/skillgroup.yml 定義的技能組（組0=[100,101]、組1=[200]） | 僅名稱（apidump.txt:605）；data/skillgroup.yml 僅作旁證 | 技能 | 未驗證 |

## Stall

| 函式 | 參數 | 回傳 | 用途 | 依據 | 標籤 | 狀態 |
|---|---|---|---|---|---|---|
| `Stall.Start` | `(charIndex, name, desc, itemPriceList, petPriceList)` | 無 | 讓角色開始擺攤；itemPriceList／petPriceList 的 table 格式文件未寫（推測：以欄位位置為 key、價格為值，未驗證） | lua参考/Stall.lua:9 | 交易 | 已確認 |
| `Stall.End` | `(charIndex)` | 無 | 結束擺攤 | lua参考/Stall.lua:13 | 交易 | 已確認 |
| `Stall.BuyItem` | `(buyer, seller, pos)` | 無（文件未寫） | 讓 buyer 買 seller 攤位第 pos 格（0-19）的道具；對應事件 CharaStallSoldEvent | lua参考/Stall.lua:19 | 交易 | 已確認 |
| `Stall.BuyPet` | `(buyer, seller, pos)` | 無（文件未寫） | 讓 buyer 買 seller 攤位第 pos 格（0-4）的寵物 | lua参考/Stall.lua:25 | 交易 | 已確認 |
| `Stall.GetItemPrice` | `(charIndex, pos)` | 未寫（推測：價格數字） | 查攤位某格道具價格（0-19） | lua参考/Stall.lua:30 | 交易 | 已確認 |
| `Stall.GetPetPrice` | `(charIndex, pos)` | 未寫（推測：價格數字） | 查攤位某格寵物價格（0-4） | lua参考/Stall.lua:35 | 交易 | 已確認 |

## Tech

| 函式 | 參數 | 回傳 | 用途 | 依據 | 標籤 | 狀態 |
|---|---|---|---|---|---|---|
| `Tech.GetData` | `(techIndex, dataLine)` | string\|number | 讀技能（招式）欄位（data/tech.txt，CONST.TECH_*：SKILLID=2、NECESSARYLV=3、COST=6、FORCEPOINT=8…） | lua参考/Tech.lua:7 | 技能 | 已確認 |
| `Tech.SetData` | `(techIndex, dataLine, val)` | number（0=成功） | 改招式欄位 | lua参考/Tech.lua:14 | 技能 | 已確認 |
| `Tech.GetTechIndex` | `(techId)` | number（TechIndex；>=0 為存在） | 由 techId 換 TechIndex | lua参考/Tech.lua:19；實測；gmsv/lua/Modules/autobattle.lua:100（Tech.GetTechIndex(id) >= 0 判斷招式是否存在） | 技能 | 已確認 |

## TechArea

| 函式 | 參數 | 回傳 | 用途 | 依據 | 標籤 | 狀態 |
|---|---|---|---|---|---|---|
| `TechArea.CreateTechArea` | `(mapId, floor, x, y, w, h, name, skillId, zOrder, failedProb, needItem, itemId1, rate1, itemId2, rate2, itemId3, rate3, itemId4, rate4, itemId5, rate5, itemId6, rate6, itemId7, rate7, itemId8, rate8, itemId9, rate9, itemId10, rate10)` | number（>=0 成功的區域 Index） | 在地圖上建立採集區域（技能 id、失敗率、所需道具、最多 10 種產物及機率）；對應 data/techarea.txt（2237 列，技能 227 挖掘／226 狩獵／254 釣魚） | lua参考/TechArea.lua:36 | 採集 | 已確認 |
| `TechArea.RemoveTechArea` | `(index)` | 0=成功 | 移除採集區域 | lua参考/TechArea.lua:41 | 採集 | 已確認 |
| `TechArea.GetIndexList` | `(mapId, floor, x, y, skillId)` | count（>=0 成功）, list={ {index,zOrder}... } | 查某座標、某採集技能涵蓋的所有採集區域 | lua参考/TechArea.lua:51 | 採集 | 已確認 |
| `TechArea.GetData` | `(areaIndex, dataLine)` | string\|number | 讀採集區欄位（CONST.TECH_AREA_*：SKILLID=3、MAPID=6、FLOOR=7、FROMX/FROMY/TOX/TOY=8~11、ZORDER=12、FAILEDPROB=13、ITEMID1..10=14~23、ITEMPROB1..10=24~33、NEED_ITEM=34、NAME=4000） | lua参考/TechArea.lua:57 | 採集 | 已確認 |
| `TechArea.SetData` | `(areaIndex, dataLine, value)` | 0=成功 | 改採集區欄位（動態調整產物與機率） | lua参考/TechArea.lua:64 | 採集 | 已確認 |

## 事件（EventName alias 全部 93 個，順序同 `gmsv/lua/libs/Module/ModuleBase.lua:102`）

| 事件 | 回呼參數 | 觸發時機 | 回傳值意義 | 依據 | 標籤 | 狀態 |
|---|---|---|---|---|---|---|
| `ProtocolOnRecv` | `(fd, head, data)`（data 為封包欄位陣列，data[3] 起為內容，見 autoRegister.lua:12） | 伺服器收到指定封包頭的封包時（regCallback 第三參數 extSign 即封包頭，例 'JFVf'、'SWITMM'） | 1=攔截該封包、0=放行（GlobalEvents 鏈：任一回呼回非 0 或 true 即回 1 攔截；註解寫「<0 攔截」與程式不符，以程式為準） | gmsv/lua/libs/GlobalEvents.lua:122；gmsv/lua/Modules/autoRegister.lua:8、Modules/bagSwitch.lua:21、Modules/autoUnlock.lua:54；lua参考/Protocol.lua:9-17（OnRecvCallBack） | 網路 | 已確認 |
| `EnemyCommandEvent` | `(battleIndex, side, slot, action)` | 怪物執行 AI 前 | 文件未寫回傳意義（推測：回值不影響行為） | lua参考/NL.lua:848（Reg）/856（回呼）；exe_strings.txt:180572 | 戰鬥 | 推測 |
| `BattleCalcDexEvent` | `(battleIndex, charaIndex, action, flg, dex)` | 戰鬥計算行動優先順序（dex）時 | 回傳修改後的 dex（數字才採用；GlobalEvents 鏈式累積） | lua参考/NL.lua:1398（Reg）/1408（回呼）；gmsv/lua/libs/GlobalEvents.lua:287；exe_strings.txt:180597 | 戰鬥 | 已確認 |
| `ItemInitEvent` | `(CharIndex, ItemIndex)` | 所有道具初始化時（登入、取得／建立新道具、開銀行、開公會倉庫）；註冊即全部觸發，會加重引擎負載 | 無（不消費回傳） | lua参考/NL.lua:521（Reg）/527（回呼）；exe_strings.txt:180554 | 其他 | 已確認 |
| `CheckDummyDollEvent` | `(charIndex, battleIndex, dmg, type)` | 替身娃娃（A/B 型）結算前 | 回 1=可使用娃娃、0=禁用娃娃 | lua参考/NL.lua:862（Reg）/871（回呼）；exe_strings.txt:180575 | 戰鬥 | 已確認 |
| `ItemUseEvent` | `(CharIndex, TargetCharIndex, ItemSlot)` | 玩家使用道具時（含戰鬥中） | <0=取消使用、>=0=正常使用（GlobalEvents 鏈：任一回呼回 <0 即攔截並回 -1） | lua参考/NL.lua:533（Reg）/541（回呼）；gmsv/lua/libs/GlobalEvents.lua:187；exe_strings.txt:180555 | 其他 | 已確認 |
| `ItemAttachEvent` | `(CharIndex, FromItemIndex)` | 玩家裝備道具時 | <0=取消裝備、>=0=正常（鏈：任一 <0 即攔截） | lua参考/NL.lua:547（Reg）/554（回呼）；gmsv/lua/libs/GlobalEvents.lua:183；exe_strings.txt:180556 | 其他 | 已確認 |
| `ItemDetachEvent` | `(CharIndex, FromItemIndex)` | 玩家卸下裝備時 | 無 | lua参考/NL.lua:560（Reg）/566（回呼）；exe_strings.txt:180557 | 其他 | 已確認 |
| `ResetCharaBattleStateEvent` | `(charIndex)` | 實測：戰鬥結束、角色離開戰場後觸發（逃跑與打贏都會），此時 Battle.GetCurrentBattle(c) 已是 -1；文件寫「戰鬥結算畫面出現時」，以實測為準【實測】 | 無（defaultChain 回最後一個回呼的值；autobattle 不回值） | lua参考/NL.lua:893（Reg）/898（回呼）；exe_strings.txt:180538；gmsv/lua/Modules/autobattle.lua:675 | 存檔掛機 | 已確認 |
| `CharaSavedEvent` | `(charIndex)` | 角色資料存檔完成後 | 無 | lua参考/NL.lua:904（Reg）/909（回呼）；exe_strings.txt:180541 | 存檔掛機 | 已確認 |
| `PetFieldEvent` | `(CharIndex, PetIndex, PetPos)` | 玩家展示（休息）寵物時 | <0=攔截展示／休息、>=0=正常 | lua参考/NL.lua:598（Reg）/606（回呼）；exe_strings.txt:180519 | 其他 | 已確認 |
| `BeforeCharaSaveEvent` | `(charIndex)` | 角色資料存檔前 | 無 | lua参考/NL.lua:915（Reg）/920（回呼）；exe_strings.txt:180540 | 存檔掛機 | 已確認 |
| `CharaDeletedEvent` | `(cdkey, registnumber, result)` | 刪除角色時（備註：注意參數是 cdkey、registnumber，不是 charIndex） | 無（參數 result：1=成功） | lua参考/NL.lua:926（Reg）/933（回呼）；exe_strings.txt:180539 | 存檔掛機 | 已確認 |
| `DamageCalculateEvent` | `(未知)` | 戰鬥中計算傷害時 | 回傳新傷害值（數字才採用；<=0 時 GlobalEvents 會正規化：閃避／Miss／原傷害 0 → 0，其他 → 1） | lua参考/NL.lua:638（Reg）/0（回呼）；gmsv/lua/libs/GlobalEvents.lua:138；exe_strings.txt:180586 | 戰鬥 | 已確認 |
| `ScriptCallEvent` | `(npcIndex, playerIndex, text, msg)` | NPC 腳本（luac）呼叫 Lua 時（參考「頭目萬歲」） | 回傳新值給 data（鏈：第一個回數字的回呼勝出，否則 nil） | lua参考/NL.lua:939（Reg）/948（回呼）；gmsv/lua/libs/GlobalEvents.lua:215；exe_strings.txt:180582 | 其他 | 已確認 |
| `DropRateEvent` | `(未知)` | NL.lua 與 apidump 都沒有 RegDropRateEvent；僅 EventName alias 列了名稱（備註：推測：舊名或打字誤植，對應 ItemDropRateEvent（見補充表）） | 未驗證 | 僅名稱，未驗證 | 戰鬥 | 未驗證 |
| `LoginEvent` | `(CharIndex)` | 玩家登入遊戲時 | 回 0 即可（廣播鏈，不消費回傳） | lua参考/NL.lua:66（Reg）/72（回呼）；gmsv/lua/libs/GlobalEvents.lua:207；exe_strings.txt:180508；gmsv/lua/Modules/welcome.lua:27 | 存檔掛機 | 已確認 |
| `BattleEscapeEvent` | `(battleIndex, charIndex, rate)` | 玩家逃跑判定時（備註：文件把 charIndex 註解成「施放召喚角色」，疑為複製錯誤） | 回傳逃跑結果 1=成功、0=失敗（文件參數 rate 實為結果）；可強制逃跑成功／失敗 | lua参考/NL.lua:954（Reg）/962（回呼）；exe_strings.txt:180530 | 戰鬥 | 已確認 |
| `LoginGateEvent` | `(CharIndex)` | 玩家按「登出回記錄點」時（僅此時才觸發） | 回 0 即可（廣播鏈） | lua参考/NL.lua:78（Reg）/84（回呼）；gmsv/lua/libs/GlobalEvents.lua:199；exe_strings.txt:180509 | 存檔掛機 | 已確認 |
| `BattleSealRateEvent` | `(battleIndex, charIndex, enemyIndex, rate)` | 玩家對魔物使用封印時計算成功率（備註：rate 單位文件未寫（SealEvent 的 -100 說明提到 abs(rate/100)-1，推測 rate 為百分率×100）） | 回傳新成功率（數字；鏈式累積）；文件註明「不能突破伺服器設定」（推測：伺服器仍有上限） | lua参考/NL.lua:968（Reg）/977（回呼）；gmsv/lua/libs/GlobalEvents.lua:255；exe_strings.txt:180578 | 封印 | 已確認 |
| `LogoutEvent` | `(CharIndex)` | 玩家登出遊戲時 | 回 0 即可（廣播鏈） | lua参考/NL.lua:90（Reg）/96（回呼）；gmsv/lua/libs/GlobalEvents.lua:203；exe_strings.txt:180510；gmsv/lua/Modules/loginGate.lua:114 | 存檔掛機 | 已確認 |
| `CalcCriticalRateEvent` | `(aIndex, fIndex, rate)` | 計算必殺（暴擊）率時 | 回傳新必殺率 | lua参考/NL.lua:983（Reg）/991（回呼）；gmsv/lua/libs/GlobalEvents.lua:259；exe_strings.txt:180571 | 戰鬥 | 已確認 |
| `TalkEvent` | `(CharIndex, Msg, Color, Range, Size)` | 玩家說話時（做 GM／自訂指令的入口）【實測】 | 1=正常送出、0=攔截這句話（GlobalEvents 鏈：回 nil 視為 1，任一回呼回非 1 即立刻回傳該值） | lua参考/NL.lua:102（Reg）/112（回呼）；gmsv/lua/libs/GlobalEvents.lua:96；exe_strings.txt:180514；gmsv/lua/Modules/admin.lua:58、autobattle.lua:673 | 其他 | 已確認 |
| `BattleDodgeRateEvent` | `(battleIndex, aIndex, fIndex, rate)` | 計算閃躲率時 | 回傳新閃躲率 | lua参考/NL.lua:997（Reg）/1006（回呼）；gmsv/lua/libs/GlobalEvents.lua:263；exe_strings.txt:180576 | 戰鬥 | 已確認 |
| `BattleCounterRateEvent` | `(battleIndex, aIndex, fIndex, rate)` | 計算反擊率時 | 回傳新反擊率 | lua参考/NL.lua:1012（Reg）/1021（回呼）；gmsv/lua/libs/GlobalEvents.lua:267；exe_strings.txt:180577 | 戰鬥 | 已確認 |
| `BattleMagicDamageRateEvent` | `(battleIndex, aIndex, fIndex, rate)` | 魔法傷害計算時調整魔法係數 | 回傳新魔法係數 | lua参考/NL.lua:1027（Reg）/1036（回呼）；gmsv/lua/libs/GlobalEvents.lua:271；exe_strings.txt:180581 | 戰鬥 | 已確認 |
| `BattleMagicRssRateEvent` | `(battleIndex, aIndex, fIndex, rate)` | 魔法傷害計算時調整魔防係數 | 回傳新魔防係數 | lua参考/NL.lua:1042（Reg）/1051（回呼）；gmsv/lua/libs/GlobalEvents.lua:275；exe_strings.txt:180585 | 戰鬥 | 已確認 |
| `ItemBoxGenerateEvent` | `(mapId, floor, itemBoxType, adm)` | 寶箱生成時（備註：adm 作用文件寫「未知」） | 回傳 {itemBoxType, adm} 陣列改寫寶箱參數 | lua参考/NL.lua:1057（Reg）/1066（回呼）；exe_strings.txt:180548 | 採集 | 已確認 |
| `LevelUpEvent` | `(CharIndex, PetIndex, UpLevel)` | 玩家角色升級後（可發等級獎勵、記錄衝級速度）（備註：文件簽名寫 (CharIndex, PetIndex, UpLevel)，與 CharaAfterUpLevelEvent(CharIndex, UpLevel) 重複，疑為複製錯誤；實際參數未實測） | 回 0 即可 | lua参考/NL.lua:118（Reg）/126（回呼）；exe_strings.txt:180516 | 其他 | 推測 |
| `BattleStartEvent` | `(BattleIndex)` | 角色進入戰鬥時 | 回 0 即可 | lua参考/NL.lua:132（Reg）/138（回呼）；exe_strings.txt:180527 | 戰鬥 | 已確認 |
| `ItemBoxLootEvent` | `(charaIndex, mapId, floor, X, Y, boxType, adm)` | 開寶箱取得物品時 | 1=攔截預設物品、0=不攔截 | lua参考/NL.lua:1072（Reg）/1084（回呼）；exe_strings.txt:180547 | 採集 | 已確認 |
| `BattleOverEvent` | `(BattleIndex)` | 戰鬥結束時（備註：實測：參數 battleIndex） | 回 0 即可 | lua参考/NL.lua:144（Reg）/150（回呼）；exe_strings.txt:180528；gmsv/lua/Modules/autobattle.lua:672、areaprobe.lua:98 | 戰鬥 | 已確認 |
| `WarpEvent` | `(未知)` | 玩家通過傳送點、傳送前 | 回傳 {mapId, floor, x, y} 可改目的地，回 nil 不改 | lua参考/NL.lua:156（Reg）/0（回呼）；exe_strings.txt:180536 | 移動 | 已確認 |
| `AfterWarpEvent` | `(未知)` | 玩家傳送完成後 | 回 0 即可 | lua参考/NL.lua:177（Reg）/0（回呼）；exe_strings.txt:180537 | 移動 | 已確認 |
| `ItemBoxEncountRateEvent` | `(charaIndex, mapId, floor, X, Y, itemIndex, rate, boxType)` | 寶箱遇敵率計算時 | 回傳新遇敵率 | lua参考/NL.lua:1090（Reg）/1103（回呼）；gmsv/lua/libs/GlobalEvents.lua:279；exe_strings.txt:180545 | 採集 | 已確認 |
| `ItemBoxEncountEvent` | `(charaIndex, mapId, floor, X, Y, itemIndex)` | 開寶箱遇敵時 | 回傳遇敵陣列（每隻 3 欄：怪物 id、等級、隨機等級）；回 nil 不攔截 | lua参考/NL.lua:1109（Reg）/1120（回呼）；exe_strings.txt:180546 | 戰鬥 | 已確認 |
| `TribeRateEvent` | `(a, b, rate)` | 種族相剋傷害比率計算時 | 回傳新克制比率（可與 Data.SetTribeMapValue 對照） | lua参考/NL.lua:1126（Reg）/1134（回呼）；exe_strings.txt:180549 | 戰鬥 | 已確認 |
| `HttpRequestEvent` | `(method, api, params, body)` | Http 伺服器收到「已用 Http.RegApi 註冊」的 API 請求時 | 回傳字串當作回應內容 | lua参考/NL.lua:1140（Reg）/1149（回呼）；exe_strings.txt:180588；gmsv/lua/Modules/http.lua:27 | 網路 | 已確認 |
| `DropEvent` | `(CharIndex)` | 玩家掉線時 | 回 0 即可 | lua参考/NL.lua:198（Reg）/204（回呼）；exe_strings.txt:180511；gmsv/lua/Modules/loginGate.lua:115 | 存檔掛機 | 已確認 |
| `TitleChangedEvent` | `(CharIndex, Ori_Title, New_Title)` | 玩家更換稱號時 | 0=正常、<0=攔截 | lua参考/NL.lua:210（Reg）/218（回呼）；exe_strings.txt:180584 | 其他 | 已確認 |
| `BattleHealCalculateEvent` | `(未知)` | 戰鬥中計算治療量時（備註：參數同 DamageCalculateEvent，flg 查 CONST.HealDamageFlags） | 回傳新治療值（取整、最小 0） | lua参考/NL.lua:1171（Reg）/0（回呼）；gmsv/lua/libs/GlobalEvents.lua:142；exe_strings.txt:180587 | 戰鬥 | 已確認 |
| `GetExpEvent` | `(CharIndex, Exp)` | 角色獲得戰鬥經驗時 | 回傳要獲得的經驗值（不改就別 return 或 return Exp）；先於道具加成計算 | lua参考/NL.lua:224（Reg）/231（回呼）；gmsv/lua/libs/GlobalEvents.lua:243；exe_strings.txt:180522 | 戰鬥 | 已確認 |
| `BattleSkillExpEvent` | `(CharIndex, SkillID, Exp)` | 角色獲得戰鬥技能經驗時 | 回傳要獲得的經驗值；先於道具加成計算 | lua参考/NL.lua:237（Reg）/245（回呼）；gmsv/lua/libs/GlobalEvents.lua:251；exe_strings.txt:180525 | 技能 | 已確認 |
| `ProductSkillExpEvent` | `(CharIndex, SkillID, Exp)` | 角色獲得生產技能（含採集／製造）經驗時（備註：推測：採集技能（伐木／狩獵／挖掘）也屬生產技能，會走這裡；未實測） | 回傳要獲得的經驗值；先於道具加成計算 | lua参考/NL.lua:251（Reg）/259（回呼）；gmsv/lua/libs/GlobalEvents.lua:247；exe_strings.txt:180526 | 製造 | 已確認 |
| `PetLevelUpEvent` | `(CharIndex, PetIndex, UpLevel)` | 寵物升級後 | 回 0 即可 | lua参考/NL.lua:265（Reg）/273（回呼）；exe_strings.txt:180517 | 其他 | 已確認 |
| `BattleExitEvent` | `(CharIndex, BattleIndex, Type)` | 玩家離開戰鬥時 | 文件無回傳意義（Type：1=正常離開含勝負、逃跑、登出；2=被踢） | lua参考/NL.lua:292（Reg）/299（回呼）；exe_strings.txt:180529 | 戰鬥 | 已確認 |
| `PreItemPickUpEvent` | `(CharIndex, ItemIndex)` | 玩家撿道具之前 | <0=攔截、>=0=正常（鏈：任一 <0 即攔截） | lua参考/NL.lua:1427（Reg）/1434（回呼）；gmsv/lua/libs/GlobalEvents.lua:195；exe_strings.txt:180550 | 其他 | 已確認 |
| `RightClickEvent` | `(CharIndex, TargetCharIndex)` | 玩家右鍵點其他玩家時 | 1=攔截、其他不攔截 | lua参考/NL.lua:305（Reg）/312（回呼）；exe_strings.txt:180515 | 其他 | 已確認 |
| `PreItemDropEvent` | `(CharIndex, ItemIndex)` | 玩家丟棄道具之前 | <0=攔截、>=0=正常 | lua参考/NL.lua:1414（Reg）/1421（回呼）；gmsv/lua/libs/GlobalEvents.lua:191；exe_strings.txt:180552 | 其他 | 已確認 |
| `BattleInjuryEvent` | `(dIndex, aIndex, battleIndex, inject, newVal)` | 戰鬥中受傷時（備註：GlobalEvents 以 (dIndex,aIndex,battleIndex,inject,newVal) 呼叫） | 回傳受傷程度 0~100（鏈：<=0 立刻結束） | lua参考/NL.lua:877（Reg）/887（回呼）；gmsv/lua/libs/GlobalEvents.lua:146；exe_strings.txt:180565 | 戰鬥 | 已確認 |
| `ShutDownEvent` | `()` | 伺服器程式關閉時 | 回 0 即可 | lua参考/NL.lua:318（Reg）/323（回呼）；exe_strings.txt:180512；gmsv/lua/libs/Module/ModuleSystem.lua:5 | 其他 | 已確認 |
| `ItemExpansionEvent` | `(itemIndex, type, msg, charIndex, slot)` | 道具說明（type=1）與右鍵說明（type=2）顯示時 | 回傳新說明字串 | lua参考/NL.lua:1210（Reg）/1220（回呼）；gmsv/lua/libs/GlobalEvents.lua:130；exe_strings.txt:180560 | 其他 | 已確認 |
| `PartyEvent` | `(CharIndex, TargetCharIndex, Type)` | 玩家組隊／離隊時（備註：Type：0 加入、1 離開；CharIndex 為隊員、Target 為隊長） | 1=允許、0=禁止（鏈：任一回 0 即禁止） | lua参考/NL.lua:329（Reg）/337（回呼）；gmsv/lua/libs/GlobalEvents.lua:231；exe_strings.txt:180533 | 其他 | 已確認 |
| `TitleCheckCallEvent` | `(charIndex, Data, Flg)` | 稱號條件檢查（titleconfig.txt 用 LUA 關鍵字） | 1=條件滿足、0=不滿足 | lua参考/NL.lua:1226（Reg）/1234（回呼）；exe_strings.txt:180583 | 其他 | 已確認 |
| `SealEvent` | `(CharIndex, EnemyIndex, Ret)` | 玩家封印寵物時（結果已判定後）（備註：失敗碼 -1..-11、-100（機率不足）見 lua参考/NL.lua:351-363） | 回傳 RetFlg；正數=成功、負數=失敗，可直接回傳原值或強改結果 | lua参考/NL.lua:343（Reg）/365（回呼）；exe_strings.txt:180579 | 封印 | 已確認 |
| `RankUpEvent` | `(CharIndex, OldRank, NewRank)` | 職業晉級時 | >=0=允許晉級、負數=拒絕 | lua参考/NL.lua:691（Reg）/699（回呼）；exe_strings.txt:180535 | 其他 | 已確認 |
| `TechOptionEvent` | `(CharIndex, Option, TechID, Val)` | 取得技能附加參數（Option 欄）時 | 回傳新值（鏈式累積） | lua参考/NL.lua:663（Reg）/672（回呼）；gmsv/lua/libs/GlobalEvents.lua:162；exe_strings.txt:180612 | 技能 | 已確認 |
| `GatherItemEvent` | `(charIndex, skillId, skillLv, itemId)` | 採集技能（伐木／狩獵／挖掘）判定採集物時（備註：能直接覆寫採集產出） | 回傳採集物 itemId（itemset.txt）；不回傳＝預設結果 | lua参考/NL.lua:1240（Reg）/1249（回呼）；exe_strings.txt:180590 | 採集 | 已確認 |
| `BattleActionEvent` | `(CharIndex, Com1, Com2, Com3, ActionNum)` | 玩家在戰鬥中下指令時 | 無 | lua参考/NL.lua:371（Reg）/380（回呼）；exe_strings.txt:180531 | 戰鬥 | 已確認 |
| `PetTimeDeleteEvent` | `(PetIndex)` | 地上的寵物被系統定時刪除時 | <=0=照常刪除、>0=延長到該秒數後再刪 | lua参考/NL.lua:705（Reg）/711（回呼）；exe_strings.txt:180518 | 其他 | 已確認 |
| `ItemDropEvent` | `(CharIndex, ItemIndex)` | 玩家丟棄道具時 | <0=攔截丟棄、>=0=正常 | lua参考/NL.lua:572（Reg）/579（回呼）；gmsv/lua/libs/GlobalEvents.lua:179；exe_strings.txt:180553 | 其他 | 已確認 |
| `BattleSurpriseEvent` | `(battleIndex, result)` | 戰鬥偷襲判定前 | 0=不偷襲、1=我方偷襲、2=被偷襲 | lua参考/NL.lua:717（Reg）/724（回呼）；gmsv/lua/libs/GlobalEvents.lua:134；exe_strings.txt:180563 | 戰鬥 | 已確認 |
| `VSEnemyCreateEvent` | `(CharIndex, GroupId, EnemyNum, EnemyList)` | 玩家遇敵、生成敵人隊列時 | 回傳新敵人隊列（number[]）；非 table 即不修改 | lua参考/NL.lua:1255（Reg）/1264（回呼）；exe_strings.txt:180593 | 戰鬥 | 已確認 |
| `ItemOverLapEvent` | `(CharIndex, FromItemIndex, TargetItemIndex, Num)` | 玩家把道具拖到另一個道具上（堆疊）時 | 1 或 <0=攔截、0=正常移動（鏈：任一回非 0 即回 1） | lua参考/NL.lua:426（Reg）/435（回呼）；gmsv/lua/libs/GlobalEvents.lua:227；exe_strings.txt:180558 | 其他 | 已確認 |
| `CharActionEvent` | `(CharIndex, ActionID)` | 玩家做任何動作（暈倒、攻擊、剪刀石頭布等）時 | 無 | lua参考/NL.lua:399（Reg）/405（回呼）；exe_strings.txt:180532 | 其他 | 已確認 |
| `BattleSummonEnemyEvent` | `(battleIndex, charIndex, enemyId)` | 怪物施放召喚時 | 回傳 {enemyId, 等級, 等級波動} 改召喚物種類與等級 | lua参考/NL.lua:730（Reg）/738（回呼）；gmsv/lua/libs/GlobalEvents.lua:166；exe_strings.txt:180573 | 戰鬥 | 已確認 |
| `CalcFpConsumeEvent` | `(charIndex, techId, Fp)` | 計算技能耗魔（FP）時 | 回傳新耗魔值 | lua参考/NL.lua:1196（Reg）/1204（回呼）；exe_strings.txt:180562 | 技能 | 已確認 |
| `MergeItemEvent` | `(CharIndex, SkillID, SkillLv, ItemIndex, jewelNo)` | 玩家用生產技能製造道具時（製造完成鉤子）（備註：ItemIndex=-1 代表製造失敗；jewelNo 為寶石物品 id） | 無（文件未寫回傳意義） | lua参考/NL.lua:411（Reg）/420（回呼）；exe_strings.txt:180559 | 製造 | 已確認 |
| `BattleActionTargetEvent` | `(charIndex, battleIndex, com1, com2, com3, targetList)` | 玩家攻擊時決定目標（亂射、連擊等） | 回傳新目標位置陣列；非 table 即不修改 | lua参考/NL.lua:1270（Reg）/1281（回呼）；gmsv/lua/libs/GlobalEvents.lua:315；exe_strings.txt:180594 | 戰鬥 | 已確認 |
| `BattleSummonedEnemyEvent` | `(battleIndex, actionCharIndex, charIndex)` | 召喚物生成前 | 無（可在此改召喚物屬性） | lua参考/NL.lua:744（Reg）/751（回呼）；exe_strings.txt:180574 | 戰鬥 | 已確認 |
| `BattleSkillCheckEvent` | `(charIndex, battleIndex, arrayOfSkillEnable)` | 控制戰鬥技能可否使用 | 回傳陣列（1=可用、0=不可用） | lua参考/NL.lua:1287（Reg）/1295（回呼）；gmsv/lua/libs/GlobalEvents.lua:319；exe_strings.txt:180595 | 戰鬥 | 已確認 |
| `BattleNextEnemyEvent` | `(battleIndex, flg)` | 連戰（下一波）敵人生成前 | 回傳 {enemyId, 等級, ...}（依 10-19 位置排）；回 nil 取消連戰 | lua参考/NL.lua:757（Reg）/764（回呼）；gmsv/lua/libs/GlobalEvents.lua:170；exe_strings.txt:180569 | 戰鬥 | 已確認 |
| `ItemString` | `(CharIndex, ItemIndex)` | itemset.txt 道具自訂函式欄位（NL.RegItemString(檔, 函式, LUA_xxx)）：init/use/att/det/drop/prepick/pick 七種（備註：不是 NL.Reg*Event；舊模組大量使用（見 Module/*.lua）） | 依 LUA_ 前綴不同：use→回 0 即可；att→<0 取消裝備；prepick→<0 取消撿取；其他無 | lua参考/NL.lua:467（Reg）/473（回呼）；gmsv/lua/Module/GoldMap.lua:175 等 | 其他 | 已確認 |
| `BattleLuaSkillEvent` | `(battleIndex, charIndex, SKLFunc, ActFunc, MsgFunc)` | 自訂 Lua 技能（Tech 的 Lua 型）施放時 | 無；回呼拿到 SKLFunc／ActFunc／MsgFunc 三個發封包函式 | lua参考/NL.lua:1301（Reg）/1310（回呼）；exe_strings.txt:180596 | 戰鬥 | 已確認 |
| `BattleNextEnemyInitEvent` | `(battleIndex, flg)` | 連戰魔物生成前（可改屬性） | 無 | lua参考/NL.lua:770（Reg）/776（回呼）；exe_strings.txt:180570 | 戰鬥 | 已確認 |
| `ItemPickUpEvent` | `(CharIndex, ItemIndex)` | 玩家成功撿起道具之後 | <0=攔截、>=0=正常 | lua参考/NL.lua:585（Reg）/592（回呼）；gmsv/lua/libs/GlobalEvents.lua:175；exe_strings.txt:180551 | 其他 | 已確認 |
| `BeforeBattleTurnEvent` | `(battleIndex)` | 每回合怪物 AI 執行前【實測】 | 回 true=結果為 true（GlobalEvents 鏈：任一回呼回真值即 true）；實測可用於每回合下指令 | lua参考/NL.lua:782（Reg）/787（回呼）；gmsv/lua/libs/GlobalEvents.lua:112；exe_strings.txt:180566；gmsv/lua/Modules/autobattle.lua:671 | 戰鬥 | 已確認 |
| `GetLoginPointEvent` | `(CharIndex, MapID, FloorID, X, Y)` | 玩家登入取得登入點時（可取代 Login 事件裡的原地登入，直接設座標，無需 warp） | 無（在回呼中直接設座標） | lua参考/NL.lua:441（Reg）/450（回呼）；exe_strings.txt:180524；gmsv/lua/Modules/loginGate.lua:113 | 移動 | 已確認 |
| `BeforeBattleTurnStartEvent` | `(battleIndex)` | 所有指令就位、回合開始時 | 無 | lua参考/NL.lua:793（Reg）/798（回呼）；exe_strings.txt:180567 | 戰鬥 | 已確認 |
| `PetPickUpEvent` | `(CharIndex, PetIndex)` | 玩家撿起寵物時 | <0=攔截、>=0=繼續正常流程 | lua参考/NL.lua:625（Reg）/632（回呼）；exe_strings.txt:180521 | 其他 | 已確認 |
| `AfterBattleTurnEvent` | `(battleIndex)` | 回合結束時 | 無 | lua参考/NL.lua:804（Reg）/809（回呼）；exe_strings.txt:180568 | 戰鬥 | 已確認 |
| `ItemDurabilityChangedEvent` | `(itemIndex, oldDurability, newDurability, value, mode)` | 道具耐久變化時（備註：mode：0 一般損耗、1 致死打擊、2 沉重打擊、3 耐久清空、4 裝備破壞） | 回傳新 mode（mode 1、2 回 0 可取消對應提示） | lua参考/NL.lua:1365（Reg）/1375（回呼）；gmsv/lua/libs/GlobalEvents.lua:311；exe_strings.txt:180592 | 戰鬥 | 已確認 |
| `AfterCalcCharaBpEvent` | `(charIndex)` | 角色屬性計算後（含裝備屬性） | 無 | lua参考/NL.lua:815（Reg）/820（回呼）；exe_strings.txt:180543 | 其他 | 已確認 |
| `HeadCoverEvent` | `(CharIndex, CurrentHeadCoverImage)` | 顯示角色頭飾效果時 | 回傳新頭飾圖檔 id；不變就回 CurrentHeadCoverImage | lua参考/NL.lua:678（Reg）/685（回呼）；exe_strings.txt:180534 | 其他 | 已確認 |
| `AfterCalcCharaStatusEvent` | `(charIndex)` | 角色裝備計算後（含受傷、掉魂） | 無 | lua参考/NL.lua:826（Reg）/831（回呼）；exe_strings.txt:180542 | 其他 | 已確認 |
| `PetDropEvent` | `(CharIndex, PetPos)` | 玩家丟出寵物時 | <0=攔截丟棄、>=0=正常 | lua参考/NL.lua:612（Reg）/619（回呼）；exe_strings.txt:180520 | 其他 | 已確認 |
| `StatusCalcEvent` | `(charIndex)` | 角色計算屬性時 | 無 | lua参考/NL.lua:837（Reg）/842（回呼）；exe_strings.txt:180544 | 其他 | 已確認 |
| `BattleGetProfitEvent` | `(battleIndex, side, pos, charaIndex, type, reward)` | 戰鬥獲得戰利品時（經驗、DP、道具） | 回傳修改後的經驗／DP／itemIndex（type：EXP=-1、DP=-2、ITEM1..3=0..2） | lua参考/NL.lua:1381（Reg）/1392（回呼）；gmsv/lua/libs/GlobalEvents.lua:283；exe_strings.txt:180591 | 戰鬥 | 已確認 |
| `ItemConsumeEvent` | `(charIndex, itemIndex, slot, amount)` | 玩家在戰鬥中使用物品而消耗時 | 回傳消耗數量（推測：回 0 可讓道具不減少，未實測） | lua参考/NL.lua:1440（Reg）/1449（回呼）；gmsv/lua/libs/GlobalEvents.lua:307；exe_strings.txt:180561 | 其他 | 已確認 |
| `CharaStallSoldEvent` | `(buyer, seller, itemIndex, petIndex, price)` | 擺攤成交時（備註：price 欄文件註解複製錯誤（寫「消費數量」）） | 無 | lua参考/NL.lua:1464（Reg）/1473（回呼）；exe_strings.txt:180598 | 交易 | 已確認 |
| `CharaStallStartEvent` | `(seller)` | 玩家開始擺攤時 | 無 | lua参考/NL.lua:1479（Reg）/1484（回呼）；exe_strings.txt:180599 | 交易 | 已確認 |
| `CharaStallEndEvent` | `(seller)` | 玩家結束擺攤時 | 無 | lua参考/NL.lua:1490（Reg）/1495（回呼）；exe_strings.txt:180600 | 交易 | 已確認 |
| `CharaStallBrowseEvent` | `(buyer, seller)` | 有人瀏覽攤位時 | 無 | lua参考/NL.lua:1501（Reg）/1507（回呼）；exe_strings.txt:180601 | 交易 | 已確認 |

## 補充：不在 alias 但 NL.Reg*／exe 字串有的事件

（`apidump.txt` 的 `NL.Reg*Event` 清單或 `exe_strings.txt:180508-180612` 有；regCallback 的事件名可直接用，因為 `GlobalEvents.lua:355` 會找 `NL["Reg"..eventName]`）

| 事件 | 回呼參數 | 觸發時機 | 回傳值意義 | 依據 | 標籤 | 狀態 |
|---|---|---|---|---|---|---|
| `AutoBattleCommandEvent` | `(battleIndex, CharIndex)` | 玩家啟用自動戰鬥時【實測】 | 必須回 1，否則角色原地不動（1=由伺服器代下指令） | lua参考/NL.lua:386（Reg）/393（回呼）；exe_strings.txt:180606；gmsv/lua/Modules/autobattle.lua:674 | 戰鬥 | 已確認 |
| `CharaAfterUpLevelEvent` | `(CharIndex, UpLevel)` | 角色升級後 | 回 0 即可 | lua参考/NL.lua:279（Reg）/286（回呼）；exe_strings.txt:180605 | 其他 | 已確認 |
| `GetLevelExpEvent` | `(未知)` | 僅 exe 字串有名（未見文件） | 未驗證 | exe_strings.txt:180523 | 其他 | 未驗證 |
| `GatherTechUsedEvent` | `(未知)` | 僅 exe 字串有名（未見文件）；字面推測為採集技能被使用 | 未驗證 | exe_strings.txt:180513 | 採集 | 未驗證 |
| `BattlePreEvent` | `(battleIndex)` | 戰鬥資料發送前 | 回 0 即可（不參與邏輯） | lua参考/NL.lua:1653（Reg）/1659（回呼）；exe_strings.txt:180564 | 戰鬥 | 已確認 |
| `BattleStatusReflectionEvent` | `(battleIndex, charIndex)` | 戰鬥屬性更新前 | 回 0 即可 | lua参考/NL.lua:1640（Reg）/1647（回呼）；exe_strings.txt:180580 | 戰鬥 | 已確認 |
| `HttpResultEvent` | `(reqId, url, success, statusCode, responseBody, errMsg)` | Http.Send 發出的請求有結果時 | 無 | lua参考/NL.lua:1155（Reg）/1165（回呼）；exe_strings.txt:180589 | 網路 | 已確認 |
| `ItemDropRateEvent` | `(battleIndex, enemyIndex, charaIndex, itemId, rate)` | 怪物掉寶機率計算時 | 回傳新掉率（百萬分率，1000000=100%） | lua参考/NL.lua:1529（Reg）/1539（回呼）；gmsv/lua/libs/GlobalEvents.lua:295；exe_strings.txt:180602 | 戰鬥 | 已確認 |
| `StealItemEmitRateEvent` | `(battleIndex, enemyIndex, charaIndex, itemId, rate)` | 偷竊物品出現率計算時 | 回傳新機率（百萬分率） | lua参考/NL.lua:1513（Reg）/1523（回呼）；gmsv/lua/libs/GlobalEvents.lua:291；exe_strings.txt:180603 | 戰鬥 | 已確認 |
| `BattlePetLeaveCheckEvent` | `(battleIndex, charIndex, type, com1, com2, com3)` | 戰鬥寵物行為檢測 | 回傳新 type（0 正常、1 收寵、2 位置、3 發呆、4 防禦、5 攻擊、6 ?、7 逃跑） | lua参考/NL.lua:1545（Reg）/1556（回呼）；gmsv/lua/libs/GlobalEvents.lua:299；exe_strings.txt:180604 | 戰鬥 | 已確認 |
| `BattleBeforeActionEvent` | `(battleIndex, charIndex, addAction)` | 戰鬥 ACTION 之前 | 回 0 即可；addAction 可追加行動 | lua参考/NL.lua:1562（Reg）/1570（回呼）；exe_strings.txt:180607 | 戰鬥 | 已確認 |
| `BattleAfterActionEvent` | `(battleIndex, charIndex, addAction)` | 戰鬥 ACTION 之後 | 回 0 即可；addAction 可追加行動 | lua参考/NL.lua:1576（Reg）/1584（回呼）；exe_strings.txt:180608 | 戰鬥 | 已確認 |
| `BattleStatusResistanceEvent` | `(battleIndex, aCharIndex, dCharIndex, type, rate)` | 異常狀態命中判定 | 回傳機率（萬分率） | lua参考/NL.lua:1590（Reg）/1600（回呼）；gmsv/lua/libs/GlobalEvents.lua:303；exe_strings.txt:180609 | 戰鬥 | 已確認 |
| `JudgeItemEvent` | `(charIndex, skillid, skilllv, itemindex, prob, flg)` | 玩家鑑定道具時 | 1=鑑定成功、0=失敗（prob 萬分率，-1=技能等級不足） | lua参考/NL.lua:1606（Reg）/1617（回呼）；exe_strings.txt:180610 | 製造 | 已確認 |
| `RepairItemEvent` | `(charIndex, skillid, skilllv, itemindex, prob, flg)` | 玩家修理道具時 | 1=修理成功、0=失敗（prob 萬分率，-1=技能等級不足） | lua参考/NL.lua:1623（Reg）/1634（回呼）；exe_strings.txt:180611 | 製造 | 已確認 |
| `BattleDamageEvent` | `(未知)` | 僅 GlobalEvents.lua 鏈有定義，無 NL.Reg 也不在 exe 字串 | 未驗證 | gmsv/lua/libs/GlobalEvents.lua:126 | 戰鬥 | 未驗證 |
