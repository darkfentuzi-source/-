-- Xeno Global v5.4 - NumPad2 AimLock, Anti-AFK, Fun Movement, Multi-Team Colors

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local Teams = game:GetService("Teams")

-- === 4. ОПТИМІЗАЦІЙНІ ТА ОСНОВНІ НАЛАШТУВАННЯ (SETTINGS) ===
local Settings = {
    -- Оптимізація
    ESP_UPDATE_RATE = 0.07,
    REMOVE_DISTANCE = 3500,
    MAP_SCALE_FACTOR = 4,
    MAP_MAX_DOT_DISTANCE = 75,

    -- Основні перемикачі
    ESP_Enabled = true,
    Aim_Enabled = false, -- Класичний Aimbot (утримання кнопки)
    Tracers_Enabled = true,
    Minimap_Visible = true,
    Fullbright_Enabled = true,
    ShowTriggerPoints = false,
    Hitbox_Expansion_Enabled = false,
    TeamRecognition_Enabled = false,

    -- Аімбот
    AimKey = Enum.UserInputType.MouseButton2,
    AimSpeed = 0.9, -- Швидкий Aimbot (різкий, але не телепорт)
    AimFOV = 200,
    FOV_Circle_Color = Color3.fromRGB(255, 255, 255),

    -- Hitbox
    Hitbox_Expansion_Factor = 0.2,

    -- Кольори
    HeadColor_Static = Color3.fromRGB(128, 0, 128), -- ФІОЛЕТОВИЙ (свій / голова)
    Color_Visible = Color3.fromRGB(0, 255, 0),      -- ЗЕЛЕНИЙ (видно ворога)
    Color_Hidden = Color3.fromRGB(255, 0, 0),       -- ЧЕРВОНИЙ (за стіною)
    Color_AimTarget = Color3.fromRGB(255, 215, 0),  -- ЗОЛОТИЙ (поточна ціль)
    Color_Bot = Color3.fromRGB(255, 165, 0),        -- ПОМАРАНЧЕВИЙ (боти)

    -- Додаткові кольори для кількох ворожих команд
    EnemyTeamVisibleColors = {
        Color3.fromRGB(255, 60, 60),   -- команда 1 (видно)
        Color3.fromRGB(60, 200, 255),  -- команда 2 (видно)
        Color3.fromRGB(255, 220, 60),  -- команда 3 (видно)
        Color3.fromRGB(190, 60, 255),  -- команда 4 (видно)
    },
    EnemyTeamHiddenColors = {
        Color3.fromRGB(120, 20, 20),   -- команда 1 (за стіною)
        Color3.fromRGB(20, 90, 130),   -- команда 2 (за стіною)
        Color3.fromRGB(130, 100, 20),  -- команда 3 (за стіною)
        Color3.fromRGB(90, 20, 120),   -- команда 4 (за стіною)
    },

    -- Клавіші
    Key_ToggleESP = Enum.KeyCode.RightAlt,
    Key_ToggleAim = Enum.KeyCode.J, -- Класичний Aimbot
    Key_ToggleMap = Enum.KeyCode.M,
    Key_ToggleTracers = Enum.KeyCode.T,
    Key_Reconnect = Enum.KeyCode.Period, -- >
    Key_TogglePoints = Enum.KeyCode.Comma, -- <
    Key_ToggleHitbox = Enum.KeyCode.P,
    Key_ToggleTeam = Enum.KeyCode.KeypadOne, -- NumPad1

    -- Aim Lock V2 Клавіші (Фіксація цілі)
    Key_ToggleAimLockV2 = Enum.KeyCode.KeypadTwo,  -- NumPad2
    Key_ToggleAimLockV2Alt = Enum.KeyCode.KeypadZero, -- NumPad0 (додатково)

    -- Anti AFK
    Key_ToggleAntiAFK = Enum.KeyCode.KeypadThree, -- NumPad3

    -- Фанові функції (Home/End/PgUp/PgDn/Ins/Del)
    Key_ToggleFastRun   = Enum.KeyCode.Home,
    Key_ToggleAirJump   = Enum.KeyCode.PageUp,
    Key_ToggleNoclip    = Enum.KeyCode.Insert,
    Key_ToggleExtraFOV  = Enum.KeyCode.PageDown,
    Key_ToggleFullbright= Enum.KeyCode.End,
    Key_TogglePointsAlt = Enum.KeyCode.Delete,
}

-- === ЗМІННІ СКРИПТА ===
local Visuals = {}
local AimTarget = nil -- Ціль для класичного Aimbot (утримання)
local AimingActive = false -- Класичний Aimbot активний
local AimLockV2Active = false -- Aim Lock V2 активний
local AimLockV2Target = nil -- Ціль для Aim Lock V2
local AntiAFK_Enabled = false
local AntiAFK_Timer = 0
local lastESPUpdate = 0

local FOVCircle = Drawing.new("Circle")
FOVCircle.Radius = Settings.AimFOV
FOVCircle.Color = Settings.FOV_Circle_Color
FOVCircle.Thickness = 2
FOVCircle.Transparency = 0.7
FOVCircle.Visible = false

local R15_PARTS = {"Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg"}
local R6_PARTS = {"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}

-- Додаткові стани
local FastRunEnabled = false
local AirJumpEnabled = false
local NoclipEnabled = false
local ExtraFOVEnabled = false
local ArrowMove = {Up=false,Down=false,Left=false,Right=false}
local DefaultFOV = Camera.FieldOfView
local OriginalWalkSpeed = 16
local AirJumpCount = 0
local MaxAirJumps = 3

-- Мапа кольорів для ворожих команд
local TeamColorMap = {}
local NextEnemyTeamIndex = 1

-- === UI STATUS PANEL ===
local CoreGui = game:GetService("CoreGui")
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "XenoOverlay"
ScreenGui.Parent = CoreGui

local StatusFrame = Instance.new("Frame")
StatusFrame.Position = UDim2.new(0, 20, 0, 20)
StatusFrame.Size = UDim2.new(0, 260, 0, 260)
StatusFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
StatusFrame.BackgroundTransparency = 0.3
StatusFrame.BorderSizePixel = 0
StatusFrame.Parent = ScreenGui

local UIList = Instance.new("UIListLayout")
UIList.Parent = StatusFrame
UIList.Padding = UDim.new(0, 5)
UIList.SortOrder = Enum.SortOrder.LayoutOrder

local function CreateStatusLabel(text)
    local lab = Instance.new("TextLabel")
    lab.Size = UDim2.new(1, 0, 0, 20)
    lab.BackgroundTransparency = 1
    lab.TextColor3 = Color3.fromRGB(255, 255, 255)
    lab.TextStrokeTransparency = 0.5
    lab.Font = Enum.Font.Code
    lab.TextSize = 14
    lab.TextXAlignment = Enum.TextXAlignment.Left
    lab.Text = " " .. text
    lab.Parent = StatusFrame
    return lab
end

local L_ESP       = CreateStatusLabel("[RightAlt] ESP: ON")
local L_Aim       = CreateStatusLabel("[J] Aimbot Hold: OFF")
local L_AimV2     = CreateStatusLabel("[NumPad2] AimLock V2: OFF")
local L_AntiAFK   = CreateStatusLabel("[NumPad3] Anti-AFK: OFF")
local L_Map       = CreateStatusLabel("[M] Minimap: ON")
local L_Trace     = CreateStatusLabel("[T] Tracers: ON")
local L_Points    = CreateStatusLabel("[< / Del] Points: OFF")
local L_Hitbox    = CreateStatusLabel("[P] Hitbox Exp: OFF")
local L_Team      = CreateStatusLabel("[NumPad1] Team Rec: OFF")
local L_Run       = CreateStatusLabel("[Home] Fast Run: OFF")
local L_AirJump   = CreateStatusLabel("[PgUp] Air Jump: OFF")
local L_Noclip    = CreateStatusLabel("[Ins] Noclip: OFF")
local L_FOV       = CreateStatusLabel("[PgDn] Extra FOV: OFF")
local L_Fullbright= CreateStatusLabel("[End] Fullbright: ON")
local L_Reconnect = CreateStatusLabel("[>] Reconnect: Ready")

-- Міні-карта
local MapFrame = Instance.new("Frame")
MapFrame.Name = "Minimap"
MapFrame.Size = UDim2.new(0, 160, 0, 160)
MapFrame.Position = UDim2.new(0, 20, 1, -180)
MapFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
MapFrame.BorderColor3 = Color3.fromRGB(255, 255, 255)
MapFrame.BorderSizePixel = 2
MapFrame.BackgroundTransparency = 0.4
MapFrame.Visible = Settings.Minimap_Visible
MapFrame.Parent = ScreenGui
Instance.new("UICorner", MapFrame).CornerRadius = UDim.new(1,0)

local PlayerArrowContainer = Instance.new("Frame")
PlayerArrowContainer.Name = "PlayerArrow"
PlayerArrowContainer.Size = UDim2.new(0, 10, 0, 10)
PlayerArrowContainer.Position = UDim2.new(0.5, -5, 0.5, -5)
PlayerArrowContainer.BackgroundTransparency = 1
PlayerArrowContainer.BorderSizePixel = 0
PlayerArrowContainer.ZIndex = 3
PlayerArrowContainer.Parent = MapFrame

local FrontIndicator = Instance.new("Frame", PlayerArrowContainer)
FrontIndicator.Size = UDim2.new(0, 4, 0, 4)
FrontIndicator.Position = UDim2.new(0.5, -2, 0.5, -6)
FrontIndicator.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
FrontIndicator.BorderSizePixel = 0
FrontIndicator.ZIndex = 4
Instance.new("UICorner", FrontIndicator).CornerRadius = UDim.new(1,0)

local BackIndicator = Instance.new("Frame", PlayerArrowContainer)
BackIndicator.Size = UDim2.new(0, 4, 0, 4)
BackIndicator.Position = UDim2.new(0.5, -2, 0.5, 2)
BackIndicator.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
BackIndicator.BorderSizePixel = 0
BackIndicator.ZIndex = 4
Instance.new("UICorner", BackIndicator).CornerRadius = UDim.new(1,0)

local CenterDot = Instance.new("Frame", PlayerArrowContainer)
CenterDot.Size = UDim2.new(0, 4, 0, 4)
CenterDot.Position = UDim2.new(0.5, -2, 0.5, -2)
CenterDot.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
CenterDot.BorderSizePixel = 0
CenterDot.ZIndex = 5
Instance.new("UICorner", CenterDot).CornerRadius = UDim.new(1,0)

-- === ПАНЕЛЬ ЦІЛІ АІМБОТА ===
local TargetPanel = Instance.new("Frame")
TargetPanel.Name = "AimTargetPanel"
TargetPanel.Size = UDim2.new(0, 260, 0, 25)
TargetPanel.Position = UDim2.new(0.5, -130, 0, 5)
TargetPanel.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
TargetPanel.BackgroundTransparency = 0.6
TargetPanel.BorderSizePixel = 1
TargetPanel.BorderColor3 = Color3.fromRGB(50, 50, 50)
TargetPanel.Parent = ScreenGui

local TargetLabel = Instance.new("TextLabel")
TargetLabel.Name = "TargetName"
TargetLabel.Size = UDim2.new(1, 0, 1, 0)
TargetLabel.BackgroundTransparency = 1
TargetLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
TargetLabel.TextStrokeTransparency = 0.8
TargetLabel.Font = Enum.Font.Code
TargetLabel.TextSize = 16
TargetLabel.Text = "Aimbot не активний (J / NumPad2)"
TargetLabel.Parent = TargetPanel

-- === ФУНКЦІЇ (FUNCTIONS) ===
local function Reconnect()
    TeleportService:Teleport(game.PlaceId, LocalPlayer)
end

local function IsVisible(char)
    local parts = (char.Humanoid.RigType == Enum.HumanoidRigType.R15) and R15_PARTS or R6_PARTS
    local origin = Camera.CFrame.Position
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {LocalPlayer.Character, ScreenGui}

    for _, partName in ipairs(parts) do
        local part = char:FindFirstChild(partName, true)
        if part and part.Transparency < 1 and part.Size.Magnitude > 0.5 then
            local direction = (part.Position - origin).Unit * ((part.Position - origin).Magnitude - 0.5)
            local result = workspace:Raycast(origin, direction, params)
            if result == nil or result.Instance:IsDescendantOf(char) then
                return true
            end
        end
    end
    return false
end

local function CreateInfoTag()
    local bg = Instance.new("BillboardGui")
    bg.Name = "ESP_Info"
    bg.Adornee = nil
    bg.AlwaysOnTop = true
    bg.Size = UDim2.new(0, 200, 0, 100)
    bg.StudsOffset = Vector3.new(0, 1, 0)
    bg.Parent = ScreenGui

    local List = Instance.new("UIListLayout")
    List.Parent = bg
    List.SortOrder = Enum.SortOrder.LayoutOrder
    List.Padding = UDim.new(0, 1)
    List.VerticalAlignment = Enum.VerticalAlignment.Top

    local nameLab = Instance.new("TextLabel")
    nameLab.Name = "NameLabel"
    nameLab.Size = UDim2.new(1, 0, 0, 20)
    nameLab.BackgroundTransparency = 1
    nameLab.TextStrokeTransparency = 0.55
    nameLab.TextColor3 = Settings.Color_Hidden
    nameLab.TextSize = 14
    nameLab.Font = Enum.Font.GothamBold
    nameLab.Text = "Loading..."
    nameLab.LayoutOrder = 1
    nameLab.Parent = bg

    local statsLab = Instance.new("TextLabel")
    statsLab.Name = "StatsLabel"
    statsLab.Size = UDim2.new(1, 0, 0, 15)
    statsLab.BackgroundTransparency = 1
    statsLab.TextStrokeTransparency = 0.55
    statsLab.TextColor3 = Color3.fromRGB(255, 255, 255)
    statsLab.TextSize = 12
    statsLab.Font = Enum.Font.Gotham
    statsLab.Text = ""
    statsLab.LayoutOrder = 2
    statsLab.Parent = bg

    return bg, nameLab, statsLab
end

local function CreateTracer()
    local line = Drawing.new("Line")
    line.Visible = false
    line.Color = Color3.new(1, 1, 1)
    line.Thickness = 1.5
    line.Transparency = 0.3
    return line
end

local function RemoveVisuals(key)
    if Visuals[key] then
        if Visuals[key].Tracer then Visuals[key].Tracer:Remove() end
        if Visuals[key].InfoGUI then Visuals[key].InfoGUI:Destroy() end
        if Visuals[key].MapDot then Visuals[key].MapDot:Destroy() end
        if Visuals[key].HeadAdornment then Visuals[key].HeadAdornment:Destroy() end
        for _, b in pairs(Visuals[key].BoxParts or {}) do b:Destroy() end
        for _, p in pairs(Visuals[key].TriggerPoints or {}) do p:Destroy() end
        Visuals[key] = nil
    end
end

-- Основна функція оновлення ESP
local function UpdateVisuals()
    local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end

    local targets = {}
    local currentKeys = {}
    local expansion = Settings.Hitbox_Expansion_Enabled and (1 + Settings.Hitbox_Expansion_Factor) or 1

    -- 1. Гравці
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            targets[p] = p.Character
            currentKeys[p] = true
        end
    end

    -- 2. Боти (Model з Humanoid, але без Player)
    for _, child in ipairs(workspace:GetChildren()) do
        if child:IsA("Model") and child:FindFirstChild("Humanoid") and child:FindFirstChild("HumanoidRootPart") then
            local p = Players:GetPlayerFromCharacter(child)
            if not p and child ~= LocalPlayer.Character then
                targets[child] = child
                currentKeys[child] = true
            end
        end
    end

    -- 3. Очистка зниклих цілей
    for key, _ in pairs(Visuals) do
        if not currentKeys[key] then
            RemoveVisuals(key)
        end
    end

    -- 4. Обробка всіх цілей
    for key, char in pairs(targets) do
        local player = Players:GetPlayerFromCharacter(char)
        local isBot = player == nil

        local v = Visuals[key]
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local head = char:FindFirstChild("Head")
        local hum = char:FindFirstChild("Humanoid")

        if not hrp or not head or not hum or hum.Health <= 0 then
            RemoveVisuals(key)
            if AimLockV2Target == char then
                AimLockV2Active = false
                AimLockV2Target = nil
            end
            continue
        end

        local dist = (hrp.Position - myHRP.Position).Magnitude

        if not v then
            Visuals[key] = {
                BoxParts = {}, HeadAdornment = nil, MapDot = nil, Tracer = CreateTracer(),
                TriggerPoints = {}
            }
            local bg, nl, sl = CreateInfoTag()
            Visuals[key].InfoGUI, Visuals[key].NameLabel, Visuals[key].StatsLabel = bg, nl, sl

            local dot = Instance.new("Frame", MapFrame)
            dot.Size = UDim2.new(0, 4, 0, 4)
            dot.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
            dot.BorderSizePixel = 0
            Instance.new("UICorner", dot).CornerRadius = UDim.new(1,0)
            Visuals[key].MapDot = dot
            v = Visuals[key]
        end

        if dist > Settings.REMOVE_DISTANCE then
            v.InfoGUI.Enabled = false
            v.MapDot.Visible = false
            v.Tracer.Visible = false
            if v.HeadAdornment then v.HeadAdornment.Visible = false end
            for _, box in pairs(v.BoxParts) do box.Visible = false end
            for _, p in pairs(v.TriggerPoints) do p.Visible = false end
            continue
        end

        local visible = IsVisible(char)
        local isEnabled = Settings.ESP_Enabled

        local mainColor
        local headColorToUse
        local isTeamate = false

        if isBot then
            headColorToUse = Settings.Color_Bot
            mainColor = Settings.Color_Bot
        else
            if player then
                local isSameTeam = (LocalPlayer.Team and player.Team and LocalPlayer.Team == player.Team)
                    or (LocalPlayer.TeamColor and player.TeamColor and LocalPlayer.TeamColor == player.TeamColor)
                isTeamate = isSameTeam
            end

            if Settings.TeamRecognition_Enabled and isTeamate then
                mainColor = Settings.HeadColor_Static
                headColorToUse = Settings.HeadColor_Static
            elseif Settings.TeamRecognition_Enabled and player and player.Team then
                -- Друга / третя / четверта ворожа команда з власним кольором
                local t = player.Team
                local entry = TeamColorMap[t]
                if not entry then
                    local vidx = NextEnemyTeamIndex
                    local visCol = Settings.EnemyTeamVisibleColors[vidx] or Settings.Color_Visible
                    local hidCol = Settings.EnemyTeamHiddenColors[vidx] or Settings.Color_Hidden
                    TeamColorMap[t] = {Visible = visCol, Hidden = hidCol}
                    NextEnemyTeamIndex = NextEnemyTeamIndex + 1
                    if NextEnemyTeamIndex > #Settings.EnemyTeamVisibleColors then
                        NextEnemyTeamIndex = 1
                    end
                    entry = TeamColorMap[t]
                end
                local useCol = visible and entry.Visible or entry.Hidden
                mainColor = useCol
                headColorToUse = useCol
            else
                mainColor = visible and Settings.Color_Visible or Settings.Color_Hidden
                headColorToUse = visible and Settings.HeadColor_Static or Settings.Color_Hidden
            end
        end

        local isCurrentTarget = (AimTarget == char) or (AimLockV2Target == char)
        if isCurrentTarget then
            headColorToUse = Settings.Color_AimTarget
        end

        if not v.HeadAdornment then
            local h = Instance.new("CylinderHandleAdornment")
            h.Height = 1.1; h.Radius = 0.6; h.CFrame = CFrame.Angles(math.rad(90),0,0)
            h.AlwaysOnTop = true; h.Transparency = 0.4; h.ZIndex = 5
            h.Parent = ScreenGui; v.HeadAdornment = h
        end
        v.HeadAdornment.Adornee = head
        v.HeadAdornment.Radius = 0.6 * expansion
        v.HeadAdornment.Height = 1.1 * expansion
        v.HeadAdornment.Color3 = headColorToUse
        v.HeadAdornment.Visible = isEnabled

        local limbs = char.Humanoid.RigType == Enum.HumanoidRigType.R15 and R15_PARTS or R6_PARTS
        for _, partName in ipairs(limbs) do
            local part = char:FindFirstChild(partName)
            if part and part.Name ~= "Head" and part.Name ~= "HumanoidRootPart" then
                if not v.BoxParts[partName] then
                    local b = Instance.new("BoxHandleAdornment")
                    b.Adornee = part; b.AlwaysOnTop = true; b.Transparency = 0.6; b.ZIndex = 1
                    b.Parent = ScreenGui; v.BoxParts[partName] = b
                end
                v.BoxParts[partName].Adornee = part
                v.BoxParts[partName].Size = part.Size * expansion
                v.BoxParts[partName].Color3 = mainColor
                v.BoxParts[partName].Visible = isEnabled
            else
                if v.BoxParts[partName] then v.BoxParts[partName].Visible = false end
            end
        end

        -- Триггер-точки (можеш допиляти далі, якщо треба)
        if Settings.ShowTriggerPoints then
            for _, p in pairs(v.TriggerPoints) do p.Visible = true end
        else
            for _, p in pairs(v.TriggerPoints) do p.Visible = false end
        end

        v.InfoGUI.Enabled = isEnabled
        v.InfoGUI.Adornee = head

        local teamPrefix = ""
        if isBot then
            teamPrefix = string.format("<font color=\"rgb(%d, %d, %d)\"><b>БОТ | </b></font>",
                Settings.Color_Bot.R * 255, Settings.Color_Bot.G * 255, Settings.Color_Bot.B * 255)
        elseif isTeamate and Settings.TeamRecognition_Enabled then
            teamPrefix = string.format("<font color=\"rgb(%d, %d, %d)\"><b>СВІЙ | </b></font>",
                Settings.HeadColor_Static.R * 255, Settings.HeadColor_Static.G * 255, Settings.HeadColor_Static.B * 255)
        end

        v.NameLabel.RichText = true
        v.NameLabel.Text = teamPrefix .. (isBot and char.Name or player.Name)
        v.NameLabel.TextColor3 = isBot and Settings.Color_Bot or mainColor

        local currentHP = math.floor(hum.Health)
        local maxHP = math.floor(hum.MaxHealth)
        v.StatsLabel.Text = string.format("[ %d / %d HP ] [ %dm ]", currentHP, maxHP, math.floor(dist))

        if Settings.Minimap_Visible then
            local rel = hrp.Position - myHRP.Position
            local angleToTarget = math.atan2(rel.X, rel.Z)
            local mDist = math.clamp(dist / Settings.MAP_SCALE_FACTOR, 0, Settings.MAP_MAX_DOT_DISTANCE)

            if mDist < Settings.MAP_MAX_DOT_DISTANCE then
                local x = math.sin(angleToTarget) * mDist
                local y = math.cos(angleToTarget) * mDist
                v.MapDot.Position = UDim2.new(0.5, x - 2, 0.5, -y - 2)
                v.MapDot.Visible = true
                v.MapDot.BackgroundColor3 = isBot and Settings.Color_Bot or mainColor
            else
                v.MapDot.Visible = false
            end
        else
            v.MapDot.Visible = false
        end

        if Settings.Tracers_Enabled then
            local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            if onScreen and isEnabled then
                v.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                v.Tracer.To = Vector2.new(screenPos.X, screenPos.Y)
                v.Tracer.Color = isBot and Settings.Color_Bot or mainColor
                v.Tracer.Visible = true
            else
                v.Tracer.Visible = false
            end
        else
            v.Tracer.Visible = false
        end
    end
end

local function GetTarget(checkVisibility)
    local mouse = UserInputService:GetMouseLocation()
    local closest, minD = nil, Settings.AimFOV

    for _, v in pairs(Visuals) do
        local char = v.InfoGUI.Adornee and v.InfoGUI.Adornee.Parent
        if char and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then
            local head = char:FindFirstChild("Head")
            if head then
                if checkVisibility and not IsVisible(char) then
                    continue
                end
                local headPos = head.Position
                local pos, vis = Camera:WorldToViewportPoint(headPos)
                if vis then
                    local d = (Vector2.new(pos.X, pos.Y) - mouse).Magnitude
                    if d < minD then
                        minD = d
                        closest = char
                    end
                end
            end
        end
    end
    return closest
end

-- Anti-AFK: клік миші при ідлі
Players.LocalPlayer.Idled:Connect(function()
    if AntiAFK_Enabled then
        VirtualUser:Button2Down(Vector2.new(0, 0), Camera.CFrame)
        task.wait(0.1)
        VirtualUser:Button2Up(Vector2.new(0, 0), Camera.CFrame)
    end
end)

-- AirJump: ресет лічильника при приземленні
local function SetupHumanoid(hum)
    if not hum then return end
    hum.StateChanged:Connect(function(_, new)
        if new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running or new == Enum.HumanoidStateType.RunningNoPhysics then
            AirJumpCount = 0
        end
    end)
    OriginalWalkSpeed = hum.WalkSpeed
end

if LocalPlayer.Character then
    local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
    if hum then SetupHumanoid(hum) end
end

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(1)
    local hum = char:FindChild("Humanoid") or char:FindFirstChild("Humanoid")
    if hum then SetupHumanoid(hum) end
end)

UserInputService.JumpRequest:Connect(function()
    if not AirJumpEnabled then return end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChild("Humanoid")
    if not hum then return end
    if hum.FloorMaterial ~= Enum.Material.Air then
        AirJumpCount = 0
        return
    end
    if AirJumpCount < MaxAirJumps then
        AirJumpCount = AirJumpCount + 1
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

-- === ОБРОБКА ВХОДУ (INPUT) ===
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end

    if input.KeyCode == Settings.Key_ToggleESP then
        Settings.ESP_Enabled = not Settings.ESP_Enabled
        L_ESP.Text = Settings.ESP_Enabled and "[RightAlt] ESP: ON" or "[RightAlt] ESP: OFF"
        L_ESP.TextColor3 = Settings.ESP_Enabled and Color3.new(0,1,0) or Color3.new(1,0,0)

    elseif input.KeyCode == Settings.Key_ToggleAim then
        Settings.Aim_Enabled = not Settings.Aim_Enabled
        L_Aim.Text = Settings.Aim_Enabled and "[J] Aimbot Hold: ON" or "[J] Aimbot Hold: OFF"
        L_Aim.TextColor3 = Settings.Aim_Enabled and Color3.new(0,1,0) or Color3.new(1,0,0)

    -- AIM LOCK V2 TOGGLE (NumPad2 / NumPad0)
    elseif input.KeyCode == Settings.Key_ToggleAimLockV2 or input.KeyCode == Settings.Key_ToggleAimLockV2Alt then
        if AimLockV2Active then
            AimLockV2Active = false
            AimLockV2Target = nil
            L_AimV2.Text = "[NumPad2] AimLock V2: OFF"
            L_AimV2.TextColor3 = Color3.new(1,0,0)
        else
            local newTarget = GetTarget(true)
            if newTarget then
                AimLockV2Target = newTarget
                AimLockV2Active = true
                L_AimV2.Text = "[NumPad2] AimLock V2: ON"
                L_AimV2.TextColor3 = Color3.new(0,1,0)
            else
                L_AimV2.Text = "[NumPad2] AimLock V2: No Target"
                L_AimV2.TextColor3 = Color3.fromRGB(255, 165, 0)
                AimLockV2Active = false
                AimLockV2Target = nil
            end
        end

    -- Anti-AFK toggle (NumPad3)
    elseif input.KeyCode == Settings.Key_ToggleAntiAFK then
        AntiAFK_Enabled = not AntiAFK_Enabled
        L_AntiAFK.Text = AntiAFK_Enabled and "[NumPad3] Anti-AFK: ON" or "[NumPad3] Anti-AFK: OFF"
        L_AntiAFK.TextColor3 = AntiAFK_Enabled and Color3.new(0,1,0) or Color3.new(1,0,0)

    -- Fast run (Home)
    elseif input.KeyCode == Settings.Key_ToggleFastRun then
        FastRunEnabled = not FastRunEnabled
        L_Run.Text = FastRunEnabled and "[Home] Fast Run: ON" or "[Home] Fast Run: OFF"
        L_Run.TextColor3 = FastRunEnabled and Color3.new(0,1,0) or Color3.new(1,0,0)

    -- Air jump (PgUp)
    elseif input.KeyCode == Settings.Key_ToggleAirJump then
        AirJumpEnabled = not AirJumpEnabled
        AirJumpCount = 0
        L_AirJump.Text = AirJumpEnabled and "[PgUp] Air Jump: ON" or "[PgUp] Air Jump: OFF"
        L_AirJump.TextColor3 = AirJumpEnabled and Color3.new(0,1,0) or Color3.new(1,0,0)

    -- Noclip (Insert)
    elseif input.KeyCode == Settings.Key_ToggleNoclip then
        NoclipEnabled = not NoclipEnabled
        L_Noclip.Text = NoclipEnabled and "[Ins] Noclip: ON" or "[Ins] Noclip: OFF"
        L_Noclip.TextColor3 = NoclipEnabled and Color3.new(0,1,0) or Color3.new(1,0,0)

    -- Extra FOV (PgDn)
    elseif input.KeyCode == Settings.Key_ToggleExtraFOV then
        ExtraFOVEnabled = not ExtraFOVEnabled
        L_FOV.Text = ExtraFOVEnabled and "[PgDn] Extra FOV: ON" or "[PgDn] Extra FOV: OFF"
        L_FOV.TextColor3 = ExtraFOVEnabled and Color3.new(0,1,0) or Color3.new(1,0,0)

    -- Fullbright toggle (End)
    elseif input.KeyCode == Settings.Key_ToggleFullbright then
        Settings.Fullbright_Enabled = not Settings.Fullbright_Enabled
        L_Fullbright.Text = Settings.Fullbright_Enabled and "[End] Fullbright: ON" or "[End] Fullbright: OFF"
        L_Fullbright.TextColor3 = Settings.Fullbright_Enabled and Color3.new(0,1,0) or Color3.new(1,0,0)

    -- Alt points toggle (Delete)
    elseif input.KeyCode == Settings.Key_TogglePointsAlt or input.KeyCode == Settings.Key_TogglePoints then
        Settings.ShowTriggerPoints = not Settings.ShowTriggerPoints
        L_Points.Text = Settings.ShowTriggerPoints and "[< / Del] Points: ON" or "[< / Del] Points: OFF"
        L_Points.TextColor3 = Settings.ShowTriggerPoints and Color3.new(0,1,0) or Color3.new(1,0,0)

    elseif input.KeyCode == Settings.Key_ToggleHitbox then
        Settings.Hitbox_Expansion_Enabled = not Settings.Hitbox_Expansion_Enabled
        L_Hitbox.Text = Settings.Hitbox_Expansion_Enabled and "[P] Hitbox Exp: ON" or "[P] Hitbox Exp: OFF"
        L_Hitbox.TextColor3 = Settings.Hitbox_Expansion_Enabled and Color3.new(0,1,0) or Color3.new(1,0,0)

    elseif input.KeyCode == Settings.Key_ToggleTeam then
        Settings.TeamRecognition_Enabled = not Settings.TeamRecognition_Enabled
        L_Team.Text = Settings.TeamRecognition_Enabled and "[NumPad1] Team Rec: ON" or "[NumPad1] Team Rec: OFF"
        L_Team.TextColor3 = Settings.TeamRecognition_Enabled and Color3.new(0,1,0) or Color3.new(1,0,0)

    elseif input.KeyCode == Settings.Key_Reconnect then
        Reconnect()
    end

    -- Стрілки біля NumPad (Up/Down/Left/Right)
    if input.KeyCode == Enum.KeyCode.Up then
        ArrowMove.Up = true
    elseif input.KeyCode == Enum.KeyCode.Down then
        ArrowMove.Down = true
    elseif input.KeyCode == Enum.KeyCode.Left then
        ArrowMove.Left = true
    elseif input.KeyCode == Enum.KeyCode.Right then
        ArrowMove.Right = true
    end

    if input.UserInputType == Settings.AimKey and Settings.Aim_Enabled then
        AimingActive = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Settings.AimKey then
        AimingActive = false
        AimTarget = nil
    end

    if input.KeyCode == Enum.KeyCode.Up then
        ArrowMove.Up = false
    elseif input.KeyCode == Enum.KeyCode.Down then
        ArrowMove.Down = false
    elseif input.KeyCode == Enum.KeyCode.Left then
        ArrowMove.Left = false
    elseif input.KeyCode == Enum.KeyCode.Right then
        ArrowMove.Right = false
    end
end)

-- === ГОЛОВНИЙ ЦИКЛ (RENDER LOOP) ===
RunService.RenderStepped:Connect(function(dt)
    -- Оновлення ESP
    lastESPUpdate = lastESPUpdate + dt
    if lastESPUpdate >= Settings.ESP_UPDATE_RATE then
        UpdateVisuals()
        lastESPUpdate = 0
    end

    -- Fullbright
    if Settings.Fullbright_Enabled then
        Lighting.ClockTime = 14
        Lighting.GlobalShadows = false
    end

    -- Extra FOV
    if ExtraFOVEnabled then
        Camera.FieldOfView = 95
    else
        Camera.FieldOfView = DefaultFOV
    end

    -- Anti-AFK рух (біг + стрибки час від часу)
    if AntiAFK_Enabled then
        AntiAFK_Timer = AntiAFK_Timer + dt
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChild("Humanoid")
        if hum and AntiAFK_Timer >= 4 then
            hum:Move(Vector3.new(1, 0, 0), true)
            hum.Jump = true
            AntiAFK_Timer = 0
        end
    end

    -- Fast Run + керування стрілками
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChild("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    if hum then
        if FastRunEnabled then
            hum.WalkSpeed = math.max(OriginalWalkSpeed * 2, 32)
        else
            hum.WalkSpeed = OriginalWalkSpeed
        end

        -- Рух стрілками
        local moveDir = Vector3.new()
        if ArrowMove.Up then
            moveDir = moveDir + Camera.CFrame.LookVector
        end
        if ArrowMove.Down then
            moveDir = moveDir - Camera.CFrame.LookVector
        end
        if ArrowMove.Left then
            moveDir = moveDir - Camera.CFrame.RightVector
        end
        if ArrowMove.Right then
            moveDir = moveDir + Camera.CFrame.RightVector
        end
        if moveDir.Magnitude > 0 then
            hum:Move(moveDir.Unit * (FastRunEnabled and 2 or 1), true)
        end
    end

    -- Noclip
    if NoclipEnabled and char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    elseif char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.CanCollide = true
            end
        end
    end

    -- Визначення поточної цілі для прицілювання
    local targetToAim = nil
    local isAimbotActive = false

    if AimLockV2Active and AimLockV2Target and AimLockV2Target:FindFirstChild("Humanoid") and AimLockV2Target.Humanoid.Health > 0 then
        targetToAim = AimLockV2Target
        isAimbotActive = true
    elseif Settings.Aim_Enabled and AimingActive then
        if not AimTarget or not AimTarget.Parent or AimTarget:FindFirstChild("Humanoid").Health <= 0 then
            AimTarget = GetTarget(false)
        end
        targetToAim = AimTarget
        isAimbotActive = targetToAim ~= nil
    end

    if isAimbotActive and targetToAim and targetToAim:FindFirstChild("Head") then
        local head = targetToAim.Head
        local targetPos = head.Position
        local currentCF = Camera.CFrame
        local targetCF = CFrame.new(currentCF.Position, targetPos)

        -- РІЗКИЙ AIM
        Camera.CFrame = currentCF:Lerp(targetCF, Settings.AimSpeed)

        local mode = AimLockV2Active and "AIM LOCK V2" or "AIMBOT HOLD"
        TargetLabel.Text = string.format("[%s] TARGET: %s (%.0fm)", mode, targetToAim.Name, (head.Position - Camera.CFrame.Position).Magnitude)
        TargetLabel.TextColor3 = Settings.Color_AimTarget
        TargetPanel.BorderColor3 = Settings.Color_AimTarget

        if Settings.Aim_Enabled and AimingActive then
            FOVCircle.Position = UserInputService:GetMouseLocation()
            FOVCircle.Visible = true
        else
            FOVCircle.Visible = false
        end
    else
        if AimLockV2Active and (not AimLockV2Target or not AimLockV2Target:FindFirstChild("Humanoid") or AimLockV2Target.Humanoid.Health <= 0) then
            AimLockV2Active = false
            AimLockV2Target = nil
            L_AimV2.Text = "[NumPad2] AimLock V2: Target Lost"
            L_AimV2.TextColor3 = Color3.fromRGB(255, 165, 0)
        end

        if not AimLockV2Active then
            AimTarget = nil
            TargetLabel.Text = "Aimbot не активний (J / NumPad2)"
            TargetLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
            TargetPanel.BorderColor3 = Color3.fromRGB(50, 50, 50)
            FOVCircle.Visible = false
        end
    end

    -- Оновлення стрілки напрямку гравця на міні-карті
    local _, Y, _ = Camera.CFrame:ToEulerAnglesYXZ()
    local rotation = math.deg(Y)
    PlayerArrowContainer.Rotation = -rotation
end)

Players.PlayerRemoving:Connect(RemoveVisuals)

print("Xeno Global v5.4 Loaded: Fun keys + multi-team colors.")
