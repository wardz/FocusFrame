local Loader = getfenv(0).Focus_Loader

-- luna clickcasting
Loader:Register("LunaUnitFrames", function(Focus)
    local orig_lufmo = SlashCmdList.LUFMO

    SlashCmdList.LUFMO = function(arg1, arg2)
        local frame = GetMouseFocus()

        if arg1 and strfind(frame:GetName() or "", "FocusFrame") then
            Focus:Call(CastSpellByName, arg1)
        else
            orig_lufmo(arg1, arg2)
        end
    end
end)

--[[Loader:Register("pfUI", function(Focus)
    local orig_pfcast = SlashCmdList.PFCAST

    SlashCmdList.PFCAST = function(arg1, arg2)
        local frame = GetMouseFocus()

        if arg1 and strfind(frame:GetName() or "", "FocusFrame") then
            Focus:Call(CastSpellByName, arg1)
        else
            orig_PFCAST(arg1, arg2)
        end
    end
end)]]
