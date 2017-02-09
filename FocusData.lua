local focusData = {}
local raidMemberIndex = 1
local partyUnit
local ScanPartyTargets

-- Store frequently used globals in locals for faster access
local UnitName, UnitExists, UnitIsFriend, UnitIsPlayer, UnitIsConnected =
	  UnitName, UnitExists, UnitIsFriend, UnitIsPlayer, UnitIsConnected

local UnitHealth, UnitHealthMax, UnitMana, UnitManaMax, UnitPowerType =
	  UnitHealth, UnitHealthMax, UnitMana, UnitManaMax, UnitPowerType

function FocusFrame_SetFocusInfo(unit)
	if CURR_FOCUS_TARGET and UnitExists(unit) then
		local name = UnitName(unit)
		if name == CURR_FOCUS_TARGET then
			if not focusData[name] then
				focusData[name] = {}
			end

			local data = focusData[name]
			data.health = UnitHealth(unit)
			data.maxHealth = UnitHealthMax(unit)
			data.mana = UnitMana(unit)
			data.maxMana = UnitManaMax(unit)
			data.power = UnitPowerType(unit)
			data.isDead = UnitHealth(unit) <= 0 and UnitIsConnected(unit) and true or false
			data.enemy = UnitIsFriend(unit, "player") == 1 and "1" or "2" -- true|false seems to be bugged for some reason
			data.npc = UnitIsPlayer(unit) == 1 and "1" or "2"

			return true
		end
	end

	return false
end

do
	local UnitInRaid, GetNumRaidMembers, GetNumPartyMembers = UnitInRaid, GetNumRaidMembers, GetNumPartyMembers
	local FocusFrame_SetFocusInfo = FocusFrame_SetFocusInfo
	local refresh, interval = 0, 0.2

	function ScanPartyTargets() --local
		refresh = refresh - 0.1
		if refresh < 0 then
			local groupType = UnitInRaid("player") and "raid" or "party"
			local members = groupType == "raid" and GetNumRaidMembers() or GetNumPartyMembers()
			local enemy = focusData[CURR_FOCUS_TARGET] and focusData[CURR_FOCUS_TARGET].enemy == "2"

			if members > 0 then
				local unit = groupType .. raidMemberIndex .. (enemy and "target" or "")
				local unitPet = groupType .. "pet" .. raidMemberIndex .. (enemy and "target" or "")

				if FocusFrame_SetFocusInfo(unit) then
					raidMemberIndex = 1
					partyUnit = unit
				elseif FocusFrame_SetFocusInfo(unitPet) then
					raidMemberIndex = 1
					partyUnit = unitPet
				else
					partyUnit = nil
					raidMemberIndex = raidMemberIndex < members and raidMemberIndex + 1 or 1
				end
			end

			refresh = interval
		end
	end
end

function FocusFrame_SetUnitHealth(name, health)
	if not focusData[name] then
		focusData[name] = {}
	end

	focusData[name].health = health
end

function FocusFrame_GetFocusData(name)
	if not name then name = CURR_FOCUS_TARGET end
	return focusData[name] or {}
end

function FocusFrame_DeleteFocusData(name)
	raidMemberIndex = 1
	partyUnit = nil

	if next(focusData) then
		if name then
			focusData[name] = nil
		else
			for k, v in next, focusData do
				focusData[k] = nil
			end
		end
	end
end

do
	local refresh, interval = 0, 1/60

	local f = CreateFrame("Frame")
	f:SetScript("OnUpdate", function()
		refresh = refresh - arg1
		if refresh < 0 then
			if CURR_FOCUS_TARGET then
				FocusFrame_ScanCast()

				if partyUnit and CURR_FOCUS_TARGET == UnitName(partyUnit) then
					FocusFrame_Update(partyUnit)
					return
				end
		
				if CURR_FOCUS_TARGET ~= UnitName("target") and CURR_FOCUS_TARGET ~= UnitName("mouseover") then
					FocusFrame_ScanHealth()
					ScanPartyTargets()
				else
					FocusFrame_SetFocusInfo("target")
					FocusFrame_SetFocusInfo("mouseover")
				end
			end

			refresh = interval
		end
	end)
end
