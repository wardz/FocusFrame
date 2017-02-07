local ipairs, WorldFrame = ipairs, WorldFrame

local function IsPlate(frame)
	local overlayRegion = frame:GetRegions()
	if not overlayRegion or overlayRegion:GetObjectType() ~= "Texture"
	or overlayRegion:GetTexture() ~= [[Interface\Tooltips\Nameplate-Border]] then
		return false
	end
	return true
end

function FocusFrame_ScanHealth()
	local frames = { WorldFrame:GetChildren() }

	for _, plate in ipairs(frames) do
		if IsPlate(plate) and plate:IsVisible() then
			local _, _, nameFrame = plate:GetRegions()
			local health = plate:GetChildren():GetValue()
			local name = nameFrame:GetText()

			if name == CURR_FOCUS_TARGET then
				return FocusFrame_SetUnitHealth(name, health)
			end
		end
	end
end
