local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

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
local updateInterval = 0.05
local autoMoveEnabled = false
local touchedParts = {}
local lastTarget = nil

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

-- Filter folders
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
			if dist < scanRadius and dist < shortestDistance then
				shortestDistance = dist
				nearestPart = part
			end
		end
	end

	return nearestPart
end

local currentTween
local function walkTo(targetCFrame)
	if currentTween then currentTween:Cancel() end

	local distance = (HumanoidRootPart.Position - targetCFrame.Position).Magnitude
	local travelTime = distance / moveSpeed

	local tweenInfo = TweenInfo.new(travelTime, Enum.EasingStyle.Linear)
	currentTween = TweenService:Create(HumanoidRootPart, tweenInfo, {
		CFrame = targetCFrame
	})
	currentTween:Play()
end

-- Circle around the target at 5 studs
local function circleAroundTarget(target)
	task.spawn(function()
		while autoMoveEnabled and target and target:FindFirstChild("Humanoid") and target.Humanoid.Health > 0 do
			local angle = tick() % 6.28
			local radius = 5
			local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			local goalPos = target.HumanoidRootPart.Position + offset
			local goalCFrame = CFrame.new(goalPos, target.HumanoidRootPart.Position)
			walkTo(goalCFrame)
			task.wait(0.05)
		end
	end)
end

-- Main loop
task.spawn(function()
	while true do
		if autoMoveEnabled then
			combatRange = baseCombatRange
			local mob = nil

			-- Try expanding range step-by-step
			while not mob and combatRange <= scanRadius do
				mob = getLowestHpMobInRange(combatRange)
				if not mob then
					combatRange += 100
				end
			end

			if mob then
				if mob ~= lastTarget then
					lastTarget = mob
					circleAroundTarget(mob)
				end
			else
				local touchPart = getNearestUntouchedTouchPart()
				if touchPart then
					touchedParts[touchPart] = true
					walkTo(touchPart.CFrame)
					task.wait(1.5)
				end
			end
		end
		task.wait(updateInterval)
	end
end)
