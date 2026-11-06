---自动战斗无头测试（多样性）：伺服器启动 30 秒后同时建立 PARTIES 队假人（随机职业 1～4 人、随机技能组合、4 种等级），
---技能等级随等级浮动；每场随机挑怪群，敌人等级 = 我方等级 -5～+10，每 4 场有 1 场 +25（测逃跑）。
---由 autobattle 指挥，各打 BATTLES_EACH 场；每场结束写一行 summary。测完把 loadModule('abtest') 拿掉即可。
local Module = ModuleBase:createModule('abtest')

local PARTIES, BATTLES_EACH = 24, 4
local LEVELS = { 5, 20, 40, 70 }
local PET = 1 -- 虎人

-- 职业：{名字, 图档, 必带技能, 选配技能池, 带宠物}；每个假人从选配池随机抽 1～3 个，队伍 1～4 人随机职业
local JOBS = {
  { '劍士', 105509, { 0 }, { 1, 3, 5 }, true },
  { '戰斧', 105102, { 3 }, { 0, 1, 5 }, true },
  { '騎士', 105509, { 5 }, { 0, 1, 7 }, true },
  { '弓手', 120119, { 95 }, { 0, 1, 3 }, true },
  { '格鬥', 105102, { 4 }, { 0, 5, 1 }, true },
  { '傳教', 105285, { 61 }, { 62, 63, 67, 68, 19 }, false },
  { '巫師', 105285, { 61 }, { 64, 67, 68, 20 }, false },
  { '法師', 105266, { 19 }, { 20, 21, 22, 23, 24, 25, 27, 28 }, false },
  { '咒術', 105266, { 33 }, { 19, 20, 36, 32 }, false },
}
local MAX_PARTY = 4
local ENEMY_SETS = { -- 怪物 ID
  { 40020, 40020, 40013, 40035 }, -- 树精×2、迷你蝙蝠、哥布林
  { 40035 },                      -- 单只哥布林
  { 40020, 40020, 40013, 40013, 40035 },
  { 40035, 40035, 40013 },
}

local parties = {}  -- [k] = {members, lv, comp, battles, setup...}
local battleOf = {} -- [battleIndex] = k；逃跑后队长已不在战场上，靠这张表找队伍

local function clamp(x, lo, hi)
  return math.max(lo, math.min(hi, x))
end

local function copy(t)
  local r = {}
  for i, x in ipairs(t) do r[i] = x end
  return r
end

local function pickSkills(job)
  local skills, pool = copy(job[3]), copy(job[4])
  for _ = 1, math.random(1, math.min(3, #pool)) do
    table.insert(skills, table.remove(pool, math.random(1, #pool)))
  end
  return skills
end

local function makeDummy(name, image, skills, withPet, lv)
  local c = Char.CreateDummy()
  Char.SetData(c, CONST.CHAR_地图类型, 0)
  Char.SetData(c, CONST.CHAR_地图, 1000)
  Char.SetData(c, CONST.CHAR_X, 234)
  Char.SetData(c, CONST.CHAR_Y, 70)
  Char.SetData(c, CONST.CHAR_名字, name)
  Char.SetData(c, CONST.CHAR_形象, image)
  Char.SetData(c, CONST.CHAR_原形, image)
  Char.SetData(c, CONST.CHAR_原始图档, image)
  Char.SetData(c, CONST.CHAR_等级, lv)
  local bp = (10 + lv) * 100 -- 能力值随等级成长（每 100 = 1 点）
  Char.SetData(c, CONST.CHAR_体力, bp * 1.3)
  Char.SetData(c, CONST.CHAR_力量, bp)
  Char.SetData(c, CONST.CHAR_强度, bp * 0.7)
  Char.SetData(c, CONST.CHAR_速度, bp * 0.7)
  Char.SetData(c, CONST.CHAR_魔法, bp)
  local skillLv = {}
  for _, id in ipairs(skills) do
    local sl = clamp(math.floor(lv / 10) + 1 + math.random(-1, 1), 1, 10)
    Char.AddSkill(c, id)
    Char.SetSkillLevel(c, Char.HaveSkill(c, id), sl)
    table.insert(skillLv, id .. ':' .. sl)
  end
  if withPet then
    local pet = Char.GivePet(c, PET, 1)
    Char.SetData(pet, CONST.对象_等级, lv)
    Char.SetData(c, CONST.CHAR_战宠, 0)
    Pet.UpPet(c, pet)
  end
  getModule('autobattle'):setEnabled(c, true)
  return c, table.concat(skillLv, ' ')
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

function Module:startBattle(k)
  local p = parties[k]
  rest(p.members)
  local set = ENEMY_SETS[math.random(1, #ENEMY_SETS)]
  local strong = (p.battles + k) % 4 == 0
  local base = p.lv + (strong and 25 or math.random(-5, 10))
  local lvs = {}
  for i = 1, #set do
    lvs[i] = clamp(base + math.random(-2, 2), 1, 160)
  end
  p.enemyDesc = string.format('n=%d lv=%d%s', #set, base, strong and '(strong)' or '')
  local b = Battle.PVE(p.members[1], p.members[1], nil, set, lvs)
  p.startedAt, p.battle = os.time(), b
  if b < 0 then
    self:logInfo('PVE failed', k, b)
  else
    battleOf[b] = k
  end
end

function Module:setup()
  math.randomseed(os.time())
  for k = 1, PARTIES do
    local lv = LEVELS[(k - 1) % #LEVELS + 1]
    local members, comp = {}, {}
    for i = 1, math.random(1, MAX_PARTY) do
      local j = JOBS[math.random(1, #JOBS)]
      local skills
      members[i], skills = makeDummy(j[1] .. k, j[2], pickSkills(j), j[5], lv)
      comp[i] = j[1]
      self:logInfo('dummy', 'party=', k, j[1], 'lv=', lv, 'skills=', skills)
    end
    Char.SetData(members[1], CONST.对象_组队开关, 1)
    for i = 2, #members do
      Char.JoinParty(members[i], members[1], true)
    end
    parties[k] = { members = members, lv = lv, battles = 0, comp = table.concat(comp, '+') }
    self:startBattle(k)
  end
  self:logInfo('setup', #parties, 'parties')
end

function Module:finish(k, b, result)
  local p = parties[k]
  if p.battle ~= b then
    return -- 已经记过（逃跑检查和 BattleOverEvent 都可能来）
  end
  p.battle, battleOf[b] = nil, nil
  p.battles = p.battles + 1
  local hp = {}
  for _, c in ipairs(p.members) do
    table.insert(hp, string.format('%d/%d', Char.GetData(c, CONST.对象_血), Char.GetData(c, CONST.对象_最大血)))
  end
  self:logInfo('summary', 'party=', k, p.comp, 'lv=', p.lv, 'enemy=', p.enemyDesc, 'battle=', b,
    'turns=', Battle.GetTurn(b), 'secs=', os.time() - p.startedAt, result, 'hp=', table.concat(hp, ' '))
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

function Module:onBattleOver(b)
  local k = battleOf[b]
  if k then
    local side, alive = Battle.GetWinSide(b), false
    for _, c in ipairs(parties[k].members) do
      if Char.GetData(c, CONST.对象_血) > 0 then alive = true end
    end
    -- 逃跑成功时引擎也回报敌方胜，用「还有人活着」区分
    self:finish(k, b, side == 0 and 'WIN' or (side == 1 and (alive and 'ESCAPED' or 'LOSE') or 'OTHER' .. tostring(side)))
  end
end

-- 全队逃跑成功时不一定有 BattleOverEvent：每 5 秒看队员是否都已离开战斗
function Module:watch()
  for k, p in ipairs(parties) do
    local left = p.battle and os.time() - p.startedAt >= 2
    for _, c in ipairs(left and p.members or {}) do
      if Battle.GetCurrentBattle(c) == p.battle then left = false end
    end
    if left then
      self:finish(k, p.battle, 'ESCAPED')
    end
  end
  Cron.RunAt(os.time() + 5, function() self:watch() end)
end

function Module:onLoad()
  self:logInfo('load')
  self:regCallback('BattleOverEvent', Func.bind(self.onBattleOver, self))
  Cron.RunAt(os.time() + 30, function() self:setup() end)
  Cron.RunAt(os.time() + 35, function() self:watch() end)
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
