local _, ts = ...

local GetLocale = GetLocale

local localeText = {
    enUS = {
        TOGGLE = "Toggle Talent Sequence Window",
        LOAD = "Load",
        IMPORT = "Import",
        LOAD_TOOLTIP = "Click to Load Sequence List",
        IMPORT_TOOLTIP = "Click to Import a New Sequence",
        IMPORT_DIALOG = "Paste your talent string into the box below.",
        EARLY_LINK = "It seems the name you entered may be a link. It may not appear properly as the name for the import and overlap other elements.",
        TRY_AGAIN = "Try again",
        CONFIRM = "Continue",
        RE_ENTER = "Re-enter",
        OK = "OK",
        CANCEL = "Cancel",
        SUCCESS = "Talent import for another class successful.",
        LOAD_SEQUENCE_TIP = "Click to Load Sequence",
        NO_WOWHEAD_CLASSIC = "Sorry, the entered text doesn't appear to be a link from Wowhead's Classic Talent Calculator. Copy the url below to create one in your browser.",
        INVALID_LINK = "Sorry, the link appears to be invalid. Please make sure you've copied the entire Wowhead Talent Calculator URL or get one by copying the link below.",
        DELETE_TIP = "<Shift>-Click to Delete",
        RENAME_TIP = "Click to Rename",
        UNNAMED = "Auto-Imported from Active",
        IMPORT_NAME_DIALOG = "Enter a name for your talent build.",
        MISSING_NAME = "Please enter a name."
    }
};

ts.L = localeText["enUS"]
local locale = GetLocale()
if (locale == "enUS" or locale == "enGB" or localeText[locale] == nil) then
    return
end
for k, v in pairs(localeText[locale]) do
    ts.L[k] = v
end
