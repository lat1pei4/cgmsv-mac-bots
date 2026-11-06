---帐号管理页的 API（网页在 lua/www/bots.html，由 http 模组的 10086 埠提供）：
---GET /api/bots 列出帐号与角色状态；POST /api/botact {account, action, ...} 下指令；POST /api/botdetail {account} 角色详细；
---POST /api/botadd {account, password, slot, charname}（该位置没角色时用 charname 建立）、/api/botdel 增删帐号。
---编码：Iconv 只有伺服器语系（GBK）与 UTF-8 互转，台版游戏端打的角色名却是 Big5，
---所以讯息一律回英数代码（网页翻成中文），角色名回原始位元组的 hex（网页用 big5 解码），地图名（GBK）才用 Iconv 转。
local Module = ModuleBase:createModule('botpanel')

-- 练等：练功地点 [floor, x, y] 记在角色的 ExtData（重启、重载、重新登入都还在）
local GRIND_KEY = 'grind'
-- bot 用 NLG.WalkMove 走路引擎不会判定遇敌（实测 300 步 0 场），所以在练功点来回走、每步自己照遇敌率掷骰
local STEP_MS = 400        -- 一步的时间（和 autobattle 的 WALK_MS 一样）
local AFTER_BATTLE_MS = 2000 -- 战斗结束到再开始走（关战斗画面）
local ROAM = 5             -- 离练功点超过几格就算不在练功点（要走回去）
local DEFAULT_FIELD = 100 -- 在城里开练等（没有遇敌区）时去芙蕾雅
local LEVEL_MARGIN = 2    -- 自动选点的基准级：怪物最高等级不超过队伍平均等级 +2
-- 依实战表现换点（使用者指定）：每趟（练功点出发到回东医）打了几场、有没有人倒下，决定往上／往下换一级
local EASY_BATTLES = 6 -- 一趟打到这么多场算轻松
local EASY_TRIPS = 2   -- 连续几趟轻松才往上一级
local HARD_BATTLES = 3 -- 一趟打不到这么多场（或有人倒下）就往下一级
local MAX_ADJ = 3      -- 最多偏离基准级几级

-- 每行用 tab 分栏（保留空栏），全部转数字（非数字是 nil）
local function eachRow(path, fn)
  local f = io.open(path, 'r')
  if not f then return end
  for line in f:lines() do
    local v = {}
    for field in (line:gsub('\r', '') .. '\t'):gmatch('([^\t]*)\t') do table.insert(v, tonumber(field) or false) end
    fn(v)
  end
  f:close()
end

-- 遇敌区域与怪物等级（栏位用 Data.GetEncountData 和战斗封包对过）：
-- data/encount.txt：编号, _, mapid, floor, x1, y1, x2, y2, 遇敌率下限, 上限, 敌人数上限, 优先度, _, _, 群组 1～10
-- data/group.txt：_, _, 群组编号, _, _, 怪物 1～10；data/enemy.txt：名字, 设定, 怪物编号, _, 等级下限, 等级上限
local zones
local function loadZones()
  local lv, groups = {}, {}
  eachRow('data/enemy.txt', function(v) if v[3] and v[5] and v[6] then lv[v[3]] = { v[5], v[6] } end end)
  eachRow('data/group.txt', function(v)
    if v[3] then
      groups[v[3]] = {}
      for i = 6, 15 do if v[i] and v[i] > 0 then table.insert(groups[v[3]], v[i]) end end
    end
  end)
  zones = {}
  eachRow('data/encount.txt', function(v)
    if not (v[1] and v[4] and v[12]) then return end
    local z = { id = v[1], floor = v[4], x1 = v[5], y1 = v[6], x2 = v[7], y2 = v[8], min = v[9], max = v[10], z = v[12] }
    for i = 15, 24 do
      for _, e in ipairs(v[i] and groups[v[i]] or {}) do
        local r = lv[e]
        if r and r[2] > 1 then -- 等级 1～1 的是特殊版本（同名怪的捕捉用？），不算
          z.lo, z.hi = math.min(z.lo or r[1], r[1]), math.max(z.hi or r[2], r[2])
        end
      end
    end
    table.insert(zones, z)
  end)
end

---盖住这格、优先度最高的遇敌区域（城里回 nil）
local function zoneAt(floor, x, y)
  local best
  for _, z in ipairs(zones) do
    if z.floor == floor and x >= z.x1 and x <= z.x2 and y >= z.y1 and y <= z.y2 and (not best or z.z > best.z) then best = z end
  end
  return best
end

---这一格每步的遇敌率（%）：在区域的下限～上限之间取；没有区域回 0（autobattle 走路时也用）
local function encountRate(floor, x, y)
  local z = zoneAt(floor, x, y)
  return z and math.random(z.min, z.max) or 0
end

-- 芙蕾雅的练功范围：野外加上从芙蕾雅走得进去的洞（维诺亚洞穴、哈巴鲁东边洞穴、两个海底洞窟；使用者指定）。
-- 穿过海底洞窟到索奇亚是另一块大陆，不算。autobattle 的 TRAVEL_FLOORS 也要有这些图才算得出路线
local FIELD_OF = {}
for _, f in ipairs({ 100, 11000, 11001, 11002, 11003, 11004, 11005, 15003, 15004, 15005, 15592, 15593, 15594 }) do
  FIELD_OF[f] = true
end
local function sameField(a, b) return a == b or (FIELD_OF[a] and FIELD_OF[b]) or false end
-- 练功点那一格要从法兰城东门外（芙蕾雅那一侧）走得到：有些区域里有被围起来、走不进去的小块
local ANCHOR = { 100, 475, 196 }

---自动选练功点。把这张图（芙蕾雅含洞）的区域依「怪物最高等级」分级（同一个最高等级＝同一级）：
---基准级＝最高等级 ≤ 队伍等级 + LEVEL_MARGIN 里最强的一级，实际去基准级 + adj；
---ceil＝{最高等级, 队伍等级}：这一级打输过，队伍还是那个等级时不再去（升级后才再试）。
---同一级挑离 (nx, ny) 近的区域（跨图照出入口估路程），从区域中心往外找一格能走、而且确实属于这个区域的格子。
---回 { floor, x, y, true（自动）, 实际 adj, ceil 最高等级 or false, ceil 队伍等级 or false }，找不到回 nil
local function pickSpot(floor, partyLv, nx, ny, adj, ceil)
  local his, seen = {}, {}
  for _, z in ipairs(zones) do
    if sameField(floor, z.floor) and z.hi and not seen[z.hi] then
      seen[z.hi] = true
      table.insert(his, z.hi)
    end
  end
  if #his == 0 then return nil end
  table.sort(his)
  local base = 1
  for i, h in ipairs(his) do if h <= partyLv + LEVEL_MARGIN then base = i end end
  local i = math.max(1, math.min(#his, base + (adj or 0)))
  if ceil and ceil[1] and partyLv <= ceil[2] then
    while i > 1 and his[i] >= ceil[1] do i = i - 1 end
  else
    ceil = nil
  end
  local cands, hospital = {}, getModule('autobattle')
  for _, z in ipairs(zones) do
    if sameField(floor, z.floor) and z.hi == his[i] then
      local cx, cy = math.floor((z.x1 + z.x2) / 2), math.floor((z.y1 + z.y2) / 2)
      local d = hospital:distance(floor, nx, ny, z.floor, cx, cy) or math.huge
      table.insert(cands, { z = z, cx = cx, cy = cy, d = d })
    end
  end
  table.sort(cands, function(a, b) return a.d < b.d end)
  for _, c in ipairs(cands) do
    for r = 0, 15 do
      for dx = -r, r do
        for dy = -r, r do
          local x, y = c.cx + dx, c.cy + dy
          if math.max(math.abs(dx), math.abs(dy)) == r and NLG.Walkable(0, c.z.floor, x, y) == 1 and zoneAt(c.z.floor, x, y) == c.z
              and hospital:distance(ANCHOR[1], ANCHOR[2], ANCHOR[3], c.z.floor, x, y) then
            return { c.z.floor, x, y, true, i - base, ceil and ceil[1] or false, ceil and ceil[2] or false }
          end
        end
      end
    end
  end
  return nil
end

---队伍平均等级（取整）；没组队就是自己的等级
local function partyLevel(c)
  local sum, n = 0, 0
  for i = 0, 4 do
    local m = Char.GetPartyMember(c, i)
    if m >= 0 then sum, n = sum + Char.GetData(m, CONST.对象_等级), n + 1 end
  end
  if n == 0 then return Char.GetData(c, CONST.对象_等级) end
  return math.floor(sum / n)
end

local function spotOf(c)
  local raw = Char.GetExtData(c, GRIND_KEY)
  local ok, spot = pcall(JSON.decode, raw or '')
  return ok and type(spot) == 'table' and spot[3] and spot or nil
end

local function setSpot(c, spot)
  Char.SetExtData(c, GRIND_KEY, spot and JSON.encode(spot) or nil)
  Char.SaveToDb(c) -- SetExtData 不会马上写进资料库（实测）
end

local function here(c)
  return { Char.GetData(c, CONST.CHAR_地图), Char.GetData(c, CONST.CHAR_X), Char.GetData(c, CONST.CHAR_Y) }
end

local function reply(t)
  return JSON.encode(t)
end

local function hex(s)
  return (s or ''):gsub('.', function(ch) return string.format('%02x', ch:byte()) end)
end

local function validAccount(a)
  return type(a) == 'string' and a:match('^[%w_]+$') ~= nil and #a <= 16
end

local function charInfo(c)
  local floor = Char.GetData(c, CONST.CHAR_地图)
  local leader = Char.GetPartyMember(c, 0)
  return {
    nameHex = hex(Char.GetData(c, CONST.对象_名字)),
    lv = Char.GetData(c, CONST.对象_等级),
    face = Char.GetData(c, CONST.对象_脸),
    hp = Char.GetData(c, CONST.对象_血), maxHp = Char.GetData(c, CONST.对象_最大血),
    mp = Char.GetData(c, CONST.对象_魔), maxMp = Char.GetData(c, CONST.对象_最大魔),
    gold = Char.GetGold(c),
    floor = floor, x = Char.GetData(c, CONST.CHAR_X), y = Char.GetData(c, CONST.CHAR_Y),
    mapName = Iconv.ToUtf8(NLG.GetMapName(0, floor) or ''),
    battle = Battle.GetCurrentBattle(c) >= 0,
    auto = Char.GetData(c, CONST.对象_自动战斗开关) == 1,
    leaderHex = leader >= 0 and hex(Char.GetData(leader, CONST.对象_名字)) or nil,
    isLeader = leader == c,
  }
end

function Module:list()
  local login = getModule('botlogin')
  local out = {}
  for _, r in ipairs(login:accounts()) do
    local st = login:status(r.account)
    local item = { account = r.account, slot = tonumber(r.slot), autologin = tonumber(r.autologin) == 1,
      charname = r.charname,
      state = st and st.state or 'offline', err = st and st.err }
    if st and st.state == 'online' and st.char >= 0 then
      item.char = charInfo(st.char)
      item.activity = spotOf(st.char) and 'grind' or nil
    end
    table.insert(out, item)
  end
  return out
end

local function onlineChar(account)
  local st = getModule('botlogin'):status(account)
  return st and st.state == 'online' and st.char or -1
end

-- 配点方式：预设自动（人物攻敏、宠物纯攻）；网页关掉就改手动配（使用者指定），人物与宠物一起，记在 ExtData（重启、重新登入都在）
local MANUAL_KEY = 'manualpoints'
local function manualPoints(c) return Char.GetExtData(c, MANUAL_KEY) == '1' end

-- 资料表的名字（Big5 原样）：GM 发的道具／宠物存档后名字是空的（tbl_item TrueName、tbl_pet Name 实测为空），网页显示时用这里补
local ITEM_NAMES, PET_NAMES = {}, {}
local function loadNames()
  local function each(path, fn)
    local f = io.open(path, 'r')
    if not f then return end
    for line in f:lines() do
      local v = {}
      for field in (line:gsub('\r', '') .. '\t'):gmatch('([^\t]*)\t') do table.insert(v, field) end
      fn(v)
    end
    f:close()
  end
  each('data/itemset.txt', function(v) if tonumber(v[12]) and v[2] ~= '' then ITEM_NAMES[tonumber(v[12])] = v[2] end end)
  each('data/enemybase.txt', function(v) if tonumber(v[2]) and v[1] ~= '' then PET_NAMES[tonumber(v[2])] = v[1] end end)
end

-- 角色详细（网页点角色时显示，像游戏里的状态／道具／宠物视窗）：道具名、宠物名、招式名是 Big5，回 hex
local BASE = { { 'vit', CONST.对象_体力 }, { 'str', CONST.对象_力量 }, { 'tgh', CONST.对象_强度 },
  { 'agi', CONST.对象_速度 }, { 'mag', CONST.对象_魔法 } }
local function unitInfo(u)
  local t = {
    nameHex = hex(Char.GetData(u, CONST.对象_名字)), lv = Char.GetData(u, CONST.对象_等级),
    img = Char.GetData(u, CONST.对象_形象), face = Char.GetData(u, CONST.对象_脸), -- 图号（网页用 tools/cg_graphic.py 解出的 img/<图号>.png）
    exp = Char.GetData(u, CONST.对象_经验), nextExp = Char.GetNextExp(u),
    hp = Char.GetData(u, CONST.对象_血), maxHp = Char.GetData(u, CONST.对象_最大血),
    mp = Char.GetData(u, CONST.对象_魔), maxMp = Char.GetData(u, CONST.对象_最大魔),
    atk = Char.GetData(u, CONST.对象_攻击力), def = Char.GetData(u, CONST.对象_防御力), quick = Char.GetData(u, CONST.对象_敏捷),
    spi = Char.GetData(u, CONST.对象_精神), rec = Char.GetData(u, CONST.对象_回复),
    crit = Char.GetData(u, CONST.对象_必杀), counter = Char.GetData(u, CONST.对象_反击),
    hit = Char.GetData(u, CONST.对象_命中), dodge = Char.GetData(u, CONST.对象_闪躲),
    earth = Char.GetData(u, CONST.对象_地属性), water = Char.GetData(u, CONST.对象_水属性),
    fire = Char.GetData(u, CONST.对象_火属性), wind = Char.GetData(u, CONST.对象_风属性),
    injury = Char.GetData(u, CONST.对象_受伤), points = Char.GetData(u, CONST.对象_升级点),
  }
  for _, b in ipairs(BASE) do t[b[1]] = Char.GetData(u, b[2]) / 100 end
  return t
end

local function itemInfo(c, slot)
  local it = Char.GetItemIndex(c, slot)
  if it < 0 then return nil end
  return {
    slot = slot, lv = Item.GetData(it, CONST.道具_等级),
    nameHex = hex(Item.GetData(it, CONST.道具_名字) ~= '' and Item.GetData(it, CONST.道具_名字) or ITEM_NAMES[Item.GetData(it, CONST.道具_ID)]),
    img = Item.GetData(it, CONST.道具_图),
    n = Item.GetData(it, CONST.道具_堆叠数), dur = Item.GetData(it, CONST.道具_耐久), maxDur = Item.GetData(it, CONST.道具_最大耐久),
    atk = Item.GetData(it, CONST.道具_攻击), def = Item.GetData(it, CONST.道具_防御), quick = Item.GetData(it, CONST.道具_敏捷),
    spi = Item.GetData(it, CONST.道具_精神), rec = Item.GetData(it, CONST.道具_回复),
  }
end

function Module:detail(account)
  if not validAccount(account) then return { ok = false, msg = 'bad_param' } end
  local c = onlineChar(account)
  if c < 0 then return { ok = false, msg = 'offline' } end
  local me = unitInfo(c)
  me.gold, me.autoPoints = Char.GetGold(c), not manualPoints(c)
  local items, pets = {}, {}
  for slot = 0, 27 do table.insert(items, itemInfo(c, slot)) end
  local battlePet = Char.GetData(c, CONST.对象_战宠)
  for slot = 0, 4 do
    local p = Char.GetPet(c, slot)
    if p >= 0 then
      local t = unitInfo(p)
      if t.nameHex == '' then t.nameHex = hex(PET_NAMES[Char.GetData(p, CONST.宠物_PETID)]) end
      t.slot, t.battle, t.loyal, t.skills = slot, battlePet == slot, Char.GetData(p, CONST.宠物_忠诚), {}
      t.state = Char.GetData(p, CONST.对象_PET_DepartureBattleStatus)
      -- 掉档：满档成长 - 目前成长（Pet.FullArtRank - Pet.GetArtRank），0＝满档
      t.drop = {}
      for _, a in ipairs({ CONST.宠档_体成, CONST.宠档_力成, CONST.宠档_强成, CONST.宠档_敏成, CONST.宠档_魔成 }) do
        table.insert(t.drop, Pet.FullArtRank(p, a) - Pet.GetArtRank(p, a))
      end
      for k = 0, Char.GetData(p, CONST.宠物_技能栏) - 1 do
        local id = Pet.GetSkill(p, k)
        local ti = id >= 0 and Tech.GetTechIndex(id) or -1
        if ti >= 0 then table.insert(t.skills, (hex(Tech.GetData(ti, CONST.TECH_NAME)))) end
      end
      table.insert(pets, t)
    end
  end
  return { ok = true, char = me, items = items, pets = pets }
end

-- 国民装＋宠物（使用者指定「A（国民装）、GM 发、宠都可」）：道具 ID 是法兰城武器店／防具店卖的 Lv1 国民系列（data/itemset.txt）
-- 只补空的装备栏、没宠物才给，重复执行不会多发；放不进装备栏的就删掉（不然回城会被当杂物卖）
local OUTFIT = {
  { 900, CONST.道栏_左手 },  -- 国民斧（攻 3）
  { 6500, CONST.道栏_右手 }, -- 国民盾
  { 3701, CONST.道栏_头位 }, -- 国民头盔
  { 4500, CONST.道栏_身位 }, -- 国民铠
  { 18222, CONST.道栏_脚位 }, -- 国民鞋（靴类的纸靴 5605 实测装不上，鞋类可以）
}
local STARTER_PET = 1003 -- 哥布林（enemy.txt，城外 1003／1004 区会出现）；GivePet 给的是 1 级
local function outfit(c)
  local done = {}
  for _, e in ipairs(OUTFIT) do
    if Char.GetItemIndex(c, e[2]) < 0 then
      if Char.GiveItem(c, e[1], 1, false) < 0 then return false, 'bag_full' end
      local slot = Char.FindItemId(c, e[1])
      if Char.MoveItem(c, slot, e[2], -1) ~= 1 then
        Char.DelItemBySlot(c, slot)
        return false, 'equip_failed_' .. e[1]
      end
      done[#done + 1] = e[1]
    end
  end
  if Char.GetPet(c, 0) < 0 then
    if Char.GivePet(c, STARTER_PET) < 0 then return false, 'pet_failed' end
    Char.SetPetDepartureState(c, 0, CONST.宠物状态_战斗)
    done[#done + 1] = 'pet'
  end
  NLG.UpChar(c)
  return true, #done > 0 and table.concat(done, ',') or 'already'
end

local STATS = { vit = CONST.对象_体力, str = CONST.对象_力量, tgh = CONST.对象_强度, agi = CONST.对象_速度, mag = CONST.对象_魔法 }
local PET_STATES = { [CONST.宠物状态_待命] = true, [CONST.宠物状态_战斗] = true, [CONST.宠物状态_休息] = true }

local function emptyBagSlot(c)
  for slot = 8, 27 do
    if Char.GetItemIndex(c, slot) < 0 then return slot end
  end
end

-- 穿装备（网页点背包道具）：先试空的装备栏，再试有东西的栏（原本那件先脱到背包，穿不上就放回）；
-- 哪一格能放由引擎判断（Char.MoveItem 放不进去回非 1，实测纸靴放脚位会失败）
local function equip(c, from)
  for _, occupied in ipairs({ false, true }) do
    for to = 0, 7 do
      if (Char.GetItemIndex(c, to) >= 0) == occupied then
        local back = occupied and emptyBagSlot(c)
        if not occupied or (back and Char.MoveItem(c, to, back, -1) == 1) then
          if Char.MoveItem(c, from, to, -1) == 1 then return true end
          if back then Char.MoveItem(c, back, to, -1) end
        end
      end
    end
  end
  return false
end

-- 每个指令回 (成功, 讯息代码)
local ACTIONS = {
  login = function(a) return getModule('botlogin'):login(a), 'login' end,
  logout = function(a) return getModule('botlogin'):logout(a), 'logout' end,
  autologin = function(a, req) getModule('botlogin'):setAutologin(a, req.on); return true, 'saved' end,
  auto = function(a, req, c)
    getModule('autobattle'):setAuto(c, req.on)
    return true, req.on and 'auto_on' or 'auto_off'
  end,
  hospital = function(a, req, c)
    return getModule('autobattle'):toHospital(c), 'hospital'
  end,
  encount = function(a, req, c)
    return Battle.Encount(c, c) >= 0, 'encount'
  end,
  grind = function(a, req, c)
    -- 练功点：有给 floor/x/y 就固定用它；没给就照队伍等级自动选（这张图没有遇敌区就去芙蕾雅），升级后会自动换点。
    -- 不在练功点会先算脚程再过去
    local spot
    if req.on and req.floor then
      spot = { tonumber(req.floor), tonumber(req.x), tonumber(req.y) }
      if not (spot[1] and spot[2] and spot[3] and NLG.Walkable(0, spot[1], spot[2], spot[3]) == 1) then return false, 'bad_pos' end
    elseif req.on then
      local p = here(c)
      local floor = zoneAt(p[1], p[2], p[3]) and p[1] or DEFAULT_FIELD
      spot = pickSpot(floor, partyLevel(c), p[2], p[3])
      if not spot then return false, 'bad_pos' end
    end
    setSpot(c, spot)
    return true, req.on and 'grind_on' or 'grind_off'
  end,
  warp = function(a, req, c)
    local floor, x, y = tonumber(req.floor), tonumber(req.x), tonumber(req.y)
    if not (floor and x and y) or NLG.Walkable(0, floor, x, y) ~= 1 then return false, 'bad_pos' end
    local ok = Char.Warp(c, 0, floor, x, y) == 1
    if ok and spotOf(c) then setSpot(c, { floor, x, y }) end -- 练等中传送＝换练功地点
    return ok, 'warped'
  end,
  join = function(a, req, c)
    if not validAccount(req.leader) then return false, 'bad_leader' end
    local leader = onlineChar(req.leader)
    if leader < 0 then return false, 'leader_offline' end
    if Char.GetPartyMember(leader, 0) < 0 then Char.SetData(leader, CONST.对象_组队开关, 1) end
    return Char.JoinParty(c, leader, true) ~= false, 'joined'
  end,
  leave = function(a, req, c) Char.LeaveParty(c); return true, 'left' end,
  outfit = function(a, req, c) return outfit(c) end,
  autopoints = function(a, req, c)
    Char.SetExtData(c, MANUAL_KEY, (not req.on) and '1' or nil)
    Char.SaveToDb(c) -- SetExtData 不会马上写进资料库（实测）
    return true, req.on and 'autopoints_on' or 'autopoints_off'
  end,
  -- 手动配点：{stat = vit/str/tgh/agi/mag, pet = 宠物栏 0～4（不给＝人物）, n = 点数}
  addpoint = function(a, req, c)
    if not manualPoints(c) then return false, 'autopoints' end
    local stat, u = STATS[req.stat or ''], c
    if req.pet ~= nil then u = Char.GetPet(c, tonumber(req.pet) or -1) end
    local n, pts = math.floor(tonumber(req.n) or 1), u >= 0 and Char.GetData(u, CONST.对象_升级点) or 0
    if not stat or u < 0 then return false, 'bad_param' end
    if n < 1 or n > pts then return false, 'no_points' end
    Char.SetData(u, stat, Char.GetData(u, stat) + n * 100)
    Char.SetData(u, CONST.对象_升级点, pts - n)
    if u == c then NLG.UpChar(c) else Pet.UpPet(c, u) end
    return true, 'point_added'
  end,
  -- 宠物状态 {slot, state = 1 待命／2 出战／3 休息}；出战只能一只，原本出战的改待命
  petstate = function(a, req, c)
    local slot, state = tonumber(req.slot), tonumber(req.state)
    if not (slot and state and PET_STATES[state]) or Char.GetPet(c, slot) < 0 then return false, 'bad_param' end
    if state == CONST.宠物状态_战斗 then
      for s = 0, 4 do
        local p = Char.GetPet(c, s)
        if s ~= slot and p >= 0 and Char.GetData(p, CONST.对象_PET_DepartureBattleStatus) == CONST.宠物状态_战斗 then
          Char.SetPetDepartureState(c, s, CONST.宠物状态_待命)
        end
      end
    end
    return Char.SetPetDepartureState(c, slot, state) == 1, 'pet_state'
  end,
  -- 脱装备 {slot = 0～7} 放到背包第一个空格；穿装备 {slot = 背包 8～27}
  unequip = function(a, req, c)
    local slot, to = tonumber(req.slot), emptyBagSlot(c)
    if not slot or slot < 0 or slot > 7 or Char.GetItemIndex(c, slot) < 0 then return false, 'bad_param' end
    if not to then return false, 'bag_full' end
    local ok = Char.MoveItem(c, slot, to, -1) == 1
    NLG.UpChar(c)
    return ok, 'unequipped'
  end,
  -- 丢弃背包道具 {slot = 8～27}（使用者指定）：直接删掉，不掉在地上
  discard = function(a, req, c)
    local slot = tonumber(req.slot)
    if not slot or slot < 8 or slot > 27 or Char.GetItemIndex(c, slot) < 0 then return false, 'bad_param' end
    Char.DelItemBySlot(c, slot)
    NLG.UpChar(c)
    return true, 'discarded'
  end,
  equip = function(a, req, c)
    local slot = tonumber(req.slot)
    if not slot or slot < 8 or slot > 27 or Char.GetItemIndex(c, slot) < 0 then return false, 'bad_param' end
    local ok = equip(c, slot)
    NLG.UpChar(c)
    return ok, ok and 'equipped' or 'equip_failed'
  end,
}
local NEED_ONLINE = { auto = true, hospital = true, encount = true, grind = true, warp = true, join = true, leave = true, outfit = true,
  autopoints = true, addpoint = true, petstate = true, unequip = true, equip = true, discard = true }

function Module:encountRate(floor, x, y)
  return encountRate(floor, x, y)
end

function Module:act(req)
  local a, fn = req.account, ACTIONS[req.action or '']
  if not validAccount(a) or not fn then return { ok = false, msg = 'bad_param' } end
  local c = onlineChar(a)
  if NEED_ONLINE[req.action] and c < 0 then return { ok = false, msg = 'offline' } end
  local ok, msg = fn(a, req, c)
  self:logInfo('act', a, req.action, tostring(ok))
  return { ok = ok and true or false, msg = msg }
end

-- 升级点数：每 4 点力量、速度各加 2（使用者指定「攻敏各2」）；能力值内部单位是点数×100（实测：速度 15 点存 1500）
local BUILD = { { CONST.对象_力量, 2 }, { CONST.对象_速度, 2 } }
local function spendPoints(c)
  local mag = Char.GetData(c, CONST.对象_魔法)
  if mag > 0 and Char.GetExtData(c, 'magmoved') ~= '1' then -- 旧版建角色配了魔法 15（bot 只普攻用不到），改配到力量；只转一次
    Char.SetData(c, CONST.对象_魔法, 0)
    Char.SetData(c, CONST.对象_力量, Char.GetData(c, CONST.对象_力量) + mag)
    NLG.UpChar(c)
  end
  if Char.GetExtData(c, 'magmoved') ~= '1' then -- 转过（或本来就没魔法）就记下，之后手动配的魔法不会被转走
    Char.SetExtData(c, 'magmoved', '1')
    Char.SaveToDb(c)
  end
  local pts = Char.GetData(c, CONST.对象_升级点)
  if pts < 4 then return end
  local n = math.floor(pts / 4)
  for _, b in ipairs(BUILD) do Char.SetData(c, b[1], Char.GetData(c, b[1]) + b[2] * n * 100) end
  Char.SetData(c, CONST.对象_升级点, pts - 4 * n)
  NLG.UpChar(c)
end

-- 宠物配点（使用者指定「纯攻」）：升级点全加力量
local function spendPetPoints(c)
  for slot = 0, 4 do
    local pet = Char.GetPet(c, slot)
    local pts = pet >= 0 and Char.GetData(pet, CONST.对象_升级点) or 0
    if pts > 0 then
      Char.SetData(pet, CONST.对象_力量, Char.GetData(pet, CONST.对象_力量) + pts * 100)
      Char.SetData(pet, CONST.对象_升级点, 0)
      Pet.UpPet(c, pet)
      Module:logInfo('pet points', Char.GetData(c, CONST.对象_名字), Char.GetData(pet, CONST.对象_等级), pts,
        'maxHp', Char.GetData(pet, CONST.对象_最大血))
    end
  end
end

-- 宠物等级跟上主人（使用者指定）：直接改等级能力值不会跟着长（实测），改灌经验让引擎自己升（实测一场连升 4 级）。
-- 经验是「这一级累积的」，Char.GetLevelExp(k) 是 k-1 升 k 要的量（实测对得上），所以灌到主人等级为止的总和
local function syncPetLevel(c)
  local lv, name = Char.GetData(c, CONST.对象_等级), Char.GetData(c, CONST.对象_名字)
  for slot = 0, 4 do
    local pet = Char.GetPet(c, slot)
    local plv = pet >= 0 and Char.GetData(pet, CONST.对象_等级)
    if plv and plv < lv then
      local need = 0
      for k = plv + 1, lv do need = need + Char.GetLevelExp(k) end
      if Char.GetData(pet, CONST.对象_经验) < need then
        Char.SetData(pet, CONST.对象_经验, need)
        Pet.UpPet(c, pet)
        Module:logInfo('pet exp', name, plv, lv, need)
      end
    end
  end
end

-- 整队往 st.dir 走一步，下一步换反方向（在练功点东西来回）
local function walkStep(c, st)
  local x = Char.GetData(c, CONST.CHAR_X)
  NLG.WalkMove(c, st.dir)
  if Char.GetData(c, CONST.CHAR_X) ~= x then
    for i = 1, 4 do
      local m = Char.GetPartyMember(c, i)
      if m >= 0 then NLG.WalkMove(m, st.dir) end
    end
  end
  st.dir = st.dir == 2 and 6 or 2
end

-- 练等（每步跑一次）：练等中的角色（队长或单人）不在战斗、不在回东医途中时——
-- 在练功点附近：整队来回走，每步照这格的遇敌率掷骰，中了才遇敌；战斗结束先停 AFTER_BATTLE_MS。
-- 不在练功点（补完血、重新登入、换练功点）：整队走回去（autobattle:travelTo，路上会遇敌、会用开过的村庄传送点）
local roam = {} -- [charIndex] = { dir = 下一步方向, rest = 还要停几步, battles/ko = 这一趟的战绩, easy = 连续轻松几趟 }

---一趟结束（开始回东医）：照这趟的战绩调 adj，换了级就改练功点（补完血直接走去新点）
function Module:judgeTrip(c, st, spot, account)
  local b, ko, adj = st.battles or 0, st.ko == true, spot[5] or 0
  local ceil = spot[6] and { spot[6], spot[7] } or nil
  st.battles, st.ko = 0, false
  if st.partial then -- 模组重载／重新登入后的第一趟是从半路开始算的，不拿来判断
    st.partial = false
    self:logInfo('trip', account, 'battles', b, 'partial, skip')
    return
  end
  local verdict = 'keep'
  if ko or b < HARD_BATTLES then
    verdict, st.easy, adj = 'down', 0, math.max(-MAX_ADJ, adj - 1)
    local z = zoneAt(spot[1], spot[2], spot[3])
    ceil = z and { z.hi, partyLevel(c) } or ceil
  elseif b >= EASY_BATTLES then
    st.easy = (st.easy or 0) + 1
    if st.easy >= EASY_TRIPS then verdict, st.easy, adj = 'up', 0, math.min(MAX_ADJ, adj + 1) end
  else
    st.easy = 0
  end
  self:logInfo('trip', account, 'battles', b, 'ko', tostring(ko), verdict, 'adj', adj)
  if verdict == 'keep' then return end
  local new = pickSpot(spot[1], partyLevel(c), spot[2], spot[3], adj, ceil)
  if new then
    setSpot(c, new)
    local z = zoneAt(new[1], new[2], new[3])
    self:logInfo('auto spot', account, verdict, new[1], new[2], new[3], z.id, 'hi', z.hi, 'adj', new[5])
  end
end
function Module:grind()
  local hospital = getModule('autobattle')
  local live = {}
  for _, r in ipairs(getModule('botlogin'):accounts()) do
    local c = onlineChar(r.account)
    if c >= 0 and Battle.GetCurrentBattle(c) < 0 then
      if not manualPoints(c) then
        spendPoints(c)
        spendPetPoints(c)
      end
      syncPetLevel(c)
    end
    local spot = c >= 0 and spotOf(c)
    local leader = c >= 0 and Char.GetPartyMember(c, 0)
    if spot and (leader < 0 or leader == c) then
      live[c] = true
      local st = roam[c] or { dir = 2, rest = 0, partial = true }
      roam[c] = st
      local lv = spot[4] and partyLevel(c)
      if lv and lv ~= st.lv then -- 自动选点：队伍等级变了就重选（不同点就换过去，也是算脚程）
        st.lv = lv
        local new = pickSpot(spot[1], lv, spot[2], spot[3], spot[5], spot[6] and { spot[6], spot[7] } or nil)
        if new and (new[1] ~= spot[1] or new[2] ~= spot[2] or new[3] ~= spot[3]) then
          setSpot(c, new)
          spot = new
          self:logInfo('auto spot', r.account, lv, new[1], new[2], new[3], zoneAt(new[1], new[2], new[3]).id)
        end
      end
      -- 战绩：一场打完记一场；打完有人血剩 1 以下（倒下）记 ko
      local inBattle = Battle.GetCurrentBattle(c) >= 0
      if inBattle then
        st.fighting = true
      elseif st.fighting then
        st.fighting = false
        if not hospital:isWalking(c) then -- 走路途中遇到的不算这一趟练功的战绩
          st.battles = (st.battles or 0) + 1
          for i = 0, 4 do
            local m = Char.GetPartyMember(c, i)
            if (m >= 0 or i == 0) and Char.GetData(m >= 0 and m or c, CONST.对象_血) <= 1 then st.ko = true end
          end
        end
      end
      if spot[4] and hospital:busy(c) and ((st.battles or 0) > 0 or st.ko) then
        self:judgeTrip(c, st, spot, r.account)
      end
      if inBattle then
        st.rest = AFTER_BATTLE_MS / STEP_MS
      elseif not hospital:busy(c) then
        local p = here(c)
        if p[1] ~= spot[1] or math.max(math.abs(p[2] - spot[2]), math.abs(p[3] - spot[3])) > ROAM then
          local secs = hospital:travelTo(c, spot[1], spot[2], spot[3], function() end, 'spot')
          self:logInfo('to spot', r.account, secs)
        elseif st.rest > 0 then
          st.rest = st.rest - 1
        else
          walkStep(c, st)
          if math.random(100) <= encountRate(p[1], p[2], p[3]) then Battle.Encount(c, c) end
        end
      end
    end
  end
  for c in pairs(roam) do
    if not live[c] then roam[c] = nil end
  end
end

local function body(raw)
  local ok, t = pcall(JSON.decode, raw or '')
  return ok and type(t) == 'table' and t or {}
end

function Module:onLoad()
  self:logInfo('load')
  local http = getModule('http')
  http:regApi('get', 'bots', function() return reply(self:list()) end)
  http:regApi('post', 'botact', function(_, raw) return reply(self:act(body(raw))) end)
  http:regApi('post', 'botdetail', function(_, raw) return reply(self:detail(body(raw).account)) end)
  http:regApi('post', 'botadd', function(_, raw)
    local t = body(raw)
    if not validAccount(t.account) or not validAccount(t.password) then return reply({ ok = false, msg = 'bad_account' }) end
    -- 网页没办法产生 Big5，角色名先限英数字（中文名在游戏端建立）
    local name = t.charname ~= nil and t.charname ~= '' and t.charname or nil
    if name and not validAccount(name) then return reply({ ok = false, msg = 'bad_charname' }) end
    local slot = tonumber(t.slot) == 1 and 1 or 0
    return reply({ ok = getModule('botlogin'):addAccount(t.account, t.password, slot, name), msg = 'added' })
  end)
  http:regApi('post', 'botdel', function(_, raw)
    local t = body(raw)
    if not validAccount(t.account) then return reply({ ok = false, msg = 'bad_param' }) end
    return reply({ ok = getModule('botlogin'):removeAccount(t.account), msg = 'deleted' })
  end)
  loadZones()
  loadNames()
  self:logInfo('encount zones', #zones)
  self.grindTask = Cron.AddInterval(STEP_MS, function() self:grind() end, 1)
end

function Module:onUnload()
  Cron.RemoveTask(self.grindTask)
  self:logInfo('unload')
end

return Module
