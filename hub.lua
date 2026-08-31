--[[
    R63 GUI
    R6 custom body mesh + classic clothing/accessory loader.

    Designed for executors that provide:
      - game:HttpGet
      - writefile
      - getcustomasset OR getsynasset
    Optional:
      - isfile
      - makefolder

    The mesh files are downloaded from the same GitHub repo as this script.
]]

if getgenv and getgenv().R63_GUI_LOADED then
    local old = game:GetService("CoreGui"):FindFirstChild("R63 GUI")
    if old then old:Destroy() end
end
if getgenv then
    getgenv().R63_GUI_LOADED = true
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer

-- loader.lua sets this automatically.
-- If you run hub.lua directly, replace the placeholder below.
local BASE_URL =
    (getgenv and getgenv().R63_REPO_BASE)
    or "https://raw.githubusercontent.com/a65407112-boop/r63/main"

BASE_URL = BASE_URL:gsub("/+$", "")

local CACHE_DIR = "r63_gui"
local MESH_DIR = CACHE_DIR .. "/meshes"

local MESHES = {
    {part = Enum.BodyPart.Torso,    file = "torso.mesh",    label = "Torso"},
    {part = Enum.BodyPart.LeftArm,  file = "leftarm.mesh",  label = "Left Arm"},
    {part = Enum.BodyPart.RightArm, file = "rightarm.mesh", label = "Right Arm"},
    {part = Enum.BodyPart.LeftLeg,  file = "leftleg.mesh",  label = "Left Leg"},
    {part = Enum.BodyPart.RightLeg, file = "rightleg.mesh", label = "Right Leg"},
}

local addedInstances = {}
local autoReapply = false
local lastAssetText = ""

local function getCharacter()
    local char = player.Character or player.CharacterAdded:Wait()
    local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 10)
    return char, hum
end

local function ensureR6()
    local char, hum = getCharacter()
    if not hum then
        return nil, "Humanoid not found."
    end
    if hum.RigType ~= Enum.HumanoidRigType.R6 then
        return nil, "R63 GUI currently requires an R6 character."
    end
    return char
end

local function ensureFolder(path)
    if makefolder then
        pcall(makefolder, path)
    end
end

local function readCached(path)
    if isfile and isfile(path) and readfile then
        local ok, data = pcall(readfile, path)
        if ok and data and #data > 0 then
            return data
        end
    end
    return nil
end

local function download(url)
    local ok, body = pcall(function()
        return game:HttpGet(url, true)
    end)
    if not ok or type(body) ~= "string" or #body < 16 then
        error("Download failed: " .. tostring(url))
    end
    return body
end

local function customAsset(path)
    if getcustomasset then
        return getcustomasset(path)
    end
    if getsynasset then
        return getsynasset(path)
    end
    error("Your executor does not provide getcustomasset/getsynasset.")
end

local function localMesh(file)
    ensureFolder(CACHE_DIR)
    ensureFolder(MESH_DIR)

    local path = MESH_DIR .. "/" .. file
    local cached = readCached(path)

    if not cached then
        if not writefile then
            error("Your executor does not provide writefile.")
        end
        local body = download(BASE_URL .. "/meshes/" .. file)
        writefile(path, body)
    end

    return customAsset(path)
end

local function bodyPartKey(partEnum)
    return "R63_" .. tostring(partEnum):gsub("Enum.BodyPart.", "")
end

local function removeR63Meshes(char)
    for _, obj in ipairs(char:GetChildren()) do
        if obj:IsA("CharacterMesh") and obj:GetAttribute("R63GUI") then
            obj:Destroy()
        end
    end
end

local function refreshClassicClothes(char)
    -- Re-parenting classic clothing after the body mesh is replaced makes
    -- Roblox recalculate the classic shirt/pants rendering on the morph.
    local clones = {}
    for _, obj in ipairs(char:GetChildren()) do
        if obj:IsA("Shirt") or obj:IsA("Pants") or obj:IsA("ShirtGraphic") then
            table.insert(clones, obj:Clone())
            obj:Destroy()
        end
    end
    RunService.Heartbeat:Wait()
    for _, clone in ipairs(clones) do
        clone.Parent = char
    end
end

local function applyBodyMeshes(status)
    local char, err = ensureR6()
    if not char then
        error(err)
    end

    if status then status("Downloading / applying body meshes...") end

    removeR63Meshes(char)

    for _, info in ipairs(MESHES) do
        local mesh = Instance.new("CharacterMesh")
        mesh.Name = bodyPartKey(info.part)
        mesh.BodyPart = info.part
        mesh.MeshId = localMesh(info.file)
        mesh:SetAttribute("R63GUI", true)
        mesh.Parent = char
    end

    refreshClassicClothes(char)

    if status then status("R63 body applied.") end
end

local function splitIds(text)
    local out, seen = {}, {}
    for token in tostring(text):gmatch("[^,%s;]+") do
        local id = token:match("(%d+)")
        if id and not seen[id] then
            seen[id] = true
            table.insert(out, id)
        end
    end
    return out
end

local wearableClasses = {
    Shirt = true,
    Pants = true,
    ShirtGraphic = true,
    Accessory = true,
    Hat = true,
    BodyColors = true,
}

local function collectWearables(root)
    local found = {}

    local function inspect(obj)
        if wearableClasses[obj.ClassName] then
            table.insert(found, obj)
        end
    end

    inspect(root)
    for _, obj in ipairs(root:GetDescendants()) do
        inspect(obj)
    end

    return found
end

local function destroyClass(char, className)
    for _, obj in ipairs(char:GetChildren()) do
        if obj.ClassName == className then
            obj:Destroy()
        end
    end
end

local function markAdded(obj)
    obj:SetAttribute("R63GUIAdded", true)
    table.insert(addedInstances, obj)
end

local function applyWearable(char, hum, obj)
    local clone = obj:Clone()

    if clone:IsA("Shirt") then
        destroyClass(char, "Shirt")
        clone.Parent = char
        markAdded(clone)
        return true
    elseif clone:IsA("Pants") then
        destroyClass(char, "Pants")
        clone.Parent = char
        markAdded(clone)
        return true
    elseif clone:IsA("ShirtGraphic") then
        destroyClass(char, "ShirtGraphic")
        clone.Parent = char
        markAdded(clone)
        return true
    elseif clone:IsA("BodyColors") then
        destroyClass(char, "BodyColors")
        clone.Parent = char
        markAdded(clone)
        return true
    elseif clone:IsA("Accessory") or clone:IsA("Hat") then
        clone.Parent = nil
        local ok = pcall(function()
            hum:AddAccessory(clone)
        end)
        if not ok then
            clone.Parent = char
        end
        markAdded(clone)
        return true
    end

    clone:Destroy()
    return false
end

local function loadAssetObjects(id)
    local ok, objects = pcall(function()
        return game:GetObjects("rbxassetid://" .. id)
    end)
    if not ok or type(objects) ~= "table" then
        return {}
    end
    return objects
end

local function applyAssetIds(text, status)
    local char, err = ensureR6()
    if not char then
        error(err)
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local ids = splitIds(text)
    if #ids == 0 then
        error("Enter at least one Roblox asset ID.")
    end

    lastAssetText = text

    local applied = 0
    local failed = {}

    for i, id in ipairs(ids) do
        if status then
            status(("Loading asset %d/%d: %s"):format(i, #ids, id))
        end

        local roots = loadAssetObjects(id)
        local gotAny = false

        for _, root in ipairs(roots) do
            local wearables = collectWearables(root)
            for _, wearable in ipairs(wearables) do
                local ok = applyWearable(char, hum, wearable)
                if ok then
                    applied += 1
                    gotAny = true
                end
            end
            root:Destroy()
        end

        if not gotAny then
            table.insert(failed, id)
        end
    end

    refreshClassicClothes(char)

    if #failed > 0 then
        if status then
            status(("Applied %d item(s). Could not load: %s"):format(applied, table.concat(failed, ", ")))
        end
    else
        if status then
            status(("Applied %d wearable item(s)."):format(applied))
        end
    end
end

local function clearAdded(status)
    for i = #addedInstances, 1, -1 do
        local obj = addedInstances[i]
        if obj and obj.Parent then
            obj:Destroy()
        end
        addedInstances[i] = nil
    end

    local char = player.Character
    if char then
        for _, obj in ipairs(char:GetChildren()) do
            if obj:GetAttribute("R63GUIAdded") then
                obj:Destroy()
            end
        end
    end

    if status then status("Removed items added by R63 GUI.") end
end

-- =========================
-- GUI
-- =========================

local gui = Instance.new("ScreenGui")
gui.Name = "R63 GUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

pcall(function()
    gui.Parent = CoreGui
end)
if not gui.Parent then
    gui.Parent = player:WaitForChild("PlayerGui")
end

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(390, 410)
main.Position = UDim2.new(0.5, -195, 0.5, -205)
main.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
main.BorderSizePixel = 0
main.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = main

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(75, 75, 88)
stroke.Thickness = 1
stroke.Parent = main

local top = Instance.new("Frame")
top.Size = UDim2.new(1, 0, 0, 48)
top.BackgroundTransparency = 1
top.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -60, 1, 0)
title.Position = UDim2.fromOffset(16, 0)
title.BackgroundTransparency = 1
title.Text = "R63 GUI"
title.TextColor3 = Color3.fromRGB(245, 245, 250)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
title.TextSize = 21
title.Parent = top

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(34, 34)
close.Position = UDim2.new(1, -42, 0, 7)
close.BackgroundColor3 = Color3.fromRGB(48, 48, 56)
close.Text = "×"
close.TextColor3 = Color3.fromRGB(240, 240, 245)
close.Font = Enum.Font.GothamBold
close.TextSize = 22
close.Parent = top
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 8)
close.MouseButton1Click:Connect(function()
    gui:Destroy()
    if getgenv then getgenv().R63_GUI_LOADED = false end
end)

local idsLabel = Instance.new("TextLabel")
idsLabel.Size = UDim2.new(1, -32, 0, 22)
idsLabel.Position = UDim2.fromOffset(16, 58)
idsLabel.BackgroundTransparency = 1
idsLabel.Text = "Avatar / clothing asset IDs"
idsLabel.TextColor3 = Color3.fromRGB(210, 210, 220)
idsLabel.TextXAlignment = Enum.TextXAlignment.Left
idsLabel.Font = Enum.Font.Gotham
idsLabel.TextSize = 14
idsLabel.Parent = main

local ids = Instance.new("TextBox")
ids.Size = UDim2.new(1, -32, 0, 72)
ids.Position = UDim2.fromOffset(16, 84)
ids.BackgroundColor3 = Color3.fromRGB(34, 34, 40)
ids.BorderSizePixel = 0
ids.ClearTextOnFocus = false
ids.MultiLine = true
ids.TextWrapped = true
ids.TextXAlignment = Enum.TextXAlignment.Left
ids.TextYAlignment = Enum.TextYAlignment.Top
ids.TextColor3 = Color3.fromRGB(245, 245, 250)
ids.PlaceholderColor3 = Color3.fromRGB(125, 125, 138)
ids.PlaceholderText = "Example: 123456789, 987654321, 555555555"
ids.Text = ""
ids.Font = Enum.Font.Code
ids.TextSize = 14
ids.Parent = main
Instance.new("UICorner", ids).CornerRadius = UDim.new(0, 8)

local pad = Instance.new("UIPadding")
pad.PaddingLeft = UDim.new(0, 10)
pad.PaddingRight = UDim.new(0, 10)
pad.PaddingTop = UDim.new(0, 8)
pad.PaddingBottom = UDim.new(0, 8)
pad.Parent = ids

local function mkButton(text, y, widthScale, xOffset)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(widthScale or 1, widthScale == 1 and -32 or -20, 0, 42)
    b.Position = UDim2.new(xOffset or 0, xOffset and 8 or 16, 0, y)
    b.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = Color3.fromRGB(245, 245, 250)
    b.Font = Enum.Font.GothamSemibold
    b.TextSize = 14
    b.AutoButtonColor = true
    b.Parent = main
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    return b
end

local applyBody = mkButton("Apply R63 body meshes", 170, 1)
local applyIds = mkButton("Apply IDs", 222, 0.5, 0)
applyIds.Size = UDim2.new(0.5, -20, 0, 42)
applyIds.Position = UDim2.fromOffset(16, 222)

local applyAll = mkButton("Apply all", 222, 0.5, 0.5)
applyAll.Size = UDim2.new(0.5, -20, 0, 42)
applyAll.Position = UDim2.new(0.5, 4, 0, 222)

local clear = mkButton("Clear items added by GUI", 274, 1)

local auto = mkButton("Auto reapply on respawn: OFF", 326, 1)

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -32, 0, 34)
statusLabel.Position = UDim2.fromOffset(16, 372)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Ready."
statusLabel.TextColor3 = Color3.fromRGB(165, 165, 178)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.TextWrapped = true
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 12
statusLabel.Parent = main

local function status(text)
    statusLabel.Text = tostring(text)
end

local busy = false
local function runAction(fn)
    if busy then return end
    busy = true
    task.spawn(function()
        local ok, err = pcall(fn)
        if not ok then
            status("Error: " .. tostring(err))
        end
        busy = false
    end)
end

applyBody.MouseButton1Click:Connect(function()
    runAction(function()
        applyBodyMeshes(status)
    end)
end)

applyIds.MouseButton1Click:Connect(function()
    runAction(function()
        applyAssetIds(ids.Text, status)
    end)
end)

applyAll.MouseButton1Click:Connect(function()
    runAction(function()
        applyBodyMeshes(status)
        if ids.Text:match("%d") then
            applyAssetIds(ids.Text, status)
        end
        status("R63 body + selected assets applied.")
    end)
end)

clear.MouseButton1Click:Connect(function()
    runAction(function()
        clearAdded(status)
    end)
end)

auto.MouseButton1Click:Connect(function()
    autoReapply = not autoReapply
    auto.Text = "Auto reapply on respawn: " .. (autoReapply and "ON" or "OFF")
    auto.BackgroundColor3 = autoReapply
        and Color3.fromRGB(66, 74, 66)
        or Color3.fromRGB(50, 50, 60)
end)

player.CharacterAdded:Connect(function()
    if not autoReapply then return end
    task.wait(1.25)
    runAction(function()
        applyBodyMeshes(status)
        if lastAssetText:match("%d") then
            applyAssetIds(lastAssetText, status)
        end
        status("Auto reapplied R63 morph.")
    end)
end)

-- Dragging
do
    local dragging = false
    local dragStart
    local startPos

    top.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
        end
    end)

    top.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (
            input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch
        ) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

status("Ready. Apply body first, then IDs, or use Apply all.")
