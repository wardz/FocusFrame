local focusData = {}
local raidMemberIndex = 1
local partyUnitID

function FocusFrame_SetFocusInfo(unitID)
    if CURR_FOCUS_TARGET and UnitExists(unitID) then
        local name = UnitName(unitID)
        if name == CURR_FOCUS_TARGET then
            focusData[name] = {
                ['health'] = UnitHealth(unitID),
                ['maxHealth'] = UnitHealthMax(unitID),
                ['mana'] = UnitMana(unitID),
                ['maxMana'] = UnitManaMax(unitID),
                ['power'] = UnitPowerType(unitID),
                ['enemy'] = UnitIsEnemy(unitID, "player"),
                ['isDead'] = UnitHealth(unitID) <= 0 and UnitIsConnected(unitID) and true or false
            }

            return true
        end
    end

    return false
end

local function ScanPartyTargets()
    local groupType = UnitInRaid("player") and "raid" or "party"
    local members = groupType == "raid" and GetNumRaidMembers() or GetNumPartyMembers()
    local enemy = focusData[CURR_FOCUS_TARGET] and focusData[CURR_FOCUS_TARGET].enemy

    if members > 0 then
        local unitID = groupType .. raidMemberIndex .. (enemy and "target" or "")
        if FocusFrame_SetFocusInfo(unitID) then
            raidMemberIndex = 1
            partyUnitID = not enemy and unitID or nil
            return
        else
            partyUnitID = nil
            raidMemberIndex = raidMemberIndex < members and raidMemberIndex + 1 or 1
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
    return focusData[name] or {}
end

function FocusFrame_DeleteFocusData(name)
    raidMemberIndex = 1

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
    local refresh, interval = 0, 0.19

    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function()
        refresh = refresh - arg1
        if refresh < 0 then
            if CURR_FOCUS_TARGET then
                FocusFrame_ScanCast()

                if partyUnitID and CURR_FOCUS_TARGET == UnitName(partyUnitID) then
                    return FocusFrame_SetFocusInfo(partyUnitID)
                end
        
                if CURR_FOCUS_TARGET ~= UnitName("target") and CURR_FOCUS_TARGET ~= UnitName("mouseover") then
                    ScanPartyTargets()
                    FocusFrame_ScanHealth()
                else
                    FocusFrame_SetFocusInfo("target")
                    FocusFrame_SetFocusInfo("mouseover")
                end
            end

            refresh = interval
        end
    end)
end
