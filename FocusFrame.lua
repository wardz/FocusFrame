CURR_FOCUS_TARGET = nil

print = function(x) DEFAULT_CHAT_FRAME:AddMessage(x) end

local function UnitIsFocus(unitID)
    return UnitName(unitID) == CURR_FOCUS_TARGET
end

local function GetFocusID()
    if UnitExists("target") and UnitIsFocus("target") then
        return "target"
    elseif UnitExists("mouseover") and UnitIsFocus("mouseover") then
        return "mouseover"
    end
end

local function ClearFocus()
    CURR_FOCUS_TARGET = nil
    FocusFrame_DeleteFocusData()
    FocusFrame_Update()
end

local function FocusAction(func, arg1, arg2)
    local oldTarget = UnitName("target")
	local alreadyFocus = UnitIsFocus("target")

	--if not alreadyFocus then
    	TargetByName(CURR_FOCUS_TARGET, true)
	--end
    
	if func then
		-- TODO is there vararg in this lua version?
		func(arg1, arg2)
	end

	if --[[not alreadyFocus and]] oldTarget then
    	--TargetByName(oldTarget, true)
		--TargetUnit("playertarget")
		TargetLastTarget()
	else
		ClearTarget()
	end
end

local function SetFocus(name)
    CURR_FOCUS_TARGET = name

    if name then
		FocusAction() -- Target focus once to update info
        FocusFrame_Update() -- TODO needed?
	else
        ClearFocus()
    end
end

-- Chat Commands

SLASH_FOCUS1 = "/focus"
SlashCmdList["FOCUS"] = function(name)
	if not name or name == "" then
        name = UnitName("target")
    end

    SetFocus(name)
end

SLASH_MFOCUS1 = "/mfocus"
SlashCmdList["MFOCUS"] = function()
    if UnitExists("mouseover") then
        SetFocus(UnitName("mouseover"))
    end
end

SLASH_FCAST1 = "/fcast"
SlashCmdList["FCAST"] = function(spell)
	if CURR_FOCUS_TARGET then
		FocusAction(CastSpellByName, spell)
	else
		UIErrorsFrame:AddMessage("|cffFF003F You have no focus.|r")
	end
end

SLASH_FITEM1 = "/fitem"
SlashCmdList["FITEM"] = function(msg)
	if CURR_FOCUS_TARGET then
		local scantip = getglobal("FocusScantip")
		local scantipTextLeft1 = getglobal("FocusScantipTextLeft1")
		msg = strlower(msg)
	
		for i = 0, 19 do
			scantip:ClearLines()
			scantip:SetInventoryItem("player", i)
			local text = scantipTextLeft1:GetText()
			if text and strlower(text) == msg then
				return FocusAction(UseInventoryItem, i)
			end
		end

		for i = 0, 4 do
			for j = 1, GetContainerNumSlots(i) do
				scantip:ClearLines()
				scantip:SetBagItem(i, j)

				local text = scantipTextLeft1:GetText()
				if text and strlower(text) == msg then
					return FocusAction(UseContainerItem, i, j)
				end
			end
		end
	else
		UIErrorsFrame:AddMessage("|cffFF003F You have no focus.|r")
	end
end

SLASH_TARFOCUS1 = "/tarfocus"
SlashCmdList["TARFOCUS"] = function()
	if CURR_FOCUS_TARGET then
		TargetByName(CURR_FOCUS_TARGET, true)
	else
		UIErrorsFrame:AddMessage("|cffFF003F You have no focus.|r")
	end
end

SLASH_CLEARFOCUS1 = "/clearfocus"
SlashCmdList["CLEARFOCUS"] = ClearFocus

-- Modified Blizzard targetframe
-- https://github.com/tekkub/wow-ui-source/blob/1.12.1/FrameXML/TargetFrame.lua
function FocusFrame_OnLoad()
	FocusFrame_Update()

	this:RegisterEvent("PLAYER_ENTERING_WORLD")
	this:RegisterEvent("UNIT_HEALTH")
	this:RegisterEvent("UNIT_LEVEL")
	this:RegisterEvent("UNIT_FACTION")
	this:RegisterEvent("UNIT_CLASSIFICATION_CHANGED")
	this:RegisterEvent("UNIT_AURA")
	this:RegisterEvent("PLAYER_FLAGS_CHANGED")

	this:RegisterEvent("UNIT_MANA")
	this:RegisterEvent("UNIT_RAGE")
	this:RegisterEvent("UNIT_FOCUS")
	this:RegisterEvent("UNIT_ENERGY")
	--this:RegisterEvent("UNIT_DISPLAYPOWER")
	this:RegisterEvent("UNIT_PORTRAIT_UPDATE")

	--this:RegisterEvent("PARTY_MEMBERS_CHANGED")
	--this:RegisterEvent("RAID_TARGET_UPDATE")
end

function FocusFrame_Update()
	if not CURR_FOCUS_TARGET then
		return FocusFrame:Hide()
	end

	local unit = GetFocusID()
    if unit then
        FocusName:SetText(GetUnitName(unit))
        SetPortraitTexture(FocusPortrait, unit)
		FocusPortrait:SetAlpha(1.0)

        if UnitIsPartyLeader(unit) then
            FocusLeaderIcon:Show()
        else
            FocusLeaderIcon:Hide()
        end

        FocusFrame_CheckLevel(unit)
        FocusFrame_CheckFaction(unit)
        FocusFrame_CheckClassification(unit)
        FocusFrame_CheckDead(unit)
        FocusFrame_CheckDishonorableKill(unit)

		FocusFrame_SetFocusInfo(unit)
        FocusDebuffButton_Update(unit)
		FocusFrame_HealthUpdate(unit)

		FocusFrame:Show()
	end
end

do
	local refresh, interval = 0, 0.2
	function FocusFrame_OnUpdate(elapsed)
		refresh = refresh - elapsed
		if refresh < 0 then
			if CURR_FOCUS_TARGET then
				if GetFocusID() then
					FocusFrame_Update()
				else
					FocusDebuffButton_Update()
					FocusFrame_HealthUpdate()
					FocusFrame_CheckDead()
				end
			else
				FocusFrame:Hide()
			end

			refresh = interval
		end
	end
end


function FocusFrame_HealthUpdate(unit)
	if unit then
		-- sync values
		FocusFrame_SetFocusInfo(unit)
	end

	local data = FocusFrame_GetFocusData(CURR_FOCUS_TARGET)

	FocusFrameHealthBar:SetMinMaxValues(0, data.maxHealth or 100)
	FocusFrameHealthBar:SetValue(data.health or 100)
	FocusFrameManaBar:SetMinMaxValues(0, data.maxMana or 100)
	FocusFrameManaBar:SetValue(data.mana or 0)

	local info = ManaBarColor[data.power]
	if info then
		FocusFrameManaBar:SetStatusBarColor(info.r, info.g, info.b)
	end
end

do
	local MAX_FOCUS_DEBUFFS = 16;
	local MAX_FOCUS_BUFFS = 5;

	local GetAllBuffs = FSPELLCASTINGCOREgetBuffs

	local scantip = getglobal("FocusScantip")
	local scantipTextLeft1 = getglobal("FocusScantipTextLeft1")
	local scantipTextRight1 = getglobal("FocusScantipTextRight1")

	local function StoreBuff(unit, i, texture, debuff)
		scantip:ClearLines()
		if debuff then
			scantip:SetUnitDebuff(unit, i)
		else
			scantip:SetUnitBuff(unit, i)
		end

		local text = scantipTextLeft1:GetText()
		local magicType = scantipTextRight1:GetText()
		if text then
			-- sync buffs
			FocusFrame_NewBuff(CURR_FOCUS_TARGET, text, texture, debuff, magicType)
		end
	end

	function FocusDebuffButton_Update(unit)
		local buff, buffButton;
		local button;
		local numBuffs = 0;
		local data, buffList, debuffList

		if not unit then
			local buffs = GetAllBuffs(CURR_FOCUS_TARGET)
			data = FocusFrame_GetFocusData(CURR_FOCUS_TARGET)
			buffList = buffs["buffs"]
			debuffList = buffs["debuffs"]
		end

		if (unit and UnitHealth(unit) <= 0) or data and data.health <= 0 then
			--for i = 1, MAX_FOCUS_BUFFS do getglobal("FocusFrameBuff"..i):Hide() end
			--for i = 1, MAX_FOCUS_DEBUFFS do getglobal("FocusFrameDebuff"..i):Hide() end
			FocusFrame_ClearBuffs(CURR_FOCUS_TARGET)
			--return
		end

		for i=1, MAX_FOCUS_BUFFS do
			if unit then
				buff = UnitBuff(unit, i);
				if buff then
					StoreBuff(unit, i, buff)
				end
			else
				buff = buffList[i]
			end

			button = getglobal("FocusFrameBuff"..i);
			if ( buff ) then
				getglobal("FocusFrameBuff"..i.."Icon"):SetTexture(type(buff) == "table" and buff.icon or buff);
				button:Show();
				button.id = i;
				numBuffs = numBuffs + 1; 
			else
				button:Hide();
			end
		end

		local debuff, debuffButton, debuffStack, debuffType, color;
		local debuffCount;
		local numDebuffs = 0;
		for i=1, MAX_FOCUS_DEBUFFS do

			local debuffBorder = getglobal("FocusFrameDebuff"..i.."Border");

			if unit then
				debuff, debuffStack, debuffType = UnitDebuff(unit, i);
				if debuff then
					StoreBuff(unit, i, debuff, true)
				end
			else
				debuff = debuffList[i]
				debuffStack = debuff and debuff.stacks or 0
				debuffType = debuff and debuff.debuffType or nil
				--debuffType = nil
			end

			button = getglobal("FocusFrameDebuff"..i);
			if ( debuff ) then
				getglobal("FocusFrameDebuff"..i.."Icon"):SetTexture(type(debuff) == "table" and debuff.icon or debuff);
				debuffCount = getglobal("FocusFrameDebuff"..i.."Count");
				if ( debuffType ) then
					color = RGB_BORDER_DEBUFFS_COLOR[debuffType] or RGB_BORDER_DEBUFFS_COLOR["none"];
				else
					color = RGB_BORDER_DEBUFFS_COLOR["none"];
				end
				if ( debuffStack and debuffStack > 1 ) then
					debuffCount:SetText(debuffStack);
					debuffCount:Show();
				else
					debuffCount:Hide();
				end
				debuffBorder:SetVertexColor(color[0], color[1], color[2], color[4]);
				button:Show();
				numDebuffs = numDebuffs + 1;
			else
				button:Hide();
			end
			button.id = i;
		end

		local debuffFrame, debuffWrap, debuffSize, debuffFrameSize;
		local targetofTarget = false --TargetofTargetFrame:IsShown();

		if ( data and data["enemy"] or unit and UnitIsFriend("player", unit) ) then
			FocusFrameBuff1:SetPoint("TOPLEFT", "FocusFrame", "BOTTOMLEFT", 5, 32);
			FocusFrameDebuff1:SetPoint("TOPLEFT", "FocusFrameBuff1", "BOTTOMLEFT", 0, -2);
		else
			FocusFrameDebuff1:SetPoint("TOPLEFT", "FocusFrame", "BOTTOMLEFT", 5, 32);
			if ( targetofTarget ) then
				if ( numDebuffs < 5 ) then
					FocusFrameBuff1:SetPoint("TOPLEFT", "FocusFrameDebuff6", "BOTTOMLEFT", 0, -2);
				elseif ( numDebuffs >= 5 and numDebuffs < 10  ) then
					FocusFrameBuff1:SetPoint("TOPLEFT", "FocusFrameDebuff6", "BOTTOMLEFT", 0, -2);
				elseif (  numDebuffs >= 10 ) then
					FocusFrameBuff1:SetPoint("TOPLEFT", "FocusFrameDebuff11", "BOTTOMLEFT", 0, -2);
				end
			else
				FocusFrameBuff1:SetPoint("TOPLEFT", "FocusFrameDebuff7", "BOTTOMLEFT", 0, -2);
			end
		end
		
		-- set the wrap point for the rows of de/buffs.
		if ( targetofTarget ) then
			debuffWrap = 5;
		else
			debuffWrap = 6;
		end

		-- and shrinks the debuffs if they begin to overlap the TargetFrame
		if ( ( targetofTarget and ( numBuffs == 5 ) ) or ( numDebuffs >= debuffWrap ) ) then
			debuffSize = 17;
			debuffFrameSize = 19;
		else
			debuffSize = 21;
			debuffFrameSize = 23;
		end
		
		-- resize Buffs
		for i=1, 5 do
			button = getglobal("FocusFrameBuff"..i);
			if ( button ) then
				button:SetWidth(debuffSize);
				button:SetHeight(debuffSize);
			end
		end

		-- resize Debuffs
		for i=1, 6 do
			button = getglobal("FocusFrameDebuff"..i);
			debuffFrame = getglobal("FocusFrameDebuff"..i.."Border");
			if ( debuffFrame ) then
				debuffFrame:SetWidth(debuffFrameSize);
				debuffFrame:SetHeight(debuffFrameSize);
			end
			button:SetWidth(debuffSize);
			button:SetHeight(debuffSize);
		end

		-- Reset anchors for debuff wrapping
		getglobal("FocusFrameDebuff"..debuffWrap):ClearAllPoints();
		getglobal("FocusFrameDebuff"..debuffWrap):SetPoint("LEFT", getglobal("FocusFrameDebuff"..(debuffWrap - 1)), "RIGHT", 3, 0);
		getglobal("FocusFrameDebuff"..(debuffWrap + 1)):ClearAllPoints();
		getglobal("FocusFrameDebuff"..(debuffWrap + 1)):SetPoint("TOPLEFT", "FocusFrameDebuff1", "BOTTOMLEFT", 0, -2);
		getglobal("FocusFrameDebuff"..(debuffWrap + 2)):ClearAllPoints();
		getglobal("FocusFrameDebuff"..(debuffWrap + 2)):SetPoint("LEFT", getglobal("FocusFrameDebuff"..(debuffWrap + 1)), "RIGHT", 3, 0);

		-- Set anchor for the last row if debuffWrap is 5
		if ( debuffWrap == 5 ) then
			FocusFrameDebuff11:ClearAllPoints();
			FocusFrameDebuff11:SetPoint("TOPLEFT", "FocusFrameDebuff6", "BOTTOMLEFT", 0, -2);
		else
			FocusFrameDebuff11:ClearAllPoints();
			FocusFrameDebuff11:SetPoint("LEFT", "FocusFrameDebuff10", "RIGHT", 3, 0);
		end
	end
end

function FocusFrame_OnEvent(event)
	if ( event == "PLAYER_ENTERING_WORLD"  and ( not FocusFrame:IsVisible() ) ) then
		FocusFrame_Update();
	elseif ( event == "PLAYER_TARGET_CHANGED" or event == "UNIT_PORTRAIT_UPDATE") then
		FocusFrame_Update();
	elseif ( event == "UNIT_HEALTH" or event == "UNIT_MANA" or event == "UNIT_RAGE" or event == "UNIT_FOCUS" or event == "UNIT_ENERGY" ) then
        if UnitIsFocus(arg1) then
			FocusFrame_CheckDead(arg1);
			FocusFrame_HealthUpdate(arg1)
		end
	elseif ( event == "UNIT_LEVEL" ) then
		if UnitIsFocus(arg1) then
			FocusFrame_CheckLevel(arg1);
		end
	elseif ( event == "UNIT_FACTION" ) then
		if UnitIsFocus(arg1) then
			FocusFrame_CheckFaction(arg1);
			FocusFrame_CheckLevel(arg1);
		end
	elseif ( event == "UNIT_CLASSIFICATION_CHANGED" ) then
		if UnitIsFocus(arg1) then
			FocusFrame_CheckClassification(arg1);
		end
	elseif ( event == "UNIT_AURA" ) then
		if UnitIsFocus(arg1) then
			FocusDebuffButton_Update(arg1);
		end
	elseif ( event == "PLAYER_FLAGS_CHANGED" ) then
		if ( UnitIsFocus(arg1) ) then
			if ( UnitIsPartyLeader(arg1) ) then
				FocusLeaderIcon:Show();
			else
				FocusLeaderIcon:Hide();
			end
		end
	elseif ( event == "PARTY_MEMBERS_CHANGED" ) then
		--FocusFrame_CheckFaction();
	elseif ( event == "RAID_TARGET_UPDATE" ) then
		--FocusFrame_UpdateRaidTargetIcon();
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
	PlaySound("INTERFACESOUND_LOSTTARGETUNIT");
end

function FocusFrame_CheckLevel(unit)
	local targetLevel = UnitLevel(unit);
	
	if ( UnitIsCorpse(unit) ) then
		FocusLevelText:Hide();
		FocusHighLevelTexture:Show();
	elseif ( targetLevel > 0 ) then
		-- Normal level target
		FocusLevelText:SetText(targetLevel);
		-- Color level number
		if ( UnitCanAttack("player", unit) ) then
			local color = GetDifficultyColor(targetLevel);
			FocusLevelText:SetVertexColor(color.r, color.g, color.b);
		else
			FocusLevelText:SetVertexColor(1.0, 0.82, 0.0);
		end
		FocusLevelText:Show();
		FocusHighLevelTexture:Hide();
	else
		-- Target is too high level to tell
		FocusLevelText:Hide();
		FocusHighLevelTexture:Show();
	end
end

function FocusFrame_CheckFaction(unit)
	if ( UnitPlayerControlled(unit) ) then
		local r, g, b;
		if ( UnitCanAttack(unit, "player") ) then
			-- Hostile players are red
			if ( not UnitCanAttack("player", unit) ) then
				r = 0.0;
				g = 0.0;
				b = 1.0;
			else
				r = UnitReactionColor[2].r;
				g = UnitReactionColor[2].g;
				b = UnitReactionColor[2].b;
			end
		elseif ( UnitCanAttack("player", unit) ) then
			-- Players we can attack but which are not hostile are yellow
			r = UnitReactionColor[4].r;
			g = UnitReactionColor[4].g;
			b = UnitReactionColor[4].b;
		elseif ( UnitIsPVP(unit) ) then
			-- Players we can assist but are PvP flagged are green
			r = UnitReactionColor[6].r;
			g = UnitReactionColor[6].g;
			b = UnitReactionColor[6].b;
		else
			-- All other players are blue (the usual state on the "blue" server)
			r = 0.0;
			g = 0.0;
			b = 1.0;
		end
		FocusFrameNameBackground:SetVertexColor(r, g, b);
		FocusPortrait:SetVertexColor(1.0, 1.0, 1.0);
	elseif ( UnitIsTapped(unit) and not UnitIsTappedByPlayer(unit) ) then
		FocusFrameNameBackground:SetVertexColor(0.5, 0.5, 0.5);
		FocusPortrait:SetVertexColor(0.5, 0.5, 0.5);
	else
		local reaction = UnitReaction(unit, "player");
		if ( reaction ) then
			local r, g, b;
			r = UnitReactionColor[reaction].r;
			g = UnitReactionColor[reaction].g;
			b = UnitReactionColor[reaction].b;
			FocusFrameNameBackground:SetVertexColor(r, g, b);
		else
			FocusFrameNameBackground:SetVertexColor(0, 0, 1.0);
		end
		FocusPortrait:SetVertexColor(1.0, 1.0, 1.0);
	end

	local factionGroup = UnitFactionGroup(unit);
	if ( UnitIsPVPFreeForAll(unit) ) then
		FocusPVPIcon:SetTexture("Interface\\TargetingFrame\\UI-PVP-FFA");
		FocusPVPIcon:Show();
	elseif ( factionGroup and UnitIsPVP(unit) ) then
		FocusPVPIcon:SetTexture("Interface\\TargetingFrame\\UI-PVP-"..factionGroup);
		FocusPVPIcon:Show();
	else
		FocusPVPIcon:Hide();
	end
end

function FocusFrame_CheckClassification(unit)
	local classification = UnitClassification(unit)

	if classification == "worldboss" or classification == "rareelite" or classification == "elite" then
		FocusFrameTexture:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Elite");
	elseif classification == "rare" then
		FocusFrameTexture:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Rare");
	else
		FocusFrameTexture:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame");
	end
end

function FocusFrame_CheckDead(unit)
	if unit then
		if (UnitHealth(unit) <= 0) and UnitIsConnected(unit) then
			FocusDeadText:Show()
		else
			FocusDeadText:Hide()
		end
	else
		local data = FocusFrame_GetFocusData(CURR_FOCUS_TARGET)
		if data and data.health <= 0 then
			FocusDeadText:Show()
		else
			FocusDeadText:Hide()
		end
	end
end

function FocusFrame_CheckDishonorableKill(unit)
	if UnitIsCivilian(unit) then
		FocusFrameNameBackground:SetVertexColor(1.0, 1.0, 1.0)
	end
end

function FocusFrame_OnClick(button)
	if SpellIsTargeting() and button == "RightButton" then
		return SpellStopTargeting()
	end

	if button == "LeftButton" then
		if SpellIsTargeting() then
            FocusAction(SpellTargetUnit, "target")
		elseif CursorHasItem() then
            FocusAction(DropItemOnUnit, "target")
		else
            TargetByName(CURR_FOCUS_TARGET, true)
        end
	end
end
