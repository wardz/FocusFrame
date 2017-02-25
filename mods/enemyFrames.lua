if not IsAddOnLoaded("enemyFrames") then return end

local Focus = getglobal("FocusData")

local portraitDebuff = CreateFrame('Frame', 'FocusPortraitDebuff', TargetFrame)
portraitDebuff:SetFrameLevel(0)
portraitDebuff:SetPoint('TOPLEFT', FocusPortrait, 'TOPLEFT', 7, -2)
portraitDebuff:SetPoint('BOTTOMRIGHT', FocusPortrait, 'BOTTOMRIGHT', -5.5, 4)
portraitDebuff:Hide()

-- circle texture
portraitDebuff.bgText = FocusFrame:CreateTexture(nil, 'OVERLAY')
portraitDebuff.bgText:SetPoint('TOPLEFT', FocusPortrait, 'TOPLEFT', 3, -4.5)
portraitDebuff.bgText:SetPoint('BOTTOMRIGHT', FocusPortrait, 'BOTTOMRIGHT', -4, 3)
portraitDebuff.bgText:SetVertexColor(.3, .3, .3)
portraitDebuff.bgText:SetTexture([[Interface\AddOns\enemyFrames\globals\resources\portraitBg.tga]])
-- debuff texture
portraitDebuff.debuffText = FocusFrame:CreateTexture()
portraitDebuff.debuffText:SetPoint('TOPLEFT', FocusPortrait, 'TOPLEFT', 7.5, -8)
portraitDebuff.debuffText:SetPoint('BOTTOMRIGHT', FocusPortrait, 'BOTTOMRIGHT', -7.5, 4.5)	
portraitDebuff.debuffText:SetTexCoord(.12, .88, .12, .88)
-- duration text
local portraitDurationFrame = CreateFrame('Frame', nil, FocusFrame)
portraitDurationFrame:SetAllPoints()
portraitDurationFrame:SetFrameLevel(2)

portraitDebuff.duration = portraitDurationFrame:CreateFontString(nil, 'OVERLAY')--, 'GameFontNormalSmall')
portraitDebuff.duration:SetFont(STANDARD_TEXT_FONT, 14, 'OUTLINE')
portraitDebuff.duration:SetTextColor(.9, .9, .2, 1)
portraitDebuff.duration:SetShadowOffset(1, -1)
portraitDebuff.duration:SetShadowColor(0, 0, 0)
portraitDebuff.duration:SetPoint('CENTER', FocusPortrait, 'CENTER', 0, -7)
-- cooldown spiral
portraitDebuff.cd = CreateCooldown(portraitDebuff, 1.054, true)
portraitDebuff.cd:SetAlpha(1)

local SPELLCASTINGCOREgetPrioBuff, floor, GetTime = SPELLCASTINGCOREgetPrioBuff, floor, GetTime

-------------------------------------------------------------------------------
local function round(num, idp)
    local mult = 10^(idp or 0)
    return floor(num * mult + 0.5) / mult
end
local getTimerLeft = function(tEnd, l)
    local t = tEnd - GetTime()
    if not l then l = 3 end
    if t > l then return round(t, 0) else return round(t, 1) end
end
-------------------------------------------------------------------------------

local a, maxa, b, c = .002, .058, 0, 1
local showPortraitDebuff = function()
    if Focus:FocusExists() then
        local prioBuff = SPELLCASTINGCOREgetPrioBuff(Focus:GetName(), 1)[1]

        if prioBuff ~= nil then
            local d = 1
            if b > maxa then c = -1 end
            if b < 0 then c = 1 end
            b = b + a * c 
            d = -b 
            
            --portraitDebuff.debuffText:SetTexCoord(.12+b, .88+d, .12+d, .88+b)
        
            portraitDebuff.debuffText:SetTexture(prioBuff.icon)
            portraitDebuff.duration:SetText(getTimerLeft(prioBuff.timeEnd))
            portraitDebuff.bgText:Show()
            portraitDebuff.cd:SetTimers(prioBuff.timeStart, prioBuff.timeEnd)
            portraitDebuff.cd:Show()
            portraitDebuff:Show()
            
            local br, bg, bb = prioBuff.border[1], prioBuff.border[2], prioBuff.border[3]
            portraitDebuff.bgText:SetVertexColor(br, bg, bb)
            
        --[[elseif Focus:GetName() == flagCarriers[xtFaction] then
            portraitDebuff.debuffText:SetTexture(SPELLINFO_WSG_FLAGS[xtFaction]['icon'])
            portraitDebuff.bgText:Show()
            portraitDebuff.duration:SetText('')
            portraitDebuff.cd:Hide()
            portraitDebuff.bgText:SetVertexColor(.1, .1, .1)]]
            
        else
            portraitDebuff.cd:Hide()		
            portraitDebuff.debuffText:SetTexture()
            portraitDebuff.duration:SetText('')
            portraitDebuff.bgText:Hide()
            portraitDebuff:Hide()
        end			
    end
end

local ENEMYFRAMESPLAYERDATA = ENEMYFRAMESPLAYERDATA
local nextRefresh, refreshInterval = 0, 0.1
local dummyFrame = CreateFrame'Frame'

dummyFrame:SetScript('OnUpdate', function()
    nextRefresh = nextRefresh - arg1
    if nextRefresh < 0 then

        if ENEMYFRAMESPLAYERDATA.targetPortraitDebuff then
            showPortraitDebuff()
        else
            portraitDebuff.cd:Hide()				
            portraitDebuff.debuffText:SetTexture()
            portraitDebuff.duration:SetText('')
            portraitDebuff.bgText:Hide()
        end

        nextRefresh = refreshInterval			
    end
end)
