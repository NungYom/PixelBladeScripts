local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

-- ตั้งค่า
local moveSpeed = 100 -- studs per second
local scanRadius = 1500 -- ระยะค้นหา
local updateInterval = 0.75 -- ความถี่การค้นหา
local autoMoveEnabled = false

-- GUI สั้น ๆ
local gui = Instance.new("ScreenGui", PlayerGui)
gui.Name = "AutoMoveGUI"

local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0, 200, 0, 50)
toggleButton.Position = UDim2.new(0, 20, 0, 20)
toggleButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.Font = Enum.Font.GothamBold
toggleButton.TextSize = 20
toggleButton.Text = "AutoMove: OFF"
toggleButton.Parent = gui

toggleButton.MouseButton1Click:Connect(function()
	autoMoveEnabled = not autoMoveEnabled
	toggleButton.Text = "AutoMove: " .. (autoMoveEnabled and "ON" or "OFF")
end)

-- หา Mob ที่ใกล้ที่สุด
local function getNearestMob()
	local nearestMob = nil
	local shortestDistance = math.huge

	for _, npc in pairs(workspace:GetDescendants()) do
		if npc:IsA("Model") and npc:FindFirstChild("Humanoid") and npc:FindFirstChild("HumanoidRootPart") and npc ~= Character and npc.Humanoid.Health > 0 then
			local dist = (HumanoidRootPart.Position - npc.HumanoidRootPart.Position).Magnitude
			if dist < scanRadius and dist < shortestDistance then
				shortestDistance = dist
				nearestMob = npc
			end
		end
	end

	return nearestMob
end

-- Tween ไปหาเป้าหมาย
local function walkTo(target)
	local targetHRP = target:FindFirstChild("HumanoidRootPart")
	if not targetHRP then return end

	local distance = (HumanoidRootPart.Position - targetHRP.Position).Magnitude
	local travelTime = distance / moveSpeed

	local tweenInfo = TweenInfo.new(travelTime, Enum.EasingStyle.Linear)
	local tween = TweenService:Create(HumanoidRootPart, tweenInfo, {
		CFrame = targetHRP.CFrame * CFrame.new(0, 0, -3)
	})
	tween:Play()
end

-- ลูปการทำงาน
task.spawn(function()
	while true do
		if autoMoveEnabled then
			local mob = getNearestMob()
			if mob then
				walkTo(mob)
			end
		end
		task.wait(updateInterval)
	end
end)
