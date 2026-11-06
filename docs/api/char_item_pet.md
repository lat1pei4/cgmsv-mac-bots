# cgmsv 26.8d Lua API：Char／Item／Pet

產生日期 2026-11-06。清單來源為執行期匯出 `apidump.txt`（Char 126、Item 28、Pet 12，共 166 個函式；Item 區段另有 1 個非函式項目，不列入）。

## 資料來源與路徑縮寫
- `lua参考/X.lua:行` ＝ `~/Desktop/Personal/crossgate/server-b/lua参考/{Char,Item,Pet}.lua` 的 EmmyLua 註解（GBK，第三方文件）。這是參數／回傳說明的主要出處，但它是通用 cgmsv 文件，不保證與 26.8d 實際行為完全一致。
- `gmsv/lua/...:行` ＝ `~/Desktop/Personal/crossgate/server-b/gmsv/lua/` 下的實際 Lua（GBK，行號與原檔一致）。
- `modules-src/merc.utf8.lua:行` 等 ＝ `~/Desktop/Personal/crossgate/server-b/modules-src/`（第三方 AI 佣兵 mod 與自家 probe）。
- `定義 gmsv/lua/libs/Gmsv/XxxEx.lua:行` ＝ Lua 包裝函式本身的定義位置，原始碼已讀。
- 「已知事實(實測)」＝任務簡報中已實測的事實。
- 回傳值中的 -2／-3／-4 多為「參數型別錯／對象 index 無效／位置超出範圍」，出自 lua参考 文件。

## 狀態判準
- **已確認**：有 lua参考 說明，且在實際 Lua 找得到用例／或已知事實／或是 Lua 包裝（原始碼已讀）。
- **推測**：只有 lua参考 文件，沒有任何用例（說明「用途」欄開頭標「推測：」）。
- **未驗證**：連文件都沒有，僅知名稱。

## 對生態系的重點速查
- 假人（無頭角色）生命週期：`Char.CreateDummy()` → `Char.SetData` 設位置／名字／圖／職業 → `Char.GiveItem`＋`Char.MoveItem(c, 背包slot, CONST.EQUIP_左手, -1)` 裝備 → `Char.AddSkill` → `Char.GivePet`＋`Char.SetPetDepartureState` → `Char.JoinParty(假人, 隊長, true)`；收回用 `Char.DelDummy`（見 `gmsv/lua/Modules/adminCommands.lua:88-114`、`modules-src/merc.utf8.lua:683-795`）。
- `Char.IsDummy` 用於區分假人與真人（`modules-src/merc.utf8.lua:93`）。
- 事件回呼簽名見各事件函式列；`Dofile` 傳 `nil` 表示用目前檔案，FuncName 為全域函式名字串。
- 4 頁背包：`Char.GetBagPage`／`Char.SwitchBag`／`Char.ItemMoveBag`（`gmsv/lua/Modules/bagSwitch.lua:113-211`）。

## Char（126 個）

| 函式 | 參數 → 回傳 | 用途（繁體中文） | 依據 | 標籤 |
|---|---|---|---|---|
| Char.AddCrystal | (charIndex:number, amount:number(增加的數量，負數為減少。)) → number | 推測：為目標增加水晶貨幣。（僅第三方文件，無用例） | lua参考/Char.lua:116 | 交易 |
| Char.AddGold | (charIndex:number, amount:number(增加的數量，負數為減少。)) → number | 增加金錢（amount 負數＝扣款），stub 未說明回傳。用例：扣 200G 開打卡、佣兵購買扣款。 | lua参考/Char.lua:110; 例 gmsv/lua/Modules/adminCommands.lua:8; 例 modules-src/merc.utf8.lua:243 | 交易 |
| Char.AddPet | (CharIndex:number, PetID:number(寵物的ID)) → number 製作成功則返回目標寵物的物件index，否則返回-1，引數資料型別不對返回-2，物件index無效返回-3。 | 為物件增加一隻等級為1成長隨機的PetID的寵物。 | lua参考/Char.lua:161; 例 gmsv/lua/Module/nofix/GMSyumi.lua:213 | 寵物 |
| Char.AddSkill | (CharIndex:number, SkillID:number(技能的ID，對應Skill.txt的id。), SkillExp?:number(技能的初始經驗值，如果不寫則為0。), ShowMsg?:number(是否顯示系統資訊。)) → number 如果成功則返回增加的技能欄的位置，範圍0-14，如果失敗則返回-1，引數資料型別不對返回-2，物件index無效返回-3，技能的ID錯誤返回-4。 | 學會技能：(c, skillId, 初始經驗=0, ShowMsg)，成功回技能欄位 0~14，失敗 -1／-4（技能 ID 錯）。 | lua参考/Char.lua:247; 例 gmsv/lua/Modules/abtest.lua:93; 例 gmsv/lua/Modules/adminCommands.lua:107; 已知事實(實測) | 技能 |
| Char.Ban | (charIndex:CharIndex) → 無回傳說明 | 推測：封號（stub 僅「封号」）。危險，勿對生態系角色呼叫。 | lua参考/Char.lua:795 | 存檔掛機 |
| Char.CalcConsumeFp | (charIndex:number, techId:number(tech.txt中的ID)) → number techId釋放需要的魔法值 | 計算施放 techId 所需魔力（Tech.txt ID）。 | lua参考/Char.lua:629; 例 gmsv/lua/Modules/adminCommands.lua:172; 例 gmsv/lua/Modules/autobattle.lua:100; 已知事實(實測) | 技能／戰鬥 |
| Char.CheckTitle | (CharIndex:number) → number 重新整理玩家稱號，返回-1失敗，引數資料型別不對返回-2，物件index無效返回-3。 | 推測：重新整理玩家的稱號，如阿蒙。（僅第三方文件，無用例） | lua参考/Char.lua:517 | 查詢 |
| Char.CreateDummy | (opt?:DummyCreateOptions(@)) → number 假人index | 建立假人（無客戶端的角色）並回傳其 charIndex；可傳 opt 表 {mapType,floor,x,y,image,name}，實測用例都是無參數呼叫後用 SetData 補位置／名字／圖檔。 | lua参考/Char.lua:717; 例 gmsv/lua/Modules/abtest.lua:75; 例 gmsv/lua/Modules/adminCommands.lua:88; 已知事實(實測) | 存檔掛機 |
| Char.DelDummy | (charIndex:number) → number 成功返回0 | 刪除假人（成功回 0）。用完要刪，否則殘留。 | lua参考/Char.lua:732; 例 gmsv/lua/Modules/abtest.lua:233; 例 gmsv/lua/Modules/adminCommands.lua:150 | 存檔掛機 |
| Char.DelItem | (CharIndex:number, ItemID:number(道具ID。), Amount:number(道具的數量。), ShowMsg?:boolean(是否顯示系統資訊)) → number 成功返回1，失敗則返回0。 | 刪除目標物件道具。 | lua参考/Char.lua:124; 例 gmsv/lua/Modules/adminCommands.lua:24; 例 modules-src/merc.utf8.lua:256 | 道具 |
| Char.DelItemBySlot | (charIndex:number, slot:number(道具欄位置)) → number 成功返回0 | 根據位置刪除物品 | lua参考/Char.lua:594; 例 gmsv/lua/Modules/adminCommands.lua:28 | 道具 |
| Char.DelPet | (CharIndex:number, PetID:number(寵物的ID), Level:number(寵物的等級。), LevelSetting:number(0為刪除一隻小於等於Level的寵物，1為刪除一隻等於Level的寵物，)) → number 製作刪除返回0，否則返回-1，引數資料型別不對返回-2，物件index無效返回-3。 | 刪除物件身上滿足條件的寵物。 | lua参考/Char.lua:182; 例 gmsv/lua/Module/nofix/EasyGM.lua:537 | 寵物 |
| Char.DelSkill | (CharIndex:number, SkillID:number(技能的ID，對應Skill.txt的id。), ShowMsg?:number(是否顯示系統資訊。)) → number 如果成功刪除技能則返回該技能原本的技能欄的位置，範圍0-14，如果失敗則返回-1。 /  / 如果玩家沒有該技能，也返回-1。 /  / 引數資料型別不對返回-2，物件index無效返回-3，技能的ID錯誤返回-4。 | 推測：刪除目標玩家的指定技能。（僅第三方文件，無用例） | lua参考/Char.lua:254 | 技能 |
| Char.DelSlotPet | (CharIndex:number, Slot:number(寵物的位置，範圍0-4。)) → number 成功刪除返回1，失敗返回0，寵物位置超出範圍(0-4)返回-1，引數資料型別不對返回-2，物件index無效返回-3。 | 刪除目標指定欄位的寵物。 | lua参考/Char.lua:188; 例 gmsv/lua/Module/routine_too.lua:395; 例 gmsv/lua/Module/nofix/routine_too.lua:395 | 寵物 |
| Char.DischargeParty | (CharIndex:number(目標物件index。)) → number 返回1代表成功，返回0失敗，引數資料型別不對返回-2，物件index無效返回-3。 | 解散該玩家的隊伍，回 1 成功。 | lua参考/Char.lua:224; 例 modules-src/merc.utf8.lua:346; 例 gmsv/lua/Module/GoldMap.lua:163 | 隊伍 |
| Char.DropPet | (charIndex:number, slot:number(寵物的位置，範圍0-4。)) → number 成功丟出返回1，失敗返回0，寵物的位置範圍錯誤(0-4)返回-1，引數資料型別不對返回-2，物件index無效返回-3，按位置獲取的寵物錯誤返回-4。 | 推測：丟出目標指定欄位的寵物。（僅第三方文件，無用例） | lua参考/Char.lua:199 | 寵物 |
| Char.EndEvent | (charIndex:number, flag:number(任務旗標。), value:number) → 無回傳說明 ／ (charIndex:number, flag:number(任務旗標。)) → number 返回旗標狀態。 | 讀寫任務旗標 EndEvent（已完成）：(c,flag) 讀，(c,flag,value) 寫。常拿旗標 0 當「首次登入」標記。 | lua参考/Char.lua:32; 例 gmsv/lua/Modules/loginGate.lua:39; 例 gmsv/lua/Module/Welcome.lua:20 | NPC事件 |
| Char.FeverStart | (CharIndex:number) → number 1打卡成功，0打卡失敗，引數資料型別不對返回-2，物件index無效返回-3。 | 開始「打卡」狀態（Fever time，遊戲內計時卡機制；stub 稱 打卡）。回 1 成功、0 失敗。用例：登入後依先前狀態恢復打卡，或扣 200G 後開啟（myLogin／ng）。 | lua参考/Char.lua:360; 例 gmsv/lua/Module/myLogin.lua:172; 例 gmsv/lua/Module/ng.lua:102 | 存檔掛機 |
| Char.FeverStop | (CharIndex:number) → number 1結束打卡成功，0結束打卡失敗，引數資料型別不對返回-2，物件index無效返回-3。 | 結束打卡狀態，回 1 成功。 | lua参考/Char.lua:365; 例 gmsv/lua/Module/ng.lua:110; gmsv/lua/Module/nofix/Item_Lucky.lua:262（該處呼叫的是 Char.FeverTimeStop，不在清單內，疑為舊名） | 存檔掛機 |
| Char.FindItemId | (charIndex:number, itemID:number(道具ID)) → number 如果有則返回第一個結果的道具欄位置，如果沒有則返回-1。 | 回傳第一個該 itemId 的欄位 slot，沒有回 -1。 | lua参考/Char.lua:104; 例 gmsv/lua/Module/nofix/qichong.lua:76; 已知事實(實測) | 道具 |
| Char.GetBagPage | (charIndex:number(物件的index)) → number 當前背包編號 0~3 | 取得目前背包頁編號（0~3）。 | lua参考/Char.lua:762; 例 gmsv/lua/Modules/bagSwitch.lua:113 | 道具 |
| Char.GetBattleIndex | (CharIndex:number) → number 成功返回當前戰鬥index，返回-1代表沒有戰鬥，引數資料型別不對返回-2，物件index無效返回-3。 | 取得目前戰鬥 index，沒在戰鬥回 -1。 | lua参考/Char.lua:321; 例 gmsv/lua/Module/nofix/kickbot.lua:42 | 戰鬥 |
| Char.GetCharPointer | (CharIndex:number) → number 返回-1代表失敗，其他為物件的記憶體地址。 | 推測：獲取指定物件的物件指標，指標為記憶體地址，如果不清楚如何使用請勿使用。（僅第三方文件，無用例） | lua参考/Char.lua:326 | 其他 |
| Char.GetData | (charIndex:number, dataIndex:number(指定的物件例項資訊欄位，具體參考CONST.物件_***)) → number/string 指定資訊欄位的值 | 讀取對象（玩家／NPC／寵物／怪）欄位，欄位用 CONST.對象_*（舊式 %對象_血%）。字串欄位回字串（欄位號 >=2000 為字串，見 adminCommands 判斷）。 | lua参考/Char.lua:7; 例 gmsv/lua/Modules/abtest.lua:116; 例 gmsv/lua/Modules/admin.lua:35; gmsv/lua/Modules/adminCommands.lua:122 | 查詢 |
| Char.GetEmptyItemSlot | 未驗證 | 未驗證 | 定義 gmsv/lua/libs/Gmsv/CharEx.lua:20 | 道具 |
| Char.GetEmptyPetSlot | 未驗證 | 未驗證 | 定義 gmsv/lua/libs/Gmsv/CharEx.lua:44 | 寵物 |
| Char.GetExtData | (charIndex:number, dataIndex:string(資訊儲存的位置，自定義)) → string/number/nil 獲得指定位置的字串 | 讀自訂資料（字串鍵），會存進資料庫（跨登入保存），可存 JSON 字串；nil 表無。是角色自帶永久記憶體的現成管道。 | lua参考/Char.lua:523; 例 gmsv/lua/Modules/loginGate.lua:43; 例 modules-src/merc.utf8.lua:211 | 查詢 |
| Char.GetGold | (charIndex:number) → number 角色身上金幣數量 | 查詢角色身上金幣數量。 | lua参考/Char.lua:607; 例 modules-src/merc.utf8.lua:239 | 交易 |
| Char.GetGuildID | (CharIndex:number) → number 成功返回玩家家族ID，返回-1代表沒有家族，引數資料型別不對返回-2，物件index無效返回-3。 | 推測：獲取指定玩家的家族ID。（僅第三方文件，無用例） | lua参考/Char.lua:311 | 查詢 |
| Char.GetGuildTitle | (charIndex:number) → number 返回-1代表沒有家族，其他為玩家家族中的稱號ID，引數資料型別不對返回-2，物件index無效返回-3。 | 推測：查詢角色家族中的稱號ID（僅第三方文件，無用例） | lua参考/Char.lua:639 | 查詢 |
| Char.GetHouseItem | (CharIndex:number, Slot:number(出租屋中的位置，範圍0-19。)) → number 如果目標有則返回道具物件index，沒有則返回-1，引數資料型別不對返回-2，物件index無效返回-3，道具的位置範圍錯誤返回-4。 | 讀取出租屋（家）指定格 0~19 的道具 index；無回 -1。無用例。 | lua参考/Char.lua:344 | 道具 |
| Char.GetHousePet | (CharIndex:number, Slot:number(出租屋中的位置，範圍0-4。)) → number 如果目標有該寵物的寵物物件index，沒有則返回-1，引數資料型別不對返回-2，物件index無效返回-3，寵物的位置範圍錯誤返回-4。 | 讀取出租屋指定格 0~4 的寵物對象 index；無回 -1。無用例。 | lua参考/Char.lua:332 | 寵物 |
| Char.GetItemIndex | (charIndex:number, slot:number(道具欄位置)) → number 如果目標欄位有道具，則返回道具index，否則返回 -1: 物件指標錯誤 -2: 道具欄無道具 -3: 超出範圍。 | 取得指定欄位的道具 index：背包 slot 8~27，0~7 為裝備欄；無道具回 -2，指標錯 -1，超出範圍 -3。 | lua参考/Char.lua:561; 例 gmsv/lua/Modules/autobattle.lua:231; 例 gmsv/lua/Modules/bagSwitch.lua:161; 已知事實(實測) | 道具 |
| Char.GetItemSlot | 未驗證 | 未驗證 | 定義 gmsv/lua/libs/Gmsv/CharEx.lua:35; 例 gmsv/lua/Modules/adminCommands.lua:19; 例 modules-src/merc.utf8.lua:730 | 道具 |
| Char.GetLevelExp | (Level:number(等級Level。)) → number Level-1到等級Level所需的經驗，傳入的等級引數小於等於0則返回-1，引數資料型別不對返回-2。 | 推測：獲取等級Level-1到等級Level所需的經驗。（僅第三方文件，無用例） | lua参考/Char.lua:229 | 查詢 |
| Char.GetMyRoomFloor | (charIndex:number(物件的index)) → number 成功返回出租房floor，失敗返回-1 | 推測：檢視角色的出租房floor（僅第三方文件，無用例） | lua参考/Char.lua:737 | 查詢 |
| Char.GetNextExp | (CharIndex:number) → number 下一級所需經驗，傳入的等級引數小於等於0則返回-1，引數資料型別不對返回-2，物件index無效返回-3。 | 推測：獲取物件的下一級所需經驗。（僅第三方文件，無用例） | lua参考/Char.lua:239 | 查詢 |
| Char.GetPartyMember | (CharIndex:number, Slot:number(團隊中的位置，取值0-4)) → number 返回指定位置的玩家的物件index，如果沒有玩家則返回-1，獲取失敗返回0，引數資料型別不對返回-2，物件index無效返回-3，如果團隊中的位置超過範圍(0-4)返回-4。 | 取得隊伍中第 slot 位成員的 charIndex（0 為隊長）；無人回 -1，未組隊也回 -1。 | lua参考/Char.lua:219; 例 gmsv/lua/Modules/autobattle.lua:624; 例 modules-src/autobattle.utf8.lua:624; 已知事實(實測) | 隊伍 |
| Char.GetPet | (CharIndex:number, Slot:number(寵物的位置，範圍0-4。)) → number 如果目標有該寵物的寵物物件index，沒有則返回-1，引數資料型別不對返回-2，物件index無效返回-3，位置超出範圍(0-4)返回-4。 | 獲取目標位置的寵物物件index。 | lua参考/Char.lua:174; 例 gmsv/lua/Modules/abtest.lua:114; 例 gmsv/lua/Modules/adminCommands.lua:40 | 寵物 |
| Char.GetPetEnemyId | (charIndex:number, slot:number(寵物欄位置)) → number 寵物enemyId | 推測：獲得寵物enemyId（僅第三方文件，無用例） | lua参考/Char.lua:650 | 寵物 |
| Char.GetPoolItem | (CharIndex:number, Slot:number(銀行中的位置，韓服範圍0-19，臺服範圍0-39，國服範圍0-79。)) → number 如果目標有則返回道具物件index，沒有則返回-1，引數資料型別不對返回-2，物件index無效返回-3，銀行中道具位置範圍錯誤返回-4。 | 讀取銀行（倉庫）指定格的道具 index；格數範圍依版本：韓服 0-19、台服 0-39、國服 0-79。無道具回 -1，範圍錯回 -4。注意 stub 說明文字寫的是「出租屋」（疑複製貼上），參數說明寫「銀行」，此處以參數說明為準；無用例，本服實際格數未驗證。 | lua参考/Char.lua:350 | 道具 |
| Char.GetPoolPet | (CharIndex:number, Slot:number(銀行中的位置，範圍0-4。)) → number 如果目標有該寵物的寵物物件index，沒有則返回-1，引數資料型別不對返回-2，物件index無效返回-3，寵物的位置範圍錯誤返回-4。 | 推測：獲取玩家物件銀行中指定位置的寵物物件index。（僅第三方文件，無用例） | lua参考/Char.lua:338 | 寵物 |
| Char.GetSkillExp | (CharIndex:number, Slot:number(技能位置，可用Char.HaveSkill來獲取位置。)) → number 成功返回技能經驗,失敗返回-1，引數資料型別不對返回-2，物件index無效返回-3，技能的位置錯誤返回-4。 | 讀取技能經驗；slot 是技能欄位（用 Char.HaveSkill(c,技能ID) 取得），不是技能 ID。失敗 -1。 | lua参考/Char.lua:290 | 技能 |
| Char.GetSkillID | (CharIndex:number, Slot:number(技能位置，不能大於人物自身的技能欄位數量。)) → number 返回-1代表失敗，其他為技能ID，與skill.txt內容相對應，引數資料型別不對返回-2，物件index無效返回-3，技能位置超出範圍返回-4。 | 依欄位取技能 ID（-1 無）。 | lua参考/Char.lua:278; 例 gmsv/lua/Modules/autobattle.lua:96; 例 modules-src/autobattle.utf8.lua:96; 已知事實(實測) | 技能 |
| Char.GetSkillId | (CharIndex:number, Slot:number(技能位置，不能大於人物自身的技能欄位數量。)) → number 返回-1代表失敗，其他為技能ID，與skill.txt內容相對應，引數資料型別不對返回-2，物件index無效返回-3，技能位置超出範圍返回-4。 | 推測：獲取指定玩家的指定位置的技能ID。（僅第三方文件，無用例） | lua参考/Char.lua:284 | 技能 |
| Char.GetSkillLevel | (CharIndex:number, Slot:number(技能位置，可用Char.HaveSkill來獲取位置。)) → number 成功返回技能等級,失敗返回-1，引數資料型別不對返回-2，物件index無效返回-3，技能的位置錯誤返回-4。 | 推測：獲取指定玩家的指定技能位置的技能等級。（僅第三方文件，無用例） | lua参考/Char.lua:260 | 技能 |
| Char.GetSkillLv | (CharIndex:number, Slot:number(技能位置，可用Char.HaveSkill來獲取位置。)) → number 成功返回技能等級,失敗返回-1，引數資料型別不對返回-2，物件index無效返回-3，技能的位置錯誤返回-4。 | 依欄位取技能等級。 | lua参考/Char.lua:266; 例 gmsv/lua/Modules/autobattle.lua:98; 例 modules-src/autobattle.utf8.lua:98; 已知事實(實測) | 技能 |
| Char.GetSkillSeqNo | (charIndex:number(物件的index), slot:number(技能實際位置，範圍0-14)) → number seq 技能顯示位置，範圍1-15 | 推測：獲取技能顯示順序（僅第三方文件，無用例） | lua参考/Char.lua:749 | 技能 |
| Char.GetSuitCount | (charIndex:number) → number 套裝數量 | 推測：角色啟用套裝的數量（僅第三方文件，無用例） | lua参考/Char.lua:704 | 道具 |
| Char.GetSuitId | (charIndex:number, slot:number(道具欄位置)) → number 角色道具欄套裝的ID | 推測：獲得角色道具欄套裝的ID（僅第三方文件，無用例） | lua参考/Char.lua:699 | 道具 |
| Char.GetTempData | (charIndex:number, dataIndex:string(資訊儲存的位置，自定義)) → string/number/nil 獲得指定位置的字串 | 讀自訂暫存資料（不存庫，登出／重啟即失）。 | lua参考/Char.lua:536; 例 gmsv/lua/libs/Module/Parts/Char.lua:35 | 查詢 |
| Char.GetTitle | (CharIndex:number) → number 成功返回玩家物件啟用的稱號ID，返回-1代表失敗，引數資料型別不對返回-2，物件index無效返回-3。 | 獲取指定玩家啟用的稱號ID。 | lua参考/Char.lua:316; 例 gmsv/lua/Module/title.lua:20 | 查詢 |
| Char.GetTitleBySlot | (charIndex:CharIndex, slot:number(序號)) → number titleId | 推測：獲取玩家TitleId（僅第三方文件，無用例） | lua参考/Char.lua:787 | 查詢 |
| Char.GetTitleIndex | (charIndex:number) → number 玩家稱號index | 推測：查詢玩家稱號index（僅第三方文件，無用例） | lua参考/Char.lua:644 | 查詢 |
| Char.GetTitleNameBySlot | (charIndex:number(CharIndex), slot:number(序號)) → string 稱號名字 | 推測：獲取稱號通過序號（僅第三方文件，無用例） | lua参考/Char.lua:781 | 查詢 |
| Char.GetUUID | (charIndex:number) → number 角色UUID | 取得角色唯一 ID（Pet.GetUUID 即包裝此函式）。 | lua参考/Char.lua:623; 例 gmsv/lua/libs/Gmsv/Pet.lua:4 | 查詢 |
| Char.GetWeapon | 未驗證 | 未驗證 | 定義 gmsv/lua/libs/Gmsv/CharEx.lua:3; 例 gmsv/lua/libs/Gmsv/BattleEx.lua:6 | 道具 |
| Char.GiveItem | (CharIndex:number, ItemID:number(道具ID。), Amount:number(道具的數量。), ShowMsg?:boolean(是否顯示系統資訊)) → number 目標道具index，失敗則返回負數。 | 給道具：(c, itemId, 數量, ShowMsg)，成功回道具 index（stub），失敗負數。 | lua参考/Char.lua:132; 例 gmsv/lua/Modules/abtest.lua:104; 例 gmsv/lua/Modules/adminCommands.lua:12; 已知事實(實測) | 道具 |
| Char.GivePet | (CharIndex:number, PetID:number(寵物的ID), FullBP?:number(1表示製作滿檔寵物，0表示檔數隨機，不填寫該引數則檔數隨機)) → number 製作成功則返回目標寵物的物件index，否則返回-1，引數資料型別不對返回-2，物件index無效返回-3。 | 給對象一隻 1 級寵物（enemyId，FullBP=1 滿檔／0 隨機），回新寵物 index。 | lua参考/Char.lua:168; 例 gmsv/lua/Modules/abtest.lua:98; 例 gmsv/lua/Modules/adminCommands.lua:36; 已知事實(實測) | 寵物 |
| Char.GlobalEvent | (charIndex:number, flag:number(任務旗標。)) → number 返回旗標狀態。 ／ (charIndex:number, flag:number(任務旗標。), value:number) → 無回傳說明 | 推測：獲取目標物件的GlobalEvent任務旗標。（僅第三方文件，無用例） | lua参考/Char.lua:92 | NPC事件 |
| Char.GlobalGAEvent | (charIndex:number, flag:number(任務旗標。)) → number 返回旗標狀態。 ／ (charIndex:number, flag:number(任務旗標。), value:number) → 無回傳說明 | 推測：獲取目標物件整隊的GlobalEvent任務旗標。（僅第三方文件，無用例） | lua参考/Char.lua:68 | NPC事件 |
| Char.GlobalTEvent | (charIndex:number, flag:number(任務旗標。)) → number 返回旗標狀態。 ／ (charIndex:number, flag:number(任務旗標。), value:number) → 無回傳說明 | 推測：獲取目標物件的GlobalTEvent任務旗標。（僅第三方文件，無用例） | lua参考/Char.lua:80 | NPC事件 |
| Char.HaveGuild | (CharIndex:number) → number 如果目標有工會，則返回1，沒有則返回-1。 | 推測：檢查角色是否加入公會（僅第三方文件，無用例） | lua参考/Char.lua:512 | 查詢 |
| Char.HaveItem | (CharIndex:number, ItemID:number(道具ID。)) → number 如果目標有該道具，則返回該道具index，否則返回-1。 | 檢查是否擁有 itemId：有回第一個道具 index（用例以 ~= -1 判斷），沒有回 -1。 | lua参考/Char.lua:138; 例 gmsv/lua/Module/autowarp.lua:114; 例 gmsv/lua/Module/nofix/ExtractCredits_GA.lua:184 | 道具 |
| Char.HaveItemID | (charIndex:number, itemId:number(道具ID)) → number 第一個符合條件的itemIndex | 推測：角色是否有符合itemId條件的道具（僅第三方文件，無用例） | lua参考/Char.lua:549 | 道具 |
| Char.HaveItemPos | (charIndex:number, itemId:number(道具ID)) → number 第一個符合條件的道具欄 | 推測：角色是否有符合itemId條件的道具，並返回位置（僅第三方文件，無用例） | lua参考/Char.lua:555 | 道具 |
| Char.HavePet | (charIndex:number, petId:number(寵物的ID)) → number 如果目標有該寵物的寵物位置(0-4)，沒有則返回-1，引數資料型別不對返回-2，物件index無效返回-3。 | 檢測物件身上是否有目標寵物。 | lua参考/Char.lua:155; 例 gmsv/lua/Module/routine_too.lua:382; 例 gmsv/lua/Module/nofix/routine_too.lua:382 | 寵物 |
| Char.HaveSkill | (CharIndex:number, SkillID:number(技能ID，與skill.txt內容相對應。)) → number 返回-1代表失敗，其他為技能欄位置，引數資料型別不對返回-2，物件index無效返回-3，技能的ID錯誤返回-4。 | 查技能 ID 所在欄位（0~14），沒有回 -1；常與 SetSkillLevel／GetSkillLv 串用。 | lua参考/Char.lua:272; 例 gmsv/lua/Modules/abtest.lua:94; 例 modules-src/abtest.utf8.lua:94; 已知事實(實測) | 技能 |
| Char.IsDummy | (charIndex:number) → number true，假人，false，不是假人 | 判斷對象是否為假人（true／false）。AI 佣兵 mod 用它區分假人與真玩家。 | lua参考/Char.lua:722; 例 modules-src/merc.utf8.lua:93 | 存檔掛機 |
| Char.IsEnemy | 未驗證 | 未驗證 | 定義 gmsv/lua/libs/Gmsv/CharEx.lua:74 | 查詢 |
| Char.IsFeverTime | (CharIndex:number) → number 1在打卡，0不在打卡，引數資料型別不對返回-2，物件index無效返回-3。 | 是否在打卡狀態：1 是、0 否。登入記憶用。 | lua参考/Char.lua:355; 例 gmsv/lua/Module/myLogin.lua:49; 例 gmsv/lua/Module/nofix/Item_Lucky.lua:262 | 存檔掛機 |
| Char.IsNpc | 未驗證 | 未驗證 | 定義 gmsv/lua/libs/Gmsv/CharEx.lua:83 | 查詢 |
| Char.IsPet | 未驗證 | 未驗證 | 定義 gmsv/lua/libs/Gmsv/CharEx.lua:56; 例 modules-src/merc.utf8.lua:602 | 寵物 |
| Char.IsPlayer | 未驗證 | 未驗證 | 定義 gmsv/lua/libs/Gmsv/CharEx.lua:65; 例 modules-src/merc.utf8.lua:288 | 查詢 |
| Char.IsValidCharIndex | 未驗證 | 未驗證 | 定義 gmsv/lua/libs/Gmsv/CharEx.lua:16; 例 gmsv/lua/libs/Gmsv/CharEx.lua:21; 例 gmsv/lua/libs/Module/LegacyModule.lua:7 | 查詢 |
| Char.ItemMoveBag | (charIndex:number(物件的index), slot:number(道具位置0~27), page:number(背包編號0~3), toSlot:number(道具位置0~19, -1為自動找空位)) → number 1為成功，其他均為失敗 | 把物品移到另一頁背包：slot（0~27）、page（0~3）、toSlot（0~19，-1 自動找空位），回 1 成功。依 bagSwitch 用例，slot 以 EQUIP_NUM+選項 計算（含裝備欄偏移）。 | lua参考/Char.lua:775; 例 gmsv/lua/Modules/bagSwitch.lua:211 | 道具 |
| Char.ItemNum | (charIndex:number, ItemID:number(道具ID。)) → number 如果目標有該道具，則返回擁有的該道具的數量，否則返回0。 | 某 itemId 的總數量（含堆疊）。 | lua参考/Char.lua:149; 例 gmsv/lua/Modules/itemprobe.lua:28; 例 modules-src/itemprobe.utf8.lua:28; 已知事實(實測) | 道具 |
| Char.ItemSlot | (CharIndex:number) → number 目標道具欄的已經使用的欄位數量，無任何道具返回0。 | 檢測物件身上的已經有道具的道具欄位數量。 | lua参考/Char.lua:143; 例 gmsv/lua/Module/Signin.lua:246; 例 gmsv/lua/Module/TJBX.lua:74 | 道具 |
| Char.JoinParty | (sourceIndex:number(隊員index), targetIndex:number(隊長index), flag?:boolean(是否無視組隊開關)) → number 成功返回0 | 無視距離加入隊伍：(隊員, 隊長, flag=true 無視對方組隊開關)，成功回 0。假人加入真人隊伍就靠它。 | lua参考/Char.lua:688; 例 gmsv/lua/Modules/abtest.lua:159; 例 gmsv/lua/Modules/adminCommands.lua:65 | 隊伍 |
| Char.LeaveParty | (charIndex:number) → number 成功返回1 | 離開隊伍，成功回 1。 | lua参考/Char.lua:693; 例 modules-src/merc.utf8.lua:96 | 隊伍 |
| Char.LevelExp | (CharIndex:number) → number 下一級所需經驗，傳入的等級引數小於等於0則返回-1，引數資料型別不對返回-2，物件index無效返回-3。 | 推測：獲取物件的下一級所需經驗。（僅第三方文件，無用例） | lua参考/Char.lua:234 | 查詢 |
| Char.LocalCount | (charIndex:number, flag:number(任務旗標。)) → number 返回旗標狀態。 ／ (charIndex:number, flag:number(任務旗標。), value:number(數值)) → 無回傳說明 | 推測：獲取目標物件的LocalCount變數。（僅第三方文件，無用例） | lua参考/Char.lua:44 | NPC事件 |
| Char.LocalEvent | (charIndex:number, flag:number(任務旗標。)) → number 返回旗標狀態。 ／ (charIndex:number, flag:number(任務旗標。), value:number) → 無回傳說明 | 推測：獲取目標物件的LocalEvent任務旗標。（僅第三方文件，無用例） | lua参考/Char.lua:56 | NPC事件 |
| Char.MoveArray | (charIndex:number, walkArray:number[](移動列表，取值0-7對應 CONST裡面的方向，不建議超過5次移動)) → number 成功返回1 | 依方向表移動角色／NPC（方向值 0~7，對應 CONST 方向；不建議超過 5 步），回 1 成功。 | lua参考/Char.lua:618; 例 gmsv/lua/Modules/adminCommands.lua:154 | 移動 |
| Char.MoveItem | (charIndex:number, fromSlot:number(移動那個物品，取值0-27), toSlot:number(移動到那個位置, 取值0-27), amount:number(數量，整體移動取值可為-1)) → number 成功返回1 | 在同一角色身上移動物品：fromSlot→toSlot（0~27，0~7 為裝備欄、8~27 為背包），amount=-1 整堆移動。把背包物品移到 CONST.EQUIP_* 位置即「裝備」；回 1 成功。 | lua参考/Char.lua:602; 例 gmsv/lua/Modules/adminCommands.lua:103; 例 modules-src/merc.utf8.lua:734 | 道具 |
| Char.MovePet | (charIndex:number, frslot:number(移動前寵物欄位置，0-4), toslot:number(移動後寵物欄位置，0-4)) → number 成功返回1 | 推測：移動寵物（僅第三方文件，無用例） | lua参考/Char.lua:681 | 寵物 |
| Char.NowEvent | (charIndex:number, flag:number(任務旗標。)) → number 則返回旗標狀態。 ／ (charIndex:number, flag:number(任務旗標。), value:number) → 無回傳說明 | 讀寫任務旗標 NowEvent（進行中）：2 參數＝讀，3 參數＝寫（value 0／1）。 | lua参考/Char.lua:20; 例 gmsv/lua/Module/nofix/checked/EasyWarp.lua:363 | NPC事件 |
| Char.PartyNum | (CharIndex:number) → number 組隊中的玩家人數，無組隊返回-1，否則返回玩家人數，獲取失敗返回0，引數資料型別不對返回-2，物件index無效返回-3。 | 獲取物件的組隊中的玩家人數。 | lua参考/Char.lua:213; 例 modules-src/merc.utf8.lua:327; 例 gmsv/lua/Module/autowarp.lua:214 | 隊伍 |
| Char.PetNum | (charIndex:number) → number 返回目標的寵物數量，範圍0-5。 | 檢測物件身的寵物數量。 | lua参考/Char.lua:193; 例 gmsv/lua/Module/nofix/Item_Lucky.lua:247 | 寵物 |
| Char.RemovePoolItem | (charIndex:number, slot:number(道具欄位置)) → number 成功返回0 | 刪除銀行指定格的道具，成功回 0。無用例。 | lua参考/Char.lua:581 | 道具 |
| Char.SaveToDb | (charIndex:number) → number 成功返回0 | 立刻把角色資料存入資料庫（成功回 0）。AI 佣兵 mod 在 Char.SetExtData 寫入購買記錄後立刻呼叫，用來避免資料沒落盤。 | lua参考/Char.lua:634; 例 modules-src/merc.utf8.lua:247 | 存檔掛機 |
| Char.SetAutoWalk | (charaIndex:number, iMovable:boolean, distance:number 0~10, interval:number 毫秒, fromX, toX, fromY, toY) → number 1 成功，其他失敗 | 設定對象自動移動（stub 描述）：iMovable 開關、distance 每次距離 0~10、interval 毫秒、fromX/toX/fromY/toY 為活動範圍矩形。回 1 成功。對象大概是 NPC／假人，真人是否適用未驗證，無用例。 | lua参考/Char.lua:807 | 移動 |
| Char.SetData | (charIndex:number, dataIndex:number(指定的物件例項資訊欄位，具體參考CONST.物件_***), value:string/number(新的值)) → number 0為失敗，1為成功 | 寫入對象欄位，回傳 1 成功／0 失敗；改完 HP／能力值後常需 NLG.UpChar 刷新給客戶端。 | lua参考/Char.lua:14; 例 gmsv/lua/Modules/abtest.lua:76; 例 gmsv/lua/Modules/adminCommands.lua:40 | 其他 |
| Char.SetDummy | (charIndex:number) → number 成功返回0 | 推測：把既有對象標記為假人（回 0 成功）。無任何用例；建立假人應用 CreateDummy，此函式用途（把真人角色轉假人以無頭運作？）未實測。 | lua参考/Char.lua:727 | 存檔掛機 |
| Char.SetExtData | (charIndex:number, dataIndex:string(資訊儲存的位置，自定義), value:string/number/nil(儲存的資訊)) → number | 寫自訂資料（字串鍵）並存入資料庫；傳 nil 可清除。注意變更是否立即落盤，AI 佣兵 mod 寫完會再呼叫 Char.SaveToDb。 | lua参考/Char.lua:530; 例 gmsv/lua/Modules/loginGate.lua:65; 例 modules-src/merc.utf8.lua:246 | 其他 |
| Char.SetItemIndex | (charIndex:number, slot:number(道具欄位置), itemIndex:number(道具的 index)) → number 成功所在欄位 | 推測：設定指定道具欄的道具為itemIndex,可與Item.MakeItem(itemId)聯用（僅第三方文件，無用例） | lua参考/Char.lua:568 | 道具 |
| Char.SetItemPutEvent | (Dofile?:string(要載入的指令碼檔名，如果為當前檔案，則定義nil即可), FuncName:string(觸發的Lua函式的名稱，該函式的申明格式請參考[CharItemPutC), CharIndex:number(設定的物件index。)) → 無回傳說明 | 推測：為物件index設定丟棄道具事件的回撥函式，物件在丟棄道具的時候會觸發該函式，由Lua引擎將Callback的引數傳遞給指定的Callback並執行。（僅第三方文件，無用例） | lua参考/Char.lua:456 | NPC事件 |
| Char.SetLoopEvent | (Dofile?:string(要載入的指令碼檔名，如果為當前檔案，則定義nil即可), FuncName:string(觸發的Lua函式的名稱，該函式的申明格式請參考[CharLoopCall), CharIndex:number(設定的物件index。), Interval:number(迴圈間隔，單位毫秒。)) → 無回傳說明 | 註冊每 Interval 毫秒觸發的循環回呼 callback(charIndex)（對 NPC 對象設定，作為定時器）。用例以 SetLoopEvent(nil,nil,idx,0) 清掉舊的再註冊 (nil,"函式名",idx,1000)。是伺服器端排程採集／巡邏的候選機制。 | lua参考/Char.lua:412; 例 gmsv/lua/Module/TJBX.lua:57; 例 gmsv/lua/Module/Tohelos.lua:179 | 存檔掛機／NPC事件 |
| Char.SetPetDepartureState | (charIndex:number, slot:number(寵物欄位置), state:number(寵物狀態，對應CONST.PET_STATE_*)) → number 成功返回1 | 設定指定寵物欄位的出戰狀態（CONST.PET_STATE_*，如戰鬥／待機），回 1 成功。 | lua参考/Char.lua:657; 例 gmsv/lua/Modules/adminCommands.lua:109 | 寵物／戰鬥 |
| Char.SetPetDepartureStateAll | (charIndex:number, pet1State:number(寵物狀態，對應CONST.PET_STATE_*), pet2State:number(寵物狀態，對應CONST.PET_STATE_*), pet3State:number(寵物狀態，對應CONST.PET_STATE_*), pet4State:number(寵物狀態，對應CONST.PET_STATE_*), pet5State:number(寵物狀態，對應CONST.PET_STATE_*)) → number 成功返回1 | 推測：設定寵物戰鬥狀態(批次)（僅第三方文件，無用例） | lua参考/Char.lua:667 | 寵物／戰鬥 |
| Char.SetPoolItem | (charIndex:number, slot:number(道具欄位置), itemIndex:number(道具的 index)) → number 成功返回0 | 把 itemIndex 放進銀行指定格（可搭配 Item.MakeItem(itemId) 先造無主道具），成功回 0。無用例。 | lua参考/Char.lua:575 | 道具 |
| Char.SetPostOverEvent | (Dofile?:string(要載入的指令碼檔名，如果為當前檔案，則定義nil即可), FuncName:string(觸發的Lua函式的名稱，該函式的申明格式請參考[PostOverEven), CharIndex:number(設定的物件index。)) → 無回傳說明 | 推測：為物件index設定覆蓋其他物件後事件的回撥函式，物件在覆蓋其他物件後會觸發該函式，由Lua引擎將Callback的引數傳遞給指定的Callback並執行。（僅第三方文件，無用例） | lua参考/Char.lua:398 | NPC事件 |
| Char.SetSkillAction | (charIndex:number(物件的index), skillNo?:number(圖示旗標，取值0~15)) → number 成功返回0 | 推測：設定頭頂技能圖示（skillNo 0~15）。stub 僅「设置头顶技能图标」，無用例；是否對應採集／製造動畫圖示未驗證。 | lua参考/Char.lua:743 | 技能 |
| Char.SetSkillExp | (CharIndex:number, Slot:number(技能位置，可用Char.HaveSkill來獲取位置。), EXP:number(新的技能經驗。), ShowMsg?:number(是否顯示系統資訊。)) → number 成功返回新的技能經驗,失敗返回-1，傳入的引數資料型別不對返回-2，物件index無效返回-3，技能的位置錯誤返回-4，傳入的新經驗小於1則返回-5。 | 設定技能經驗（stub 說明文字誤寫為「獲取」，簽名為 Set）。slot 用 Char.HaveSkill 取得，EXP 需 >=1，回新經驗值。可用來直接調整採集／製造技能熟練度，未實測。 | lua参考/Char.lua:306 | 技能 |
| Char.SetSkillLevel | (CharIndex:number, Slot:number(技能位置，可用Char.HaveSkill來獲取位置。), Level:number(新的技能等級。), ShowMsg?:number(是否顯示系統資訊。)) → number 成功返回新技能等級,失敗返回-1，傳入的引數資料型別不對返回-2，物件index無效返回-3，技能的位置錯誤返回-4，傳入的新等級小於1則返回-5。 | 設定技能等級；slot 為技能欄位（Char.HaveSkill 取得），Level>=1，成功回新等級（stub 說明誤寫「獲取」）。 | lua参考/Char.lua:298; 例 gmsv/lua/Modules/abtest.lua:94; 例 modules-src/abtest.utf8.lua:94; 已知事實(實測) | 技能 |
| Char.SetSkillSeqNo | (charIndex:number(物件的index), slot:number(技能實際位置，範圍0-14), seq:number(技能顯示位置，範圍1-15), msg:number/boolean(是否顯示系統資訊)) → number seq 技能顯示位置，範圍1-15 | 推測：設定技能顯示順序（僅第三方文件，無用例） | lua参考/Char.lua:757 | 技能 |
| Char.SetTalkedEvent | (Dofile?:string(要載入的指令碼檔名，如果為當前檔案，則定義nil即可), FuncName:string(觸發的Lua函式的名稱，該函式的申明格式請參考[CharWalkPreC), CharIndex:number(設定的物件index。)) → 無回傳說明 | 註冊「玩家對 NPC 說話」回呼：callback(npcIndex, talkerIndex, msg, color, size)（stub 簽名描述；第一參數是 NPC，第二是說話者）。多見 Dofile 寫完整相對路徑 "lua/Module/xxx.lua"。 | lua参考/Char.lua:424; 例 gmsv/lua/libs/Module/Parts/Npc.lua:139; 例 gmsv/lua/Module/Shortcut.lua:20 | NPC事件 |
| Char.SetTempData | (charIndex:number, dataIndex:string(資訊儲存的位置，自定義), value:string/number/nil(儲存的資訊)) → number | 寫自訂暫存資料（不存庫）。 | lua参考/Char.lua:543; 例 gmsv/lua/libs/Module/Parts/Char.lua:43 | 其他 |
| Char.SetWalkPostEvent | (Dofile?:string(要載入的指令碼檔名，如果為當前檔案，則定義nil即可), FuncName:string(觸發的Lua函式的名稱，該函式的申明格式請參考[CharWalkPost), CharIndex:number(設定的物件index。)) → number 成功返回0 | 註冊「走路之後」回呼：每走一步後觸發 callback(charIndex)。Dofile 傳 nil＝本檔，或寫 "lua/Module/xxx.lua"。成功回 0；取消用 UnsetWalkPostEvent(charIndex)。可用來偵測假人／真人移動後事件（例如遇敵判定）。 | lua参考/Char.lua:386; 例 gmsv/lua/Modules/adminCommands.lua:229; 例 gmsv/lua/Module/item.lua:30 | 移動／NPC事件 |
| Char.SetWalkPreEvent | (Dofile?:string(要載入的指令碼檔名，如果為當前檔案，則定義nil即可), FuncName:string(觸發的Lua函式的名稱，該函式的申明格式請參考[CharWalkPreC), CharIndex:number(設定的物件index。)) → 無回傳說明 | 註冊「走路之前」回呼 callback(charIndex)；回傳 1 執行行走，回傳 0 取消這一步。可用來限制角色移動。 | lua参考/Char.lua:372 | 移動／NPC事件 |
| Char.SetWatchEvent | (Dofile?:string(要載入的指令碼檔名，如果為當前檔案，則定義nil即可), FuncName:string(觸發的Lua函式的名稱，該函式的申明格式請參考[CharWatchCal), CharIndex:number(設定的物件index。)) → 無回傳說明 | 推測：疑似限時道具（僅第三方文件，無用例） | lua参考/Char.lua:469 | NPC事件 |
| Char.SetWindowTalkedEvent | (Dofile?:string(要載入的指令碼檔名，如果為當前檔案，則定義nil即可), FuncName:string(觸發的Lua函式的名稱，該函式的申明格式請參考[CharWindowTa), CharIndex:number(設定的物件index。)) → 無回傳說明 | 註冊「視窗互動」回呼：callback(npcIndex, talkerIndex, seqNo, select, data)；seqNo 對應 NLG.ShowWindowTalked 送出的視窗 ID，select 為按鈕／選項值，data 為客戶端回傳字串。NPC 對話選單的核心。 | lua参考/Char.lua:440; 例 gmsv/lua/libs/Module/Parts/Npc.lua:151; 例 gmsv/lua/Module/MateChage.lua:24 | NPC事件 |
| Char.SimpleLogout | (charIndex:CharIndex) → 無回傳說明 | 登出該對象（stub 僅寫「登出」，無回傳說明）。用例：AI 佣兵 mod 對假人呼叫後再 Warp／JoinParty，推測為把假人從目前場景／戰鬥中清掉以便重置；真人帳號登出行為未驗證。 | lua参考/Char.lua:791; 例 modules-src/merc.utf8.lua:328 | 存檔掛機 |
| Char.SwitchBag | (charIndex:number(物件的index), page:number(背包編號0~3)) → number 1為成功，其他均為失敗 | 切換目前背包頁（page 0~3），回 1 成功，其他失敗。本服擴充功能（4 頁背包）。 | lua参考/Char.lua:768; 例 gmsv/lua/Modules/bagSwitch.lua:119 | 道具 |
| Char.TradeItem | (fromChar:number(從誰身上交出去 物件index), slot:number(道具欄位置，範圍8-27), toChar:number(交易給誰 物件index)) → number 接收者所在的欄位，少於0時失敗 | 推測：把 fromChar 背包 slot（8~27）的道具直接移交給 toChar，回傳接收者的新欄位（<0 失敗）。無用例，未實測；若可行，是角色間轉移道具（collector→倉管）的最短路徑。 | lua参考/Char.lua:588 | 交易 |
| Char.TradePet | (fromChar:number(從誰身上交出 CharIndex), slot:number(寵物欄位置，0-4), toChar:number(交易給誰 CharIndex)) → number 成功所在的新欄位 | 推測：把 fromChar 寵物欄 slot（0~4）的寵物直接移交給 toChar，回傳新欄位。無用例，未實測。 | lua参考/Char.lua:674 | 交易 |
| Char.UnsetItemPutEvent | (charIndex:number) → 無回傳說明 | 推測：解除ItemPutEvent（僅第三方文件，無用例） | lua参考/Char.lua:503 | NPC事件 |
| Char.UnsetLoopEvent | (charIndex:number) → 無回傳說明 | 解除LoopEvent | lua参考/Char.lua:491; 例 gmsv/lua/libs/Module/Parts/Npc.lua:244 | 存檔掛機／NPC事件 |
| Char.UnsetPostOverEvent | (charIndex:number) → 無回傳說明 | 推測：解除PostOverEvent（僅第三方文件，無用例） | lua参考/Char.lua:487 | NPC事件 |
| Char.UnsetTalkedEvent | (charIndex:number) → 無回傳說明 | 解除TalkedEvent | lua参考/Char.lua:495; 例 gmsv/lua/libs/Module/Parts/Npc.lua:246 | NPC事件 |
| Char.UnsetWalkPostEvent | (charIndex:number) → 無回傳說明 | 解除walkpostevent | lua参考/Char.lua:479; 例 gmsv/lua/Modules/adminCommands.lua:232 | 移動／NPC事件 |
| Char.UnsetWalkPreEvent | (charIndex:number) → 無回傳說明 | 推測：解除WalkPreEvent（僅第三方文件，無用例） | lua参考/Char.lua:483 | 移動／NPC事件 |
| Char.UnsetWatchEvent | (charIndex:number) → 無回傳說明 | 推測：解除WatchEvent（僅第三方文件，無用例） | lua参考/Char.lua:507 | NPC事件 |
| Char.UnsetWindowTalkedEvent | (charIndex:number) → 無回傳說明 | 解除WindowTalkedEvent | lua参考/Char.lua:499; 例 gmsv/lua/libs/Module/Parts/Npc.lua:245 | NPC事件 |
| Char.UpCharStatus | (charIndex:number) → number 成功返回0 | 推測：更新角色狀態資訊（僅第三方文件，無用例） | lua参考/Char.lua:612 | 道具 |
| Char.Warp | (charIndex:number, mapType:number 慣用0, floorId:number, x:number, y:number) → 實測 1 成功 | 傳送對象：(c, MapType=0, floorId, x, y)，傳隊長時隊員一起移動，成功回 1（stub 寫 boolean true）。第二參數 MapType 慣例填 0。 | lua参考/Char.lua:208; 例 gmsv/lua/Modules/adminCommands.lua:32; 例 gmsv/lua/Modules/autobattle.lua:653; 已知事實(實測) | 移動 |

## Item（28 個）

| 函式 | 參數 → 回傳 | 用途（繁體中文） | 依據 | 標籤 |
|---|---|---|---|---|
| Item.CreateNewItemType | (type:number(道具型別編號), name:string(道具型別名稱), defaultImage:number(未鑑定時圖檔), place:number(裝備位置), flags:number(武器型別。1-劍，2-斧，4-槍，8-杖，16-弓，32-小刀，64-回)) → number 成功返回1 | 建立新的道具類型（type 編號、name、未鑑定圖檔、裝備位置 place、flags 武器類型位元：1劍 2斧 4槍 8杖 16弓 32小刀 64回力鏢 128空手 255 全部）。成功回 1。 | lua参考/Item.lua:48 | 道具 |
| Item.GetCharPointer | (ItemIndex:number(道具index)) → number 道具的userdata | 推測：獲取道具的userdata（僅第三方文件，無用例） | lua参考/Item.lua:75 | 道具 |
| Item.GetData | (ItemIndex:number, Dataline:number(說指定的物件例項資訊欄位，具體欄位常量請檢視附錄。)) → number/string 指定資訊欄位的值 | 讀道具欄位（CONST.道具_*；字串欄位回字串，如 道具_自用参数 回 "LP100"，道具_战斗可用 回 1/0）。 | lua参考/Item.lua:7; 例 gmsv/lua/Modules/autobattle.lua:232; 例 gmsv/lua/Modules/bagSwitch.lua:165; 已知事實(實測) | 道具 |
| Item.GetExtData | (ItemIndex:number, Dataline:string(說指定的物件例項資訊欄位)) → number/string 指定資訊欄位的值 | 道具自訂資料（字串鍵）讀取。無用例。 | lua参考/Item.lua:20 | 道具 |
| Item.GetItemTypeEquipLevelForJob | (job:number(職業ID), type:number(道具型別)) → number 該物品類別的職業裝備等級 | 推測：獲取擴充套件自定義物品類別職業裝備等級（僅第三方文件，無用例） | lua参考/Item.lua:63 | 道具 |
| Item.GetNameFromNumber | (ItemId:number(道具id)) → number string 道具名 | 依 itemId 取得道具名稱（字串；stub 回傳標註型別為 number 疑為筆誤）。 | lua参考/Item.lua:91 | 道具 |
| Item.GetNewItemType | (type:number(道具型別編號)) → number 由CreateNewItemType輸入的type ; string 由CreateNewItemType輸入的name ; number 由CreateNewItemType輸入的place ; number 由CreateNewItemType輸入的defaultImage ; number 由CreateNewItemType輸入的flags | 推測：獲得新得道具型別資訊（僅第三方文件，無用例） | lua参考/Item.lua:57 | 道具 |
| Item.GetOwner | (itemIndex:number(ItemIndex)) → number 道具所有者的CharIndex | 取得道具所有者的 charIndex。無用例。 | lua参考/Item.lua:125 | 道具 |
| Item.GetPetEquipPlace | (type:number(道具型別), place:number(位置，0-4，參考CONST.寵道欄_*)) → number 能裝備為返回1 | 推測：獲取道具型別寵物裝備位置（僅第三方文件，無用例） | lua参考/Item.lua:112 | 道具 |
| Item.GetSlot | (charIndex:number, itemIndex:number) → number slot／-1 | Lua 包裝：由 itemIndex 在背包 8 ~ (道具欄數-1) 找出所在欄位，找不到回 -1。 | 定義 gmsv/lua/libs/Gmsv/ItemEx.lua:1; 例 gmsv/lua/libs/Gmsv/ItemEx.lua:96 | 道具 |
| Item.GetTimeLimit | (CharIndex:number, ItemIndex:number) → number 剩餘秒／nil | Lua 包裝：取得限時道具剩餘秒數；非限時或不在背包回 nil。內部用 道具_TIMELIMIT／道具_ENDTIME。 | 定義 gmsv/lua/libs/Gmsv/ItemEx.lua:105; 例 gmsv/lua/libs/Gmsv/ItemEx.lua:101 | 道具 |
| Item.IsWeaponType | (ItemIndex:number(道具index)) → number 是武器時返回1 | 推測：判斷道具是否為武器（是回 1）。已有 Lua 包裝 Item.isWeapon 可用。 | lua参考/Item.lua:101 | 道具 |
| Item.Kill | (CharIndex:number(目標物件index。), ItemIndex:number(目標道具index。), Slot:number(指定背包的位置。)) → number 道具刪除成功返回1,失敗返回0或負數。 | 刪除道具並通知玩家：(CharIndex, ItemIndex, Slot)。成功回 1。 | lua参考/Item.lua:39; 例 gmsv/lua/Module/MateChage.lua:91; 例 gmsv/lua/Module/item.lua:66 | 道具 |
| Item.MakeItem | (itemId:number(道具id)) → number number 返回道具itemindex | 依 itemId 製造一個無主道具並回傳 itemIndex；之後用 Char.SetItemIndex／SetPoolItem 放進欄位。無用例（Char.GiveItem 較常用）。 | lua参考/Item.lua:106 | 製造／道具 |
| Item.RemoveCharPointer | (ItemIndex:number(道具index)) → number 道具的userdata | 推測：移除道具的userdata（僅第三方文件，無用例） | lua参考/Item.lua:86 | 道具 |
| Item.SetCharPointer | (ItemIndex:number(道具index), val:userdata) → number 成功返回0 | 推測：定義道具的userdata（僅第三方文件，無用例） | lua参考/Item.lua:81 | 道具 |
| Item.SetData | (ItemIndex:number, Dataline:number(說指定的物件例項資訊欄位，具體欄位常量請檢視附錄。), Data:number/string(新的值)) → number 0為失敗，1為成功。 | 寫道具欄位，回 1 成功／0 失敗；改完要 Item.UpItem 才會同步給客戶端。 | lua参考/Item.lua:14; 例 gmsv/lua/Modules/adminCommands.lua:15; 例 modules-src/merc.utf8.lua:709 | 道具 |
| Item.SetExtData | (ItemIndex:number, Dataline:string(說指定的物件例項資訊欄位), Data:number/string(新的值)) → number 0為失敗，1為成功。 | 道具自訂資料（字串鍵）寫入。無用例。 | lua参考/Item.lua:27 | 道具 |
| Item.SetItemTypeEquipLevelForJob | (job:number(職業ID), type:number(道具型別), level:number(職業裝備等級)) → boolean 成功返回true | 推測：擴充套件自定義物品類別職業裝備等級（僅第三方文件，無用例） | lua参考/Item.lua:70 | 道具 |
| Item.SetPetEquipPlace | (type:number(道具型別), place:number(位置，0-4，參考CONST.寵道欄_*), enable:number/boolean(能否裝備)) → number 成功返回1 | 推測：獲取道具型別寵物裝備位置（僅第三方文件，無用例） | lua参考/Item.lua:120 | 道具 |
| Item.SetTimeLimit | (CharIndex:number, ItemIndex:number, Time:number 秒) → 無回傳 | Lua 包裝（原生沒有才定義）：設限時道具，Time<0 取消限時，否則 ENDTIME=os.time()+Time；之後 UpItem。 | 定義 gmsv/lua/libs/Gmsv/ItemEx.lua:88; 例 gmsv/lua/libs/Gmsv/ItemEx.lua:83 | 道具 |
| Item.TohelosIgnoreEnemyLv | 未驗證 | 未驗證：名稱含 Tohelos（本服自訂 Tohelos 模組），推測為該模組用的「無視敵人等級」判斷。lua参考與用例均無。 | 僅名稱，未驗證 | 道具 |
| Item.UnlinkItem | (ItemIndex:number(道具index)) → number 成功返回0 | 推測：從世界移除道具物件（成功回 0），與 Item.Kill 差別在不通知玩家。無用例，慎用。 | lua参考/Item.lua:96 | 道具 |
| Item.UpItem | (CharIndex:number(目標物件index。), Slot:number(指定背包的位置，如果為-1則遍歷所有的道具。)) → 無回傳說明 | 發送更新道具封包給該玩家：(c, slot)，slot=-1 遍歷全部。SetData 之後必呼叫。 | lua参考/Item.lua:32; 例 gmsv/lua/Modules/adminCommands.lua:19; 例 modules-src/merc.utf8.lua:728 | 道具 |
| Item.isAccessory | (itemIndex:number) → boolean | Lua 包裝：是否飾品（手環樂器項鍊戒指頭帶耳環護身符），依 Item.GetData(道具_类型) 判斷。 | 定義 gmsv/lua/libs/Gmsv/ItemEx.lua:75 | 道具 |
| Item.isArmour | (itemIndex:number) → boolean | Lua 包裝：是否防具（盾盔帽鎧衣袍靴鞋），依 Item.GetData(道具_类型) 判斷。 | 定義 gmsv/lua/libs/Gmsv/ItemEx.lua:71 | 道具 |
| Item.isCrystal | (itemIndex:number) → boolean | Lua 包裝：是否水晶，依 Item.GetData(道具_类型) 判斷。 | 定義 gmsv/lua/libs/Gmsv/ItemEx.lua:79 | 道具 |
| Item.isWeapon | (itemIndex:number) → boolean | Lua 包裝：是否武器（劍斧槍杖弓小刀回力鏢），依 Item.GetData(道具_类型) 判斷。 | 定義 gmsv/lua/libs/Gmsv/ItemEx.lua:67; 例 gmsv/lua/libs/Gmsv/CharEx.lua:5 | 道具 |

## Pet（12 個）

| 函式 | 參數 → 回傳 | 用途（繁體中文） | 依據 | 標籤 |
|---|---|---|---|---|
| Pet.AddSkill | (PetIndex:number(目標寵物物件index。), SkillID:number(技能的ID，這裡是指Tech.txt檔案中定義的ID)) → number 成功增加返回1，失敗返回0。 | 替寵物學新技能（Tech.txt ID）；技能欄未滿才成功，回 1，否則 0。 | lua参考/Pet.lua:42; 例 modules-src/merc.utf8.lua:780; 例 gmsv/lua/Module/nofix/Item_Use.lua:151 | 寵物／技能 |
| Pet.DelSkill | (PetIndex:number(目標寵物物件index。), SkillSlot:number(技能的位置，從0開始計算。)) → number 成功增加返回1，失敗返回0。 | 刪除寵物指定欄位（0 起算）的技能；成功回 1（stub 回傳句誤寫「增加」）。 | lua参考/Pet.lua:48; 例 modules-src/merc.utf8.lua:777; 例 gmsv/lua/Module/nofix/Item_Use.lua:150 | 寵物／技能 |
| Pet.FullArtRank | (PetIndex:number(目標寵物物件index。), ArtType:number(要檢視的屬性，具體請參考附錄的寵物常量。)) → number 指定屬性的成長值。 | 寵物某屬性滿檔成長值。 | lua参考/Pet.lua:20; 例 gmsv/lua/Module/LvOnePet.lua:23; 例 gmsv/lua/Module/getpetBp.lua:56 | 寵物／封印 |
| Pet.GetArtRank | (PetIndex:number(目標寵物物件index。), ArtType:number(要檢視的屬性，具體請參考附錄的寵物常量。)) → number 指定屬性的成長值，數值型。 | 寵物某屬性目前成長值；與 FullArtRank 相減即「檔數」（滿檔差距），封印後評估寵物品質用。 | lua参考/Pet.lua:7; 例 gmsv/lua/Module/LvOnePet.lua:28; 例 gmsv/lua/Module/getpetBp.lua:55 | 寵物／封印 |
| Pet.GetOwner | (PetIndex:number(目標寵物物件index。)) → number 返回-1為未找到，否則為物件index。 | 寵物主人的 charIndex；寵物在地上或主人離線回 -1。 | lua参考/Pet.lua:36; 例 gmsv/lua/Module/nofix/petlvup.lua:9 | 寵物 |
| Pet.GetSkill | (PetIndex:number(目標寵物物件index。), SkillSlot:number(技能的位置，從0開始計算。)) → number 成功返回技能ID，失敗返回-1。 | 取得寵物指定欄位（0 起算）的技能 ID（Tech.txt），失敗 -1。 | lua参考/Pet.lua:54; 例 gmsv/lua/Modules/autobattle.lua:114; 例 modules-src/autobattle.utf8.lua:114; 已知事實(實測) | 寵物／技能 |
| Pet.GetUUID | (PetIndex:number) → string | Lua 包裝：回傳寵物唯一 ID（內部呼叫 Char.GetUUID），非寵物回 "-1"。 | 定義 gmsv/lua/libs/Gmsv/Pet.lua:3; lua参考/Pet.lua:59 | 寵物 |
| Pet.MoveItem | (charIndex:number(目標物件index。), fromPetSlot:number(0=玩家,1-5為寵物欄位), fromItemSlot:number(道具欄位置), toPetSlot:number(0=玩家,1-5為寵物欄位), toItemSlot:number(道具欄位置)) → 無回傳說明 | 在玩家與寵物之間移動裝備：fromPetSlot／toPetSlot 0=玩家、1~5=寵物欄；fromItemSlot／toItemSlot 為道具欄位。無用例。 | lua参考/Pet.lua:72 | 寵物／道具 |
| Pet.ReBirth | (PlayerIndex:number(目標物件index。), PetIndex:number(目標寵物物件index。)) → number 成功返回0 | 回爐寵物至 1 級（屬性與升級點重置，檔數不變），成功 0。 | lua参考/Pet.lua:26; 例 gmsv/lua/Module/xd.lua:76; 例 gmsv/lua/Module/nofix/GMSyumi.lua:182 | 寵物 |
| Pet.SetArtRank | (PetIndex:number(目標寵物物件index。), ArtType:number(要檢視的屬性，具體請參考附錄的寵物常量。), Value:number(要設定為的成長值。)) → number 0成功，其他失敗。 | 設寵物某屬性成長值（BP 分佈不會跟著變），0 成功；配合 Pet.ReBirth 可重新分配 BP。 | lua参考/Pet.lua:14; 例 gmsv/lua/Module/LvOnePet.lua:43; 例 gmsv/lua/Module/xd.lua:64 | 寵物／封印 |
| Pet.SetUUID | (PetIndex:number(目標寵物物件index。), uuid:string(寵物全域性唯一標識)) → 無回傳說明 | 設定寵物全局唯一識別字串。無用例。 | lua参考/Pet.lua:64 | 寵物 |
| Pet.UpPet | (PlayerIndex:number(目標物件index。), PetIndex:number(目標寵物物件index。)) → 無回傳說明 | 送出寵物狀態封包並重算等級等資訊（改了寵物 Data 後需呼叫）：(PlayerIndex, PetIndex)。 | lua参考/Pet.lua:31; 例 gmsv/lua/Modules/abtest.lua:101; 例 gmsv/lua/Modules/adminCommands.lua:41 | 寵物 |
