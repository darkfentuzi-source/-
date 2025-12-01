-- Delta HUD v3 Full (UPDATED) + FOV Manager (single-file)
-- Features: HUD, ESP, AIM (prediction, nearest-point), FOV visualizer (AIM/ESP circles),
-- All functionality lives in one script for injector (Xeno). Use at your own risk.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = Workspace.CurrentCamera

-- Save original lighting for restore
local originalLighting = {
    ClockTime = Lighting.ClockTime,
    Brightness = Lighting.Brightness,
    GlobalShadows = Lighting.GlobalShadows,
    FogEnd = Lighting.FogEnd,
    FogStart = Lighting.FogStart,
}

-- SETTINGS (extended with FOV/visual manager)
local Settings = {
    HUDVisible = true,

    -- ESP
    ESPEnabled = false,
    ESPShowPlayers = true,
    ESPShowBots = true,
    ESPRange = 250,
    ESPUpdateRate = 0.28,
    ESPNameSize = 14,
    ESPVisibleColor = Color3.fromRGB(0,255,0),
    ESPHiddenColor = Color3.fromRGB(255,64,64),
    ESPNameColor = Color3.fromRGB(255,255,255),
    ESPBodyHighlight = true,
    ESPBillboardHeight = 2.6,
    ESPFOV = 360, -- degrees for ESP circle

    -- AIM
    AimEnabled = false,
    AimPlayers = true,
    AimBots = true,
    AimRange = 200,
    AimFOV = 90,
    AimSmoothness = 0.25,
    AimRequireLOF = true,
    AimTargetBone = "Head",
    AimSearchRate = 0.12,
    AimWhileHold = true,

    -- Prediction
    PredictionEnabled = true,
    PredictionSampleDelay = 0.1,
    PredictionTime = 0.12,
    PredictionMultiplier = 1.0,

    -- FOV Visuals
    FOVCircleEnabled = true,
    AIMCircleEnabled = true,
    ESPCircleEnabled = false,
    AIMCircleColor = Color3.fromRGB(255,255,255),
    ESPCircleColor = Color3.fromRGB(0,170,255),
    FOVStyle = "Outline", -- Outline / Glow / Filled
    FOVMaxPixels = 800, -- clamp size

    -- Day/Night
    ForceDay = false,
}

-- Internal pools and caches
local ESPPool = {}
local lastESPUpdate = 0
local lastAimSearch = 0
local currentTargetPart = nil
local currentTargetModel = nil
local aiming = false
local predictionCache = {}

-- MAIN SCREEN GUI (one root)
local screenGui = Instance.new("ScreenGui")
screenGui.ResetOnSpawn = false
screenGui.Name = "DeltaHUD_v3"
screenGui.Parent = PlayerGui

-- MAIN FRAME
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 420, 0, 340)
mainFrame.Position = UDim2.new(0.5, -210, 0.5, -170)
mainFrame.BackgroundColor3 = Color3.fromRGB(22,22,22)
mainFrame.BorderSizePixel = 1
mainFrame.Parent = screenGui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,0,0,34)
title.Position = UDim2.new(0,0,0,0)
title.BackgroundColor3 = Color3.fromRGB(35,35,35)
title.Text = "Delta HUD v3"
title.TextColor3 = Color3.fromRGB(255,255,255)
title.Font = Enum.Font.GothamBold
title.Parent = mainFrame

-- Dragging support
local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
local function updateDrag(input)
    local delta = input.Position - dragStart
    mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true; dragStart = input.Position; startPos = mainFrame.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
    end
end)

title.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end end)
UserInputService.InputChanged:Connect(function(input) if dragging and input == dragInput then updateDrag(input) end end)

-- UI HELPERS
local function makeButton(parent, posY, txt)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -20, 0, 30); b.Position = UDim2.new(0, 10, 0, posY)
    b.BackgroundColor3 = Color3.fromRGB(60,60,60); b.Text = txt; b.TextColor3 = Color3.fromRGB(255,255,255); b.Parent = parent
    return b
end
local function makeLabel(parent, posY, txt)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0.58, -20, 0, 20); l.Position = UDim2.new(0,10,0,posY); l.BackgroundTransparency = 1
    l.Text = txt; l.TextColor3 = Color3.fromRGB(220,220,220); l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = parent
    return l
end
local function makeToggle(parent, posY, default)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 70, 0, 24); btn.Position = UDim2.new(1, -90, 0, posY)
    btn.Text = default and "ON" or "OFF"; btn.BackgroundColor3 = default and Color3.fromRGB(0,150,0) or Color3.fromRGB(150,0,0)
    btn.TextColor3 = Color3.fromRGB(255,255,255); btn.Parent = parent; return btn
end
local function makeTextBox(parent, posY, default)
    local tb = Instance.new("TextBox")
    tb.Size = UDim2.new(0, 110, 0, 24); tb.Position = UDim2.new(1, -220, 0, posY); tb.Text = tostring(default); tb.ClearTextOnFocus = false; tb.Parent = parent
    return tb
end

-- Main navigation buttons
local aimBtn = makeButton(mainFrame, 44, "AIMBOT Settings")
local espBtn = makeButton(mainFrame, 84, "ESP Settings")
local fovBtn = makeButton(mainFrame, 124, "FOV Manager")
local dayBtn = makeButton(mainFrame, 300, "Toggle Day/Night")

-- Subframes (single visible at a time)
local function makeSubFrame(titleText)
    local f = Instance.new("Frame"); f.Size = UDim2.new(0, 380, 0, 240); f.Position = UDim2.new(0.5, -190, 0.5, -110); f.BackgroundColor3 = Color3.fromRGB(18,18,18); f.Parent = screenGui; f.Visible = false
    local t = Instance.new("TextLabel", f); t.Size = UDim2.new(1,0,0,28); t.BackgroundColor3 = Color3.fromRGB(30,30,30); t.Text = titleText; t.TextColor3 = Color3.fromRGB(255,255,255)
    return f
end
local aimFrame = makeSubFrame("AIMBOT Settings")
local espFrame = makeSubFrame("ESP Settings")
local fovFrame = makeSubFrame("FOV Manager")

-- AIM TAB
local y = 36
makeLabel(aimFrame, y, "Enable Aim"); local aimToggle = makeToggle(aimFrame, y, Settings.AimEnabled); y = y + 28
makeLabel(aimFrame, y, "Aim Players"); local aimPlayersToggle = makeToggle(aimFrame, y, Settings.AimPlayers); y = y + 28
makeLabel(aimFrame, y, "Aim Bots"); local aimBotsToggle = makeToggle(aimFrame, y, Settings.AimBots); y = y + 28
makeLabel(aimFrame, y, "Aim Range"); local aimRangeBox = makeTextBox(aimFrame, y, Settings.AimRange); y = y + 28
makeLabel(aimFrame, y, "Aim FOV"); local aimFOVBox = makeTextBox(aimFrame, y, Settings.AimFOV); y = y + 28
makeLabel(aimFrame, y, "Smoothness"); local aimSmoothBox = makeTextBox(aimFrame, y, Settings.AimSmoothness); y = y + 28
makeLabel(aimFrame, y, "Prediction Time (s)"); local predTimeBox = makeTextBox(aimFrame, y, Settings.PredictionTime); y = y + 28
makeLabel(aimFrame, y, "Prediction Enabled"); local predToggle = makeToggle(aimFrame, y, Settings.PredictionEnabled); y = y + 28
makeLabel(aimFrame, y, "Target Bone"); local boneBtn = Instance.new("TextButton"); boneBtn.Size = UDim2.new(0,130,0,24); boneBtn.Position = UDim2.new(1,-160,0,y); boneBtn.Text = Settings.AimTargetBone; boneBtn.Parent = aimFrame
local boneOptions = {"Head","Neck","Torso","UpperTorso","HumanoidRootPart","LeftHand","RightHand","LeftFoot","RightFoot","Random"}
local boneIndex = 1 for i,v in ipairs(boneOptions) do if v == Settings.AimTargetBone then boneIndex = i break end end
boneBtn.MouseButton1Click:Connect(function() boneIndex = boneIndex % #boneOptions + 1; Settings.AimTargetBone = boneOptions[boneIndex]; boneBtn.Text = Settings.AimTargetBone end)

-- ESP TAB
y = 36
makeLabel(espFrame, y, "Enable ESP"); local espToggle = makeToggle(espFrame, y, Settings.ESPEnabled); y = y + 28
makeLabel(espFrame, y, "Show Players"); local espPlayersToggle = makeToggle(espFrame, y, Settings.ESPShowPlayers); y = y + 28
makeLabel(espFrame, y, "Show Bots"); local espBotsToggle = makeToggle(espFrame, y, Settings.ESPShowBots); y = y + 28
makeLabel(espFrame, y, "ESP Range"); local espRangeBox = makeTextBox(espFrame, y, Settings.ESPRange); y = y + 28
makeLabel(espFrame, y, "Name Size"); local espNameSizeBox = makeTextBox(espFrame, y, Settings.ESPNameSize); y = y + 28
makeLabel(espFrame, y, "Billboard Height (studs)"); local espBillBox = makeTextBox(espFrame, y, Settings.ESPBillboardHeight); y = y + 36
makeLabel(espFrame, y, "ESP FOV (deg)"); local espFOVBox = makeTextBox(espFrame, y, Settings.ESPFOV); y = y + 28

-- FOV TAB (manager)
y = 36
makeLabel(fovFrame, y, "Enable FOV Circle"); local fovToggle = makeToggle(fovFrame, y, Settings.FOVCircleEnabled); y = y + 28
makeLabel(fovFrame, y, "Show AIM Circle"); local aimCircleToggle = makeToggle(fovFrame, y, Settings.AIMCircleEnabled); y = y + 28
makeLabel(fovFrame, y, "Show ESP Circle"); local espCircleToggle = makeToggle(fovFrame, y, Settings.ESPCircleEnabled); y = y + 28
makeLabel(fovFrame, y, "AIM Circle Color (R,G,B)"); local aimColorBox = makeTextBox(fovFrame, y, "255, 255, 255"); y = y + 28
makeLabel(fovFrame, y, "ESP Circle Color (R,G,B)"); local espColorBox = makeTextBox(fovFrame, y, "0, 170, 255"); y = y + 28
makeLabel(fovFrame, y, "FOV Sync: (AIM/ESP/Off)"); local fovSyncBox = makeTextBox(fovFrame, y, "AIM"); y = y + 28
makeLabel(fovFrame, y, "FOV Style (Outline/Glow/Filled)"); local fovStyleBox = makeTextBox(fovFrame, y, Settings.FOVStyle); y = y + 28
makeLabel(fovFrame, y, "Max Pixel Radius"); local fovMaxBox = makeTextBox(fovFrame, y, Settings.FOVMaxPixels); y = y + 28

-- Hook navigation buttons
aimBtn.MouseButton1Click:Connect(function() aimFrame.Visible = not aimFrame.Visible; espFrame.Visible = false; fovFrame.Visible = false end)
espBtn.MouseButton1Click:Connect(function() espFrame.Visible = not espFrame.Visible; aimFrame.Visible = false; fovFrame.Visible = false end)
fovBtn.MouseButton1Click:Connect(function() fovFrame.Visible = not fovFrame.Visible; aimFrame.Visible = false; espFrame.Visible = false end)

-- Day/Night toggle
dayBtn.MouseButton1Click:Connect(function()
    Settings.ForceDay = not Settings.ForceDay
    if Settings.ForceDay then
        Lighting.ClockTime = 14; Lighting.GlobalShadows = true; Lighting.Brightness = 2
    else
        Lighting.ClockTime = originalLighting.ClockTime; Lighting.GlobalShadows = originalLighting.GlobalShadows; Lighting.Brightness = originalLighting.Brightness
    end
end)

-- Toggle logic helper
local function toggleBehavior(btn, setter)
    btn.MouseButton1Click:Connect(function()
        local on = (btn.Text == "ON")
        if on then btn.Text = "OFF"; btn.BackgroundColor3 = Color3.fromRGB(150,0,0); setter(false)
        else btn.Text = "ON"; btn.BackgroundColor3 = Color3.fromRGB(0,150,0); setter(true) end
    end)
end

toggleBehavior(aimToggle, function(v) Settings.AimEnabled = v end)
toggleBehavior(aimPlayersToggle, function(v) Settings.AimPlayers = v end)
toggleBehavior(aimBotsToggle, function(v) Settings.AimBots = v end)
toggleBehavior(espToggle, function(v) Settings.ESPEnabled = v end)
toggleBehavior(espPlayersToggle, function(v) Settings.ESPShowPlayers = v end)
toggleBehavior(espBotsToggle, function(v) Settings.ESPShowBots = v end)
toggleBehavior(fovToggle, function(v) Settings.FOVCircleEnabled = v end)
toggleBehavior(aimCircleToggle, function(v) Settings.AIMCircleEnabled = v end)
toggleBehavior(espCircleToggle, function(v) Settings.ESPCircleEnabled = v end)
toggleBehavior(predToggle, function(v) Settings.PredictionEnabled = v end)

-- Textbox commit handlers
aimRangeBox.FocusLost:Connect(function() local n = tonumber(aimRangeBox.Text); if n then Settings.AimRange = math.max(0,n) end; aimRangeBox.Text = tostring(Settings.AimRange) end)
aimFOVBox.FocusLost:Connect(function() local n = tonumber(aimFOVBox.Text); if n then Settings.AimFOV = math.clamp(n,1,360) end; aimFOVBox.Text = tostring(Settings.AimFOV) end)
aimSmoothBox.FocusLost:Connect(function() local n = tonumber(aimSmoothBox.Text); if n then Settings.AimSmoothness = math.clamp(n,0,1) end; aimSmoothBox.Text = tostring(Settings.AimSmoothness) end)
predTimeBox.FocusLost:Connect(function() local n = tonumber(predTimeBox.Text); if n then Settings.PredictionTime = math.max(0,n) end; predTimeBox.Text = tostring(Settings.PredictionTime) end)

espRangeBox.FocusLost:Connect(function() local n = tonumber(espRangeBox.Text); if n then Settings.ESPRange = math.max(0,n) end; espRangeBox.Text = tostring(Settings.ESPRange) end)
espNameSizeBox.FocusLost:Connect(function() local n = tonumber(espNameSizeBox.Text); if n then Settings.ESPNameSize = math.max(8,n) end; espNameSizeBox.Text = tostring(Settings.ESPNameSize) end)
espBillBox.FocusLost:Connect(function() local n = tonumber(espBillBox.Text); if n then Settings.ESPBillboardHeight = math.max(0,n) end; espBillBox.Text = tostring(Settings.ESPBillboardHeight) end)
espFOVBox.FocusLost:Connect(function() local n = tonumber(espFOVBox.Text); if n then Settings.ESPFOV = math.clamp(n,1,360) end; espFOVBox.Text = tostring(Settings.ESPFOV) end)

aimColorBox.FocusLost:Connect(function() local s = aimColorBox.Text; local r,g,b = s:match("(%d+),%s*(%d+),%s*(%d+)"); if r then Settings.AIMCircleColor = Color3.fromRGB(tonumber(r),tonumber(g),tonumber(b)) end; aimColorBox.Text = s end)
espColorBox.FocusLost:Connect(function() local s = espColorBox.Text; local r,g,b = s:match("(%d+),%s*(%d+),%s*(%d+)"); if r then Settings.ESPCircleColor = Color3.fromRGB(tonumber(r),tonumber(g),tonumber(b)) end; espColorBox.Text = s end)

fovSyncBox.FocusLost:Connect(function() local s = fovSyncBox.Text; s = tostring(s):upper(); if s == "AIM" or s == "ESP" or s == "OFF" then fovSyncBox.Text = s; else fovSyncBox.Text = "AIM" end end)
fovStyleBox.FocusLost:Connect(function() local s = fovStyleBox.Text; if s == "Outline" or s == "Glow" or s == "Filled" then Settings.FOVStyle = s else fovStyleBox.Text = Settings.FOVStyle end end)
fovMaxBox.FocusLost:Connect(function() local n = tonumber(fovMaxBox.Text); if n then Settings.FOVMaxPixels = math.max(50, math.floor(n)) end; fovMaxBox.Text = tostring(Settings.FOVMaxPixels) end)

-- HUD toggle
UserInputService.InputBegan:Connect(function(inp,gp) if gp then return end if inp.KeyCode == Enum.KeyCode.RightShift then Settings.HUDVisible = not Settings.HUDVisible; screenGui.Enabled = Settings.HUDVisible end end)
screenGui.Enabled = Settings.HUDVisible

-- UTIL functions (playerFromModel, resolveBone, isVisible, closestPointOnPart)
local function playerFromModel(model) return Players:GetPlayerFromCharacter(model) end
local function resolveBone(model, boneName)
    if not model then return nil end
    if boneName == "Random" then local pool = {"Head","Neck","UpperTorso","LowerTorso","HumanoidRootPart","LeftHand","RightHand","LeftFoot","RightFoot"}; boneName = pool[math.random(1,#pool)] end
    local priority = { Head={"Head"}, Neck={"Neck","UpperTorso","Torso","HumanoidRootPart"}, Torso={"Torso","UpperTorso","HumanoidRootPart"}, UpperTorso={"UpperTorso","Torso","HumanoidRootPart"}, HumanoidRootPart={"HumanoidRootPart","LowerTorso","Torso"}, LeftHand={"LeftHand","LeftArm"}, RightHand={"RightHand","RightArm"}, LeftFoot={"LeftFoot","LeftLeg"}, RightFoot={"RightFoot","RightLeg"} }
    local candidates = priority[boneName] or {boneName}
    for _,n in ipairs(candidates) do local found = model:FindFirstChild(n, true); if found and found:IsA("BasePart") then return found end end
    return model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head")
end
local function isVisible(part)
    if not part then return false end
    local origin = Camera.CFrame.Position
    local dir = (part.Position - origin)
    local rayParams = RaycastParams.new(); rayParams.FilterDescendantsInstances = {LocalPlayer.Character}; rayParams.FilterType = Enum.RaycastFilterType.Blacklist; rayParams.IgnoreWater = true
    local ray = Workspace:Raycast(origin, dir, rayParams)
    if not ray then return true end
    if ray.Instance and ray.Instance:IsDescendantOf(part.Parent) then return true end
    return false
end
local function closestPointOnPart(part, worldPoint)
    if not part or not part:IsA("BasePart") then return part and part.Position or nil end
    local relative = part.CFrame:PointToObjectSpace(worldPoint)
    local half = part.Size * 0.5
    local clamped = Vector3.new(math.clamp(relative.X, -half.X, half.X), math.clamp(relative.Y, -half.Y, half.Y), math.clamp(relative.Z, -half.Z, half.Z))
    return part.CFrame:PointToWorldSpace(clamped)
end

-- Create / update ESP functions (reuse existing logic)
local function createOrUpdateESP(model, displayName, dist)
    if not model then return end
    local pool = ESPPool[model]
    if not pool then
        pool = {}
        local highlight = Instance.new("Highlight"); highlight.Adornee = model; highlight.FillTransparency = 0.7; highlight.OutlineTransparency = 0; highlight.Parent = workspace; pool.highlight = highlight
        local bg = Instance.new("BillboardGui"); bg.Name = "DeltaESP_Billboard"; bg.Adornee = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("UpperTorso") or model:FindFirstChild("Head"); bg.Size = UDim2.new(0,140,0,40); bg.AlwaysOnTop = true; bg.LightInfluence = 0; bg.Parent = screenGui
        local label = Instance.new("TextLabel"); label.Size = UDim2.new(1,0,1,0); label.BackgroundTransparency = 0.3; label.BackgroundColor3 = Settings.ESPVisibleColor; label.TextColor3 = Settings.ESPNameColor; label.TextScaled = false; label.Font = Enum.Font.Gotham; label.Parent = bg
        pool.billboard = bg; pool.label = label; ESPPool[model] = pool
    end
    pool.billboard.Adornee = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("UpperTorso") or model:FindFirstChild("Head")
    pool.label.Text = displayName; pool.label.TextSize = Settings.ESPNameSize
    pool.billboard.StudsOffset = Vector3.new(0, Settings.ESPBillboardHeight, 0)
    local targetPart = pool.billboard.Adornee; local vis = isVisible(targetPart)
    if vis then pool.label.BackgroundColor3 = Settings.ESPVisibleColor; if pool.highlight then pool.highlight.FillColor = Settings.ESPVisibleColor; pool.highlight.OutlineColor = Settings.ESPVisibleColor; pool.highlight.Enabled = Settings.ESPBodyHighlight end
    else pool.label.BackgroundColor3 = Settings.ESPHiddenColor; if pool.highlight then pool.highlight.FillColor = Settings.ESPHiddenColor; pool.highlight.OutlineColor = Settings.ESPHiddenColor; pool.highlight.Enabled = Settings.ESPBodyHighlight end end
end
local function removeESP(model) if not model then return end local pool = ESPPool[model]; if not pool then return end if pool.highlight and pool.highlight.Parent then pool.highlight:Destroy() end if pool.billboard and pool.billboard.Parent then pool.billboard:Destroy() end ESPPool[model] = nil end

-- ESP scan (optimized)
spawn(function()
    while true do
        if Settings.ESPEnabled and LocalPlayer.Character and LocalPlayer.Character.PrimaryPart then
            local myPos = LocalPlayer.Character.PrimaryPart.Position
            if Settings.ESPShowPlayers then
                for _,pl in ipairs(Players:GetPlayers()) do
                    if pl ~= LocalPlayer and pl.Character and pl.Character.PrimaryPart then
                        local dist = (pl.Character.PrimaryPart.Position - myPos).Magnitude
                        if dist <= Settings.ESPRange then createOrUpdateESP(pl.Character, pl.Name .. "\n" .. math.floor(dist) .. "m", dist) else removeESP(pl.Character) end
                    end
                end
            else
                for m,p in pairs(ESPPool) do if playerFromModel(m) then removeESP(m) end end
            end
            if Settings.ESPShowBots then
                for _,obj in ipairs(Workspace:GetDescendants()) do
                    if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") and not playerFromModel(obj) then
                        local root = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Head")
                        if root then local dist = (root.Position - myPos).Magnitude; if dist <= Settings.ESPRange then createOrUpdateESP(obj, (obj.Name or "Bot") .. "\n" .. math.floor(dist) .. "m", dist) else removeESP(obj) end end
                    end
                end
            else
                for m,p in pairs(ESPPool) do if p and not playerFromModel(m) then removeESP(m) end end
            end
        else
            for m,p in pairs(ESPPool) do removeESP(m) end
        end
        wait(Settings.ESPUpdateRate)
    end
end)

-- Prediction cache updater
spawn(function()
    while true do
        local now = tick()
        for _,pl in ipairs(Players:GetPlayers()) do
            if pl.Character then local hrp = pl.Character:FindFirstChild("HumanoidRootPart"); if hrp then local ent = predictionCache[pl] or {}; if ent.pos then ent.prevPos = ent.pos; ent.prevT = ent.t end; ent.pos = hrp.Position; ent.t = now; predictionCache[pl] = ent end end
        end
        for _,obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") and not playerFromModel(obj) then local hrp = obj:FindFirstChild("HumanoidRootPart"); if hrp then local ent = predictionCache[obj] or {}; if ent.pos then ent.prevPos = ent.pos; ent.prevT = ent.t end; ent.pos = hrp.Position; ent.t = now; predictionCache[obj] = ent end end
        end
        wait(Settings.PredictionSampleDelay)
    end
end)

local function getPredictedPositionForModel(model, leadTime)
    if not model then return nil end
    local key = playerFromModel(model) or model
    local ent = predictionCache[key]
    if not ent or not ent.pos or not ent.prevPos or not ent.prevT or not ent.t then
        local hrp = model:FindFirstChild("HumanoidRootPart")
        if hrp then return hrp.Position end
        return (model:FindFirstChild("Head") and model.Head.Position) or model.PrimaryPart and model.PrimaryPart.Position
    end
    local dt = ent.t - ent.prevT; if dt <= 0 then dt = 0.0001 end
    local vel = (ent.pos - ent.prevPos) / dt
    local predicted = ent.pos + vel * (leadTime * Settings.PredictionMultiplier)
    return predicted
end

-- AIM target search
local function findBestTarget()
    if not LocalPlayer.Character or not LocalPlayer.Character.PrimaryPart then return nil end
    local origin = Camera.CFrame.Position
    local mousePos = UserInputService:GetMouseLocation()
    local bestPart, bestModel = nil, nil; local bestScore = math.huge
    local fovPixels = Settings.AimFOV * (Camera.ViewportSize.X/1200)
    local function evalCandidate(part, model)
        if not part then return end
        local dist = (part.Position - origin).Magnitude
        if dist > Settings.AimRange then return end
        local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
        if not onScreen then return end
        local ang = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
        if ang > fovPixels then return end
        if Settings.AimRequireLOF and not isVisible(part) then return end
        local score = dist + ang * 0.1
        if score < bestScore then bestScore = score; bestPart = part; bestModel = model end
    end
    if Settings.AimPlayers then for _,pl in ipairs(Players:GetPlayers()) do if pl ~= LocalPlayer and pl.Character and pl.Character.PrimaryPart then local bonePart = resolveBone(pl.Character, Settings.AimTargetBone); if bonePart then evalCandidate(bonePart, pl.Character) end end end end
    if Settings.AimBots then for _,obj in ipairs(Workspace:GetDescendants()) do if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") and not playerFromModel(obj) then local bonePart = resolveBone(obj, Settings.AimTargetBone); if bonePart then evalCandidate(bonePart, obj) end end end end
    return bestPart, bestModel
end

-- AIM controls
UserInputService.InputBegan:Connect(function(input,gp) if gp then return end if input.UserInputType == Enum.UserInputType.MouseButton2 then aiming = true end end)
UserInputService.InputEnded:Connect(function(input,gp) if gp then return end if input.UserInputType == Enum.UserInputType.MouseButton2 then aiming = false; currentTargetPart = nil; currentTargetModel = nil end end)

local function smoothLookAt(targetPos)
    if not Camera then return end
    local camPos = Camera.CFrame.Position
    local targetCFrame = CFrame.new(camPos, targetPos)
    Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, Settings.AimSmoothness)
end

local function computeAimPointOnPart(part, idealPoint) if not part then return nil end; return closestPointOnPart(part, idealPoint) end

-- FOV VISUALS: create circle UI(s)
local FOVGui = Instance.new("ScreenGui") FOVGui.Name = "DeltaHUD_FOV"; FOVGui.ResetOnSpawn = false; FOVGui.Parent = PlayerGui; FOVGui.Enabled = true

-- container for both circles
local FOVContainer = Instance.new("Frame"); FOVContainer.BackgroundTransparency = 1; FOVContainer.Size = UDim2.new(1,0,1,0); FOVContainer.Position = UDim2.new(0,0,0,0); FOVContainer.Parent = FOVGui

local function makeCircle(name, color)
    local frame = Instance.new("Frame"); frame.Name = name; frame.AnchorPoint = Vector2.new(0.5,0.5); frame.Size = UDim2.new(0,200,0,200); frame.Position = UDim2.new(0.5,0.5,0.5,0); frame.BackgroundTransparency = 1; frame.Parent = FOVContainer
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(1,0); corner.Parent = frame
    local stroke = Instance.new("UIStroke"); stroke.Thickness = 2; stroke.Color = color; stroke.Parent = frame
    return frame, stroke
end

local AIMCircle, AIMStroke = makeCircle("AIM_Circle", Settings.AIMCircleColor)
local ESPCircle, ESPStroke = makeCircle("ESP_Circle", Settings.ESPCircleColor)

-- Helpers to compute pixel radius from FOV degrees (simple approximation)
local function fovToPixelsDeg(fovDeg)
    -- map degrees to radius in pixels using viewport width heuristic; clamp to FOVMaxPixels
    local screenW = Camera and Camera.ViewportSize.X or 1920
    local base = screenW * 0.5
    local ratio = math.clamp(fovDeg / 180, 0, 1)
    local pixels = math.clamp(base * ratio, 20, Settings.FOVMaxPixels)
    return pixels
end

local function parseColorString(s, fallback)
    if not s then return fallback end
    local r,g,b = s:match("(%d+),%s*(%d+),%s*(%d+)")
    if r then return Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b)) end
    return fallback
end

-- update functions
local function updateAIMCircle()
    AIMStroke.Color = Settings.AIMCircleColor
    AIMCircle.Visible = Settings.FOVCircleEnabled and Settings.AIMCircleEnabled
    if Settings.FOVStyle == "Outline" then AIMStroke.Thickness = 2; AIMCircle.BackgroundTransparency = 1
    elseif Settings.FOVStyle == "Filled" then AIMStroke.Thickness = 1; AIMCircle.BackgroundTransparency = 0.9
    elseif Settings.FOVStyle == "Glow" then AIMStroke.Thickness = 4; AIMCircle.BackgroundTransparency = 1 end
    local fovDeg = (tostring(fovSyncBox and fovSyncBox.Text or "AIM") == "ESP") and Settings.ESPFOV or Settings.AimFOV
    local px = fovToPixelsDeg(fovDeg)
    AIMCircle.Size = UDim2.new(0, px, 0, px)
end
local function updateESPCircle()
    ESPStroke.Color = Settings.ESPCircleColor
    ESPCircle.Visible = Settings.FOVCircleEnabled and Settings.ESPCircleEnabled
    if Settings.FOVStyle == "Outline" then ESPStroke.Thickness = 2; ESPCircle.BackgroundTransparency = 1
    elseif Settings.FOVStyle == "Filled" then ESPStroke.Thickness = 1; ESPCircle.BackgroundTransparency = 0.9
    elseif Settings.FOVStyle == "Glow" then ESPStroke.Thickness = 4; ESPCircle.BackgroundTransparency = 1 end
    local fovDeg = (tostring(fovSyncBox and fovSyncBox.Text or "AIM") == "AIM") and Settings.AimFOV or Settings.ESPFOV
    local px = fovToPixelsDeg(fovDeg)
    ESPCircle.Size = UDim2.new(0, px, 0, px)
end

-- Wire initial color values
AIMStroke.Color = Settings.AIMCircleColor
ESPStroke.Color = Settings.ESPCircleColor

-- Main RenderStepped loop: AIM behavior + FOV updates
RunService.RenderStepped:Connect(function()
    -- Update FOV circles live
    if Settings.FOVCircleEnabled then
        updateAIMCircle(); updateESPCircle()
    else
        AIMCircle.Visible = false; ESPCircle.Visible = false
    end

    -- AIM processing
    if Settings.AimEnabled and aiming then
        local now = tick()
        if now - lastAimSearch >= Settings.AimSearchRate then lastAimSearch = now; local p, model = findBestTarget(); currentTargetPart = p; currentTargetModel = model end
        if currentTargetPart then
            local aimPoint = currentTargetPart.Position
            if Settings.PredictionEnabled and currentTargetModel then
                local predictedHRP = getPredictedPositionForModel(currentTargetModel, Settings.PredictionTime)
                if predictedHRP and currentTargetModel:FindFirstChild("HumanoidRootPart") then
                    local curHRP = currentTargetModel:FindFirstChild("HumanoidRootPart")
                    if curHRP then local offset = currentTargetPart.Position - curHRP.Position; aimPoint = predictedHRP + offset else aimPoint = getPredictedPositionForModel(currentTargetModel, Settings.PredictionTime) end
                end
            end
            local correctedAim = computeAimPointOnPart(currentTargetPart, aimPoint) or aimPoint
            smoothLookAt(correctedAim)
        end
    else
        currentTargetPart = nil
    end
end)

-- Hook cleanup and player events
Players.PlayerRemoving:Connect(function(pl) if pl.Character then removeESP(pl.Character) end; predictionCache[pl] = nil end)
Players.PlayerAdded:Connect(function(pl) pl.CharacterRemoving:Connect(function() predictionCache[pl] = nil end) end)
LocalPlayer.AncestryChanged:Connect(function() if not LocalPlayer:IsDescendantOf(game) then for m,p in pairs(ESPPool) do removeESP(m) end; if screenGui and screenGui.Parent then screenGui:Destroy() end; if FOVGui and FOVGui.Parent then FOVGui:Destroy() end end end)

print("Delta HUD v3 (Full) with FOV Manager loaded.")