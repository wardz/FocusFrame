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

local Focus = getglobal("FocusData")

local UpdatePortrait = function(event, unit) -- ran after FocusFrame_CheckPortrait
	-- Just a note if you're gonna hook any FocusFrame functions,
	-- unit id argument is not always guaranteed for certain events, so you need to check 
	-- if unit is nil before u use it
    if UnitExists(unit) == 1 and UnitIsPlayer(unit) == 1 then
        local _, class = UnitClass(unit)
		local coords = CLASS_BUTTONS[class]

        FocusPortrait:SetTexture(iconPath, true)
        FocusPortrait:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    else
        FocusPortrait:SetTexCoord(0, 1, 0, 1)
    end
end

Focus:OnEvent("FOCUS_UNITID_EXISTS", UpdatePortrait) -- on focus targeted
Focus:OnEvent("UNIT_PORTRAIT_UPDATE", UpdatePortrait) -- while focus is targeted
