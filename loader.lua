-- R63 GUI v6 always-fresh loader
local BASE = "https://raw.githubusercontent.com/a65407112-boop/r63/main/r63_v6.lua"
local URL = BASE .. "?nocache=" .. tostring(os.time()) .. "_" .. tostring(math.random(100000,999999))

local ok, source = pcall(function()
    return game:HttpGet(URL, false)
end)

if not ok or type(source) ~= "string" or #source < 100 then
    error("R63 GUI: failed to download v6")
end

if not source:find("R63 GUI v6", 1, true) then
    warn("R63 GUI: unexpected cached version")
end

local fn, err = loadstring(source)
if not fn then
    error("R63 GUI compile error: " .. tostring(err))
end

fn()
