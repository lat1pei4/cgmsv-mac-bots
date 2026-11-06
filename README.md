# cgmsv-mac-bots

在 Apple Silicon Mac 上用 Wine 架設魔力寶貝（Cross Gate）私服，並用 Lua 模組做自動戰鬥 AI 與無頭角色。個人研究專案。

- 伺服器：cgmsv 26.8d（Windows 版，Wine 執行）
- 用戶端：台版 7.1（Big5），經由 cgmsv 包裝程式連線
- 環境：macOS 26／Apple M5、Wine Staging 11.21（Gcenx 版）

**本 repo 只放自己寫的腳本、Lua 模組與筆記。** 遊戲用戶端、伺服器程式、遊戲資料、Wine 都不包含，需要自行準備（`.gitignore` 是白名單，只追蹤自己寫的檔案）。

## 做了什麼

| 項目 | 內容 |
|---|---|
| Wine 啟動 | Rosetta 的 AVX／BMI2 宣告、GDI 繪製避開 WoW64 OpenGL 崩潰、中文字型對應、一鍵啟動與正常關機存檔（`tools/run-*.sh`） |
| 繁體化 | 伺服器資料轉 Big5（OpenCC s2tw）、引擎內嵌訊息表修補（`tools/convert_big5.py`、`tools/patch_exe_msg.py`） |
| 遊戲端加速 | 代理 `winmm.dll`，inline hook `GetTickCount`／`Sleep`（`tools/speed/`） |
| 自動戰鬥 AI | 只用玩家畫面看得到的資訊：依技能等級選單體／強力／全體、集火殘血敵人、補血與復活、護衛、狀態魔法、補給用完自動回醫院（走到護士前補）、依對照實驗調整的逃跑判斷（`modules-src/autobattle.utf8.lua`） |
| 無頭角色 | 伺服器模組自己用 LuaJIT FFI 扮演遊戲端，讓真帳號不開遊戲就上線、組隊、自動練等；協定是明文（`modules-src/botlogin.utf8.lua`） |
| 管理網頁 | `http://127.0.0.1:10086/bots.html`：新增帳號（可自動建角色）、登入登出、自動戰鬥、練等、傳送、組隊（`modules-src/botpanel.utf8.lua`、`modules-src/www/bots.html`） |
| 無頭測試 | 隨機職業、技能組合、等級的假人隊伍大量對戰，含逃跑與不逃跑的雙胞胎對照（`modules-src/abtest.utf8.lua`） |
| API 參考 | cgmsv Lua 全部函式與事件的整理，含實測結果（`docs/api/`） |

## 資料夾

```
SETUP.md               安裝、日常操作、設計理由、卡關紀錄（從這裡開始看）
CLAUDE.md              給 AI 助手的作業守則（轉碼、部署、協定的實測結論）
cg_protocol_notes.md   早期調查的協定筆記（加密的部分不適用於 26.8d，實際是明文）
docs/api/              cgmsv Lua API 參考
server-b/modules-src/  Lua 模組原始碼（UTF-8；部署時轉成伺服器用的 GBK／Big5）
server-b/gmsv/         只追蹤 cgmsv.cf 與 ModuleConfig.lua
tools/                 啟動、轉碼、部署、封包查詢、冒煙測試
```

## 開發流程

```bash
bash tools/run-start.sh                     # 啟動伺服器（偶發啟動崩潰會自動重試）＋遊戲
bash tools/deploy-module.sh autobattle      # 轉碼 → LuaJIT 語法檢查 → 熱重載，不必重啟伺服器
python3 -I tools/bot_smoke.py               # bot 冒煙測試：登入、組隊、戰鬥、回醫院
python3 -I tools/pktlog.py aitest01 'LYIm'  # 查某帳號的封包收送順序
bash tools/run-stop.sh                      # 正常關機（存檔＋備份資料庫）
```

需要：Wine Staging（放在 `tools/Wine Staging.app`）、Python 3、`brew install luajit sqlite`。路徑寫死在 `tools/env.sh` 的 `CG_ROOT`。

## 注意

- 這是個人研究用的非官方專案，與遊戲營運方無關；魔力寶貝相關的商標與著作權屬於各自的權利人。
- 只在本機（127.0.0.1）測試過；管理網頁沒有登入機制，http 模組設定為只聽本機。

## 第三方

- `docs/api/upstream/`：取自 [Muscipular/cgmsv-lua](https://github.com/Muscipular/cgmsv-lua) 的 `docs/`，Apache License 2.0（全文見該資料夾的 `LICENSE`）。
