-- R63 GUI v2 loader
-- https://github.com/a65407112-boop/r63

local URL = "https://raw.githubusercontent.com/a65407112-boop/r63/main/hub.lua?r63v=2"

local ok, source = pcall(function()
    return game:HttpGet(URL, true)
end)

if not ok or type(source) ~= "string" or #source < 100 then
    error("R63 GUI: failed to download hub.lua.")
end

local fn, err = loadstring(source)
if not fn then
    error("R63 GUI hub compile error: " .. tostring(err))
end

fn()
