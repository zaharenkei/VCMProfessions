require "VCMProfessionsProfessionData"

VCMProfessionsProfessionTraits = {}
local traits = VCMProfessionsProfessionTraits
traits.byTrait = {}
traits.byProfession = {}
local icons = {}

local function encodedId(profession)
    return (tostring(profession:getType()):gsub(".", function(char)
        return string.format("%02x", string.byte(char))
    end))
end

local function descriptionWithoutSkills(profession)
    local description = profession:getDescription() or ""
    local skills = {}
    for perk, amount in pairs(transformIntoKahluaTable(profession:getXpBoosts())) do
        local value = amount:intValue()
        skills[#skills + 1] = {
            name = PerkFactory.getPerkName(perk),
            value = value > 0 and "+" .. tostring(value) or tostring(value),
        }
    end
    if #skills == 0 then return description end
    table.sort(skills, function(a, b) return a.name < b.name end)
    local generated, names = {}, {}
    for _, skill in ipairs(skills) do
        generated[#generated + 1] = skill.value .. " " .. skill.name
    end
    local granted = profession:getGrantedTraits()
    for i = 0, granted:size() - 1 do
        local definition = CharacterTraitDefinition.getCharacterTraitDefinition(granted:get(i))
        if not definition then
            error("VCM Professions: missing profession-granted trait definition: " .. tostring(granted:get(i)))
        end
        names[#names + 1] = definition:getLabel()
        generated[#generated + 1] = definition:getLabel()
    end
    local suffix = table.concat(generated, "\n")
    if description:sub(-#suffix) ~= suffix then return description end
    local prefix = description:sub(1, #description - #suffix)
    if prefix ~= "" and prefix:sub(-1) ~= "\n" then return description end
    if #names == 0 then
        local text = prefix:gsub("\n$", "")
        return text
    end
    return prefix .. table.concat(names, "\n")
end

local function registerProfession(profession)
    local id = encodedId(profession)
    local traitId = "VCMProfessions:profession_" .. id
    local trait = CharacterTrait.register(traitId)
    local key = "UI_VCMProfessions_Profession_" .. id
    local baseLabel = getText("UI_VCMProfessions_ProfessionLabel", profession:getUIName())
    local label, suffix = baseLabel, 0
    local existing = CharacterTraitDefinition.getTraits()
    local function labelExists(value)
        for i = 0, existing:size() - 1 do
            if existing:get(i):getLabel() == value then return true end
        end
        return false
    end
    while labelExists(label) do
        suffix = suffix + 1
        label = baseLabel .. " (" .. tostring(profession:getType()) .. (suffix > 1 and " " .. suffix or "") .. ")"
    end
    local translatedLabel = label:gsub("%%", "%%%%")
    Translator.getUI():put(key, translatedLabel)
    local definition = CharacterTraitDefinition.addCharacterTraitDefinition(
        trait, key, VCMProfessionsProfessionData.traitCost(profession), "", false, false
    )
    local granted = profession:getGrantedTraits()
    for i = 0, granted:size() - 1 do
        definition:addGrantedTrait(granted:get(i))
    end
    traits.byTrait[trait] = profession
    traits.byProfession[profession:getType()] = trait
    return definition
end

function traits.refresh()
    local professions = CharacterProfessionDefinition.getProfessions()
    local missing = {}
    for i = 0, professions:size() - 1 do
        local profession = professions:get(i)
        if not traits.byProfession[profession:getType()] then
            missing[#missing + 1] = profession
        end
    end
    table.sort(missing, function(a, b) return tostring(a:getType()) < tostring(b:getType()) end)
    for _, profession in ipairs(missing) do
        registerProfession(profession)
    end
end

function traits.refreshDisplay()
    traits.refresh()
    for trait, profession in pairs(traits.byTrait) do
        local definition = CharacterTraitDefinition.getCharacterTraitDefinition(trait)
        local source
        if profession:getType() == CharacterProfession.UNEMPLOYED then
            source = getTexture("media/ui/Traits/trait_profession_custom.png")
            if not source then
                error("VCM Professions: missing custom profession icon")
            end
        else
            source = profession:getTexture()
        end
        if source and (not icons[trait] or icons[trait].source ~= source) then
            local icon = Texture.new(source)
            icon:setWidth(18)
            icon:setHeight(18)
            icons[trait] = { source = source, icon = icon }
        end
        definition:setTexture(source and icons[trait].icon or nil)
        definition:setDescription(descriptionWithoutSkills(profession))
        VCMProfessionsTraitGroups[trait] = "VCM Professions"
    end
end

function traits.grantedTraitSet(profession)
    local result = {}
    local granted = profession:getGrantedTraits()
    for i = 0, granted:size() - 1 do result[granted:get(i)] = true end
    return result
end

function traits.professionForPlayer(player)
    local selected
    local known = player:getCharacterTraits():getKnownTraits()
    for i = 0, known:size() - 1 do
        local profession = traits.byTrait[known:get(i)]
        if profession then
            if selected then error("VCM Professions: player has multiple profession traits") end
            selected = profession
        end
    end
    if selected and player:getDescriptor():getCharacterProfession() ~= selected:getType() then
        error("VCM Professions: profession trait does not match the character's profession")
    end
    return selected
end

function traits.setDescriptorProfession(descriptor, profession)
    descriptor:setCharacterProfession(profession:getType())
    local boosts = descriptor:getXPBoostMap()
    boosts:clear()
    local scratch = CharacterTraitDefinition.getCharacterTraitDefinition(VCMProfessionsBoostScratch)
    if not scratch then error("VCM Professions: missing temporary boost definition") end
    local scratchBoosts = scratch:getXpBoosts()
    scratchBoosts:clear()
    local totals = {}
    for trait in pairs(traits.grantedTraitSet(profession)) do
        local definition = CharacterTraitDefinition.getCharacterTraitDefinition(trait)
        if not definition then
            error("VCM Professions: missing profession-granted trait definition: " .. tostring(trait))
        end
        for perk, amount in pairs(transformIntoKahluaTable(definition:getXpBoosts())) do
            totals[perk] = (totals[perk] or 0) + amount:intValue()
        end
    end
    for perk, amount in pairs(totals) do scratch:addXPBoost(perk, -amount) end
    boosts:putAll(scratchBoosts)
    scratchBoosts:clear()
end

local function onBoot()
    CharacterTraitDefinition.addCharacterTraitDefinition(
        VCMProfessionsBoostScratch, "UI_VCMProfessions_BoostScratch", 0, "", true, false
    )
    traits.refresh()
end

Events.OnGameBoot.Add(onBoot)
Events.OnMainMenuEnter.Add(traits.refresh)
Events.OnServerStarted.Add(traits.refresh)
