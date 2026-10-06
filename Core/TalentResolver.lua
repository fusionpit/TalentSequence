local _, ts = ...

local strfind = strfind
local strsub = strsub
local strlen = strlen
local pairs = pairs
local ipairs = ipairs
local tinsert = tinsert

ts.TalentResolver = {}

-- Cached reverse lookup: spellId -> {tab, index, rank}
-- Keyed by classToken to avoid cross-class collisions
local spellIdCache = {}

-- Cached forward lookup: "tab:index" -> {ranks = {spellId, ...}, name, icon}
-- Keyed by classToken
local locationCache = {}

local function GetTalentData()
    return ts.WowheadData
end

local function BuildCacheForClass(classToken)
    if spellIdCache[classToken] then return end

    local talentData = GetTalentData()
    if not talentData then return end

    local spellLookup = {}
    local locLookup = {}

    local preferredFlavor = ts.Flavor and ts.Flavor.GetKey and ts.Flavor.GetKey()
    local flavorOrder = {}
    if preferredFlavor and talentData[preferredFlavor] then
        tinsert(flavorOrder, preferredFlavor)
    end
    for flavorKey in pairs(talentData) do
        if flavorKey ~= "__meta" and flavorKey ~= preferredFlavor then
            tinsert(flavorOrder, flavorKey)
        end
    end

    for _, flavorKey in ipairs(flavorOrder) do
        local flavorMap = talentData[flavorKey]
        local classMap = flavorMap and flavorMap[classToken]
        if classMap then
            local meta = flavorMap.__meta
            local singleTokens = meta and meta.singlePointTokens
            if singleTokens then
                for tab, treeMap in pairs(classMap) do
                    if type(tab) == "number" then
                        for token, entry in pairs(treeMap) do
                            local index = strfind(singleTokens, token, 1, true)
                            if index and entry.ranks then
                                local key = (tab + 1) .. ":" .. index
                                locLookup[key] = entry
                                for rank, spellId in ipairs(entry.ranks) do
                                    spellLookup[spellId] = {
                                        tab = tab + 1,
                                        index = index,
                                        rank = rank,
                                    }
                                end
                            end
                        end
                    end
                end
            end
            break
        end
    end

    spellIdCache[classToken] = spellLookup
    locationCache[classToken] = locLookup
end

function ts.TalentResolver.Resolve(spellId, classToken)
    if not spellId or not classToken then return nil end
    BuildCacheForClass(classToken)
    local lookup = spellIdCache[classToken]
    return lookup and lookup[spellId] or nil
end

function ts.TalentResolver.GetSpellId(classToken, tab, index, rank)
    if not classToken or not tab or not index then return nil end
    BuildCacheForClass(classToken)
    local locLookup = locationCache[classToken]
    if not locLookup then return nil end
    local key = tab .. ":" .. index
    local entry = locLookup[key]
    if not entry or not entry.ranks then return nil end
    return entry.ranks[rank or 1]
end

function ts.TalentResolver.GetMaxRank(classToken, tab, index)
    if not classToken or not tab or not index then return nil end
    BuildCacheForClass(classToken)
    local locLookup = locationCache[classToken]
    if not locLookup then return nil end
    local key = tab .. ":" .. index
    local entry = locLookup[key]
    if not entry or not entry.ranks then return nil end
    return #entry.ranks
end

function ts.TalentResolver.GetFlavorMeta(flavorKey)
    return ts.Flavor.GetMeta(flavorKey)
end

function ts.TalentResolver.InvalidateCache()
    spellIdCache = {}
    locationCache = {}
end
