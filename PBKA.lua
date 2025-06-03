local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

-- ตั้งค่า
local moveSpeed = 100
local scanRadius = 1500
local updateInterval = 0.75
local autoMoveEnabled = false

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

-- โฟลเดอร์ GoblinArena (ใช้สำหรับกรอง)
local goblinArenaFolder = workspace:FindFirstChild("GoblinArena")
local excludedFolders = {}
if goblinArenaFolder then
	table.insert(excludedFolders, goblinArenaFolder:FindFirstChild("Goblins"))
	table.insert(excludedFolders, goblinArenaFolder:FindFirstChild("DrumGoblins"))
	table.insert(excludedFolders, goblinArenaFolder:FindFirstChild("introPositions"))
end

-- ตรวจว่า npc อยู่ในโฟลเดอร์ที่ถูกกรองหรือไม่
local function isInExcludedFolder(npc)
	for _, folder in pairs(excludedFolders) do
		if folder and npc:IsDescendantOf(folder) then
			return true
		end
	end
	return false
end

-- หา Mob ที่ใกล้ที่สุด (ไม่นับในโฟลเดอร์ประกอบฉาก)
local function getNearestMob()
	local nearestMob = nil
	local shortestDistance = math.huge

	for _, npc in pairs(workspace:GetDescendants()) do
		if npc:IsA("Model")
			and npc ~= Character
			and npc:FindFirstChild("Humanoid")
			and npc:FindFirstChild("HumanoidRootPart")
			and npc.Humanoid.Health > 0
			and not isInExcludedFolder(npc) then

			local dist = (HumanoidRootPart.Position - npc.HumanoidRootPart.Position).Magnitude
			if dist < scanRadius and dist < shortestDistance then
				shortestDistance = dist
				nearestMob = npc
			end
		end
	end

	return nearestMob
end

-- หา Part ชื่อ "touch"
local function getNearestTouchPart()
	local nearestPart = nil
	local shortestDistance = math.huge

	for _, part in pairs(workspace:GetDescendants()) do
		if part:IsA("BasePart") and part.Name:lower() == "touch" then
			local dist = (HumanoidRootPart.Position - part.Position).Magnitude
			if dist < scanRadius and dist < shortestDistance then
				shortestDistance = dist
				nearestPart = part
			end
		end
	end

	return nearestPart
end

-- Tween ไปหาเป้าหมาย
local function walkTo(targetCFrame)
	local distance = (HumanoidRootPart.Position - targetCFrame.Position).Magnitude
	local travelTime = distance / moveSpeed

	local tweenInfo = TweenInfo.new(travelTime, Enum.EasingStyle.Linear)
	local tween = TweenService:Create(HumanoidRootPart, tweenInfo, {
		CFrame = targetCFrame * CFrame.new(0, 0, -3)
	})
	tween:Play()
end

-- ฟังก์ชันใช้สกิลอัตโนมัติ (Slash)
local function useSkill()
	local sword = Character:FindFirstChild("SteelSword")
	if not sword then return end

	local waitTimeOptions = {0.225, 0.475}
	local randomWait = waitTimeOptions[math.random(1, #waitTimeOptions)]

	local slashArgs = {
		"Slash",
		{
			wpn = sword,
			waitTime = randomWait
		}
	}

	ReplicatedStorage:WaitForChild("remotes"):WaitForChild("newEffect"):FireServer(unpack(slashArgs))
end

-- ลูปเดินอัตโนมัติ
task.spawn(function()
	while true do
		if autoMoveEnabled then
			local mob = getNearestMob()
			if mob then
				walkTo(mob:FindFirstChild("HumanoidRootPart").CFrame)
			else
				local touchPart = getNearestTouchPart()
				if touchPart then
					walkTo(touchPart.CFrame)
				end
			end
		end
		task.wait(updateInterval)
	end
end)

-- ลูปใช้สกิลอัตโนมัติ
task.spawn(function()
	while true do
		if autoMoveEnabled then
			useSkill()
		end
		task.wait(1)
	end
end)
