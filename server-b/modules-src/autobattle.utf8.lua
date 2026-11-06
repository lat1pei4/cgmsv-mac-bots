---自动战斗：玩家说 /auto 开关。只用玩家画面上看得到的信息判断：
---我方：血条／魔条比例、倒下、异常状态；敌方：位置、是否倒下、异常状态图示。
---不读敌方血量／能力值／下一步行动。
local Module = ModuleBase:createModule('autobattle')

local enabled = {}  -- [charIndex] = true
local focus = {}    -- [battleIndex] = 集火目标位置
local lastTurn = {} -- [battleIndex] = 已处理的回合
local spent = {}    -- [charIndex] = 本回合已排定要花的魔力（一回合两动时用）
local planned = {}  -- [slot] = 本回合已有人要补血／复活／洁净的我方位置，不重复

local MP_RESERVE = 0.3 -- 会补血的角色，攻击技能只在剩余魔力 >= 30% 时才放

local function shuffled(list)
  local r = {}
  for i, v in ipairs(list) do
    table.insert(r, math.random(1, i), v)
  end
  return r
end

-- 招式组（= skill.txt 技能 ID）对应的战斗指令
local function comOf(g)
  local C = CONST.BATTLE_COM
  if g == 0 then return C.BATTLE_COM_P_RENZOKU end
  if g == 1 or g == 3 then return C.BATTLE_COM_P_PARAMETER end
  if g == 4 then return C.BATTLE_COM_P_SPIRACLESHOT end
  if g == 5 then return C.BATTLE_COM_P_GUARDBREAK end
  if g >= 19 and g <= 30 then return C.BATTLE_COM_P_MAGIC end
  if g >= 61 and g <= 63 then return C.BATTLE_COM_P_HEAL end
  if g == 67 then return C.BATTLE_COM_P_STATUSRECOVER end
  if g == 68 then return C.BATTLE_COM_P_REVIVE end
  if g >= 75 and g <= 80 then return C.BATTLE_COM_M_STATUSATTACK end
  if g == 81 then return C.BATTLE_COM_M_BLOODATTACK end
  if g == 94 then return C.BATTLE_COM_P_PANIC end
  if g == 95 then return C.BATTLE_COM_P_RANDOMSHOT end
end

-- 人物：每个技能取魔力付得起的最高等级招式 {[组] = techId}
local function playerTechs(idx)
  local mp, list = Char.GetData(idx, CONST.对象_魔) - (spent[idx] or 0), {}
  for slot = 0, 14 do
    local sk = Char.GetSkillID(idx, slot)
    if sk and sk >= 0 and sk < 1000 then
      for l = math.min(10, Char.GetSkillLv(idx, slot)), 1, -1 do
        local id = sk * 100 + l - 1
        if Tech.GetTechIndex(id) >= 0 and Char.CalcConsumeFp(idx, id) <= mp then
          list[sk] = id
          break
        end
      end
    end
  end
  return list
end

-- 宠物：学会的招式里魔力付得起的
local function petTechs(pet)
  local mp, list = Char.GetData(pet, CONST.对象_魔) - (spent[pet] or 0), {}
  for slot = 0, 9 do
    local id = Pet.GetSkill(pet, slot)
    if id and id >= 0 and id < 10000 then
      local g = math.floor(id / 100)
      if (list[g] == nil or id > list[g]) and Char.CalcConsumeFp(pet, id) <= mp then
        list[g] = id
      end
    end
  end
  return list
end

local function ailing(idx)
  return Char.GetData(idx, CONST.对象_Sleep) > 0 or Char.GetData(idx, CONST.对象_Stone) > 0
      or Char.GetData(idx, CONST.对象_Confusion) > 0 or Char.GetData(idx, CONST.对象_Drunk) > 0
      or Char.GetData(idx, CONST.对象_Amnesia) > 0
end

-- 战场上看得到的信息
local function view(b, side)
  local v = { allies = {}, enemies = {} }
  for slot = 0, 19 do
    local idx = Battle.GetPlayer(b, slot)
    if idx >= 0 then
      local dead = Char.GetData(idx, CONST.对象_战死) == 1
      if (slot < 10) == (side == 0) then
        table.insert(v.allies, {
          slot = slot, idx = idx, dead = dead, ailing = not dead and ailing(idx),
          hp = Char.GetData(idx, CONST.对象_血) / math.max(1, Char.GetData(idx, CONST.对象_最大血)),
          person = Char.GetData(idx, CONST.对象_类型) == CONST.对象类型_人,
        })
      elseif not dead then
        local asleep = Char.GetData(idx, CONST.对象_Sleep) > 0 or Char.GetData(idx, CONST.对象_Stone) > 0
        table.insert(v.enemies, { slot = slot, idx = idx, asleep = asleep })
      end
    end
  end
  return v
end

-- 集火：上一个目标还在就继续打；否则挑没睡着／没石化的（打了会醒、石化减伤）
local function pickTarget(b, v)
  local awake = {}
  for _, e in ipairs(v.enemies) do
    if e.slot == focus[b] and not e.asleep then
      return e
    end
    if not e.asleep then
      table.insert(awake, e)
    end
  end
  local pool = #awake > 0 and awake or v.enemies
  local e = pool[math.random(1, #pool)]
  focus[b] = e.slot
  return e
end

---@return number com, number target, number techId, string 说明
local function decide(b, actor, techs, v, side)
  local allyAll, enemyAll = 40 + side, 41 - side
  local mp, maxMp = Char.GetData(actor, CONST.对象_魔) - (spent[actor] or 0), math.max(1, Char.GetData(actor, CONST.对象_最大魔))
  local healer = techs[61] or techs[62] or techs[63] or techs[68]
  local function affordable(g)
    local id = techs[g]
    if id and (not healer or (mp - Char.CalcConsumeFp(actor, id)) / maxMp >= MP_RESERVE) then
      return id
    end
  end

  -- 1. 我方有人倒下：气绝回复
  if techs[68] then
    for _, u in ipairs(v.allies) do
      if u.dead and u.person and not planned[u.slot] then
        planned[u.slot] = true
        return comOf(68), u.slot, techs[68], '气绝回复'
      end
    end
  end

  -- 2. 补血：人物低于 50%、宠物低于 35% 才补，先顾人物；3 个以上用超强，2 个用强力，1 个用单体
  local low, lowest, me = {}, nil, nil
  for _, u in ipairs(v.allies) do
    if u.idx == actor then me = u end
    if not u.dead and not planned[u.slot] and u.hp < (u.person and 0.5 or 0.35) then
      table.insert(low, u)
      if not lowest or (u.person and not lowest.person) or (u.person == lowest.person and u.hp < lowest.hp) then
        lowest = u
      end
    end
  end
  if lowest then
    -- 等级照缺血比例挑（缺越多用越高级），不一律用最高级
    local function sized(g)
      return g * 100 + math.max(1, math.ceil((techs[g] % 100 + 1) * (1 - lowest.hp))) - 1
    end
    local com, target, id, label
    if #low >= 3 and techs[63] then
      com, target, id, label = comOf(63), allyAll, techs[63], '超强补血'
    elseif #low >= 2 and techs[62] then
      com, target, id, label = comOf(62), lowest.slot + 20, sized(62), '强力补血'
    elseif techs[61] then
      com, target, id, label = comOf(61), lowest.slot, sized(61), '补血'
    elseif techs[62] then
      com, target, id, label = comOf(62), lowest.slot + 20, sized(62), '强力补血'
    end
    if com then
      for _, u in ipairs(com == comOf(61) and { lowest } or low) do
        planned[u.slot] = true
      end
      return com, target, id, label
    end
  end

  -- 3. 队友睡着／石化／混乱／酒醉／遗忘：洁净
  if techs[67] then
    for _, u in ipairs(v.allies) do
      if u.ailing and u.person and not planned[u.slot] then
        planned[u.slot] = true
        return comOf(67), u.slot, techs[67], '洁净'
      end
    end
  end

  -- 4. 自己快倒了、而队友有人能补血：先防御等补
  local C = CONST.BATTLE_COM
  local function teammateCanHeal()
    for _, u in ipairs(v.allies) do
      if u.person and not u.dead and u.idx ~= actor then
        local t = playerTechs(u.idx)
        if t[61] or t[62] or t[63] then return true end
      end
    end
  end
  if #v.enemies == 0 or (me and me.hp < 0.2 and teammateCanHeal()) then
    return C.BATTLE_COM_GUARD, -1, -1, '防御'
  end

  -- 5. 攻击：敌人 3 只以上优先全体／范围，否则单体技能，都不行就普通攻击
  local target = pickTarget(b, v)
  if #v.enemies >= 3 then
    for _, g in ipairs(shuffled({ 27, 28, 29, 30 })) do
      if affordable(g) then return comOf(g), enemyAll, techs[g], '超强魔法' end
    end
    for _, g in ipairs(shuffled({ 23, 24, 25, 26 })) do
      if affordable(g) then return comOf(g), target.slot + 20, techs[g], '强力魔法' end
    end
    if affordable(95) then return comOf(95), target.slot, techs[95], '乱射' end
  end
  local singles = { 0, 3, 4, 5, 81 }
  if me and me.hp > 0.5 then -- 诸刃会反伤，血少不用
    table.insert(singles, 1)
  end
  for _, g in ipairs(shuffled(singles)) do
    if affordable(g) then return comOf(g), target.slot, techs[g], '单体技能' end
  end
  for _, g in ipairs(shuffled({ 19, 20, 21, 22 })) do
    if affordable(g) then return comOf(g), target.slot, techs[g], '单体魔法' end
  end
  return C.BATTLE_COM_ATTACK, target.slot, -1, '攻击'
end

function Module:act(b, actor, techs, side)
  local com, target, id, label = decide(b, actor, techs, view(b, side), side)
  Battle.ActionSelect(actor, com, target, id) -- 回传值实测成功也是 0，不检查
  if id >= 0 then
    spent[actor] = (spent[actor] or 0) + Char.CalcConsumeFp(actor, id)
  end
  self:logInfo('act', 'b=', b, Char.GetData(actor, CONST.对象_名字), label, com, target, id,
    'mp=', Char.GetData(actor, CONST.对象_魔), 'spent=', spent[actor] or 0)
end

function Module:onTurn(b)
  local turn = Battle.GetTurn(b)
  if lastTurn[b] == turn then
    return
  end
  lastTurn[b] = turn
  spent, planned = {}, {}
  for slot = 0, 19 do
    local p = Battle.GetPlayer(b, slot)
    if p >= 0 and enabled[p] and Battle.IsWaitingCommand(p) == 1 and Char.GetData(p, CONST.对象_血) > 0 then
      local side = slot < 10 and 0 or 1
      self:act(b, p, playerTechs(p), side)
      local pet = Battle.GetPlayer(b, slot + 5)
      if pet >= 0 and Char.GetData(pet, CONST.对象_类型) == CONST.对象类型_宠 then
        if Battle.IsWaitingCommand(pet) == 1 then
          self:act(b, pet, petTechs(pet), side)
        end
      elseif Battle.IsWaitingCommand(p) == 1 then -- 没带宠物：人物第 2 动
        self:act(b, p, playerTechs(p), side)
      end
    end
  end
end

function Module:onBattleOver(b)
  focus[b], lastTurn[b] = nil, nil
end

function Module:onTalk(player, msg)
  if msg == '/auto' or msg == '、auto' then
    enabled[player] = not enabled[player] or nil
    NLG.SystemMessage(player, enabled[player] and '自动战斗：开启' or '自动战斗：关闭')
    return 0
  end
  return 1
end

function Module:onLogout(player)
  enabled[player] = nil
end

--- 测试模块用：让假人也由本模块指挥
function Module:setEnabled(charIndex, on)
  enabled[charIndex] = on or nil
end

function Module:onLoad()
  self:logInfo('load', 'BATTLE_COM=', type(CONST.BATTLE_COM), 'TECH_COST=', CONST.TECH_COST)
  self:regCallback('BeforeBattleTurnEvent', Func.bind(self.onTurn, self))
  self:regCallback('BattleOverEvent', Func.bind(self.onBattleOver, self))
  self:regCallback('TalkEvent', Func.bind(self.onTalk, self))
  self:regCallback('LogoutEvent', Func.bind(self.onLogout, self))
  self:regCallback('DropEvent', Func.bind(self.onLogout, self))
end

function Module:onUnload()
  self:logInfo('unload')
end

return Module
