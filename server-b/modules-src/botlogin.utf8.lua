---真角色无头上线：模块自己扮演游戏端，开本机连线走正常登入流程，引擎照常从资料库载入角色。
---连线不断开，角色就是正常的在线玩家（存档、自动战斗都照引擎原本的方式）；登出＝关掉连线。
---协定是明文（每行「指令 参数… 」加换行，实测抓包确认没有加密）：JFVf 登入 → Gp 角色清单（Daj）→
---没有角色就 aSEl 建立 → emRV <角色登记编号，62 进位> 进入游戏。
---帐号存在 bot_account 表；伺服器启动后自动登入 autologin=1 的帐号。
local Module = ModuleBase:createModule('botlogin')

local ffi = require('ffi')
pcall(ffi.cdef, [[
  typedef uintptr_t SOCKET;
  typedef struct { unsigned short wVersion, wHighVersion; char d[400]; } WSADATA;
  typedef struct { short sin_family; unsigned short sin_port; unsigned int s_addr; char zero[8]; } sockaddr_in;
  int WSAStartup(unsigned short ver, WSADATA *data);
  SOCKET socket(int af, int type, int protocol);
  int connect(SOCKET s, const sockaddr_in *name, int namelen);
  int ioctlsocket(SOCKET s, long cmd, unsigned long *argp);
  int send(SOCKET s, const char *buf, int len, int flags);
  int recv(SOCKET s, char *buf, int len, int flags);
  int closesocket(SOCKET s);
  int WSAGetLastError(void);
  unsigned short htons(unsigned short v);
  unsigned int inet_addr(const char *cp);
]]) -- 重新载入模组时已定义过，忽略错误
local ws = ffi.load('ws2_32')

local PORT = 9030
local MACHINE, MAC = 'd43d504b83f30f4a774c5e42b3ac0e99', '0013253e002a' -- 游戏端登入时送的机器码与网卡位址（实际封包）
local WOULDBLOCK, FIONBIO = 10035, -2147195266
local ECHO_SECS = 30 -- 游戏端闲置时也会定期送 Or（连线检查）
-- 游戏端每 60 秒送 DE（引擎记为 FC）：进游戏 5 分钟没收到就断线（"Client not send FC"），
-- 送太勤会被当成加速外挂断线（"CHEAT!! Client Accelerate 200.00%"，30 秒一次时）
local TICK_SECS = 60
local TIMEOUT_SECS = 30 -- 登入流程卡住多久算失败
local CREATE_TRIES = 3 -- 建角色失败（DZ failed）重试次数

local conns = {} -- [account] = {account, password, slot, s, state, buf, since, lastEcho, char, err}
local recvBuf = ffi.new('char[65536]')

local function sendLine(c, plain)
  local data = plain .. ' \n'
  return ws.send(c.s, data, #data, 0) == #data
end

-- 游戏端的数字用 0-9a-zA-Z 的 62 进位
local B62 = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
local function base62(n)
  local s = ''
  repeat
    local d = n % 62
    s, n = B62:sub(d + 1, d + 1) .. s, math.floor(n / 62)
  until n == 0
  return s
end

-- Daj 0 名字|位置\\z造型\\z等级\\z…\\z名字\\z登记编号\\z职业\\z…|名字|…：回传 {[位置] = 登记编号}
local function parseCharList(plain)
  local list = {}
  local entries = plain:match('^Daj %S+ (.*)$') or ''
  for _, fields in entries:gmatch('([^|]*)|([^|]*)|') do
    local f = {}
    for v in (fields .. '\\\\z'):gmatch('(.-)\\\\z') do table.insert(f, v) end
    local place, regist = tonumber(f[1]), tonumber(f[15])
    if place and regist then list[place] = regist end
  end
  return list
end

-- 建角色：沿用游戏端实际送出的造型、头像与属性，只换名字；点数（体力 力量 强度 速度 魔法，16 进位）配攻敏各 15
local function createLine(slot, name)
  return string.format('aSEl %d %s rE9 110s 0 f 0 f 0 0 0 0 a', slot, name)
end

local function close(c, state, err)
  if c.s then ws.closesocket(c.s) end
  c.s, c.state, c.err, c.char = nil, state, err, -1
end

-- 登入流程看指令名推进状态；上线后只处理战斗的 LYIm（其余读掉不解析）
local function onPacket(self, c, plain)
  local op = plain:match('^(%S+)')
  if c.state == 'login' and op == 'whV' then
    sendLine(c, 'Gp')
    c.state = 'list'
  elseif c.state == 'list' and op == 'Daj' then
    local regist = parseCharList(plain)[c.slot]
    if regist then
      sendLine(c, 'emRV ' .. base62(regist) .. ' 2 110s') -- 后两个参数照游戏端实际送的
      c.state = 'enter'
    elseif c.charName and not c.created then
      sendLine(c, createLine(c.slot, c.charName))
      c.created = true -- 建好伺服器回 DZ，再要一次清单
    else
      close(c, 'failed', 'no_char')
    end
  elseif c.state == 'list' and op == 'DZ' then
    if plain:match('^DZ successful') then
      sendLine(c, 'Gp')
    elseif (c.createTries or 0) < CREATE_TRIES then
      -- 引擎同时建多个角色时各自写 SQLite，抢不到锁（log：database is locked）不等待就回 DZ failed -1，重建一次就好
      c.createTries, c.created = (c.createTries or 0) + 1, false
      sendLine(c, 'Gp')
    else
      close(c, 'failed', 'create_failed')
      self:logInfo('create failed', c.account, plain)
    end
  elseif c.state == 'enter' and op == 'hPUd' and not plain:match('^hPUd successful') then
    close(c, 'failed', 'enter_failed')
    self:logInfo('enter failed', c.account, plain)
  elseif c.state == 'online' and op == 'LYIm' then
    -- 战斗每回合伺服器送 P|我方位置|…、C|…、A|已下指令的位置（16 进位位元）|回合|，等游戏端回指令。
    -- 游戏端开自动战斗时回两次「Rg N」（人物、宠物各一，N＝不下指令），引擎再触发 AutoBattleCommandEvent 由 autobattle 出招。
    -- 战斗结束（含逃跑）送「C|20」，游戏端关掉战斗画面后回「eL 0」，引擎才让角色回到地图（不回就一直卡在战斗中）
    local kind, arg = plain:match('^LYIm (%a)|(%x+)')
    if kind == 'C' and arg == '20' then
      sendLine(c, 'eL 0')
      c.rgSent = true -- 结束后那个 A 不用回
    elseif kind == 'P' then
      c.battleSlot, c.rgSent = tonumber(arg, 16), false
    elseif kind == 'A' and c.battleSlot and not c.rgSent
        and math.floor(tonumber(arg, 16) / 2 ^ c.battleSlot) % 2 == 0 then
      sendLine(c, 'Rg N')
      sendLine(c, 'Rg N')
      c.rgSent = true
    end
  end
end

local function poll(self)
  local now = os.time()
  for _, c in pairs(conns) do
    if c.s then
      if c.state == 'connect' then
        if ws.send(c.s, '', 0, 0) == 0 then -- 非阻塞 connect 完成
          sendLine(c, string.format('JFVf %s %s %s %s', MACHINE, c.account, c.password, MAC))
          c.state = 'login'
        end
      end
      while c.s do
        local n = ws.recv(c.s, recvBuf, 65536, 0)
        if n > 0 then
          c.buf = c.buf .. ffi.string(recvBuf, n)
          for line in c.buf:gmatch('([^\n]*)\n') do
            if c.s then onPacket(self, c, line) end
          end
          c.buf = c.buf:match('[^\n]*$')
        elseif n == 0 then
          close(c, 'closed', 'server_closed')
        elseif ws.WSAGetLastError() ~= WOULDBLOCK then
          close(c, 'closed', 'socket_error:' .. ws.WSAGetLastError())
        else
          break
        end
      end
      if c.state == 'enter' then
        local idx = NLG.FindUser(c.account)
        if idx >= 0 then
          c.char, c.state, c.lastEcho, c.lastTick = idx, 'online', now, now
          self:logInfo('online', c.account, idx)
        end
      end
      if c.state == 'online' and now - c.lastTick >= TICK_SECS then
        sendLine(c, 'DE')
        c.lastTick = now
      end
      if c.state == 'online' and now - c.lastEcho >= ECHO_SECS then
        sendLine(c, 'Or nr')
        c.lastEcho = now
      elseif c.s and c.state ~= 'online' and now - c.since > TIMEOUT_SECS then
        close(c, 'failed', 'timeout:' .. c.state)
        self:logInfo('login timeout', c.account)
      end
    end
  end
end

---@return table 帐号列表 {account, password, slot, charname, autologin}
function Module:accounts()
  return SQL.QueryEx('select account, password, slot, charname, autologin from bot_account order by account').rows or {}
end

---charName：该位置没有角色时用这个名字建立（伺服器语系字串）；nil 则不建
function Module:addAccount(account, password, slot, charName)
  return SQL.QueryEx('insert or replace into bot_account (account, password, slot, charname, autologin) values (?, ?, ?, ?, 1)',
    account, password, slot or 0, charName).effectRows == 1
end

function Module:removeAccount(account)
  self:logout(account)
  conns[account] = nil
  return SQL.QueryEx('delete from bot_account where account = ?', account).effectRows == 1
end

function Module:setAutologin(account, on)
  SQL.QueryEx('update bot_account set autologin = ? where account = ?', on and 1 or 0, account)
end

---@return table|nil 连线状态 {state, char, err}；没连过回 nil
function Module:status(account)
  return conns[account]
end

function Module:login(account)
  local c = conns[account]
  if c and c.s then return false end
  local row
  for _, r in ipairs(self:accounts()) do
    if r.account == account then row = r end
  end
  if not row then return false end
  local s = ws.socket(2, 1, 6)
  ws.ioctlsocket(s, FIONBIO, ffi.new('unsigned long[1]', 1))
  local addr = ffi.new('sockaddr_in')
  addr.sin_family, addr.sin_port, addr.s_addr = 2, ws.htons(PORT), ws.inet_addr('127.0.0.1')
  ws.connect(s, addr, ffi.sizeof(addr))
  conns[account] = { account = account, password = row.password, slot = tonumber(row.slot) or 0, s = s,
    charName = row.charname ~= '' and row.charname or nil,
    state = 'connect', buf = '', since = os.time(), lastEcho = 0, char = -1 }
  self:logInfo('login', account)
  return true
end

-- 关掉连线＝玩家登出，引擎照常存档
function Module:logout(account)
  local c = conns[account]
  if not c or not c.s then return false end
  close(c, 'offline')
  self:logInfo('logout', account)
  return true
end

function Module:onLoad()
  self:logInfo('load')
  ws.WSAStartup(0x0202, ffi.new('WSADATA'))
  SQL.QueryEx('create table if not exists bot_account (account text primary key, password text not null, '
    .. 'slot integer not null default 0, charname text, autologin integer not null default 1)')
  self.pollTask = Cron.AddInterval(100, function() poll(self) end, 1)
  Cron.RunAt(os.time() + 10, function() -- 等伺服器开始收连线
    for _, r in ipairs(self:accounts()) do
      if tonumber(r.autologin) == 1 then self:login(r.account) end
    end
  end)
end

function Module:onUnload()
  Cron.RemoveTask(self.pollTask)
  for account in pairs(conns) do self:logout(account) end
  self:logInfo('unload')
end

return Module
