--[[
    R63 GUI v2
    Repository: https://github.com/a65407112-boop/r63

    Fixes compared with v1:
      * Uses SpecialMesh on the actual R6 body parts instead of CharacterMesh.
      * Current classic Shirt/Pants are remapped onto the custom mesh UVs.
      * Existing accessories are preserved.
      * Comma-separated catalog asset IDs are optional.
]]

local BASE = "https://raw.githubusercontent.com/a65407112-boop/r63/main"

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer

if getgenv and getgenv().R63_GUI_OBJECT then
    pcall(function()
        getgenv().R63_GUI_OBJECT:Destroy()
    end)
end

local CACHE_DIR = "r63_gui_v2"
local MESH_DIR = CACHE_DIR .. "/meshes"

local BODY = {
    ["Torso"] = "torso.mesh",
    ["Left Arm"] = "leftarm.mesh",
    ["Right Arm"] = "rightarm.mesh",
    ["Left Leg"] = "leftleg.mesh",
    ["Right Leg"] = "rightleg.mesh",
}

local SHIRT_PARTS = {
    ["Torso"] = true,
    ["Left Arm"] = true,
    ["Right Arm"] = true,
}

local PANTS_PARTS = {
    ["Torso"] = true,
    ["Left Leg"] = true,
    ["Right Leg"] = true,
}

local localMeshUris = {}
local addedByGui = {}
local autoReapply = false
local lastIdText = ""
local morphActive = false
local clothingSyncBusy = false

local function getChar()
    local char = player.Character or player.CharacterAdded:Wait()
    local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 10)
    if not hum then
        error("Humanoid not found.")
    end
    if hum.RigType ~= Enum.HumanoidRigType.R6 then
        error("R63 GUI v2 requires an R6 character.")
    end
    return char, hum
end

local function ensureFolder(path)
    if makefolder then
        pcall(makefolder, path)
    end
end

local function httpGet(url)
    local ok, body = pcall(function()
        return game:HttpGet(url, true)
    end)
    if not ok or type(body) ~= "string" or #body < 16 then
        error("Failed to download: " .. url)
    end
    return body
end

local function localAsset(path)
    if getcustomasset then
        return getcustomasset(path)
    elseif getsynasset then
        return getsynasset(path)
    end
    error("Your executor needs getcustomasset or getsynasset.")
end

local function downloadMesh(file)
    if localMeshUris[file] then
        return localMeshUris[file]
    end

    if not writefile then
        error("Your executor needs writefile.")
    end

    ensureFolder(CACHE_DIR)
    ensureFolder(MESH_DIR)

    local path = MESH_DIR .. "/" .. file
    local valid = false

    if isfile and readfile and isfile(path) then
        local ok, data = pcall(readfile, path)
        if ok and type(data) == "string" and #data > 100 then
            valid = true
        end
    end

    if not valid then
        local body = httpGet(BASE .. "/meshes/" .. file .. "?r63v=2")
        writefile(path, body)
    end

    local uri = localAsset(path)
    localMeshUris[file] = uri
    return uri
end

local function removeOldR63Objects(char)
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:GetAttribute("R63GUI") then
            obj:Destroy()
        end
    end

    -- Remove CharacterMesh objects created by the old R63 GUI.
    for _, obj in ipairs(char:GetChildren()) do
        if obj:IsA("CharacterMesh") then
            if obj.Name:match("^R63_") or obj:GetAttribute("R63GUI") then
                obj:Destroy()
            end
        end
    end
end

local function getSavedTemplate(clothing, propertyName)
    local live = clothing[propertyName]
    if live and live ~= "" then
        clothing:SetAttribute("R63SavedTemplate", live)
        return live
    end

    local saved = clothing:GetAttribute("R63SavedTemplate")
    if type(saved) == "string" then
        return saved
    end

    return ""
end

local function disableNativeClassicClothing(char)
    local shirtTexture = ""
    local pantsTexture = ""

    for _, obj in ipairs(char:GetChildren()) do
        if obj:IsA("Shirt") then
            local template = getSavedTemplate(obj, "ShirtTemplate")
            if template ~= "" then
                shirtTexture = template
            end
            if obj.ShirtTemplate ~= "" then
                obj.ShirtTemplate = ""
            end
        elseif obj:IsA("Pants") then
            local template = getSavedTemplate(obj, "PantsTemplate")
            if template ~= "" then
                pantsTexture = template
            end
            if obj.PantsTemplate ~= "" then
                obj.PantsTemplate = ""
            end
        end
    end

    return shirtTexture, pantsTexture
end

local function restoreNativeClassicClothing(char)
    for _, obj in ipairs(char:GetChildren()) do
        if obj:IsA("Shirt") then
            local saved = obj:GetAttribute("R63SavedTemplate")
            if type(saved) == "string" and saved ~= "" then
                obj.ShirtTemplate = saved
            end
            obj:SetAttribute("R63SavedTemplate", nil)
        elseif obj:IsA("Pants") then
            local saved = obj:GetAttribute("R63SavedTemplate")
            if type(saved) == "string" and saved ~= "" then
                obj.PantsTemplate = saved
            end
            obj:SetAttribute("R63SavedTemplate", nil)
        end
    end
end

local function makeOverlay(char, bodyPart, meshUri, textureId, kind, scale)
    if not textureId or textureId == "" then
        return
    end

    local overlay = Instance.new("Part")
    overlay.Name = "R63_" .. kind .. "_" .. bodyPart.Name:gsub(" ", "")
    overlay.Size = bodyPart.Size
    overlay.CFrame = bodyPart.CFrame
    overlay.Color = Color3.new(1, 1, 1)
    overlay.Material = Enum.Material.SmoothPlastic
    overlay.Transparency = 0
    overlay.CanCollide = false
    overlay.CanTouch = false
    overlay.CanQuery = false
    overlay.Massless = true
    overlay.CastShadow = false
    overlay:SetAttribute("R63GUI", true)
    overlay:SetAttribute("R63ClothingOverlay", true)
    overlay.Parent = char

    local mesh = Instance.new("SpecialMesh")
    mesh.Name = "R63ClothingMesh"
    mesh.MeshType = Enum.MeshType.FileMesh
    mesh.MeshId = meshUri
    mesh.TextureId = textureId
    mesh.Scale = Vector3.new(scale, scale, scale)
    mesh:SetAttribute("R63GUI", true)
    mesh.Parent = overlay

    local weld = Instance.new("WeldConstraint")
    weld.Part0 = bodyPart
    weld.Part1 = overlay
    weld:SetAttribute("R63GUI", true)
    weld.Parent = overlay
end

local function clearClothingOverlays(char)
    for _, obj in ipairs(char:GetChildren()) do
        if obj:GetAttribute("R63ClothingOverlay") then
            obj:Destroy()
        end
    end
end

local function syncClassicClothing(char)
    if clothingSyncBusy or not morphActive then
        return
    end

    clothingSyncBusy = true

    local ok, err = pcall(function()
        clearClothingOverlays(char)

        local shirtTexture, pantsTexture = disableNativeClassicClothing(char)

        for partName, file in pairs(BODY) do
            local bodyPart = char:FindFirstChild(partName)
            if bodyPart and bodyPart:IsA("BasePart") then
                local meshUri = localMeshUris[file] or downloadMesh(file)

                if SHIRT_PARTS[partName] and shirtTexture ~= "" then
                    makeOverlay(char, bodyPart, meshUri, shirtTexture, "Shirt", 1.006)
                end

                if PANTS_PARTS[partName] and pantsTexture ~= "" then
                    makeOverlay(char, bodyPart, meshUri, pantsTexture, "Pants", 1.012)
                end
            end
        end
    end)

    clothingSyncBusy = false

    if not ok then
        error(err)
    end
end

local function applyBody(status)
    local char = getChar()

    if status then
        status("Loading custom body meshes...")
    end

    removeOldR63Objects(char)

    -- Clear any old v2 meshes without touching the head mesh.
    for partName in pairs(BODY) do
        local part = char:FindFirstChild(partName)
        if part then
            for _, child in ipairs(part:GetChildren()) do
                if child:IsA("SpecialMesh") and child:GetAttribute("R63GUI") then
                    child:Destroy()
                end
            end
        end
    end

    for partName, file in pairs(BODY) do
        local part = char:FindFirstChild(partName)
        if not part or not part:IsA("BasePart") then
            error("Missing R6 body part: " .. partName)
        end

        local mesh = Instance.new("SpecialMesh")
        mesh.Name = "R63BodyMesh"
        mesh.MeshType = Enum.MeshType.FileMesh
        mesh.MeshId = downloadMesh(file)
        mesh.Scale = Vector3.new(1, 1, 1)
        mesh.Offset = Vector3.new(0, 0, 0)
        mesh:SetAttribute("R63GUI", true)
        mesh.Parent = part
    end

    morphActive = true

    RunService.Heartbeat:Wait()
    syncClassicClothing(char)

    if status then
        status("R63 body applied. Current Shirt/Pants adapted to the morph.")
    end
end

local function resetMorph(status)
    local char = player.Character
    if not char then
        return
    end

    morphActive = false
    clearClothingOverlays(char)

    for partName in pairs(BODY) do
        local part = char:FindFirstChild(partName)
        if part then
            for _, child in ipairs(part:GetChildren()) do
                if child:IsA("SpecialMesh") and child:GetAttribute("R63GUI") then
                    child:Destroy()
                end
            end
        end
    end

    restoreNativeClassicClothing(char)

    if status then
        status("R63 morph removed and normal classic clothing restored.")
    end
end

local function splitIds(text)
    local result = {}
    local seen = {}

    for token in tostring(text):gmatch("[^,%s;]+") do
        local id = token:match("(%d+)")
        if id and not seen[id] then
            seen[id] = true
            table.insert(result, id)
        end
    end

    return result
end

local supported = {
    Shirt = true,
    Pants = true,
    ShirtGraphic = true,
    Accessory = true,
    Hat = true,
    BodyColors = true,
}

local function collectSupported(root)
    local result = {}

    if supported[root.ClassName] then
        table.insert(result, root)
    end

    for _, obj in ipairs(root:GetDescendants()) do
        if supported[obj.ClassName] then
            table.insert(result, obj)
        end
    end

    return result
end

local function removeClass(char, className)
    for _, obj in ipairs(char:GetChildren()) do
        if obj.ClassName == className then
            obj:Destroy()
        end
    end
end

local function addWearable(char, hum, source)
    local clone = source:Clone()

    if clone:IsA("Shirt") then
        removeClass(char, "Shirt")
        clone.Parent = char
    elseif clone:IsA("Pants") then
        removeClass(char, "Pants")
        clone.Parent = char
    elseif clone:IsA("ShirtGraphic") then
        removeClass(char, "ShirtGraphic")
        clone.Parent = char
    elseif clone:IsA("BodyColors") then
        removeClass(char, "BodyColors")
        clone.Parent = char
    elseif clone:IsA("Accessory") or clone:IsA("Hat") then
        clone.Parent = nil
        local ok = pcall(function()
            hum:AddAccessory(clone)
        end)
        if not ok then
            clone.Parent = char
        end
    else
        clone:Destroy()
        return false
    end

    clone:SetAttribute("R63GUIAdded", true)
    table.insert(addedByGui, clone)
    return true
end

local function applyIds(text, status)
    local char, hum = getChar()
    local ids = splitIds(text)

    if #ids == 0 then
        error("Enter at least one asset ID.")
    end

    lastIdText = text
    local applied = 0
    local failed = {}

    for i, id in ipairs(ids) do
        if status then
            status(("Loading ID %d/%d: %s"):format(i, #ids, id))
        end

        local ok, roots = pcall(function()
            return game:GetObjects("rbxassetid://" .. id)
        end)

        local found = false

        if ok and type(roots) == "table" then
            for _, root in ipairs(roots) do
                for _, obj in ipairs(collectSupported(root)) do
                    if addWearable(char, hum, obj) then
                        found = true
                        applied += 1
                    end
                end
                root:Destroy()
            end
        end

        if not found then
            table.insert(failed, id)
        end
    end

    if morphActive then
        task.wait()
        syncClassicClothing(char)
    end

    if #failed > 0 then
        status(("Applied %d item(s). Failed IDs: %s"):format(applied, table.concat(failed, ", ")))
    else
        status(("Applied %d item(s). Clothing remapped to R63 body."):format(applied))
    end
end

local function clearGuiItems(status)
    local char = player.Character

    for i = #addedByGui, 1, -1 do
        local obj = addedByGui[i]
        if obj and obj.Parent then
            obj:Destroy()
        end
        addedByGui[i] = nil
    end

    if char then
        for _, obj in ipairs(char:GetChildren()) do
            if obj:GetAttribute("R63GUIAdded") then
                obj:Destroy()
            end
        end

        if morphActive then
            syncClassicClothing(char)
        end
    end

    status("Removed clothing/accessories added through the ID box.")
end

-- =========================
-- GUI
-- =========================

local gui = Instance.new("ScreenGui")
gui.Name = "R63 GUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local parented = false
if gethui then
    parented = pcall(function()
        gui.Parent = gethui()
    end)
end
if not parented or not gui.Parent then
    pcall(function()
        gui.Parent = CoreGui
    end)
end
if not gui.Parent then
    gui.Parent = player:WaitForChild("PlayerGui")
end

if getgenv then
    getgenv().R63_GUI_OBJECT = gui
end

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(410, 474)
main.Position = UDim2.new(0.5, -205, 0.5, -237)
main.BackgroundColor3 = Color3.fromRGB(24, 24, 29)
main.BorderSizePixel = 0
main.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = main

local outline = Instance.new("UIStroke")
outline.Color = Color3.fromRGB(76, 76, 90)
outline.Parent = main

local top = Instance.new("Frame")
top.Size = UDim2.new(1, 0, 0, 48)
top.BackgroundTransparency = 1
top.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -58, 1, 0)
title.Position = UDim2.fromOffset(16, 0)
title.BackgroundTransparency = 1
title.Text = "R63 GUI v2"
title.TextColor3 = Color3.fromRGB(245, 245, 250)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
title.TextSize = 21
title.Parent = top

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(34, 34)
close.Position = UDim2.new(1, -42, 0, 7)
close.BackgroundColor3 = Color3.fromRGB(49, 49, 58)
close.Text = "×"
close.TextColor3 = Color3.fromRGB(245, 245, 250)
close.Font = Enum.Font.GothamBold
close.TextSize = 22
close.Parent = top
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 8)
close.MouseButton1Click:Connect(function()
    gui:Destroy()
end)

local label = Instance.new("TextLabel")
label.Size = UDim2.new(1, -32, 0, 22)
label.Position = UDim2.fromOffset(16, 58)
label.BackgroundTransparency = 1
label.Text = "Optional clothing / accessory asset IDs"
label.TextColor3 = Color3.fromRGB(210, 210, 220)
label.TextXAlignment = Enum.TextXAlignment.Left
label.Font = Enum.Font.Gotham
label.TextSize = 14
label.Parent = main

local idsBox = Instance.new("TextBox")
idsBox.Size = UDim2.new(1, -32, 0, 70)
idsBox.Position = UDim2.fromOffset(16, 84)
idsBox.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
idsBox.BorderSizePixel = 0
idsBox.ClearTextOnFocus = false
idsBox.MultiLine = true
idsBox.TextWrapped = true
idsBox.TextXAlignment = Enum.TextXAlignment.Left
idsBox.TextYAlignment = Enum.TextYAlignment.Top
idsBox.TextColor3 = Color3.fromRGB(245, 245, 250)
idsBox.PlaceholderColor3 = Color3.fromRGB(130, 130, 143)
idsBox.PlaceholderText = "123456789, 987654321, 555555555"
idsBox.Font = Enum.Font.Code
idsBox.TextSize = 14
idsBox.Parent = main
Instance.new("UICorner", idsBox).CornerRadius = UDim.new(0, 8)

local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 10)
padding.PaddingRight = UDim.new(0, 10)
padding.PaddingTop = UDim.new(0, 8)
padding.PaddingBottom = UDim.new(0, 8)
padding.Parent = idsBox

local function button(text, x, y, w)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(w, 42)
    b.Position = UDim2.fromOffset(x, y)
    b.BackgroundColor3 = Color3.fromRGB(51, 51, 61)
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = Color3.fromRGB(245, 245, 250)
    b.Font = Enum.Font.GothamSemibold
    b.TextSize = 14
    b.Parent = main
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    return b
end

local applyMorphBtn = button("Apply R63 morph + current outfit", 16, 168, 378)
local refreshBtn = button("Refresh clothing mapping", 16, 220, 184)
local applyIdsBtn = button("Apply IDs", 210, 220, 184)
local applyAllBtn = button("Apply morph + IDs", 16, 272, 378)
local clearBtn = button("Clear ID-added items", 16, 324, 184)
local resetBtn = button("Reset morph", 210, 324, 184)
local autoBtn = button("Auto reapply on respawn: OFF", 16, 376, 378)

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -32, 0, 46)
statusLabel.Position = UDim2.fromOffset(16, 425)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Ready. Existing Shirt/Pants will be mapped onto the custom mesh."
statusLabel.TextColor3 = Color3.fromRGB(165, 165, 180)
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
local function run(fn)
    if busy then
        return
    end
    busy = true
    task.spawn(function()
        local ok, err = pcall(fn)
        if not ok then
            status("Error: " .. tostring(err))
        end
        busy = false
    end)
end

applyMorphBtn.MouseButton1Click:Connect(function()
    run(function()
        applyBody(status)
    end)
end)

refreshBtn.MouseButton1Click:Connect(function()
    run(function()
        local char = getChar()
        if not morphActive then
            applyBody(status)
        else
            syncClassicClothing(char)
            status("Current Shirt/Pants mapping refreshed.")
        end
    end)
end)

applyIdsBtn.MouseButton1Click:Connect(function()
    run(function()
        applyIds(idsBox.Text, status)
    end)
end)

applyAllBtn.MouseButton1Click:Connect(function()
    run(function()
        applyBody(status)
        if idsBox.Text:match("%d") then
            applyIds(idsBox.Text, status)
        end
        status("Morph and selected IDs applied.")
    end)
end)

clearBtn.MouseButton1Click:Connect(function()
    run(function()
        clearGuiItems(status)
    end)
end)

resetBtn.MouseButton1Click:Connect(function()
    run(function()
        resetMorph(status)
    end)
end)

autoBtn.MouseButton1Click:Connect(function()
    autoReapply = not autoReapply
    autoBtn.Text = "Auto reapply on respawn: " .. (autoReapply and "ON" or "OFF")
    status(autoReapply and "Auto reapply enabled." or "Auto reapply disabled.")
end)

player.CharacterAdded:Connect(function()
    morphActive = false

    if not autoReapply then
        return
    end

    task.wait(1.2)

    run(function()
        applyBody(status)

        if lastIdText:match("%d") then
            applyIds(lastIdText, status)
        end

        status("R63 morph reapplied after respawn.")
    end)
end)

-- If the game adds/replaces classic clothing while the morph is active,
-- remap it automatically.
local watchedCharacter

local function watchCharacter(char)
    watchedCharacter = char

    char.ChildAdded:Connect(function(obj)
        if watchedCharacter ~= char or not morphActive then
            return
        end

        if obj:IsA("Shirt") or obj:IsA("Pants") then
            task.defer(function()
                if morphActive and char.Parent then
                    pcall(function()
                        syncClassicClothing(char)
                    end)
                end
            end)
        end
    end)
end

if player.Character then
    watchCharacter(player.Character)
end
player.CharacterAdded:Connect(watchCharacter)

-- Drag window.
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
