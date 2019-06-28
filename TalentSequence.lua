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
    OnShow = function()
        getglobal(this:GetName().."EditBox"):SetText("");
    end,
    OnAccept = function()
        local talentsString = getglobal(this:GetParent():GetName().."EditBox"):GetText();
        TalentSequence_SetTalents(TalentOrderFrame, talentsString);
    end,
    EditBoxOnEnterPressed = function()
        local talentsString = getglobal(this:GetParent():GetName().."EditBox"):GetText();
        TalentSequence_SetTalents(TalentOrderFrame, talentsString);
        this:GetParent():Hide();
    end,
    EditBoxOnEscapePressed = function()
        this:GetParent():Hide();
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

    local iconTexture = getglobal(row.icon:GetName().."IconTexture");
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
        iconTexture:SetDesaturated(0);
    end
end

function TalentSequence_FindFirstUnlearnedIndex()
    for index, talent in TalentSequenceTalents do
        local _, _, _, _, currentRank = GetTalentInfo(talent.tab, talent.index);
        if (talent.rank > currentRank) then
            return index;
        end
    end
end

function TalentSequence_ScrollFirstUnlearnedTalentIntoView(frame)
    local numTalents = getn(TalentSequenceTalents);
    if (numTalents <= MAX_ROWS) then
        return;
    end

    local scrollBar = frame.scrollBar;
    local bar = getglobal(scrollBar:GetName().."ScrollBar");

    local nextTalentIndex = TalentSequence_FindFirstUnlearnedIndex();
    if (not nextTalentIndex) then
        return;
    end
    if (nextTalentIndex == 1) then
        FauxScrollFrame_SetOffset(scrollBar, 0);
        bar:SetValue(0);
        return;
    end
    local nextTalentOffset = nextTalentIndex - 1;
    if (nextTalentOffset > numTalents-MAX_ROWS) then
        nextTalentOffset = numTalents-MAX_ROWS;
    end
    FauxScrollFrame_SetOffset(scrollBar, nextTalentOffset);
    bar:SetValue(ceil(nextTalentOffset*ROW_HEIGHT-0.5));
end

function TalentSequence_Update(frame)
    local scrollBar = frame.scrollBar;
    local numTalents = getn(TalentSequenceTalents);
    FauxScrollFrame_Update(scrollBar, numTalents, MAX_ROWS, ROW_HEIGHT);
    local offset = FauxScrollFrame_GetOffset(scrollBar);
    for i = 1, MAX_ROWS do
        local talentIndex = i+offset;
        local talent = TalentSequenceTalents[talentIndex];
        local row = getglobal(frame:GetName().."Row"..i);
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
    mainFrame:SetScript("OnShow", function()
        TalentSequence_ScrollFirstUnlearnedTalentIntoView(this);
    end);
    mainFrame:RegisterEvent("CHARACTER_POINTS_CHANGED");
    mainFrame:RegisterEvent("SPELLS_CHANGED");
    mainFrame:SetScript("OnEvent", function()
        if (((event == "CHARACTER_POINTS_CHANGED") or (event == "SPELLS_CHANGED")) and this:IsShown()) then
            TalentSequence_ScrollFirstUnlearnedTalentIntoView(this);
            TalentSequence_Update(this);
        end
    end)
    mainFrame:Hide();
    -- This needs to be changed to some hooks in Classic
    local oldOnClick = TalentFrameTab_OnClick;
    TalentFrameTab_OnClick = function()
        oldOnClick();
        if (mainFrame:IsShown()) then
            TalentSequence_Update(mainFrame);
        end
    end
    local oldOnShow = TalentFrame_OnShow;
    TalentFrame_OnShow = function()
        oldOnShow();
        if (IsTalentSequenceExpanded) then
            mainFrame:Show();
        end
    end
    local oldOnHide = TalentFrame_OnHide;
    TalentFrame_OnHide = function()
        oldOnHide();
        mainFrame:Hide();
    end
    
    local scrollBar = CreateFrame("ScrollFrame", "$parentScrollBar", mainFrame, "FauxScrollFrameTemplate");
    scrollBar:SetPoint("TOPLEFT", 0, -8);
    scrollBar:SetPoint("BOTTOMRIGHT", -30, 8);
    scrollBar:SetScript("OnVerticalScroll", function()
        FauxScrollFrame_OnVerticalScroll(ROW_HEIGHT, function()
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
        icon:SetScript("OnClick", function()
            local talent = this:GetParent().talent;
            local _, _, _, _, currentRank = GetTalentInfo(talent.tab, talent.index);
            local playerLevel = UnitLevel("player");
            if (currentRank + 1 == talent.rank and playerLevel >= talent.level) then
                LearnTalent(talent.tab, talent.index);
            end
        end);
        icon:SetScript("OnEnter", function()
            if (not this.tooltip) then 
                return;
            end
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT", 0, -ROW_HEIGHT);
            GameTooltip:SetText(this.tooltip, nil, nil, nil, nil, true);
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
    end
    showButton.tooltip = L["TOGGLE"];
    showButton:SetScript("OnClick", function()
        IsTalentSequenceExpanded = not IsTalentSequenceExpanded;
        if (IsTalentSequenceExpanded) then
            mainFrame:Show();
            this:SetText("<<");
        else
            mainFrame:Hide();
            this:SetText(">>");
        end
    end);
    showButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT");
        GameTooltip:SetText(this.tooltip, nil, nil, nil, nil, true);
        GameTooltip:Show();
    end);
    showButton:SetScript("OnLeave", function()
        GameTooltip:Hide();
    end);
    showButton:SetHeight(14);
    showButton:SetWidth(18);
end

local talentSequenceEventFrame = CreateFrame("Frame");
talentSequenceEventFrame:SetScript("OnEvent", function()
    if ((event == "VARIABLES_LOADED") or (event == "ADDON_LOADED" and arg1 == "TalentSequence")) then
        if (TalentSequenceTalents == nil) then
            TalentSequenceTalents = {};
        end
        if (IsTalentSequenceExpanded == 0) then
            IsTalentSequenceExpanded = false;
        end
        if (TalentOrderFrame == nil) then
            TalentSequence_CreateFrame();
        end
    end
end);
talentSequenceEventFrame:RegisterEvent("VARIABLES_LOADED");
talentSequenceEventFrame:RegisterEvent("ADDON_LOADED");
