local _, ts = ...

local _G = _G
local CreateFrame = CreateFrame
local FauxScrollFrame_SetOffset = FauxScrollFrame_SetOffset
local FauxScrollFrame_GetOffset = FauxScrollFrame_GetOffset
local FauxScrollFrame_OnVerticalScroll = FauxScrollFrame_OnVerticalScroll
local FauxScrollFrame_Update = FauxScrollFrame_Update
local strfind = strfind
local tinsert = tinsert
local tremove = tremove

local SEQUENCES_ROW_HEIGHT = 26
local MAX_SEQUENCE_ROWS = 5

local function BuildSequenceDisplayRows()
    local currentClassToken = ts.DB.GetPlayerClassToken()
    local collapsedClasses = ts.DB.GetCollapsedClassStore()
    local groupedSequences = {}
    local classTokens = {currentClassToken}
    local seenClassTokens = {[currentClassToken] = true}
    local rows = {}

    for index, sequence in ipairs(ts.DB.GetSequenceStore()) do
        ts.DB.EnsureSequenceMetadata(sequence, currentClassToken)
        if (not groupedSequences[sequence.classToken]) then
            groupedSequences[sequence.classToken] = {}
            if (not seenClassTokens[sequence.classToken]) then
                tinsert(classTokens, sequence.classToken)
                seenClassTokens[sequence.classToken] = true
            end
        end
        tinsert(groupedSequences[sequence.classToken], {
            type = "sequence",
            classToken = sequence.classToken,
            sequence = sequence,
            sequenceIndex = index,
            assignmentLabel = ts.DB.GetSequenceAssignmentLabel(sequence.id)
        })
    end

    table.sort(classTokens, function(left, right)
        if (left == currentClassToken) then return true end
        if (right == currentClassToken) then return false end
        return ts.DB.GetClassDisplayName(left) < ts.DB.GetClassDisplayName(right)
    end)

    for _, classToken in ipairs(classTokens) do
        tinsert(rows, {
            type = "header",
            classToken = classToken,
            className = ts.DB.GetClassDisplayName(classToken),
            isCurrentClass = (classToken == currentClassToken)
        })
        if (classToken == currentClassToken or not collapsedClasses[classToken]) then
            for _, sequenceRow in ipairs(groupedSequences[classToken] or {}) do
                tinsert(rows, sequenceRow)
            end
        end
    end

    return rows
end

local function FindDisplayRowIndexForSequence(displayRows, targetSequence)
    for index, entry in ipairs(displayRows) do
        if (entry.type == "sequence" and entry.sequence == targetSequence) then
            return index
        end
    end
end

function ts:ImportTalents(talentsString)
    local talents, classToken, err

    if (ts.WebUITalents and (ts.WebUITalents.IsJSON(talentsString) or ts.WebUITalents.IsURL(talentsString))) then
        talents, classToken, err = ts.WebUITalents.GetTalents(talentsString)
    elseif (ts.WarcraftTavernTalents and ts.WarcraftTavernTalents.IsURL(talentsString)) then
        talents, classToken, err = ts.WarcraftTavernTalents.GetTalents(talentsString)
    elseif strfind(talentsString, "wowhead") then
        talents, classToken, err = ts.WowheadTalents.GetTalents(talentsString)
    else
        print("|cffff6060Talent Planner:|r " .. ts.L.IMPORT_FAILED)
        return
    end

    if (talents == nil) then
        if (err == "NO_ORDER") then
            print("|cffff6060Talent Planner:|r " .. ts.L.NO_ORDER)
        elseif (err == "FLAVOR_MISMATCH") then
            print("|cffff6060Talent Planner:|r " .. ts.L.FLAVOR_MISMATCH)
        else
            print("|cffff6060Talent Planner:|r " .. ts.L.IMPORT_FAILED)
        end
        return
    end
    local sequence = ts.DB.InsertSequence(talents, classToken)
    ts.DB.GetCollapsedClassStore()[classToken] = nil
    self.PendingRenameSequence = sequence
    if (self.ImportFrame and self.ImportFrame:IsShown()) then
        local scrollBar = self.ImportFrame.scrollBar
        FauxScrollFrame_SetOffset(scrollBar, 0)
        FauxScrollFrame_OnVerticalScroll(scrollBar, 0, SEQUENCES_ROW_HEIGHT)
        ts:UpdateSequencesFrame()
    end
end

function ts:UpdateSequencesFrame()
    local frame = self.ImportFrame
    frame:ShowAllLoadButtons()
    frame.displayRows = BuildSequenceDisplayRows()
    FauxScrollFrame_Update(frame.scrollBar, #frame.displayRows,
                           MAX_SEQUENCE_ROWS, SEQUENCES_ROW_HEIGHT, nil, nil,
                           nil, nil, nil, nil, true)
    local offset = FauxScrollFrame_GetOffset(frame.scrollBar)
    for i = 1, MAX_SEQUENCE_ROWS do
        local index = i + offset
        local row = frame.rows[i]
        row:SetEntry(frame.displayRows[index])
    end

    if (self.PendingRenameSequence) then
        local rowIndex = FindDisplayRowIndexForSequence(frame.displayRows,
                                                        self.PendingRenameSequence)
        if (rowIndex) then
            local desiredOffset = rowIndex - 1
            local maxOffset = #frame.displayRows - MAX_SEQUENCE_ROWS
            if (maxOffset < 0) then maxOffset = 0 end
            if (desiredOffset > maxOffset) then desiredOffset = maxOffset end
            FauxScrollFrame_SetOffset(frame.scrollBar, desiredOffset)
            for i = 1, MAX_SEQUENCE_ROWS do
                local displayIndex = i + desiredOffset
                frame.rows[i]:SetEntry(frame.displayRows[displayIndex])
            end
            frame.rows[rowIndex - desiredOffset]:SetForRename()
            self.PendingRenameSequence = nil
        end
    end
end

function ts.CreateImportFrame()
    local sequencesFrame = CreateFrame("Frame", "TalentPlannerSequences", UIParent,
                                       "BasicFrameTemplateWithInset")
    sequencesFrame:Hide()
    sequencesFrame:SetScript("OnShow", function() ts:UpdateSequencesFrame() end)
    sequencesFrame:SetSize(325, 212)
    if (ts.MainFrame) then
        sequencesFrame:SetPoint("TOPLEFT", ts.MainFrame, "TOPRIGHT", 0, 0)
    else
        sequencesFrame:SetPoint("CENTER")
    end
    sequencesFrame:SetMovable(true)
    sequencesFrame:SetClampedToScreen(true)
    sequencesFrame:SetScript("OnMouseDown", sequencesFrame.StartMoving)
    sequencesFrame:SetScript("OnMouseUp", sequencesFrame.StopMovingOrSizing)
    sequencesFrame.TitleText:SetText("Talent Planner")
    function sequencesFrame:ShowAllLoadButtons()
        for _, row in ipairs(self.rows) do row:SetForLoad() end
    end
    tinsert(UISpecialFrames, "TalentPlannerSequences")
    local scrollBar = CreateFrame("ScrollFrame", "$parentScrollBar",
                                  sequencesFrame, "FauxScrollFrameTemplate")
    scrollBar:SetPoint("TOPLEFT", sequencesFrame.InsetBg, "TOPLEFT", 5, -6)
    scrollBar:SetPoint("BOTTOMRIGHT", sequencesFrame.InsetBg, "BOTTOMRIGHT",
                       -28, 28)

    sequencesFrame.scrollBar = scrollBar

    local importButton = CreateFrame("Button", nil, sequencesFrame,
                                     "UIPanelButtonTemplate")
    importButton:SetPoint("BOTTOM", 0, 8)
    importButton:SetSize(100, 24)
    importButton:SetText(ts.L.IMPORT)
    importButton:SetNormalFontObject("GameFontNormal")
    importButton:SetHighlightFontObject("GameFontHighlight")
    importButton:SetScript("OnClick", function() ts.Dialogs.ShowImportDialog() end)

    local tooltip = ts.tooltip
    local rows = {}
    for i = 1, MAX_SEQUENCE_ROWS do
        local row = CreateFrame("Frame", "$parentRow" .. i, sequencesFrame)
        row.index = i
        row:SetPoint("RIGHT", scrollBar)
        row:SetPoint("LEFT", scrollBar)
        row:SetHeight(SEQUENCES_ROW_HEIGHT)

        local nameInput = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
        nameInput:SetPoint("TOP")
        nameInput:SetPoint("BOTTOM")
        nameInput:SetPoint("LEFT")
        nameInput:SetWidth(150)
        nameInput:SetAutoFocus(false)

        local namedLoadButton = CreateFrame("Button", nil, row,
                                            "UIPanelButtonTemplate")
        namedLoadButton:SetPoint("TOPLEFT", nameInput, "TOPLEFT", -6, 0)
        namedLoadButton:SetPoint("BOTTOMRIGHT", nameInput, "BOTTOMRIGHT")
        nameInput:Hide()

        local talentAmountString = row:CreateFontString(nil, "ARTWORK",
                                                        "GameFontWhite")
        talentAmountString:SetPoint("LEFT", nameInput, "RIGHT")
        local headerButton = CreateFrame("Button", nil, row)
        headerButton:SetPoint("TOPLEFT")
        headerButton:SetPoint("BOTTOMRIGHT")
        local headerText = row:CreateFontString(nil, "ARTWORK",
                                                "GameFontHighlight")
        headerText:SetPoint("LEFT", headerButton, "LEFT", 4, 0)
        headerText:SetJustifyH("LEFT")

        local deleteButton = CreateFrame("Button", nil, row)
        deleteButton:EnableMouse(true)
        deleteButton:SetPoint("RIGHT")
        deleteButton:SetPoint("TOP")
        deleteButton:SetPoint("BOTTOM")
        deleteButton:SetWidth(SEQUENCES_ROW_HEIGHT)

        local delete = row:CreateTexture(nil, "ARTWORK")
        delete:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
        delete:SetAllPoints(deleteButton)
        delete:SetVertexColor(1, 1, 1, 0.5)

        local renameButton = CreateFrame("Button", nil, row)
        renameButton:EnableMouse(true)
        renameButton:SetPoint("TOP")
        renameButton:SetPoint("BOTTOM")
        renameButton:SetPoint("RIGHT", delete, "LEFT")
        renameButton:SetWidth(SEQUENCES_ROW_HEIGHT)

        talentAmountString:SetPoint("RIGHT", renameButton, "LEFT")

        local rename = row:CreateTexture(nil, "ARTWORK")
        rename:SetTexture("Interface\\Buttons\\UI-OptionsButton")
        rename:SetAllPoints(renameButton)
        rename:SetVertexColor(1, 1, 1, 0.5)

        nameInput:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
            self:Hide()
            namedLoadButton:Show()
        end)
        nameInput:SetScript("OnEnterPressed", function(self)
            local inputText = self:GetText()
            local newName = (inputText and inputText ~= "") and inputText or
                            ts.L.UNNAMED
            if (self:GetParent().entry and self:GetParent().entry.sequence) then
                self:GetParent().entry.sequence.name = newName
            end
            namedLoadButton:Show()
            self:Hide()
            ts:UpdateSequencesFrame()
        end)
        namedLoadButton:SetScript("OnEnter", function(self)
            tooltip:SetOwner(self, "ANCHOR_RIGHT")
            if (self:IsEnabled()) then
                tooltip:SetText(ts.L.LOAD_SEQUENCE_TIP)
            else
                tooltip:SetText(ts.L.LOAD_OTHER_CLASS_TIP)
            end
            tooltip:Show()
        end)
        namedLoadButton:SetScript("OnLeave", function() tooltip:Hide() end)
        namedLoadButton:SetScript("OnClick", function(self)
            local entry = self:GetParent().entry
            local sequence = entry and entry.sequence
            if (not sequence) then return end
            if (sequence.classToken ~= ts.DB.GetPlayerClassToken()) then return end
            ts:ActivateSequence(sequence)
            ts:UpdateSequencesFrame()
        end)
        headerButton:SetScript("OnClick", function(self)
            local entry = self:GetParent().entry
            if (not entry or entry.type ~= "header" or entry.isCurrentClass) then
                return
            end
            local collapsedClasses = ts.DB.GetCollapsedClassStore()
            collapsedClasses[entry.classToken] = not collapsedClasses[entry.classToken]
            ts:UpdateSequencesFrame()
        end)
        local function onIconButtonEnter(tooltipText, button, icon)
            icon:SetVertexColor(1, 1, 1, 1)
            tooltip:SetOwner(button, "ANCHOR_RIGHT")
            tooltip:SetText(tooltipText)
            tooltip:Show()
        end
        local function onIconButtonLeave(icon)
            icon:SetVertexColor(1, 1, 1, 0.5)
            tooltip:Hide()
        end
        deleteButton:SetScript("OnEnter", function(self)
            onIconButtonEnter(ts.L.DELETE_TIP, self, delete)
        end)
        deleteButton:SetScript("OnLeave", function()
            onIconButtonLeave(delete)
        end)
        renameButton:SetScript("OnEnter", function(self)
            onIconButtonEnter(ts.L.RENAME_TIP, self, rename)
        end)
        renameButton:SetScript("OnLeave", function()
            onIconButtonLeave(rename)
        end)
        deleteButton:SetScript("OnClick", function(self)
            if (not IsShiftKeyDown()) then return end
            local entry = self:GetParent().entry
            local sequence = entry and entry.sequence
            local index = entry and entry.sequenceIndex
            if (not sequence or not index) then return end
            ts.DB.ClearSequenceAssignments(sequence.id)
            tremove(ts.DB.GetSequenceStore(), index)
            if (ts.ActiveSequenceId == sequence.id) then
                ts:LoadAssignedSequenceForCurrentSpec()
            end
            ts:UpdateSequencesFrame()
        end)
        renameButton:SetScript("OnClick", function(self)
            self:GetParent():SetForRename()
        end)

        function row:SetForRename()
            if (not self.entry or self.entry.type ~= "sequence") then return end
            namedLoadButton:Hide()
            nameInput:SetText(self.entry.sequence.name)
            nameInput:Show()
            nameInput:SetFocus()
            nameInput:HighlightText()
        end
        function row:SetForLoad()
            nameInput:ClearFocus()
            nameInput:Hide()
            namedLoadButton:Show()
            namedLoadButton:Enable()
            deleteButton:Show()
            delete:Show()
            renameButton:Show()
            rename:Show()
            headerButton:Hide()
            headerText:Hide()
        end
        function row:SetEntry(entry)
            self.entry = entry
            if (entry == nil) then
                self:Hide()
                return
            end

            self:Show()
            self:SetForLoad()
            if (entry.type == "header") then
                namedLoadButton:Hide()
                talentAmountString:SetText("")
                deleteButton:Hide()
                delete:Hide()
                renameButton:Hide()
                rename:Hide()
                headerButton:Show()
                headerText:Show()
                local prefix = "[-]"
                if (not entry.isCurrentClass and ts.DB.GetCollapsedClassStore()[entry.classToken]) then
                    prefix = "[+]"
                end
                local suffix = ""
                if (entry.isCurrentClass) then
                    suffix = " (" .. ts.L.CURRENT_CLASS_LABEL .. ")"
                end
                headerText:SetText(prefix .. " " .. entry.className .. suffix)
                return
            end

            namedLoadButton:SetText(entry.sequence.name)
            if (entry.assignmentLabel) then
                talentAmountString:SetText(entry.sequence.points .. " [" .. entry.assignmentLabel .. "]")
            else
                talentAmountString:SetText(entry.sequence.points)
            end
            local canLoad = entry.sequence.classToken == ts.DB.GetPlayerClassToken()
            if (canLoad) then
                namedLoadButton:Enable()
                namedLoadButton:GetFontString():SetTextColor(1, 1, 1)
                talentAmountString:SetTextColor(1, 1, 1)
            else
                namedLoadButton:Disable()
                namedLoadButton:GetFontString():SetTextColor(0.5, 0.5, 0.5)
                talentAmountString:SetTextColor(0.6, 0.6, 0.6)
            end
        end

        if (rows[i - 1] == nil) then
            row:SetPoint("TOPLEFT", scrollBar, 5, -6)
        else
            row:SetPoint("TOPLEFT", rows[i - 1], "BOTTOMLEFT", 0, -2)
        end
        rawset(rows, i, row)
    end
    sequencesFrame.rows = rows

    scrollBar:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, SEQUENCES_ROW_HEIGHT,
                                         function()
            ts:UpdateSequencesFrame()
        end)
    end)
    scrollBar:SetScript("OnShow", function() ts:UpdateSequencesFrame() end)

    ts.ImportFrame = sequencesFrame
end
