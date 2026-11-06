# cgmsv 26.8d Lua API 參考

2026-11-06 整理。清單來自伺服器執行期匯出（`apidump.txt`：遍歷所有全域表格的函式，名稱後有 `@檔案:行` 的是 Lua 包裝，其餘是 C 函式），表格裡每個函式都有一列，不多不少。

| 檔案 | 內容 |
|---|---|
| [char_item_pet.md](char_item_pet.md) | Char 126／Item 28／Pet 12 |
| [battle_nlg_map.md](battle_nlg_map.md) | Battle 46／NLG 51／NL 118／Obj 31／Map 19／Field 2 |
| [misc_events.md](misc_events.md) | Data、Protocol、Recipe、Skill、Stall、Tech、TechArea、Guild、SQL、Cron、Setup、Http、Func、BattleCommands、BT（共 96），以及全部事件（93＋補充 16） |
| `apidump.txt` | 執行期匯出的原始清單 |
| `upstream/` | 上游 Muscipular/cgmsv-lua 的 `docs/*.lua`（24.x 時代的 EmmyLua 文件，battle_nlg_map.md 引用的「上游」） |

## 資料來源與可信度

- `server-b/lua参考/*.lua`（GBK）：隨伺服器附的 EmmyLua 文件，幾乎每個函式、事件都有參數說明，是主要出處。但它是通用文件，不保證和 26.8d 完全一致。
- `server-b/gmsv/lua/`：實際的 Lua。`Modules/`、`libs/` 是新框架，較可信；`Module/`、`Module/nofix/` 多是舊版（`%常數%` 寫法）腳本，簽名可能不同。
- 狀態：**已確認**＝本機有用例、libs 註解或實測；**推測**＝只有文件；**未驗證**＝只有名稱。標【實測】的是自己跑過的。
- 讀 GBK 檔：`iconv -f gbk -t utf-8 -c 檔案`；grep 用 `LC_ALL=C grep -a`。

## 實測過的（可直接用）

- 戰鬥：`Battle.PVE(leader, leader, nil, {怪ID...}, {等級...})`；`Battle.ActionSelect(c, com, 目標, 招式ID)`，用道具時第 4 參數是背包位置 8～27；目標：單體＝位置、強力＝位置+20、全體＝40+side（我方）／41-side（敵方）；逃跑成功時 `GetWinSide` 也回敵方勝。
- 事件：`AutoBattleCommandEvent(b, c)` 要回 1；`ResetCharaBattleStateEvent(c)` 在角色離開戰場後觸發（逃跑、打贏都會）；`BeforeBattleTurnEvent(b)`、`BattleOverEvent(b)`。
- 隊伍與移動：`Char.GetPartyMember(c, 0)` 回隊長、未組隊回 -1；`Char.Warp(隊長, 0, map, x, y)` 隊員跟著走。
- 道具：`Item.GetData(it, CONST.道具_自用参数)` 回 `LP100` 之類；`CONST.道具_战斗可用` 回血藥 1、回魔料理 0。

## 生態系會用到的重點（多數未實測）

| 用途 | API | 狀態 |
|---|---|---|
| 無頭角色 | `Char.CreateDummy`／`DelDummy`／`IsDummy`；`Char.SetDummy` 只有「標記為假人」的說明，能否把真角色轉成掛機未驗證 | 部分已確認 |
| 角色永久資料 | `Char.SetExtData`／`GetExtData`（字串鍵，可存 JSON，存在 `hook_charaext` 表）、`Char.SaveToDb`；`SQL.QueryEx`（`?` 綁定）＋模組 migrations 自建表 | 【實測】登出、重啟都留得住；**`SetExtData` 不會馬上寫進資料庫，要接著 `SaveToDb`**；傳 nil 清除 |
| 採集 | `GatherItemEvent(c, 技能ID, 等級, itemId)` 回傳 itemId 可改產物；`TechArea.CreateTechArea(...)` 可在任意地圖建採集區（最多 10 種產物與機率）；技能 225 伐木／226 狩獵／227 挖掘 | 文件 |
| 製造 | `Recipe.GetData`／`GiveRecipe`／`HasRecipe`（對應 `data/itemrecipe.txt`）；`MergeItemEvent(c, 技能ID, 等級, itemIndex, 寶石)`，itemIndex=-1 是失敗；角色最多 64 個配方 | 已確認（資料表比對） |
| 技能經驗 | `Char.GetSkillExp`／`SetSkillExp(c, 技能欄位, exp)`（欄位用 `Char.HaveSkill` 取得）；`ProductSkillExpEvent`、`BattleSkillExpEvent`、`GetExpEvent` 回傳值可改經驗 | 推測／文件 |
| 封印抓寵 | `BATTLE_COM_CAPTURE`(5)；`SealEvent` 回傳正數＝成功、負數＝失敗原因（-3 寵物欄滿、-4 等級不足、-100 機率不足…）；`BattleSealRateEvent` 改機率 | 文件 |
| 寵物品質 | `Pet.GetArtRank` − `Pet.FullArtRank`＝檔數；`Pet.UpPet(player, pet)` 改完要同步 | 已確認 |
| 遇敵與連戰 | `Battle.Encount(p, p)` 原地遇敵（回負數＝此處不能遇敵）；`Battle.SetNextBattle(b, -2, flg)`＋`BattleNextEnemyEvent` 由 Lua 決定下一場 | 部分已確認 |
| 角色間交易 | `Char.TradeItem(from, 背包位置, to)`、`Char.TradePet(from, 寵物欄 0～4, to)`，回接收位置，<0 失敗 | 推測 |
| 背包與倉庫 | 4 頁背包 `GetBagPage`／`SwitchBag`／`ItemMoveBag`；銀行 `GetPoolItem`／`SetPoolItem`；出租屋 `GetHouseItem` | 背包已確認，倉庫推測 |
| 擺攤 | `Stall.Start`／`BuyItem`／`BuyPet`＋`CharaStallSoldEvent`；價格 table 格式要實測 | 文件 |
| 走路與定時 | `NLG.WalkMove(c, 方向0～7)` 走一格；`Char.SetWalkPostEvent`；`Char.SetLoopEvent(nil, 函式名, c, 毫秒)`；`Cron.AddInterval`／`AddCron`／`RunAt` | 部分已確認 |
| NPC 與視窗 | `NL.CreateArgNpc`、`NL.CreateNpc`；`NLG.ShowWindowTalked`；`Char.SetWindowTalkedEvent` 回呼 `(npc, talker, seqNo, select, data)` | 已確認 |
| 練功圖 | `Map.MakeCopyMap(mapId, floor)` 複製出獨立地圖 | 已確認 |
| 外部控制 | `Http.RegApi`／`Http.Start`＋`HttpRequestEvent`（現有 `Modules/http.lua` 聽 0.0.0.0:10086） | 已確認 |

## 事件鏈規則（`libs/GlobalEvents.lua`）

- 多個模組註冊同一事件時，依 `OrderedCallback(fn, order)` 的 order 由大到小執行；數值型事件（機率、經驗、傷害）依序累積。
- `ItemUseEvent`、`ItemPickUpEvent` 等任一回呼回 <0 即攔截；`TalkEvent` 回 nil 視為 1、回非 1 即攔截；`ProtocolOnRecv` 任一回呼回非 0 即攔截。

## 待實測

`Char.SetDummy`（真角色轉掛機）、`Char.TradeItem`／`TradePet`、`Char.SetSkillExp`、銀行格數、`Stall.Start` 價格格式、`Battle.SetNextBattle` 連戰、`Map.GetAvailablePos` 參數（本機舊腳本與上游文件不一致）、`Obj.*` 全部（本機零用例）、`ItemConsumeEvent` 回 0 是否讓消耗品不減少、`GatherItemEvent` 對假人是否有效（採集通常由遊戲端操作觸發）。
