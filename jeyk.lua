--[[
    CRAFT A WORLD V0.0.3 - EXPLOIT SCRIPT
    CUSTOMIZABLE PARTS ARE MARKED WITH [CUSTOM]
    
    How to customize:
    1. Replace "Wave" with your name
    2. Change the theme color
    3. Default settings can be changed
--]]

-- [CUSTOM] =================================
local SCRIPT_NAME = "Wave" -- << CHANGE THIS
local THEME = "BloodTheme" -- Options: DarkTheme, LightTheme, GrapeTheme, BloodTheme
local SHOW_SPLASH = true -- Show logo/credits
-- ==========================================

-- Service initialization
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

-- Player variables
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local Mouse = LocalPlayer:GetMouse()
local Camera = workspace.CurrentCamera

-- Remote events
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- Mapping all remotes
local RemotesList = {
    PlayerPlaceItem = Remotes:WaitForChild("PlayerPlaceItem"),
    PlayerFist = Remotes:WaitForChild("PlayerFist"),
    WorldSetTile = Remotes:WaitForChild("WorldSetTile"),
    WorldSetTileHit = Remotes:WaitForChild("WorldSetTileHit"),
    WorldSetTileData = Remotes:WaitForChild("WorldSetTileData"),
    InventorySetItem = Remotes:WaitForChild("InventorySetItem"),
    InventorySetAmount = Remotes:WaitForChild("InventorySetAmount"),
    InventoryInitialize = Remotes:WaitForChild("InventoryInitialize"),
    PlayerSetGems = Remotes:WaitForChild("PlayerSetGems"),
    PlayerSetMaxSlots = Remotes:WaitForChild("PlayerSetMaxSlots"),
    PlayerSetPosition = Remotes:WaitForChild("PlayerSetPosition"),
    RequestWorldTiles = Remotes:WaitForChild("RequestWorldTiles"),
    RequestItemData = Remotes:WaitForChild("RequestItemData"),
}

-- Game modules
local Inventory = require(ReplicatedStorage.Modules.Inventory)
local ItemsManager = require(ReplicatedStorage.Managers.ItemsManager)
local WorldManager = require(ReplicatedStorage.Managers.WorldManager)
local PlayerMovement = require(LocalPlayer.PlayerScripts.PlayerModule.PlayerMovement)

-- GUI Library
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/xHeptc/Kavo-UI-Library/main/source.lua"))()
local Window = Library.CreateLib(SCRIPT_NAME, THEME)

-- ==============================================
-- DYNAMIC ITEM LISTS (populated from inventory)
-- ==============================================
local DynamicItems = {
    Saplings = {},
    Blocks = {},
    AllItems = {}
}

-- Function to refresh items from inventory
local function RefreshInventoryItems()
    DynamicItems.Saplings = {}
    DynamicItems.Blocks = {}
    DynamicItems.AllItems = {}

    for slot, stack in pairs(Inventory.Stacks) do
        if stack and stack.Id then
            local itemId = stack.Id
            local itemName = tostring(itemId)

            table.insert(DynamicItems.AllItems, itemName)

            if string.sub(itemName, -8) == "_sapling" then
                table.insert(DynamicItems.Saplings, itemName)
            end

            local success, itemData = pcall(function()
                return ItemsManager.RequestItemData(itemId)
            end)

            if success and itemData and itemData.Tile then
                table.insert(DynamicItems.Blocks, itemName)
            end
        end
    end

    local function unique(tbl)
        local seen = {}
        local result = {}
        for _, v in ipairs(tbl) do
            if not seen[v] then
                seen[v] = true
                table.insert(result, v)
            end
        end
        return result
    end

    DynamicItems.Saplings = unique(DynamicItems.Saplings)
    DynamicItems.Blocks = unique(DynamicItems.Blocks)
    DynamicItems.AllItems = unique(DynamicItems.AllItems)

    table.sort(DynamicItems.Saplings)
    table.sort(DynamicItems.Blocks)
    table.sort(DynamicItems.AllItems)

    print("[✓] Inventory refreshed - " .. #DynamicItems.AllItems .. " items found")
    print("    Saplings: " .. #DynamicItems.Saplings)
    print("    Blocks: " .. #DynamicItems.Blocks)

    return DynamicItems
end

-- Settings table
local Settings = {
    AutoPlant = false,
    AutoHarvest = false,
    AutoBreak = false,
    OneHitMode = false,
    TractorMode = false,

    SelectedSapling = "NONE",
    SelectedBlock = "NONE",
    SelectedTile = "NONE",

    PlantInterval = 0.01,
    HarvestInterval = 0.01,
    BreakInterval = 0.01,
    PlaceInterval = 0.15,

    Radius = 5,
    Speed = 16,
    JumpPower = 50,
    TargetGems = 999999,
}

-- ==============================================
-- SPLASH SCREEN
-- ==============================================
if SHOW_SPLASH then
    print("╔══════════════════════════════════════╗")
    print("║  " .. SCRIPT_NAME .. " v1.0")
    print("║  Craft a World v0.0.3")
    print("║  Dynamic Item Selection")
    print("╚══════════════════════════════════════╝")
end

-- ==============================================
-- TAB 1: FARMING
-- ==============================================
local FarmingTab = Window:NewTab("Farming")
local FarmingSection = FarmingTab:NewSection("Auto Farm Controls")

FarmingSection:NewButton("🔄 Refresh Backpack", "Load items from inventory", function()
    local items = RefreshInventoryItems()

    if #items.Saplings > 0 then
        FarmingTab:UpdateDropdown("Select Sapling", items.Saplings)
    end

    if #items.Blocks > 0 then
        FarmingTab:UpdateDropdown("Select Block", items.Blocks)
    end

    FarmingTab:UpdateDropdown("Select Tile", items.AllItems)
end)

FarmingSection:NewDropdown("Select Sapling", "Choose a sapling (Refresh first)", {"NONE"}, function(value)
    Settings.SelectedSapling = value
    print("[✓] Selected sapling: " .. value)
end)

FarmingSection:NewDropdown("Select Block", "Choose a block (Refresh first)", {"NONE"}, function(value)
    Settings.SelectedBlock = value
    print("[✓] Selected block: " .. value)
end)

FarmingSection:NewDropdown("Select Tile", "Choose a tile (Refresh first)", {"NONE"}, function(value)
    Settings.SelectedTile = value
    print("[✓] Selected tile: " .. value)
end)

FarmingSection:NewToggle("Auto Plant", "Automatically plant saplings", function(state)
    if state and Settings.SelectedSapling == "NONE" then
        print("[!] Select a sapling first!")
        return
    end
    Settings.AutoPlant = state
end)

FarmingSection:NewToggle("Auto Harvest", "Automatically harvest crops", function(state)
    Settings.AutoHarvest = state
end)

FarmingSection:NewToggle("Auto Break", "Break blocks automatically", function(state)
    if state and Settings.SelectedBlock == "NONE" then
        print("[!] Select a block first!")
        return
    end
    Settings.AutoBreak = state
end)

FarmingSection:NewToggle("1 Hit Mode", "One punch kill", function(state)
    Settings.OneHitMode = state
    if state then
        PlayerMovement.Punching = function() return true end
    end
end)

FarmingSection:NewToggle("Tractor Mode", "Wide area mode", function(state)
    Settings.TractorMode = state
    Settings.Radius = state and 10 or 5
end)

FarmingSection:NewSlider("Plant Interval (ms)", "Plant delay", 100, 1, function(value)
    Settings.PlantInterval = value / 1000
end)

FarmingSection:NewSlider("Harvest Interval (ms)", "Harvest delay", 100, 1, function(value)
    Settings.HarvestInterval = value / 1000
end)

FarmingSection:NewSlider("Break Interval (ms)", "Break delay", 100, 1, function(value)
    Settings.BreakInterval = value / 1000
end)

FarmingSection:NewSlider("Farm Radius", "Farm range", 20, 1, function(value)
    Settings.Radius = value
end)

-- ==============================================
-- TAB 2: PLAYER
-- ==============================================
local PlayerTab = Window:NewTab("Player")
local PlayerSection = PlayerTab:NewSection("Player Mods")

PlayerSection:NewSlider("WalkSpeed", "Movement speed", 250, 16, function(value)
    Settings.Speed = value
    if Humanoid then Humanoid.WalkSpeed = value end
end)

PlayerSection:NewSlider("JumpPower", "Jump height", 500, 50, function(value)
    Settings.JumpPower = value
    if Humanoid then Humanoid.JumpPower = value end
end)

PlayerSection:NewToggle("Fly", "Enable flight", function(state)
    local bodyGyro, bodyVelocity
    if state then
        bodyGyro = Instance.new("BodyGyro")
        bodyGyro.P = 9e4
        bodyGyro.maxTorque = Vector3.new(9e4, 9e4, 9e4)
        bodyGyro.Parent = Character.HumanoidRootPart

        bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.maxForce = Vector3.new(9e4, 9e4, 9e4)
        bodyVelocity.Parent = Character.HumanoidRootPart

        RunService.Heartbeat:Connect(function()
            if state then
                bodyGyro.cframe = Camera.CFrame
                bodyVelocity.velocity =
                    Camera.CFrame.lookVector * (UserInputService:IsKeyDown(Enum.KeyCode.W) and 50 or 0) +
                    -Camera.CFrame.lookVector * (UserInputService:IsKeyDown(Enum.KeyCode.S) and 50 or 0) +
                    Camera.CFrame.rightVector * (UserInputService:IsKeyDown(Enum.KeyCode.D) and 50 or 0) +
                    -Camera.CFrame.rightVector * (UserInputService:IsKeyDown(Enum.KeyCode.A) and 50 or 0) +
                    Vector3.new(0, UserInputService:IsKeyDown(Enum.KeyCode.Space) and 50 or 0, 0) +
                    Vector3.new(0, UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) and -50 or 0, 0)
            end
        end)
    else
        if bodyGyro then bodyGyro:Destroy() end
        if bodyVelocity then bodyVelocity:Destroy() end
    end
end)

PlayerSection:NewButton("Teleport to Mouse", "Move to cursor position", function()
    if Mouse.Hit then
        Character.HumanoidRootPart.CFrame = CFrame.new(Mouse.Hit.p + Vector3.new(0, 3, 0))
        pcall(function()
            RemotesList.PlayerSetPosition:FireServer(Mouse.Hit.p + Vector3.new(0, 3, 0))
        end)
    end
end)

-- ==============================================
-- TAB 3: ITEMS
-- ==============================================
local ItemTab = Window:NewTab("Items")
local ItemSection = ItemTab:NewSection("Item Exploits")

ItemSection:NewButton("Set Gems 999999", "Change gems amount", function()
    pcall(function()
        RemotesList.PlayerSetGems:FireServer(999999)
    end)
end)

ItemSection:NewButton("Max Slots (100)", "Unlock all slots", function()
    pcall(function()
        RemotesList.PlayerSetMaxSlots:FireServer(100)
    end)
end)

ItemSection:NewButton("Show Inventory in Console", "View inventory items in console", function()
    RefreshInventoryItems()
    print("\n=== INVENTORY ITEMS ===")
    for i, item in ipairs(DynamicItems.AllItems) do
        print(i .. ". " .. item)
    end
    print("=======================\n")
end)

-- ==============================================
-- TAB 4: WORLD
-- ==============================================
local WorldTab = Window:NewTab("World")
local WorldSection = WorldTab:NewSection("Tile Control")

WorldSection:NewButton("Place Selected Tile", "Place tile (select one first)", function()
    if Settings.SelectedTile == "NONE" then
        print("[!] Select a tile first!")
        return
    end

    if Mouse.Hit then
        local pos = Mouse.Hit.p
        local gridX = math.floor(pos.X / 4.5 + 0.5)
        local gridY = math.floor(pos.Y / 4.5 + 0.5)
        pcall(function()
            RemotesList.WorldSetTile:FireServer(gridX, gridY, Settings.SelectedTile, {})
        end)
    end
end)

WorldSection:NewButton("Break Tile at Mouse", "Destroy tile at cursor", function()
    if Mouse.Hit then
        local pos = Mouse.Hit.p
        local gridX = math.floor(pos.X / 4.5 + 0.5)
        local gridY = math.floor(pos.Y / 4.5 + 0.5)
        pcall(function()
            RemotesList.WorldSetTileHit:FireServer(gridX, gridY)
        end)
    end
end)

-- ==============================================
-- TAB 5: ESP
-- ==============================================
local ESPTab = Window:NewTab("ESP")
local ESPSection = ESPTab:NewSection("Growscan")

ESPSection:NewButton("Scan Saplings", "Highlight nearby saplings", function()
    local pos = Character.HumanoidRootPart.Position
    for x = -30, 30 do
        for y = -30, 30 do
            local gridX = math.floor((pos.X / 4.5 + 0.5) + x)
            local gridY = math.floor((pos.Y / 4.5 + 0.5) + y)

            local success, tile = pcall(function()
                return RemotesList.RequestWorldTiles:InvokeServer(gridX, gridY)
            end)

            if success and tile and string.sub(tostring(tile), -8) == "_sapling" then
                local part = Instance.new("Part")
                part.Size = Vector3.new(4, 4, 4)
                part.Position = Vector3.new(gridX * 4.5, gridY * 4.5, 0)
                part.Anchored = true
                part.CanCollide = false
                part.Transparency = 0.5
                part.BrickColor = BrickColor.new("Bright green")
                part.Material = Enum.Material.Neon
                part.Parent = workspace

                game:GetService("Debris"):AddItem(part, 5)
            end
        end
        task.wait()
    end
end)

-- ==============================================
-- MAIN FARMING LOOP
-- ==============================================
spawn(function()
    while task.wait(0.05) do
        if not Character or not Character:FindFirstChild("HumanoidRootPart") then
            Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
            Humanoid = Character:WaitForChild("Humanoid")
        end

        local rootPos = Character.HumanoidRootPart.Position
        local playerGridX = math.floor(rootPos.X / 4.5 + 0.5)
        local playerGridY = math.floor(rootPos.Y / 4.5 + 0.5)

        -- Auto Plant (only if a sapling is selected)
        if Settings.AutoPlant and Settings.SelectedSapling ~= "NONE" and Mouse.Hit then
            local mousePos = Mouse.Hit.p
            local gridX = math.floor(mousePos.X / 4.5 + 0.5)
            local gridY = math.floor(mousePos.Y / 4.5 + 0.5)

            if math.abs(gridX - playerGridX) <= 2 and math.abs(gridY - playerGridY) <= 2 then
                pcall(function()
                    RemotesList.WorldSetTile:FireServer(gridX, gridY, Settings.SelectedSapling, {})
                    RemotesList.PlayerPlaceItem:FireServer(gridX, gridY, Settings.SelectedSapling)
                end)
                task.wait(Settings.PlantInterval)
            end
        end

        -- Auto Harvest/Break
        if Settings.AutoHarvest or (Settings.AutoBreak and Settings.SelectedBlock ~= "NONE") then
            for x = -Settings.Radius, Settings.Radius do
                for y = -Settings.Radius, Settings.Radius do
                    local targetX = playerGridX + x
                    local targetY = playerGridY + y

                    local success, tileInfo = pcall(function()
                        return RemotesList.RequestWorldTiles:InvokeServer(targetX, targetY)
                    end)

                    if success and tileInfo then
                        -- Auto Harvest (all saplings)
                        if Settings.AutoHarvest and string.sub(tostring(tileInfo), -8) == "_sapling" then
                            pcall(function()
                                RemotesList.WorldSetTileHit:FireServer(targetX, targetY)
                                RemotesList.PlayerFist:FireServer(targetX, targetY)
                            end)
                            task.wait(Settings.HarvestInterval)
                        end

                        -- Auto Break (only selected block)
                        if Settings.AutoBreak and Settings.SelectedBlock ~= "NONE" and tostring(tileInfo) == Settings.SelectedBlock then
                            pcall(function()
                                RemotesList.WorldSetTileHit:FireServer(targetX, targetY)
                            end)
                            task.wait(Settings.BreakInterval)
                        end
                    end
                end
            end
        end

        -- Update speed/jump each tick
        if Humanoid then
            Humanoid.WalkSpeed = Settings.Speed
            Humanoid.JumpPower = Settings.JumpPower
        end
    end
end)

-- Auto refresh on first load
task.wait(1)
RefreshInventoryItems()

print("[" .. SCRIPT_NAME .. "] Loaded successfully!")
print("[✓] Click 'Refresh Backpack' to load items from inventory")
