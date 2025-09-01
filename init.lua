--[[
Copyright (c) 2025 [Marco4413](https://github.com/Marco4413/CP77-BetterSleeves)

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

local BetterUI = require "BetterUI"
local Scheduler = require "Scheduler"

local BetterSleeves = {
    autoRoll = true,
    autoRollDelay = 1.0,
    autoRollOnVehiclesTPP = false,
    autoRollVehiclesDelay = 1.0,
    syncInventoryPuppet = true,
    syncInventoryPuppetDelay = 1.0,
    showUI = false,
    scheduler = Scheduler.New(),
    forceKeepRolledDown = false,
    keepRolledDown = true,
    rollDownItemBlacklist = {},
    rollDownWeaponBlacklist = {},
    rollDownMissionBlacklist = {},
    slotsToRoll = {},
    SlotType = {
        USER_DEFINED = 0,
        VANILLA = 1,
        EQUIPMENT_EX = 2,
    },
    _newItem = "",
    _newWeapon = "",
    _newMission = "",
    _newSlot = "",
    slotToAreaType = {},
    _configInitialized = false,
    -- Populated within Event_OnInit

    ---Deprecated: See BetterSleeves:HasCameraAppearanceSuffix()
    appearanceSuffixCameraRecord = nil,
    gorillaArmsWeaponName = "w_strong_arms",
    gorillaArmsRollUpOnDoorOpen = true,
    gorillaArmsRollDownDelay = 3.15,
    _inventoryPuppet = nil,
    _photoPuppet = nil,
}

function BetterSleeves.Log(...)
    print(table.concat{"[ ", os.date("%x %X"), " ][ BetterSleeves ]: ", ...})
end

BetterSleeves.scheduler:SetLogger(BetterSleeves.Log)

function BetterSleeves:DetectEquipmentExAndEnableSlots()
    if EquipmentEx then
        -- Equipment-EX Slots
        for _, slot in next, self.slotsToRoll do
            if slot.type == self.SlotType.EQUIPMENT_EX then
                slot.enabled = true
                slot.userHandled = false
            end
        end
        return true
    end
    return false
end

function BetterSleeves:ResetConfig()
    local eqExInstalled = EquipmentEx and true or false
    self.autoRoll = true
    self.autoRollDelay = 1.0
    self.autoRollOnVehiclesTPP = false
    self.autoRollVehiclesDelay = 1.0
    self.syncInventoryPuppet = true
    self.syncInventoryPuppetDelay = 1.0
    self.forceKeepRolledDown = false
    self.keepRolledDown = true
    self.rollDownItemBlacklist = {}
    self.rollDownWeaponBlacklist = {}
    self.rollDownMissionBlacklist = {}
    self.slotsToRoll = {
        ["AttachmentSlots.Outfit"]  = { type = self.SlotType.VANILLA, enabled = true, userHandled = false },
        ["AttachmentSlots.Torso"]   = { type = self.SlotType.VANILLA, enabled = true, userHandled = false },
        ["AttachmentSlots.Chest"]   = { type = self.SlotType.VANILLA, enabled = true, userHandled = false },
        ["OutfitSlots.TorsoOuter"]  = { type = self.SlotType.EQUIPMENT_EX, enabled = eqExInstalled, userHandled = false },
        ["OutfitSlots.TorsoMiddle"] = { type = self.SlotType.EQUIPMENT_EX, enabled = eqExInstalled, userHandled = false },
        ["OutfitSlots.TorsoInner"]  = { type = self.SlotType.EQUIPMENT_EX, enabled = eqExInstalled, userHandled = false },
        ["OutfitSlots.TorsoUnder"]  = { type = self.SlotType.EQUIPMENT_EX, enabled = eqExInstalled, userHandled = false },
        ["OutfitSlots.TorsoAux"]    = { type = self.SlotType.EQUIPMENT_EX, enabled = eqExInstalled, userHandled = false },
        ["OutfitSlots.BodyOuter"]   = { type = self.SlotType.EQUIPMENT_EX, enabled = eqExInstalled, userHandled = false },
        ["OutfitSlots.BodyMiddle"]  = { type = self.SlotType.EQUIPMENT_EX, enabled = eqExInstalled, userHandled = false },
        ["OutfitSlots.BodyInner"]   = { type = self.SlotType.EQUIPMENT_EX, enabled = eqExInstalled, userHandled = false },
        ["OutfitSlots.BodyUnder"]   = { type = self.SlotType.EQUIPMENT_EX, enabled = eqExInstalled, userHandled = false },
    }
    self.gorillaArmsRollUpOnDoorOpen = true
    self.gorillaArmsRollDownDelay = 3.15
    -- Add all blacklist entries
    self:MigrateConfigFromVersion(nil)
end

function BetterSleeves:SaveConfig()
    local file = io.open("data/config.json", "w")

    local slotsToSave = { }
    for slotName, slot in next, self.slotsToRoll do
        if slot.type == self.SlotType.USER_DEFINED or slot.userHandled then
            slotsToSave[slotName] = slot
        end
    end

    file:write(json.encode({
        version = 5,
        autoRoll = self.autoRoll,
        autoRollDelay = self.autoRollDelay,
        autoRollOnVehiclesTPP = self.autoRollOnVehiclesTPP,
        autoRollVehiclesDelay = self.autoRollVehiclesDelay,
        syncInventoryPuppet = self.syncInventoryPuppet,
        syncInventoryPuppetDelay = self.syncInventoryPuppetDelay,
        forceKeepRolledDown = self.forceKeepRolledDown,
        keepRolledDown = self.keepRolledDown,
        rollDownItemBlacklist = self.rollDownItemBlacklist,
        rollDownWeaponBlacklist = self.rollDownWeaponBlacklist,
        rollDownMissionBlacklist = self.rollDownMissionBlacklist,
        slotsToRoll = slotsToSave,
        gorillaArmsRollUpOnDoorOpen = self.gorillaArmsRollUpOnDoorOpen,
        gorillaArmsRollDownDelay = self.gorillaArmsRollDownDelay,
    }))
    io.close(file)
end

function BetterSleeves:MigrateConfigFromVersion(version)
    if not version or type(version) ~= "number" then
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

    if version <= 2 then
        version = 3
        self.rollDownItemBlacklist["outfit_02__trauma_"] = true
    end

    if version <= 3 then
        version = 4
        for slotName, slotType in next, self.slotsToRoll do
            if type(slotType) == "number" then
                self.slotsToRoll[slotName] = { type = slotType, enabled = true }
            end
        end
    end

    if version <= 4 then
        version = 5
        self.autoRollVehiclesDelay = self.autoRollDelay
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

        if type(config.autoRoll) == "boolean" then
            self.autoRoll = config.autoRoll
        end

        if type(config.autoRollDelay) == "number" then
            self.autoRollDelay = config.autoRollDelay
        end

        if type(config.autoRollOnVehiclesTPP) == "boolean" then
            self.autoRollOnVehiclesTPP = config.autoRollOnVehiclesTPP
        end

        if type(config.autoRollVehiclesDelay) == "number" then
            self.autoRollVehiclesDelay = config.autoRollVehiclesDelay
        end

        if type(config.syncInventoryPuppet) == "boolean" then
            self.syncInventoryPuppet = config.syncInventoryPuppet
        end

        if type(config.syncInventoryPuppetDelay) == "number" then
            self.syncInventoryPuppetDelay = config.syncInventoryPuppetDelay
        end

        if type(config.forceKeepRolledDown) == "boolean" then
            self.forceKeepRolledDown = config.forceKeepRolledDown
        end

        if type(config.keepRolledDown) == "boolean" then
            self.keepRolledDown = config.keepRolledDown
        end

        if type(config.rollDownItemBlacklist) == "table" then
            self.rollDownItemBlacklist = config.rollDownItemBlacklist
        end

        if type(config.rollDownWeaponBlacklist) == "table" then
            self.rollDownWeaponBlacklist = config.rollDownWeaponBlacklist
        end

        if type(config.rollDownMissionBlacklist) == "table" then
            self.rollDownMissionBlacklist = config.rollDownMissionBlacklist
        end

        if type(config.slotsToRoll) == "table" then
            for slotName, slot in next, config.slotsToRoll do
                if type(slot) == "number" then
                    if slot == self.SlotType.USER_DEFINED and not self.slotsToRoll[slotName] then
                        self.slotsToRoll[slotName] = { type = slot, enabled = true }
                    end
                else -- Table
                    if slot.type == self.SlotType.USER_DEFINED then
                        self.slotsToRoll[slotName] = slot
                    elseif self.slotsToRoll[slotName] and self.slotsToRoll[slotName].type == slot.type then
                        self.slotsToRoll[slotName] = slot
                        self.slotsToRoll[slotName].userHandled = true
                    end
                end
            end
        end

        if type(config.gorillaArmsRollUpOnDoorOpen) == "boolean" then
            self.gorillaArmsRollUpOnDoorOpen = config.gorillaArmsRollUpOnDoorOpen
        end

        if type(config.gorillaArmsRollDownDelay) == "number" then
            self.gorillaArmsRollDownDelay = config.gorillaArmsRollDownDelay
        end

        self:MigrateConfigFromVersion(config.version)
    end)
    if not ok then self:SaveConfig(); end
end

---@param puppet gamePuppet
---@param item gameItemObject
---@return string|nil
function BetterSleeves:GetItemAppearanceName(puppet, item)
    if not puppet then return nil; end
    local tSys = Game.GetTransactionSystem()
    local itemApp = tSys:GetItemAppearance(puppet, item:GetItemID())
    return itemApp and itemApp.value or nil
end

---@param puppet gamePuppet
---@param slot string
---@return gameItemObject|nil
function BetterSleeves:GetItem(puppet, slot)
    if not puppet then return nil; end
    local tSys = Game.GetTransactionSystem()
    local item = tSys:GetItemInSlot(puppet, slot)
    return item    
end

---@enum POVChangeResult
local POVChangeResult = {
    Changed = 0,
    NoItem = 1,
    NoCameraSuffix = 2,
    SamePOV = 3,
    ---@deprecated
    ItemBlacklisted = 4,
    ---@deprecated
    WeaponBlacklisted = 5,
    ---@deprecated
    MissionBlacklisted = 6,
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

---@param checkWardrobe boolean|nil Whether to filter by active wardrobe slots (default: true)
---@return string[] slots The slots that need to be rolled
function BetterSleeves:GetActiveSlots(checkWardrobe)
    checkWardrobe = checkWardrobe == nil and true or checkWardrobe

    local wardrobeSystem = checkWardrobe  and Game.GetWardrobeSystem() or nil
    local activeClothing = wardrobeSystem and wardrobeSystem:GetActiveClothingSet() or nil

    local slots = {}
    if activeClothing then
        local clothes = activeClothing.clothingList
        for i=1, #clothes do
            local item = TweakDB:GetRecord(clothes[i].visualItem.id)
            if item then
                local areaType = clothes[i].areaType
                for slotName, at in next, self.slotToAreaType do
                    local slot = self.slotsToRoll[slotName]
                    if slot and slot.enabled and areaType == at then
                        table.insert(slots, slotName)
                        break
                    end
                end
            end
        end
    else
        for slotName, slot in next, self.slotsToRoll do
            if slot.enabled then
                table.insert(slots, slotName)
            end
        end
    end
    return slots
end

function BetterSleeves:GetInventoryPuppet()
    return self._inventoryPuppet
end

function BetterSleeves:GetPhotoPuppet()
    return self._photoPuppet
end

---@return gamePuppet[] puppets All puppets where sleeves need to be handled
function BetterSleeves:GetActivePuppets()
    local puppets = {Game.GetPlayer()}
    if self.syncInventoryPuppet then
        table.insert(puppets, self:GetInventoryPuppet())
    end
    return puppets
end

function BetterSleeves:SyncPuppetsPOV(puppetSrc, puppetDst, slot)
    local itemSrc = self:GetItem(puppetSrc, slot)
    if not itemSrc then return false; end
    local itemDst = self:GetItem(puppetDst, slot)
    if not itemDst then return false; end

    local appSrcName = self:GetItemAppearanceName(puppetSrc, itemSrc)
    if not appSrcName then self.Log("Failed to retrieve appearance name for source."); return false; end
    local isAppSrcTpp = appSrcName:find("&TPP", 1, true)
    
    local appDstName = self:GetItemAppearanceName(puppetDst, itemDst)
    if not appDstName then self.Log("Failed to retrieve appearance name for destination."); return false; end

    local hasChanged = false
    if isAppSrcTpp then
        appDstName, n = appDstName:gsub("&FPP", "&TPP")
        hasChanged = hasChanged or n > 0
    else
        appDstName, n = appDstName:gsub("&TPP", "&FPP")
        hasChanged = hasChanged or n > 0
    end
    
    if hasChanged then
        local transactionSystem = Game.GetTransactionSystem()
        transactionSystem:ChangeItemAppearanceByName(puppetDst, itemDst:GetItemID(), appDstName)
    end

    return hasChanged
end

---@param appName string
function BetterSleeves:HasCameraAppearanceSuffix(appName)
    return appName:find("&[FT]PP") and true or false
end

---Deprecated: Use :ChangeItemPOVForSlot() instead.
---@deprecated
---@param puppet gamePuppet
---@param slot string
---@param fpp boolean
---@param itemBlacklist table
---@param weaponBlacklist table
---@param missionBlacklist table
---@return POVChangeResult
function BetterSleeves:ChangeItemPOV(puppet, slot, fpp, itemBlacklist, weaponBlacklist, missionBlacklist)
    self.Log("Usage of deprecated function :ChangeItemPOV(), please use :ChangeItemPOVForSlot() instead.")
    local item = self:GetItem(puppet, slot)
    if not item then return POVChangeResult.NoItem; end

    -- Removed because some items returned false even though they have a Camera Suffix
    -- local itemRecord = TweakDB:GetRecord(item:GetItemID().id)
    -- if not itemRecord:AppearanceSuffixesContains(self.appearanceSuffixCameraRecord) then
    --     return POVChangeResult.NoCameraSuffix
    -- end

    local itemName = self:GetItemAppearanceName(puppet, item)
    if not self:HasCameraAppearanceSuffix(itemName) then
        return POVChangeResult.NoCameraSuffix
    end

    -- itemBlacklist contains names without attributes
    if itemBlacklist and itemBlacklist[itemName:match("[^&]+")] then return POVChangeResult.ItemBlacklisted; end

    if weaponBlacklist and puppet.GetActiveWeapon then
        local weapon = puppet:GetActiveWeapon()
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

    local newItemName, hasItemChanged
    if fpp then
        local n
        newItemName, n = itemName:gsub("&TPP", "&FPP")
        hasItemChanged = hasItemChanged or n > 0
    else
        local n
        newItemName, n = itemName:gsub("&FPP", "&TPP")
        hasItemChanged = hasItemChanged or n > 0
    end
    if not hasItemChanged then return POVChangeResult.SamePOV; end

    local tSys = Game.GetTransactionSystem()
    tSys:ChangeItemAppearanceByName(puppet, item:GetItemID(), newItemName)
    return POVChangeResult.Changed
end

---@param missionBlacklist table
---@return boolean
function BetterSleeves:IsMissionBlacklisted(missionBlacklist)
    local quest, obj = self:GetTrackedMissionAndObjectiveIds()
    if quest and (
        missionBlacklist[table.concat{quest, ".*"}] or
        missionBlacklist[table.concat{quest, ".", obj}]
    ) then
        return true
    end

    return false
end

---@param puppet gamePuppet
---@param weaponBlacklist table
---@return boolean
function BetterSleeves:IsWeaponBlacklisted(puppet, weaponBlacklist)
    local weapon = puppet:GetActiveWeapon()
    if weapon then
        local weaponName = weapon:GetWeaponRecord():FriendlyName()
        if weaponBlacklist[weaponName] then
            return true
        end
    end

    return false
end

---@param puppet gamePuppet
---@param slot string
---@param itemBlacklist table
---@return boolean
function BetterSleeves:IsItemInSlotBlacklisted(puppet, slot, itemBlacklist)
    if not itemBlacklist then return false; end

    local item = self:GetItem(puppet, slot)
    if not item then return false; end

    local itemName = self:GetItemAppearanceName(puppet, item)
    -- itemBlacklist contains names without attributes
    if itemBlacklist[itemName:match("[^&]+")] then
        return true
    end

    return false
end

---@param puppet gamePuppet
---@param slot string
---@param fpp boolean
---@return POVChangeResult
function BetterSleeves:ChangeItemPOVForSlot(puppet, slot, fpp)
    local item = self:GetItem(puppet, slot)
    if not item then return POVChangeResult.NoItem; end

    -- Removed because some items returned false even though they have a Camera Suffix
    -- local itemRecord = TweakDB:GetRecord(item:GetItemID().id)
    -- if not itemRecord:AppearanceSuffixesContains(self.appearanceSuffixCameraRecord) then
    --     return POVChangeResult.NoCameraSuffix
    -- end

    local itemName = self:GetItemAppearanceName(puppet, item)
    if not self:HasCameraAppearanceSuffix(itemName) then
        return POVChangeResult.NoCameraSuffix
    end

    local newItemName, hasItemChanged
    if fpp then
        local n
        newItemName, n = itemName:gsub("&TPP", "&FPP")
        hasItemChanged = hasItemChanged or n > 0
    else
        local n
        newItemName, n = itemName:gsub("&FPP", "&TPP")
        hasItemChanged = hasItemChanged or n > 0
    end
    if not hasItemChanged then return POVChangeResult.SamePOV; end

    local tSys = Game.GetTransactionSystem()
    tSys:ChangeItemAppearanceByName(puppet, item:GetItemID(), newItemName)
    return POVChangeResult.Changed
end

---@param force boolean
---@param puppets gamePuppet[]|nil
function BetterSleeves:RollDownSleeves(force, puppets)
    local slots = self:GetActiveSlots(true)
    local puppets = puppets or self:GetActivePuppets()
    if force then
        for _, puppet in next, puppets do
            for _, slot in next, slots do
                self:ChangeItemPOVForSlot(puppet, slot, false)
            end
        end
    else
        local missionBlacklist = self.rollDownMissionBlacklist
        local weaponBlacklist = self.rollDownWeaponBlacklist
        local itemBlacklist = self.rollDownItemBlacklist

        if self:IsMissionBlacklisted(missionBlacklist) then
            self:RollUpSleeves(false, puppets)
        else
            for _, puppet in next, puppets do
                if self:IsWeaponBlacklisted(puppet, weaponBlacklist) then
                    self:RollUpSleeves(false, {puppet})
                else
                    local isItemInSlotBlacklisted = {}
                    local areAllItemsBlacklisted  = true

                    for i, slot in next, slots do
                        table.insert(isItemInSlotBlacklisted, self:IsItemInSlotBlacklisted(puppet, slot, itemBlacklist))
                        if isItemInSlotBlacklisted[i] then
                            self:RollUpSleevesForSlot(slot, {puppet})
                        else
                            areAllBlacklisted = false
                        end
                    end

                    -- TODO: Figure out if swapping all items to TPP at the end fixes a reported issue.
                    if not areAllBlacklisted then
                        for i, slot in next, slots do
                            if not isItemInSlotBlacklisted[i] then
                                self:ChangeItemPOVForSlot(puppet, slot, false)
                            end
                        end
                    end
                end
            end
        end
    end
end

---@param slot string
---@param puppets gamePuppet[]|nil
function BetterSleeves:RollUpSleevesForSlot(slot, puppets)
    -- TODO: Deprecate this function?
    puppets = puppets or self:GetActivePuppets()
    for _, puppet in next, puppets do
        if not self:IsItemInSlotBlacklisted(puppet, slot, { ["empty_appearance_default"] = true }) then
            self:ChangeItemPOVForSlot(puppet, slot, true)
        end
    end
end

---@param all boolean
---@param puppets gamePuppet[]|nil
function BetterSleeves:RollUpSleeves(all, puppets)
    local player = Game.GetPlayer()
    if not player then return; end

    puppets = puppets or self:GetActivePuppets()
    for slotName, slot in next, self.slotsToRoll do
        -- TODO: Figure out why :GetActiveSlots() was not used here.
        --       Probably there was some bug that only happened when rolling down.
        if all or slot.enabled then
            self:RollUpSleevesForSlot(slotName, puppets)
        end
    end
end

function BetterSleeves:SyncKeepState()
    if self.keepRolledDown then
        self:RollDownSleeves(self.forceKeepRolledDown)
    else
        self:RollUpSleeves()
    end
end

---@param force boolean
---@param rollDown boolean|nil If nil, sleeves are toggled.
function BetterSleeves:ToggleSleeves(force, rollDown)
    self.forceKeepRolledDown = (force == true)
    self.keepRolledDown = (rollDown == nil) and (not self.keepRolledDown) or (rollDown == true)
    self:SyncKeepState()
end

local function AutoRollSleevesDelayedCB()
    if not BetterSleeves.autoRollOnVehiclesTPP then
        local player = Game.GetPlayer()
        if not player then return; end
    
        -- Handle Vehicles TPP
        local vehicle = player:GetMountedVehicle()
        if vehicle then
            local cameraManager = vehicle:GetCameraManager()
            if cameraManager and cameraManager:IsTPPActive() then
                return
            end
        end
    end

    BetterSleeves:SyncKeepState()
end

local function SyncSleevesDelayedCB()
    local player = Game.GetPlayer()
    if not player then return; end
    
    local inventoryPuppet = BetterSleeves:GetInventoryPuppet()
    if not inventoryPuppet then return; end

    local slots = BetterSleeves:GetActiveSlots()
    for _, slotName in next, slots do
        BetterSleeves:SyncPuppetsPOV(player, inventoryPuppet, slotName)
    end
end

---Creates a new "Delayed Roll Down Sleeves Event(tm)" if the current delay is less than the new one.
---@param delay number Seconds to wait before auto-rolling down sleeves.
---@return boolean ok Whether or not an Auto-Roll could be performed.
function BetterSleeves:DoAutoRollSleevesDelayed(delay)
    if self.autoRoll then
        self.scheduler:SetTask("auto-roll", AutoRollSleevesDelayedCB, delay)
        return true
    end
    return false
end

---Creates a new "Sync Sleeves Event(r)" if the current delay is less than the new one.
---@param delay number Seconds to wait before syncing sleeves.
---@return boolean ok Whether or not a sync could be performed.
function BetterSleeves:DoSyncSleevesDelayed(delay)
    local isAutoRolling = BetterSleeves.scheduler:HasTask("auto-roll")
    if self.syncInventoryPuppet and not isAutoRolling then
        self.scheduler:SetTask("sync-sleeves", SyncSleevesDelayedCB, delay)
        return true
    end
    return false
end

local function Event_SyncSleeves()
    BetterSleeves:DoSyncSleevesDelayed(BetterSleeves.syncInventoryPuppetDelay)
end

local function Event_UpdateSleeves()
    BetterSleeves:DoAutoRollSleevesDelayed(BetterSleeves.autoRollDelay)
    Event_SyncSleeves()
end

local function Event_DoorControllerPS_OnActionDemolition()
    if not (
        BetterSleeves.autoRoll and
        BetterSleeves.gorillaArmsRollUpOnDoorOpen
    ) then return; end

    local player = Game.GetPlayer()
    if not player then return; end

    local eqSys = Game.GetScriptableSystemsContainer():Get("EquipmentSystem")
    local armsCybId = eqSys:GetActiveItem(player, gamedataEquipmentArea.ArmsCW)
    if not armsCybId then return; end

    local armsCybName = TweakDB:GetRecord(armsCybId.id):FriendlyName()
    if armsCybName ~= BetterSleeves.gorillaArmsWeaponName then return; end

    BetterSleeves:RollUpSleeves(false, { player })
    BetterSleeves:DoAutoRollSleevesDelayed(BetterSleeves.gorillaArmsRollDownDelay)
end

local function Event_VehicleComponent_OnVehicleCameraChange()
    BetterSleeves:DoAutoRollSleevesDelayed(BetterSleeves.autoRollVehiclesDelay)
    Event_SyncSleeves()
end

local function Event_OnInit()
    if EquipmentEx then BetterSleeves.Log("EquipmentEx found."); end
    if GetMod("RenderPlaneFix") then BetterSleeves.Log("RenderPlaneFix found."); end

    BetterSleeves:ResetConfig() -- Loads default settings
    BetterSleeves:LoadConfig()
    BetterSleeves._configInitialized = true

    BetterSleeves.appearanceSuffixCameraRecord = TweakDB:GetRecord("itemsFactoryAppearanceSuffix.Camera")

    BetterSleeves.slotToAreaType["AttachmentSlots.Outfit"] = gamedataEquipmentArea.Outfit
    BetterSleeves.slotToAreaType["AttachmentSlots.Torso"] = gamedataEquipmentArea.OuterChest
    BetterSleeves.slotToAreaType["AttachmentSlots.Chest"] = gamedataEquipmentArea.InnerChest

    Observe("PlayerPuppet", "OnWeaponEquipEvent", Event_UpdateSleeves)
    -- This also triggers when switching from TPP to FPP on vehicles (and vice-versa).
    -- I don't know if it was also triggered in other contexts which made the mod work.
    -- TODO: Figure out if not listening to this event breaks the mod
    -- Observe("PlayerPuppet", "OnItemAddedToSlot", Event_UpdateSleeves)
    Observe("PlayerPuppet", "OnItemEquipped", Event_UpdateSleeves)
    Observe("PlayerPuppet", "OnItemUnequipped", Event_UpdateSleeves)
    Observe("PlayerPuppet", "OnMakePlayerVisibleAfterSpawn", Event_UpdateSleeves)
    Observe("JournalManager", "OnQuestEntryTracked", Event_UpdateSleeves)
    Observe("JournalManager", "OnQuestEntryUntracked", Event_UpdateSleeves)
    Observe("gameWardrobeSystem", "SetActiveClothingSetIndex", Event_UpdateSleeves)

    Observe("DoorControllerPS", "OnActionDemolition", Event_DoorControllerPS_OnActionDemolition)

    Observe("VehicleComponent", "OnVehicleCameraChange", Event_VehicleComponent_OnVehicleCameraChange)

    -- On menu open is only needed for the first time the menu is opened.
    -- Event_UpdateSleeves will sync the inventory before the menu is even opened which makes inventory loading faster.
    Observe("gameuiInventoryGameController", "OnInitialize", Event_SyncSleeves)
    Observe("gameuiInventoryGameController", "RefreshedEquippedItemData", Event_SyncSleeves)
    -- Observe("gameuiInventoryGameController", "RefreshEquippedWardrobeItems", Event_SyncSleeves)
    
    -- Thanks psiberx! https://github.com/psiberx/cp2077-codeware/blob/main/scripts/Player/PlayerSystem.reds
    -- It's the same as what Codeware does.
    local n_gameuiInventoryPuppetPreviewGameController = CName.new("gameuiInventoryPuppetPreviewGameController");
    ObserveAfter("inkPuppetPreviewGameController", "OnPreviewInitialized", function(this)
        if this:GetClassName() == n_gameuiInventoryPuppetPreviewGameController then
            BetterSleeves._inventoryPuppet = this:GetGamePuppet()
        end
    end)

    ObserveAfter("PhotoModePlayerEntityComponent", "SetupInventory", function(this)
        BetterSleeves._photoPuppet = this.fakePuppet
    end)

    BetterSleeves.Log("Initialized!")
end

local function Event_OnUpdate(dt)
    BetterSleeves.scheduler:Update(dt)
end

local function Event_OnShutdown()
    if BetterSleeves._configInitialized then
        BetterSleeves:SaveConfig()
    end
end

local function Event_OnDraw()
    if not BetterSleeves.showUI then return; end
    if ImGui.Begin("Better Sleeves") then
        ImGui.Text("Sleeves |")
        ImGui.SameLine()

        if BetterUI.FitButtonN(2, "Roll Down") then BetterSleeves:ToggleSleeves(false, true); end
        ImGui.SameLine()

        if BetterUI.FitButtonN(1, "Roll Up") then BetterSleeves:ToggleSleeves(false, false); end
        ImGui.Separator()

        BetterSleeves.autoRoll = ImGui.Checkbox("Auto-Roll", BetterSleeves.autoRoll)
        if BetterSleeves.autoRoll then
            BetterSleeves.autoRollDelay = BetterUI.DragFloat("Roll Delay*", BetterSleeves.autoRollDelay, 0.01, 0.01, 5, "%.2f")
            if ImGui.IsItemHovered() then
                ImGui.SetTooltip("*If too low, may stop sleeves from rolling down when changing clothes.")
            end

            ImGui.PushID("keep-state")
            if ImGui.Button("Toggle") then
                BetterSleeves:ToggleSleeves(BetterSleeves.forceKeepRolledDown)
            end
            ImGui.SameLine()
            BetterSleeves.forceKeepRolledDown = ImGui.Checkbox("", BetterSleeves.forceKeepRolledDown)
            ImGui.SameLine()
            ImGui.TextWrapped(table.concat{
                "Keep ",
                BetterSleeves.forceKeepRolledDown and "Forcefully* " or "",
                BetterSleeves.keepRolledDown and "Rolled Down" or "Rolled Up",
            })
            if BetterSleeves.forceKeepRolledDown and ImGui.IsItemHovered() then
                ImGui.SetTooltip("*Ignores any user blacklist.")
            end
            ImGui.PopID()
            ImGui.Separator()

            BetterSleeves.autoRollOnVehiclesTPP = ImGui.Checkbox("Allow on Vehicles TPP*", BetterSleeves.autoRollOnVehiclesTPP)
            if ImGui.IsItemHovered() then
                ImGui.SetTooltip("*Can cause parts of clothes to disappear in TPP if sleeves are auto-rolled up.");
            end
            BetterSleeves.autoRollVehiclesDelay = BetterUI.DragFloat("Vehicles Roll Delay*", BetterSleeves.autoRollVehiclesDelay, 0.01, 0.01, 5, "%.2f")
            if ImGui.IsItemHovered() then
                ImGui.SetTooltip("*If too low, may stop sleeves from rolling down on TPP to FPP camera transitions.")
            end
            ImGui.Separator()

            ImGui.PushID("auto-roll_gorilla-arms")
            BetterSleeves.gorillaArmsRollUpOnDoorOpen = ImGui.Checkbox("Roll Up on Gorilla Arms Door Open", BetterSleeves.gorillaArmsRollUpOnDoorOpen)
            if BetterSleeves.gorillaArmsRollUpOnDoorOpen then
                BetterSleeves.gorillaArmsRollDownDelay = BetterUI.DragFloat("Roll Down Delay", BetterSleeves.gorillaArmsRollDownDelay, 0.01, 1, 5, "%.2f")
            end
            ImGui.PopID()
        end
        ImGui.Separator()
        ImGui.Separator()

        do
            ImGui.PushID("inventory_photo-mode")
            BetterSleeves.syncInventoryPuppet = ImGui.Checkbox("Sync Inventory Character", BetterSleeves.syncInventoryPuppet)

            if BetterSleeves.syncInventoryPuppet then
                BetterSleeves.syncInventoryPuppetDelay = BetterUI.DragFloat("Sync Delay*", BetterSleeves.syncInventoryPuppetDelay, 0.01, 0.01, 5, "%.2f")
                if ImGui.IsItemHovered() then
                    ImGui.SetTooltip("*If too low, may stop sleeves from syncing when swapping clothes.");
                end
                if BetterUI.FitButtonN(1, "Perform Inventory Sync") then
                    BetterSleeves:DoSyncSleevesDelayed(0)
                end
            end

            ImGui.Separator()
            local photoModeSystem = Game.GetPhotoModeSystem()
            local photoPuppet = BetterSleeves:GetPhotoPuppet()

            if photoModeSystem:IsPhotoModeActive() and photoPuppet then
                ImGui.TextWrapped("Photo Mode Sleeves |")
                ImGui.SameLine()
                if BetterUI.FitButtonN(2, "Roll Down") then BetterSleeves:RollDownSleeves(true, {photoPuppet}); end
                ImGui.SameLine()
                if BetterUI.FitButtonN(1, "Roll Up") then BetterSleeves:RollUpSleeves(nil, {photoPuppet}); end
            else
                ImGui.TextWrapped("Photo Mode Sleeves | Currently not in Photo Mode.")
            end
            ImGui.PopID()
        end
        ImGui.Separator()

        if ImGui.CollapsingHeader("Integrations") then
            ImGui.TextWrapped("Everything in this menu is available through integrations with other mods.")

            ImGui.Separator()
            local isCodewareInstalled = Codeware and true or false
            ImGui.TextWrapped(table.concat{
                "Codeware: ", isCodewareInstalled and "Installed" or "Not Installed"
            })

            ImGui.Separator()
            ImGui.TextWrapped(table.concat{
                "EquipmentEx: ", EquipmentEx and "Installed" or "Not Installed"
            })

            ImGui.Separator()
            ImGui.TextWrapped(table.concat{
                "RenderPlaneFix: ", GetMod("RenderPlaneFix") and "Installed" or "Not Installed"
            })
        end

        if ImGui.CollapsingHeader("Item Blacklist") then
            ImGui.PushID("item-blacklist")
            if BetterUI.ButtonAdd() then
                BetterSleeves.rollDownItemBlacklist[BetterSleeves._newItem] = true
                BetterSleeves._newItem = ""
            end
            ImGui.SameLine()
            BetterSleeves._newItem = ImGui.InputText("", BetterSleeves._newItem, 256)

            for item in next, BetterSleeves.rollDownItemBlacklist do
                ImGui.PushID(table.concat{ "item-blacklist_", item })
                if BetterUI.ButtonRemove() then
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
            if BetterUI.ButtonAdd() then
                BetterSleeves.rollDownWeaponBlacklist[BetterSleeves._newWeapon] = true
                BetterSleeves._newWeapon = ""
            end
            ImGui.SameLine()
            BetterSleeves._newWeapon = ImGui.InputText("", BetterSleeves._newWeapon, 256)

            for weapon in next, BetterSleeves.rollDownWeaponBlacklist do
                ImGui.PushID(table.concat{ "weapon-blacklist_", weapon })
                if BetterUI.ButtonRemove() then
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
            if BetterUI.ButtonAdd() then
                BetterSleeves.rollDownMissionBlacklist[BetterSleeves._newMission] = true
                BetterSleeves._newMission = ""
            end
            ImGui.SameLine()
            BetterSleeves._newMission = ImGui.InputText("", BetterSleeves._newMission, 512)

            for mission in next, BetterSleeves.rollDownMissionBlacklist do
                ImGui.PushID(table.concat{ "mission-blacklist_", mission })
                if BetterUI.ButtonRemove() then
                    BetterSleeves.rollDownMissionBlacklist[mission] = nil
                end
                ImGui.SameLine()
                ImGui.Text(mission)
                ImGui.PopID()
            end
            ImGui.PopID()
        end

        if ImGui.CollapsingHeader("Slots to Roll") then
            ImGui.TextWrapped("Within this menu you'll be able to add custom slots to use when rolling sleeves.")
            ImGui.Bullet()
            ImGui.TextWrapped("Items still need to have separate models for FPP (sleeveless) and TPP (sleeved).")
            ImGui.Bullet()
            ImGui.TextWrapped("TPP models must be set correctly to draw on top of player hands.")
            ImGui.Separator()

            ImGui.TextWrapped(table.concat{
                "If you don't see any EquipmentEx slot *enabled*, it means that this mod did not find it installed.",
                " If you think that's not the case, try pressing the button below."
            })

            if BetterUI.FitButtonN(1, "Detect EquipmentEx") then
                if BetterSleeves:DetectEquipmentExAndEnableSlots() then
                    BetterSleeves.Log("'Detect EquipmentEx' button has found EquipmentEx.")
                else
                    BetterSleeves.Log("'Detect EquipmentEx' button did not find EquipmentEx installed.")
                end
            end
            ImGui.Separator()

            ImGui.TextWrapped(table.concat{
                "Press this button if you enable/disable slots while Sleeves are rolled down.",
                " The mod won't try to roll up slots that are not enabled."
            })

            if BetterUI.FitButtonN(1, "Roll Up ALL Slots") then
                BetterSleeves:RollUpSleeves(true)
            end
            ImGui.Separator()

            ImGui.PushID("user-slots")
            if BetterUI.ButtonAdd() then
                if not BetterSleeves.slotsToRoll[BetterSleeves._newSlot] then
                    BetterSleeves.slotsToRoll[BetterSleeves._newSlot] = {
                        type = BetterSleeves.SlotType.USER_DEFINED,
                        enabled = true
                    }
                    BetterSleeves._newSlot = ""
                end
            end
            ImGui.SameLine()
            BetterSleeves._newSlot = ImGui.InputText("", BetterSleeves._newSlot, 512)

            for slotName, slot in next, BetterSleeves.slotsToRoll do
                if slot.type == BetterSleeves.SlotType.USER_DEFINED then
                    ImGui.PushID(table.concat{ "user-slots_", slotName })
                    if BetterUI.ButtonRemove() then
                        BetterSleeves.slotsToRoll[slotName] = nil
                    end
                    ImGui.SameLine()
                    BetterSleeves.slotsToRoll[slotName].enabled = ImGui.Checkbox("", BetterSleeves.slotsToRoll[slotName].enabled)
                    ImGui.SameLine()
                    ImGui.Text(slotName)
                    ImGui.PopID()
                end
            end

            for slotName, slot in next, BetterSleeves.slotsToRoll do
                if slot.type ~= BetterSleeves.SlotType.USER_DEFINED then
                    ImGui.PushID(table.concat{ "modded-slots_", slotName })
                    local newEnabled, changed = ImGui.Checkbox("", BetterSleeves.slotsToRoll[slotName].enabled)
                    if changed then
                        BetterSleeves.slotsToRoll[slotName].userHandled = true
                        BetterSleeves.slotsToRoll[slotName].enabled = newEnabled
                    end
                    ImGui.PopID()
                    ImGui.SameLine()
                end

                if slot.type == BetterSleeves.SlotType.VANILLA then
                    ImGui.Text("[Vanilla] " .. slotName)
                elseif slot.type == BetterSleeves.SlotType.EQUIPMENT_EX then
                    ImGui.Text("[EquipmentEx] " .. slotName)
                elseif slot.type ~= BetterSleeves.SlotType.USER_DEFINED then
                    ImGui.Text("[Other Mods] " .. slotName)
                end
            end
            ImGui.PopID()
        end

        if ImGui.CollapsingHeader("Quick Blacklist") then
            ImGui.TextWrapped("Within this section you can quickly blacklist equipped items, active weapons and quests.")

            local player = Game.GetPlayer()
            for slot in next, BetterSleeves.slotsToRoll do
                local item = BetterSleeves:GetItem(player, slot)
                if item then
                    local itemName = BetterSleeves:GetItemAppearanceName(player, item):match("[^&]+")
                    ImGui.PushID(table.concat{ "slot-qb_", slot })
                    if BetterUI.ButtonAdd() then
                        BetterSleeves.rollDownItemBlacklist[itemName] = true
                    end
                    ImGui.SameLine()
                    if BetterSleeves.rollDownItemBlacklist[itemName] then
                        if BetterUI.ButtonRemove() then
                            BetterSleeves.rollDownItemBlacklist[itemName] = nil
                        end
                    else
                        BetterUI.SquareButton("/")
                    end
                    ImGui.SameLine()
                    ImGui.Text(table.concat { slot:match("%.(.+)"), " Item: ", itemName })
                    ImGui.PopID()
                end
            end

            if player then
                local weapon = player:GetActiveWeapon()
                if weapon then
                    local weaponName = weapon:GetWeaponRecord():FriendlyName()
                    ImGui.PushID("weapon-qb")
                    if BetterUI.ButtonAdd() then
                        BetterSleeves.rollDownWeaponBlacklist[weaponName] = true
                    end
                    ImGui.SameLine()
                    if BetterSleeves.rollDownWeaponBlacklist[weaponName] then
                        if BetterUI.ButtonRemove() then
                            BetterSleeves.rollDownWeaponBlacklist[weaponName] = nil
                        end
                    else
                        BetterUI.SquareButton("/")
                    end
                    ImGui.SameLine()
                    ImGui.Text("Weapon Name: " .. weaponName)
                    ImGui.PopID()
                end
            end

            local quest, obj = BetterSleeves:GetTrackedMissionAndObjectiveIds()
            if quest then
                ImGui.PushID("quest-qb")
                local blacklistQuestAll = table.concat{quest, ".*"}
                if BetterUI.ButtonAdd() then
                    BetterSleeves.rollDownMissionBlacklist[blacklistQuestAll] = true
                end
                ImGui.SameLine()
                if BetterSleeves.rollDownMissionBlacklist[blacklistQuestAll] then
                    if BetterUI.ButtonRemove() then
                        BetterSleeves.rollDownMissionBlacklist[blacklistQuestAll] = nil
                    end
                else
                    BetterUI.SquareButton("/")
                end
                ImGui.SameLine()
                ImGui.Text("Quest ID: " .. quest)
                ImGui.PopID()

                ImGui.PushID("objective-qb")
                local blacklistQuestSpecific = table.concat{quest, ".", obj}
                if BetterUI.ButtonAdd() then
                    BetterSleeves.rollDownMissionBlacklist[blacklistQuestSpecific] = true
                end
                ImGui.SameLine()
                if BetterSleeves.rollDownMissionBlacklist[blacklistQuestSpecific] then
                    if BetterUI.ButtonRemove() then
                        BetterSleeves.rollDownMissionBlacklist[blacklistQuestSpecific] = nil
                    end
                else
                    BetterUI.SquareButton("/")
                end
                ImGui.SameLine()
                ImGui.Text("Objective ID: " .. obj)
                ImGui.PopID()
            end
        end

        ImGui.Separator()

        ImGui.Text("Config |")
        ImGui.SameLine()

        if BetterUI.FitButtonN(3, "Load") then BetterSleeves:LoadConfig(); end
        ImGui.SameLine()

        if BetterUI.FitButtonN(2, "Save") then BetterSleeves:SaveConfig(); end
        ImGui.SameLine()

        if BetterUI.FitButtonN(1, "Reset") then BetterSleeves:ResetConfig(); end
        ImGui.Separator()
    end
end

local function Event_OnOverlayOpen()
    BetterSleeves.showUI = true
end

local function Event_OnOverlayClose()
    BetterSleeves.showUI = false
end

function BetterSleeves:Init()
    local function _InputAsHotkey(cb)
        return function(pressed)
            if not pressed then cb(); end
        end
    end

    registerInput("rolldown_sleeves", "Roll Down Sleeves", _InputAsHotkey(function() self:ToggleSleeves(false, true)  end))
    registerInput("rollup_sleeves",   "Roll Up Sleeves",   _InputAsHotkey(function() self:ToggleSleeves(false, false) end))
    registerInput("toggle_sleeves",   "Toggle Sleeves",    _InputAsHotkey(function() self:ToggleSleeves(false)        end))
    registerInput("force_rolldown_sleeves", "Force Roll Down Sleeves", _InputAsHotkey(function() self:ToggleSleeves(true, true)  end))
    registerInput("force_rollup_sleeves",   "Force Roll Up Sleeves",   _InputAsHotkey(function() self:ToggleSleeves(true, false) end))
    registerInput("force_toggle_sleeves",   "Force Toggle Sleeves",    _InputAsHotkey(function() self:ToggleSleeves(true)        end))

    registerForEvent("onInit",     Event_OnInit)
    registerForEvent("onUpdate",   Event_OnUpdate)
    registerForEvent("onShutdown", Event_OnShutdown)
    registerForEvent("onDraw",         Event_OnDraw)
    registerForEvent("onOverlayOpen",  Event_OnOverlayOpen)
    registerForEvent("onOverlayClose", Event_OnOverlayClose)
    return self
end

return BetterSleeves:Init()
