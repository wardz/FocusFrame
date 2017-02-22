------------
-- @module FocusData
local _G = getfenv(0)
print = print or function(msg) DEFAULT_CHAT_FRAME:AddMessage(msg or "nil") end
if _G.FocusData then return end

-- Vars
local Focus = {}
local focusTargetName
local partyUnit
local rawData
local data

-- Functions
local NameplateScanner
local PartyScanner
local SetFocusAuras
local CallHooks

-- Upvalues
local next, strfind, UnitName, TargetLastTarget, TargetByName, strlower, type, tgetn =
      next, strfind, UnitName, TargetLastTarget, TargetByName, strlower, type, table.getn

local FSPELLCASTINGCOREgetDebuffs, FSPELLCASTINGCOREgetBuffs, FRGB_BORDER_DEBUFFS_COLOR =
      FSPELLCASTINGCOREgetDebuffs, FSPELLCASTINGCOREgetBuffs, FRGB_BORDER_DEBUFFS_COLOR

-- Data event handling
do
    local rawset = rawset

    --- Hookable events. Ran only if unit = focus.
    -- @table Events
    -- @usage Focus:HookEvent("EVENT_NAME", callbackFunc)
    -- @field UNIT_HEALTH_OR_POWER
    -- @field UNIT_LEVEL
    -- @field UNIT_AURA
    -- @field UNIT_CLASSIFICATION_CHANGED
    -- @field PLAYER_FLAGS_CHANGED
    -- @field RAID_TARGET_UPDATE
    -- @field FOCUS_UNITID_EXISTS arg1=event, arg2=unit
    -- @field FOCUS_SET arg1=event, arg2=unit
    -- @field FOCUS_CHANGED arg1=event, arg2=unit
    -- @field FOCUS_CLEAR
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
    }

    rawData = { eventsThrottle = {} }
    -- data.x will trigger events.
    -- rawData.x will not and has less overhead.
    data = setmetatable({}, {
        __index = function(self, key)
            return rawData[key]
        end,

        __newindex = function(self, key, value)
            local oldValue = rawData[key]
            rawset(rawData, key, value)

            if events[key] then
                if key ~= "auraUpdate" then
                    if oldValue and oldValue == value then return end
                    if key == "unit" and not value then return end
                end

                local last = rawData.eventsThrottle[key] or 0
                if (GetTime() - last) > 0.1 then
                    rawData.eventsThrottle[key] = GetTime()
                    CallHooks(events[key], key == "unit" and rawData.unit)
                end
            end
        end
    })
end

-- Aura unit scanning
do
    local ClearBuffs = FSPELLCASTINGCOREClearBuffs
    local NewBuff = FSPELLCASTINGCORENewBuff
    local UnitBuff, UnitDebuff = UnitBuff, UnitDebuff

    local scantip = _G["FocusDataScantip"]
    local scantipTextLeft1 = _G["FocusDataScantipTextLeft1"]
    local scantipTextRight1 = _G["FocusDataScantipTextRight1"]

    local function DeleteExistingAuras()
        if rawData.health <= 0 then
            return ClearBuffs(focusTargetName)
        end

        ClearBuffs(focusTargetName, rawData.unitIsEnemy)
    end

    local function SyncBuff(unit, i, texture, stack, debuffType, isDebuff)
        scantip:ClearLines()
        if isDebuff then
            scantip:SetUnitDebuff(unit, i)
        else
            scantip:SetUnitBuff(unit, i)
        end

        local name = scantipTextLeft1:GetText()
        local magicType = debuffType or scantipTextRight1:GetText()
        if not magicType or magicType == "" then
            magicType = "none"
        end

        if name then
            NewBuff(focusTargetName, name, texture, isDebuff, magicType, stack)
        end
    end

    -- Scans unit for buffs and adds them to FSPELLCASTINGCORE
    function SetFocusAuras(unit) --local
        DeleteExistingAuras()

        for i = 1, 16 do
            local texture, stack, debuffType = UnitDebuff(unit, i)
            if texture then
                SyncBuff(unit, i, texture, stack, debuffType, true)
            end
        end

        for i = 1, 5 do
            local texture = UnitBuff(unit, i)
            if texture then SyncBuff(unit, i, texture) end
        end

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

    local function IsPlate(frame)
        local overlayRegion = frame:GetRegions()
        if not overlayRegion or overlayRegion:GetObjectType() ~= "Texture"
        or overlayRegion:GetTexture() ~= [[Interface\Tooltips\Nameplate-Border]] then
            return false
        end
        return true
    end

    function NameplateScanner() -- local
        --if data.unitIsEnemy and GetCVar("nameplateShowEnemies") == "1" then return end
        --if data.unitIsFriend and GetCVar("nameplateShowFriends") == "1" then return end
        local frames = { WorldFrame:GetChildren() }

        for _, plate in ipairs(frames) do
            if IsPlate(plate) and plate:IsVisible() then
                local _, _, name, level, _, raidIcon = plate:GetRegions()
                local health = plate:GetChildren():GetValue()

                if name:GetText() == focusTargetName then
                    if raidIcon and raidIcon:IsVisible() then
                        local ux, uy = raidIcon:GetTexCoord()
                        data.raidIcon = RaidIconCoordinate[ux][uy]
                    end

                    data.health = health
                    data.unitLevel = tonumber(level:GetText())
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

local function SetFocusInfo(unit)
	if Focus:UnitIsFocus(unit) then
        data.playerCanAttack = UnitCanAttack("player", unit)
        data.raidIcon = GetRaidTargetIndex(unit)
        data.unit = unit

        data.unitName = GetUnitName(unit)
        data.unitIsEnemy = UnitIsEnemy(unit, "player")
        data.unitIsFriend = UnitIsFriend(unit, "player")
        data.unitIsPlayer = UnitIsPlayer(unit)
        data.unitClassification = UnitClassification(unit)
        data.unitIsCivilian = UnitIsCivilian(unit)
        data.unitLevel = UnitLevel(unit)
        data.unitCanAttack = UnitCanAttack(unit, "player")
        data.unitIsCorpse = UnitIsCorpse(unit)
        data.unitIsPartyLeader = UnitIsPartyLeader(unit)
        data.unitIsTapped = UnitIsTapped(unit)
        data.unitIsTappedByPlayer = UnitIsTappedByPlayer(unit)
        data.unitReaction = UnitReaction(unit, "player")
        data.unitIsPVPFreeForAll = UnitIsPVPFreeForAll(unit)
        data.unitIsPVP = UnitIsPVP(unit)
        data.unitIsConnected = UnitIsConnected(unit)
        -- More data can be sat using Focus:SetData() in FOCUS_SET event

        SetFocusHealth(unit)
        SetFocusAuras(unit)

        return true
	end

	return false
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
            local unit = groupType .. raidMemberIndex .. (data.unitIsEnemy and "target" or "")
            local unitPet = groupType .. "pet" .. raidMemberIndex .. (data.unitIsEnemy and "target" or "")
            -- party1, party1target if focus is enemy

            if SetFocusInfo(unit) then
                raidMemberIndex = 1
                partyUnit = unit
            elseif SetFocusInfo(unitPet) then
                raidMemberIndex = 1
                partyUnit = unitPet
            else
                partyUnit = nil
                -- Scan for 1 target every frame instead of all at once
                raidMemberIndex = raidMemberIndex < members and raidMemberIndex + 1 or 1
            end
        end
	end
end

--------------------------------------
-- Public API
-- Most of these can only be used after certain events,
-- or OnUpdate script with focus exist check. See wiki for more info.
--------------------------------------

--- Display focus UI error
-- @tparam[opt] string msg
function Focus:ShowError(msg)
    UIErrorsFrame:AddMessage("|cffFF003F " .. (msg or "You have no focus.") .. "|r")
end

--- Check if unit ID or unit name matches focus target.
-- @tparam string unit
-- @tparam[opt] bool checkName
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

--- Get focus unit name.
-- @treturn[1] string unit name
-- @treturn[2] nil
function Focus:GetName()
    return focusTargetName
end

--- Check if focus is sat.
-- @warning Not same as UnitExists()
-- @tparam[opt] bool showError display UI error msg
-- @treturn bool true if exists
function Focus:FocusExists(showError)
    if showError and not focusTargetName then
        self:ShowError()
    end

    return focusTargetName ~= nil
end

--- Use any unit function on focus target, i.e CastSpellByName
-- @usage Focus:Trigger(CastSpellByName, "Fireball")
-- @usage Focus:Trigger(DropItemOnUnit); -- unit defaults to focus when no second arg.
-- @tparam func func function
-- @param arg1
-- @param arg2
-- @param arg3
-- @param arg4
function Focus:Trigger(func, arg1, arg2, arg3, arg4) -- no vararg in this lua version so this'll have to do for now
    if self:FocusExists(true) then
        if type(func) == "function" then
            arguments = arguments or "target"
            self:TargetFocus()
            func(arg1, arg2, arg3, arg4)
            self:TargetPrevious()
        else
            error("Usage: Trigger(function, arg1,arg2,arg3,arg4)")
        end
    end
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
-- @warning uses numeric indexes.
-- @tparam string debuffType e.g "magic" or "physical"
-- @return table
function Focus:GetDebuffColor(debuffType)
    return debuffType and FRGB_BORDER_DEBUFFS_COLOR[strlower(debuffType)] or {0, 0, 0, 0}
end

--- Get table containing all buff data for focus.
-- Should be ran in an OnUpdate script or HookEvent("UNIT_AURA")
-- @treturn table data or empty table
function Focus:GetBuffs()
    local list = FSPELLCASTINGCOREgetBuffs(focusTargetName)
    return list and list.buffs or {}
end

--- Get table containing all debuff data for focus.
-- Should be ran in an OnUpdate script or HookEvent("UNIT_AURA")
-- @treturn table data or empty table
function Focus:GetDebuffs()
    return FSPELLCASTINGCOREgetDebuffs(focusTargetName) or {}
end

do
    local mod, floor, GetTime = mod, floor, GetTime
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
            local gTime = GetTime()

            if gTime < timeEnd then
                local t = timeEnd - gTime
                local timer = Round(t, t > 3 and 0 or 1)
                local maxValue = timeEnd - timeStart
                local value, sparkPosition

                if cast.inverse then
                    value = mod(t, timeEnd - timeStart)
                    sparkPosition = t / (timeEnd - timeStart)
                else
                    value = mod((gTime - timeStart), timeEnd - timeStart)
                    sparkPosition = (gTime - timeStart) / (timeEnd - timeStart)
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

--- Target the focus.
-- @tparam[opt] string name
function Focus:TargetFocus(name)
    if not self:FocusExists() then
        return self:ShowError()
    end

    self.oldTarget = UnitName("target")
    if not self.oldTarget or self.oldTarget ~= focusTargetName then
        if not rawData.unitIsPlayer then
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

    SetFocusInfo("target")
end

-- @private
function Focus:TargetPrevious()
    if self.oldTarget and self.needRetarget then
        TargetLastTarget()

        if UnitName("target") ~= self.oldTarget then
            -- TargetLastTarget seems to bug out randomly,
            -- so use this as fallback
            self:TargetFocus(name)
        end
    elseif not self.oldTarget then
        ClearTarget()
    end
end

--- Set current target as focus, or name if given.
-- @warning Name is case sensitive.
-- @tparam[opt] string name
function Focus:SetFocus(name)
    if not name or name == "" then
        name = UnitName("target")
    else
        name = strlower(name)
        name = gsub(name, "^%l", strupper)
    end

    local focusChanged = Focus:FocusExists()

    focusTargetName = name
    if focusTargetName then
        self:TargetFocus()
        CallHooks("FOCUS_SET", "target")
        if focusChanged then
            CallHooks("FOCUS_CHANGED", "target")
        end
        self:TargetPrevious()
    else
        self:ClearFocus()
    end
end

--- Remove focus & its data.
function Focus:ClearFocus()
    focusTargetName = nil
    partyUnit = nil
    self:ClearData()

    CallHooks("FOCUS_CLEAR")
end

--- Check if focus is dead.
-- @treturn bool true if dead
function Focus:IsDead()
    return rawData.health and rawData.health <= 0 --and data.unitIsConnected
end

--- Get UnitReactionColor for focus. (player only, not npc)
-- @treturn number r
-- @treturn number g
-- @treturn number b
function Focus:GetReactionColors()
    if not self:FocusExists() then return end
    local r, g, b = 0, 0, 1

    if rawData.unitCanAttack == 1then
        -- Hostile players are red
        if rawData.playerCanAttack == 1then
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

--- Get specific focus data.
-- If no key is specified, returns all the data.
-- @tparam[opt] string key
-- @return[1] data or empty table
-- @return[2] nil
function Focus:GetData(key)
    if key then
        return rawData[key] or nil
    else
        return rawData or {}
    end
end

--- Insert/replace any focus data
-- @tparam string key
-- @param value
function Focus:SetData(key, value)
    if key and type(key) == "string" and value then
        data[key] = value
    else
        error('Usage: SetData("key", value)')
    end
end

--- Delete specific or all focus data
-- @tparam[opt] string key
function Focus:ClearData(key)
    if key then
        data[key] = nil
    else
        for k, v in next, data do
            if k == "eventsThrottle" then
                data[k] = {}
            else
                data[k] = nil
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

    function CallHooks(event, arg1, arg2, arg3, arg4, recursive) --local
        print(event)
        rawData.init = event == "FOCUS_SET"
        --if not data.init then
            local hooks = hookEvents[event]
            if hooks then
                for i = 1, tgetn(hooks) do
                    hooks[i](event, arg1, arg2, arg3, arg4)
                end
            end
        --end

        if not recursive and event == "FOCUS_SET" then
            -- Trigger all events for easy GUI updating
            for k, v in next, hookEvents do
                if k ~= "FOCUS_CLEAR" then
                    CallHooks(k, arg1, arg2, arg3, arg4, true)
                end
            end
            rawData.init = false
        end
    end

    local function EventHandler()
        if strfind(event, "UNIT_") or strfind(event, "PLAYER_") then
            -- Run only events for focus
            if not Focus:UnitIsFocus(arg1) then return end
        end

        if event == "UNIT_DISPLAYPOWER" or event == "UNIT_HEALTH" or event == "UNIT_MANA"
        or event == "UNIT_RAGE" or event == "UNIT_FOCUS" or event == "UNIT_ENERGY" then
            -- Combine into 1 single event
            return events:UNIT_HEALTH_OR_POWER(event, arg1)
        end

        if events[event] then
            events[event](Focus, event, arg1, arg2, arg3, arg4)
        end
    end

    local function OnUpdateHandler()
        refresh = refresh - arg1
        if refresh < 0 then
            if focusTargetName then
                if partyUnit and focusTargetName == UnitName(partyUnit) then
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

            refresh = 0.2
        end
    end

    --- Post-hook a focus event.
    -- @tparam string eventName
    -- @tparam func callback
    -- @treturn number event ID
    function Focus:HookEvent(eventName, callback)
        if type(eventName) ~= "string" or type(callback) ~= "function" then
            return error('Usage: HookEvent("event", callbackFunc)')
        end

        if not hookEvents[eventName] then
            hookEvents[eventName] = {}
        end

        local i = tgetn(hookEvents[eventName])
        hookEvents[eventName][i+1] = callback
        return i+1
    end

    --- Remove event.
    -- @tparam string eventName
    -- @tparam number eventID
    function Focus:UnhookEvent(eventName, eventID)
        if type(eventName) ~= "string" or type(eventID) ~= "number" then
            return error('Usage: UnhookEvent("event", id)')
        end

        if hookEvents[eventName] and hookEvents[eventName][eventID] then
            table.remove(hookEvents[eventName], eventID)
        end
    end

    --------------------------------------------------------

    function events:UNIT_HEALTH_OR_POWER(event, unit)
        SetFocusHealth(unit)
    end

    function events:UNIT_AURA(event, unit)
        SetFocusAuras(unit)
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

    function events:UNIT_PORTRAIT_UPDATE(event, unit)
        -- TODO
    end

    events:SetScript("OnEvent", EventHandler)
    events:SetScript("OnUpdate", OnUpdateHandler)
    events:RegisterEvent("PLAYER_FLAGS_CHANGED")
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
