if SlashCmdList.MFOCUS then return end

local _G = getfenv(0)
local Focus = _G["FocusData"]

local scantip = _G["FocusDataScantip"]
local scantipTextLeft1 = _G["FocusDataScantipTextLeft1"]

SLASH_FOCUS1 = "/focus"
SLASH_MFOCUS1 = "/mfocus"
SLASH_FCAST1 = "/fcast"
SLASH_FITEM1 = "/fitem"
SLASH_FSWAP1 = "/fswap"
SLASH_TARFOCUS1 = "/tarfocus"
SLASH_CLEARFOCUS1 = "/clearfocus"

SlashCmdList.FOCUS = function(msg) Focus:SetFocus(msg) end
SlashCmdList.TARFOCUS = function() Focus:TargetFocus() end
SlashCmdList.CLEARFOCUS = function() Focus:ClearFocus() end

SlashCmdList.MFOCUS = function()
    if UnitExists("mouseover") then
        Focus:SetFocus(UnitName("mouseover"))
    end
end

SlashCmdList.FCAST = function(spell)
    if spell and strlower(spell) == "petattack" then
        Focus:Call(PetAttack)
    else
        Focus:Call(CastSpellByName, spell)
    end
end

SlashCmdList.FITEM = function(msg)
    if Focus:FocusExists(true) then
        msg = strlower(msg)
    
        for i = 0, 19 do
            scantip:ClearLines()
            scantip:SetInventoryItem("player", i)
            local text = scantipTextLeft1:GetText()
            if text and strlower(text) == msg then
                return Focus:Call(UseInventoryItem, i)
            end
        end

        for i = 0, 4 do
            for j = 1, GetContainerNumSlots(i) do
                scantip:ClearLines()
                scantip:SetBagItem(i, j)

                local text = scantipTextLeft1:GetText()
                if text and strlower(text) == msg then
                    return Focus:Call(UseContainerItem, i, j)
                end
            end
        end
    end
end

SlashCmdList.FSWAP = function()
    if Focus:FocusExists(true) and UnitExists("target") then
        local target = UnitName("target")
        Focus:TargetFocus()
        Focus:SetFocus(target)
    end
end
