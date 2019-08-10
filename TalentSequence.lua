local _, ts = ...

local _G = _G
local GetTalentInfo = GetTalentInfo
local GetTalentTabInfo = GetTalentTabInfo
local SetItemButtonTexture = SetItemButtonTexture
local UnitLevel = UnitLevel
local LearnTalent = LearnTalent
local CreateFrame = CreateFrame
local StaticPopup_Show = StaticPopup_Show
local FauxScrollFrame_SetOffset = FauxScrollFrame_SetOffset
local FauxScrollFrame_GetOffset = FauxScrollFrame_GetOffset
local FauxScrollFrame_OnVerticalScroll = FauxScrollFrame_OnVerticalScroll
local FauxScrollFrame_Update = FauxScrollFrame_Update
local hooksecurefunc = hooksecurefunc
local format = format
local ceil = ceil
local GREEN_FONT_COLOR = GREEN_FONT_COLOR
local NORMAL_FONT_COLOR = NORMAL_FONT_COLOR
local RED_FONT_COLOR = RED_FONT_COLOR
local GRAY_FONT_COLOR = GRAY_FONT_COLOR

local ROW_HEIGHT = 38
local MAX_ROWS = 10
local SCROLLING_WIDTH = 100
local NONSCROLLING_WIDTH = 82
local IMPORT_DIALOG = "TALENTSEQUENCEIMPORTDIALOG"

IsTalentSequenceExpanded = false
TalentSequenceTalents = {}

StaticPopupDialogs[IMPORT_DIALOG] = {
    text = ts.L["IMPORT_DIALOG"],
    hasEditBox = true,
    button1 = ts.L["OK"],
    button2 = ts.L["CANCEL"],
    OnShow = function(self)
        _G[self:GetName() .. "EditBox"]:SetText("")
    end,
    OnAccept = function(self)
        local talentsString = self.editBox:GetText()
        ts.SetTalents(ts.MainFrame, talentsString)
    end,
    EditBoxOnEnterPressed = function(self)
        local talentsString = _G[self:GetParent():GetName() .. "EditBox"]:GetText()
        ts.SetTalents(ts.MainFrame, talentsString)
        self:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3
}

local tooltip = CreateFrame("GameTooltip", "TalentSequenceTooltip", UIParent, "GameTooltipTemplate")
function ts.SetRowTalent(row, talent)
    if (not talent) then
        row:Hide()
        row.talent = nil
        return
    end

    row:Show()
    row.talent = talent
    local name, icon, _, _, currentRank, maxRank = GetTalentInfo(talent.tab, talent.index)

    SetItemButtonTexture(row.icon, icon)
    local tabName = GetTalentTabInfo(talent.tab)
    row.icon.tooltip = format("%s (%d/%d) - %s", name, talent.rank, maxRank, tabName)
    row.icon.rank:SetText(talent.rank)

    if (talent.rank < maxRank) then
        row.icon.rank:SetTextColor(GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b)
    else
        row.icon.rank:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
    end
    if (tooltip:IsOwned(row.icon) and row.icon.tooltip) then
        tooltip:SetText(row.icon.tooltip, nil, nil, nil, nil, true)
    end

    local iconTexture = _G[row.icon:GetName() .. "IconTexture"]
    if (talent.tab ~= TalentFrame.selectedTab) then
        iconTexture:SetVertexColor(1.0, 1.0, 1.0, 0.25)
    else
        iconTexture:SetVertexColor(1.0, 1.0, 1.0, 1.0)
    end

    row.level.label:SetText(talent.level)
    local playerLevel = UnitLevel("player")
    if (talent.level <= playerLevel) then
        row.level.label:SetTextColor(GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b)
    else
        row.level.label:SetTextColor(RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b)
    end

    if (talent.rank <= currentRank) then
        row.level.label:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
        row.icon.rank:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
        iconTexture:SetDesaturated(1)
    else
        iconTexture:SetDesaturated(nil)
    end
end

function ts.FindFirstUnlearnedIndex()
    for index, talent in pairs(ts.Talents) do
        local _, _, _, _, currentRank = GetTalentInfo(talent.tab, talent.index)
        if (talent.rank > currentRank) then
            return index
        end
    end
end

function ts.ScrollFirstUnlearnedTalentIntoView(frame)
    local numTalents = #ts.Talents
    if (numTalents <= MAX_ROWS) then
        return
    end

    local scrollBar = frame.scrollBar

    local nextTalentIndex = ts.FindFirstUnlearnedIndex()
    if (not nextTalentIndex) then
        return
    end
    if (nextTalentIndex == 1) then
        FauxScrollFrame_SetOffset(scrollBar, 0)
        FauxScrollFrame_OnVerticalScroll(scrollBar, 0, ROW_HEIGHT)
        return
    end
    local nextTalentOffset = nextTalentIndex - 1
    if (nextTalentOffset > numTalents - MAX_ROWS) then
        nextTalentOffset = numTalents - MAX_ROWS
    end
    FauxScrollFrame_SetOffset(scrollBar, nextTalentOffset)
    FauxScrollFrame_OnVerticalScroll(scrollBar, ceil(nextTalentOffset * ROW_HEIGHT - 0.5), ROW_HEIGHT)
end

function ts.Update(frame)
    local scrollBar = frame.scrollBar
    local numTalents = #ts.Talents
    FauxScrollFrame_Update(scrollBar, numTalents, MAX_ROWS, ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(scrollBar)
    for i = 1, MAX_ROWS do
        local talentIndex = i + offset
        local talent = ts.Talents[talentIndex]
        local row = frame.rows[i]
        ts.SetRowTalent(row, talent)
    end
    if (numTalents <= MAX_ROWS) then
        frame:SetWidth(NONSCROLLING_WIDTH)
    else
        frame:SetWidth(SCROLLING_WIDTH)
    end
end

function ts.SetTalents(frame, talentsString)
    local talents = ts.BoboTalents.GetTalents(talentsString)
    if (talents == nil) then return end
    ts.Talents = talents
    TalentSequenceTalents = ts.Talents
    if (frame:IsShown()) then
        local scrollBar = frame.scrollBar
        local numTalents = #ts.Talents
        FauxScrollFrame_Update(scrollBar, numTalents, MAX_ROWS, ROW_HEIGHT)
        ts.ScrollFirstUnlearnedTalentIntoView(frame)
        ts.Update(frame)
    end
end

function ts.CreateFrame()
    local mainFrame = CreateFrame("Frame", "TalentOrderFrame", TalentFrame)
    mainFrame:SetPoint("TOPLEFT", "TalentFrame", "TOPRIGHT", -36, -12)
    mainFrame:SetPoint("BOTTOMLEFT", "TalentFrame", "BOTTOMRIGHT", 0, 72)
    mainFrame:SetBackdrop(
        {
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = {left = 4, right = 4, top = 4, bottom = 4}
        }
    )
    mainFrame:SetScript(
        "OnShow",
        function(self)
            ts.ScrollFirstUnlearnedTalentIntoView(self)
        end
    )
    mainFrame:RegisterEvent("CHARACTER_POINTS_CHANGED")
    mainFrame:RegisterEvent("SPELLS_CHANGED")
    mainFrame:SetScript(
        "OnEvent",
        function(self, event)
            if (((event == "CHARACTER_POINTS_CHANGED") or (event == "SPELLS_CHANGED")) and self:IsShown()) then
                ts.ScrollFirstUnlearnedTalentIntoView(self)
                ts.Update(self)
            end
        end
    )
    mainFrame:Hide()

    hooksecurefunc(
        "TalentFrameTab_OnClick",
        function()
            if (mainFrame:IsShown()) then
                ts.Update(mainFrame)
            end
        end
    )

    local scrollBar = CreateFrame("ScrollFrame", "$parentScrollBar", mainFrame, "FauxScrollFrameTemplate")
    scrollBar:SetPoint("TOPLEFT", 0, -8)
    scrollBar:SetPoint("BOTTOMRIGHT", -30, 8)
    scrollBar:SetScript(
        "OnVerticalScroll",
        function(self, offset)
            FauxScrollFrame_OnVerticalScroll(
                self,
                offset,
                ROW_HEIGHT,
                function()
                    ts.Update(mainFrame)
                end
            )
        end
    )
    scrollBar:SetScript(
        "OnShow",
        function()
            ts.Update(mainFrame)
        end
    )
    mainFrame.scrollBar = scrollBar

    local rows = {}
    for i = 1, MAX_ROWS do
        local row = CreateFrame("Frame", "$parentRow" .. i, mainFrame)
        row:SetWidth(110)
        row:SetHeight(ROW_HEIGHT)

        local level = CreateFrame("Frame", "$parentLevel", row)
        level:SetWidth(16)
        level:SetPoint("LEFT", row, "LEFT")
        level:SetPoint("TOP", row, "TOP")
        level:SetPoint("BOTTOM", row, "BOTTOM")

        local levelLabel = level:CreateFontString(nil, "OVERLAY", "GameFontWhite")
        levelLabel:SetPoint("TOPLEFT", level, "TOPLEFT")
        levelLabel:SetPoint("BOTTOMRIGHT", level, "BOTTOMRIGHT")
        level.label = levelLabel

        local icon = CreateFrame("Button", "$parentIcon", row, "ItemButtonTemplate")
        icon:SetWidth(37)
        icon:SetPoint("LEFT", level, "RIGHT", 4, 0)
        icon:SetPoint("TOP", level, "TOP")
        icon:SetPoint("BOTTOM", level, "BOTTOM")
        icon:EnableMouse(true)
        icon:SetScript(
            "OnClick",
            function(self)
                local talent = self:GetParent().talent
                local _, _, _, _, currentRank = GetTalentInfo(talent.tab, talent.index)
                local playerLevel = UnitLevel("player")
                if (currentRank + 1 == talent.rank and playerLevel >= talent.level) then
                    LearnTalent(talent.tab, talent.index)
                end
            end
        )
        icon:SetScript(
            "OnEnter",
            function(self)
                if (not self.tooltip) then
                    return
                end
                tooltip:SetOwner(self, "ANCHOR_RIGHT")
                tooltip:SetText(self.tooltip, nil, nil, nil, nil, true)
                tooltip:Show()
            end
        )
        icon:SetScript(
            "OnLeave",
            function()
                tooltip:Hide()
            end
        )

        local rankBorderTexture = icon:CreateTexture(nil, "OVERLAY")
        rankBorderTexture:SetWidth(32)
        rankBorderTexture:SetHeight(32)
        rankBorderTexture:SetPoint("CENTER", icon, "BOTTOMRIGHT")
        rankBorderTexture:SetTexture("Interface\\TalentFrame\\TalentFrame-RankBorder")
        local rankText = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        rankText:SetPoint("CENTER", rankBorderTexture)
        icon.rank = rankText

        row.icon = icon
        row.level = level

        if (rows[i - 1] == nil) then
            row:SetPoint("TOPLEFT", mainFrame, 8, -8)
        else
            row:SetPoint("TOPLEFT", rows[i - 1], "BOTTOMLEFT", 0, -2)
        end

        rawset(rows, i, row)
    end
    mainFrame.rows = rows

    local importButton = CreateFrame("Button", "$parentImportButton", mainFrame, "UIPanelButtonTemplate")
    importButton:SetPoint("TOP", mainFrame, "BOTTOM", 0, 4)
    importButton:SetPoint("RIGHT", mainFrame)
    importButton:SetPoint("LEFT", mainFrame)
    importButton:SetText(ts.L["IMPORT"])
    importButton:SetHeight(22)
    importButton:SetScript(
        "OnClick",
        function()
            StaticPopup_Show(IMPORT_DIALOG)
        end
    )

    local showButton = CreateFrame("Button", "ShowTalentOrderButton", TalentFrame, "UIPanelButtonTemplate")
    showButton:SetPoint("TOPRIGHT", -62, -18)
    showButton:SetText(">>")
    if (IsTalentSequenceExpanded) then
        showButton:SetText("<<")
        mainFrame:Show()
    end
    showButton.tooltip = ts.L["TOGGLE"]
    showButton:SetScript(
        "OnClick",
        function(self)
            IsTalentSequenceExpanded = not IsTalentSequenceExpanded
            if (IsTalentSequenceExpanded) then
                mainFrame:Show()
                self:SetText("<<")
            else
                mainFrame:Hide()
                self:SetText(">>")
            end
        end
    )
    showButton:SetScript(
        "OnEnter",
        function(self)
            tooltip:SetOwner(self, "ANCHOR_RIGHT")
            tooltip:SetText(self.tooltip, nil, nil, nil, nil, true)
            tooltip:Show()
        end
    )
    showButton:SetScript(
        "OnLeave",
        function()
            tooltip:Hide()
        end
    )
    showButton:SetHeight(14)
    showButton:SetWidth(showButton:GetTextWidth() + 10)

    ts.MainFrame = mainFrame
end

local talentSequenceEventFrame = CreateFrame("Frame")
talentSequenceEventFrame:SetScript(
    "OnEvent",
    function(self, event, ...)
        if (event == "ADDON_LOADED" and ... == "TalentSequence") then
            if (not TalentSequenceTalents) then
                TalentSequenceTalents = {}
            end
            ts.Talents = TalentSequenceTalents
            if (IsTalentSequenceExpanded == 0) then
                IsTalentSequenceExpanded = false
            end
            if (ts.MainFrame == nil) then
                ts.CreateFrame()
            end
            self:UnregisterEvent("ADDON_LOADED")
        end
    end
)
talentSequenceEventFrame:RegisterEvent("ADDON_LOADED")
