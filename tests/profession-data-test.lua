local root = [[Contents\mods\VCMProfessions\42.22\media\lua\shared\]]
function transformIntoKahluaTable(map) return map end
local function number(value) return { intValue = function() return value end } end
local function list(values)
    return {
        size = function() return #values end,
        get = function(_, index) return values[index + 1] end,
    }
end
local function definition(cost, boosts, traits)
    return {
        getCost = function() return cost end,
        getXpBoosts = function() return boosts end,
        getGrantedTraits = function() return list(traits) end,
    }
end
local traitDefinitions = {
    herbalist = definition(0, { Foraging = number(1) }, {}),
    nested = definition(0, { Axe = number(2) }, { "shared" }),
    shared = definition(0, { Axe = number(1) }, { "nested" }),
}
CharacterTraitDefinition = {
    getCharacterTraitDefinition = function(id) return traitDefinitions[id] end,
}
dofile(root .. "VCMProfessionsProfessionData.lua")
local data = VCMProfessionsProfessionData
local burglar = definition(-6, { Nimble = number(2), Sneak = number(2), Lightfoot = number(2) }, {})
assert(data.traitCost(burglar) == 0)
local ranger = definition(-4, {
    Foraging = number(1), Trapping = number(1), Doctor = number(1),
    Carving = number(1), FlintKnapping = number(1),
}, { "herbalist" })
assert(data.skillBonuses(ranger).Foraging == 2 and data.traitCost(ranger) == -2)
local modded = definition(2, { Axe = number(1) }, { "nested", "shared" })
assert(data.skillBonuses(modded).Axe == 4 and data.traitCost(modded) == -6)
local indirect = definition(2, { Axe = number(1) }, { "nested", "nested" })
assert(data.skillBonuses(indirect).Axe == 3 and data.traitCost(indirect) == -5)
local missing = definition(0, {}, { "missing" })
local ok, message = pcall(data.skillBonuses, missing)
assert(not ok and message:find("missing profession%-granted trait definition"))
print("Profession pricing counts direct granted traits once and excludes indirect grants")
