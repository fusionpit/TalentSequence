local _, ts = ...

local GetLocale = GetLocale

local localeText = {
    enUS = {
        TOGGLE = "Toggle Talent Sequence Window",
        IMPORT = "Import",
        IMPORT_DIALOG = "Paste your talent string into the box below",
        OK = "OK",
        CANCEL = "Cancel",
        WRONG_CLASS = "Unable to import, you're not a %s!"
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
