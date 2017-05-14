-- Adds support for ClassPortraits and ClassPortraits_Vanilla.
local OnLoad = function(Focus, addonName)
	local iconPath = "Interface\\Addons\\" .. addonName .. "\\UI-CLASSES-CIRCLES"

	local CLASS_COORDS = {
		["HUNTER"]	= { 0,			0.25,		0.25,	0.5  },
		["WARRIOR"] = { 0,			0.25,		0,		0.25 },
		["ROGUE"]	= { 0.49609375,	0.7421875,	0,		0.25 },
		["MAGE"]	= { 0.25, 		0.49609375,	0,		0.25 },
		["PRIEST"]	= { 0.49609375, 0.7421875,	0.25,	0.5  },
		["WARLOCK"] = { 0.7421875,	0.98828125, 0.25,	0.5  },
		["DRUID"]	= { 0.7421875,	0.98828125, 0,		0.25 },
		["SHAMAN"]	= { 0.25,		0.49609375, 0.25,	0.5  },
		["PALADIN"]	= { 0,			0.25,		0.5,	0.75 }
	}

	local UpdatePortrait = function(event, unit) -- ran after FocusFrame UpdatePortrait
		if UnitExists(unit) and UnitIsPlayer(unit) then
			local _, class = UnitClass(unit)
			local coords = CLASS_COORDS[class]

			FocusPortrait:SetTexture(iconPath, true)
			FocusPortrait:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
		else
			FocusPortrait:SetTexCoord(0, 1, 0, 1)
		end
	end

	-- "post-hook" event functions used in FocusFrame.lua
	Focus:OnEvent("FOCUS_UNITID_EXISTS", UpdatePortrait) -- on focus targeted
	Focus:OnEvent("UNIT_PORTRAIT_UPDATE", UpdatePortrait) -- while focus is targeted only
end

Focus_Loader:Register("ClassPortraits", OnLoad)
Focus_Loader:Register("ClassPortraits_Vanilla", OnLoad)
