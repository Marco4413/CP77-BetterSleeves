--[[
Copyright (c) 2023 [Marco4413](https://github.com/Marco4413/CP77-BetterSleeves)

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
]]

local BetterSleeves = {
    autoRoll = true,
    showUI = false,
    showDebugUI = false,
    delayTimer = 1.0,
    delayCallback = nil,
    rolledDown = false,
    rollDownItemBlacklist = {},
    rollDownWeaponBlacklist = {
        ["mantis_blade"] = true,
        ["projectile_launcher"] = true,
    },
}

function BetterSleeves:SaveConfig()
    local file = io.open("data/config.json", "w")
    file:write(json.encode({
        autoRoll = self.autoRoll,
    }))
    io.close(file)
end

function BetterSleeves:LoadConfig()
    local ok = pcall(function ()
        local file = io.open("data/config.json", "r")
        local configText = file:read("*a")
        io.close(file)

        local config = json.decode(configText)
        if not config then return; end

        if (type(config.autoRoll) == "boolean") then
            self.autoRoll = config.autoRoll
        end
    end)
    if (not ok) then self:SaveConfig(); end
end

---@param item gameItemObject
---@return string|nil
function BetterSleeves:GetItemAppearanceName(item)
    local player = Game.GetPlayer()
    if not player then return nil; end
    local tSys = Game.GetTransactionSystem()
    local itemApp = tSys:GetItemAppearance(player, item:GetItemID())
    return itemApp and itemApp.value or nil
end

---@param slot string
---@return gameItemObject|nil
function BetterSleeves:GetItem(slot)
    local player = Game.GetPlayer()
    if not player then return nil; end
    local tSys = Game.GetTransactionSystem()
    local item = tSys:GetItemInSlot(player, slot)
    return item    
end

---@enum POVChangeResult
local POVChangeResult = {
    Changed = 0,
    NoItem = 1,
    SamePOV = 2,
    ItemBlacklisted = 3,
    WeaponBlacklisted = 4,
}

BetterSleeves.POVChangeResult = POVChangeResult

---@param slot string
---@param fpp boolean
---@param itemBlacklist table
---@param weaponBlacklist table
---@return POVChangeResult
function BetterSleeves:ChangeItemPOV(slot, fpp, itemBlacklist, weaponBlacklist)
    local item = self:GetItem(slot)
    if not item then return POVChangeResult.NoItem; end

    local itemName = self:GetItemAppearanceName(item)
    -- itemBlacklist contains names without attributes
    if itemBlacklist and itemBlacklist[itemName:match("[^&]+")] then return POVChangeResult.ItemBlacklisted; end

    -- Don't need to nil-check because of valid item
    local player = Game.GetPlayer()
    local tSys = Game.GetTransactionSystem()
    if weaponBlacklist then
        local weapon = player:GetActiveWeapon()
        if weapon then
            local weaponName = weapon:GetWeaponRecord():FriendlyName()
            if weaponBlacklist[weaponName] then return POVChangeResult.WeaponBlacklisted; end
        end
    end

    local newItemName, n;
    if fpp then
        newItemName, n = itemName:gsub("&TPP", "&FPP")
    else
        newItemName, n = itemName:gsub("&FPP", "&TPP")
    end
    if n == 0 then return POVChangeResult.SamePOV; end

    tSys:ChangeItemAppearanceByName(player, item:GetItemID(), newItemName)
    return POVChangeResult.Changed
end

---@param force boolean
function BetterSleeves:RollDownSleeves(force)
    local player = Game.GetPlayer()
    if not player then return; end
    
    self.rolledDown = true

    local slots = {}
    local activeClothing = Game.GetWardrobeSystem():GetActiveClothingSet()
    if activeClothing then
        local clothes = activeClothing.clothingList
        for i=1, #clothes do
            local item = TweakDB:GetRecord(clothes[i].visualItem.id)
            if item then
                local areaType = clothes[i].areaType
                if areaType == gamedataEquipmentArea.Outfit then
                    table.insert(slots, "AttachmentSlots.Outfit")
                elseif areaType == gamedataEquipmentArea.OuterChest then
                    table.insert(slots, "AttachmentSlots.Torso")
                elseif areaType == gamedataEquipmentArea.InnerChest then
                    table.insert(slots, "AttachmentSlots.Chest")
                end
            end
        end
    else
        slots = { "AttachmentSlots.Chest", "AttachmentSlots.Torso", "AttachmentSlots.Outfit" }
    end

    if force then
        for _, slot in next, slots do
            self:ChangeItemPOV(slot, false)
        end
    else
        for _, slot in next, slots do
            local res = self:ChangeItemPOV(slot, false, self.rollDownItemBlacklist, self.rollDownWeaponBlacklist)
            if res == POVChangeResult.WeaponBlacklisted then
                self:RollUpSleeves()
                return
            elseif res == POVChangeResult.ItemBlacklisted then
                self:ChangeItemPOV(slot, true)
            end
        end
    end
end

function BetterSleeves:RollUpSleeves()
    local player = Game.GetPlayer()
    if not player then return; end

    self.rolledDown = false
    self:ChangeItemPOV("AttachmentSlots.Chest", true)
    self:ChangeItemPOV("AttachmentSlots.Torso", true)
    self:ChangeItemPOV("AttachmentSlots.Outfit", true)
end

---@param force boolean
function BetterSleeves:ToggleSleeves(force)
    if self.rolledDown then
        self:RollUpSleeves()
    else
        self:RollDownSleeves(force)
    end
end

local function Event_RollDownSleeves()
    if not BetterSleeves.autoRoll then return; end
    BetterSleeves.delayTimer = 1
    BetterSleeves.delayCallback = function ()
        BetterSleeves:RollDownSleeves()
    end
end

local function Event_OnInit()
    BetterSleeves:LoadConfig()

    ObserveBefore("PlayerPuppet", "OnWeaponEquipEvent", Event_RollDownSleeves)
    ObserveAfter("PlayerPuppet", "OnItemAddedToSlot", Event_RollDownSleeves)
    ObserveAfter("PlayerPuppet", "OnItemRemovedFromSlot", Event_RollDownSleeves)
    ObserveAfter("PlayerPuppet", "OnMakePlayerVisibleAfterSpawn", Event_RollDownSleeves)
    ObserveAfter("VehicleComponent", "OnVehicleCameraChange", Event_RollDownSleeves)
end

local function Event_OnUpdate(dt)
    if BetterSleeves.delayTimer <= 0 or not BetterSleeves.delayCallback then return; end

    BetterSleeves.delayTimer = BetterSleeves.delayTimer - dt
    if BetterSleeves.delayTimer <= 0 then
        BetterSleeves.delayCallback()
        BetterSleeves.delayCallback = nil
    end
end

local function Event_OnShutdown()
    BetterSleeves:SaveConfig()
end

local function Event_OnDraw()
    if not BetterSleeves.showUI then return; end
    if ImGui.Begin("Better Sleeves") then
        if ImGui.Button("Roll Down Sleeves") then
            BetterSleeves:RollDownSleeves()
        end

        if ImGui.Button("Roll Up Sleeves") then
            BetterSleeves:RollUpSleeves()
        end

        BetterSleeves.updateInterval = ImGui.DragFloat("Update Interval (Auto-Roll)", BetterSleeves.updateInterval, 0.01, 1, 3600, "%.2f")
        BetterSleeves.autoRoll = ImGui.Checkbox("Auto-Roll", BetterSleeves.autoRoll)

        BetterSleeves.showDebugUI = ImGui.Checkbox("Show Debug Info", BetterSleeves.showDebugUI)
        if BetterSleeves.showDebugUI then
            local chest = BetterSleeves:GetItem("AttachmentSlots.Chest")
            if chest then
                local name = BetterSleeves:GetItemAppearanceName(chest)
                ImGui.Text("Chest Item: " .. name:match("[^&]+"))
            end

            local torso = BetterSleeves:GetItem("AttachmentSlots.Torso")
            if torso then
                local name = BetterSleeves:GetItemAppearanceName(torso)
                ImGui.Text("Torso Item: " .. name:match("[^&]+"))
            end

            local outfit = BetterSleeves:GetItem("AttachmentSlots.Outfit")
            if outfit then
                local name = BetterSleeves:GetItemAppearanceName(outfit)
                ImGui.Text("Outfit Item: " .. name:match("[^&]+"))
            end

            local player = Game.GetPlayer()
            if player then
                local weapon = player:GetActiveWeapon()
                if weapon then
                    local weaponName = weapon:GetWeaponRecord():FriendlyName()
                    ImGui.Text("Weapon Name: " .. weaponName)
                end
            end
        end
    end
end

local function Event_OnOverlayOpen()
    BetterSleeves.showUI = true
end

local function Event_OnOverlayClose()
    BetterSleeves.showUI = false
end

function BetterSleeves:Init()
    registerHotkey("rolldown_sleeves", "Roll Down Sleeves", function () self:RollDownSleeves(false) end)
    registerHotkey("rollup_sleeves"  , "Roll Up Sleeves"  , function () self:RollUpSleeves()        end)
    registerHotkey("toggle_sleeves"  , "Toggle Sleeves"   , function () self:ToggleSleeves(false)   end)
    registerHotkey("force_rolldown_sleeves", "Force Roll Down Sleeves", function () self:RollDownSleeves(true) end)
    registerHotkey("force_rollup_sleeves"  , "Force Roll Up Sleeves"  , function () self:RollUpSleeves()       end)
    registerHotkey("force_toggle_sleeves"  , "Force Toggle Sleeves"   , function () self:ToggleSleeves(true)   end)

    registerForEvent("onInit", Event_OnInit)
    registerForEvent("onUpdate", Event_OnUpdate)
    registerForEvent("onShutdown", Event_OnShutdown)
    registerForEvent("onDraw", Event_OnDraw)
    registerForEvent("onOverlayOpen", Event_OnOverlayOpen)
    registerForEvent("onOverlayClose", Event_OnOverlayClose)
    return self
end

return BetterSleeves:Init()
