-- Blade Ball Ultimate Script
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

local Config = {
    AutoParry = false,
    ParryRadius = 18,
    ShowParryCircle = true,
    AutoAim = false,
    AimFOV = 120,
    AimPrediction = true,
    AimPriority = "Distance",
    BallESP = false,
    PlayerESP = false,
    Tracers = false,
    Radar = false,
    ShowTrajectory = true,
    AutoDodge = false,
    SpeedHack = false,
    SpeedValue = 32,
    Fly = false,
    FlySpeed = 50,
    AutoAbilities = false,
    AbilityPriority = "Defensive"
}

local ESPDrawings = {}
local Connections = {}
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

local function FindBall()
    local ball = Workspace:FindFirstChild("Ball") or Workspace:FindFirstChild("BladeBall")
    if ball and ball:IsA("BasePart") then return ball end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj.Name == "Ball" and obj:IsA("BasePart") and obj.Velocity.Magnitude > 1 then
            return obj
        end
    end
    for _, obj in ipairs(CollectionService:GetTagged("Ball")) do
        if obj:IsA("BasePart") then return obj end
    end
    return nil
end

local function FindRemotes()
    if ParryRemote and AbilityRemote then return end
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            local name = obj.Name:lower()
            if name:find("parry") or name:find("block") or name:find("defend") then
                ParryRemote = obj
            elseif name:find("ability") or name:find("skill") or name:find("dash") then
                AbilityRemote = obj
            end
        end
    end
end

local function IsBallTargetingPlayer(ball, player)
    if not ball or not player or not player.Character then return false end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local ballVelocity = ball.Velocity or ball.AssemblyLinearVelocity or Vector3.zero
    if ballVelocity.Magnitude < 1 then return false end
    local ballToPlayer = (hrp.Position - ball.Position).Unit
    local ballDirection = ballVelocity.Unit
    local dotProduct = ballToPlayer:Dot(ballDirection)
    return dotProduct > 0.3
end

local function BallDistanceToPlayer(ball, player)
    if not ball or not player or not player.Character then return 999 end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return 999 end
    return (ball.Position - hrp.Position).Magnitude
end

-- GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PlaletteBladeBall"
ScreenGui.Parent = CoreGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 300, 0, 400)
MainFrame.Position = UDim2.new(0.75, 0, 0.2, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

local Border = Instance.new("Frame")
Border.Size = UDim2.new(1, 4, 1, 4)
Border.Position = UDim2.new(0, -2, 0, -2)
Border.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
Border.BorderSizePixel = 0
Border.Parent = MainFrame
Instance.new("UICorner", Border).CornerRadius = UDim.new(0, 11)

task.spawn(function()
    local hue = 0.55
    while ScreenGui and ScreenGui.Parent do
        hue = hue + 0.003
        if hue > 0.62 then hue = 0.55 end
        pcall(function() Border.BackgroundColor3 = Color3.fromHSV(hue, 0.8, 1) end)
        task.wait(0.03)
    end
end)

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
MiniText.Text = "plalettescripts - Press CTRL"
MiniText.Font = Enum.Font.SourceSansBold
MiniText.TextSize = 12
MiniText.Parent = MiniFrame

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl then
        MainFrame.Visible = not MainFrame.Visible
        MiniFrame.Visible = not MiniFrame.Visible
    end
end)

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
TitleText.Text = "Blade Ball Ultimate"
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
    Content.CanvasSize = UDim2.new(0, 0, 0, 600)
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
        Lbl.Text = text
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

local CombatTab = CreateTab("Combat", "⚔")
local VisualsTab = CreateTab("Visuals", "👁")
local MoveTab = CreateTab("Move", "🏃")
local AbilityTab = CreateTab("Ability", "✨")

-- Combat Tab
CombatTab:AddDivider("Auto Parry")
CombatTab:AddToggle("Auto Parry (Instant)", "AutoParry")
CombatTab:AddSlider("Parry Radius", "ParryRadius", 5, 40, 18)
CombatTab:AddToggle("Parry Circle", "ShowParryCircle")

CombatTab:AddDivider("Auto Aim")
CombatTab:AddToggle("Auto Aim", "AutoAim")
CombatTab:AddSlider("Aim FOV", "AimFOV", 30, 180, 120)
CombatTab:AddToggle("Prediction", "AimPrediction")
CombatTab:AddDropdown("Priority", "AimPriority", {"Distance", "Weakest", "Dangerous"}, "Distance")

-- Visuals Tab
VisualsTab:AddDivider("ESP")
VisualsTab:AddToggle("Ball ESP", "BallESP")
VisualsTab:AddToggle("Player ESP", "PlayerESP")
VisualsTab:AddToggle("Tracers", "Tracers")
VisualsTab:AddToggle("Radar", "Radar")
VisualsTab:AddToggle("Trajectory", "ShowTrajectory")

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
AbilityTab:AddDropdown("Priority", "AbilityPriority", {"Defensive", "Offensive", "Both"}, "Defensive")

-- Credits (in Settings tab content area, properly sized)
local SettingsContent = CreateTab("Settings", "⚙").Content or ContentFrame
local CreditFrame = Instance.new("Frame")
CreditFrame.Size = UDim2.new(1, -2, 0, 120)
CreditFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
CreditFrame.Parent = SettingsContent
Instance.new("UICorner", CreditFrame).CornerRadius = UDim.new(0, 6)

local CreditText = Instance.new("TextLabel")
CreditText.Size = UDim2.new(1, -16, 1, -16)
CreditText.Position = UDim2.new(0, 8, 0, 8)
CreditText.BackgroundTransparency = 1
CreditText.TextColor3 = Color3.fromRGB(200, 230, 255)
CreditText.Text = [[
Blade Ball Ultimate

Created by: plalettescripts

Features:
- Auto Parry (Instant)
- Auto Aim + Prediction
- Ball & Player ESP
- Tracers & Radar
- Speed Hack & Fly
- Auto Abilities

Made by Plalette
]]
CreditText.Font = Enum.Font.SourceSans
CreditText.TextSize = 11
CreditText.TextXAlignment = Enum.TextXAlignment.Left
CreditText.TextYAlignment = Enum.TextYAlignment.Top
CreditText.TextWrapped = true
CreditText.Parent = CreditFrame

-- ==================== AUTO PARRY (INSTANT) ====================
task.spawn(function()
    while task.wait() do
        if Config.AutoParry then
            pcall(function()
                FindRemotes()
                local ball = FindBall()
                
                if ball and ParryRemote and LocalPlayer.Character then
                    local dist = BallDistanceToPlayer(ball, LocalPlayer)
                    local isTargeting = IsBallTargetingPlayer(ball, LocalPlayer)
                    
                    -- INHUMAN REACTION - Instant parry, no delay
                    if dist <= Config.ParryRadius and isTargeting then
                        ParryRemote:FireServer()
                    end
                end
            end)
        end
        task.wait(0.005) -- Ultra-fast polling for instant reaction
    end
end)

-- ==================== AUTO AIM ====================
task.spawn(function()
    while task.wait(0.03) do
        if Config.AutoAim then
            pcall(function()
                local ball = FindBall()
                if ball and LocalPlayer.Character then
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
                end
            end)
        end
    end
end)

-- ==================== ESP ====================
task.spawn(function()
    while task.wait(0.04) do
        ClearDrawings()
        
        if Config.BallESP then
            local ball = FindBall()
            if ball then
                local pos, onScreen = Camera:WorldToViewportPoint(ball.Position)
                if onScreen then
                    local name = AddDrawing(Drawing.new("Text"))
                    name.Text = "Ball"
                    name.Color = Color3.fromRGB(255, 200, 50)
                    name.Size = 14
                    name.Position = Vector2.new(pos.X, pos.Y - 20)
                    name.Center = true
                    name.Visible = true
                    
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
                    
                    if Config.ShowTrajectory then
                        local vel = ball.Velocity or ball.AssemblyLinearVelocity or Vector3.zero
                        if vel.Magnitude > 1 then
                            local steps = 15
                            local prevPoint = Vector2.new(pos.X, pos.Y)
                            local gravity = Vector3.new(0, -Workspace.Gravity, 0)
                            
                            for i = 1, steps do
                                local t = i * 0.05
                                local futurePos = ball.Position + vel * t + 0.5 * gravity * t * t
                                local futureScreen, futureOn = Camera:WorldToViewportPoint(futurePos)
                                if futureOn then
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
        end
        
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
                            box.Color = Color3.fromRGB(0, 200, 255)
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
        
        if Config.ShowParryCircle and LocalPlayer.Character then
            local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local circlePos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                if onScreen then
                    local ball = FindBall()
                    local dist = ball and BallDistanceToPlayer(ball, LocalPlayer) or 999
                    local isTargeting = ball and IsBallTargetingPlayer(ball, LocalPlayer) or false
                    
                    local color = Color3.fromRGB(50, 255, 50)
                    if isTargeting and dist < Config.ParryRadius * 2 then color = Color3.fromRGB(255, 255, 50) end
                    if isTargeting and dist < Config.ParryRadius then color = Color3.fromRGB(255, 50, 50) end
                    
                    local circle = AddDrawing(Drawing.new("Circle"))
                    circle.Color = color
                    circle.Thickness = 1.5
                    circle.Radius = Config.ParryRadius * 3
                    circle.Position = Vector2.new(circlePos.X, circlePos.Y)
                    circle.Filled = false
                    circle.Visible = true
                end
            end
        end
        
        if Config.Radar then
            local radarSize = 90
            local radarX = Camera.ViewportSize.X - radarSize - 15
            local radarY = Camera.ViewportSize.Y - radarSize - 15
            
            local radarBg = AddDrawing(Drawing.new("Square"))
            radarBg.Color = Color3.fromRGB(0, 0, 0)
            radarBg.Size = Vector2.new(radarSize, radarSize)
            radarBg.Position = Vector2.new(radarX, radarY)
            radarBg.Filled = true
            radarBg.Visible = true
            
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

-- ==================== AUTO ABILITIES ====================
task.spawn(function()
    while task.wait(0.5) do
        if Config.AutoAbilities then
            pcall(function()
                FindRemotes()
                if AbilityRemote then
                    local ball = FindBall()
                    local dist = ball and BallDistanceToPlayer(ball, LocalPlayer) or 999
                    local isTargeting = ball and IsBallTargetingPlayer(ball, LocalPlayer) or false
                    
                    if Config.AbilityPriority == "Defensive" or Config.AbilityPriority == "Both" then
                        if isTargeting and dist < Config.ParryRadius * 1.5 then
                            AbilityRemote:FireServer("Dash")
                        end
                    end
                    
                    if Config.AbilityPriority == "Offensive" or Config.AbilityPriority == "Both" then
                        if dist > Config.ParryRadius * 3 then
                            AbilityRemote:FireServer("Rage")
                        end
                    end
                end
            end)
        end
    end
end)

-- ==================== MOVEMENT ====================
RunService.Stepped:Connect(function()
    if Config.SpeedHack and LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then humanoid.WalkSpeed = Config.SpeedValue end
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

print("Blade Ball Ultimate Loaded!")
print("Created by plalettescripts")
