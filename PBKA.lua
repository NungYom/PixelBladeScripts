local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

-- Settings
local moveSpeed = 100
local autoMoveEnabled = false
local touchedParts = {}
local visitedTargets = {}
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

local function isPlayerCharacter(model)
	if not model or not model:IsA("Model") then return false end
	if not model:FindFirstChild("HumanoidRootPart") then return false end

	local player = Players:GetPlayerFromCharacter(model)
	if player then
		return true
	end

	for _, p in pairs(Players:GetPlayers()) do
		if model.Name == p.Name then
			return true
		end
	end

	local root = model:FindFirstChild("HumanoidRootPart")
	if root then
		local rootParent = root.Parent
		if rootParent and Players:GetPlayerFromCharacter(rootParent) then
			return true
		end
	end

	for _, child in pairs(model:GetChildren()) do
		if child:IsA("Tool") then
			local toolParent = child.Parent
			if toolParent and Players:GetPlayerFromCharacter(toolParent) then
				return true
			end
		end
	end

	if model:GetAttribute("IsPlayerCharacter") == true then
		return true
	end

	local boolVal = model:FindFirstChild("IsPlayerCharacter")
	if boolVal and boolVal:IsA("BoolValue") and boolVal.Value == true then
		return true
	end

	if CollectionService:HasTag(model, "Player") then
		return true
	end

	return false
end

local function getAllTargetsSortedByDistance()
	local targets = {}

	for _, npc in pairs(workspace:GetDescendants()) do
		if npc:IsA("Model")
			and npc ~= Character
			and npc:FindFirstChild("Humanoid")
			and npc:FindFirstChild("HumanoidRootPart")
			and npc.Humanoid.Health > 0
			and not excludedNames[npc.Name]
			and not isInExcludedFolder(npc)
			and isOnGround(npc.HumanoidRootPart)
			and not visitedTargets[npc]
			and not isPlayerCharacter(npc) then

			table.insert(targets, {
				type = "mob",
				object = npc,
				distance = (HumanoidRootPart.Position - npc.HumanoidRootPart.Position).Magnitude
			})
		end
	end

	for _, part in pairs(workspace:GetDescendants()) do
		if part:IsA("BasePart")
			and part.Name:lower() == "touch"
			and not touchedParts[part]
			and not visitedTargets[part] then

			table.insert(targets, {
				type = "touch",
				object = part,
				distance = (HumanoidRootPart.Position - part.Position).Magnitude
			})
		end
	end

	table.sort(targets, function(a, b)
		return a.distance < b.distance
	end)

	return targets
end

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

local function moveToTarget(target)
	if not target or not target:FindFirstChild("Humanoid") or target.Humanoid.Health <= 0 then return end

	while target.Humanoid.Health > 0 and autoMoveEnabled do
		local offset = (HumanoidRootPart.Position - target.HumanoidRootPart.Position).Unit * 4
		local goalPos = target.HumanoidRootPart.Position + offset
		local goalCFrame = CFrame.new(goalPos, target.HumanoidRootPart.Position)

		walkTo(goalCFrame)

		-- รอจนถึงระยะใกล้พอ หรือเป้าหมายตาย หรือปิด autoMove
		local reached = false
		while not reached and target.Humanoid.Health > 0 and autoMoveEnabled do
			local distance = (HumanoidRootPart.Position - goalPos).Magnitude
			if distance <= 5 then
				reached = true
			end
			task.wait(0.3)
		end
	end
end

-- Main loop
local function mainLoop()
	while true do
		if autoMoveEnabled then
			local targets = getAllTargetsSortedByDistance()
			local selected = targets[1]
			if selected then
				if selected.type == "mob" then
					if selected.object ~= lastTarget and selected.object:FindFirstChild("Humanoid") then
						lastTarget = selected.object
						moveToTarget(selected.object)
						repeat
							task.wait(0.2)
						until selected.object.Humanoid.Health <= 0 or not autoMoveEnabled
						visitedTargets[selected.object] = true
					end
				elseif selected.type == "touch" then
					lastTarget = selected.object
					walkTo(selected.object.CFrame)
					task.wait(3)
					touchedParts[selected.object] = true
					visitedTargets[selected.object] = true
					lastTarget = nil
				end
			end
		end
		task.wait(0.5)
	end
end

task.spawn(mainLoop)
