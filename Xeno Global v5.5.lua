-- Xeno Global v5.5 - FunPad + In-Game Menu
-- NumPad / Arrows / PgUp/PgDn/Home/End/Ins/Del bound

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local CoreGui = game:GetService("CoreGui")

-- === SETTINGS ===
local Settings = {
    -- Оптимізація
    ESP_UPDATE_RATE = 0.07,
    REMOVE_DISTANCE = 3500,
    MAP_SCALE_FACTOR = 4,
    MAP_MAX_DOT_DISTANCE = 75,

    -- Основні перемикачі
    ESP_Enabled = true,
    Aim_Enabled = false,          -- класичний aimbot (утримання ПКМ)
    Tracers_Enabled = true,
    Minimap_Visible = true,
    Fullbright_Enabled = true,
    ShowTriggerPoints = false,
    Hitbox_Expansion_Enabled = false,
    TeamRecognition_Enabled = false,

    -- Аімбот
    AimKey = Enum.UserInputType.MouseButton2,
    AimSpeed = 0.9,               -- різкий aimbot
    AimFOV = 200,
    FOV_Circle_Color = Color3.fromRGB(255, 255, 255),

    -- Hitbox
    Hitbox_Expansion_Factor = 0.2,

    -- Кольори
    HeadColor_Static = Color3.fromRGB(128, 0, 128), -- фіолетовий (свої / голова)
    Color_Visible   = Color3.fromRGB(0, 255, 0),    -- зелений (видно)
    Color_Hidden    = Color3.fromRGB(255, 0, 0),    -- червоний (за стіною)
    Color_AimTarget = Color3.fromRGB(255, 215, 0),  -- золотий (ціль аімбота)
    Color_Bot       = Color3.fromRGB(255, 165, 0),  -- помаранчевий (боти)

    -- Рух / фанові фічі
    Speed_Walk  = 32,
    Speed_Jump  = 75,
    Teleport_Step = 6,
    Spin_Speed  = 180,

    -- Клавіші
    Key_ToggleESP       = Enum.KeyCode.RightAlt,
    Key_ToggleAim       = Enum.KeyCode.J,
    Key_ToggleMap       = Enum.KeyCode.M,
    Key_ToggleTracers   = Enum.KeyCode.T,
    Key_Reconnect       = Enum.KeyCode.Period,      -- >
    Key_TogglePoints    = Enum.KeyCode.Comma,       -- <
    Key_ToggleHitbox    = Enum.KeyCode.P,
    Key_ToggleTeam      = Enum.KeyCode.KeypadOne,

    -- Aim Lock V2
    Key_ToggleAimLockV2    = Enum.KeyCode.KeypadTwo,   -- NumPad 2
    Key_ToggleAimLockV2Alt = Enum.KeyCode.KeypadZero,  -- NumPad 0

    -- Anti AFK + рух
    Key_ToggleAntiAFK = Enum.KeyCode.KeypadThree,   -- NumPad 3
    Key_ToggleSpeed   = Enum.KeyCode.KeypadFour,    -- швидкий біг
    Key_ToggleAirJump = Enum.KeyCode.KeypadFive,    -- air-jump
    Key_ToggleNoclip  = Enum.KeyCode.KeypadSix,     -- noclip
    Key_ToggleSpin    = Enum.KeyCode.KeypadSeven,   -- spin fun

    -- Додаткові fun клавіші на NumPad
    Key_ToggleCrazyFOV = Enum.KeyCode.KeypadEight,  -- супер Zoom-Out
    Key_ToggleGhostCam = Enum.KeyCode.KeypadNine,   -- ghost camera

    -- Меню / FOV / Fullbright / Panic
    Key_ToggleMenu  = Enum.KeyCode.Insert,
    Key_FOV_Up      = Enum.KeyCode.PageUp,
    Key_FOV_Down    = Enum.KeyCode.PageDown,
    Key_ToggleFull  = Enum.KeyCode.Home,
    Key_Cinematic   = Enum.KeyCode.End,
    Key_PanicOff    = Enum.KeyCode.Delete,

    -- Arrow-фліки
    Key_FlickForward = Enum.KeyCode.Up,
    Key_FlickBack    = Enum.KeyCode.Down,
    Key_FlickLeft    = Enum.KeyCode.Left,
    Key_FlickRight   = Enum.KeyCode.Right,
}

-- === STATE ===
local Visuals = {}
local AimTarget = nil
local AimingActive = false
local AimLockV2Active = false
local AimLockV2Target = nil
local AntiAFK_Enabled = false
local AntiAFK_Timer = 0
local Speed_Enabled = false
local AirJump_Enabled = false
local Noclip_Enabled = false
local Spin_Enabled = false
local CrazyFOV_Enabled = false
local GhostCam_Enabled = false
local Cinematic_Enabled = false
local MenuVisible = true

local DefaultWalkSpeed = 16
local DefaultJumpPower = 50

local OriginalCollision = {} -- для коректного noclip без ламання сходів

local FOVCircle = Drawing.new("Circle")
FOVCircle.Radius = Settings.AimFOV
FOVCircle.Color = Settings.FOV_Circle_Color
FOVCircle.Thickness = 2
FOVCircle.Transparency = 0.7
FOVCircle.Visible = false

local R15_PARTS = {"Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg"}
local R6_PARTS  = {"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}

-- === UI ROOT ===
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "XenoOverlayV55"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = CoreGui

-- Мінікарта
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
TargetPanel.Size = UDim2.new(0, 280, 0, 25)
TargetPanel.Position = UDim2.new(0.5, -140, 0, 5)
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

-- === In-Game Menu ===
local MenuFrame = Instance.new("Frame")
MenuFrame.Name = "XenoMenu"
MenuFrame.Size = UDim2.new(0, 320, 0, 380)
MenuFrame.Position = UDim2.new(0.5, -160, 0.5, -190)
MenuFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
MenuFrame.BackgroundTransparency = 0.15
MenuFrame.BorderSizePixel = 0
MenuFrame.Visible = MenuVisible
MenuFrame.Parent = ScreenGui

local MenuCorner = Instance.new("UICorner", MenuFrame)
MenuCorner.CornerRadius = UDim.new(0, 10)

local MenuTitle = Instance.new("TextLabel")
MenuTitle.Size = UDim2.new(1, -10, 0, 30)
MenuTitle.Position = UDim2.new(0, 5, 0, 5)
MenuTitle.BackgroundTransparency = 1
MenuTitle.Font = Enum.Font.GothamBold
MenuTitle.TextSize = 18
MenuTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
MenuTitle.Text = "Xeno Global v5.5 Menu [Insert]"
MenuTitle.Parent = MenuFrame

local MenuDesc = Instance.new("TextLabel")
MenuDesc.Size = UDim2.new(1, -10, 0, 18)
MenuDesc.Position = UDim2.new(0, 5, 0, 30)
MenuDesc.BackgroundTransparency = 1
MenuDesc.Font = Enum.Font.Code
MenuDesc.TextSize = 13
MenuDesc.TextColor3 = Color3.fromRGB(200, 200, 200)
MenuDesc.TextXAlignment = Enum.TextXAlignment.Left
MenuDesc.Text = "ЛКМ по рядку = toggle, NumPad/клавіші теж працюють."
MenuDesc.Parent = MenuFrame

local MenuListHolder = Instance.new("Frame")
MenuListHolder.Size = UDim2.new(1, -10, 1, -60)
MenuListHolder.Position = UDim2.new(0, 5, 0, 55)
MenuListHolder.BackgroundTransparency = 1
MenuListHolder.Parent = MenuFrame

local MenuList = Instance.new("UIListLayout")
MenuList.Parent = MenuListHolder
MenuList.Padding = UDim.new(0, 4)
MenuList.SortOrder = Enum.SortOrder.LayoutOrder

local TogglesUI = {}

local function createToggleRow(keyHint, name, getState, setState)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 22)
    btn.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    btn.AutoButtonColor = true
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.Code
    btn.TextSize = 14
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Parent = MenuListHolder

    local function refresh()
        local on = getState()
        local stateText = on and "ON" or "OFF"
        btn.Text = string.format("[%s] %s : %s", keyHint, name, stateText)
        btn.TextColor3 = on and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 80, 80)
        btn.BackgroundColor3 = on and Color3.fromRGB(30, 30, 40) or Color3.fromRGB(20, 20, 20)
    end

    btn.MouseButton1Click:Connect(function()
        setState(not getState())
        refresh()
    end)

    TogglesUI[name] = {refresh = refresh}
    refresh()
end

local function refreshToggle(name)
    if TogglesUI[name] then
        TogglesUI[name].refresh()
    end
end

-- === Core helpers ===
local function Reconnect()
    TeleportService:Teleport(game.PlaceId, LocalPlayer)
end

local function IsVisible(char)
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return false end
    local parts = hum.RigType == Enum.HumanoidRigType.R15 and R15_PARTS or R6_PARTS

    local origin = Camera.CFrame.Position
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {LocalPlayer.Character, ScreenGui}

    for _, partName in ipairs(parts) do
        local part = char:FindFirstChild(partName, true)
        if part and part.Transparency < 1 and part.Size.Magnitude > 0.5 then
            local dir = (part.Position - origin)
            local result = workspace:Raycast(origin, dir.Unit * (dir.Magnitude - 0.5), params)
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
    bg.Size = UDim2.new(0, 200, 0, 80)
    bg.StudsOffset = Vector3.new(0, 1, 0)
    bg.Parent = ScreenGui

    local list = Instance.new("UIListLayout")
    list.Parent = bg
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Padding = UDim.new(0, 1)
    list.VerticalAlignment = Enum.VerticalAlignment.Top

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
    local v = Visuals[key]
    if not v then return end
    if v.Tracer then v.Tracer:Remove() end
    if v.InfoGUI then v.InfoGUI:Destroy() end
    if v.MapDot then v.MapDot:Destroy() end
    if v.HeadAdornment then v.HeadAdornment:Destroy() end
    for _, b in pairs(v.BoxParts or {}) do b:Destroy() end
    for _, p in pairs(v.TriggerPoints or {}) do p:Destroy() end
    Visuals[key] = nil
end

-- Основна функція ESP
local function UpdateVisuals()
    local myChar = LocalPlayer.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
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

    -- Боти (Model + Humanoid + HRP без Player)
    for _, child in ipairs(workspace:GetChildren()) do
        if child:IsA("Model") and child:FindFirstChild("Humanoid") and child:FindFirstChild("HumanoidRootPart") then
            local p = Players:GetPlayerFromCharacter(child)
            if not p and child ~= myChar then
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

    for key, char in pairs(targets) do
        local player = Players:GetPlayerFromCharacter(char)
        local isBot = player == nil

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
        local v = Visuals[key]

        if not v then
            Visuals[key] = {
                BoxParts = {},
                HeadAdornment = nil,
                MapDot = nil,
                Tracer = CreateTracer(),
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
        local isTeammate = false

        if isBot then
            mainColor = Settings.Color_Bot
            headColorToUse = Settings.Color_Bot
        else
            if player then
                local sameTeam = (LocalPlayer.Team and player.Team and LocalPlayer.Team == player.Team)
                    or (LocalPlayer.TeamColor and player.TeamColor and LocalPlayer.TeamColor == player.TeamColor)
                isTeammate = sameTeam
            end

            if Settings.TeamRecognition_Enabled and isTeammate then
                mainColor = Settings.HeadColor_Static
                headColorToUse = Settings.HeadColor_Static
            else
                if Settings.TeamRecognition_Enabled and player and player.TeamColor then
                    local base = player.TeamColor.Color
                    if visible then
                        mainColor = base
                    else
                        mainColor = base:lerp(Color3.new(0,0,0), 0.4)
                    end
                    headColorToUse = visible and Settings.HeadColor_Static or mainColor
                else
                    mainColor = visible and Settings.Color_Visible or Settings.Color_Hidden
                    headColorToUse = visible and Settings.HeadColor_Static or Settings.Color_Hidden
                end
            end
        end

        local isCurrentTarget = (AimTarget == char) or (AimLockV2Target == char)
        if isCurrentTarget then
            headColorToUse = Settings.Color_AimTarget
        end

        -- Голова
        if not v.HeadAdornment then
            local h = Instance.new("CylinderHandleAdornment")
            h.Height = 1.1
            h.Radius = 0.6
            h.CFrame = CFrame.Angles(math.rad(90),0,0)
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
        local limbs = hum.RigType == Enum.HumanoidRigType.R15 and R15_PARTS or R6_PARTS
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
            elseif v.BoxParts[partName] then
                v.BoxParts[partName].Visible = false
            end
        end

        -- Триггер точки (можна розширити, поки тільки видимість ON/OFF)
        if Settings.ShowTriggerPoints then
            for _, p in pairs(v.TriggerPoints) do p.Visible = true end
        else
            for _, p in pairs(v.TriggerPoints) do p.Visible = false end
        end

        -- Інфо
        v.InfoGUI.Enabled = isEnabled
        v.InfoGUI.Adornee = head

        local teamPrefix = ""
        if isBot then
            teamPrefix = string.format("<font color=\"rgb(%d,%d,%d)\"><b>БОТ | </b></font>",
                Settings.Color_Bot.R*255, Settings.Color_Bot.G*255, Settings.Color_Bot.B*255)
        elseif isTeammate and Settings.TeamRecognition_Enabled then
            teamPrefix = string.format("<font color=\"rgb(%d,%d,%d)\"><b>СВІЙ | </b></font>",
                Settings.HeadColor_Static.R*255, Settings.HeadColor_Static.G*255, Settings.HeadColor_Static.B*255)
        elseif Settings.TeamRecognition_Enabled and player and player.Team then
            local c = player.TeamColor and player.TeamColor.Color or mainColor
            teamPrefix = string.format("<font color=\"rgb(%d,%d,%d)\"><b>%s | </b></font>",
                c.R*255, c.G*255, c.B*255, player.Team.Name)
        end

        v.NameLabel.RichText = true
        v.NameLabel.Text = teamPrefix .. (isBot and char.Name or player.Name)
        v.NameLabel.TextColor3 = isBot and Settings.Color_Bot or mainColor

        local currentHP = math.floor(hum.Health)
        local maxHP = math.floor(hum.MaxHealth)
        v.StatsLabel.Text = string.format("[ %d / %d HP ] [ %dm ]", currentHP, maxHP, math.floor(dist))

        -- Мінікарта
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
        if Settings.Tracers_Enabled and isEnabled then
            local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            if onScreen then
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
        local hum = char and char:FindFirstChild("Humanoid")
        if char and hum and hum.Health > 0 then
            local player = Players:GetPlayerFromCharacter(char)
            if Settings.TeamRecognition_Enabled and player and LocalPlayer.Team and player.Team and LocalPlayer.Team == player.Team then
                continue
            end

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

-- Anti-AFK через VirtualUser
Players.LocalPlayer.Idled:Connect(function()
    if AntiAFK_Enabled then
        VirtualUser:Button2Down(Vector2.new(0, 0), Camera.CFrame)
        task.wait(0.1)
        VirtualUser:Button2Up(Vector2.new(0, 0), Camera.CFrame)
    end
end)

-- AirJump
UserInputService.JumpRequest:Connect(function()
    if not AirJump_Enabled then return end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChild("Humanoid")
    if hum then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

-- Arrow quick flicks
local function QuickFlick(direction)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local cf = hrp.CFrame
    local step = Settings.Teleport_Step
    if direction == "forward" then
        hrp.CFrame = cf + cf.LookVector * step
    elseif direction == "back" then
        hrp.CFrame = cf - cf.LookVector * step
    elseif direction == "left" then
        hrp.CFrame = cf - cf.RightVector * step
    elseif direction == "right" then
        hrp.CFrame = cf + cf.RightVector * step
    end
end

-- === MENU TOGGLE ROWS ===
createToggleRow("RightAlt", "ESP", function() return Settings.ESP_Enabled end, function(v) Settings.ESP_Enabled = v end)
createToggleRow("J", "Aimbot Hold", function() return Settings.Aim_Enabled end, function(v) Settings.Aim_Enabled = v end)
createToggleRow("Num2", "AimLock V2", function() return AimLockV2Active end, function(v)
    -- клік по рядку: якщо вимкнено, шукаємо таргет; якщо включено, відрубаємо
    if AimLockV2Active then
        AimLockV2Active = false
        AimLockV2Target = nil
    else
        local newTarget = GetTarget(true)
        if newTarget then
            AimLockV2Target = newTarget
            AimLockV2Active = true
        end
    end
end)
createToggleRow("Num3", "Anti-AFK", function() return AntiAFK_Enabled end, function(v) AntiAFK_Enabled = v end)
createToggleRow("Num4", "SpeedHack", function() return Speed_Enabled end, function(v) Speed_Enabled = v end)
createToggleRow("Num5", "AirJump", function() return AirJump_Enabled end, function(v) AirJump_Enabled = v end)
createToggleRow("Num6", "Noclip", function() return Noclip_Enabled end, function(v) Noclip_Enabled = v end)
createToggleRow("Num7", "SpinFun", function() return Spin_Enabled end, function(v) Spin_Enabled = v end)
createToggleRow("Num8", "Crazy FOV", function() return CrazyFOV_Enabled end, function(v) CrazyFOV_Enabled = v end)
createToggleRow("Num9", "Ghost Cam", function() return GhostCam_Enabled end, function(v) GhostCam_Enabled = v end)
createToggleRow("Num1", "Team Check", function() return Settings.TeamRecognition_Enabled end, function(v) Settings.TeamRecognition_Enabled = v end)
createToggleRow("P", "Hitbox Expand", function() return Settings.Hitbox_Expansion_Enabled end, function(v) Settings.Hitbox_Expansion_Enabled = v end)
createToggleRow("<", "Trigger Points", function() return Settings.ShowTriggerPoints end, function(v) Settings.ShowTriggerPoints = v end)
createToggleRow("M", "Minimap", function() return Settings.Minimap_Visible end, function(v) Settings.Minimap_Visible = v; MapFrame.Visible = v end)
createToggleRow("T", "Tracers", function() return Settings.Tracers_Enabled end, function(v) Settings.Tracers_Enabled = v end)
createToggleRow("Home", "Fullbright", function() return Settings.Fullbright_Enabled end, function(v) Settings.Fullbright_Enabled = v end)
createToggleRow("End", "Cinematic", function() return Cinematic_Enabled end, function(v) Cinematic_Enabled = v end)

-- === INPUT HANDLING ===
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end

    if input.KeyCode == Settings.Key_ToggleESP then
        Settings.ESP_Enabled = not Settings.ESP_Enabled
        refreshToggle("ESP")

    elseif input.KeyCode == Settings.Key_ToggleAim then
        Settings.Aim_Enabled = not Settings.Aim_Enabled
        refreshToggle("Aimbot Hold")

    elseif input.KeyCode == Settings.Key_ToggleAimLockV2 or input.KeyCode == Settings.Key_ToggleAimLockV2Alt then
        if AimLockV2Active then
            AimLockV2Active = false
            AimLockV2Target = nil
        else
            local newTarget = GetTarget(true)
            if newTarget then
                AimLockV2Target = newTarget
                AimLockV2Active = true
            end
        end
        refreshToggle("AimLock V2")

    elseif input.KeyCode == Settings.Key_ToggleAntiAFK then
        AntiAFK_Enabled = not AntiAFK_Enabled
        refreshToggle("Anti-AFK")

    elseif input.KeyCode == Settings.Key_ToggleSpeed then
        Speed_Enabled = not Speed_Enabled
        refreshToggle("SpeedHack")

    elseif input.KeyCode == Settings.Key_ToggleAirJump then
        AirJump_Enabled = not AirJump_Enabled
        refreshToggle("AirJump")

    elseif input.KeyCode == Settings.Key_ToggleNoclip then
        Noclip_Enabled = not Noclip_Enabled
        refreshToggle("Noclip")

    elseif input.KeyCode == Settings.Key_ToggleSpin then
        Spin_Enabled = not Spin_Enabled
        refreshToggle("SpinFun")

    elseif input.KeyCode == Settings.Key_ToggleCrazyFOV then
        CrazyFOV_Enabled = not CrazyFOV_Enabled
        refreshToggle("Crazy FOV")

    elseif input.KeyCode == Settings.Key_ToggleGhostCam then
        GhostCam_Enabled = not GhostCam_Enabled
        if GhostCam_Enabled then
            Camera.CameraType = Enum.CameraType.Scriptable
        else
            Camera.CameraType = Enum.CameraType.Custom
        end
        refreshToggle("Ghost Cam")

    elseif input.KeyCode == Settings.Key_ToggleMap then
        Settings.Minimap_Visible = not Settings.Minimap_Visible
        MapFrame.Visible = Settings.Minimap_Visible
        refreshToggle("Minimap")

    elseif input.KeyCode == Settings.Key_ToggleTracers then
        Settings.Tracers_Enabled = not Settings.Tracers_Enabled
        refreshToggle("Tracers")

    elseif input.KeyCode == Settings.Key_TogglePoints then
        Settings.ShowTriggerPoints = not Settings.ShowTriggerPoints
        refreshToggle("Trigger Points")

    elseif input.KeyCode == Settings.Key_ToggleHitbox then
        Settings.Hitbox_Expansion_Enabled = not Settings.Hitbox_Expansion_Enabled
        refreshToggle("Hitbox Expand")

    elseif input.KeyCode == Settings.Key_ToggleTeam then
        Settings.TeamRecognition_Enabled = not Settings.TeamRecognition_Enabled
        refreshToggle("Team Check")

    elseif input.KeyCode == Settings.Key_Reconnect then
        Reconnect()

    elseif input.KeyCode == Settings.Key_ToggleFull then
        Settings.Fullbright_Enabled = not Settings.Fullbright_Enabled
        refreshToggle("Fullbright")

    elseif input.KeyCode == Settings.Key_Cinematic then
        Cinematic_Enabled = not Cinematic_Enabled
        refreshToggle("Cinematic")

    elseif input.KeyCode == Settings.Key_ToggleMenu then
        MenuVisible = not MenuVisible
        MenuFrame.Visible = MenuVisible

    elseif input.KeyCode == Settings.Key_FOV_Up then
        Settings.AimFOV = math.clamp(Settings.AimFOV + 25, 25, 600)
        FOVCircle.Radius = Settings.AimFOV

    elseif input.KeyCode == Settings.Key_FOV_Down then
        Settings.AimFOV = math.clamp(Settings.AimFOV - 25, 25, 600)
        FOVCircle.Radius = Settings.AimFOV

    elseif input.KeyCode == Settings.Key_PanicOff then
        -- Hard panic off
        Settings.ESP_Enabled = false
        Settings.Aim_Enabled = false
        Settings.Tracers_Enabled = false
        Settings.Minimap_Visible = false
        Settings.ShowTriggerPoints = false
        Settings.Hitbox_Expansion_Enabled = false
        Settings.TeamRecognition_Enabled = false
        AntiAFK_Enabled = false
        Speed_Enabled = false
        AirJump_Enabled = false
        Noclip_Enabled = false
        Spin_Enabled = false
        CrazyFOV_Enabled = false
        GhostCam_Enabled = false
        AimLockV2Active = false
        AimLockV2Target = nil
        AimingActive = false
        AimTarget = nil
        MapFrame.Visible = false
        FOVCircle.Visible = false

        refreshToggle("ESP")
        refreshToggle("Aimbot Hold")
        refreshToggle("AimLock V2")
        refreshToggle("Anti-AFK")
        refreshToggle("SpeedHack")
        refreshToggle("AirJump")
        refreshToggle("Noclip")
        refreshToggle("SpinFun")
        refreshToggle("Crazy FOV")
        refreshToggle("Ghost Cam")
        refreshToggle("Team Check")
        refreshToggle("Hitbox Expand")
        refreshToggle("Trigger Points")
        refreshToggle("Minimap")
        refreshToggle("Tracers")
        refreshToggle("Fullbright")
        refreshToggle("Cinematic")

    elseif input.KeyCode == Settings.Key_FlickForward then
        QuickFlick("forward")
    elseif input.KeyCode == Settings.Key_FlickBack then
        QuickFlick("back")
    elseif input.KeyCode == Settings.Key_FlickLeft then
        QuickFlick("left")
    elseif input.KeyCode == Settings.Key_FlickRight then
        QuickFlick("right")
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
end)

-- === MAIN LOOP ===
local lastESPUpdate = 0

RunService.RenderStepped:Connect(function(dt)
    -- ESP
    lastESPUpdate = lastESPUpdate + dt
    if lastESPUpdate >= Settings.ESP_UPDATE_RATE then
        UpdateVisuals()
        lastESPUpdate = 0
    end

    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChild("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    -- Fullbright
    if Settings.Fullbright_Enabled then
        Lighting.ClockTime = 14
        Lighting.GlobalShadows = false
    end

    -- Cinematic: сховати декор, але ESP/таргет лишається
    if Cinematic_Enabled then
        MapFrame.Visible = false
    else
        MapFrame.Visible = Settings.Minimap_Visible
    end

    -- Speed / Jump
    if hum then
        if Speed_Enabled then
            if hum.WalkSpeed ~= Settings.Speed_Walk then
                hum.WalkSpeed = Settings.Speed_Walk
            end
            if hum.UseJumpPower ~= nil then
                hum.UseJumpPower = true
                hum.JumpPower = Settings.Speed_Jump
            end
        else
            hum.WalkSpeed = DefaultWalkSpeed
            if hum.UseJumpPower ~= nil then
                hum.JumpPower = DefaultJumpPower
            end
        end
    end

    -- Noclip з збереженням оригінальних колізій (щоб сходи нормально працювали)
    if char then
        if Noclip_Enabled then
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") then
                    if OriginalCollision[p] == nil then
                        OriginalCollision[p] = p.CanCollide
                    end
                    p.CanCollide = false
                end
            end
        else
            for part, state in pairs(OriginalCollision) do
                if part and part.Parent then
                    part.CanCollide = state
                end
                OriginalCollision[part] = nil
            end
        end

        if Spin_Enabled and hrp then
            hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(Settings.Spin_Speed) * dt, 0)
        end
    end

    -- Crazy FOV (локальний візуальний ефект)
    if CrazyFOV_Enabled then
        Camera.FieldOfView = 100
    else
        Camera.FieldOfView = 70
    end

    -- Ghost camera простий (вертикальний дрейф для фану)
    if GhostCam_Enabled and not char then
        Camera.CFrame = Camera.CFrame * CFrame.new(0, math.sin(tick()*0.5)*0.02, 0)
    end

    -- AntiAFK рух
    if AntiAFK_Enabled and hum then
        AntiAFK_Timer = AntiAFK_Timer + dt
        if AntiAFK_Timer >= 4 then
            hum:Move(Vector3.new(1,0,0), true)
            hum.Jump = true
            AntiAFK_Timer = 0
        end
    end

    -- AIMBOT логіка
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
        end
        AimTarget = nil
        TargetLabel.Text = "Aimbot не активний (J / NumPad2)"
        TargetLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        TargetPanel.BorderColor3 = Color3.fromRGB(50, 50, 50)
        FOVCircle.Visible = false
    end

    -- Обертання стрілки мінікарти
    local _, Y, _ = Camera.CFrame:ToEulerAnglesYXZ()
    PlayerArrowContainer.Rotation = -math.deg(Y)
end)

Players.PlayerRemoving:Connect(RemoveVisuals)

print("Xeno Global v5.5 Loaded: Menu, fun keybinds, fixed noclip stairs.")
