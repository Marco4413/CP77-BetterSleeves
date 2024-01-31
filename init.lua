--[[
Copyright (c) 2024 [Marco4413](https://github.com/Marco4413/CP77-BetterSleeves)

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
    autoRollOnVehiclesTPP = false,
    showUI = false,
    delayTimer = 1.0,
    delayCallback = nil,
    ---This is not 100% accurate, and is only used by the "Toggle Sleeves" feature.
    rolledDown = false,
    rollDownDelay = 1.0,
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
    -- Populated within Event_OnInit
    slotToAreaType = {},
    appearanceSuffixCameraRecord = nil,
    gorillaArmsWeaponName = "w_strong_arms",
    gorillaArmsRollUpOnDoorOpen = true,
    gorillaArmsRollDownDelay = 3.15,
    UI = {},
}

function BetterSleeves.Log(...)
    print(table.concat{"[ ", os.date("%x %X"), " ][ BetterSleeves ]: ", ...})
end

function BetterSleeves:DetectEquipmentExAndAddSlots()
    if EquipmentEx then
        -- Equipment-EX Slots
        self.slotsToRoll["OutfitSlots.TorsoOuter"]  = self.SlotType.EQUIPMENT_EX
        self.slotsToRoll["OutfitSlots.TorsoMiddle"] = self.SlotType.EQUIPMENT_EX
        self.slotsToRoll["OutfitSlots.TorsoInner"]  = self.SlotType.EQUIPMENT_EX
        self.slotsToRoll["OutfitSlots.TorsoUnder"]  = self.SlotType.EQUIPMENT_EX
        self.slotsToRoll["OutfitSlots.TorsoAux"]    = self.SlotType.EQUIPMENT_EX
        self.slotsToRoll["OutfitSlots.BodyOuter"]   = self.SlotType.EQUIPMENT_EX
        self.slotsToRoll["OutfitSlots.BodyMiddle"]  = self.SlotType.EQUIPMENT_EX
        self.slotsToRoll["OutfitSlots.BodyInner"]   = self.SlotType.EQUIPMENT_EX
        self.slotsToRoll["OutfitSlots.BodyUnder"]   = self.SlotType.EQUIPMENT_EX
        return true
    end
    return false
end

function BetterSleeves:ResetConfig()
    self.autoRoll = true
    self.autoRollOnVehiclesTPP = false
    self.rollDownDelay = 1.0
    self.rollDownItemBlacklist = {}
    self.rollDownWeaponBlacklist = {}
    self.rollDownMissionBlacklist = {}
    self.slotsToRoll = {
        ["AttachmentSlots.Outfit"] = self.SlotType.VANILLA,
        ["AttachmentSlots.Torso"]  = self.SlotType.VANILLA,
        ["AttachmentSlots.Chest"]  = self.SlotType.VANILLA
    }
    self:DetectEquipmentExAndAddSlots()
    self.gorillaArmsRollUpOnDoorOpen = true
    self.gorillaArmsRollDownDelay = 3.15
    -- Add all blacklist entries
    self:MigrateConfigFromVersion(nil)
end

function BetterSleeves:SaveConfig()
    local file = io.open("data/config.json", "w")

    local userSlots = {}
    for slot, type in next, self.slotsToRoll do
        if type == self.SlotType.USER_DEFINED then
            userSlots[slot] = self.SlotType.USER_DEFINED
        end
    end

    file:write(json.encode({
        version = 3,
        autoRoll = self.autoRoll,
        autoRollOnVehiclesTPP = self.autoRollOnVehiclesTPP,
        rollDownDelay = self.rollDownDelay,
        rollDownItemBlacklist = self.rollDownItemBlacklist,
        rollDownWeaponBlacklist = self.rollDownWeaponBlacklist,
        rollDownMissionBlacklist = self.rollDownMissionBlacklist,
        slotsToRoll = userSlots,
        gorillaArmsRollUpOnDoorOpen = self.gorillaArmsRollUpOnDoorOpen,
        gorillaArmsRollDownDelay = self.gorillaArmsRollDownDelay,
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

    if version <= 2 then
        version = 3
        self.rollDownItemBlacklist["outfit_02__trauma_"] = true
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

        if type(config.autoRollOnVehiclesTPP) == "boolean" then
            self.autoRollOnVehiclesTPP = config.autoRollOnVehiclesTPP
        end

        if type(config.rollDownDelay) == "number" then
            self.rollDownDelay = config.rollDownDelay
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
            for slot, type in next, config.slotsToRoll do
                if type == self.SlotType.USER_DEFINED and not self.slotsToRoll[slot] then
                    self.slotsToRoll[slot] = type
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
    NoCameraSuffix = 2,
    SamePOV = 3,
    ItemBlacklisted = 4,
    WeaponBlacklisted = 5,
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

---@param slot string
---@param fpp boolean
---@param itemBlacklist table
---@param weaponBlacklist table
---@param missionBlacklist table
---@return POVChangeResult
function BetterSleeves:ChangeItemPOV(slot, fpp, itemBlacklist, weaponBlacklist, missionBlacklist)
    local item = self:GetItem(slot)
    if not item then return POVChangeResult.NoItem; end

    local itemRecord = TweakDB:GetRecord(item:GetItemID().id)
    if not itemRecord:AppearanceSuffixesContains(self.appearanceSuffixCameraRecord) then
        return POVChangeResult.NoCameraSuffix
    end

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
                for slot, at in next, self.slotToAreaType do
                    if areaType == at then
                        table.insert(slots, slot)
                        break
                    end
                end
            end
        end
    else
        for slot in next, self.slotsToRoll do
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
    for slot in next, self.slotsToRoll do
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

local function AutoRollDownSleevesDelayedCB()
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

    BetterSleeves:RollDownSleeves()
end

---Creates a new "Delayed Roll Down Sleeves Event(tm)" if the current delay is less than the new one.
---@param delay number Seconds to wait before auto-rolling down sleeves.
---@return boolean ok Whether or not an Auto-Roll could be performed.
function BetterSleeves:DoAutoRollDownSleevesDelayed(delay)
    if not BetterSleeves.autoRoll then
        return false
    elseif BetterSleeves.autoRoll and ((not self.delayCallback) or self.delayTimer < delay) then
        self.delayTimer = delay
        self.delayCallback = AutoRollDownSleevesDelayedCB
    end
    return true
end

function BetterSleeves.UI.ButtonAdd()
    local lineHeight = ImGui.GetTextLineHeightWithSpacing()
    ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 0.0)
    ImGui.PushStyleColor(ImGuiCol.Text, .1, .9, 0, 1)
    local res = ImGui.Button("+", lineHeight, lineHeight)
    ImGui.PopStyleColor()
    ImGui.PopStyleVar()
    return res
end

function BetterSleeves.UI.ButtonRemove()
    local lineHeight = ImGui.GetTextLineHeightWithSpacing()
    ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 0.0)
    ImGui.PushStyleColor(ImGuiCol.Text, .9, .1, 0, 1)
    local res = ImGui.Button("-", lineHeight, lineHeight)
    ImGui.PopStyleColor()
    ImGui.PopStyleVar()
    return res
end

function BetterSleeves.UI.DragFloat(...)
    ImGui.PushItemWidth(100)
    local value, changed = ImGui.DragFloat(...)
    ImGui.PopItemWidth()
    return value, changed
end

local function Event_RollDownSleeves()
    BetterSleeves:DoAutoRollDownSleevesDelayed(BetterSleeves.rollDownDelay)
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

    BetterSleeves:RollUpSleeves()
    BetterSleeves:DoAutoRollDownSleevesDelayed(BetterSleeves.gorillaArmsRollDownDelay)
end

local function Event_OnInit()
    if EquipmentEx then
        BetterSleeves.Log("EquipmentEx found.")
    end
    BetterSleeves:ResetConfig() -- Loads default settings
    BetterSleeves:LoadConfig()

    BetterSleeves.appearanceSuffixCameraRecord = TweakDB:GetRecord("itemsFactoryAppearanceSuffix.Camera")

    BetterSleeves.slotToAreaType["AttachmentSlots.Outfit"] = gamedataEquipmentArea.Outfit
    BetterSleeves.slotToAreaType["AttachmentSlots.Torso"] = gamedataEquipmentArea.OuterChest
    BetterSleeves.slotToAreaType["AttachmentSlots.Chest"] = gamedataEquipmentArea.InnerChest

    Observe("PlayerPuppet", "OnWeaponEquipEvent", Event_RollDownSleeves)
    Observe("PlayerPuppet", "OnItemAddedToSlot", Event_RollDownSleeves)
    -- Observe("PlayerPuppet", "OnItemRemovedFromSlot", Event_RollDownSleeves)
    Observe("PlayerPuppet", "OnMakePlayerVisibleAfterSpawn", Event_RollDownSleeves)
    Observe("JournalManager", "OnQuestEntryTracked", Event_RollDownSleeves)
    Observe("JournalManager", "OnQuestEntryUntracked", Event_RollDownSleeves)
    Observe("gameWardrobeSystem", "SetActiveClothingSetIndex", Event_RollDownSleeves)

    Observe("DoorControllerPS", "OnActionDemolition", Event_DoorControllerPS_OnActionDemolition)

    -- PlayerPuppet.OnItemRemovedFromSlot is also called when changing vehicle camera
    Observe("VehicleComponent", "OnVehicleCameraChange", Event_RollDownSleeves)
    BetterSleeves.Log("Initialized!")
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
        do
            ImGui.Text("Sleeves |")
            ImGui.SameLine()
            
            local widthAvail, _ = ImGui.GetContentRegionAvail()
            local lineHeight = ImGui.GetTextLineHeightWithSpacing()
            local buttonWidth = widthAvail/2 - 2.5

            if ImGui.Button("Roll Down", buttonWidth, lineHeight) then BetterSleeves:RollDownSleeves(); end
            ImGui.SameLine()
    
            if ImGui.Button("Roll Up", buttonWidth, lineHeight) then BetterSleeves:RollUpSleeves(); end
            ImGui.Separator()
        end

        BetterSleeves.autoRoll = ImGui.Checkbox("Auto-Roll", BetterSleeves.autoRoll)
        if BetterSleeves.autoRoll then
            BetterSleeves.rollDownDelay = BetterSleeves.UI.DragFloat("Roll Down Delay", BetterSleeves.rollDownDelay, 0.01, 1, 5, "%.2f")
            BetterSleeves.autoRollOnVehiclesTPP = ImGui.Checkbox("Allow on Vehicles TPP*", BetterSleeves.autoRollOnVehiclesTPP)
            if ImGui.IsItemHovered() then
              ImGui.SetTooltip("*Can cause parts of clothes to disappear in TPP if sleeves are auto-rolled up.");
            end
            ImGui.Separator()

            ImGui.PushID("auto-roll_gorilla-arms")
            BetterSleeves.gorillaArmsRollUpOnDoorOpen = ImGui.Checkbox("Roll Up on Gorilla Arms Door Open", BetterSleeves.gorillaArmsRollUpOnDoorOpen)
            if BetterSleeves.gorillaArmsRollUpOnDoorOpen then
                BetterSleeves.gorillaArmsRollDownDelay = BetterSleeves.UI.DragFloat("Roll Down Delay", BetterSleeves.gorillaArmsRollDownDelay, 0.01, 1, 5, "%.2f")
            end
            ImGui.PopID()
        end
        ImGui.Separator()

        if ImGui.CollapsingHeader("Item Blacklist") then
            ImGui.PushID("item-blacklist")
            if BetterSleeves.UI.ButtonAdd() then
                BetterSleeves.rollDownItemBlacklist[BetterSleeves._newItem] = true
                BetterSleeves._newItem = ""
            end
            ImGui.SameLine()
            BetterSleeves._newItem = ImGui.InputText("", BetterSleeves._newItem, 256)

            for item in next, BetterSleeves.rollDownItemBlacklist do
                ImGui.PushID(table.concat{ "item-blacklist_", item })
                if BetterSleeves.UI.ButtonRemove() then
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
            if BetterSleeves.UI.ButtonAdd() then
                BetterSleeves.rollDownWeaponBlacklist[BetterSleeves._newWeapon] = true
                BetterSleeves._newWeapon = ""
            end
            ImGui.SameLine()
            BetterSleeves._newWeapon = ImGui.InputText("", BetterSleeves._newWeapon, 256)

            for weapon in next, BetterSleeves.rollDownWeaponBlacklist do
                ImGui.PushID(table.concat{ "weapon-blacklist_", weapon })
                if BetterSleeves.UI.ButtonRemove() then
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
            if BetterSleeves.UI.ButtonAdd() then
                BetterSleeves.rollDownMissionBlacklist[BetterSleeves._newMission] = true
                BetterSleeves._newMission = ""
            end
            ImGui.SameLine()
            BetterSleeves._newMission = ImGui.InputText("", BetterSleeves._newMission, 512)

            for mission in next, BetterSleeves.rollDownMissionBlacklist do
                ImGui.PushID(table.concat{ "mission-blacklist_", mission })
                if BetterSleeves.UI.ButtonRemove() then
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
                "If you don't see any EquipmentEx slot, it means that this mod did not find it installed.",
                " If you think that's not the case, try pressing the button below."
            })

            do
                local widthAvail, _ = ImGui.GetContentRegionAvail()
                if ImGui.Button("Detect EquipmentEx", widthAvail, ImGui.GetTextLineHeightWithSpacing()) then
                    if BetterSleeves:DetectEquipmentExAndAddSlots() then
                        BetterSleeves.Log("'Detect EquipmentEx' button has found EquipmentEx.")
                    else
                        BetterSleeves.Log("'Detect EquipmentEx' button did not find EquipmentEx installed.")
                    end
                end
                ImGui.Separator()
            end

            ImGui.PushID("user-slots")
            if BetterSleeves.UI.ButtonAdd() then
                if not BetterSleeves.slotsToRoll[BetterSleeves._newSlot] then
                    BetterSleeves.slotsToRoll[BetterSleeves._newSlot] = BetterSleeves.SlotType.USER_DEFINED
                    BetterSleeves._newSlot = ""
                end
            end
            ImGui.SameLine()
            BetterSleeves._newSlot = ImGui.InputText("", BetterSleeves._newSlot, 512)

            for slot, type in next, BetterSleeves.slotsToRoll do
                if type == BetterSleeves.SlotType.USER_DEFINED then
                    ImGui.PushID(table.concat{ "user-slots_", slot })
                    if BetterSleeves.UI.ButtonRemove() then
                        BetterSleeves.slotsToRoll[slot] = nil
                    end
                    ImGui.SameLine()
                    ImGui.Text(slot .. " (User Defined)")
                    ImGui.PopID()
                end
            end

            for slot, type in next, BetterSleeves.slotsToRoll do
                if type == BetterSleeves.SlotType.VANILLA then
                    ImGui.Text(slot .. " (Vanilla)")
                elseif type == BetterSleeves.SlotType.EQUIPMENT_EX then
                    ImGui.Text(slot .. " (EquipmentEx)")
                elseif type ~= BetterSleeves.SlotType.USER_DEFINED then
                    ImGui.Text(slot .. " (Other Mods)")
                end
            end
            ImGui.PopID()
        end

        if ImGui.CollapsingHeader("Quick Blacklist") then
            ImGui.TextWrapped("Within this section you can quickly blacklist equipped items, active weapons and quests.")

            for slot in next, BetterSleeves.slotsToRoll do
                local item = BetterSleeves:GetItem(slot)
                if item then
                    local itemName = BetterSleeves:GetItemAppearanceName(item):match("[^&]+")
                    ImGui.PushID(table.concat{ "slot-qb_", slot })
                    if ImGui.Button("Blacklist") then
                        BetterSleeves.rollDownItemBlacklist[itemName] = true
                    end
                    ImGui.SameLine()
                    ImGui.Text(table.concat { slot:match("%.(.+)"), " Item: ", itemName })
                    ImGui.PopID()
                end
            end

            local player = Game.GetPlayer()
            if player then
                local weapon = player:GetActiveWeapon()
                if weapon then
                    local weaponName = weapon:GetWeaponRecord():FriendlyName()
                    ImGui.PushID("weapon-qb")
                    if ImGui.Button("Blacklist") then
                        BetterSleeves.rollDownWeaponBlacklist[weaponName] = true
                    end
                    ImGui.SameLine()
                    ImGui.Text("Weapon Name: " .. weaponName)
                    ImGui.PopID()
                end
            end

            local quest, obj = BetterSleeves:GetTrackedMissionAndObjectiveIds()
            if quest then
                ImGui.PushID("quest-qb")
                if ImGui.Button("Blacklist") then
                    BetterSleeves.rollDownMissionBlacklist[table.concat{quest, ".*"}] = true
                end
                ImGui.SameLine()
                ImGui.Text("Quest ID: " .. quest)
                ImGui.PopID()

                ImGui.PushID("objective-qb")
                if ImGui.Button("Blacklist") then
                    BetterSleeves.rollDownMissionBlacklist[table.concat{quest, ".", obj}] = true
                end
                ImGui.SameLine()
                ImGui.Text("Objective ID: " .. obj)
                ImGui.PopID()
            end
        end

        ImGui.Separator()

        do
            ImGui.Text("Config |")
            ImGui.SameLine()

            local widthAvail, _ = ImGui.GetContentRegionAvail()
            local lineHeight = ImGui.GetTextLineHeightWithSpacing()
            local buttonWidth = widthAvail/3 - 5

            if ImGui.Button("Load", buttonWidth, lineHeight) then BetterSleeves:LoadConfig(); end
            ImGui.SameLine()
    
            if ImGui.Button("Save", buttonWidth, lineHeight) then BetterSleeves:SaveConfig(); end
            ImGui.SameLine()
    
            if ImGui.Button("Reset", buttonWidth, lineHeight) then BetterSleeves:ResetConfig(); end
            ImGui.Separator()
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
