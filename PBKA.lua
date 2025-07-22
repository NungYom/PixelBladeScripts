-- โหลด Turtle Lib
local lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/Bac0nHck/Scripts/refs/heads/main/Turtle-Lib/main/source.lua"))()

-- สร้างหน้าต่างหลัก
local m = lib:Window("Build An Island")
local bi = lib:Window("Buy Items")
local s = lib:Window("Settings")

-- เปิดหน้าต่างทั้งหมดทันที
if m.Open then m:Open() end
if bi.Open then bi:Open() end
if s.Open then s:Open() end

-- ต่อจากนี้คือโค้ดฟังก์ชันหลักเดิม
local plr = game.Players.LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()
local rs = game:GetService("ReplicatedStorage")
local events = rs:WaitForChild("Events")

-- ตำแหน่งเกาะทั้งหมด
local islands = {}
for _, v in pairs(workspace:GetDescendants()) do
	if v:IsA("Model") and v.Name:match("Island") and v:FindFirstChild("Build") then
		table.insert(islands, v)
	end
end

-- ปุ่มฟาร์ม
local farming = false
m:Toggle("Auto Build", function(v)
	farming = v
end)

-- ปุ่มซื้อของ
bi:Button("Buy Wood", function()
	events.BuyWood:FireServer()
end)

bi:Button("Buy Stone", function()
	events.BuyStone:FireServer()
end)

-- ปุ่มฟาร์มแบบไม่วน
local once = false
s:Toggle("One Time Build", function(v)
	once = v
end)

-- ฟังก์ชันการสร้าง
game:GetService("RunService").RenderStepped:Connect(function()
	if farming then
		for _, island in ipairs(islands) do
			local build = island:FindFirstChild("Build")
			if build then
				events.BuildStructure:FireServer(build)
				task.wait(0.1)
			end
		end
		if once then
			farming = false
		end
	end
end)
