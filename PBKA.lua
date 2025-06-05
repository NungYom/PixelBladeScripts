local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")

-- ตั้งค่า
local moveSpeed = 100
local scanRadius = 1500
local combatRange = 400
local updateInterval = 0.1
local autoMoveEnabled = false
local orbiting = false
local orbitRadius = 4
local orbitConnection
local isHealing = false -- สถานะฟื้นฟูเลือด
local targetTimeout = 3 -- วินาทีที่ให้ตามเป้าหมายเดิมก่อนเปลี่ยน

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

-- noclip setup
local noclipConnection

local function setNoclip(enabled)
	if enabled then
		if noclipConnection then return end -- ถ้ามีแล้วไม่ต้องทำซ้ำ
		noclipConnection = RunService.Stepped:Connect(function()
			if Character and Character.Parent then
				for _, part in pairs(Character:GetChildren()) do
					if part:IsA("BasePart") and part.CanCollide == true then
						part.CanCollide = false
					end
				end
			end
		end)
	else
		if noclipConnection then
			noclipConnection:Disconnect()
			noclipConnection = nil
		end
		-- เปิดการชนให้ปกติเมื่อปิด noclip
		if Character and Character.Parent then
			for _, part in pairs(Character:GetChildren()) do
				if part:IsA("BasePart") then
					part.CanCollide = true
				end
			end
		end
	end
end

toggleButton.MouseButton1Click:Connect(function()
	autoMoveEnabled = not autoMoveEnabled
	toggleButton.Text = "AutoMove: " .. (autoMoveEnabled and "ON" or "OFF")
	setNoclip(autoMoveEnabled)
end)

-- โฟลเดอร์ใน GoblinArena ที่ต้องกรอง
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

-- ฟังก์ชันตรวจสอบว่า NPC อยู่ในโฟลเดอร์ที่ต้องกรองหรือไม่
local function isInExcludedFolder(npc)
	for _, folder in ipairs(excludeFolders) do
		if folder and npc:IsDescendantOf(folder) then
			return true
		end
	end
	return false
end

-- หา mob ที่ใกล้ที่สุด (เฉพาะ mob ที่ไม่ใช่ผู้เล่น)
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
			and not isInExcludedFolder(npc) then

			-- ไม่ใช่ผู้เล่นอื่น
			local isPlayerModel = Players:GetPlayerFromCharacter(npc) ~= nil
			if not isPlayerModel then
				local dist = (HumanoidRootPart.Position - npc.HumanoidRootPart.Position).Magnitude
				if dist < maxDistance and dist < shortestDistance then
					shortestDistance = dist
					nearestMob = npc
				end
			end
		end
	end

	return nearestMob
end

-- เก็บ touch parts ที่เคยไปแล้ว
local touchedParts = {}

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

-- ตัวแปร tween ปัจจุบัน
local currentTween

-- ฟังก์ชันเดินไปหาเป้าหมายโดยเว้นระยะ 4 studs
local function walkTo(targetCFrame)
	if currentTween then currentTween:Cancel() end

	local targetPos = targetCFrame.Position
	local direction = (HumanoidRootPart.Position - targetPos).Unit
	local offsetPos = targetPos + direction * 4 -- เว้นระยะ 4 studs ออกมา

	local distance = (HumanoidRootPart.Position - offsetPos).Magnitude
	local travelTime = distance / moveSpeed

	local tweenInfo = TweenInfo.new(travelTime, Enum.EasingStyle.Linear)
	local tween = TweenService:Create(HumanoidRootPart, tweenInfo, {
		CFrame = CFrame.new(offsetPos.X, offsetPos.Y, offsetPos.Z)
	})
	currentTween = tween
	tween:Play()
end

-- ฟังก์ชันให้ตัวละครเคลื่อนที่เป็นวงกลมรอบ mob รัศมี 4 studs
local function orbitAround(target)
	if orbiting or not target or isHealing then return end
	orbiting = true

	local angle = 0
	orbitConnection = RunService.RenderStepped:Connect(function(dt)
		if not autoMoveEnabled or not target or not target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("Humanoid").Health <= 0 or isHealing then
			orbiting = false
			if orbitConnection then orbitConnection:Disconnect() end
			return
		end

		angle = angle + dt * 2 -- ความเร็วในการหมุน
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * orbitRadius
		local targetPos = target.HumanoidRootPart.Position + offset
		Humanoid:MoveTo(targetPos)
	end)
end

-- ตรวจจับ HP ต่ำกว่า 20% แล้วเทเลพอร์ตลง void เพื่อฟื้นฟูเลือด
task.spawn(function()
	while true do
		if autoMoveEnabled and not isHealing and Humanoid.Health > 0 then
			if Humanoid.Health / Humanoid.MaxHealth < 0.2 then
				isHealing = true

				-- ยกเลิก tween และวงโคจร
				if currentTween then currentTween:Cancel() end
				if orbitConnection then orbitConnection:Disconnect() end
				orbiting = false

				local currentPos = HumanoidRootPart.Position
				local targetPos = Vector3.new(currentPos.X, currentPos.Y - 1000, currentPos.Z)

				-- เทเลพอร์ตลง void
				HumanoidRootPart.CFrame = CFrame.new(targetPos)

				-- รอเลือดฟื้น (เกมฟื้นเลือดเอง)
				task.wait(3)

				isHealing = false
			end
		end
		task.wait(0.25)
	end
end)

-- ลูปหลักควบคุมการเดินหา mob และ touch parts
task.spawn(function()
	local currentTarget = nil
	local targetStartTime = 0
	while true do
		if autoMoveEnabled and not isHealing then
			local mob = nil

			if currentTarget and currentTarget:FindFirstChild("Humanoid") and currentTarget.Humanoid.Health > 0 then
				-- ถ้าเป้าหมายเดิมยังมีชีวิตอยู่และไม่ timeout
				if os.clock() - targetStartTime < targetTimeout then
					mob = currentTarget
				else
					currentTarget = nil
				end
			end

			if not mob then
				mob = getNearestMobInRange(combatRange)
				currentTarget = mob
				targetStartTime = mob and os.clock() or 0
			end

			if mob then
				orbitAround(mob)
				task.wait(0.1)
			else
				-- หาตำแหน่ง touch part ที่ยังไม่เคยไป
				local touchPart = getNearestUntouchedTouchPart()
				if touchPart then
					touchedParts[touchPart] = true
					walkTo(touchPart.CFrame)
					task.wait(1)
				end
			end
		end
		task.wait(updateInterval)
	end
end)
