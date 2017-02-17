local _G = getfenv(0)
local tgetn = table.getn
print = print or function(msg) DEFAULT_CHAT_FRAME:AddMessage(msg or "nil") end
if _G.FocusData then return end

local Focus = {}
local focusTargetName
local partyUnit
local data

-- Functions
local NameplateScanner
local PartyScanner
local SetFocusAuras
local CallHooks

do
    local userdata = {}

    local events = {
        -- Changing these values in data will trigger the listed event.
        health = "UNIT_HEALTH_OR_POWER",
        maxHealth = "UNIT_HEALTH_OR_POWER",
        power = "UNIT_HEALTH_OR_POWER",
        maxPower = "UNIT_HEALTH_OR_POWER",
        unitLevel = "UNIT_LEVEL",
        unitClassification = "UNIT_CLASSIFICATION_CHANGED",
        unitIsPartyLeader = "PLAYER_FLAGS_CHANGED",
        raidIcon = "RAID_TARGET_UPDATE",
        auraUpdate = "UNIT_AURA",
        --unit = "FOCUS_TARGETED",
        --cast = "FOCUS_CASTING",
    }

    data = setmetatable({}, {
        __index = function(self, key)
            return userdata[key]
        end,

        __newindex = function(self, key, value)
            local oldValue = userdata[key]
            rawset(userdata, key, value)

            if events[key] then
                --local last = userdata.eventsThrottle[event] or 0
                --if (GetTime() - last) > 0.2 then
                    if not oldValue or oldValue ~= value then
                        CallHooks(events[key])
                        --userdata.eventsThrottle[event] = GetTime()
                    end
                --end
            end
        end
    })

    data.eventsThrottle = {}
end

-- Aura unit scanning
do
    local ClearBuffs = FSPELLCASTINGCOREClearBuffs
    local NewBuff = FSPELLCASTINGCORENewBuff

    local scantip = _G["FocusDataScantip"]
    local scantipTextLeft1 = _G["FocusDataScantipTextLeft1"]
    local scantipTextRight1 = _G["FocusDataScantipTextRight1"]

    local function DeleteExistingAuras()
        if data.health <= 0 then
            return ClearBuffs(focusTargetName)
        end

        ClearBuffs(focusTargetName, data.unitIsEnemy)
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

            if i <= 5 then
                local texture = UnitBuff(unit, i)
                if texture then SyncBuff(unit, i, texture) end
            end
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
                local _, _, nameFrame, _, _, raidIcon = plate:GetRegions() -- TODO add lvl frame
                local health = plate:GetChildren():GetValue()
                local name = nameFrame:GetText()

                if name == focusTargetName then
                    if raidIcon and raidIcon:IsVisible() then
                        local ux, uy = raidIcon:GetTexCoord()
                        data.raidIcon = RaidIconCoordinate[ux][uy]
                    end

                    data.health = health
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
        -- More data can be sat using Focus:SetData() in FOCUS_SET event

        SetFocusHealth(unit)
        SetFocusAuras(unit)

        return true
	end

	return false
end

-- Raid/party unit scanning
do
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
--------------------------------------

-- Display user error
-- @param {String} [msg]
function Focus:ShowError(msg)
    UIErrorsFrame:AddMessage("|cffFF003F " .. (msg or "You have no focus.") .. "|r")
end

-- Check if unitID or name matches focus target.
-- @param {String} unit
-- @param {Boolean} [checkName]
-- @return {Boolean}
function Focus:UnitIsFocus(unit, checkName)
    if not checkName then
        return focusTargetName and UnitName(unit) == focusTargetName
    else
        return unit == focusTargetName
    end
end

-- Get unitID for focus *if available*
-- @return {String|Nil}
function Focus:GetFocusUnit()
    if data.unit and UnitExists(data.unit) and self:UnitIsFocus(data.unit) then
        return data.unit
    end
end

-- Check if focus is sat. (Not same as UnitExists!)
-- @param {Boolean} [showError]
-- @return {Boolean}
function Focus:FocusExists(showError)
    if showError and not focusTargetName then
        self:ShowError()
    end

    return focusTargetName ~= nil
end

-- Use any unit function on focus target, i.e CastSpellByName
-- Focus:Trigger(CastSpellByName, "Fireball")
-- Focus:Trigger(DropItemOnUnit) -- defaults to "target" when no second arg.
-- @param {Function} func
-- @param {Object|*} [arguments] - Use table here if u need more than 1 arg.
function Focus:Trigger(func, arguments, err)
    if self:FocusExists(true) then
        if not err and type(func) == "function" then
            arguments = arguments or "target"
            self:TargetFocus()
            func(type(arguments) == "table" and unpack(arguments) or arguments)
            self:TargetPrevious()
        else
            error("Usage: Trigger(function, {arg1,arg2,..}")
        end
    end
end

-- local min, max = Focus:GetHealth()
-- @return {Number}
function Focus:GetHealth()
    return data.health or 0, data.maxHealth or 100
end

-- local min, max = Focus:GetPower()
-- @return {Number}
function Focus:GetPower()
    return data.power or 0, data.maxPower or 100
end

-- Get statusbar color for power.
-- @return {Object}
function Focus:GetPowerColor()
    return ManaBarColor[data.powerType] or { r = 0, g = 0, b = 0 }
end

-- Get border color for debuffs.
-- Note: uses numeric indexes.
-- @param {String} debuffType - E.g "magic" or "phyisical"
-- @return {Object}
function Focus:GetDebuffColor(debuffType)
    return debuffType and FRGB_BORDER_DEBUFFS_COLOR[strlower(debuffType)] or {0, 0, 0, 0}
end

-- Get table containing all buff data for focus.
-- Should be ran in an OnUpdate script or HookEvent("UNIT_AURA")
-- @return {Object}
function Focus:GetBuffs()
    local list = FSPELLCASTINGCOREgetBuffs(focusTargetName)
    return list and list.buffs or {}
end

-- Get table containing all debuff data for focus.
-- Should be ran in an OnUpdate script or HookEvent("UNIT_AURA")
-- @return {Object}
function Focus:GetDebuffs()
    return FSPELLCASTINGCOREgetDebuffs(focusTargetName) or {}
end


do
    local function Round(num, idp)
        local mult = 10^(idp or 0)

        return floor(num * mult + 0.5) / mult
    end

    -- Get table containing cast data for focus.
    -- Should be ran in an OnUpdate script.
    -- @return {Object,Number|Nil}
    function Focus:GetCast()
        local cast = FSPELLCASTINGCOREgetCast(focusTargetName)
        if cast then
            local timeEnd, timeStart = cast.timeEnd, cast.timeStart
            local gTime = GetTime()

            if gTime < timeEnd then
                local t = timeEnd - gTime()
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

-- Target the focus.
-- @param {String} [name] - opt
function Focus:TargetFocus(name)
    self.oldTarget = UnitName("target")
    if not self.oldTarget or self.oldTarget ~= focusTargetName then
        if not data.unitIsPlayer then
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

-- Set current target as focus, or name if given.
-- Note that name is case sensitive.
-- @param {String} [name]
function Focus:SetFocus(name)
    if not name or name == "" then
        name = UnitName("target")
    else
        name = strlower(name)
        name = gsub(name, "^%l", strupper)
    end

    focusTargetName = name
    if focusTargetName then
        self:TargetFocus()
        CallHooks("FOCUS_SET", "target")
        self:TargetPrevious()
    else
        self:ClearFocus()
    end
end

-- Remove focus & its data.
function Focus:ClearFocus()
    focusTargetName = nil
    partyUnit = nil
    self:ClearData()

    CallHooks("FOCUS_CLEAR")
end

-- Check if focus is dead.
-- @return {Boolean}
function Focus:IsDead()
    return data.health <= 0 --and data.unitIsConnected
end

-- Get UnitReactionColor for focus.
-- local r, g, b = Focus:GetReactionColors()
-- @return {Number}
function Focus:GetReactionColors()
    local r, g, b = 0, 0, 1

    if data.unitCanAttack then
        -- Hostile players are red
        if data.playerCanAttack then
            r = UnitReactionColor[2].r
            g = UnitReactionColor[2].g
            b = UnitReactionColor[2].b
        end
    elseif data.playerCanAttack then
        -- Players we can attack but which are not hostile are yellow
        r = UnitReactionColor[4].r
        g = UnitReactionColor[4].g
        b = UnitReactionColor[4].b
    elseif data.unitIsPVP then
        -- Players we can assist but are PvP flagged are green
        r = UnitReactionColor[6].r
        g = UnitReactionColor[6].g
        b = UnitReactionColor[6].b
    end

    return r, g, b
end

-- Get specific focus data.
-- If no key is specified, returns all the data.
-- @param {String} [key]
-- @return {*}
function Focus:GetData(key)
    return key and data[key] or data or {}
end

-- Insert/replace any focus data
-- @param {String} key
-- @param {*} value
function Focus:SetData(key, value)
    if key and type(key) == "string" and value then
        data[key] = value
    else
        error('Usage: SetData("key", value)')
    end
end

-- Delete (specific) focus data
-- @param {String} [key]
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

    function CallHooks(event, arguments, recursive) --local
        data.init = event == "FOCUS_SET"
        --if not data.init then
            local hooks = hookEvents[event]
            if hooks then
                for i = 1, tgetn(hooks) do
                    hooks[i](event, type(arguments) == "table" and unpack(arguments) or arguments)
                end
            end
        --end

        if not recursive and event == "FOCUS_SET" then
            -- Trigger all events for easy GUI updating
            for k, v in next, hookEvents do
                if k ~= "FOCUS_CLEAR" then
                    CallHooks(k, arguments, true)
                end
            end
            data.init = false
        end
    end

    local function EventHandler()
        if strfind(event, "UNIT_") or strfind(event, "PLAYER_") then
            -- Run only events for focus
            if not Focus:UnitIsFocus(arg1) then return end
        end

        if event == "UNIT_HEALTH" or event == "UNIT_MANA" or event == "UNIT_RAGE" or event == "UNIT_FOCUS" or event == "UNIT_ENERGY" then
            -- Combine into 1 single event
            return events:UNIT_HEALTH_OR_POWER(event, arg1)
        end

        if events[event] then
            events[event](Focus, event, arg1, arg2, arg3)
        end
    end

    local function OnUpdateHandler()
        refresh = refresh - arg1
        if refresh < 0 then
            if focusTargetName then
                if focusTargetName ~= UnitName("target") and focusTargetName ~= UnitName("mouseover") then
                    if partyUnit and focusTargetName == UnitName(partyUnit) then
                        return SetFocusInfo(partyUnit)
                    end

                    NameplateScanner()
                    PartyScanner()
                    data.unit = nil
                else
                    if not SetFocusInfo("target") then
                        if not SetFocusInfo("mouseover") then
                            data.unit = nil
                        end
                    end
                end
            end

            refresh = 0.2
        end
    end

    function Focus:HookEvent(eventName, callback)
        if type(eventName) ~= "string" or type(callback) ~= "function" then
            return error('Usage: HookEvent("event", callbackFunc)')
        end

        if not hookEvents[eventName] then
            hookEvents[eventName] = {}
        end
        table.insert(hookEvents[eventName], callback)
    end

    function Focus:UnhookEvent(eventName, callback)
        if type(eventName) ~= "string" or type(callback) ~= "function" then
            return error('Usage: UnhookEvent("event", callbackFunc)')
        end

        if hookEvents[eventName] then
            -- TODO
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

    events:SetScript("OnEvent", EventHandler)
    events:SetScript("OnUpdate", OnUpdateHandler)
    events:RegisterEvent("PLAYER_FLAGS_CHANGED")
    --events:RegisterEvent("PARTY_LEADER_CHANGED")
    events:RegisterEvent("RAID_TARGET_UPDATE")
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
