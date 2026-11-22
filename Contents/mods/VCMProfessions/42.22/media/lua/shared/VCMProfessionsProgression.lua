require "VCMProfessionsConfig"
require "VCMProfessionsProfessionTraits"

VCMProfessionsProgression = {}
local config = VCMProfessionsConfig

local function getSkillTier(player, skillName)
    local traits = VCMProfessionsTraitsBySkill[skillName]
    if not traits then
        return nil
    end
    for _, tier in ipairs(config.tiers) do
        if player:hasTrait(traits[tier]) then
            return tier
        end
    end
    return nil
end

local function getSkillName(perk)
    local perkDefinition = PerkFactory.getPerk(perk)
    if not perkDefinition then
        return nil, nil
    end
    if perkDefinition:getParent() == Perks.None then
        return nil, perkDefinition
    end
    return tostring(perkDefinition:getType()), perkDefinition
end

local function setSkillLevel(player, perk, level)
    player:setPerkLevelDebug(perk, level)
    player:getXp():setXPToLevel(perk, level)
    if perk == Perks.Fitness then
        player:getStats():set(CharacterStat.FITNESS, level / 5 - 1)
    end
end

local function enforceSkillCap(player, perk)
    local skillName = getSkillName(perk)
    if not skillName then
        return
    end

    local cap = config.cap(skillName, getSkillTier(player, skillName))
    if cap and player:getPerkLevel(perk) > cap then
        setSkillLevel(player, perk, cap)
    end
end

local function onAddXP(player, perk, amount)
    if amount > 0 then
        enforceSkillCap(player, perk)
    end
end

-- LevelPerk fires inside the game's XP level-up loop; clamp after that loop completes.
local pendingCaps = {}

local function onLevelPerk(player, perk, level, increased)
    if increased and instanceof(player, "IsoPlayer") then
        local skillName = getSkillName(perk)
        local cap = skillName and config.cap(skillName, getSkillTier(player, skillName))
        if cap and level > cap then
            pendingCaps[player] = pendingCaps[player] or {}
            pendingCaps[player][perk] = true
        end
    end
end

local function applyPendingCaps()
    local pending = pendingCaps
    pendingCaps = {}
    for player, perks in pairs(pending) do
        for perk in pairs(perks) do
            enforceSkillCap(player, perk)
        end
    end
end

local function startingBoosts(player, server)
    local totals = {}
    local function add(definition)
        if definition and definition:getXpBoosts() then
            for perk, amount in pairs(transformIntoKahluaTable(definition:getXpBoosts())) do
                if not (server and perk == Perks.PlantScavenging and config.traitModuleEnabled("Foraging")
                    and definition:getType() == CharacterTrait.HERBALIST) then
                    totals[perk] = (totals[perk] or 0) + amount:intValue()
                end
            end
        end
    end
    local descriptor = player:getDescriptor()
    local profession = VCMProfessionsProfessionTraits.professionForPlayer(player)
    local granted = profession and VCMProfessionsProfessionTraits.grantedTraitSet(profession) or {}
    if not profession then
        add(CharacterProfessionDefinition.getCharacterProfessionDefinition(descriptor:getCharacterProfession()))
    end
    local known = player:getCharacterTraits():getKnownTraits()
    for i = 0, known:size() - 1 do
        local trait = known:get(i)
        if not granted[trait] then
            add(CharacterTraitDefinition.getCharacterTraitDefinition(trait))
        end
    end
    return totals
end

local function initializePlayer(player, server)
    local modData = player:getModData()
    local marker = server and "VCMProfessionsServerInitialLevelsApplied" or "VCMProfessionsInitialLevelsApplied"
    if not modData[marker] then
        if not server and player:getHoursSurvived() > 0.25 then
            modData[marker] = true
            return false
        end
        VCMProfessionsProfessionTraits.professionForPlayer(player)
        local boosts
        for i = 0, Perks.getMaxIndex() - 1 do
            local perk = Perks.fromIndex(i)
            local skillName = getSkillName(perk)
            local tier = skillName and getSkillTier(player, skillName)
            if skillName then
                if config.isPhysical(skillName) and config.physicalEnabled() then
                    local currentLevel = player:getPerkLevel(perk)
                    local level = config.physicalStartLevel(skillName, tier)
                    if level ~= currentLevel then
                        setSkillLevel(player, perk, level)
                    end
                elseif not config.isPhysical(skillName) then
                    local cap = config.cap(skillName, tier)
                    local xp = player:getXp()
                    if VCMProfessionsTraitsBySkill[skillName] then
                        local adjustment = config.regularStartLevel(tier) - (config.startLevels[tier] or 0)
                        local serverHerbalist = server and skillName == "PlantScavenging"
                            and config.traitModuleEnabled("Foraging") and player:hasTrait(CharacterTrait.HERBALIST)
                        if adjustment ~= 0 or serverHerbalist then
                            boosts = boosts or startingBoosts(player, server)
                            local raw = boosts[perk] or 0
                            local oldLevel = math.max(0, math.min(10, raw))
                            local newLevel = math.max(0, math.min(10, raw + adjustment))
                            local level = server and newLevel
                                or math.max(0, math.min(10, player:getPerkLevel(perk) + newLevel - oldLevel))
                            if cap then level = math.min(level, cap) end
                            if level ~= player:getPerkLevel(perk) then
                                setSkillLevel(player, perk, level)
                            end
                            local boost = server and math.min(newLevel, 3)
                                or xp:getPerkBoost(perk) + math.min(newLevel, 3) - math.min(oldLevel, 3)
                            xp:setPerkBoost(perk, math.max(0, math.min(3, cap or 3, boost)))
                        end
                    end
                    if cap and xp:getPerkBoost(perk) > cap then
                        xp:setPerkBoost(perk, cap)
                    end
                end
            end
        end
        modData[marker] = true
        return true
    end
    return false
end

function VCMProfessionsProgression.initializeServerPlayer(player)
    if player:getHoursSurvived() > 0.25 then
        print("VCM Professions: refused late initial skill request for " .. tostring(player:getUsername()))
        return
    end
    if initializePlayer(player, true) then
        for i = 0, Perks.getMaxIndex() - 1 do
            enforceSkillCap(player, Perks.fromIndex(i))
        end
    end
end

local function onCreatePlayer(playerIndex, player)
    local initialized = initializePlayer(player, false)
    for i = 0, Perks.getMaxIndex() - 1 do
        enforceSkillCap(player, Perks.fromIndex(i))
    end
    if initialized and isClient() then
        sendClientCommand(player, "VCMProfessions", "InitializeSkills", {})
    end
end

Events.AddXP.Add(onAddXP)
Events.OnCreatePlayer.Add(onCreatePlayer)
Events.LevelPerk.Add(onLevelPerk)
Events.OnTick.Add(applyPendingCaps)
