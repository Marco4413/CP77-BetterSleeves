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

local BetterUI  = require "BetterUI"
local Enum      = require "Enum"
local Scheduler = require "Scheduler"

---@enum SleevesState
local SleevesState = Enum.New{
    Current    = 1,
    RolledDown = 2,
    RolledUp   = 3,
}

---@enum SlotType
local SlotType = Enum.New{
    UserDefined = 0,
    Vanilla     = 1,
    EquipmentEx = 2,
    OtherMods   = 1024,
}

---@class SleevesRule
---@field fpp SleevesState
---@field tpp SleevesState

---@class SlotToRoll
---@field type SlotType
---@field enabled boolean
---@field userHandled boolean

local BetterSleeves = {
    SleevesState = SleevesState,
    SlotType = SlotType,

    autoRoll = true,
    autoRollDelay = 1.0,
    autoRollOnVehiclesTPP = false,
    autoRollVehiclesDelay = 1.0,
    syncInventoryPuppet = true,
    syncInventoryPuppetDelay = 1.0,
    showUI = false,
    scheduler = Scheduler.New(),

    forceKeepState = false,
    ---@type SleevesState
    keepState = SleevesState.RolledDown,

    ---@type table<string, SleevesRule>
    missionRules = {},
    ---@type table<string, SleevesRule>
    itemRules = {},
    ---@type table<string, SleevesRule>
    weaponRules = {},

    ---@type table<string, SlotToRoll>
    slotsToRoll = {},
    _newSlot = "",
    slotToAreaType = {},
    _configInitialized = false,
    -- Populated within Event_OnInit

    ---@deprecated
    appearanceSuffixCameraRecord = nil,
    gorillaArmsWeaponName = "w_strong_arms",
    gorillaArmsRollUpOnDoorOpen = true,
    gorillaArmsRollDownDelay = 3.15,
    _inventoryPuppet = nil,
    _photoPuppet = nil,

    ---Deprecated: See `forceKeepState`
    ---@deprecated
    forceKeepRolledDown = false,
    ---Deprecated: See `keepState`
    ---@deprecated
    keepRolledDown = true,

    ---Deprecated: See `itemRules`
    ---@deprecated
    ---@type table<string, boolean>
    rollDownItemBlacklist = {},
    ---Deprecated: See `weaponRules`
    ---@deprecated
    ---@type table<string, boolean>
    rollDownWeaponBlacklist = {},
    ---Deprecated: See `missionRules`
    ---@deprecated
    ---@type table<string, boolean>
    rollDownMissionBlacklist = {},
}

function BetterSleeves.Log(...)
    print(table.concat{"[ ", os.date("%x %X"), " ][ BetterSleeves ]: ", ...})
end

BetterSleeves.scheduler:SetLogger(BetterSleeves.Log)

function BetterSleeves:DetectEquipmentExAndEnableSlots()
    if EquipmentEx then
        -- Equipment-EX Slots
        for _, slot in next, self.slotsToRoll do
            if slot.type == SlotType.EquipmentEx then
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
    self.forceKeepState = false
    self.keepState = SleevesState.RolledDown
    self.missionRules = {}
    self.itemRules = {}
    self.weaponRules = {}
    self.slotsToRoll = {
        ["AttachmentSlots.Outfit"]  = { type = SlotType.Vanilla, enabled = true, userHandled = false },
        ["AttachmentSlots.Torso"]   = { type = SlotType.Vanilla, enabled = true, userHandled = false },
        ["AttachmentSlots.Chest"]   = { type = SlotType.Vanilla, enabled = true, userHandled = false },
        ["OutfitSlots.TorsoOuter"]  = { type = SlotType.EquipmentEx, enabled = eqExInstalled, userHandled = false },
        ["OutfitSlots.TorsoMiddle"] = { type = SlotType.EquipmentEx, enabled = eqExInstalled, userHandled = false },
        ["OutfitSlots.TorsoInner"]  = { type = SlotType.EquipmentEx, enabled = eqExInstalled, userHandled = false },
        ["OutfitSlots.TorsoUnder"]  = { type = SlotType.EquipmentEx, enabled = eqExInstalled, userHandled = false },
        ["OutfitSlots.TorsoAux"]    = { type = SlotType.EquipmentEx, enabled = eqExInstalled, userHandled = false },
        ["OutfitSlots.BodyOuter"]   = { type = SlotType.EquipmentEx, enabled = eqExInstalled, userHandled = false },
        ["OutfitSlots.BodyMiddle"]  = { type = SlotType.EquipmentEx, enabled = eqExInstalled, userHandled = false },
        ["OutfitSlots.BodyInner"]   = { type = SlotType.EquipmentEx, enabled = eqExInstalled, userHandled = false },
        ["OutfitSlots.BodyUnder"]   = { type = SlotType.EquipmentEx, enabled = eqExInstalled, userHandled = false },
    }
    self.gorillaArmsRollUpOnDoorOpen = true
    self.gorillaArmsRollDownDelay = 3.15

    self.forceKeepRolledDown = false
    self.keepRolledDown = true
    self.rollDownItemBlacklist = {}
    self.rollDownWeaponBlacklist = {}
    self.rollDownMissionBlacklist = {}

    -- Add all blacklist entries and migrate from deprecated fields
    self:MigrateConfigFromVersion(nil)
end

---@param rule SleevesRule
---@return table
function BetterSleeves:GetSleevesRuleForConfig(rule)
    return { fpp = SleevesState[rule.fpp], tpp = SleevesState[rule.tpp] }
end

---@param rules table<string, SleevesRule>
---@return table
function BetterSleeves:GetSleevesRulesForConfig(rules)
    local rulesForConfig = {}
    for id, rule in next, rules do
        rulesForConfig[id] = self:GetSleevesRuleForConfig(rule)
    end
    return rulesForConfig
end

---@param ruleConfig table
---@return SleevesRule|nil
function BetterSleeves:GetSleevesRuleFromConfig(ruleConfig)
    if type(ruleConfig.fpp) ~= "string" and not SleevesState[ruleConfig.fpp] then return nil; end
    if type(ruleConfig.tpp) ~= "string" and not SleevesState[ruleConfig.tpp] then return nil; end
    return { fpp = SleevesState[ruleConfig.fpp], tpp = SleevesState[ruleConfig.tpp] }
end

---@param ruleConfig table
---@return table<string, SleevesRule>
function BetterSleeves:GetSleevesRulesFromConfig(rulesConfig)
    local rules = {}
    for id, ruleConfig in next, rulesConfig do
        if type(id) == "string" and type(ruleConfig) == "table" then
            rules[id] = self:GetSleevesRuleFromConfig(ruleConfig)
        end
    end
    return rules
end

function BetterSleeves:SaveConfig()
    local file = io.open("data/config.json", "w")

    local slotsToSave = { }
    for slotName, slot in next, self.slotsToRoll do
        if slot.type == SlotType.UserDefined or slot.userHandled then
            slotsToSave[slotName] = {
                type        = SlotType[slot.type],
                enabled     = slot.enabled,
                userHandled = slot.userHandled,
            }
        end
    end

    file:write(json.encode({
        version = 6,
        autoRoll = self.autoRoll,
        autoRollDelay = self.autoRollDelay,
        autoRollOnVehiclesTPP = self.autoRollOnVehiclesTPP,
        autoRollVehiclesDelay = self.autoRollVehiclesDelay,
        syncInventoryPuppet = self.syncInventoryPuppet,
        syncInventoryPuppetDelay = self.syncInventoryPuppetDelay,
        forceKeepState = self.forceKeepState,
        keepState = SleevesState[self.keepState],
        missionRules = self:GetSleevesRulesForConfig(self.missionRules),
        itemRules = self:GetSleevesRulesForConfig(self.itemRules),
        weaponRules = self:GetSleevesRulesForConfig(self.weaponRules),
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

    if version <= 5 then
        version = 6
        self.forceKeepState = self.forceKeepRolledDown
        self.keepState      = self.keepRolledDown and SleevesState.RolledDown or SleevesState.RolledUp

        local blacklistMigrations = {
            { blacklist = self.rollDownMissionBlacklist, rules = self.missionRules },
            { blacklist = self.rollDownItemBlacklist,    rules = self.itemRules    },
            { blacklist = self.rollDownWeaponBlacklist,  rules = self.weaponRules  },
        }

        for _, migration in next, blacklistMigrations do
            for id, blacklisted in next, migration.blacklist do
                if blacklisted then
                    migration.rules[id] = {
                        fpp = SleevesState.RolledUp,
                        tpp = SleevesState.RolledDown,
                    }
                end
            end
        end
    end

    -- Migrate from version x to latest
end

function BetterSleeves:LoadConfig()
    local ok = pcall(function()
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

        if type(config.forceKeepState) == "boolean" then
            self.forceKeepState = config.forceKeepState
        end

        if type(config.keepState) == "string" then
            self.keepState = SleevesState[config.keepState]
        end

        if type(config.missionRules) == "table" then
            self.missionRules = self:GetSleevesRulesFromConfig(config.missionRules)
        end

        if type(config.itemRules) == "table" then
            self.itemRules = self:GetSleevesRulesFromConfig(config.itemRules)
        end

        if type(config.weaponRules) == "table" then
            self.weaponRules = self:GetSleevesRulesFromConfig(config.weaponRules)
        end

        if type(config.slotsToRoll) == "table" then
            for slotName, slot in next, config.slotsToRoll do
                slot.enabled = slot.enabled and true or false
                if type(slot) == "number" then
                    if not SlotType[slot] then slot = SlotType.OtherMods; end
                    if slot == SlotType.UserDefined and not self.slotsToRoll[slotName] then
                        self.slotsToRoll[slotName] = { type = slot, enabled = true }
                    end
                elseif type(slot) == "table" then
                    if not SlotType[slot.type]     then slot.type = SlotType.OtherMods;  end
                    -- slot.type exists in SlotType, convert it to integer
                    if type(slot.type) == "string" then slot.type = SlotType[slot.type]; end

                    if slot.type == SlotType.UserDefined then
                        self.slotsToRoll[slotName] = slot
                    elseif self.slotsToRoll[slotName] and self.slotsToRoll[slotName].type == slot.type then
                        slot.userHandled = true
                        self.slotsToRoll[slotName] = slot
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

        -- DEPRECATED FIELDS
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

        self:MigrateConfigFromVersion(config.version)
    end)
    if not ok then self:SaveConfig(); end
end

---@param puppet gamePuppet
---@param item gameItemObject
---@return string|nil
function BetterSleeves:GetItemAppearanceName(puppet, item)
    if not puppet then return nil; end
    local transactionSystem = Game.GetTransactionSystem()
    local itemAppearance = transactionSystem:GetItemAppearance(puppet, item:GetItemID())
    return itemAppearance and itemAppearance.value or nil
end

---@param puppet gamePuppet
---@param slotName string
---@return gameItemObject|nil
function BetterSleeves:GetItem(puppet, slotName)
    if not puppet then return nil; end
    local transactionSystem = Game.GetTransactionSystem()
    local item = transactionSystem:GetItemInSlot(puppet, slotName)
    return item
end

---@return string|nil questId
---@return string|nil objectiveId
function BetterSleeves:GetTrackedQuestAndObjectiveIds()
    local journal = Game.GetJournalManager()

    -- gameJournalQuestObjective[ id:02_meet_hanako ]
    local objective = journal:GetTrackedEntry()
    if not objective then return; end

    -- gameJournalQuestPhase[ id:q115 ]
    local phase = journal:GetParentEntry(objective)
    if not phase then return; end

    -- gameJournalQuest[ id:02_sickness ]
    local quest = journal:GetParentEntry(phase)
    if not quest then return; end

    return quest.id, objective.id
end

---@param checkWardrobe boolean|nil Whether to filter by active wardrobe slots (default: true)
---@return string[] slots The slots that need to be rolled
function BetterSleeves:GetSlotNamesToRoll(checkWardrobe)
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

---@return string[] slots All known slots
function BetterSleeves:GetAllSlots()
    local slots = {}
    for slotName, _ in next, self.slotsToRoll do
        table.insert(slots, slotName)
    end
    return slots
end

function BetterSleeves:GetInventoryPuppet()
    return self._inventoryPuppet
end

function BetterSleeves:GetPhotoPuppet()
    return self._photoPuppet
end

---@param player PlayerPuppet
---@return boolean
function BetterSleeves:IsPlayerPuppetInTPP(player)
    local vehicle = player:GetMountedVehicle()
    if vehicle then
        local cameraManager = vehicle:GetCameraManager()
        if cameraManager and cameraManager:IsTPPActive() then
            return true
        end
    end
    return false
end

---@return gamePuppet[] puppets All fpp puppets where sleeves need to be handled
function BetterSleeves:GetPuppetsFPP()
    local puppets = {}
    local player = Game.GetPlayer()
    if not self:IsPlayerPuppetInTPP(player) then
        table.insert(puppets, player)
    end
    return puppets
end

---@return gamePuppet[] puppets All tpp puppets where sleeves need to be handled
function BetterSleeves:GetPuppetsTPP()
    local puppets = {}
    local player = Game.GetPlayer()
    if self:IsPlayerPuppetInTPP(player) then
        table.insert(puppets, player)
    end
    if self.syncInventoryPuppet then
        table.insert(puppets, self:GetInventoryPuppet())
    end
    return puppets
end

---@return gamePuppet[] puppets All puppets where sleeves need to be handled
function BetterSleeves:GetPuppets()
    local puppets = self:GetPuppetsFPP()
    for _, puppet in next, self:GetPuppetsTPP() do
        table.insert(puppets, puppet)
    end
    return puppets
end

---@param puppet gamePuppet
---@return string[]
function BetterSleeves:GetActiveWeaponsName(puppet)
    ---@type WeaponObject[]
    local weaponObjects = {}
    if puppet.GetActiveWeapons then
        weaponObjects = puppet:GetActiveWeapons()
    elseif puppet.GetActiveWeapon then
        table.insert(weaponObjects, puppet:GetActiveWeapon())
    end

    local weaponNames = {}
    for _, weaponObject in next, weaponObjects do
        local weaponRecord = weaponObject:GetWeaponRecord()
        local weaponName   = weaponRecord:FriendlyName()
        table.insert(weaponNames, weaponName)
    end
    return weaponNames
end

function BetterSleeves:CreateRuleFetchingContext()
    local context = {
        _mod            = self,
        ---@type gamePuppet|nil
        _puppet         = nil,
        ---@type string|nil
        _slotName       = nil,
        ---@type string|nil
        _questId        = nil,
        ---@type string|nil
        _objectiveId    = nil,
        ---@type string|nil
        _itemAppearance = nil,
        _weaponNames    = {},
        ---@type SleevesRule|nil
        _sleevesRule    = nil,
    }

    local questId, objectiveId = self:GetTrackedQuestAndObjectiveIds()
    if questId then
        context._questId = table.concat{questId, ".*"}
        if objectiveId then
            context._objectiveId = table.concat{questId, ".", objectiveId}
        end
    end

    ---@param puppet gamePuppet|nil
    function context:SetPuppet(puppet)
        self._sleevesRule = nil

        self._puppet = puppet
        self:SetSlot(self._slotName)
        self._weaponNames = {}
        if not puppet then return; end

        self._weaponNames = self._mod:GetActiveWeaponsName(puppet)
    end

    ---@param slotName string
    function context:SetSlot(slotName)
        self._sleevesRule = nil

        self._slotName       = slotName
        self._itemAppearance = nil
        if not self._puppet or not slotName then return; end

        local item = self._mod:GetItem(self._puppet, slotName)
        if not item then return; end

        self._itemAppearance = self._mod:GetItemAppearanceName(self._puppet, item)
    end

    ---@return string|nil
    function context:GetItemName()
        if not self._itemAppearance then return nil; end
        return self._itemAppearance:match("[^&]+")
    end

    ---@private
    function context:_GetRuleList()
        ---@type SleevesRule[]
        local ruleStack = {{
            fpp = self._mod.keepState,
            tpp = self._mod.keepState,
        }}

        if self._mod.forceKeepState then return ruleStack; end

        if self._questId then
            table.insert(ruleStack, self._mod.missionRules[self._questId])
        end
        if self._objectiveId then
            table.insert(ruleStack, self._mod.missionRules[self._objectiveId])
        end

        local itemName = self:GetItemName()
        if itemName then
            table.insert(ruleStack, self._mod.itemRules[itemName])
        end

        for i=#self._weaponNames, 1, -1 do
            local weaponName = self._weaponNames[i]
            table.insert(ruleStack, self._mod.weaponRules[weaponName])
        end

        return ruleStack
    end

    ---@return SleevesRule
    function context:GetSleevesRule()
        if self._sleevesRule then return self._sleevesRule; end

        local ruleList = self:_GetRuleList()
        ---@type SleevesRule
        local sleevesRule = ruleList[1]

        for i=2, #ruleList do
            local rule = ruleList[i]
            if rule.fpp ~= SleevesState.Current then
                sleevesRule.fpp = rule.fpp
            end
            if rule.tpp ~= SleevesState.Current then
                sleevesRule.tpp = rule.tpp
            end
        end

        self._sleevesRule = sleevesRule
        return sleevesRule
    end

    ---@param slotName string
    ---@param pov "fpp"|"tpp"
    function context:ApplySleevesRuleForSlot(slotName, pov)
        self:SetSlot(slotName)
        if not self._puppet then return false; end

        local rule = self:GetSleevesRule()
        local keepState = rule[pov]
        return self._mod:ChangeStateForSlot(self._puppet, slotName, keepState)
    end

    return context
end

---@param puppet gamePuppet
---@param slotName string
---@param keepState SleevesState
---@return boolean changed
function BetterSleeves:ChangeStateForSlot(puppet, slotName, keepState)
    if keepState == SleevesState.Current then return false; end

    local item = self:GetItem(puppet, slotName)
    if not item then return false; end

    local appearanceName = self:GetItemAppearanceName(puppet, item)

    local newAppearanceName    = appearanceName
    local hasAppearanceChanged = false
    if keepState == SleevesState.RolledUp then
        local n
        newAppearanceName, n = newAppearanceName:gsub("&TPP", "&FPP")
        hasAppearanceChanged = hasAppearanceChanged or n > 0
        newAppearanceName, n = newAppearanceName:gsub("&Full", "&Part")
        hasAppearanceChanged = hasAppearanceChanged or n > 0
    elseif keepState == SleevesState.RolledDown then
        local n
        newAppearanceName, n = newAppearanceName:gsub("&FPP", "&TPP")
        hasAppearanceChanged = hasAppearanceChanged or n > 0
        newAppearanceName, n = newAppearanceName:gsub("&Part", "&Full")
        hasAppearanceChanged = hasAppearanceChanged or n > 0
    else
        assert(false, "unhandled keep state '" .. SleevesState[keepState] .. "'")
    end

    if not hasAppearanceChanged then return false; end

    local transactionSystem = Game.GetTransactionSystem()
    transactionSystem:ChangeItemAppearanceByName(puppet, item:GetItemID(), newAppearanceName)
    return true
end

---@param slots string[]|nil
---@param puppet gamePuppet
---@param keepState SleevesState
function BetterSleeves:ChangeStateForPuppet(slots, puppet, keepState)
    slots = slots or self:GetSlotNamesToRoll(true)
    for _, slotName in next, slots do
        self:ChangeStateForSlot(puppet, slotName, keepState)
    end
end

---@param slots string[]|nil
---@param puppets gamePuppet[]
---@param keepState SleevesState
function BetterSleeves:ChangeStateForPuppets(slots, puppets, keepState)
    slots = slots or self:GetSlotNamesToRoll(true)
    for _, puppet in next, puppets do
        for _, slotName in next, slots do
            self:ChangeStateForSlot(puppet, slotName, keepState)
        end
    end
end

---@param context table|nil
---@param slots string[]|nil
---@param puppets gamePuppet[]
---@param pov "fpp"|"tpp"
function BetterSleeves:UpdateSleevesFor(context, slots, puppets, pov)
    context = context or self:CreateRuleFetchingContext()
    slots   = slots   or self:GetSlotNamesToRoll(true)

    for _, puppet in next, puppets do
        context:SetSlot(nil)
        context:SetPuppet(puppet)
        for _, slotName in next, slots do
            context:ApplySleevesRuleForSlot(slotName, pov)
        end
    end
end

function BetterSleeves:UpdateSleeves()
    local context = self:CreateRuleFetchingContext()
    local slots = self:GetSlotNamesToRoll(true)

    self:UpdateSleevesFor(context, slots, self:GetPuppetsFPP(), "fpp")
    self:UpdateSleevesFor(context, slots, self:GetPuppetsTPP(), "tpp")
end

---@param force boolean
---@param keepState SleevesState|nil If nil, sleeves are toggled.
function BetterSleeves:ToggleSleeves(force, keepState)
    self.forceKeepState = (force == true)
    if keepState == nil then
        self.keepState = (self.keepState ~= SleevesState.RolledDown
                and SleevesState.RolledDown
                or  SleevesState.RolledUp)
    else
        self.keepState = keepState
    end
    self:UpdateSleeves()
end

---Creates a new "Delayed Roll Down Sleeves Event(tm)" if the current delay is less than the new one.
---@param delay number Seconds to wait before auto-rolling down sleeves.
---@return boolean ok Whether or not an Auto-Roll could be performed.
function BetterSleeves:DoAutoRollSleevesDelayed(delay)
    if not self.autoRoll then return false; end
    self.scheduler:SetTask("auto-roll", function()
        if not self.autoRollOnVehiclesTPP then
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

        self:UpdateSleeves()
    end, delay)
    return true
end

---Creates a new "Sync Inventory Sleeves Event(r)" if the current delay is less than the new one.
---@param delay number Seconds to wait before syncing sleeves.
---@return boolean ok Whether or not a sync could be performed.
function BetterSleeves:DoSyncInventorySleevesDelayed(delay)
    if not self.syncInventoryPuppet then return false; end
    self.scheduler:SetTask("sync-inventory-sleeves", function()
        local isAutoRolling = self.scheduler:HasTask("auto-roll")
        if isAutoRolling then return; end

        local inventoryPuppet = self:GetInventoryPuppet()
        if not inventoryPuppet then return; end
        self:UpdateSleevesFor(nil, nil, {inventoryPuppet}, "tpp")
    end, delay)
    return true
end

local function Event_AutoRollSleeves()
    BetterSleeves:DoAutoRollSleevesDelayed(BetterSleeves.autoRollDelay)
    BetterSleeves:DoSyncInventorySleevesDelayed(BetterSleeves.syncInventoryPuppetDelay)
end

local function Event_SyncInventorySleeves()
    BetterSleeves:DoSyncInventorySleevesDelayed(BetterSleeves.syncInventoryPuppetDelay)
end

local function Event_DoorControllerPS_OnActionDemolition()
    if not (
        BetterSleeves.autoRoll and
        BetterSleeves.gorillaArmsRollUpOnDoorOpen
    ) then return; end

    local player = Game.GetPlayer()
    if not player then return; end

    local equipmentSystem = Game.GetScriptableSystemsContainer():Get("EquipmentSystem")
    local armsCyberwareId = equipmentSystem:GetActiveItem(player, gamedataEquipmentArea.ArmsCW)
    if not armsCyberwareId then return; end

    local armsCyberwareName = TweakDB:GetRecord(armsCyberwareId.id):FriendlyName()
    if armsCyberwareName ~= BetterSleeves.gorillaArmsWeaponName then return; end

    BetterSleeves:ChangeStateForPuppet(nil, player, SleevesState.RolledUp)
    BetterSleeves:DoAutoRollSleevesDelayed(BetterSleeves.gorillaArmsRollDownDelay)
end

local function Event_VehicleComponent_OnVehicleCameraChange()
    BetterSleeves:DoAutoRollSleevesDelayed(BetterSleeves.autoRollVehiclesDelay)
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

    -- EquipmentEx listeners
    if EquipmentEx then
        -- ObserveAfter("EquipmentEx.OutfitSystem", "EquipItem;ItemIDTweakDBID", Event_AutoRollSleeves)
        -- This is also called within EquipItem(): https://github.com/psiberx/cp2077-equipment-ex/blob/9c3990e758b663dd6dee752fc077f41eada431ce/scripts/OutfitSystem.reds#L617
        ObserveAfter("EquipmentEx.OutfitSystem", "UnequipItem;ItemID", Event_AutoRollSleeves)
    end

    -- Game listeners
    Observe("PlayerPuppet", "OnWeaponEquipEvent", Event_AutoRollSleeves)
    Observe("PlayerPuppet", "OnItemEquipped", Event_AutoRollSleeves)
    Observe("PlayerPuppet", "OnItemUnequipped", Event_AutoRollSleeves)
    Observe("PlayerPuppet", "OnMakePlayerVisibleAfterSpawn", Event_AutoRollSleeves)
    Observe("JournalManager", "OnQuestEntryTracked", Event_AutoRollSleeves)
    Observe("JournalManager", "OnQuestEntryUntracked", Event_AutoRollSleeves)
    Observe("InventoryDataManagerV2", "EquipItem", Event_AutoRollSleeves)
    Observe("InventoryDataManagerV2", "UnequipItem", Event_AutoRollSleeves)
    Observe("gameWardrobeSystem", "SetActiveClothingSetIndex", Event_AutoRollSleeves)

    Observe("DoorControllerPS", "OnActionDemolition", Event_DoorControllerPS_OnActionDemolition)

    Observe("VehicleComponent", "OnVehicleCameraChange", Event_VehicleComponent_OnVehicleCameraChange)

    -- On menu open is only needed for the first time the menu is opened.
    -- Event_UpdateSleeves will sync the inventory before the menu is even opened which makes inventory loading faster.
    Observe("gameuiInventoryGameController", "OnInitialize", Event_SyncInventorySleeves)
    Observe("gameuiInventoryGameController", "RefreshedEquippedItemData", Event_SyncInventorySleeves)
    -- Observe("gameuiInventoryGameController", "RefreshEquippedWardrobeItems", Event_SyncInventorySleeves)

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
    local mod = BetterSleeves

    if not mod.showUI then return; end
    if ImGui.Begin("Better Sleeves") then
        ImGui.Text("Sleeves |")
        ImGui.SameLine()

        if BetterUI.FitButtonN(2, "Roll Down") then
            mod:ToggleSleeves(mod.forceKeepState, SleevesState.RolledDown)
        end
        ImGui.SameLine()

        if BetterUI.FitButtonN(1, "Roll Up") then
            mod:ToggleSleeves(mod.forceKeepState, SleevesState.RolledUp)
        end
        ImGui.Separator()

        mod.autoRoll = ImGui.Checkbox("Auto-Roll", mod.autoRoll)
        if mod.autoRoll then
            mod.autoRollDelay = BetterUI.DragFloat("Roll Delay*", mod.autoRollDelay, 0.01, 0.01, 5, "%.2f")
            if ImGui.IsItemHovered() then
                ImGui.SetTooltip("*If too low, may stop sleeves from rolling down when changing clothes.")
            end

            ImGui.PushID("keep-state")
            if ImGui.Button("Toggle") then
                mod:ToggleSleeves(mod.forceKeepState)
            end
            ImGui.SameLine()
            mod.forceKeepState = ImGui.Checkbox("", mod.forceKeepState)
            ImGui.SameLine()
            ImGui.TextWrapped(table.concat{
                "Keep ",
                mod.forceKeepState and "Forcefully* " or "",
                Enum.ToHumanCase(SleevesState[mod.keepState]),
            })
            if mod.forceKeepState and ImGui.IsItemHovered() then
                ImGui.SetTooltip("*Ignores rules.")
            end
            ImGui.PopID()
            ImGui.Separator()

            mod.autoRollOnVehiclesTPP = ImGui.Checkbox("Allow on Vehicles TPP*", mod.autoRollOnVehiclesTPP)
            if ImGui.IsItemHovered() then
                ImGui.SetTooltip("*Can cause parts of clothes to disappear in TPP if sleeves are auto-rolled up.");
            end
            mod.autoRollVehiclesDelay = BetterUI.DragFloat("Vehicles Roll Delay*", mod.autoRollVehiclesDelay, 0.01, 0.01, 5, "%.2f")
            if ImGui.IsItemHovered() then
                ImGui.SetTooltip("*If too low, may stop sleeves from updating on TPP to FPP camera transitions.")
            end
            ImGui.Separator()

            ImGui.PushID("auto-roll_gorilla-arms")
            mod.gorillaArmsRollUpOnDoorOpen = ImGui.Checkbox("Roll Up on Gorilla Arms Door Open", mod.gorillaArmsRollUpOnDoorOpen)
            if mod.gorillaArmsRollUpOnDoorOpen then
                mod.gorillaArmsRollDownDelay = BetterUI.DragFloat("Re-Roll Delay", mod.gorillaArmsRollDownDelay, 0.01, 1, 5, "%.2f")
            end
            ImGui.PopID()
        end
        ImGui.Separator()
        ImGui.Separator()

        do
            ImGui.PushID("inventory_photo-mode")
            mod.syncInventoryPuppet = ImGui.Checkbox("Sync Inventory Character", mod.syncInventoryPuppet)

            if mod.syncInventoryPuppet then
                mod.syncInventoryPuppetDelay = BetterUI.DragFloat("Sync Delay*", mod.syncInventoryPuppetDelay, 0.01, 0.01, 5, "%.2f")
                if ImGui.IsItemHovered() then
                    ImGui.SetTooltip("*If too low, may stop sleeves from syncing when swapping clothes.");
                end
                if BetterUI.FitButtonN(1, "Perform Inventory Sync") then
                    mod:DoSyncInventorySleevesDelayed(0)
                end
            end

            ImGui.Separator()
            local photoModeSystem = Game.GetPhotoModeSystem()
            local photoPuppet = mod:GetPhotoPuppet()

            if photoModeSystem:IsPhotoModeActive() and photoPuppet then
                ImGui.TextWrapped("Photo Mode Sleeves |")
                ImGui.SameLine()
                if BetterUI.FitButtonN(3, "Sync") then mod:UpdateSleevesFor(nil, nil, {photoPuppet}, "tpp"); end
                ImGui.SameLine()
                if BetterUI.FitButtonN(2, "Roll Down") then mod:ChangeStateForPuppet(nil, photoPuppet, SleevesState.RolledDown); end
                ImGui.SameLine()
                if BetterUI.FitButtonN(1, "Roll Up") then mod:ChangeStateForPuppet(nil, photoPuppet, SleevesState.RolledUp); end
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

        ---@param rule SleevesRule
        local function ImSleevesRule(rule)
            ImGui.PushID("fpp")
                ImGui.Text("FPP")
                ImGui.SameLine()
                rule.fpp = Enum.ImCombo(SleevesState, rule.fpp, "")
            ImGui.PopID()
            ImGui.SameLine()
            ImGui.PushID("tpp")
                ImGui.Text("TPP")
                ImGui.SameLine()
                rule.tpp = Enum.ImCombo(SleevesState, rule.tpp, "")
            ImGui.PopID()
        end

        ---@param rules table<string, SleevesRule>
        ---@param ruleId string
        ---@param scope string
        ---@param label string
        local function ImSleevesRulesEntry(rules, ruleId, scope, label)
            ImGui.PushID(table.concat{ scope, "_", ruleId })
            local rule = rules[ruleId]
            if not rule then
                if BetterUI.ButtonAdd() then
                    rules[ruleId] = { fpp = SleevesState.RolledUp, tpp = SleevesState.RolledDown }
                end
            else
                if BetterUI.ButtonRemove() then
                    rules[ruleId] = nil
                end
                ImGui.SameLine()
                ImSleevesRule(rule)
            end
            ImGui.SameLine()
            ImGui.Text(label .. ruleId)
            ImGui.PopID()
        end

        local function ImSleevesRulesBegin()
            ImGui.PushID("sleeves-rules")
            return true
        end

        local function ImSleevesRulesEnd()
            ImGui.PopID()
        end

        if ImGui.CollapsingHeader("Edit Rules") then
            ImGui.PushID("edit-rules")
            ImGui.TextWrapped(table.concat{
                "Rules change the default behaviour of the mod for a specific",
                " mission, item and/or weapon depending on if you're looking at",
                " your character in FPP or TPP. Keep sleeves rolled up for items",
                " which have collars that clip in FPP or keep them rolled down",
                " for the ones which disappear in TPP, you can customize YOUR",
                " experience from this menu."
            })
            ImGui.TextWrapped("Rules are applied in the following order: Global State > Mission (Quest) > Mission (Objective) > Item > Weapon")
            ImGui.TextWrapped("You can choose between \"Current\", \"Rolled Down\" or \"Rolled Up\":")
            ImGui.Bullet(); ImGui.SameLine()
                ImGui.TextWrapped("\"Current\" does not modify the behaviour of previously applied rules.")
            ImGui.Bullet(); ImGui.SameLine()
                ImGui.TextWrapped("\"Rolled Down\" vanilla behaviour for TPP, sleeves are rolled down.")
            ImGui.Bullet(); ImGui.SameLine()
                ImGui.TextWrapped("\"Rolled Up\" vanilla behaviour for FPP, sleeves are rolled up.")
            ImGui.Separator()

            if ImSleevesRulesBegin() then
                local questId, objectiveId = mod:GetTrackedQuestAndObjectiveIds()
                if questId then
                    local entireQuest = questId .. ".*"
                    ImSleevesRulesEntry(mod.missionRules, entireQuest, "mission", "Quest: ")
                    if objectiveId then
                        local specificObjective = table.concat{questId, ".", objectiveId}
                        ImSleevesRulesEntry(mod.missionRules, specificObjective, "mission", "Objective: ")
                    end
                end

                local player = Game.GetPlayer()
                if player then
                    for slotName in next, mod.slotsToRoll do
                        local item = mod:GetItem(player, slotName)
                        if item then
                            local itemName = mod:GetItemAppearanceName(player, item):match("[^&]+")
                            ImSleevesRulesEntry(mod.itemRules, itemName, "slot", slotName:match("%.(.+)") .. " Item: ")
                        end
                    end

                    local weaponNames = mod:GetActiveWeaponsName(player)
                    for i, weaponName in ipairs(weaponNames) do
                        ImSleevesRulesEntry(mod.weaponRules, weaponName, "weapon", "Weapon" .. tostring(i) .. " Name: ")
                    end
                end

                ImGui.Separator()
                if BetterUI.FitButtonN(1, "Update Sleeves") then
                    mod:UpdateSleeves()
                end

                ImSleevesRulesEnd()
            end

            if ImGui.CollapsingHeader("Mission") then
                if ImSleevesRulesBegin() then
                    for missionName, rule in next, mod.missionRules do
                        ImSleevesRulesEntry(mod.missionRules, missionName, "mission", "")
                    end
                    ImGui.Separator()
                    if BetterUI.FitButtonN(1, "Update Sleeves") then
                        mod:UpdateSleeves()
                    end
                    ImSleevesRulesEnd()
                end
            end

            if ImGui.CollapsingHeader("Item") then
                if ImSleevesRulesBegin() then
                    for itemName, rule in next, mod.itemRules do
                        ImSleevesRulesEntry(mod.itemRules, itemName, "item", "")
                    end
                    ImGui.Separator()
                    if BetterUI.FitButtonN(1, "Update Sleeves") then
                        mod:UpdateSleeves()
                    end
                    ImSleevesRulesEnd()
                end
            end

            if ImGui.CollapsingHeader("Weapon") then
                if ImSleevesRulesBegin() then
                    for weaponName, rule in next, mod.weaponRules do
                        ImSleevesRulesEntry(mod.weaponRules, weaponName, "weapon", "")
                    end
                    ImGui.Separator()
                    if BetterUI.FitButtonN(1, "Update Sleeves") then
                        mod:UpdateSleeves()
                    end
                    ImSleevesRulesEnd()
                end
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
                if mod:DetectEquipmentExAndEnableSlots() then
                    mod.Log("'Detect EquipmentEx' button has found EquipmentEx.")
                else
                    mod.Log("'Detect EquipmentEx' button did not find EquipmentEx installed.")
                end
            end
            ImGui.Separator()

            ImGui.TextWrapped(table.concat{
                "Press this button if you enable/disable slots while Sleeves are rolled down.",
                " The mod won't try to roll up slots that are not enabled."
            })

            if BetterUI.FitButtonN(1, "Roll Up ALL Slots") then
                mod:ChangeStateForPuppets(mod:GetAllSlots(), mod:GetPuppets(), SleevesState.RolledUp)
            end
            ImGui.Separator()

            ImGui.PushID("user-slots")
            if BetterUI.ButtonAdd() then
                if not mod.slotsToRoll[mod._newSlot] then
                    mod.slotsToRoll[mod._newSlot] = {
                        type = SlotType.UserDefined,
                        enabled = true
                    }
                    mod._newSlot = ""
                end
            end
            ImGui.SameLine()
            mod._newSlot = ImGui.InputText("", mod._newSlot, 512)

            for slotName, slot in next, mod.slotsToRoll do
                if slot.type == SlotType.UserDefined then
                    ImGui.PushID(table.concat{ "user-slots_", slotName })
                    if BetterUI.ButtonRemove() then
                        mod.slotsToRoll[slotName] = nil
                    end
                    ImGui.SameLine()
                    mod.slotsToRoll[slotName].enabled = ImGui.Checkbox("", mod.slotsToRoll[slotName].enabled)
                    ImGui.SameLine()
                    ImGui.Text(slotName)
                    ImGui.PopID()
                end
            end

            for slotName, slot in next, mod.slotsToRoll do
                if slot.type ~= SlotType.UserDefined then
                    ImGui.PushID(table.concat{ "modded-slots_", slotName })
                    local newEnabled, changed = ImGui.Checkbox("", mod.slotsToRoll[slotName].enabled)
                    if changed then
                        mod.slotsToRoll[slotName].userHandled = true
                        mod.slotsToRoll[slotName].enabled = newEnabled
                    end
                    ImGui.PopID()
                    ImGui.SameLine()
                    ImGui.Text(table.concat{ "[", Enum.ToHumanCase(SlotType[slot.type]), "] ", slotName })
                end
            end
            ImGui.PopID()
        end

        ImGui.Separator()

        ImGui.Text("Config |")
        ImGui.SameLine()

        if BetterUI.FitButtonN(3, "Load") then mod:LoadConfig(); end
        ImGui.SameLine()

        if BetterUI.FitButtonN(2, "Save") then mod:SaveConfig(); end
        ImGui.SameLine()

        if BetterUI.FitButtonN(1, "Reset") then mod:ResetConfig(); end
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

    registerInput("rolldown_sleeves", "Roll Down Sleeves", _InputAsHotkey(function() self:ToggleSleeves(false, SleevesState.RolledDown) end))
    registerInput("rollup_sleeves",   "Roll Up Sleeves",   _InputAsHotkey(function() self:ToggleSleeves(false, SleevesState.RolledUp)   end))
    registerInput("toggle_sleeves",   "Toggle Sleeves",    _InputAsHotkey(function() self:ToggleSleeves(false) end))
    registerInput("force_rolldown_sleeves", "Force Roll Down Sleeves", _InputAsHotkey(function() self:ToggleSleeves(true, SleevesState.RolledDown) end))
    registerInput("force_rollup_sleeves",   "Force Roll Up Sleeves",   _InputAsHotkey(function() self:ToggleSleeves(true, SleevesState.RolledUp)   end))
    registerInput("force_toggle_sleeves",   "Force Toggle Sleeves",    _InputAsHotkey(function() self:ToggleSleeves(true) end))

    registerInput("update_sleeves", "Update Sleeves", _InputAsHotkey(function() self:UpdateSleeves() end))

    registerForEvent("onInit",     Event_OnInit)
    registerForEvent("onUpdate",   Event_OnUpdate)
    registerForEvent("onShutdown", Event_OnShutdown)
    registerForEvent("onDraw",         Event_OnDraw)
    registerForEvent("onOverlayOpen",  Event_OnOverlayOpen)
    registerForEvent("onOverlayClose", Event_OnOverlayClose)
    return self
end

return BetterSleeves:Init()
