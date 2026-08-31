-- R63 GUI always-fresh loader
local BASE = "https://raw.githubusercontent.com/a65407112-boop/r63/main/hub.lua"

-- Different URL every run so executor/CDN caches cannot keep an old hub.lua.
local nonce = tostring(os.time()) .. "_" .. tostring(math.random(100000, 999999))
local URL = BASE .. "?nocache=" .. nonce

local ok, source = pcall(function()
    return game:HttpGet(URL, true)
end)

if not ok or type(source) ~= "string" or #source < 100 then
    error("R63 GUI: failed to download latest hub.lua.")
end

-- Small sanity check so stale v3 is obvious instead of silently loading.
if not source:find("R63 GUI v4", 1, true) then
    warn("R63 GUI: downloaded hub.lua is not marked v4; forcing execution anyway.")
end

local fn, err = loadstring(source)
if not fn then
    error("R63 GUI compile error: " .. tostring(err))
end

fn()
