VCMProfessionsConfig = {}

local config = VCMProfessionsConfig
config.tiers = { "novice", "confident", "master" }
config.startLevels = { novice = 1, confident = 2, master = 3 }

local regularStartLevels = {
    unexperienced = { "UnexperiencedSkillLevel", 0 }, novice = { "NoviceSkillLevel", 1 },
    confident = { "ConfidentSkillLevel", 2 }, master = { "MasterSkillLevel", 3 },
}
local regularCosts = {
    novice = { "NoviceSkillCost", 1 },
    confident = { "ConfidentSkillCost", 2 },
    master = { "MasterSkillCost", 4 },
}
local strengthCosts = {
    novice = { "StrengthNoviceCost", 3 }, confident = { "StrengthConfidentCost", 6 },
    master = { "StrengthMasterCost", 9 },
}
local fitnessCosts = {
    novice = { "FitnessNoviceCost", 3 }, confident = { "FitnessConfidentCost", 6 },
    master = { "FitnessMasterCost", 9 },
}
local regularCaps = {
    unexperienced = { "UnqualifiedSkillCap", 2 }, novice = { "NoviceSkillCap", 4 },
    confident = { "ConfidentSkillCap", 6 }, master = { "MasterSkillCap", 10 },
}
local physicalCaps = {
    unexperienced = { "PhysicalUnexperiencedCap", 4 }, novice = { "PhysicalNoviceCap", 6 },
    confident = { "PhysicalConfidentCap", 8 }, master = { "PhysicalMasterCap", 10 },
}
local physicalStartLevels = {
    unexperienced = { "PhysicalUnexperiencedLevel", 4 }, novice = { "PhysicalNoviceLevel", 5 },
    confident = { "PhysicalConfidentLevel", 6 }, master = { "PhysicalMasterLevel", 8 },
}
local fitnessCaps = {
    unexperienced = { "FitnessUnexperiencedCap", 4 }, novice = { "FitnessNoviceCap", 6 },
    confident = { "FitnessConfidentCap", 8 }, master = { "FitnessMasterCap", 10 },
}
local fitnessStartLevels = {
    unexperienced = { "FitnessUnexperiencedLevel", 4 }, novice = { "FitnessNoviceLevel", 5 },
    confident = { "FitnessConfidentLevel", 6 }, master = { "FitnessMasterLevel", 8 },
}

local function numberOption(option, defaultValue, minValue, maxValue)
    local settings = SandboxVars and SandboxVars.VCMProfessions
    local value = settings and settings[option]
    if type(value) ~= "number" then
        value = defaultValue
    end
    return math.max(minValue, math.min(maxValue, math.floor(value)))
end

local function booleanOption(option, defaultValue)
    local settings = SandboxVars and SandboxVars.VCMProfessions
    local value = settings and settings[option]
    if type(value) ~= "boolean" then
        return defaultValue
    end
    return value
end

function config.isPhysical(skillName)
    return skillName == "Strength" or skillName == "Fitness"
end

function config.physicalEnabled()
    return booleanOption("PhysicalEnabled", true)
end

function config.disableSkillTraits()
    return booleanOption("DisableSkillTraits", true)
end

function config.professionalTraitsEnabled()
    return false
end

function config.traitModuleEnabled(module)
    return config.professionalTraitsEnabled() and booleanOption(module .. "TraitsEnabled", true)
end

function config.craftingTraitCost()
    return numberOption("CraftingTraitCost", 1, 1, 1000)
end

function config.craftingModRecipesEnabled()
    return booleanOption("CraftingModRecipesEnabled", true)
end

function config.hideVanillaTraits()
    return false
end

function config.hideOtherModTraits()
    return false
end

function config.cost(skillName, tier)
    if not tier then
        return 0
    end
    local costs = skillName == "Strength" and strengthCosts
        or skillName == "Fitness" and fitnessCosts or regularCosts
    local setting = costs[tier]
    return numberOption(setting[1], setting[2], 0, 1000)
end

function config.regularStartLevel(tier)
    local setting = regularStartLevels[tier or "unexperienced"]
    return numberOption(setting[1], setting[2], 0, 10)
end

function config.cap(skillName, tier)
    local physical = config.isPhysical(skillName)
    if physical then
        if not config.physicalEnabled() or not booleanOption("PhysicalCappingEnabled", true) then
            return nil
        end
    elseif not booleanOption("CappingEnabled", true) then
        return nil
    end
    local caps = skillName == "Fitness" and fitnessCaps or physical and physicalCaps or regularCaps
    local setting = caps[tier or "unexperienced"]
    return numberOption(setting[1], setting[2], 0, 10)
end

function config.physicalStartLevel(skillName, tier)
    local settings = skillName == "Fitness" and fitnessStartLevels or physicalStartLevels
    local setting = settings[tier or "unexperienced"]
    local level = numberOption(setting[1], setting[2], 0, 10)
    local cap = config.cap(skillName, tier)
    return cap and math.min(level, cap) or level
end
