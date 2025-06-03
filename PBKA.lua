local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

-- ตั้งค่า
local moveSpeed = 100
local scanRadius = 1500
local updateInterval = 0.75
local autoMoveEnabled = false

-- GUI
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

-- ฟังก์ชันกรอง NPC ประกอบฉาก
local function isDecorativeNPC(npc)
	if not npc:IsA("Model") then return false end

	-- ตรวจโฟลเดอร์ต้นทางชื่อ "GoblinType1" หรือ "GoblinType2" ซึ่งมาจาก screenshot
	local parent = npc.Parent
	while parent do
		if parent.Name == "GoblinType1" or parent.Name == "GoblinType2" then
			return true
		end
		parent = parent.Parent
	end
	return false
end

-- หา Mob ที่ใกล้ที่สุด (ไม่นับ NPC ประกอบฉาก)
local function getNearestMob()
	local nearestMob = nil
	local shortestDistance = math.huge

	for _, npc in pairs(workspace:GetDescendants()) do
		if npc:IsA("Model")
			and npc ~= Character
			and npc:FindFirstChild("Humanoid")
			and npc:FindFirstChild("HumanoidRootPart")
			and npc.Humanoid.Health > 0
			and not isDecorativeNPC(npc) then

			local dist = (HumanoidRootPart.Position - npc.HumanoidRootPart.Position).Magnitude
			if dist < scanRadius and dist < shortestDistance then
				shortestDistance = dist
				nearestMob = npc
			end
		end
	end

	return nearestMob
end

-- หา Part ชื่อ "touch"
local function getNearestTouchPart()
	local nearestPart = nil
	local shortestDistance = math.huge

	for _, part in pairs(workspace:GetDescendants()) do
		if part:IsA("BasePart") and part.Name:lower() == "touch" then
			local dist = (HumanoidRootPart.Position - part.Position).Magnitude
			if dist < scanRadius and dist < shortestDistance then
				shortestDistance = dist
				nearestPart = part
			end
		end
	end

	return nearestPart
end

-- Tween ไปหาเป้าหมาย
local function walkTo(targetCFrame)
	local distance = (HumanoidRootPart.Position - targetCFrame.Position).Magnitude
	local travelTime = distance / moveSpeed

	local tweenInfo = TweenInfo.new(travelTime, Enum.EasingStyle.Linear)
	local tween = TweenService:Create(HumanoidRootPart, tweenInfo, {
		CFrame = targetCFrame * CFrame.new(0, 0, -3)
	})
	tween:Play()
end

-- ฟังก์ชันใช้สกิล tornado
local function useTornadoSkill()
	local mob = getNearestMob()
	if not mob then return end

	local newEffect = ReplicatedStorage:WaitForChild("remotes"):WaitForChild("newEffect")
	local useAbility = ReplicatedStorage:WaitForChild("remotes"):WaitForChild("useAbility")

	-- เอฟเฟกต์เสียง tornado (อาจไม่จำเป็น แต่มีใน remoteSpy)
	newEffect:FireServer("PositionalSound", {
		position = HumanoidRootPart.Position,
		soundName = "ability_tornado",
		positionMoveWith = HumanoidRootPart
	})

	-- เอฟเฟกต์ภาพ tornado
	newEffect:FireServer("tornadoWoosh", {
		char = Character,
		dur = 2,
		closestEnemy = mob
	})

	-- ใช้สกิล tornado จริง
	useAbility:FireServer({"tornado"})
end

-- ลูปเดินอัตโนมัติ
task.spawn(function()
	while true do
		if autoMoveEnabled then
			local mob = getNearestMob()
			if mob then
				walkTo(mob:FindFirstChild("HumanoidRootPart").CFrame)
			else
				local touchPart = getNearestTouchPart()
				if touchPart then
					walkTo(touchPart.CFrame)
				end
			end
		end
		task.wait(updateInterval)
	end
end)

-- ลูปใช้สกิล tornado ทุก 1 วิ
task.spawn(function()
	while true do
		if autoMoveEnabled then
			useTornadoSkill()
		end
		task.wait(1)
	end
end)
