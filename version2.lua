-- Xeno Global v5.4
-- NumPad2 AimLock, Anti-AFK, Spinbot, RGB ESP, SpeedBoost, SuperJump, Fun Keys
-- Примітка: Fn неможливо зловити в Roblox, тому вона не використовується.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local CoreGui = game:GetService("CoreGui")

-- === НАЛАШТУВАННЯ (SETTINGS) ===
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
    AimSpeed = 0.9, -- РІЗКИЙ Lerp
    AimFOV = 200,
    FOV_Circle_Color = Color3.fromRGB(255, 255, 255),

    -- Hitbox
    Hitbox_Expansion_Factor = 0.2,

    -- Кольори
    HeadColor_Static = Color3.fromRGB(128, 0, 128), -- Фіолетовий (свій / голова)
    Color_Visible = Color3.fromRGB(0, 255, 0),      -- Зелений (тіло видно)
    Color_Hidden = Color3.fromRGB(255, 0, 0),       -- Червоний (за стіною)
    Color_AimTarget = Color3.fromRGB(255, 215, 0),  -- Золотий (ціль аімбота)
    Color_Bot = Color3.fromRGB(255, 165, 0),        -- Помаранчевий (боти)

    -- Клавіші (старі)
    Key_ToggleESP   = Enum.KeyCode.RightAlt,
    Key_ToggleAim   = Enum.KeyCode.J,
    Key_ToggleMap   = Enum.KeyCode.M,
    Key_ToggleTracers = Enum.KeyCode.T,
    Key_Reconnect   = Enum.KeyCode.Period,
    Key_TogglePoints = Enum.KeyCode.Comma,
    Key_ToggleHitbox = Enum.KeyCode.P,
    Key_ToggleTeam  = Enum.KeyCode.KeypadOne,

    -- Aim Lock V2
    Key_ToggleAimLockV2    = Enum.KeyCode.KeypadTwo, -- NumPad2
    Key_ToggleAimLockV2Alt = Enum.KeyCode.KeypadZero,

    -- Anti AFK
    Key_ToggleAntiAFK = Enum.KeyCode.KeypadThree,   -- NumPad3

    -- НОВІ ФАНОВІ КЛАВІШІ (NumPad + спец)
    Key_ToggleSpinbot     = Enum.KeyCode.KeypadFour,  -- NumPad4
    Key_ToggleShakeCam    = Enum.KeyCode.KeypadFive,  -- NumPad5
    Key_ToggleRainbowESP  = Enum.KeyCode.KeypadSix,   -- NumPad6
    Key_ToggleSpeedBoost  = Enum.KeyCode.KeypadSeven, -- NumPad7
    Key_ToggleSuperJump   = Enum.KeyCode.KeypadEight, -- NumPad8

    Key_ToggleFullbright  = Enum.KeyCode.Home,        -- Fullbright ON/OFF
    Key_ToggleUI          = Enum.KeyCode.Insert,      -- Показати/сховати UI
    Key_Panic             = Enum.KeyCode.Delete,      -- Все викл + очистка
    Key_AimFOV_Up         = Enum.KeyCode.PageUp,      -- +FOV
    Key_AimFOV_Down       = Enum.KeyCode.PageDown,    -- -FOV
    -- End використаємо без окремого Settings (разовий блинк)
}

-- === ЗМІННІ СКРИПТА ===
local Visuals = {}
local AimTarget = nil           -- Ціль для класичного Aimbot (утримання)
local AimingActive = false      -- Класичний Aimbot активний
local AimLockV2Active = false   -- Aim Lock V2 активний
local AimLockV2Target = nil     -- Ціль для Aim Lock V2

local AntiAFK_Enabled = false
local AntiAFK_Timer = 0

local Spinbot_Enabled = false
local ShakeCam_Enabled = false
local RainbowESP_Enabled = false
local SpeedBoost_Enabled = false
local SuperJump_Enabled = false

local OriginalWalkSpeed = nil
local OriginalJumpPower = nil

local lastESPUpdate = 0

local FOVCircle = Drawing.new("Circle")
FOVCircle.Radius = Settings.AimFOV
FOVCircle.Color = Settings.FOV_Circle_Color
FOVCircle.Thickness = 2
FOVCircle.Transparency = 0.7
FOVCircle.Visible = false

local R15_PARTS = {"Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg"}
local R6_PARTS  = {"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}

-- === UI STATUS PANEL ===
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "XenoOverlay"
ScreenGui.Parent = CoreGui

local StatusFrame = Instance.new("Frame")
StatusFrame.Position = UDim2.new(0, 20, 0, 20)
StatusFrame.Size = UDim2.new(0, 230, 0, 280)
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
local L_Map      = CreateStatusLabel("[M] Minimap: ON")
local L_Trace    = CreateStatusLabel("[T] Tracers: ON")
local L_Points   = CreateStatusLabel("[<] Points: OFF")
local L_Hitbox   = CreateStatusLabel("[O] Hitbox Exp: OFF")
local L_Team     = CreateStatusLabel("[NumPad1] Team Rec: OFF")
local L_Spin     = CreateStatusLabel("[NumPad4] Spinbot: OFF")
local L_Shake    = CreateStatusLabel("[NumPad5] ShakeCam: OFF")
local L_Rainbow  = CreateStatusLabel("[NumPad6] RGB ESP: OFF")
local L_Speed    = CreateStatusLabel("[NumPad7] SpeedBoost: OFF")
local L_Jump     = CreateStatusLabel("[NumPad8] SuperJump: OFF")
local L_FBright  = CreateStatusLabel("[Home] Fullbright: ON")
local L_UIVis    = CreateStatusLabel("[Ins] UI Visible: ON")
local L_Reconnect= CreateStatusLabel("[>] Reconnect: Ready")

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

-- Перевірка видимості
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

-- Billboard для ніку/статистики
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

-- Трейсер
local function CreateTracer()
    local line = Drawing.new("Line")
    line.Visible = false
    line.Color = Color3.new(1, 1, 1)
    line.Thickness = 1.5
    line.Transparency = 0.3
    return line
end

-- Очистка візуалу
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

-- Оновлення ESP / мапи / трейсерів / кольорів
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

    -- Боти (Model з Humanoid, але без Player)
    for _, child in ipairs(workspace:GetChildren()) do
        if child:IsA("Model") and child:FindFirstChild("Humanoid") and child:FindFirstChild("HumanoidRootPart") then
            local p = Players:GetPlayerFromCharacter(child)
            if not p and child ~= LocalPlayer.Character then
                targets[child] = child
                currentKeys[child] = true
            end
        end
    end

    -- Очистка зниклих
    for key,_ in pairs(Visuals) do
        if not currentKeys[key] then
            RemoveVisuals(key)
        end
    end

    -- Обробка цілей
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
                BoxParts = {}, HeadAdornment = nil, MapDot = nil,
                Tracer = CreateTracer(), TriggerPoints = {}
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
            else
                mainColor = visible and Settings.Color_Visible or Settings.Color_Hidden
                headColorToUse = visible and Settings.HeadColor_Static or Settings.Color_Hidden
            end
        end

        local isCurrentTarget = (AimTarget == char) or (AimLockV2Target == char)
        if isCurrentTarget then
            headColorToUse = Settings.Color_AimTarget
        end

        -- RGB ESP (тільки для ворогів, не ботів, не поточного таргета)
        if RainbowESP_Enabled and (not isBot) and (not isCurrentTarget) then
            local hsvColor = Color3.fromHSV((tick() * 0.2) % 1, 1, 1)
            mainColor = hsvColor
        end

        -- Голова
        if not v.HeadAdornment then
            local h = Instance.new("CylinderHandleAdornment")
            h.Height = 1.1
            h.Radius = 0.6
            h.CFrame = CFrame.Angles(math.rad(90), 0, 0)
            h.AlwaysOnTop = true
            h.Transparency = 0.4
            h.ZIndex = 5
            h.Parent = ScreenGui
            v.HeadAdornment = h
        end
        v.HeadAdornment.Adornee = head
        v.HeadAdornment.Radius = 0.6 * expansion
        v.HeadAdornment.Height = 1.1 * expansion
        v.HeadAdornment.Color3 = headColorToUse
        v.HeadAdornment.Visible = isEnabled

        -- Тіло
        local limbs = char.Humanoid.RigType == Enum.HumanoidRigType.R15 and R15_PARTS or R6_PARTS
        for _, partName in ipairs(limbs) do
            local part = char:FindFirstChild(partName)
            if part and part.Name ~= "Head" and part.Name ~= "HumanoidRootPart" then
                if not v.BoxParts[partName] then
                    local b = Instance.new("BoxHandleAdornment")
                    b.Adornee = part
                    b.AlwaysOnTop = true
                    b.Transparency = 0.6
                    b.ZIndex = 1
                    b.Parent = ScreenGui
                    v.BoxParts[partName] = b
                end
                v.BoxParts[partName].Adornee = part
                v.BoxParts[partName].Size = part.Size * expansion
                v.BoxParts[partName].Color3 = mainColor
                v.BoxParts[partName].Visible = isEnabled
            else
                if v.BoxParts[partName] then
                    v.BoxParts[partName].Visible = false
                end
            end
        end

        -- Точки видимості (можна розширити при бажанні)
        if Settings.ShowTriggerPoints then
            for _, p in pairs(v.TriggerPoints) do
                p.Visible = true
            end
        else
            for _, p in pairs(v.TriggerPoints) do
                p.Visible = false
            end
        end

        -- Текст / нік / HP / дистанція
        v.InfoGUI.Enabled = isEnabled
        v.InfoGUI.Adornee = head

        local teamPrefix = ""
        if isBot then
            teamPrefix = string.format(
                "<font color=\"rgb(%d, %d, %d)\"><b>БОТ | </b></font>",
                Settings.Color_Bot.R*255, Settings.Color_Bot.G*255, Settings.Color_Bot.B*255
            )
        elseif isTeamate and Settings.TeamRecognition_Enabled then
            teamPrefix = string.format(
                "<font color=\"rgb(%d, %d, %d)\"><b>СВІЙ | </b></font>",
                Settings.HeadColor_Static.R*255,
                Settings.HeadColor_Static.G*255,
                Settings.HeadColor_Static.B*255
            )
        end

        v.NameLabel.RichText = true
        v.NameLabel.Text = teamPrefix .. (isBot and char.Name or player.Name)
        v.NameLabel.TextColor3 = isBot and Settings.Color_Bot or mainColor

        local currentHP = math.floor(hum.Health)
        local maxHP = math.floor(hum.MaxHealth)
        v.StatsLabel.Text = string.format("[ %d / %d HP ] [ %dm ]", currentHP, maxHP, math.floor(dist))

        -- Міні-карта
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

        -- Трейсери
        if Settings.Tracers_Enabled then
            local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            if onScreen and isEnabled then
                v.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                v.Tracer.To   = Vector2.new(screenPos.X, screenPos.Y)
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

-- Пошук таргета в FOV
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

-- Anti-AFK: VirtualUser клік
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

    -- Anti AFK (NumPad3)
    elseif input.KeyCode == Settings.Key_ToggleAntiAFK then
        AntiAFK_Enabled = not AntiAFK_Enabled
        L_AntiAFK.Text = AntiAFK_Enabled and "[NumPad3] Anti-AFK: ON" or "[NumPad3] Anti-AFK: OFF"
        L_AntiAFK.TextColor3 = AntiAFK_Enabled and Color3.new(0,1,0) or Color3.new(1,0,0)

    -- Мінімпа / трейсер / точки / хитбокс / команда / реконект
    elseif input.KeyCode == Settings.Key_ToggleMap then
        Settings.Minimap_Visible = not Settings.Minimap_Visible
        MapFrame.Visible = Settings.Minimap_Visible
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

    -- НОВІ ФУНКЦІЇ NUMPAD
    elseif input.KeyCode == Settings.Key_ToggleSpinbot then
        Spinbot_Enabled = not Spinbot_Enabled
        L_Spin.Text = Spinbot_Enabled and "[NumPad4] Spinbot: ON" or "[NumPad4] Spinbot: OFF"
        L_Spin.TextColor3 = Spinbot_Enabled and Color3.new(0,1,0) or Color3.new(1,0,0)

    elseif input.KeyCode == Settings.Key_ToggleShakeCam then
        ShakeCam_Enabled = not ShakeCam_Enabled
        L_Shake.Text = ShakeCam_Enabled and "[NumPad5] ShakeCam: ON" or "[NumPad5] ShakeCam: OFF"
        L_Shake.TextColor3 = ShakeCam_Enabled and Color3.new(0,1,0) or Color3.new(1,0,0)

    elseif input.KeyCode == Settings.Key_ToggleRainbowESP then
        RainbowESP_Enabled = not RainbowESP_Enabled
        L_Rainbow.Text = RainbowESP_Enabled and "[NumPad6] RGB ESP: ON" or "[NumPad6] RGB ESP: OFF"
        L_Rainbow.TextColor3 = RainbowESP_Enabled and Color3.new(0,1,0) or Color3.new(1,0,0)

    elseif input.KeyCode == Settings.Key_ToggleSpeedBoost then
        SpeedBoost_Enabled = not SpeedBoost_Enabled
        L_Speed.Text = SpeedBoost_Enabled and "[NumPad7] SpeedBoost: ON" or "[NumPad7] SpeedBoost: OFF"
        L_Speed.TextColor3 = SpeedBoost_Enabled and Color3.new(0,1,0) or Color3.new(1,0,0)

    elseif input.KeyCode == Settings.Key_ToggleSuperJump then
        SuperJump_Enabled = not SuperJump_Enabled
        L_Jump.Text = SuperJump_Enabled and "[NumPad8] SuperJump: ON" or "[NumPad8] SuperJump: OFF"
        L_Jump.TextColor3 = SuperJump_Enabled and Color3.new(0,1,0) or Color3.new(1,0,0)

    -- FULLBRIGHT (Home)
    elseif input.KeyCode == Settings.Key_ToggleFullbright then
        Settings.Fullbright_Enabled = not Settings.Fullbright_Enabled
        if Settings.Fullbright_Enabled then
            L_FBright.Text = "[Home] Fullbright: ON"
            L_FBright.TextColor3 = Color3.new(0,1,0)
        else
            L_FBright.Text = "[Home] Fullbright: OFF"
            L_FBright.TextColor3 = Color3.new(1,0,0)
            Lighting.ClockTime = 12
            Lighting.GlobalShadows = true
        end

    -- UI (Insert)
    elseif input.KeyCode == Settings.Key_ToggleUI then
        ScreenGui.Enabled = not ScreenGui.Enabled
        L_UIVis.Text = ScreenGui.Enabled and "[Ins] UI Visible: ON" or "[Ins] UI Visible: OFF"
        L_UIVis.TextColor3 = ScreenGui.Enabled and Color3.new(0,1,0) or Color3.new(1,0,0)
        if not ScreenGui.Enabled then
            FOVCircle.Visible = false
        end

    -- Aim FOV +/- (PgUp, PgDn)
    elseif input.KeyCode == Settings.Key_AimFOV_Up then
        Settings.AimFOV = math.clamp(Settings.AimFOV + 25, 50, 400)
        FOVCircle.Radius = Settings.AimFOV

    elseif input.KeyCode == Settings.Key_AimFOV_Down then
        Settings.AimFOV = math.clamp(Settings.AimFOV - 25, 50, 400)
        FOVCircle.Radius = Settings.AimFOV

    -- PANIC BUTTON (Delete)
    elseif input.KeyCode == Settings.Key_Panic then
        Settings.ESP_Enabled = false
        Settings.Aim_Enabled = false
        AimLockV2Active = false
        AimLockV2Target = nil
        AimingActive = false
        AntiAFK_Enabled = false
        Spinbot_Enabled = false
        ShakeCam_Enabled = false
        RainbowESP_Enabled = false
        SpeedBoost_Enabled = false
        SuperJump_Enabled = false

        L_ESP.Text = "[RightAlt] ESP: OFF"
        L_ESP.TextColor3 = Color3.new(1,0,0)
        L_Aim.Text = "[J] Aimbot Hold: OFF"
        L_Aim.TextColor3 = Color3.new(1,0,0)
        L_AimV2.Text = "[NumPad2] AimLock V2: OFF"
        L_AimV2.TextColor3 = Color3.new(1,0,0)
        L_AntiAFK.Text = "[NumPad3] Anti-AFK: OFF"
        L_AntiAFK.TextColor3 = Color3.new(1,0,0)
        L_Spin.Text = "[NumPad4] Spinbot: OFF"
        L_Spin.TextColor3 = Color3.new(1,0,0)
        L_Shake.Text = "[NumPad5] ShakeCam: OFF"
        L_Shake.TextColor3 = Color3.new(1,0,0)
        L_Rainbow.Text = "[NumPad6] RGB ESP: OFF"
        L_Rainbow.TextColor3 = Color3.new(1,0,0)
        L_Speed.Text = "[NumPad7] SpeedBoost: OFF"
        L_Speed.TextColor3 = Color3.new(1,0,0)
        L_Jump.Text = "[NumPad8] SuperJump: OFF"
        L_Jump.TextColor3 = Color3.new(1,0,0)

        FOVCircle.Visible = false
        for key,_ in pairs(Visuals) do
            RemoveVisuals(key)
        end
    end

    -- END: маленький рандомний "блінк" персонажа
    if input.KeyCode == Enum.KeyCode.End then
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local dx = math.random(-5,5)
            local dz = math.random(-5,5)
            hrp.CFrame = hrp.CFrame * CFrame.new(dx, 0, dz)
        end
    end

    -- Aimbot Hold (ПКМ)
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

-- === RENDER LOOP ===
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

    -- Anti-AFK локальний рух / стрибок
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

    -- SPEED / JUMP / SPINBOT
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChild("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    if hum then
        if not OriginalWalkSpeed then OriginalWalkSpeed = hum.WalkSpeed end
        if not OriginalJumpPower then
            if hum.UseJumpPower ~= false then
                OriginalJumpPower = hum.JumpPower
            else
                OriginalJumpPower = 50
            end
        end

        if SpeedBoost_Enabled then
            hum.WalkSpeed = (OriginalWalkSpeed or 16) * 2
        else
            hum.WalkSpeed = OriginalWalkSpeed or hum.WalkSpeed
        end

        if SuperJump_Enabled then
            hum.JumpPower = (OriginalJumpPower or 50) * 1.5
        else
            hum.JumpPower = OriginalJumpPower or hum.JumpPower
        end
    end

    if Spinbot_Enabled and hrp then
        hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(3), 0)
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

    -- ShakeCam (останнім, щоб трусило все)
    if ShakeCam_Enabled then
        local t = tick()
        local cf = Camera.CFrame
        Camera.CFrame = cf * CFrame.new(math.sin(t*20)*0.15, math.cos(t*17)*0.15, 0)
    end

    -- Оновлення стрілки напрямку гравця на міні-карті
    local _, Y, _ = Camera.CFrame:ToEulerAnglesYXZ()
    local rotation = math.deg(Y)
    PlayerArrowContainer.Rotation = -rotation
end)

Players.PlayerRemoving:Connect(RemoveVisuals)

print("Xeno Global v5.4 Loaded: Full NumPad Fun + Anti-AFK + AimLock.")
