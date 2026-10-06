local _, ts = ...

local strlen = strlen
local strsub = strsub
local strfind = strfind
local strupper = strupper
local tinsert = tinsert
local string_gmatch = string.gmatch

ts.WowheadTalents = {}

local function NormalizeTalentString(rawTalentString)
    if (type(rawTalentString) ~= "string") then
        return nil
    end

    local normalized = rawTalentString:match("^%s*(.-)%s*$")
    if (normalized == "") then
        return nil
    end

    normalized = normalized:gsub("[?#].*$", "")
    normalized = normalized:gsub("/+$", "")
    return normalized
end

local function FindLast(haystack, needle)
    local lastIndex = nil
    local currentIndex = string.find(haystack, needle, 1, true)
    while currentIndex do
        lastIndex = currentIndex
        currentIndex = string.find(haystack, needle, currentIndex + 1, true)
    end
    return lastIndex
end

local function GetWowheadFlavor(rawTalentString)
    if strfind(rawTalentString, "/classic/") then
        return "classic"
    end
    if strfind(rawTalentString, "/tbc/") then
        return "tbc"
    end
    if strfind(rawTalentString, "/wotlk/") then
        return "wotlk"
    end
    if strfind(rawTalentString, "/cata/") then
        return "cata"
    end
    return nil
end

local function GetFlavorMetadata(flavorKey)
    local flavorMap = ts.WowheadData and ts.WowheadData[flavorKey]
    return flavorMap and flavorMap.__meta or nil
end

local function GetTalentPointLevel(flavorMeta, pointNumber)
    if not flavorMeta or pointNumber < 1 then
        return nil
    end

    local pointGrantLevels = flavorMeta.pointGrantLevels
    if type(pointGrantLevels) == "table" then
        return pointGrantLevels[pointNumber]
    end

    local startingLevel = flavorMeta.startingLevel or 9
    return startingLevel + pointNumber
end

local function GetEncodedTalentToken(flavorMeta, encodedId)
    if not flavorMeta or not encodedId then
        return nil, nil
    end

    local singlePointTokens = flavorMeta.singlePointTokens
    local maxRankTokens = flavorMeta.maxRankTokens
    local index = strfind(singlePointTokens, encodedId, 1, true)
    if index then
        return strsub(singlePointTokens, index, index), false
    end

    index = strfind(maxRankTokens, encodedId, 1, true)
    if index then
        return strsub(singlePointTokens, index, index), true
    end

    return nil, nil
end

local function GetWowheadClass(rawTalentString)
    for segment in string_gmatch(rawTalentString, "[^/]+") do
        if segment == "death-knight" or segment == "deathknight" then
            return "DEATHKNIGHT"
        end
        if segment == "druid" or segment == "hunter" or segment == "mage" or
            segment == "paladin" or segment == "priest" or segment == "rogue" or
            segment == "shaman" or segment == "warlock" or segment == "warrior" then
            return strupper(segment)
        end
    end

    return nil
end

local function HasTalentOrder(encodedString, flavorMeta)
    if not flavorMeta then
        return false
    end

    for i = 1, strlen(encodedString) do
        local encodedId = strsub(encodedString, i, i)
        if GetEncodedTalentToken(flavorMeta, encodedId) then
            return true
        end
    end
    return false
end

local function GetTalentEntry(flavorKey, classToken, tab, token)
    local flavorMap = ts.WowheadData and ts.WowheadData[flavorKey]
    local classMap = flavorMap and flavorMap[classToken]
    local treeMap = classMap and classMap[tab]
    return treeMap and treeMap[token] or nil
end

function ts.WowheadTalents.GetTalents(talentString)
    local rawTalentString = NormalizeTalentString(talentString)
    if not rawTalentString then
        return nil, nil, "INVALID_URL"
    end

    local classToken = GetWowheadClass(rawTalentString)
    if not classToken then
        return nil, nil, "INVALID_URL"
    end
    local flavorKey = GetWowheadFlavor(rawTalentString)
    if not flavorKey then
        return nil, classToken, "INVALID_URL"
    end
    if flavorKey ~= ts.Flavor.GetKey() then
        return nil, classToken, "FLAVOR_MISMATCH"
    end
    local flavorMeta = GetFlavorMetadata(flavorKey)
    if not flavorMeta then
        return nil, classToken, "IMPORT_FAILED"
    end

    local startPosition = FindLast(rawTalentString, "/")
    if startPosition then
        talentString = strsub(rawTalentString, startPosition + 1)
    else
        talentString = rawTalentString
    end

    if not HasTalentOrder(talentString, flavorMeta) then
        return nil, classToken, "NO_ORDER"
    end

    local currentTab = 0
    local talentStringLength = strlen(talentString)
    local talents = {}
    local talentCounter = {}
    local pointsSpent = 0
    for i = 1, talentStringLength, 1 do
        local encodedId = strsub(talentString, i, i)
        if strfind("012", encodedId, 1, true) then
            currentTab = tonumber(encodedId)
        else
            local normalizedToken, isMaxRank = GetEncodedTalentToken(flavorMeta, encodedId)
            if not normalizedToken then
                return nil, classToken, "MAPPING_FAILED"
            end

            local entry = GetTalentEntry(flavorKey, classToken, currentTab, normalizedToken)
            if not entry or not entry.ranks then
                return nil, classToken, "MAPPING_FAILED"
            end

            if isMaxRank then
                local maxRank = #entry.ranks
                if maxRank < 1 then
                    return nil, classToken, "MAPPING_FAILED"
                end
                for j = 1, maxRank do
                    pointsSpent = pointsSpent + 1
                    local spellId = entry.ranks[j]
                    local resolved = ts.TalentResolver.Resolve(spellId, classToken)
                    if not resolved then
                        return nil, classToken, "MAPPING_FAILED"
                    end
                    tinsert(talents, {
                        tab = resolved.tab,
                        index = resolved.index,
                        rank = j,
                        level = GetTalentPointLevel(flavorMeta, pointsSpent),
                        spellId = spellId,
                    })
                end
            else
                local counterKey = currentTab .. ":" .. normalizedToken
                talentCounter[counterKey] = (talentCounter[counterKey] or 0) + 1
                local rank = talentCounter[counterKey]

                local spellId = entry.ranks[rank]
                if not spellId then
                    return nil, classToken, "MAPPING_FAILED"
                end

                pointsSpent = pointsSpent + 1
                local resolved = ts.TalentResolver.Resolve(spellId, classToken)
                if not resolved then
                    return nil, classToken, "MAPPING_FAILED"
                end
                tinsert(talents, {
                    tab = resolved.tab,
                    index = resolved.index,
                    rank = rank,
                    level = GetTalentPointLevel(flavorMeta, pointsSpent),
                    spellId = spellId,
                })
            end
        end
    end
    return talents, classToken
end
