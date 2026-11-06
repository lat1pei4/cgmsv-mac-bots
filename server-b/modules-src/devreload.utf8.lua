---开发用：不重启伺服器就换上新版模组（tools/deploy-module.sh 呼叫）。
---POST /api/reload {module}：已载入的就 reloadModule（先 onUnload 再重新读档），没载入的就 loadModule（临时探针不用改 ModuleConfig）。
---http 模组只听 127.0.0.1。重载 http、自己会断掉 API，不接受。
local Module = ModuleBase:createModule('devreload')

local REFUSE = { http = true, devreload = true }

function Module:reload(name)
  if type(name) ~= 'string' or not name:match('^[%w_]+$') or REFUSE[name] then
    return { ok = false, msg = 'bad_module' }
  end
  local loaded = getModule(name) ~= nil
  local m
  if loaded then
    m = reloadModule(name)
  else
    m = loadModule(name)
  end
  self:logInfo(loaded and 'reload' or 'load', name, tostring(m ~= nil))
  -- 读档或语法错误时回 nil（错误内容在 server-b.log）
  return { ok = m ~= nil, msg = m and (loaded and 'reloaded' or 'loaded') or 'failed_see_log' }
end

function Module:onLoad()
  self:logInfo('load')
  getModule('http'):regApi('post', 'reload', function(_, raw)
    local ok, t = pcall(JSON.decode, raw or '')
    return JSON.encode(self:reload(ok and type(t) == 'table' and t.module or nil))
  end)
end

return Module
