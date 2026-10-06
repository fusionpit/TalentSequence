local _, ts = ...

local _G = _G
local GetTalentInfo = GetTalentInfo
local GetTalentTabInfo = GetTalentTabInfo
local SetItemButtonTexture = SetItemButtonTexture
local UnitLevel = UnitLevel
local LearnTalent = LearnTalent
local CreateFrame = CreateFrame
local GetNumTalentTabs = GetNumTalentTabs
local FauxScrollFrame_SetOffset = FauxScrollFrame_SetOffset
local FauxScrollFrame_GetOffset = FauxScrollFrame_GetOffset
local FauxScrollFrame_OnVerticalScroll = FauxScrollFrame_OnVerticalScroll
local FauxScrollFrame_Update = FauxScrollFrame_Update
local format = format
local ceil = ceil
local GetNumTalents = GetNumTalents
local PanelTemplates_GetSelectedTab = PanelTemplates_GetSelectedTab
local GREEN_FONT_COLOR = GREEN_FONT_COLOR
local NORMAL_FONT_COLOR = NORMAL_FONT_COLOR
local RED_FONT_COLOR = RED_FONT_COLOR
local GRAY_FONT_COLOR = GRAY_FONT_COLOR

local TALENT_ROW_HEIGHT = 38
local MAX_TALENT_ROWS = 10
local SCROLLING_WIDTH = 102
local NONSCROLLING_WIDTH = 84
local LEVEL_WIDTH = 20
local RANK_BORDER_DEFAULT_WIDTH = 32
local RANK_BORDER_DEFAULT_HEIGHT = 32
local RANK_BORDER_OVERLAY_WIDTH = 64
local RANK_BORDER_OVERLAY_HEIGHT = 34

local function BuildLiveTalentNameLookup()
    local lookup = {}
    local numTabs = GetNumTalentTabs and GetNumTalentTabs() or 0

    for tabIndex = 1, numTabs do
        local numTalents = GetNumTalents(tabIndex) or 0
        for talentIndex = 1, numTalents do
            local name, icon, _, _, _, maxRank = GetTalentInfo(tabIndex, talentIndex)
            if name then
                if not lookup[name] then
                    lookup[name] = {}
                end
                tinsert(lookup[name], {
                    tab = tabIndex,
                    index = talentIndex,
                    icon = icon,
                    maxRank = maxRank,
                })
            end
        end
    end

    return lookup
end

local function ResolveTalentLocationFromSpellId(talentLookup, spellId, fallbackTalent)
    if not spellId then
        return nil
    end

    local spellName, _, spellIcon = ts.Compat.GetSpellInfo(spellId)
    if not spellName then
        return nil
    end

    local candidates = talentLookup[spellName]
    if not candidates or #candidates == 0 then
        return nil
    end

    if #candidates == 1 then
        return candidates[1]
    end

    if spellIcon then
        for _, candidate in ipairs(candidates) do
            if candidate.icon == spellIcon then
                return candidate
            end
        end
    end

    if fallbackTalent and fallbackTalent.tab and fallbackTalent.index then
        for _, candidate in ipairs(candidates) do
            if candidate.tab == fallbackTalent.tab and candidate.index == fallbackTalent.index then
                return candidate
            end
        end
    end

    return nil
end

local function HydrateTalentsForPlayer(sequence)
    if not sequence or type(sequence.talents) ~= "table" then
        return {}
    end

    if sequence.classToken ~= ts.DB.GetPlayerClassToken() then
        return {}
    end

    local talentLookup = BuildLiveTalentNameLookup()
    local hydrated = {}
    local rankCounter = {}

    for _, talent in ipairs(sequence.talents) do
        local resolved = ResolveTalentLocationFromSpellId(talentLookup, talent.spellId, talent)
        local hydratedTalent

        if resolved then
            local counterKey = tostring(resolved.tab) .. ":" .. tostring(resolved.index)
            rankCounter[counterKey] = (rankCounter[counterKey] or 0) + 1
            hydratedTalent = {
                tab = resolved.tab,
                index = resolved.index,
                rank = talent.rank or rankCounter[counterKey],
                level = talent.level,
                spellId = talent.spellId,
            }
        else
            hydratedTalent = {
                tab = talent.tab,
                index = talent.index,
                rank = talent.rank,
                level = talent.level,
                spellId = talent.spellId,
            }
        end

        tinsert(hydrated, hydratedTalent)
    end

    return hydrated
end

function ts:LoadAssignedSequenceForCurrentSpec()
    local sequence = ts.DB.GetAssignedSequence(ts.DB.GetActiveSpecSlot())
    if (sequence and sequence.classToken == ts.DB.GetPlayerClassToken()) then
        self:SetTalents(HydrateTalentsForPlayer(sequence), sequence.id)
    else
        self:SetTalents({}, nil)
    end
end

function ts:ActivateSequence(sequence)
    if (not sequence or sequence.classToken ~= ts.DB.GetPlayerClassToken()) then return end
    ts.DB.AssignSequenceToSpec(sequence, ts.DB.GetActiveSpecSlot())
    self:SetTalents(HydrateTalentsForPlayer(sequence), sequence.id)
end

local function BuildPlannedRankLookup()
    local planned = {}
    local expected = {}
    local playerLevel = UnitLevel("player")
    for _, talent in ipairs(ts.Talents) do
        if not planned[talent.tab] then
            planned[talent.tab] = {}
            expected[talent.tab] = {}
        end
        local current = planned[talent.tab][talent.index] or 0
        if talent.rank > current then
            planned[talent.tab][talent.index] = talent.rank
        end
        if talent.level <= playerLevel then
            local currentExpected = expected[talent.tab][talent.index] or 0
            if talent.rank > currentExpected then
                expected[talent.tab][talent.index] = talent.rank
            end
        end
    end
    return planned, expected
end

function ts.UpdateTalentButtonOverlays()
    local cfg = ts.FrameConfig
    if not cfg then return end
    local talentFrame = _G[cfg.talentFrameName]
    if not talentFrame or not talentFrame:IsVisible() then return end

    local hasTalents = ts.Talents and #ts.Talents > 0
    local planned, expected
    if hasTalents then
        planned, expected = BuildPlannedRankLookup()
    end

    local selectedTab = PanelTemplates_GetSelectedTab(talentFrame) or 1
    local numTalents = GetNumTalents(selectedTab)
    local buttonPrefix = cfg.talentFrameName .. "Talent"

    for i = 1, numTalents do
        local button = _G[buttonPrefix .. i]
        if button then
            local _, _, _, _, currentRank = GetTalentInfo(selectedTab, i)
            local rankText = _G[button:GetName() .. "Rank"]
            local rankBorder = _G[button:GetName() .. "RankBorder"]
            if rankText then
                local showOverlay = false
                if hasTalents then
                    local plannedRank = (planned[selectedTab] and planned[selectedTab][i]) or 0
                    local expectedRank = (expected[selectedTab] and expected[selectedTab][i]) or 0
                    if plannedRank == 0 and currentRank == 0 then
                        -- Not in plan and no points: leave default
                    elseif currentRank > 0 and plannedRank == 0 then
                        rankText:SetText(format("%d/%d", currentRank, 0))
                        rankText:SetTextColor(RED_FONT_COLOR.r, RED_FONT_COLOR.g,
                                              RED_FONT_COLOR.b)
                        showOverlay = true
                    elseif currentRank == plannedRank then
                        rankText:SetText(format("%d/%d", currentRank, plannedRank))
                        rankText:SetTextColor(1, 0.82, 0)
                        showOverlay = true
                    elseif currentRank > expectedRank then
                        rankText:SetText(format("%d/%d", currentRank, plannedRank))
                        rankText:SetTextColor(RED_FONT_COLOR.r, RED_FONT_COLOR.g,
                                              RED_FONT_COLOR.b)
                        showOverlay = true
                    else
                        rankText:SetText(format("%d/%d", currentRank, plannedRank))
                        if currentRank == 0 then
                            rankText:SetTextColor(GRAY_FONT_COLOR.r,
                                                  GRAY_FONT_COLOR.g,
                                                  GRAY_FONT_COLOR.b)
                        else
                            rankText:SetTextColor(GREEN_FONT_COLOR.r,
                                                  GREEN_FONT_COLOR.g,
                                                  GREEN_FONT_COLOR.b)
                        end
                        showOverlay = true
                    end
                end
                if rankBorder then
                    if showOverlay then
                        rankBorder:SetWidth(RANK_BORDER_OVERLAY_WIDTH)
                        rankBorder:SetHeight(RANK_BORDER_OVERLAY_HEIGHT)
                        rankBorder:Show()
                        rankText:Show()
                        rankText:ClearAllPoints()
                        rankText:SetPoint("CENTER", rankBorder, "CENTER", 0, 1)
                    else
                        rankBorder:SetWidth(RANK_BORDER_DEFAULT_WIDTH)
                        rankBorder:SetHeight(RANK_BORDER_DEFAULT_HEIGHT)
                        rankText:SetText("")
                        rankBorder:Hide()
                        rankText:Hide()
                        rankText:ClearAllPoints()
                        rankText:SetPoint("CENTER", rankBorder, "CENTER", 0, 0)
                    end
                end
            end
        end
    end
end

function ts.FindFirstUnlearnedIndex()
    for index, talent in ipairs(ts.Talents) do
        local _, _, _, _, currentRank = GetTalentInfo(talent.tab, talent.index)
        if (talent.rank > currentRank) then return index end
    end
end

function ts.ScrollFirstUnlearnedTalentIntoView(frame)
    local scrollBar = frame.scrollBar
    local numTalents = #ts.Talents
    local nextTalentIndex = ts.FindFirstUnlearnedIndex()

    if (numTalents <= MAX_TALENT_ROWS or not nextTalentIndex or nextTalentIndex == 1) then
        FauxScrollFrame_SetOffset(scrollBar, 0)
        FauxScrollFrame_OnVerticalScroll(scrollBar, 0, TALENT_ROW_HEIGHT)
        return
    end

    local nextTalentOffset = nextTalentIndex - 1
    if (nextTalentOffset > numTalents - MAX_TALENT_ROWS) then
        nextTalentOffset = numTalents - MAX_TALENT_ROWS
    end
    FauxScrollFrame_SetOffset(scrollBar, nextTalentOffset)
    FauxScrollFrame_OnVerticalScroll(scrollBar, ceil(
                                         nextTalentOffset * TALENT_ROW_HEIGHT -
                                             0.5), TALENT_ROW_HEIGHT)
end

function ts.UpdateTalentFrame(frame)
    local scrollBar = frame.scrollBar
    local numTalents = #ts.Talents
    FauxScrollFrame_Update(scrollBar, numTalents, MAX_TALENT_ROWS,
                           TALENT_ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(scrollBar)
    for i = 1, MAX_TALENT_ROWS do
        local talentIndex = i + offset
        local talent = ts.Talents[talentIndex]
        local row = frame.rows[i]
        row:SetTalent(talent)
    end
    if (numTalents <= MAX_TALENT_ROWS) then
        frame:SetWidth(NONSCROLLING_WIDTH)
    else
        frame:SetWidth(SCROLLING_WIDTH)
    end
end

function ts:SetTalents(talents, sequenceId)
    if (talents == nil) then return end
    ts.Talents = talents
    ts.ActiveSequenceId = sequenceId
    TalentPlannerTalents = ts.Talents
    if (self.MainFrame and self.MainFrame:IsShown()) then
        local scrollBar = self.MainFrame.scrollBar
        local numTalents = #ts.Talents
        FauxScrollFrame_Update(scrollBar, numTalents, MAX_TALENT_ROWS,
                               TALENT_ROW_HEIGHT)
        ts.ScrollFirstUnlearnedTalentIntoView(self.MainFrame)
        ts.UpdateTalentFrame(self.MainFrame)
    end
    if _G.TalentFrame_Update then
        TalentFrame_Update()
    end
end

function ts.CreateMainFrame()
    local cfg = ts.FrameConfig
    local talentFrame = cfg.talentFrameName
    local mainFrame = CreateFrame("Frame", nil, _G[talentFrame], BackdropTemplateMixin and "BackdropTemplate")
    mainFrame:SetSize(128, 128)
    mainFrame:SetPoint(cfg.trackerAnchors[1][1], talentFrame, cfg.trackerAnchors[1][2], cfg.trackerAnchors[1][3], cfg.trackerAnchors[1][4])
    mainFrame:SetPoint(cfg.trackerAnchors[2][1], talentFrame, cfg.trackerAnchors[2][2], cfg.trackerAnchors[2][3], cfg.trackerAnchors[2][4])
    mainFrame:SetBackdrop(cfg.trackerBackdrop)
    mainFrame:SetBackdropColor(0, 0, 0, 1)
    mainFrame:SetScript("OnShow", function(self)
        ts.ScrollFirstUnlearnedTalentIntoView(self)
    end)
    mainFrame:SetScript("OnHide", function(self)
        if (ts.ImportFrame and ts.ImportFrame:IsShown()) then
            ts.ImportFrame:Hide()
        end
    end)
    mainFrame:RegisterEvent("CHARACTER_POINTS_CHANGED")
    mainFrame:RegisterEvent("SPELLS_CHANGED")
    mainFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    mainFrame:SetScript("OnEvent", function(self, event)
        if (event == "ACTIVE_TALENT_GROUP_CHANGED") then
            ts:LoadAssignedSequenceForCurrentSpec()
        elseif (((event == "CHARACTER_POINTS_CHANGED") or
            (event == "SPELLS_CHANGED")) and self:IsVisible()) then
            ts.ScrollFirstUnlearnedTalentIntoView(self)
            ts.UpdateTalentFrame(self)
        end
    end)

    mainFrame:Hide()

    local scrollBar = CreateFrame("ScrollFrame", "$parentScrollBar", mainFrame,
                                  "FauxScrollFrameTemplate")
    scrollBar:SetPoint("TOPLEFT", 0, -8)
    scrollBar:SetPoint("BOTTOMRIGHT", -30, 8)
    scrollBar:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, TALENT_ROW_HEIGHT,
                                         function()
            ts.UpdateTalentFrame(mainFrame)
        end)
    end)
    scrollBar:SetScript("OnShow", function() ts.UpdateTalentFrame(mainFrame) end)
    mainFrame.scrollBar = scrollBar

    local tooltip = ts.tooltip
    ts.Compat.HookSpellTooltip(function(tip)
        if tip ~= tooltip then
            return
        end
        if tip.talentTrainName then
            tip:AddLine(" ")
            tip:AddLine(format(
                "Train |cff71d5ff[%s]|r to |cffffd100(%d/%d)|r",
                tip.talentTrainName, tip.talentTrainRank,
                tip.talentTrainMaxRank), 1, 1, 1)
            tip:Show()
        end
    end, tooltip)
    local rows = {}
    for i = 1, MAX_TALENT_ROWS do
        local row = CreateFrame("Frame", "$parentRow" .. i, mainFrame)
        row:SetWidth(110)
        row:SetHeight(TALENT_ROW_HEIGHT)

        local level = CreateFrame("Frame", "$parentLevel", row)
        level:SetWidth(LEVEL_WIDTH)
        level:SetPoint("LEFT", row, "LEFT")
        level:SetPoint("TOP", row, "TOP")
        level:SetPoint("BOTTOM", row, "BOTTOM")

        local levelLabel = level:CreateFontString(nil, "OVERLAY",
                                                  "GameFontWhite")
        levelLabel:SetPoint("TOPLEFT", level, "TOPLEFT")
        levelLabel:SetPoint("BOTTOMRIGHT", level, "BOTTOMRIGHT")
        level.label = levelLabel

        local icon = CreateFrame("Button", "$parentIcon", row,
                                 "ItemButtonTemplate")
        icon:SetWidth(37)
        icon:SetPoint("LEFT", level, "RIGHT", 4, 0)
        icon:SetPoint("TOP", level, "TOP")
        icon:SetPoint("BOTTOM", level, "BOTTOM")
        icon:EnableMouse(true)
        icon:SetScript("OnClick", function(self)
            local talent = self:GetParent().talent
            local _, _, _, _, currentRank =
                GetTalentInfo(talent.tab, talent.index)
            local playerLevel = UnitLevel("player")
            if (currentRank + 1 == talent.rank and playerLevel >= talent.level) then
                LearnTalent(talent.tab, talent.index)
            end
        end)
        icon:SetScript("OnEnter", function(self)
            tooltip:SetOwner(self, "ANCHOR_RIGHT")
            tooltip.talentTrainName = self.talentName
            tooltip.talentTrainRank = self.talentRank
            tooltip.talentTrainMaxRank = self.talentMaxRank
            if (self.spellId) then
                if not ts.Compat.SetSpellTooltip(tooltip, self.spellId) then
                    tooltip:SetText(self.talentName or "", nil, nil, nil, nil, true)
                    tooltip:Show()
                end
            elseif (self.tooltip) then
                tooltip:SetText(self.tooltip, nil, nil, nil, nil, true)
                if (self.talentName and self.talentRank and self.talentMaxRank) then
                    tooltip:AddLine(" ")
                    tooltip:AddLine(format(
                        "Train |cff71d5ff[%s]|r to |cffffd100(%d/%d)|r",
                        self.talentName, self.talentRank, self.talentMaxRank),
                        1, 1, 1)
                end
                tooltip:Show()
            end
        end)
        icon:SetScript("OnLeave", function()
            tooltip.talentTrainName = nil
            tooltip:Hide()
        end)

        local rankBorderTexture = icon:CreateTexture(nil, "OVERLAY")
        rankBorderTexture:SetWidth(32)
        rankBorderTexture:SetHeight(32)
        rankBorderTexture:SetPoint("CENTER", icon, "BOTTOMRIGHT")
        rankBorderTexture:SetTexture(
            "Interface\\TalentFrame\\TalentFrame-RankBorder")
        local rankText = icon:CreateFontString(nil, "OVERLAY",
                                               "GameFontNormalSmall")
        rankText:SetPoint("CENTER", rankBorderTexture)
        icon.rank = rankText

        row.icon = icon
        row.level = level

        if (rows[i - 1] == nil) then
            row:SetPoint("TOPLEFT", mainFrame, 8, -8)
        else
            row:SetPoint("TOPLEFT", rows[i - 1], "BOTTOMLEFT", 0, -2)
        end

        function row:SetTalent(talent)
            if (not talent) then
                self:Hide()
                self.talent = nil
                self.icon.spellId = nil
                self.icon.tooltip = nil
                self.icon.talentName = nil
                self.icon.talentRank = nil
                self.icon.talentMaxRank = nil
                return
            end

            self:Show()
            self.talent = talent
            local name, icon, _, _, currentRank, maxRank =
                GetTalentInfo(talent.tab, talent.index)

            SetItemButtonTexture(self.icon, icon)
            self.icon.spellId = talent.spellId
            self.icon.talentName = name
            self.icon.talentRank = talent.rank
            self.icon.talentMaxRank = maxRank
            if (talent.spellId) then
                self.icon.tooltip = nil
            else
                local tabName = GetTalentTabInfo(talent.tab)
                self.icon.tooltip = format("%s (%d/%d) - %s", name, talent.rank,
                                           maxRank, tabName)
            end
            self.icon.rank:SetText(talent.rank)

            if (talent.rank < maxRank) then
                self.icon.rank:SetTextColor(GREEN_FONT_COLOR.r,
                                            GREEN_FONT_COLOR.g,
                                            GREEN_FONT_COLOR.b)
            else
                self.icon.rank:SetTextColor(NORMAL_FONT_COLOR.r,
                                            NORMAL_FONT_COLOR.g,
                                            NORMAL_FONT_COLOR.b)
            end
            if (tooltip:IsOwned(self.icon) and self.icon.tooltip) then
                tooltip:SetText(self.icon.tooltip, nil, nil, nil, nil, true)
            end

            local iconTexture = _G[self.icon:GetName() .. "IconTexture"]
            iconTexture:SetVertexColor(1.0, 1.0, 1.0, 1.0)

            self.level.label:SetText(talent.level)
            local playerLevel = UnitLevel("player")
            if (talent.level <= playerLevel) then
                self.level.label:SetTextColor(GREEN_FONT_COLOR.r,
                                              GREEN_FONT_COLOR.g,
                                              GREEN_FONT_COLOR.b)
            else
                self.level.label:SetTextColor(RED_FONT_COLOR.r,
                                              RED_FONT_COLOR.g, RED_FONT_COLOR.b)
            end

            if (talent.rank <= currentRank) then
                self.level.label:SetTextColor(GRAY_FONT_COLOR.r,
                                              GRAY_FONT_COLOR.g,
                                              GRAY_FONT_COLOR.b)
                self.icon.rank:SetTextColor(GRAY_FONT_COLOR.r,
                                            GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
                iconTexture:SetDesaturated(1)
            else
                iconTexture:SetDesaturated(nil)
            end
        end

        rawset(rows, i, row)
    end
    mainFrame.rows = rows

    local loadButton = CreateFrame("Button", "$parentloadButton", mainFrame,
                                   "UIPanelButtonTemplate")
    loadButton:SetPoint("TOP", mainFrame, "BOTTOM", 0, 4)
    loadButton:SetPoint("RIGHT", mainFrame)
    loadButton:SetPoint("LEFT", mainFrame)
    loadButton:SetText(ts.L.MANAGE)
    loadButton:SetHeight(22)
    loadButton:SetScript("OnClick", function()
        if (ts.ImportFrame == nil) then ts.CreateImportFrame() end
        ts.ImportFrame:Show()
        ts.ImportFrame:Raise()
    end)
    local showButton = CreateFrame("Button", "ShowTalentPlannerButton",
                                   _G[talentFrame], "UIPanelButtonTemplate")
    showButton:SetPoint(unpack(cfg.showButtonAnchor))
    if (cfg.showButtonHeight) then
        showButton:SetHeight(cfg.showButtonHeight)
    end
    showButton:SetText("  Talent Planner >>  ")
    if (IsTalentPlannerExpanded) then
        showButton:SetText("  Talent Planner <<  ")
        mainFrame:Show()
    end
    showButton.tooltip = ts.L.TOGGLE
    showButton:SetScript("OnClick", function(self)
        IsTalentPlannerExpanded = not IsTalentPlannerExpanded
        if (IsTalentPlannerExpanded) then
            mainFrame:Show()
            self:SetText("  Talent Planner <<  ")
        else
            mainFrame:Hide()
            self:SetText("  Talent Planner >>  ")
        end
    end)
    showButton:SetScript("OnEnter", function(self)
        tooltip:SetOwner(self, "ANCHOR_RIGHT")
        tooltip:SetText(self.tooltip, nil, nil, nil, nil, true)
        tooltip:Show()
    end)
    showButton:SetScript("OnLeave", function() tooltip:Hide() end)
    showButton:SetWidth(showButton:GetTextWidth() + 10)
    ts.MainFrame = mainFrame

    if _G.TalentFrame_Update then
        hooksecurefunc("TalentFrame_Update", ts.UpdateTalentButtonOverlays)
        ts.UpdateTalentButtonOverlays()
    end
end
