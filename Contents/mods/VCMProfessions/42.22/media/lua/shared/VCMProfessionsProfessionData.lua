VCMProfessionsProfessionData = {}

local data = VCMProfessionsProfessionData

function data.skillBonuses(profession)
    local totals = {}
    local visited = {}

    local function add(definition)
        for perk, amount in pairs(transformIntoKahluaTable(definition:getXpBoosts())) do
            totals[perk] = (totals[perk] or 0) + amount:intValue()
        end
    end

    local function addGrantedTrait(trait)
        if visited[trait] then return end
        visited[trait] = true
        local definition = CharacterTraitDefinition.getCharacterTraitDefinition(trait)
        if not definition then
            error("VCM Professions: missing profession-granted trait definition: " .. tostring(trait))
        end
        add(definition)
    end

    add(profession)
    local granted = profession:getGrantedTraits()
    for i = 0, granted:size() - 1 do
        addGrantedTrait(granted:get(i))
    end
    return totals
end

function data.traitCost(profession)
    local discount = 0
    for _, amount in pairs(data.skillBonuses(profession)) do
        discount = discount + math.max(0, amount)
    end
    return -profession:getCost() - discount
end
