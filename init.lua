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
    timer = 0.0,
    updateInterval = 4.0,
    rolledDown = false,
    rollDownItemBlacklist = {},
    rollDownWeaponBlacklist = {
        ["mantis_blade"] = true
    },
}

function BetterSleeves:SaveConfig()
    local file = io.open("data/config.json", "w")
    file:write(json.encode({
        autoRoll = self.autoRoll,
        updateInterval = self.updateInterval,
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

        if (type(config.updateInterval) == "number") then
            self.updateInterval = config.updateInterval
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
    self.rolledDown = true
    if force then
        self:ChangeItemPOV("AttachmentSlots.Chest", false)
        self:ChangeItemPOV("AttachmentSlots.Torso", false)
        self:ChangeItemPOV("AttachmentSlots.Outfit", false)
    else
        local chest = self:ChangeItemPOV("AttachmentSlots.Chest", false, self.rollDownItemBlacklist, self.rollDownWeaponBlacklist)
        if chest == POVChangeResult.WeaponBlacklisted then
            self:RollUpSleeves()
            return
        elseif chest == POVChangeResult.ItemBlacklisted then
            self:ChangeItemPOV("AttachmentSlots.Chest", true)
        end

        -- Checking for POVChangeResult.WeaponBlacklisted because POVChangeResult.NoItem returns early
        local torso = self:ChangeItemPOV("AttachmentSlots.Torso", false, self.rollDownItemBlacklist, self.rollDownWeaponBlacklist)
        if torso == POVChangeResult.WeaponBlacklisted then
            self:RollUpSleeves()
            return
        elseif torso == POVChangeResult.ItemBlacklisted then
            self:ChangeItemPOV("AttachmentSlots.Torso", true)
        end


        local outfit = self:ChangeItemPOV("AttachmentSlots.Outfit", false, self.rollDownItemBlacklist, self.rollDownWeaponBlacklist)
        if outfit == POVChangeResult.WeaponBlacklisted then
            self:RollUpSleeves()
            return
        elseif outfit == POVChangeResult.ItemBlacklisted then
            self:ChangeItemPOV("AttachmentSlots.Outfit", true)
        end
    end
end

function BetterSleeves:RollUpSleeves()
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

local function Event_OnUpdate(dt)
    if BetterSleeves.autoRoll and Game.GetPlayer() then
        BetterSleeves.timer = BetterSleeves.timer + dt
        if (BetterSleeves.timer >= BetterSleeves.updateInterval) then
            BetterSleeves.timer = 0.0

            local photoMode = Game.GetPhotoModeSystem()
            if not photoMode:IsPhotoModeActive() then
                BetterSleeves:RollDownSleeves()
            end 
        end

    end
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
    registerForEvent("onUpdate", Event_OnUpdate)
    registerForEvent("onDraw", Event_OnDraw)
    registerForEvent("onOverlayOpen", Event_OnOverlayOpen)
    registerForEvent("onOverlayClose", Event_OnOverlayClose)
    return self
end

return BetterSleeves:Init()
