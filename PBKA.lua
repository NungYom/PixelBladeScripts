local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local rs = ReplicatedStorage:WaitForChild("remotes")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

local moveSpeed = 100
local scanRadius = 1500
local attackRange = 5
local updateInterval = 0.75
local autoMoveEnabled = false

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

-- กรองโฟลเดอร์
local goblinArenaFolder = workspace:FindFirstChild("GoblinArena")
local excludeFolders = {}

if goblinArenaFolder then
	excludeFolders = {
		goblinArenaFolder:FindFirstChild("DrumGoblins"),
		goblinArenaFolder:FindFirstChild("Goblins"),
		goblinArenaFolder:FindFirstChild("introPositions")
	}
end

local function isInExcludedFolder(npc)
	for _, folder in ipairs(excludeFolders) do
		if folder and npc:IsDescendantOf(folder) then
			return true
		end
	end
	return false
end

local excludedNames = {
	["GoblinType1"] = true,
	["GoblinType2"] = true
}

local function getNearestMob()
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

			local dist = (HumanoidRootPart.Position - npc.HumanoidRootPart.Position).Magnitude
			if dist < scanRadius and dist < shortestDistance then
				shortestDistance = dist
				nearestMob = npc
			end
		end
	end

	return nearestMob
end

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

local currentTween

local function walkTo(targetCFrame)
	if currentTween then currentTween:Cancel() end

	local distance = (HumanoidRootPart.Position - targetCFrame.Position).Magnitude
	local travelTime = distance / moveSpeed

	local tweenInfo = TweenInfo.new(travelTime, Enum.EasingStyle.Linear)
	local tween = TweenService:Create(HumanoidRootPart, tweenInfo, {
		CFrame = targetCFrame * CFrame.new(0, 0, -3)
	})
	currentTween = tween
	tween:Play()
end

-- ฟังก์ชันโจมตีเป้าหมาย
local function attackTarget(target)
	local weapon = Character:FindFirstChild("SteelSword")
	local humanoid = target:FindFirstChild("Humanoid")
	local targetRoot = target:FindFirstChild("HumanoidRootPart")

	if not (weapon and humanoid and targetRoot) then return end

	-- Swing เริ่ม
	rs.swing:FireServer()

	rs.newEffect:FireServer("Slash", {
		wpn = weapon,
		waitTime = 0.283
	})

	rs.newEffect:FireServer("PositionalSound", {
		position = HumanoidRootPart.Position,
		soundName = "SwordSwoosh",
		positionMoveWith = HumanoidRootPart
	})

	task.wait(0.05)

	rs.newEffect:FireServer("PositionalSound", {
		position = targetRoot.Position,
		soundName = "BladeHit",
		positionMoveWith = targetRoot
	})

	rs.newEffect:FireServer("hitFeedback", {
		hitPos = targetRoot.Position,
		dur = 0.25,
		enemy = target
	})

	-- แรงโจมตีสูง (9999)
	rs.onHit:FireServer(humanoid, 9999, {}, 0)
end

-- ลูป
task.spawn(function()
	while true do
		if autoMoveEnabled then
			local mob = getNearestMob()
			if mob then
				local mobHRP = mob:FindFirstChild("HumanoidRootPart")
				local mobHumanoid = mob:FindFirstChild("Humanoid")

				if mobHRP and mobHumanoid and mobHumanoid.Health > 0 then
					local dist = (HumanoidRootPart.Position - mobHRP.Position).Magnitude
					if dist > attackRange then
						walkTo(mobHRP.CFrame)
					else
						attackTarget(mob)
						repeat task.wait(0.25) until mobHumanoid.Health <= 0 or not autoMoveEnabled
					end
				end
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
