local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

-- ตั้งค่า
local moveSpeed = 1000 -- ความเร็วสูงสุด
local scanRadius = 1500
local combatRange = 400
local updateInterval = 0.1
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
	local nearestMob, shortestDistance = nil, math.huge
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
	local nearestPart, shortestDistance = nil, math.huge
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

-- Tween function
local currentTween
local tweenTarget = nil

local function walkToCFrame(targetCFrame)
	if currentTween then currentTween:Cancel() end
	tweenTarget = targetCFrame

	local distance = (HumanoidRootPart.Position - targetCFrame.Position).Magnitude
	local travelTime = distance / moveSpeed

	local tweenInfo = TweenInfo.new(travelTime, Enum.EasingStyle.Linear)
	currentTween = TweenService:Create(HumanoidRootPart, tweenInfo, {
		CFrame = targetCFrame
	})
	currentTween:Play()
end

-- NoClip
RunService.Stepped:Connect(function()
	if autoMoveEnabled then
		for _, part in pairs(Character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = false
			end
		end
	end
end)

-- Move in circle
local function moveInCircleAroundTarget(target)
	local radius = 4
	local angle = 0
	local center = target.HumanoidRootPart.Position

	while autoMoveEnabled and target and target:FindFirstChild("Humanoid") and target.Humanoid.Health > 0 do
		angle += math.rad(10)
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius
		local pos = center + offset
		local cframe = CFrame.new(pos, center)
		walkToCFrame(cframe)
		task.wait(0.1)
	end
end

-- HP Monitor
task.spawn(function()
	while true do
		if autoMoveEnabled and Humanoid.Health > 0 then
			local maxHealth = Humanoid.MaxHealth
			if Humanoid.Health / maxHealth < 0.2 then
				local pos = HumanoidRootPart.Position
				local below = pos - Vector3.new(0, 1000, 0)
				HumanoidRootPart.CFrame = CFrame.new(below)
				task.wait(2) -- รอให้ฟื้น HP
			end
		end
		task.wait(0.25)
	end
end)

-- Main Loop
task.spawn(function()
	local currentTarget = nil
	local targetStartTime = 0

	while true do
		if autoMoveEnabled then
			local now = tick()

			if currentTarget and currentTarget:FindFirstChild("Humanoid") and currentTarget.Humanoid.Health > 0 then
				if now - targetStartTime > 3 then
					currentTarget = nil -- เปลี่ยนเป้าหมาย
				else
					moveInCircleAroundTarget(currentTarget)
				end
			else
				local mob = getNearestMobInRange(combatRange)
				if mob then
					currentTarget = mob
					targetStartTime = tick()

					local targetPos = mob.HumanoidRootPart.Position
					local dir = (targetPos - HumanoidRootPart.Position).Unit
					local safeOffset = -dir * 2 -- ระยะห่าง 2 studs
					local dest = targetPos + safeOffset
					walkToCFrame(CFrame.new(dest, targetPos))
				else
					local touchPart = getNearestUntouchedTouchPart()
					if touchPart then
						touchedParts[touchPart] = true
						walkToCFrame(touchPart.CFrame)
						task.wait(1.5)
					end
				end
			end
		end
		task.wait(updateInterval)
	end
end)
