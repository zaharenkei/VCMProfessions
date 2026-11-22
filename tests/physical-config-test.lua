local root = [[Contents\mods\VCMProfessions\42.22\media\lua\shared\]]
package.path = root .. [[?.lua;]] .. package.path
package.loaded.VCMProfessionsProfessionTraits = true
VCMProfessionsProfessionTraits = {
    professionForPlayer = function(player) return player.profession end,
    grantedTraitSet = function(profession) return profession.granted end,
}

local callbacks = {}
Events = {}
for _, name in ipairs({ "AddXP", "OnCreatePlayer", "LevelPerk", "OnTick" }) do
    Events[name] = { Add = function(callback) callbacks[name] = callback end }
end
Perks = {
    None = "None", Strength = "Strength", Fitness = "Fitness", Axe = "Axe",
    PlantScavenging = "PlantScavenging",
    getMaxIndex = function() return 4 end,
    fromIndex = function(index) return ({ "Strength", "Fitness", "Axe", "PlantScavenging" })[index + 1] end,
}
CharacterTrait = { HERBALIST = "herbalist" }
PerkFactory = {
    getPerk = function(perk)
        return { getParent = function() return "Physical" end, getType = function() return perk end }
    end,
}
CharacterStat = { FITNESS = "FitnessStat" }
function instanceof(_, class) return class == "IsoPlayer" end
local client = false
local sentCommands = {}
function isClient() return client end
function sendClientCommand(player, module, command)
    sentCommands[#sentCommands + 1] = { player = player, module = module, command = command }
end
function transformIntoKahluaTable(map) return map end
local function number(value) return { intValue = function() return value end } end
local traitDefinitions = {
    { getType = function() return "axe_novice" end,
      getXpBoosts = function() return { Axe = number(1) } end },
    { getType = function() return "bonus" end,
      getXpBoosts = function() return { Axe = number(2), PlantScavenging = number(2) } end },
    { getType = function() return "herbalist" end,
      getXpBoosts = function() return { PlantScavenging = number(1) } end },
    { getType = function() return "foraging_novice" end,
      getXpBoosts = function() return { PlantScavenging = number(1) } end },
}
CharacterTraitDefinition = { getTraits = function()
    return { size = function() return #traitDefinitions end,
        get = function(_, index) return traitDefinitions[index + 1] end }
end, getCharacterTraitDefinition = function(id)
    for _, definition in ipairs(traitDefinitions) do
        if definition:getType() == id then return definition end
    end
end }
CharacterProfessionDefinition = {
    getCharacterProfessionDefinition = function() return { getXpBoosts = function() return {} end } end,
}
VCMProfessionsTraitsBySkill = {
    Strength = { novice = "strength_novice", confident = "strength_confident", master = "strength_master" },
    Fitness = { novice = "fitness_novice", confident = "fitness_confident", master = "fitness_master" },
    Axe = { novice = "axe_novice", confident = "axe_confident", master = "axe_master" },
    PlantScavenging = { novice = "foraging_novice", confident = "foraging_confident", master = "foraging_master" },
}
SandboxVars = { VCMProfessions = {
    StrengthNoviceCost = 8, FitnessNoviceCost = 2,
    PhysicalNoviceLevel = 7, FitnessNoviceLevel = 3,
    PhysicalNoviceCap = 6, FitnessNoviceCap = 2,
} }

require "VCMProfessionsProgression"
local config = VCMProfessionsConfig
assert(not config.professionalTraitsEnabled())
assert(not config.traitModuleEnabled("Foraging") and not config.traitModuleEnabled("Property"))
assert(not config.hideVanillaTraits() and not config.hideOtherModTraits())
SandboxVars.VCMProfessions.ProfessionalTraitsEnabled = true
SandboxVars.VCMProfessions.HideVanillaTraits = true
assert(not config.traitModuleEnabled("Foraging") and not config.hideVanillaTraits())
assert(config.cost("Strength", "novice") == 8)
assert(config.cost("Fitness", "novice") == 2)
assert(config.cap("Strength", "novice") == 6)
assert(config.cap("Fitness", "novice") == 2)
assert(config.physicalStartLevel("Strength", "novice") == 6)
assert(config.physicalStartLevel("Fitness", "novice") == 2)

local function player(initialized, extraTraits)
    local data = { VCMProfessionsInitialLevelsApplied = initialized }
    local levels = { Strength = 5, Fitness = 5, Axe = 0, PlantScavenging = 0 }
    local xp = {
        boosts = { Axe = 0 },
        setXPToLevel = function(_, perk, level) levels[perk .. "XP"] = level end,
        getPerkBoost = function(self, perk) return self.boosts[perk] or 0 end,
        setPerkBoost = function(self, perk, value) self.boosts[perk] = value end,
    }
    local stats = { set = function(_, key, value) levels[key] = value end }
    return {
        levels = levels,
        getModData = function() return data end,
        getPerkLevel = function(_, perk) return levels[perk] end,
        setPerkLevelDebug = function(_, perk, level) levels[perk] = level end,
        getXp = function() return xp end,
        getStats = function() return stats end,
        getHoursSurvived = function(self) return self.hours or 0 end,
        getUsername = function() return "test-player" end,
        getDescriptor = function() return { getCharacterProfession = function() return "unemployed" end } end,
        getCharacterTraits = function()
            local known = { "strength_novice", "fitness_novice" }
            for trait, present in pairs(extraTraits or {}) do
                if present then known[#known + 1] = trait end
            end
            return { getKnownTraits = function()
                return { size = function() return #known end, get = function(_, i) return known[i + 1] end }
            end }
        end,
        hasTrait = function(_, trait)
            return trait == "strength_novice" or trait == "fitness_novice"
                or (extraTraits and extraTraits[trait]) or false
        end,
    }
end

local newPlayer = player(false)
callbacks.OnCreatePlayer(0, newPlayer)
assert(newPlayer.levels.Strength == 6 and newPlayer.levels.StrengthXP == 6)
assert(newPlayer.levels.Fitness == 2 and newPlayer.levels.FitnessXP == 2)
assert(newPlayer.levels.FitnessStat == -0.6)
newPlayer.levels.Strength = 7
callbacks.LevelPerk(newPlayer, Perks.Strength, 7, true)
assert(newPlayer.levels.Strength == 7)
callbacks.OnTick()
assert(newPlayer.levels.Strength == 6 and newPlayer.levels.StrengthXP == 6)
newPlayer.levels.Fitness = 3
callbacks.LevelPerk(newPlayer, Perks.Fitness, 3, true)
callbacks.OnTick()
assert(newPlayer.levels.Fitness == 2 and newPlayer.levels.FitnessXP == 2)

local existing = player(true)
existing.levels.Strength = 3
existing.levels.Fitness = 1
callbacks.OnCreatePlayer(0, existing)
assert(existing.levels.Strength == 3 and existing.levels.Fitness == 1)

SandboxVars.VCMProfessions.PhysicalCappingEnabled = false
assert(config.cap("Strength", "novice") == nil and config.cap("Fitness", "novice") == nil)
assert(config.physicalStartLevel("Strength", "novice") == 7)
assert(config.physicalStartLevel("Fitness", "novice") == 3)
local uncapped = player(false)
callbacks.OnCreatePlayer(0, uncapped)
assert(uncapped.levels.Strength == 7 and uncapped.levels.Fitness == 3)

SandboxVars.VCMProfessions.PhysicalCappingEnabled = true
SandboxVars.VCMProfessions.PhysicalEnabled = false
assert(config.cap("Strength", "novice") == nil and config.cap("Fitness", "novice") == nil)
local disabled = player(false)
callbacks.OnCreatePlayer(0, disabled)
assert(disabled.levels.Strength == 5 and disabled.levels.Fitness == 5)

SandboxVars.VCMProfessions.UnexperiencedSkillLevel = 2
SandboxVars.VCMProfessions.UnqualifiedSkillCap = 10
local unexperienced = player(false, { bonus = true })
unexperienced.levels.Axe = 2
unexperienced:getXp().boosts.Axe = 2
callbacks.OnCreatePlayer(0, unexperienced)
assert(unexperienced.levels.Axe == 4 and unexperienced:getXp().boosts.Axe == 3)

SandboxVars.VCMProfessions.NoviceSkillLevel = 4
SandboxVars.VCMProfessions.NoviceSkillCap = 4
local novice = player(false, { bonus = true, axe_novice = true })
novice.levels.Axe = 3
novice:getXp().boosts.Axe = 3
callbacks.OnCreatePlayer(0, novice)
assert(novice.levels.Axe == 4 and novice:getXp().boosts.Axe == 3)

local alreadyInitialized = player(true, { bonus = true })
alreadyInitialized.levels.Axe = 2
callbacks.OnCreatePlayer(0, alreadyInitialized)
assert(alreadyInitialized.levels.Axe == 2)

client = true
local multiplayer = player(false, { bonus = true, axe_novice = true })
multiplayer.levels.Axe = 3
multiplayer:getXp().boosts.Axe = 3
callbacks.OnCreatePlayer(0, multiplayer)
assert(#sentCommands == 1 and sentCommands[1].player == multiplayer)
assert(sentCommands[1].module == "VCMProfessions" and sentCommands[1].command == "InitializeSkills")
VCMProfessionsProgression.initializeServerPlayer(multiplayer)
assert(multiplayer.levels.Axe == 4)
multiplayer.levels.Axe = 2
VCMProfessionsProgression.initializeServerPlayer(multiplayer)
assert(multiplayer.levels.Axe == 2)
local late = player(false, { axe_novice = true })
late.hours = 1
late.levels.Axe = 1
VCMProfessionsProgression.initializeServerPlayer(late)
assert(late.levels.Axe == 1 and not late:getModData().VCMProfessionsServerInitialLevelsApplied)
SandboxVars.VCMProfessions.UnexperiencedSkillLevel = 0
SandboxVars.VCMProfessions.UnqualifiedSkillCap = 10
local serverHerbalist = player(false, { herbalist = true, bonus = true })
serverHerbalist.levels.PlantScavenging = 3
serverHerbalist:getXp().boosts.PlantScavenging = 3
VCMProfessionsProgression.initializeServerPlayer(serverHerbalist)
assert(serverHerbalist.levels.PlantScavenging == 3)
assert(serverHerbalist:getXp().boosts.PlantScavenging == 3)
local serverRanked = player(false, { herbalist = true, foraging_novice = true })
serverRanked.levels.PlantScavenging = 2
serverRanked:getXp().boosts.PlantScavenging = 2
VCMProfessionsProgression.initializeServerPlayer(serverRanked)
assert(serverRanked.levels.PlantScavenging == 4)
assert(serverRanked:getXp().boosts.PlantScavenging == 3)
SandboxVars.VCMProfessions.ForagingTraitsEnabled = false
SandboxVars.VCMProfessions.UnexperiencedSkillLevel = 2
local vanillaHerbalist = player(false, { herbalist = true, bonus = true })
vanillaHerbalist.levels.PlantScavenging = 3
VCMProfessionsProgression.initializeServerPlayer(vanillaHerbalist)
assert(vanillaHerbalist.levels.PlantScavenging == 5)
local existingHerbalist = player(false, { herbalist = true })
existingHerbalist.hours = 1
existingHerbalist.levels.PlantScavenging = 3
VCMProfessionsProgression.initializeServerPlayer(existingHerbalist)
assert(existingHerbalist.levels.PlantScavenging == 3)
local professionPlayer = player(false, { bonus = true, herbalist = true })
professionPlayer.profession = { granted = { herbalist = true } }
professionPlayer.levels.PlantScavenging = 2
professionPlayer:getXp().boosts.PlantScavenging = 2
VCMProfessionsProgression.initializeServerPlayer(professionPlayer)
assert(professionPlayer.levels.PlantScavenging == 4)
assert(professionPlayer:getXp().boosts.PlantScavenging == 3)
print("Skill configuration and client/server initialization tests passed")
