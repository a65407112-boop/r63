-- R63 GUI v5.1 always-fresh loader
local BASE = "https://raw.githubusercontent.com/a65407112-boop/r63/main/hub.lua"
local URL = BASE .. "?nocache=" .. tostring(os.time()) .. "_" .. tostring(math.random(100000,999999))

local ok, source = pcall(function()
    return game:HttpGet(URL, false)
end)

if not ok or type(source) ~= "string" or #source < 100 then
    error("R63 GUI: failed to download latest hub.lua")
end

if not source:find("R63 GUI v5.1", 1, true) then
    warn("R63 GUI: unexpected cached hub version")
end

local fn, err = loadstring(source)
if not fn then
    error("R63 GUI compile error: " .. tostring(err))
end

fn()
