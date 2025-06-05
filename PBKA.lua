local Players = game:GetService("Players")
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
local updateInterval = 0.1 -- ลดความถี่ลงเพื่อประหยัด CPU
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
toggleButton.Text = "AutoFarm: OFF"
toggleButton.Parent = gui

toggleButton.MouseButton1Click:Connect(function()
	autoMoveEnabled = not autoMoveEnabled
	toggleButton.Text = "AutoFarm: " .. (autoMoveEnabled and "ON" or "OFF")
	if not autoMoveEnabled then
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

local lastGroundCheckPos = nil
local lastGroundCheckResult = true
local function isOnGround(part)
	-- เช็คพื้นแบบ cache ถ้าตำแหน่งไม่ขยับมากจะไม่ raycast ซ้ำ
	if lastGroundCheckPos and (part.Position - lastGroundCheckPos).Magnitude < 2 then
		return lastGroundCheckResult
	end
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	raycastParams.FilterDescendantsInstances = {part.Parent}
	local ray = workspace:Raycast(part.Position, Vector3.new(0, -10, 0), raycastParams)
	lastGroundCheckPos = part.Position
	lastGroundCheckResult = ray ~= nil
	return lastGroundCheckResult
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

-- เคลื่อนที่แบบ Lerp (นิ่มกว่า Tween)
local function walkTo(targetCFrame)
	local startPos = HumanoidRootPart.Position
	local goalPos = targetCFrame.Position
	local distance = (goalPos - startPos).Magnitude
	local duration = distance / moveSpeed
	local elapsed = 0
	local step = updateInterval

	while elapsed < duration and autoMoveEnabled do
		local alpha = elapsed / duration
		local newPos = startPos:Lerp(goalPos, alpha)
		HumanoidRootPart.CFrame = CFrame.new(newPos, goalPos) -- หันหน้าไปยังเป้าหมาย
		task.wait(step)
		elapsed = elapsed + step
	end

	-- ตั้งตำแหน่งสุดท้ายให้ตรงเป๊ะ
	if autoMoveEnabled then
		HumanoidRootPart.CFrame = CFrame.new(goalPos, goalPos)
	end
end

-- ป้องกัน circleAroundTarget ซ้อนกัน
local isCircling = false

local function circleAroundTarget(target)
	if isCircling then return end
	isCircling = true
	Humanoid.AutoRotate = false

	while autoMoveEnabled and target and target:FindFirstChild("Humanoid") and target.Humanoid.Health > 0 do
		local touchPart = getNearestUntouchedTouchPart()
		if touchPart then
			touchedParts[touchPart] = true
			walkTo(touchPart.CFrame)
			task.wait(3)
			lastTarget = nil
			break
		end

		local angle = tick() % (2 * math.pi)
		local radius = 5
		local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local goalPos = target.HumanoidRootPart.Position + offset

		local currentPos = HumanoidRootPart.Position
		local newPos = currentPos:Lerp(goalPos, 0.2)
		HumanoidRootPart.CFrame = CFrame.new(newPos, target.HumanoidRootPart.Position)

		task.wait(0.05)
	end

	Humanoid.AutoRotate = true
	isCircling = false
end

-- ล็อกกล้องแค่ตอนเปิด AutoMove
local cameraLocked = false
RunService.RenderStepped:Connect(function()
	if autoMoveEnabled and not cameraLocked then
		Camera.CameraSubject = Humanoid
		Camera.CameraType = Enum.CameraType.Custom
		cameraLocked = true
	elseif not autoMoveEnabled and cameraLocked then
		cameraLocked = false
	end
end)

-- Main loop
task.spawn(function()
	while true do
		if autoMoveEnabled then
			local touchPart = getNearestUntouchedTouchPart()
			if touchPart then
				touchedParts[touchPart] = true
				walkTo(touchPart.CFrame)
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
