local addonName, ts = ...

IsTalentPlannerExpanded = false
TalentPlannerTalents = {}

local DEFAULT_CONFIG = {
    talentFrameName = "PlayerTalentFrame",
    trackerAnchors = {
        {"TOPLEFT", "TOPRIGHT", -36, -12},
        {"BOTTOMLEFT", "BOTTOMRIGHT", 0, 72},
    },
    trackerBackdrop = {
        bgFile = "Interface\\FrameGeneral\\UI-Background-Marble",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    },
    showButtonAnchor = {"TOPRIGHT", -120, -16},
    showButtonHeight = 18,
}

local initRun = false

local function init(frameConfig)
    if initRun then
        return
    end

    if not ts.Flavor.IsSupported() then
        print("|cffff6060Talent Planner:|r This game version uses a different talent system and is not supported.")
        initRun = true
        return
    end

    ts.FrameConfig = frameConfig
    if not TalentPlannerTalents then
        TalentPlannerTalents = {}
    end
    if not TalentPlannerSavedSequences then
        TalentPlannerSavedSequences = {}
    end

    ts.DB.GetSequenceStore()
    ts.DB.GetCollapsedClassStore()
    ts.DB.GetActiveSequenceAssignmentStore()
    ts.DB.MigrateSavedSequences()

    if #TalentPlannerTalents > 0 and #ts.DB.GetSequenceStore() == 0 then
        ts.DB.InsertSequence(TalentPlannerTalents, ts.DB.GetPlayerClassToken())
    end

    ts.Talents = {}
    if IsTalentPlannerExpanded == 0 then
        IsTalentPlannerExpanded = false
    end

    if ts.MainFrame == nil then
        ts.CreateMainFrame()
    end
    ts:LoadAssignedSequenceForCurrentSpec()
    initRun = true
end

local function TryInitFromTalentUI()
    if initRun then
        return
    end
    if _G.PlayerTalentFrame == nil then
        return
    end
    init(DEFAULT_CONFIG)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == addonName then
            -- Defer UI attachment until the talent frame exists.
            return
        end
        if arg1 == "Blizzard_TalentUI" then
            TryInitFromTalentUI()
        end
        return
    end

    if event == "PLAYER_LOGIN" then
        if ts.Compat.IsAddOnLoaded("Blizzard_TalentUI") then
            TryInitFromTalentUI()
        end
    end
end)

-- Talent UI is load-on-demand; hook the toggle so we init the first time it opens.
if type(hooksecurefunc) == "function" then
    hooksecurefunc("ToggleTalentFrame", function()
        if _G.PlayerTalentFrame == nil then
            -- Some clients expose TalentFrame_LoadUI / LoadAddOn instead of creating immediately.
            if type(_G.TalentFrame_LoadUI) == "function" then
                _G.TalentFrame_LoadUI()
            elseif not ts.Compat.IsAddOnLoaded("Blizzard_TalentUI") then
                ts.Compat.LoadAddOn("Blizzard_TalentUI")
            end
        end
        TryInitFromTalentUI()
    end)
end
