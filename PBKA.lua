local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

-- Settings
local moveSpeed = 100
local autoMoveEnabled = false
local touchedParts = {}
local lastTarget = nil
local currentTween = nil

-- GUI Setup
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
toggleButton.Text = "AutoFarm: OFF"
toggleButton.Parent = gui

toggleButton.MouseButton1Click:Connect(function()
	autoMoveEnabled = not autoMoveEnabled
	toggleButton.Text = "AutoFarm: " .. (autoMoveEnabled and "ON" or "OFF")
	if not autoMoveEnabled and currentTween then
		currentTween:Cancel()
		currentTween = nil
		lastTarget = nil
	end
end)

-- Exclude folders and names
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
	-- Raycast only once per call for efficiency
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	raycastParams.FilterDescendantsInstances = {part.Parent}
	local ray = workspace:Raycast(part.Position, Vector3.new(0, -10, 0), raycastParams)
	return ray ~= nil
end

local function isValidMob(npc)
	if not npc or not npc:IsA("Model") then return false end
	local humanoid = npc:FindFirstChild("Humanoid")
	local hrp = npc:FindFirstChild("HumanoidRootPart")
	if not humanoid or not hrp then return false end
	if humanoid.Health <= 0 then return false end
	if excludedNames[npc.Name] then return false end
	if isInExcludedFolder(npc) then return false end
	if not isOnGround(hrp) then return false end
	return true
end

local function getAllTargets()
	local worldSpawn = workspace:FindFirstChild("SpawnLocation") or Instance.new("Part")
	worldSpawn.Position = Vector3.new(0,0,0)

	local targets = {}

	-- Cache workspace descendants once
	local descendants = workspace:GetDescendants()

	for i = 1, #descendants do
		local obj = descendants[i]

		if obj:IsA("Model") and obj ~= Character then
			if isValidMob(obj) then
				local hrp = obj:FindFirstChild("HumanoidRootPart")
				if hrp then
					table.insert(targets, {
						type = "mob",
						object = obj,
						distance = (worldSpawn.Position - hrp.Position).Magnitude
					})
				end
			end
		elseif obj:IsA("BasePart") and obj.Name:lower() == "touch" and not touchedParts[obj] then
			table.insert(targets, {
				type = "touch",
				object = obj,
				distance = (worldSpawn.Position - obj.Position).Magnitude
			})
		end
	end

	table.sort(targets, function(a, b)
		return a.distance < b.distance
	end)

	return targets
end

local function walkTo(targetCFrame)
	if currentTween then
		currentTween:Cancel()
		currentTween = nil
	end

	local distance = (HumanoidRootPart.Position - targetCFrame.Position).Magnitude
	if distance < 0.1 then return end -- Skip if too close

	local travelTime = distance / moveSpeed
	if travelTime <= 0 then return end

	local tweenInfo = TweenInfo.new(travelTime, Enum.EasingStyle.Linear)
	currentTween = TweenService:Create(HumanoidRootPart, tweenInfo, {CFrame = targetCFrame})
	currentTween:Play()
end

local movingToTarget = false

local function moveToTarget(targetModel)
	if movingToTarget then return end
	movingToTarget = true

	while autoMoveEnabled and targetModel and targetModel:FindFirstChild("Humanoid") and targetModel.Humanoid.Health > 0 do
		local hrp = targetModel:FindFirstChild("HumanoidRootPart")
		if not hrp then break end
		local direction = (HumanoidRootPart.Position - hrp.Position)
		if direction.Magnitude <= 4 then break end
		local offset = direction.Unit * 4
		local goalPos = hrp.Position + offset
		local goalCFrame = CFrame.new(goalPos, hrp.Position)
		walkTo(goalCFrame)
		task.wait(0.1)
	end

	movingToTarget = false
end

-- Main loop optimized with RunService.Heartbeat for smooth updates
RunService.Heartbeat:Connect(function(deltaTime)
	if autoMoveEnabled then
		local targets = getAllTargets()
		local selected = targets[1]

		if selected then
			if selected.type == "mob" then
				if selected.object ~= lastTarget then
					lastTarget = selected.object
					moveToTarget(selected.object)
				end
			elseif selected.type == "touch" then
				touchedParts[selected.object] = true
				if currentTween then
					currentTween:Cancel()
					currentTween = nil
				end
				walkTo(selected.object.CFrame)
				task.wait(3)
				lastTarget = nil
			end
		end
	else
		if currentTween then
			currentTween:Cancel()
			currentTween = nil
		end
		lastTarget = nil
	end
end)
