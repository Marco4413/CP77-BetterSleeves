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
    rollDownDelay = 1.0,
    rollDownItemBlacklist = {
        ["outfit_01__q305__hazmat_"] = true,
        ["outfit_01__q303__diving_suit_ow_helmet_"] = true,
    },
    rollDownWeaponBlacklist = {
        ["mantis_blade"] = true,
        ["projectile_launcher"] = true,
    },
    SlotToAreaType = {}, -- Populated within Event_OnInit
    _newItem = "",
    _newWeapon = "",
}

function BetterSleeves:SaveConfig()
    local file = io.open("data/config.json", "w")
    file:write(json.encode({
        autoRoll = self.autoRoll,
        rollDownDelay = self.rollDownDelay,
        rollDownItemBlacklist = self.rollDownItemBlacklist,
        rollDownWeaponBlacklist = self.rollDownWeaponBlacklist,
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

        if (type(config.rollDownDelay) == "number") then
            self.rollDownDelay = config.rollDownDelay
        end

        if (type(config.rollDownItemBlacklist) == "table") then
            self.rollDownItemBlacklist = config.rollDownItemBlacklist
        end

        if (type(config.rollDownWeaponBlacklist) == "table") then
            self.rollDownWeaponBlacklist = config.rollDownWeaponBlacklist
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
                for slot, at in next, self.SlotToAreaType do
                    if areaType == at then
                        table.insert(slots, slot)
                        break
                    end
                end
            end
        end
    else
        for slot in next, self.SlotToAreaType do
            table.insert(slots, slot)
        end
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
    for slot in next, self.SlotToAreaType do
        self:ChangeItemPOV(slot, true)
    end
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
    BetterSleeves.delayTimer = BetterSleeves.rollDownDelay
    BetterSleeves.delayCallback = function ()
        BetterSleeves:RollDownSleeves()
    end
end

local function Event_OnInit()
    BetterSleeves:LoadConfig()

    BetterSleeves.SlotToAreaType["AttachmentSlots.Outfit"] = gamedataEquipmentArea.Outfit
    BetterSleeves.SlotToAreaType["AttachmentSlots.Torso"] = gamedataEquipmentArea.OuterChest
    BetterSleeves.SlotToAreaType["AttachmentSlots.Chest"] = gamedataEquipmentArea.InnerChest

    -- Equipment-EX Slots
    BetterSleeves.SlotToAreaType["OutfitSlots.TorsoOuter"] = {}
    BetterSleeves.SlotToAreaType["OutfitSlots.TorsoMiddle"] = {}
    BetterSleeves.SlotToAreaType["OutfitSlots.TorsoInner"] = {}
    BetterSleeves.SlotToAreaType["OutfitSlots.TorsoUnder"] = {}
    BetterSleeves.SlotToAreaType["OutfitSlots.BodyOuter"] = {}
    BetterSleeves.SlotToAreaType["OutfitSlots.BodyMiddle"] = {}
    BetterSleeves.SlotToAreaType["OutfitSlots.BodyInner"] = {}
    BetterSleeves.SlotToAreaType["OutfitSlots.BodyUnder"] = {}

    ObserveBefore("PlayerPuppet", "OnWeaponEquipEvent", Event_RollDownSleeves)
    ObserveAfter("PlayerPuppet", "OnItemAddedToSlot", Event_RollDownSleeves)
    -- ObserveAfter("PlayerPuppet", "OnItemRemovedFromSlot", Event_RollDownSleeves)
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

        BetterSleeves.autoRoll = ImGui.Checkbox("Auto-Roll", BetterSleeves.autoRoll)
        if BetterSleeves.autoRoll then
            BetterSleeves.rollDownDelay = ImGui.DragFloat("Roll Down Delay", BetterSleeves.rollDownDelay, 0.01, 1, 5, "%.2f")
        end

        if ImGui.CollapsingHeader("Item Blacklist") then
            ImGui.PushID("item-blacklist")
            if ImGui.Button("+") then
                BetterSleeves.rollDownItemBlacklist[BetterSleeves._newItem] = true
                BetterSleeves._newItem = ""
            end
            ImGui.SameLine()
            BetterSleeves._newItem = ImGui.InputText("", BetterSleeves._newItem, 256)

            for item in next, BetterSleeves.rollDownItemBlacklist do
                ImGui.PushID(table.concat{ "item-blacklist_", item })
                if ImGui.Button("-") then
                    BetterSleeves.rollDownItemBlacklist[item] = nil
                end
                ImGui.SameLine()
                ImGui.Text(item)
                ImGui.PopID()
            end
            ImGui.PopID()
        end

        if ImGui.CollapsingHeader("Weapon Blacklist") then
            ImGui.PushID("weapon-blacklist")
            if ImGui.Button("+") then
                BetterSleeves.rollDownWeaponBlacklist[BetterSleeves._newWeapon] = true
                BetterSleeves._newWeapon = ""
            end
            ImGui.SameLine()
            BetterSleeves._newWeapon = ImGui.InputText("", BetterSleeves._newWeapon, 256)

            for weapon in next, BetterSleeves.rollDownWeaponBlacklist do
                ImGui.PushID(table.concat{ "weapon-blacklist_", weapon })
                if ImGui.Button("-") then
                    BetterSleeves.rollDownWeaponBlacklist[weapon] = nil
                end
                ImGui.SameLine()
                ImGui.Text(weapon)
                ImGui.PopID()
            end
            ImGui.PopID()
        end

        BetterSleeves.showDebugUI = ImGui.Checkbox("Show Debug Info", BetterSleeves.showDebugUI)
        if BetterSleeves.showDebugUI then
            for slot in next, BetterSleeves.SlotToAreaType do
                local item = BetterSleeves:GetItem(slot)
                if item then
                    local itemName = BetterSleeves:GetItemAppearanceName(item):match("[^&]+")
                    ImGui.PushID(table.concat{ "slot-debug_", slot })
                    ImGui.Text(table.concat { slot:match("%.(.+)"), " Item: ", itemName })
                    ImGui.SameLine()
                    if ImGui.Button("Blacklist") then
                        BetterSleeves.rollDownItemBlacklist[itemName] = true
                    end
                    ImGui.PopID()
                end
            end

            local player = Game.GetPlayer()
            if player then
                local weapon = player:GetActiveWeapon()
                if weapon then
                    local weaponName = weapon:GetWeaponRecord():FriendlyName()
                    ImGui.PushID("weapon-debug")
                    ImGui.Text("Weapon Name: " .. weaponName)
                    ImGui.SameLine()
                    if ImGui.Button("Blacklist") then
                        BetterSleeves.rollDownWeaponBlacklist[weaponName] = true
                    end
                    ImGui.PopID()
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
