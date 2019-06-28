local ROW_HEIGHT = 38
local MAX_ROWS = 10 
local SCROLLING_WIDTH = 100;
local NONSCROLLING_WIDTH = 82;
local IMPORT_DIALOG = "TALENTSEQUENCEIMPORTDIALOG";
local L = TalentSequenceText;

IsTalentSequenceExpanded = false;
TalentSequenceTalents = {};

StaticPopupDialogs[IMPORT_DIALOG] = {
    text = L["IMPORT_DIALOG"],
    hasEditBox = true,
    button1 = L["OK"],
    button2 = L["CANCEL"],
    OnShow = function(self)
        _G[self:GetName().."EditBox"]:SetText("");
    end,
    OnAccept = function(self)
        local talentsString = self.editBox:GetText();
        TalentSequence_SetTalents(TalentOrderFrame, talentsString);
    end,
    EditBoxOnEnterPressed = function(self)
        local talentsString = _G[self:GetParent():GetName().."EditBox"]:GetText();
        TalentSequence_SetTalents(TalentOrderFrame, talentsString);
        self:GetParent():Hide();
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide();
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3
}

function TalentSequence_SetRowTalent(row, talent)
    if (not talent) then
        row:Hide();
        return;
    else
        row:Show();
        row.talent = talent;
    end
    local name, icon, _, _, currentRank, maxRank = GetTalentInfo(talent.tab, talent.index);
    
    SetItemButtonTexture(row.icon, icon);
    local tabName = GetTalentTabInfo(talent.tab);
    row.icon.tooltip = name..string.format(" (%d/%d) - %s", talent.rank, maxRank, tabName);
    row.icon.rank:SetText(talent.rank);
    
    if (talent.rank < maxRank) then
        row.icon.rank:SetTextColor(GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b);
    else
        row.icon.rank:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
    end
    if (GameTooltip:IsOwned(row.icon) and row.icon.tooltip) then
        GameTooltip:SetText(row.icon.tooltip, nil, nil, nil, nil, true);
    end

    local iconTexture = _G[row.icon:GetName().."IconTexture"];
    if (talent.tab ~= TalentFrame.selectedTab) then
        iconTexture:SetVertexColor(1.0, 1.0, 1.0, 0.25);
    else
        iconTexture:SetVertexColor(1.0, 1.0, 1.0, 1.0);
    end

    row.level.label:SetText(talent.level);
    local playerLevel = UnitLevel("player");
    if (talent.level <= playerLevel) then
        row.level.label:SetTextColor(GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b);
    else
        row.level.label:SetTextColor(RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b);
    end

    if (talent.rank <= currentRank) then
        row.level.label:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b);
        row.icon.rank:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b);
        iconTexture:SetDesaturated(1);
    else
        iconTexture:SetDesaturated(nil);
    end
end

function TalentSequence_FindFirstUnlearnedIndex()
    for index, talent in pairs(TalentSequenceTalents) do
        local _, _, _, _, currentRank = GetTalentInfo(talent.tab, talent.index);
        if (talent.rank > currentRank) then
            return index;
        end
    end
end

function TalentSequence_ScrollFirstUnlearnedTalentIntoView(frame)
    local numTalents = #TalentSequenceTalents;
    if (numTalents <= MAX_ROWS) then
        return;
    end

    local scrollBar = frame.scrollBar;
    local bar = _G[scrollBar:GetName().."ScrollBar"];

    local nextTalentIndex = TalentSequence_FindFirstUnlearnedIndex();
    if (not nextTalentIndex) then
        return;
    end
    if (nextTalentIndex == 1) then
        FauxScrollFrame_SetOffset(scrollBar, 0);
        FauxScrollFrame_OnVerticalScroll(scrollBar, 0, ROW_HEIGHT);
        return;
    end
    local nextTalentOffset = nextTalentIndex - 1;
    if (nextTalentOffset > numTalents-MAX_ROWS) then
        nextTalentOffset = numTalents-MAX_ROWS;
    end
    FauxScrollFrame_SetOffset(scrollBar, nextTalentOffset);
    FauxScrollFrame_OnVerticalScroll(scrollBar, ceil(nextTalentOffset*ROW_HEIGHT-0.5), ROW_HEIGHT);
end

function TalentSequence_Update(frame)
    local scrollBar = frame.scrollBar;
    local numTalents = #TalentSequenceTalents;
    FauxScrollFrame_Update(scrollBar, numTalents, MAX_ROWS, ROW_HEIGHT);
    local offset = FauxScrollFrame_GetOffset(scrollBar);
    for i = 1, MAX_ROWS do
        local talentIndex = i+offset;
        local talent = TalentSequenceTalents[talentIndex];
        local row = _G[frame:GetName().."Row"..i];
        TalentSequence_SetRowTalent(row, talent);
    end
    if (numTalents <= MAX_ROWS) then
        frame:SetWidth(NONSCROLLING_WIDTH);
    else
        frame:SetWidth(SCROLLING_WIDTH);
    end
end

function TalentSequence_SetTalents(frame, talentsString)
    TalentSequenceTalents = BoboTalents.GetTalents(talentsString);
    if (frame:IsShown()) then
        TalentSequence_ScrollFirstUnlearnedTalentIntoView(frame);
        TalentSequence_Update(frame);
    end
end

function TalentSequence_CreateFrame()
    local mainFrame = CreateFrame("Frame", "TalentOrderFrame", TalentFrame);
    mainFrame:SetPoint("TOPLEFT", "TalentFrame", "TOPRIGHT", -36, -12);
    mainFrame:SetPoint("BOTTOMLEFT", "TalentFrame", "BOTTOMRIGHT", 0, 72);
    mainFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    });
    mainFrame:SetScript("OnShow", function(self)
        TalentSequence_ScrollFirstUnlearnedTalentIntoView(self);
    end);
    mainFrame:RegisterEvent("CHARACTER_POINTS_CHANGED");
    mainFrame:RegisterEvent("SPELLS_CHANGED");
    mainFrame:SetScript("OnEvent", function(self, event, ...)
        if (((event == "CHARACTER_POINTS_CHANGED") or (event == "SPELLS_CHANGED")) and self:IsShown()) then
            TalentSequence_ScrollFirstUnlearnedTalentIntoView(self);
            TalentSequence_Update(self);
        end
    end)
    mainFrame:Hide();

    hooksecurefunc("TalentFrameTab_OnClick", function()
        if (mainFrame:IsShown()) then
            TalentSequence_Update(mainFrame);
        end
    end);
    
    local scrollBar = CreateFrame("ScrollFrame", "$parentScrollBar", mainFrame, "FauxScrollFrameTemplate");
    scrollBar:SetPoint("TOPLEFT", 0, -8);
    scrollBar:SetPoint("BOTTOMRIGHT", -30, 8);
    scrollBar:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, function()
            TalentSequence_Update(mainFrame);
        end);
    end);
    scrollBar:SetScript("OnShow", function() 
        TalentSequence_Update(mainFrame);
    end);
    mainFrame.scrollBar = scrollBar;

    local rows = {};
    local lastRow = nil;
    for i = 1, MAX_ROWS do
        local row = CreateFrame("Frame", "$parentRow"..i, mainFrame);
        row:SetWidth(110);
        row:SetHeight(ROW_HEIGHT);

        local level = CreateFrame("Frame", "$parentLevel", row);
        level:SetWidth(16);
        level:SetPoint("LEFT", "TalentOrderFrameRow"..i, "LEFT");
        level:SetPoint("TOP", "TalentOrderFrameRow"..i, "TOP");
        level:SetPoint("BOTTOM", "TalentOrderFrameRow"..i, "BOTTOM");

        local levelLabel = level:CreateFontString(nil, "OVERLAY", "GameFontWhite");
        levelLabel:SetPoint("TOPLEFT", level:GetName(), "TOPLEFT");
        levelLabel:SetPoint("BOTTOMRIGHT", level:GetName(), "BOTTOMRIGHT");
        level.label = levelLabel;

        local icon = CreateFrame("Button", "$parentIcon", row, "ItemButtonTemplate");
        icon:SetWidth(37);
        icon:SetPoint("LEFT", level:GetName(), "RIGHT", 4, 0);
        icon:SetPoint("TOP", level:GetName(), "TOP");
        icon:SetPoint("BOTTOM", level:GetName(), "BOTTOM");
        icon:EnableMouse(true);
        icon:SetScript("OnClick", function(self)
            local talent = self:GetParent().talent;
            local _, _, _, _, currentRank = GetTalentInfo(talent.tab, talent.index);
            local playerLevel = UnitLevel("player");
            if (currentRank + 1 == talent.rank and playerLevel >= talent.level) then
                LearnTalent(talent.tab, talent.index);
            end
        end);
        icon:SetScript("OnEnter", function(self)
            if (not self.tooltip) then 
                return;
            end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 0, -ROW_HEIGHT);
            GameTooltip:SetText(self.tooltip, nil, nil, nil, nil, true);
            GameTooltip:Show();
        end);
        icon:SetScript("OnLeave", function()
            GameTooltip:Hide();
        end);

        local rankBorderTexture = icon:CreateTexture(nil, "OVERLAY");
        rankBorderTexture:SetWidth(32);
        rankBorderTexture:SetHeight(32);
        rankBorderTexture:SetPoint("CENTER", icon, "BOTTOMRIGHT");
        rankBorderTexture:SetTexture("Interface\\TalentFrame\\TalentFrame-RankBorder");
        local rankText = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
        rankText:SetPoint("CENTER", rankBorderTexture, "CENTER", -1, 0);
        icon.rank = rankText;

        row.icon = icon;
        row.level = level;

        if (lastRow == nil) then
            row:SetPoint("TOPLEFT", mainFrame, 8, -8);
        else
            row:SetPoint("TOPLEFT", rows[i-1], "BOTTOMLEFT", 0, -2);
        end
        lastRow = row;

        rawset(rows, i, row);
    end

    local importButton = CreateFrame("Button", "$parentImportButton", TalentOrderFrame, "UIPanelButtonTemplate");
    importButton:SetPoint("TOP", "TalentOrderFrame", "BOTTOM", 0, 4);
    importButton:SetPoint("RIGHT", "TalentOrderFrame");
    importButton:SetPoint("LEFT", "TalentOrderFrame");
    importButton:SetText(L["IMPORT"]);
    importButton:SetHeight(22);
    importButton:SetScript("OnClick", function()
        StaticPopup_Show(IMPORT_DIALOG);
    end)

    local showButton = CreateFrame("Button", "ShowTalentOrderButton", TalentFrame, "UIPanelButtonTemplate");
    showButton:SetPoint("TOPRIGHT", -62, -18);
    showButton:SetText(">>");
    if (IsTalentSequenceExpanded) then
        showButton:SetText("<<");
        mainFrame:Show();
    end
    showButton.tooltip = L["TOGGLE"];
    showButton:SetScript("OnClick", function(self)
        IsTalentSequenceExpanded = not IsTalentSequenceExpanded;
        if (IsTalentSequenceExpanded) then
            mainFrame:Show();
            self:SetText("<<");
        else
            mainFrame:Hide();
            self:SetText(">>");
        end
    end);
    showButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
        GameTooltip:SetText(self.tooltip, nil, nil, nil, nil, true);
        GameTooltip:Show();
    end);
    showButton:SetScript("OnLeave", function()
        GameTooltip:Hide();
    end);
    showButton:SetHeight(14);
    showButton:SetWidth(showButton:GetTextWidth()+10);
end

local talentSequenceEventFrame = CreateFrame("Frame");
talentSequenceEventFrame:SetScript("OnEvent", function(self, event, ...)
    if (event == "ADDON_LOADED" and ... == "TalentSequence") then
        if (not TalentSequenceTalents) then
            TalentSequenceTalents = {};
        end
        if (IsTalentSequenceExpanded == 0) then
            IsTalentSequenceExpanded = false;
        end
        if (TalentOrderFrame == nil) then
            TalentSequence_CreateFrame();
        end
        self:UnregisterEvent("ADDON_LOADED");
    end
end);
talentSequenceEventFrame:RegisterEvent("ADDON_LOADED");
