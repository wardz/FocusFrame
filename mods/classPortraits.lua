if not IsAddOnLoaded("ClassPortraits") then return end

local iconPath = "Interface\\Addons\\ClassPortraits\\UI-CLASSES-CIRCLES"
local CLASS_BUTTONS = {
	["HUNTER"] = {
		0, -- [1]
		0.25, -- [2]
		0.25, -- [3]
		0.5, -- [4]
	},
	["WARRIOR"] = {
		0, -- [1]
		0.25, -- [2]
		0, -- [3]
		0.25, -- [4]
	},
	["ROGUE"] = {
		0.49609375, -- [1]
		0.7421875, -- [2]
		0, -- [3]
		0.25, -- [4]
	},
	["MAGE"] = {
		0.25, -- [1]
		0.49609375, -- [2]
		0, -- [3]
		0.25, -- [4]
	},
	["PRIEST"] = {
		0.49609375, -- [1]
		0.7421875, -- [2]
		0.25, -- [3]
		0.5, -- [4]
	},
	["WARLOCK"] = {
		0.7421875, -- [1]
		0.98828125, -- [2]
		0.25, -- [3]
		0.5, -- [4]
	},
	["DRUID"] = {
		0.7421875, -- [1]
		0.98828125, -- [2]
		0, -- [3]
		0.25, -- [4]
	},
	["SHAMAN"] = {
		0.25, -- [1]
		0.49609375, -- [2]
		0.25, -- [3]
		0.5, -- [4]
	},
	["PALADIN"] = {
		0, -- [1]
		0.25, -- [2]
		0.5, -- [3]
		0.75, -- [4]
	},
}

local orig_FocusFrame_CheckPortrait = FocusFrame_CheckPortrait
FocusFrame_CheckPortrait = function(event, unit)
    orig_FocusFrame_CheckPortrait(event, unit)

    if UnitExists(unit) == 1 and UnitIsPlayer(unit) == 1 then
        local _, class = UnitClass(unit)

        FocusPortrait:SetTexture(iconPath, true)
        FocusPortrait:SetTexCoord(unpack(CLASS_BUTTONS[class]))
    else
        FocusPortrait:SetTexCoord(0, 1, 0, 1)
    end
end
