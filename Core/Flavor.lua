local _, ts = ...

-- Detects which classic talent ruleset this client build is running.
-- Talent Planner only targets live clients that still use the classic
-- three-tree point-spending system: Classic Era / Hardcore / SoD, and
-- Burning Crusade Classic Anniversary.

ts.Flavor = {}

local PROJECT_FLAVORS = {
    [WOW_PROJECT_CLASSIC or 2] = "classic",
    [WOW_PROJECT_BURNING_CRUSADE_CLASSIC or 5] = "tbc",
    [WOW_PROJECT_WRATH_CLASSIC or 11] = "wotlk",
    [WOW_PROJECT_CATACLYSM_CLASSIC or 14] = "cata",
}

local FLAVOR_LABELS = {
    classic = "Classic Era",
    tbc = "Burning Crusade Classic",
    wotlk = "Wrath of the Lich King Classic",
    cata = "Cataclysm Classic",
}

-- Clients where a classic talent-sequence planner is still meaningful.
local SUPPORTED_LIVE_FLAVORS = {
    classic = true,
    tbc = true,
}

function ts.Flavor.GetKey()
    if ts._flavorKey then
        return ts._flavorKey
    end

    -- Prefer the Wowhead data TOC actually loaded for this client.
    if ts.WowheadData then
        if ts.WowheadData.classic then
            ts._flavorKey = "classic"
            return ts._flavorKey
        end
        if ts.WowheadData.tbc then
            ts._flavorKey = "tbc"
            return ts._flavorKey
        end
        if ts.WowheadData.wotlk then
            ts._flavorKey = "wotlk"
            return ts._flavorKey
        end
        if ts.WowheadData.cata then
            ts._flavorKey = "cata"
            return ts._flavorKey
        end
    end

    local projectId = _G.WOW_PROJECT_ID
    if projectId and PROJECT_FLAVORS[projectId] then
        ts._flavorKey = PROJECT_FLAVORS[projectId]
        return ts._flavorKey
    end

    ts._flavorKey = "classic"
    return ts._flavorKey
end

function ts.Flavor.GetLabel(flavorKey)
    flavorKey = flavorKey or ts.Flavor.GetKey()
    return FLAVOR_LABELS[flavorKey] or flavorKey
end

function ts.Flavor.IsSupported(flavorKey)
    flavorKey = flavorKey or ts.Flavor.GetKey()
    return SUPPORTED_LIVE_FLAVORS[flavorKey] == true
end

function ts.Flavor.GetMeta(flavorKey)
    flavorKey = flavorKey or ts.Flavor.GetKey()
    local flavorMap = ts.WowheadData and ts.WowheadData[flavorKey]
    return flavorMap and flavorMap.__meta or nil
end

function ts.Flavor.GetTalentPointLevel(flavorKey, pointNumber)
    local meta = ts.Flavor.GetMeta(flavorKey)
    if not meta or not pointNumber or pointNumber < 1 then
        return nil
    end

    local pointGrantLevels = meta.pointGrantLevels
    if type(pointGrantLevels) == "table" and pointGrantLevels[pointNumber] then
        return pointGrantLevels[pointNumber]
    end

    local startingLevel = meta.startingLevel or 9
    return startingLevel + pointNumber
end
