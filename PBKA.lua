local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")

-- ตั้งค่า
local moveSpeed = 100
local scanRadius = 1500
local combatRange = 400
local updateInterval = 0.1
local autoMoveEnabled = false
local orbiting = false
local orbitRadius = 4
local orbitConnection
local isHealing = false

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

-- โฟลเดอร์ใน GoblinArena ที่ต้องกรอง
local goblinArenaFolder = workspace:FindFirstChild("GoblinArena")
local excludeFolders = {}

if goblinArenaFolder then
	excludeFolders = {
		goblinArenaFolder:FindFirstChild("DrumGoblins"),
		goblinArenaFolder:FindFirstChild("Goblins"),
		goblinArenaFolder:FindFirstChild("introPositions")
	}
end

-- ฟังก์ชันตรวจสอบว่า NPC อยู่ในโฟลเดอร์ที่ต้องกรองหรือไม่
local function isInExcludedFolder(npc)
	for _, folder in ipairs(excludeFolders) do
		if folder and npc:IsDescendantOf(folder) then
			return true
		end
	end
	return false
end

-- รายชื่อ NPC ที่ไม่ต้องไล่ตาม
local excludedNames = {
	["GoblinType1"] = true,
	["GoblinType2"] = true
}

-- ฟังก์ชันหา mob ที่ใกล้ที่สุดภายในระยะที่กำหนด
local function getNearestMobInRange(maxDistance)
	local nearestMob = nil
	local shortestDistance = math.huge

	for _, npc in pairs(workspace:GetDescendants()) do
		if npc:IsA("Model")
			and npc ~= Character
			and npc:FindFirstChild("Humanoid")
			and npc:FindFirstChild("HumanoidRootPart")
			and npc.Humanoid.Health > 0
			and not excludedNames[npc.Name]
			and not isInExcludedFolder(npc)
			and not Players:GetPlayerFromCharacter(npc) then

			local dist = (HumanoidRootPart.Position - npc.HumanoidRootPart.Position).Magnitude
			if dist < maxDistance and dist < shortestDistance then
				shortestDistance = dist
				nearestMob = npc
			end
		end
	end

	return nearestMob
end

-- จำแคมป์ไฟที่เคยสัมผัสแล้ว
local touchedParts = {}

-- หา touch part ที่ยังไม่เคยไป
local function getNearestUntouchedTouchPart()
	local nearestPart = nil
	local shortestDistance = math.huge

	for _, part in pairs(workspace:GetDescendants()) do
		if part:IsA("BasePart")
			and part.Name:lower() == "touch"
			and not touchedParts[part] then

			local dist = (HumanoidRootPart.Position - part.Position).Magnitude
			if dist < scanRadius and dist < shortestDistance then
				shortestDistance = dist
				nearestPart = part
			end
		end
	end

	return nearestPart
end

-- Tween ไปหา
local currentTween

local function walkTo(targetCFrame)
	if currentTween then currentTween:Cancel() end

	local distance = (HumanoidRootPart.Position - targetCFrame.Position).Magnitude
	local travelTime = distance / moveSpeed

	local tweenInfo = TweenInfo.new(travelTime, Enum.EasingStyle.Linear)
	local targetOffset = targetCFrame.LookVector.Unit * -4
	local tween = TweenService:Create(HumanoidRootPart, tweenInfo, {
		CFrame = CFrame.new(targetCFrame.Position + targetOffset)
	})
	currentTween = tween
	tween:Play()
end

-- เดินวนรอบ mob
local function orbitAround(target)
	if orbiting or not target then return end
	orbiting = true

	local angle = 0
	orbitConnection = RunService.RenderStepped:Connect(function(dt)
		if not autoMoveEnabled or not target or not target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("Humanoid").Health <= 0 then
			orbiting = false
			if orbitConnection then orbitConnection:Disconnect() end
			return
		end

		angle = angle + dt * 2
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * orbitRadius
		local targetPos = target.HumanoidRootPart.Position + offset
		Humanoid:MoveTo(targetPos)
	end)
end

-- ตรวจจับ HP ต่ำ แล้วเทเลพอร์ต
task.spawn(function()
	while true do
		if autoMoveEnabled and not isHealing and Humanoid.Health > 0 then
			if Humanoid.Health / Humanoid.MaxHealth < 0.2 then
				isHealing = true
				if currentTween then currentTween:Cancel() end
				if orbitConnection then orbitConnection:Disconnect() end
				orbiting = false

				local currentPos = HumanoidRootPart.Position
				local targetPos = Vector3.new(currentPos.X, currentPos.Y - 1000, currentPos.Z)
				Humanoid:MoveTo(targetPos)
				task.wait(1)
				HumanoidRootPart.CFrame = CFrame.new(targetPos)

				task.wait(1.5)
				isHealing = false
			end
		end
		task.wait(0.25)
	end
end)

-- ลูปหลัก
task.spawn(function()
	while true do
		if autoMoveEnabled and not isHealing then
			local mob = getNearestMobInRange(combatRange)
			if mob then
				walkTo(mob.HumanoidRootPart.CFrame)
				repeat
					task.wait(0.05)
				until not mob or not mob:FindFirstChild("Humanoid") or mob.Humanoid.Health <= 0 or not autoMoveEnabled or isHealing

				if mob and mob:FindFirstChild("Humanoid") and mob.Humanoid.Health > 0 then
					orbitAround(mob)
				end
			else
				local touchPart = getNearestUntouchedTouchPart()
				if touchPart then
					touchedParts[touchPart] = true
					walkTo(touchPart.CFrame)
					task.wait(1)
				end
			end
		end
		task.wait(updateInterval)
	end
end)
