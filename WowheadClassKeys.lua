local _, ts = ...

--[[
Each talent tree has a unique index make up so each
class's spec's talents need to be outlined with the following macro:

/run for i = 1, GetNumTalentTabs() do for j = 1, GetNumTalents(i) do print(i, j, GetTalentInfo(i, j)) end end

The resulting information needs to then be split into its respective specs, ordered by 'column', then ordered
by 'tier' (https://wowpedia.fandom.com/wiki/API_GetTalentInfo/Classic).

Once you have them ordered by 'tier' and 'column', they will be listed in the same order that the Wowhead url
is generated. Take the wowhead characters, 'abcdefghjkmnpqrstvw', line them up with their respective talent,
then sort by 'talentIndex'. 

***USED BY WowheadTalents.lua TO ADD TALENTS TO TABLE***
***USED BY TalentSequence.lua TO CREATE/VALIDATE/ORDER CLASSES INTO TalentSequenceSavedSequences TABLE***
 
]]
ts.ClassTreeKeys = {
    {
        ["class"] = "druid",
        ["spec1"] = "baekghqndjprfmsc",     -- Balance
        ["spec2"] = "ebadhcmnjkgpfrsq",     -- Feral
        ["spec3"] = "abdcqegnfkmhpjr"       -- Restoration
	}, -- Druid 
    {
        ["class"] = "hunter",
        ["spec1"] = "dagkspnbqhmejrcf",     -- Beast Mastery
        ["spec2"] = "abcdefmhjngkqp",       -- Marksmanship
        ["spec3"] = "brdfgjnmcqpkseha"      -- Survival
    }, -- Hunter
    {
        ["class"] = "mage",
        ["spec1"] = "afbqdchgkjpsmrne",     -- Arcane
        ["spec2"] = "jmkaedhbgqpcrsfn",     -- Fire
        ["spec3"] = "behfkrgnpsjatqdmc"     -- Frost
    }, -- Mage
    {
        ["class"] = "paladin",
        ["spec1"] = "cmfgekbajdnqph",       -- Holy
        ["spec2"] = "baehdpqrnfgkmjc",      -- Protection
        ["spec3"] = "aqembpngrdhckfj"       -- Retribution
    }, -- Paladin
    {
        ["class"] = "priest",
        ["spec1"] = "frkaedbjhgmpcnq",      -- Discipline
        ["spec2"] = "hcqmrbkadnfepjgs",     -- Holy
        ["spec3"] = "mrebacgdjphsnfkq"      -- Shadow
    }, -- Priest
    {
        ["class"] = "rogue",
        ["spec1"] = "mjcbdeafhpngqrk",      -- Assassination
        ["spec2"] = "fmspcebdagwknjqrhvt",  -- Combat
        ["spec3"] = "aefjdbkhqpgtrmcns"     -- Subtlety
    }, -- Rogue
    {
        ["class"] = "shaman",
        ["spec1"] = "ehbapjcrfgqdnkm",      -- Elemental
        ["spec2"] = "jkefcgpbdamqhsrn",     -- Enhancement
        ["spec3"] = "dhfagkcrpqbmejn"       -- Restoration
    }, -- Shaman
    {
        ["class"] = "warlock",
        ["spec1"] = "hmbfacektpsjqrdng",    -- Affliction
        ["spec2"] = "abcdehkjfgrqmtpsn",    -- Demonology
        ["spec3"] = "bcaphkmrqsgdefjn"      -- Destruction
    }, -- Warlock
    {
        ["class"] = "warrior",
        ["spec1"] = "jraqdcftbgnpsvkhem",   -- Arms
        ["spec2"] = "hmsbadfcpetngrkqj",    -- Fury
        ["spec3"] = "bdecnjgkhtrpmqfsa"     -- Protection
    }  -- Warrior
}
