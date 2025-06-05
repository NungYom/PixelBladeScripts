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
local updateInterval = 0.75
local autoMoveEnabled = false
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

local function isInExcludedFolder(npc)
	for _, folder in ipairs(excludeFolders) do
		if folder and npc:IsDescendantOf(folder) then
			return true
		end
	end
	return false
end

local excludedNames = {
	["GoblinType1"] = true,
	["GoblinType2"] = true
}

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
			and not isInExcludedFolder(npc) then

			local dist = (HumanoidRootPart.Position - npc.HumanoidRootPart.Position).Magnitude
			if dist < maxDistance and dist < shortestDistance then
				shortestDistance = dist
				nearestMob = npc
			end
		end
	end

	return nearestMob
end

local touchedParts = {}

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

local currentTween

local function walkToOffset(targetCFrame, offset)
	if currentTween then currentTween:Cancel() end

	local offsetCFrame = targetCFrame * CFrame.new(0, 0, -offset)
	local distance = (HumanoidRootPart.Position - offsetCFrame.Position).Magnitude
	local travelTime = distance / moveSpeed

	local tweenInfo = TweenInfo.new(travelTime, Enum.EasingStyle.Linear)
	local tween = TweenService:Create(HumanoidRootPart, tweenInfo, {
		CFrame = offsetCFrame
	})
	currentTween = tween
	tween:Play()
end

-- วงกลมรอบมอนสเตอร์
local orbitConnection
local orbiting = false

local function startOrbit(target, onFinish)
	if orbiting or not target or not target:FindFirstChild("HumanoidRootPart") then return end
	orbiting = true
	local radius = 4
	local angle = 0

	orbitConnection = RunService.RenderStepped:Connect(function(dt)
		if not autoMoveEnabled or not target or not target:FindFirstChild("Humanoid") or target.Humanoid.Health <= 0 then
			orbiting = false
			if orbitConnection then orbitConnection:Disconnect() end
			if onFinish then onFinish() end
			return
		end

		angle = angle + dt * math.pi
		local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local targetPos = target.HumanoidRootPart.Position + offset
		HumanoidRootPart.CFrame = CFrame.new(targetPos, target.HumanoidRootPart.Position)
	end)
end

-- Healing ตรวจจับ hp ต่ำ
task.spawn(function()
	while true do
		if autoMoveEnabled and not isHealing and Humanoid.Health > 0 then
			if Humanoid.Health / Humanoid.MaxHealth < 0.2 then
				isHealing = true
				local currentPos = HumanoidRootPart.Position
				local downPos = Vector3.new(currentPos.X, currentPos.Y - 1000, currentPos.Z)
				HumanoidRootPart.CFrame = CFrame.new(downPos)
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
				walkToOffset(mob.HumanoidRootPart.CFrame, 2)
				startOrbit(mob, function()
					task.wait()
				end)
			else
				local touchPart = getNearestUntouchedTouchPart()
				if touchPart then
					touchedParts[touchPart] = true
					walkToOffset(touchPart.CFrame, 0)
					task.wait(1.5)
				end
			end
		end
		task.wait(updateInterval)
	end
end)
