-- R63 GUI v6 compatibility loader; the maintained implementation is R63 GUI v7 in hub.lua.
local URL = "https://raw.githubusercontent.com/a65407112-boop/r63/main/hub.lua?compat_v6="
    .. tostring(os.time())
    .. "_"
    .. tostring(math.random(100000, 999999))

local ok, source = pcall(function()
    return game:HttpGet(URL)
end)
if not ok or type(source) ~= "string" or #source < 100 then
    error("R63 GUI: failed to download the maintained v7 script")
end
if not source:find("R63 GUI v7", 1, true) then
    error("R63 GUI: unexpected cached script")
end

local chunk, compileError = loadstring(source)
if not chunk then
    error("R63 GUI compile error: " .. tostring(compileError))
end
return chunk()
