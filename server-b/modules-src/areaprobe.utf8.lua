---量测强力魔法的范围（无头多开）：10 个假人各开一场，各自对敌方一个位置放强力陨石（放两回合确认一致），
---记录受到伤害的位置。log 行：area center= 中心位置 turn= 回合 hit= 受伤位置。量完把 loadModule('areaprobe') 拿掉。
local Module = ModuleBase:createModule('areaprobe')

local probes = {} -- [battleIndex] = {caster, center, hits}
local done = 0

local function refill(c)
  NLG.UpChar(c)
  Char.SetData(c, CONST.对象_血, Char.GetData(c, CONST.对象_最大血))
  Char.SetData(c, CONST.对象_魔, Char.GetData(c, CONST.对象_最大魔))
end

-- 量测工具才看敌方血量（AI 不用）：和上回合比，掉血的位置就是被打到的
local function enemyHp(b)
  local hp = {}
  for s = 10, 19 do
    local e = Battle.GetPlayer(b, s)
    hp[s] = e >= 0 and Char.GetData(e, CONST.对象_血) or -1
  end
  return hp
end

function Module:flush(b, p)
  local now = enemyHp(b)
  if p.turn then
    local hits = {}
    for s = 10, 19 do
      if p.hp[s] > 0 and now[s] < p.hp[s] then table.insert(hits, s) end
    end
    self:logInfo('area', 'center=', p.center, 'turn=', p.turn, 'hit=', table.concat(hits, ','),
      'casterHP=', Char.GetData(p.caster, CONST.对象_血), 'MP=', Char.GetData(p.caster, CONST.对象_魔))
  end
  p.hp, p.turn = now, nil
end

function Module:onTurn(b)
  local p = probes[b]
  if not p then return end
  self:flush(b, p)
  local turn = Battle.GetTurn(b)
  local C = CONST.BATTLE_COM
  if turn >= 3 then
    Battle.ActionSelect(p.caster, C.BATTLE_COM_ESCAPE, -1, -1)
    Battle.ActionSelect(p.caster, C.BATTLE_COM_ESCAPE, -1, -1)
    return
  end
  refill(p.caster)
  p.turn = turn
  Battle.ActionSelect(p.caster, C.BATTLE_COM_P_MAGIC, p.center + 20, 2300) -- 强力陨石 LV1
  Battle.ActionSelect(p.caster, C.BATTLE_COM_GUARD, -1, -1)
end

function Module:onBattleOver(b)
  local p = probes[b]
  if p then
    self:logInfo('over', 'center=', p.center, 'turn=', Battle.GetTurn(b), 'win=', Battle.GetWinSide(b),
      'casterHP=', Char.GetData(p.caster, CONST.对象_血))
    done = done + 1
    if done == 10 then self:logInfo('probe done') end
  end
end

local function makeCaster(k)
  local c = Char.CreateDummy()
  Char.SetData(c, CONST.CHAR_地图类型, 0)
  Char.SetData(c, CONST.CHAR_地图, 1000)
  Char.SetData(c, CONST.CHAR_X, 234)
  Char.SetData(c, CONST.CHAR_Y, 72)
  Char.SetData(c, CONST.CHAR_名字, '量測員' .. k)
  Char.SetData(c, CONST.CHAR_形象, 105266)
  Char.SetData(c, CONST.CHAR_原形, 105266)
  Char.SetData(c, CONST.CHAR_原始图档, 105266)
  Char.SetData(c, CONST.CHAR_等级, 10)
  Char.SetData(c, CONST.CHAR_体力, 50000)
  Char.SetData(c, CONST.CHAR_魔法, 1000)
  Char.AddSkill(c, 23)
  refill(c)
  return c
end

function Module:setup()
  local ids, lvs = {}, {}
  for i = 1, 10 do
    ids[i], lvs[i] = 40035, 80 -- 哥布林 80 级：挨 LV1 强力不会死
  end
  for k = 0, 9 do
    local c = makeCaster(k)
    local b = Battle.PVE(c, c, nil, ids, lvs)
    probes[b] = { caster = c, center = 10 + k, hp = {} }
    self:logInfo('probe', k, 'battle=', b)
  end
end

function Module:onLoad()
  self:logInfo('load')
  self:regCallback('BeforeBattleTurnEvent', Func.bind(self.onTurn, self))
  self:regCallback('BattleOverEvent', Func.bind(self.onBattleOver, self))
  Cron.RunAt(os.time() + 20, function() self:setup() end)
end

function Module:onUnload()
  for _, p in pairs(probes) do
    Char.DelDummy(p.caster)
  end
end

return Module
