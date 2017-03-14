-- Add support for luna clickcasting
-- NOTE: Clique support is not possible.
getfenv(0).Focus_Loader:Register("LunaUnitFrames", function(Focus)
    local L = LunaUF.L

    FocusFrame_OnClick = function(btn)
        if btn == "UNKNOWN" then
            btn = LunaUF.clickedButton
        end

        --[[if Luna_Custom_ClickFunction and Luna_Custom_ClickFunction(btn, "target") then
            return
        end]]

        local button = (IsControlKeyDown() and "Ctrl-" or "") .. (IsShiftKeyDown() and "Shift-" or "") .. (IsAltKeyDown() and "Alt-" or "") .. L[btn]
        local action = LunaUF.db.profile.clickcasting.bindings[button]

        if not action then
            return
        elseif action == L["menu"] then
            if SpellIsTargeting() then
                return SpellStopTargeting()
            end
        elseif action == L["target"] then
            if SpellIsTargeting() then
                Focus:Call(SpellTargetUnit)
            elseif CursorHasItem() then
                Focus:Call(DropItemOnUnit)
            else
                Focus:TargetFocus()
            end
        else
            LunaUF:Mouseover("FocusData:Call(CastSpellByName, " .. action .. ")")
        end
    end
end)
