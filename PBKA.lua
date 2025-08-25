-- สร้าง GUI หลัก
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Parent = game:GetService("CoreGui")

-- ปุ่ม Attack + Train Toggle
local ToggleButton = Instance.new("TextButton")
ToggleButton.Size = UDim2.new(0, 150, 0, 50)
ToggleButton.Position = UDim2.new(0.5, -75, 0, 100) -- กลางบน
ToggleButton.Text = "Attack+Train: OFF"
ToggleButton.Parent = ScreenGui

-- ปุ่ม Rebirth Toggle
local RebirthButton = Instance.new("TextButton")
RebirthButton.Size = UDim2.new(0, 150, 0, 50)
RebirthButton.Position = UDim2.new(1, -170, 0.5, -25) -- ขวากลาง
RebirthButton.Text = "Rebirth: OFF"
RebirthButton.Parent = ScreenGui

-- ตัวแปรควบคุม loop
local running = false
local rebirthRunning = false

-- ฟังก์ชันลูป Attack + Train
local function attackTrainLoop()
    while running do
        pcall(function()
            game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("_Index")
                :WaitForChild("sleitnick_knit@1.5.1"):WaitForChild("knit"):WaitForChild("Services")
                :WaitForChild("FightService"):WaitForChild("RE"):WaitForChild("Attack"):FireServer()

            game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("_Index")
                :WaitForChild("sleitnick_knit@1.5.1"):WaitForChild("knit"):WaitForChild("Services")
                :WaitForChild("TrainService"):WaitForChild("RE"):WaitForChild("Train"):FireServer()
        end)
        task.wait(0.1)
    end
end

-- ฟังก์ชันลูป Rebirth
local function rebirthLoop()
    while rebirthRunning do
        pcall(function()
            game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("_Index")
                :WaitForChild("sleitnick_knit@1.5.1"):WaitForChild("knit"):WaitForChild("Services")
                :WaitForChild("RebirthService"):WaitForChild("RF"):WaitForChild("Rebirth"):InvokeServer()
        end)
        task.wait(1)
    end
end

-- กดปุ่ม Attack+Train
ToggleButton.MouseButton1Click:Connect(function()
    running = not running
    if running then
        ToggleButton.Text = "Attack+Train: ON"
        task.spawn(attackTrainLoop)
    else
        ToggleButton.Text = "Attack+Train: OFF"
    end
end)

-- กดปุ่ม Rebirth
RebirthButton.MouseButton1Click:Connect(function()
    rebirthRunning = not rebirthRunning
    if rebirthRunning then
        RebirthButton.Text = "Rebirth: ON"
        task.spawn(rebirthLoop)
    else
        RebirthButton.Text = "Rebirth: OFF"
    end
end)
