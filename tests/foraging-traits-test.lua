local root = [[Contents\mods\VCMProfessions\42.22\media\lua\client\]]
package.loaded.VCMProfessionsConfig = true
package.loaded.VCMProfessionsCrafting = true
local enabled, propertyEnabled, personalityEnabled = true, true, false
VCMProfessionsConfig = {
    traitModuleEnabled = function(module)
        return (module == "Foraging" and enabled) or (module == "Property" and propertyEnabled)
            or (module == "Personality" and personalityEnabled)
    end,
    craftingTraitCost = function() return 1 end,
}
VCMProfessionsCrafting = { recipes = function() return {} end }
VCMProfessionsCraftingTraits = {}
VCMProfessionsGeneratorTrait = "generator"
VCMProfessionsForagingTraits = { perceptive = "perceptive", blind = "blind" }
VCMProfessionsPropertyTraits = { homeless = "homeless", poor = "poor", successful = "successful" }
CharacterTrait = setmetatable({}, {
    __index = function(t, key) rawset(t, key, key); return key end,
})
Perks = { PlantScavenging = "foraging", Cooking = "cooking" }
PerkFactory = { getPerkName = function(perk) return perk end }
function transformIntoKahluaTable(map) return map.values end
local definitions = {}
local function makeDefinition(id, cost)
    local function list()
        return {
            values = {},
            add = function(self, value) self.values[#self.values + 1] = value end,
            addAll = function(self, other)
                for _, value in ipairs(other.values) do self:add(value) end
            end,
            size = function(self) return #self.values end,
            get = function(self, index) return self.values[index + 1] end,
        }
    end
    local exclusions, recipes, granted = list(), list(), list()
    local boosts = {
        values = {},
        putAll = function(self, other)
            for key, value in pairs(other.values) do self.values[key] = value end
        end,
        remove = function(self, key) self.values[key] = nil end,
    }
    local object = {
        id = id, cost = cost, excluded = {},
        getType = function(self) return self.id end,
        getTexture = function() return "texture" end,
        setTexture = function() end,
        setDescription = function(self, value) self.description = value end,
        getDescription = function(self) return self.description end,
        getCost = function(self) return self.cost end,
        isDisabledInMultiplayer = function() return false end,
        getGrantedRecipes = function() return recipes end,
        getXpBoosts = function() return boosts end,
        getGrantedTraits = function() return granted end,
        addGrantedRecipe = function(_, recipe) recipes:add(recipe) end,
        addGrantedTrait = function(_, trait) granted:add(trait) end,
        addMutuallyExclusive = function(self, other) self.excluded[other] = true end,
        getMutuallyExclusiveTraits = function() return exclusions end,
    }
    object.description = "description"
    return object
end
CharacterTraitDefinition = {
    getCharacterTraitDefinition = function(id)
        definitions[id] = definitions[id] or makeDefinition(id, 4)
        return definitions[id]
    end,
    addCharacterTraitDefinition = function(id, _, cost)
        definitions[id] = makeDefinition(id, cost)
        return definitions[id]
    end,
    characterTraitDefinitions = { put = function(_, id, value) definitions[id] = value end },
}
local callbacks = 0
Events = { OnCreatePlayer = { Add = function() callbacks = callbacks + 1 end } }
function getText(key) return key end
dofile(root .. "VCMProfessionsTraits.lua")

local original = CharacterTraitDefinition.getCharacterTraitDefinition(CharacterTrait.HERBALIST)
original:getXpBoosts().values[Perks.PlantScavenging] = { intValue = function() return 1 end }
original:getXpBoosts().values[Perks.Cooking] = { intValue = function() return 2 end }
original:setDescription("herb knowledge\n+1 foraging\n+2 cooking")
original:addGrantedRecipe("Herbalist")
original:addGrantedTrait("test-trait")
original:getMutuallyExclusiveTraits():add("test-exclusive")
local burglar = CharacterTraitDefinition.getCharacterTraitDefinition(CharacterTrait.BURGLAR)
local parent = CharacterTraitDefinition.getCharacterTraitDefinition("parent")
local child = CharacterTraitDefinition.getCharacterTraitDefinition("child")
parent:addGrantedTrait("child")
child:addGrantedTrait("parent")
assert(not VCMProfessionsTraits.grantsSkillLevels(parent))
child:getXpBoosts().values[Perks.Cooking] = { intValue = function() return -1 end }
assert(VCMProfessionsTraits.grantsSkillLevels(parent))
assert(VCMProfessionsTraits.grantsSkillLevels(original))
VCMProfessionsTraits.configure()
assert(VCMProfessionsTraitGroups[CharacterTrait.HERBALIST] == "VCM Professions")
local replacement = CharacterTraitDefinition.getCharacterTraitDefinition(CharacterTrait.HERBALIST)
assert(replacement ~= original and replacement.cost == 4)
assert(replacement:getXpBoosts().values[Perks.PlantScavenging] == nil)
assert(replacement:getXpBoosts().values[Perks.Cooking]:intValue() == 2)
assert(replacement:getDescription() == "herb knowledge\n+2 cooking")
assert(replacement:getGrantedRecipes():get(0) == "Herbalist")
assert(replacement:getGrantedTraits():get(0) == "test-trait")
assert(replacement:getMutuallyExclusiveTraits():get(0) == "test-exclusive")
assert(original:getXpBoosts().values[Perks.PlantScavenging]:intValue() == 1)
VCMProfessionsTraits.configure()
assert(CharacterTraitDefinition.getCharacterTraitDefinition(CharacterTrait.HERBALIST) == replacement)
assert(original.cost == 4)
assert(VCMProfessionsTraitGroups.homeless == "VCM Professions")
assert(VCMProfessionsTraitGroups[CharacterTrait.UNDERWEIGHT] == nil)
assert(definitions.homeless.cost == -3 and definitions.poor.cost == -1 and definitions.successful.cost == 2)
assert(definitions.homeless.excluded.poor and definitions.homeless.excluded.successful)
propertyEnabled = false
enabled = false
VCMProfessionsTraits.configure()
assert(VCMProfessionsTraitGroups[CharacterTrait.HERBALIST] == nil)
assert(CharacterTraitDefinition.getCharacterTraitDefinition(CharacterTrait.HERBALIST) == original)
assert(VCMProfessionsTraits.customTraitEnabled("perceptive") == false)
assert(VCMProfessionsTraits.customTraitEnabled("homeless") == false)
assert(VCMProfessionsTraitGroups.homeless == nil and callbacks == 1)
enabled = true
VCMProfessionsTraits.configure()
assert(definitions[CharacterTrait.HERBALIST]:getXpBoosts().values[Perks.PlantScavenging] == nil)
enabled = false
VCMProfessionsTraits.configure()
assert(definitions[CharacterTrait.HERBALIST] == original)
VCMProfessionsForagingTraits = {}
propertyEnabled = true
assert(VCMProfessionsTraits.customTraitEnabled("homeless") == true)
VCMProfessionsForagingTraits = { perceptive = "perceptive", blind = "blind" }
personalityEnabled = true
VCMProfessionsTraits.configure()
assert(definitions[CharacterTrait.BURGLAR].cost == 3)
assert(definitions[CharacterTrait.DESENSITIZED].cost == 4)
assert(definitions[CharacterTrait.NIGHT_OWL].cost == 2)
personalityEnabled = false
VCMProfessionsTraits.configure()
assert(definitions[CharacterTrait.BURGLAR] == burglar)
print("Vanilla Herbalist grouping and foraging module tests passed")
