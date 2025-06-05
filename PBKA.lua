local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

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

-- Performance boost: minimize visuals
Lighting.GlobalShadows = false
Lighting.FogEnd = 1000000
for _, v in ipairs(workspace:GetDescendants()) do
	if v:IsA("BasePart") then
		v.Material = Enum.Material.SmoothPlastic
		v.CastShadow = false
	end
	if v:IsA("ParticleEmitter") or v:IsA("Trail") then
		v.Enabled = false
	end
end
-- Noclip & Floating (เพื่อไม่ให้กระตุกขึ้นลง)
RunService.Stepped:Connect(function()
	if autoMoveEnabled and Character and Character:FindFirstChildOfClass("Humanoid") then
		for _, part in pairs(Character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = false
				part.Anchored = false
			end
		end
		Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		HumanoidRootPart.Velocity = Vector3.new(0, 0, 0)
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

			local dist = (HumanoidRootPart.Position - npc.HumanoidRootPart.Position).Magnitude
			if dist < maxDistance and dist < shortestDistance then
				shortestDistance = dist
				nearestMob = npc
			end
		end
	end

	return nearestMob
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

-- Smooth circle strafing
local function circleAroundTarget(target)
	task.spawn(function()
		local angle = 0
		while autoMoveEnabled and target and target:FindFirstChild("Humanoid") and target.Humanoid.Health > 0 do
			local radius = 4
			angle += math.rad(2)
			if angle > math.pi * 2 then angle = 0 end
			local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			local goalPos = target.HumanoidRootPart.Position + offset
			local goalCFrame = CFrame.new(goalPos, target.HumanoidRootPart.Position)
			walkTo(goalCFrame)
			task.wait(0.05)
		end
	end)
end
-- ปิดเอฟเฟกต์เพื่อเพิ่มเฟรมเรต โดยไม่ยุ่งกับ Texture/Decal ของเกม
task.spawn(function()
	while true do
		for _, obj in pairs(workspace:GetDescendants()) do
			if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then
				obj.Enabled = false
			elseif obj:IsA("Light") then
				obj.Enabled = false
			end
		end
		-- ลดคุณภาพกราฟิกจากฝั่งผู้เล่นโดยไม่ทำลายองค์ประกอบของเกม
		pcall(function()
			settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
			UserSettings():GetService("UserGameSettings").SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
		end)
		task.wait(2)
	end
end)

-- Main loop
task.spawn(function()
	while true do
		if autoMoveEnabled then
			local mob = getNearestMobInRange(combatRange)
			if mob then
				if mob ~= lastTarget then
					lastTarget = mob
					local offsetCFrame = mob.HumanoidRootPart.CFrame * CFrame.new(0, 0, -4)
					walkTo(offsetCFrame)
					circleAroundTarget(mob)
				end
			end
		end
		task.wait(updateInterval)
	end
end)
