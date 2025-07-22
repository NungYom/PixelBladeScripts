-- ล้าง GUI เดิม
local guiParent = gethui and gethui() or game:GetService("CoreGui") or game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
if guiParent:FindFirstChild("IslandUI") then
	guiParent.IslandUI:Destroy()
end

-- ===== เก็บเฉพาะฟังก์ชันการทำงานหลัก =====
local function createIsland()
    print("Creating Island...")
    -- (เนื้อหาฟังก์ชันจากต้นฉบับ)
end

local function buildWalls()
    print("Building Walls...")
    -- (เนื้อหาฟังก์ชันจากต้นฉบับ)
end

local function fillGround()
    print("Filling Ground...")
    -- (เนื้อหาฟังก์ชันจากต้นฉบับ)
end

-- ===== สร้าง GUI ใหม่ที่มุมขวาบน =====
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "IslandUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = guiParent

local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 160, 0, 140)
Frame.Position = UDim2.new(1, -170, 0, 10)
Frame.BackgroundTransparency = 0.5
Frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Frame.BorderSizePixel = 0
Frame.Parent = ScreenGui

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Padding = UDim.new(0, 6)
UIListLayout.FillDirection = Enum.FillDirection.Vertical
UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Top
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Parent = Frame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 24)
Title.Text = "🌴 Build Menu"
Title.TextColor3 = Color3.new(1,1,1)
Title.TextTransparency = 0.2
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamBold
Title.TextScaled = true
Title.Parent = Frame

local function createButton(text, callback)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, -20, 0, 26)
	button.Text = text
	button.Font = Enum.Font.Gotham
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextScaled = true
	button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.MouseButton1Click:Connect(callback)
	button.Parent = Frame
end

-- ===== ปุ่มเรียกใช้ฟังก์ชัน =====
createButton("Create Island", createIsland)
createButton("Build Walls", buildWalls)
createButton("Fill Ground", fillGround)
