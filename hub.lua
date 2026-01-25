local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Teams = game:GetService("Teams")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local OrionLib

-- 作者情報の定義
local AuthorName = "holon_calm"
local RobloxID = "najayou777"
local DetailIcon = "rbxassetid://7733964719"

-- 重複実行時の接続解除処理
if getgenv().HolonConnections then
    for _, c in pairs(getgenv().HolonConnections) do
        if c then c:Disconnect() end
    end
end
getgenv().HolonConnections = {}
pcall(function() RunService:UnbindFromRenderStep("HolonAimbot") end)
-- GUIクリーンアップ
local function cleanupGui(name)
    if game:GetService("CoreGui"):FindFirstChild(name) then game:GetService("CoreGui")[name]:Destroy() end
    if gethui and gethui():FindFirstChild(name) then gethui()[name]:Destroy() end
    if LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild(name) then LocalPlayer.PlayerGui[name]:Destroy() end
end
cleanupGui("HolonFOV")
cleanupGui("HolonMiniUI")

-- リンク集を表示する共通関数（認証画面とメイン画面で使い回せます）
local function AddDetailContent(Tab)
    Tab:AddButton({
        Name = "TikTok",
        Callback = function()
            setclipboard("https://www.tiktok.com/@holon_calm")
            OrionLib:MakeNotification({Name = "リンク", Content = "TikTokのリンクをコピーしました", Time = 3})
        end
    })
    
    Tab:AddButton({
        Name = "Discord",
        Callback = function()
            setclipboard("https://discord.gg/EHBXqgZZYN")
            OrionLib:MakeNotification({Name = "リンク", Content = "Discordの招待リンクをコピーしました", Time = 3})
        end
    })
    
    Tab:AddButton({
        Name = "YouTube",
        Callback = function()
            setclipboard("https://www.youtube.com/@Holoncalm")
            OrionLib:MakeNotification({Name = "リンク", Content = "YouTubeのリンクをコピーしました", Time = 3})
        end
    })
    Tab:AddLabel("作者: " .. AuthorName)
    Tab:AddLabel("Roblox ID: " .. RobloxID)
end

local aimCfg = { 
    Enabled = false, 
    FOV = 150, 
    ShowFOV = true, 
    ThroughWalls = false,
    TargetPart = "HumanoidRootPart",
    TargetTeam = "敵チーム"
}

local currentLockedTarget = nil

local bodyPartMap = {
    ["頭"] = "Head",
    ["胴体"] = "HumanoidRootPart",
    ["上半身"] = "UpperTorso",
    ["下半身"] = "LowerTorso"
}
local bodyPartMapReverse = {
    ["Head"] = "頭",
    ["HumanoidRootPart"] = "胴体",
    ["UpperTorso"] = "上半身",
    ["LowerTorso"] = "下半身"
}

-- UI要素を管理するテーブル (グローバルスコープに移動して連携可能にする)
local UIElements = {}

-- Auto Aim FOV Circle
local fovCircleGui = Instance.new("ScreenGui")
fovCircleGui.Name = "HolonFOV"
-- gethuiがあればそれを使用、なければCoreGui、それもなければPlayerGui
fovCircleGui.IgnoreGuiInset = true -- ズレ修正
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

-- ミニUIの作成
local miniUiGui = Instance.new("ScreenGui")
miniUiGui.Name = "HolonMiniUI"
miniUiGui.Parent = parent
miniUiGui.Enabled = false
miniUiGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local miniFrame = Instance.new("Frame")
miniFrame.Size = UDim2.new(0, 160, 0, 180) -- 初期サイズ調整
miniFrame.Position = UDim2.new(0.85, 0, 0.3, 0)
miniFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
miniFrame.BorderSizePixel = 0
miniFrame.Active = true -- カスタムドラッグのためDraggableは削除
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
miniAimBtn.Size = UDim2.new(0, 140, 0, 30)
miniAimBtn.BackgroundColor3 = Color3.fromRGB(170, 0, 0)
miniAimBtn.Text = "Aim: OFF"
miniAimBtn.TextColor3 = Color3.new(1,1,1)
miniAimBtn.Font = Enum.Font.SourceSansBold
miniAimBtn.TextSize = 14
miniAimBtn.Parent = miniFrame
Instance.new("UICorner", miniAimBtn).CornerRadius = UDim.new(0, 6)

-- 2. Team Cycle Button
local miniTeamBtn = Instance.new("TextButton")
miniTeamBtn.Size = UDim2.new(0, 140, 0, 30)
miniTeamBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
miniTeamBtn.Text = "Team: 敵チーム"
miniTeamBtn.TextColor3 = Color3.new(1,1,1)
miniTeamBtn.Font = Enum.Font.SourceSans
miniTeamBtn.TextSize = 14
miniTeamBtn.Parent = miniFrame
Instance.new("UICorner", miniTeamBtn).CornerRadius = UDim.new(0, 6)

-- 3. FOV Slider Frame
local miniSliderFrame = Instance.new("Frame")
miniSliderFrame.Size = UDim2.new(0, 140, 0, 30)
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
miniSliderText.Text = "FOV: " .. aimCfg.FOV
miniSliderText.TextColor3 = Color3.new(1,1,1)
miniSliderText.Font = Enum.Font.SourceSansBold
miniSliderText.TextSize = 14
miniSliderText.Parent = miniSliderFrame

-- 4. Unlock Target Button
local miniUnlockBtn = Instance.new("TextButton")
miniUnlockBtn.Size = UDim2.new(0, 140, 0, 30)
miniUnlockBtn.BackgroundColor3 = Color3.fromRGB(200, 100, 0)
miniUnlockBtn.Text = "Unlock Target"
miniUnlockBtn.TextColor3 = Color3.new(1,1,1)
miniUnlockBtn.Font = Enum.Font.SourceSansBold
miniUnlockBtn.TextSize = 14
miniUnlockBtn.Parent = miniFrame
Instance.new("UICorner", miniUnlockBtn).CornerRadius = UDim.new(0, 6)

-- ミニUIのロジック
local function updateMiniUI()
    miniAimBtn.Text = "Aim: " .. (aimCfg.Enabled and "ON" or "OFF")
    miniAimBtn.BackgroundColor3 = aimCfg.Enabled and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(170, 0, 0)
    miniTeamBtn.Text = "Team: " .. aimCfg.TargetTeam
    miniSliderText.Text = "FOV: " .. math.floor(aimCfg.FOV)
    miniSliderFill.Size = UDim2.new(aimCfg.FOV/800, 0, 1, 0)
end

miniAimBtn.MouseButton1Click:Connect(function()
    aimCfg.Enabled = not aimCfg.Enabled
    if UIElements.AimEnabled then UIElements.AimEnabled:Set(aimCfg.Enabled) end
    updateMiniUI()
end)

miniTeamBtn.MouseButton1Click:Connect(function()
    local teams = {"敵チーム", "全てのチーム"}
    for _, t in ipairs(Teams:GetTeams()) do table.insert(teams, t.Name) end
    local idx = table.find(teams, aimCfg.TargetTeam) or 0
    aimCfg.TargetTeam = teams[(idx % #teams) + 1] or "敵チーム"
    if UIElements.AimTargetTeam then UIElements.AimTargetTeam:Set(aimCfg.TargetTeam) end
    updateMiniUI()
end)

miniUnlockBtn.MouseButton1Click:Connect(function()
    currentLockedTarget = nil
end)

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

-- ミニUIのドラッグ＆スナップ処理
local draggingMini = false
local dragStart, startPos

miniFrame.InputBegan:Connect(function(input)
    if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and not draggingSlider then
        draggingMini = true
        dragStart = input.Position
        startPos = miniFrame.Position
    end
end)

miniFrame.InputChanged:Connect(function(input)
    if draggingMini and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        miniFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and draggingMini then
        draggingMini = false
        
        -- スナップ処理
        local vp = Camera.ViewportSize
        local pos = miniFrame.AbsolutePosition
        local size = miniFrame.AbsoluteSize
        
        local distLeft = pos.X
        local distRight = vp.X - (pos.X + size.X)
        local distTop = pos.Y
        local distBottom = vp.Y - (pos.Y + size.Y)
        
        local minDist = math.min(distLeft, distRight, distTop, distBottom)
        local targetPos = UDim2.new(0, pos.X, 0, pos.Y)
        local isVertical = true
        
        if minDist == distLeft then
            targetPos = UDim2.new(0, 10, 0, pos.Y)
            isVertical = true
        elseif minDist == distRight then
            targetPos = UDim2.new(1, -size.X - 10, 0, pos.Y)
            isVertical = true
        elseif minDist == distTop then
            targetPos = UDim2.new(0, pos.X, 0, 10)
            isVertical = false
        elseif minDist == distBottom then
            targetPos = UDim2.new(0, pos.X, 1, -size.Y - 10)
            isVertical = false
        end
        
        -- レイアウト変更 (端に合わせて長さを変える)
        if isVertical then
            miniLayout.FillDirection = Enum.FillDirection.Vertical
            miniFrame.Size = UDim2.new(0, 160, 0, 180) -- 縦長
            -- ボタンサイズのリセット
            miniAimBtn.Size = UDim2.new(0, 140, 0, 30)
            miniTeamBtn.Size = UDim2.new(0, 140, 0, 30)
            miniSliderFrame.Size = UDim2.new(0, 140, 0, 30)
            miniUnlockBtn.Size = UDim2.new(0, 140, 0, 30)
        else
            miniLayout.FillDirection = Enum.FillDirection.Horizontal
            miniFrame.Size = UDim2.new(0, 600, 0, 50) -- 横長
            -- ボタンサイズのリセット
            miniAimBtn.Size = UDim2.new(0, 140, 0, 30)
            miniTeamBtn.Size = UDim2.new(0, 140, 0, 30)
            miniSliderFrame.Size = UDim2.new(0, 140, 0, 30)
            miniUnlockBtn.Size = UDim2.new(0, 140, 0, 30)
        end
        
        TweenService:Create(miniFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = targetPos}):Play()
    end
end)

-- オートエイムループ
RunService:BindToRenderStep("HolonAimbot", Enum.RenderPriority.Camera.Value + 1, function()
    -- FOV円の更新
    fovCircleFrame.Size = UDim2.new(0, aimCfg.FOV * 2, 0, aimCfg.FOV * 2)
    fovCircleGui.Enabled = aimCfg.Enabled and aimCfg.ShowFOV
    
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    -- 手動操作によるターゲット解除 (マウスの動きを検知)
    local mouseDelta = UserInputService:GetMouseDelta()
    if mouseDelta.Magnitude > 3 then -- 閾値
        currentLockedTarget = nil
    end

    if aimCfg.Enabled then
        local target = nil
        
        -- ロック中のターゲットが有効かチェック
        if currentLockedTarget and currentLockedTarget.Parent and currentLockedTarget.Parent:FindFirstChild("Humanoid") and currentLockedTarget.Parent.Humanoid.Health > 0 then
             local p = Players:GetPlayerFromCharacter(currentLockedTarget.Parent)
             if p then
                 -- チーム判定
                 local isTargetTeam = false
                 if aimCfg.TargetTeam == "全てのチーム" then
                     isTargetTeam = true
                 elseif aimCfg.TargetTeam == "敵チーム" then
                     isTargetTeam = true
                     if p.Team and LocalPlayer.Team and p.Team == LocalPlayer.Team then
                         isTargetTeam = false
                     end
                 elseif p.Team and p.Team.Name == aimCfg.TargetTeam then
                     isTargetTeam = true
                 end
                 
                 if isTargetTeam then
                     -- FOVと壁抜きチェック
                     local screenPos, onScreen = Camera:WorldToViewportPoint(currentLockedTarget.Position)
                     local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                     
                     if onScreen and dist <= aimCfg.FOV then
                         local visible = true
                         if not aimCfg.ThroughWalls then
                             local params = RaycastParams.new()
                             params.FilterDescendantsInstances = {LocalPlayer.Character, workspace.CurrentCamera} -- ターゲット自体は除外しない（ヒットしたら見えている証拠）
                             params.FilterType = Enum.RaycastFilterType.Exclude
                             local dir = (currentLockedTarget.Position - Camera.CFrame.Position)
                             local result = workspace:Raycast(Camera.CFrame.Position, dir.Unit * dir.Magnitude, params)
                             -- ヒットしたものがターゲットのキャラクターの一部でなければ「壁」とみなす
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

        -- 新しいターゲットを探す
        if not target then
            local closest = nil
            local minDist = aimCfg.FOV
            
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then
                    -- チーム判定
                    local isTargetTeam = false
                    if aimCfg.TargetTeam == "全てのチーム" then
                        isTargetTeam = true
                    elseif aimCfg.TargetTeam == "敵チーム" then
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
                                -- 壁抜きチェック
                                if not aimCfg.ThroughWalls then
                                    local params = RaycastParams.new()
                                    params.FilterDescendantsInstances = {LocalPlayer.Character, workspace.CurrentCamera}
                                    params.FilterType = Enum.RaycastFilterType.Exclude
                                    local dir = (targetPart.Position - Camera.CFrame.Position)
                                    local result = workspace:Raycast(Camera.CFrame.Position, dir.Unit * dir.Magnitude, params)
                                    if result and not result.Instance:IsDescendantOf(p.Character) then 
                                        continue 
                                    end
                                end
                                
                                minDist = dist
                                closest = targetPart
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
            -- CFrame.lookAtを使用してカメラの回転を安定させる
            Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, target.Position)
        end
    else
        currentLockedTarget = nil
    end
end)

RunService.Heartbeat:Connect(updateSubFeatures)

-- プレイヤー機能ループ
UserInputService.JumpRequest:Connect(function()
    if infiniteJump and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

RunService.Stepped:Connect(function(time, deltaTime)
    if not LocalPlayer.Character then return end
    local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
    local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

    if hum then
        if useWalkSpeed and root and hum.MoveDirection.Magnitude > 0 then
            -- CFrameによる移動 (Cosmic Hub参考)
            local extraSpeed = math.max(0, walkSpeed - 16)
            root.CFrame = root.CFrame + (hum.MoveDirection * (extraSpeed * deltaTime))
        end
        if useJumpPower then 
            hum.UseJumpPower = true
            hum.JumpPower = jumpPower
            -- UseJumpPowerが強制的にfalseにされる場合への対策 (JumpHeightを使用)
            if not hum.UseJumpPower then
                hum.JumpHeight = jumpPower * 0.2 -- 概算
            end
        end
    end
    
    if antiFire then
        for _, v in ipairs(LocalPlayer.Character:GetDescendants()) do
            if v:IsA("Fire") then v:Destroy() end
        end
    end
    
    if antiGrab then
        local char = LocalPlayer.Character
        if char then
            -- Cosmic style Anti-Grab Loop
            local head = char:FindFirstChild("Head")
            local isHeldVal = LocalPlayer:FindFirstChild("IsHeld")
            local isHeld = (head and head:FindFirstChild("PartOwner")) or (isHeldVal and isHeldVal.Value)
            local struggleEvt = ReplicatedStorage:FindFirstChild("CharacterEvents") and ReplicatedStorage.CharacterEvents:FindFirstChild("Struggle")

            if isHeld then
                -- 掴まれている間、固定して抵抗し続ける
                for _, p in ipairs(char:GetChildren()) do
                    if p:IsA("BasePart") then p.Anchored = true end
                end
                
                if struggleEvt then
                    struggleEvt:FireServer(LocalPlayer) -- 引数追加
                end
            else
                -- 掴まれていない、かつアンチ爆発(ラグドール)中でなければ固定解除
                local isRagdolled = antiExplosion and char:FindFirstChild("Humanoid") and char.Humanoid:FindFirstChild("Ragdolled") and char.Humanoid.Ragdolled.Value
                if not isRagdolled then
                    for _, p in ipairs(char:GetChildren()) do
                        if p:IsA("BasePart") then p.Anchored = false end
                    end
                end
            end
        end
    end

    -- Noclip
    if noclip and LocalPlayer.Character then
        for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end)

Workspace.DescendantAdded:Connect(function(v)
    if antiExplosion and v:IsA("Explosion") then
        v.BlastPressure = 0
        v.BlastRadius = 0
        v.Visible = false
        task.wait()
        v:Destroy()
    end
end)

-- Anti-Explosion (Ragdoll Anchor) & Anti-Fire (Extinguish) Loop 修正版
local extOriginalCFrame = nil
local extPart = nil

task.spawn(function()
    while true do
        task.wait(0.1)
        local char = LocalPlayer.Character
        if char then
            -- Anti-Explosion: Ragdoll Anchor (修正: 解除処理を追加)
            if antiExplosion then
                local hum = char:FindFirstChild("Humanoid")
                if hum then
                    local rag = hum:FindFirstChild("Ragdolled")
                    if rag and rag.Value then
                        -- ラグドール中は固定
                        for _, p in ipairs(char:GetChildren()) do
                            if p:IsA("BasePart") then p.Anchored = true end
                        end
                    else
                        -- ラグドール解除後は固定解除 (動けるようにする)
                        for _, p in ipairs(char:GetChildren()) do
                            if p:IsA("BasePart") then p.Anchored = false end
                        end
                    end
                end
            end

            -- Anti-Fire: Extinguish Part (修正: 紫の物体を元の位置に戻す)
            if antiFire then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                local hasFire = hrp and (hrp:FindFirstChild("FireLight") or hrp:FindFirstChild("FireParticleEmitter"))
                
                -- パーツを一度だけ取得・保存
                if not extPart then
                    local map = Workspace:FindFirstChild("Map")
                    local hole = map and map:FindFirstChild("Hole")
                    local poison = hole and hole:FindFirstChild("PoisonBigHole")
                    extPart = poison and poison:FindFirstChild("ExtinguishPart")
                    if extPart then extOriginalCFrame = extPart.CFrame end
                end
                
                if extPart then
                    if hasFire then
                        -- 炎があるなら消火パーツを自分に持ってくる
                        extPart.CFrame = hrp.CFrame
                    elseif extOriginalCFrame then
                        -- 炎が消えたら元の位置に戻す (紫の物体を隠す)
                        extPart.CFrame = extOriginalCFrame
                    end
                end
            end
        end
    end
end)


--------------------------------------------------------------------------------
-- [設定]保存、見た目 
--------------------------------------------------------------------------------
-- --- 設定読み込み用関数 ---
-- 設定ファイルのリストをリアルタイムに取得する関数
local function getConfigFileList()
    local files = {}
    if not isfolder("holon_config") then makefolder("holon_config") end
    
    for _, file in ipairs(listfiles("holon_config")) do
        if file:sub(-5) == ".json" then
            -- パスを除去してファイル名だけにする
            local name = file:gsub("holon_config\\", ""):gsub("holon_config/", "")
            table.insert(files, name)
        end
    end
    if #files == 0 then table.insert(files, "ファイルなし") end
    return files
end

-- チームリスト取得関数
local function getTeamList()
    local list = {"全てのチーム"}
    for _, t in ipairs(Teams:GetTeams()) do
        table.insert(list, t.Name)
    end
    return list
end

local function updateSubFeatures()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local char = p.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChild("Humanoid")
            
            -- チーム判定
            local isTeamMatch = true
            if espCfg.TargetTeam ~= "全てのチーム" then
                if not p.Team or p.Team.Name ~= espCfg.TargetTeam then
                    isTeamMatch = false
                end
            end

            local shouldShow = false
            local isTarget = (not espCfg.TargetOnly) or (espCfg.TargetOnly and p == targetSub)
            
            -- 設定が有効、かつターゲット一致、かつチーム一致、かつ生存している場合
            if espCfg.Enabled and isTarget and isTeamMatch and root and hum and hum.Health > 0 then
                shouldShow = true
            end

            local esp = espCache[p] or {}
            
            if shouldShow then
                -- カラー決定
                local color = espCfg.ESPColor
                if espCfg.UseTeamColor and p.TeamColor then
                    color = p.TeamColor.Color
                end

                -- 1. ハイライト処理
                if not esp.H or esp.H.Parent ~= char then 
                    esp.H = Instance.new("Highlight")
                    esp.H.Parent = char
                    esp.H.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                end
                esp.H.Enabled = true
                esp.H.Enabled = espCfg.Highlight -- 個別トグル
                esp.H.FillColor = color

                -- 2. アイコン付き名前表示 (確実に動くURL形式)
                if not esp.B or esp.B.Parent ~= root then
                    esp.B = Instance.new("BillboardGui")
                    esp.B.Parent = root
                    esp.B.Size = UDim2.new(0, 250, 0, 50)
                    esp.B.AlwaysOnTop = true
                    esp.B.ExtentsOffset = Vector3.new(0, 3, 0)

                    local frame = Instance.new("Frame", esp.B)
                    frame.Size = UDim2.new(1, 0, 1, 0)
                    frame.BackgroundTransparency = 1

                    local icon = Instance.new("ImageLabel", frame)
                    icon.Name = "Icon"
                    icon.Size = UDim2.new(0, 30, 0, 30)
                    icon.Position = UDim2.new(0, 0, 0.5, -15)
                    icon.BackgroundTransparency = 1
                    -- アイコンが表示されていた形式のURLを使用
                    icon.Image = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. p.UserId .. "&width=420&height=420&format=png"

                    local l = Instance.new("TextLabel", frame)
                    l.Name = "NameLabel"
                    l.Size = UDim2.new(1, -35, 1, 0)
                    l.Position = UDim2.new(0, 35, 0, 0)
                    l.BackgroundTransparency = 1
                    l.TextXAlignment = Enum.TextXAlignment.Left
                    l.TextStrokeTransparency = 0
                    l.Font = Enum.Font.SourceSansBold
                    l.TextSize = 14
                    
                    esp.L = l
                    esp.I = icon
                end
                esp.B.Enabled = true
                esp.I.Visible = espCfg.Icons
                esp.L.Visible = espCfg.Names
                esp.L.Text = p.DisplayName .. " (@" .. p.Name .. ")"
                esp.L.TextColor3 = color

                -- 3. トレーサー (改善版)
                if espCfg.Tracers then
                    if not esp.T then
                        esp.T = Drawing.new("Line")
                        esp.T.Thickness = 1
                        esp.T.Transparency = 1
                    end
                    
                    local screenPos, onScreen = Camera:WorldToViewportPoint(root.Position)
                    esp.T.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                    esp.T.Color = color
                    
                    if onScreen then
                        esp.T.To = Vector2.new(screenPos.X, screenPos.Y)
                        esp.T.Visible = true
                    else
                        -- 画面外のトレーサー処理（不要な場合は visible = false に）
                        esp.T.Visible = false 
                    end
                elseif esp.T then
                    esp.T.Visible = false
                end

                -- 4. ヒットボックス
                if espCfg.Hitbox then
                    root.Size = Vector3.new(espCfg.HitboxSize, espCfg.HitboxSize, espCfg.HitboxSize)
                    root.Transparency = 0.5
                    root.Color = color
                    root.CanCollide = false
                else
                    root.Size = Vector3.new(2, 2, 1)
                    root.Transparency = 1
                end
                espCache[p] = esp
            else
                -- 表示不要（退出・死亡・設定OFF）になったら即座にクリーンアップ
                removeESP(p)
                -- ヒットボックスのサイズも元に戻す
                if root and root.Parent then
                    root.Size = Vector3.new(2, 2, 1)
                    root.Transparency = 1
                end
            end
        end
    end
end

-- オートエイムループ
RunService.RenderStepped:Connect(function()
    -- FOV円の更新
    fovCircle.Position = UserInputService:GetMouseLocation()
    fovCircle.Radius = aimCfg.FOV
    fovCircle.Visible = aimCfg.Enabled and aimCfg.ShowFOV

    if aimCfg.Enabled then
        local closest = nil
        local minDist = aimCfg.FOV
        local mousePos = UserInputService:GetMouseLocation()

        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                -- 敵判定 (自分のチームと違う場合、またはチームがない場合)
                local isEnemy = true
                if p.Team and LocalPlayer.Team and p.Team == LocalPlayer.Team then
                    isEnemy = false
                end

                if isEnemy and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
                    local root = p.Character.HumanoidRootPart
                    local screenPos, onScreen = Camera:WorldToViewportPoint(root.Position)
                    
                    if onScreen then
                        local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                        if dist < minDist then
                            -- 壁抜きチェック
                            if not aimCfg.ThroughWalls then
                                local params = RaycastParams.new()
                                params.FilterDescendantsInstances = {LocalPlayer.Character, p.Character, workspace.CurrentCamera}
                                params.FilterType = Enum.RaycastFilterType.Exclude
                                local dir = (root.Position - Camera.CFrame.Position)
                                local result = workspace:Raycast(Camera.CFrame.Position, dir.Unit * dir.Magnitude, params)
                                if result then continue end -- 壁がある
                            end
                            
                            minDist = dist
                            closest = root
                        end
                    end
                end
            end
        end
        
        if closest then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, closest.Position)
        end
    end
end)

--------------------------------------------------------------------------------
-- [UI 構築] orion lib
--------------------------------------------------------------------------------
local OrionUrl = "https://raw.githubusercontent.com/hololove1021/HolonHUB/refs/heads/main/source.txt"

-- [[ 1. メイン画面の関数 ]]
local function StartHolonHUB()
    -- スマホ対策：OrionLibを関数内で読み込み直す
    OrionLib = loadstring(game:HttpGet(OrionUrl))()
    
    -- 既存のUIを強制削除（二重表示防止）
    pcall(function()
        if game:GetService("CoreGui"):FindFirstChild("Orion") then 
            game:GetService("CoreGui").Orion:Destroy() 
        end
    end)

    local Window = OrionLib:MakeWindow({
        Name = "Holon HUB v1.3.9",
        HidePremium = false,
        SaveConfig = false, -- 初期化時の干渉を防ぐため無効化
        ConfigFolder = "HolonHUB",
        IntroEnabled = true,
        IntroText = "Holon HUB v1.3.9 Loaded!"
    })

-- プレイヤーリスト取得関数
local function getPList()
    local plist = {}
    for _, p in ipairs(Players:GetPlayers()) do
        -- 「表示名 (@ユーザー名)」の形式でテーブルに入れる
        table.insert(plist, p.DisplayName .. " (@" .. p.Name .. ")")
    end
    return plist
end

-- --- TAB: AUTO AIM ---
local AimTab = Window:MakeTab({
    Name = "オートエイム",
    Icon = "rbxassetid://7733674676" -- ターゲットアイコン
})

local AimSec = AimTab:AddSection({ Name = "エイムボット設定" })

UIElements.AimEnabled = AimSec:AddToggle({
    Name = "オートエイム有効化",
    Default = false,
    Callback = function(v) 
        aimCfg.Enabled = v 
        updateMiniUI()
    end
})

UIElements.AimShowFOV = AimSec:AddToggle({
    Name = "FOV円を表示",
    Default = true,
    Callback = function(v) 
        aimCfg.ShowFOV = v 
        updateMiniUI()
    end
})

UIElements.AimFOV = AimSec:AddSlider({
    Name = "FOVサイズ (円の大きさ)",
    Min = 10, Max = 800, Default = 150,
    Callback = function(v) 
        aimCfg.FOV = v 
        updateMiniUI()
    end
})

UIElements.AimThroughWalls = AimSec:AddToggle({
    Name = "壁抜き (壁を無視)",
    Default = false,
    Callback = function(v) aimCfg.ThroughWalls = v end
})

AimSec:AddToggle({
    Name = "ミニUIを表示",
    Default = false,
    Callback = function(v) miniUiGui.Enabled = v end
})

UIElements.AimTargetTeam = AimSec:AddDropdown({
    Name = "対象チーム",
    Default = "敵チーム",
    Options = (function() 
        local list = {"敵チーム", "全てのチーム"}
        for _, t in ipairs(Teams:GetTeams()) do table.insert(list, t.Name) end
        return list
    end)(),
    Callback = function(v) 
        aimCfg.TargetTeam = v 
        updateMiniUI()
    end
})

AimSec:AddButton({
    Name = "現在のターゲットを解除",
    Callback = function() currentLockedTarget = nil end
})

AimSec:AddDropdown({
    Name = "狙う部位",
    Default = "HumanoidRootPart",
    Options = {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso"},
    Callback = function(v) aimCfg.TargetPart = v end
})

local DetailTab = Window:MakeTab({Name = "詳細", Icon = DetailIcon})
AddDetailContent(DetailTab)

-- 通知（起動時）
OrionLib:MakeNotification({
	Name = "Holon HUB",
	Content = "v1.3.9 が読み込まれました！",
	Time = 5
})

    -- メイン画面側の初期化
    OrionLib:Init()
end
StartHolonHUB()
