local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

-- === CONFIG ===
local moveSpeed = 100
local scanRadius = 1500
local updateInterval = 0.75
local autoMoveEnabled = false

local lobbyPlaceId = 18172550962

-- === GUI ===
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

-- === ฟังก์ชันเฉพาะ Lobby ===
local function lobbyCode()
	local args = {
		"Grasslands",
		"Heroic",
		true
	}

	local tpRemote = ReplicatedStorage:WaitForChild("remotes"):WaitForChild("playerTP")
	tpRemote:FireServer(unpack(args))

	-- ปิด AutoMove ทันทีหลังส่งคำสั่ง (ถ้าต้องการ)
	autoMoveEnabled = false
	toggleButton.Text = "AutoMove: OFF"
end

-- === ฟังก์ชันสำหรับตีมอน ===
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

local function getNearestMob()
	local nearestMob, shortestDistance = nil, math.huge

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
	local nearestPart, shortestDistance = nil, math.huge

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

-- === ลูปหลัก ===
task.spawn(function()
	local doneLobbyCode = false

	while true do
		if game.PlaceId == lobbyPlaceId then
			if not doneLobbyCode then
				doneLobbyCode = true
				lobbyCode()
			end
		else
			doneLobbyCode = false

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
		end

		task.wait(updateInterval)
	end
end)
