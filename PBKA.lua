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

-- RemoteEvent สมมติ ชื่อ UseSkill (กดปุ่ม E)
local useSkillRemote = ReplicatedStorage:WaitForChild("remotes"):WaitForChild("UseSkill")

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

local autoMoveTask = nil
local skillTask = nil

toggleButton.MouseButton1Click:Connect(function()
	autoMoveEnabled = not autoMoveEnabled
	toggleButton.Text = "AutoMove: " .. (autoMoveEnabled and "ON" or "OFF")

	if autoMoveEnabled then
		-- เริ่มฟังก์ชัน auto move
		autoMoveTask = task.spawn(function()
			while autoMoveEnabled do
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
				task.wait(updateInterval)
			end
		end)

		-- เริ่มกดปุ่ม E อัตโนมัติ ทุก 1 วินาที
		skillTask = task.spawn(function()
			while autoMoveEnabled do
				pcall(function()
					useSkillRemote:FireServer()
				end)
				task.wait(1)
			end
		end)

	else
		-- หยุดทั้งสองงาน
		if autoMoveTask then
			autoMoveTask:Cancel()
			autoMoveTask = nil
		end
		if skillTask then
			skillTask:Cancel()
			skillTask = nil
		end
		lastTarget = nil
	end
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

-- Circle around the target at 20 studs
local function circleAroundTarget(target)
	task.spawn(function()
		while autoMoveEnabled and target and target:FindFirstChild("Humanoid") and target.Humanoid.Health > 0 do
			local angle = tick() % 6.28
			local radius = 20
			local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			local goalPos = target.HumanoidRootPart.Position + offset
			local goalCFrame = CFrame.new(goalPos, target.HumanoidRootPart.Position)
			walkTo(goalCFrame)
			task.wait(0.05)
		end
	end)
end
