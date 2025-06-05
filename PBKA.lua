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
local updateInterval = 0.05
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

local function hasDescendantAI(npc)
	for _, descendant in ipairs(npc:GetDescendants()) do
		if descendant:IsA("Script") or descendant:IsA("ModuleScript") then
			return true
		end
	end
	return false
end

local function hasActiveAnimations(humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, animTrack in ipairs(animator:GetPlayingAnimationTracks()) do
			if animTrack.IsPlaying then
				return true
			end
		end
	end
	return false
end

local function hasBodyMovers(npc)
	for _, descendant in ipairs(npc:GetDescendants()) do
		if descendant:IsA("BodyPosition")
			or descendant:IsA("BodyVelocity")
			or descendant:IsA("BodyGyro")
			or descendant:IsA("BodyAngularVelocity")
			or descendant:IsA("BodyForce")
			or descendant:IsA("BodyThrust") then
			return true
		end
	end
	return false
end

local function isRealMob(npc)
	local hrp = npc:FindFirstChild("HumanoidRootPart")
	local humanoid = npc:FindFirstChild("Humanoid")
	if not hrp or not humanoid then return false end
	
	if humanoid.Health <= 0 then return false end
	
	if isInExcludedFolder(npc) then return false end
	if excludedNames[npc.Name] then return false end
	if not isOnGround(hrp) then return false end
	
	-- ต้องมี AI Script ในลูกหลาน หรือ
	-- มี Animator พร้อมเล่นแอนิเมชัน หรือ
	-- มี BodyMover ควบคุมการเคลื่อนที่ หรือ
	-- เดินได้ (WalkSpeed > 0) หรือ
	-- ขยับอยู่ (Velocity > 0.1)
	
	if hasDescendantAI(npc) then
		return true
	end
	
	if hasActiveAnimations(humanoid) then
		return true
	end
	
	if hasBodyMovers(npc) then
		return true
	end
	
	if humanoid.WalkSpeed > 0 then
		return true
	end
	
	if hrp.Velocity.Magnitude > 0.1 then
		return true
	end
	
	-- ถ้าไม่มีอะไรเลย ถือว่าไม่ใช่มอนที่พร้อมตี
	return false
end

local function getAllNearbyTargets()
	local realMobs = {}
	local fakeMobs = {}
	local touches = {}

	local worldSpawn = workspace:FindFirstChild("SpawnLocation")
	if not worldSpawn then
		worldSpawn = Instance.new("Part")
		worldSpawn.Position = Vector3.new(0, 0, 0)
	end
	local spawnPos = worldSpawn.Position

	for _, npc in pairs(workspace:GetDescendants()) do
		if npc:IsA("Model")
			and npc ~= Character
			and npc:FindFirstChild("Humanoid")
			and npc:FindFirstChild("HumanoidRootPart")
			and npc.Humanoid.Health > 0 then

			local dist = (spawnPos - npc.HumanoidRootPart.Position).Magnitude
			if true then -- ลบระยะขอบเขตออกทั้งหมด
				if isRealMob(npc) then
					table.insert(realMobs, {type = "realmob", object = npc, distance = dist})
				else
					table.insert(fakeMobs, {type = "fakemob", object = npc, distance = dist})
				end
			end
		end
	end

	for _, part in pairs(workspace:GetDescendants()) do
		if part:IsA("BasePart")
			and part.Name:lower() == "touch"
			and not touchedParts[part] then

			local dist = (spawnPos - part.Position).Magnitude
			if true then -- ลบระยะขอบเขตออกทั้งหมด
				table.insert(touches, {type = "touch", object = part, distance = dist})
			end
		end
	end

	-- 1. มอนที่มี behavior (realMobs) เรียงจากไกล → ใกล้
	table.sort(realMobs, function(a, b)
		return a.distance > b.distance -- มากไปน้อย
	end)

	-- 2. มอนที่ไม่มี behavior (fakeMobs) เรียงจากใกล้ → ไกล
	table.sort(fakeMobs, function(a, b)
		return a.distance < b.distance -- น้อยไปมาก
	end)

	-- 3. touch เรียงจากใกล้ → ไกล
	table.sort(touches, function(a, b)
		return a.distance < b.distance
	end)

	-- รวมลิสต์ตามลำดับที่ต้องการ
	local combined = {}
	for _, v in ipairs(realMobs) do table.insert(combined, v) end
	for _, v in ipairs(fakeMobs) do table.insert(combined, v) end
	for _, v in ipairs(touches) do table.insert(combined, v) end

	return combined
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
	task.spawn(function()
		while autoMoveEnabled and target and target:FindFirstChild("Humanoid") and target.Humanoid.Health > 0 do
			local offset = (HumanoidRootPart.Position - target.HumanoidRootPart.Position).Unit * 4
			local goalPos = target.HumanoidRootPart.Position + offset
			local goalCFrame = CFrame
