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
    rollDownItemBlacklist = {},
    rollDownWeaponBlacklist = {},
    rollDownMissionBlacklist = {},
    SlotToAreaType = {}, -- Populated within Event_OnInit
    _newItem = "",
    _newWeapon = "",
    _newMission = "",
}

function BetterSleeves:ResetConfig()
    self.autoRoll = true
    self.rollDownDelay = 1.0
    self.rollDownItemBlacklist = {}
    self.rollDownWeaponBlacklist = {}
    -- Add all blacklist entries
    self:MigrateConfigFromVersion(nil)
end

function BetterSleeves:SaveConfig()
    local file = io.open("data/config.json", "w")
    file:write(json.encode({
        version = 2,
        autoRoll = self.autoRoll,
        rollDownDelay = self.rollDownDelay,
        rollDownItemBlacklist = self.rollDownItemBlacklist,
        rollDownWeaponBlacklist = self.rollDownWeaponBlacklist,
    }))
    io.close(file)
end

function BetterSleeves:MigrateConfigFromVersion(version)
    if not version then
        -- Migrate from version 0 to 1
        version = 1
        self.rollDownItemBlacklist["outfit_01__q305__hazmat_"] = true
        self.rollDownItemBlacklist["outfit_01__q303__diving_suit_"] = true
        self.rollDownItemBlacklist["outfit_01__q303__diving_suit_ow_helmet_"] = true
        self.rollDownItemBlacklist["outfit_02_sq029_police_suit_"] = true
        self.rollDownItemBlacklist["outfit_02_sq030_diving_suit_"] = true
        self.rollDownItemBlacklist["outfit_02_q101_recovery_bandage_"] = true
        self.rollDownWeaponBlacklist["mantis_blade"] = true
        self.rollDownWeaponBlacklist["projectile_launcher"] = true
    end

    if version <= 1 then
        version = 2
        self.rollDownItemBlacklist["empty_appearance_default"] = true
        self.rollDownItemBlacklist["t2_jacket_21_edgerunners_01_"] = true
    end

    -- Migrate from version x to latest
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

        self:MigrateConfigFromVersion(config.version)
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
    MissionBlacklisted = 5,
}

BetterSleeves.POVChangeResult = POVChangeResult

function BetterSleeves:GetTrackedMissionAndObjectiveIds()
    local journal = Game.GetJournalManager()

    -- gameJournalQuestObjective[ id:02_meet_hanako ]
    local obj = journal:GetTrackedEntry()
    if not obj then return; end

    -- gameJournalQuestPhase[ id:q115 ]
    local phase = journal:GetParentEntry(obj)
    if not phase then return; end

    -- gameJournalQuest[ id:02_sickness ]
    local quest = journal:GetParentEntry(phase)
    if not quest then return; end

    return quest.id, obj.id
end

---@param str string
---@param sep string
---@param n number|nil
---@return table
function BetterSleeves.StringSplit(str, sep, n)
    if n == 0 then return {str}; end
    local split = {}
    local index = 1
    while true do
        local st, en = str:find(sep, index, true)
        if not st then
            table.insert(split, str:sub(index))
            break
        end

        table.insert(split, str:sub(index, st-1))
        index = en + 1

        if n then
            n = n - 1
            if n <= 0 then
                table.insert(split, str:sub(index))
                break
            end
        end
    end
    return split
end

---@param itemName string
---@param oldCamera string
---@param newCamera string
---@return string
---@return boolean
function BetterSleeves.ReplaceCameraSuffix(itemName, oldCamera, newCamera)
    local nameAndSuffixes = BetterSleeves.StringSplit(itemName, "&", 3)
    local cameraIndex = 2
    if nameAndSuffixes[2] and (
        nameAndSuffixes[2] == "Male" or
        nameAndSuffixes[2] == "Female") then
        cameraIndex = 3
    end

    if nameAndSuffixes[cameraIndex] == newCamera then
        return itemName, false
    elseif nameAndSuffixes[cameraIndex] == oldCamera then
        nameAndSuffixes[cameraIndex] = newCamera
        return table.concat(nameAndSuffixes, "&"), true
    end

    table.insert(nameAndSuffixes, cameraIndex, newCamera)
    return table.concat(nameAndSuffixes, "&"), true
end

---@param slot string
---@param fpp boolean
---@param itemBlacklist table
---@param weaponBlacklist table
---@param missionBlacklist table
---@return POVChangeResult
function BetterSleeves:ChangeItemPOV(slot, fpp, itemBlacklist, weaponBlacklist, missionBlacklist)
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

    if missionBlacklist then
        local quest, obj = self:GetTrackedMissionAndObjectiveIds()
        if quest and (
            missionBlacklist[table.concat{quest, ".*"}] or
            missionBlacklist[table.concat{quest, ".", obj}]
        ) then
            return POVChangeResult.MissionBlacklisted
        end
    end

    local newItemName, changed;
    if fpp then
        newItemName, changed = self.ReplaceCameraSuffix(itemName, "TPP", "FPP")
    else
        newItemName, changed = self.ReplaceCameraSuffix(itemName, "FPP", "TPP")
    end
    if not changed then return POVChangeResult.SamePOV; end

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
        local weaponBlacklist = self.rollDownWeaponBlacklist
        local missionBlacklist = self.rollDownMissionBlacklist
        for _, slot in next, slots do
            local res = self:ChangeItemPOV(slot, false, self.rollDownItemBlacklist, weaponBlacklist, missionBlacklist)
            if (res == POVChangeResult.Changed or
                res == POVChangeResult.SamePOV) then
                -- If res is in a "not blacklisted state" then weapon and mission blacklist don't have to be checked again.
                weaponBlacklist = nil
                missionBlacklist = nil
            elseif (res == POVChangeResult.WeaponBlacklisted or
                res == POVChangeResult.MissionBlacklisted) then
                self:RollUpSleeves()
                return
            elseif res == POVChangeResult.ItemBlacklisted then
                self:RollUpSleevesForSlot(slot)
            end
        end
    end
end

---@param slot string
function BetterSleeves:RollUpSleevesForSlot(slot)
    self:ChangeItemPOV(slot, true, { ["empty_appearance_default"] = true })
end

function BetterSleeves:RollUpSleeves()
    local player = Game.GetPlayer()
    if not player then return; end

    self.rolledDown = false
    for slot in next, self.SlotToAreaType do
        self:RollUpSleevesForSlot(slot)
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
    BetterSleeves:ResetConfig() -- Loads default settings
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
    ObserveAfter("JournalManager", "OnQuestEntryTracked", Event_RollDownSleeves)
    ObserveAfter("JournalManager", "OnQuestEntryUntracked", Event_RollDownSleeves)
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

        if ImGui.CollapsingHeader("Mission Blacklist") then
            ImGui.PushID("mission-blacklist")
            if ImGui.Button("+") then
                BetterSleeves.rollDownMissionBlacklist[BetterSleeves._newMission] = true
                BetterSleeves._newMission = ""
            end
            ImGui.SameLine()
            BetterSleeves._newMission = ImGui.InputText("", BetterSleeves._newMission, 512)

            for mission in next, BetterSleeves.rollDownMissionBlacklist do
                ImGui.PushID(table.concat{ "mission-blacklist_", mission })
                if ImGui.Button("-") then
                    BetterSleeves.rollDownMissionBlacklist[mission] = nil
                end
                ImGui.SameLine()
                ImGui.Text(mission)
                ImGui.PopID()
            end
            ImGui.PopID()
        end

        if ImGui.Button("Reload Config") then
            BetterSleeves:LoadConfig()
        end

        if ImGui.Button("Save Config") then
            BetterSleeves:SaveConfig()
        end

        if ImGui.Button("Reset Config") then
            BetterSleeves:ResetConfig()
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

            local quest, obj = BetterSleeves:GetTrackedMissionAndObjectiveIds()
            if quest then
                ImGui.PushID("quest-debug")
                ImGui.Text("Quest ID: " .. quest)
                ImGui.SameLine()
                if ImGui.Button("Blacklist") then
                    BetterSleeves.rollDownMissionBlacklist[table.concat{quest, ".*"}] = true
                end
                ImGui.PopID()

                ImGui.PushID("objective-debug")
                ImGui.Text("Objective ID: " .. obj)
                ImGui.SameLine()
                if ImGui.Button("Blacklist") then
                    BetterSleeves.rollDownMissionBlacklist[table.concat{quest, ".", obj}] = true
                end
                ImGui.PopID()
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
