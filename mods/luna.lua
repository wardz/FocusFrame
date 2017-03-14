-- Add support for luna clickcasting
getfenv(0).Focus_Loader:Register("LunaUnitFrames", function(Focus)
    local orig_lufmo = SlashCmdList.LUFMO

    SlashCmdList.LUFMO = function(arg1, arg2)
        local frame = GetMouseFocus()

        if strfind(frame:GetName() or "", "FocusFrame") then
            LunaUF:Mouseover('FocusData:Call(CastSpellByName, "' .. arg1 .. '")')
        else
            orig_lufmo(arg1, arg2)
        end
    end
end)
