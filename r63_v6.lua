-- R63 GUI v6
-- Robust outfit resolver: Roblox HumanoidDescription -> temporary R6 rig -> real Shirt/Pants/Accessories.
-- Repo: https://github.com/a65407112-boop/r63

local Players=game:GetService("Players")
local MarketplaceService=game:GetService("MarketplaceService")
local CoreGui=game:GetService("CoreGui")
local UIS=game:GetService("UserInputService")
local player=Players.LocalPlayer
local BASE="https://raw.githubusercontent.com/a65407112-boop/r63/main"
local BODY={["Torso"]="torso.mesh",["Left Arm"]="leftarm.mesh",["Right Arm"]="rightarm.mesh",["Left Leg"]="leftleg.mesh",["Right Leg"]="rightleg.mesh"}
local ORDER={"Torso","Left Arm","Right Arm","Left Leg","Right Leg"}
local SHIRT={["Torso"]=true,["Left Arm"]=true,["Right Arm"]=true}
local PANTS={["Torso"]=true,["Left Leg"]=true,["Right Leg"]=true}
local meshCache={}
local saved=nil
local active=false
local auto=false
local lastIds=""
local headMode="Normal"
local hue,sat,val=.075,.30,1
local function skin() return Color3.fromHSV(hue,sat,val) end
local function getChar()
 local c=player.Character or player.CharacterAdded:Wait()
 local h=c:FindFirstChildOfClass("Humanoid") or c:WaitForChild("Humanoid",10)
 if not h then error("R63 v6: Humanoid not found") end
 if h.RigType~=Enum.HumanoidRigType.R6 then error("R63 v6: R6 required") end
 return c,h
end
local function ensureFolder(p) if makefolder then pcall(makefolder,p) end end
local function customAsset(p)
 if getcustomasset then return getcustomasset(p) end
 if getsynasset then return getsynasset(p) end
 error("R63 v6: getcustomasset/getsynasset required")
end
local function getMesh(file)
 if meshCache[file] then return meshCache[file] end
 if not writefile then error("R63 v6: writefile required") end
 ensureFolder("r63_gui_v6"); ensureFolder("r63_gui_v6/meshes")
 local path="r63_gui_v6/meshes/"..file
 local okCache=false
 if isfile and readfile and isfile(path) then local ok,d=pcall(readfile,path); okCache=ok and type(d)=="string" and #d>100 end
 if not okCache then
  local ok,d=pcall(function() return game:HttpGet(BASE.."/meshes/"..file.."?v6="..tostring(os.time()),false) end)
  if not ok or type(d)~="string" or #d<100 then error("R63 v6: failed mesh "..file) end
  writefile(path,d)
 end
 meshCache[file]=customAsset(path)
 return meshCache[file]
end
local function cloneObj(o)
 local a=o.Archivable; o.Archivable=true
 local ok,c=pcall(function() return o:Clone() end)
 o.Archivable=a
 return ok and c or nil
end
local function normalizeTexture(s)
 s=tostring(s or "")
 if s=="" then return "" end
 local id=s:match("[?&]id=(%d+)") or s:match("rbxassetid://(%d+)") or s:match("(%d+)")
 if id then return "rbxassetid://"..id,id end
 return s,s
end
local function faceTexture(c)
 local h=c:FindFirstChild("Head"); if not h then return "" end
 local d=h:FindFirstChild("face"); if d and d:IsA("Decal") then return d.Texture end
 for _,x in ipairs(h:GetChildren()) do if x:IsA("Decal") then return x.Texture end end
 return ""
end
local function snapshot(c)
 local o={shirt="",pants="",graphic="",face=faceTexture(c),acc={}}
 local s=c:FindFirstChildOfClass("Shirt"); if s then o.shirt=s.ShirtTemplate end
 local p=c:FindFirstChildOfClass("Pants"); if p then o.pants=p.PantsTemplate end
 local g=c:FindFirstChildOfClass("ShirtGraphic"); if g then o.graphic=g.Graphic end
 for _,x in ipairs(c:GetChildren()) do if x:IsA("Accessory") or x:IsA("Hat") then local q=cloneObj(x); if q then table.insert(o.acc,q) end end end
 return o
end
local function clearCosmetics(c)
 for _,x in ipairs(c:GetChildren()) do
  if x:IsA("Shirt") or x:IsA("Pants") or x:IsA("ShirtGraphic") or x:IsA("Accessory") or x:IsA("Hat") or x:IsA("CharacterMesh") then x:Destroy() end
 end
end
local function rememberPart(p)
 if p:GetAttribute("R63v6Trans")==nil then p:SetAttribute("R63v6Trans",p.Transparency) end
 if p:GetAttribute("R63v6Color")==nil then p:SetAttribute("R63v6Color",p.Color) end
end
local function hideRig(c)
 for _,n in ipairs(ORDER) do local p=c:FindFirstChild(n); if p and p:IsA("BasePart") then rememberPart(p); p.Transparency=1 end end
end
local function restoreRig(c)
 for _,p in ipairs(c:GetChildren()) do if p:IsA("BasePart") then
  local t=p:GetAttribute("R63v6Trans"); local co=p:GetAttribute("R63v6Color")
  if typeof(t)=="number" then p.Transparency=t; p:SetAttribute("R63v6Trans",nil) end
  if typeof(co)=="Color3" then p.Color=co; p:SetAttribute("R63v6Color",nil) end
 end end
end
local function rememberHead(h)
 rememberPart(h)
 for _,d in ipairs(h:GetChildren()) do if d:IsA("Decal") or d:IsA("Texture") then if d:GetAttribute("R63v6Trans")==nil then d:SetAttribute("R63v6Trans",d.Transparency) end end end
end
local function applyHead(c,face)
 local h=c:FindFirstChild("Head"); if not h then return end
 rememberHead(h); h.Color=skin()
 local old=h:GetAttribute("R63v6Trans")
 h.Transparency=(headMode=="Invisible") and 1 or (typeof(old)=="number" and old or 0)
 local d=h:FindFirstChild("face")
 if face and face~="" then if not d then d=Instance.new("Decal"); d.Name="face"; d.Face=Enum.NormalId.Front; d.Parent=h end; d.Texture=face end
 for _,x in ipairs(h:GetChildren()) do if x:IsA("Decal") or x:IsA("Texture") then local ot=x:GetAttribute("R63v6Trans"); if headMode=="Normal" then x.Transparency=typeof(ot)=="number" and ot or 0 else x.Transparency=1 end end end
end
local function restoreHead(c)
 local h=c:FindFirstChild("Head"); if not h then return end
 local t=h:GetAttribute("R63v6Trans"); if typeof(t)=="number" then h.Transparency=t end
 for _,x in ipairs(h:GetChildren()) do if x:IsA("Decal") or x:IsA("Texture") then local ot=x:GetAttribute("R63v6Trans"); if typeof(ot)=="number" then x.Transparency=ot end end end
end
local function makeVisual(folder,src,name,uri,texture,scale,kind)
 local p=Instance.new("Part")
 p.Name=kind.."_"..name:gsub(" ",""); p.Size=src.Size; p.CFrame=src.CFrame; p.Color=skin(); p.Material=Enum.Material.SmoothPlastic
 p.Transparency=0; p.CanCollide=false; p.CanTouch=false; p.CanQuery=false; p.Massless=true; p.CastShadow=false; p.Anchored=false
 p:SetAttribute("R63v6Layer",kind); p.Parent=folder
 local m=Instance.new("SpecialMesh"); m.Name="Mesh"; m.MeshType=Enum.MeshType.FileMesh; m.MeshId=uri; m.TextureId=normalizeTexture(texture); m.VertexColor=Vector3.new(1,1,1); m.Scale=Vector3.new(scale,scale,scale); m.Parent=p
 local w=Instance.new("WeldConstraint"); w.Part0=src; w.Part1=p; w.Parent=p
 return p
end
local function recolor(c)
 local f=c and c:FindFirstChild("R63VisualMorph")
 if f then for _,p in ipairs(f:GetChildren()) do if p:IsA("BasePart") then p.Color=skin() end end end
 if c then applyHead(c,saved and saved.face or "") end
end
local function findRigAttachment(c,accessory,name)
 for _,x in ipairs(c:GetDescendants()) do if x:IsA("Attachment") and x.Name==name and not x:IsDescendantOf(accessory) and x.Parent and x.Parent:IsA("BasePart") then return x end end
end
local function manualAttach(c,a)
 local h=a:FindFirstChild("Handle"); if not h or not h:IsA("BasePart") then return false end
 a.Parent=c; h.Anchored=false; h.CanCollide=false; h.CanTouch=false; h.CanQuery=false; h.Massless=true
 for _,w in ipairs(h:GetChildren()) do if (w:IsA("Weld") or w:IsA("WeldConstraint") or w:IsA("Motor6D")) and w.Name=="AccessoryWeld" then w:Destroy() end end
 for _,ha in ipairs(h:GetChildren()) do if ha:IsA("Attachment") then local ra=findRigAttachment(c,a,ha.Name); if ra then
  local rp=ra.Parent; h.CFrame=rp.CFrame*ra.CFrame*ha.CFrame:Inverse(); local w=Instance.new("Weld"); w.Name="AccessoryWeld"; w.Part0=rp; w.Part1=h; w.C0=ra.CFrame; w.C1=ha.CFrame; w.Parent=h; return true
 end end end
 local hd=c:FindFirstChild("Head")
 if hd then local ap=CFrame.new(); pcall(function() ap=a.AttachmentPoint end); local hp=CFrame.new(0,.5,0); h.CFrame=hd.CFrame*hp*ap:Inverse(); local w=Instance.new("Weld"); w.Name="AccessoryWeld"; w.Part0=hd; w.Part1=h; w.C0=hp; w.C1=ap; w.Parent=h; return true end
 return false
end
local function addAccessory(c,h,a)
 local q=cloneObj(a); if not q then return false end; q.Parent=nil
 local ok=pcall(function() h:AddAccessory(q) end)
 if ok and q.Parent==c then return true end
 if q.Parent then q.Parent=nil end
 if manualAttach(c,q) then return true end
 q:Destroy(); return false
end
local function parseIds(s)
 local r,seen={},{}
 for t in tostring(s):gmatch("[^,%s;]+") do local id=t:match("(%d+)"); if id and not seen[id] then seen[id]=true; table.insert(r,tonumber(id)) end end
 return r
end
local ACCESSORY_PROPS={[8]="HatAccessory",[41]="HairAccessory",[42]="FaceAccessory",[43]="NeckAccessory",[44]="ShouldersAccessory",[45]="FrontAccessory",[46]="BackAccessory",[47]="WaistAccessory"}
local function resolveWithDummy(text,status)
 local ids=parseIds(text)
 local result={shirt=nil,pants=nil,graphic=nil,face=nil,acc={},failed={},types={}}
 if #ids==0 then return result end
 local desc=Instance.new("HumanoidDescription")
 local propLists={}
 local wanted={shirt=false,pants=false,graphic=false,face=false,acc=false}
 for i,id in ipairs(ids) do
  if status then status(("Resolving catalog ID %d/%d: %d"):format(i,#ids,id)) end
  local ok,info=pcall(function() if MarketplaceService.GetProductInfoAsync then return MarketplaceService:GetProductInfoAsync(id,Enum.InfoType.Asset) else return MarketplaceService:GetProductInfo(id,Enum.InfoType.Asset) end end)
  local typ=ok and info and tonumber(info.AssetTypeId); result.types[id]=typ
  if typ==11 then desc.Shirt=id; wanted.shirt=true
  elseif typ==12 then desc.Pants=id; wanted.pants=true
  elseif typ==2 then desc.GraphicTShirt=id; wanted.graphic=true
  elseif typ==18 then desc.Face=id; wanted.face=true
  elseif ACCESSORY_PROPS[typ] then local prop=ACCESSORY_PROPS[typ]; propLists[prop]=propLists[prop] or {}; table.insert(propLists[prop],tostring(id)); wanted.acc=true
  else table.insert(result.failed,tostring(id)) end
 end
 for prop,list in pairs(propLists) do desc[prop]=table.concat(list,",") end
 local dummy=nil
 local ok=pcall(function() if Players.CreateHumanoidModelFromDescriptionAsync then dummy=Players:CreateHumanoidModelFromDescriptionAsync(desc,Enum.HumanoidRigType.R6) else dummy=Players:CreateHumanoidModelFromDescription(desc,Enum.HumanoidRigType.R6) end end)
 if ok and dummy then
  if wanted.shirt then local x=dummy:FindFirstChildOfClass("Shirt"); if x then result.shirt=x.ShirtTemplate end end
  if wanted.pants then local x=dummy:FindFirstChildOfClass("Pants"); if x then result.pants=x.PantsTemplate end end
  if wanted.graphic then local x=dummy:FindFirstChildOfClass("ShirtGraphic"); if x then result.graphic=x.Graphic end end
  if wanted.face then result.face=faceTexture(dummy) end
  if wanted.acc then for _,x in ipairs(dummy:GetChildren()) do if x:IsA("Accessory") or x:IsA("Hat") then local q=cloneObj(x); if q then table.insert(result.acc,q) end end end end
  dummy:Destroy()
 else
  for _,id in ipairs(ids) do
   local roots={}; local rok,r=pcall(function() return game:GetObjects("rbxassetid://"..id) end); if rok and type(r)=="table" then roots=r end
   for _,root in ipairs(roots) do
    local all={root}; for _,x in ipairs(root:GetDescendants()) do table.insert(all,x) end
    for _,x in ipairs(all) do
     if x:IsA("Shirt") then result.shirt=x.ShirtTemplate
     elseif x:IsA("Pants") then result.pants=x.PantsTemplate
     elseif x:IsA("ShirtGraphic") then result.graphic=x.Graphic
     elseif x:IsA("Accessory") or x:IsA("Hat") then local q=cloneObj(x); if q then table.insert(result.acc,q) end end
    end
    pcall(function() root:Destroy() end)
   end
  end
 end
 if wanted.shirt and not result.shirt then table.insert(result.failed,"shirt") end
 if wanted.pants and not result.pants then table.insert(result.failed,"pants") end
 if wanted.graphic and not result.graphic then table.insert(result.failed,"t-shirt") end
 if wanted.acc and #result.acc==0 then table.insert(result.failed,"accessories") end
 return result
end
local function merge(base,custom)
 local out={shirt=base and base.shirt or "",pants=base and base.pants or "",graphic=base and base.graphic or "",face=base and base.face or "",acc={}}
 if base then for _,a in ipairs(base.acc or {}) do local q=cloneObj(a); if q then table.insert(out.acc,q) end end end
 if custom then
  if custom.shirt~=nil then out.shirt=custom.shirt end
  if custom.pants~=nil then out.pants=custom.pants end
  if custom.graphic~=nil then out.graphic=custom.graphic end
  if custom.face~=nil then out.face=custom.face end
  for _,a in ipairs(custom.acc or {}) do local q=cloneObj(a); if q then table.insert(out.acc,q) end end
 end
 return out
end
local function build(out,status)
 local c,h=getChar(); local old=c:FindFirstChild("R63VisualMorph"); if old then old:Destroy() end
 clearCosmetics(c); hideRig(c); applyHead(c,out.face)
 local f=Instance.new("Folder"); f.Name="R63VisualMorph"; f.Parent=c
 local shirtTex,shirtId=normalizeTexture(out.shirt); local pantsTex,pantsId=normalizeTexture(out.pants)
 for _,name in ipairs(ORDER) do
  local src=c:FindFirstChild(name); if not src then error("R63 v6: missing "..name) end
  local uri=getMesh(BODY[name]); makeVisual(f,src,name,uri,"",1,"Body")
  if PANTS[name] and pantsTex~="" then makeVisual(f,src,name,uri,pantsTex,1.002,"Pants") end
  if SHIRT[name] and shirtTex~="" then makeVisual(f,src,name,uri,shirtTex,1.004,"Shirt") end
 end
 if out.graphic and out.graphic~="" then local g=Instance.new("ShirtGraphic"); g.Graphic=out.graphic; g.Parent=c end
 local attached=0; for _,a in ipairs(out.acc or {}) do if addAccessory(c,h,a) then attached+=1 end end
 active=true
 if status then status("R63 v6 | shirt:"..tostring(shirtId or "none").." pants:"..tostring(pantsId or "none").." accessories:"..attached) end
end
local function apply(text,status)
 local c=getChar(); if not active or not saved then saved=snapshot(c) end
 local custom=nil; if tostring(text):match("%d") then lastIds=text; custom=resolveWithDummy(text,status) else lastIds="" end
 build(merge(saved,custom),status)
 if custom and #custom.failed>0 and status then status("Built, but unresolved: "..table.concat(custom.failed,", ")) end
end
local function reset(status)
 local c=player.Character; if not c then return end
 local f=c:FindFirstChild("R63VisualMorph"); if f then f:Destroy() end
 clearCosmetics(c); restoreRig(c); restoreHead(c)
 if saved then
  if saved.shirt~="" then local x=Instance.new("Shirt"); x.ShirtTemplate=saved.shirt; x.Parent=c end
  if saved.pants~="" then local x=Instance.new("Pants"); x.PantsTemplate=saved.pants; x.Parent=c end
  if saved.graphic~="" then local x=Instance.new("ShirtGraphic"); x.Graphic=saved.graphic; x.Parent=c end
  local h=c:FindFirstChildOfClass("Humanoid"); if h then for _,a in ipairs(saved.acc or {}) do addAccessory(c,h,a) end end
  applyHead(c,saved.face)
 end
 active=false; if status then status("Original visuals restored") end
end
if getgenv and getgenv().R63_GUI_OBJECT then pcall(function() getgenv().R63_GUI_OBJECT:Destroy() end) end
local gui=Instance.new("ScreenGui"); gui.Name="R63 GUI"; gui.ResetOnSpawn=false; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
local parented=false; if gethui then parented=pcall(function() gui.Parent=gethui() end) end; if not parented or not gui.Parent then pcall(function() gui.Parent=CoreGui end) end; if not gui.Parent then gui.Parent=player:WaitForChild("PlayerGui") end
if getgenv then getgenv().R63_GUI_OBJECT=gui end
local main=Instance.new("Frame"); main.AnchorPoint=Vector2.new(.5,.5); main.Position=UDim2.fromScale(.5,.5); main.Size=UDim2.fromOffset(344,474); main.BackgroundColor3=Color3.fromRGB(24,24,29); main.BorderSizePixel=0; main.Parent=gui; Instance.new("UICorner",main).CornerRadius=UDim.new(0,11)
local scale=Instance.new("UIScale",main)
local function fit() local cam=workspace.CurrentCamera; if not cam then scale.Scale=1 return end; local v=cam.ViewportSize; scale.Scale=math.clamp(math.min(1,(v.X-18)/344,(v.Y-28)/474),.68,1) end
fit(); if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit) end
local top=Instance.new("Frame"); top.Size=UDim2.new(1,0,0,36); top.BackgroundTransparency=1; top.Parent=main
local title=Instance.new("TextLabel"); title.Size=UDim2.new(1,-46,1,0); title.Position=UDim2.fromOffset(12,0); title.BackgroundTransparency=1; title.Text="R63 GUI v6"; title.TextColor3=Color3.new(1,1,1); title.TextXAlignment=Enum.TextXAlignment.Left; title.Font=Enum.Font.GothamBold; title.TextSize=17; title.Parent=top
local close=Instance.new("TextButton"); close.Size=UDim2.fromOffset(28,28); close.Position=UDim2.new(1,-34,0,4); close.BackgroundColor3=Color3.fromRGB(50,50,58); close.Text="×"; close.TextColor3=Color3.new(1,1,1); close.TextSize=18; close.Parent=top; Instance.new("UICorner",close).CornerRadius=UDim.new(0,7); close.MouseButton1Click:Connect(function() gui:Destroy() end)
local label=Instance.new("TextLabel"); label.Size=UDim2.new(1,-24,0,18); label.Position=UDim2.fromOffset(12,40); label.BackgroundTransparency=1; label.Text="Catalog IDs: shirt, pants, T-shirt, rigid accessories"; label.TextColor3=Color3.fromRGB(205,205,216); label.TextXAlignment=Enum.TextXAlignment.Left; label.Font=Enum.Font.Gotham; label.TextSize=11; label.Parent=main
local box=Instance.new("TextBox"); box.Size=UDim2.new(1,-24,0,46); box.Position=UDim2.fromOffset(12,61); box.BackgroundColor3=Color3.fromRGB(35,35,42); box.BorderSizePixel=0; box.ClearTextOnFocus=false; box.MultiLine=true; box.TextWrapped=true; box.TextXAlignment=Enum.TextXAlignment.Left; box.TextYAlignment=Enum.TextYAlignment.Top; box.TextColor3=Color3.new(1,1,1); box.PlaceholderColor3=Color3.fromRGB(125,125,138); box.PlaceholderText="Empty = keep current outfit"; box.Font=Enum.Font.Code; box.TextSize=12; box.Parent=main; Instance.new("UICorner",box).CornerRadius=UDim.new(0,7)
local pad=Instance.new("UIPadding",box); pad.PaddingLeft=UDim.new(0,8); pad.PaddingRight=UDim.new(0,8); pad.PaddingTop=UDim.new(0,6)
local skinLabel=Instance.new("TextLabel"); skinLabel.Size=UDim2.fromOffset(130,18); skinLabel.Position=UDim2.fromOffset(12,112); skinLabel.BackgroundTransparency=1; skinLabel.Text="Skin color"; skinLabel.TextColor3=Color3.fromRGB(205,205,216); skinLabel.TextXAlignment=Enum.TextXAlignment.Left; skinLabel.Font=Enum.Font.Gotham; skinLabel.TextSize=11; skinLabel.Parent=main
local wheel=Instance.new("Frame"); wheel.Size=UDim2.fromOffset(106,106); wheel.Position=UDim2.fromOffset(12,132); wheel.BackgroundTransparency=1; wheel.Parent=main
local dots={}
for ring=1,5 do local s=ring/5; local radius=9+ring*8; for step=0,23 do local h=step/24; local a=h*math.pi*2-math.pi/2; local x=53+math.cos(a)*radius; local y=53+math.sin(a)*radius; local b=Instance.new("TextButton"); b.Size=UDim2.fromOffset(9,9); b.Position=UDim2.fromOffset(x-4.5,y-4.5); b.BackgroundColor3=Color3.fromHSV(h,s,val); b.BorderSizePixel=0; b.Text=""; b.AutoButtonColor=false; b.Parent=wheel; Instance.new("UICorner",b).CornerRadius=UDim.new(1,0); table.insert(dots,{b,h,s}); b.MouseButton1Click:Connect(function() hue=h; sat=s; recolor(player.Character) end) end end
local center=Instance.new("TextButton"); center.Size=UDim2.fromOffset(16,16); center.Position=UDim2.fromOffset(45,45); center.BackgroundColor3=Color3.fromHSV(0,0,val); center.BorderSizePixel=0; center.Text=""; center.Parent=wheel; Instance.new("UICorner",center).CornerRadius=UDim.new(1,0); center.MouseButton1Click:Connect(function() sat=0; recolor(player.Character) end)
local preview=Instance.new("Frame"); preview.Size=UDim2.fromOffset(28,28); preview.Position=UDim2.fromOffset(132,136); preview.BackgroundColor3=skin(); preview.Parent=main; Instance.new("UICorner",preview).CornerRadius=UDim.new(1,0)
local function smallButton(text,x,y,w) local b=Instance.new("TextButton"); b.Size=UDim2.fromOffset(w,30); b.Position=UDim2.fromOffset(x,y); b.BackgroundColor3=Color3.fromRGB(50,50,58); b.BorderSizePixel=0; b.Text=text; b.TextColor3=Color3.new(1,1,1); b.Font=Enum.Font.GothamSemibold; b.TextSize=10; b.Parent=main; Instance.new("UICorner",b).CornerRadius=UDim.new(0,7); return b end
local darker=smallButton("Darker",132,174,78); local lighter=smallButton("Lighter",218,174,78)
local function refreshColors() preview.BackgroundColor3=skin(); for _,d in ipairs(dots) do d[1].BackgroundColor3=Color3.fromHSV(d[2],d[3],val) end; center.BackgroundColor3=Color3.fromHSV(0,0,val); recolor(player.Character) end
darker.MouseButton1Click:Connect(function() val=math.clamp(val-.08,.16,1); refreshColors() end); lighter.MouseButton1Click:Connect(function() val=math.clamp(val+.08,.16,1); refreshColors() end)
local headLabel=Instance.new("TextLabel"); headLabel.Size=UDim2.fromOffset(120,18); headLabel.Position=UDim2.fromOffset(132,211); headLabel.BackgroundTransparency=1; headLabel.Text="Head"; headLabel.TextColor3=Color3.fromRGB(205,205,216); headLabel.TextXAlignment=Enum.TextXAlignment.Left; headLabel.Font=Enum.Font.Gotham; headLabel.TextSize=11; headLabel.Parent=main
local headButtons={}
local function refreshHeadButtons() for mode,b in pairs(headButtons) do b.BackgroundColor3=(mode==headMode) and Color3.fromRGB(78,78,94) or Color3.fromRGB(50,50,58) end end
local function headButton(mode,x,w) local b=smallButton(mode,x,231,w); headButtons[mode]=b; b.MouseButton1Click:Connect(function() headMode=mode; refreshHeadButtons(); if player.Character then applyHead(player.Character,saved and saved.face or faceTexture(player.Character)) end end) end
headButton("Normal",132,52); headButton("Faceless",188,58); headButton("Invisible",250,70); refreshHeadButtons()
local function button(text,x,y,w) local b=Instance.new("TextButton"); b.Size=UDim2.fromOffset(w,34); b.Position=UDim2.fromOffset(x,y); b.BackgroundColor3=Color3.fromRGB(51,51,61); b.BorderSizePixel=0; b.Text=text; b.TextColor3=Color3.new(1,1,1); b.Font=Enum.Font.GothamSemibold; b.TextSize=12; b.Parent=main; Instance.new("UICorner",b).CornerRadius=UDim.new(0,7); return b end
local applyB=button("Rebuild morph",12,274,320); local currentB=button("Use current outfit",12,316,154); local idsB=button("Resolve IDs + rebuild",178,316,154); local resetB=button("Reset original",12,358,154); local autoB=button("Auto respawn: OFF",178,358,154)
local statusLabel=Instance.new("TextLabel"); statusLabel.Size=UDim2.new(1,-24,0,66); statusLabel.Position=UDim2.fromOffset(12,400); statusLabel.BackgroundTransparency=1; statusLabel.Text="v6 resolves catalog assets through Roblox avatar loading instead of treating catalog IDs as raw models."; statusLabel.TextColor3=Color3.fromRGB(160,160,176); statusLabel.TextXAlignment=Enum.TextXAlignment.Left; statusLabel.TextYAlignment=Enum.TextYAlignment.Top; statusLabel.TextWrapped=true; statusLabel.Font=Enum.Font.Gotham; statusLabel.TextSize=10; statusLabel.Parent=main
local function status(t) statusLabel.Text=tostring(t) end
local busy=false
local function run(fn) if busy then return end; busy=true; task.spawn(function() local ok,e=pcall(fn); if not ok then status("Error: "..tostring(e)) end; busy=false end) end
applyB.MouseButton1Click:Connect(function() run(function() apply(box.Text,status) end) end); currentB.MouseButton1Click:Connect(function() run(function() box.Text=""; apply("",status) end) end); idsB.MouseButton1Click:Connect(function() run(function() apply(box.Text,status) end) end); resetB.MouseButton1Click:Connect(function() run(function() reset(status) end) end); autoB.MouseButton1Click:Connect(function() auto=not auto; autoB.Text="Auto respawn: "..(auto and "ON" or "OFF") end)
player.CharacterAdded:Connect(function() active=false; saved=nil; if auto then task.wait(1.1); run(function() apply(lastIds,status) end) end end)
do
 local drag=false; local start; local pos
 top.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=true; start=i.Position; pos=main.Position end end)
 top.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=false end end)
 UIS.InputChanged:Connect(function(i) if drag and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then local d=i.Position-start; main.Position=UDim2.new(pos.X.Scale,pos.X.Offset+d.X,pos.Y.Scale,pos.Y.Offset+d.Y) end end)
end
