--! rewrite
--! new

local function post(path, payload)
    local url = "http://127.0.0.1:6967" .. path
    local success, result = pcall(function()
        return game:GetService("HttpService"):PostAsync(url, HttpService:JSONEncode(payload))
    end)
    if success then return result else return nil end
end

-- File functions

local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function base64Encode(data)
    return ((data:gsub('.', function(x)
        local r,bits='',x:byte()
        for i=8,1,-1 do r=r..(bits%2^i-bits%2^(i-1)>0 and '1' or '0') end
        return r
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if #x < 6 then return '' end
        local c=0
        for i=1,6 do c=c + (x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

local function base64Decode(data)
    data = data:gsub('[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if x == '=' then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or 0) end
        return r
    end):gsub('%d%d%d%d%d%d%d%d', function(x)
        local c=0
        for i=1,8 do c=c + (x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end


-- ===== File functions =====
env.writefile = function(path, contents)
    local encoded = base64Encode(contents)
    post("/files", {file = path, method = "create", content = encoded})
end

env.appendfile = function(path, contents)
    local current = env.readfile(path) or ""
    env.writefile(path, current .. contents)
end

env.readfile = function(path)
    local encoded = post("/files", {file = path, method = "read"})
    if encoded then
        return base64Decode(encoded)
    end
    return nil
end

env.isfile = function(path)
    local res = post("/files", {file = path, method = "check"})
    return res == "true"
end

env.makefolder = function(path)
    post("/files", {file = path, method = "create", folder = "true"})
end

env.delfolder = function(path)
    post("/files", {file = path, method = "delete", folder = "true"})
end

env.delfile = function(path)
    post("/files", {file = path, method = "delete"})
end

env.listfiles = function(path)
    path = path or "" -- default to workspace
    local response = post("/files", {file = path, method = "list"})
    if response then
        local ok, decoded = pcall(function() return load("return "..response)() end)
        return ok and decoded or {}
    end
    return {}
end

-- ===== Function calls =====
env.getcustomasset = function(file)
    return post("/functions", {func = "getcustomasset", file = file})
end

env.setclipboard = function(text)
    return post("/functions", {func = "setclipboard", text = text})
end

local renv = {
	print = print, warn = warn, error = error, shared = shared, assert = assert, collectgarbage = collectgarbage, require = require,
	select = select, tonumber = tonumber, tostring = tostring, type = type, xpcall = xpcall,
	pairs = pairs, next = next, ipairs = ipairs, newproxy = newproxy, rawequal = rawequal, rawget = rawget,
	rawset = rawset, rawlen = rawlen, gcinfo = gcinfo,

	coroutine = {
		create = coroutine.create, resume = coroutine.resume, running = coroutine.running,
		status = coroutine.status, wrap = coroutine.wrap, yield = coroutine.yield,
	},

	bit32 = {
		arshift = bit32.arshift, band = bit32.band, bnot = bit32.bnot, bor = bit32.bor, btest = bit32.btest,
		extract = bit32.extract, lshift = bit32.lshift, replace = bit32.replace, rshift = bit32.rshift, xor = bit32.xor,
	},

	math = {
		abs = math.abs, acos = math.acos, asin = math.asin, atan = math.atan, atan2 = math.atan2, ceil = math.ceil,
		cos = math.cos, cosh = math.cosh, deg = math.deg, exp = math.exp, floor = math.floor, fmod = math.fmod,
		frexp = math.frexp, ldexp = math.ldexp, log = math.log, log10 = math.log10, max = math.max, min = math.min,
		modf = math.modf, pow = math.pow, rad = math.rad, random = math.random, randomseed = math.randomseed,
		sin = math.sin, sinh = math.sinh, sqrt = math.sqrt, tan = math.tan, tanh = math.tanh
	},

	string = {
		byte = string.byte, char = string.char, find = string.find, format = string.format, gmatch = string.gmatch,
		gsub = string.gsub, len = string.len, lower = string.lower, match = string.match, pack = string.pack,
		packsize = string.packsize, rep = string.rep, reverse = string.reverse, sub = string.sub,
		unpack = string.unpack, upper = string.upper,
	},

	table = {
		concat = table.concat, insert = table.insert, pack = table.pack, remove = table.remove, sort = table.sort,
		unpack = table.unpack,
	},

	utf8 = {
		char = utf8.char, charpattern = utf8.charpattern, codepoint = utf8.codepoint, codes = utf8.codes,
		len = utf8.len, nfdnormalize = utf8.nfdnormalize, nfcnormalize = utf8.nfcnormalize,
	},

	os = {
		clock = os.clock, date = os.date, difftime = os.difftime, time = os.time,
	},

	delay = delay, elapsedTime = elapsedTime, spawn = spawn, tick = tick, time = time, typeof = typeof,
	UserSettings = UserSettings, version = version, wait = wait, _VERSION = _VERSION,

	task = {
		defer = task.defer, delay = task.delay, spawn = task.spawn, wait = task.wait,
	},

	debug = {
		traceback = debug.traceback, profilebegin = debug.profilebegin, profileend = debug.profileend, info = debug.info 
	},

	game = game, workspace = workspace, Game = game, Workspace = workspace,

	getmetatable = getmetatable, setmetatable = setmetatable
}
table.freeze(renv)

-- assume `env` is already defined somewhere, e.g., local env = {}

env.gethiddenproperty = function(instance, property) 
    local instanceprs = hiddenprs[instance]
    if instanceprs and instanceprs[property] then
        return instanceprs[property], true
    end
    return oldghpr(instance, property)
end

env.sethiddenproperty = function(instance, property, value)
    local instanceprs = hiddenprs[instance]
    if not instanceprs then
        instanceprs = {}
        hiddenprs[instance] = instanceprs
    end
    instanceprs[property] = value
    return true
end

env.getdevice = function()
    return tostring(game:GetService("UserInputService"):GetPlatform()):split(".")[3]
end 

env.getping = function(suffix: boolean)
    local rawping = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValueString()
    local pingstr = rawping:sub(1, #rawping - 7)
    local pingnum = tonumber(pingstr)
    local ping = tostring(math.round(pingnum))
    return not suffix and ping or ping .. " ms"
end 

env.getfps = function(): number
    local FPS: number
    local TimeFunction = RunService:IsRunning() and time or os.clock
    local LastIteration: number, Start: number
    local FrameUpdateTable = {}
    local function HeartbeatUpdate()
        LastIteration = TimeFunction()
        for Index = #FrameUpdateTable, 1, -1 do
            FrameUpdateTable[Index + 1] = FrameUpdateTable[Index] >= LastIteration - 1 and FrameUpdateTable[Index] or nil
        end
        FrameUpdateTable[1] = LastIteration
        FPS = TimeFunction() - Start >= 1 and #FrameUpdateTable or #FrameUpdateTable / (TimeFunction() - Start)
    end
    Start = TimeFunction()
    RunService.Heartbeat:Connect(HeartbeatUpdate)
    task.wait(1.1)
    return FPS
end

env.getplayer = function(name: string)
    return not name and env.getplayers()["LocalPlayer"] or env.getplayers()[name]
end

env.getplayers = function()
    local players = {}
    for _, x in pairs(game:GetService("Players"):GetPlayers()) do
        players[x.Name] = x
    end
    players["LocalPlayer"] = game:GetService("Players").LocalPlayer
    return players
end

env.getlocalplayer = function(): Player
    return env.getplayer()
end

env.customprint = function(text: string, properties: table, imgid: rbxasset)
    print(text)
    task.wait(0.025)
    local clientl = CoreGui.DevConsoleMaster.DevConsoleWindow.DevConsoleUI.MainView.ClientLog
    local cc = #clientl:GetChildren()
    local msgi = cc > 0 and cc - 1 or 0
    local msg = clientl:FindFirstChild(tostring(msgi))
    if msg then
        for i, x in pairs(properties) do
            msg[i] = x
        end
        if imgid then
            msg.Parent.image.Image = imgid
        end
    end
end

env.joinserver = function(placeID: number, jobID: string)
    game:GetService("TeleportService"):TeleportToPlaceInstance(placeID, jobID, env.getplayer())
end


env.getrenv = function()
	return renv
end

env.run_on_actor = function(actor, code)
    local func, err = loadstring(code)
    if not func then
        return warn("no func?")
    end
    local success, exec = pcall(function()
        setfenv(func, getfenv()) 
        func()
    end)
    if not success then
        warn("execution failed: " .. tostring(exec))
    end
end

env.isexecutorclosure = function(a)
    assert(typeof(a) == "function", "argument #1 is not a 'function'", 0)
    local result = false
    for b, c in next, getfenv() do
        if c == a then
            result = true
        end
    end
    if not result then
        for b, c in next, Cclosures do
            if c == a then
                result = true
            end
        end
    end
    return result or islclosure(a)
end

env.checkclosure = env.isexecutorclosure
env.isourclosure = env.isexecutorclosure
env.is_saturn_closure = env.isexecutorclosure
env.is_saturn_function = env.isexecutorclosure
env.is_our_function = env.isexecutorclosure

env.keyclick = function(key)
    if typeof(key) == "number" then
        if not keys[key] then
            return error("Key " .. tostring(key) .. " not found!")
        end
        VirtualInputManager:SendKeyEvent(true, keys[key], false, game)
        task.wait()
        VirtualInputManager:SendKeyEvent(false, keys[key], false, game)
    elseif typeof(key) == "EnumItem" then
        VirtualInputManager:SendKeyEvent(true, key, false, game)
        task.wait()
        VirtualInputManager:SendKeyEvent(false, key, false, game)
    end
end

env.keypress = function(key)
    if typeof(key) == "number" then
        if not keys[key] then
            return error("Key " .. tostring(key) .. " not found!")
        end
        VirtualInputManager:SendKeyEvent(true, keys[key], false, game)
    elseif typeof(key) == "EnumItem" then
        VirtualInputManager:SendKeyEvent(true, key, false, game)
    end
end

env.keyrelease = function(key)
    if typeof(key) == "number" then
        if not keys[key] then
            return error("Key " .. tostring(key) .. " not found!")
        end
        VirtualInputManager:SendKeyEvent(false, keys[key], false, game)
    elseif typeof(key) == "EnumItem" then
        VirtualInputManager:SendKeyEvent(false, key, false, game)
    end
end 

env.iskeydown = function(key)
    return keyshit[key] == true
end

env.iskeytoggled = function(key)
    return keyshit[key] ~= nil and keyshit[key] or false
end

game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
    if not processed and input.UserInputType == Enum.UserInputType.Keyboard then
        keyshit[input.KeyCode] = true
    end
end)

game:GetService("UserInputService").InputEnded:Connect(function(input, processed)
    if not processed and input.UserInputType == Enum.UserInputType.Keyboard then
        keyshit[input.KeyCode] = false
    end
end)

env.getthreadidentity = function() -- Taken from MoreUNC (remember to credit ccv)
    local function try(f)
        return function()
            return pcall(f);
        end
    end

	for i, v in next, ({
		try(function() return game.Name end),
		try(function() return game:GetService("CoreGui").Name end),
		try(function() return game.DataCost end),
		try(function() return Instance_new, "Player" end),
		try(function() return game:GetService("CorePackages").Name end),
		try(function() return Instance_new("SurfaceAppearance").TexturePack end),
		try(function() Instance_new("MeshPart").MeshId = "" end)
	}) do
        if not v() then
            return i - 1; -- Previous level because the current isnt available
        end
    end
	
    return 7;
end

env.getthreadcontext = env.getthreadidentity
env.getidentity = env.getthreadidentity

env.isrbxactive = true
env.isgameactive = true
