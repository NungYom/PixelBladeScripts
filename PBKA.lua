local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

-- ตั้งค่า
local moveSpeed = 100
local scanRadius = 1500
local combatRange = 400
local updateInterval = 0.75
local autoMoveEnabled = false
local isHealing = false
local orbiting = false

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

-- รายชื่อ NPC ที่ไม่ต้องไล่ตาม
local excludedNames = {
	["GoblinType1"] = true,
	["GoblinType2"] = true
}

-- หา mob ที่ใกล้ที่สุด
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
			and not Players:GetPlayerFromCharacter(npc) then

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

-- Tween ไปหาเป้าหมาย (ห่าง 2 studs)
local currentTween

local function walkToOffset(targetCFrame, distance)
	if currentTween then currentTween:Cancel() end

	local dir = (targetCFrame.Position - HumanoidRootPart.Position).Unit
	local targetPos = targetCFrame.Position - dir * distance
	local travelTime = (HumanoidRootPart.Position - targetPos).Magnitude / moveSpeed

	local tweenInfo = TweenInfo.new(travelTime, Enum.EasingStyle.Linear)
	currentTween = TweenService:Create(HumanoidRootPart, tweenInfo, {
		CFrame = CFrame.new(targetPos)
	})
	currentTween:Play()
end

-- เดินวนรอบมอน
local orbitConnection

local function startOrbit(target)
	if orbiting or not target or not target:FindFirstChild("HumanoidRootPart") then return end
	orbiting = true
	local radius = 4
	local angle = 0

	orbitConnection = RunService.RenderStepped:Connect(function(dt)
		if not autoMoveEnabled or not target or not target:FindFirstChild("Humanoid") or target.Humanoid.Health <= 0 then
			orbiting = false
			if orbitConnection then orbitConnection:Disconnect() end
			return
		end

		angle = angle + dt * math.pi -- ปรับความเร็วการวน

		local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local targetPos = target.HumanoidRootPart.Position + offset

		HumanoidRootPart.CFrame = CFrame.new(targetPos, target.HumanoidRootPart.Position)
	end)
end

-- ฟังก์ชันตรวจ HP
function monitorHealth()
	while true do
		if autoMoveEnabled and not isHealing and (Humanoid.Health / Humanoid.MaxHealth < 0.2) then
			isHealing = true
			local currentPos = HumanoidRootPart.Position
			local voidPos = Vector3.new(currentPos.X, currentPos.Y - 1000, currentPos.Z)

			Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
			Humanoid.PlatformStand = true
			Character:PivotTo(CFrame.new(voidPos))

			repeat task.wait(0.5) until Humanoid.Health >= Humanoid.MaxHealth - 1

			Humanoid.PlatformStand = false
			Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			isHealing = false
		end
		task.wait(0.5)
	end
end

task.spawn(monitorHealth)

-- ลูปหลัก
task.spawn(function()
	while true do
		if autoMoveEnabled and not isHealing then
			local mob = getNearestMobInRange(combatRange)
			if mob then
				walkToOffset(mob.HumanoidRootPart.CFrame, 2)
				task.wait(0.5)
				startOrbit(mob)
			else
				local touchPart = getNearestUntouchedTouchPart()
				if touchPart then
					touchedParts[touchPart] = true
					walkToOffset(touchPart.CFrame, 0)
					task.wait(1.5)
				end
			end
		end
		task.wait(updateInterval)
	end
end)
