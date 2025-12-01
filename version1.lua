-- Xeno Global v5.4
-- NumPad2 AimLock + Anti-AFK + Fun Pack (Speed, AirJump, Noclip, SpinBot, LowGravity, Dash)
-- Управління дивись в коментарях вище 😉

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")

-- === НАЛАШТУВАННЯ (SETTINGS) ===
local Settings = {
    -- Оптимізація
    ESP_UPDATE_RATE      = 0.07,
    REMOVE_DISTANCE      = 3500,
    MAP_SCALE_FACTOR     = 4,
    MAP_MAX_DOT_DISTANCE = 75,

    -- Основні перемикачі
    ESP_Enabled              = true,
    Aim_Enabled              = false, -- Класичний Aimbot (утримання кнопки)
    Tracers_Enabled          = true,
    Minimap_Visible          = true,
    Fullbright_Enabled       = true,
    ShowTriggerPoints        = false,
    Hitbox_Expansion_Enabled = false,
    TeamRecognition_Enabled  = false,

    -- Аімбот
    AimKey          = Enum.UserInputType.MouseButton2,
    AimSpeed        = 0.9,                               -- РІЗКИЙ AIM
    AimFOV          = 200,
    FOV_Circle_Color= Color3.fromRGB(255, 255, 255),

    -- Hitbox
    Hitbox_Expansion_Factor = 0.2,

    -- Кольори
    HeadColor_Static = Color3.fromRGB(128, 0, 128),  -- ФІОЛЕТОВИЙ (хед)
    Color_Visible    = Color3.fromRGB(0, 255, 0),    -- ЗЕЛЕНИЙ
    Color_Hidden     = Color3.fromRGB(255, 0, 0),    -- ЧЕРВОНИЙ
    Color_AimTarget  = Color3.fromRGB(255, 215, 0),  -- ЗОЛОТИЙ
    Color_Bot        = Color3.fromRGB(255, 165, 0),  -- ПОМАРАНЧЕВИЙ (боти)

    -- Клавіші
    Key_ToggleESP       = Enum.KeyCode.RightAlt,
    Key_ToggleAim       = Enum.KeyCode.J,
    Key_ToggleMap       = Enum.KeyCode.M,
    Key_ToggleTracers   = Enum.KeyCode.T,
    Key_Reconnect       = Enum.KeyCode.Period,
    Key_TogglePoints    = Enum.KeyCode.Comma,
    Key_ToggleHitbox    = Enum.KeyCode.P,
    Key_ToggleTeam      = Enum.KeyCode.KeypadOne,

    -- Aim Lock V2
    Key_ToggleAimLockV2    = Enum.KeyCode.KeypadTwo,  -- NumPad2
    Key_ToggleAimLockV2Alt = Enum.KeyCode.KeypadZero, -- NumPad0

    -- Anti AFK
    Key_ToggleAntiAFK   = Enum.KeyCode.KeypadThree,   -- NumPad3

    -- FUN клавіші NumPad
    Key_ToggleFastRun   = Enum.KeyCode.KeypadFour,    -- NumPad4
    Key_ToggleAirJump   = Enum.KeyCode.KeypadFive,    -- NumPad5
    Key_ToggleNoclip    = Enum.KeyCode.KeypadSix,     -- NumPad6
    Key_ToggleSpinBot   = Enum.KeyCode.KeypadSeven,   -- NumPad7
    Key_ToggleLowGrav   = Enum.KeyCode.KeypadEight,   -- NumPad8
    Key_ToggleFunPack   = Enum.KeyCode.KeypadNine,    -- NumPad9

    -- Клавіші блоку керування
    Key_ToggleHUD       = Enum.KeyCode.Insert,
    Key_PanicOff        = Enum.KeyCode.Delete,
    Key_TeleportUp      = Enum.KeyCode.Home,
    Key_ResetMovement   = Enum.KeyCode.End,
    Key_AimFOV_Up       = Enum.KeyCode.PageUp,
    Key_AimFOV_Down     = Enum.KeyCode.PageDown,
}

-- Частини тіла
local R15_PARTS = {"Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg"}
local R6_PARTS  = {"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}

-- === СТАН СКРИПТА ===
local Visuals = {}
local AimTarget = nil            -- для Aimbot Hold
local AimingActive = false
local AimLockV2Active = false
local AimLockV2Target = nil
local AntiAFK_Enabled = false
local AntiAFK_Timer = 0
local lastESPUpdate = 0

local FastRun_Enabled   = false
local AirJump_Enabled   = false
local Noclip_Enabled    = false
local SpinBot_Enabled   = false
local LowGrav_Enabled   = false

local OriginalWalkSpeed = 16
local DefaultGravity    = workspace.Gravity

local HUD_Visible = true

-- FOV Circle
local FOVCircle = Drawing.new("Circle")
FOVCircle.Radius = Settings.AimFOV
FOVCircle.Color = Settings.FOV_Circle_Color
FOVCircle.Thickness = 2
FOVCircle.Transparency = 0.7
FOVCircle.Visible = false

-- === UI STATUS PANEL ===
local CoreGui = game:GetService("CoreGui")
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "XenoOverlay"
ScreenGui.Parent = CoreGui

local StatusFrame = Instance.new("Frame")
StatusFrame.Position = UDim2.new(0, 20, 0, 20)
StatusFrame.Size = UDim2.new(0, 240, 0, 320)
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

local L_ESP      = CreateStatusLabel("[RightAlt] ESP: ON")
local L_Aim      = CreateStatusLabel("[J] Aimbot Hold: OFF")
local L_AimV2    = CreateStatusLabel("[NumPad2] AimLock V2: OFF")
local L_AntiAFK  = CreateStatusLabel("[NumPad3] Anti-AFK: OFF")
local L_FastRun  = CreateStatusLabel("[NumPad4] Speed: OFF")
local L_AirJump  = CreateStatusLabel("[NumPad5] AirJump: OFF")
local L_Noclip   = CreateStatusLabel("[NumPad6] Noclip: OFF")
local L_Spin     = CreateStatusLabel("[NumPad7] SpinBot: OFF")
local L_LowGrav  = CreateStatusLabel("[NumPad8] LowGravity: OFF")
local L_Map      = CreateStatusLabel("[M] Minimap: ON")
local L_Trace    = CreateStatusLabel("[T] Tracers: ON")
local L_Points   = CreateStatusLabel("[<] Points: OFF")
local L_Hitbox   = CreateStatusLabel("[O] Hitbox Exp: OFF")
local L_Team     = CreateStatusLabel("[NumPad1] Team Rec: OFF")
local L_Reconnect= CreateStatusLabel("[.] Reconnect: Ready")

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

-- Панель цілі аімбота
local TargetPanel = Instance.new("Frame")
TargetPanel.Name = "AimTargetPanel"
TargetPanel.Size = UDim2.new(0, 250, 0, 25)
TargetPanel.Position = UDim2.new(0.5, -125, 0, 5)
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

-- === ФУНКЦІЇ ===
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

local function UpdateVisuals()
    local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end

    local targets = {}
    local currentKeys = {}
    local expansion = Settings.Hitbox_Expansion_Enabled and (1 + Settings.Hitbox_Expansion_Factor) or 1

    -- Гравці
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            targets[p] = p.Character
            currentKeys[p] = true
        end
    end

    -- Боти
    for _, child in ipairs(workspace:GetChildren()) do
        if child:IsA("Model") and child:FindFirstChild("Humanoid") and child:FindFirstChild("HumanoidRootPart") then
            local p = Players:GetPlayerFromCharacter(child)
            if not p and child ~= LocalPlayer.Character then
                targets[child] = child
                currentKeys[child] = true
            end
        end
    end

    -- Очистка
    for key,_ in pairs(Visuals) do
        if not currentKeys[key] then
            RemoveVisuals(key)
        end
    end

    -- Обробка цілей
    for key,char in pairs(targets) do
        local player = Players:GetPlayerFromCharacter(char)
        local isBot = player == nil

        local v = Visuals[key]
        local hrp = char.HumanoidRootPart
        local head = char:FindFirstChild("Head")
        local hum  = char:FindFirstChild("Humanoid")

        if not head or not hum or hum.Health <= 0 then
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

        local visible   = IsVisible(char)
        local isEnabled = Settings.ESP_Enabled

        local mainColor
        local headColorToUse
        local isTeamate = false

        if isBot then
            headColorToUse = Settings.Color_Bot
            mainColor      = Settings.Color_Bot
        else
            if player then
                local isSameTeam = (LocalPlayer.Team and player.Team and LocalPlayer.Team == player.Team)
                    or (LocalPlayer.TeamColor and player.TeamColor and LocalPlayer.TeamColor == player.TeamColor)
                isTeamate = isSameTeam
            end

            if Settings.TeamRecognition_Enabled and isTeamate then
                mainColor      = Settings.HeadColor_Static
                headColorToUse = Settings.HeadColor_Static
            else
                mainColor      = visible and Settings.Color_Visible or Settings.Color_Hidden
                headColorToUse = visible and Settings.HeadColor_Static or Settings.Color_Hidden
            end
        end

        local isCurrentTarget = (AimTarget == char) or (AimLockV2Target == char)
        if isCurrentTarget then
            headColorToUse = Settings.Color_AimTarget
        end

        -- Голова
        if not v.HeadAdornment then
            local h = Instance.new("CylinderHandleAdornment")
            h.Height = 1.1; h.Radius = 0.6; h.CFrame = CFrame.Angles(math.rad(90),0,0)
            h.AlwaysOnTop = true; h.Transparency = 0.4; h.ZIndex = 5
            h.Parent = ScreenGui; v.HeadAdornment = h
        end
        v.HeadAdornment.Adornee   = head
        v.HeadAdornment.Radius    = 0.6 * expansion
        v.HeadAdornment.Height    = 1.1 * expansion
        v.HeadAdornment.Color3    = headColorToUse
        v.HeadAdornment.Visible   = isEnabled and HUD_Visible

        -- Тіло
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
                v.BoxParts[partName].Size    = part.Size * expansion
                v.BoxParts[partName].Color3  = mainColor
                v.BoxParts[partName].Visible = isEnabled and HUD_Visible
            else
                if v.BoxParts[partName] then v.BoxParts[partName].Visible = false end
            end
        end

        -- Триггер-точки (можна розширити тут, якщо треба)
        if Settings.ShowTriggerPoints then
            for _, p in pairs(v.TriggerPoints) do p.Visible = true end
        else
            for _, p in pairs(v.TriggerPoints) do p.Visible = false end
        end

        -- Текст
        v.InfoGUI.Enabled = isEnabled and HUD_Visible
        v.InfoGUI.Adornee = head

        local teamPrefix = ""
        if isBot then
            teamPrefix = string.format("<font color=\"rgb(%d, %d, %d)\"><b>БОТ | </b></font>",
                Settings.Color_Bot.R*255, Settings.Color_Bot.G*255, Settings.Color_Bot.B*255)
        elseif isTeamate and Settings.TeamRecognition_Enabled then
            teamPrefix = string.format("<font color=\"rgb(%d, %d, %d)\"><b>СВІЙ | </b></font>",
                Settings.HeadColor_Static.R*255, Settings.HeadColor_Static.G*255, Settings.HeadColor_Static.B*255)
        end

        v.NameLabel.RichText   = true
        v.NameLabel.Text       = teamPrefix .. (isBot and char.Name or player.Name)
        v.NameLabel.TextColor3 = isBot and Settings.Color_Bot or mainColor

        local currentHP = math.floor(hum.Health)
        local maxHP     = math.floor(hum.MaxHealth)
        v.StatsLabel.Text = string.format("[ %d / %d HP ] [ %dm ]", currentHP, maxHP, math.floor(dist))

        -- Мінімпа
        if Settings.Minimap_Visible and HUD_Visible then
            local rel = hrp.Position - myHRP.Position
            local angleToTarget = math.atan2(rel.X, rel.Z)
            local mDist = math.clamp(dist / Settings.MAP_SCALE_FACTOR, 0, Settings.MAP_MAX_DOT_DISTANCE)
            if mDist < Settings.MAP_MAX_DOT_DISTANCE then
                local x = math.sin(angleToTarget) * mDist
                local y = math.cos(angleToTarget) * mDist
                v.MapDot.Position = UDim2.new(0.5, x - 2, 0.5, -y - 2)
                v.MapDot.Visible  = true
                v.MapDot.BackgroundColor3 = isBot and Settings.Color_Bot or mainColor
            else
                v.MapDot.Visible = false
            end
        else
            v.MapDot.Visible = false
        end

        -- Трейсери
        if Settings.Tracers_Enabled and HUD_Visible then
            local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            if onScreen and isEnabled then
                v.Tracer.From   = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
                v.Tracer.To     = Vector2.new(screenPos.X, screenPos.Y)
                v.Tracer.Color  = isBot and Settings.Color_Bot or mainColor
                v.Tracer.Visible= true
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

-- Anti-AFK (click)
Players.LocalPlayer.Idled:Connect(function()
    if AntiAFK_Enabled then
        VirtualUser:Button2Down(Vector2.new(0, 0), Camera.CFrame)
        task.wait(0.1)
        VirtualUser:Button2Up(Vector2.new(0, 0), Camera.CFrame)
    end
end)

-- === INPUT ===
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end

    -- Тогли ESP / AIM / HUD
    if input.KeyCode == Settings.Key_ToggleESP then
        Settings.ESP_Enabled = not Settings.ESP_Enabled
        L_ESP.Text = Settings.ESP_Enabled and "[RightAlt] ESP: ON" or "[RightAlt] ESP: OFF"
        L_ESP.TextColor3 = Settings.ESP_Enabled and Color3.new(0,1,0) or Color3.new(1,0,0)

    elseif input.KeyCode == Settings.Key_ToggleAim then
        Settings.Aim_Enabled = not Settings.Aim_Enabled
        L_Aim.Text = Settings.Aim_Enabled and "[J] Aimbot Hold: ON" or "[J] Aimbot Hold: OFF"
        L_Aim.TextColor3 = Settings.Aim_Enabled and Color3.new(0,1,0) or Color3.new(1,0,0)

    -- AimLock V2 (NumPad2 / NumPad0)
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
                L_AimV2.TextColor3 = Color3.fromRGB(255,165,0)
                AimLockV2Active = false
                AimLockV2Target = nil
            end
        end

    -- Anti-AFK (NumPad3)
    elseif input.KeyCode == Settings.Key_ToggleAntiAFK then
        AntiAFK_Enabled = not AntiAFK_Enabled
        L_AntiAFK.Text = AntiAFK_Enabled and "[NumPad3] Anti-AFK: ON" or "[NumPad3] Anti-AFK: OFF"
        L_AntiAFK.TextColor3 = AntiAFK_Enabled and Color3.new(0,1,0) or Color3.new(1,0,0)

    -- FastRun (NumPad4)
    elseif input.KeyCode == Settings.Key_ToggleFastRun then
        FastRun_Enabled = not FastRun_Enabled
        L_FastRun.Text = FastRun_Enabled and "[NumPad4] Speed: ON" or "[NumPad4] Speed: OFF"
        L_FastRun.TextColor3 = FastRun_Enabled and Color3.new(0,1,0) or Color3.new(1,0,0)

    -- AirJump (NumPad5)
    elseif input.KeyCode == Settings.Key_ToggleAirJump then
        AirJump_Enabled = not AirJump_Enabled
        L_AirJump.Text = AirJump_Enabled and "[NumPad5] AirJump: ON" or "[NumPad5] AirJump: OFF"
        L_AirJump.TextColor3 = AirJump_Enabled and Color3.new(0,1,0) or Color3.new(1,0,0)

    -- Noclip (NumPad6)
    elseif input.KeyCode == Settings.Key_ToggleNoclip then
        Noclip_Enabled = not Noclip_Enabled
        L_Noclip.Text = Noclip_Enabled and "[NumPad6] Noclip: ON" or "[NumPad6] Noclip: OFF"
        L_Noclip.TextColor3 = Noclip_Enabled and Color3.new(0,1,0) or Color3.new(1,0,0)

    -- SpinBot (NumPad7)
    elseif input.KeyCode == Settings.Key_ToggleSpinBot then
        SpinBot_Enabled = not SpinBot_Enabled
        L_Spin.Text = SpinBot_Enabled and "[NumPad7] SpinBot: ON" or "[NumPad7] SpinBot: OFF"
        L_Spin.TextColor3 = SpinBot_Enabled and Color3.new(0,1,0) or Color3.new(1,0,0)

    -- LowGravity (NumPad8)
    elseif input.KeyCode == Settings.Key_ToggleLowGrav then
        LowGrav_Enabled = not LowGrav_Enabled
        L_LowGrav.Text = LowGrav_Enabled and "[NumPad8] LowGravity: ON" or "[NumPad8] LowGravity: OFF"
        L_LowGrav.TextColor3 = LowGrav_Enabled and Color3.new(0,1,0) or Color3.new(1,0,0)

    -- FunPack (NumPad9) – все разом
    elseif input.KeyCode == Settings.Key_ToggleFunPack then
        local newState = not (FastRun_Enabled and AirJump_Enabled and Noclip_Enabled)
        FastRun_Enabled = newState
        AirJump_Enabled = newState
        Noclip_Enabled  = newState

        L_FastRun.Text = FastRun_Enabled and "[NumPad4] Speed: ON" or "[NumPad4] Speed: OFF"
        L_FastRun.TextColor3 = FastRun_Enabled and Color3.new(0,1,0) or Color3.new(1,0,0)
        L_AirJump.Text = AirJump_Enabled and "[NumPad5] AirJump: ON" or "[NumPad5] AirJump: OFF"
        L_AirJump.TextColor3 = AirJump_Enabled and Color3.new(0,1,0) or Color3.new(1,0,0)
        L_Noclip.Text = Noclip_Enabled and "[NumPad6] Noclip: ON" or "[NumPad6] Noclip: OFF"
        L_Noclip.TextColor3 = Noclip_Enabled and Color3.new(0,1,0) or Color3.new(1,0,0)

    elseif input.KeyCode == Settings.Key_ToggleMap then
        Settings.Minimap_Visible = not Settings.Minimap_Visible
        MapFrame.Visible = Settings.Minimap_Visible and HUD_Visible
        L_Map.Text = Settings.Minimap_Visible and "[M] Minimap: ON" or "[M] Minimap: OFF"

    elseif input.KeyCode == Settings.Key_ToggleTracers then
        Settings.Tracers_Enabled = not Settings.Tracers_Enabled
        L_Trace.Text = Settings.Tracers_Enabled and "[T] Tracers: ON" or "[T] Tracers: OFF"

    elseif input.KeyCode == Settings.Key_TogglePoints then
        Settings.ShowTriggerPoints = not Settings.ShowTriggerPoints
        L_Points.Text = Settings.ShowTriggerPoints and "[<] Points: ON" or "[<] Points: OFF"
        L_Points.TextColor3 = Settings.ShowTriggerPoints and Color3.new(0,1,0) or Color3.new(1,0,0)

    elseif input.KeyCode == Settings.Key_ToggleHitbox then
        Settings.Hitbox_Expansion_Enabled = not Settings.Hitbox_Expansion_Enabled
        L_Hitbox.Text = Settings.Hitbox_Expansion_Enabled and "[O] Hitbox Exp: ON" or "[O] Hitbox Exp: OFF"
        L_Hitbox.TextColor3 = Settings.Hitbox_Expansion_Enabled and Color3.new(0,1,0) or Color3.new(1,0,0)

    elseif input.KeyCode == Settings.Key_ToggleTeam then
        Settings.TeamRecognition_Enabled = not Settings.TeamRecognition_Enabled
        L_Team.Text = Settings.TeamRecognition_Enabled and "[NumPad1] Team Rec: ON" or "[NumPad1] Team Rec: OFF"
        L_Team.TextColor3 = Settings.TeamRecognition_Enabled and Color3.new(0,1,0) or Color3.new(1,0,0)

    elseif input.KeyCode == Settings.Key_Reconnect then
        Reconnect()

    -- HUD ON/OFF (Insert)
    elseif input.KeyCode == Settings.Key_ToggleHUD then
        HUD_Visible = not HUD_Visible
        ScreenGui.Enabled = HUD_Visible
        -- FOVCircle окремо, бо це Drawing
        if not HUD_Visible then
            FOVCircle.Visible = false
        end

    -- PANIC OFF (Delete)
    elseif input.KeyCode == Settings.Key_PanicOff then
        Settings.Aim_Enabled          = false
        AimLockV2Active               = false
        AimLockV2Target               = nil
        AntiAFK_Enabled               = false
        FastRun_Enabled               = false
        AirJump_Enabled               = false
        Noclip_Enabled                = false
        SpinBot_Enabled               = false
        LowGrav_Enabled               = false

        L_Aim.Text      = "[J] Aimbot Hold: OFF"
        L_Aim.TextColor3= Color3.new(1,0,0)
        L_AimV2.Text    = "[NumPad2] AimLock V2: OFF"
        L_AimV2.TextColor3 = Color3.new(1,0,0)
        L_AntiAFK.Text  = "[NumPad3] Anti-AFK: OFF"
        L_AntiAFK.TextColor3 = Color3.new(1,0,0)
        L_FastRun.Text  = "[NumPad4] Speed: OFF"
        L_FastRun.TextColor3 = Color3.new(1,0,0)
        L_AirJump.Text  = "[NumPad5] AirJump: OFF"
        L_AirJump.TextColor3 = Color3.new(1,0,0)
        L_Noclip.Text   = "[NumPad6] Noclip: OFF"
        L_Noclip.TextColor3 = Color3.new(1,0,0)
        L_Spin.Text     = "[NumPad7] SpinBot: OFF"
        L_Spin.TextColor3 = Color3.new(1,0,0)
        L_LowGrav.Text  = "[NumPad8] LowGravity: OFF"
        L_LowGrav.TextColor3 = Color3.new(1,0,0)

        workspace.Gravity = DefaultGravity
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
        if hum then hum.WalkSpeed = OriginalWalkSpeed end

    -- Home: трошки підняти гравця
    elseif input.KeyCode == Settings.Key_TeleportUp then
        local char = LocalPlayer.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = hrp.CFrame + Vector3.new(0, 5, 0)
        end

    -- End: скинути гравітацію та швидкість
    elseif input.KeyCode == Settings.Key_ResetMovement then
        workspace.Gravity = DefaultGravity
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
        if hum then
            hum.WalkSpeed = OriginalWalkSpeed
        end
        LowGrav_Enabled = false
        L_LowGrav.Text = "[NumPad8] LowGravity: OFF"
        L_LowGrav.TextColor3 = Color3.new(1,0,0)

    -- PageUp / PageDown: FOV +
    elseif input.KeyCode == Settings.Key_AimFOV_Up then
        Settings.AimFOV = math.clamp(Settings.AimFOV + 25, 25, 600)
        FOVCircle.Radius = Settings.AimFOV

    elseif input.KeyCode == Settings.Key_AimFOV_Down then
        Settings.AimFOV = math.clamp(Settings.AimFOV - 25, 25, 600)
        FOVCircle.Radius = Settings.AimFOV
    end

    -- Dash на стрілках
    if input.KeyCode == Enum.KeyCode.Up or input.KeyCode == Enum.KeyCode.Down
        or input.KeyCode == Enum.KeyCode.Left or input.KeyCode == Enum.KeyCode.Right then

        local char = LocalPlayer.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local cf = Camera.CFrame
            local dir = Vector3.new()
            if input.KeyCode == Enum.KeyCode.Up then
                dir = cf.LookVector
            elseif input.KeyCode == Enum.KeyCode.Down then
                dir = -cf.LookVector
            elseif input.KeyCode == Enum.KeyCode.Left then
                dir = -cf.RightVector
            elseif input.KeyCode == Enum.KeyCode.Right then
                dir = cf.RightVector
            end
            hrp.CFrame = hrp.CFrame + dir * 6
        end
    end

    -- Aimbot Hold
    if input.UserInputType == Settings.AimKey and Settings.Aim_Enabled then
        AimingActive = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Settings.AimKey then
        AimingActive = false
        AimTarget = nil
    end
end)

-- AirJump через JumpRequest
UserInputService.JumpRequest:Connect(function()
    if AirJump_Enabled then
        local char = LocalPlayer.Character
        local hum  = char and char:FindFirstChild("Humanoid")
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- === ГОЛОВНИЙ ЦИКЛ ===
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

    -- Запам'ятати дефолтний WalkSpeed
    local char = LocalPlayer.Character
    local hum  = char and char:FindFirstChild("Humanoid")
    if hum and OriginalWalkSpeed == 16 and hum.WalkSpeed ~= 0 then
        OriginalWalkSpeed = hum.WalkSpeed
    end

    -- Anti-AFK рух
    if AntiAFK_Enabled then
        AntiAFK_Timer = AntiAFK_Timer + dt
        if hum and AntiAFK_Timer >= 4 then
            hum:Move(Vector3.new(1, 0, 0), true)
            hum.Jump = true
            AntiAFK_Timer = 0
        end
    end

    -- FastRun
    if hum then
        if FastRun_Enabled then
            hum.WalkSpeed = OriginalWalkSpeed * 2.5
        else
            hum.WalkSpeed = OriginalWalkSpeed
        end
    end

    -- Low Gravity
    if LowGrav_Enabled then
        workspace.Gravity = 40
    else
        workspace.Gravity = DefaultGravity
    end

    -- Noclip
    if Noclip_Enabled and char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end

    -- SpinBot
    if SpinBot_Enabled then
        local cf = Camera.CFrame
        Camera.CFrame = cf * CFrame.Angles(0, math.rad(3), 0)
    end

    -- Aimbot логіка
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

        Camera.CFrame = currentCF:Lerp(targetCF, Settings.AimSpeed)

        local mode = AimLockV2Active and "AIM LOCK V2" or "AIMBOT HOLD"
        TargetLabel.Text = string.format("[%s] TARGET: %s (%.0fm)", mode, targetToAim.Name, (head.Position - Camera.CFrame.Position).Magnitude)
        TargetLabel.TextColor3 = Settings.Color_AimTarget
        TargetPanel.BorderColor3 = Settings.Color_AimTarget

        if Settings.Aim_Enabled and AimingActive and HUD_Visible then
            FOVCircle.Position = UserInputService:GetMouseLocation()
            FOVCircle.Visible  = true
        else
            FOVCircle.Visible  = false
        end
    else
        if AimLockV2Active and (not AimLockV2Target or not AimLockV2Target:FindFirstChild("Humanoid") or AimLockV2Target.Humanoid.Health <= 0) then
            AimLockV2Active = false
            AimLockV2Target = nil
            L_AimV2.Text = "[NumPad2] AimLock V2: Target Lost"
            L_AimV2.TextColor3 = Color3.fromRGB(255,165,0)
        end

        if not AimLockV2Active then
            AimTarget = nil
            TargetLabel.Text = "Aimbot не активний (J / NumPad2)"
            TargetLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
            TargetPanel.BorderColor3 = Color3.fromRGB(50, 50, 50)
            FOVCircle.Visible = false
        end
    end

    -- Стрілка напряму на міні-карті
    local _, Y, _ = Camera.CFrame:ToEulerAnglesYXZ()
    PlayerArrowContainer.Rotation = -math.deg(Y)
end)

Players.PlayerRemoving:Connect(RemoveVisuals)

print("Xeno Global v5.4 Loaded: Full NumPad Fun Pack.")
