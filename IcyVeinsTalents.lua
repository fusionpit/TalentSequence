local _, ts = ...

local strlen = strlen
local strsub = strsub
local strfind = strfind
local strlower = strlower
local tinsert = tinsert
local UnitClass = UnitClass

local talentMap = {
    -- list of characters, in order, being used by Icy Veins when calculating talents (modified for lua issues I don't know lua well enough to fix)
    talentEncoding = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-*_~+",
    ["druid"] = {
        tabOne = 21,
        tabTwo = 42
    },
    ["hunter"] = {
        tabOne = 21,
        tabTwo = 41
    },
    ["mage"] = {
        tabOne = 23,
        tabTwo = 45
    },
    ["paladin"] = {
        tabOne = 20,
        tabTwo = 42
    },
    ["priest"] = {
        tabOne = 22,
        tabTwo = 43
    },
    ["rogue"] = {
        tabOne = 21,
        tabTwo = 45
    },
    ["shaman"] = {
        tabOne = 20,
        tabTwo = 41
    },
    ["warlock"] = {
        tabOne = 21,
        tabTwo = 43
    },
    ["warrior"] = {
        tabOne = 23,
        tabTwo = 44
    }
}

ts.IcyVeinsTalents = {}

function ts.IcyVeinsTalents.GetTalents(talentString)
    --- workaround for problematic characters
    talentString = talentString:gsub("%[", "+")
    talentString = talentString:gsub("%.", "*")

    local _, playerClass = UnitClass("player")
    playerClass = strlower(playerClass)
    local talentStringLength = strlen(talentString)
    local level = 9
    local talents = {}
    local talentCounter = {}
    for i = 1, talentStringLength, 1 do
        local encodedId = strsub(talentString, i, i)
        local talentIndex = strfind(talentMap.talentEncoding,encodedId)
        local classTabs = talentMap[playerClass]
        local talentTab = 1 
        if (talentIndex > classTabs.tabTwo) then
            talentTab = 3
            talentIndex = talentIndex - classTabs.tabTwo
        elseif (talentIndex > classTabs.tabOne) then
            talentTab = 2
            talentIndex = talentIndex - classTabs.tabOne
        end
        if (talentCounter[encodedId] == nil) then
            talentCounter[encodedId] = 1
        else
            talentCounter[encodedId] = talentCounter[encodedId] + 1
        end
        tinsert(talents,
        {
            tab = talentTab,
            id = encodedId,
            level = level + i,
            index = talentIndex,
            rank = talentCounter[encodedId]
        })

    end

    return talents
end