---自动战斗：玩家说 /auto 切换引擎的自动战斗开关，引擎要指令时（AutoBattleCommandEvent）由本模块出招。
---假人（测试用）则在 BeforeBattleTurnEvent 出招。补给用完时战斗后自动回东医（见 onLeaveBattle）。只用玩家画面上看得到的信息判断：
---我方：血量、魔条比例、倒下、异常状态；敌方：位置、血条比例、是否倒下、异常状态图示。
---不读敌方血量数值／能力值／下一步行动。
local Module = ModuleBase:createModule('autobattle')

local enabled = {}   -- [charIndex] = true（测试用假人）
local focus = {}     -- [battleIndex] = 集火目标位置
local turnState = {} -- [battleIndex] = {turn, spent, planned, dummiesDone}
local spent = {}     -- 处理中这场战斗：[charIndex] = 本回合已排定要花的魔力（一回合两动时用）
local planned = {}   -- 处理中这场战斗：[slot] = 本回合已有人要补血／复活／洁净的我方位置，不重复
local acted = {}     -- 处理中这场战斗：[charIndex] = 本回合已下过指令
local noEscape = {}  -- [battleIndex] = true：不逃跑（测试对照组用）
local history = {}   -- [battleIndex][side] = 每回合一笔 {hp = 我方人物血量比例总和, foe = 敌方血条比例总和}

-- 切到这场战斗的本回合状态（新回合就重建）
local function enterTurn(b)
  local turn = Battle.GetTurn(b)
  local s = turnState[b]
  if s and turn < s.turn then -- 同一个战斗编号开了新的一场（全员逃跑时不一定有 BattleOverEvent），清掉旧状态
    focus[b], history[b], s = nil, nil, nil
  end
  if not s or s.turn ~= turn then
    s = { turn = turn, spent = {}, planned = {}, acted = {} }
    turnState[b] = s
  end
  spent, planned, acted = s.spent, s.planned, s.acted
  return s
end

local MP_RESERVE = 0.3 -- 会补血的角色，攻击技能只在剩余魔力 >= 30% 时才放

-- 记下本回合看得到的战况（每回合每边一笔）
local function observe(b, side, v)
  history[b] = history[b] or {}
  local hs = history[b][side] or {}
  history[b][side] = hs
  local turn = Battle.GetTurn(b)
  if hs.last ~= turn then
    local hp, foe = 0, 0
    for _, u in ipairs(v.allies) do
      if u.person and not u.dead then hp = hp + u.hp end
    end
    for _, e in ipairs(v.enemies) do foe = foe + e.hp end
    table.insert(hs, { hp = hp, foe = foe })
    hs.last = turn
  end
  return hs
end

-- 胜算：我方最近两回合的掉血速度 vs 敌方血条（全场）的下降速度，
-- 估算「几回合后我方倒光」和「几回合打完」；会先倒光、而且 2 回合内就会倒光才逃（太早逃会白白放弃打得赢的仗）
local function losing(hs)
  local n = #hs
  if n < 3 then return false end -- 至少看两回合再判断
  local now = hs[n]
  local loss = (hs[n - 2].hp - now.hp) / 2
  if loss <= 0 then return false end
  local dealt = (hs[1].foe - now.foe) / (n - 1)
  local die = now.hp / loss
  return die <= 1 and die < now.foe / math.max(dealt, 0.05)
end

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
  if g == 7 then return C.BATTLE_COM_P_BODYGUARD end
  if g >= 19 and g <= 30 then return C.BATTLE_COM_P_MAGIC end
  if g >= 32 and g <= 49 then return C.BATTLE_COM_P_STATUSCHANGE end
  if g >= 61 and g <= 63 then return C.BATTLE_COM_P_HEAL end
  if g >= 64 and g <= 66 then return C.BATTLE_COM_P_LP_RECOVERY end
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

-- 强力（范围）魔法的十字范围：中心、同排左右相邻、前后排同位置（2026-11-06 无头实测）。
-- 同排由左到右的位置编号是 3 1 0 2 4
local COLUMN = { [3] = 1, [1] = 2, [0] = 3, [2] = 4, [4] = 5 }
local function area(center)
  local rowStart, i = center - center % 5, center % 5
  local s = { center, center % 10 < 5 and center + 5 or center - 5 } -- 中心、前后排同位置
  for j, col in pairs(COLUMN) do
    if math.abs(col - COLUMN[i]) == 1 then table.insert(s, rowStart + j) end
  end
  return s
end

-- 以 slots 里每个位置当中心，挑范围内涵盖 wanted 最多的；回传中心与涵盖的位置
local function bestCenter(slots, wanted)
  local best, cover = nil, {}
  for _, c in ipairs(slots) do
    local got = {}
    for _, s in ipairs(area(c)) do
      if wanted[s] then table.insert(got, s) end
    end
    if #got > #cover then best, cover = c, got end
  end
  return best, cover
end

-- 技能表的 AR（每个目标的威力），依技能等级 1～10；四属性相同
local MAGIC_AR = {
  single = { 95, 171, 239, 303, 368, 432, 497, 570, 646, 722 },
  area = { 57, 103, 143, 182, 221, 259, 298, 342, 388, 433 },
  all = { 38, 68, 96, 121, 147, 173, 199, 228, 258, 289 },
}
local function magicPower(kind, id)
  return MAGIC_AR[kind][id % 100 + 1]
end
-- 补血量 ≈ 每级 AR × 等级（单体 60／强力 36／超强 24，未计回复力加成）
local HEAL_AR = { [61] = 60, [62] = 36, [63] = 24 }
-- 恢复魔法：6 回合内每回合回 RR（单体每级 20／强力 12／超强 8），这里算 6 回合的总量
local REGEN_AR = { [64] = 120, [65] = 72, [66] = 48 }
local REGEN_TURNS = 6
-- 异常魔法：单体 32～37、强力 38～43、超强 44～49，组内顺序 中毒/昏睡/石化/酒醉/混乱/遗忘；
-- 优先让敌人停手的：昏睡、石化、混乱、酒醉、遗忘、中毒
local STATUS_ORDER = { 1, 2, 4, 3, 5, 0 }
-- 成功率（技能表 SR，依等级）：单体约 35～55%、强力 15～35%、超强 15～27%
local function statusRate(kind, id)
  local lv = id % 100
  if kind == 'single' then return 0.35 + lv * 0.022 end
  if kind == 'area' then return 0.15 + lv * 0.022 end
  return 0.15 + lv * 0.013
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
        local hp, maxHp = Char.GetData(idx, CONST.对象_血), math.max(1, Char.GetData(idx, CONST.对象_最大血))
        table.insert(v.allies, {
          slot = slot, idx = idx, dead = dead, ailing = not dead and ailing(idx),
          hp = hp / maxHp, miss = maxHp - hp, -- 我方血量画面上看得到
          person = Char.GetData(idx, CONST.对象_类型) == CONST.对象类型_人,
        })
      elseif not dead then
        local asleep = Char.GetData(idx, CONST.对象_Sleep) > 0 or Char.GetData(idx, CONST.对象_Stone) > 0
        local hp = Char.GetData(idx, CONST.对象_血) / math.max(1, Char.GetData(idx, CONST.对象_最大血))
        local ailed = ailing(idx) or Char.GetData(idx, CONST.对象_Poison) > 0 -- 异常状态图示
        table.insert(v.enemies, { slot = slot, idx = idx, asleep = asleep, hp = hp, ailing = ailed }) -- 血条比例，不看数值
      end
    end
  end
  return v
end

-- 集火：挑血条最短的（残血优先）；同分续打上一个目标，再同分随机。
-- 睡着／石化的不打（打了会醒、石化减伤），除非只剩这些
local function pickTarget(b, v)
  local awake = {}
  for _, e in ipairs(v.enemies) do
    if not e.asleep then table.insert(awake, e) end
  end
  local best, low = {}, math.huge
  for _, e in ipairs(#awake > 0 and awake or v.enemies) do
    local hp = e.hp - (e.slot == focus[b] and 1e-6 or 0)
    if hp < low then
      best, low = { e }, hp
    elseif hp == low then
      table.insert(best, e)
    end
  end
  local e = best[math.random(1, #best)]
  focus[b] = e.slot
  return e
end

-- 背包里战斗中能用的回血药（参数 LPxxx；回魔的料理／食物战斗中不能用）：{{slot, lp}...}，扣掉本回合已排定要用的
local function potions(idx)
  local list = {}
  for slot = 8, 27 do
    local it = Char.GetItemIndex(idx, slot)
    if it >= 0 and Item.GetData(it, CONST.道具_战斗可用) == 1 then
      local lp = tonumber(string.match(Item.GetData(it, CONST.道具_自用参数) or '', '^LP(%d+)$'))
      local left = math.max(1, Item.GetData(it, CONST.道具_堆叠数)) - (planned['i' .. idx .. ':' .. slot] or 0)
      if lp and left > 0 then table.insert(list, { slot = slot, lp = lp }) end
    end
  end
  return list
end

-- 本回合还会补血的队友（还没下指令、魔力付得起补血）能补几个人：会强力／超强补血的算全部
local function healCapacity(b, actor, v)
  local n = 0
  for _, u in ipairs(v.allies) do
    if u.person and not u.dead and u.idx ~= actor and not acted[u.idx] then
      local t = playerTechs(u.idx)
      if t[62] or t[63] then return math.huge end
      if t[61] then n = n + 1 end
    end
  end
  return n
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

  local C = CONST.BATTLE_COM
  local me
  for _, u in ipairs(v.allies) do
    if u.idx == actor then me = u end
  end

  -- 0. 打不过就逃（Boss 战不能逃）；宠物不能逃，改防御
  if not noEscape[b] and Battle.GetType(b) ~= CONST.战斗_BOSS战 and losing(observe(b, side, v)) then
    if me and me.person then
      return C.BATTLE_COM_ESCAPE, -1, -1, '逃跑'
    end
    return C.BATTLE_COM_GUARD, -1, -1, '防御（主人逃跑）'
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

  -- 2. 补血：人物低于 50%、宠物低于 35% 才补，先顾人物
  local low, lowest = {}, nil
  for _, u in ipairs(v.allies) do
    if not u.dead and not planned[u.slot] and u.hp < (u.person and 0.5 or 0.35) then
      table.insert(low, u)
      if not lowest or (u.person and not lowest.person) or (u.person == lowest.person and u.hp < lowest.hp) then
        lowest = u
      end
    end
  end
  -- 补血／恢复魔法共用：单体／强力／超强各自挑「补得满最缺的那个」的最低等级（不超过付得起的等级），
  -- 比实际补到的总量（每人最多补到满），同量取魔力便宜的。base = 61（补血）或 64（恢复）
  local function bestHeal(base, rate, need, first, labels)
    local function option(g, label, tgt, slots)
      local maxLv, worst = techs[g] % 100 + 1, 0
      for _, s in ipairs(slots) do worst = math.max(worst, need[s]) end
      local lv = math.min(maxLv, math.max(1, math.ceil(worst / rate[g])))
      local amount = 0
      for _, s in ipairs(slots) do amount = amount + math.min(need[s], rate[g] * lv) end
      local id = g * 100 + lv - 1
      return { amount, Char.CalcConsumeFp(actor, id), comOf(g), tgt, id, label, slots }
    end
    local options = {}
    if techs[base] then
      table.insert(options, option(base, labels[1], first.slot, { first.slot }))
    end
    if techs[base + 1] then
      for _, u in ipairs(v.allies) do
        if not u.dead then
          local cover = {}
          for _, s in ipairs(area(u.slot)) do
            if need[s] then table.insert(cover, s) end
          end
          if #cover > 0 then table.insert(options, option(base + 1, labels[2], u.slot + 20, cover)) end
        end
      end
    end
    if techs[base + 2] then
      local all = {}
      for _, u in ipairs(v.allies) do
        if need[u.slot] then table.insert(all, u.slot) end
      end
      table.insert(options, option(base + 2, labels[3], allyAll, all))
    end
    local pick
    for _, o in ipairs(options) do
      if not pick or o[1] > pick[1] or (o[1] == pick[1] and o[2] < pick[2]) then pick = o end
    end
    return pick
  end

  if lowest then
    local need = {}
    for _, u in ipairs(low) do need[u.slot] = u.miss end
    local pick = bestHeal(61, HEAL_AR, need, lowest, { '补血', '强力补血', '超强补血' })
    if pick then
      for _, s in ipairs(pick[7]) do planned[s] = true end
      return pick[3], pick[4], pick[5], pick[6]
    end
  end

  -- 2b. 道具补血：补师没魔（或没有补师）、或同时残血的人多过补师补得到的，才用回血药。
  -- 补师会先补最危险的，所以药留给排在补师能力之后的那个；挑补得满的最小瓶，不够就用最大瓶
  if lowest and me and me.person then
    local queue = {}
    for _, u in ipairs(low) do table.insert(queue, u) end
    table.sort(queue, function(x, y)
      if x.person ~= y.person then return x.person end
      return x.hp < y.hp
    end)
    local u = queue[healCapacity(b, actor, v) + 1]
    local bottles = u and potions(actor) or {}
    local pick
    for _, p in ipairs(bottles) do
      if not pick or (pick.lp < u.miss and p.lp > pick.lp) or (p.lp >= u.miss and p.lp < pick.lp) then pick = p end
    end
    if pick then
      planned[u.slot] = true
      local key = 'i' .. actor .. ':' .. pick.slot
      planned[key] = (planned[key] or 0) + 1
      return C.BATTLE_COM_ITEM, u.slot, pick.slot, '道具补血'
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

  -- 4. 防御：本回合有人要补我而我血很少、宠物快倒了、或自己快倒了而队友能补血
  local function teammateCanHeal()
    for _, u in ipairs(v.allies) do
      if u.person and not u.dead and u.idx ~= actor then
        local t = playerTechs(u.idx)
        if t[61] or t[62] or t[63] then return true end
      end
    end
  end
  if #v.enemies == 0 then
    return C.BATTLE_COM_GUARD, -1, -1, '防御'
  end
  if me and me.hp < 0.35 and planned[me.slot] then
    return C.BATTLE_COM_GUARD, -1, -1, '防御（等补血）'
  end
  if me and not me.person and me.hp < 0.25 then
    return C.BATTLE_COM_GUARD, -1, -1, '防御（宠物血少）'
  end
  if me and me.hp < 0.2 and teammateCanHeal() then
    return C.BATTLE_COM_GUARD, -1, -1, '防御'
  end

  -- 5. 护卫：替血少（<50%）的队友（人物）挡，挑最少血的；自己血量要够（>=70%）才护
  if techs[7] and me and me.hp >= 0.7 then
    local weak
    for _, u in ipairs(v.allies) do
      if u.person and not u.dead and u.idx ~= actor and u.hp < 0.5 and not planned['g' .. u.slot]
          and (not weak or u.hp < weak.hp) then
        weak = u
      end
    end
    if weak then
      planned['g' .. weak.slot] = true
      return comOf(7), weak.slot, techs[7], '护卫'
    end
  end

  -- 6. 恢复魔法：还不用急补（50%）但低于 80%、身上没有恢复效果的队友，先挂上持续回复
  if techs[64] or techs[65] or techs[66] then
    history[b] = history[b] or {}
    local regen = history[b].regen or {}
    history[b].regen = regen
    local turn = Battle.GetTurn(b)
    local need, first = {}, nil
    for _, u in ipairs(v.allies) do
      if not u.dead and not planned[u.slot] and u.hp < 0.8 and (regen[u.slot] or -1) < turn then
        need[u.slot] = u.miss
        if not first or u.hp < first.hp then first = u end
      end
    end
    local pick = first and bestHeal(64, REGEN_AR, need, first, { '恢复魔法', '强力恢复魔法', '超强恢复魔法' })
    if pick then
      for _, s in ipairs(pick[7]) do
        planned[s], regen[s] = true, turn + REGEN_TURNS - 1
      end
      return pick[3], pick[4], pick[5], pick[6]
    end
  end

  local alive, enemySlots = {}, {}
  for _, e in ipairs(v.enemies) do
    alive[e.slot] = true
    table.insert(enemySlots, e.slot)
  end

  -- 7. 异常魔法：还没中异常的敌人 2 只以上才放；单体／强力／超强比「成功率 × 可能中招隻数」
  local fresh, freshSlots = {}, {}
  for _, e in ipairs(v.enemies) do
    if not e.ailing and not planned['s' .. e.slot] then
      fresh[e.slot] = true
      table.insert(freshSlots, e.slot)
    end
  end
  if #freshSlots >= 2 then
    local function firstOf(base)
      for _, o in ipairs(STATUS_ORDER) do
        if affordable(base + o) then return base + o end
      end
    end
    local opts = {}
    local g = firstOf(32)
    if g then
      local e = freshSlots[math.random(1, #freshSlots)]
      table.insert(opts, { statusRate('single', techs[g]), g, e, { e }, '异常魔法' })
    end
    g = firstOf(38)
    if g then
      local c, cover = bestCenter(enemySlots, fresh)
      if c then table.insert(opts, { statusRate('area', techs[g]) * #cover, g, c + 20, cover, '强力异常魔法' }) end
    end
    g = firstOf(44)
    if g then
      table.insert(opts, { statusRate('all', techs[g]) * #freshSlots, g, enemyAll, freshSlots, '超强异常魔法' })
    end
    local best
    for _, o in ipairs(opts) do
      if not best or o[1] > best[1] then best = o end
    end
    if best then
      for _, slot in ipairs(best[4]) do planned['s' .. slot] = true end
      return comOf(best[2]), best[3], techs[best[2]], best[5]
    end
  end

  -- 8. 攻击：敌人 3 只以上优先全体／范围，否则单体技能，都不行就普通攻击
  local target = pickTarget(b, v)
  -- 魔法：单体／强力（挑涵盖最多敌人的中心）／超强，比「该等级的威力 × 打到隻数」；
  -- 敌人血量看不到，所以只比总威力。范围魔法赢过单体魔法（没有就以单体 LV1 为准）才用
  local pick
  local function consider(score, com, tgt, id, label)
    if not pick or score > pick[1] + 1e-9 then pick = { score, com, tgt, id, label } end
  end
  for _, g in ipairs(shuffled({ 23, 24, 25, 26 })) do
    if affordable(g) then
      local c, cover = bestCenter(enemySlots, alive)
      if c then consider(magicPower('area', techs[g]) * #cover, comOf(g), c + 20, techs[g], '强力魔法') end
      break
    end
  end
  for _, g in ipairs(shuffled({ 27, 28, 29, 30 })) do
    if affordable(g) then
      consider(magicPower('all', techs[g]) * #enemySlots, comOf(g), enemyAll, techs[g], '超强魔法')
      break
    end
  end
  local single = MAGIC_AR.single[1]
  for g = 19, 22 do
    if affordable(g) then single = math.max(single, magicPower('single', techs[g])) end
  end
  if pick and pick[1] > single then
    return pick[2], pick[3], pick[4], pick[5]
  end
  if #v.enemies >= 3 and affordable(95) then return comOf(95), target.slot, techs[95], '乱射' end
  local singles = { 0, 3, 4, 5, 81 }
  if me and me.hp > 0.5 then -- 诸刃会反伤，血少不用
    table.insert(singles, 1)
  end
  for _, g in ipairs(shuffled(singles)) do
    if affordable(g) then return comOf(g), target.slot, techs[g], '单体技能' end
  end
  local best -- 单体魔法挑等级最高的，同级随机属性
  for _, g in ipairs(shuffled({ 19, 20, 21, 22 })) do
    if affordable(g) and (not best or techs[g] % 100 > techs[best] % 100) then best = g end
  end
  if best then return comOf(best), target.slot, techs[best], '单体魔法' end
  return C.BATTLE_COM_ATTACK, target.slot, -1, '攻击'
end

function Module:act(b, actor, techs, side)
  local com, target, id, label
  if Char.GetData(actor, CONST.对象_血) <= 0 then -- 倒下也要给指令，否则伺服器会一直等到 420 秒逾时
    com, target, id, label = CONST.BATTLE_COM.BATTLE_COM_GUARD, -1, -1, '倒下'
  else
    com, target, id, label = decide(b, actor, techs, view(b, side), side)
  end
  Battle.ActionSelect(actor, com, target, id) -- 回传值实测成功也是 0，不检查；用道具时 id 是背包位置
  acted[actor] = true
  if id >= 0 and com ~= CONST.BATTLE_COM.BATTLE_COM_ITEM then
    spent[actor] = (spent[actor] or 0) + Char.CalcConsumeFp(actor, id)
  end
  self:logInfo('act', 'b=', b, Char.GetData(actor, CONST.对象_名字), label, com, target, id,
    'mp=', Char.GetData(actor, CONST.对象_魔), 'spent=', spent[actor] or 0)
end

-- 人物（和宠物）本回合的指令；没带宠物时人物动两次
function Module:command(b, slot, p)
  local side = slot < 10 and 0 or 1
  self:act(b, p, playerTechs(p), side)
  local pet = Battle.GetPlayer(b, slot + 5)
  if pet >= 0 and Char.GetData(pet, CONST.对象_类型) == CONST.对象类型_宠 then
    if Battle.IsWaitingCommand(pet) == 1 then
      self:act(b, pet, petTechs(pet), side)
    end
  elseif Battle.IsWaitingCommand(p) == 1 then
    self:act(b, p, playerTechs(p), side)
  end
end

-- 测试用假人
function Module:onTurn(b)
  local s = enterTurn(b)
  if s.dummiesDone then
    return
  end
  s.dummiesDone = true
  for slot = 0, 19 do
    local p = Battle.GetPlayer(b, slot)
    if p >= 0 and enabled[p] and Battle.IsWaitingCommand(p) == 1 then
      self:command(b, slot, p)
    end
  end
end

-- 玩家开了自动战斗开关时，引擎每回合来要指令；必须回传 1，否则原地不动
function Module:onAutoBattle(b, p)
  local ok, err = pcall(function()
    enterTurn(b)
    for slot = 0, 19 do
      if Battle.GetPlayer(b, slot) == p then
        if Battle.IsWaitingCommand(p) == 1 then
          self:command(b, slot, p)
        end
        return
      end
    end
  end)
  if not ok then
    self:logError('onAutoBattle', err)
  end
  return 1
end

function Module:onBattleOver(b)
  focus[b], turnState[b], history[b], noEscape[b] = nil, nil, nil, nil
end

function Module:onTalk(player, msg)
  if msg == '/auto' or msg == '、auto' then
    local on = Char.GetData(player, CONST.对象_自动战斗开关) ~= 1
    Char.SetData(player, CONST.对象_自动战斗开关, on and 1 or 0)
    NLG.SystemMessage(player, on and '自动战斗：开启' or '自动战斗：关闭')
    return 0
  end
  return 1
end

--- 测试模块用：让假人也由本模块指挥
function Module:setEnabled(charIndex, on)
  enabled[charIndex] = on or nil
end

function Module:setNoEscape(battleIndex, on)
  noEscape[battleIndex] = on or nil
end

-- 回东医：开 /auto 的玩家（队长或单人）离开战斗后，若「有人血不到一半、没人会补血、也没有回血药」
-- 或「全队魔力剩不到 10%」，整队传送到法兰城东门医院（地图 1112，进门的位置）并补满血魔
local HOSPITAL = { map = 1112, x = 12, y = 42 }

local function partyOf(c)
  local leader = Char.GetPartyMember(c, 0)
  if leader < 0 then return { c } end -- 没组队
  if leader ~= c then return nil end  -- 由队长判断，队员不重复
  local list = {}
  for i = 0, 4 do
    local m = Char.GetPartyMember(c, i)
    if m >= 0 then table.insert(list, m) end
  end
  return list
end

local function exhausted(members)
  spent, planned = {}, {} -- 战斗外：没有本回合预定的魔力和药
  local low, canHeal, hasPotion, mp, maxMp = false, false, false, 0, 0
  for _, c in ipairs(members) do
    if Char.GetData(c, CONST.对象_血) < Char.GetData(c, CONST.对象_最大血) * 0.5 then low = true end
    local t = playerTechs(c)
    if t[61] or t[62] or t[63] then canHeal = true end
    if #potions(c) > 0 then hasPotion = true end
    mp, maxMp = mp + Char.GetData(c, CONST.对象_魔), maxMp + Char.GetData(c, CONST.对象_最大魔)
  end
  return (low and not canHeal and not hasPotion) or mp < maxMp * 0.1
end

function Module:onLeaveBattle(c)
  if Char.GetData(c, CONST.对象_自动战斗开关) ~= 1 then return 0 end
  local members = partyOf(c)
  if not members or not exhausted(members) then return 0 end
  Cron.RunAt(os.time() + 1, function() -- 等引擎把战斗状态清完再传送
    Char.Warp(c, 0, HOSPITAL.map, HOSPITAL.x, HOSPITAL.y) -- 传队长，队员会跟着
    for _, m in ipairs(members) do
      for _, u in ipairs({ m, Char.GetPet(m, 0), Char.GetPet(m, 1), Char.GetPet(m, 2), Char.GetPet(m, 3), Char.GetPet(m, 4) }) do
        if u >= 0 then
          Char.SetData(u, CONST.对象_血, Char.GetData(u, CONST.对象_最大血))
          Char.SetData(u, CONST.对象_魔, Char.GetData(u, CONST.对象_最大魔))
        end
      end
      NLG.UpChar(m)
    end
    NLG.SystemMessage(c, '[自動戰鬥] 補給用完，已回東醫補滿血魔')
    self:logInfo('hospital', Char.GetData(c, CONST.对象_名字), #members)
  end)
  return 0
end

function Module:onLoad()
  self:logInfo('load')
  self:regCallback('BeforeBattleTurnEvent', Func.bind(self.onTurn, self))
  self:regCallback('BattleOverEvent', Func.bind(self.onBattleOver, self))
  self:regCallback('TalkEvent', Func.bind(self.onTalk, self))
  self:regCallback('AutoBattleCommandEvent', Func.bind(self.onAutoBattle, self))
  self:regCallback('ResetCharaBattleStateEvent', Func.bind(self.onLeaveBattle, self))
end

function Module:onUnload()
  self:logInfo('unload')
end

return Module
