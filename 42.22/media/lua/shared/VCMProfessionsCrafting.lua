require "VCMProfessionsConfig"

VCMProfessionsCrafting = {}

local skillOwners = {
    Cooking = "cook", Trapping = "trapper", Fishing = "fisher", Farming = "farmer",
    Mechanics = "mechanic", MetalWelding = "welder", Woodwork = "carpenter",
    Carving = "carver", Blacksmith = "blacksmith",
    FlintKnapping = "knapper", Glassmaking = "glassmaker",
    Tailoring = "tailor", Electricity = "electrician",
}

local categoryOwners = {
    cooking = "cook", fishing = "fisher", farming = "farmer",
    vehicle = "mechanic", welding = "welder", metalworking = "welder",
    carpentry = "carpenter", carving = "carver", blacksmithing = "blacksmith",
    blade = "blacksmith", cookware = "blacksmith",
    knapping = "knapper", glassmaking = "glassmaker", tailoring = "tailor",
    electrical = "electrician",
}

local removedTags = {
    tanleather = true, removeflesh = true, removefur = true,
    dryleatherlarge = true, dryleathermedium = true, dryleathersmall = true,
}

local formerRepairerOwners = {
    BarbedWireWeapon = "carpenter", MakeBucketMaul = "carpenter", MakeKettleMaul = "carpenter",
    MakeRailspikeIronPipe = "carpenter", MakeRailspikeLongHandle = "carpenter",
    MakeRailspikeWeapon = "carpenter", MakeHollowBook = "carpenter",
    BindSpear = "carver", WireSpear = "carver", MakeBoneClub = "carver",
    MakeJawboneAxe = "carver", MakeJawboneClub = "carver", MakeToothbrushShiv = "carver",
    MakeCrudeWhetstone = "knapper", MakeGlassShiv = "glassmaker",
    MakeShiv = "blacksmith", MakeScrewdriver = "electrician",
}

local vanillaSeasons = {
    "barley", "basil", "bell pepper", "black sage", "broadleaf plantain", "broccoli",
    "cabbage", "carrot", "cauliflower", "chamomile", "chives", "cilantro", "comfrey",
    "common mallow", "corn", "cucumber", "flax", "garlic", "green pea", "habanero",
    "hemp", "hops", "jalapeno", "kale", "lavender", "leek", "lemongrass", "lettuce",
    "marigold", "mint", "onion", "oregano", "parsley", "poppy", "potato", "pumpkin",
    "radish", "rosemary", "rose", "rye", "sage", "soybean", "spinach", "strawberry",
    "sugar beet", "sunflower", "sweet potato", "thyme", "tobacco", "tomato", "turnip",
    "watermelon", "wheat", "wild garlic", "zucchini",
}

local function ownerFromPerk(entry)
    local perk = entry:getPerk()
    return perk and skillOwners[tostring(perk)] or nil
end

local function ownerFromSkills(recipe, count, getter)
    for i = 0, count - 1 do
        local owner = ownerFromPerk(getter(recipe, i))
        if owner then return owner end
    end
end

local function recipeOwner(recipe)
    if recipe:isVanilla() or recipe:getExistsAsVanilla() then
        local owner = formerRepairerOwners[recipe:getName()]
        if owner then return owner end
    end
    local tags = recipe:getTags()
    for i = 0, tags:size() - 1 do
        local tag = string.lower(tostring(tags:get(i)))
        if tag == "trapper" then return "trapper" end
        if removedTags[tag] then return nil end
    end

    local category = recipe:getCategory()
    category = category and string.lower(tostring(category))
    if category == "animals" or category == "medical" or category == "pottery" or category == "masonry" then
        return nil
    end
    if category == "farming" then
        for i = 0, recipe:getXPAwardCount() - 1 do
            if tostring(recipe:getXPAward(i):getPerk()) == "Butchering" then return nil end
        end
        for i = 0, recipe:getRequiredSkillCount() - 1 do
            if tostring(recipe:getRequiredSkill(i):getPerk()) == "Butchering" then return nil end
        end
    end
    local owner = category and categoryOwners[category]
    if owner then return owner end

    -- Traps can award Woodwork XP even though Trapping is their primary craft.
    for i = 0, recipe:getAutoLearnAnySkillCount() - 1 do
        if ownerFromPerk(recipe:getAutoLearnAnySkill(i)) == "trapper" then
            return "trapper"
        end
    end

    return ownerFromSkills(recipe, recipe:getXPAwardCount(), recipe.getXPAward)
        or ownerFromSkills(recipe, recipe:getRequiredSkillCount(), recipe.getRequiredSkill)
        or ownerFromSkills(recipe, recipe:getAutoLearnAnySkillCount(), recipe.getAutoLearnAnySkill)
        or ownerFromSkills(recipe, recipe:getAutoLearnAllSkillCount(), recipe.getAutoLearnAllSkill)
end

function VCMProfessionsCrafting.recipes()
    local result = {}
    local seen = {}
    for name in pairs(VCMProfessionsCraftingTraits) do
        result[name] = {}
    end
    local collections = {
        getScriptManager():getAllCraftRecipes(),
        getScriptManager():getAllBuildableRecipes(),
    }
    for _, recipes in ipairs(collections) do
        for i = 0, recipes:size() - 1 do
            local recipe = recipes:get(i)
            if recipe:needToBeLearn() and (VCMProfessionsConfig.craftingModRecipesEnabled()
                or recipe:isVanilla() or recipe:getExistsAsVanilla()) then
                local name = recipe:getName()
                local owner = recipeOwner(recipe)
                if owner and not seen[name] then
                    result[owner][#result[owner] + 1] = name
                    seen[name] = true
                end
            end
        end
    end
    return result
end

function VCMProfessionsCrafting.extraKnowledge(name)
    local knowledge = {}
    local seen = {}
    local function add(value)
        if not seen[value] then
            seen[value] = true
            knowledge[#knowledge + 1] = value
        end
    end
    if name == "farmer" then
        for _, season in ipairs(vanillaSeasons) do
            add("base:" .. season .. " growing season")
        end
        if VCMProfessionsConfig.craftingModRecipesEnabled()
            and farming_vegetableconf and farming_vegetableconf.props then
            for _, props in pairs(farming_vegetableconf.props) do
                if props.seasonRecipe then add(props.seasonRecipe) end
            end
        end
    elseif name == "mechanic" then
        add("Basic Mechanics")
        add("Intermediate Mechanics")
        add("Advanced Mechanics")
    elseif name == "electrician" then
        add("Generator")
    end
    return knowledge
end

function VCMProfessionsCrafting.grantKnowledge(player)
    if player:hasTrait(VCMProfessionsGeneratorTrait) then
        player:learnRecipe("Generator", false)
    end
    local selected = {}
    for name, trait in pairs(VCMProfessionsCraftingTraits) do
        if player:hasTrait(trait) then selected[#selected + 1] = name end
    end
    if #selected == 0 then return end
    local recipes = VCMProfessionsCrafting.recipes()
    for _, name in ipairs(selected) do
        for _, recipe in ipairs(recipes[name]) do
            player:learnRecipe(recipe, false)
        end
        for _, knowledge in ipairs(VCMProfessionsCrafting.extraKnowledge(name)) do
            player:learnRecipe(knowledge, false)
        end
    end
end

Events.OnNewGame.Add(VCMProfessionsCrafting.grantKnowledge)
Events.OnCreatePlayer.Add(function(_, player)
    VCMProfessionsCrafting.grantKnowledge(player)
    if isClient() then
        sendClientCommand(player, "VCMProfessions", "InitializeKnowledge", {})
    end
end)
