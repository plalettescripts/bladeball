--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║                    BLADE BALL - ULTIMATE                    ║
    ║                  Created by: plalettescripts                ║
    ║                  Version: 1.0 | No Kick                     ║
    ╚══════════════════════════════════════════════════════════════╝
    
    SEKTIONEN:
    1. Services & Variablen
    2. GUI-System (Dark-Mode, Tabs, Animationen)
    3. Auto Parry (Ball-Erkennung, Velocity, Distanz, Remote)
    4. Auto Aim / Ball Redirect
    5. ESP & Visuals (Ball, Spieler, Radar, Tracer)
    6. Ability Automatisierung
    7. Movement & Ausweichen
    8. Spielmodus-Erkennung
    9. Konfiguration & Webhook
    10. Benachrichtigungs-System
    11. Anti-Cheat & Humanisierung
]]

-- ==================== 1. SERVICES & VARIABLEN ====================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- Konfiguration (Standardwerte)
local Config = {
    -- Auto Parry
    AutoParry = false,
    ParryRadius = 18,
    ParryDelayMin = 50,   -- ms
    ParryDelayMax = 150,  -- ms
    ShowParryCircle = true,
    ParryHumanize = true,
    
    -- Auto Aim
    AutoAim = false,
    AimFOV = 120,
    AimPrediction = true,
    AimPriority = "Distance", -- "Distance", "Weakest", "Dangerous"
    
    -- ESP
    BallESP = false,
    PlayerESP = false,
    Tracers = false,
    Radar = false,
    ShowTrajectory = true,
    
    -- Movement
    AutoDodge = false,
    SpeedHack = false,
    SpeedValue = 32,
    Fly = false,
    FlySpeed = 50,
    
    -- Abilities
    AutoAbilities = false,
    AbilityPriority = "Defensive", -- "Defensive", "Offensive", "Both"
    
    -- Settings
    WebhookURL = "",
    KeySystem = false,
    KeyBind = Enum.KeyCode.LeftControl
}

-- Speicher für ESP-Zeichnungen (Limit: 100)
local ESPDrawings = {}
local MaxDrawings = 100

-- Verbindungs-Speicher
local Connections = {}

-- Remote-Event-Cache
local ParryRemote = nil
local AbilityRemote = nil
local BallRemote = nil

-- Spielmodus-Erkennung
local GameMode = "Standard"
local InRound = false

-- ==================== HILFSFUNKTIONEN ====================

-- Humanisierte Verzögerung
local function HumanizeDelay(min, max)
    if not Config.ParryHumanize then return 0 end
    return math.random(min or 50, max or 150) / 1000
end

-- Zeichnungen sicher entfernen
local function ClearDrawings()
    for _, d in pairs(ESPDrawings) do
        pcall(function() d:Remove() end)
    end
    ESPDrawings = {}
end

-- Zeichnung hinzufügen mit Limit-Prüfung
local function AddDrawing(drawing)
    if #ESPDrawings >= MaxDrawings then
        local old = table.remove(ESPDrawings, 1)
        pcall(function() old:Remove() end)
    end
    table.insert(ESPDrawings, drawing)
    return drawing
end

-- Ball im Workspace finden
local function FindBall()
    -- Suche nach dem Ball über verschiedene Methoden
    local ball = Workspace:FindFirstChild("Ball") or Workspace:FindFirstChild("BladeBall")
    if ball and ball:IsA("BasePart") then return ball end
    
    -- Suche in Ordnern
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj.Name == "Ball" and obj:IsA("BasePart") and obj.Velocity.Magnitude > 1 then
            return obj
        end
    end
    
    -- Suche über CollectionService Tags
    for _, obj in ipairs(CollectionService:GetTagged("Ball")) do
        if obj:IsA("BasePart") then return obj end
    end
    
    return nil
end

-- Remote Events finden
local function FindRemotes()
    if ParryRemote and AbilityRemote then return end
    
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            local name = obj.Name:lower()
            if name:find("parry") or name:find("block") then
                ParryRemote = obj
            elseif name:find("ability") or name:find("skill") or name:find("dash") then
                AbilityRemote = obj
            elseif name:find("ball") or name:find("hit") then
                BallRemote = obj
            end
        end
    end
end

-- Prüfen ob Ball auf Spieler zielt
local function IsBallTargetingPlayer(ball, player)
    if not ball or not player or not player.Character then return false end
    
    local char = player.Character
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    local ballVelocity = ball.Velocity or ball.AssemblyLinearVelocity or Vector3.zero
    if ballVelocity.Magnitude < 1 then return false end
    
    -- Prüfe ob Ball in Richtung des Spielers fliegt
    local ballToPlayer = (hrp.Position - ball.Position).Unit
    local ballDirection = ballVelocity.Unit
    local dotProduct = ballToPlayer:Dot(ballDirection)
    
    return dotProduct > 0.3 -- Ball bewegt sich generell in Spieler-Richtung
end

-- Distanz zwischen Ball und Spieler
local function BallDistanceToPlayer(ball, player)
    if not ball or not player or not player.Character then return 999 end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return 999 end
    return (ball.Position - hrp.Position).Magnitude
end

-- ==================== 2. GUI-SYSTEM ====================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PlaletteBladeBall"
ScreenGui.Parent = CoreGui

-- Hauptrahmen
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 300, 0, 420)
MainFrame.Position = UDim2.new(0.75, 0, 0.2, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

-- Animierter Rand
local Border = Instance.new("Frame")
Border.Size = UDim2.new(1, 4, 1, 4)
Border.Position = UDim2.new(0, -2, 0, -2)
Border.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
Border.BorderSizePixel = 0
Border.Parent = MainFrame
Instance.new("UICorner", Border).CornerRadius = UDim.new(0, 11)

-- Rand-Animation (Cyan-Blau Verlauf)
task.spawn(function()
    local hue = 0.55
    while ScreenGui and ScreenGui.Parent do
        hue = hue + 0.003
        if hue > 0.62 then hue = 0.55 end
        pcall(function() Border.BackgroundColor3 = Color3.fromHSV(hue, 0.8, 1) end)
        task.wait(0.03)
    end
end)

-- Minimiertes Fenster
local MiniFrame = Instance.new("Frame")
MiniFrame.Size = UDim2.new(0, 180, 0, 40)
MiniFrame.Position = UDim2.new(0.5, -90, 0.02, 0)
MiniFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
MiniFrame.BorderSizePixel = 0
MiniFrame.Visible = false
MiniFrame.Active = true
MiniFrame.Draggable = true
MiniFrame.Parent = ScreenGui
Instance.new("UICorner", MiniFrame).CornerRadius = UDim.new(0, 8)

local MiniText = Instance.new("TextLabel")
MiniText.Size = UDim2.new(1, 0, 1, 0)
MiniText.BackgroundTransparency = 1
MiniText.TextColor3 = Color3.fromRGB(0, 200, 255)
MiniText.Text = "⚔️ plalettescripts - CTRL"
MiniText.Font = Enum.Font.SourceSansBold
MiniText.TextSize = 12
MiniText.Parent = MiniFrame

-- CTRL Toggle
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Config.KeyBind then
        MainFrame.Visible = not MainFrame.Visible
        MiniFrame.Visible = not MiniFrame.Visible
    end
end)

-- Titel
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 35)
TitleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 10)

local TitleText = Instance.new("TextLabel")
TitleText.Size = UDim2.new(0.7, 0, 1, 0)
TitleText.Position = UDim2.new(0.06, 0, 0, 0)
TitleText.BackgroundTransparency = 1
TitleText.TextColor3 = Color3.fromRGB(0, 220, 255)
TitleText.Text = "⚔️ Blade Ball Ultimate"
TitleText.Font = Enum.Font.SourceSansBold
TitleText.TextSize = 16
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.Parent = TitleBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 26, 0, 22)
CloseBtn.Position = UDim2.new(1, -32, 0, 6)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Text = "X"
CloseBtn.Font = Enum.Font.SourceSansBold
CloseBtn.TextSize = 13
CloseBtn.Parent = TitleBar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 4)
CloseBtn.MouseButton1Click:Connect(function()
    ClearDrawings()
    for _, c in pairs(Connections) do pcall(function() c:Disconnect() end) end
    ScreenGui:Destroy()
end)

-- Tab-System
local TabContainer = Instance.new("Frame")
TabContainer.Size = UDim2.new(0, 85, 1, -39)
TabContainer.Position = UDim2.new(0, 2, 0, 37)
TabContainer.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
TabContainer.BorderSizePixel = 0
TabContainer.Parent = MainFrame
Instance.new("UICorner", TabContainer).CornerRadius = UDim.new(0, 6)

local TabList = Instance.new("UIListLayout")
TabList.Padding = UDim.new(0, 2)
TabList.FillDirection = Enum.FillDirection.Vertical
TabList.SortOrder = Enum.SortOrder.LayoutOrder
TabList.Parent = TabContainer

local ContentFrame = Instance.new("Frame")
ContentFrame.Size = UDim2.new(1, -92, 1, -43)
ContentFrame.Position = UDim2.new(0, 90, 0, 37)
ContentFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
ContentFrame.BorderSizePixel = 0
ContentFrame.Parent = MainFrame
Instance.new("UICorner", ContentFrame).CornerRadius = UDim.new(0, 6)

-- Tab-Erstellungs-Funktion
local function CreateTab(name, icon)
    local TabBtn = Instance.new("TextButton")
    TabBtn.Size = UDim2.new(1, -4, 0, 28)
    TabBtn.Position = UDim2.new(0, 2, 0, 0)
    TabBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    TabBtn.TextColor3 = Color3.fromRGB(180, 180, 200)
    TabBtn.Text = icon .. " " .. name
    TabBtn.Font = Enum.Font.SourceSansSemibold
    TabBtn.TextSize = 10
    TabBtn.TextXAlignment = Enum.TextXAlignment.Left
    TabBtn.Parent = TabContainer
    Instance.new("UICorner", TabBtn).CornerRadius = UDim.new(0, 4)

    local Content = Instance.new("ScrollingFrame")
    Content.Size = UDim2.new(1, -8, 1, -8)
    Content.Position = UDim2.new(0, 4, 0, 4)
    Content.BackgroundTransparency = 1
    Content.BorderSizePixel = 0
    Content.ScrollBarThickness = 3
    Content.ScrollBarImageColor3 = Color3.fromRGB(0, 180, 240)
    Content.CanvasSize = UDim2.new(0, 0, 0, 500)
    Content.Visible = false
    Content.Parent = ContentFrame

    local ContentList = Instance.new("UIListLayout")
    ContentList.Padding = UDim.new(0, 3)
    ContentList.FillDirection = Enum.FillDirection.Vertical
    ContentList.SortOrder = Enum.SortOrder.LayoutOrder
    ContentList.Parent = Content

    TabBtn.MouseButton1Click:Connect(function()
        for _, child in ipairs(ContentFrame:GetChildren()) do
            if child:IsA("ScrollingFrame") then child.Visible = false end
        end
        for _, child in ipairs(TabContainer:GetChildren()) do
            if child:IsA("TextButton") then
                child.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
                child.TextColor3 = Color3.fromRGB(180, 180, 200)
            end
        end
        Content.Visible = true
        TabBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 240)
        TabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    end)

    -- Auto-select first tab
    local found = false
    for _, child in ipairs(ContentFrame:GetChildren()) do
        if child:IsA("ScrollingFrame") and child.Visible then found = true end
    end
    if not found then
        Content.Visible = true
        TabBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 240)
        TabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    end

    local tab = {}

    function tab:AddDivider(text)
        local Div = Instance.new("Frame")
        Div.Size = UDim2.new(1, -2, 0, 20)
        Div.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
        Div.Parent = Content
        Instance.new("UICorner", Div).CornerRadius = UDim.new(0, 4)
        local Lbl = Instance.new("TextLabel")
        Lbl.Size = UDim2.new(1, 0, 1, 0)
        Lbl.BackgroundTransparency = 1
        Lbl.TextColor3 = Color3.fromRGB(0, 200, 255)
        Lbl.Text = "⚡ " .. text .. " ⚡"
        Lbl.Font = Enum.Font.SourceSansBold
        Lbl.TextSize = 10
        Lbl.Parent = Div
    end

    function tab:AddToggle(name, key)
        local Frame = Instance.new("Frame")
        Frame.Size = UDim2.new(1, -2, 0, 30)
        Frame.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
        Frame.Parent = Content
        Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 4)

        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.new(0.55, 0, 1, 0)
        Label.Position = UDim2.new(0.03, 0, 0, 0)
        Label.BackgroundTransparency = 1
        Label.TextColor3 = Color3.fromRGB(220, 220, 240)
        Label.Text = name .. " : OFF"
        Label.Font = Enum.Font.SourceSansSemibold
        Label.TextSize = 11
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.Parent = Frame

        local Btn = Instance.new("TextButton")
        Btn.Size = UDim2.new(0, 36, 0, 18)
        Btn.Position = UDim2.new(0.9, -36, 0, 6)
        Btn.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
        Btn.Text = ""
        Btn.Parent = Frame
        Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 9)

        local on = false
        Btn.MouseButton1Click:Connect(function()
            on = not on
            Config[key] = on
            Label.Text = name .. " : " .. (on and "ON" or "OFF")
            Btn.BackgroundColor3 = on and Color3.fromRGB(0, 180, 240) or Color3.fromRGB(50, 50, 65)
        end)
    end

    function tab:AddSlider(name, key, min, max, default)
        Config[key] = default
        local Frame = Instance.new("Frame")
        Frame.Size = UDim2.new(1, -2, 0, 48)
        Frame.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
        Frame.Parent = Content
        Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 4)

        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.new(1, 0, 0, 18)
        Label.Position = UDim2.new(0.03, 0, 0, 3)
        Label.BackgroundTransparency = 1
        Label.TextColor3 = Color3.fromRGB(220, 220, 240)
        Label.Text = name .. " : " .. tostring(default)
        Label.Font = Enum.Font.SourceSans
        Label.TextSize = 11
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.Parent = Frame

        local Input = Instance.new("TextBox")
        Input.Size = UDim2.new(0.3, 0, 0, 22)
        Input.Position = UDim2.new(0.35, 0, 0, 23)
        Input.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
        Input.TextColor3 = Color3.fromRGB(200, 240, 255)
        Input.Text = tostring(default)
        Input.Font = Enum.Font.SourceSans
        Input.TextSize = 11
        Input.Parent = Frame
        Instance.new("UICorner", Input).CornerRadius = UDim.new(0, 4)

        Input.FocusLost:Connect(function()
            local val = tonumber(Input.Text)
            if val and val >= min and val <= max then
                Config[key] = val
                Label.Text = name .. " : " .. tostring(val)
            else
                Input.Text = tostring(Config[key])
            end
        end)
    end

    function tab:AddDropdown(name, key, options, default)
        Config[key] = default or options[1]
        local Frame = Instance.new("Frame")
        Frame.Size = UDim2.new(1, -2, 0, 30)
        Frame.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
        Frame.Parent = Content
        Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 4)

        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.new(0.35, 0, 1, 0)
        Label.Position = UDim2.new(0.03, 0, 0, 0)
        Label.BackgroundTransparency = 1
        Label.TextColor3 = Color3.fromRGB(220, 220, 240)
        Label.Text = name .. ":"
        Label.Font = Enum.Font.SourceSansSemibold
        Label.TextSize = 11
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.Parent = Frame

        local DropBtn = Instance.new("TextButton")
        DropBtn.Size = UDim2.new(0.5, 0, 0, 22)
        DropBtn.Position = UDim2.new(0.47, 0, 0, 4)
        DropBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
        DropBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        DropBtn.Text = Config[key]
        DropBtn.Font = Enum.Font.SourceSans
        DropBtn.TextSize = 11
        DropBtn.Parent = Frame
        Instance.new("UICorner", DropBtn).CornerRadius = UDim.new(0, 4)

        local DropList = Instance.new("Frame")
        DropList.Size = UDim2.new(0.5, 0, 0, #options * 24)
        DropList.Position = UDim2.new(0.47, 0, 0, 27)
        DropList.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
        DropList.BorderSizePixel = 0
        DropList.Visible = false
        DropList.Parent = Frame
        Instance.new("UICorner", DropList).CornerRadius = UDim.new(0, 4)

        local DL = Instance.new("UIListLayout", DropList)
        DL.FillDirection = Enum.FillDirection.Vertical
        DL.SortOrder = Enum.SortOrder.LayoutOrder

        for _, opt in ipairs(options) do
            local OptBtn = Instance.new("TextButton")
            OptBtn.Size = UDim2.new(1, 0, 0, 24)
            OptBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
            OptBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            OptBtn.Text = opt
            OptBtn.Font = Enum.Font.SourceSans
            OptBtn.TextSize = 11
            OptBtn.Parent = DropList
            OptBtn.MouseButton1Click:Connect(function()
                Config[key] = opt
                DropBtn.Text = opt
                DropList.Visible = false
            end)
        end

        DropBtn.MouseButton1Click:Connect(function()
            DropList.Visible = not DropList.Visible
        end)
    end

    return tab
end

-- Tabs erstellen
local CombatTab = CreateTab("Combat", "⚔")
local VisualsTab = CreateTab("Visuals", "👁")
local MoveTab = CreateTab("Move", "🏃")
local AbilityTab = CreateTab("Ability", "✨")
local SettingsTab = CreateTab("Settings", "⚙")

-- ==================== GUI INHALT ====================

-- Combat Tab
CombatTab:AddDivider("Auto Parry")
CombatTab:AddToggle("Auto Parry", "AutoParry")
CombatTab:AddSlider("Parry Radius", "ParryRadius", 5, 40, 18)
CombatTab:AddToggle("Parry-Kreis anzeigen", "ShowParryCircle")
CombatTab:AddToggle("Humanized Timing", "ParryHumanize")

CombatTab:AddDivider("Auto Aim")
CombatTab:AddToggle("Auto Aim", "AutoAim")
CombatTab:AddSlider("Aim FOV", "AimFOV", 30, 180, 120)
CombatTab:AddToggle("Prediction", "AimPrediction")
CombatTab:AddDropdown("Priorität", "AimPriority", {"Distance", "Weakest", "Dangerous"}, "Distance")

-- Visuals Tab
VisualsTab:AddDivider("ESP")
VisualsTab:AddToggle("Ball ESP", "BallESP")
VisualsTab:AddToggle("Spieler ESP", "PlayerESP")
VisualsTab:AddToggle("Tracer", "Tracers")
VisualsTab:AddToggle("Radar", "Radar")
VisualsTab:AddToggle("Flugbahn", "ShowTrajectory")

-- Movement Tab
MoveTab:AddDivider("Movement")
MoveTab:AddToggle("Auto Dodge", "AutoDodge")
MoveTab:AddSlider("Walk Speed", "SpeedValue", 16, 100, 32)
MoveTab:AddToggle("Speed Hack", "SpeedHack")
MoveTab:AddSlider("Fly Speed", "FlySpeed", 20, 200, 50)
MoveTab:AddToggle("Fly", "Fly")

-- Ability Tab
AbilityTab:AddDivider("Abilities")
AbilityTab:AddToggle("Auto Abilities", "AutoAbilities")
AbilityTab:AddDropdown("Priorität", "AbilityPriority", {"Defensive", "Offensive", "Both"}, "Defensive")

-- Settings Tab
SettingsTab:AddDivider("Settings")
SettingsTab:AddToggle("Key-System", "KeySystem")

local CreditsFrame = Instance.new("Frame")
CreditsFrame.Size = UDim2.new(1, -2, 0, 120)
CreditsFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
CreditsFrame.Parent = SettingsTab.Content or ContentFrame
Instance.new("UICorner", CreditsFrame).CornerRadius = UDim.new(0, 6)

local CreditsText = Instance.new("TextLabel")
CreditsText.Size = UDim2.new(1, -16, 1, -16)
CreditsText.Position = UDim2.new(0, 8, 0, 8)
CreditsText.BackgroundTransparency = 1
CreditsText.TextColor3 = Color3.fromRGB(200, 230, 255)
CreditsText.Text = [[
⚔️ Blade Ball Ultimate ⚔️

Created by: plalettescripts

GitHub: plalettescripts/bladeball-script

Features:
- Auto Parry mit Radius
- Auto Aim mit Prediction
- Ball & Spieler ESP
- Tracer & Radar
- Auto Abilities
- Speed Hack & Fly
- Anti-Cheat Humanization

💙 Made by Plalette 💙
]]
CreditsText.Font = Enum.Font.SourceSans
CreditsText.TextSize = 11
CreditsText.TextXAlignment = Enum.TextXAlignment.Left
CreditsText.TextYAlignment = Enum.TextYAlignment.Top
CreditsText.TextWrapped = true
CreditsText.Parent = CreditsFrame

-- ==================== 3. AUTO PARRY ====================
task.spawn(function()
    while task.wait() do
        if Config.AutoParry then
            pcall(function()
                FindRemotes()
                local ball = FindBall()
                
                if ball and ParryRemote and LocalPlayer.Character then
                    local dist = BallDistanceToPlayer(ball, LocalPlayer)
                    local isTargeting = IsBallTargetingPlayer(ball, LocalPlayer)
                    
                    -- Parry auslösen wenn Ball in Reichweite und auf Spieler gerichtet
                    if dist <= Config.ParryRadius and isTargeting then
                        local delay = HumanizeDelay(Config.ParryDelayMin, Config.ParryDelayMax)
                        task.wait(delay)
                        
                        -- Parry Remote feuern
                        ParryRemote:FireServer()
                    end
                end
            end)
        end
        task.wait(0.016) -- ~60 FPS
    end
end)

-- ==================== 4. AUTO AIM ====================
task.spawn(function()
    while task.wait() do
        if Config.AutoAim then
            pcall(function()
                local ball = FindBall()
                if ball and LocalPlayer.Character then
                    local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local closestDist = math.huge
                        local target = nil
                        
                        -- Auto Aim nach erfolgreichem Parry
                        for _, player in ipairs(Players:GetPlayers()) do
                            if player ~= LocalPlayer and player.Character then
                                local targetHrp = player.Character:FindFirstChild("HumanoidRootPart")
                                if targetHrp then
                                    local dist = (targetHrp.Position - hrp.Position).Magnitude
                                    local screenPos, onScreen = Camera:WorldToViewportPoint(targetHrp.Position)
                                    
                                    if onScreen then
                                        local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)).Magnitude
                                        if screenDist < Config.AimFOV and dist < closestDist then
                                            closestDist = dist
                                            target = player
                                        end
                                    end
                                end
                            end
                        end
                        
                        -- Kamera auf Ziel richten
                        if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                            if Config.AimPrediction then
                                local velocity = target.Character.HumanoidRootPart.Velocity or Vector3.zero
                                local predictedPos = target.Character.HumanoidRootPart.Position + velocity * 0.3
                                Camera.CFrame = CFrame.new(Camera.CFrame.Position, predictedPos)
                            else
                                Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.Character.HumanoidRootPart.Position)
                            end
                        end
                    end
                end
            end)
        end
        task.wait(0.03)
    end
end)

-- ==================== 5. ESP & VISUALS ====================
-- Ball ESP
task.spawn(function()
    while task.wait(0.04) do
        ClearDrawings()
        
        if Config.BallESP then
            local ball = FindBall()
            if ball then
                local pos, onScreen = Camera:WorldToViewportPoint(ball.Position)
                if onScreen then
                    -- Ball-Name
                    local name = AddDrawing(Drawing.new("Text"))
                    name.Text = "⚽ Ball"
                    name.Color = Color3.fromRGB(255, 200, 50)
                    name.Size = 14
                    name.Position = Vector2.new(pos.X, pos.Y - 20)
                    name.Center = true
                    name.Visible = true
                    
                    -- Distanz
                    if LocalPlayer.Character then
                        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            local dist = math.floor((ball.Position - hrp.Position).Magnitude)
                            local distText = AddDrawing(Drawing.new("Text"))
                            distText.Text = dist .. "m"
                            distText.Color = Color3.fromRGB(200, 200, 200)
                            distText.Size = 11
                            distText.Position = Vector2.new(pos.X, pos.Y - 6)
                            distText.Center = true
                            distText.Visible = true
                        end
                    end
                    
                    -- Geschwindigkeitsbalken
                    local vel = ball.Velocity or ball.AssemblyLinearVelocity or Vector3.zero
                    local speed = math.floor(vel.Magnitude)
                    local barWidth = math.clamp(speed / 2, 10, 60)
                    local bar = AddDrawing(Drawing.new("Line"))
                    bar.Color = speed > 80 and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(50, 255, 50)
                    bar.Thickness = 3
                    bar.From = Vector2.new(pos.X - barWidth/2, pos.Y + 10)
                    bar.To = Vector2.new(pos.X + barWidth/2, pos.Y + 10)
                    bar.Visible = true
                    
                    -- Flugbahn-Vorschau
                    if Config.ShowTrajectory and vel.Magnitude > 1 then
                        local steps = 20
                        local prevPoint = Vector2.new(pos.X, pos.Y)
                        local direction = vel.Unit
                        local gravity = Vector3.new(0, -Workspace.Gravity, 0)
                        
                        for i = 1, steps do
                            local t = i * 0.05
                            local futurePos = ball.Position + vel * t + 0.5 * gravity * t * t
                            local futureScreen, futureOn = Camera:WorldToViewportPoint(futurePos)
                            if futureOn and (futureScreen - Vector3.new(pos.X, pos.Y, 0)).Magnitude < 300 then
                                local line = AddDrawing(Drawing.new("Line"))
                                line.Color = Color3.fromRGB(255, 255, 100)
                                line.Thickness = 0.5
                                line.From = prevPoint
                                line.To = Vector2.new(futureScreen.X, futureScreen.Y)
                                line.Visible = true
                                prevPoint = Vector2.new(futureScreen.X, futureScreen.Y)
                            end
                        end
                    end
                end
            end
        end
        
        -- Spieler ESP
        if Config.PlayerESP then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    local head = player.Character:FindFirstChild("Head")
                    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
                    
                    if head and hrp then
                        local headPos, onScreen = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
                        local legPos = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
                        
                        if onScreen then
                            local h = math.abs(headPos.Y - legPos.Y)
                            local w = h / 2
                            
                            -- Box
                            local box = AddDrawing(Drawing.new("Square"))
                            box.Color = Color3.fromRGB(0, 200, 255)
                            box.Thickness = 1
                            box.Size = Vector2.new(w, h)
                            box.Position = Vector2.new(headPos.X - w/2, headPos.Y)
                            box.Filled = false
                            box.Visible = true
                            
                            -- Name
                            local pName = AddDrawing(Drawing.new("Text"))
                            pName.Text = player.Name
                            pName.Color = Color3.fromRGB(255, 255, 255)
                            pName.Size = 12
                            pName.Position = Vector2.new(headPos.X, headPos.Y - 18)
                            pName.Center = true
                            pName.Visible = true
                            
                            -- Lebensbalken
                            if humanoid then
                                local healthPercent = humanoid.Health / humanoid.MaxHealth
                                local barH = h
                                local barX = headPos.X - w/2 - 6
                                
                                local healthBar = AddDrawing(Drawing.new("Line"))
                                healthBar.Color = Color3.fromRGB(50, 255, 50)
                                healthBar.Thickness = 2
                                healthBar.From = Vector2.new(barX, legPos.Y)
                                healthBar.To = Vector2.new(barX, legPos.Y + barH * healthPercent)
                                healthBar.Visible = true
                            end
                        end
                    end
                end
            end
        end
        
        -- Tracer
        if Config.Tracers then
            local ball = FindBall()
            if ball then
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer and player.Character then
                        local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            local playerPos, pOn = Camera:WorldToViewportPoint(hrp.Position)
                            local ballPos, bOn = Camera:WorldToViewportPoint(ball.Position)
                            if pOn and bOn then
                                local line = AddDrawing(Drawing.new("Line"))
                                line.Color = Color3.fromRGB(0, 200, 255)
                                line.Thickness = 0.5
                                line.From = Vector2.new(playerPos.X, playerPos.Y)
                                line.To = Vector2.new(ballPos.X, ballPos.Y)
                                line.Visible = true
                            end
                        end
                    end
                end
            end
        end
        
        -- Parry-Radius-Kreis
        if Config.ShowParryCircle and LocalPlayer.Character then
            local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local circlePos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                if onScreen then
                    local ball = FindBall()
                    local dist = ball and BallDistanceToPlayer(ball, LocalPlayer) or 999
                    local isTargeting = ball and IsBallTargetingPlayer(ball, LocalPlayer) or false
                    
                    local color = Color3.fromRGB(50, 255, 50) -- Grün: sicher
                    if isTargeting and dist < Config.ParryRadius * 2 then
                        color = Color3.fromRGB(255, 255, 50) -- Gelb: Ball nähert sich
                    end
                    if isTargeting and dist < Config.ParryRadius then
                        color = Color3.fromRGB(255, 50, 50) -- Rot: kritisch
                    end
                    
                    local radius = Config.ParryRadius * 3
                    local circle = AddDrawing(Drawing.new("Circle"))
                    circle.Color = color
                    circle.Thickness = 1.5
                    circle.Radius = radius
                    circle.Position = Vector2.new(circlePos.X, circlePos.Y)
                    circle.Filled = false
                    circle.Visible = true
                end
            end
        end
        
        -- Radar
        if Config.Radar then
            local radarSize = 100
            local radarX = Camera.ViewportSize.X - radarSize - 20
            local radarY = Camera.ViewportSize.Y - radarSize - 20
            
            local radarBg = AddDrawing(Drawing.new("Square"))
            radarBg.Color = Color3.fromRGB(0, 0, 0)
            radarBg.Thickness = 1
            radarBg.Size = Vector2.new(radarSize, radarSize)
            radarBg.Position = Vector2.new(radarX, radarY)
            radarBg.Filled = true
            radarBg.Visible = true
            
            -- Spieler-Punkte auf Radar
            if LocalPlayer.Character then
                local myHrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if myHrp then
                    for _, player in ipairs(Players:GetPlayers()) do
                        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                            local targetHrp = player.Character.HumanoidRootPart
                            local offset = targetHrp.Position - myHrp.Position
                            local radarDist = math.clamp(offset.Magnitude / 2, 0, radarSize/2 - 3)
                            local angle = math.atan2(offset.Z, offset.X)
                            
                            local dotX = radarX + radarSize/2 + math.cos(angle) * radarDist
                            local dotY = radarY + radarSize/2 + math.sin(angle) * radarDist
                            
                            local dot = AddDrawing(Drawing.new("Circle"))
                            dot.Color = player == LocalPlayer and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
                            dot.Radius = 3
                            dot.Position = Vector2.new(dotX, dotY)
                            dot.Filled = true
                            dot.Visible = true
                        end
                    end
                    
                    -- Ball auf Radar
                    local ball = FindBall()
                    if ball then
                        local offset = ball.Position - myHrp.Position
                        local radarDist = math.clamp(offset.Magnitude / 2, 0, radarSize/2 - 3)
                        local angle = math.atan2(offset.Z, offset.X)
                        local dotX = radarX + radarSize/2 + math.cos(angle) * radarDist
                        local dotY = radarY + radarSize/2 + math.sin(angle) * radarDist
                        
                        local ballDot = AddDrawing(Drawing.new("Circle"))
                        ballDot.Color = Color3.fromRGB(255, 255, 0)
                        ballDot.Radius = 4
                        ballDot.Position = Vector2.new(dotX, dotY)
                        ballDot.Filled = true
                        ballDot.Visible = true
                    end
                end
            end
        end
    end
end)

-- ==================== 6. ABILITY AUTOMATISIERUNG ====================
task.spawn(function()
    while task.wait(0.5) do
        if Config.AutoAbilities then
            pcall(function()
                FindRemotes()
                
                if AbilityRemote then
                    local ball = FindBall()
                    local dist = ball and BallDistanceToPlayer(ball, LocalPlayer) or 999
                    local isTargeting = ball and IsBallTargetingPlayer(ball, LocalPlayer) or false
                    
                    -- Defensive: Nutze Ability wenn Ball gefährlich nah
                    if Config.AbilityPriority == "Defensive" or Config.AbilityPriority == "Both" then
                        if isTargeting and dist < Config.ParryRadius * 1.5 then
                            AbilityRemote:FireServer("Dash") -- oder passenden Ability-Namen
                        end
                    end
                    
                    -- Offensive: Nutze Ability wenn Ball weit weg
                    if Config.AbilityPriority == "Offensive" or Config.AbilityPriority == "Both" then
                        if dist > Config.ParryRadius * 3 then
                            AbilityRemote:FireServer("Rage") -- oder passenden Ability-Namen
                        end
                    end
                end
            end)
        end
    end
end)

-- ==================== 7. MOVEMENT ====================
-- Speed Hack
RunService.Stepped:Connect(function()
    if Config.SpeedHack and LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = Config.SpeedValue
        end
    end
end)

-- Fly
task.spawn(function()
    while task.wait() do
        if Config.Fly and LocalPlayer.Character then
            local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local gyro = hrp:FindFirstChild("FlyGyro") or Instance.new("BodyGyro", hrp)
                local vel = hrp:FindFirstChild("FlyVel") or Instance.new("BodyVelocity", hrp)
                gyro.Name = "FlyGyro"
                gyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
                gyro.CFrame = Camera.CFrame
                vel.Name = "FlyVel"
                vel.MaxForce = Vector3.new(9e9, 9e9, 9e9)

                local speed = Config.FlySpeed or 50
                local move = Vector3.zero
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += Camera.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= Camera.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= Camera.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += Camera.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0, 1, 0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then move -= Vector3.new(0, 1, 0) end
                vel.Velocity = move * speed
            end
        end
    end
end)

-- ==================== 8. SPIELMODUS-ERKENNUNG ====================
task.spawn(function()
    while task.wait(2) do
        pcall(function()
            -- Einfache Spielmodus-Erkennung über GUI-Elemente
            local screenGuis = LocalPlayer.PlayerGui:GetChildren()
            for _, gui in ipairs(screenGuis) do
                if gui:IsA("ScreenGui") then
                    local text = gui.Name:lower()
                    if text:find("clash") then GameMode = "Clash"
                    elseif text:find("team") then GameMode = "Teams"
                    elseif text:find("sudden") then GameMode = "Sudden Death"
                    else GameMode = "Standard" end
                end
            end
        end)
    end
end)

-- ==================== 9. BENACHRICHTIGUNGS-SYSTEM ====================
local function Notify(title, message, duration)
    duration = duration or 3
    local NotifFrame = Instance.new("Frame")
    NotifFrame.Size = UDim2.new(0, 220, 0, 50)
    NotifFrame.Position = UDim2.new(1, -230, 1, -60)
    NotifFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    NotifFrame.BorderSizePixel = 0
    NotifFrame.Parent = ScreenGui
    Instance.new("UICorner", NotifFrame).CornerRadius = UDim.new(0, 6)
    
    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size = UDim2.new(1, -10, 0, 18)
    TitleLabel.Position = UDim2.new(0, 5, 0, 3)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
    TitleLabel.Text = title
    TitleLabel.Font = Enum.Font.SourceSansBold
    TitleLabel.TextSize = 12
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Parent = NotifFrame
    
    local MsgLabel = Instance.new("TextLabel")
    MsgLabel.Size = UDim2.new(1, -10, 0, 24)
    MsgLabel.Position = UDim2.new(0, 5, 0, 22)
    MsgLabel.BackgroundTransparency = 1
    MsgLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    MsgLabel.Text = message
    MsgLabel.Font = Enum.Font.SourceSans
    MsgLabel.TextSize = 11
    MsgLabel.TextXAlignment = Enum.TextXAlignment.Left
    MsgLabel.Parent = NotifFrame
    
    task.delay(duration, function()
        pcall(function() NotifFrame:Destroy() end)
    end)
end

-- ==================== 10. WILLKOMMENSNACHRICHT ====================
Notify("⚔️ Blade Ball Ultimate", "Willkommen! Created by plalettescripts", 5)
print("⚔️ Blade Ball Ultimate geladen!")
print("👤 Created by: plalettescripts")
print("⚡ Auto Parry | ESP | Aimbot | Fly | Abilities")
print("🔵 CTRL = Minimieren")
