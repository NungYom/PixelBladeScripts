local lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/Turtle-Brand/Turtle-Lib/main/source.lua"))()

-- สร้างหน้าต่างเดียว
local main = lib:Window("Build An Island", {
    Position = UDim2.new(1, -10, 0, 10),
    Anchor = Vector2.new(1, 0),
    Transparency = 0.5,
    Size = UDim2.new(0, 300, 0, 400),
})

-- ตั้งค่าตัวแปร
local Players = game:GetService("Players")
local plr = Players.LocalPlayer
local plot = game:GetService("Workspace"):WaitForChild("Plots"):WaitForChild(plr.Name)
local land = plot:FindFirstChild("Land")
local resources = plot:WaitForChild("Resources")
local expand = plot:WaitForChild("Expand")
getgenv().settings = {
    farm=false, expand=false,
    craft=false, sell=false,
    gold=false, collect=false,
    harvest=false, hive=false,
    auto_buy=false
}
local expand_delay, craft_delay = 0.1, 0.1

-- ฟังก์ชัน Auto ต่างๆ
local function addToggle(label, field, func)
    main:Toggle(label, settings[field], function(b)
        settings[field] = b
        task.spawn(func)
    end)
end

addToggle("Auto Farm Resources", "farm", function()
    while settings.farm do
        for _, r in ipairs(resources:GetChildren()) do
            game:GetService("ReplicatedStorage").Communication.HitResource:FireServer(r)
            task.wait(.01)
        end
        task.wait(.1)
    end
end)

addToggle("Auto Expand Land", "expand", function()
    while settings.expand do
        for _, exp in ipairs(expand:GetChildren()) do
            local top = exp:FindFirstChild("Top")
            if top then
                for _, c in ipairs(top:GetDescendants()) do
                    if c:IsA("Frame") and c.Name ~= "Example" then
                        game:GetService("ReplicatedStorage").Communication.ContributeToExpand:FireServer(exp.Name, c.Name, 1)
                    end
                end
            end
            task.wait(0.01)
        end
        task.wait(expand_delay)
    end
end)

addToggle("Auto Crafter", "craft", function()
    while settings.craft do
        for _, c in ipairs(plot:GetDescendants()) do
            if c.Name=="Crafter" then
                local att = c:FindFirstChildOfClass("Attachment")
                if att then
                    game:GetService("ReplicatedStorage").Communication.Craft:FireServer(att)
                end
            end
        end
        task.wait(craft_delay)
    end
end)

addToggle("Auto Gold Mine", "gold", function()
    while settings.gold do
        for _, mine in ipairs(land:GetDescendants()) do
            if mine:IsA("Model") and mine.Name=="GoldMineModel" then
                game:GetService("ReplicatedStorage").Communication.Goldmine:FireServer(mine.Parent.Name,1)
            end
        end
        task.wait(1)
    end
end)

addToggle("Auto Collect Gold", "collect", function()
    while settings.collect do
        for _, mine in ipairs(land:GetDescendants()) do
            if mine:IsA("Model") and mine.Name=="GoldMineModel" then
                game:GetService("ReplicatedStorage").Communication.Goldmine:FireServer(mine.Parent.Name,2)
            end
        end
        task.wait(1)
    end
end)

addToggle("Auto Sell", "sell", function()
    while settings.sell do
        for _, crop in ipairs(plr.Backpack:GetChildren()) do
            if crop:GetAttribute("Sellable") then
                game:GetService("ReplicatedStorage").Communication.SellToMerchant:FireServer(false, {crop:GetAttribute("Hash")})
            end
        end
        task.wait(1)
    end
end)

addToggle("Auto Harvest", "harvest", function()
    while settings.harvest do
        for _, crop in ipairs(plot.Plants:GetChildren()) do
            game:GetService("ReplicatedStorage").Communication.Harvest:FireServer(crop.Name)
        end
        task.wait(1)
    end
end)

addToggle("Auto Collect Hive", "hive", function()
    while settings.hive do
        for _, spot in ipairs(land:GetDescendants()) do
            if spot:IsA("Model") and spot.Name:match("Spot") then
                game:GetService("ReplicatedStorage").Communication.Hive:FireServer(spot.Parent.Name, spot.Name, 2)
            end
        end
        task.wait(1)
    end
end)

-- ฟังก์ชัน Buy items
local items = {}
for _, item in ipairs(plr.PlayerGui.Main.Menus.Merchant.Inner.ScrollingFrame.Hold:GetChildren()) do
    if item:IsA("Frame") and item.Name~="Example" then
        table.insert(items, item.Name)
    end
end
local selectedItem = nil
main:Dropdown("Buy Items", items, function(name) selectedItem = name end)
main:Button("Buy Now", function()
    if selectedItem then
        game:GetService("ReplicatedStorage").Communication.BuyFromMerchant:FireServer(selectedItem, false)
    end
end)
addToggle("Auto Buy Item", "auto_buy", function()
    while settings.auto_buy do
        if selectedItem then
            game:GetService("ReplicatedStorage").Communication.BuyFromMerchant:FireServer(selectedItem, false)
        end
        task.wait(0.25)
    end
end)

-- Delay settings
main:Box("Expand Delay", function(t) expand_delay = tonumber(t) or expand_delay end)
main:Box("Craft Delay", function(t) craft_delay = tonumber(t) or craft_delay end)

-- Anti AFK & Destroy GUI
main:Button("Anti AFK", function()
    local vu = game:GetService("VirtualUser")
    plr.Idled:Connect(function()
        vu:CaptureController()
        vu:ClickButton2(Vector2.new())
    end)
end)
main:Button("Destroy GUI", function()
    for k in pairs(settings) do settings[k] = false end
    lib:Destroy()
end)

-- Keybind to hide
main:Keybind("LeftControl")
