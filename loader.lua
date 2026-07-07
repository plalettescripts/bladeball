--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║                    BLADE BALL ULTIMATE v2.0                 ║
    ║                  Created by: plalettescripts                ║
    ╚══════════════════════════════════════════════════════════════╝
    
    ÄNDERUNGEN v2.0:
    - Neues Layout: Menü oben links, 90% Flächennutzung
    - Credits als ausblendbarer Footer
    - Auto-Parry als ERSTES Element auf Tab 1, großer leuchtender Button
    - Parry: KEINE Delays, KEIN FOV, KEIN Distanz-Limit, KEIN Sichtbarkeits-Check
    - Parry: Instant 0ms, feuert durch Wände, spam-geschützt
    - ESP: Weißer Parry-Radius-Kreis + Linie Ball→Spieler
    - Test-Button zum Ball spawnen
    - X-Button zum Verstecken von Beschreibungen
]]

-- ==================== 1. SERVICES ====================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ==================== 2. KONFIGURATION ====================
local Config = {
    AutoParry = false,
    ParryDistance = 25,
    ShowParryCircle = true,
    ShowBallLine = true,
    AutoAim = false,
    AimFOV = 120,
    AimPrediction = true,
    AimPriority = "Distance",
    BallESP = false,
    PlayerESP = false,
    Tracers = false,
    Radar = false,
    ShowTrajectory = false,
    SpeedHack = false,
    SpeedValue = 32,
    Fly = false,
    FlySpeed = 50,
    AutoAbilities = false,
    AbilityPriority = "Defensive",
    ShowDescriptions = true
}

-- ==================== 3. VARIABLEN ====================
local ESPDrawings = {}
local ParryRemote = nil
local AbilityRemote = nil

local function ClearDrawings()
    for _, d in pairs(ESPDrawings) do pcall(function() d:Remove() end) end
    ESPDrawings = {}
end

local function AddDrawing(drawing)
    if #ESPDrawings >= 100 then
        local old = table.remove(ESPDrawings, 1)
        pcall(function() old:Remove() end)
    end
    table.insert(ESPDrawings, drawing)
    return drawing
end

-- Ball finden
local function FindBall()
    local ball = Workspace:FindFirstChild("Ball") or Workspace:FindFirstChild("BladeBall")
    if ball and ball:IsA("BasePart") then return ball end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj.Name == "Ball" and obj:IsA("BasePart") then return obj end
    end
    for _, obj in ipairs(CollectionService:GetTagged("Ball")) do
        if obj:IsA("BasePart") then return obj end
    end
    return nil
end

-- Remote Events finden
local function FindRemotes()
    if ParryRemote then return end
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            local name = obj.Name:lower()
            if name:find("parry") or name:find("block") or name:find("defend") or name:find("hit") then
                ParryRemote = obj
            elseif name:find("ability") or name:find("skill") then
                AbilityRemote = obj
            end
        end
    end
end

-- ==================== 4. GUI - NEUES LAYOUT ====================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PlaletteBladeBall"
ScreenGui.Parent = CoreGui

-- Hauptmenü (90% Fläche, oben links)
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 320, 0.9, 0)
MainFrame.Position = UDim2.new(0.01, 0, 0.01, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

-- Animierter Rand
local Border = Instance.new("Frame")
Border.Size = UDim2.new(1, 4, 1, 4)
Border.Position = UDim2.new(0, -2, 0, -2)
Border.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
Border.BorderSizePixel = 0
Border.Parent = MainFrame
Instance.new("UICorner", Border).CornerRadius = UDim.new(0, 11)

task.spawn(function()
    local hue = 0.3
    while ScreenGui and ScreenGui.Parent do
        hue = hue + 0.003
        if hue > 0.4 then hue = 0.3 end
        pcall(function() Border.BackgroundColor3 = Color3.fromHSV(hue, 1, 1) end)
        task.wait(0.03)
    end
end)

-- Minimiert
local MiniFrame = Instance.new("Frame")
MiniFrame.Size = UDim2.new(0, 200, 0, 35)
MiniFrame.Position = UDim2.new(0.01, 0, 0.01, 0)
MiniFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 20)
MiniFrame.BorderSizePixel = 0
MiniFrame.Visible = false
MiniFrame.Active = true
MiniFrame.Draggable = true
MiniFrame.Parent = ScreenGui
Instance.new("UICorner", MiniFrame).CornerRadius = UDim.new(0, 8)

local MiniText = Instance.new("TextLabel")
MiniText.Size = UDim2.new(1, 0, 1, 0)
MiniText.BackgroundTransparency = 1
MiniText.TextColor3 = Color3.fromRGB(0, 255, 100)
MiniText.Text = "⚡ BB v2.0 | plalettescripts"
MiniText.Font = Enum.Font.SourceSansBold
MiniText.TextSize = 11
MiniText.Parent = MiniFrame

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl then
        MainFrame.Visible = not MainFrame.Visible
        MiniFrame.Visible = not MiniFrame.Visible
    end
end)

-- Titel mit v2.0
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 40)
TitleBar.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 10)

local TitleText = Instance.new("TextLabel")
TitleText.Size = UDim2.new(0.6, 0, 0.55, 0)
TitleText.Position = UDim2.new(0.04, 0, 0, 0)
TitleText.BackgroundTransparency = 1
TitleText.TextColor3 = Color3.fromRGB(0, 255, 100)
TitleText.Text = "BLADE BALL v2.0"
TitleText.Font = Enum.Font.SourceSansBold
TitleText.TextSize = 17
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.Parent = TitleBar

local VersionText = Instance.new("TextLabel")
VersionText.Size = UDim2.new(0.6, 0, 0.35, 0)
VersionText.Position = UDim2.new(0.04, 0, 0.55, 0)
VersionText.BackgroundTransparency = 1
VersionText.TextColor3 = Color3.fromRGB(0, 180, 80)
VersionText.Text = "plalettescripts | Instant Parry"
VersionText.Font = Enum.Font.SourceSans
VersionText.TextSize = 9
VersionText.TextXAlignment = Enum.TextXAlignment.Left
VersionText.Parent = TitleBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 26, 0, 22)
CloseBtn.Position = UDim2.new(1, -60, 0, 8)
CloseBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Text = "_"
CloseBtn.Font = Enum.Font.SourceSansBold
CloseBtn.TextSize = 14
CloseBtn.Parent = TitleBar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 4)
CloseBtn.MouseButton1Click:Connect(function()
    Config.ShowDescriptions = not Config.ShowDescriptions
end)

local CloseBtn2 = Instance.new("TextButton")
CloseBtn2.Size = UDim2.new(0, 26, 0, 22)
CloseBtn2.Position = UDim2.new(1, -32, 0, 8)
CloseBtn2.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
CloseBtn2.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn2.Text = "X"
CloseBtn2.Font = Enum.Font.SourceSansBold
CloseBtn2.TextSize = 13
CloseBtn2.Parent = TitleBar
Instance.new("UICorner", CloseBtn2).CornerRadius = UDim.new(0, 4)
CloseBtn2.MouseButton1Click:Connect(function()
    ClearDrawings()
    ScreenGui:Destroy()
end)

-- Tab-System
local TabContainer = Instance.new("Frame")
TabContainer.Size = UDim2.new(0, 90, 1, -44)
TabContainer.Position = UDim2.new(0, 3, 0, 42)
TabContainer.BackgroundColor3 = Color3.fromRGB(16, 16, 26)
TabContainer.BorderSizePixel = 0
TabContainer.Parent = MainFrame
Instance.new("UICorner", TabContainer).CornerRadius = UDim.new(0, 6)

local TabList = Instance.new("UIListLayout")
TabList.Padding = UDim.new(0, 2)
TabList.FillDirection = Enum.FillDirection.Vertical
TabList.SortOrder = Enum.SortOrder.LayoutOrder
TabList.Parent = TabContainer

local ContentFrame = Instance.new("Frame")
ContentFrame.Size = UDim2.new(1, -98, 1, -70)
ContentFrame.Position = UDim2.new(0, 95, 0, 42)
ContentFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
ContentFrame.BorderSizePixel = 0
ContentFrame.Parent = MainFrame
Instance.new("UICorner", ContentFrame).CornerRadius = UDim.new(0, 6)

-- Footer Credits (ausblendbar)
local FooterFrame = Instance.new("Frame")
FooterFrame.Size = UDim2.new(1, -98, 0, 22)
FooterFrame.Position = UDim2.new(0, 95, 1, -26)
FooterFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
FooterFrame.BorderSizePixel = 0
FooterFrame.Parent = MainFrame
Instance.new("UICorner", FooterFrame).CornerRadius = UDim.new(0, 4)

local FooterText = Instance.new("TextLabel")
FooterText.Size = UDim2.new(1, -10, 1, 0)
FooterText.Position = UDim2.new(0, 5, 0, 0)
FooterText.BackgroundTransparency = 1
FooterText.TextColor3 = Color3.fromRGB(150, 150, 170)
FooterText.Text = "v2.0 | plalettescripts | Instant Parry"
FooterText.Font = Enum.Font.SourceSans
FooterText.TextSize = 10
FooterText.TextXAlignment = Enum.TextXAlignment.Left
FooterText.Parent = FooterFrame

-- Tab-Erstellung
local function CreateTab(name, icon)
    local TabBtn = Instance.new("TextButton")
    TabBtn.Size = UDim2.new(1, -6, 0, 28)
    TabBtn.Position = UDim2.new(0, 3, 0, 0)
    TabBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
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
    Content.ScrollBarImageColor3 = Color3.fromRGB(0, 255, 100)
    Content.CanvasSize = UDim2.new(0, 0, 0, 700)
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
                child.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
                child.TextColor3 = Color3.fromRGB(180, 180, 200)
            end
        end
        Content.Visible = true
        TabBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 80)
        TabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    end)

    local found = false
    for _, child in ipairs(ContentFrame:GetChildren()) do
        if child:IsA("ScrollingFrame") and child.Visible then found = true end
    end
    if not found then
        Content.Visible = true
        TabBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 80)
        TabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    end

    local tab = {}

    function tab:AddBigButton(name, key, color)
        local Btn = Instance.new("TextButton")
        Btn.Size = UDim2.new(1, -4, 0, 40)
        Btn.BackgroundColor3 = color or Color3.fromRGB(0, 200, 60)
        Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        Btn.Text = name
        Btn.Font = Enum.Font.SourceSansBold
        Btn.TextSize = 14
        Btn.Parent = Content
        Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 6)

        local on = false
        Btn.MouseButton1Click:Connect(function()
            on = not on
            Config[key] = on
            Btn.BackgroundColor3 = on and Color3.fromRGB(0, 255, 80) or Color3.fromRGB(40, 40, 55)
            Btn.Text = on and "⚡ " .. name .. " - ACTIVE" or name
        end)
    end

    function tab:AddToggle(name, key)
        local Frame = Instance.new("Frame")
        Frame.Size = UDim2.new(1, -4, 0, 28)
        Frame.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
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
        Btn.Size = UDim2.new(0, 34, 0, 18)
        Btn.Position = UDim2.new(0.9, -34, 0, 5)
        Btn.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
        Btn.Text = ""
        Btn.Parent = Frame
        Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 9)

        local on = false
        Btn.MouseButton1Click:Connect(function()
            on = not on
            Config[key] = on
            Label.Text = name .. " : " .. (on and "ON" or "OFF")
            Btn.BackgroundColor3 = on and Color3.fromRGB(0, 200, 80) or Color3.fromRGB(50, 50, 65)
        end)
    end

    function tab:AddSlider(name, key, min, max, default)
        Config[key] = default
        local Frame = Instance.new("Frame")
        Frame.Size = UDim2.new(1, -4, 0, 46)
        Frame.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
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
        Input.Position = UDim2.new(0.35, 0, 0, 22)
        Input.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
        Input.TextColor3 = Color3.fromRGB(200, 255, 220)
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

    function tab:AddButton(name, callback)
        local Btn = Instance.new("TextButton")
        Btn.Size = UDim2.new(1, -4, 0, 28)
        Btn.BackgroundColor3 = Color3.fromRGB(0, 180, 200)
        Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        Btn.Text = name
        Btn.Font = Enum.Font.SourceSansBold
        Btn.TextSize = 11
        Btn.Parent = Content
        Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 4)
        Btn.MouseButton1Click:Connect(callback)
    end

    function tab:AddDropdown(name, key, options, default)
        Config[key] = default or options[1]
        local Frame = Instance.new("Frame")
        Frame.Size = UDim2.new(1, -4, 0, 28)
        Frame.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
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
        DropBtn.Size = UDim2.new(0.5, 0, 0, 20)
        DropBtn.Position = UDim2.new(0.47, 0, 0, 4)
        DropBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
        DropBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        DropBtn.Text = Config[key]
        DropBtn.Font = Enum.Font.SourceSans
        DropBtn.TextSize = 11
        DropBtn.Parent = Frame
        Instance.new("UICorner", DropBtn).CornerRadius = UDim.new(0, 4)

        local DropList = Instance.new("Frame")
        DropList.Size = UDim2.new(0.5, 0, 0, #options * 22)
        DropList.Position = UDim2.new(0.47, 0, 0, 25)
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
            OptBtn.Size = UDim2.new(1, 0, 0, 22)
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

-- Tabs
local CombatTab = CreateTab("Combat", "⚔")
local VisualsTab = CreateTab("Visuals", "👁")
local MoveTab = CreateTab("Move", "🏃")

-- ==================== COMBAT TAB - AUTO PARRY ZUERST ====================

-- 1. AUTO PARRY - Großer Button, ERSTES Element
CombatTab:AddBigButton("AUTO PARRY (Instant)", "AutoParry", Color3.fromRGB(0, 180, 50))

-- 2. Parry Distance Slider
CombatTab:AddSlider("Parry Distance", "ParryDistance", 5, 200, 25)

-- 3. Parry Visuals
CombatTab:AddToggle("Parry Circle", "ShowParryCircle")
CombatTab:AddToggle("Ball Line", "ShowBallLine")

-- 4. Test Button
CombatTab:AddButton("Test Ball Spawnen", function()
    local ball = Instance.new("Part")
    ball.Name = "Ball"
    ball.Size = Vector3.new(2, 2, 2)
    ball.Shape = Enum.PartType.Ball
    ball.Position = LocalPlayer.Character and LocalPlayer.Character.HumanoidRootPart.Position + Vector3.new(20, 0, 0) or Vector3.new(0, 20, 0)
    ball.Velocity = (LocalPlayer.Character and LocalPlayer.Character.HumanoidRootPart.Position - ball.Position).Unit * 80 or Vector3.new(-80, 0, 0)
    ball.Parent = Workspace
    task.delay(5, function() pcall(function() ball:Destroy() end) end)
end)

-- 5. Auto Aim
CombatTab:AddToggle("Auto Aim", "AutoAim")
CombatTab:AddSlider("Aim FOV", "AimFOV", 30, 180, 120)
CombatTab:AddToggle("Prediction", "AimPrediction")
CombatTab:AddDropdown("Priority", "AimPriority", {"Distance", "Weakest", "Dangerous"}, "Distance")

-- Visuals Tab
VisualsTab:AddToggle("Ball ESP", "BallESP")
VisualsTab:AddToggle("Player ESP", "PlayerESP")
VisualsTab:AddToggle("Tracers", "Tracers")
VisualsTab:AddToggle("Radar", "Radar")
VisualsTab:AddToggle("Trajectory", "ShowTrajectory")

-- Movement Tab
MoveTab:AddSlider("Walk Speed", "SpeedValue", 16, 100, 32)
MoveTab:AddToggle("Speed Hack", "SpeedHack")
MoveTab:AddSlider("Fly Speed", "FlySpeed", 20, 200, 50)
MoveTab:AddToggle("Fly", "Fly")

-- ==================== 5. AUTO PARRY - INSTANT, 0ms, KEINE LIMITS ====================
task.spawn(function()
    while task.wait() do
        if Config.AutoParry then
            pcall(function()
                FindRemotes()
                local ball = FindBall()
                
                if ball and ParryRemote then
                    -- KEIN Distanz-Check
                    -- KEIN Sichtbarkeits-Check
                    -- KEIN FOV-Check
                    -- KEIN Delay
                    -- Einfach feuern bei Erkennung
                    
                    -- Spam-Schutz: Mehrfach feuern
                    for i = 1, 3 do
                        ParryRemote:FireServer()
                    end
                end
            end)
        end
        task.wait() -- Maximale Geschwindigkeit
    end
end)

-- ==================== 6. AUTO AIM ====================
task.spawn(function()
    while task.wait(0.02) do
        if Config.AutoAim and LocalPlayer.Character then
            pcall(function()
                local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local closestDist = math.huge
                    local target = nil
                    
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
            end)
        end
    end
end)

-- ==================== 7. ESP & VISUALS ====================
task.spawn(function()
    while task.wait(0.04) do
        ClearDrawings()
        
        -- Parry Circle + Ball Line
        if (Config.ShowParryCircle or Config.ShowBallLine) and LocalPlayer.Character then
            local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local playerPos, pOn = Camera:WorldToViewportPoint(hrp.Position)
                
                -- Weißer Parry-Kreis
                if Config.ShowParryCircle and pOn then
                    local circle = AddDrawing(Drawing.new("Circle"))
                    circle.Color = Color3.fromRGB(255, 255, 255)
                    circle.Thickness = 1.5
                    circle.Radius = Config.ParryDistance * 2.5
                    circle.Position = Vector2.new(playerPos.X, playerPos.Y)
                    circle.Filled = false
                    circle.Visible = true
                end
                
                -- Linie Ball zu Spieler
                if Config.ShowBallLine then
                    local ball = FindBall()
                    if ball then
                        local ballPos, bOn = Camera:WorldToViewportPoint(ball.Position)
                        if pOn and bOn then
                            local line = AddDrawing(Drawing.new("Line"))
                            line.Color = Color3.fromRGB(255, 255, 255)
                            line.Thickness = 1
                            line.From = Vector2.new(ballPos.X, ballPos.Y)
                            line.To = Vector2.new(playerPos.X, playerPos.Y)
                            line.Visible = true
                        end
                    end
                end
            end
        end
        
        -- Ball ESP
        if Config.BallESP then
            local ball = FindBall()
            if ball then
                local pos, onScreen = Camera:WorldToViewportPoint(ball.Position)
                if onScreen then
                    local name = AddDrawing(Drawing.new("Text"))
                    name.Text = "Ball"
                    name.Color = Color3.fromRGB(255, 200, 50)
                    name.Size = 14
                    name.Position = Vector2.new(pos.X, pos.Y - 15)
                    name.Center = true
                    name.Visible = true
                end
            end
        end
        
        -- Player ESP
        if Config.PlayerESP then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    local head = player.Character:FindFirstChild("Head")
                    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                    if head and hrp then
                        local headPos, onScreen = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
                        local legPos = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
                        if onScreen then
                            local h = math.abs(headPos.Y - legPos.Y)
                            local w = h / 2
                            local box = AddDrawing(Drawing.new("Square"))
                            box.Color = Color3.fromRGB(0, 255, 100)
                            box.Thickness = 1
                            box.Size = Vector2.new(w, h)
                            box.Position = Vector2.new(headPos.X - w/2, headPos.Y)
                            box.Filled = false
                            box.Visible = true
                            
                            local pName = AddDrawing(Drawing.new("Text"))
                            pName.Text = player.Name
                            pName.Color = Color3.fromRGB(255, 255, 255)
                            pName.Size = 12
                            pName.Position = Vector2.new(headPos.X, headPos.Y - 18)
                            pName.Center = true
                            pName.Visible = true
                        end
                    end
                end
            end
        end
        
        -- Tracers
        if Config.Tracers then
            local ball = FindBall()
            if ball then
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer and player.Character then
                        local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            local pPos, pOn = Camera:WorldToViewportPoint(hrp.Position)
                            local bPos, bOn = Camera:WorldToViewportPoint(ball.Position)
                            if pOn and bOn then
                                local line = AddDrawing(Drawing.new("Line"))
                                line.Color = Color3.fromRGB(0, 200, 100)
                                line.Thickness = 0.5
                                line.From = Vector2.new(pPos.X, pPos.Y)
                                line.To = Vector2.new(bPos.X, bPos.Y)
                                line.Visible = true
                            end
                        end
                    end
                end
            end
        end
        
        -- Radar
        if Config.Radar then
            local rs = 80
            local rx = 10
            local ry = Camera.ViewportSize.Y - rs - 10
            
            local bg = AddDrawing(Drawing.new("Square"))
            bg.Color = Color3.fromRGB(0, 0, 0)
            bg.Size = Vector2.new(rs, rs)
            bg.Position = Vector2.new(rx, ry)
            bg.Filled = true
            bg.Visible = true
            
            if LocalPlayer.Character then
                local myHrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if myHrp then
                    for _, player in ipairs(Players:GetPlayers()) do
                        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                            local tHrp = player.Character.HumanoidRootPart
                            local off = tHrp.Position - myHrp.Position
                            local rd = math.clamp(off.Magnitude / 2, 0, rs/2 - 3)
                            local ang = math.atan2(off.Z, off.X)
                            local dx = rx + rs/2 + math.cos(ang) * rd
                            local dy = ry + rs/2 + math.sin(ang) * rd
                            
                            local dot = AddDrawing(Drawing.new("Circle"))
                            dot.Color = player == LocalPlayer and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
                            dot.Radius = 2
                            dot.Position = Vector2.new(dx, dy)
                            dot.Filled = true
                            dot.Visible = true
                        end
                    end
                    
                    local ball = FindBall()
                    if ball then
                        local off = ball.Position - myHrp.Position
                        local rd = math.clamp(off.Magnitude / 2, 0, rs/2 - 2)
                        local ang = math.atan2(off.Z, off.X)
                        local dx = rx + rs/2 + math.cos(ang) * rd
                        local dy = ry + rs/2 + math.sin(ang) * rd
                        
                        local bd = AddDrawing(Drawing.new("Circle"))
                        bd.Color = Color3.fromRGB(255, 255, 0)
                        bd.Radius = 3
                        bd.Position = Vector2.new(dx, dy)
                        bd.Filled = true
                        bd.Visible = true
                    end
                end
            end
        end
    end
end)

-- ==================== 8. AUTO ABILITIES ====================
task.spawn(function()
    while task.wait(0.3) do
        if Config.AutoAbilities then
            pcall(function()
                FindRemotes()
                if AbilityRemote then
                    local ball = FindBall()
                    if ball then
                        if Config.AbilityPriority == "Defensive" or Config.AbilityPriority == "Both" then
                            AbilityRemote:FireServer("Dash")
                        end
                        if Config.AbilityPriority == "Offensive" or Config.AbilityPriority == "Both" then
                            AbilityRemote:FireServer("Rage")
                        end
                    end
                end
            end)
        end
    end
end)

-- ==================== 9. MOVEMENT ====================
RunService.Stepped:Connect(function()
    if Config.SpeedHack and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = Config.SpeedValue end
    end
end)

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

print("⚡ Blade Ball v2.0 - Instant Parry | plalettescripts")
