local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Teams = game:GetService("Teams")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local OrionLib

-- Author Info
local AuthorName = "holon_calm"
local RobloxID = "najayou777"
local DetailIcon = "rbxassetid://7733960981"

-- Disconnect previous connections
if getgenv().HolonConnections then
    for _, c in pairs(getgenv().HolonConnections) do
        if c then c:Disconnect() end
    end
end
getgenv().HolonConnections = {}
pcall(function() RunService:UnbindFromRenderStep("HolonAimbot") end)

-- GUI Cleanup
local function cleanupGui(name)
    if game:GetService("CoreGui"):FindFirstChild(name) then game:GetService("CoreGui")[name]:Destroy() end
    if gethui and gethui():FindFirstChild(name) then gethui()[name]:Destroy() end
    if LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild(name) then LocalPlayer.PlayerGui[name]:Destroy() end
end
cleanupGui("HolonFOV")
cleanupGui("HolonMiniUI")

-- Common function for details
local function AddDetailContent(Tab)
    Tab:AddLabel("Author: " .. AuthorName)
    Tab:AddLabel("Roblox ID: " .. RobloxID)
    Tab:AddButton({
        Name = "Discord",
        Callback = function()
            setclipboard("https://discord.gg/EHBXqgZZYN")
            OrionLib:MakeNotification({Name = "Link", Content = "Discord invite link copied!", Time = 3})
        end
    })
    Tab:AddButton({
        Name = "JP版コピーと起動",
        Callback = function()
            setclipboard("loadstring(game:HttpGet(\"https://raw.githubusercontent.com/hololove1021/holon-mvs2/refs/heads/main/hub-jp.lua\"))()")
            task.spawn(function()
                loadstring(game:HttpGet("https://raw.githubusercontent.com/hololove1021/holon-mvs2/refs/heads/main/hub-jp.lua"))()
            end)
        end
    })
end

local aimCfg = { 
    Enabled = false, 
    FOV = 190, 
    ShowFOV = true, 
    ThroughWalls = false,
    TargetPart = "HumanoidRootPart",
    TargetTeam = "Enemy Team",
    ExcludeFriends = false,
    Whitelist = {},
    Blacklist = {}
}

local currentLockedTarget = nil

local bodyPartMap = {
    ["Head"] = "Head",
    ["Torso"] = "HumanoidRootPart",
    ["Upper Torso"] = "UpperTorso",
    ["Lower Torso"] = "LowerTorso"
}
local bodyPartMapReverse = {
    ["Head"] = "Head",
    ["HumanoidRootPart"] = "Torso",
    ["UpperTorso"] = "Upper Torso",
    ["LowerTorso"] = "Lower Torso"
}

-- Cache Table
local FriendCache = {}

-- Cache Update Loop
task.spawn(function()
    while true do
        if aimCfg.ExcludeFriends then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then
                    if aimCfg.ExcludeFriends then pcall(function() FriendCache[p.Name] = LocalPlayer:IsFriendsWith(p.UserId) end) end
                end
                task.wait()
            end
        end
        task.wait(5)
    end
end)

-- UI Elements Table
local UIElements = {}

-- Auto Aim FOV Circle
local fovCircleGui = Instance.new("ScreenGui")
fovCircleGui.Name = "HolonFOV"
fovCircleGui.IgnoreGuiInset = true
local parent = (gethui and gethui()) or game:GetService("CoreGui") or LocalPlayer:WaitForChild("PlayerGui")
fovCircleGui.Parent = parent
fovCircleGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local fovCircleFrame = Instance.new("Frame")
fovCircleFrame.Name = "Circle"
fovCircleFrame.AnchorPoint = Vector2.new(0.5, 0.5)
fovCircleFrame.BackgroundColor3 = Color3.new(1, 1, 1)
fovCircleFrame.BackgroundTransparency = 1
fovCircleFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
fovCircleFrame.Size = UDim2.new(0, 300, 0, 300)
fovCircleFrame.Parent = fovCircleGui

local fovCorner = Instance.new("UICorner")
fovCorner.CornerRadius = UDim.new(1, 0)
fovCorner.Parent = fovCircleFrame

local fovStroke = Instance.new("UIStroke")
fovStroke.Color = Color3.new(1, 1, 1)
fovStroke.Thickness = 1
fovStroke.Parent = fovCircleFrame

-- Mini UI
local miniUiGui = Instance.new("ScreenGui")
miniUiGui.Name = "HolonMiniUI"
miniUiGui.Parent = parent
miniUiGui.Enabled = false
miniUiGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local miniFrame = Instance.new("Frame")
miniFrame.Size = UDim2.new(0, 120, 0, 190)
miniFrame.Position = UDim2.new(1, -10, 0.4, 0)
miniFrame.AnchorPoint = Vector2.new(1, 0.5)
miniFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
miniFrame.BorderSizePixel = 0
miniFrame.Parent = miniUiGui

local miniCorner = Instance.new("UICorner")
miniCorner.CornerRadius = UDim.new(0, 8)
miniCorner.Parent = miniFrame

local miniStroke = Instance.new("UIStroke")
miniStroke.Color = Color3.fromRGB(100, 100, 100)
miniStroke.Thickness = 1
miniStroke.Parent = miniFrame

local miniLayout = Instance.new("UIListLayout")
miniLayout.Parent = miniFrame
miniLayout.SortOrder = Enum.SortOrder.LayoutOrder
miniLayout.Padding = UDim.new(0, 5)
miniLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local miniPadding = Instance.new("UIPadding")
miniPadding.Parent = miniFrame
miniPadding.PaddingTop = UDim.new(0, 5)
miniPadding.PaddingBottom = UDim.new(0, 5)
miniPadding.PaddingLeft = UDim.new(0, 5)
miniPadding.PaddingRight = UDim.new(0, 5)

-- 1. Aim Toggle Button
local miniAimBtn = Instance.new("TextButton")
miniAimBtn.Size = UDim2.new(0, 110, 0, 25)
miniAimBtn.BackgroundColor3 = Color3.fromRGB(170, 0, 0)
miniAimBtn.Text = "Aim: OFF"
miniAimBtn.TextColor3 = Color3.new(1,1,1)
miniAimBtn.Font = Enum.Font.SourceSansBold
miniAimBtn.TextSize = 12
miniAimBtn.Parent = miniFrame
Instance.new("UICorner", miniAimBtn).CornerRadius = UDim.new(0, 6)

-- 2. Team Cycle Button
local miniTeamBtn = Instance.new("TextButton")
miniTeamBtn.Size = UDim2.new(0, 110, 0, 25)
miniTeamBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
miniTeamBtn.Text = "Team: Enemy Team"
miniTeamBtn.TextColor3 = Color3.new(1,1,1)
miniTeamBtn.Font = Enum.Font.SourceSans
miniTeamBtn.TextSize = 12
miniTeamBtn.Parent = miniFrame
Instance.new("UICorner", miniTeamBtn).CornerRadius = UDim.new(0, 6)

-- 3. Part Cycle Button
local miniPartBtn = Instance.new("TextButton")
miniPartBtn.Size = UDim2.new(0, 110, 0, 25)
miniPartBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
miniPartBtn.Text = "Part: Torso"
miniPartBtn.TextColor3 = Color3.new(1,1,1)
miniPartBtn.Font = Enum.Font.SourceSans
miniPartBtn.TextSize = 12
miniPartBtn.Parent = miniFrame
Instance.new("UICorner", miniPartBtn).CornerRadius = UDim.new(0, 6)

-- 4. FOV Slider Frame
local miniSliderFrame = Instance.new("Frame")
miniSliderFrame.Size = UDim2.new(0, 110, 0, 25)
miniSliderFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
miniSliderFrame.Parent = miniFrame
Instance.new("UICorner", miniSliderFrame).CornerRadius = UDim.new(0, 6)

local miniSliderFill = Instance.new("Frame")
miniSliderFill.Size = UDim2.new(aimCfg.FOV/800, 0, 1, 0)
miniSliderFill.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
miniSliderFill.Parent = miniSliderFrame
Instance.new("UICorner", miniSliderFill).CornerRadius = UDim.new(0, 6)

local miniSliderText = Instance.new("TextLabel")
miniSliderText.Size = UDim2.new(1, 0, 1, 0)
miniSliderText.BackgroundTransparency = 1
miniSliderText.Text = "FOV: " .. math.floor(aimCfg.FOV)
miniSliderText.TextColor3 = Color3.new(1,1,1)
miniSliderText.Font = Enum.Font.SourceSansBold
miniSliderText.TextSize = 12
miniSliderText.Parent = miniSliderFrame

-- 5. Unlock Target Button
local miniUnlockBtn = Instance.new("TextButton")
miniUnlockBtn.Size = UDim2.new(0, 110, 0, 25)
miniUnlockBtn.BackgroundColor3 = Color3.fromRGB(200, 100, 0)
miniUnlockBtn.Text = "Unlock"
miniUnlockBtn.TextColor3 = Color3.new(1,1,1)
miniUnlockBtn.Font = Enum.Font.SourceSansBold
miniUnlockBtn.TextSize = 12
miniUnlockBtn.Parent = miniFrame
Instance.new("UICorner", miniUnlockBtn).CornerRadius = UDim.new(0, 6)

-- Mini UI Logic
local function updateMiniUI()
    miniAimBtn.Text = "Aim: " .. (aimCfg.Enabled and "ON" or "OFF")
    miniAimBtn.BackgroundColor3 = aimCfg.Enabled and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(170, 0, 0)
    miniTeamBtn.Text = "Team: " .. aimCfg.TargetTeam
    miniPartBtn.Text = "Part: " .. (bodyPartMapReverse[aimCfg.TargetPart] or aimCfg.TargetPart)
    miniSliderText.Text = "FOV: " .. math.floor(aimCfg.FOV)
    miniSliderFill.Size = UDim2.new(aimCfg.FOV/800, 0, 1, 0)
end

miniAimBtn.MouseButton1Click:Connect(function()
    aimCfg.Enabled = not aimCfg.Enabled
    if UIElements.AimEnabled then UIElements.AimEnabled:Set(aimCfg.Enabled) end
    updateMiniUI()
end)

miniTeamBtn.MouseButton1Click:Connect(function()
    local teams = {"Enemy Team", "All Teams", "Specific Players"}
    for _, t in ipairs(Teams:GetTeams()) do table.insert(teams, t.Name) end
    local idx = table.find(teams, aimCfg.TargetTeam) or 0
    aimCfg.TargetTeam = teams[(idx % #teams) + 1] or "Enemy Team"
    if UIElements.AimTargetTeam then UIElements.AimTargetTeam:Set(aimCfg.TargetTeam) end
    updateMiniUI()
end)

miniPartBtn.MouseButton1Click:Connect(function()
    local parts = {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso"}
    local idx = table.find(parts, aimCfg.TargetPart) or 0
    aimCfg.TargetPart = parts[(idx % #parts) + 1] or "HumanoidRootPart"
    if UIElements.AimTargetPart then UIElements.AimTargetPart:Set(bodyPartMapReverse[aimCfg.TargetPart]) end
    updateMiniUI()
end)

miniUnlockBtn.MouseButton1Click:Connect(function()
    currentLockedTarget = nil
end)

local miniUiPos = "Right"
local function updateMiniUiLayout()
    if miniUiPos == "Right" then
        miniFrame.AnchorPoint = Vector2.new(1, 0.5)
        miniFrame.Position = UDim2.new(1, -10, 0.4, 0)
        miniLayout.FillDirection = Enum.FillDirection.Vertical
        miniFrame.Size = UDim2.new(0, 120, 0, 190)
        
        miniAimBtn.Size = UDim2.new(0, 110, 0, 25)
        miniTeamBtn.Size = UDim2.new(0, 110, 0, 25)
        miniPartBtn.Size = UDim2.new(0, 110, 0, 25)
        miniSliderFrame.Size = UDim2.new(0, 110, 0, 25)
        miniUnlockBtn.Size = UDim2.new(0, 110, 0, 25)
    else -- Top
        miniFrame.AnchorPoint = Vector2.new(0.5, 0)
        miniFrame.Position = UDim2.new(0.5, 0, 0, 10)
        miniLayout.FillDirection = Enum.FillDirection.Horizontal
        miniFrame.Size = UDim2.new(0, 600, 0, 40)
        
        miniAimBtn.Size = UDim2.new(0, 110, 0, 25)
        miniTeamBtn.Size = UDim2.new(0, 110, 0, 25)
        miniPartBtn.Size = UDim2.new(0, 110, 0, 25)
        miniSliderFrame.Size = UDim2.new(0, 110, 0, 25)
        miniUnlockBtn.Size = UDim2.new(0, 110, 0, 25)
    end
end

local draggingSlider = false
miniSliderFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingSlider = true
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingSlider = false
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local mousePos = UserInputService:GetMouseLocation()
        local relX = math.clamp(mousePos.X - miniSliderFrame.AbsolutePosition.X, 0, miniSliderFrame.AbsoluteSize.X)
        local ratio = relX / miniSliderFrame.AbsoluteSize.X
        local newFov = math.floor(ratio * 790 + 10)
        aimCfg.FOV = newFov
        if UIElements.AimFOV then UIElements.AimFOV:Set(newFov) end
        updateMiniUI()
    end
end)

-- Auto Aim Loop
RunService:BindToRenderStep("HolonAimbot", Enum.RenderPriority.Camera.Value + 1, function()
    -- FOV Circle Update
    fovCircleFrame.Size = UDim2.new(0, aimCfg.FOV * 2, 0, aimCfg.FOV * 2)
    fovCircleGui.Enabled = aimCfg.Enabled and aimCfg.ShowFOV
    
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    -- Manual Target Unlock
    local mouseDelta = UserInputService:GetMouseDelta()
    if mouseDelta.Magnitude > 3 then
        currentLockedTarget = nil
    end

    if aimCfg.Enabled then
        local target = nil
        
        -- Check Locked Target
        if currentLockedTarget and currentLockedTarget.Parent and currentLockedTarget.Parent:FindFirstChild("Humanoid") and currentLockedTarget.Parent.Humanoid.Health > 0 then
             local p = Players:GetPlayerFromCharacter(currentLockedTarget.Parent)
             if p then
                 -- Team Check
                 local isTargetTeam = false
                 if aimCfg.TargetTeam == "All Teams" then
                     isTargetTeam = true
                 elseif aimCfg.TargetTeam == "Enemy Team" then
                     isTargetTeam = true
                     if p.Team and LocalPlayer.Team and p.Team == LocalPlayer.Team then
                         isTargetTeam = false
                     end
                 elseif p.Team and p.Team.Name == aimCfg.TargetTeam then
                     isTargetTeam = true
                 end
                 
                 if isTargetTeam then
                     -- FOV and Wall Check
                     local screenPos, onScreen = Camera:WorldToViewportPoint(currentLockedTarget.Position)
                     local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                     
                     if onScreen and dist <= aimCfg.FOV then
                         local visible = true
                         if not aimCfg.ThroughWalls then
                             local params = RaycastParams.new()
                             params.FilterDescendantsInstances = {LocalPlayer.Character, workspace.CurrentCamera}
                             params.FilterType = Enum.RaycastFilterType.Exclude
                             local dir = (currentLockedTarget.Position - Camera.CFrame.Position)
                             local result = workspace:Raycast(Camera.CFrame.Position, dir.Unit * dir.Magnitude, params)
                             if result and not result.Instance:IsDescendantOf(currentLockedTarget.Parent) then 
                                 visible = false 
                             end
                         end
                         
                         if visible then
                             target = currentLockedTarget
                         else
                             currentLockedTarget = nil
                         end
                     else
                         currentLockedTarget = nil
                     end
                 else
                     currentLockedTarget = nil
                 end
             else
                 currentLockedTarget = nil
             end
        else
            currentLockedTarget = nil
        end

        -- Find New Target
        if not target then
            local closest = nil
            local minDist = aimCfg.FOV
            
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then
                    -- Filter Check
                    local isExcluded = false
                    if aimCfg.ExcludeFriends and FriendCache[p.Name] then isExcluded = true end
                    if not isExcluded and table.find(aimCfg.Whitelist, p.Name) then isExcluded = true end

                    if not isExcluded then
                        -- Team Check
                        local isTargetTeam = false
                        if table.find(aimCfg.Blacklist, p.Name) then
                            isTargetTeam = true
                        elseif aimCfg.TargetTeam == "Specific Players" then
                            isTargetTeam = false
                        elseif aimCfg.TargetTeam == "All Teams" then
                            isTargetTeam = true
                        elseif aimCfg.TargetTeam == "Enemy Team" then
                            isTargetTeam = true
                            if p.Team and LocalPlayer.Team and p.Team == LocalPlayer.Team then
                                isTargetTeam = false
                            end
                        elseif p.Team and p.Team.Name == aimCfg.TargetTeam then
                            isTargetTeam = true
                        end

                        if isTargetTeam and p.Character and p.Character:FindFirstChild(aimCfg.TargetPart) and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
                            local targetPart = p.Character[aimCfg.TargetPart]
                            local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                            
                            if onScreen then
                                local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                                if dist < minDist then
                                    -- Wall Check
                                    local isVisible = true
                                    if not aimCfg.ThroughWalls then
                                        local params = RaycastParams.new()
                                        params.FilterDescendantsInstances = {LocalPlayer.Character, workspace.CurrentCamera}
                                        params.FilterType = Enum.RaycastFilterType.Exclude
                                        local dir = (targetPart.Position - Camera.CFrame.Position)
                                        local result = workspace:Raycast(Camera.CFrame.Position, dir.Unit * dir.Magnitude, params)
                                        if result and not result.Instance:IsDescendantOf(p.Character) then 
                                            isVisible = false
                                        end
                                    end
                                    
                                    if isVisible then
                                        minDist = dist
                                        closest = targetPart
                                    end
                                end
                            end
                        end
                    end
                end
            end
            target = closest
            if target then
                currentLockedTarget = target
            end
        end
        
        if target then
            Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, target.Position)
        end
    else
        currentLockedTarget = nil
    end
end)

-- UI Construction
local OrionUrl = "https://raw.githubusercontent.com/hololove1021/HolonHUB/refs/heads/main/source.txt"

local function StartHolonHUB()
    OrionLib = loadstring(game:HttpGet(OrionUrl))()
    
    pcall(function()
        if game:GetService("CoreGui"):FindFirstChild("Orion") then 
            game:GetService("CoreGui").Orion:Destroy() 
        end
    end)

    local Window = OrionLib:MakeWindow({
        Name = "Holon HUB v1.4.2",
        HidePremium = false,
        SaveConfig = false,
        ConfigFolder = "HolonHUB",
        IntroEnabled = true,
        IntroText = "Holon HUB v1.4.2 Loaded!"
    })

    -- Player List Function
    local function getPList()
        local plist = {}
        for _, p in ipairs(Players:GetPlayers()) do
            table.insert(plist, p.DisplayName .. " (@" .. p.Name .. ")")
        end
        return plist
    end

    -- TAB: AUTO AIM
    local AimTab = Window:MakeTab({
        Name = "Auto Aim",
        Icon = "rbxassetid://7733674676"
    })

    local AimSec = AimTab:AddSection({ Name = "Aimbot Settings" })

    UIElements.AimEnabled = AimSec:AddToggle({
        Name = "Enable Auto Aim",
        Default = false,
        Callback = function(v) 
            aimCfg.Enabled = v 
            updateMiniUI()
        end
    })

    UIElements.AimShowFOV = AimSec:AddToggle({
        Name = "Show FOV Circle",
        Default = true,
        Callback = function(v) 
            aimCfg.ShowFOV = v 
            updateMiniUI()
        end
    })

    UIElements.AimFOV = AimSec:AddSlider({
        Name = "FOV Size",
        Min = 10, Max = 800, Default = 190,
        Callback = function(v) 
            aimCfg.FOV = v 
            updateMiniUI()
        end
    })

    UIElements.AimThroughWalls = AimSec:AddToggle({
        Name = "Through Walls",
        Default = false,
        Callback = function(v) aimCfg.ThroughWalls = v end
    })

    AimSec:AddToggle({
        Name = "Show Mini UI",
        Default = false,
        Callback = function(v) miniUiGui.Enabled = v end
    })

    AimSec:AddDropdown({
        Name = "Mini UI Position",
        Default = "Right",
        Options = {"Right", "Top"},
        Callback = function(v)
            miniUiPos = (v == "Right") and "Right" or "Top"
            updateMiniUiLayout()
        end
    })

    UIElements.AimTargetTeam = AimSec:AddDropdown({
        Name = "Target Team",
        Default = "Enemy Team",
        Options = (function()
            local list = {"Enemy Team", "All Teams", "Specific Players"}
            for _, t in ipairs(Teams:GetTeams()) do table.insert(list, t.Name) end
            return list
        end)(),
        Callback = function(v) 
            aimCfg.TargetTeam = v 
            updateMiniUI()
        end
    })

    AimSec:AddButton({
        Name = "Unlock Target",
        Callback = function() currentLockedTarget = nil end
    })

    UIElements.AimTargetPart = AimSec:AddDropdown({
        Name = "Target Part",
        Default = "Torso",
        Options = {"Head", "Torso", "Upper Torso", "Lower Torso"},
        Callback = function(v) 
            aimCfg.TargetPart = bodyPartMap[v] or "HumanoidRootPart"
            updateMiniUI()
        end
    })

    local FilterSec = AimTab:AddSection({ Name = "Target Filters" })

    FilterSec:AddToggle({
        Name = "Exclude Friends",
        Default = false,
        Callback = function(v) aimCfg.ExcludeFriends = v end
    })

    local ListSec = AimTab:AddSection({ Name = "Player Specific Settings" })

    local selectedPlayer = nil
    local playerDropdown = ListSec:AddDropdown({
        Name = "Select Player",
        Default = "",
        Options = (function()
            local list = {}
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then table.insert(list, p.Name) end
            end
            return list
        end)(),
        Callback = function(v) selectedPlayer = v end
    })

    ListSec:AddButton({
        Name = "Refresh List",
        Callback = function()
            local list = {}
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then table.insert(list, p.Name) end
            end
            playerDropdown:Refresh(list, true)
        end
    })

    local whitelistLabel = ListSec:AddLabel("Whitelist: ")
    local blacklistLabel = ListSec:AddLabel("Blacklist: ")

    local function updateListLabels()
        whitelistLabel:Set("Whitelist: " .. table.concat(aimCfg.Whitelist, ", "))
        blacklistLabel:Set("Blacklist: " .. table.concat(aimCfg.Blacklist, ", "))
    end

    ListSec:AddButton({
        Name = "Add to Whitelist (Exclude)",
        Callback = function()
            if selectedPlayer and not table.find(aimCfg.Whitelist, selectedPlayer) then
                table.insert(aimCfg.Whitelist, selectedPlayer)
                OrionLib:MakeNotification({Name = "Added", Content = selectedPlayer .. " added to whitelist", Time = 2})
                updateListLabels()
            end
        end
    })
    ListSec:AddButton({
        Name = "Remove from Whitelist",
        Callback = function()
            if selectedPlayer then
                local idx = table.find(aimCfg.Whitelist, selectedPlayer)
                if idx then
                    table.remove(aimCfg.Whitelist, idx)
                    OrionLib:MakeNotification({Name = "Removed", Content = selectedPlayer .. " removed from whitelist", Time = 2})
                    updateListLabels()
                end
            end
        end
    })
    ListSec:AddButton({
        Name = "Add to Blacklist (Target)",
        Callback = function()
            if selectedPlayer and not table.find(aimCfg.Blacklist, selectedPlayer) then
                table.insert(aimCfg.Blacklist, selectedPlayer)
                OrionLib:MakeNotification({Name = "Added", Content = selectedPlayer .. " added to blacklist", Time = 2})
                updateListLabels()
            end
        end
    })
    ListSec:AddButton({
        Name = "Remove from Blacklist",
        Callback = function()
            if selectedPlayer then
                local idx = table.find(aimCfg.Blacklist, selectedPlayer)
                if idx then
                    table.remove(aimCfg.Blacklist, idx)
                    OrionLib:MakeNotification({Name = "Removed", Content = selectedPlayer .. " removed from blacklist", Time = 2})
                    updateListLabels()
                end
            end
        end
    })
    ListSec:AddButton({
        Name = "Clear Lists",
        Callback = function()
            aimCfg.Whitelist = {}
            aimCfg.Blacklist = {}
            OrionLib:MakeNotification({Name="Cleared",Content="Lists reset",Time=2})
            updateListLabels()
        end
    })
    updateListLabels()

    local DetailTab = Window:MakeTab({Name = "Details", Icon = DetailIcon})
    AddDetailContent(DetailTab)

    OrionLib:MakeNotification({
        Name = "Holon HUB",
        Content = "v1.4.2 Loaded!",
        Time = 5
    })

    OrionLib:Init()
end
StartHolonHUB()
