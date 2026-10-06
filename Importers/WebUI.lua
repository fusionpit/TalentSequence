local _, ts = ...

local strlen = strlen
local strsub = strsub
local strfind = strfind
local tinsert = tinsert

ts.WebUITalents = {}

-- Minimal base64 decoder
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="
local B64_LOOKUP = {}
for i = 1, #B64 do B64_LOOKUP[B64:sub(i, i)] = i - 1 end

local function DecodeBase64(input)
    if not input or input == "" then return nil end
    input = input:gsub("[^A-Za-z0-9+/=]", "")
    local output = {}
    for i = 1, #input, 4 do
        local a = B64_LOOKUP[input:sub(i, i)] or 0
        local b = B64_LOOKUP[input:sub(i + 1, i + 1)] or 0
        local c = B64_LOOKUP[input:sub(i + 2, i + 2)] or 0
        local d = B64_LOOKUP[input:sub(i + 3, i + 3)] or 0
        local n = a * 262144 + b * 4096 + c * 64 + d
        output[#output + 1] = string.char(math.floor(n / 65536) % 256)
        if input:sub(i + 2, i + 2) ~= "=" then
            output[#output + 1] = string.char(math.floor(n / 256) % 256)
        end
        if input:sub(i + 3, i + 3) ~= "=" then
            output[#output + 1] = string.char(n % 256)
        end
    end
    return table.concat(output)
end

-- Minimal JSON parser for the web UI export format:
-- { "classToken": "PALADIN", "flavor": "tbc", "talents": [ {spellId}, ... ] }
local ParseObject, ParseArray

local function SkipWhitespace(str, pos)
    return str:match("^%s*()", pos)
end

local function ParseString(str, pos)
    if strsub(str, pos, pos) ~= '"' then return nil, pos end
    local endPos = strfind(str, '"', pos + 1, true)
    if not endPos then return nil, pos end
    return strsub(str, pos + 1, endPos - 1), endPos + 1
end

local function ParseNumber(str, pos)
    local numStr = str:match("^(-?%d+)", pos)
    if not numStr then return nil, pos end
    return tonumber(numStr), pos + #numStr
end

local function ParseValue(str, pos)
    pos = SkipWhitespace(str, pos)
    local ch = strsub(str, pos, pos)

    if ch == '"' then
        return ParseString(str, pos)
    elseif ch == '-' or (ch >= '0' and ch <= '9') then
        return ParseNumber(str, pos)
    elseif ch == '{' then
        return ParseObject(str, pos)
    elseif ch == '[' then
        return ParseArray(str, pos)
    elseif strsub(str, pos, pos + 3) == "null" then
        return nil, pos + 4
    elseif strsub(str, pos, pos + 3) == "true" then
        return true, pos + 4
    elseif strsub(str, pos, pos + 4) == "false" then
        return false, pos + 5
    end
    return nil, pos
end

ParseObject = function(str, pos)
    if strsub(str, pos, pos) ~= '{' then return nil, pos end
    pos = SkipWhitespace(str, pos + 1)
    local obj = {}

    if strsub(str, pos, pos) == '}' then return obj, pos + 1 end

    while pos <= strlen(str) do
        pos = SkipWhitespace(str, pos)
        local key
        key, pos = ParseString(str, pos)
        if not key then return nil, pos end

        pos = SkipWhitespace(str, pos)
        if strsub(str, pos, pos) ~= ':' then return nil, pos end
        pos = SkipWhitespace(str, pos + 1)

        local val
        val, pos = ParseValue(str, pos)
        obj[key] = val

        pos = SkipWhitespace(str, pos)
        local ch = strsub(str, pos, pos)
        if ch == '}' then return obj, pos + 1 end
        if ch == ',' then pos = pos + 1 end
    end
    return nil, pos
end

ParseArray = function(str, pos)
    if strsub(str, pos, pos) ~= '[' then return nil, pos end
    pos = SkipWhitespace(str, pos + 1)
    local arr = {}

    if strsub(str, pos, pos) == ']' then return arr, pos + 1 end

    while pos <= strlen(str) do
        pos = SkipWhitespace(str, pos)
        local val
        val, pos = ParseValue(str, pos)
        tinsert(arr, val)

        pos = SkipWhitespace(str, pos)
        local ch = strsub(str, pos, pos)
        if ch == ']' then return arr, pos + 1 end
        if ch == ',' then pos = pos + 1 end
    end
    return nil, pos
end

local function ParseJSON(str)
    if type(str) ~= "string" then return nil end
    str = str:match("^%s*(.-)%s*$")
    if str == "" then return nil end
    local val = ParseValue(str, 1)
    return val
end

-- Detect whether the input is a web UI JSON blob
function ts.WebUITalents.IsJSON(input)
    local trimmed = input:match("^%s*(.-)%s*$")
    return strsub(trimmed, 1, 1) == "{"
end

-- Detect whether the input is a web UI URL
function ts.WebUITalents.IsURL(input)
    return strfind(input, "talentplanner%.app") ~= nil
        or strfind(input, "#b/") ~= nil
end

-- Import from JSON blob
function ts.WebUITalents.ImportJSON(input)
    local data = ParseJSON(input)
    if type(data) ~= "table" then
        return nil, nil, "INVALID_JSON"
    end

    local classToken = data.classToken
    if type(classToken) ~= "string" or classToken == "" then
        return nil, nil, "IMPORT_FAILED"
    end

    local talents = data.talents
    if type(talents) ~= "table" or #talents == 0 then
        return nil, classToken, "IMPORT_FAILED"
    end

    local flavorKey = data.flavor
    if type(flavorKey) ~= "string" or flavorKey == "" then
        flavorKey = ts.Flavor.GetKey()
    end

    -- Reject imports built for a different ruleset than this client.
    if flavorKey ~= ts.Flavor.GetKey() then
        return nil, classToken, "FLAVOR_MISMATCH"
    end

    local result = {}
    for i, t in ipairs(talents) do
        if type(t) == "number" then
            local spellId = t
            local resolved = ts.TalentResolver.Resolve(spellId, classToken)
            if not resolved then
                return nil, classToken, "MAPPING_FAILED"
            end
            tinsert(result, {
                tab = resolved.tab,
                index = resolved.index,
                rank = resolved.rank,
                level = ts.Flavor.GetTalentPointLevel(flavorKey, i),
                spellId = spellId,
            })
        elseif type(t) == "table" then
            if t.spellId then
                local resolved = ts.TalentResolver.Resolve(t.spellId, classToken)
                if not resolved then
                    return nil, classToken, "MAPPING_FAILED"
                end
                tinsert(result, {
                    tab = resolved.tab,
                    index = resolved.index,
                    rank = resolved.rank,
                    level = t.level or ts.Flavor.GetTalentPointLevel(flavorKey, i),
                    spellId = t.spellId,
                })
            elseif t.tab and t.index and t.rank and t.level then
                tinsert(result, {
                    tab = t.tab,
                    index = t.index,
                    rank = t.rank,
                    level = t.level,
                    spellId = ts.TalentResolver.GetSpellId(classToken, t.tab, t.index, t.rank),
                })
            else
                return nil, classToken, "IMPORT_FAILED"
            end
        else
            return nil, classToken, "IMPORT_FAILED"
        end
    end

    return result, classToken
end

-- Import from URL hash
function ts.WebUITalents.ImportURL(input)
    -- Extract the hash fragment
    local hash = input:match("#(.+)$")
    if not hash then
        return nil, nil, "INVALID_URL"
    end

    -- Current format: #b/<base64-json>
    local base64Data = hash:match("^b/(.+)$")
    if not base64Data then
        return nil, nil, "INVALID_URL"
    end

    local json = DecodeBase64(base64Data)
    if not json then
        return nil, nil, "IMPORT_FAILED"
    end

    return ts.WebUITalents.ImportJSON(json)
end

-- Main entry point: detect format and import
function ts.WebUITalents.GetTalents(input)
    if ts.WebUITalents.IsJSON(input) then
        return ts.WebUITalents.ImportJSON(input)
    end
    return ts.WebUITalents.ImportURL(input)
end
