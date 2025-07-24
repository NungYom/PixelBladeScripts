local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local function getEquippedToolUID()
	local character = player.Character or player.CharacterAdded:Wait()
	local tool = character:FindFirstChildOfClass("Tool")
	if tool then
		local uidValue = tool:FindFirstChild("UID")
		if uidValue and typeof(uidValue.Value) == "string" then
			return uidValue.Value
		end
	end
	return nil
end
local itemId = 6
local itemUID = getEquippedToolUID()
if not itemUID then
	warn("❌ ไม่พบปืนที่ถืออยู่หรือไม่มี UID")
	return
end
local function fireAllRemote(uuid, fishUUID, direction, origin)
	local args1 = {
		"10000",
		{ ItemId = itemId, UID = itemUID },
		"1002",
		uuid,
		2
	}
	ReplicatedStorage.GameplayAbilitySystem.Remote.ServerActivateGameplayEffect:FireServer(unpack(args1))

	local args2 = {
		"10000",
		"1",
		{ ItemId = itemId, UID = itemUID }
	}
	ReplicatedStorage.GameplayAbilitySystem.Remote.ClientApplyServerActivateGA:InvokeServer(unpack(args2))

	wait(0.05)

	local args3 = {
		"10000",
		tostring(itemId),
		"12",
		{
			Direction = direction,
			ThrowableId = itemId,
			UUID = uuid,
			Origin = origin
		},
		2,
		"1002",
		uuid
	}
	ReplicatedStorage.GameplayAbilitySystem.Remote.GameplayEffectExeFinish:FireServer(unpack(args3))

	wait(0.05)

	local args4 = { "10000", "12", "1002", "1" }
	ReplicatedStorage.GameplayAbilitySystem.Remote.ExeGameplayEffectStartFuncSucc:FireServer(unpack(args4))

	local args5 = { uuid }
	ReplicatedStorage.Throwable.Remote.GetInstaceByThrowableIndex:InvokeServer(unpack(args5))

	wait(0.2)

	local args6 = {
		{
			UUID = uuid,
			FishList = { fishUUID }
		}
	}
	ReplicatedStorage.Harpoon.Remote.ApplyCaptureResult:InvokeServer(unpack(args6))
end
while task.wait(0.5) do
	pcall(function()
		for _, fishFolder in pairs(Workspace:WaitForChild("FishModelList"):GetChildren()) do
			local center = fishFolder:FindFirstChild("Center")
			if center then
				local uuid = fishFolder.Name
				local direction = (center.Position - player.Character.HumanoidRootPart.Position).Unit
				local origin = player.Character.HumanoidRootPart.Position

				fireAllRemote(uuid, uuid, direction, origin)
				task.wait(0.2)
			end
		end
	end)
end
