---量测战斗中「使用道具」（BATTLE_COM_ITEM）的参数格式（无头多开）：每种写法各开一场，
---每回合把假人血量设成 30%，用生命力回复药（100）后看下回合血量与药的数量有没有变。量完把 loadModule('itemprobe') 拿掉。
local Module = ModuleBase:createModule('itemprobe')

local ITEM = 15606 -- 生命力回复药（100）
local probes = {}  -- [battleIndex] = {c, variant, hp, n}
local done = 0

local VARIANTS = { -- 回传 {目标, 参数}
  function(slot, invSlot, itemIndex) return slot, invSlot end,
  function(slot, invSlot, itemIndex) return slot, itemIndex end,
  function(slot, invSlot, itemIndex) return invSlot, slot end,
  function(slot, invSlot, itemIndex) return slot, invSlot - 8 end,
  function(slot, invSlot, itemIndex) return slot, ITEM end,
}

local function findItem(c)
  for s = 8, 27 do
    local it = Char.GetItemIndex(c, s)
    if it >= 0 and Item.GetData(it, CONST.道具_ID) == ITEM then return s, it end
  end
  return -1, -1
end

function Module:onTurn(b)
  local p = probes[b]
  if not p then return end
  local hpNow, n = Char.GetData(p.c, CONST.对象_血), Char.ItemNum(p.c, ITEM)
  if p.hp then
    self:logInfo('item', 'variant=', p.variant, 'turn=', Battle.GetTurn(b), 'hp=', p.hp, '->', hpNow, 'count=', p.n, '->', n,
      'target=', p.tgt, 'arg=', p.arg)
  end
  local C = CONST.BATTLE_COM
  if Battle.GetTurn(b) >= 3 then
    Battle.ActionSelect(p.c, C.BATTLE_COM_ESCAPE, -1, -1)
    Battle.ActionSelect(p.c, C.BATTLE_COM_ESCAPE, -1, -1)
    return
  end
  local maxHp = Char.GetData(p.c, CONST.对象_最大血)
  Char.SetData(p.c, CONST.对象_血, math.floor(maxHp * 0.3))
  NLG.UpChar(p.c)
  local invSlot, itemIndex = findItem(p.c)
  p.tgt, p.arg = VARIANTS[p.variant](Battle.GetSlot(b, p.c), invSlot, itemIndex)
  p.hp, p.n = Char.GetData(p.c, CONST.对象_血), Char.ItemNum(p.c, ITEM)
  Battle.ActionSelect(p.c, C.BATTLE_COM_ITEM, p.tgt, p.arg)
  Battle.ActionSelect(p.c, C.BATTLE_COM_GUARD, -1, -1)
end

function Module:onBattleOver(b)
  if probes[b] then
    done = done + 1
    if done == #VARIANTS then self:logInfo('probe done') end
  end
end

local function makeDummy(k)
  local c = Char.CreateDummy()
  Char.SetData(c, CONST.CHAR_地图类型, 0)
  Char.SetData(c, CONST.CHAR_地图, 1000)
  Char.SetData(c, CONST.CHAR_X, 234)
  Char.SetData(c, CONST.CHAR_Y, 72)
  Char.SetData(c, CONST.CHAR_名字, '道具測試' .. k)
  Char.SetData(c, CONST.CHAR_形象, 105509)
  Char.SetData(c, CONST.CHAR_原形, 105509)
  Char.SetData(c, CONST.CHAR_原始图档, 105509)
  Char.SetData(c, CONST.CHAR_等级, 40)
  Char.SetData(c, CONST.CHAR_体力, 6000)
  Char.SetData(c, CONST.CHAR_强度, 3000)
  Char.GiveItem(c, ITEM, 3)
  NLG.UpChar(c)
  return c
end

function Module:setup()
  for k = 1, #VARIANTS do
    local c = makeDummy(k)
    local b = Battle.PVE(c, c, nil, { 40035 }, { 1 })
    probes[b] = { c = c, variant = k }
    local s, it = findItem(c)
    self:logInfo('probe', k, 'battle=', b, 'invSlot=', s, 'itemIndex=', it, 'count=', Char.ItemNum(c, ITEM))
  end
  -- 回血药和回魔食物：AI 读得到的参数与「战斗可用」旗标
  local c = makeDummy(9)
  Char.GiveItem(c, 15200, 1) -- 糖果（FP50）
  for s = 8, 27 do
    local it = Char.GetItemIndex(c, s)
    if it >= 0 then
      self:logInfo('itemdata', 'slot=', s, 'id=', Item.GetData(it, CONST.道具_ID), 'arg=', Item.GetData(it, CONST.道具_自用参数),
        'battleUse=', Item.GetData(it, CONST.道具_战斗可用), 'range=', Item.GetData(it, CONST.道具_使用范围),
        'type=', Item.GetData(it, CONST.道具_类型))
    end
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
    Char.DelDummy(p.c)
  end
end

return Module
