-- R63 GUI v7 always-fresh loader
local BASE_URL = "https://raw.githubusercontent.com/a65407112-boop/r63/main/hub.lua"
local NONCE = table.concat({
    tostring(os.time()),
    tostring(math.floor(os.clock() * 1000000)),
    tostring(math.random(100000, 999999)),
}, "_")
local URL = BASE_URL .. "?nocache=" .. NONCE

local ok, source = pcall(function()
    return game:HttpGet(URL)
end)
if not ok or type(source) ~= "string" or #source < 100 then
    error("R63 GUI: failed to download hub.lua")
end
if not source:find("R63 GUI v7", 1, true) then
    error("R63 GUI: GitHub returned an unexpected or cached script")
end

local chunk, compileError = loadstring(source)
if not chunk then
    error("R63 GUI compile error: " .. tostring(compileError))
end
return chunk()
