local Focus = getglobal("FocusData")
FocusFrameDB = FocusFrameDB or { unlock = true }

--[[ Focus frame ]]

function FocusFrame_Refresh(event, unit)
	FocusName:SetText(UnitName(unit))
	SetPortraitTexture(FocusPortrait, unit)
	FocusPortrait:SetAlpha(1)

	if UnitIsPartyLeader(unit) then
		FocusLeaderIcon:Show()
	else
		FocusLeaderIcon:Hide()
	end

	FocusFrame_CheckDishonorableKill() -- TODO is there event for this?
	FocusFrame:SetScale(FocusFrameDB.scale or 1)
	FocusFrame:Show()
end

function FocusFrame_HealthUpdate()
	local health, maxHealth = Focus:GetHealth()
	local mana, maxMana = Focus:GetPower()

	FocusFrameHealthBar:SetMinMaxValues(0, maxHealth)
	FocusFrameHealthBar:SetValue(health)
	FocusFrameManaBar:SetMinMaxValues(0, maxMana)
	FocusFrameManaBar:SetValue(mana)
	local color = Focus:GetPowerColor()
	FocusFrameManaBar:SetStatusBarColor(color.r, color.g, color.b)

	if Focus:IsDead() then
		FocusDeadText:Show()
	else
		FocusDeadText:Hide()
	end

	SetTextStatusBarText(FocusFrameHealthBar, FocusFrameHealthBarText)
	SetTextStatusBarText(FocusFrameManaBar, FocusFrameManaBarText)
end

do
	local function PositionBuffs(numDebuffs, numBuffs)
		local debuffFrame, debuffWrap, debuffSize, debuffFrameSize;
		local targetofTarget = false --FocusTargetofTargetFrame:IsShown();

		if Focus:IsFriendly() then
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
		if ( ( targetofTarget and ( numBuffs == 5 ) ) or ( numDebuffs >= debuffWrap ) ) then
			debuffSize = 17
			debuffFrameSize = 19
		else
			debuffSize = 21
			debuffFrameSize = 23
		end
		
		-- resize Buffs
		for i = 1, 5 do
			button = getglobal("FocusFrameBuff" .. i)
			if button then
				button:SetWidth(debuffSize)
				button:SetHeight(debuffSize)
			end
		end

		-- resize Debuffs
		for i = 1, 6 do
			button = getglobal("FocusFrameDebuff" .. i)
			debuffFrame = getglobal("FocusFrameDebuff" .. i .. "Border")

			if debuffFrame then
				debuffFrame:SetWidth(debuffFrameSize)
				debuffFrame:SetHeight(debuffFrameSize)
			end

			button:SetWidth(debuffSize)
			button:SetHeight(debuffSize)
		end

		-- Reset anchors for debuff wrapping
		getglobal("FocusFrameDebuff"..debuffWrap):ClearAllPoints()
		getglobal("FocusFrameDebuff"..debuffWrap):SetPoint("LEFT", getglobal("FocusFrameDebuff"..(debuffWrap - 1)), "RIGHT", 3, 0)
		getglobal("FocusFrameDebuff"..(debuffWrap + 1)):ClearAllPoints()
		getglobal("FocusFrameDebuff"..(debuffWrap + 1)):SetPoint("TOPLEFT", "FocusFrameDebuff1", "BOTTOMLEFT", 0, -2)
		getglobal("FocusFrameDebuff"..(debuffWrap + 2)):ClearAllPoints()
		getglobal("FocusFrameDebuff"..(debuffWrap + 2)):SetPoint("LEFT", getglobal("FocusFrameDebuff"..(debuffWrap + 1)), "RIGHT", 3, 0)

		-- Set anchor for the last row if debuffWrap is 5
		if debuffWrap == 5 then
			FocusFrameDebuff11:ClearAllPoints()
			FocusFrameDebuff11:SetPoint("TOPLEFT", "FocusFrameDebuff6", "BOTTOMLEFT", 0, -2)
		else
			FocusFrameDebuff11:ClearAllPoints()
			FocusFrameDebuff11:SetPoint("LEFT", "FocusFrameDebuff10", "RIGHT", 3, 0)
		end

		-- Move castbar
		--[[local amount = numBuffs + numDebuffs
		if targetofTarget then

		else
			if Focus:GetData("unitIsEnemy") then
				if numBuffs >= 1 then
					FocusFrame.cast:SetPoint("BOTTOMLEFT", FocusFrame, 15, -100)
					return
				end
			end
			
			local y = amount < 7 and -35 or amount < 13 and -70 or amount < 19 and -100
			FocusFrame.cast:SetPoint("BOTTOMLEFT", FocusFrame, 15, y)
		end]]
	end

	function FocusDebuffButton_Update(unit)
		local buff, buffButton;
		local button;
		local numBuffs = 0;

		local buffs = Focus:GetBuffs()
		local debuffs = Focus:GetDebuffs()
		print(table.getn(debuffs))

		for i = 1, 5 do
			local buff = buffs[i]
			button = getglobal("FocusFrameBuff" .. i)
			if buff then
				getglobal("FocusFrameBuff" .. i .. "Icon"):SetTexture(buff.icon)
				button:Show()
				button.id = i
				numBuffs = numBuffs + 1
			else
				button:Hide()
			end
		end

		local debuff, debuffButton, debuffStack, debuffType;
		local debuffCount;
		local numDebuffs = 0;
		local color

		for i = 1, 16 do
			local debuffBorder = getglobal("FocusFrameDebuff" .. i .. "Border");
			debuff = debuffs[i]
	
			button = getglobal("FocusFrameDebuff" .. i)
			if debuff then
				debuffStack = debuff.stacks or 0
				debuffType = debuff.debuffType

				getglobal("FocusFrameDebuff" .. i .. "Icon"):SetTexture(debuff.icon)
				debuffCount = getglobal("FocusFrameDebuff" .. i .. "Count")

				-- TODO add to API
				color = debuffType and FRGB_BORDER_DEBUFFS_COLOR[strlower(debuffType)] or {0, 0, 0, 0}

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

		PositionBuffs(numDebuffs, numBuffs)
	end
end

function FocusFrame_UpdateRaidTargetIcon()
	local index = Focus:GetData("raidIcon")

	if index then
		SetRaidTargetIconTexture(FocusRaidTargetIcon, index)
		FocusRaidTargetIcon:Show()
	else
		FocusRaidTargetIcon:Hide()
	end
end

function FocusFrame_OnShow()
	if UnitIsEnemy("target", "player") then
		PlaySound("igCreatureAggroSelect")
	elseif UnitIsFriend("player", "target") then
		PlaySound("igCharacterNPCSelect")
	else
		PlaySound("igCreatureNeutralSelect")
	end
end

function FocusFrame_OnHide()
	PlaySound("INTERFACESOUND_LOSTTARGETUNIT")
end

function FocusFrame_CheckLevel()
	local targetLevel = Focus:GetData("unitLevel")
	
	if Focus:GetData("unitIsCorpse") then
		FocusLevelText:Hide()
		FocusHighLevelTexture:Show()
	elseif targetLevel > 0 then
		-- Normal level target
		FocusLevelText:SetText(targetLevel)

		-- Color level number
		if Focus:GetData("unitCanAttack") then
			local color = GetDifficultyColor(targetLevel)
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

function FocusFrame_CheckFaction()
	if Focus:GetData("unitPlayerControlled") then
		local r, g, b = Focus:GetReactionColors()

		FocusFrameNameBackground:SetVertexColor(r, g, b)
		FocusPortrait:SetVertexColor(1.0, 1.0, 1.0)
	elseif Focus:GetData("unitIsTapped") and not Focus:GetData("unitIsTappedByPlayer") then
		FocusFrameNameBackground:SetVertexColor(0.5, 0.5, 0.5)
		FocusPortrait:SetVertexColor(0.5, 0.5, 0.5)
	else
		local reaction = Focus:GetData("unitReaction")
		if reaction then
			local r = UnitReactionColor[reaction].r
			local g = UnitReactionColor[reaction].g
			local b = UnitReactionColor[reaction].b

			FocusFrameNameBackground:SetVertexColor(r, g, b)
		else
			FocusFrameNameBackground:SetVertexColor(0, 0, 1.0)
		end

		FocusPortrait:SetVertexColor(1.0, 1.0, 1.0);
	end

	local factionGroup = Focus:GetData("unitFactionGroup")
	if Focus:GetData("unitIsPVPFreeForAll") then
		FocusPVPIcon:SetTexture("Interface\\TargetingFrame\\UI-PVP-FFA")
		FocusPVPIcon:Show()
	elseif factionGroup and Focus:GetData("unitIsPVP") then
		FocusPVPIcon:SetTexture("Interface\\TargetingFrame\\UI-PVP-" .. factionGroup)
		FocusPVPIcon:Show()
	else
		FocusPVPIcon:Hide()
	end
end

function FocusFrame_CheckClassification()
	local classification = Focus:GetData("unitClassification")

	if classification == "worldboss" or classification == "rareelite" or classification == "elite" then
		FocusFrameTexture:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Elite");
	elseif classification == "rare" then
		FocusFrameTexture:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Rare");
	else
		FocusFrameTexture:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame");
	end
end

function FocusFrame_CheckDishonorableKill()
	if Focus:GetData("unitIsCivilian") then
		FocusFrameNameBackground:SetVertexColor(1.0, 1.0, 1.0)
	end
end

function FocusFrame_OnClick(button)
	if SpellIsTargeting() and button == "RightButton" then
		return SpellStopTargeting()
	end

	if button == "LeftButton" then
		if SpellIsTargeting() then
			Focus:Trigger(SpellTargetUnit, "target") -- target=focus here
		elseif CursorHasItem() then
			Focus:Trigger(DropItemOnUnit, "target")
		else
			Focus:TargetFocus()
		end
	end
end

Focus:HookEvent("FOCUS_SET", FocusFrame_Refresh)
Focus:HookEvent("FOCUS_CLEAR", function() FocusFrame:Hide() end)
Focus:HookEvent("UNIT_HEALTH_OR_POWER", FocusFrame_HealthUpdate)
Focus:HookEvent("RAID_TARGET_UPDATE", FocusFrame_UpdateRaidTargetIcon)
Focus:HookEvent("UNIT_AURA", FocusDebuffButton_Update)
Focus:HookEvent("UNIT_LEVEL", FocusFrame_CheckLevel)
Focus:HookEvent("UNIT_FACTION", FocusFrame_CheckFaction)
Focus:HookEvent("UNIT_CLASSIFICATION_CHANGED", FocusFrame_CheckClassification)

--[[ Chat commands ]]
do
	local scantip = getglobal("FocusScantip")
	local scantipTextLeft1 = getglobal("FocusScantipTextLeft1")
	local CastSpellByName = CastSpellByName

	SLASH_FOCUS1 = "/focus"
	SLASH_MFOCUS1 = "/mfocus"
	SLASH_FCAST1 = "/fcast"
	SLASH_FITEM1 = "/fitem"
	SLASH_TARFOCUS1 = "/tarfocus"
	SLASH_CLEARFOCUS1 = "/clearfocus"
	SLASH_FOCUSOPTIONS1 = "/foption"

	SlashCmdList.FOCUS = function() Focus:SetFocus() end
	SlashCmdList.TARFOCUS = function() Focus:TargetFocus() end
	SlashCmdList.CLEARFOCUS = function() Focus:ClearFocus() end

	function SlashCmdList:MFOCUS()
		if UnitExists("mouseover") then
			Focus:SetFocus(UnitName("mouseover"))
		end
	end

	SlashCmdList.FCAST = function(spell)
		Focus:Trigger(CastSpellByName, spell)
	end

	SlashCmdList.FITEM = function(msg)
		if Focus:FocusExists(true) then
			msg = strlower(msg)
		
			for i = 0, 19 do
				scantip:ClearLines()
				scantip:SetInventoryItem("player", i)
				local text = scantipTextLeft1:GetText()
				if text and strlower(text) == msg then
					return Focus:Trigger(UseInventoryItem, i)
				end
			end

			for i = 0, 4 do
				for j = 1, GetContainerNumSlots(i) do
					scantip:ClearLines()
					scantip:SetBagItem(i, j)

					local text = scantipTextLeft1:GetText()
					if text and strlower(text) == msg then
						return Focus:Trigger(UseContainerItem, {i, j})
					end
				end
			end
		end
	end

	SlashCmdList.FOCUSOPTIONS = function(msg)
		local space = string.find(msg or "", " ")
		local cmd = string.sub(msg, 1, space and (space - 1))
		local value = tonumber(string.sub(msg, space or -1))
		local print = function(x) DEFAULT_CHAT_FRAME:AddMessage(x) end
		
		if cmd == "scale" and value then
			local x = value > 0.1 and value <= 2 and value or 1
			FocusFrame:SetScale(x)
			FocusFrameDB.scale = x
			print("Scale set to " .. x)
		elseif cmd == "lock" then
			FocusFrameDB.unlock = not FocusFrameDB.unlock
			print("Frame is now " .. (FocusFrameDB.unlock and "un" or "") .. "locked.")
		elseif cmd == "reset" then
			
		else
			print("Valid commands are:\n/foption scale 1 - Change frame size (0.2 - 2)\n/foption lock - Toggle dragging of frame")
		end
	end
end
