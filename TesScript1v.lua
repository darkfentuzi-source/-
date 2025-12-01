-- Delta HUD v3 Full (UPDATED)
-- Додано: підняття ніку над головою, nearest-point aiming, predictive aiming (AI-boost),
-- кращий вибір кістки, оптимізації для інжектора Xeno.

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

-- SETTINGS
local Settings = {
    HUDVisible = true,

    -- ESP
    ESPEnabled = false,
    ESPShowPlayers = true,
    ESPShowBots = true,
    ESPRange = 250,
    ESPUpdateRate = 0.28, -- seconds between scans (optimized)
    ESPNameSize = 14,
    ESPVisibleColor = Color3.fromRGB(0, 255, 0),
    ESPHiddenColor = Color3.fromRGB(255, 64, 64),
    ESPNameColor = Color3.fromRGB(255,255,255),
    ESPBodyHighlight = true,
    ESPBillboardHeight = 2.6, -- Висота над Adornee у студзах

    -- AIM
    AimEnabled = false,
    AimPlayers = true,
    AimBots = true,
    AimRange = 200,
    AimFOV = 90,
    AimSmoothness = 0.25,
    AimRequireLOF = true,
    AimTargetBone = "Head", -- options: Head, Torso, HumanoidRootPart, LeftHand, RightHand, LeftFoot, RightFoot, Neck, Random
    AimSearchRate = 0.12, -- seconds between target search
    AimWhileHold = true, -- require holding right mouse

    -- Prediction (AI-boost)
    PredictionEnabled = true,
    PredictionSampleDelay = 0.1, -- секунда між збереженням попередньої позиції (ваша ідея)
    PredictionTime = 0.12, -- на скільки секунд підсунути вперед (lead time)
    PredictionMultiplier = 1.0, -- інший варіант множника (для налаштувань)

    -- Day/Night
    ForceDay = false,
}

-- Internal pools
local ESPPool = {} -- character/model -> {highlight = Highlight, billboard = BillboardGui}
local lastESPUpdate = 0
local lastAimSearch = 0
local currentTargetPart = nil -- now part (BasePart) we aim at
local aiming = false

-- Prediction cache: model -> {pos = Vector3, t = time}
local predictionCache = {}

-- UI Creation (same as before, only minor changes: billboard height exposed)
local screenGui = Instance.new("ScreenGui")
screenGui.ResetOnSpawn = false
screenGui.Name = "DeltaHUD_v3"
screenGui.Parent = PlayerGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 360, 0, 300)
mainFrame.Position = UDim2.new(0.5, -180, 0.5, -150)
mainFrame.BackgroundColor3 = Color3.fromRGB(22,22,22)
mainFrame.BorderSizePixel = 1
mainFrame.Parent = screenGui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,0,0,30)
title.Position = UDim2.new(0,0,0,0)
title.BackgroundColor3 = Color3.fromRGB(35,35,35)
title.Text = "Delta HUD v3"
title.TextColor3 = Color3.fromRGB(255,255,255)
title.Font = Enum.Font.GothamBold
title.Parent = mainFrame

-- Drag support
local dragging = false
local dragInput, dragStart, startPos

local function updateDrag(input)
    local delta = input.Position - dragStart
    mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

title.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        updateDrag(input)
    end
end)

-- Quick UI helpers (same functions)
local function makeButton(parent, posY, txt)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -20, 0, 30)
    b.Position = UDim2.new(0, 10, 0, posY)
    b.BackgroundColor3 = Color3.fromRGB(60,60,60)
    b.Text = txt
    b.TextColor3 = Color3.fromRGB(255,255,255)
    b.Parent = parent
    return b
end

local function makeLabel(parent, posY, txt)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0.6, -20, 0, 20)
    l.Position = UDim2.new(0,10,0,posY)
    l.BackgroundTransparency = 1
    l.Text = txt
    l.TextColor3 = Color3.fromRGB(220,220,220)
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = parent
    return l
end

local function makeToggle(parent, posY, default)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 70, 0, 24)
    btn.Position = UDim2.new(1, -90, 0, posY)
    btn.Text = default and "ON" or "OFF"
    btn.BackgroundColor3 = default and Color3.fromRGB(0,150,0) or Color3.fromRGB(150,0,0)
    btn.TextColor3 = Color3.fromRGB(255,255,255)
    btn.Parent = parent
    return btn
end

local function makeTextBox(parent, posY, default)
    local tb = Instance.new("TextBox")
    tb.Size = UDim2.new(0, 90, 0, 24)
    tb.Position = UDim2.new(1, -200, 0, posY)
    tb.Text = tostring(default)
    tb.ClearTextOnFocus = false
    tb.Parent = parent
    return tb
end

-- Main buttons
local aimbotBtn = makeButton(mainFrame, 40, "AIMBOT Settings")
local espBtn = makeButton(mainFrame, 80, "ESP Settings")
local dayBtn = makeButton(mainFrame, 260, "Toggle Day/Night")

-- Subframes
local function makeSubFrame(titleText)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(0, 350, 0, 260)
    f.Position = UDim2.new(0.5, -175, 0.5, -130)
    f.BackgroundColor3 = Color3.fromRGB(18,18,18)
    f.Parent = screenGui
    f.Visible = false
    local t = Instance.new("TextLabel", f)
    t.Size = UDim2.new(1,0,0,28)
    t.BackgroundColor3 = Color3.fromRGB(30,30,30)
    t.Text = titleText
    t.TextColor3 = Color3.fromRGB(255,255,255)
    t.Parent = f
    return f
end

local aimFrame = makeSubFrame("AIMBOT Settings")
local espFrame = makeSubFrame("ESP Settings")

-- AIM UI elements
makeLabel(aimFrame, 36, "Enable Aim")
local aimToggle = makeToggle(aimFrame, 36, Settings.AimEnabled)

makeLabel(aimFrame, 64, "Aim Players")
local aimPlayersToggle = makeToggle(aimFrame, 64, Settings.AimPlayers)

makeLabel(aimFrame, 92, "Aim Bots")
local aimBotsToggle = makeToggle(aimFrame, 92, Settings.AimBots)

makeLabel(aimFrame, 120, "Aim Range")
local aimRangeBox = makeTextBox(aimFrame, 120, Settings.AimRange)

makeLabel(aimFrame, 148, "Aim FOV")
local aimFOVBox = makeTextBox(aimFrame, 148, Settings.AimFOV)

makeLabel(aimFrame, 176, "Smoothness")
local aimSmoothBox = makeTextBox(aimFrame, 176, Settings.AimSmoothness)

-- Prediction settings in UI
makeLabel(aimFrame, 204, "Prediction Time (s)")
local predTimeBox = makeTextBox(aimFrame, 204, Settings.PredictionTime)

makeLabel(aimFrame, 232, "Prediction Enabled")
local predToggle = makeToggle(aimFrame, 232, Settings.PredictionEnabled)

-- Aim target bone selector (cycle button)
makeLabel(aimFrame, 260, "Target Bone")
local boneBtn = Instance.new("TextButton")
boneBtn.Size = UDim2.new(0, 130, 0, 24)
boneBtn.Position = UDim2.new(1, -160, 0, 260)
boneBtn.Text = Settings.AimTargetBone
boneBtn.Parent = aimFrame

local boneOptions = {"Head","Neck","Torso","UpperTorso","HumanoidRootPart","LeftHand","RightHand","LeftFoot","RightFoot","Random"}
local boneIndex = 1
for i,v in ipairs(boneOptions) do if v == Settings.AimTargetBone then boneIndex = i break end end
boneBtn.MouseButton1Click:Connect(function()
    boneIndex = boneIndex % #boneOptions + 1
    Settings.AimTargetBone = boneOptions[boneIndex]
    boneBtn.Text = Settings.AimTargetBone
end)

-- ESP UI elements
makeLabel(espFrame, 36, "Enable ESP")
local espToggle = makeToggle(espFrame, 36, Settings.ESPEnabled)

makeLabel(espFrame, 64, "Show Players")
local espPlayersToggle = makeToggle(espFrame, 64, Settings.ESPShowPlayers)

makeLabel(espFrame, 92, "Show Bots")
local espBotsToggle = makeToggle(espFrame, 92, Settings.ESPShowBots)

makeLabel(espFrame, 120, "ESP Range")
local espRangeBox = makeTextBox(espFrame, 120, Settings.ESPRange)

makeLabel(espFrame, 148, "Name Size")
local espNameSizeBox = makeTextBox(espFrame, 148, Settings.ESPNameSize)

makeLabel(espFrame, 176, "Billboard Height (studs)")
local espBillBox = makeTextBox(espFrame, 176, Settings.ESPBillboardHeight)

-- Color presets for visible/hidden
makeLabel(espFrame, 204, "Visible Color (preset)")
local visColors = {Color3.fromRGB(0,255,0), Color3.fromRGB(0,170,255), Color3.fromRGB(255,200,0)}
for i,col in ipairs(visColors) do
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 24, 0, 24)
    b.Position = UDim2.new(0, 140 + (i-1)*28, 0, 204)
    b.BackgroundColor3 = col
    b.Parent = espFrame
    b.MouseButton1Click:Connect(function() Settings.ESPVisibleColor = col end)
end

makeLabel(espFrame, 236, "Hidden Color (preset)")
local hidColors = {Color3.fromRGB(255,64,64), Color3.fromRGB(255,0,255), Color3.fromRGB(255,255,255)}
for i,col in ipairs(hidColors) do
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 24, 0, 24)
    b.Position = UDim2.new(0, 140 + (i-1)*28, 0, 236)
    b.BackgroundColor3 = col
    b.Parent = espFrame
    b.MouseButton1Click:Connect(function() Settings.ESPHiddenColor = col end)
end

-- Hook main buttons
aimbotBtn.MouseButton1Click:Connect(function()
    aimFrame.Visible = not aimFrame.Visible
    espFrame.Visible = false
end)
espBtn.MouseButton1Click:Connect(function()
    espFrame.Visible = not espFrame.Visible
    aimFrame.Visible = false
end)

dayBtn.MouseButton1Click:Connect(function()
    Settings.ForceDay = not Settings.ForceDay
    if Settings.ForceDay then
        Lighting.ClockTime = 14
        Lighting.GlobalShadows = true
        Lighting.Brightness = 2
    else
        Lighting.ClockTime = originalLighting.ClockTime
        Lighting.GlobalShadows = originalLighting.GlobalShadows
        Lighting.Brightness = originalLighting.Brightness
    end
end)

-- Toggle button behavior
local function toggleBehavior(btn, setter)
    btn.MouseButton1Click:Connect(function()
        local on = (btn.Text == "ON")
        if on then
            btn.Text = "OFF"
            btn.BackgroundColor3 = Color3.fromRGB(150,0,0)
            setter(false)
        else
            btn.Text = "ON"
            btn.BackgroundColor3 = Color3.fromRGB(0,150,0)
            setter(true)
        end
    end)
end

toggleBehavior(aimToggle, function(v) Settings.AimEnabled = v end)
toggleBehavior(aimPlayersToggle, function(v) Settings.AimPlayers = v end)
toggleBehavior(aimBotsToggle, function(v) Settings.AimBots = v end)
toggleBehavior(espToggle, function(v) Settings.ESPEnabled = v end)
toggleBehavior(espPlayersToggle, function(v) Settings.ESPShowPlayers = v end)
toggleBehavior(espBotsToggle, function(v) Settings.ESPShowBots = v end)
toggleBehavior(predToggle, function(v) Settings.PredictionEnabled = v end)

-- Textbox updates
aimRangeBox.FocusLost:Connect(function()
    local n = tonumber(aimRangeBox.Text)
    if n then Settings.AimRange = math.max(0, n) end
    aimRangeBox.Text = tostring(Settings.AimRange)
end)

aimFOVBox.FocusLost:Connect(function()
    local n = tonumber(aimFOVBox.Text)
    if n then Settings.AimFOV = math.clamp(n, 1, 300) end
    aimFOVBox.Text = tostring(Settings.AimFOV)
end)

aimSmoothBox.FocusLost:Connect(function()
    local n = tonumber(aimSmoothBox.Text)
    if n then Settings.AimSmoothness = math.clamp(n, 0, 1) end
    aimSmoothBox.Text = tostring(Settings.AimSmoothness)
end)

predTimeBox.FocusLost:Connect(function()
    local n = tonumber(predTimeBox.Text)
    if n then Settings.PredictionTime = math.max(0, n) end
    predTimeBox.Text = tostring(Settings.PredictionTime)
end)

espRangeBox.FocusLost:Connect(function()
    local n = tonumber(espRangeBox.Text)
    if n then Settings.ESPRange = math.max(0, n) end
    espRangeBox.Text = tostring(Settings.ESPRange)
end)

espNameSizeBox.FocusLost:Connect(function()
    local n = tonumber(espNameSizeBox.Text)
    if n then Settings.ESPNameSize = math.max(8, n) end
    espNameSizeBox.Text = tostring(Settings.ESPNameSize)
end)

espBillBox.FocusLost:Connect(function()
    local n = tonumber(espBillBox.Text)
    if n then Settings.ESPBillboardHeight = math.max(0, n) end
    espBillBox.Text = tostring(Settings.ESPBillboardHeight)
end)

-- HUD toggle with RightShift
UserInputService.InputBegan:Connect(function(inp, gp)
    if gp then return end
    if inp.KeyCode == Enum.KeyCode.RightShift then
        Settings.HUDVisible = not Settings.HUDVisible
        screenGui.Enabled = Settings.HUDVisible
    end
end)

screenGui.Enabled = Settings.HUDVisible

-- UTIL: determine if model is player
local function playerFromModel(model)
    return Players:GetPlayerFromCharacter(model)
end

-- UTIL: choose bone part from model according to Settings.AimTargetBone
local function resolveBone(model, boneName)
    if not model then return nil end
    if boneName == "Random" then
        local pool = {"Head","Neck","UpperTorso","LowerTorso","HumanoidRootPart","LeftHand","RightHand","LeftFoot","RightFoot"}
        boneName = pool[math.random(1,#pool)]
    end
    -- mapping fallbacks
    local priority = {
        Head = {"Head"},
        Neck = {"Neck","UpperTorso","Torso","HumanoidRootPart"},
        Torso = {"Torso","UpperTorso","HumanoidRootPart"},
        UpperTorso = {"UpperTorso","Torso","HumanoidRootPart"},
        HumanoidRootPart = {"HumanoidRootPart","LowerTorso","Torso"},
        LeftHand = {"LeftHand","LeftArm"},
        RightHand = {"RightHand","RightArm"},
        LeftFoot = {"LeftFoot","LeftLeg"},
        RightFoot = {"RightFoot","RightLeg"},
    }
    local candidates = priority[boneName] or {boneName}
    for _,n in ipairs(candidates) do
        local found = model:FindFirstChild(n, true)
        if found and found:IsA("BasePart") then return found end
    end
    -- last resort: return HumanoidRootPart or Head
    return model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head")
end

-- UTIL: line of sight check (raycast from camera to part)
local function isVisible(part)
    if not part then return false end
    local origin = Camera.CFrame.Position
    local dir = (part.Position - origin)
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {LocalPlayer.Character}
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    rayParams.IgnoreWater = true
    local ray = Workspace:Raycast(origin, dir, rayParams)
    if not ray then return true end
    if ray.Instance and ray.Instance:IsDescendantOf(part.Parent) then return true end
    return false
end

-- UTIL: closest point on a part's bounding box to a given world point
local function closestPointOnPart(part, worldPoint)
    if not part or not part:IsA("BasePart") then return part and part.Position or nil end
    -- Convert world point to object's local space
    local relative = part.CFrame:PointToObjectSpace(worldPoint)
    local half = part.Size * 0.5
    local clamped = Vector3.new(
        math.clamp(relative.X, -half.X, half.X),
        math.clamp(relative.Y, -half.Y, half.Y),
        math.clamp(relative.Z, -half.Z, half.Z)
    )
    local world = part.CFrame:PointToWorldSpace(clamped)
    return world
end

-- Create or update ESP for a model
local function createOrUpdateESP(model, displayName, dist)
    if not model then return end
    local pool = ESPPool[model]
    if not pool then
        pool = {}
        -- Highlight
        local highlight = Instance.new("Highlight")
        highlight.Adornee = model
        highlight.FillTransparency = 0.7
        highlight.OutlineTransparency = 0
        highlight.Parent = workspace
        pool.highlight = highlight
        -- Billboard
        local bg = Instance.new("BillboardGui")
        bg.Name = "DeltaESP_Billboard"
        -- Adornee choose HRP or UpperTorso or Head (prefer stable root)
        bg.Adornee = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("UpperTorso") or model:FindFirstChild("Head")
        bg.Size = UDim2.new(0, 140, 0, 40)
        bg.AlwaysOnTop = true
        bg.LightInfluence = 0
        bg.Parent = screenGui
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1,0,1,0)
        label.BackgroundTransparency = 0.3
        label.BackgroundColor3 = Settings.ESPVisibleColor
        label.TextColor3 = Settings.ESPNameColor
        label.TextScaled = false
        label.Font = Enum.Font.Gotham
        label.Parent = bg
        pool.billboard = bg
        pool.label = label
        ESPPool[model] = pool
    end
    -- update content
    pool.billboard.Adornee = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("UpperTorso") or model:FindFirstChild("Head")
    pool.label.Text = displayName
    pool.label.TextSize = Settings.ESPNameSize
    -- Raise billboard above the part so it doesn't overlap head
    pool.billboard.StudsOffset = Vector3.new(0, Settings.ESPBillboardHeight, 0)
    -- visibility coloring
    local targetPart = pool.billboard.Adornee
    local vis = isVisible(targetPart)
    if vis then
        pool.label.BackgroundColor3 = Settings.ESPVisibleColor
        if pool.highlight then
            pool.highlight.FillColor = Settings.ESPVisibleColor
            pool.highlight.OutlineColor = Settings.ESPVisibleColor
            pool.highlight.Enabled = Settings.ESPBodyHighlight
        end
    else
        pool.label.BackgroundColor3 = Settings.ESPHiddenColor
        if pool.highlight then
            pool.highlight.FillColor = Settings.ESPHiddenColor
            pool.highlight.OutlineColor = Settings.ESPHiddenColor
            pool.highlight.Enabled = Settings.ESPBodyHighlight
        end
    end
end

local function removeESP(model)
    local pool = ESPPool[model]
    if not pool then return end
    if pool.highlight and pool.highlight.Parent then pool.highlight:Destroy() end
    if pool.billboard and pool.billboard.Parent then pool.billboard:Destroy() end
    ESPPool[model] = nil
end

-- ESP scanning loop (optimized interval)
spawn(function()
    while true do
        if Settings.ESPEnabled and LocalPlayer.Character and LocalPlayer.Character.PrimaryPart then
            local myPos = LocalPlayer.Character.PrimaryPart.Position
            -- players
            if Settings.ESPShowPlayers then
                for _,pl in ipairs(Players:GetPlayers()) do
                    if pl ~= LocalPlayer and pl.Character and pl.Character.PrimaryPart then
                        local dist = (pl.Character.PrimaryPart.Position - myPos).Magnitude
                        if dist <= Settings.ESPRange then
                            createOrUpdateESP(pl.Character, pl.Name .. "\n" .. math.floor(dist) .. "m", dist)
                        else
                            removeESP(pl.Character)
                        end
                    end
                end
            else
                -- remove all player ESP
                for m,p in pairs(ESPPool) do
                    if playerFromModel(m) then removeESP(m) end
                end
            end
            -- bots (models that have humanoid but not linked to player)
            if Settings.ESPShowBots then
                for _,obj in ipairs(Workspace:GetDescendants()) do
                    if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") and not playerFromModel(obj) then
                        local root = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Head")
                        if root then
                            local dist = (root.Position - myPos).Magnitude
                            if dist <= Settings.ESPRange then
                                createOrUpdateESP(obj, (obj.Name or "Bot") .. "\n" .. math.floor(dist) .. "m", dist)
                            else
                                removeESP(obj)
                            end
                        end
                    end
                end
            else
                for m,p in pairs(ESPPool) do
                    if p and not playerFromModel(m) then removeESP(m) end
                end
            end
        else
            -- if ESP disabled, clear
            for m,p in pairs(ESPPool) do removeESP(m) end
        end
        wait(Settings.ESPUpdateRate)
    end
end)

-- Prediction cache updater (sample positions at PredictionSampleDelay)
spawn(function()
    while true do
        local now = tick()
        -- iterate players and bots we may target and store HRP position
        for _,pl in ipairs(Players:GetPlayers()) do
            if pl.Character then
                local hrp = pl.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local ent = predictionCache[pl] or {}
                    -- store previous as prev (if exists)
                    if ent.pos then
                        ent.prevPos = ent.pos
                        ent.prevT = ent.t
                    end
                    ent.pos = hrp.Position
                    ent.t = now
                    predictionCache[pl] = ent
                end
            end
        end
        -- bots: store by model reference
        for _,obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") and not playerFromModel(obj) then
                local hrp = obj:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local ent = predictionCache[obj] or {}
                    if ent.pos then
                        ent.prevPos = ent.pos
                        ent.prevT = ent.t
                    end
                    ent.pos = hrp.Position
                    ent.t = now
                    predictionCache[obj] = ent
                end
            end
        end
        wait(Settings.PredictionSampleDelay)
    end
end)

-- Predictive position getter: model -> predicted world Vector3
local function getPredictedPositionForModel(model, leadTime)
    if not model then return nil end
    local key = playerFromModel(model) or model
    local ent = predictionCache[key]
    if not ent or not ent.pos or not ent.prevPos or not ent.prevT or not ent.t then
        -- no data: fallback to current HRP or part position
        local hrp = model:FindFirstChild("HumanoidRootPart")
        if hrp then return hrp.Position end
        return (model:FindFirstChild("Head") and model.Head.Position) or model.PrimaryPart and model.PrimaryPart.Position
    end
    local dt = ent.t - ent.prevT
    if dt <= 0 then dt = 0.0001 end
    local vel = (ent.pos - ent.prevPos) / dt -- studs per second
    local predicted = ent.pos + vel * (leadTime * Settings.PredictionMultiplier)
    return predicted
end

-- AIM: find best target (returns BasePart and model)
local function findBestTarget()
    if not LocalPlayer.Character or not LocalPlayer.Character.PrimaryPart then return nil end
    local origin = Camera.CFrame.Position
    local mousePos = UserInputService:GetMouseLocation()
    local bestPart = nil
    local bestModel = nil
    local bestScore = math.huge

    local fovPixels = Settings.AimFOV * (Camera.ViewportSize.X/1200)

    -- helper to evaluate candidate part
    local function evalCandidate(part, model)
        if not part then return end
        local dist = (part.Position - origin).Magnitude
        if dist > Settings.AimRange then return end
        local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
        if not onScreen then return end
        local ang = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
        if ang > fovPixels then return end
        if Settings.AimRequireLOF and not isVisible(part) then return end
        -- scoring prefers closer + closer to crosshair
        local score = dist + ang * 0.1
        if score < bestScore then
            bestScore = score
            bestPart = part
            bestModel = model
        end
    end

    -- players
    if Settings.AimPlayers then
        for _,pl in ipairs(Players:GetPlayers()) do
            if pl ~= LocalPlayer and pl.Character and pl.Character.PrimaryPart then
                local bonePart = resolveBone(pl.Character, Settings.AimTargetBone)
                if bonePart then evalCandidate(bonePart, pl.Character) end
            end
        end
    end

    -- bots
    if Settings.AimBots then
        for _,obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") and not playerFromModel(obj) then
                local bonePart = resolveBone(obj, Settings.AimTargetBone)
                if bonePart then evalCandidate(bonePart, obj) end
            end
        end
    end

    return bestPart, bestModel
end

-- AIM main control: hold right mouse to aim (configurable)
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        aiming = true
    end
end)
UserInputService.InputEnded:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        aiming = false
        currentTargetPart = nil
    end
end)

-- Smoothly point camera at given world position
local function smoothLookAt(targetPos)
    if not Camera then return end
    local camPos = Camera.CFrame.Position
    local targetCFrame = CFrame.new(camPos, targetPos)
    Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, Settings.AimSmoothness)
end

-- When aiming at a part, sometimes aiming vector may fall outside the part bounds.
-- We'll compute nearest point on the target part bounding box to the ideal aim point.
local function computeAimPointOnPart(part, idealPoint)
    if not part then return nil end
    -- nearest point on bounding box to "idealPoint"
    local closest = closestPointOnPart(part, idealPoint)
    return closest
end

-- Main aim loop (runs on RenderStepped for smoothness)
RunService.RenderStepped:Connect(function()
    if Settings.AimEnabled and aiming then
        local now = tick()
        if now - lastAimSearch >= Settings.AimSearchRate then
            lastAimSearch = now
            local p, model = findBestTarget()
            currentTargetPart = p
            currentTargetModel = model
        end

        if currentTargetPart then
            -- compute ideal aim point: predicted pos of model bone (if prediction enabled) OR current part position
            local aimPoint = currentTargetPart.Position

            if Settings.PredictionEnabled and currentTargetModel then
                -- try to get HRP predicted, then translate to equivalent offset for the current part
                local predictedHRP = getPredictedPositionForModel(currentTargetModel, Settings.PredictionTime)
                if predictedHRP and currentTargetModel:FindFirstChild("HumanoidRootPart") then
                    -- determine offset from HRP to the targetPart in current frame: targetPart.Position - currentHRP.Position
                    local curHRP = currentTargetModel:FindFirstChild("HumanoidRootPart")
                    if curHRP then
                        local offset = currentTargetPart.Position - curHRP.Position
                        aimPoint = predictedHRP + offset
                    else
                        aimPoint = getPredictedPositionForModel(currentTargetModel, Settings.PredictionTime)
                    end
                end
            end

            -- Ensure aimPoint lies on the part bounds (if ideal aimpoint drifted)
            local correctedAim = computeAimPointOnPart(currentTargetPart, aimPoint) or aimPoint

            -- Ensure nearest: if correctedAim far from ideal and ideal outside bounds, use correctedAim
            smoothLookAt(correctedAim)
        end
    else
        currentTargetPart = nil
    end
end)

-- Clean removal on character leaving
Players.PlayerRemoving:Connect(function(pl)
    if pl.Character then removeESP(pl.Character) end
    predictionCache[pl] = nil
end)

-- Also cleanup prediction cache when character dies / removed
Players.PlayerAdded:Connect(function(pl)
    pl.CharacterRemoving:Connect(function()
        predictionCache[pl] = nil
    end)
end)

-- Clean on script disable
local function cleanupAll()
    for m,p in pairs(ESPPool) do removeESP(m) end
    screenGui:Destroy()
    -- restore lighting
    Lighting.ClockTime = originalLighting.ClockTime
    Lighting.Brightness = originalLighting.Brightness
    Lighting.GlobalShadows = originalLighting.GlobalShadows
end

-- Bind cleanup to player quit / script end
LocalPlayer.AncestryChanged:Connect(function()
    if not LocalPlayer:IsDescendantOf(game) then cleanupAll() end
end)

print("Delta HUD v3 (Full) updated & loaded. Use RightShift to toggle HUD. Configure AIM/ESP in menu.")
