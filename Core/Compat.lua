local _, ts = ...

-- Compatibility helpers for Classic Era (1.15.9+) and TBC Classic Anniversary (2.5.6+),
-- which share modernized UI code with retail-style APIs.

ts.Compat = {}

local function ResolveAddOnAPI()
    local api = _G.C_AddOns
    return {
        IsAddOnLoaded = (api and api.IsAddOnLoaded) or _G.IsAddOnLoaded,
        LoadAddOn = (api and api.LoadAddOn) or _G.LoadAddOn,
        GetAddOnEnableState = (api and api.GetAddOnEnableState) or _G.GetAddOnEnableState,
        DoesAddOnExist = (api and api.DoesAddOnExist) or _G.DoesAddOnExist,
    }
end

local addonAPI = ResolveAddOnAPI()

function ts.Compat.IsAddOnLoaded(name)
    if not addonAPI.IsAddOnLoaded then
        return false
    end
    return addonAPI.IsAddOnLoaded(name)
end

function ts.Compat.LoadAddOn(name)
    if not addonAPI.LoadAddOn then
        return false
    end
    return addonAPI.LoadAddOn(name)
end

function ts.Compat.GetSpellInfo(spellId)
    if not spellId then
        return nil
    end

    if _G.C_Spell and _G.C_Spell.GetSpellInfo then
        local info = _G.C_Spell.GetSpellInfo(spellId)
        if type(info) == "table" then
            return info.name, nil, info.iconID, nil, nil, nil, info.spellID
        end
    end

    if _G.GetSpellInfo then
        return _G.GetSpellInfo(spellId)
    end

    return nil
end

function ts.Compat.SetSpellTooltip(tooltip, spellId)
    if not tooltip or not spellId then
        return false
    end

    if tooltip.SetSpellByID then
        tooltip:SetSpellByID(spellId)
        return true
    end

    if _G.C_TooltipInfo and _G.C_TooltipInfo.GetSpellByID and tooltip.ProcessSpellByID then
        tooltip:ProcessSpellByID(spellId)
        return true
    end

    return false
end

-- Register a spell-tooltip post-call that works on both legacy OnTooltipSetSpell
-- clients and TooltipDataProcessor-based clients (Classic 1.15.9 / TBC 2.5.6+).
-- When `tooltipFrame` is provided, the legacy path hooks that frame specifically.
function ts.Compat.HookSpellTooltip(callback, tooltipFrame)
    if type(callback) ~= "function" then
        return
    end

    if _G.TooltipDataProcessor and _G.TooltipDataProcessor.AddTooltipPostCall then
        local spellType = _G.Enum and _G.Enum.TooltipDataType and _G.Enum.TooltipDataType.Spell
        if spellType then
            _G.TooltipDataProcessor.AddTooltipPostCall(spellType, function(tooltip, data)
                callback(tooltip, data)
            end)
            return
        end
    end

    local target = tooltipFrame or _G.GameTooltip
    if target and target.HookScript then
        local ok = pcall(function()
            target:HookScript("OnTooltipSetSpell", function(self)
                callback(self)
            end)
        end)
        if ok then
            return
        end
    end
end
