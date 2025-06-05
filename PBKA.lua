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
local orbitRadius = 4

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
	if autoMoveEnabled then
		setNoclip(true)
	else
		setNoclip(false)
	end
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

-- ฟังก์ชันตรวจสอบว่า NPC อยู่ในโฟลเดอร์ที่ต้องกรองหรือไม่
local function isInExcludedFolder(npc)
	for _, folder in ipairs(excludeFolders) do
		if folder and npc:IsDescendantOf(folder) then
			return true
		end
	end
	return false
end

-- รายชื่อ NPC ที่ไม่ต้องไล่ตาม (ผู้เล่น)
local excludedNames = {
	["GoblinType1"] = true,
	["GoblinType2"] = true
}

local function isPlayerModel(model)
	if not model then return false end
	if model:FindFirstChildOfClass("Humanoid") and model:FindFirstChild("HumanoidRootPart") then
		for _, player in pairs(Players:GetPlayers()) do
			if player.Character == model then
				return true
			end
		end
	end
	return false
end

-- ฟังก์ชันหา mob ที่ใกล้ที่สุดภายในระยะที่กำหนด (ไม่ใช่ผู้เล่น)
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
			and not isPlayerModel(npc) then

			local dist = (HumanoidRootPart.Position - npc.HumanoidRootPart.Position).Magnitude
			if dist < maxDistance and dist < shortestDistance then
				shortestDistance = dist
				nearestMob = npc
			end
		end
	end

	return nearestMob
end

-- จำแคมป์ไฟที่เคยสัมผัสแล้ว
local touchedParts = {}

-- หา touch part ที่ยังไม่เคยไป
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

-- Tween ไปหา (ห่างเป้าหมาย 2 studs)
local currentTween

local function walkTo(targetCFrame)
	if currentTween then currentTween:Cancel() end

	local offsetCFrame = targetCFrame * CFrame.new(0, 0, -2)
	local distance = (HumanoidRootPart.Position - offsetCFrame.Position).Magnitude
	local travelTime = distance / moveSpeed

	local tweenInfo = TweenInfo.new(travelTime, Enum.EasingStyle.Linear)
	local tween = TweenService:Create(HumanoidRootPart, tweenInfo, {
		CFrame = offsetCFrame
	})
	currentTween = tween
	tween:Play()
end

-- Noclip
local noclipConnection
local function setNoclip(enable)
	if noclipConnection then
		noclipConnection:Disconnect()
		noclipConnection = nil
	end

	if enable then
		noclipConnection = RunService.Stepped:Connect(function()
			for _, part in pairs(Character:GetChildren()) do
				if part:IsA("BasePart") then
					part.CanCollide = false
				end
			end
		end)
	else
		for _, part in pairs(Character:GetChildren()) do
			if part:IsA("BasePart") then
				part.CanCollide = true
			end
		end
	end
end

-- Orbit รอบ mob ด้วย TweenService เร็วและลื่นกว่า
local orbiting = false
local orbitTween

local function orbitAround(target)
	if orbiting or not target or not target:FindFirstChild("HumanoidRootPart") then return end
	if target.Humanoid.Health <= 0 then return end

	orbiting = true

	if orbitTween then
		orbitTween:Disconnect()
		orbitTween = nil
	end

	local angle = 0

	orbitTween = RunService.RenderStepped:Connect(function(dt)
		if not autoMoveEnabled
			or not target
			or not target:FindFirstChild("HumanoidRootPart")
			or target.Humanoid.Health <= 0 then
			orbiting = false
			if orbitTween then
				orbitTween:Disconnect()
				orbitTween = nil
			end
			return
		end

		angle = angle + dt * 5 -- ความเร็วการหมุน ปรับได้
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * orbitRadius
		local targetPos = target.HumanoidRootPart.Position + offset

		if currentTween then currentTween:Cancel() end
		local distance = (HumanoidRootPart.Position - targetPos).Magnitude
		local travelTime = distance / moveSpeed

		local tweenInfo = TweenInfo.new(travelTime, Enum.EasingStyle.Linear)
		local tween = TweenService:Create(HumanoidRootPart, tweenInfo, {
			CFrame = CFrame.new(targetPos.X, targetPos.Y, targetPos.Z)
		})
		currentTween = tween
		tween:Play()
	end)
end

-- Teleport ลง void เมื่อตัวละคร hp ต่ำกว่า 20%
local isHealing = false
local function checkHPAndTeleportVoid()
	if Humanoid.Health / Humanoid.MaxHealth < 0.2 then
		isHealing = true
		if currentTween then currentTween:Cancel() end
		if orbitTween then
			orbitTween:Disconnect()
			orbitTween = nil
		end

		local currentPos = HumanoidRootPart.Position
		local voidPos = Vector3.new(currentPos.X, currentPos.Y - 1000, currentPos.Z)
		-- เทเลพอร์ตไป void
		Character:SetPrimaryPartCFrame(CFrame.new(voidPos))
		task.wait(0.5) -- รอให้เลือดฟื้น
		isHealing = false
	end
end

-- ระบบเปลี่ยนเป้าหมายถ้าตามเกิน 3 วิ
local currentTarget = nil
local targetStartTime = 0
local targetTimeout = 3

-- ลูปหลัก
task.spawn(function()
	while true do
		if autoMoveEnabled and not isHealing then
			checkHPAndTeleportVoid()

			-- หา mob ตัวใหม่หาก timeout หรือไม่มีเป้าหมาย
			local mob = nil

			if currentTarget and currentTarget.Humanoid and currentTarget.Humanoid.Health > 0 then
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
		else
			task.wait(0.1)
		end
		task.wait(updateInterval)
	end
end)
