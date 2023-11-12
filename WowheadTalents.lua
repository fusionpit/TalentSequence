local _, ts = ...

local strlen = strlen
local strsub = strsub
local strfind = strfind
local strlower = strlower
local tinsert = tinsert
local UnitClass = UnitClass
local GetTalentInfo = GetTalentInfo

ts.WowheadTalents = {}

local function strToTable(str) -- converts a string to a table for indexing each character
    local rTable = {}
    if (not str) then
        return nil
    end
    for i = 1, #str, 1 do
        rTable[i] = str:sub(i, i)
    end
    return rTable
end

function ts.WowheadTalents.GetTalents(rank, sequence, class)
    local urlOrder = "abcdefghjkmnpqrstvw" -- each character refers to the in-order talent selection up to 19 talents in a tree in the WoWhead Talent Calculator
    local spec1 = strToTable(rank[1]) -- Max selected ranks of each talent in first tree if any talents selected
    local spec2 = strToTable(rank[2]) -- ^ second tree
    local spec3 = strToTable(rank[3]) -- ^ third tree
    local specs = {spec1, spec2, spec3} -- Adding each spec in order to correspond to same indices as tabCI
    
    local currentTab = 0 -- Spec tab (1, 2, 3 -- Arcane, Fire, Frost)
    local talentStringLength = strlen(sequence) -- Used to iterate the appropriate number of times through the string
    local level = 9 -- Character level
    local talents = {}
    local talentCounter = {} -- Keeps track of how many ranks have been added to a particular talent
    local tabCI = {} -- Class Spec Tab Index → see WowheadClassKeys.lua for more info.

    for k, v in pairs(ts.ClassTreeKeys) do -- Grabs the class's index keys and assigns to tabCI
        if v.class == class then
            tabCI = {v.spec1, v.spec2, v.spec3}
        end
    end    
    
    for i = 1, talentStringLength, 1 do -- evaluates each character of the tab/talent key in the url
        local encodedId = strsub(sequence, i, i)
        if (strbyte(encodedId) <= 50) then -- set spec tab based on #s in the url, characters that follow belong to that spec
            currentTab = encodedId + 1
        else
            local talentIndex = strfind((tabCI[currentTab]),strlower(encodedId)) -- retrieves the in-game index for the talent referred to by the url (see WowheadClassKeys.lua for more info).
            local rankIndex = strfind(urlOrder, strlower(encodedId)) -- rankIndex will be used to match the same index of the rank listed in specs[spec1, 2, or 3] based on currentTab -- Removes the need for GetTalentInfo.
            -- Capitalized letters means the talent is selected maxRank-times until maxed.
            if (strbyte(encodedId) < 97) then -- checks for capital letter, adds maxRank number of entries of same talent for sequencing.
                local maxRank = specs[currentTab][rankIndex] -- Grabs the rank level from the spec-string associated with the maxed talent. 
                for j = 1, maxRank, 1 do
                    level = level + 1
                    tinsert(talents,
                    {
                        tab = currentTab,
                        id = encodedId,
                        level = level,
                        index = talentIndex,
                        rank = j
                    })
                end
            else -- adds all other talent selections in order
                level = level + 1
                local uniqueID = tostring(currentTab)..encodedId -- need to combine tab and encoded id as tabs share encodedIDs.
                if (talentCounter[uniqueID] == nil) then
                    talentCounter[uniqueID] = 1
                else
                    talentCounter[uniqueID] = talentCounter[uniqueID] + 1 -- keeps track of current rank of talents
                end
                tinsert(talents,
                {
                    tab = currentTab,
                    id = encodedId,
                    level = level,
                    index = talentIndex,
                    rank = talentCounter[uniqueID]
                })
            end
        end
    end
    return talents
end
