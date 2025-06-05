local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")

-- ตั้งค่า
local moveSpeed = 100
local scanRadius = 1500
local combatRange = 400
local updateInterval = 0.75
local autoMoveEnabled = false
local isHealing = false

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
		task.spawn(monitorHealth)
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

-- รายชื่อ NPC ที่ไม่ต้องไล่ตาม
local excludedNames = {
	["GoblinType1"] = true,
	["GoblinType2"] = true
}

-- ฟังก์ชันหา mob ที่ใกล้ที่สุดภายในระยะที่กำหนด
local function getNearestMobInRange(maxDistance)
	local nearestMob = nil
	local shortestDistance = math.huge

	for _, npc in pairs(workspace:GetDescendants()) do
		if npc:IsA("Model")
			and npc ~= Character
			and npc:FindFirstChild("Humanoid")
			and npc:FindFirstChild("HumanoidRootPart")
			and npc.Humanoid.Health > 0
			and not Players:GetPlayerFromCharacter(npc)
			and not excludedNames[npc.Name]
			and not isInExcludedFolder(npc) then

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

-- Tween ไปหาเป้าหมาย โดยหยุดห่าง 2 studs
local currentTween

local function walkTo(targetCFrame)
	if currentTween then currentTween:Cancel() end

	local targetPos = targetCFrame.Position
	local direction = (targetPos - HumanoidRootPart.Position).Unit
	local stopDistance = 2
	local destination = targetPos - direction * stopDistance

	local distance = (HumanoidRootPart.Position - destination).Magnitude
	local travelTime = distance / moveSpeed

	local tweenInfo = TweenInfo.new(travelTime, Enum.EasingStyle.Linear)
	local tween = TweenService:Create(HumanoidRootPart, tweenInfo, {
		CFrame = CFrame.new(destination, destination + HumanoidRootPart.CFrame.LookVector)
	})
	currentTween = tween
	tween:Play()
end

-- ตรวจ HP หากต่ำกว่า 20% ให้ตก void แล้วรอจน HP เต็ม
function monitorHealth()
	while autoMoveEnabled do
		if not isHealing and (Humanoid.Health / Humanoid.MaxHealth < 0.2) then
			isHealing = true
			local currentPos = HumanoidRootPart.Position
			local voidPos = Vector3.new(currentPos.X, currentPos.Y - 1000, currentPos.Z)
			Character:PivotTo(CFrame.new(voidPos)) -- << ใช้ PivotTo เพื่อให้ตก void จริง
			warn("Low HP! Teleporting to void...")

			-- รอให้ HP รีเซ็ต
			repeat task.wait(0.25) until Humanoid.Health >= Humanoid.MaxHealth - 1
			warn("HP restored after void.")
			isHealing = false
		end
		task.wait(0.5)
	end
end

-- ลูปหลัก
task.spawn(function()
	while true do
		if autoMoveEnabled and not isHealing then
			local mob = getNearestMobInRange(combatRange)
			if mob then
				walkTo(mob.HumanoidRootPart.CFrame)
			else
				local touchPart = getNearestUntouchedTouchPart()
				if touchPart then
					touchedParts[touchPart] = true
					walkTo(touchPart.CFrame)
					task.wait(1.5)
				end
			end
		end
		task.wait(updateInterval)
	end
end)
