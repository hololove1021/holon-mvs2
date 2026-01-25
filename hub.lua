fovCircle.Color = Color3.new(1, 1, 1)
fovCircle.Transparency = 1

-- 以前のバージョンの残留物を削除
if game:GetService("CoreGui"):FindFirstChild("HolonESP_Holder") then
    game:GetService("CoreGui").HolonESP_Holder:Destroy()
end

--------------------------------------------------------------------------------
-- [ESP & サブ機能] 更新ループ (Prometheus対応版)
--------------------------------------------------------------------------------
                    esp.Name.Visible = false
                end

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
                -- 3. トレーサー (改善版)
                if espCfg.Tracers then
                    if not esp.Tracer then
                        esp.Tracer = Drawing.new("Line")
                        esp.Tracer.Thickness = 1
                        esp.Tracer.Transparency = 1
                    end
                    
                    esp.Tracer.Visible = onScreen
                    if onScreen then
                        esp.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                        esp.Tracer.To = Vector2.new(vector.X, vector.Y)
                        esp.Tracer.Color = color
                    end
                elseif esp.Tracer then
                    esp.Tracer.Visible = false
                end
                
                espCache[p] = esp
            else
                -- 表示不要（退出・死亡・設定OFF）になったら即座にクリーンアップ
                removeESP(p)
            end
        end
    end
end

-- オートエイムループ
RunService.RenderStepped:Connect(function()
    -- FOV円の更新
    fovCircle.Position = UserInputService:GetMouseLocation()
    fovCircle.Radius = aimCfg.FOV
    fovCircle.Visible = aimCfg.ShowFOV

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

                if isEnemy and p.Character and p.Character:FindFirstChild(aimCfg.TargetPart) and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
                    local targetPart = p.Character[aimCfg.TargetPart]
                    local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                    
                    if onScreen then
                        local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                        if dist < minDist then
                            -- 壁抜きチェック
                            if not aimCfg.ThroughWalls then
                                local params = RaycastParams.new()
                                params.FilterDescendantsInstances = {LocalPlayer.Character, p.Character, workspace.CurrentCamera}
                                params.FilterType = Enum.RaycastFilterType.Exclude
                                local dir = (targetPart.Position - Camera.CFrame.Position)
                                local result = workspace:Raycast(Camera.CFrame.Position, dir.Unit * dir.Magnitude, params)
                                if result then continue end -- 壁がある
                            end
                            
                            minDist = dist
                            closest = targetPart
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

RunService.Heartbeat:Connect(updateSubFeatures)

--------------------------------------------------------------------------------
-- [UI 構築] orion lib
--------------------------------------------------------------------------------
local OrionUrl = "https://raw.githubusercontent.com/hololove1021/HolonHUB/refs/heads/main/source.txt"

-- [[ 1. メイン画面の関数 ]]
local function StartHolonHUB()
    -- スマホ対策：OrionLibを関数内で読み込み直す
    local OrionLib = loadstring(game:HttpGet(OrionUrl))()
    
    -- 既存のUIを強制削除（二重表示防止）
    pcall(function()
        if game:GetService("CoreGui"):FindFirstChild("Orion") then 
            game:GetService("CoreGui").Orion:Destroy() 
        end
    end)

    local Window = OrionLib:MakeWindow({
        Name = "Holon HUB v1.3.6",
        HidePremium = false,
        SaveConfig = false, -- 初期化時の干渉を防ぐため無効化
        ConfigFolder = "HolonHUB",
        IntroEnabled = true,
        IntroText = "Holon HUB v1.3.6 Loaded!"
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

-- UI要素を管理するテーブル
local UIElements = {}

-- --- TAB: AUTO AIM ---
local AimTab = Window:MakeTab({
    Name = "オートエイム",
    Icon = "rbxassetid://7733674676" -- ターゲットアイコン
})

local AimSec = AimTab:AddSection({ Name = "エイムボット設定" })

UIElements.AimEnabled = AimSec:AddToggle({
    Name = "オートエイム有効化",
    Default = false,
    Callback = function(v) aimCfg.Enabled = v end
})

UIElements.AimShowFOV = AimSec:AddToggle({
    Name = "FOV円を表示",
    Default = true,
    Callback = function(v) aimCfg.ShowFOV = v end
})

UIElements.AimFOV = AimSec:AddSlider({
    Name = "FOVサイズ (円の大きさ)",
    Min = 10, Max = 800, Default = 150,
    Callback = function(v) aimCfg.FOV = v end
})

UIElements.AimThroughWalls = AimSec:AddToggle({
    Name = "壁抜き (壁を無視)",
    Default = false,
    Callback = function(v) aimCfg.ThroughWalls = v end
})

AimSec:AddDropdown({
    Name = "狙う部位",
    Default = "HumanoidRootPart",
    Options = {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso"},
    Callback = function(v) aimCfg.TargetPart = v end
})

-- --- TAB: ESP ---
local EspTab = Window:MakeTab({
    Name = "ESP",
    Icon = "rbxassetid://7733771472"
})

-- ESP設定セクション
local EspSec = EspTab:AddSection({
    Name = "ESP設定"
})

UIElements.EspEnabled = EspSec:AddToggle({
    Name = "ESP有効",
    Default = false,
    Callback = function(v) espCfg.Enabled = v end 
})

UIElements.EspTargetOnly = EspSec:AddToggle({
    Name = "ターゲットのみ表示",
    Default = false,
    Callback = function(v) espCfg.TargetOnly = v end 
})

UIElements.EspTargetTeam = EspSec:AddDropdown({
    Name = "対象チーム選択",
    Default = "全てのチーム",
    Options = getTeamList(),
    Callback = function(v) espCfg.TargetTeam = v end
})

UIElements.EspNames = EspSec:AddToggle({
    Name = "名前表示",
    Default = true,
    Callback = function(v) espCfg.Names = v end 
})

UIElements.EspHighlight = EspSec:AddToggle({
    Name = "体を発光 (Box)",
    Default = false,
    Callback = function(v) espCfg.Highlight = v end 
})

UIElements.EspTracers = EspSec:AddToggle({
    Name = "トレーサー表示",
    Default = false,
    Callback = function(v) espCfg.Tracers = v end 
})

UIElements.EspUseTeamColor = EspSec:AddToggle({
    Name = "チームカラーを使用",
    Default = false,
    Callback = function(v) espCfg.UseTeamColor = v end
})

UIElements.EspColor = EspSec:AddColorpicker({
    Name = "ESPカラー",
    Default = Color3.new(1,0,0),
    Callback = function(v)
        espCfg.ESPColor = v
    end	  
})

local DetailTab = Window:MakeTab({Name = "詳細", Icon = DetailIcon})
AddDetailContent(DetailTab)

-- 通知（起動時）
OrionLib:MakeNotification({
	Name = "Holon HUB",
	Content = "v1.3.6 が読み込まれました！",
	Time = 5
})
    -- 起動時にUIスタイルを適用
    applyCustomStyle()

    -- メイン画面側の初期化
    OrionLib:Init()
end
StartHolonHUB()
