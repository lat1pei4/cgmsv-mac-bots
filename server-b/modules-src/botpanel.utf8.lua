---帐号管理页的 API（网页在 lua/www/bots.html，由 http 模组的 10086 埠提供）：
---GET /api/bots 列出帐号与角色状态；POST /api/botact {account, action, ...} 下指令；
---POST /api/botadd {account, password, slot, charname}（该位置没角色时用 charname 建立）、/api/botdel 增删帐号。
---编码：Iconv 只有伺服器语系（GBK）与 UTF-8 互转，台版游戏端打的角色名却是 Big5，
---所以讯息一律回英数代码（网页翻成中文），角色名回原始位元组的 hex（网页用 big5 解码），地图名（GBK）才用 Iconv 转。
local Module = ModuleBase:createModule('botpanel')

local GRIND_SECS = 3
-- 练等：练功地点 [floor, x, y] 记在角色的 ExtData（重启、重载、重新登入都还在）
local GRIND_KEY = 'grind'

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
    setSpot(c, req.on and here(c) or nil) -- 在哪里开就在哪里练
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
}
local NEED_ONLINE = { auto = true, hospital = true, encount = true, grind = true, warp = true, join = true, leave = true }

function Module:act(req)
  local a, fn = req.account, ACTIONS[req.action or '']
  if not validAccount(a) or not fn then return { ok = false, msg = 'bad_param' } end
  local c = onlineChar(a)
  if NEED_ONLINE[req.action] and c < 0 then return { ok = false, msg = 'offline' } end
  local ok, msg = fn(a, req, c)
  self:logInfo('act', a, req.action, tostring(ok))
  return { ok = ok and true or false, msg = msg }
end

-- 练等：练等中的角色（队长或单人）不在战斗中就遇敌；补给用完由 autobattle 送回东医，
-- 补完（或重新登入后）不在练功地点的地图就传回去
function Module:grind()
  local hospital = getModule('autobattle')
  for _, r in ipairs(getModule('botlogin'):accounts()) do
    local c = onlineChar(r.account)
    local spot = c >= 0 and spotOf(c)
    local leader = c >= 0 and Char.GetPartyMember(c, 0)
    if spot and (leader < 0 or leader == c) and Battle.GetCurrentBattle(c) < 0 and not hospital:busy(c) then
      if Char.GetData(c, CONST.CHAR_地图) == spot[1] then
        Battle.Encount(c, c)
      else
        Char.Warp(c, 0, spot[1], spot[2], spot[3]) -- 传队长，队员会跟着
      end
    end
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
  self.grindTask = Cron.AddInterval(GRIND_SECS * 1000, function() self:grind() end, 1)
end

function Module:onUnload()
  Cron.RemoveTask(self.grindTask)
  self:logInfo('unload')
end

return Module
