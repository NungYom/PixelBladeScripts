task.wait(5)
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

-- Settings
local moveSpeed = 20
local orbitRadius = 5
local autoMoveEnabled = true
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

-- Exclude by name only
local excludedNames = {
	["GoblinType1"] = true,
	["GoblinType2"] = true
}

local function isOnGround(part)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	raycastParams.FilterDescendantsInstances = {part.Parent}
	local ray = workspace:Raycast(part.Position, Vector3.new(0, -10, 0), raycastParams)
	return ray ~= nil
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
			and isOnGround(npc.HumanoidRootPart)
			and not visitedTargets[npc]
			and Players:GetPlayerFromCharacter(npc) == nil -- กรองไม่ให้เจอผู้เล่น
		then
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

local function walkTo(cframe)
	if currentTween then currentTween:Cancel() end

	local distance = (HumanoidRootPart.Position - cframe.Position).Magnitude
	local travelTime = distance / moveSpeed

	local tweenInfo = TweenInfo.new(travelTime, Enum.EasingStyle.Linear)
	currentTween = TweenService:Create(HumanoidRootPart, tweenInfo, {
		CFrame = cframe
	})
	currentTween:Play()
end

local function orbitTarget(target)
	local angle = 0
	local orbiting = true

	while orbiting and autoMoveEnabled and target and target:FindFirstChild("Humanoid") and target.Humanoid.Health > 0 do
		if not target:FindFirstChild("HumanoidRootPart") then break end

		local center = target.HumanoidRootPart.Position
		angle += math.rad(30)
		if angle >= math.pi * 2 then angle = angle - math.pi * 2 end

		local offsetX = math.cos(angle) * orbitRadius
		local offsetZ = math.sin(angle) * orbitRadius
		local orbitPosition = center + Vector3.new(offsetX, 0, offsetZ)
		local orbitCFrame = CFrame.new(orbitPosition, center)

		walkTo(orbitCFrame)
		task.wait(0.2)
	end
end

local function mainLoop()
	while true do
		if autoMoveEnabled then
			local targets = getAllTargetsSortedByDistance()
			local selected = targets[1]
			if selected then
				if selected.type == "mob" then
					if selected.object ~= lastTarget then
						lastTarget = selected.object
						orbitTarget(selected.object)
						visitedTargets[selected.object] = true
						lastTarget = nil
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
		task.wait(0.1)
	end
end

task.spawn(mainLoop)
