---自动战斗无头测试：伺服器启动 30 秒后同时建立 20 队假人（5 种组合 × 不同怪群），
---由 autobattle 指挥，各打 3 场；每场结束写一行摘要。测完把 loadModule('abtest') 拿掉即可。
local Module = ModuleBase:createModule('abtest')

local PARTIES, BATTLES_EACH, LV = 20, 3, 10
local PET = 1 -- 虎人

-- 职业模板：{名字, 图档, {{技能ID, 等级}...}, 带宠物}
local JOBS = {
  healer  = { '補師', 105285, { { 61, 3 }, { 62, 2 }, { 68, 2 }, { 67, 2 }, { 19, 2 } }, false },
  sword   = { '劍士', 105509, { { 0, 3 }, { 1, 3 }, { 3, 2 } }, true },
  mage    = { '法師', 105266, { { 19, 3 }, { 20, 3 }, { 21, 3 }, { 22, 3 }, { 23, 2 }, { 27, 1 } }, false },
  fighter = { '格鬥', 105102, { { 4, 3 }, { 5, 2 }, { 0, 2 } }, true },
  archer  = { '弓手', 120119, { { 95, 3 }, { 0, 2 } }, true },
}
local COMPS = {
  { 'healer', 'sword' }, { 'mage', 'fighter' }, { 'healer', 'mage', 'archer' }, { 'sword' }, { 'fighter', 'archer' },
}
local ENEMIES = { -- {怪物ID...}, {等级...}
  { { 40020, 40020, 40013, 40035 }, { 8, 8, 8, 10 } },  -- 树精×2、迷你蝙蝠、哥布林
  { { 40035 }, { 12 } },                                -- 单只哥布林
  { { 40020, 40020, 40013, 40013, 40035 }, { 6, 6, 6, 6, 8 } },
}

local parties = {}  -- [k] = {members = {...}, battles = 0, wins = 0, comp = '...'}
local leaderOf = {} -- [charIndex] = k

local function makeDummy(name, image, skills, withPet)
  local c = Char.CreateDummy()
  Char.SetData(c, CONST.CHAR_地图类型, 0)
  Char.SetData(c, CONST.CHAR_地图, 1000)
  Char.SetData(c, CONST.CHAR_X, 234)
  Char.SetData(c, CONST.CHAR_Y, 70)
  Char.SetData(c, CONST.CHAR_名字, name)
  Char.SetData(c, CONST.CHAR_形象, image)
  Char.SetData(c, CONST.CHAR_原形, image)
  Char.SetData(c, CONST.CHAR_原始图档, image)
  Char.SetData(c, CONST.CHAR_等级, LV)
  Char.SetData(c, CONST.CHAR_体力, 2000)
  Char.SetData(c, CONST.CHAR_力量, 1500)
  Char.SetData(c, CONST.CHAR_强度, 1000)
  Char.SetData(c, CONST.CHAR_速度, 1000)
  Char.SetData(c, CONST.CHAR_魔法, 1500)
  for _, s in ipairs(skills) do
    Char.AddSkill(c, s[1])
    Char.SetSkillLevel(c, Char.HaveSkill(c, s[1]), s[2])
  end
  if withPet then
    local pet = Char.GivePet(c, PET, 1)
    Char.SetData(pet, CONST.对象_等级, LV)
    Char.SetData(c, CONST.CHAR_战宠, 0)
    Pet.UpPet(c, pet)
  end
  getModule('autobattle'):setEnabled(c, true)
  return c
end

-- 像玩家回城休息：人和宠物补满血魔
local function rest(members)
  for _, c in ipairs(members) do
    NLG.UpChar(c) -- 先算出最大血魔
    for _, u in ipairs({ c, Char.GetPet(c, 0) }) do
      if u >= 0 then
        Char.SetData(u, CONST.对象_血, Char.GetData(u, CONST.对象_最大血))
        Char.SetData(u, CONST.对象_魔, Char.GetData(u, CONST.对象_最大魔))
      end
    end
    NLG.UpChar(c)
  end
end

local function partyIn(b)
  for slot = 0, 4 do
    local k = leaderOf[Battle.GetPlayer(b, slot)]
    if k then return k end
  end
end

-- 时间追踪（只追前 3 队）：找出每回合 6.5 秒花在哪个阶段
function Module:stamp(tag, b)
  local k = partyIn(b)
  if not k or k > 3 then
    return
  end
  local waiting = {}
  if tag == 'cmd' then -- autobattle 下完指令后，还在等指令的位置
    for slot = 0, 19 do
      local u = Battle.GetPlayer(b, slot)
      if u >= 0 and Battle.IsWaitingCommand(u) == 1 then
        table.insert(waiting, slot)
      end
    end
  end
  self:logInfo('t', tag, 'party=', k, 'b=', b, 'turn=', Battle.GetTurn(b), 'time=', os.time(),
    'clock=', string.format('%.3f', os.clock()), 'waiting=', table.concat(waiting, ','))
end

function Module:startBattle(k)
  local p = parties[k]
  rest(p.members)
  local e = ENEMIES[(k - 1) % #ENEMIES + 1]
  local b = Battle.PVE(p.members[1], p.members[1], nil, e[1], e[2])
  p.startedAt = os.time()
  if b < 0 then
    self:logInfo('PVE failed', k, b)
  end
end

function Module:setup()
  for k = 1, PARTIES do
    local comp = COMPS[(k - 1) % #COMPS + 1]
    local members = {}
    for i, job in ipairs(comp) do
      local j = JOBS[job]
      members[i] = makeDummy(j[1] .. k, j[2], j[3], j[4])
    end
    Char.SetData(members[1], CONST.对象_组队开关, 1)
    for i = 2, #members do
      Char.JoinParty(members[i], members[1], true)
    end
    parties[k] = { members = members, battles = 0, wins = 0, comp = table.concat(comp, '+') }
    leaderOf[members[1]] = k
    self:startBattle(k)
  end
  self:logInfo('setup', PARTIES, 'parties')
end

function Module:onBattleOver(b)
  local k = partyIn(b)
  if not k then
    return
  end
  local p = parties[k]
  local win = Battle.GetWinSide(b) == 0
  p.battles = p.battles + 1
  p.wins = p.wins + (win and 1 or 0)
  local hp = {}
  for _, c in ipairs(p.members) do
    table.insert(hp, string.format('%d/%d', Char.GetData(c, CONST.对象_血), Char.GetData(c, CONST.对象_最大血)))
  end
  self:logInfo('summary', 'party=', k, p.comp, 'enemies=', (k - 1) % #ENEMIES + 1, 'battle=', b,
    'turns=', Battle.GetTurn(b), 'secs=', os.time() - p.startedAt, win and 'WIN' or 'LOSE', 'hp=', table.concat(hp, ' '))
  if p.battles < BATTLES_EACH then
    Cron.RunAt(os.time() + 3, function() self:startBattle(k) end)
  else
    local finished = 0
    for _, q in ipairs(parties) do
      if q.battles >= BATTLES_EACH then finished = finished + 1 end
    end
    if finished == #parties then
      self:logInfo('done')
    end
  end
end

function Module:onLoad()
  self:logInfo('load')
  self:regCallback('BattleOverEvent', Func.bind(self.onBattleOver, self))
  self:regCallback('BattleStartEvent', function(b) self:stamp('start', b) end)
  self:regCallback('BeforeBattleTurnEvent', function(b) self:stamp('cmd', b) end)
  self:regCallback('BeforeBattleTurnStartEvent', function(b) self:stamp('proc', b) end)
  self:regCallback('AfterBattleTurnEvent', function(b) self:stamp('after', b) end)
  Cron.RunAt(os.time() + 30, function() self:setup() end)
end

function Module:onUnload()
  for _, p in ipairs(parties) do
    for _, c in ipairs(p.members) do
      Char.DelDummy(c)
    end
  end
  self:logInfo('unload')
end

return Module
