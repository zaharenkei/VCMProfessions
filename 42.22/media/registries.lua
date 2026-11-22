VCMProfessionsSkillNames = {
    "Aiming",
    "Axe",
    "Blacksmith",
    "Blunt",
    "Butchering",
    "Carving",
    "Cooking",
    "Doctor",
    "Electricity",
    "Farming",
    "Fishing",
    "Fitness",
    "FlintKnapping",
    "Glassmaking",
    "Husbandry",
    "Lightfoot",
    "LongBlade",
    "Maintenance",
    "Masonry",
    "Mechanics",
    "Melting",
    "MetalWelding",
    "Nimble",
    "PlantScavenging",
    "Pottery",
    "Reloading",
    "SmallBlade",
    "SmallBlunt",
    "Sneak",
    "Spear",
    "Sprinting",
    "Strength",
    "Tailoring",
    "Tracking",
    "Trapping",
    "Woodwork",
}

VCMProfessionsTraitsBySkill = {}
VCMProfessionsTraitSet = {}
VCMProfessionsBoostScratch = CharacterTrait.register("VCMProfessions:profession_boost_scratch")

VCMProfessionsCraftingTraits = {}
VCMProfessionsGeneratorTrait = CharacterTrait.register("VCMProfessions:generator_knowledge")
VCMProfessionsForagingTraits = {
    perceptive = CharacterTrait.register("VCMProfessions:perceptive_forager"),
    blind = CharacterTrait.register("VCMProfessions:blind_forager"),
}
VCMProfessionsPropertyTraits = {
    homeless = CharacterTrait.register("VCMProfessions:property_homeless"),
    poor = CharacterTrait.register("VCMProfessions:property_poor"),
    successful = CharacterTrait.register("VCMProfessions:property_successful"),
}
for _, name in ipairs({
    "cook", "trapper", "fisher", "farmer", "mechanic", "welder",
    "carpenter", "carver", "blacksmith", "knapper", "glassmaker",
    "tailor", "electrician",
}) do
    VCMProfessionsCraftingTraits[name] = CharacterTrait.register("VCMProfessions:crafting_" .. name)
end

-- Keep removed IDs registered so existing characters can still load them.
for _, name in ipairs({ "medic", "butcher", "rancher", "potter", "mason", "smelter", "forager", "repairer" }) do
    CharacterTrait.register("VCMProfessions:crafting_" .. name)
end

-- Trait IDs are persisted in existing characters and saved builds.
local legacyTierIds = { novice = "familiar", confident = "badat", master = "professional" }
for _, skillName in ipairs(VCMProfessionsSkillNames) do
    local traits = {}
    for _, tier in ipairs({ "novice", "confident", "master" }) do
        local trait = CharacterTrait.register("VCMProfessions:" .. legacyTierIds[tier] .. "_" .. string.lower(skillName))
        traits[tier] = trait
        VCMProfessionsTraitSet[trait] = true
    end
    VCMProfessionsTraitsBySkill[skillName] = traits
end
