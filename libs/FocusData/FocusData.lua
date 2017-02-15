local _G = getfenv(0)
if _G.FocusData then return end

if not FSPELLCASTINGCOREgetDebuffs then
    return print("spellcastingCore.lua is required for FocusFrame")
end

local Focus = CreateFrame("Frame")
local data = {}
local focusTargetName = nil
local partyUnit = nil
local CallHooks

local tgetn = table.getn

if not print then
    print = function(msg)
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage(msg or "nil")
        end
    end
end

--------------------------------------
-- Core
--------------------------------------
local NameplateScanner
local PartyScanner
local SetFocusAuras

local function SetFocusHealth(unit)
    data.health = UnitHealth(unit)
    data.maxHealth = UnitHealthMax(unit)
    data.power = UnitMana(unit)
    data.maxPower = UnitManaMax(unit)
    data.powerType = UnitPowerType(unit)

    CallHooks("UNIT_HEALTH_OR_POWER", unit)
end

-- Aura unit scanning
do
    local FSPELLCASTINGCOREClearBuffs = FSPELLCASTINGCOREClearBuffs
    local FSPELLCASTINGCORENewBuff = FSPELLCASTINGCORENewBuff

    local scantip = _G["FocusDataScantip"]
    local scantipTextLeft1 = _G["FocusDataScantipTextLeft1"]
    local scantipTextRight1 = _G["FocusDataScantipTextRight1"]

    local function DeleteExistingAuras()
        if data.health <= 0 then
            FSPELLCASTINGCOREClearBuffs(focusTargetName)
            return
        end

        if not data.unitIsEnemy then
            -- Delete all buffs
            FSPELLCASTINGCOREClearBuffs(focusTargetName)
        else
            -- Delete debuffs only
            FSPELLCASTINGCOREClearBuffs(focusTargetName, true)
        end
    end

    local function SyncBuff(unit, i, texture, stack, debuffType, isDebuff) --local
        scantip:ClearLines()
        if debuff then
            scantip:SetUnitDebuff(unit, i)
        else
            scantip:SetUnitBuff(unit, i)
        end

        local name = scantipTextLeft1:GetText()
        local magicType = scantipTextRight1:GetText()
        if not magicType or magicType == "" then
            magicType = "none"
        end

        if name then
            FSPELLCASTINGCORENewBuff(focusTargetName, name, texture, isDebuff, magicType, stack)
            CallHooks("UNIT_AURA")
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
    end
end

local function SetFocusInfo(unit)
	if Focus:UnitIsFocus(unit) then
        SetFocusHealth(unit)
        SetFocusAuras(unit)
    
        data.playerCanAttack = UnitCanAttack("player", unit)
        data.raidIcon = GetRaidTargetIndex(unit)
        data.unit = unit
        data.refreshed = GetTime()

        data.unitName = GetUnitName(unit)
        data.unitIsEnemy = UnitIsEnemy(unit, "player") == 1 and true or false
        data.unitIsPlayer = UnitIsPlayer(unit) == 1 and true or false
        data.unitClassification = UnitClassification(unit)
        data.unitIsCivilian = UnitIsCivilian(unit)
        data.unitLevel = UnitLevel(unit)
        data.unitCanAttack = UnitCanAttack(unit, "player")
        data.unitIsCorpse = UnitIsCorpse(unit)
        data.unitIsPartyLeader = UnitIsPartyLeader(unit)
        data.unitIsTapped = UnitIsTapped(unit)
        data.unitIsTappedByPlayer = UnitIsTappedByPlayer(unit)
        data.unitReaction = UnitReaction(unit, "player")
        data.unitIsPvPFreeForAll = UnitIsPVPFreeForAll(unit)
        data.unitIsPvP = UnitIsPVP(unit)

        return true
	end

	return false
end

-- Nameplate scanning
do
    local WorldFrame = WorldFrame

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
        local frames = { WorldFrame:GetChildren() }

        for _, plate in ipairs(frames) do
            if IsPlate(plate) and plate:IsVisible() then
                local _, _, nameFrame, _, _, raidIcon = plate:GetRegions() -- TODO add lvl
                local health = plate:GetChildren():GetValue()
                local name = nameFrame:GetText()

                if name == focusTargetName then
                    if raidIcon and raidIcon:IsVisible() then
                        local ux, uy = raidIcon:GetTexCoord()
                        data.raidIcon = RaidIconCoordinate[ux][uy]
                        CallHooks("RAID_TARGET_UPDATE")
                    end

                    data.health = health
                    CallHooks("UNIT_HEALTH_OR_POWER")
                    return
                end
            end
        end
    end
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

-- OnUpdate
do
	local refresh, interval = 0, 0.2

	local f = CreateFrame("Frame")
	f:SetScript("OnUpdate", function()
		refresh = refresh - arg1
		if refresh < 0 then
			if focusTargetName then
		
				if focusTargetName ~= UnitName("target") and focusTargetName ~= UnitName("mouseover") then
					if partyUnit and focusTargetName == UnitName(partyUnit) then
						return SetFocusInfo(partyUnit)
					end

					NameplateScanner()
					PartyScanner()
				else
                    if not SetFocusInfo("target") then
                        if not SetFocusInfo("mouseover") then
                            data.unit = nil
                        end
                    end
				end
			end

			refresh = interval
		end
	end)
end

--------------------------------------
-- Public API
--------------------------------------

-- Display user error
function Focus:ShowError(msg)
    UIErrorsFrame:AddMessage("|cffFF003F " .. (msg or "You have no focus.") .. "|r")
end

-- Check if unitID matches focus target
function Focus:UnitIsFocus(unit, checkName)
    if not checkName then
        return focusTargetName and UnitName(unit) == focusTargetName
    else
        return unit == focusTargetName
    end
end

-- Get unitID for focus *if available*
function Focus:GetFocusUnit()
    if data.unit and UnitExists(data.unit) and self:UnitIsFocus(data.unit) then
        return data.unit
    end
end

-- Check if focus is sat. (Not same as UnitExists!)
function Focus:FocusExists(showError)
    if showError and not focusTargetName then
        self:ShowError()
    end

    return focusTargetName ~= nil
end

-- Use any unit function on focus target, i.e CastSpellByName
-- Focus:Trigger(CastSpellByName, "Fireball")
-- If you need multiple arguments, use a table as arg
function Focus:Trigger(func, arguments)
    if self:FocusExists(true) then
        if type(func) == "function" then
            self:TargetFocus()
            func(type(arguments) == "table" and unpack(arguments) or arguments)
            self:TargetPrevious()
            return
        end

        print("invalid arguments in TriggerOnFocus")
    end
end

-- local min, max = Focus:GetHealth()
function Focus:GetHealth()
    return data.health or 0, data.maxHealth or 100
end

-- local min, max = Focus:GetPower()
function Focus:GetPower()
    return data.power or 0, data.powerMax or 100
end

-- Get statusbar color for power. I.e mana is blue.
function Focus:GetPowerColor()
    return ManaBarColor[data.powerType] or { r = 0, g = 0, b = 0 }
end

function Focus:GetDebuffColor(debuffType)
    return debuffType and FRGB_BORDER_DEBUFFS_COLOR[strlower(debuffType)] or {0, 0, 0, 0}
end

-- Get table containing all buff data for focus.
-- Should be ran in an OnUpdate script or HookEvent("UNIT_AURA")
function Focus:GetBuffs()
    local list = FSPELLCASTINGCOREgetBuffs(focusTargetName)
    return list and list.buffs or {}
end

-- Get table containing all debuff data for focus.
-- Should be ran in an OnUpdate script or HookEvent("UNIT_AURA")
function Focus:GetDebuffs()
    return FSPELLCASTINGCOREgetDebuffs(focusTargetName) or {}
end

-- Get table containing cast data for focus.
-- Should be ran in an OnUpdate script.
function Focus:GetCast()
    return FSPELLCASTINGCOREgetCast(focusTargetName)
end

-- Target the focus.
function Focus:TargetFocus(name)
    self.oldTarget = UnitName("target")
    if not self.oldTarget or self.oldTarget ~= focusTargetName then
        if not data.unitIsPlayer then
            local _name = strsub(name or focusTargetName, 1, -2)
            TargetByName(_name, false)

            if UnitIsDead("target") == 1 then
                TargetByName(_name, true)
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

-- Target previous target. (TargetFocus() needs to be ran first)
function Focus:TargetPrevious()
    if self.oldTarget and self.needRetarget then
        TargetLastTarget()

        if UnitName("target") ~= self.oldTarget then
            self:TargetFocus(name)
        end
    elseif not self.oldTarget then
        ClearTarget()
    end
end

-- Set current target as focus, or name if given.
-- Note that name is case sensitive.
function Focus:SetFocus(name)
    if not name or name == "" then
        name = UnitName("target")
    else
        name = strlower(name)
        name = string.gsub(name, "^%l", string.upper)
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

-- Delete all focus data.
function Focus:ClearFocus()
    focusTargetName = nil
    partyUnit = nil
    self:ClearData()
    CallHooks("FOCUS_CLEAR")
end

-- Check if focus is dead.
function Focus:IsDead()
    return data.health <= 0
end

-- Check if focus is enemy.
function Focus:IsEnemy()
    return data.unitIsEnemy
end

-- Check if focus is friendly.
function Focus:IsFriendly()
    return not data.unitIsEnemy
end

-- Get UnitReactionColor for focus.
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

-- Data that doesn't have any getter functions
-- can be retrieved here
-- If no key is specified, returns all the data.
function Focus:GetData(key)
    if key then
        return data[key]
    end

    return data or {}
end

-- Insert/replace any focus data
function Focus:SetData(key, value)
    if key and value then
        data[key] = value
        if strfind(strlower(key), "health") then
            CallHooks("UNIT_HEALTH_OR_POWER")
        end
    end
end

-- Delete (specific) focus data
function Focus:ClearData(key)
    if key then
        data[key] = nil
    else
        for k, v in next, data do
            data[k] = nil
        end
    end
end

-- Event handling
do
    local hookEvents = {}
    local events = CreateFrame("frame")

    function CallHooks(event, arguments, recursive) --local
        local hooks = hookEvents[event]
        if hooks then
            for i = 1, tgetn(hooks) do
                hooks[i](event, type(arguments) == "table" and unpack(arguments) or arguments)
            end
        end

        if not recursive and event == "FOCUS_SET" then
            for k, v in next, hookEvents do
                if k ~= "FOCUS_CLEAR" then
                    CallHooks(k, arguments, true)
                end
            end
        end
    end

    events:SetScript("OnEvent", function()
        if strfind(event, "UNIT_") or strfind(event, "PLAYER_") then
            if not Focus:UnitIsFocus(arg1) then return end
        end

        if event == "UNIT_HEALTH" or event == "UNIT_MANA" or event == "UNIT_RAGE" or event == "UNIT_FOCUS" or event == "UNIT_ENERGY" then
            Focus:UNIT_HEALTH_OR_POWER(event, arg1)
            CallHooks("UNIT_HEALTH_OR_POWER", arg1)
            return
        end

        if events[event] then
            events[event](Focus, event, arg1, arg2, arg3)
            CallHooks(event, {arg1, arg2, arg3})
        end
    end)

    function Focus:HookEvent(eventName, callback)
        if not hookEvents[eventName] then
            hookEvents[eventName] = {}
        end

        table.insert(hookEvents[eventName], callback)
    end

    function Focus:UnhookEvent(eventName, callback)
        -- TODO func can be used as key here?
        if hookEvents[eventName] then
            table.remove(hookEvents[eventName], callback)
        end
    end

    function events:UNIT_HEALTH_OR_POWER(event, unit)
        SetFocusHealth(unit)
    end

    function events:UNIT_AURA(event, unit, test)
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

    events:RegisterEvent("PLAYER_FLAGS_CHANGED")
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

_G.FocusData = Focus
