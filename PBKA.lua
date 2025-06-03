local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

-- Remotes
local remotes = ReplicatedStorage:WaitForChild("remotes")
local swing = remotes:FindFirstChild("swing")
local newEffect = remotes:FindFirstChild("newEffect")
local onHit = remotes:FindFirstChild("onHit")

-- GUI ที่แสดงผล
local gui = Instance.new("ScreenGui", PlayerGui)
gui.Name = "KillAuraGui"

-- ปุ่มเปิดปิด Kill Aura
local button = Instance.new("TextButton")
button.Size = UDim2.new(0, 250, 0, 60)
button.Position = UDim2.new(0, 30, 0, 30)
button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
button.TextColor3 = Color3.fromRGB(255, 255, 255)
button.Font = Enum.Font.GothamBold
button.TextSize = 22
button.Text = "Kill Aura: OFF"
button.Parent = gui

local function fireOnHit(targetModel)
    if not targetModel then return end
    local hum = targetModel:FindFirstChild("Humanoid")
    if not hum then return end
    if not onHit then
        warn("onHit remote not found!")
        return
    end
    -- จำลอง hit
    local dummy = Instance.new("Humanoid") -- หลอก server ว่าโดนโจมตี
    onHit:FireServer(dummy, 16, {}, 0)
end

-- แสดง Log / Debug
local logLabel = Instance.new("TextLabel")
logLabel.Size = UDim2.new(0, 500, 0, 100)
logLabel.Position = UDim2.new(0, 30, 0, 100)
logLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
logLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
logLabel.Font = Enum.Font.Code
logLabel.TextSize = 16
logLabel.TextWrapped = true
logLabel.Text = "Logs:\n"
logLabel.Parent = gui

local function log(msg)
    logLabel.Text = logLabel.Text .. tostring(msg) .. "\n"
end

local auraOn = false
button.MouseButton1Click:Connect(function()
    auraOn = not auraOn
    button.Text = "Kill Aura: " .. (auraOn and "ON" or "OFF")
    log("Aura Toggled: " .. tostring(auraOn))
end)

-- หาเป้าหมายในระยะ 100 studs
local function getTargets(radius)
    local targets = {}

    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
            local dist = (HumanoidRootPart.Position - p.Character.HumanoidRootPart.Position).Magnitude
            if dist <= radius then
                table.insert(targets, p.Character)
            end
        end
    end

    for _, npc in pairs(workspace:GetDescendants()) do
        if npc:IsA("Model") and npc:FindFirstChild("Humanoid") and npc:FindFirstChild("HumanoidRootPart") and npc ~= Character and npc.Humanoid.Health > 0 then
            local dist = (HumanoidRootPart.Position - npc.HumanoidRootPart.Position).Magnitude
            if dist <= radius then
                table.insert(targets, npc)
            end
        end
    end

    return targets
end

-- โจมตี 1 ครั้ง
local function attack()
    local crusher = Character:FindFirstChild("Crusher")
    if not crusher then
        log("❌ ไม่พบอาวุธ 'Crusher'")
        return
    end

    -- Fire PositionalSound
    newEffect:FireServer("PositionalSound", {
        position = HumanoidRootPart.Position,
        soundName = "SwordSwoosh",
        positionMoveWith = HumanoidRootPart
    })
    log("🎵 Fired: PositionalSound")

    -- Fire Slash
    newEffect:FireServer("Slash", {
        wpn = crusher,
        waitTime = 0.1
    })
    log("💥 Fired: Slash Effect")

    -- Fire Swing
    swing:FireServer()
    log("🗡️ Fired: swing")
end

-- ลูป Kill Aura
task.spawn(function()
    while true do
        if auraOn then
            local targets = getTargets(100)
            if #targets > 0 then
                log("🎯 Targets found: " .. #targets)
                attack()

                -- เรียก fireOnHit กับเป้าหมายแต่ละตัว
                for _, target in pairs(targets) do
                    fireOnHit(target)
                end
            end
        end
        task.wait(0.3)
    end
end)
