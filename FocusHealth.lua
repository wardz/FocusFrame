local ipairs, WorldFrame = ipairs, WorldFrame

local function IsPlate(frame)
	local overlayRegion = frame:GetRegions()
	if not overlayRegion or overlayRegion:GetObjectType() ~= "Texture"
	or overlayRegion:GetTexture() ~= [[Interface\Tooltips\Nameplate-Border]] then
		return false
	end
	return true
end


--/run targettest("Fireball", 4)
--[[function targettest(spell, id)

	--TargetByName(CURR_FOCUS_TARGET)
	if FocusFrame_GetMobID() == id then
		CastSpellByName(spell)
	else
		TargetNearestEnemy()
	end

	print(FocusFrame_GetMobID())

end

function FocusFrame_GetMobID()
	local frames = { WorldFrame:GetChildren() }

	for i, plate in pairs(frames) do
		if IsPlate(plate) and plate:IsVisible() then
			local _, _, nameFrame = plate:GetRegions()
			local name = nameFrame:GetText()
			--plate.mobID = plate.mobID or i

			if name == CURR_FOCUS_TARGET then
				if UnitExists("target") and plate:GetAlpha() == 1 then
					return plate.mobID
				end
			end
		end
	end
end]]

function FocusFrame_ScanPlates()
	local frames = { WorldFrame:GetChildren() }

	for i, plate in pairs(frames) do
		if IsPlate(plate) and plate:IsVisible() then
			local _, _, nameFrame = plate:GetRegions()
			local health = plate:GetChildren():GetValue()
			local name = nameFrame:GetText()
			--plate.mobID = plate.mobID or i

			if name == CURR_FOCUS_TARGET then
				return FocusFrame_SetUnitHealth(name, health)
			end
		end
	end
end
