------------
-- Documentation: https://wardz.github.io/FocusFrame/.
-- Feel free to use or fork this module.
-- See FocusFrame.lua for examples.
-- @module FocusData
-- @author Wardz
-- @license MIT
local _G = getfenv(0)
if _G.FocusData then return end
print = print or function(msg) DEFAULT_CHAT_FRAME:AddMessage(msg or "nil") end

-- Vars
local Focus = {}
local focusTargetName
local partyUnit
local rawData
local data

-- Upvalues
local GetTime, next, strfind, UnitName, TargetLastTarget, TargetByName, strlower, type, tgetn =
      GetTime, next, strfind, UnitName, TargetLastTarget, TargetByName, strlower, type, table.getn

local FSPELLCASTINGCOREgetBuffs, FRGB_BORDER_DEBUFFS_COLOR = FSPELLCASTINGCOREgetBuffs, FRGB_BORDER_DEBUFFS_COLOR

-- Functions
local NameplateScanner
local PartyScanner
local SetFocusAuras
local CallHooks

-- Event handling for data struct
do
    local rawset = rawset

    --- FocusData events.
    -- List of events that you can register for. All events can be
    -- registered multiple times.
    -- @table Events
    -- @usage Focus:OnEvent("EVENT_NAME", callbackFunc)
    -- @field UNIT_HEALTH_OR_POWER arg1=event or nil, arg2=unit or nil
    -- @field UNIT_LEVEL arg1=event or nil, arg2=unit or nil
    -- @field UNIT_AURA arg1=event or nil, arg2=unit or nil
    -- @field UNIT_CLASSIFICATION_CHANGED
    -- @field PLAYER_FLAGS_CHANGED
    -- @field RAID_TARGET_UPDATE
    -- @field FOCUS_UNITID_EXISTS arg1=event, arg2=unit
    -- @field FOCUS_SET arg1=event, arg2=unit
    -- @field FOCUS_CHANGED arg1=event, arg2=unit
    -- @field FOCUS_CLEAR
    -- @field UNIT_FACTION arg1=event, arg2=unit
    local events = {
        health              = "UNIT_HEALTH_OR_POWER",
        maxHealth           = "UNIT_HEALTH_OR_POWER",
        power               = "UNIT_HEALTH_OR_POWER",
        maxPower            = "UNIT_HEALTH_OR_POWER",
        unitLevel           = "UNIT_LEVEL",
        auraUpdate          = "UNIT_AURA",
        unitClassification  = "UNIT_CLASSIFICATION_CHANGED",
        unitIsPartyLeader   = "PLAYER_FLAGS_CHANGED",
        raidIcon            = "RAID_TARGET_UPDATE",
        unit                = "FOCUS_UNITID_EXISTS",
        unitIsPVP           = "UNIT_FACTION",
        unitIsTapped        = "UNIT_FACTION",
        unitIsTappedByPlayer = "UNIT_FACTION",
    }

    rawData = { eventsThrottle = {} }

    -- data = rawData, but:
    -- data.x will trigger events.
    -- rawData.x will not and has less overhead.

    data = setmetatable({}, {
        __index = function(self, key)
            local value = rawData[key]
            if value == nil then error("unknown key: " .. key) end
            return value
        end,

        -- This function is called everytime a property in data has been changed
        __newindex = function(self, key, value)
            local oldValue = rawData[key]
            rawset(rawData, key, value)

            -- Call event listeners if property has event
            if not rawData.init and events[key] then
                if not focusTargetName then return end
                if key ~= "auraUpdate" then
                    if oldValue == value then return end
                end
                if key == "unit" and not value then return end

                local getTime = GetTime()
                local last = rawData.eventsThrottle[key]
                if last then
                    if (getTime - last) < 0.1 then return end
                end
                rawData.eventsThrottle[key] = getTime

                CallHooks(events[key], rawData.unit)
            end
        end
    })
end

-- Aura unit scanning
do
    local ClearBuffs = FSPELLCASTINGCOREClearBuffs
    local NewBuff = FSPELLCASTINGCORENewBuff
    local GetLastAura = FSPELLCASTINGCOREGetLastBuffInfo
    local UnitBuff, UnitDebuff = UnitBuff, UnitDebuff

    local FocusDataScantip = CreateFrame("GameTooltip", "FocusDataScantip", nil, "GameTooltipTemplate")
    FocusDataScantip:SetOwner(UIParent, "ANCHOR_NONE")
    FocusDataScantip:SetFrameStrata("TOOLTIP")

    local scantip = _G["FocusDataScantip"]
    local scantipTextLeft1 = _G["FocusDataScantipTextLeft1"]
    local scantipTextRight1 = _G["FocusDataScantipTextRight1"]

    local prevTexture = ""
    local prevAmount = 0
    local prevRan = false

    local function SyncBuff(unit, i, texture, stack, debuffType, isDebuff)
        scantip:ClearLines()
        scantipTextRight1:SetText(nil) -- ClearLines hides right text instead of clearing it

        if isDebuff then
            scantip:SetUnitDebuff(unit, i)
        else
            scantip:SetUnitBuff(unit, i)
        end

        -- Get buff name. UnitBuff only gives texture
        local name = scantipTextLeft1:GetText()
        if name then
            if isDebuff and not debuffType or debuffType == "" then
                debuffType = scantipTextRight1:GetText()
            end

            NewBuff(focusTargetName, name, texture, isDebuff, debuffType, stack)
            prevTexture = texture
        end
    end

    local function HasAurasChanged()
        local len, texture = GetLastAura(focusTargetName)

        if len == prevAmount then
            if prevTexture == texture then
                return false
            end
        end

        return true
    end

    function SetFocusAuras(unit) --local
        --if not HasAurasChanged() then return end

        -- Delete all buffs stored in DB, then re-add them later if found on target
        -- This is needed when buffs are not removed in the combat log. (i.e unit out of range)
        -- If unit is enemy, only debuffs are deleted.
        -- TODO continue only if buffList has changed
        if rawData.health <= 0 then
            return ClearBuffs(focusTargetName, false)
        end
        ClearBuffs(focusTargetName, rawData.unitIsEnemy == 1)

        -- TODO add support for Detect Magic

        for i = 1, 5 do
            local texture = UnitBuff(unit, i)
            if not texture then break end
            SyncBuff(unit, i, texture)
        end

        for i = 1, 16 do
            local texture, stack, debuffType = UnitDebuff(unit, i)
            if not texture then break end
            SyncBuff(unit, i, texture, stack, debuffType, true)
        end

        prevAmount = GetLastAura(focusTargetName)
        CallHooks("UNIT_AURA")
    end
end

-- Nameplate scanning
do
    local WorldFrame, ipairs = WorldFrame, ipairs

    local RaidIconCoordinate = {
        [0]		= { [0]	= 1,	[0.25]	= 5, },
        [0.25]	= { [0]	= 2,	[0.25]	= 6, },
        [0.5]	= { [0]	= 3,	[0.25]	= 7, },
        [0.75]	= { [0]	= 4,	[0.25]	= 8, },
    }

    local function IsPlate(overlayRegion)
        if not overlayRegion or overlayRegion:GetObjectType() ~= "Texture"
        or overlayRegion:GetTexture() ~= [[Interface\Tooltips\Nameplate-Border]] then
            return false
        end
        return true
    end

    function NameplateScanner() -- local
        --if rawData.unitIsEnemy and GetCVar("nameplateShowEnemies") == "1" then return end
        --if rawData.unitIsFriend and GetCVar("nameplateShowFriends") == "1" then return end

        for _, plate in ipairs({ WorldFrame:GetChildren() }) do
            local overlay, _, name, level, _, raidIcon = plate:GetRegions()

            if plate:IsVisible() and IsPlate(overlay) then
                if name:GetText() == focusTargetName then
                    if raidIcon and raidIcon:IsVisible() then
                        local ux, uy = raidIcon:GetTexCoord()
                        data.raidIcon = RaidIconCoordinate[ux][uy]
                    end

                    data.health = plate:GetChildren():GetValue()

                    local lvl = level:GetText()
                    if lvl then -- lvl is not shown when unit is skull (too high lvl)
                        data.unitLevel = tonumber(lvl)
                    end
                    return
                end
            end
        end
    end
end

local function SetFocusHealth(unit)
    data.health = UnitHealth(unit)
    data.maxHealth = UnitHealthMax(unit)
    data.power = UnitMana(unit)
    data.maxPower = UnitManaMax(unit)
    data.powerType = UnitPowerType(unit)
end

local function SetFocusInfo(unit, resetRefresh)
	if not Focus:UnitIsFocus(unit) then return false end

    local getTime = GetTime()

    -- Changing these will trigger event.
    -- Ran every 0.2s
    data.unit = unit
    SetFocusHealth(unit)
    SetFocusAuras(unit)
    data.raidIcon = GetRaidTargetIndex(unit)
    data.unitLevel = UnitLevel(unit)
    data.unitIsPVP = UnitIsPVP(unit)
    data.unitIsTapped = UnitIsTapped(unit)
    data.unitIsTappedByPlayer = UnitIsTappedByPlayer(unit)

    if resetRefresh then
        rawData.refreshed = nil
    end

    if rawData.refreshed then
        if (getTime - rawData.refreshed) < 4 then
            return true
        end
    end

    data.unitIsPartyLeader = UnitIsPartyLeader(unit)
    data.unitClassification = UnitClassification(unit)

    -- Data without event triggers.
    -- Ran every ~4s while unit is targeted
    rawData.playerCanAttack = UnitCanAttack("player", unit)
    rawData.unitCanAttack = UnitCanAttack(unit, "player")
    rawData.unitIsEnemy = rawData.playerCanAttack == 1 and rawData.unitCanAttack == 1 and 1 -- UnitIsEnemy() does not count neutral targets
    rawData.unitIsFriend = UnitIsFriend(unit, "player")
    rawData.unitReaction = UnitReaction(unit, "player")
    rawData.unitIsConnected = UnitIsConnected(unit)
    rawData.unitFactionGroup = UnitFactionGroup(unit)
    rawData.unitClass = UnitClass(unit)
    rawData.unitName = GetUnitName(unit)
    rawData.unitIsPlayer = UnitIsPlayer(unit)
    rawData.unitIsCivilian = UnitIsCivilian(unit)
    rawData.unitIsCorpse = UnitIsCorpse(unit)
    rawData.unitIsPVPFreeForAll = UnitIsPVPFreeForAll(unit)
    rawData.unitPlayerControlled = UnitPlayerControlled(unit)
    rawData.refreshed = getTime
    -- More data can be sat using Focus:SetData() in FOCUS_SET event

	return true
end

-- Raid/party unit scanning
do
    local UnitInRaid, GetNumRaidMembers, GetNumPartyMembers =
          UnitInRaid, GetNumRaidMembers, GetNumPartyMembers

    local raidMemberIndex = 1

	function PartyScanner() --local
        local groupType = UnitInRaid("player") and "raid" or "party"
        local members = groupType == "raid" and GetNumRaidMembers() or GetNumPartyMembers()

        if members > 0 then
            local unit = groupType .. raidMemberIndex .. (rawData.unitIsEnemy == 1 and "target" or "")
            local unitPet = groupType .. "pet" .. raidMemberIndex .. (rawData.unitIsEnemy == 1 and "target" or "")
            -- "party1", "party1target" if focus is enemy and so on

            if SetFocusInfo(unit, true) then
                raidMemberIndex = 1
                partyUnit = unit -- cache unit id
            elseif SetFocusInfo(unitPet, true) then
                raidMemberIndex = 1
                partyUnit = unitPet
            else
                partyUnit = nil
                -- Scan 1 unitID every frame instead of all at once
                raidMemberIndex = raidMemberIndex < members and raidMemberIndex + 1 or 1
            end
        end
	end
end

--------------------------------------
-- Public API
-- Most of these may only be used after certain events,
-- or in an OnUpdate script with focus exist check.
-- Documentation: https://wardz.github.io/FocusFrame/
--------------------------------------

--- Misc
-- @section misc

--- Display focus UI error
-- @tparam[opt="You have no focus"] string msg
function Focus:ShowError(msg)
    UIErrorsFrame:AddMessage("|cffFF003F " .. (msg or "You have no focus.") .. "|r")
end

--- Unit
-- @section unit

--- Check if unit ID or unit name matches focus target.
-- @tparam string unit
-- @tparam[opt=false] bool checkName
-- @treturn bool true if match
function Focus:UnitIsFocus(unit, checkName)
    if not checkName then
        return focusTargetName and UnitName(unit) == focusTargetName
    else
        return unit == focusTargetName
    end
end

--- Get unit ID for focus if available
-- @treturn[1] string unitID
-- @treturn[2] nil
function Focus:GetFocusUnit()
    if rawData.unit and UnitExists(rawData.unit) and self:UnitIsFocus(rawData.unit) then
        return rawData.unit
    end
end

--- Check if focus is sat. (Not same as UnitExists!)
-- @tparam[opt=false] bool showError display UI error msg
-- @treturn bool true if exists
function Focus:FocusExists(showError)
    if showError and not focusTargetName then
        self:ShowError()
    end

    return focusTargetName ~= nil
end

--- Use any unit function on focus target, i.e CastSpellByName.
-- @usage Focus:Call(CastSpellByName, "Fireball") -- Casts Fireball on focus target
-- @usage Focus:Call(DropItemOnUnit); -- defaults to focus unit if no second arg given
-- @tparam func func function reference
-- @param arg1
-- @param arg2
-- @param arg3
-- @param arg4
function Focus:Call(func, arg1, arg2, arg3, arg4) -- no vararg in this lua version so this'll have to do for now
    if self:FocusExists(true) then
        if type(func) == "function" then
            arg1 = arg1 or "target" --focus
            self:TargetFocus()
            func(arg1, arg2, arg3, arg4)
            self:TargetPrevious()
        else
            error("Usage: Focus:Call(function, arg1,arg2,arg3,arg4)")
        end
    end
end

--- Target the focus.
-- @tparam[opt=nil] string name
-- @tparam[opt=false] bool setFocusName if true, sets focus name to UnitName("target")
function Focus:TargetFocus(name, setFocusName)
    if not setFocusName and not self:FocusExists() then
        return self:ShowError()
    end

    self.oldTarget = UnitName("target")
    if not self.oldTarget or self.oldTarget ~= focusTargetName then
        if rawData.unitIsPlayer ~= 1 then
            local _name = strsub(name or focusTargetName, 1, -2)
            TargetByName(_name, false)
            -- Case insensitive name will make the game target nearest enemy
            -- instead of random

            if UnitIsDead("target") == 1 then
                TargetByName(name or focusTargetName, true)
            end
        else
            TargetByName(name or focusTargetName, true)
        end

        self.needRetarget = true
    else
        self.needRetarget = false
    end

    if setFocusName then
        -- name is case sensitive, so we'll just let UnitName handle the parsing for
        -- /focus <name>
        focusTargetName = UnitName("target")
        CURR_FOCUS_TARGET = focusTargetName -- global
    end

    SetFocusInfo("target", true)
end

-- @private
function Focus:TargetPrevious()
    if self.oldTarget and self.needRetarget then
        TargetLastTarget()

        if UnitName("target") ~= self.oldTarget then
            -- TargetLastTarget seems to bug out randomly,
            -- so use this as fallback
            self:TargetFocus(self.oldTarget)
        end
    elseif not self.oldTarget then
        ClearTarget()
    end
end

local ToUpper = function(a, b) return strupper(a) .. b end

--- Set current target as focus, or name if given.
-- @tparam[opt=nil] string name
function Focus:SetFocus(name)
    if not name or name == "" then
        name = UnitName("target")
    end

    local isFocusChanged = Focus:FocusExists()
    focusTargetName = name

    if focusTargetName then
        rawData.init = true -- prevent calling events, FOCUS_SET will handle that here
        self:TargetFocus(name, true)
        rawData.init = nil

        if self:FocusExists() then
            CallHooks("FOCUS_SET", "target")
            if isFocusChanged then
                CallHooks("FOCUS_CHANGED", "target")
            end
        else
            self:ClearFocus()
        end

        self:TargetPrevious()
    else
        self:ClearFocus()
    end
end

--- Check if focus is dead.
-- @treturn bool true if dead
function Focus:IsDead()
    return rawData.health and rawData.health <= 0 --and data.unitIsConnected
end

--- Remove focus & all data.
function Focus:ClearFocus()
    focusTargetName = nil
    CURR_FOCUS_TARGET = nil
    partyUnit = nil
    self:ClearData()

    CallHooks("FOCUS_CLEAR")
end

--- Getters
-- @section getters

--- Get focus unit name.
-- Global var CURR_FOCUS_TARGET may also be used.
-- @treturn[1] string unit name
-- @treturn[2] nil
function Focus:GetName()
    return focusTargetName
end

--- Get focus health.
-- @treturn number min
-- @treturn number max
function Focus:GetHealth()
    return rawData.health or 0, rawData.maxHealth or 100
end

--- Get focus power.
-- @treturn number min
-- @treturn number max
function Focus:GetPower()
    return rawData.power or 0, rawData.maxPower or 100
end

--- Get statusbar color for power.
-- @treturn table {r=number,g=number,b=number}
function Focus:GetPowerColor()
    return ManaBarColor[rawData.powerType] or { r = 0, g = 0, b = 0 }
end

--- Get border color for debuffs.
-- Uses numeric indexes.
-- @tparam string debuffType e.g "magic" or "physical"
-- @return table
function Focus:GetDebuffColor(debuffType)
    return debuffType and FRGB_BORDER_DEBUFFS_COLOR[strlower(debuffType)] or { 0, 0, 0, 0 }
end

--- Get table containing all buff+debuff data for focus.
-- Should be ran in an OnUpdate script or OnEvent("UNIT_AURA")
-- This list can only be traversed in a for loop. Do not use pairs!
-- @treturn table data or empty table
function Focus:GetBuffs()
    return FSPELLCASTINGCOREgetBuffs(focusTargetName) or {}
end

do
    local mod, floor = mod, floor
    local GetCast = FSPELLCASTINGCOREgetCast

    local function Round(num, idp)
        local mult = 10^(idp or 0)

        return floor(num * mult + 0.5) / mult
    end

    --- Get cast data for focus.
    -- Should be ran in an OnUpdate script.
    -- @treturn[1] table FSPELLCASTINGCORE cast data
    -- @treturn[1] number Current cast time
    -- @treturn[1] number Max cast time
    -- @treturn[1] number Spark position
    -- @treturn[1] number Time left formatted
    -- @treturn[2] nil
    function Focus:GetCast()
        local cast = GetCast(focusTargetName)
        if cast then
            local timeEnd, timeStart = cast.timeEnd, cast.timeStart
            local getTime = GetTime()

            if getTime < timeEnd then
                local t = timeEnd - getTime
                local timer = Round(t, t > 3 and 0 or 1)
                local maxValue = timeEnd - timeStart
                local value, sparkPosition

                if cast.inverse then
                    value = mod(t, timeEnd - timeStart)
                    sparkPosition = t / (timeEnd - timeStart)
                else
                    value = mod((getTime - timeStart), timeEnd - timeStart)
                    sparkPosition = (getTime - timeStart) / (timeEnd - timeStart)
                end

                if sparkPosition < 0 then
                    sparkPosition = 0
                end

                return cast, value, maxValue, sparkPosition, timer
            end
        end

        return nil
    end
end

--- Get UnitReactionColor for focus. (player only, not npc)
-- @treturn number r
-- @treturn number g
-- @treturn number b
function Focus:GetReactionColors()
    if not self:FocusExists() then return error("no focus sat.") end
    local r, g, b = 0, 0, 1

    if rawData.unitCanAttack == 1 then
        -- Hostile players are red
        if rawData.playerCanAttack == 1 then
            r = UnitReactionColor[2].r
            g = UnitReactionColor[2].g
            b = UnitReactionColor[2].b
        end
    elseif rawData.playerCanAttack == 1 then
        -- Players we can attack but which are not hostile are yellow
        r = UnitReactionColor[4].r
        g = UnitReactionColor[4].g
        b = UnitReactionColor[4].b
    elseif rawData.unitIsPVP == 1 then
        -- Players we can assist but are PvP flagged are green
        r = UnitReactionColor[6].r
        g = UnitReactionColor[6].g
        b = UnitReactionColor[6].b
    end

    return r, g, b
end

--- Data
-- @section data

--- Get specific focus data.
-- If no key is specified, returns all the data.
-- See SetFocusInfo() for list of data available.
-- @tparam[opt=nil] string key1
-- @tparam[opt=nil] string key2
-- @tparam[opt=nil] string key3
-- @tparam[opt=nil] string key4
-- @usage local lvl = Focus:GetData("unitLevel")
-- @usage local lvl, class, name = Focus:GetData("unitLevel", "unitClass", "unitName")
-- @usage local data = Focus:GetData()
-- @return[1] data or empty table
-- @return[2] nil
function Focus:GetData(key1, key2, key3, key4, key5)
    if key1 then
        if key5 then error("max 4 keys") end
        return rawData[key1], key2 and rawData[key2], key3 and rawData[key3], key4 and rawData[key4]
    else
        return rawData or {}
    end
end

--- Insert/replace any focus data
-- @tparam string key
-- @param value
function Focus:SetData(key, value)
    if key and value then
        data[key] = value
    else
        error('Usage: SetData("key", value)')
    end
end

--- Delete specific or all focus data
-- @tparam[opt=nil] string key
function Focus:ClearData(key)
    if key then
        data[key] = nil
    else
        for k, v in pairs(rawData) do
            if k == "eventsThrottle" then
                rawData[k] = {}
            else
                rawData[k] = nil
            end
        end
    end
end

--------------------------------
-- Event handling & OnUpdate
--------------------------------
do
    local hookEvents = {}
    local events = CreateFrame("frame")
    local refresh = 0

    -- Call all eventlisteners for given event.
    function CallHooks(event, arg1, arg2, arg3, arg4, recursive) --local
        if rawData.init then return end

        local callbacks = hookEvents[event]
        if callbacks then
            --if not recursive then print(event) end
            for i = 1, tgetn(callbacks) do
                callbacks[i](event, arg1, arg2, arg3, arg4)
            end
        end

        if not recursive and event == "FOCUS_SET" then
            -- Trigger all events for easy GUI updating
            for evnt, _ in next, hookEvents do
                if evnt ~= "FOCUS_CLEAR" and evnt ~= "FOCUS_SET" then
                    CallHooks(evnt, arg1, arg2, arg3, arg4, true)
                end
            end
        end
    end

    local EventHandler = function()
        if strfind(event, "UNIT_") or strfind(event, "PLAYER_") then
            -- Run only events for focus
            if not Focus:UnitIsFocus(arg1 or "player") then return end
        end

        if event == "UNIT_DISPLAYPOWER" or event == "UNIT_HEALTH" or event == "UNIT_MANA"
        or event == "UNIT_RAGE" or event == "UNIT_FOCUS" or event == "UNIT_ENERGY" then
            -- Combine into 1 single event
            --return events:UNIT_HEALTH_OR_POWER(event, arg1)
            return SetFocusHealth(arg1)
        end

        if events[event] then
            events[event](Focus, event, arg1, arg2, arg3, arg4)
        end
    end

    local OnUpdateHandler = function()
        refresh = refresh - arg1
        if refresh < 0 then
            if focusTargetName then
                if partyUnit and focusTargetName == UnitName(partyUnit) then
                    -- partyX or partyXtarget = focus
                    return SetFocusInfo(partyUnit)
                end

                if not SetFocusInfo("target") then
                    if not SetFocusInfo("mouseover") then
                        if not SetFocusInfo("targettarget") then
                            rawData.unit = nil
                            NameplateScanner()
                            PartyScanner()
                        end
                    end
                end
            end

            refresh = 0.3
        end
    end

    --------------------------------------------------------

    --- Events
    -- @section events

    --- Register event listener for a focus event.
    -- @tparam string eventName
    -- @tparam func callback
    -- @treturn number event ID
    function Focus:OnEvent(eventName, callback)
        if type(eventName) ~= "string" or type(callback) ~= "function" then
            return error('Usage: OnEvent("event", callbackFunc)')
        end

        if not hookEvents[eventName] then
            hookEvents[eventName] = {}
        end

        local i = tgetn(hookEvents[eventName]) + 1
        hookEvents[eventName][i] = callback
        return i
    end

    --- Remove existing event listener.
    -- @tparam string eventName
    -- @tparam number eventID
    function Focus:RemoveEvent(eventName, eventID)
        if type(eventName) ~= "string" or type(eventID) ~= "number" then
            return error('Usage: UnhookEvent("event", id)')
        end

        if hookEvents[eventName] and hookEvents[eventName][eventID] then
            table.remove(hookEvents[eventName], eventID)
        else
            error("Invalid event name or id.")
        end
    end

    --------------------------------------------------------

    function events:UNIT_AURA(event, unit)
        SetFocusAuras(unit)
    end

    function events:PLAYER_AURAS_CHANGED(event)
        SetFocusAuras("player")
    end

    function events:UNIT_LEVEL(event, unit)
        data.unitLevel = UnitLevel(unit)
    end

    function events:UNIT_CLASSIFICATION_CHANGED(event, unit)
        data.unitClassification = UnitClassification(unit)
    end

    function events:PLAYER_FLAGS_CHANGED(event, unit)
        data.unitIsPartyLeader = UnitIsPartyLeader(unit)
    end

    function events:PARTY_LEADER_CHANGED(event, unit)
        data.unitIsPartyLeader = UnitIsPartyLeader(unit)
    end

    events:SetScript("OnEvent", EventHandler)
    events:SetScript("OnUpdate", OnUpdateHandler)
    events:RegisterEvent("PLAYER_FLAGS_CHANGED")
    events:RegisterEvent("PLAYER_AURAS_CHANGED")
    events:RegisterEvent("PARTY_LEADER_CHANGED")
    events:RegisterEvent("RAID_TARGET_UPDATE")
    events:RegisterEvent("UNIT_PORTRAIT_UPDATE")
    events:RegisterEvent("UNIT_CLASSIFICATION_CHANGED")
    events:RegisterEvent("UNIT_HEALTH")
    events:RegisterEvent("UNIT_LEVEL")
    events:RegisterEvent("UNIT_AURA")
    events:RegisterEvent("UNIT_MANA")
    events:RegisterEvent("UNIT_RAGE")
    events:RegisterEvent("UNIT_FOCUS")
    events:RegisterEvent("UNIT_ENERGY")
end

-- Add to global namespace
_G.FocusData = Focus
