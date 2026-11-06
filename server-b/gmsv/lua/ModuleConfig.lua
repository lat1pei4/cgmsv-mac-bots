_G.loggerLevel = 3;
ModuleBase:SetLogLevel(_G.loggerLevel);
moduleInitial();
loadModule('admin')
loadModule('adminCommands')
loadModule('autoRegister')
loadModule('autoUnlock')
loadModule('loginGate')
loadModule('http')
loadModule('autobattle')
-- loadModule('abtest') -- 自动战斗测试时才打开
