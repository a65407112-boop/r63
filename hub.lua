-- R63 GUI v5.1
-- Mesh body + direct classic-clothing texture mapping + accessory rebuild.
local P=game:GetService("Players").LocalPlayer
local RS=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local IS=game:GetService("InsertService")
local CG=game:GetService("CoreGui")
local BASE="https://raw.githubusercontent.com/a65407112-boop/r63/main"
local BODY={Torso="torso.mesh",["Left Arm"]="leftarm.mesh",["Right Arm"]="rightarm.mesh",["Left Leg"]="leftleg.mesh",["Right Leg"]="rightleg.mesh"}
local ORDER={"Torso","Left Arm","Right Arm","Left Leg","Right Leg"}
local SHIRT={Torso=true,["Left Arm"]=true,["Right Arm"]=true}
local PANTS={Torso=true,["Left Leg"]=true,["Right Leg"]=true}
local meshCache,saved,lastIds={},nil,""
local active,auto=false,false
local hue,sat,val=.075,.30,1
local headMode="Normal"
local function skin() return Color3.fromHSV(hue,sat,val) end
local function char()
 local c=P.Character or P.CharacterAdded:Wait(); local h=c:FindFirstChildOfClass("Humanoid") or c:WaitForChild("Humanoid",10)
 if not h then error("R63: Humanoid not found") end
 if h.RigType~=Enum.HumanoidRigType.R6 then error("R63: R6 required") end
 return c,h
end
local function folder(p) if makefolder then pcall(makefolder,p) end end
local function asset(path)
 if getcustomasset then return getcustomasset(path) end
 if getsynasset then return getsynasset(path) end
 error("R63: getcustomasset/getsynasset required")
end
local function mesh(file)
 if meshCache[file] then return meshCache[file] end
 if not writefile then error("R63: writefile required") end
 folder("r63_gui_v51"); folder("r63_gui_v51/meshes")
 local path="r63_gui_v51/meshes/"..file; local good=false
 if isfile and readfile and isfile(path) then local ok,d=pcall(readfile,path); good=ok and type(d)=="string" and #d>100 end
 if not good then
  local ok,d=pcall(function() return game:HttpGet(BASE.."/meshes/"..file.."?v=51_"..os.time(),false) end)
  if not ok or type(d)~="string" or #d<100 then error("R63: failed mesh "..file) end
  writefile(path,d)
 end
 meshCache[file]=asset(path); return meshCache[file]
end
local function clone(o)
 local a=o.Archivable; o.Archivable=true; local ok,c=pcall(function() return o:Clone() end); o.Archivable=a
 return ok and c or nil
end
local function snapshot(c)
 local o={shirt="",pants="",graphic="",acc={}}
 local s=c:FindFirstChildOfClass("Shirt"); if s then o.shirt=s.ShirtTemplate end
 local p=c:FindFirstChildOfClass("Pants"); if p then o.pants=p.PantsTemplate end
 local g=c:FindFirstChildOfClass("ShirtGraphic"); if g then o.graphic=g.Graphic end
 for _,x in ipairs(c:GetChildren()) do if x:IsA("Accessory") or x:IsA("Hat") then local q=clone(x); if q then table.insert(o.acc,q) end end end
 return o
end
local function clearCos(c)
 for _,x in ipairs(c:GetChildren()) do
  if x:IsA("Shirt") or x:IsA("Pants") or x:IsA("ShirtGraphic") or x:IsA("Accessory") or x:IsA("Hat") or x:IsA("CharacterMesh") then x:Destroy() end
 end
end
local function remember(part)
 if part:GetAttribute("R63OldTrans")==nil then part:SetAttribute("R63OldTrans",part.Transparency) end
 if part:GetAttribute("R63OldColor")==nil then part:SetAttribute("R63OldColor",part.Color) end
end
local function hideRig(c)
 for _,n in ipairs(ORDER) do local p=c:FindFirstChild(n); if p then remember(p); p.Transparency=1 end end
end
local function restoreRig(c)
 for _,p in ipairs(c:GetChildren()) do if p:IsA("BasePart") then
  local t=p:GetAttribute("R63OldTrans"); local co=p:GetAttribute("R63OldColor")
  if typeof(t)=="number" then p.Transparency=t; p:SetAttribute("R63OldTrans",nil) end
  if typeof(co)=="Color3" then p.Color=co; p:SetAttribute("R63OldColor",nil) end
 end end
end
local function rememberHead(h)
 remember(h)
 for _,d in ipairs(h:GetChildren()) do if d:IsA("Decal") or d:IsA("Texture") then if d:GetAttribute("R63OldTrans")==nil then d:SetAttribute("R63OldTrans",d.Transparency) end end end
end
local function head(c)
 local h=c:FindFirstChild("Head"); if not h then return end; rememberHead(h); h.Color=skin()
 local old=h:GetAttribute("R63OldTrans")
 if headMode=="Invisible" then h.Transparency=1 else h.Transparency=typeof(old)=="number" and old or 0 end
 for _,d in ipairs(h:GetChildren()) do if d:IsA("Decal") or d:IsA("Texture") then
  local ot=d:GetAttribute("R63OldTrans")
  if headMode=="Normal" then d.Transparency=typeof(ot)=="number" and ot or 0 else d.Transparency=1 end
 end end
end
local function restoreHead(c)
 local h=c:FindFirstChild("Head"); if not h then return end
 local t=h:GetAttribute("R63OldTrans"); if typeof(t)=="number" then h.Transparency=t end
 for _,d in ipairs(h:GetChildren()) do if d:IsA("Decal") or d:IsA("Texture") then local q=d:GetAttribute("R63OldTrans"); if typeof(q)=="number" then d.Transparency=q end end end
end
local function visual(f,src,n,uri,tex,scale,kind)
 local p=Instance.new("Part"); p.Name=kind.."_"..n:gsub(" ",""); p.Size=src.Size; p.CFrame=src.CFrame
 p.Color=kind=="Body" and skin() or Color3.new(1,1,1); p.Material=Enum.Material.SmoothPlastic
 p.Transparency=0; p.CanCollide=false; p.CanTouch=false; p.CanQuery=false; p.Massless=true; p.CastShadow=false; p.Anchored=false
 p:SetAttribute("R63Layer",kind); p.Parent=f
 local m=Instance.new("SpecialMesh"); m.MeshType=Enum.MeshType.FileMesh; m.MeshId=uri; m.TextureId=tex or ""; m.VertexColor=Vector3.new(1,1,1); m.Scale=Vector3.new(scale,scale,scale); m.Parent=p
 local w=Instance.new("WeldConstraint"); w.Part0=src; w.Part1=p; w.Parent=p
end
local function recolor(c)
 local f=c and c:FindFirstChild("R63VisualMorph")
 if f then for _,p in ipairs(f:GetChildren()) do if p:IsA("BasePart") then p.Color=p:GetAttribute("R63Layer")=="Body" and skin() or Color3.new(1,1,1) end end end
 if c then head(c) end
end
local function rigAttach(c,a,name)
 for _,x in ipairs(c:GetDescendants()) do if x:IsA("Attachment") and x.Name==name and not x:IsDescendantOf(a) and x.Parent and x.Parent:IsA("BasePart") then return x end end
end
local function manualAcc(c,a)
 local h=a:FindFirstChild("Handle"); if not h or not h:IsA("BasePart") then return false end
 a.Parent=c; h.Anchored=false; h.CanCollide=false; h.CanTouch=false; h.CanQuery=false; h.Massless=true
 for _,w in ipairs(h:GetChildren()) do if w:IsA("Weld") or w:IsA("WeldConstraint") or w:IsA("Motor6D") then if w.Name=="AccessoryWeld" then w:Destroy() end end end
 for _,ha in ipairs(h:GetChildren()) do if ha:IsA("Attachment") then local ra=rigAttach(c,a,ha.Name); if ra then
  local rp=ra.Parent; h.CFrame=rp.CFrame*ra.CFrame*ha.CFrame:Inverse(); local w=Instance.new("Weld"); w.Name="AccessoryWeld"; w.Part0=rp; w.Part1=h; w.C0=ra.CFrame; w.C1=ha.CFrame; w.Parent=h; return true
 end end end
 local hd=c:FindFirstChild("Head"); if hd then local ap=CFrame.new(); pcall(function() ap=a.AttachmentPoint end); local hp=CFrame.new(0,.5,0); h.CFrame=hd.CFrame*hp*ap:Inverse(); local w=Instance.new("Weld"); w.Name="AccessoryWeld"; w.Part0=hd; w.Part1=h; w.C0=hp; w.C1=ap; w.Parent=h; return true end
 return false
end
local function addAcc(c,h,a)
 local q=clone(a); if not q then return false end; q.Parent=nil
 local ok=pcall(function() h:AddAccessory(q) end)
 if ok and q.Parent==c then return true end
 if q.Parent then q.Parent=nil end
 if manualAcc(c,q) then return true end; q:Destroy(); return false
end
local function ids(s)
 local r,seen={},{}; for t in tostring(s):gmatch("[^,%s;]+") do local id=t:match("(%d+)"); if id and not seen[id] then seen[id]=true; table.insert(r,id) end end; return r
end
local function roots(id)
 local ok,r=pcall(function() return game:GetObjects("rbxassetid://"..id) end); if ok and type(r)=="table" and #r>0 then return r end
 local x; local ok2=pcall(function() x=IS:LoadAsset(tonumber(id)) end); return ok2 and x and {x} or {}
end
local function fromIds(txt,status)
 local o={shirt=nil,pants=nil,graphic=nil,acc={},failed={}}; local list=ids(txt)
 for i,id in ipairs(list) do if status then status(("Reading %d/%d: %s"):format(i,#list,id)) end; local found=false
  for _,root in ipairs(roots(id)) do
   local all={root}; for _,x in ipairs(root:GetDescendants()) do table.insert(all,x) end
   for _,x in ipairs(all) do
    if x:IsA("Shirt") then o.shirt=x.ShirtTemplate; found=true
    elseif x:IsA("Pants") then o.pants=x.PantsTemplate; found=true
    elseif x:IsA("ShirtGraphic") then o.graphic=x.Graphic; found=true
    elseif x:IsA("Accessory") or x:IsA("Hat") then local q=clone(x); if q then table.insert(o.acc,q); found=true end end
   end
   pcall(function() root:Destroy() end)
  end
  if not found then table.insert(o.failed,id) end
 end
 return o
end
local function merge(a,b)
 local o={shirt=a and a.shirt or "",pants=a and a.pants or "",graphic=a and a.graphic or "",acc={}}
 if a then for _,x in ipairs(a.acc or {}) do local q=clone(x); if q then table.insert(o.acc,q) end end end
 if b then if b.shirt~=nil then o.shirt=b.shirt end; if b.pants~=nil then o.pants=b.pants end; if b.graphic~=nil then o.graphic=b.graphic end
  if #b.acc>0 then o.acc={}; for _,x in ipairs(b.acc) do local q=clone(x); if q then table.insert(o.acc,q) end end end
 end
 return o
end
local function build(out,status)
 local c,h=char(); local old=c:FindFirstChild("R63VisualMorph"); if old then old:Destroy() end; clearCos(c); hideRig(c); head(c)
 local f=Instance.new("Folder"); f.Name="R63VisualMorph"; f.Parent=c
 for _,n in ipairs(ORDER) do local src=c:FindFirstChild(n); if not src then error("R63: missing "..n) end; local uri=mesh(BODY[n]); visual(f,src,n,uri,"",1,"Body")
  if PANTS[n] and out.pants~="" then visual(f,src,n,uri,out.pants,1.0025,"Pants") end
  if SHIRT[n] and out.shirt~="" then visual(f,src,n,uri,out.shirt,1.005,"Shirt") end
 end
 if out.graphic~="" then local g=Instance.new("ShirtGraphic"); g.Graphic=out.graphic; g.Parent=c end
 local n=0; for _,a in ipairs(out.acc or {}) do if addAcc(c,h,a) then n=n+1 end end
 active=true; recolor(c); if status then status("R63 rebuilt. Accessories: "..n) end
end
local function apply(txt,status)
 local c=char(); if not active or not saved then saved=snapshot(c) end
 local p=nil; if tostring(txt):match("%d") then lastIds=txt; p=fromIds(txt,status) else lastIds="" end
 build(merge(saved,p),status); if p and #p.failed>0 and status then status("Applied; unresolved IDs: "..table.concat(p.failed,", ")) end
end
local function reset(status)
 local c=P.Character; if not c then return end; local f=c:FindFirstChild("R63VisualMorph"); if f then f:Destroy() end; clearCos(c); restoreRig(c); restoreHead(c)
 if saved then if saved.shirt~="" then local s=Instance.new("Shirt"); s.ShirtTemplate=saved.shirt; s.Parent=c end; if saved.pants~="" then local p=Instance.new("Pants"); p.PantsTemplate=saved.pants; p.Parent=c end; if saved.graphic~="" then local g=Instance.new("ShirtGraphic"); g.Graphic=saved.graphic; g.Parent=c end
  local h=c:FindFirstChildOfClass("Humanoid"); if h then for _,a in ipairs(saved.acc or {}) do addAcc(c,h,a) end end
 end
 active=false; if status then status("Original visuals restored") end
end
-- GUI
if getgenv and getgenv().R63_GUI_OBJECT then pcall(function() getgenv().R63_GUI_OBJECT:Destroy() end) end
local gui=Instance.new("ScreenGui"); gui.Name="R63 GUI"; gui.ResetOnSpawn=false; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
local ok=false; if gethui then ok=pcall(function() gui.Parent=gethui() end) end; if not ok or not gui.Parent then pcall(function() gui.Parent=CG end) end; if not gui.Parent then gui.Parent=P:WaitForChild("PlayerGui") end
if getgenv then getgenv().R63_GUI_OBJECT=gui end
local main=Instance.new("Frame"); main.AnchorPoint=Vector2.new(.5,.5); main.Position=UDim2.fromScale(.5,.5); main.Size=UDim2.fromOffset(340,458); main.BackgroundColor3=Color3.fromRGB(24,24,29); main.BorderSizePixel=0; main.Parent=gui; Instance.new("UICorner",main).CornerRadius=UDim.new(0,11)
local sc=Instance.new("UIScale",main); local function size() local cam=workspace.CurrentCamera; if not cam then sc.Scale=1 return end; local v=cam.ViewportSize; sc.Scale=math.clamp(math.min(1,(v.X-18)/340,(v.Y-28)/458),.68,1) end; size(); if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(size) end
local top=Instance.new("Frame"); top.Size=UDim2.new(1,0,0,36); top.BackgroundTransparency=1; top.Parent=main
local title=Instance.new("TextLabel"); title.Size=UDim2.new(1,-44,1,0); title.Position=UDim2.fromOffset(12,0); title.BackgroundTransparency=1; title.Text="R63 GUI v5.1"; title.TextColor3=Color3.new(1,1,1); title.TextXAlignment=Enum.TextXAlignment.Left; title.Font=Enum.Font.GothamBold; title.TextSize=17; title.Parent=top
local close=Instance.new("TextButton"); close.Size=UDim2.fromOffset(28,28); close.Position=UDim2.new(1,-34,0,4); close.Text="×"; close.TextSize=18; close.TextColor3=Color3.new(1,1,1); close.BackgroundColor3=Color3.fromRGB(49,49,58); close.Parent=top; Instance.new("UICorner",close).CornerRadius=UDim.new(0,7); close.MouseButton1Click:Connect(function() gui:Destroy() end)
local box=Instance.new("TextBox"); box.Size=UDim2.new(1,-24,0,46); box.Position=UDim2.fromOffset(12,44); box.BackgroundColor3=Color3.fromRGB(35,35,42); box.TextColor3=Color3.new(1,1,1); box.PlaceholderText="IDs, comma-separated; empty = current outfit"; box.PlaceholderColor3=Color3.fromRGB(130,130,140); box.Text=""; box.ClearTextOnFocus=false; box.MultiLine=true; box.TextWrapped=true; box.Font=Enum.Font.Code; box.TextSize=11; box.Parent=main; Instance.new("UICorner",box).CornerRadius=UDim.new(0,7)
local pad=Instance.new("UIPadding",box); pad.PaddingLeft=UDim.new(0,7); pad.PaddingRight=UDim.new(0,7); pad.PaddingTop=UDim.new(0,5)
local lab=Instance.new("TextLabel"); lab.Position=UDim2.fromOffset(12,98); lab.Size=UDim2.fromOffset(140,18); lab.BackgroundTransparency=1; lab.Text="Skin color"; lab.TextColor3=Color3.fromRGB(210,210,220); lab.TextXAlignment=Enum.TextXAlignment.Left; lab.Font=Enum.Font.Gotham; lab.TextSize=12; lab.Parent=main
local wheel=Instance.new("Frame"); wheel.Position=UDim2.fromOffset(12,118); wheel.Size=UDim2.fromOffset(106,106); wheel.BackgroundTransparency=1; wheel.Parent=main
local dots={}; local center=Vector2.new(53,53)
for ring=1,5 do local s=ring/5; local r=9+ring*8; for step=0,23 do local h=step/24; local a=h*math.pi*2-math.pi/2; local b=Instance.new("TextButton"); b.Size=UDim2.fromOffset(9,9); b.Position=UDim2.fromOffset(center.X+math.cos(a)*r-4.5,center.Y+math.sin(a)*r-4.5); b.BackgroundColor3=Color3.fromHSV(h,s,val); b.Text=""; b.BorderSizePixel=0; b.Parent=wheel; Instance.new("UICorner",b).CornerRadius=UDim.new(1,0); table.insert(dots,{b,h,s}); b.MouseButton1Click:Connect(function() hue,sat=h,s; recolor(P.Character) end) end end
local white=Instance.new("TextButton"); white.Size=UDim2.fromOffset(16,16); white.Position=UDim2.fromOffset(45,45); white.Text=""; white.BackgroundColor3=Color3.fromHSV(0,0,val); white.BorderSizePixel=0; white.Parent=wheel; Instance.new("UICorner",white).CornerRadius=UDim.new(1,0); white.MouseButton1Click:Connect(function() sat=0; recolor(P.Character) end)
local preview=Instance.new("Frame"); preview.Position=UDim2.fromOffset(132,120); preview.Size=UDim2.fromOffset(28,28); preview.BackgroundColor3=skin(); preview.Parent=main; Instance.new("UICorner",preview).CornerRadius=UDim.new(1,0)
local function small(txt,x,y,w) local b=Instance.new("TextButton"); b.Position=UDim2.fromOffset(x,y); b.Size=UDim2.fromOffset(w,30); b.Text=txt; b.TextColor3=Color3.new(1,1,1); b.TextSize=11; b.Font=Enum.Font.GothamSemibold; b.BackgroundColor3=Color3.fromRGB(49,49,58); b.Parent=main; Instance.new("UICorner",b).CornerRadius=UDim.new(0,7); return b end
local dark=small("Darker",132,158,76); local light=small("Lighter",216,158,76)
local function colorUI() preview.BackgroundColor3=skin(); for _,d in ipairs(dots) do d[1].BackgroundColor3=Color3.fromHSV(d[2],d[3],val) end; white.BackgroundColor3=Color3.fromHSV(0,0,val); recolor(P.Character) end
dark.MouseButton1Click:Connect(function() val=math.clamp(val-.08,.16,1); colorUI() end); light.MouseButton1Click:Connect(function() val=math.clamp(val+.08,.16,1); colorUI() end)
local hm={}; local function hmb(mode,x,w) local b=small(mode,x,198,w); hm[mode]=b; b.MouseButton1Click:Connect(function() headMode=mode; for m,z in pairs(hm) do z.BackgroundColor3=m==headMode and Color3.fromRGB(78,78,94) or Color3.fromRGB(49,49,58) end; if P.Character then head(P.Character) end end); return b end
hmb("Normal",132,52); hmb("Faceless",188,62); hmb("Invisible",254,68)
local function big(txt,x,y,w) local b=small(txt,x,y,w); b.Size=UDim2.fromOffset(w,34); b.TextSize=12; return b end
local applyB=big("Rebuild morph",12,238,316); local currentB=big("Use current outfit",12,280,152); local idsB=big("Use IDs + fallback",176,280,152); local resetB=big("Reset original",12,322,152); local autoB=big("Auto respawn: OFF",176,322,152)
local stat=Instance.new("TextLabel"); stat.Position=UDim2.fromOffset(12,366); stat.Size=UDim2.new(1,-24,0,78); stat.BackgroundTransparency=1; stat.Text="Ready. Clothing textures are mapped directly onto the custom mesh UVs."; stat.TextColor3=Color3.fromRGB(165,165,180); stat.TextWrapped=true; stat.TextXAlignment=Enum.TextXAlignment.Left; stat.TextYAlignment=Enum.TextYAlignment.Top; stat.Font=Enum.Font.Gotham; stat.TextSize=11; stat.Parent=main
local function status(s) stat.Text=tostring(s) end; local busy=false; local function run(f) if busy then return end; busy=true; task.spawn(function() local ok,e=pcall(f); if not ok then status("Error: "..tostring(e)) end; busy=false end) end
applyB.MouseButton1Click:Connect(function() run(function() apply(box.Text,status) end) end); currentB.MouseButton1Click:Connect(function() run(function() box.Text=""; apply("",status) end) end); idsB.MouseButton1Click:Connect(function() run(function() apply(box.Text,status) end) end); resetB.MouseButton1Click:Connect(function() run(function() reset(status) end) end); autoB.MouseButton1Click:Connect(function() auto=not auto; autoB.Text="Auto respawn: "..(auto and "ON" or "OFF") end)
P.CharacterAdded:Connect(function() active=false; saved=nil; if auto then task.wait(1.1); run(function() apply(lastIds,status) end) end end)
-- drag title bar; initial spawn remains exact center
local dragging,startPos,startMouse=false,nil,nil
top.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=true; startMouse=i.Position; startPos=main.Position end end)
top.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end end)
UIS.InputChanged:Connect(function(i) if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then local d=i.Position-startMouse; main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y) end end)
colorUI()
