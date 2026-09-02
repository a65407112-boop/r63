-- R63 GUI v7
-- R6 visual morph with classic clothing UV layers, catalog resolver and safe reload/reset.
-- Repo: https://github.com/a65407112-boop/r63

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
if not player then
    error("R63 GUI v7: LocalPlayer is unavailable")
end

local environment = getgenv and getgenv() or _G
local previousRuntime = rawget(environment, "R63_GUI_RUNTIME")
if type(previousRuntime) == "table" and type(previousRuntime.shutdown) == "function" then
    pcall(previousRuntime.shutdown, true)
end

local previousGui = rawget(environment, "R63_GUI_OBJECT")
if typeof(previousGui) == "Instance" then
    pcall(function()
        previousGui:Destroy()
    end)
end

local runtime = {
    connections = {},
    disconnected = false,
    closed = false,
}
environment.R63_GUI_RUNTIME = runtime

local BASE_URL = "https://raw.githubusercontent.com/a65407112-boop/r63/main"
local MORPH_NAME = "R63VisualMorph"
local PART_ORDER = { "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
local BODY_MESHES = {
    ["Torso"] = "torso.mesh",
    ["Left Arm"] = "leftarm.mesh",
    ["Right Arm"] = "rightarm.mesh",
    ["Left Leg"] = "leftleg.mesh",
    ["Right Leg"] = "rightleg.mesh",
}
local EXPECTED_MESH_SIZE = {
    ["torso.mesh"] = 757381,
    ["leftarm.mesh"] = 139669,
    ["rightarm.mesh"] = 139309,
    ["leftleg.mesh"] = 761769,
    ["rightleg.mesh"] = 761489,
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

local ACCESSORY_ASSET_TYPES = {
    [8] = { property = "HatAccessory", category = "Hat", accessoryType = "Hat" },
    [41] = { property = "HairAccessory", category = "Hair", accessoryType = "Hair" },
    [42] = { property = "FaceAccessory", category = "Face", accessoryType = "Face" },
    [43] = { property = "NeckAccessory", category = "Neck", accessoryType = "Neck" },
    [44] = { property = "ShouldersAccessory", category = "Shoulder", accessoryType = "Shoulder" },
    [45] = { property = "FrontAccessory", category = "Front", accessoryType = "Front" },
    [46] = { property = "BackAccessory", category = "Back", accessoryType = "Back" },
    [47] = { property = "WaistAccessory", category = "Waist", accessoryType = "Waist" },
}
local MODERN_RIGID_ASSET_TYPES = {
    [76] = { category = "Eyebrow", accessoryType = "Eyebrow" },
    [77] = { category = "Eyelash", accessoryType = "Eyelash" },
}
local LAYERED_ASSET_TYPES = {
    [64] = true,
    [65] = true,
    [66] = true,
    [67] = true,
    [68] = true,
    [69] = true,
    [70] = true,
    [71] = true,
    [72] = true,
}
local ATTACHMENT_CATEGORIES = {
    HatAttachment = "Hat",
    HairAttachment = "Hair",
    FaceFrontAttachment = "Face",
    FaceCenterAttachment = "Face",
    NeckAttachment = "Neck",
    LeftShoulderAttachment = "Shoulder",
    RightShoulderAttachment = "Shoulder",
    BodyFrontAttachment = "Front",
    BodyBackAttachment = "Back",
    WaistFrontAttachment = "Waist",
    WaistCenterAttachment = "Waist",
    WaistBackAttachment = "Waist",
}

local meshCache = {}
local saved = nil
local savedCharacter = nil
local currentOutfit = nil
local active = false
local autoRespawn = false
local lastIds = ""
local headMode = "Normal"
local hue, saturation, value = 0.075, 0.30, 1

local function track(connection)
    table.insert(runtime.connections, connection)
    return connection
end

local function skinColor()
    return Color3.fromHSV(hue, saturation, value)
end

local function getCharacter()
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
    if not humanoid then
        error("R63 GUI v7: Humanoid was not found")
    end
    if humanoid.RigType ~= Enum.HumanoidRigType.R6 then
        error("R63 GUI v7 supports R6 only. Switch the avatar rig to R6 first.")
    end
    for _, name in ipairs(PART_ORDER) do
        local part = character:FindFirstChild(name)
        if not part or not part:IsA("BasePart") then
            error("R63 GUI v7: missing R6 body part " .. name)
        end
    end
    return character, humanoid
end

local function cloneObject(object)
    if not object then
        return nil
    end
    local archivable = object.Archivable
    object.Archivable = true
    local ok, clone = pcall(function()
        return object:Clone()
    end)
    object.Archivable = archivable
    return ok and clone or nil
end

local function normalizeTexture(valueToNormalize)
    local text = tostring(valueToNormalize or "")
    if text == "" then
        return "", nil
    end
    local id = text:match("[?&]id=(%d+)")
        or text:match("rbxassetid://(%d+)")
        or text:match("(%d+)")
    if id then
        return "rbxassetid://" .. id, id
    end
    return text, text
end

local function getFaceTexture(character)
    local head = character and character:FindFirstChild("Head")
    if not head then
        return ""
    end
    local namedFace = head:FindFirstChild("face")
    if namedFace and namedFace:IsA("Decal") then
        return namedFace.Texture
    end
    for _, child in ipairs(head:GetChildren()) do
        if child:IsA("Decal") then
            return child.Texture
        end
    end
    return ""
end

local function setFaceTexture(character, texture)
    local head = character and character:FindFirstChild("Head")
    if not head then
        return
    end
    local face = head:FindFirstChild("face")
    if face and not face:IsA("Decal") then
        face = nil
    end
    if not face then
        for _, child in ipairs(head:GetChildren()) do
            if child:IsA("Decal") then
                face = child
                break
            end
        end
    end
    if texture and texture ~= "" then
        if not face then
            face = Instance.new("Decal")
            face.Name = "face"
            face.Face = Enum.NormalId.Front
            face.Parent = head
        end
        face.Texture = texture
    elseif face and face.Name == "face" then
        face:Destroy()
    end
end

local function restoreAttribute(instance, attributeNames, propertyName, expectedType)
    for _, attributeName in ipairs(attributeNames) do
        local stored = instance:GetAttribute(attributeName)
        if typeof(stored) == expectedType then
            instance[propertyName] = stored
            instance:SetAttribute(attributeName, nil)
            return true
        end
    end
    return false
end

local function recoverLegacyMorph(character)
    if not character then
        return
    end

    local recoveredShirt = ""
    local recoveredPants = ""
    local morph = character:FindFirstChild(MORPH_NAME)
    if morph then
        for _, visual in ipairs(morph:GetDescendants()) do
            if visual:IsA("BasePart") then
                local layer = visual:GetAttribute("R63Layer")
                    or visual:GetAttribute("R63v6Layer")
                    or visual:GetAttribute("R63v5Layer")
                if not layer then
                    layer = visual.Name:match("^(%a+)_")
                end
                local mesh = visual:FindFirstChildOfClass("SpecialMesh")
                if mesh and mesh.TextureId ~= "" then
                    if layer == "Shirt" and recoveredShirt == "" then
                        recoveredShirt = mesh.TextureId
                    elseif layer == "Pants" and recoveredPants == "" then
                        recoveredPants = mesh.TextureId
                    end
                end
            end
        end
        morph:Destroy()
    end

    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("BasePart") then
            restoreAttribute(child, {
                "R63OriginalTransparency",
                "R63v6Trans",
                "R63OldTrans",
            }, "Transparency", "number")
            restoreAttribute(child, {
                "R63OriginalColor",
                "R63v6Color",
                "R63OldColor",
            }, "Color", "Color3")
        end
    end

    local head = character:FindFirstChild("Head")
    if head then
        for _, child in ipairs(head:GetChildren()) do
            if child:IsA("Decal") or child:IsA("Texture") then
                restoreAttribute(child, {
                    "R63OriginalTransparency",
                    "R63v6Trans",
                    "R63OldTrans",
                }, "Transparency", "number")
            end
        end
    end

    if recoveredShirt ~= "" and not character:FindFirstChildOfClass("Shirt") then
        local shirt = Instance.new("Shirt")
        shirt.Name = "Shirt"
        shirt.ShirtTemplate = recoveredShirt
        shirt.Parent = character
    end
    if recoveredPants ~= "" and not character:FindFirstChildOfClass("Pants") then
        local pants = Instance.new("Pants")
        pants.Name = "Pants"
        pants.PantsTemplate = recoveredPants
        pants.Parent = character
    end
end

recoverLegacyMorph(player.Character)

do
    local character = player.Character
    local source = character and (character:FindFirstChild("Torso") or character:FindFirstChild("Head"))
    if source and source:IsA("BasePart") then
        hue, saturation, value = source.Color:ToHSV()
    end
end

local function ensureFolder(path)
    if makefolder then
        pcall(makefolder, path)
    end
end

local function meshDataIsValid(fileName, data)
    return type(data) == "string"
        and #data == EXPECTED_MESH_SIZE[fileName]
        and data:sub(1, 8) == "version "
end

local function localAsset(path)
    if getcustomasset then
        return getcustomasset(path)
    end
    if getsynasset then
        return getsynasset(path)
    end
    error("R63 GUI v7: getcustomasset or getsynasset is required")
end

local function getMesh(fileName)
    if meshCache[fileName] then
        return meshCache[fileName]
    end
    if not writefile then
        error("R63 GUI v7: writefile is required to load the custom meshes")
    end

    local flatPath = "r63_gui_v7_" .. fileName
    local path
    if makefolder then
        ensureFolder("r63_gui_v7")
        ensureFolder("r63_gui_v7/meshes")
        path = "r63_gui_v7/meshes/" .. fileName
    else
        path = flatPath
    end

    local validCache = false
    if isfile and readfile and isfile(path) then
        local ok, data = pcall(readfile, path)
        validCache = ok and meshDataIsValid(fileName, data)
    end

    if not validCache then
        local nonce = tostring(os.time()) .. "_" .. tostring(math.random(100000, 999999))
        local ok, data = pcall(function()
            return game:HttpGet(BASE_URL .. "/meshes/" .. fileName .. "?v7=" .. nonce)
        end)
        if not ok or not meshDataIsValid(fileName, data) then
            error("R63 GUI v7: mesh download failed or was corrupted: " .. fileName)
        end
        local wrote, writeError = pcall(writefile, path, data)
        if not wrote and path ~= flatPath then
            path = flatPath
            wrote, writeError = pcall(writefile, path, data)
        end
        if not wrote then
            error("R63 GUI v7: could not cache " .. fileName .. ": " .. tostring(writeError))
        end
    end

    local ok, uri = pcall(localAsset, path)
    if not ok or type(uri) ~= "string" or uri == "" then
        error("R63 GUI v7: executor could not register mesh " .. fileName)
    end
    meshCache[fileName] = uri
    return uri
end

local function accessoryCategory(accessory)
    if not accessory then
        return "Unknown"
    end
    local ok, accessoryType = pcall(function()
        return accessory.AccessoryType
    end)
    if ok and accessoryType then
        local name = accessoryType.Name
        if name == "Hat" or name == "Hair" or name == "Face" or name == "Neck"
            or name == "Front" or name == "Back" or name == "Waist"
            or name == "Eyebrow" or name == "Eyelash" then
            return name
        elseif name == "Shoulder" then
            return "Shoulder"
        end
    end

    local handle = accessory:FindFirstChild("Handle")
    if handle then
        for _, descendant in ipairs(handle:GetDescendants()) do
            if descendant:IsA("Attachment") and ATTACHMENT_CATEGORIES[descendant.Name] then
                return ATTACHMENT_CATEGORIES[descendant.Name]
            end
        end
    end
    if accessory:IsA("Hat") then
        return "Hat"
    end
    return "Unknown"
end

local function accessorySignature(accessory)
    local handle = accessory and accessory:FindFirstChild("Handle")
    local meshId = ""
    local textureId = ""
    if handle and handle:IsA("MeshPart") then
        meshId = handle.MeshId
        textureId = handle.TextureID
    elseif handle then
        local mesh = handle:FindFirstChildOfClass("SpecialMesh")
        if mesh then
            meshId = mesh.MeshId
            textureId = mesh.TextureId
        end
    end
    return table.concat({
        accessoryCategory(accessory),
        accessory and accessory.Name or "",
        meshId,
        textureId,
    }, "|")
end

local function destroySnapshot(snapshot)
    if not snapshot then
        return
    end
    for _, listName in ipairs({ "accessories", "characterMeshes", "headVisuals" }) do
        for _, object in ipairs(snapshot[listName] or {}) do
            pcall(function()
                object:Destroy()
            end)
        end
    end
    for _, objectName in ipairs({ "shirtObject", "pantsObject", "graphicObject" }) do
        local object = snapshot[objectName]
        if object then
            pcall(function()
                object:Destroy()
            end)
        end
    end
end

local function captureSnapshot(character)
    local snapshot = {
        shirt = "",
        pants = "",
        graphic = "",
        face = getFaceTexture(character),
        accessories = {},
        characterMeshes = {},
        headVisuals = {},
        parts = {},
        shirtObject = nil,
        pantsObject = nil,
        graphicObject = nil,
    }

    local shirt = character:FindFirstChildOfClass("Shirt")
    local pants = character:FindFirstChildOfClass("Pants")
    local graphic = character:FindFirstChildOfClass("ShirtGraphic")
    if shirt then
        snapshot.shirt = shirt.ShirtTemplate
        snapshot.shirtObject = cloneObject(shirt)
    end
    if pants then
        snapshot.pants = pants.PantsTemplate
        snapshot.pantsObject = cloneObject(pants)
    end
    if graphic then
        snapshot.graphic = graphic.Graphic
        snapshot.graphicObject = cloneObject(graphic)
    end

    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("Accessory") or child:IsA("Hat") then
            local clone = cloneObject(child)
            if clone then
                table.insert(snapshot.accessories, clone)
            end
        elseif child:IsA("CharacterMesh") then
            local clone = cloneObject(child)
            if clone then
                table.insert(snapshot.characterMeshes, clone)
            end
        end
    end

    local head = character:FindFirstChild("Head")
    if head then
        for _, child in ipairs(head:GetChildren()) do
            if child:IsA("Decal") or child:IsA("Texture") then
                local clone = cloneObject(child)
                if clone then
                    table.insert(snapshot.headVisuals, clone)
                end
            end
        end
    end

    for _, name in ipairs({ "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }) do
        local part = character:FindFirstChild(name)
        if part and part:IsA("BasePart") then
            snapshot.parts[name] = {
                transparency = part.Transparency,
                color = part.Color,
            }
        end
    end
    return snapshot
end

local function clearCosmetics(character)
    for _, child in ipairs(character:GetChildren()) do
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

local function clearMorphArtifacts(character)
    for _, child in ipairs(character:GetChildren()) do
        if child.Name == MORPH_NAME then
            child:Destroy()
        elseif child:IsA("BasePart") and child:GetAttribute("R63Layer") then
            child:Destroy()
        end
    end
end

local function rememberPart(part)
    if part:GetAttribute("R63OriginalTransparency") == nil then
        part:SetAttribute("R63OriginalTransparency", part.Transparency)
    end
    if part:GetAttribute("R63OriginalColor") == nil then
        part:SetAttribute("R63OriginalColor", part.Color)
    end
end

local function hideOriginalRig(character)
    for _, name in ipairs(PART_ORDER) do
        local part = character:FindFirstChild(name)
        if part and part:IsA("BasePart") then
            rememberPart(part)
            part.Transparency = 1
        end
    end
end

local function clearR63Attributes(instance)
    for _, attribute in ipairs({
        "R63OriginalTransparency",
        "R63OriginalColor",
        "R63v6Trans",
        "R63v6Color",
        "R63OldTrans",
        "R63OldColor",
    }) do
        instance:SetAttribute(attribute, nil)
    end
end

local function restorePartSnapshot(character, snapshot)
    for name, properties in pairs(snapshot.parts or {}) do
        local part = character:FindFirstChild(name)
        if part and part:IsA("BasePart") then
            part.Transparency = properties.transparency
            part.Color = properties.color
            clearR63Attributes(part)
        end
    end
end

local function applyHead(character, faceTexture)
    local head = character:FindFirstChild("Head")
    if not head or not head:IsA("BasePart") then
        return
    end
    rememberPart(head)
    setFaceTexture(character, faceTexture or "")
    head.Color = skinColor()

    local originalTransparency = head:GetAttribute("R63OriginalTransparency")
    if headMode == "Invisible" then
        head.Transparency = 1
    else
        head.Transparency = typeof(originalTransparency) == "number" and originalTransparency or 0
    end

    for _, child in ipairs(head:GetChildren()) do
        if child:IsA("Decal") or child:IsA("Texture") then
            if child:GetAttribute("R63OriginalTransparency") == nil then
                child:SetAttribute("R63OriginalTransparency", child.Transparency)
            end
            if headMode == "Normal" then
                local original = child:GetAttribute("R63OriginalTransparency")
                child.Transparency = typeof(original) == "number" and original or 0
            else
                child.Transparency = 1
            end
        end
    end
end

local function makeVisual(folder, sourcePart, bodyPartName, meshUri, texture, scale, layer)
    local visual = Instance.new("Part")
    visual.Name = layer .. "_" .. bodyPartName:gsub(" ", "")
    visual.Size = sourcePart.Size
    visual.CFrame = sourcePart.CFrame
    visual.Color = layer == "Body" and skinColor() or Color3.new(1, 1, 1)
    visual.Material = Enum.Material.SmoothPlastic
    visual.Transparency = 0
    visual.CanCollide = false
    visual.CanTouch = false
    visual.CanQuery = false
    visual.Massless = true
    visual.CastShadow = false
    visual.Anchored = false
    visual:SetAttribute("R63Layer", layer)
    visual.Parent = folder

    local mesh = Instance.new("SpecialMesh")
    mesh.Name = "Mesh"
    mesh.MeshType = Enum.MeshType.FileMesh
    mesh.MeshId = meshUri
    mesh.TextureId = normalizeTexture(texture)
    mesh.VertexColor = Vector3.new(1, 1, 1)
    mesh.Scale = Vector3.new(scale, scale, scale)
    mesh.Parent = visual

    local weld = Instance.new("WeldConstraint")
    weld.Name = "R63VisualWeld"
    weld.Part0 = sourcePart
    weld.Part1 = visual
    weld.Parent = visual
    return visual
end

local function makeGraphicLayer(folder, character, graphicTexture)
    local torso = character:FindFirstChild("Torso")
    if not torso or not torso:IsA("BasePart") then
        return
    end
    local normalized = normalizeTexture(graphicTexture)
    if normalized == "" then
        return
    end

    local nativeGraphic = Instance.new("ShirtGraphic")
    nativeGraphic.Name = "R63ShirtGraphic"
    nativeGraphic.Graphic = normalized
    nativeGraphic.Parent = character

    local plane = Instance.new("Part")
    plane.Name = "Graphic_Torso"
    plane.Size = torso.Size
    plane.CFrame = torso.CFrame
    plane.Transparency = 1
    plane.CanCollide = false
    plane.CanTouch = false
    plane.CanQuery = false
    plane.Massless = true
    plane.CastShadow = false
    plane.Anchored = false
    plane:SetAttribute("R63Layer", "Graphic")
    plane.Parent = folder

    local weld = Instance.new("WeldConstraint")
    weld.Name = "R63GraphicWeld"
    weld.Part0 = torso
    weld.Part1 = plane
    weld.Parent = plane

    local surface = Instance.new("SurfaceGui")
    surface.Name = "R63GraphicOverlay"
    surface.Adornee = plane
    surface.Face = Enum.NormalId.Front
    surface.AlwaysOnTop = true
    surface.LightInfluence = 0
    surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    surface.PixelsPerStud = 100
    surface.Parent = plane

    local image = Instance.new("ImageLabel")
    image.Name = "Graphic"
    image.BackgroundTransparency = 1
    image.Position = UDim2.fromScale(0.125, 0.08)
    image.Size = UDim2.fromScale(0.75, 0.78)
    image.Image = normalized
    image.ScaleType = Enum.ScaleType.Fit
    image.Parent = surface
end

local function recolor(character)
    local morph = character and character:FindFirstChild(MORPH_NAME)
    if morph then
        for _, visual in ipairs(morph:GetDescendants()) do
            if visual:IsA("BasePart") then
                if visual:GetAttribute("R63Layer") == "Body" then
                    visual.Color = skinColor()
                else
                    visual.Color = Color3.new(1, 1, 1)
                end
            end
        end
    end
    if character and active then
        applyHead(character, currentOutfit and currentOutfit.face or getFaceTexture(character))
    end
end

local function destroyAccessoryWelds(accessory)
    for _, descendant in ipairs(accessory:GetDescendants()) do
        if descendant.Name == "AccessoryWeld"
            and (descendant:IsA("Weld")
                or descendant:IsA("WeldConstraint")
                or descendant:IsA("Motor6D")) then
            descendant:Destroy()
        end
    end
end

local function prepareAccessory(accessory)
    destroyAccessoryWelds(accessory)
    for _, descendant in ipairs(accessory:GetDescendants()) do
        if descendant:IsA("BasePart") then
            descendant.Anchored = false
            descendant.CanCollide = false
            descendant.CanTouch = false
            descendant.CanQuery = false
            descendant.Massless = true
        end
    end
end

local function validAccessoryWeld(character, accessory)
    local handle = accessory:FindFirstChild("Handle")
    if not handle or not handle:IsA("BasePart") then
        return false
    end
    for _, descendant in ipairs(accessory:GetDescendants()) do
        if descendant.Name == "AccessoryWeld"
            and (descendant:IsA("Weld")
                or descendant:IsA("WeldConstraint")
                or descendant:IsA("Motor6D")) then
            local ok, part0, part1 = pcall(function()
                return descendant.Part0, descendant.Part1
            end)
            if ok and part0 and part1 then
                local other = part0 == handle and part1 or (part1 == handle and part0 or nil)
                if other and other:IsDescendantOf(character) and not other:IsDescendantOf(accessory) then
                    return true
                end
            end
        end
    end
    return false
end

local function findRigAttachment(character, accessory, attachmentName)
    for _, descendant in ipairs(character:GetDescendants()) do
        if descendant:IsA("Attachment")
            and descendant.Name == attachmentName
            and not descendant:IsDescendantOf(accessory)
            and descendant.Parent
            and descendant.Parent:IsA("BasePart") then
            return descendant
        end
    end
    return nil
end

local function manuallyAttachAccessory(character, accessory)
    local handle = accessory:FindFirstChild("Handle")
    if not handle or not handle:IsA("BasePart") then
        return false
    end
    prepareAccessory(accessory)
    accessory.Parent = character

    for _, handleAttachment in ipairs(handle:GetChildren()) do
        if handleAttachment:IsA("Attachment") then
            local rigAttachment = findRigAttachment(character, accessory, handleAttachment.Name)
            if rigAttachment then
                local rigPart = rigAttachment.Parent
                handle.CFrame = rigPart.CFrame * rigAttachment.CFrame * handleAttachment.CFrame:Inverse()
                local weld = Instance.new("Weld")
                weld.Name = "AccessoryWeld"
                weld.Part0 = rigPart
                weld.Part1 = handle
                weld.C0 = rigAttachment.CFrame
                weld.C1 = handleAttachment.CFrame
                weld.Parent = handle
                return true
            end
        end
    end

    local head = character:FindFirstChild("Head")
    if head and head:IsA("BasePart") then
        local attachmentPoint = CFrame.new()
        pcall(function()
            attachmentPoint = accessory.AttachmentPoint
        end)
        local headPoint = CFrame.new(0, 0.5, 0)
        handle.CFrame = head.CFrame * headPoint * attachmentPoint:Inverse()
        local weld = Instance.new("Weld")
        weld.Name = "AccessoryWeld"
        weld.Part0 = head
        weld.Part1 = handle
        weld.C0 = headPoint
        weld.C1 = attachmentPoint
        weld.Parent = handle
        return true
    end
    return false
end

local function addAccessory(character, humanoid, sourceAccessory)
    local accessory = cloneObject(sourceAccessory)
    if not accessory then
        return false
    end
    accessory.Parent = nil
    prepareAccessory(accessory)

    local ok = pcall(function()
        humanoid:AddAccessory(accessory)
    end)
    if ok and accessory.Parent == character then
        if validAccessoryWeld(character, accessory)
            or accessory:FindFirstChildWhichIsA("WrapLayer", true) then
            return true
        end
    end

    destroyAccessoryWelds(accessory)
    accessory.Parent = nil
    if manuallyAttachAccessory(character, accessory) then
        return true
    end
    accessory:Destroy()
    return false
end

local function parseIds(text)
    local result = {}
    local seen = {}
    for token in tostring(text):gmatch("[^,%s;]+") do
        local id = token:match("(%d+)")
        if id and not seen[id] then
            seen[id] = true
            table.insert(result, tonumber(id))
        end
    end
    return result
end

local function appendUniqueAccessory(result, sourceAccessory)
    local signature = accessorySignature(sourceAccessory)
    if result.accessorySignatures[signature] then
        return false
    end
    local clone = cloneObject(sourceAccessory)
    if not clone then
        return false
    end
    result.accessorySignatures[signature] = true
    table.insert(result.accessories, clone)
    local category = accessoryCategory(clone)
    if category ~= "Unknown" then
        result.replaceCategories[category] = true
        result.categoryCounts[category] = (result.categoryCounts[category] or 0) + 1
    end
    return true
end

local function pushFailure(result, label)
    label = tostring(label)
    if not result.failureSet[label] then
        result.failureSet[label] = true
        table.insert(result.failed, label)
    end
end

local function readDirectAsset(id, result)
    local ok, roots = pcall(function()
        return game:GetObjects("rbxassetid://" .. tostring(id))
    end)
    if not ok or type(roots) ~= "table" then
        return false
    end

    local found = false
    for _, root in ipairs(roots) do
        local objects = { root }
        for _, descendant in ipairs(root:GetDescendants()) do
            table.insert(objects, descendant)
        end
        for _, object in ipairs(objects) do
            if object:IsA("Shirt") then
                result.shirt = object.ShirtTemplate
                found = true
            elseif object:IsA("Pants") then
                result.pants = object.PantsTemplate
                found = true
            elseif object:IsA("ShirtGraphic") then
                result.graphic = object.Graphic
                found = true
            elseif object:IsA("Accessory") or object:IsA("Hat") then
                found = appendUniqueAccessory(result, object) or found
            elseif object:IsA("Decal")
                and object.Texture ~= ""
                and not object:FindFirstAncestorOfClass("Accessory")
                and not object:FindFirstAncestorOfClass("Hat") then
                result.face = object.Texture
                found = true
            end
        end
        pcall(function()
            root:Destroy()
        end)
    end
    return found
end

local function createDescriptionRig(description)
    local rig = nil
    local ok = pcall(function()
        rig = Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R6)
    end)
    if not ok or not rig then
        ok = pcall(function()
            rig = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R6)
        end)
    end
    return ok and rig or nil
end

local function resolveCatalogIds(text, setStatus)
    local ids = parseIds(text)
    local result = {
        shirt = nil,
        pants = nil,
        graphic = nil,
        face = nil,
        accessories = {},
        replaceCategories = {},
        categoryCounts = {},
        accessorySignatures = {},
        failed = {},
        failureSet = {},
    }
    if #ids == 0 then
        return result
    end

    local description = Instance.new("HumanoidDescription")
    local accessoryLists = {}
    local requests = {}
    local directFallback = {}
    local directFallbackSet = {}
    local descriptionHasData = false
    local needsModernAccessorySet = false
    local wanted = {
        shirt = false,
        pants = false,
        graphic = false,
        face = false,
    }

    local function queueFallback(id)
        if not directFallbackSet[id] then
            directFallbackSet[id] = true
            table.insert(directFallback, id)
        end
    end

    for index, id in ipairs(ids) do
        if setStatus then
            setStatus(("Reading catalog ID %d/%d: %d"):format(index, #ids, id))
        end
        local ok, info = pcall(function()
            return MarketplaceService:GetProductInfo(id, Enum.InfoType.Asset)
        end)
        local assetType = ok and info and tonumber(info.AssetTypeId) or nil

        if assetType == 11 then
            wanted.shirt = true
            table.insert(requests, { id = id, kind = "shirt" })
            local assigned = pcall(function()
                description.Shirt = id
            end)
            descriptionHasData = assigned or descriptionHasData
            if not assigned then
                queueFallback(id)
            end
        elseif assetType == 12 then
            wanted.pants = true
            table.insert(requests, { id = id, kind = "pants" })
            local assigned = pcall(function()
                description.Pants = id
            end)
            descriptionHasData = assigned or descriptionHasData
            if not assigned then
                queueFallback(id)
            end
        elseif assetType == 2 then
            wanted.graphic = true
            table.insert(requests, { id = id, kind = "graphic" })
            local assigned = pcall(function()
                description.GraphicTShirt = id
            end)
            descriptionHasData = assigned or descriptionHasData
            if not assigned then
                queueFallback(id)
            end
        elseif assetType == 18 then
            wanted.face = true
            table.insert(requests, { id = id, kind = "face" })
            local assigned = pcall(function()
                description.Face = id
            end)
            descriptionHasData = assigned or descriptionHasData
            if not assigned then
                queueFallback(id)
            end
        elseif ACCESSORY_ASSET_TYPES[assetType] then
            local data = ACCESSORY_ASSET_TYPES[assetType]
            table.insert(requests, {
                id = id,
                kind = "accessory",
                category = data.category,
                accessoryType = data.accessoryType,
            })
            accessoryLists[data.property] = accessoryLists[data.property] or {}
            table.insert(accessoryLists[data.property], tostring(id))
        elseif MODERN_RIGID_ASSET_TYPES[assetType] then
            local data = MODERN_RIGID_ASSET_TYPES[assetType]
            needsModernAccessorySet = true
            table.insert(requests, {
                id = id,
                kind = "accessory",
                category = data.category,
                accessoryType = data.accessoryType,
                modern = true,
            })
        elseif LAYERED_ASSET_TYPES[assetType] then
            pushFailure(result, "layered:" .. tostring(id))
        else
            table.insert(requests, { id = id, kind = "direct" })
            queueFallback(id)
        end
    end

    for propertyName, list in pairs(accessoryLists) do
        local assigned = pcall(function()
            description[propertyName] = table.concat(list, ",")
        end)
        descriptionHasData = assigned or descriptionHasData
        if not assigned then
            for _, id in ipairs(list) do
                queueFallback(tonumber(id))
            end
        end
    end

    if needsModernAccessorySet then
        local specifications = {}
        for _, request in ipairs(requests) do
            if request.kind == "accessory" and request.accessoryType then
                local ok, enumItem = pcall(function()
                    return Enum.AccessoryType[request.accessoryType]
                end)
                if ok and enumItem then
                    table.insert(specifications, {
                        AssetId = request.id,
                        AccessoryType = enumItem,
                        Order = #specifications + 1,
                    })
                else
                    queueFallback(request.id)
                end
            end
        end
        local assigned = #specifications > 0 and pcall(function()
            description:SetAccessories(specifications, true)
        end)
        descriptionHasData = assigned or descriptionHasData
        if not assigned then
            for _, request in ipairs(requests) do
                if request.kind == "accessory" and request.modern then
                    queueFallback(request.id)
                end
            end
        end
    end

    local rig = descriptionHasData and createDescriptionRig(description) or nil
    if rig then
        local shirt = rig:FindFirstChildOfClass("Shirt")
        local pants = rig:FindFirstChildOfClass("Pants")
        local graphic = rig:FindFirstChildOfClass("ShirtGraphic")
        if wanted.shirt and shirt then
            result.shirt = shirt.ShirtTemplate
        end
        if wanted.pants and pants then
            result.pants = pants.PantsTemplate
        end
        if wanted.graphic and graphic then
            result.graphic = graphic.Graphic
        end
        if wanted.face then
            result.face = getFaceTexture(rig)
        end
        for _, child in ipairs(rig:GetChildren()) do
            if child:IsA("Accessory") or child:IsA("Hat") then
                appendUniqueAccessory(result, child)
            end
        end
        rig:Destroy()
    else
        for _, request in ipairs(requests) do
            queueFallback(request.id)
        end
    end

    local requestedCategoryCounts = {}
    for _, request in ipairs(requests) do
        if request.kind == "shirt" and (not result.shirt or result.shirt == "") then
            queueFallback(request.id)
        elseif request.kind == "pants" and (not result.pants or result.pants == "") then
            queueFallback(request.id)
        elseif request.kind == "graphic" and (not result.graphic or result.graphic == "") then
            queueFallback(request.id)
        elseif request.kind == "face" and (not result.face or result.face == "") then
            queueFallback(request.id)
        elseif request.kind == "accessory" then
            requestedCategoryCounts[request.category] = (requestedCategoryCounts[request.category] or 0) + 1
        end
    end
    for _, request in ipairs(requests) do
        if request.kind == "accessory"
            and (result.categoryCounts[request.category] or 0) < requestedCategoryCounts[request.category] then
            queueFallback(request.id)
        end
    end

    for index, id in ipairs(directFallback) do
        if setStatus then
            setStatus(("Fallback asset read %d/%d: %d"):format(index, #directFallback, id))
        end
        if not readDirectAsset(id, result) then
            pushFailure(result, tostring(id))
        end
    end

    description:Destroy()
    result.accessorySignatures = nil
    result.failureSet = nil
    return result
end

local function mergeOutfit(base, custom)
    local result = {
        shirt = base and base.shirt or "",
        pants = base and base.pants or "",
        graphic = base and base.graphic or "",
        face = base and base.face or "",
        accessories = {},
    }

    if custom then
        if custom.shirt ~= nil then
            result.shirt = custom.shirt
        end
        if custom.pants ~= nil then
            result.pants = custom.pants
        end
        if custom.graphic ~= nil then
            result.graphic = custom.graphic
        end
        if custom.face ~= nil and custom.face ~= "" then
            result.face = custom.face
        end
    end

    local seen = {}
    for _, accessory in ipairs(base and base.accessories or {}) do
        local category = accessoryCategory(accessory)
        if not custom or not custom.replaceCategories[category] then
            local signature = accessorySignature(accessory)
            if not seen[signature] then
                local clone = cloneObject(accessory)
                if clone then
                    seen[signature] = true
                    table.insert(result.accessories, clone)
                end
            end
        end
    end
    for _, accessory in ipairs(custom and custom.accessories or {}) do
        local signature = accessorySignature(accessory)
        if not seen[signature] then
            local clone = cloneObject(accessory)
            if clone then
                seen[signature] = true
                table.insert(result.accessories, clone)
            end
        end
    end
    return result
end

local function destroyOutfit(outfit)
    if not outfit then
        return
    end
    for _, accessory in ipairs(outfit.accessories or {}) do
        pcall(function()
            accessory:Destroy()
        end)
    end
end

local function restoreOriginal(setStatus)
    local character = player.Character
    if not character then
        active = false
        currentOutfit = nil
        return
    end

    if saved and savedCharacter == character then
        clearMorphArtifacts(character)
        clearCosmetics(character)
        restorePartSnapshot(character, saved)

        local head = character:FindFirstChild("Head")
        if head then
            for _, child in ipairs(head:GetChildren()) do
                if child:IsA("Decal") or child:IsA("Texture") then
                    child:Destroy()
                end
            end
            for _, original in ipairs(saved.headVisuals or {}) do
                local clone = cloneObject(original)
                if clone then
                    clone.Parent = head
                end
            end
        end

        for _, original in ipairs(saved.characterMeshes or {}) do
            local clone = cloneObject(original)
            if clone then
                clone.Parent = character
            end
        end
        if saved.shirtObject then
            local shirt = cloneObject(saved.shirtObject)
            if shirt then
                shirt.Parent = character
            end
        elseif saved.shirt ~= "" then
            local shirt = Instance.new("Shirt")
            shirt.ShirtTemplate = saved.shirt
            shirt.Parent = character
        end
        if saved.pantsObject then
            local pants = cloneObject(saved.pantsObject)
            if pants then
                pants.Parent = character
            end
        elseif saved.pants ~= "" then
            local pants = Instance.new("Pants")
            pants.PantsTemplate = saved.pants
            pants.Parent = character
        end
        if saved.graphicObject then
            local graphic = cloneObject(saved.graphicObject)
            if graphic then
                graphic.Parent = character
            end
        elseif saved.graphic ~= "" then
            local graphic = Instance.new("ShirtGraphic")
            graphic.Graphic = saved.graphic
            graphic.Parent = character
        end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            for _, accessory in ipairs(saved.accessories or {}) do
                addAccessory(character, humanoid, accessory)
            end
        end
    else
        recoverLegacyMorph(character)
    end

    destroyOutfit(currentOutfit)
    currentOutfit = nil
    active = false
    if setStatus then
        setStatus("Original avatar restored")
    end
end

local function buildMorph(outfit, setStatus)
    local meshUris = {}
    for index, name in ipairs(PART_ORDER) do
        if setStatus then
            setStatus(("Loading body mesh %d/%d: %s"):format(index, #PART_ORDER, name))
        end
        meshUris[name] = getMesh(BODY_MESHES[name])
    end

    local character, humanoid = getCharacter()
    if savedCharacter ~= character or not saved then
        error("R63 GUI v7: character changed while the outfit was loading; press Apply again")
    end

    local ok, buildError = pcall(function()
        clearMorphArtifacts(character)
        clearCosmetics(character)
        hideOriginalRig(character)

        local folder = Instance.new("Folder")
        folder.Name = MORPH_NAME
        folder.Parent = character

        local shirtTexture, shirtId = normalizeTexture(outfit.shirt)
        local pantsTexture, pantsId = normalizeTexture(outfit.pants)
        for _, name in ipairs(PART_ORDER) do
            local sourcePart = character:FindFirstChild(name)
            local meshUri = meshUris[name]
            makeVisual(folder, sourcePart, name, meshUri, "", 1, "Body")
            if PANTS_PARTS[name] and pantsTexture ~= "" then
                makeVisual(folder, sourcePart, name, meshUri, pantsTexture, 1.0025, "Pants")
            end
            if SHIRT_PARTS[name] and shirtTexture ~= "" then
                makeVisual(folder, sourcePart, name, meshUri, shirtTexture, 1.005, "Shirt")
            end
        end

        if outfit.graphic and outfit.graphic ~= "" then
            makeGraphicLayer(folder, character, outfit.graphic)
        end

        applyHead(character, outfit.face)
        local attached = 0
        local failedAccessories = 0
        for _, accessory in ipairs(outfit.accessories or {}) do
            if addAccessory(character, humanoid, accessory) then
                attached = attached + 1
            else
                failedAccessories = failedAccessories + 1
            end
        end

        active = true
        if setStatus then
            setStatus(("R63 v7 ready | shirt:%s pants:%s accessories:%d%s"):format(
                tostring(shirtId or "none"),
                tostring(pantsId or "none"),
                attached,
                failedAccessories > 0 and (" failed:" .. tostring(failedAccessories)) or ""
            ))
        end
    end)

    if not ok then
        pcall(restoreOriginal)
        error(buildError)
    end
end

local function captureOriginalIfNeeded(character)
    if not active or savedCharacter ~= character or not saved then
        destroySnapshot(saved)
        saved = captureSnapshot(character)
        savedCharacter = character
    end
end

local function applyMorph(text, setStatus)
    local character = getCharacter()
    captureOriginalIfNeeded(character)

    local custom = nil
    if tostring(text):match("%d") then
        lastIds = tostring(text)
        custom = resolveCatalogIds(text, setStatus)
    else
        lastIds = ""
    end
    if player.Character ~= character then
        error("R63 GUI v7: character respawned during loading; press Apply again")
    end

    local nextOutfit = mergeOutfit(saved, custom)
    destroyOutfit(currentOutfit)
    currentOutfit = nextOutfit
    local built, buildError = pcall(buildMorph, nextOutfit, setStatus)
    if custom then
        for _, accessory in ipairs(custom.accessories or {}) do
            pcall(function()
                accessory:Destroy()
            end)
        end
    end
    if not built then
        error(buildError)
    end
    if custom and #custom.failed > 0 and setStatus then
        setStatus("Morph built; unresolved/unsupported: " .. table.concat(custom.failed, ", "))
    end
end

-- GUI -----------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "R63 GUI v7"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999999
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
environment.R63_GUI_OBJECT = gui
runtime.gui = gui

local main = Instance.new("Frame")
main.Name = "Main"
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.Position = UDim2.fromScale(0.5, 0.5)
main.Size = UDim2.fromOffset(344, 474)
main.BackgroundColor3 = Color3.fromRGB(24, 24, 29)
main.BorderSizePixel = 0
main.Parent = gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 11)
mainCorner.Parent = main

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(60, 60, 72)
mainStroke.Transparency = 0.35
mainStroke.Thickness = 1
mainStroke.Parent = main

local scale = Instance.new("UIScale")
scale.Parent = main
local viewportConnection = nil
local function fitToViewport()
    local camera = workspace.CurrentCamera
    if not camera then
        scale.Scale = 1
        return
    end
    local viewport = camera.ViewportSize
    scale.Scale = math.clamp(math.min(1, (viewport.X - 18) / 344, (viewport.Y - 28) / 474), 0.45, 1)
end
local function bindCamera()
    if viewportConnection then
        viewportConnection:Disconnect()
    end
    local camera = workspace.CurrentCamera
    if camera then
        viewportConnection = track(camera:GetPropertyChangedSignal("ViewportSize"):Connect(fitToViewport))
    end
    fitToViewport()
end
track(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera))
bindCamera()

local top = Instance.new("Frame")
top.Name = "TitleBar"
top.Size = UDim2.new(1, 0, 0, 36)
top.BackgroundTransparency = 1
top.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -46, 1, 0)
title.Position = UDim2.fromOffset(12, 0)
title.BackgroundTransparency = 1
title.Text = "R63 GUI v7"
title.TextColor3 = Color3.new(1, 1, 1)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
title.TextSize = 17
title.Parent = top

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(28, 28)
close.Position = UDim2.new(1, -34, 0, 4)
close.BackgroundColor3 = Color3.fromRGB(50, 50, 58)
close.BorderSizePixel = 0
close.Text = "×"
close.TextColor3 = Color3.new(1, 1, 1)
close.TextSize = 18
close.Parent = top
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 7)
closeCorner.Parent = close

local idsLabel = Instance.new("TextLabel")
idsLabel.Size = UDim2.new(1, -24, 0, 18)
idsLabel.Position = UDim2.fromOffset(12, 40)
idsLabel.BackgroundTransparency = 1
idsLabel.Text = "Catalog IDs: classic clothes, face, rigid accessories"
idsLabel.TextColor3 = Color3.fromRGB(205, 205, 216)
idsLabel.TextXAlignment = Enum.TextXAlignment.Left
idsLabel.Font = Enum.Font.Gotham
idsLabel.TextSize = 11
idsLabel.Parent = main

local idsBox = Instance.new("TextBox")
idsBox.Size = UDim2.new(1, -24, 0, 46)
idsBox.Position = UDim2.fromOffset(12, 61)
idsBox.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
idsBox.BorderSizePixel = 0
idsBox.ClearTextOnFocus = false
idsBox.MultiLine = true
idsBox.TextWrapped = true
idsBox.TextXAlignment = Enum.TextXAlignment.Left
idsBox.TextYAlignment = Enum.TextYAlignment.Top
idsBox.TextColor3 = Color3.new(1, 1, 1)
idsBox.PlaceholderColor3 = Color3.fromRGB(125, 125, 138)
idsBox.PlaceholderText = "Empty = preserve the current outfit"
idsBox.Font = Enum.Font.Code
idsBox.TextSize = 12
idsBox.Parent = main
local idsCorner = Instance.new("UICorner")
idsCorner.CornerRadius = UDim.new(0, 7)
idsCorner.Parent = idsBox
local idsPadding = Instance.new("UIPadding")
idsPadding.PaddingLeft = UDim.new(0, 8)
idsPadding.PaddingRight = UDim.new(0, 8)
idsPadding.PaddingTop = UDim.new(0, 6)
idsPadding.Parent = idsBox

local skinLabel = Instance.new("TextLabel")
skinLabel.Size = UDim2.fromOffset(130, 18)
skinLabel.Position = UDim2.fromOffset(12, 112)
skinLabel.BackgroundTransparency = 1
skinLabel.Text = "Skin color"
skinLabel.TextColor3 = Color3.fromRGB(205, 205, 216)
skinLabel.TextXAlignment = Enum.TextXAlignment.Left
skinLabel.Font = Enum.Font.Gotham
skinLabel.TextSize = 11
skinLabel.Parent = main

local wheel = Instance.new("Frame")
wheel.Size = UDim2.fromOffset(106, 106)
wheel.Position = UDim2.fromOffset(12, 132)
wheel.BackgroundTransparency = 1
wheel.Parent = main

local dots = {}
local refreshColors
for ring = 1, 5 do
    local ringSaturation = ring / 5
    local radius = 9 + ring * 8
    for step = 0, 23 do
        local dotHue = step / 24
        local angle = dotHue * math.pi * 2 - math.pi / 2
        local x = 53 + math.cos(angle) * radius
        local y = 53 + math.sin(angle) * radius
        local dot = Instance.new("TextButton")
        dot.Size = UDim2.fromOffset(9, 9)
        dot.Position = UDim2.fromOffset(x - 4.5, y - 4.5)
        dot.BackgroundColor3 = Color3.fromHSV(dotHue, ringSaturation, value)
        dot.BorderSizePixel = 0
        dot.Text = ""
        dot.AutoButtonColor = false
        dot.Parent = wheel
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = dot
        table.insert(dots, { button = dot, hue = dotHue, saturation = ringSaturation })
        track(dot.MouseButton1Click:Connect(function()
            hue = dotHue
            saturation = ringSaturation
            refreshColors()
        end))
    end
end

local whiteDot = Instance.new("TextButton")
whiteDot.Size = UDim2.fromOffset(16, 16)
whiteDot.Position = UDim2.fromOffset(45, 45)
whiteDot.BackgroundColor3 = Color3.fromHSV(0, 0, value)
whiteDot.BorderSizePixel = 0
whiteDot.Text = ""
whiteDot.Parent = wheel
local whiteCorner = Instance.new("UICorner")
whiteCorner.CornerRadius = UDim.new(1, 0)
whiteCorner.Parent = whiteDot

local preview = Instance.new("Frame")
preview.Size = UDim2.fromOffset(28, 28)
preview.Position = UDim2.fromOffset(132, 136)
preview.BackgroundColor3 = skinColor()
preview.Parent = main
local previewCorner = Instance.new("UICorner")
previewCorner.CornerRadius = UDim.new(1, 0)
previewCorner.Parent = preview

local function smallButton(text, x, y, width)
    local button = Instance.new("TextButton")
    button.Size = UDim2.fromOffset(width, 30)
    button.Position = UDim2.fromOffset(x, y)
    button.BackgroundColor3 = Color3.fromRGB(50, 50, 58)
    button.BorderSizePixel = 0
    button.Text = text
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Font = Enum.Font.GothamSemibold
    button.TextSize = 10
    button.Parent = main
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = button
    return button
end

local darker = smallButton("Darker", 132, 174, 78)
local lighter = smallButton("Lighter", 218, 174, 78)

refreshColors = function()
    preview.BackgroundColor3 = skinColor()
    for _, dot in ipairs(dots) do
        dot.button.BackgroundColor3 = Color3.fromHSV(dot.hue, dot.saturation, value)
    end
    whiteDot.BackgroundColor3 = Color3.fromHSV(0, 0, value)
    recolor(player.Character)
end

track(whiteDot.MouseButton1Click:Connect(function()
    saturation = 0
    refreshColors()
end))
track(darker.MouseButton1Click:Connect(function()
    value = math.clamp(value - 0.08, 0.16, 1)
    refreshColors()
end))
track(lighter.MouseButton1Click:Connect(function()
    value = math.clamp(value + 0.08, 0.16, 1)
    refreshColors()
end))

local headLabel = Instance.new("TextLabel")
headLabel.Size = UDim2.fromOffset(120, 18)
headLabel.Position = UDim2.fromOffset(132, 211)
headLabel.BackgroundTransparency = 1
headLabel.Text = "Head"
headLabel.TextColor3 = Color3.fromRGB(205, 205, 216)
headLabel.TextXAlignment = Enum.TextXAlignment.Left
headLabel.Font = Enum.Font.Gotham
headLabel.TextSize = 11
headLabel.Parent = main

local headButtons = {}
local function refreshHeadButtons()
    for mode, button in pairs(headButtons) do
        button.BackgroundColor3 = mode == headMode
            and Color3.fromRGB(78, 78, 94)
            or Color3.fromRGB(50, 50, 58)
    end
end
local function makeHeadButton(mode, x, width)
    local button = smallButton(mode, x, 231, width)
    headButtons[mode] = button
    track(button.MouseButton1Click:Connect(function()
        headMode = mode
        refreshHeadButtons()
        if player.Character and active then
            applyHead(player.Character, currentOutfit and currentOutfit.face or "")
        end
    end))
end
makeHeadButton("Normal", 132, 52)
makeHeadButton("Faceless", 188, 58)
makeHeadButton("Invisible", 250, 70)
refreshHeadButtons()

local function largeButton(text, x, y, width)
    local button = smallButton(text, x, y, width)
    button.Size = UDim2.fromOffset(width, 34)
    button.TextSize = 12
    return button
end

local applyButton = largeButton("Rebuild morph", 12, 274, 320)
local currentButton = largeButton("Use current outfit", 12, 316, 154)
local idsButton = largeButton("Resolve IDs + rebuild", 178, 316, 154)
local resetButton = largeButton("Reset original", 12, 358, 154)
local autoButton = largeButton("Auto respawn: OFF", 178, 358, 154)

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -24, 0, 66)
statusLabel.Position = UDim2.fromOffset(12, 400)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Ready. v7 preserves your original avatar and maps classic clothes to the custom mesh UVs."
statusLabel.TextColor3 = Color3.fromRGB(160, 160, 176)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.TextWrapped = true
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 10
statusLabel.Parent = main

local function setStatus(text)
    if statusLabel and statusLabel.Parent then
        statusLabel.Text = tostring(text)
    end
end

local busy = false
local function run(action)
    if busy or runtime.closed then
        return
    end
    busy = true
    task.spawn(function()
        local ok, result = pcall(action)
        if not ok then
            setStatus("Error: " .. tostring(result))
        end
        busy = false
    end)
end

track(applyButton.MouseButton1Click:Connect(function()
    run(function()
        applyMorph(idsBox.Text, setStatus)
    end)
end))
track(currentButton.MouseButton1Click:Connect(function()
    run(function()
        idsBox.Text = ""
        applyMorph("", setStatus)
    end)
end))
track(idsButton.MouseButton1Click:Connect(function()
    run(function()
        applyMorph(idsBox.Text, setStatus)
    end)
end))
track(resetButton.MouseButton1Click:Connect(function()
    run(function()
        restoreOriginal(setStatus)
    end)
end))
track(autoButton.MouseButton1Click:Connect(function()
    autoRespawn = not autoRespawn
    autoButton.Text = "Auto respawn: " .. (autoRespawn and "ON" or "OFF")
end))

track(player.CharacterAdded:Connect(function(character)
    active = false
    destroyOutfit(currentOutfit)
    currentOutfit = nil
    destroySnapshot(saved)
    saved = nil
    savedCharacter = nil
    recoverLegacyMorph(character)
    if autoRespawn and not runtime.closed then
        task.wait(1.1)
        run(function()
            applyMorph(lastIds, setStatus)
        end)
    end
end))

do
    local dragging = false
    local startPointer = nil
    local startPosition = nil
    track(top.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            startPointer = input.Position
            startPosition = main.Position
        end
    end))
    track(top.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
    track(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - startPointer
            main.Position = UDim2.new(
                startPosition.X.Scale,
                startPosition.X.Offset + delta.X,
                startPosition.Y.Scale,
                startPosition.Y.Offset + delta.Y
            )
        end
    end))
end

runtime.reset = function()
    restoreOriginal()
end
runtime.shutdown = function(restoreAvatar)
    if restoreAvatar then
        pcall(restoreOriginal)
    end
    if not runtime.disconnected then
        runtime.disconnected = true
        for _, connection in ipairs(runtime.connections) do
            pcall(function()
                connection:Disconnect()
            end)
        end
    end
    runtime.closed = true
    if gui and gui.Parent then
        pcall(function()
            gui:Destroy()
        end)
    end
    if environment.R63_GUI_OBJECT == gui then
        environment.R63_GUI_OBJECT = nil
    end
    if restoreAvatar then
        destroySnapshot(saved)
        saved = nil
        savedCharacter = nil
        if environment.R63_GUI_RUNTIME == runtime then
            environment.R63_GUI_RUNTIME = nil
        end
    end
end

track(close.MouseButton1Click:Connect(function()
    runtime.shutdown(false)
end))

refreshColors()
