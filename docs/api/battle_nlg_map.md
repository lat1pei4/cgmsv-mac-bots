# cgmsv 26.8d Lua API 參考：Battle / NLG / NL / Obj / Map / Field

產生依據與標記說明（先讀這段）

- 清單來源：執行期匯出 `docs/api/apidump.txt`（權威；每個函式都在表中，不多不少）。
- 依據欄 `lua/…:行` ＝ `~/Desktop/Personal/crossgate/server-b/gmsv/lua/` 底下檔案（GBK，行號與原檔相同）。
- 依據欄 `上游 docs/X.lua:行` ＝ GitHub Muscipular/cgmsv-lua 的 `docs/X.lua`（EmmyLua 註解，24.x 時代文件；副本在 `docs/api/upstream/`，行號取自該副本）。26.8d 的簽名可能與它不同，已知差異都在該列備註。
- 依據欄 `exe_strings.txt:行` ＝ 從 cgmsv.exe 抽出的字串（含內嵌 Lua 原始碼與事件名）；`exe_strings.txt` 不進版控，要對照時用 `strings -n 3 server-b/gmsv/cgmsv.exe > exe_strings.txt` 重建（行號以此指令產生的檔為準）。
- 狀態：已確認＝本機有程式用例／libs 註解／內嵌 Lua 佐證（含使用者實測事實）；推測＝只有上游文件簽名，本機無用例；未驗證＝只有名稱。
- 本機 `lua/Module/`、`lua/Module/nofix/` 多為舊版（`%常數%` 巨集式）腳本，簽名可能與 26.8d 不同；列內已標出「待實測」的差異。
- `lua/Modules/`（新框架）與 `lua/libs/` 較可信；自動戰鬥、探測模組皆在這裡。
- 用 `self:regCallback('XxxEvent', fn)`（lua/libs/GlobalEvents.lua:355-360）註冊事件時，框架會替你呼叫 `NL.RegXxxEvent(nil, 全域函式名)`。


## Battle（46 個函式；已確認 14／推測 32／未驗證 0）

| 函式 | 參數 → 回傳 | 用途（繁體中文） | 依據 | 標籤 |
|---|---|---|---|---|
| `Battle.ActionSelect` | (charIndex, com, target, techIdOrSlot) → 0（成功也回 0，實測；上游文件寫 1 成功） | [已確認] 讓處於等待指令狀態的角色下戰鬥指令；用道具時第 4 參數是背包 slot（8～27）；目標編號：單體＝slot、強力＝slot+20、全體＝40+side（我方）／41-side（敵方）。須 IsWaitingCommand==1 才有效。 | lua/Modules/autobattle.lua:539；lua/Modules/areaprobe.lua:50（魔法 target=center+20）；上游 docs/Battle.lua:125 | 戰鬥 |
| `Battle.AppendBattleMsg` | (msg:string) → 無 | [推測] 為目前處理中的戰鬥追加訊息（如施放技能喊話）。 | 上游 docs/Battle.lua:222 | 訊息 |
| `Battle.CalcAttributeDmgRate` | (attackerCharIndex, defenceCharIndex) → 克制比率 | [推測] 計算兩個對象之間的屬性克制傷害比率。 | 上游 docs/Battle.lua:192 | 查詢 |
| `Battle.CalcPropScore` | (ap:number[4], dp:number[4], magic:0或1) → 屬性傷害比率（10 屬性=100） | [推測] 用攻守雙方地水火風 4 屬性陣列計算屬性傷害比率。 | 上游 docs/Battle.lua:180 | 查詢 |
| `Battle.CalcTribeDmgRate` | (attackerCharIndex, defenderCharIndex) → 當前戰鬥種族傷害比率 | [推測] 計算目前戰鬥中雙方的種族傷害比率。 | 上游 docs/Battle.lua:204 | 查詢 |
| `Battle.CalcTribeRate` | (attackerTribe, defenderTribe) → 種族傷害比率 | [推測] 以種族編號計算種族傷害比率。 | 上游 docs/Battle.lua:198 | 查詢 |
| `Battle.Encount` | (upCharIndex, downCharIndex[, data:string]) → battleIndex；失敗回負數 | [已確認] 呼叫伺服器 encount 建立戰鬥。兩個參數都傳同一玩家且不給 data＝就地遇敵（依該地圖遇敵表）；該處無法遇敵回負數。回傳的 battleIndex 可接 SetWinEvent／SetNextBattle。 | lua/Module/nofix/ikki_encount.lua:27、:35（傳 player,player；回傳 <0 判定失敗）；lua/Module/nofix/checked/MakeQMX.lua:41；上游 docs/Battle.lua:20 | 戰鬥 |
| `Battle.ExitBattle` | (charIndex) → 0 成功 | [已確認] 讓指定角色退出目前戰鬥（可用來把戰敗者踢出戰鬥）。 | lua/Module/nofix/swjjc.lua:197；上游 docs/Battle.lua:80 | 戰鬥 |
| `Battle.GetBattleCharacterStatus` | (charIndex, statusType) → 值；失敗 -1 | [推測] 讀取角色在戰鬥中的狀態欄位（statusType 見 CONST 戰屬常量）。 | 上游 docs/Battle.lua:296 | 查詢 |
| `Battle.GetBattleFieldAttribute` | (battleIndex) → 戰場魔法狀態, 持續回合, 狀態屬性；失敗回 0 | [推測] 讀取戰場魔法效果（如屬性反轉、魔法封印）。 | 上游 docs/Battle.lua:130 | 戰鬥 |
| `Battle.GetCurrentBattle` | (charIndex) → battleIndex（不在戰鬥回 -1） | [已確認] 取得角色目前所在戰鬥的 index。dump 顯示為 C 函式（libs 只在其為 nil 時才補 Lua 版）。 | lua/Modules/abtest.lua:214；lua/libs/Gmsv/BattleEx.lua:60 | 查詢 |
| `Battle.GetDexRearrangeRate` | (battleIndex) → 是否啟用, 機率 | [推測] 讀取該戰鬥的「亂敏率」（行動順序隨機打亂機率）。 | 上游 docs/Battle.lua:247 | 戰鬥 |
| `Battle.GetEntryData` | (battleIndex, charIndex, dataline) → 值 | [推測] 讀取角色在該戰鬥的 Entry 資料欄（dataline 為 CONST.BATTLE_ENTRY_*／戰屬_*）。 | 上游 docs/Battle.lua:229 | 查詢 |
| `Battle.GetEntryPosition` | (battleIndex, charIndex) → 戰鬥位置 0-19 | [推測] 取得角色在戰鬥中的真實位置（上游文件與 GetPos 說明相同）。 | 上游 docs/Battle.lua:162 | 查詢 |
| `Battle.GetExtData` | (battleIndex, key:string) → string/number/nil | [推測] 讀取掛在該戰鬥上的自訂資料（可存自訂旗標，戰鬥結束後自然消失）。 | 上游 docs/Battle.lua:277 | 查詢 |
| `Battle.GetGainMode` | (battleIndex) → 獎勵模式 | [已確認] 取得戰鬥獎勵模式（如給經驗、給 DP）。 | lua/Module/NewbieBless.lua:14；上游 docs/Battle.lua:64 | 戰鬥 |
| `Battle.GetMaxCounter` | (battleIndex) → 是否啟用, 最大反擊數 | [推測] 讀取該戰鬥的最大反擊數設定。 | 上游 docs/Battle.lua:259 | 戰鬥 |
| `Battle.GetNextBattle` | (battleIndex) → encountIndex, flg | [推測] 讀取連戰設定（連戰 id 與 Lua 連戰旗標 flg）。上游另有 GetNextBattleFlg，不在本機清單中。 | 上游 docs/Battle.lua:173 | 戰鬥 |
| `Battle.GetPlayIndex` | (battleIndex, slot 0-19) → charIndex；-1 失敗、-3 battleIndex 無效、-4 slot 超範圍 | [推測] 與 GetPlayer 說明相同的別名（上游文件兩者同註解）。 | 上游 docs/Battle.lua:13 | 查詢 |
| `Battle.GetPlayer` | (battleIndex, slot 0-19) → charIndex；負數=失敗/空位 | [已確認] 取得戰鬥位置上的角色 index。slot 0-9＝下方（玩家方）、10-19＝上方（敵方）。 | lua/Module/routine_too.lua:39；lua/libs/Gmsv/BattleEx.lua:5；上游 docs/Battle.lua:7 | 查詢 |
| `Battle.GetPos` | (battleIndex, charIndex) → 戰鬥位置 0-19 | [推測] 取得角色在戰鬥中的位置（上游文件與 GetEntryPosition 同註解）。 | 上游 docs/Battle.lua:156 | 查詢 |
| `Battle.GetSlot` | (battleIndex, charIndex) → slot 0-19；找不到 -1 | [已確認] Lua 包裝：逐一用 GetPlayer 比對找出角色的 slot（libs 自訂，非引擎原生）。 | lua/libs/Gmsv/BattleEx.lua:49；lua/Modules/itemprobe.lua:43 | 查詢 |
| `Battle.GetTechOption` | (charIndex, type:string) → 當前動作技能參數 | [推測] 取得當前動作技能參數（type 如 "DD"、"AR"）。 | 上游 docs/Battle.lua:186 | 技能 |
| `Battle.GetTurn` | (battleIndex) → 目前回合數 | [已確認] 取得戰鬥當前回合數。 | lua/Modules/autobattle.lua:18；上游 docs/Battle.lua:112 | 戰鬥 |
| `Battle.GetType` | (battleIndex) → 戰鬥類型常量 | [已確認] 取得戰鬥類型（一般戰、PVP 戰等；常量 CONST.戰鬥_*）。 | lua/Module/NewbieBless.lua:14；lua/Module/nofix/kickbot.lua:43 | 查詢 |
| `Battle.GetWinSide` | (battleIndex) → 0 或 1 | [已確認] 取得勝方：0＝下方（slot 0-9，玩家方）、1＝上方（slot 10-19）。（使用者實測：逃跑成功也回敵方勝） | lua/Modules/abtest.lua:200；lua/Modules/areaprobe.lua:57；lua/Module/nofix/swjjccback.lua:11 | 戰鬥 |
| `Battle.IsBossBattle` | (battleIndex) → 0 否／1 是；其他=失敗 | [推測] 判斷是否為 BOSS 戰。 | 上游 docs/Battle.lua:241 | 戰鬥 |
| `Battle.IsWaitingCommand` | (charIndex) → 0／1 | [已確認] 角色（玩家、寵物、敵人皆可）是否在戰鬥中且等待指令；ActionSelect 前必須先確認為 1。 | lua/Modules/autobattle.lua:554、:557、:571；上游 docs/Battle.lua:117 | 戰鬥 |
| `Battle.JoinBattle` | (charIndex1:戰鬥中, charIndex2:不在戰鬥中) → 0 成功 | [推測] 讓 charIndex2 加入 charIndex1 的戰鬥（類似石器時代求助），使用前先組隊。 | 上游 docs/Battle.lua:75 | 戰鬥 |
| `Battle.PVE` | (charIndex, createPtrCharIndex, doFunc:string/nil, enemyIdAr:number[], baseLevelAr:number[][, randLvAr]) → battleIndex；負數=失敗 | [已確認] 用 Lua 建立 PVE 戰鬥（enemyId 為 enemy.txt 的 ID）；第 3 參數可傳戰鬥初始化回呼函式名，不用就 nil。實測 PVE(leader, leader, nil, {id..}, {lv..}) 回 battleIndex。 | lua/Modules/itemprobe.lua:77；lua/Modules/areaprobe.lua:89；lua/Modules/abtest.lua:129；lua/Module/GoldMap.lua:127；上游 docs/Battle.lua:31 | 戰鬥 |
| `Battle.PVP` | (upCharIndex, downCharIndex) → battleIndex；負數=失敗 | [已確認] 建立 PK（玩家對玩家）戰鬥。 | lua/Module/nofix/swjjc.lua:291；上游 docs/Battle.lua:42 | 戰鬥 |
| `Battle.PositionCheck` | (charIndex, pos 0-19) → 1 可攻擊／0 不可 | [推測] 檢查該角色能否攻擊某位置（前後排、遠距武器）。 | 上游 docs/Battle.lua:271 | 戰鬥 |
| `Battle.SetBattleCharacterStatus` | (charIndex, statusType, val) → 值；失敗 -1 | [推測] 設定角色戰鬥中的狀態欄位。 | 上游 docs/Battle.lua:290 | 戰鬥 |
| `Battle.SetBattleFieldAttribute` | (battleIndex, attr:CONST.BATTLE_FIELD_ATTR, turnCount, attrPower) → 新狀態,回合,屬性；失敗 0 | [推測] 設定戰場魔法效果（如屬性反轉、魔法封印）。 | 上游 docs/Battle.lua:138 | 戰鬥 |
| `Battle.SetDexRearrangeRate` | (battleIndex, rate 0-100) → 1 成功 | [推測] 設定該戰鬥的亂敏率。（全域版見 NLG.SetDexRearrangeRate） | 上游 docs/Battle.lua:253 | 戰鬥 |
| `Battle.SetEntryData` | (battleIndex, charIndex, dataline, value) → 無 | [推測] 設定角色在該戰鬥的 Entry 資料欄。 | 上游 docs/Battle.lua:236 | 戰鬥 |
| `Battle.SetExtData` | (battleIndex, key:string, val:string/number/nil) → 無 | [推測] 在戰鬥上掛自訂資料（例如標記「這場是練功戰」）。 | 上游 docs/Battle.lua:283 | 戰鬥 |
| `Battle.SetGainMode` | (battleIndex, mode) → 1 成功 | [推測] 設定戰鬥獎勵模式（給經驗、給 DP 等）。 | 上游 docs/Battle.lua:54 | 戰鬥 |
| `Battle.SetMaxCounter` | (battleIndex, maxCounter) → 1 成功 | [推測] 設定該戰鬥的最大反擊數。 | 上游 docs/Battle.lua:265 | 戰鬥 |
| `Battle.SetNextBattle` | (battleIndex, encountIndex, flg) → 0 成功 | [推測] 設定連戰：encountIndex=-1 取消連戰、-2＝由 Lua 生成連戰（flg 為自訂旗標，之後在 NL.RegBattleNextEnemyEvent 回呼內帶出並決定下一場敵人）。 | 上游 docs/Battle.lua:145；lua/Modules/adminCommands.lua:191（註解掉的呼叫範例） | 戰鬥 |
| `Battle.SetPVPWinEvent` | (doFile/nil, funcName:string, battleIndex) → 1 成功／0 失敗 | [推測] 為 PVP 戰鬥註冊勝利事件回呼，回呼簽名 f(battleIndex)。 | 上游 docs/Battle.lua:102 | 戰鬥 |
| `Battle.SetTurn` | (battleIndex, turn) → 1 成功 | [推測] 設定目前回合數。 | 上游 docs/Battle.lua:218 | 戰鬥 |
| `Battle.SetType` | (battleIndex, type) → 1 成功 | [推測] 設定戰鬥類型（一般戰、PVP 戰等）。 | 上游 docs/Battle.lua:48 | 戰鬥 |
| `Battle.SetWinEvent` | (doFile/nil, funcName:string, battleIndex) → 1 成功／0 失敗 | [已確認] 為「非 PVP」戰鬥註冊勝利事件回呼；回呼簽名 f(battleIndex, charIndex)（上游文件）。PVE 結算後可在此發獎、記錄、續戰。本機舊腳本的回呼只收 battleIndex（待實測）。 | lua/Module/nofix/swjjc.lua:296（回呼 lua/Module/nofix/swjjccback.lua:11）；上游 docs/Battle.lua:88 | 戰鬥 |
| `Battle.UnsetPVPWinEvent` | (battleIndex) → 無 | [推測] 解除 PVP 勝利事件。 | 上游 docs/Battle.lua:212 | 戰鬥 |
| `Battle.UnsetWinEvent` | (battleIndex) → 無 | [推測] 解除 PVE 勝利事件。 | 上游 docs/Battle.lua:208 | 戰鬥 |

## NLG（51 個函式；已確認 19／推測 30／未驗證 2）

| 函式 | 參數 → 回傳 | 用途（繁體中文） | 依據 | 標籤 |
|---|---|---|---|---|
| `NLG.CanTalk` | (charIndex, targetIndex) → 上游：0／1；本機用例以 == true 比較 | [已確認] 檢查是否面對面且在對話範圍（2 格）內；NPC 對話前的距離檢查。 | lua/Module/autowarp.lua:100；上游 docs/NLG.lua:98 | NPC事件 |
| `NLG.ChangePal` | (charIndex, palId, seconds) → 1 成功 | [推測] 暫時改變玩家的地圖調色盤（與 SetPal 同註解）。 | 上游 docs/NLG.lua:173 | 地圖 |
| `NLG.CharLook` | (charIndex, dir 0-7) → 無 | [推測] 調整角色面向，可用來「激活」NPC。 | 上游 docs/NLG.lua:325 | NPC事件 |
| `NLG.CheckInFront` | (charIndex, targetIndex, distance) → 上游：0／1；本機用例以 ==false／真值判斷 | [已確認] 檢查對象是否在指定距離內且面向目標。 | lua/Module/nofix/StyleMarketGQ.lua:324；lua/Module/nofix/weapenpowerup.lua:301；上游 docs/NLG.lua:92 | NPC事件 |
| `NLG.CheckTalkRange` | (charIndex, targetIndex) → 0／1 | [推測] 與 CanTalk 同註解：面對面且在兩格對話範圍內。 | 上游 docs/NLG.lua:104 | NPC事件 |
| `NLG.DeleteCharacter` | (cdkey, dataPlaceNum 0左/1右[, callbackName]) → 0 成功（非同步） | [推測] 非同步刪除帳號下的角色；回呼 f(cdkey, dataPlaceNum, registerNumber, result)。 | 上游 docs/NLG.lua:294 | 存檔掛機 |
| `NLG.DropPlayer` | (charIndex) → 1 成功 | [已確認] 強制玩家斷線（踢人）。 | lua/Modules/autoUnlock.lua:34；lua/Module/TmpNpc.lua:55；上游 docs/NLG.lua:150 | 存檔掛機 |
| `NLG.Effect` | （未知） | [未驗證] 僅名稱，疑似播放特效；無任何註解或用例。 | 僅名稱，未驗證 | 其他 |
| `NLG.FindUser` | (cdkey[, 第二參數]) → charIndex；-1 找不到 | [已確認] 用帳號找在線玩家的角色 index（本機用例另帶第 2 個數字參數，用途未驗證）。 | lua/Modules/autoUnlock.lua:26（單參數）；lua/Modules/autoUnlock.lua:8（雙參數）；上游 docs/NLG.lua:208 | 查詢 |
| `NLG.GetArgNpc` | (npcIndex) → string（NPC 參數） | [推測] 取得 NL.CreateArgNpc 所建 NPC 的參數字串。 | 上游 docs/NLG.lua:315 | NPC事件 |
| `NLG.GetDungeonLimit` | (dungeonId) → 剩餘時間 | [推測] 取得迷宮剩餘時間。 | 上游 docs/NLG.lua:320 | 地圖 |
| `NLG.GetGameTime` | () → 0 白天／1 黃昏／2 夜晚／3 清晨 | [推測] 取得遊戲內時段。 | 上游 docs/NLG.lua:239 | 查詢 |
| `NLG.GetIp` | (charIndex) → string | [已確認] 取得玩家 IP（僅玩家有效）。 | lua/Module/TmpNpc.lua:39；上游 docs/NLG.lua:230 | 查詢 |
| `NLG.GetMac` | (charIndex) → string | [推測] 取得玩家 MAC 位址（僅玩家有效）。上游文件寫作 NLG.GetMAC（大小寫不同），本機實際名稱 GetMac，簽名依上游推測。 | 上游 docs/NLG.lua:235 | 查詢 |
| `NLG.GetMapName` | (mapType, floor) → string；失敗 0 | [已確認] 取得地圖名稱。 | lua/Module/myLogin.lua:152；上游 docs/NLG.lua:203 | 地圖 |
| `NLG.GetMapPlayer` | (mapType, floor) → table（charIndex 陣列）；無人回非 table | [已確認] 取得某地圖上所有玩家。 | lua/Module/nofix/RaceHorse.lua:519；上游 docs/NLG.lua:145 | 查詢 |
| `NLG.GetMapPlayerNum` | (mapType, floor) → 人數；失敗 -1 | [推測] 取得地圖玩家數。 | lua/Module/nofix/kickbot.lua:26（已註解）；上游 docs/NLG.lua:118 | 查詢 |
| `NLG.GetOnLinePlayer` | () → 在線人數；失敗 -1 | [推測] 取得在線人數（與 GetPlayerNum 同註解）。 | 上游 docs/NLG.lua:112 | 查詢 |
| `NLG.GetPlayer` | () → table（所有在線玩家 charIndex；上游文件回傳型別寫 number，實為 table） | [推測] 取得所有在線玩家的 index 清單。 | 上游 docs/NLG.lua:255 | 查詢 |
| `NLG.GetPlayerNum` | () → 在線人數；失敗 -1 | [已確認] 取得在線玩家數。 | lua/Module/question.lua:296；上游 docs/NLG.lua:108 | 查詢 |
| `NLG.LowCpuUsage` | (ms) → 無 | [推測] 降低 CPU 使用：<0 關閉，>=0 為每輪 Sleep 毫秒數（不建議 >2）。 | 上游 docs/NLG.lua:259 | 其他 |
| `NLG.OpenBank` | (npcOrPlayerIndex, playerIndex) → 0 成功 | [推測] 替玩家開啟銀行視窗。 | 上游 docs/NLG.lua:265 | 交易 |
| `NLG.PlaySe` | (charIndex, toneId, pan 0-635（建議 320）, unk) → 無 | [推測] 播放音效。 | 上游 docs/NLG.lua:332 | 訊息 |
| `NLG.RaiseCrash` | () → 無 | [推測] 模擬伺服器崩潰（測試用，請勿呼叫）。 | 上游 docs/NLG.lua:268 | 其他 |
| `NLG.Rand` | (min, max) → 隨機整數 | [已確認] 用 gmsv 自身亂數種子取隨機數。 | lua/Module/jp.lua:56；上游 docs/NLG.lua:219 | 其他 |
| `NLG.Say` | (toIndex, talkerIndex, msg[, color, size]) → 0 成功 | [推測] 普通說話；toIndex=-1 對全伺服器，talkerIndex=-1 不顯示說話者名。 | 上游 docs/NLG.lua:10 | 訊息 |
| `NLG.Say2Map` | (mapType, floor, talkerIndex, msg[, color, size]) → 0 成功 | [推測] 對指定地圖所有玩家說話（與 TalkToMap／TalkToFloor 同註解）。 | 上游 docs/NLG.lua:39 | 訊息 |
| `NLG.SetAction` | (charIndex, action) → 0 成功 | [已確認] 設定對象動作編號（NPC 動畫等）。 | lua/Module/announce.lua:50；上游 docs/NLG.lua:79 | NPC事件 |
| `NLG.SetCriticalDamageAddition` | (mode 0普通/1倍率/2無/3破防, val) → 無 | [推測] 全域修改暴擊時的傷害計算方式（預設倍率 1.5；mode 3 時 val 為破防率）。 | 上游 docs/NLG.lua:288 | 戰鬥 |
| `NLG.SetDexRearrangeRate` | (rate 0-100, mode nil/0=PVE+PVP /1=PVE /2=PVP) → 1 成功 | [推測] 全域設定亂敏率。（單場版見 Battle.SetDexRearrangeRate） | 上游 docs/NLG.lua:283 | 戰鬥 |
| `NLG.SetHeadIcon` | (charIndex, headGraNo) → 1 成功 | [推測] 給人物／NPC／寵物頭上顯示任意客戶端圖檔。 | 上游 docs/NLG.lua:225 | NPC事件 |
| `NLG.SetMapName` | (mapType, floor, name) → 1 成功 | [推測] 設定地圖名稱。 | 上游 docs/NLG.lua:197 | 地圖 |
| `NLG.SetObj` | (mapType, floor, x, y, obj) → 1 成功；obj=0 刪除 | [推測] 在座標設定地圖物件（地圖上的靜態物件圖）。 | 上游 docs/NLG.lua:159 | 地圖 |
| `NLG.SetPal` | (charIndex, palId, seconds) → 1 成功 | [推測] 暫時改變玩家的地圖調色盤。 | 上游 docs/NLG.lua:166 | 地圖 |
| `NLG.SetPetRandomShot` | (enable) 或 (petId, enable) → 無 | [推測] 開啟寵物亂射（全域，或指定某種寵物 EnemyBaseId）。 | 上游 docs/NLG.lua:272 | 寵物 |
| `NLG.SetTribeRate` | (attackerTribe, defenderTribe, rate) → 比率 | [推測] 設定種族之間的傷害比率。 | 上游 docs/NLG.lua:251 | 戰鬥 |
| `NLG.ShowTalked` | （未知） | [未驗證] 僅名稱，疑似與對話框顯示有關；無任何註解或用例（推測：舊名／別名）。 | 僅名稱，未驗證 | NPC事件 |
| `NLG.ShowWindowTalked` | (toIndex, npcIndex, windowType, buttonType, seqNo, data:string) → 0 成功 | [已確認] 對玩家顯示 NPC 對話視窗；玩家操作後觸發 WindowTalkedCallBack(npc, player, seqNo, select, data)；視窗與按鈕常量見 CONST.窗口_*、BUTTON_*。 | lua/libs/Module/Parts/Npc.lua:215；lua/libs/Module/Parts/Char.lua:80；上游 docs/NLG.lua:64 | NPC事件 |
| `NLG.SortItem` | (charIndex) → 1 成功／0 失敗 | [已確認] 整理玩家背包。 | lua/Module/packagesort.lua:8；上游 docs/NLG.lua:244 | 道具 |
| `NLG.SystemMessage` | (charIndex, msg) → 1 成功；charIndex=-1 對全服 | [已確認] 發送黃色粗體系統公告。 | lua/Modules/welcome.lua:20；lua/Modules/autoUnlock.lua:35；上游 docs/NLG.lua:124 | 訊息 |
| `NLG.SystemMessageToMap` | (mapType, floor, msg) → 1 成功 | [已確認] 對指定地圖所有玩家發系統公告。 | lua/Module/nofix/RaceHorse.lua:219；上游 docs/NLG.lua:131 | 訊息 |
| `NLG.TalkToCli` | (toIndex, talkerIndex, msg[, color, size]) → 0 成功 | [已確認] 對單一玩家顯示聊天訊息；talkerIndex=-1 不顯示說話者。 | lua/Modules/welcome.lua:17；lua/Modules/admin.lua:27；上游 docs/NLG.lua:19 | 訊息 |
| `NLG.TalkToFloor` | (mapType, floor, talkerIndex, msg[, color, size]) → 0 成功 | [推測] 對指定地圖說話。本機舊腳本傳 (0,25000,msg,color,size) 順序與上游不同，26.8d 待實測。 | lua/Module/nofix/diceman.lua:101；上游 docs/NLG.lua:49 | 訊息 |
| `NLG.TalkToMap` | (mapType, floor, talkerIndex, msg[, color, size]) → 0 成功 | [推測] 對指定地圖所有玩家說話。 | 上游 docs/NLG.lua:29 | 訊息 |
| `NLG.UpChar` | (charIndex) → 無 | [已確認] 檢查對象改動並把更新封包送給相關玩家；Char.SetData 改數值後需呼叫才會顯示。 | lua/libs/Module/Parts/Npc.lua:114；lua/Modules/abtest.lua:113；lua/Modules/itemprobe.lua:41；上游 docs/NLG.lua:53 | 查詢 |
| `NLG.UpdateParty` | (charIndex) → 未說明 | [推測] 更新玩家的隊伍資訊。 | 上游 docs/NLG.lua:213 | 隊伍 |
| `NLG.WalkMove` | (charIndex, dir 0-7) → 0 成功 | [已確認] 讓對象（含 NPC）往指定方向走一格；做會走動的 NPC 或腳本移動的基礎。 | lua/Module/announce.lua:52；lua/Module/nofix/monraceplus.lua:450；上游 docs/NLG.lua:85 | 移動 |
| `NLG.Walkable` | (mapType, floor, x, y) → 1 可通行／0 不可 | [已確認] 檢測座標是否可通行。 | lua/Module/myLogin.lua:151；上游 docs/NLG.lua:139 | 地圖 |
| `NLG.WatchBattle` | (charIndex, targetIndex) → 1 成功 | [推測] 讓 charIndex 進入觀戰 targetIndex 的戰鬥。 | 上游 docs/NLG.lua:179 | 戰鬥 |
| `NLG.WatchEntry` | (charIndex, targetIndex) → 1 成功 | [推測] 與 WatchBattle 同註解（觀戰）。 | 上游 docs/NLG.lua:185 | 戰鬥 |
| `NLG.c` | (msg:string) → string | [已確認] 把 NPC 對話框文字置中（回傳加了置中排版的字串）。 | lua/Modules/bagSwitch.lua:26；lua/Module/autowarp.lua:104；上游 docs/NLG.lua:190 | NPC事件 |

## NL（118 個函式；已確認 60／推測 55／未驗證 3）

| 函式 | 參數 → 回傳 | 用途（繁體中文） | 依據 | 標籤 |
|---|---|---|---|---|
| `NL.CreateArgNpc` | (type:string, arg:string, name, image, mapType, floor, x, y, dir[, showTime]) → npcIndex；負數=失敗 | [已確認] 直接建立 npc.txt 支援類型的 NPC（如 Itemshop2、WalkEnemy），type 大小寫敏感；回傳 NPC 的 charIndex。 | lua/libs/Module/Parts/Npc.lua:36、:83；lua/Module/nofix/checked/WorldBOSS.lua:75；上游 docs/NL.lua:40 | NPC事件 |
| `NL.CreateNpc` | (doFile/nil, initFuncName:string) → npcIndex；負數=失敗 | [已確認] 用 Lua 建立 NPC，建好後呼叫 initFuncName(npcIndex) 讓你設定名字／圖／座標／事件（上游寫作 NL.CreateNPC）。 | lua/libs/Module/Parts/Npc.lua:100；lua/Module/autowarp.lua:72；lua/libs/Module/LegacyModule.lua:56；上游 docs/NL.lua:16 | NPC事件 |
| `NL.DelArgNpc` | (npcIndex) → 1 成功／0 失敗 | [推測] 刪除 CreateArgNpc 建立的 NPC（上游兩個 Del 函式說明相同）。 | 上游 docs/NL.lua:1454 | NPC事件 |
| `NL.DelNpc` | (npcIndex) → 1 成功／0 失敗 | [已確認] 刪除 Lua 建立的 NPC；刪後不會把變數設 nil，需自行處理。 | lua/libs/Module/Parts/Npc.lua:247；lua/Module/nofix/monraceplus.lua:524；上游 docs/NL.lua:27 | NPC事件 |
| `NL.GetErrorStr` | （未知） | [未驗證] 僅名稱，疑似取最近一次 Lua／引擎錯誤字串；無註解或用例（推測）。 | 僅名稱，未驗證 | 其他 |
| `NL.PrintError` | (s:string) → 無 | [推測] 把錯誤文字印到伺服器日誌。 | 上游 docs/NL.lua:9 | 其他 |
| `NL.RegAfterBattleTurnEvent` | (luaFile/nil, 全域函式名) → 無；回呼 AfterBattleTurnCallBack(battleIndex) → 無 | [推測] 每回合結束時觸發 | 上游 docs/NL.lua:804 | 戰鬥 |
| `NL.RegAfterCalcCharaBpEvent` | (luaFile/nil, 全域函式名) → 無；回呼 AfterCalcCharaBpCallBack(charIndex) → 無 | [推測] 角色屬性（含裝備）計算後觸發 | 上游 docs/NL.lua:815 | 其他 |
| `NL.RegAfterCalcCharaStatusEvent` | (luaFile/nil, 全域函式名) → 無；回呼 AfterCalcCharaStatusCallBack(charIndex) → 無 | [推測] 角色裝備／受傷／掉魂等狀態計算後觸發 | 上游 docs/NL.lua:826 | 其他 |
| `NL.RegAfterWarpEvent` | (luaFile/nil, 全域函式名) → 無；回呼 AfterWarpEventCallBack(CharIndex, Ori_MapId, Ori_FloorId, Ori_X, Ori_Y, Target_MapId, Target_FloorId, Target_X, Target_Y) → 回 0 即可 | [推測] 傳送完成後觸發（只能記錄，不能改目的地） | 上游 docs/NL.lua:177 | 移動 |
| `NL.RegAutoBattleCommandEvent` | (luaFile/nil, 全域函式名) → 無；回呼 AutoBattleCommandEvent(battleIndex, CharIndex) → 必須回 1，否則角色原地不動 | [已確認] 玩家啟用遊戲內自動戰鬥、輪到該角色決定指令時觸發；Lua 可在此 Battle.ActionSelect 接管出招 | lua/Modules/autobattle.lua:674；上游 docs/NL.lua:386 | 戰鬥 |
| `NL.RegBattleActionEvent` | (luaFile/nil, 全域函式名) → 無；回呼 BattleActionEventCallBack(CharIndex, Com1, Com2, Com3, ActionNum) → 無 | [推測] 玩家在戰鬥中下指令時觸發（Com1 指令、Com2 目標位置、Com3 技能 ID、ActionNum 第幾動） | 上游 docs/NL.lua:371 | 戰鬥 |
| `NL.RegBattleActionTargetEvent` | (luaFile/nil, 全域函式名) → 無；回呼 BattleActionTargetEventCallback(charIndex, battleIndex, com1, com2, com3, targetList) → 新目標位置 table；無修改回 targetList | [已確認] 玩家攻擊時觸發，可改攻擊目標（亂射、連擊等） | lua/libs/GlobalEvents.lua:313（回呼參數註解）；上游 docs/NL.lua:1270 | 戰鬥 |
| `NL.RegBattleAfterActionEvent` | (luaFile/nil, 全域函式名) → 無；回呼 BattleAfterActionEventCallback(battleIndex, charIndex, addAction) → 回 0 即可 | [推測] 戰鬥 ACTION 執行後觸發 | 上游 docs/NL.lua:1576 | 戰鬥 |
| `NL.RegBattleBeforeActionEvent` | (luaFile/nil, 全域函式名) → 無；回呼 BattleBeforeActionEventCallback(battleIndex, charIndex, addAction) → 回 0 即可 | [推測] 戰鬥 ACTION 執行前觸發 | 上游 docs/NL.lua:1562 | 戰鬥 |
| `NL.RegBattleCalcDexEvent` | (luaFile/nil, 全域函式名) → 無；回呼 BattleCalcDexEventCallback(battleIndex, charaIndex, action, flg, dex) → 新 dex | [已確認] 戰鬥計算行動順序（dex）時觸發，可改 dex | lua/libs/GlobalEvents.lua:285（回呼參數註解）；上游 docs/NL.lua:1398 | 戰鬥 |
| `NL.RegBattleCounterRateEvent` | (luaFile/nil, 全域函式名) → 無；回呼 BattleCounterRateCallBack(battleIndex, aIndex, fIndex, rate) → 新反擊率 | [已確認] 反擊率計算時觸發，可改機率 | lua/libs/GlobalEvents.lua:265（回呼參數註解）；上游 docs/NL.lua:1012 | 戰鬥 |
| `NL.RegBattleDodgeRateEvent` | (luaFile/nil, 全域函式名) → 無；回呼 BattleDodgeRateCallBack(battleIndex, aIndex, fIndex, rate) → 新閃躲率 | [已確認] 閃躲率計算時觸發，可改機率 | lua/libs/GlobalEvents.lua:261（回呼參數註解）；上游 docs/NL.lua:997 | 戰鬥 |
| `NL.RegBattleEscapeEvent` | (luaFile/nil, 全域函式名) → 無；回呼 BattleEscape(battleIndex, charIndex, rate) → 1 成功／0 失敗 | [推測] 逃跑判定時觸發，可改結果 | 上游 docs/NL.lua:954 | 戰鬥 |
| `NL.RegBattleExitEvent` | (luaFile/nil, 全域函式名) → 無；回呼 BattleExitCallBack(CharIndex, BattleIndex, Type) → 無 | [推測] 玩家離開戰鬥時觸發（Type 1=正常離開含勝敗逃跑登出、2=被踢） | 上游 docs/NL.lua:292 | 戰鬥 |
| `NL.RegBattleGetProfitEvent` | (luaFile/nil, 全域函式名) → 無；回呼 BattleGetProfitEventCallback(battleIndex, side, pos, charaIndex, type, reward) → 修改後的經驗／DP／ItemIndex | [已確認] 戰鬥取得戰利品（經驗／DP／物品）時觸發，可改數值 | lua/libs/GlobalEvents.lua:281（回呼參數註解）；上游 docs/NL.lua:1381 | 戰鬥 |
| `NL.RegBattleHealCalculateEvent` | (luaFile/nil, 全域函式名) → 無；回呼 BattleHealCalculateCallBack(charIndex, defCharIndex, oriheal, heal, battleIndex, com1, com2, com3, defCom1, defCom2, defCom3, flg, ExFlg) → 新治療值 | [已確認] 戰鬥計算治療量時觸發，可改治療值 | lua/libs/GlobalEvents.lua:140（回呼參數註解）；上游 docs/NL.lua:1171 | 戰鬥 |
| `NL.RegBattleInjuryEvent` | (luaFile/nil, 全域函式名) → 無；回呼 BattleInjuryCallBack(dIndex, aIndex, battleIndex, inject, newVal) → 受傷程度 0~100 | [已確認] 戰鬥中受傷時觸發，可改受傷程度 | lua/libs/GlobalEvents.lua:144（回呼參數註解）；上游 docs/NL.lua:877 | 戰鬥 |
| `NL.RegBattleLuaSkillEvent` | (luaFile/nil, 全域函式名) → 無；回呼 BattleLuaSkillEventCallback(battleIndex, charIndex, SKLFunc, ActFunc, MsgFunc) → 無 | [推測] 自訂 Lua 技能：回呼拿到 SKLFunc／ActFunc／MsgFunc 三個函式，用來自己送技能封包、動作節、戰鬥訊息 | 上游 docs/NL.lua:1301 | 技能 |
| `NL.RegBattleMagicDamageRateEvent` | (luaFile/nil, 全域函式名) → 無；回呼 BattleMagicDamageRateCallBack(battleIndex, aIndex, fIndex, rate) → 新係數 | [已確認] 造成魔法傷害時觸發，可改魔法傷害係數 | lua/libs/GlobalEvents.lua:269（回呼參數註解）；上游 docs/NL.lua:1027 | 戰鬥 |
| `NL.RegBattleMagicRssRateEvent` | (luaFile/nil, 全域函式名) → 無；回呼 BattleMagicRssRateCallBack(battleIndex, aIndex, fIndex, rate) → 新係數 | [已確認] 造成魔法傷害時觸發，可改魔防係數 | lua/libs/GlobalEvents.lua:273（回呼參數註解）；上游 docs/NL.lua:1042 | 戰鬥 |
| `NL.RegBattleNextEnemyEvent` | (luaFile/nil, 全域函式名) → 無；回呼 BattleNextEnemyCallBack(battleIndex, flg) → table {enemyId,等級,...} 依位置 10-19 排列，或 nil | [已確認] 連戰（Battle.SetNextBattle -2 的 Lua 連戰）生成怪物前觸發，可改怪物與等級；回 nil 取消連戰 | lua/libs/GlobalEvents.lua:168（回呼參數註解）；上游 docs/NL.lua:757 | 戰鬥 |
| `NL.RegBattleNextEnemyInitEvent` | (luaFile/nil, 全域函式名) → 無；回呼 BattleNextEnemyInitCallBack(battleIndex, flg) → 無 | [推測] 連戰怪物生成前觸發，可改其屬性 | 上游 docs/NL.lua:770 | 戰鬥 |
| `NL.RegBattleOverEvent` | (luaFile/nil, 全域函式名) → 無；回呼 BattleOverEventCallBack(BattleIndex) → 回 0 即可 | [已確認] 戰鬥結束時觸發；可在此用 Battle.GetWinSide 取勝負、統計戰果 | lua/Modules/autobattle.lua:672；上游 docs/NL.lua:144 | 戰鬥 |
| `NL.RegBattlePetLeaveCheckEvent` | (luaFile/nil, 全域函式名) → 無；回呼 BattlePetLeaveCheckEventCallback(battleIndex, charIndex, type, com1, com2, com3) → 新 type | [已確認] 戰鬥中寵物行為（離隊）檢測事件 | lua/libs/GlobalEvents.lua:297（回呼參數註解）；上游 docs/NL.lua:1545 | 寵物 |
| `NL.RegBattlePreEvent` | (luaFile/nil, 全域函式名) → 無；回呼 BattlePreEventCallBack(battleIndex) → 回 0 即可 | [推測] 戰鬥資料送往客戶端前觸發 | 上游 docs/NL.lua:1653 | 戰鬥 |
| `NL.RegBattleSealRateEvent` | (luaFile/nil, 全域函式名) → 無；回呼 BattleSealRateCallBack(battleIndex, charIndex, enemyIndex, rate) → 新成功率 | [已確認] 封印（抓寵）成功率計算時觸發，可改機率（不能突破伺服器設定） | lua/libs/GlobalEvents.lua:253（回呼參數註解）；上游 docs/NL.lua:968 | 封印 |
| `NL.RegBattleSkillCheckEvent` | (luaFile/nil, 全域函式名) → 無；回呼 BattleSkillCheckEventCallback(charIndex, battleIndex, arrayOfSkillEnable) → table（各技能 1 可用／0 不可用） | [已確認] 控制技能是否可使用 | lua/libs/GlobalEvents.lua:317（回呼參數註解）；上游 docs/NL.lua:1287 | 技能 |
| `NL.RegBattleSkillExpEvent` | (luaFile/nil, 全域函式名) → 無；回呼 GetBattleSkillExpEventCallBack(CharIndex, SkillID, Exp) → 新經驗值 | [已確認] 取得戰鬥技能經驗時觸發，可改經驗值 | lua/libs/GlobalEvents.lua:249（回呼參數註解）；上游 docs/NL.lua:237 | 技能 |
| `NL.RegBattleStartEvent` | (luaFile/nil, 全域函式名) → 無；回呼 BattleStartEventCallBack(BattleIndex) → 回 0 即可 | [推測] 戰鬥開始時觸發（參數 battleIndex） | 上游 docs/NL.lua:132 | 戰鬥 |
| `NL.RegBattleStatusReflectionEvent` | (luaFile/nil, 全域函式名) → 無；回呼 BattleStatusReflectionEventCallback(battleIndex, charIndex) → 回 0 即可 | [推測] 戰鬥狀態反射事件（上游文件無說明） | 上游 docs/NL.lua:1640 | 戰鬥 |
| `NL.RegBattleStatusResistanceEvent` | (luaFile/nil, 全域函式名) → 無；回呼 BattleStatusResistanceEventCallback(battleIndex, aCharIndex, dCharIndex, type, rate) → 機率（萬分率） | [已確認] 戰鬥異常狀態命中事件，可改機率（萬分率） | lua/libs/GlobalEvents.lua:301（回呼參數註解）；上游 docs/NL.lua:1590 | 戰鬥 |
| `NL.RegBattleSummonEnemyEvent` | (luaFile/nil, 全域函式名) → 無；回呼 BattleSummonEnemyCallBack(battleIndex, charIndex, enemyId) → 新 table {enemyId,等級,等級波動} | [已確認] 怪物施放召喚時觸發，可改召喚物種類與等級 | lua/libs/GlobalEvents.lua:164（回呼參數註解）；上游 docs/NL.lua:730 | 戰鬥 |
| `NL.RegBattleSummonedEnemyEvent` | (luaFile/nil, 全域函式名) → 無；回呼 BattleSummonedEnemyCallBack(battleIndex, actionCharIndex, charIndex) → 無 | [推測] 召喚物生成前觸發，可改其屬性 | 上游 docs/NL.lua:744 | 戰鬥 |
| `NL.RegBattleSurpriseEvent` | (luaFile/nil, 全域函式名) → 無；回呼 BattleSurpriseCallBack(battleIndex, result) → 0 不偷襲／1 偷襲／2 被偷襲 | [已確認] 戰鬥偷襲判定前觸發，可改偷襲形式 | lua/libs/GlobalEvents.lua:132（回呼參數註解）；上游 docs/NL.lua:717 | 戰鬥 |
| `NL.RegBeforeBattleTurnEvent` | (luaFile/nil, 全域函式名) → 無；回呼 BeforeBattleTurnCallBack(battleIndex) → 無 | [已確認] 每回合怪物 AI 執行前觸發（參數 battleIndex）；自動戰鬥模組在此為每個角色下指令 | lua/Modules/autobattle.lua:671；lua/libs/GlobalEvents.lua:110（回呼參數註解）；上游 docs/NL.lua:782 | 戰鬥 |
| `NL.RegBeforeBattleTurnStartEvent` | (luaFile/nil, 全域函式名) → 無；回呼 BeforeBattleTurnStartCallBack(battleIndex) → 無 | [推測] 所有指令都就位、回合開始前觸發 | 上游 docs/NL.lua:793 | 戰鬥 |
| `NL.RegBeforeCharaSaveEvent` | (luaFile/nil, 全域函式名) → 無；回呼 BeforeCharaSaveCallBack(charIndex) → 無 | [推測] 角色存檔前觸發 | 上游 docs/NL.lua:915 | 存檔掛機 |
| `NL.RegCalcCriticalRateEvent` | (luaFile/nil, 全域函式名) → 無；回呼 CalcCriticalRateCallBack(aIndex, fIndex, rate) → 新必殺率 | [已確認] 暴擊（必殺）率計算時觸發，可改機率 | lua/libs/GlobalEvents.lua:257（回呼參數註解）；上游 docs/NL.lua:983 | 戰鬥 |
| `NL.RegCalcFpConsumeEvent` | (luaFile/nil, 全域函式名) → 無；回呼 CalcFpConsumeCallBack(charIndex, techId, Fp) → 新耗魔值 | [推測] 技能耗魔計算時觸發，可改耗魔數值 | 上游 docs/NL.lua:1196 | 技能 |
| `NL.RegCallback` | (eventName:string, callbackFuncName:string) → 無 | [已確認] 底層：登記某事件（名稱不含 Reg 前綴）的回呼全域函式；所有 NL.RegXxx 包裝函式最終都呼叫它。 | exe_strings.txt:197260（NL.newEvent 內呼叫） | 其他 |
| `NL.RegCharActionEvent` | (luaFile/nil, 全域函式名) → 無；回呼 CharActionEventCallBack(CharIndex, ActionID) → 無 | [推測] 玩家做任何動作（暈倒、攻擊、剪刀石頭布等）時觸發 | 上游 docs/NL.lua:399 | 其他 |
| `NL.RegCharaDeletedEvent` | (luaFile/nil, 全域函式名) → 無；回呼 CharaDeletedCallBack(cdkey, registnumber, result) → 無 | [推測] 角色被刪除時觸發（cdkey, registnumber, result） | 上游 docs/NL.lua:926 | 存檔掛機 |
| `NL.RegCharaSavedEvent` | (luaFile/nil, 全域函式名) → 無；回呼 CharaSavedCallBack(charIndex) → 無 | [推測] 角色存檔後觸發 | 上游 docs/NL.lua:904 | 存檔掛機 |
| `NL.RegCharaStallBrowseEvent` | (luaFile/nil, 全域函式名) → 無；回呼 CharaStallBrowseEventCallback(buyer, seller) → 無 | [推測] 有人瀏覽攤位時觸發 | 上游 docs/NL.lua:1501 | 交易 |
| `NL.RegCharaStallEndEvent` | (luaFile/nil, 全域函式名) → 無；回呼 CharaStallEndEventCallback(seller) → 無 | [推測] 擺攤結束時觸發 | 上游 docs/NL.lua:1490 | 交易 |
| `NL.RegCharaStallSoldEvent` | (luaFile/nil, 全域函式名) → 無；回呼 CharaStallSoldEventCallback(buyer, seller, itemIndex, petIndex, price) → 無 | [推測] 擺攤有物品成交時觸發 | 上游 docs/NL.lua:1464 | 交易 |
| `NL.RegCharaStallStartEvent` | (luaFile/nil, 全域函式名) → 無；回呼 CharaStallStartEventCallback(seller) → 無 | [推測] 擺攤開始時觸發 | 上游 docs/NL.lua:1479 | 交易 |
| `NL.RegCheckDummyDollEvent` | (luaFile/nil, 全域函式名) → 無；回呼 CheckDummyDoll(charIndex, battleIndex, dmg, type) → 1 可用娃娃／0 禁用 | [推測] 替身娃娃（A\|B 型）結算前觸發 | 上游 docs/NL.lua:862 | 戰鬥 |
| `NL.RegDamageCalculateEvent` | (luaFile/nil, 全域函式名) → 無；回呼 DamageCalculateCallBack(CharIndex, DefCharIndex, OriDamage, Damage, BattleIndex, Com1, Com2, Com3, DefCom1, DefCom2, DefCom3, Flg, ExFlg) → 新傷害值 | [已確認] 戰鬥計算傷害時觸發，可改傷害值（攻守雙方指令、Flg 傷害模式皆在參數內） | lua/libs/GlobalEvents.lua:136（回呼參數註解）；上游 docs/NL.lua:638 | 戰鬥 |
| `NL.RegDropEvent` | (luaFile/nil, 全域函式名) → 無；回呼 DropEventCallBack(CharIndex) → 回 0 即可 | [已確認] 玩家掉線時觸發 | lua/Modules/loginGate.lua:115；上游 docs/NL.lua:198 | 存檔掛機 |
| `NL.RegEnemyCommandEvent` | (luaFile/nil, 全域函式名) → 無；回呼 EnemyCommandCallBack(battleIndex, side, slot, action) → 無 | [推測] 怪物執行 AI 時觸發（side、slot、action） | 上游 docs/NL.lua:848 | 戰鬥 |
| `NL.RegGatherItemEvent` | (luaFile/nil, 全域函式名) → 無；回呼 GatherItemEventCallback(charIndex, skillId, skillLv, itemId) → 道具 ID 或不回傳 | [推測] 採集技能觸發採集時呼叫，可回採集到的道具 ID（見 itemset.txt）；不回傳＝預設結果 | 上游 docs/NL.lua:1240 | 採集 |
| `NL.RegGatherTechUsedEvent` | （參數未知；推測：回呼 (charIndex, 技能…)） | [未驗證] 推測：採集技能使用時觸發（與 RegGatherItemEvent 成對）；引擎錯誤訊息出現 NPC_Lua_NL_GatherTechUsedCallBack。 | 僅名稱，未驗證（字串：exe_strings.txt:180513、:194939） | 採集 |
| `NL.RegGetExpEvent` | (luaFile/nil, 全域函式名) → 無；回呼 GetExpEventCallBack(CharIndex, Exp) → 新經驗值；不改就 return Exp | [已確認] 取得戰鬥經驗時觸發，可改經驗值（先於道具加成計算） | lua/libs/GlobalEvents.lua:241（回呼參數註解）；上游 docs/NL.lua:224 | 戰鬥 |
| `NL.RegGetLevelExpEvent` | （參數未知） | [未驗證] 推測：計算「升到某等級所需經驗」時觸發，可改經驗表；引擎錯誤訊息出現 NPC_Lua_NL_GetLevelExpCallBack。上游文件無此事件。 | 僅名稱，未驗證（字串：exe_strings.txt:180523、:194955） | 技能 |
| `NL.RegGetLoginPointEvent` | (luaFile/nil, 全域函式名) → 無；回呼 GetLoginPointEventCallBack(CharIndex, MapID, FloorID, X, Y) → 無 | [已確認] 玩家登入取得登入點時觸發；在回呼內直接設座標即可（免 warp） | lua/Modules/loginGate.lua:113；上游 docs/NL.lua:441 | 存檔掛機 |
| `NL.RegHeadCoverEvent` | (luaFile/nil, 全域函式名) → 無；回呼 HeadCoverEventCallBack(CharIndex, CurrentHeadCoverImage) → 新圖檔 ID | [推測] 角色顯示頭飾時觸發，可換頭飾圖檔 ID | 上游 docs/NL.lua:678 | 其他 |
| `NL.RegHttpRequestEvent` | (luaFile/nil, 全域函式名) → 無；回呼 HttpRequestCallBack(method, api, params, body) → string 回應內容 | [已確認] 收到伺服器內建 HTTP 請求時觸發；回傳內容為 HTTP 回應 | lua/Modules/http.lua:27；上游 docs/NL.lua:1140 | 查詢 |
| `NL.RegHttpResultEvent` | (luaFile/nil, 全域函式名) → 無；回呼 HttpResultCallBack(reqId, url, success, statusCode, responseBody, errMsg) → 無 | [推測] Http 請求結果回調（reqId, url, success, statusCode, responseBody, errMsg） | 上游 docs/NL.lua:1155 | 查詢 |
| `NL.RegInit` | () → 無（GlobalEvents 註解：事件參數 Init()） | [已確認] 伺服器腳本初始化完成時觸發；舊式腳本用 Delegate.RegInit("函式名")，在此建立 NPC、註冊事件。 | lua/libs/GlobalEvents.lua:209；lua/Module/autowarp.lua:34（Delegate.RegInit） | 存檔掛機 |
| `NL.RegItemAttachEvent` | (luaFile/nil, 全域函式名) → 無；回呼 ItemAttachCallBack(CharIndex, FromItemIndex) → <0 取消 | [已確認] 玩家裝備道具時觸發；<0 取消 | lua/libs/GlobalEvents.lua:181（回呼參數註解）；上游 docs/NL.lua:547 | 道具 |
| `NL.RegItemBoxEncountEvent` | (luaFile/nil, 全域函式名) → 無；回呼 ItemBoxEncountCallback(charaIndex, mapId, floor, X, Y, itemIndex) → table 或 nil（nil 不攔截） | [推測] 寶箱遇敵時觸發，可回自訂敵人陣列（每隻 3 值：id、等級、隨機等級） | 上游 docs/NL.lua:1109 | 地圖 |
| `NL.RegItemBoxEncountRateEvent` | (luaFile/nil, 全域函式名) → 無；回呼 ItemBoxEncountRateEventCallback(charaIndex, mapId, floor, X, Y, itemIndex, rate, boxType) → 新遇敵機率 | [已確認] 寶箱遇敵機率計算時觸發，可改機率 | lua/libs/GlobalEvents.lua:277（回呼參數註解）；上游 docs/NL.lua:1090 | 地圖 |
| `NL.RegItemBoxGenerateEvent` | (luaFile/nil, 全域函式名) → 無；回呼 ItemBoxGenerateCallback(mapId, floor, itemBoxType, adm) → table {itemBoxType, adm} | [推測] 寶箱生成時觸發，可改寶箱參數 | 上游 docs/NL.lua:1057 | 地圖 |
| `NL.RegItemBoxLootEvent` | (luaFile/nil, 全域函式名) → 無；回呼 ItemBoxLootCallback(charaIndex, mapId, floor, X, Y, boxType, adm) → 1 攔截／0 不攔截 | [推測] 寶箱取得物品時觸發；回 1 攔截預設物品 | 上游 docs/NL.lua:1072 | 地圖 |
| `NL.RegItemConsumeEvent` | (luaFile/nil, 全域函式名) → 無；回呼 ItemConsumeEventCallback(charIndex, itemIndex, slot, amount) → 消耗數量 | [已確認] 玩家在戰鬥中使用物品時觸發，可改消耗數量 | lua/libs/GlobalEvents.lua:305（回呼參數註解）；上游 docs/NL.lua:1440 | 戰鬥 |
| `NL.RegItemDetachEvent` | (luaFile/nil, 全域函式名) → 無；回呼 ItemDetachCallBack(CharIndex, FromItemIndex) → 無 | [推測] 玩家卸下裝備時觸發 | 上游 docs/NL.lua:560 | 道具 |
| `NL.RegItemDropEvent` | (luaFile/nil, 全域函式名) → 無；回呼 ItemDropCallBack(CharIndex, ItemIndex) → <0 攔截 | [已確認] 玩家丟棄道具時觸發；<0 攔截 | lua/libs/GlobalEvents.lua:177（回呼參數註解）；上游 docs/NL.lua:572 | 道具 |
| `NL.RegItemDropRateEvent` | (luaFile/nil, 全域函式名) → 無；回呼 ItemDropRateEventCallback(battleIndex, enemyIndex, charaIndex, itemId, rate) → 新掉率 | [已確認] 怪物掉寶機率事件，可改掉率（打錢／掉落調整用） | lua/libs/GlobalEvents.lua:293（回呼參數註解）；上游 docs/NL.lua:1529 | 戰鬥 |
| `NL.RegItemDurabilityChangedEvent` | (luaFile/nil, 全域函式名) → 無；回呼 ItemDurabilityChangedEventCallback(itemIndex, oldDurability, newDurability, value, mode) → 新 mode（mode 1、2 時回 0 可取消提示） | [已確認] 道具耐久變化時觸發 | lua/libs/GlobalEvents.lua:309（回呼參數註解）；上游 docs/NL.lua:1365 | 道具 |
| `NL.RegItemExpansionEvent` | (luaFile/nil, 全域函式名) → 無；回呼 ItemExpansionCallBack(itemIndex, type, msg, charIndex, slot) → string 說明 | [已確認] 組裝道具說明文字時觸發，可改說明 | lua/libs/GlobalEvents.lua:128（回呼參數註解）；上游 docs/NL.lua:1210 | 道具 |
| `NL.RegItemInitEvent` | (luaFile/nil, 全域函式名) → 無；回呼 ItemInitCallBack(CharIndex, ItemIndex) → 無 | [推測] 每個道具初始化時觸發（登入、新增道具、開銀行、開公會倉庫）；負載重請慎用 | 上游 docs/NL.lua:521 | 道具 |
| `NL.RegItemOverLapEvent` | (luaFile/nil, 全域函式名) → 無；回呼 ItemOverLapEventCallBack(CharIndex, FromItemIndex, TargetItemIndex, Num) → 1 或 <0 攔截；0 正常 | [已確認] 在道具欄把道具拖到另一個道具上時觸發；回 1 或 <0 攔截 | lua/libs/GlobalEvents.lua:225（回呼參數註解）；上游 docs/NL.lua:426 | 道具 |
| `NL.RegItemPickUpEvent` | (luaFile/nil, 全域函式名) → 無；回呼 ItemPickUpCallBack(CharIndex, ItemIndex) → <0 攔截（依上游文件） | [已確認] 玩家成功拾取道具後觸發 | lua/libs/GlobalEvents.lua:173（回呼參數註解）；上游 docs/NL.lua:585 | 道具 |
| `NL.RegItemString` | (luaFile/nil, 全域函式名, itemset 字串) → 無；回呼 ItemStringInitCallBack(CharIndex, ItemIndex) → 依字串種類而異 | [已確認] 註冊 itemset.txt 的自訂道具效果字串（LUA_init/use/att/det/drop/prepick/pick），道具觸發時呼叫指定函式 | lua/Module/xd.lua:1；上游 docs/NL.lua:467 | 道具 |
| `NL.RegItemUseEvent` | (luaFile/nil, 全域函式名) → 無；回呼 ItemUseCallBack(CharIndex, TargetCharIndex, ItemSlot) → <0 取消 | [已確認] 玩家使用道具（含戰鬥中）時觸發；<0 取消使用 | lua/libs/GlobalEvents.lua:185（回呼參數註解）；上游 docs/NL.lua:533 | 道具 |
| `NL.RegJudgeItemEvent` | (luaFile/nil, 全域函式名) → 無；回呼 JudgeItemEventCallback(charIndex, skillid, skilllv, itemindex, prob, flg) → 1 成功／0 失敗 | [推測] 玩家鑑定道具時觸發，可改成敗 | 上游 docs/NL.lua:1606 | 製造 |
| `NL.RegLevelUpEvent` | (luaFile/nil, 全域函式名) → 無；回呼 LevelUpCallBack(CharIndex, PetIndex, UpLevel) → 回 0 即可 | [推測] 玩家角色升級後觸發 | 上游 docs/NL.lua:118 | 其他 |
| `NL.RegLoginEvent` | (luaFile/nil, 全域函式名) → 無；回呼 LoginEventCallBack(CharIndex) → 回 0 即可 | [已確認] 玩家登入遊戲時觸發 | lua/Modules/welcome.lua:27；lua/libs/GlobalEvents.lua:205（回呼參數註解）；上游 docs/NL.lua:66 | 存檔掛機 |
| `NL.RegLoginGateEvent` | (luaFile/nil, 全域函式名) → 無；回呼 LoginGateEventCallBack(CharIndex) → 回 0 即可 | [已確認] 玩家按「登出回記錄點」時觸發 | lua/libs/GlobalEvents.lua:197（回呼參數註解）；上游 docs/NL.lua:78 | 存檔掛機 |
| `NL.RegLogoutEvent` | (luaFile/nil, 全域函式名) → 無；回呼 LogoutEventCallBack(CharIndex) → 回 0 即可 | [已確認] 玩家登出時觸發 | lua/Modules/loginGate.lua:114；lua/libs/GlobalEvents.lua:201（回呼參數註解）；上游 docs/NL.lua:90 | 存檔掛機 |
| `NL.RegMergeItemEvent` | (luaFile/nil, 全域函式名) → 無；回呼 MergeItemEventCallBack(CharIndex, SkillID, SkillLv, ItemIndex, jewelNo) → 無 | [推測] 玩家用生產技能做出道具時觸發（ItemIndex=-1 表示失敗） | 上游 docs/NL.lua:411 | 製造 |
| `NL.RegPartyEvent` | (luaFile/nil, 全域函式名) → 無；回呼 PartyEventCallBack(CharIndex, TargetCharIndex, Type) → 1 允許／0 禁止 | [已確認] 組隊／離隊時觸發（Type 0=加入、1=離開）；回 0 禁止該操作 | lua/libs/GlobalEvents.lua:229（回呼參數註解）；上游 docs/NL.lua:329 | 隊伍 |
| `NL.RegPetDropEvent` | (luaFile/nil, 全域函式名) → 無；回呼 PetDropCallBack(CharIndex, PetPos) → <0 攔截 | [推測] 玩家丟出寵物時觸發；<0 攔截 | 上游 docs/NL.lua:612 | 寵物 |
| `NL.RegPetFieldEvent` | (luaFile/nil, 全域函式名) → 無；回呼 PetFieldCallBack(CharIndex, PetIndex, PetPos) → <0 攔截 | [推測] 玩家展示／休息寵物時觸發；<0 攔截 | 上游 docs/NL.lua:598 | 寵物 |
| `NL.RegPetLevelUpEvent` | (luaFile/nil, 全域函式名) → 無；回呼 PetLevelUpCallBack(CharIndex, PetIndex, UpLevel) → 回 0 即可 | [已確認] 寵物升級後觸發 | lua/Module/nofix/petlvup.lua:5；上游 docs/NL.lua:265 | 寵物 |
| `NL.RegPetPickUpEvent` | (luaFile/nil, 全域函式名) → 無；回呼 PetPickUpCallBack(CharIndex, PetIndex) → <0 攔截 | [推測] 玩家撿起寵物時觸發；<0 攔截 | 上游 docs/NL.lua:625 | 寵物 |
| `NL.RegPetTimeDeleteEvent` | (luaFile/nil, 全域函式名) → 無；回呼 PetTimeDeleteCallBack(PetIndex) → <=0 照常刪；>0 延長秒數 | [推測] 地上的寵物被系統刪除前觸發，可回秒數延長刪除時間 | 上游 docs/NL.lua:705 | 寵物 |
| `NL.RegPreItemDropEvent` | (luaFile/nil, 全域函式名) → 無；回呼 PreItemDropCallBack(CharIndex, ItemIndex) → <0 攔截 | [已確認] 玩家丟棄道具「之前」觸發；<0 攔截 | lua/libs/GlobalEvents.lua:189（回呼參數註解）；上游 docs/NL.lua:1414 | 道具 |
| `NL.RegPreItemPickUpEvent` | (luaFile/nil, 全域函式名) → 無；回呼 PreItemPickUpCallBack(CharIndex, ItemIndex) → <0 攔截 | [已確認] 玩家拾取道具「之前」觸發；<0 攔截 | lua/libs/GlobalEvents.lua:193（回呼參數註解）；上游 docs/NL.lua:1427 | 道具 |
| `NL.RegProductSkillExpEvent` | (luaFile/nil, 全域函式名) → 無；回呼 GetProductSkillExpEventCallBack(CharIndex, SkillID, Exp) → 新經驗值 | [已確認] 取得生產技能經驗時觸發，可改經驗值（製造／採集練技能） | lua/libs/GlobalEvents.lua:245（回呼參數註解）；上游 docs/NL.lua:251 | 製造 |
| `NL.RegRankUpEvent` | (luaFile/nil, 全域函式名) → 無；回呼 RankUpCallBack(CharIndex, OldRank, NewRank) → >=0 允許／<0 拒絕 | [推測] 玩家職業晉級時觸發；<0 拒絕 | 上游 docs/NL.lua:691 | 技能 |
| `NL.RegRepairItemEvent` | (luaFile/nil, 全域函式名) → 無；回呼 RepairItemEventCallback(charIndex, skillid, skilllv, itemindex, prob, flg) → 1 成功／0 失敗 | [推測] 玩家修理道具時觸發，可改成敗 | 上游 docs/NL.lua:1623 | 製造 |
| `NL.RegResetCharaBattleStateEvent` | (luaFile/nil, 全域函式名) → 無；回呼 ResetCharaBattleStateCallBack(charIndex) → 無 | [已確認] 戰鬥結算畫面出現時觸發（自動戰鬥模組用來清狀態） | lua/Modules/autobattle.lua:675；上游 docs/NL.lua:893 | 戰鬥 |
| `NL.RegRightClickEvent` | (luaFile/nil, 全域函式名) → 無；回呼 RightClickCallBack(CharIndex, TargetCharIndex) → 1 攔截 | [已確認] 玩家右鍵點其他玩家時觸發；回 1 攔截 | lua/Module/RightChar.lua:4；上游 docs/NL.lua:305 | 其他 |
| `NL.RegScriptCallEvent` | (luaFile/nil, 全域函式名) → 無；回呼 ScriptCallCallBack(npcIndex, playerIndex, text, msg) → 新值（回給 data） | [已確認] luac（NPC 腳本呼叫）觸發，可回新字串給 data | lua/libs/GlobalEvents.lua:213（回呼參數註解）；上游 docs/NL.lua:939 | NPC事件 |
| `NL.RegSealEvent` | (luaFile/nil, 全域函式名) → 無；回呼 SealEventCallBack(CharIndex, EnemyIndex, Ret) → 可直接回 Ret，或回正／負數改結果 | [推測] 封印（抓寵）判定後觸發，帶判定結果 Ret（負=失敗原因碼 -1~-11、-100=機率不足；正=成功），可改寫結果 | 上游 docs/NL.lua:343 | 封印 |
| `NL.RegShutDownEvent` | (luaFile/nil, 全域函式名) → 無；回呼 ShutDownCallBack() → 回 0 即可 | [推測] 伺服器關閉時觸發 | 上游 docs/NL.lua:318 | 存檔掛機 |
| `NL.RegStatusCalcEvent` | (luaFile/nil, 全域函式名) → 無；回呼 StatusCalcCallBack(charIndex) → 無 | [推測] 角色計算屬性時觸發 | 上游 docs/NL.lua:837 | 其他 |
| `NL.RegStealItemEmitRateEvent` | (luaFile/nil, 全域函式名) → 無；回呼 StealItemEmitRateEventCallback(battleIndex, enemyIndex, charaIndex, itemId, rate) → 新機率 | [已確認] 偷竊物品出現機率事件，可改機率 | lua/libs/GlobalEvents.lua:289（回呼參數註解）；上游 docs/NL.lua:1513 | 戰鬥 |
| `NL.RegTalkEvent` | (luaFile/nil, 全域函式名) → 無；回呼 TalkEventCallBack(CharIndex, Msg, Color, Range, Size) → 0 攔截／1 放行 | [已確認] 玩家說話時觸發，可拿來做 GM／自訂指令；回 0 攔截、1 放行 | lua/Modules/admin.lua:58；lua/libs/GlobalEvents.lua:94（回呼參數註解）；上游 docs/NL.lua:102 | 訊息 |
| `NL.RegTechOptionEvent` | (luaFile/nil, 全域函式名) → 無；回呼 TechOptionCallBack(CharIndex, Option, TechID, Val) → 新值 | [已確認] 技能附加參數取得時觸發，可改數值 | lua/libs/GlobalEvents.lua:160（回呼參數註解）；上游 docs/NL.lua:663 | 技能 |
| `NL.RegTitleChangedEvent` | (luaFile/nil, 全域函式名) → 無；回呼 TitleChangedCallBack(CharIndex, Ori_Title, New_Title) → <0 攔截 | [已確認] 玩家換稱號時觸發；回負數攔截 | lua/Module/title.lua:1；上游 docs/NL.lua:210 | 其他 |
| `NL.RegTitleCheckCallEvent` | (luaFile/nil, 全域函式名) → 無；回呼 TitleCheckCallCallBack(charIndex, Data, Flg) → 1 條件成立／0 不成立 | [推測] 稱號條件檢查事件（titleconfig.txt 以 LUA 為條件關鍵字），用 Lua 自訂稱號 | 上游 docs/NL.lua:1226 | 其他 |
| `NL.RegTribeRateEvent` | (luaFile/nil, 全域函式名) → 無；回呼 TribeRateCallback(a, b, rate) → 新克制比率 | [推測] 種族克制傷害比率事件，可改克制比率 | 上游 docs/NL.lua:1126 | 戰鬥 |
| `NL.RegVSEnemyCreateEvent` | (luaFile/nil, 全域函式名) → 無；回呼 VSEnemyCreateEventCallback(CharIndex, GroupId, EnemyNum, EnemyList) → 新敵人 table；無修改回 EnemyList 或非 table | [推測] 玩家遇敵（產生敵方隊列）時觸發，可改敵人隊列與數量 | 上游 docs/NL.lua:1255 | 戰鬥 |
| `NL.RegWarpEvent` | (luaFile/nil, 全域函式名) → 無；回呼 WarpEventCallBack(CharIndex, Ori_MapId, Ori_FloorId, Ori_X, Ori_Y, Target_MapId, Target_FloorId, Target_X, Target_Y) → table 或 nil | [推測] 玩家通過傳送點前觸發；可回 {mapId,floor,x,y} 改寫目的地，回 nil 不改 | 上游 docs/NL.lua:156 | 移動 |
| `NL.RemoveCallback` | (eventName:string) → 無 | [已確認] 底層：移除某事件的回呼；NL.RegXxx(file, nil) 時呼叫。 | exe_strings.txt:197264 | 其他 |
| `NL.SetArgNpc` | (npcIndex, newArg:string) → 0 成功；負數=失敗 | [推測] 修改 CreateArgNpc 建立的 NPC 的參數字串（NPC 自動刷新；有人正在對話時修改可能出 bug，建議先隱藏）。 | 上游 docs/NL.lua:60 | NPC事件 |
| `NL.Ver` | () → string（上游：cgmsv） | [推測] 取得引擎名稱字串（與 Version 不同：回字串）。 | 上游 docs/NL.lua:1458 | 查詢 |
| `NL.Version` | () → number（例：20230511；上游寫「引擎版本」） | [已確認] 取得引擎版本數字；init.lua 以 <20230511 判不相容。 | lua/init.lua:3；上游 docs/NL.lua:5 | 查詢 |
| `NL.newEvent` | (event:string, defaultRet) → 無 | [已確認] 內嵌 Lua：為 NL 動態產生 NL.Reg<event>(luaFile, callback) 包裝（可選 pcall dofile，再呼叫 RegCallback／RemoveCallback）。這就是 dump 中 105 個 Reg*Event 帶 @[string "function NL.newEvent..."] 的來源。 | exe_strings.txt:197251 | 其他 |

## Obj（31 個函式；已確認 0／推測 31／未驗證 0）

| 函式 | 參數 → 回傳 | 用途（繁體中文） | 依據 | 標籤 |
|---|---|---|---|---|
| `Obj.AddGold` | (mapType, floor, x, y, gold) → ObjectIndex | [推測] 在地圖座標放金幣（地上掉錢）。 | 上游 docs/Obj.lua:179；本機 lua/ 全樹無呼叫 | 地圖 |
| `Obj.AddItem` | (mapType, floor, x, y, itemIndex) → ObjectIndex | [推測] 在地圖座標放物品（itemIndex 為 Item.MakeItem 的回傳）；可佈置地上掉落物。 | 上游 docs/Obj.lua:188；本機 lua/ 全樹無呼叫 | 道具 |
| `Obj.AddWarp` | (mapType, floor, x, y, toMapType, toFloor, toX, toY) → ObjectIndex | [推測] 在地圖座標動態新增傳送點，不需改 warp 設定檔。 | 上游 docs/Obj.lua:170；本機 lua/ 全樹無呼叫 | 移動 |
| `Obj.GetCharIndex` | (objectIndex) → charIndex | [推測] 由 Object 索引取得對應的人物／寵物／物品 index。 | 上游 docs/Obj.lua:14；本機 lua/ 全樹無呼叫 | 查詢 |
| `Obj.GetDelTime` | (objectIndex) → timestamp | [推測] 取得 Object 的開始時間（寵物開始丟在地上的時間，用於計算消失）。 | 上游 docs/Obj.lua:74；本機 lua/ 全樹無呼叫 | 查詢 |
| `Obj.GetFloor` | (objectIndex) → floorId | [推測] 取得 Object 所在 Floor ID。 | 上游 docs/Obj.lua:34；本機 lua/ 全樹無呼叫 | 查詢 |
| `Obj.GetMap` | (objectIndex) → mapId | [推測] 取得 Object 所在 Map ID（與 GetMapId 說明相同）。 | 上游 docs/Obj.lua:39；本機 lua/ 全樹無呼叫 | 查詢 |
| `Obj.GetMapId` | (objectIndex) → mapId | [推測] 取得 Object 所在 Map ID。 | 上游 docs/Obj.lua:44；本機 lua/ 全樹無呼叫 | 查詢 |
| `Obj.GetObject` | (mapId, floorId, x, y) → 數量, table（該座標所有 objectIndex） | [推測] 列出指定座標上的 Object 列表（地上物品／金幣／傳送點等，可用來掃地上掉落物；是否涵蓋採集點未驗證）。 | 上游 docs/Obj.lua:9；本機 lua/ 全樹無呼叫 | 查詢 |
| `Obj.GetType` | (objectIndex) → -1 非法／0 未使用／1 角色／2 道具／3 金幣／4 傳送點／5 船／6 載具 | [推測] 取得 Object 類型。 | 上游 docs/Obj.lua:19；本機 lua/ 全樹無呼叫 | 查詢 |
| `Obj.GetWarpFloor` | (objectIndex) → floorId | [推測] 取得傳送點 Object 的目的 Floor。 | 上游 docs/Obj.lua:59；本機 lua/ 全樹無呼叫 | 查詢 |
| `Obj.GetWarpMap` | (objectIndex) → mapId | [推測] 取得傳送點 Object 的目的 Map（與 GetWarpMapId 同註解）。 | 上游 docs/Obj.lua:64；本機 lua/ 全樹無呼叫 | 查詢 |
| `Obj.GetWarpMapId` | (objectIndex) → mapId | [推測] 取得傳送點 Object 的目的 Map。 | 上游 docs/Obj.lua:69；本機 lua/ 全樹無呼叫 | 查詢 |
| `Obj.GetWarpX` | (objectIndex) → x | [推測] 取得傳送點 Object 的目的 X。 | 上游 docs/Obj.lua:49；本機 lua/ 全樹無呼叫 | 查詢 |
| `Obj.GetWarpY` | (objectIndex) → y | [推測] 取得傳送點 Object 的目的 Y。 | 上游 docs/Obj.lua:54；本機 lua/ 全樹無呼叫 | 查詢 |
| `Obj.GetX` | (objectIndex) → x | [推測] 取得 Object 的 X 座標。 | 上游 docs/Obj.lua:24；本機 lua/ 全樹無呼叫 | 查詢 |
| `Obj.GetY` | (objectIndex) → y | [推測] 取得 Object 的 Y 座標。 | 上游 docs/Obj.lua:29；本機 lua/ 全樹無呼叫 | 查詢 |
| `Obj.RemoveObject` | (objectIndex) → 0 成功 | [推測] 移除指定 Object（例如清掉地上物品或自建傳送點）。 | 上游 docs/Obj.lua:158；本機 lua/ 全樹無呼叫 | 地圖 |
| `Obj.SetDelTime` | (objectIndex, timestamp) → 設定前的時間 | [推測] 設定 Object 開始時間（地上寵物消失計時起點）。 | 上游 docs/Obj.lua:153；本機 lua/ 全樹無呼叫 | 寵物 |
| `Obj.SetFloor` | (objectIndex, floorId) → 設定前的值 | [推測] 修改 Object 的 Floor（改完用 UpObject 更新）。 | 上游 docs/Obj.lua:105；本機 lua/ 全樹無呼叫 | 地圖 |
| `Obj.SetMap` | (objectIndex, mapId) → 設定前的值 | [推測] 修改 Object 的 Map ID（與 SetMapId 同註解）。 | 上游 docs/Obj.lua:111；本機 lua/ 全樹無呼叫 | 地圖 |
| `Obj.SetMapId` | (objectIndex, mapId) → 設定前的值 | [推測] 修改 Object 的 Map ID。 | 上游 docs/Obj.lua:117；本機 lua/ 全樹無呼叫 | 地圖 |
| `Obj.SetType` | (objectIndex, 0~6) → 設定前的類型 | [推測] 修改 Object 類型（0 未使用、1 角色、2 道具、3 金幣、4 傳送點、5 船、6 載具）。 | 上游 docs/Obj.lua:87；本機 lua/ 全樹無呼叫 | 地圖 |
| `Obj.SetWarpFloor` | (objectIndex, floorId) → 設定前的值 | [推測] 修改傳送點目的 Floor。 | 上游 docs/Obj.lua:135；本機 lua/ 全樹無呼叫 | 移動 |
| `Obj.SetWarpMap` | (objectIndex, mapId) → 設定前的值 | [推測] 修改傳送點目的 Map（與 SetWarpMapId 同註解）。 | 上游 docs/Obj.lua:141；本機 lua/ 全樹無呼叫 | 移動 |
| `Obj.SetWarpMapId` | (objectIndex, mapId) → 設定前的值 | [推測] 修改傳送點目的 Map。 | 上游 docs/Obj.lua:147；本機 lua/ 全樹無呼叫 | 移動 |
| `Obj.SetWarpX` | (objectIndex, x) → 設定前的值 | [推測] 修改傳送點目的 X。 | 上游 docs/Obj.lua:123；本機 lua/ 全樹無呼叫 | 移動 |
| `Obj.SetWarpY` | (objectIndex, y) → 設定前的值 | [推測] 修改傳送點目的 Y。 | 上游 docs/Obj.lua:129；本機 lua/ 全樹無呼叫 | 移動 |
| `Obj.SetX` | (objectIndex, x) → 設定前的 x | [推測] 修改 Object 的 X 座標。 | 上游 docs/Obj.lua:93；本機 lua/ 全樹無呼叫 | 地圖 |
| `Obj.SetY` | (objectIndex, y) → 設定前的 y | [推測] 修改 Object 的 Y 座標。 | 上游 docs/Obj.lua:99；本機 lua/ 全樹無呼叫 | 地圖 |
| `Obj.UpObject` | (objIndex) → 無 | [推測] 更新 Object 資訊（修改座標／類型後通知客戶端）。 | 上游 docs/Obj.lua:192；本機 lua/ 全樹無呼叫 | 地圖 |

## Map（19 個函式；已確認 14／推測 5／未驗證 0）

| 函式 | 參數 → 回傳 | 用途（繁體中文） | 依據 | 標籤 |
|---|---|---|---|---|
| `Map.DelLuaMap` | (floor) → 0 成功／-1 失敗（上游文件） | [已確認] 刪除 Lua 生成的地圖並釋放地圖編號。本機舊腳本以 ret==0 判失敗（與上游相反，待實測）。 | lua/Module/nofix/mapProc.lua:135；上游 docs/Map.lua:82 | 地圖 |
| `Map.FindDungeonEntry` | (dungeonId) → mapType, floor, x, y | [已確認] 由迷宮 ID 找迷宮入口座標。 | lua/Modules/loginGate.lua:52（解 mapID,floorID,x,y；mapID>=0 and floorID>0 判有效）；上游 docs/Map.lua:14 | 地圖 |
| `Map.GetAvailablePos` | (mapType, floor) → x, y；失敗 x、y 皆 -1 | [已確認] 取得隨機地圖（Lua 地圖）上一個可走的座標；用來把角色傳進新生成的地圖。本機舊腳本只傳 floorID 一個參數且以 0,0 判失敗，簽名與上游不同，26.8d 待實測。 | 上游 docs/Map.lua:165；lua/Module/nofix/mapProc.lua:80 | 地圖 |
| `Map.GetDungeonExpireAt` | (floor) → 到期 unix 時間；失敗 -1 | [已確認] Lua 包裝：先 GetDungeonId(floor)，再呼叫 …ByDungeonId。 | exe_strings.txt:197300（內嵌 Lua 原始碼）；lua/Modules/loginGate.lua:49 | 地圖 |
| `Map.GetDungeonExpireAtByDungeonId` | (dungeonId) → 到期 unix 時間；<0 失敗 | [已確認] 取得迷宮到期（重置）時間，C 函式。 | 上游 docs/Map.lua:19；exe_strings.txt:197272（被內嵌 Lua 呼叫） | 地圖 |
| `Map.GetDungeonExpireTime` | (floor) → 剩餘秒數（<=0 回 0；失敗回負） | [已確認] Lua 包裝：到期時間減 os.time()。 | exe_strings.txt:197282 | 地圖 |
| `Map.GetDungeonExpireTimeByDungeonId` | (dungeonId) → 剩餘秒數 | [已確認] Lua 包裝：到期時間減 os.time()。 | exe_strings.txt:197271 | 地圖 |
| `Map.GetDungeonId` | (floor) → dungeonId；<0 失敗 | [已確認] 由 floor 取得迷宮 ID。 | lua/Modules/loginGate.lua:50、:94；exe_strings.txt:197294 | 地圖 |
| `Map.GetExtData` | (mapId, floor, field:string) → number/string/nil | [推測] 讀取掛在地圖上的自訂資料。 | 上游 docs/Map.lua:189 | 地圖 |
| `Map.GetImage` | (mapType, floor, x, y) → tileId（地板圖檔）, objId（建築物圖檔） | [已確認] 讀取座標的地板與物件圖檔編號（可用來辨識地圖上的固定物件，如採集點圖檔，推測）。 | lua/Module/nofix/mapProc.lua:97；上游 docs/Map.lua:54 | 地圖 |
| `Map.GetMapSize` | (mapType, floor) → 長, 寬 | [推測] 取得地圖大小。 | 上游 docs/Map.lua:71 | 地圖 |
| `Map.IsWalkable` | (mapType, floor, x, y) → 1 可通行／0 不可 | [推測] 查地圖座標是否可通行（與 NLG.Walkable 功能重疊，推測同義）。 | 上游 docs/Map.lua:182 | 地圖 |
| `Map.MakeCopyMap` | (mapId, floor) → 新 floorID；失敗 -1 | [已確認] 複製一張地圖成 Lua 地圖（mapId 為 CONST.地圖類型_LUAMAP），可做「每人／每隊一份」的獨立練功圖。 | lua/Module/nofix/mapProc.lua:38；上游 docs/Map.lua:77 | 地圖 |
| `Map.MakeMazeMap` | (doFile, initFuncName, xSize, ySize, mapName[, 更多版面參數…]) → 新 floorID；失敗 -1 | [已確認] 建立隨機迷宮地圖（非同步，完成後呼叫回呼 f(floorID, doneFlg)，doneFlg 1 成功）；另有以 dungeonId 建立的多載。 | lua/Module/nofix/mapProc.lua:55（回呼 :68 mazeMapDoneCall）；上游 docs/Map.lua:92 | 地圖 |
| `Map.SetDungeonExpireAt` | (floor, time) → 同 ByDungeonId；找不到 dungeon 回 -1 | [已確認] Lua 包裝：GetDungeonId 後呼叫 SetDungeonExpireAtByDungeonId。 | exe_strings.txt:197293 | 地圖 |
| `Map.SetDungeonExpireAtByDungeonId` | (dungeonId, unixTime) → 到期時間 | [已確認] 以迷宮 ID 設定迷宮重置時間，C 函式。 | 上游 docs/Map.lua:25；exe_strings.txt:197298（被內嵌 Lua 呼叫） | 地圖 |
| `Map.SetExtData` | (mapId, floor, field:string, val) → 0 成功 | [推測] 在地圖上掛自訂資料。 | 上游 docs/Map.lua:197 | 地圖 |
| `Map.SetImage` | (mapType, floor, x, y[, tile, obj]) → 0 成功 | [已確認] 改寫座標的地板／物件圖檔。本機舊腳本只傳一個 image，引擎自動判斷是地板或物件。 | lua/Module/nofix/mapProc.lua:111；上游 docs/Map.lua:64 | 地圖 |
| `Map.SetWalkable` | (mapType, floor, x, y, able) → number | [推測] 設定座標是否可通行。 | 上游 docs/Map.lua:174 | 地圖 |

## Field（2 個函式；已確認 0／推測 2／未驗證 0）

| 函式 | 參數 → 回傳 | 用途（繁體中文） | 依據 | 標籤 |
|---|---|---|---|---|
| `Field.Get` | (charIndex, fieldName:string) → string | [推測] 讀取掛在角色上的指定資料欄（自訂欄位）。本機舊腳本僅有被註解掉的呼叫；同類持久化另見 Char.GetExtData（lua/Modules/loginGate.lua:43）。 | 上游 docs/Field.lua:7；lua/Module/routine_too.lua:240（已註解） | 存檔掛機 |
| `Field.Set` | (charIndex, fieldName:string, value:string) → number（上游文件未說明） | [推測] 設定角色上的指定資料欄。 | 上游 docs/Field.lua:14；lua/Module/routine_too.lua:283（已註解） | 存檔掛機 |
