FocusFrame.cast = CreateFrame("StatusBar", "FocusFrame_Castbar", FocusFrame)
FocusFrame.cast:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
FocusFrame.cast:SetStatusBarColor(0.4, 1, 0)
FocusFrame.cast:SetHeight(12)
FocusFrame.cast:SetWidth(151)
FocusFrame.cast:SetPoint("BOTTOMLEFT", FocusFrame, 15, -35)
FocusFrame.cast:SetValue(0)
FocusFrame.cast:Hide()

FocusFrame.cast.spark = FocusFrame.cast:CreateTexture(nil, "OVERLAY")
FocusFrame.cast.spark:SetTexture([[Interface\CastingBar\UI-CastingBar-Spark]])
FocusFrame.cast.spark:SetHeight(26)	
FocusFrame.cast.spark:SetWidth(26)
FocusFrame.cast.spark:SetBlendMode("ADD")

FocusFrame.cast.border = FocusFrame.cast:CreateTexture(nil, "OVERLAY")
FocusFrame.cast.border:SetPoint("TOP", 0, 28)
FocusFrame.cast.border:SetWidth(210)
FocusFrame.cast.border:SetTexture("Interface\\CastingBar\\UI-CastingBar-Border")

FocusFrame.cast.text = FocusFrame.cast:CreateFontString(nil, "OVERLAY")
FocusFrame.cast.text:SetTextColor(1, 1, 1)
FocusFrame.cast.text:SetFont(STANDARD_TEXT_FONT, 10)
FocusFrame.cast.text:SetShadowColor(0, 0, 0)
FocusFrame.cast.text:SetPoint("CENTER", FocusFrame.cast, 0, 2)
FocusFrame.cast.text:SetText("Drain Life")

FocusFrame.cast.timer = FocusFrame.cast:CreateFontString(nil, "OVERLAY")
FocusFrame.cast.timer:SetTextColor(1, 1, 1)
FocusFrame.cast.timer:SetFont(STANDARD_TEXT_FONT, 9)
FocusFrame.cast.timer:SetShadowColor(0, 0, 0)
FocusFrame.cast.timer:SetPoint("RIGHT", FocusFrame.cast, 32, 2)
FocusFrame.cast.timer:SetText("2.0s")

FocusFrame.cast.icon = FocusFrame.cast:CreateTexture(nil, "OVERLAY", nil, 7)
FocusFrame.cast.icon:SetWidth(20)
FocusFrame.cast.icon:SetHeight(20)
FocusFrame.cast.icon:SetPoint("LEFT", FocusFrame.cast, -35, 0)
FocusFrame.cast.icon:SetTexture("Interface\\Icons\\Spell_shadow_lifedrain02")

do
	local FSPELLCASTINGCOREgetCast = FSPELLCASTINGCOREgetCast
	local FSPELLCASTINGCOREgetHeal = FSPELLCASTINGCOREgetHeal
	local castbar = FocusFrame.cast
	local floor, GetTime, mod = math.floor, GetTime, mod

	local function Round(num, idp)
		local mult = 10^(idp or 0)

		return floor(num * mult + 0.5) / mult
	end

	local function GetTimerLeft(tEnd)
		local t = tEnd - GetTime()

		return Round(t, t > 3 and 0 or 1)
	end

	function FocusFrame_ScanCast()
		if not castbar then return end
		local cast = FSPELLCASTINGCOREgetCast(CURR_FOCUS_TARGET) --or FSPELLCASTINGCOREgetHeal(CURR_FOCUS_TARGET)

		if cast then
			local timeEnd, timeStart = cast.timeEnd, cast.timeStart
			local gTime = GetTime()

			if gTime < timeEnd then
				castbar:SetMinMaxValues(0, timeEnd - timeStart)

				local sparkPosition
				if cast.inverse then
					castbar:SetValue(mod((timeEnd - gTime), timeEnd - timeStart))
					sparkPosition = (timeEnd - gTime) / (timeEnd - timeStart)
				else
					castbar:SetValue(mod((gTime - timeStart), timeEnd - timeStart))
					sparkPosition = (gTime - timeStart) / (timeEnd - timeStart)
				end

				if sparkPosition < 0 then
					sparkPosition = 0
				end
				castbar.spark:SetPoint("CENTER", castbar, "LEFT", sparkPosition * castbar:GetWidth(), 0)

				castbar.text:SetText(cast.spell)
				castbar.timer:SetText(GetTimerLeft(timeEnd) .. "s")
				castbar.icon:SetTexture(cast.icon)
				castbar:SetAlpha(castbar:GetAlpha())
				castbar:Show()
			end
		else
			castbar:Hide()
		end
	end
end
