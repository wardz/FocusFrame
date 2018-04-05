local _G = getfenv(0)
local Focus = assert(_G.FocusCore, "FocusCore not loaded.")
local AurasUpdate

FocusFrameDB = FocusFrameDB or { unlock = true, scale = 1 }

-- Most local functions here can be post-hooked using Focus:OnEvent() if needed.
-- @see UpdatePortrait() in mods/classPortraits.lua for examples.
-- @see Focus:RemoveEvent() for completely overwriting functions

local function OnFocusTargetUpdated(event, name, isDead, unitID)
	if not name then
		FocusFrameTargetofTargetFrame:Hide()
		return
	end

	if name == "target" then return end

	FocusFrameTargetofTargetFrame:Show()

	local health, maxHealth = Focus:GetTargetHealth()
	local mana, maxMana = Focus:GetTargetPower()

	FocusFrameTargetofTargetHealthBar:SetMinMaxValues(0, maxHealth)
	FocusFrameTargetofTargetHealthBar:SetValue(health)
	FocusFrameTargetofTargetManaBar:SetMinMaxValues(0, maxMana)
	FocusFrameTargetofTargetManaBar:SetValue(mana)

	if isDead then
		FocusFrameTargetofTargetDeadText:Show()
	else
		FocusFrameTargetofTargetDeadText:Hide()
	end

	FocusFrameTargetofTargetName:SetText(name)
	SetPortraitTexture(FocusFrameTargetofTargetPortrait, unitID)
end

local function OnFocusSat(event, unit)
	FocusName:SetText(UnitName(unit))
	FocusFrame:SetScale(FocusFrameDB.scale or 1)

	--[[if Focus:GetTargetName() then
		OnFocusTargetChanged(event, Focus:GetTargetName(), Focus:TargetIsDead())
	end]]

	FocusFrame:SetScript("OnUpdate", FocusFrame_CastingBarOnUpdate)
	FocusFrame:Show()
end

local function OnFocusIdle()
	if FocusFrameDB.fadeOnIdle then
		FocusFrame:SetAlpha(0.6)
	end
end

local function OnFocusActive()
	FocusFrame:SetAlpha(1)
end

local function HealthUpdate()
	local health, maxHealth = Focus:GetHealth()
	local mana, maxMana = Focus:GetPower()

	FocusFrameHealthBar:SetMinMaxValues(0, maxHealth)
	FocusFrameHealthBar:SetValue(health)
	FocusFrameManaBar:SetMinMaxValues(0, maxMana)
	FocusFrameManaBar:SetValue(mana)

	if FocusFrameManaBar:IsShown() then
		local color = Focus:GetPowerColor()
		FocusFrameManaBar:SetStatusBarColor(color.r, color.g, color.b)
	else
		FocusFrameManaBarText:SetText(nil)
	end

	if Focus:IsDead() then
		FocusDeadText:Show()
	else
		FocusDeadText:Hide()
	end
end

local function RaidTargetIconUpdate()
	local index = Focus:GetData("raidIcon")

	if index then
		SetRaidTargetIconTexture(FocusRaidTargetIcon, index)
		FocusRaidTargetIcon:Show()
	else
		FocusRaidTargetIcon:Hide()
	end
end

function FocusFrame_CastingBarOnUpdate() -- ran every fps
	local cast, value, maxValue, sparkPosition, timer = Focus:GetCast()

	if cast then
		local castbar = FocusCastingBar
		castbar:SetMinMaxValues(0, maxValue)
		castbar:SetValue(value)
		castbar.spark:SetPoint("CENTER", castbar, "LEFT", sparkPosition * castbar:GetWidth(), 0)
		castbar.timer:SetText(timer)

		if cast.immune then
			castbar.shield:Show()
		else
			castbar.shield:Hide()
		end

		if not castbar:IsVisible() or castbar.text:GetText() ~= cast.spell then
			castbar.text:SetText(cast.spell)
			castbar.icon:SetTexture(cast.icon)
			castbar:SetAlpha(castbar:GetAlpha())
			castbar:Show()
		end
	else
		FocusCastingBar:Hide()
	end
end

function FocusFrame_OnShow()
	-- Ran on FOCUS_SET. "target" = focus here
	if UnitIsEnemy("target", "player") then
		PlaySound("igCreatureAggroSelect")
	elseif UnitIsFriend("player", "target") then
		PlaySound("igCharacterNPCSelect")
	else
		PlaySound("igCreatureNeutralSelect")
	end
end

function FocusFrame_OnHide() -- can't be hooked, global due to xml
	if FocusFrame:IsVisible() then -- called by FOCUS_CLEAR instead of OnHide
		FocusFrame:SetScript("OnUpdate", nil)
		FocusFrame:Hide()
	else
		PlaySound("INTERFACESOUND_LOSTTARGETUNIT")
		CloseDropDownMenus()
	end
end

function FocusFrame_OnClick(button)
	if button == "RightButton" and SpellIsTargeting() then
		return SpellStopTargeting()
	end

	if button == "LeftButton" then
		if SpellIsTargeting() then
			Focus:Call(SpellTargetUnit)
		elseif CursorHasItem() then
			Focus:Call(DropItemOnUnit)
		else
			Focus:TargetFocus()
		end
	else
		ToggleDropDownMenu(1, nil, FocusFrameDropDown, "FocusFrame", 120, 10)
	end
end

function FocusFrameTarget_OnClick(button)
	if button == "LeftButton" then
		Focus:TargetFocusTarget()
	end
end

local function CheckPortrait(event, unit)
	SetPortraitTexture(FocusPortrait, unit)
	FocusPortrait:SetAlpha(1)
end

local function CheckLevel()
	local level, isCorpse = Focus:GetData("unitLevel", "unitIsCorpse")

	if isCorpse == 1 then
		FocusLevelText:Hide()
		FocusHighLevelTexture:Show()
	elseif level > 0 then
		-- Normal level target
		FocusLevelText:SetText(level)

		-- Color level number
		if Focus:GetData("playerCanAttack") == 1 then
			local color = GetDifficultyColor(level)
			FocusLevelText:SetVertexColor(color.r, color.g, color.b)
		else
			FocusLevelText:SetVertexColor(1.0, 0.82, 0.0)
		end

		FocusLevelText:Show()
		FocusHighLevelTexture:Hide()
	else
		-- Target is too high level to tell
		FocusLevelText:Hide()
		FocusHighLevelTexture:Show()
	end
end

local function CheckFaction()
	if Focus:GetData("unitPlayerControlled") == 1 then
		local r, g, b = Focus:GetReactionColors()
		FocusFrameNameBackground:SetVertexColor(r, g, b)
		FocusPortrait:SetVertexColor(1.0, 1.0, 1.0)
	elseif Focus:GetData("unitIsTapped") == 1 and Focus:GetData("unitIsTappedByPlayer") ~= 1 then
		FocusFrameNameBackground:SetVertexColor(0.5, 0.5, 0.5)
		FocusPortrait:SetVertexColor(0.5, 0.5, 0.5)
	elseif Focus:GetData("unitIsCivilian") == 1 then
		FocusFrameNameBackground:SetVertexColor(1.0, 1.0, 1.0)
		FocusPortrait:SetVertexColor(1.0, 1.0, 1.0)
	else
		local reaction = Focus:GetData("unitReaction")
		if reaction then
			local color = UnitReactionColor[reaction]
			FocusFrameNameBackground:SetVertexColor(color.r, color.g, color.b)
		else
			FocusFrameNameBackground:SetVertexColor(0, 0, 1.0)
		end

		FocusPortrait:SetVertexColor(1.0, 1.0, 1.0)
	end

	-- PvP Icon
	local factionGroup = Focus:GetData("unitFactionGroup")
	if Focus:GetData("unitIsPVPFreeForAll") == 1 then
		FocusPVPIcon:SetTexture("Interface\\TargetingFrame\\UI-PVP-FFA")
		FocusPVPIcon:Show()
	elseif factionGroup and Focus:GetData("unitIsPVP") == 1 then
		FocusPVPIcon:SetTexture("Interface\\TargetingFrame\\UI-PVP-" .. factionGroup)
		FocusPVPIcon:Show()
	else
		FocusPVPIcon:Hide()
	end
end

local function CheckClassification()
	local classification = Focus:GetData("unitClassification")

	if classification == "worldboss" or classification == "rareelite" or classification == "elite" then
		FocusFrameTexture:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Elite")
	elseif classification == "rare" then
		FocusFrameTexture:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Rare")
	else
		FocusFrameTexture:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame")
	end
end

local function CheckLeader()
	if Focus:GetData("unitIsPartyLeader") == 1 then
		FocusLeaderIcon:Show()
	else
		FocusLeaderIcon:Hide()
	end
end

do
	-- Aura handling
	-- Works the same as in blizz TargetFrame.lua

	local function AdjustAuras(numDebuffs, numBuffs)
		local unitIsFriend = Focus:GetData("unitIsFriend")
		local targetofTarget = FocusFrameTargetofTargetFrame:IsShown()
		local debuffSize, debuffFrameSize
		local debuffWrap = 6

		if numDebuffs >= debuffWrap then
			debuffSize = 17
			debuffFrameSize = 19
		else
			debuffSize = 21
			debuffFrameSize = 23
		end

		if unitIsFriend == 1 then
			FocusFrameBuff1:SetPoint("TOPLEFT", "FocusFrame", "BOTTOMLEFT", 5, 32)
			FocusFrameDebuff1:SetPoint("TOPLEFT", "FocusFrameBuff1", "BOTTOMLEFT", 0, -2)
		else
			FocusFrameDebuff1:SetPoint("TOPLEFT", "FocusFrame", "BOTTOMLEFT", 5, 32)
			if targetofTarget then
				if numDebuffs < 5 then
					FocusFrameBuff1:SetPoint("TOPLEFT", "FocusFrameDebuff6", "BOTTOMLEFT", 0, -2)
				elseif numDebuffs >= 5 and numDebuffs < 10 then
					FocusFrameBuff1:SetPoint("TOPLEFT", "FocusFrameDebuff6", "BOTTOMLEFT", 0, -2)
				elseif numDebuffs >= 10 then
					FocusFrameBuff1:SetPoint("TOPLEFT", "FocusFrameDebuff11", "BOTTOMLEFT", 0, -2)
				end
			else
				FocusFrameBuff1:SetPoint("TOPLEFT", "FocusFrameDebuff7", "BOTTOMLEFT", 0, -2)
			end
		end

		-- set the wrap point for the rows of de/buffs.
		debuffWrap = targetofTarget and 5 or 6

		-- and shrinks the debuffs if they begin to overlap the TargetFrame
		if ((targetofTarget and (numBuffs == 5)) or (numDebuffs >= debuffWrap)) then
			debuffSize = 17
			debuffFrameSize = 19
		else
			debuffSize = 21
			debuffFrameSize = 23
		end

		-- resize Buffs
		for i = 1, 5 do
			local button = _G["FocusFrameBuff" .. i]
			if button then
				button:SetWidth(debuffSize)
				button:SetHeight(debuffSize)
			end
		end

		-- resize Debuffs
		for i = 1, 6 do
			local button = _G["FocusFrameDebuff" .. i]
			local debuffFrame = _G["FocusFrameDebuff" .. i .. "Border"]

			if debuffFrame then
				debuffFrame:SetWidth(debuffFrameSize)
				debuffFrame:SetHeight(debuffFrameSize)
			end

			button:SetWidth(debuffSize)
			button:SetHeight(debuffSize)
		end

		-- Reset anchors for debuff wrapping
		_G["FocusFrameDebuff"..debuffWrap]:ClearAllPoints()
		_G["FocusFrameDebuff"..debuffWrap]:SetPoint("LEFT", _G["FocusFrameDebuff"..(debuffWrap - 1)], "RIGHT", 3, 0)
		_G["FocusFrameDebuff"..(debuffWrap + 1)]:ClearAllPoints()
		_G["FocusFrameDebuff"..(debuffWrap + 1)]:SetPoint("TOPLEFT", "FocusFrameDebuff1", "BOTTOMLEFT", 0, -2)
		_G["FocusFrameDebuff"..(debuffWrap + 2)]:ClearAllPoints()
		_G["FocusFrameDebuff"..(debuffWrap + 2)]:SetPoint("LEFT", _G["FocusFrameDebuff"..(debuffWrap + 1)], "RIGHT", 3, 0)

		FocusFrameDebuff11:ClearAllPoints()
		FocusFrameDebuff11:SetPoint("LEFT", "FocusFrameDebuff10", "RIGHT", 3, 0)

		-- Set anchor for the last row if debuffWrap is 5
		TargetFrameDebuff11:ClearAllPoints()
		if debuffWrap == 5 then
			TargetFrameDebuff11:SetPoint("TOPLEFT", "TargetFrameDebuff6", "BOTTOMLEFT", 0, -2)
		else
			TargetFrameDebuff11:SetPoint("LEFT", "TargetFrameDebuff10", "RIGHT", 3, 0)
		end

		-- Move castbar based on amount of auras shown
		local y = (numBuffs + numDebuffs) > 7 and -70 or -35
		if unitIsFriend ~= 1 and numBuffs >= 1 then
			FocusCastingBar:SetPoint("BOTTOMLEFT", _G["FocusFrameBuff1"], 0, -35)
		else
			FocusCastingBar:SetPoint("BOTTOMLEFT", FocusFrame, 20, y)
		end
	end

	function AurasUpdate() -- local, ran very frequent
		local buffData = Focus:GetBuffs()
		local buffs = buffData.buffs
		local debuffs = buffData.debuffs
		local numBuffs = 0
		local numDebuffs = 0

		-- Set buffs shown
		for i = 1, 5 do
			local buff = buffs[i]
			local button = _G["FocusFrameBuff" .. i]

			if buff then
				_G["FocusFrameBuff" .. i .. "Icon"]:SetTexture(buff.icon)
				button:Show()
				button.id = i
				numBuffs = numBuffs + 1
			else
				button:Hide()
			end
		end

		-- Set debuffs shown
		for i = 1, 16 do
			local button = _G["FocusFrameDebuff" .. i]
			local debuff = debuffs[i]

			if debuff then
				local debuffCount = _G["FocusFrameDebuff" .. i .. "Count"]
				local debuffBorder = _G["FocusFrameDebuff" .. i .. "Border"]

				local color = debuff.border
				local debuffStack = debuff.stacks
				_G["FocusFrameDebuff" .. i .. "Icon"]:SetTexture(debuff.icon)

				if debuffStack and debuffStack > 1 then
					debuffCount:SetText(debuffStack)
					debuffCount:Show()
				else
					debuffCount:Hide()
				end

				debuffBorder:SetVertexColor(color[1], color[2], color[3], color[4])
				button:Show()
				numDebuffs = numDebuffs + 1
			else
				button:Hide()
			end

			button.id = i
		end

		AdjustAuras(numDebuffs, numBuffs)
	end
end

-- Dropdown menu
do
	local info = {}
	local FocusFrameDropDown = CreateFrame("Frame", "FocusFrameDropDown")
	FocusFrameDropDown.displayMode = "MENU"

	local function SetRaidMark()
		local mark = this.value
		if mark >= 9 then mark = 0 end

		Focus:Call(SetRaidTargetIcon, "target", mark)
	end

	local function Unlock()
		FocusFrameDB.unlock = not FocusFrameDB.unlock
	end

	local function Rescale()
		if FocusFrameDB.scale >= 1 then
			FocusFrameDB.scale = 0.9
		else
			FocusFrameDB.scale = 1
		end
		FocusFrame:SetScale(FocusFrameDB.scale)
	end

	local function ClearFocus()
		Focus:ClearFocus()
	end

	function FocusFrameDropDown_Initialize(level) -- ran every time dropdown is shown/updated
		if not level then return end
		for k, v in pairs(info) do info[k] = nil end

		if level == 1 then
			info.isTitle = 1
			info.text = Focus:GetName()
			info.notCheckable = 1
			UIDropDownMenu_AddButton(info, level)

			-- Reusing same table for mem improvements, so delete old values
			info.disabled = nil
			info.isTitle = nil
			info.notCheckable = nil

			local isLeader = UnitIsPartyLeader("player")
			info.text = "Target Marker Icon"
			info.nested = 1
			info.hasArrow = isLeader
			info.disabled = not isLeader
			UIDropDownMenu_AddButton(info, level)

			info.hasArrow = nil
			info.nested = nil
			info.menuList = nil
			info.disabled = nil

			info.text = "Clear Focus"
			info.func = ClearFocus
			UIDropDownMenu_AddButton(info, level)

			info.isTitle = 1
			info.text = "Other Options"
			info.notCheckable = 1
			UIDropDownMenu_AddButton(info, level)

			info.disabled = nil
			info.isTitle = nil
			info.notCheckable = nil

			info.text = "Larger Focus Frame"
			info.checked = FocusFrameDB.scale >= 1
			info.func = Rescale
			UIDropDownMenu_AddButton(info, level)
			info.checked = nil

			info.text = "Unlock"
			info.checked = FocusFrameDB.unlock
			info.func = Unlock
			UIDropDownMenu_AddButton(info, level)
			info.checked = nil

			-- Close menu item
			info.text = "Close"
			info.func = CloseDropDownMenus
			info.checked = nil
			info.notCheckable = 1
			UIDropDownMenu_AddButton(info, level)
		else
			-- Build nested dropdown for raid marks
			for i, name in ipairs(UnitPopupMenus["RAID_TARGET_ICON"]) do
				local item = UnitPopupButtons[name]
				info.color = nil
				info.icon = nil
				info.value = nil
				for k, v in pairs(item) do
					info[k] = v
					info.value = i
				end
				info.func = SetRaidMark
				UIDropDownMenu_AddButton(info, level)
			end
		end

		info = {}
	end

	FocusFrameDropDown.initialize = FocusFrameDropDown_Initialize
end

-- Create castbar
-- @TODO add to xml
-- lua table names are deprecated. Please use global frame names if you're gonna modify these
FocusFrame.cast = CreateFrame("StatusBar", "FocusCastingBar", FocusFrame)
FocusFrame.cast:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
FocusFrame.cast:SetStatusBarColor(0.4, 1, 0)
FocusFrame.cast:SetHeight(13)
FocusFrame.cast:SetWidth(151)
FocusFrame.cast:SetPoint("BOTTOMLEFT", FocusFrame, 15, -35)
FocusFrame.cast:SetValue(0)
FocusFrame.cast:Hide()

FocusFrame.cast.spark = FocusFrame.cast:CreateTexture("FocusCastingBarSpark", "OVERLAY")
FocusFrame.cast.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
FocusFrame.cast.spark:SetHeight(26)
FocusFrame.cast.spark:SetWidth(26)
FocusFrame.cast.spark:SetBlendMode("ADD")

FocusFrame.cast.border = FocusFrame.cast:CreateTexture("FocusCastingBarBorder", "OVERLAY")
FocusFrame.cast.border:SetPoint("TOPLEFT", -23, 20)
FocusFrame.cast.border:SetPoint("TOPRIGHT", 23, 20)
FocusFrame.cast.border:SetHeight(50)
FocusFrame.cast.border:SetTexture("Interface\\AddOns\\FocusFrame\\Media\\UI-CastingBar-Border-Small.blp")

FocusFrame.cast.text = FocusFrame.cast:CreateFontString("FocusCastingBarText", "OVERLAY")
FocusFrame.cast.text:SetTextColor(1, 1, 1)
FocusFrame.cast.text:SetFont(STANDARD_TEXT_FONT, 10)
FocusFrame.cast.text:SetShadowColor(0, 0, 0)
FocusFrame.cast.text:SetPoint("CENTER", FocusFrame.cast, 0, 2)
FocusFrame.cast.text:SetText("Drain Life")

FocusFrame.cast.timer = FocusFrame.cast:CreateFontString("FocusCastingBarTimer", "OVERLAY")
FocusFrame.cast.timer:SetTextColor(1, 1, 1)
FocusFrame.cast.timer:SetFont(STANDARD_TEXT_FONT, 9)
FocusFrame.cast.timer:SetShadowColor(0, 0, 0)
FocusFrame.cast.timer:SetPoint("RIGHT", FocusFrame.cast, 28, 2)
FocusFrame.cast.timer:SetText("2.0")

FocusFrame.cast.icon = FocusFrame.cast:CreateTexture("FocusCastingBarIcon", "OVERLAY", nil, 7)
FocusFrame.cast.icon:SetWidth(20)
FocusFrame.cast.icon:SetHeight(20)
FocusFrame.cast.icon:SetPoint("LEFT", FocusFrame.cast, -23, 1)
FocusFrame.cast.icon:SetTexture("Interface\\Icons\\Spell_shadow_lifedrain02")

FocusFrame.cast.shield = FocusFrame.cast:CreateTexture("FocusCastingBarShield", "OVERLAY")
FocusFrame.cast.shield:SetPoint("TOPLEFT", -28, 20)
FocusFrame.cast.shield:SetPoint("TOPRIGHT", 18, 20)
FocusFrame.cast.shield:SetHeight(50)
FocusFrame.cast.shield:SetTexture("Interface\\AddOns\\FocusFrame\\Media\\UI-CastingBar-Small-Shield.blp")
FocusFrame.cast.shield:Hide()

-- Register events
Focus:OnEvent("FOCUS_SET", OnFocusSat)
Focus:OnEvent("FOCUS_CLEAR", FocusFrame_OnHide)
Focus:OnEvent("RAID_TARGET_UPDATE", RaidTargetIconUpdate)
Focus:OnEvent("PLAYER_FLAGS_CHANGED", CheckLeader)
Focus:OnEvent("PARTY_LEADER_CHANGED", CheckLeader)
Focus:OnEvent("UNIT_HEALTH_OR_POWER", HealthUpdate)
Focus:OnEvent("UNIT_AURA", AurasUpdate)
Focus:OnEvent("UNIT_LEVEL", CheckLevel)
Focus:OnEvent("UNIT_FACTION", CheckFaction)
Focus:OnEvent("UNIT_CLASSIFICATION_CHANGED", CheckClassification)
Focus:OnEvent("UNIT_PORTRAIT_UPDATE", CheckPortrait)
Focus:OnEvent("FOCUS_UNITID_EXISTS", CheckPortrait) -- update on retarget/mouseover aswell
Focus:OnEvent("FOCUS_ACTIVE", OnFocusActive)
Focus:OnEvent("FOCUS_INACTIVE", OnFocusIdle)
Focus:OnEvent("FOCUS_TARGET_UPDATED", OnFocusTargetUpdated)

-- Chat options
SLASH_FOCUSOPTIONS1 = "/foption"
SlashCmdList.FOCUSOPTIONS = function(msg)
	local space = strfind(msg or "", " ")
	local cmd = strsub(msg, 1, space and (space-1))
	local value = tonumber(strsub(msg, space or -1))

	local print = function(a, b)
		if type(b) == "boolean" then b = tostring(b) end
		DEFAULT_CHAT_FRAME:AddMessage(string.format(a, b))
	end

	if cmd == "scale" and value then
		local x = value > 0.1 and value <= 2 and value or 1
		FocusFrame:SetScale(x)
		FocusFrameDB.scale = x
		print("Scale set to %f", x)
	elseif cmd == "lock" then
		FocusFrameDB.unlock = not FocusFrameDB.unlock
		print("Frame is now %slocked.", FocusFrameDB.unlock and "un" or "")
	elseif cmd == "nohide" then
		local x = FocusFrameDB.alwaysShow
		FocusFrameDB.alwaysShow = not x
		print("Frame auto hide set to %s", not x)
	elseif cmd == "fade" then
		FocusFrameDB.fadeOnIdle = not FocusFrameDB.fadeOnIdle
		print("Fade on inactive set to %s (requires retarget on focus)", FocusFrameDB.fadeOnIdle)
	elseif cmd == "strictaura" then
		FocusFrameDB.strictAuras = not FocusFrameDB.strictAuras
		FSPELLCASTINGCOREstrictAuras = FocusFrameDB.strictAuras
		print("Strict aura/cast set to %s.", FocusFrameDB.strictAuras)
	elseif cmd == "noplates" then
		local x = FocusFrameDB.disableNameplateScan
		FocusFrameDB.disableNameplateScan = not x
		Focus:ToggleNameplateScan(not x)
		print("Nameplate scanning set to %s.", not x)
	elseif cmd == "target" then
		FocusFrameDB.tot = not FocusFrameDB.tot
		OnFocusTargetUpdated(nil, nil) -- force hide tot frame
		print("Target of Target set to %s", FocusFrameDB.tot)
	elseif cmd == "statustext" then
		FocusFrameDB.statusText = not FocusFrameDB.statusText
		FocusFrameHealthBar.TextString:SetAlpha(FocusFrameDB.statusText and 0 or 1) -- kinda hacky with alpha but easiest solution
		FocusFrameManaBar.TextString:SetAlpha(FocusFrameDB.statusText and 0 or 1)
		print("Status text set to %s.", not FocusFrameDB.statusText)
	elseif cmd == "reset" then
		FocusFrameDB = { scale = 1, unlock = true }
		FocusFrame:SetScale(1)
		FocusFrame:SetAlpha(1)
		FocusFrame:SetPoint("TOPLEFT", 250, -300)
		FocusFrame:StopMovingOrSizing() -- trigger save
		FSPELLCASTINGCOREstrictAuras = false
		Focus:ToggleNameplateScan(true)
		FocusFrameHealthBar.TextString:SetAlpha(1)
		FocusFrameManaBar.TextString:SetAlpha(1)
		print("FocusFrame has been reset.")
	else
		print("FocusFrame v%s:", GetAddOnMetadata("FocusFrame", "version"))
		print("    scale 1.0 -|cff00FF7F Change frame size (0.2 - 2.0)")
		print("    lock -|cff00FF7F Toggle dragging of frame")
		print("    nohide -|cff00FF7F Toggle auto hide of frame on loading screens/release spirit.")
		print("    fade -|cff00FF7F Toggle fading of frame when focus hasn't been updated for ~10s.")
		print("    strictaura -|cff00FF7F Toggle aura/cast optimization. See github wiki for more info.")
		print("    noplates -|cff00FF7F Toggle nameplate scanning. Disable if you don't use nameplates.")
		print("    target -|cff00FF7F Toggle focus target's target frame.")
		print("    statustext -|cff00FF7F Toggle mana/hp status text.")
		print("    reset -|cff00FF7F Reset to default settings.")
	end
end
