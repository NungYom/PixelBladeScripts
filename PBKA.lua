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
local autoMoveEnabled = false
local touchedParts = {}
local lastTarget = nil
local currentTween = nil

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
toggleButton.Text = "AutoFarm: OFF"
toggleButton.Parent = gui

toggleButton.MouseButton1Click:Connect(function()
	autoMoveEnabled = not autoMoveEnabled
	toggleButton.Text = "AutoFarm: " .. (autoMoveEnabled and "ON" or "OFF")
end)

-- Filter folders (excluded folders)
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

-- ตรวจสอบว่ามี Behavior/AI จริงๆไหม (แยก mob ที่ยืนเฉยๆ)
local function hasActiveBehavior(npc)
	-- วิธีเช็คที่ค่อนข้างทั่วๆไป เช่น มี Script ที่เปิดใช้งาน, มี AI Module, หรือมี HumanoidRootPart เคลื่อนไหวอยู่บ้าง
	-- เนื่องจากไม่มีข้อมูลชัดเจนของ Behavior ในเกมนี้ ผมจะเช็คอย่างคร่าวๆโดยดูว่า npc มี Script ที่ Enabled อยู่ในตัวหรือไม่
	for _, child in ipairs(npc:GetChildren()) do
		if child:IsA("Script") or child:IsA("LocalScript") or child:IsA("ModuleScript") then
			if child.Enabled then
				return true
			end
		end
	end
	-- หรือถ้า npc เดิน/เคลื่อนไหวบ้าง (ตรวจสอบ velocity HumanoidRootPart)
	local vel = npc:FindFirstChild("HumanoidRootPart") and npc.HumanoidRootPart.Velocity.Magnitude or 0
	if vel > 0.1 then
		return true
	end

	return false
end

-- ตรวจสอบว่าตัวละครตีได้จริงไหม (มี Humanoid, HP > 0, ไม่ใช่ excludedNames, อยู่บนพื้น)
local function isValidTarget(npc)
	if not npc or not npc:IsA("Model") then return false end
	local humanoid = npc:FindFirstChild("Humanoid")
	local hrp = npc:FindFirstChild("HumanoidRootPart")
	if not humanoid or not hrp then return false end
	if humanoid.Health <= 0 then return false end
	if excludedNames[npc.Name] then return false end
	if isInExcludedFolder(npc) then return false end
	if not isOnGround(hrp) then return false end
	if not hasActiveBehavior(npc) then return false end
	return true
end

local function getAllTargets()
	local worldSpawn = workspace:FindFirstChild("SpawnLocation") or Instance.new("Part")
	worldSpawn.Position = Vector3.new(0,0,0)

	local targetsWithBehaviorFar = {}
	local targetsWithBehaviorNear = {}
	local touchTargets = {}

	for _, npc in pairs(workspace:GetDescendants()) do
		if npc:IsA("Model") and npc ~= Character then
			if isValidTarget(npc) then
				-- แยกใกล้ไกลจาก world spawn ตาม velocity (หรือจะใช้ตำแหน่งอย่างเดียวก็ได้)
				-- ผมจะใช้ระยะจาก spawn เป็นหลัก แต่ต้องแยกให้ตามโจทย์
				-- หาก velocity สูงกว่า 0.1 คือ active behavior => far group
				local hrp = npc.HumanoidRootPart
				local dist = (worldSpawn.Position - hrp.Position).Magnitude
				if hasActiveBehavior(npc) then
					-- ถ้าอยู่ไกล spawn กว่าค่าเฉลี่ย + 50 studs ถือว่า far group
					-- แทนการหาค่าเฉลี่ย จะใช้ค่าเกณฑ์ 150 studs (ปรับได้)
					if dist > 150 then
						table.insert(targetsWithBehaviorFar, {npc = npc, dist = dist})
					else
						table.insert(targetsWithBehaviorNear, {npc = npc, dist = dist})
					end
				end
			end
		end
	end

	-- เก็บ touch ส่วนที่ยังไม่โดน
	for _, part in pairs(workspace:GetDescendants()) do
		if part:IsA("BasePart") and part.Name:lower() == "touch" and not touchedParts[part] then
			local dist = (worldSpawn.Position - part.Position).Magnitude
			table.insert(touchTargets, {part = part, dist = dist})
		end
	end

	-- จัดเรียงแต่ละกลุ่มตามระยะจาก spawn
	table.sort(targetsWithBehaviorFar, function(a,b) return a.dist > b.dist end) -- far: มากไปน้อย (ไกลไปใกล้)
	table.sort(targetsWithBehaviorNear, function(a,b) return a.dist < b.dist end) -- near: น้อยไปมาก (ใกล้ไปไกล)
	table.sort(touchTargets, function(a,b) return a.dist < b.dist end) -- touch: ใกล้ไปไกล

	return targetsWithBehaviorFar, targetsWithBehaviorNear, touchTargets
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

-- Move near target at 4 studs
local function moveToTarget(targetModel)
	task.spawn(function()
		while autoMoveEnabled and targetModel and targetModel:FindFirstChild("Humanoid") and targetModel.Humanoid.Health > 0 do
			local hrp = targetModel:FindFirstChild("HumanoidRootPart")
			if not hrp then break end
			local direction = (HumanoidRootPart.Position - hrp.Position)
			if direction.Magnitude < 4 then break end
			local offset = direction.Unit * 4
			local goalPos = hrp.Position + offset
			local goalCFrame = CFrame.new(goalPos, hrp.Position)
			walkTo(goalCFrame)
			task.wait(0.05)
		end
	end)
end

-- Main loop
task.spawn(function()
	while true do
		if autoMoveEnabled then
			local far, near, touchs = getAllTargets()
			local target = nil

			-- เลือกเป้าหมายตามลำดับ priority
			if #far > 0 then
				target = far[1].npc
			elseif #near > 0 then
				target = near[1].npc
			elseif #touchs > 0 then
				target = touchs[1].part
			end

			if target then
				if typeof(target) == "Instance" and target:IsA("BasePart") then
					-- เป็น touch
					touchedParts[target] = true
					walkTo(target.CFrame)
					task.wait(3)
					lastTarget = nil
				elseif target:IsA("Model") then
					-- เป็น mob
					if target ~= lastTarget then
						lastTarget = target
						moveToTarget(target)
					end
				end
			end
		end
		task.wait(0.05)
	end
end)
