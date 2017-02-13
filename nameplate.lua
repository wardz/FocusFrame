local ipairs, WorldFrame = ipairs, WorldFrame

local RaidIconCoordinate = {
	[0]		= { [0]	= 1,	[0.25]	= 5, },
	[0.25]	= { [0]	= 2,	[0.25]	= 6, },
	[0.5]	= { [0]	= 3,	[0.25]	= 7, },
	[0.75]	= { [0]	= 4,	[0.25]	= 8, },
}

local function IsPlate(frame)
	local overlayRegion = frame:GetRegions()
	if not overlayRegion or overlayRegion:GetObjectType() ~= "Texture"
	or overlayRegion:GetTexture() ~= [[Interface\Tooltips\Nameplate-Border]] then
		return false
	end
	return true
end

function FocusFrame_ScanPlates()
	local frames = { WorldFrame:GetChildren() }

	for _, plate in ipairs(frames) do
		if IsPlate(plate) and plate:IsVisible() then
			local _, _, nameFrame, _, _, raidIcon = plate:GetRegions()
			local health = plate:GetChildren():GetValue()
			local name = nameFrame:GetText()
			--plate.mobID = plate.mobID or i

			if name == CURR_FOCUS_TARGET then
				FocusFrame_SetUnitHealth(name, health)

				if raidIcon and raidIcon:IsVisible() then
					local ux, uy = raidIcon:GetTexCoord()
					local icon = RaidIconCoordinate[ux][uy]
					FocusFrame_SetUnitRaidIcon(name, icon)
					FocusFrame_UpdateRaidTargetIcon()
				end

				return
			end
		end
	end
end
