-- Adds support for ClassPortraits addon.
getglobal("FocusFrame_Loader"):Register("ClassPortraits", function(Focus)

	local iconPath = "Interface\\Addons\\ClassPortraits\\UI-CLASSES-CIRCLES"

	local CLASS_BUTTONS = {
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
end)
