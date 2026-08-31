--[[
    R63 GUI v4 - Rebuild Morph
    Repo: https://github.com/a65407112-boop/r63

    Main design:
      * Save the current classic outfit/accessories first.
      * Remove current cosmetic instances.
      * Hide the original R6 torso/arms/legs.
      * Build a separate welded visual body using the custom .mesh files.
      * Remap Shirt/Pants textures onto matching custom body meshes.
      * If no IDs are provided, use the outfit that was already on the character.
      * If IDs are provided, only categories actually found in those IDs override
        the saved outfit. Missing categories keep the saved version.
      * Accessories are attached by matching Attachments with a legacy R6 fallback.
      * Compact HSV color wheel.
      * GUI always opens centered.
]]

local BASE = "https://raw.githubusercontent.com/a65407112-boop/r63/main"

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local InsertService = game:GetService("InsertService")

local player = Players.LocalPlayer

if getgenv and getgenv().R63_GUI_OBJECT then
    pcall(function()
        getgenv().R63_GUI_OBJECT:Destroy()
    end)
end

local CACHE_DIR = "r63_gui_v4"
local MESH_DIR = CACHE_DIR .. "/meshes"

local BODY_FILES = {
    ["Torso"] = "torso.mesh",
    ["Left Arm"] = "leftarm.mesh",
    ["Right Arm"] = "rightarm.mesh",
    ["Left Leg"] = "leftleg.mesh",
    ["Right Leg"] = "rightleg.mesh",
}

local BODY_ORDER = {
    "Torso",
    "Left Arm",
    "Right Arm",
    "Left Leg",
    "Right Leg",
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

local meshUris = {}
local morphActive = false
local autoReapply = false
local lastIdText = ""
local savedOutfit = nil

-- HSV skin state. Starts near a common light skin tone.
local skinH = 0.075
local skinS = 0.30
local skinV = 1.00

local function currentSkinColor()
    return Color3.fromHSV(skinH, skinS, skinV)
end

local function getCharacter()
    local char = player.Character or player.CharacterAdded:Wait()
    local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 10)

    if not hum then
        error("R63 GUI: Humanoid not found.")
    end

    if hum.RigType ~= Enum.HumanoidRigType.R6 then
        error("R63 GUI: this morph requires R6.")
    end

    return char, hum
end

local function ensureFolder(path)
    if makefolder then
        pcall(makefolder, path)
    end
end

local function customAsset(path)
    if getcustomasset then
        return getcustomasset(path)
    end

    if getsynasset then
        return getsynasset(path)
    end

    error("R63 GUI: executor needs getcustomasset or getsynasset.")
end

local function downloadMesh(file)
    if meshUris[file] then
        return meshUris[file]
    end

    if not writefile then
        error("R63 GUI: executor needs writefile.")
    end

    ensureFolder(CACHE_DIR)
    ensureFolder(MESH_DIR)

    local path = MESH_DIR .. "/" .. file
    local good = false

    if isfile and readfile and isfile(path) then
        local ok, bytes = pcall(readfile, path)
        good = ok and type(bytes) == "string" and #bytes > 100
    end

    if not good then
        local ok, bytes = pcall(function()
            return game:HttpGet(BASE .. "/meshes/" .. file .. "?r63v=4", true)
        end)

        if not ok or type(bytes) ~= "string" or #bytes < 100 then
            error("R63 GUI: failed to download " .. file)
        end

        writefile(path, bytes)
    end

    meshUris[file] = customAsset(path)
    return meshUris[file]
end

local function cloneSafe(obj)
    local old = obj.Archivable
    obj.Archivable = true

    local ok, result = pcall(function()
        return obj:Clone()
    end)

    obj.Archivable = old

    if ok then
        return result
    end

    return nil
end

local function snapshotCurrentOutfit(char)
    local result = {
        shirtTemplate = "",
        pantsTemplate = "",
        shirtGraphic = "",
        accessories = {},
        bodyColors = nil,
    }

    local shirt = char:FindFirstChildOfClass("Shirt")
    if shirt then
        result.shirtTemplate = shirt.ShirtTemplate
    end

    local pants = char:FindFirstChildOfClass("Pants")
    if pants then
        result.pantsTemplate = pants.PantsTemplate
    end

    local graphic = char:FindFirstChildOfClass("ShirtGraphic")
    if graphic then
        result.shirtGraphic = graphic.Graphic
    end

    local bodyColors = char:FindFirstChildOfClass("BodyColors")
    if bodyColors then
        result.bodyColors = cloneSafe(bodyColors)
    end

    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Accessory") or child:IsA("Hat") then
            local copy = cloneSafe(child)
            if copy then
                table.insert(result.accessories, copy)
            end
        end
    end

    return result
end

local function destroyCosmetics(char)
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Shirt")
        or child:IsA("Pants")
        or child:IsA("ShirtGraphic")
        or child:IsA("Accessory")
        or child:IsA("Hat")
        or child:IsA("CharacterMesh") then
            child:Destroy()
        end
    end
end

local function removeVisualMorph(char)
    local old = char:FindFirstChild("R63VisualMorph")
    if old then
        old:Destroy()
    end
end

local function rememberPartState(part)
    if part:GetAttribute("R63OldTransparency") == nil then
        part:SetAttribute("R63OldTransparency", part.Transparency)
    end

    if part:GetAttribute("R63OldColor") == nil then
        part:SetAttribute("R63OldColor", part.Color)
    end
end

local function hideOriginalBody(char)
    for _, partName in ipairs(BODY_ORDER) do
        local part = char:FindFirstChild(partName)

        if part and part:IsA("BasePart") then
            rememberPartState(part)
            part.Transparency = 1
        end
    end
end

local function restoreOriginalBody(char)
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("BasePart") then
            local oldTransparency = child:GetAttribute("R63OldTransparency")
            local oldColor = child:GetAttribute("R63OldColor")

            if typeof(oldTransparency) == "number" then
                child.Transparency = oldTransparency
                child:SetAttribute("R63OldTransparency", nil)
            end

            if typeof(oldColor) == "Color3" then
                child.Color = oldColor
                child:SetAttribute("R63OldColor", nil)
            end
        end
    end
end

local function setHeadSkin(char)
    local head = char:FindFirstChild("Head")
    if head and head:IsA("BasePart") then
        rememberPartState(head)
        head.Color = currentSkinColor()
    end
end

local function makeVisualPart(folder, sourcePart, partName, meshUri, textureId, scale, layerName)
    local visual = Instance.new("Part")
    visual.Name = layerName .. "_" .. partName:gsub(" ", "")
    visual.Size = sourcePart.Size
    visual.CFrame = sourcePart.CFrame
    visual.Color = currentSkinColor()
    visual.Material = Enum.Material.SmoothPlastic
    visual.Transparency = 0
    visual.CanCollide = false
    visual.CanTouch = false
    visual.CanQuery = false
    visual.Massless = true
    visual.CastShadow = false
    visual.Anchored = false
    visual.Parent = folder

    local mesh = Instance.new("SpecialMesh")
    mesh.Name = "Mesh"
    mesh.MeshType = Enum.MeshType.FileMesh
    mesh.MeshId = meshUri
    mesh.TextureId = textureId or ""
    mesh.Scale = Vector3.new(scale, scale, scale)
    mesh.Offset = Vector3.new(0, 0, 0)
    mesh.Parent = visual

    local weld = Instance.new("WeldConstraint")
    weld.Name = "R63Weld"
    weld.Part0 = sourcePart
    weld.Part1 = visual
    weld.Parent = visual

    return visual
end

local function findAttachmentOnRig(char, accessory, attachmentName)
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("Attachment")
        and obj.Name == attachmentName
        and not obj:IsDescendantOf(accessory)
        and obj.Parent
        and obj.Parent:IsA("BasePart") then
            return obj
        end
    end

    return nil
end

local function stripAccessoryWelds(handle)
    for _, child in ipairs(handle:GetChildren()) do
        if child:IsA("Weld")
        or child:IsA("WeldConstraint")
        or child:IsA("Motor6D") then
            if child.Name == "AccessoryWeld" or child:GetAttribute("R63MadeWeld") then
                child:Destroy()
            end
        end
    end
end

local function attachAccessoryManual(char, accessory)
    local handle = accessory:FindFirstChild("Handle")

    if not handle or not handle:IsA("BasePart") then
        return false
    end

    accessory.Parent = char

    handle.Anchored = false
    handle.CanCollide = false
    handle.CanTouch = false
    handle.CanQuery = false
    handle.Massless = true

    stripAccessoryWelds(handle)

    local handleAttachment = nil
    local rigAttachment = nil

    for _, child in ipairs(handle:GetChildren()) do
        if child:IsA("Attachment") then
            local target = findAttachmentOnRig(char, accessory, child.Name)

            if target then
                handleAttachment = child
                rigAttachment = target
                break
            end
        end
    end

    if handleAttachment and rigAttachment then
        local rigPart = rigAttachment.Parent

        handle.CFrame =
            rigPart.CFrame
            * rigAttachment.CFrame
            * handleAttachment.CFrame:Inverse()

        local weld = Instance.new("Weld")
        weld.Name = "AccessoryWeld"
        weld.Part0 = rigPart
        weld.Part1 = handle
        weld.C0 = rigAttachment.CFrame
        weld.C1 = handleAttachment.CFrame
        weld:SetAttribute("R63MadeWeld", true)
        weld.Parent = handle

        return true
    end

    local head = char:FindFirstChild("Head")

    if head and head:IsA("BasePart") then
        local attachmentPoint = CFrame.new()

        pcall(function()
            attachmentPoint = accessory.AttachmentPoint
        end)

        local headPoint = CFrame.new(0, 0.5, 0)

        handle.CFrame =
            head.CFrame
            * headPoint
            * attachmentPoint:Inverse()

        local weld = Instance.new("Weld")
        weld.Name = "AccessoryWeld"
        weld.Part0 = head
        weld.Part1 = handle
        weld.C0 = headPoint
        weld.C1 = attachmentPoint
        weld:SetAttribute("R63MadeWeld", true)
        weld.Parent = handle

        return true
    end

    return false
end

local function attachAccessory(char, hum, accessory)
    local copy = cloneSafe(accessory)

    if not copy then
        return false
    end

    copy.Parent = nil

    local humanoidOk = pcall(function()
        hum:AddAccessory(copy)
    end)

    if humanoidOk and copy.Parent == char then
        local handle = copy:FindFirstChild("Handle")
        if handle then
            for _, child in ipairs(handle:GetChildren()) do
                if child:IsA("Weld")
                or child:IsA("WeldConstraint")
                or child:IsA("Motor6D") then
                    return true
                end
            end
        end
    end

    if copy.Parent then
        copy.Parent = nil
    end

    local attached = attachAccessoryManual(char, copy)

    if not attached then
        copy:Destroy()
    end

    return attached
end

local function splitIds(text)
    local ids = {}
    local seen = {}

    for token in tostring(text):gmatch("[^,%s;]+") do
        local id = token:match("(%d+)")

        if id and not seen[id] then
            seen[id] = true
            table.insert(ids, id)
        end
    end

    return ids
end

local function loadAssetRoots(id)
    local ok, roots = pcall(function()
        return game:GetObjects("rbxassetid://" .. id)
    end)

    if ok and type(roots) == "table" and #roots > 0 then
        return roots
    end

    local loaded = nil

    local insertOk = pcall(function()
        loaded = InsertService:LoadAsset(tonumber(id))
    end)

    if insertOk and loaded then
        return {loaded}
    end

    return {}
end

local function collectWearables(root)
    local found = {}

    local function check(obj)
        if obj:IsA("Shirt")
        or obj:IsA("Pants")
        or obj:IsA("ShirtGraphic")
        or obj:IsA("Accessory")
        or obj:IsA("Hat")
        or obj:IsA("BodyColors") then
            table.insert(found, obj)
        end
    end

    check(root)

    for _, obj in ipairs(root:GetDescendants()) do
        check(obj)
    end

    return found
end

local function outfitFromIds(text, status)
    local result = {
        shirtTemplate = nil,
        pantsTemplate = nil,
        shirtGraphic = nil,
        accessories = {},
        bodyColors = nil,
        foundAny = false,
        failed = {},
    }

    local ids = splitIds(text)

    for index, id in ipairs(ids) do
        if status then
            status(("Reading asset %d/%d: %s"):format(index, #ids, id))
        end

        local roots = loadAssetRoots(id)
        local foundThisId = false

        for _, root in ipairs(roots) do
            for _, wearable in ipairs(collectWearables(root)) do
                if wearable:IsA("Shirt") then
                    result.shirtTemplate = wearable.ShirtTemplate
                    foundThisId = true
                    result.foundAny = true

                elseif wearable:IsA("Pants") then
                    result.pantsTemplate = wearable.PantsTemplate
                    foundThisId = true
                    result.foundAny = true

                elseif wearable:IsA("ShirtGraphic") then
                    result.shirtGraphic = wearable.Graphic
                    foundThisId = true
                    result.foundAny = true

                elseif wearable:IsA("Accessory") or wearable:IsA("Hat") then
                    local copy = cloneSafe(wearable)

                    if copy then
                        table.insert(result.accessories, copy)
                        foundThisId = true
                        result.foundAny = true
                    end

                elseif wearable:IsA("BodyColors") then
                    result.bodyColors = cloneSafe(wearable)
                    foundThisId = true
                    result.foundAny = true
                end
            end

            pcall(function()
                root:Destroy()
            end)
        end

        if not foundThisId then
            table.insert(result.failed, id)
        end
    end

    return result
end

local function combineOutfits(saved, prompted)
    local final = {
        shirtTemplate = saved and saved.shirtTemplate or "",
        pantsTemplate = saved and saved.pantsTemplate or "",
        shirtGraphic = saved and saved.shirtGraphic or "",
        accessories = {},
        bodyColors = saved and saved.bodyColors or nil,
    }

    if saved and saved.accessories then
        for _, acc in ipairs(saved.accessories) do
            local copy = cloneSafe(acc)
            if copy then
                table.insert(final.accessories, copy)
            end
        end
    end

    if prompted then
        if prompted.shirtTemplate ~= nil then
            final.shirtTemplate = prompted.shirtTemplate
        end

        if prompted.pantsTemplate ~= nil then
            final.pantsTemplate = prompted.pantsTemplate
        end

        if prompted.shirtGraphic ~= nil then
            final.shirtGraphic = prompted.shirtGraphic
        end

        if prompted.bodyColors ~= nil then
            final.bodyColors = prompted.bodyColors
        end

        -- If at least one accessory was explicitly supplied, replace the old
        -- accessory set with the prompted set. Otherwise keep existing ones.
        if #prompted.accessories > 0 then
            final.accessories = {}

            for _, acc in ipairs(prompted.accessories) do
                local copy = cloneSafe(acc)
                if copy then
                    table.insert(final.accessories, copy)
                end
            end
        end
    end

    return final
end

local function applySkinToVisuals(char)
    local color = currentSkinColor()
    local folder = char:FindFirstChild("R63VisualMorph")

    if folder then
        for _, obj in ipairs(folder:GetChildren()) do
            if obj:IsA("BasePart") then
                obj.Color = color
            end
        end
    end

    setHeadSkin(char)
end

local function buildMorph(finalOutfit, status)
    local char, hum = getCharacter()

    removeVisualMorph(char)
    destroyCosmetics(char)
    hideOriginalBody(char)
    setHeadSkin(char)

    local folder = Instance.new("Folder")
    folder.Name = "R63VisualMorph"
    folder.Parent = char

    if status then
        status("Building R63 visual body...")
    end

    for _, partName in ipairs(BODY_ORDER) do
        local sourcePart = char:FindFirstChild(partName)

        if not sourcePart or not sourcePart:IsA("BasePart") then
            error("Missing R6 body part: " .. partName)
        end

        local meshUri = downloadMesh(BODY_FILES[partName])

        -- Base skin mesh.
        makeVisualPart(
            folder,
            sourcePart,
            partName,
            meshUri,
            "",
            1.000,
            "Body"
        )

        -- Shirt texture layer.
        if SHIRT_PARTS[partName]
        and finalOutfit.shirtTemplate
        and finalOutfit.shirtTemplate ~= "" then
            makeVisualPart(
                folder,
                sourcePart,
                partName,
                meshUri,
                finalOutfit.shirtTemplate,
                1.004,
                "Shirt"
            )
        end

        -- Pants texture layer.
        if PANTS_PARTS[partName]
        and finalOutfit.pantsTemplate
        and finalOutfit.pantsTemplate ~= "" then
            makeVisualPart(
                folder,
                sourcePart,
                partName,
                meshUri,
                finalOutfit.pantsTemplate,
                1.008,
                "Pants"
            )
        end
    end

    -- T-shirt graphic still uses native ShirtGraphic because it is a front
    -- decal rather than a full classic template.
    if finalOutfit.shirtGraphic and finalOutfit.shirtGraphic ~= "" then
        local graphic = Instance.new("ShirtGraphic")
        graphic.Name = "R63ShirtGraphic"
        graphic.Graphic = finalOutfit.shirtGraphic
        graphic.Parent = char
    end

    local accessoryCount = 0

    for _, accessory in ipairs(finalOutfit.accessories or {}) do
        if attachAccessory(char, hum, accessory) then
            accessoryCount = accessoryCount + 1
        end
    end

    morphActive = true
    applySkinToVisuals(char)

    if status then
        status(("R63 rebuilt. %d accessory(s) attached."):format(accessoryCount))
    end
end

local function applyMorphFromInput(idText, status)
    local char = getCharacter()

    -- Only take a new snapshot when no morph is active. Otherwise we would
    -- snapshot our own stripped state and lose the user's original outfit.
    if not morphActive or not savedOutfit then
        savedOutfit = snapshotCurrentOutfit(char)
    end

    local prompted = nil

    if tostring(idText):match("%d") then
        lastIdText = idText
        prompted = outfitFromIds(idText, status)
    else
        lastIdText = ""
    end

    local finalOutfit = combineOutfits(savedOutfit, prompted)
    buildMorph(finalOutfit, status)

    if prompted and #prompted.failed > 0 then
        status(
            "Morph applied. IDs not resolved: "
            .. table.concat(prompted.failed, ", ")
        )
    end
end

local function resetMorph(status)
    local char = player.Character
    if not char then
        return
    end

    removeVisualMorph(char)
    destroyCosmetics(char)
    restoreOriginalBody(char)

    if savedOutfit then
        if savedOutfit.shirtTemplate and savedOutfit.shirtTemplate ~= "" then
            local shirt = Instance.new("Shirt")
            shirt.ShirtTemplate = savedOutfit.shirtTemplate
            shirt.Parent = char
        end

        if savedOutfit.pantsTemplate and savedOutfit.pantsTemplate ~= "" then
            local pants = Instance.new("Pants")
            pants.PantsTemplate = savedOutfit.pantsTemplate
            pants.Parent = char
        end

        if savedOutfit.shirtGraphic and savedOutfit.shirtGraphic ~= "" then
            local graphic = Instance.new("ShirtGraphic")
            graphic.Graphic = savedOutfit.shirtGraphic
            graphic.Parent = char
        end

        local hum = char:FindFirstChildOfClass("Humanoid")

        if hum then
            for _, accessory in ipairs(savedOutfit.accessories or {}) do
                attachAccessory(char, hum, accessory)
            end
        end
    end

    morphActive = false

    if status then
        status("Original character visuals restored.")
    end
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
main.Name = "Main"
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.Position = UDim2.fromScale(0.5, 0.5)
main.Size = UDim2.fromOffset(344, 438)
main.BackgroundColor3 = Color3.fromRGB(24, 24, 29)
main.BorderSizePixel = 0
main.Parent = gui

local scale = Instance.new("UIScale")
scale.Parent = main

local function updateScale()
    local camera = workspace.CurrentCamera
    if not camera then
        scale.Scale = 1
        return
    end

    local viewport = camera.ViewportSize
    local fitX = (viewport.X - 18) / 344
    local fitY = (viewport.Y - 28) / 438
    scale.Scale = math.clamp(math.min(1, fitX, fitY), 0.68, 1)
end

updateScale()

if workspace.CurrentCamera then
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    updateScale()
end)

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 11)
mainCorner.Parent = main

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(76, 76, 90)
mainStroke.Parent = main

local top = Instance.new("Frame")
top.Size = UDim2.new(1, 0, 0, 38)
top.BackgroundTransparency = 1
top.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -50, 1, 0)
title.Position = UDim2.fromOffset(12, 0)
title.BackgroundTransparency = 1
title.Text = "R63 GUI v4"
title.TextColor3 = Color3.fromRGB(245, 245, 250)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
title.TextSize = 17
title.Parent = top

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(28, 28)
close.Position = UDim2.new(1, -34, 0, 5)
close.BackgroundColor3 = Color3.fromRGB(49, 49, 58)
close.Text = "×"
close.TextColor3 = Color3.fromRGB(245, 245, 250)
close.Font = Enum.Font.GothamBold
close.TextSize = 19
close.Parent = top
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 7)

close.MouseButton1Click:Connect(function()
    gui:Destroy()
end)

local idLabel = Instance.new("TextLabel")
idLabel.Size = UDim2.new(1, -24, 0, 18)
idLabel.Position = UDim2.fromOffset(12, 42)
idLabel.BackgroundTransparency = 1
idLabel.Text = "Optional clothing / accessory IDs"
idLabel.TextColor3 = Color3.fromRGB(205, 205, 216)
idLabel.TextXAlignment = Enum.TextXAlignment.Left
idLabel.Font = Enum.Font.Gotham
idLabel.TextSize = 12
idLabel.Parent = main

local idsBox = Instance.new("TextBox")
idsBox.Size = UDim2.new(1, -24, 0, 46)
idsBox.Position = UDim2.fromOffset(12, 63)
idsBox.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
idsBox.BorderSizePixel = 0
idsBox.ClearTextOnFocus = false
idsBox.MultiLine = true
idsBox.TextWrapped = true
idsBox.TextXAlignment = Enum.TextXAlignment.Left
idsBox.TextYAlignment = Enum.TextYAlignment.Top
idsBox.TextColor3 = Color3.fromRGB(245, 245, 250)
idsBox.PlaceholderColor3 = Color3.fromRGB(125, 125, 138)
idsBox.PlaceholderText = "Leave empty = current outfit"
idsBox.Font = Enum.Font.Code
idsBox.TextSize = 12
idsBox.Parent = main
Instance.new("UICorner", idsBox).CornerRadius = UDim.new(0, 7)

local idsPadding = Instance.new("UIPadding")
idsPadding.PaddingLeft = UDim.new(0, 8)
idsPadding.PaddingRight = UDim.new(0, 8)
idsPadding.PaddingTop = UDim.new(0, 6)
idsPadding.PaddingBottom = UDim.new(0, 6)
idsPadding.Parent = idsBox

local colorLabel = Instance.new("TextLabel")
colorLabel.Size = UDim2.fromOffset(145, 18)
colorLabel.Position = UDim2.fromOffset(12, 115)
colorLabel.BackgroundTransparency = 1
colorLabel.Text = "Skin color wheel"
colorLabel.TextColor3 = Color3.fromRGB(205, 205, 216)
colorLabel.TextXAlignment = Enum.TextXAlignment.Left
colorLabel.Font = Enum.Font.Gotham
colorLabel.TextSize = 12
colorLabel.Parent = main

local wheel = Instance.new("Frame")
wheel.Name = "ColorWheel"
wheel.Size = UDim2.fromOffset(106, 106)
wheel.Position = UDim2.fromOffset(12, 136)
wheel.BackgroundTransparency = 1
wheel.Parent = main

local wheelCenter = Vector2.new(53, 53)
local dotButtons = {}
local hueSteps = 24
local rings = 5

for ring = 1, rings do
    local sat = ring / rings
    local radius = 9 + ring * 8

    for step = 0, hueSteps - 1 do
        local hue = step / hueSteps
        local angle = hue * math.pi * 2 - math.pi / 2
        local x = wheelCenter.X + math.cos(angle) * radius
        local y = wheelCenter.Y + math.sin(angle) * radius

        local dot = Instance.new("TextButton")
        dot.Size = UDim2.fromOffset(9, 9)
        dot.Position = UDim2.fromOffset(x - 4.5, y - 4.5)
        dot.BackgroundColor3 = Color3.fromHSV(hue, sat, skinV)
        dot.BorderSizePixel = 0
        dot.Text = ""
        dot.AutoButtonColor = false
        dot.Parent = wheel
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

        table.insert(dotButtons, {
            button = dot,
            h = hue,
            s = sat,
        })

        dot.MouseButton1Click:Connect(function()
            skinH = hue
            skinS = sat
            applySkinToVisuals(player.Character or getCharacter())
        end)
    end
end

local centerDot = Instance.new("TextButton")
centerDot.Size = UDim2.fromOffset(16, 16)
centerDot.Position = UDim2.fromOffset(45, 45)
centerDot.BackgroundColor3 = Color3.fromHSV(0, 0, skinV)
centerDot.BorderSizePixel = 0
centerDot.Text = ""
centerDot.AutoButtonColor = false
centerDot.Parent = wheel
Instance.new("UICorner", centerDot).CornerRadius = UDim.new(1, 0)

centerDot.MouseButton1Click:Connect(function()
    skinS = 0
    applySkinToVisuals(player.Character or getCharacter())
end)

local preview = Instance.new("Frame")
preview.Size = UDim2.fromOffset(28, 28)
preview.Position = UDim2.fromOffset(132, 138)
preview.BackgroundColor3 = currentSkinColor()
preview.BorderSizePixel = 0
preview.Parent = main
Instance.new("UICorner", preview).CornerRadius = UDim.new(1, 0)

local previewStroke = Instance.new("UIStroke")
previewStroke.Color = Color3.fromRGB(235, 235, 240)
previewStroke.Parent = preview

local darkBtn = Instance.new("TextButton")
darkBtn.Size = UDim2.fromOffset(78, 30)
darkBtn.Position = UDim2.fromOffset(132, 178)
darkBtn.BackgroundColor3 = Color3.fromRGB(49, 49, 58)
darkBtn.BorderSizePixel = 0
darkBtn.Text = "Darker"
darkBtn.TextColor3 = Color3.fromRGB(240, 240, 245)
darkBtn.Font = Enum.Font.GothamSemibold
darkBtn.TextSize = 12
darkBtn.Parent = main
Instance.new("UICorner", darkBtn).CornerRadius = UDim.new(0, 7)

local lightBtn = Instance.new("TextButton")
lightBtn.Size = UDim2.fromOffset(78, 30)
lightBtn.Position = UDim2.fromOffset(218, 178)
lightBtn.BackgroundColor3 = Color3.fromRGB(49, 49, 58)
lightBtn.BorderSizePixel = 0
lightBtn.Text = "Lighter"
lightBtn.TextColor3 = Color3.fromRGB(240, 240, 245)
lightBtn.Font = Enum.Font.GothamSemibold
lightBtn.TextSize = 12
lightBtn.Parent = main
Instance.new("UICorner", lightBtn).CornerRadius = UDim.new(0, 7)

local function refreshColorUI()
    preview.BackgroundColor3 = currentSkinColor()

    for _, data in ipairs(dotButtons) do
        data.button.BackgroundColor3 =
            Color3.fromHSV(data.h, data.s, skinV)
    end

    centerDot.BackgroundColor3 = Color3.fromHSV(0, 0, skinV)
    applySkinToVisuals(player.Character or getCharacter())
end

darkBtn.MouseButton1Click:Connect(function()
    skinV = math.clamp(skinV - 0.08, 0.16, 1)
    refreshColorUI()
end)

lightBtn.MouseButton1Click:Connect(function()
    skinV = math.clamp(skinV + 0.08, 0.16, 1)
    refreshColorUI()
end)

local function makeButton(text, x, y, width)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(width, 34)
    b.Position = UDim2.fromOffset(x, y)
    b.BackgroundColor3 = Color3.fromRGB(51, 51, 61)
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = Color3.fromRGB(245, 245, 250)
    b.Font = Enum.Font.GothamSemibold
    b.TextSize = 12
    b.Parent = main
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)
    return b
end

local applyBtn = makeButton("Rebuild morph", 12, 252, 320)
local currentBtn = makeButton("Use current outfit", 12, 294, 154)
local idsBtn = makeButton("Use IDs + fallback", 178, 294, 154)
local resetBtn = makeButton("Reset original", 12, 336, 154)
local autoBtn = makeButton("Auto respawn: OFF", 178, 336, 154)

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -24, 0, 54)
statusLabel.Position = UDim2.fromOffset(12, 378)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Ready. Empty ID box keeps the outfit already on your character."
statusLabel.TextColor3 = Color3.fromRGB(160, 160, 176)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.TextWrapped = true
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 11
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

applyBtn.MouseButton1Click:Connect(function()
    run(function()
        applyMorphFromInput(idsBox.Text, status)
    end)
end)

currentBtn.MouseButton1Click:Connect(function()
    run(function()
        idsBox.Text = ""
        applyMorphFromInput("", status)
    end)
end)

idsBtn.MouseButton1Click:Connect(function()
    run(function()
        applyMorphFromInput(idsBox.Text, status)
    end)
end)

resetBtn.MouseButton1Click:Connect(function()
    run(function()
        resetMorph(status)
    end)
end)

autoBtn.MouseButton1Click:Connect(function()
    autoReapply = not autoReapply
    autoBtn.Text = "Auto respawn: " .. (autoReapply and "ON" or "OFF")
    status(autoReapply and "Auto reapply enabled." or "Auto reapply disabled.")
end)

player.CharacterAdded:Connect(function()
    morphActive = false
    savedOutfit = nil

    if not autoReapply then
        return
    end

    task.wait(1.15)

    run(function()
        applyMorphFromInput(lastIdText, status)
        status("R63 morph rebuilt after respawn.")
    end)
end)

-- Dragging still starts from the title bar, but initial position is always center.
do
    local dragging = false
    local dragStart = nil
    local startPos = nil

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

refreshColorUI()
