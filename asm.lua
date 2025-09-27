-- Services initialization
local CoreGuiService = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local InsertService = game:GetService("InsertService")
local PlayersService = game:GetService("Players")
local VirtualInputManager = Instance.new("VirtualInputManager")

local Mouse = game:GetService("Players").LocalPlayer:GetMouse()
local Camera = workspace.CurrentCamera

-- Main folder structure
local MainFolder = Instance.new("Folder", CoreGuiService)
MainFolder.Name = "Glacier"
local PointerFolder = Instance.new("Folder", MainFolder)
PointerFolder.Name = "Pointer"
local BridgeFolder = Instance.new("Folder", MainFolder)
BridgeFolder.Name = "Bridge"

local LocalPlayer = PlayersService.LocalPlayer

local RealTypeof = typeof
local RobloxActive = true

-- GUI references
local RobloxGui = CoreGuiService:FindFirstChild("RobloxGui")
local ModulesFolder = RobloxGui:FindFirstChild("Modules")
local CommonFolder = ModulesFolder:FindFirstChild("Common")
local LoadModule = CommonFolder:FindFirstChild("CommonUtil")

-- Configuration
local ServerUrl = "http://localhost:9611"
local ProcessIdentifier = "%-PROCESS-ID-%"
local HardwareId = "Glacier-HWID-" .. LocalPlayer.UserId

local RetryCount = 3

local function SendRequest(requestData, requestType, requestSettings)
	local TimeoutDuration = 5
	local ResponseResult, StartTime = nil, tick()

	requestData = requestData or ""
	requestType = requestType or "none"
	requestSettings = requestSettings or {}

	HttpService:RequestInternal({
		Url = ServerUrl .. "/handle",
		Body = requestType .. "\n" .. ProcessIdentifier .. "\n" .. HttpService:JSONEncode(requestSettings) .. "\n" .. requestData,
		Method = "POST",
		Headers = {
			['Content-Type'] = "text/plain",
		}
	}):Start(function(isSuccess, responseBody)
		ResponseResult = responseBody
		ResponseResult['Success'] = isSuccess
	end)

	while not ResponseResult do 
		task.wait()
		if (tick() - StartTime > TimeoutDuration) then
			break
		end
	end

	if not ResponseResult or not ResponseResult.Success then
		if RetryCount <= 0 then
			warn("Execution not responding")
			return {}
		else
			RetryCount -= 1
		end
	else
		RetryCount = 3
	end

	return ResponseResult and ResponseResult.Body or ""
end

local Environment = getfenv(function() end)

Environment.getgenv = function()
	return Environment
end

Environment.identifyexecutor = function()
	return "Glacier", "1.2.0"
end
Environment.getexecutorname = Environment.identifyexecutor

Environment.compile = function(sourceCode, isEncoded)
	local Code = typeof(sourceCode) == "string" and sourceCode or ""
	local Encoded = typeof(isEncoded) == "boolean" and isEncoded or false
	local Result = SendRequest(Code, "compile", {
		["enc"] = tostring(Encoded)
	})
	return Result or ""
end

Environment.setscriptbytecode = function(scriptInstance, bytecodeData)
	local ObjectValue = Instance.new("ObjectValue", PointerFolder)
	ObjectValue.Name = HttpService:GenerateGUID(false)
	ObjectValue.Value = scriptInstance

	SendRequest(bytecodeData, "setscriptbytecode", {
		["cn"] = ObjectValue.Name
	})

	ObjectValue:Destroy()
end

local CloneReferences = {}
Environment.cloneref = function(targetObject)
	local ProxyObject = newproxy(true)
	local MetaTable = getmetatable(ProxyObject)
	
	MetaTable.__index = function(self, key)
		local Value = targetObject[key]
		if typeof(Value) == "function" then
			return function(selfRef, ...)
				if selfRef == self then
					selfRef = targetObject
				end
				return Value(selfRef, ...)
			end
		else
			return Value
		end
	end
	
	MetaTable.__newindex = function(self, key, value)
		targetObject[key] = value
	end
	
	MetaTable.__tostring = function(self)
		return tostring(targetObject)
	end
	
	MetaTable.__metatable = getmetatable(targetObject)
	CloneReferences[ProxyObject] = targetObject
	return ProxyObject
end

Environment.compareinstances = function(firstProxy, secondProxy)
	assert(type(firstProxy) == "userdata", "Invalid argument #1 to 'compareinstances' (Instance expected, got " .. typeof(firstProxy) .. ")")
	assert(type(secondProxy) == "userdata", "Invalid argument #2 to 'compareinstances' (Instance expected, got " .. typeof(secondProxy) .. ")")
	
	if CloneReferences[firstProxy] then
		firstProxy = CloneReferences[firstProxy]
	end
	if CloneReferences[secondProxy] then
		secondProxy = CloneReferences[secondProxy]
	end
	
	return firstProxy == secondProxy
end

Environment.loadstring = function(sourceCode, chunkName)
	assert(type(sourceCode) == "string", "invalid argument #1 to 'loadstring' (string expected, got " .. type(sourceCode) .. ") ", 2)
	chunkName = chunkName or "loadstring"
	assert(type(chunkName) == "string", "invalid argument #2 to 'loadstring' (string expected, got " .. type(chunkName) .. ") ", 2)
	chunkName = chunkName:gsub("[^%a_]", "")
	
	if (sourceCode == "" or sourceCode == " ") then
		return
	end

	local CompiledBytecode = Environment.compile("return{[ [["..chunkName.."]] ]=function(...)local roe=function()return'\67\104\105\109\101\114\97\76\108\101'end;"..sourceCode.."\nend}", true)
	if #CompiledBytecode <= 1 then
		return 
	end

	Environment.setscriptbytecode(LoadModule, CompiledBytecode)

	local ExecutionSuccess, ExecutionResult = pcall(function()
		return debug.loadmodule(LoadModule)
	end)

	if ExecutionSuccess then
		local CallSuccess, CallResult = pcall(function()
			return ExecutionResult()
		end)
		if CallSuccess and typeof(CallResult) == "table" and typeof(CallResult[chunkName]) == "function" then
			return setfenv(CallResult[chunkName], Environment)
		else
			return 
		end
	else
		return 
	end
end

local ValidHttpMethods = {"GET", "POST", "PUT", "DELETE", "PATCH"}

Environment.request = function(requestOptions)
	assert(type(requestOptions) == "table", "invalid argument #1 to 'request' (table expected, got " .. type(requestOptions) .. ") ", 2)
	assert(type(requestOptions.Url) == "string", "invalid option 'Url' for argument #1 to 'request' (string expected, got " .. type(requestOptions.Url) .. ") ", 2)
	
	requestOptions.Method = requestOptions.Method or "GET"
	requestOptions.Method = requestOptions.Method:upper()
	
	assert(table.find(ValidHttpMethods, requestOptions.Method), "invalid option 'Method' for argument #1 to 'request' (a valid http method expected, got '" .. requestOptions.Method .. "') ", 2)
	assert(not (requestOptions.Method == "GET" and requestOptions.Body), "invalid option 'Body' for argument #1 to 'request' (current method is GET but option 'Body' was used)", 2)
	
	if requestOptions.Body then
		assert(type(requestOptions.Body) == "string", "invalid option 'Body' for argument #1 to 'request' (string expected, got " .. type(requestOptions.Body) .. ") ", 2)
		assert(pcall(function() HttpService:JSONDecode(requestOptions.Body) end), "invalid option 'Body' for argument #1 to 'request' (invalid json string format)", 2)
	end
	
	if requestOptions.Headers then 
		assert(type(requestOptions.Headers) == "table", "invalid option 'Headers' for argument #1 to 'request' (table expected, got " .. type(requestOptions.Url) .. ") ", 2) 
	end
	
	requestOptions.Body = requestOptions.Body or "{}"
	requestOptions.Headers = requestOptions.Headers or {}
	
	if (requestOptions.Headers["User-Agent"]) then 
		assert(type(requestOptions.Headers["User-Agent"]) == "string", "invalid option 'User-Agent' for argument #1 to 'request.Header' (string expected, got " .. type(requestOptions.Url) .. ") ", 2) 
	end
	
	requestOptions.Headers["User-Agent"] = requestOptions.Headers["User-Agent"] or "Glacier/1.0.0"
	requestOptions.Headers["Glacier-Fingerprint"] = HardwareId
	requestOptions.Headers["Cache-Control"] = "no-cache"
	requestOptions.Headers["Roblox-Place-Id"] = tostring(game.PlaceId)
	requestOptions.Headers["Roblox-Game-Id"] = tostring(game.JobId)
	requestOptions.Headers["Roblox-Session-Id"] = HttpService:JSONEncode({
		["GameId"] = tostring(game.GameId),
		["PlaceId"] = tostring(game.PlaceId)
	})
	
	local RequestResponse = SendRequest("", "request", {
		['l'] = requestOptions.Url,
		['m'] = requestOptions.Method,
		['h'] = requestOptions.Headers,
		['b'] = requestOptions.Body or "{}"
	})
	
	if RequestResponse then
		local ParsedResult = HttpService:JSONDecode(RequestResponse)
		if ParsedResult['r'] ~= "OK" then
			ParsedResult['r'] = "Unknown"
		end
		return {
			Success = tonumber(ParsedResult['c']) and tonumber(ParsedResult['c']) > 200 and tonumber(ParsedResult['c']) < 300,
			StatusMessage = ParsedResult['r'],
			StatusCode = tonumber(ParsedResult['c']),
			Body = ParsedResult['b'],
			HttpError = Enum.HttpError[ParsedResult['r']],
			Headers = ParsedResult['h'],
			Version = ParsedResult['v']
		}
	end
	
	return {
		Success = false,
		StatusMessage = "Can't connect to Glacier web server!",
		StatusCode = 599,
		HttpError = Enum.HttpError.ConnectFail
	}
end

-- Base64 encoding/decoding implementation
local ValueToCharacterLookup = buffer.create(64)
local CharacterToValueLookup = buffer.create(256)

local Base64Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local PaddingCharacter = string.byte("=")

for idx = 1, 64 do
	local val = idx - 1
	local char = string.byte(Base64Alphabet, idx)

	buffer.writeu8(ValueToCharacterLookup, val, char)
	buffer.writeu8(CharacterToValueLookup, char, val)
end

local function EncodeBase64Raw(inputBuffer)
	local InputLength = buffer.len(inputBuffer)
	local InputChunks = math.ceil(InputLength / 3)

	local OutputLength = InputChunks * 4
	local OutputBuffer = buffer.create(OutputLength)

	for chunkIdx = 1, InputChunks - 1 do
		local inputIdx = (chunkIdx - 1) * 3
		local outputIdx = (chunkIdx - 1) * 4

		local chunk = bit32.byteswap(buffer.readu32(inputBuffer, inputIdx))

		local val1 = bit32.rshift(chunk, 26)
		local val2 = bit32.band(bit32.rshift(chunk, 20), 0b111111)
		local val3 = bit32.band(bit32.rshift(chunk, 14), 0b111111)
		local val4 = bit32.band(bit32.rshift(chunk, 8), 0b111111)

		buffer.writeu8(OutputBuffer, outputIdx, buffer.readu8(ValueToCharacterLookup, val1))
		buffer.writeu8(OutputBuffer, outputIdx + 1, buffer.readu8(ValueToCharacterLookup, val2))
		buffer.writeu8(OutputBuffer, outputIdx + 2, buffer.readu8(ValueToCharacterLookup, val3))
		buffer.writeu8(OutputBuffer, outputIdx + 3, buffer.readu8(ValueToCharacterLookup, val4))
	end

	local InputRemainder = InputLength % 3

	if InputRemainder == 1 then
		local chunk = buffer.readu8(inputBuffer, InputLength - 1)

		local val1 = bit32.rshift(chunk, 2)
		local val2 = bit32.band(bit32.lshift(chunk, 4), 0b111111)

		buffer.writeu8(OutputBuffer, OutputLength - 4, buffer.readu8(ValueToCharacterLookup, val1))
		buffer.writeu8(OutputBuffer, OutputLength - 3, buffer.readu8(ValueToCharacterLookup, val2))
		buffer.writeu8(OutputBuffer, OutputLength - 2, PaddingCharacter)
		buffer.writeu8(OutputBuffer, OutputLength - 1, PaddingCharacter)
	elseif InputRemainder == 2 then
		local chunk = bit32.bor(
			bit32.lshift(buffer.readu8(inputBuffer, InputLength - 2), 8),
			buffer.readu8(inputBuffer, InputLength - 1)
		)

		local val1 = bit32.rshift(chunk, 10)
		local val2 = bit32.band(bit32.rshift(chunk, 4), 0b111111)
		local val3 = bit32.band(bit32.lshift(chunk, 2), 0b111111)

		buffer.writeu8(OutputBuffer, OutputLength - 4, buffer.readu8(ValueToCharacterLookup, val1))
		buffer.writeu8(OutputBuffer, OutputLength - 3, buffer.readu8(ValueToCharacterLookup, val2))
		buffer.writeu8(OutputBuffer, OutputLength - 2, buffer.readu8(ValueToCharacterLookup, val3))
		buffer.writeu8(OutputBuffer, OutputLength - 1, PaddingCharacter)
	elseif InputRemainder == 0 and InputLength ~= 0 then
		local chunk = bit32.bor(
			bit32.lshift(buffer.readu8(inputBuffer, InputLength - 3), 16),
			bit32.lshift(buffer.readu8(inputBuffer, InputLength - 2), 8),
			buffer.readu8(inputBuffer, InputLength - 1)
		)

		local val1 = bit32.rshift(chunk, 18)
		local val2 = bit32.band(bit32.rshift(chunk, 12), 0b111111)
		local val3 = bit32.band(bit32.rshift(chunk, 6), 0b111111)
		local val4 = bit32.band(chunk, 0b111111)

		buffer.writeu8(OutputBuffer, OutputLength - 4, buffer.readu8(ValueToCharacterLookup, val1))
		buffer.writeu8(OutputBuffer, OutputLength - 3, buffer.readu8(ValueToCharacterLookup, val2))
		buffer.writeu8(OutputBuffer, OutputLength - 2, buffer.readu8(ValueToCharacterLookup, val3))
		buffer.writeu8(OutputBuffer, OutputLength - 1, buffer.readu8(ValueToCharacterLookup, val4))
	end

	return OutputBuffer
end

local function DecodeBase64Raw(inputBuffer)
	local InputLength = buffer.len(inputBuffer)
	local InputChunks = math.ceil(InputLength / 4)

	local InputPadding = 0
	if InputLength ~= 0 then
		if buffer.readu8(inputBuffer, InputLength - 1) == PaddingCharacter then 
			InputPadding += 1 
		end
		if buffer.readu8(inputBuffer, InputLength - 2) == PaddingCharacter then 
			InputPadding += 1 
		end
	end

	local OutputLength = InputChunks * 3 - InputPadding
	local OutputBuffer = buffer.create(OutputLength)

	for chunkIdx = 1, InputChunks - 1 do
		local inputIdx = (chunkIdx - 1) * 4
		local outputIdx = (chunkIdx - 1) * 3

		local val1 = buffer.readu8(CharacterToValueLookup, buffer.readu8(inputBuffer, inputIdx))
		local val2 = buffer.readu8(CharacterToValueLookup, buffer.readu8(inputBuffer, inputIdx + 1))
		local val3 = buffer.readu8(CharacterToValueLookup, buffer.readu8(inputBuffer, inputIdx + 2))
		local val4 = buffer.readu8(CharacterToValueLookup, buffer.readu8(inputBuffer, inputIdx + 3))

		local chunk = bit32.bor(
			bit32.lshift(val1, 18),
			bit32.lshift(val2, 12),
			bit32.lshift(val3, 6),
			val4
		)

		local char1 = bit32.rshift(chunk, 16)
		local char2 = bit32.band(bit32.rshift(chunk, 8), 0b11111111)
		local char3 = bit32.band(chunk, 0b11111111)

		buffer.writeu8(OutputBuffer, outputIdx, char1)
		buffer.writeu8(OutputBuffer, outputIdx + 1, char2)
		buffer.writeu8(OutputBuffer, outputIdx + 2, char3)
	end

	if InputLength ~= 0 then
		local lastInputIdx = (InputChunks - 1) * 4
		local lastOutputIdx = (InputChunks - 1) * 3

		local lastVal1 = buffer.readu8(CharacterToValueLookup, buffer.readu8(inputBuffer, lastInputIdx))
		local lastVal2 = buffer.readu8(CharacterToValueLookup, buffer.readu8(inputBuffer, lastInputIdx + 1))
		local lastVal3 = buffer.readu8(CharacterToValueLookup, buffer.readu8(inputBuffer, lastInputIdx + 2))
		local lastVal4 = buffer.readu8(CharacterToValueLookup, buffer.readu8(inputBuffer, lastInputIdx + 3))

		local lastChunk = bit32.bor(
			bit32.lshift(lastVal1, 18),
			bit32.lshift(lastVal2, 12),
			bit32.lshift(lastVal3, 6),
			lastVal4
		)

		if InputPadding <= 2 then
			local lastChar1 = bit32.rshift(lastChunk, 16)
			buffer.writeu8(OutputBuffer, lastOutputIdx, lastChar1)

			if InputPadding <= 1 then
				local lastChar2 = bit32.band(bit32.rshift(lastChunk, 8), 0b11111111)
				buffer.writeu8(OutputBuffer, lastOutputIdx + 1, lastChar2)

				if InputPadding == 0 then
					local lastChar3 = bit32.band(lastChunk, 0b11111111)
					buffer.writeu8(OutputBuffer, lastOutputIdx + 2, lastChar3)
				end
			end
		end
	end

	return OutputBuffer
end

Environment.base64encode = function(inputString)
	return buffer.tostring(EncodeBase64Raw(buffer.fromstring(inputString)))
end
Environment.base64_encode = Environment.base64encode

Environment.base64decode = function(encodedString)
	return buffer.tostring(DecodeBase64Raw(buffer.fromstring(encodedString)))
end
Environment.base64_decode = Environment.base64decode

local Base64Module = {}
Base64Module.encode = Environment.base64encode
Base64Module.decode = Environment.base64decode
Environment.base64 = Base64Module

Environment.islclosure = function(func)
	assert(type(func) == "function", "invalid argument #1 to 'islclosure' (function expected, got " .. type(func) .. ") ", 2)
	return debug.info(func, "s") ~= "[C]"
end
Environment.isluaclosure = Environment.islclosure

Environment.iscclosure = function(func)
	assert(type(func) == "function", "invalid argument #1 to 'iscclosure' (function expected, got " .. type(func) .. ") ", 2)
	return debug.info(func, "s") == "[C]"
end

Environment.newlclosure = function(func)
	assert(type(func) == "function", "invalid argument #1 to 'newlclosure' (function expected, got " .. type(func) .. ") ", 2)
	local ClonedFunction = function(...)
		return func(...)
	end
	return ClonedFunction
end

Environment.newcclosure = function(func)
	assert(type(func) == "function", "invalid argument #1 to 'newcclosure' (function expected, got " .. type(func) .. ") ", 2)
	local ClonedFunction = coroutine.wrap(function(...)
		while true do
			coroutine.yield(func(...))
		end
	end)
	return ClonedFunction
end

Environment.clonefunction = function(func)
	assert(type(func) == "function", "invalid argument #1 to 'clonefunction' (function expected, got " .. type(func) .. ") ", 2)
	if Environment.iscclosure(func) then
		return Environment.newcclosure(func)
	else
		return Environment.newlclosure(func)
	end
end

local UserAgentString = "Glacier/1.2.0"

function Environment.HttpGet(url, shouldReturnRaw)
	assert(type(url) == "string", "invalid argument #1 to 'HttpGet' (string expected, got " .. type(url) .. ") ", 2)
	local ReturnRaw = shouldReturnRaw or true

	local RequestResult = Environment.request({
		Url = url,
		Method = "GET",
		Headers = {
			["User-Agent"] = UserAgentString
		}
	})

	if ReturnRaw then
		return RequestResult.Body
	end

	return HttpService:JSONDecode(RequestResult.Body)
end

function Environment.HttpPost(url, requestBody, contentType)
	assert(type(url) == "string", "invalid argument #1 to 'HttpPost' (string expected, got " .. type(url) .. ") ", 2)
	contentType = contentType or "application/json"
	return Environment.request({
		Url = url,
		Method = "POST",
		body = requestBody,
		Headers = {
			["Content-Type"] = contentType
		}
	})
end

function Environment.GetObjects(assetId)
	return {
		InsertService:LoadLocalAsset(assetId)
	}
end

local function CreateError(targetObject)
	local _, errorResult = xpcall(function()
		targetObject:__namecall()
	end, function()
		return debug.info(2, "f")
	end)
	return errorResult
end

local FirstErrorTest = CreateError(OverlapParams.new())
local SecondErrorTest = CreateError(Color3.new())

local CachedMethods = {}

Environment.getnamecallmethod = function()
	local _, errorMsg = pcall(FirstErrorTest)
	local methodName = if type(errorMsg) == "string" then errorMsg:match("^(.+) is not a valid member of %w+$") else nil
	if not methodName then
		_, errorMsg = pcall(SecondErrorTest)
		methodName = if type(errorMsg) == "string" then errorMsg:match("^(.+) is not a valid member of %w+$") else nil
	end
	
	local FixerData = newproxy(true)
	local FixerMeta = getmetatable(FixerData)
	FixerMeta.__namecall = function()
		local _, err = pcall(FirstErrorTest)
		local method = if type(err) == "string" then err:match("^(.+) is not a valid member of %w+$") else nil
		if not method then
			_, err = pcall(SecondErrorTest)
			method = if type(err) == "string" then err:match("^(.+) is not a valid member of %w+$") else nil
		end
	end
	FixerData:__namecall()
	
	if not methodName or methodName == "__namecall" then
		if CachedMethods[coroutine.running()] then
			return CachedMethods[coroutine.running()]
		end
		return nil
	end
	
	CachedMethods[coroutine.running()] = methodName
	return methodName
end

local ProxyObjectFunction
local ProxiedObjects = {}
local ObjectReferences = {}

function ConvertToProxy(...)
	local PackedArgs = table.pack(...)
	local function ProcessTable(tableRef)
		for i, obj in ipairs(tableRef) do
			if RealTypeof(obj) == "Instance" then
				if ObjectReferences[obj] then
					tableRef[i] = ObjectReferences[obj].proxy
				else
					tableRef[i] = ProxyObjectFunction(obj)
				end
			elseif typeof(obj) == "table" then
				ProcessTable(obj)
			else
				tableRef[i] = obj
			end
		end
	end
	ProcessTable(PackedArgs)
	return table.unpack(PackedArgs, 1, PackedArgs.n)
end

function ConvertToObject(...)
	local PackedArgs = table.pack(...)
	local function ProcessTable(tableRef)
		for i, obj in ipairs(tableRef) do
			if RealTypeof(obj) == "userdata" then
				if ProxiedObjects[obj] then
					tableRef[i] = ProxiedObjects[obj].object
				else
					tableRef[i] = obj
				end
			elseif typeof(obj) == "table" then
				ProcessTable(obj)
			else
				tableRef[i] = obj
			end
		end
	end
	ProcessTable(PackedArgs)
	return table.unpack(PackedArgs, 1, PackedArgs.n)
end

local function IndexHandler(proxyTable, indexKey)
	local ProxyData = ProxiedObjects[proxyTable]
	local NameCallMethods = ProxyData.namecalls
	local OriginalObject = ProxyData.object
	
	if NameCallMethods[indexKey] then
		return function(selfRef, ...)
			return ConvertToProxy(NameCallMethods[indexKey](...))
		end
	end
	
	local Value = OriginalObject[indexKey]
	if typeof(Value) == "function" then
		return function(selfRef, ...)
			return ConvertToProxy(Value(ConvertToObject(selfRef, ...)))
		end
	else
		return ConvertToProxy(Value)
	end
end

local function NameCallHandler(proxyTable, ...)
	local ProxyData = ProxiedObjects[proxyTable]
	local NameCallMethods = ProxyData.namecalls
	local OriginalObject = ProxyData.object
	local MethodName = Environment.getnamecallmethod()
	
	if NameCallMethods[MethodName] then
		return ConvertToProxy(NameCallMethods[MethodName](...))
	end
	
	return ConvertToProxy(OriginalObject[MethodName](ConvertToObject(proxyTable, ...)))
end

local function NewIndexHandler(proxyTable, indexKey, newValue)
	local ProxyData = ProxiedObjects[proxyTable]
	local OriginalObject = ProxyData.object
	local ConvertedValue = table.pack(ConvertToObject(newValue))
	OriginalObject[indexKey] = table.unpack(ConvertedValue)
end

local function ToStringHandler(proxyTable)
	return proxyTable.Name
end

function ProxyObjectFunction(originalObject, nameCallOverrides)
	if ObjectReferences[originalObject] then
		return ObjectReferences[originalObject].proxy
	end
	
	nameCallOverrides = nameCallOverrides or {}
	
	local ProxyObject = newproxy(true)
	local ProxyMeta = getmetatable(ProxyObject)
	ProxyMeta.__index = function(...) return IndexHandler(...) end
	ProxyMeta.__namecall = function(...) return NameCallHandler(...) end
	ProxyMeta.__newindex = function(...) return NewIndexHandler(...) end
	ProxyMeta.__tostring = function(...) return ToStringHandler(...) end
	ProxyMeta.__metatable = getmetatable(originalObject)

	local ProxyData = {}
	ProxyData.object = originalObject
	ProxyData.proxy = ProxyObject
	ProxyData.meta = ProxyMeta
	ProxyData.namecalls = nameCallOverrides

	ProxiedObjects[ProxyObject] = ProxyData
	ObjectReferences[originalObject] = ProxyData
	return ProxyObject
end

local ProxiedGame = ProxyObjectFunction(game, {
	HttpGet = Environment.HttpGet,
	HttpGetAsync = Environment.HttpGet,
	HttpPost = Environment.HttpPost,
	HttpPostAsync = Environment.HttpPost,
	GetObjects = Environment.GetObjects
})
Environment.game = ProxiedGame
Environment.Game = ProxiedGame

local ProxiedWorkspace = ProxyObjectFunction(workspace)
Environment.workspace = ProxiedWorkspace
Environment.Workspace = ProxiedWorkspace

local ProxiedScript = ProxyObjectFunction(script)
Environment.script = ProxiedScript

local HiddenUI = ProxyObjectFunction(Instance.new("ScreenGui", CoreGuiService))
HiddenUI.Name = "hidden_ui_container"

for _, descendant in ipairs(game:GetDescendants()) do
	ProxyObjectFunction(descendant)
end
game.DescendantAdded:Connect(ProxyObjectFunction)

local OriginalInstance = Instance
local FakeInstance = {}

FakeInstance.new = function(className, parentObject)
	return ProxyObjectFunction(OriginalInstance.new(className, ConvertToObject(parentObject)))
end

FakeInstance.fromExisting = function(existingObject)
	return ProxyObjectFunction(OriginalInstance.fromExisting(existingObject))
end

Environment.Instance = FakeInstance

Environment.getinstances = function()
	local AllInstances = {}
	for _, objectData in pairs(ObjectReferences) do
		table.insert(AllInstances, objectData.proxy)
	end
	return AllInstances
end

Environment.getnilinstances = function()
	local NilInstances = {}
	for _, objectData in pairs(ObjectReferences) do
		if objectData.proxy.Parent == nil then
			table.insert(NilInstances, objectData.proxy)
		end
	end
	return NilInstances
end

Environment.getloadedmodules = function()
	local LoadedModules = {}
	for _, objectData in pairs(ObjectReferences) do
		if objectData.proxy:IsA("ModuleScript") then
			table.insert(LoadedModules, objectData.proxy)
		end
	end
	return LoadedModules
end

Environment.getrunningscripts = function()
	local RunningScripts = {}
	for _, objectData in pairs(ObjectReferences) do
		if objectData.proxy:IsA("ModuleScript") then
			table.insert(RunningScripts, objectData.proxy)
		end
	end
	return RunningScripts
end

Environment.getscripts = function()
	local AllScripts = {}
	for _, objectData in pairs(ObjectReferences) do
		if objectData.proxy:IsA("LocalScript") or objectData.proxy:IsA("ModuleScript") or objectData.proxy:IsA("Script") then
			table.insert(AllScripts, objectData.proxy)
		end
	end
	return AllScripts
end

Environment.typeof = function(targetObject)
	local ObjectType = RealTypeof(targetObject)
	if ObjectType == "userdata" then
		if ProxiedObjects[targetObject] then
			return "Instance"
		else
			return ObjectType
		end
	else
		return ObjectType
	end
end

Environment.gethui = function()
	return HiddenUI
end

function Environment.setclipboard(content)
	assert(type(content) == "string", "invalid argument #1 to 'setclipboard' (string expected, got " .. type(content) .. ") ", 2)
	return Bridge:setclipboard(content)
end
Environment.toclipboard = Environment.setclipboard

local nilinstances, cache = {Instance.new("Part")}, {cached = {}}

function Environment.getnilinstances()
	return nilinstances
end

function Environment.getgc()
	return table.clone(nilinstances)
end

function Environment.hookfunction(func, rep)
	local env = getfenv(debug.info(2, 'f'))
	for i, v in pairs(env) do
		if v == func then
			env[i] = rep
			return rep
		end
	end
end
Environment.replaceclosure = Environment.hookfunction

function Environment.fireclickdetector(part)
	assert(typeof(part) == "Instance", "invalid argument #1 to 'fireclickdetector' (Instance expected, got " .. type(part) .. ") ", 2)
	local clickDetector = part:FindFirstChild("ClickDetector") or part
	local previousParent = clickDetector.Parent

	local newPart = Instance.new("Part", _workspace)
	do
		newPart.Transparency = 1
		newPart.Size = Vector3.new(30, 30, 30)
		newPart.Anchored = true
		newPart.CanCollide = false
		delay(15, function()
			if newPart:IsDescendantOf(game) then
				newPart:Destroy()
			end
		end)
		clickDetector.Parent = newPart
		clickDetector.MaxActivationDistance = math.huge
	end


	local vUser = game:FindService("VirtualUser") or game:GetService("VirtualUser")

	local connection = RunService.Heartbeat:Connect(function()
		local camera = _workspace.CurrentCamera or _workspace.Camera
		newPart.CFrame = camera.CFrame * CFrame.new(0, 0, -20) * CFrame.new(camera.CFrame.LookVector.X, camera.CFrame.LookVector.Y, camera.CFrame.LookVector.Z)
		vUser:ClickButton1(Vector2.new(20, 20), camera.CFrame)
	end)

	clickDetector.MouseClick:Once(function()
		connection:Disconnect()
		clickDetector.Parent = previousParent
		newPart:Destroy()
	end)
end

local CryptographyModule = {}

CryptographyModule.base64encode = Environment.base64encode
CryptographyModule.base64_encode = Environment.base64encode
CryptographyModule.base64decode = Environment.base64decode
CryptographyModule.base64_decode = Environment.base64decode
CryptographyModule.base64 = Base64Module

CryptographyModule.generatekey = function(keyLength)
	local GeneratedKey = ''
	local CharacterSet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
	for i = 1, keyLength or 32 do 
		local randomIndex = math.random(1, #CharacterSet) 
		GeneratedKey = GeneratedKey .. CharacterSet:sub(randomIndex, randomIndex) 
	end
	return Base64Module.encode(GeneratedKey)
end

CryptographyModule.encrypt = function(plainText, encryptionKey)
	local EncryptionResult = {}
	plainText = tostring(plainText) 
	encryptionKey = tostring(encryptionKey)
	for i = 1, #plainText do
		local textByte = string.byte(plainText, i)
		local keyByte = string.byte(encryptionKey, (i - 1) % #encryptionKey + 1)
		table.insert(EncryptionResult, string.char(bit32.bxor(textByte, keyByte)))
	end
	return table.concat(EncryptionResult), encryptionKey
end

CryptographyModule.generatebytes = function(byteLength)
	return CryptographyModule.generatekey(byteLength)
end

CryptographyModule.random = function(randomLength)
	return CryptographyModule.generatekey(randomLength)
end

CryptographyModule.decrypt = CryptographyModule.encrypt

local HashLibraryResponse = Environment.request({
	Url = "https://raw.githubusercontent.com/kakav420fire/DrawinLibbbb/refs/heads/main/draw.lua",
	Method = "GET"
})
local HashLibrary = {}

if HashLibraryResponse and HashLibraryResponse.Body then
	local LoadedFunction, LoadError = Environment.loadstring(HashLibraryResponse.Body)
	if LoadedFunction then
		HashLibrary = LoadedFunction()
	else
		warn(tostring(LoadError))
	end
end

local DrawingLibraryResponse = Environment.request({
	Url = "https://raw.githubusercontent.com/kakav420fire/DrawinLibbbb/refs/heads/main/main.lua",
	Method = "GET"
})

if DrawingLibraryResponse and DrawingLibraryResponse.Body then
	local LoadedFunction, LoadError = Environment.loadstring(DrawingLibraryResponse.Body)
	if LoadedFunction then
		local DrawingModule = LoadedFunction()
		Environment.Drawing = DrawingModule.Drawing
		for functionName, functionRef in DrawingModule.functions do
			Environment[functionName] = functionRef
		end
	else
		warn(tostring(LoadError))
	end
end

CryptographyModule.hash = function(inputText, hashAlgorithm)
	for algorithmName, hashFunction in pairs(HashLibrary) do
		if algorithmName == hashAlgorithm or algorithmName:gsub("_", "-") == hashAlgorithm then
			return hashFunction(inputText)
		end
	end
end

Environment.crypt = CryptographyModule
				
-- dawg who uses the rconsole functions
Environment.rconsoleclear = function()
end
Environment.consoleclear = Environment.rconsoleclear

Environment.rconsolecreate = function()
end
Environment.consolecreate = Environment.rconsolecreate

Environment.rconsoledestroy = function()
end
Environment.consoledestroy = Environment.rconsoledestroy

Environment.rconsoleinput = function()
	return ""
end
Environment.consoleinput = Environment.rconsoleinput

Environment.rconsoleprint = function(...)
end
Environment.consoleprint = Environment.rconsoleprint

Environment.rconsolesettitle = function(title)
end

Environment.mouse1press = function()
    VirtualInputManager:SendMouseButtonEvent(Mouse.X, Mouse.Y, 0, true, game, 0)
end

Environment.mouse1release = function()
    VirtualInputManager:SendMouseButtonEvent(Mouse.X, Mouse.Y, 0, false, game, 0)
end

Environment.mouse1click = function()
    Environment.mouse1press()
    Environment.mouse1release()
end

Environment.mouse2press = function()
    VirtualInputManager:SendMouseButtonEvent(Mouse.X, Mouse.Y, 1, true, game, 0)
end

Environment.mouse2release = function()
    VirtualInputManager:SendMouseButtonEvent(Mouse.X, Mouse.Y, 1, false, game, 0)
end

Environment.mouse2click = function()
    Environment.mouse2press()
    Environment.mouse2release()
end

Environment.mousemoveabs = function(x, y)
    VirtualInputManager:SendMouseWheelEvent(x, y, false, game)
end

Environment.mousemoverel = function(x, y)
    Environment.mousemoveabs(Camera.ViewportSize.X * x, Camera.ViewportSize.Y * y)
end
				
Environment.checkcaller = function()
	local info = debug.info(getgenv, 'slnaf')
	return debug.info(1, 'slnaf')==info
end

Environment.writefile = function(filepath, content)
	assert(type(filepath) == "string", "invalid argument #1 to 'writefile' (string expected, got " .. type(filepath) .. ") ", 2)
	assert(type(content) == "string", "invalid argument #2 to 'writefile' (string expected, got " .. type(content) .. ") ", 2)
	
	local result = SendRequest(content, "writefile", {
		["path"] = filepath
	})
	
	if result:find("ERROR:") == 1 then
		error(result:sub(8), 2)
	end
end

Environment.readfile = function(filepath)
	assert(type(filepath) == "string", "invalid argument #1 to 'readfile' (string expected, got " .. type(filepath) .. ") ", 2)
	
	local result = SendRequest("", "readfile", {
		["path"] = filepath
	})
	
	if result:find("ERROR:") == 1 then
		error(result:sub(8), 2)
	end
	
	return result
end

Environment.makefolder = function(folderpath)
	assert(type(folderpath) == "string", "invalid argument #1 to 'makefolder' (string expected, got " .. type(folderpath) .. ") ", 2)
	
	local result = SendRequest("", "makefolder", {
		["path"] = folderpath
	})
	
	if result:find("ERROR:") == 1 then
		error(result:sub(8), 2)
	end
end

Environment.isfolder = function(path)
	assert(type(path) == "string", "invalid argument #1 to 'isfolder' (string expected, got " .. type(path) .. ") ", 2)
	
	local result = SendRequest("", "isfolder", {
		["path"] = path
	})
	
	return result == "true"
end

Environment.isfile = function(path)
	assert(type(path) == "string", "invalid argument #1 to 'isfile' (string expected, got " .. type(path) .. ") ", 2)
	
	local result = SendRequest("", "isfile", {
		["path"] = path
	})
	
	return result == "true"
end

Environment.delfile = function(filepath)
	assert(type(filepath) == "string", "invalid argument #1 to 'delfile' (string expected, got " .. type(filepath) .. ") ", 2)
	
	local result = SendRequest("", "delfile", {
		["path"] = filepath
	})
	
	if result:find("ERROR:") == 1 then
		error(result:sub(8), 2)
	end
end

Environment.delfolder = function(folderpath)
	assert(type(folderpath) == "string", "invalid argument #1 to 'delfolder' (string expected, got " .. type(folderpath) .. ") ", 2)
	
	local result = SendRequest("", "delfolder", {
		["path"] = folderpath
	})
	
	if result:find("ERROR:") == 1 then
		error(result:sub(8), 2)
	end
end

Environment.listfiles = function(folderpath)
	assert(type(folderpath) == "string", "invalid argument #1 to 'listfiles' (string expected, got " .. type(folderpath) .. ") ", 2)
	
	local result = SendRequest("", "listfiles", {
		["path"] = folderpath
	})
	
	if result:find("ERROR:") == 1 then
		error(result:sub(8), 2)
	end
	
	local files = HttpService:JSONDecode(result)
	return files
end

Environment.appendfile = function(filepath, content)
	assert(type(filepath) == "string", "invalid argument #1 to 'appendfile' (string expected, got " .. type(filepath) .. ") ", 2)
	assert(type(content) == "string", "invalid argument #2 to 'appendfile' (string expected, got " .. type(content) .. ") ", 2)
	
	local result = SendRequest(content, "appendfile", {
		["path"] = filepath
	})
	
	if result:find("ERROR:") == 1 then
		error(result:sub(8), 2)
	end
end

Environment.loadfile = function(filepath)
	assert(type(filepath) == "string", "invalid argument #1 to 'loadfile' (string expected, got " .. type(filepath) .. ") ", 2)
	
	if not Environment.isfile(filepath) then
		return nil, "cannot open " .. filepath .. ": No such file or directory"
	end
	
	local content = Environment.readfile(filepath)
	local func, err = Environment.loadstring(content, "@" .. filepath)
	
	if not func then
		return nil, err
	end
	
	return func
end

Environment.dofile = function(filepath)
	assert(type(filepath) == "string", "invalid argument #1 to 'dofile' (string expected, got " .. type(filepath) .. ") ", 2)
	
	local func, err = Environment.loadfile(filepath)
	if not func then
		error(err, 2)
	end
	
	return func()
end

-- Event listener initialization
SendRequest("", "listen")
task.spawn(function()
	while true do
		local ListenerResponse = SendRequest("", "listen")
		if typeof(ListenerResponse) == "table" then
			MainFolder:Destroy()
			break
		end
		if ListenerResponse and #ListenerResponse > 1 then
			task.spawn(function()
				local ExecutableFunction, FunctionError = Environment.loadstring(ListenerResponse)
				if ExecutableFunction then
					local ExecutionSuccess, ExecutionError = pcall(ExecutableFunction)
					if not ExecutionSuccess then
						warn(ExecutionError)
					end
				else
					warn(FunctionError)
				end
			end)
		end
		task.wait()
	end
end)

local StarterGuiService = game:GetService("StarterGui")

StarterGuiService:SetCore("SendNotification", {
    Title = "Glacier",
    Text = "Glacier Attached To Roblox Client.",
    Duration = 10,         
    Callback = function()  
       
    end
})

warn("glcr-1.2.0b")

return {HideTemp = function() end}
