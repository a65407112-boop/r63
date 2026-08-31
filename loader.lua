-- R63 GUI loader
-- Repository: https://github.com/a65407112-boop/r63

local BASE = "https://raw.githubusercontent.com/a65407112-boop/r63/main"

if getgenv then
    getgenv().R63_REPO_BASE = BASE
end

local ok, source = pcall(function()
    return game:HttpGet(BASE .. "/hub.lua", true)
end)

if not ok or type(source) ~= "string" or #source < 50 then
    error("R63 GUI: failed to download hub.lua from GitHub.")
end

local fn, compileError = loadstring(source)
if not fn then
    error("R63 GUI: hub.lua compile error: " .. tostring(compileError))
end

fn()
