local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

-- Settings
local moveSpeed = 100
local scanRadius = 1500
local combatRange = 400
local updateInterval = 0.05
local autoMoveEnabled = false
local touchedParts = {}
local lastTarget = nil

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "AutoMoveGUI"
gui.Parent = PlayerGui

local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0, 200, 0, 50)
toggleButton.Position = UDim2.new(0, 20, 0, 20)
toggleButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.Font = Enum.Font.GothamBold
toggleButton.TextSize = 20
toggleButton.Text = "AutoMove: OFF"
toggleButton.Parent = gui

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
			and isOnGround(npc.HumanoidRootPart) then

			local dist = (HumanoidRootPart.Position - npc.HumanoidRootPart.Position).Magnitude
			if dist < maxDistance and dist < shortestDistance then
				shortestDistance = dist
				nearestMob = npc
			end
		end
	end

	return nearestMob
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

-- Circle around the target at 20 studs smoothly
local circleThread
local function circleAroundTarget(target)
	if circleThread then
		circleThread:Disconnect()
		circleThread = nil
	end

	circleThread = RunService.Heartbeat:Connect(function()
		if not autoMoveEnabled or not target or not target:FindFirstChild("Humanoid") or target.Humanoid.Health <= 0 then
			circleThread:Disconnect()
			circleThread = nil
			return
		end

		local angle = tick() % (2 * math.pi)
		local radius = 20
		local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local goalPos = target.HumanoidRootPart.Position + offset
		local goalCFrame = CFrame.new(goalPos, target.HumanoidRootPart.Position)
		walkTo(goalCFrame)
	end)
end

-- Fire plrUpgrade event every 1 second while autoMoveEnabled
local upgradeThread
local function startAutoUpgrade()
	if upgradeThread then return end
	upgradeThread = task.spawn(function()
		while autoMoveEnabled do
			local success, err = pcall(function()
				local args = {3}
				ReplicatedStorage:WaitForChild("remotes"):WaitForChild("plrUpgrade"):FireServer(unpack(args))
			end)
			if not success then
				warn("Failed to fire plrUpgrade: "..tostring(err))
			end
			task.wait(1)
		end
		upgradeThread = nil
	end)
end

local function stopAutoUpgrade()
	if upgradeThread then
		upgradeThread = nil -- just flag to nil, the loop will stop naturally
	end
end

-- Toggle button click handler
toggleButton.MouseButton1Click:Connect(function()
	autoMoveEnabled = not autoMoveEnabled
	toggleButton.Text = "AutoMove: " .. (autoMoveEnabled and "ON" or "OFF")

	if autoMoveEnabled then
		startAutoUpgrade()
	else
		stopAutoUpgrade()
		if circleThread then
			circleThread:Disconnect()
			circleThread = nil
		end
		if currentTween then
			currentTween:Cancel()
			currentTween = nil
		end
	end
end)

-- Main loop for moving and targeting mobs or touch parts
task.spawn(function()
	while true do
		if autoMoveEnabled then
			local mob = getNearestMobInRange(combatRange)
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
