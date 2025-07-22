-- UI Setup
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SimpleFarmGUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 150, 0, 50)
frame.Position = UDim2.new(1, -160, 0, 20)
frame.BackgroundTransparency = 0.5
frame.BackgroundColor3 = Color3.new(0, 0, 0)
frame.BorderSizePixel = 0
frame.Parent = screenGui

local farmButton = Instance.new("TextButton")
farmButton.Size = UDim2.new(1, 0, 1, 0)
farmButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
farmButton.Text = "FARM: OFF"
farmButton.TextColor3 = Color3.new(1, 1, 1)
farmButton.Font = Enum.Font.SourceSansBold
farmButton.TextScaled = true
farmButton.Parent = frame

-- Core Logic
local farming = false
local heartbeat = game:GetService("RunService").Heartbeat

local function runFarmCycle()
	local REM = game:GetService("ReplicatedStorage"):WaitForChild("REM")
	local function Fire(id, data)
		REM:WaitForChild(id):FireServer(data)
	end
	local function Invoke(id, data)
		REM:WaitForChild(id):InvokeServer(data)
	end

	-- Diamond & Gold
	Fire("023585d4-347c-497f-8d2a-1f4222c5eb41", {{Type = "Diamond"}})
	Fire("023585d4-347c-497f-8d2a-1f4222c5eb41", {{Type = "Gold"}})

	-- Regrowth Upgrade
	Invoke("85729e59-0a9d-4839-abbe-464e4f70a59e", {{UpgradeType = "RegrowthSpeed"}})

	-- Fire UUIDs
	local UUIDs = {
		"51d49521-ebc1-4c16-b8cf-3c5ca67fd222", "40951b47-f09f-4355-b374-c4a337628303", "43c348d0-6d7f-4b2c-9462-7bf341fd544c",
		"09c542f5-41fd-4fc0-8686-abc5e5f3c53b", "c4b10889-be41-4a1e-9879-21941ba6da21", "aa19524f-1a10-4935-abd7-60f8061cf1a7",
		"75e00d55-912d-4c4e-a63d-8f935639499a", "db287ea6-0cfc-4630-9596-226e59658626", "13de8354-20b2-4463-8845-81b2d91b2762",
		"fe9174eb-c992-40bd-8dcb-da471fca992d", "ca1b8644-f3b3-497e-8e88-1ae390992114", "a2a3592a-7b62-403d-a074-02ada7184d1a",
		"a397a0d0-9aa1-4a57-93c2-03152f36c508", "927f6e2a-f6d9-44ff-bf8c-61096ac1f8fa", "ecafb59a-7fb9-4077-ad8f-f5d705674fa1",
		"539bd9b8-235f-4699-a730-cbcb786c0232", "becedc48-6355-42ab-8e87-d06d48c316aa", "8e3da63a-992d-4445-8dc2-4473a29f4bec",
		"4c8f875e-c2d1-43c0-a681-eb2489573f88", "ec00906a-6064-4cee-865d-6fde2fd6c29d", "6da27503-a49b-4dee-b61a-827ede4b2129",
		"3b649aee-e023-4916-911e-00ef191dc1b1", "69fcffa6-ad7b-4335-8d43-842ec322c2ca", "14c33ffd-ef18-4c70-96df-4b38c7680e7a",
		"3e13d5b6-22da-413d-8f95-72511dda8c21", "c040a9d9-979e-4afa-9019-31ed66709ed8", "b60239ef-e66c-4311-b3a8-31aa2f672c31",
		"a44c9905-91ad-4065-823f-5fe1b4cdaf24", "d3d1d15c-9631-4708-8de3-7d58b3fbd12f", "f3d2b0ed-9a7e-4d51-86d0-ec1ec2c5fa44",
		"93ae3132-381d-4654-9f80-e476c8da65fd", "fa00149c-c9e8-49b4-9f02-5b1bdc3030bf", "4d13211b-3cf9-4fa9-a5ce-7120c835e879",
		"0bdaeaaa-aefb-418b-8381-fd8dab2042bb", "523b82ad-345d-4dcf-b831-1c47e70a4459", "572ff190-a40a-4003-91b2-f8390c705901",
		"53d91d7c-a161-4afc-a8f2-a439506c0cf7", "0aa8e0dc-c6ad-4b76-8aaf-1225766ac255", "f0273b6c-9b8b-4fa4-9429-7a0236f83d98",
		"e8fa07b4-bc9f-4fbb-b8b4-3490e7e172d3", "92331b70-3669-44d7-8e8b-557ccd6d8c33", "61dc9984-036f-4e19-881e-0254b79156e9",
		"5fc5b49e-c003-4b83-b4e4-72634334a096", "6c5b9357-955a-4b86-ae3e-5948d02149e1", "e1285d2c-83f4-4339-9adb-355bcb8d4123",
		"480b2f9e-f868-4359-a655-f33971db7f05"
	}
	for _, uuid in ipairs(UUIDs) do
		Fire("c7a2740f-f938-4f4b-8ce1-e7b77cb96ac8", {{UUID = uuid}})
	end
end

-- Loop handler
task.spawn(function()
	while true do
		if farming then
			pcall(runFarmCycle)
		end
		task.wait(0.2)
	end
end)

-- Button Toggle
farmButton.MouseButton1Click:Connect(function()
	farming = not farming
	if farming then
		farmButton.Text = "FARM: ON"
		farmButton.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
	else
		farmButton.Text = "FARM: OFF"
		farmButton.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
	end
end)
