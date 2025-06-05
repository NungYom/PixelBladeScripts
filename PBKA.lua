local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

-- Settings
local moveSpeed = 100
local scanRadius = 1500
local baseCombatRange = 100
local combatRange = baseCombatRange
local updateInterval = 0.1
local autoMoveEnabled = false
local touchedParts = {}
local lastTarget = nil
local currentTween = nil

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
toggleButton.Text = "AutoFarm: OFF"
toggleButton.Parent = gui

toggleButton.MouseButton1Click:Connect(function()
	autoMoveEnabled = not autoMoveEnabled
	toggleButton.Text = "AutoFarm: " .. (autoMoveEnabled and "ON" or "OFF")
	if autoMoveEnabled then
		Humanoid.WalkSpeed = moveSpeed
	else
		if currentTween then
			currentTween:Cancel()
			currentTween = nil
		end
		Humanoid.WalkSpeed = 16
		lastTarget = nil
	end
end)

-- Noclip function
local function noclip()
	for _, part in pairs(Character:GetChildren()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
		end
	end
end

RunService.Stepped:Connect(function()
	if autoMoveEnabled then
		noclip()
		-- Lock camera to humanoid
		if Camera.CameraSubject ~= Humanoid then
			Camera.CameraSubject = Humanoid
			Camera.CameraType = Enum.CameraType.Custom
		end
	end
end)

local goblinArenaFolder = workspace:FindFirstChild("GoblinArena")
local excludeFolders = {}
if goblinArenaFolder then
	excludeFolders = {
		goblinArenaFolder:FindFirstChild("DrumGoblins"),
		goblinArenaFolder:FindFirstChild("Goblins"),
		goblinArenaFolder:FindFirstChild("introPositions")
	}
end

local excludedNames = {
	["GoblinType1"] = true,
	["GoblinType2"] = true
}

local function isInExcludedFolder(npc)
	for _, folder in ipairs(excludeFolders) do
		if folder and npc:IsDescendantOf(folder) then
			return true
		end
	end
	return false
end

local function isOnGround(part)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	raycastParams.FilterDescendantsInstances = {part.Parent}
	local ray = workspace:Raycast(part.Position, Vector3.new(0, -10, 0), raycastParams)
	return ray ~= nil
end

local function getLowestHpMobInRange(maxDistance)
	local lowestHpMob = nil
	local lowestHp = math.huge

	for _, npc in pairs(workspace:GetDescendants()) do
		if npc:IsA("Model")
			and npc ~= Character
			and npc:FindFirstChild("Humanoid")
			and npc:FindFirstChild("HumanoidRootPart")
			and npc.Humanoid.Health > 0
			and not excludedNames[npc.Name]
			and not isInExcludedFolder(npc)
			and isOnGround(npc.HumanoidRootPart) then

			local dist = (HumanoidRootPart.Position - npc.HumanoidRootPart.Position).Magnitude
			if dist < maxDistance and npc.Humanoid.Health < lowestHp then
				lowestHp = npc.Humanoid.Health
				lowestHpMob = npc
			end
		end
	end

	return lowestHpMob
end

local function getNearestUntouchedTouchPart()
	local nearestPart = nil
	local shortestDistance = math.huge

	for _, part in pairs(workspace:GetDescendants()) do
		if part:IsA("BasePart")
			and part.Name:lower() == "touch"
			and not touchedParts[part] then

			local dist = (HumanoidRootPart.Position - part.Position).Magnitude
			if dist < shortestDistance then
				shortestDistance = dist
				nearestPart = part
			end
		end
	end

	return nearestPart
end

local function walkTo(targetPosition)
	if currentTween then
		currentTween:Cancel()
		currentTween = nil
	end

	local distance = (HumanoidRootPart.Position - targetPosition).Magnitude
	local travelTime = distance / moveSpeed
	if travelTime < 0.1 then travelTime = 0.1 end

	local tweenInfo = TweenInfo.new(travelTime, Enum.EasingStyle.Linear)
	currentTween = TweenService:Create(HumanoidRootPart, tweenInfo, {
		CFrame = CFrame.new(targetPosition.X, HumanoidRootPart.Position.Y, targetPosition.Z)
	})
	currentTween:Play()
end

local isCircling = false

local function circleAroundTarget(target)
	if isCircling then return end
	isCircling = true

	while autoMoveEnabled and target and target:FindFirstChild("Humanoid") and target.Humanoid.Health > 0 do
		local touchPart = getNearestUntouchedTouchPart()
		if touchPart then
			touchedParts[touchPart] = true
			walkTo(touchPart.Position)
			task.wait(3)
			lastTarget = nil
			break
		end

		local radius = 5
		local angle = tick() % (2 * math.pi)
		local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local goalPos = target.HumanoidRootPart.Position + offset
		walkTo(goalPos)
		task.wait(0.1)
	end

	isCircling = false
end

task.spawn(function()
	while true do
		if autoMoveEnabled then
			local touchPart = getNearestUntouchedTouchPart()
			if touchPart then
				touchedParts[touchPart] = true
				walkTo(touchPart.Position)
				task.wait(3)
				lastTarget = nil
			else
				combatRange = baseCombatRange
				local mob = nil

				while not mob and combatRange <= scanRadius do
					mob = getLowestHpMobInRange(combatRange)
					if not mob then
						combatRange += 100
						task.wait(0.05)
					end
				end

				if mob then
					if mob ~= lastTarget then
						lastTarget = mob
						circleAroundTarget(mob)
					end
				end
			end
		end
		task.wait(updateInterval)
	end
end)
