require "VCMProfessionsConfig"
require "VCMProfessionsCrafting"

VCMProfessionsTraits = {}
VCMProfessionsTraitGroups = {}

local personalityGroup = "VCM Professions Personality"
local weaponGroup = "VCM Professions Weapons"
local professionsGroup = "VCM Professions"

local definitions = {
    { CharacterTrait.BURGLAR, "UI_prof_Burglar", 3, personalityGroup, "Personality" },
    { CharacterTrait.DESENSITIZED, "UI_trait_Desensitized", 4, personalityGroup, "Personality" },
    { CharacterTrait.NIGHT_OWL, "UI_trait_nightowl", 2, personalityGroup, "Personality" },
    { CharacterTrait.MARKSMAN, "UI_trait_marksman", 3, weaponGroup, "Weapons" },
    { CharacterTrait.HERBALIST, "UI_trait_Herbalist", nil, professionsGroup, "Foraging" },
}

local personalityTraits = {
    CharacterTrait.INVENTIVE, CharacterTrait.NUTRITIONIST, CharacterTrait.SPEED_DEMON,
    CharacterTrait.SUNDAY_DRIVER, CharacterTrait.HIGH_THIRST, CharacterTrait.LOW_THIRST,
    CharacterTrait.HEARTY_APPETITE, CharacterTrait.LIGHT_EATER, CharacterTrait.RESILIENT,
    CharacterTrait.PRONE_TO_ILLNESS, CharacterTrait.FAST_READER, CharacterTrait.SLOW_READER,
    CharacterTrait.WEAK_STOMACH, CharacterTrait.IRON_GUT, CharacterTrait.OUTDOORSMAN,
    CharacterTrait.DEXTROUS, CharacterTrait.NEEDS_LESS_SLEEP, CharacterTrait.CRAFTY,
    CharacterTrait.GRACEFUL, CharacterTrait.ADRENALINE_JUNKIE, CharacterTrait.INCONSPICUOUS,
    CharacterTrait.ORGANIZED, CharacterTrait.BRAVE, CharacterTrait.FAST_LEARNER,
    CharacterTrait.FAST_HEALER, CharacterTrait.THICK_SKINNED, CharacterTrait.ALL_THUMBS,
    CharacterTrait.CLUMSY, CharacterTrait.COWARDLY, CharacterTrait.SLOW_HEALER,
    CharacterTrait.SMOKER, CharacterTrait.AGORAPHOBIC, CharacterTrait.CLAUSTROPHOBIC,
    CharacterTrait.CONSPICUOUS, CharacterTrait.NEEDS_MORE_SLEEP, CharacterTrait.HEMOPHOBIC,
    CharacterTrait.PACIFIST, CharacterTrait.ASTHMATIC, CharacterTrait.NIGHT_VISION,
    CharacterTrait.EAGLE_EYED, CharacterTrait.KEEN_HEARING, CharacterTrait.SHORT_SIGHTED,
    CharacterTrait.HARD_OF_HEARING, CharacterTrait.INSOMNIAC, CharacterTrait.DISORGANIZED,
    CharacterTrait.SLOW_LEARNER, CharacterTrait.THIN_SKINNED, CharacterTrait.ILLITERATE,
    CharacterTrait.DEAF,
}

local originals = {}
local replacements = {}

function VCMProfessionsTraits.grantsSkillLevels(definition, visited)
    if not definition then
        error("VCM Professions: missing granted trait definition")
    end
    visited = visited or {}
    local trait = definition:getType()
    if visited[trait] then return false end
    visited[trait] = true
    for _, amount in pairs(transformIntoKahluaTable(definition:getXpBoosts())) do
        if amount:intValue() ~= 0 then return true end
    end
    local granted = definition:getGrantedTraits()
    for i = 0, granted:size() - 1 do
        local child = CharacterTraitDefinition.getCharacterTraitDefinition(granted:get(i))
        if VCMProfessionsTraits.grantsSkillLevels(child, visited) then return true end
    end
    return false
end

local craftingIcons = {
    cook = CharacterTrait.COOK,
    fisher = CharacterTrait.FISHING,
    farmer = CharacterTrait.HIKER,
    welder = CharacterTrait.MECHANICS,
    carpenter = CharacterTrait.HANDY,
    carver = CharacterTrait.WHITTLER,
    blacksmith = CharacterTrait.BLACKSMITH,
    knapper = CharacterTrait.HUNTER,
    glassmaker = CharacterTrait.ARTISAN,
}

local craftingExtraDescriptions = {
    farmer = "UI_VCMProfessions_CraftingFarmerExtra",
    mechanic = "UI_VCMProfessions_CraftingMechanicExtra",
    electrician = "UI_VCMProfessions_CraftingElectricianExtra",
}

local function configureCrafting()
    local recipes = VCMProfessionsCrafting.recipes()
    for name, trait in pairs(VCMProfessionsCraftingTraits) do
        local texture
        local iconTrait = craftingIcons[name]
        if iconTrait then
            local iconDefinition = CharacterTraitDefinition.getCharacterTraitDefinition(iconTrait)
            if not iconDefinition then
                error("VCM Professions: missing icon trait definition for " .. name)
            end
            texture = iconDefinition:getTexture()
        else
            texture = getTexture("media/ui/Traits/trait_crafting_" .. name .. ".png")
        end
        if not texture then
            error("VCM Professions: missing crafting trait icon for " .. name)
        end
        local definition = CharacterTraitDefinition.addCharacterTraitDefinition(
            trait, "UI_trait_vcmprofessions_crafting_" .. name,
            VCMProfessionsConfig.craftingTraitCost(), "", false, false
        )
        definition:setTexture(texture)
        local description = getText("UI_VCMProfessions_CraftingDescription", #recipes[name])
        if craftingExtraDescriptions[name] then
            description = description .. getText(craftingExtraDescriptions[name])
        end
        definition:setDescription(description)
        for _, recipe in ipairs(recipes[name]) do
            definition:addGrantedRecipe(recipe)
        end
        for _, knowledge in ipairs(VCMProfessionsCrafting.extraKnowledge(name)) do
            definition:addGrantedRecipe(knowledge)
        end
        VCMProfessionsTraitGroups[trait] = VCMProfessionsConfig.traitModuleEnabled("Crafting")
            and "VCM Professions Crafting" or nil
    end
end

local function configureGenerator()
    local icon = CharacterTraitDefinition.getCharacterTraitDefinition(CharacterTrait.MECHANICS)
    if not icon or not icon:getTexture() then
        error("VCM Professions: missing generator knowledge icon")
    end
    local definition = CharacterTraitDefinition.addCharacterTraitDefinition(
        VCMProfessionsGeneratorTrait, "UI_trait_vcmprofessions_generator", 1, "", false, false
    )
    definition:setTexture(icon:getTexture())
    definition:setDescription(getText("UI_VCMProfessions_GeneratorDescription"))
    definition:addGrantedRecipe("Generator")
    VCMProfessionsTraitGroups[VCMProfessionsGeneratorTrait] =
        VCMProfessionsConfig.traitModuleEnabled("Personality") and professionsGroup or nil
end

local function configureForaging()
    local specs = {
        { "perceptive", 2, CharacterTrait.EAGLE_EYED, "blind" },
        { "blind", -2, CharacterTrait.SHORT_SIGHTED, "perceptive" },
    }
    for _, spec in ipairs(specs) do
        local trait = VCMProfessionsForagingTraits[spec[1]]
        local icon = CharacterTraitDefinition.getCharacterTraitDefinition(spec[3])
        if not icon or not icon:getTexture() then
            error("VCM Professions: missing foraging trait icon for " .. spec[1])
        end
        local definition = CharacterTraitDefinition.addCharacterTraitDefinition(
            trait, "UI_trait_vcmprofessions_foraging_" .. spec[1], spec[2], "", false, false
        )
        definition:setTexture(icon:getTexture())
        definition:setDescription(getText("UI_VCMProfessions_Foraging_" .. spec[1]))
        if spec[4] then
            definition:addMutuallyExclusive(VCMProfessionsForagingTraits[spec[4]])
        end
        VCMProfessionsTraitGroups[trait] = VCMProfessionsConfig.traitModuleEnabled("Foraging")
            and professionsGroup or nil
    end
end

local function configureProperty()
    local specs = {
        { "homeless", -3, CharacterTrait.OUTDOORSMAN },
        { "poor", -1, CharacterTrait.INCONSPICUOUS },
        { "successful", 2, CharacterTrait.ORGANIZED },
    }
    for _, spec in ipairs(specs) do
        local trait = VCMProfessionsPropertyTraits[spec[1]]
        local icon = CharacterTraitDefinition.getCharacterTraitDefinition(spec[3])
        if not icon or not icon:getTexture() then
            error("VCM Professions: missing property trait icon for " .. spec[1])
        end
        local definition = CharacterTraitDefinition.addCharacterTraitDefinition(
            trait, "UI_trait_vcmprofessions_property_" .. spec[1], spec[2], "", false, false
        )
        definition:setTexture(icon:getTexture())
        definition:setDescription(getText("UI_VCMProfessions_Property_" .. spec[1]))
        for _, other in pairs(VCMProfessionsPropertyTraits) do
            if other ~= trait then definition:addMutuallyExclusive(other) end
        end
        VCMProfessionsTraitGroups[trait] = VCMProfessionsConfig.traitModuleEnabled("Property")
            and professionsGroup or nil
    end
end

function VCMProfessionsTraits.customTraitEnabled(trait)
    if trait == VCMProfessionsGeneratorTrait then
        return VCMProfessionsConfig.traitModuleEnabled("Personality")
    end
    for _, craftingTrait in pairs(VCMProfessionsCraftingTraits) do
        if trait == craftingTrait then
            return VCMProfessionsConfig.traitModuleEnabled("Crafting")
        end
    end
    for _, foragingTrait in pairs(VCMProfessionsForagingTraits) do
        if trait == foragingTrait then
            return VCMProfessionsConfig.traitModuleEnabled("Foraging")
        end
    end
    for _, propertyTrait in pairs(VCMProfessionsPropertyTraits) do
        if trait == propertyTrait then
            return VCMProfessionsConfig.traitModuleEnabled("Property")
        end
    end
    return nil
end

local function copyDefinition(original, spec)
    local replacement = CharacterTraitDefinition.addCharacterTraitDefinition(
        spec[1], spec[2], spec[3] or original:getCost(), "", false, original:isDisabledInMultiplayer()
    )
    local description = original:getDescription()
    if spec[1] == CharacterTrait.HERBALIST then
        local foragingBoost = transformIntoKahluaTable(original:getXpBoosts())[Perks.PlantScavenging]
        if foragingBoost and description then
            local amount = foragingBoost:intValue()
            local line = (amount > 0 and "+" or "") .. tostring(amount)
                .. " " .. PerkFactory.getPerkName(Perks.PlantScavenging)
            local lines = {}
            for entry in (description .. "\n"):gmatch("(.-)\n") do
                if entry ~= line then lines[#lines + 1] = entry end
            end
            description = table.concat(lines, "\n")
        end
    end
    replacement:setDescription(description)
    replacement:setTexture(original:getTexture())
    replacement:getGrantedRecipes():addAll(original:getGrantedRecipes())
    replacement:getMutuallyExclusiveTraits():addAll(original:getMutuallyExclusiveTraits())
    replacement:getXpBoosts():putAll(original:getXpBoosts())
    if spec[1] == CharacterTrait.HERBALIST then
        replacement:getXpBoosts():remove(Perks.PlantScavenging)
    end
    local granted = original:getGrantedTraits()
    for i = 0, granted:size() - 1 do
        replacement:addGrantedTrait(granted:get(i))
    end
    return replacement
end

function VCMProfessionsTraits.updateVisibilityGroups()
    local metabolismGroup = VCMProfessionsConfig.traitModuleEnabled("Weight") and professionsGroup or nil
    VCMProfessionsTraitGroups[CharacterTrait.WEIGHT_GAIN] = metabolismGroup
    VCMProfessionsTraitGroups[CharacterTrait.WEIGHT_LOSS] = metabolismGroup
end

function VCMProfessionsTraits.configure()
    configureCrafting()
    configureGenerator()
    configureForaging()
    configureProperty()
    for _, spec in ipairs(definitions) do
        local trait = spec[1]
        local current = CharacterTraitDefinition.getCharacterTraitDefinition(trait)
        if VCMProfessionsConfig.traitModuleEnabled(spec[5]) then
            if not current then
                error("VCM Professions: missing trait definition for " .. tostring(trait))
            end

            if current ~= replacements[trait] then
                originals[trait] = current
                replacements[trait] = copyDefinition(current, spec)
            end
            VCMProfessionsTraitGroups[trait] = professionsGroup
        else
            if current == replacements[trait] and originals[trait] then
                CharacterTraitDefinition.characterTraitDefinitions:put(trait, originals[trait])
            end
            originals[trait] = nil
            replacements[trait] = nil
            VCMProfessionsTraitGroups[trait] = nil
        end
    end

    for _, trait in ipairs(personalityTraits) do
        VCMProfessionsTraitGroups[trait] = VCMProfessionsConfig.traitModuleEnabled("Personality")
            and professionsGroup or nil
    end

    VCMProfessionsTraits.updateVisibilityGroups()
end

Events.OnCreatePlayer.Add(function()
    configureCrafting()
    configureGenerator()
    configureForaging()
    configureProperty()
end)
