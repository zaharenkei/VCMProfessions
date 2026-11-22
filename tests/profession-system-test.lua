local root = [[Contents\mods\VCMProfessions\42.22\media\lua\]]
package.path = root .. [[shared\?.lua;]] .. package.path
local function number(value) return { intValue = function() return value end } end
local function list(values)
    return {
        size = function() return #values end,
        get = function(_, index) return values[index + 1] end,
        add = function(_, value) values[#values + 1] = value end,
        contains = function(_, value)
            for _, item in ipairs(values) do if item == value then return true end end
            return false
        end,
        remove = function(_, value)
            for index, item in ipairs(values) do
                if item == value then table.remove(values, index); return end
            end
        end,
    }
end
local function map(values)
    return {
        values = values or {},
        clear = function(self) self.values = {} end,
        putAll = function(self, other)
            for key, value in pairs(other.values) do self.values[key] = value end
        end,
    }
end
function transformIntoKahluaTable(value) return value.values end
local registered, definitions, translations = {}, {}, {}
CharacterTrait = { register = function(id)
    assert(not registered[id], "duplicate trait: " .. id)
    local trait = setmetatable({ id = id }, { __tostring = function(self) return self.id end })
    function trait:getName() return self.id:match(":(.*)") end
    registered[id] = trait
    return trait
end }
for _, name in ipairs({ "UNDERWEIGHT", "WEIGHT_LOSS", "OVERWEIGHT", "WEIGHT_GAIN" }) do
    CharacterTrait[name] = CharacterTrait.register("base:" .. string.lower(name))
end
VCMProfessionsBoostScratch = CharacterTrait.register("VCMProfessions:profession_boost_scratch")
Translator = { getUI = function() return { put = function(_, key, value) translations[key] = value end } end }
function getText(key, label)
    if key == "UI_VCMProfessions_ProfessionLabel" then return "Profession: " .. label end
    return key
end
Texture = { new = function(source)
    return {
        source = source,
        setWidth = function(self, value) self.width = value end,
        setHeight = function(self, value) self.height = value end,
        getWidth = function(self) return self.width end,
        getHeight = function(self) return self.height end,
    }
end }
PerkFactory = { getPerkName = function(perk) return perk end }
local function makeDefinition(id, label, cost, free)
    local boosts, granted, exclusions = map(), {}, {}
    return {
        getType = function() return id end,
        getLabel = function() return label end,
        getCost = function() return cost end,
        isFree = function() return free end,
        getXpBoosts = function() return boosts end,
        addXPBoost = function(_, perk, amount) boosts.values[perk] = number(amount) end,
        getGrantedTraits = function() return list(granted) end,
        addGrantedTrait = function(_, trait) granted[#granted + 1] = trait end,
        getMutuallyExclusiveTraits = function() return list(exclusions) end,
        isMutuallyExclusive = function(_, other)
            return list(exclusions):contains(other:getType())
        end,
        addMutuallyExclusive = function(_, trait) exclusions[#exclusions + 1] = trait end,
        setTexture = function(self, value) self.texture = value end,
        getTexture = function(self) return self.texture end,
        setDescription = function(self, value) self.description = value end,
        getDescription = function(self) return self.description or "" end,
        getRightLabel = function() return tostring(-cost) end,
    }
end
CharacterTraitDefinition = {
    addCharacterTraitDefinition = function(id, key, cost, _, free)
        definitions[id] = makeDefinition(id, translations[key] or key, cost, free)
        return definitions[id]
    end,
    getCharacterTraitDefinition = function(id) return definitions[id] end,
    getTraits = function()
        local all = {}
        for _, definition in pairs(definitions) do all[#all + 1] = definition end
        return list(all)
    end,
}
local herbalist = CharacterTrait.register("base:herbalist_prof")
local herbalistDefinition = makeDefinition(herbalist, "Herbalist", 0, true)
herbalistDefinition:addXPBoost("Foraging", 1)
definitions[herbalist] = herbalistDefinition
local burglarTraitId = CharacterTrait.register("base:burglar")
definitions[burglarTraitId] = makeDefinition(burglarTraitId, "Burglar", 0, true)
local function profession(id, label, cost, boosts, granted, description)
    local professionType = setmetatable({}, { __tostring = function() return id end })
    function professionType:getName() return id:match(":(.*)") end
    local xp = map()
    for perk, amount in pairs(boosts) do xp.values[perk] = number(amount) end
    return {
        getType = function() return professionType end,
        getUIName = function() return label end,
        getCost = function() return cost end,
        getXpBoosts = function() return xp end,
        getGrantedTraits = function() return list(granted) end,
        getTexture = function() return "profession-icon" end,
        getDescription = function() return description end,
    }
end
local ranger = profession("base:ranger", "Park Ranger", -4, { Foraging = 1, Axe = 2 },
    { herbalist }, "Knows the forest\n+2 Axe\n+1 Foraging\nHerbalist")
local modded = profession("example:ranger", "Modded Ranger", 8, {}, {}, "Modded description")
local unemployed = profession("base:unemployed", "Unemployed", 8, {}, {}, "")
CharacterProfession = { UNEMPLOYED = unemployed:getType() }
local customIcon = "custom-profession-icon"
function getTexture(path)
    assert(path == "media/ui/Traits/trait_profession_custom.png")
    return customIcon
end
local burglar = profession("base:burglar", "Burglar", -6, { Sneak = 6 }, { burglarTraitId }, "+6 Sneak\nBurglar")
local pilot = profession("example:pilot", "Pilot", -5, {}, {}, "Pilot")
local professions = { modded, ranger, unemployed, burglar, pilot }
CharacterProfessionDefinition = { getProfessions = function() return list(professions) end }
local callbacks = {}
Events = {}
for _, event in ipairs({ "OnGameBoot", "OnMainMenuEnter", "OnServerStarted" }) do
    Events[event] = { Add = function(callback) callbacks[event] = callback end }
end
VCMProfessionsTraitGroups = {}
require "VCMProfessionsProfessionTraits"
callbacks.OnGameBoot()
callbacks.OnMainMenuEnter()
local system = VCMProfessionsProfessionTraits
system.refreshDisplay()
local rangerId = system.byProfession[ranger:getType()]
local moddedId = system.byProfession[modded:getType()]
assert(rangerId ~= moddedId)
assert(tostring(rangerId) == "VCMProfessions:profession_626173653a72616e676572")
local rangerTrait = definitions[rangerId]
assert(rangerTrait:getCost() == 0)
assert(rangerTrait:getLabel() == "Profession: Park Ranger")
assert(rangerTrait:getDescription() == "Knows the forest\nHerbalist")
assert(rangerTrait:getTexture().source == "profession-icon")
assert(rangerTrait:getTexture().width == 18 and rangerTrait:getTexture().height == 18)
assert(VCMProfessionsTraitGroups[rangerId] == "VCM Prof")
local unemployedTrait = definitions[system.byProfession[unemployed:getType()]]
assert(unemployedTrait:getCost() == -8)
assert(unemployedTrait:getTexture().source == customIcon)
assert(unemployedTrait:getTexture().width == 18 and unemployedTrait:getTexture().height == 18)
customIcon = nil
local iconOk, iconMessage = pcall(system.refreshDisplay)
assert(not iconOk and iconMessage:find("missing custom profession icon", 1, true))
customIcon = "custom-profession-icon"
system.refreshDisplay()
assert(definitions[system.byProfession[burglar:getType()]]:getLabel() ~= definitions[burglarTraitId]:getLabel())

local descriptor = {
    boosts = map(),
    setCharacterProfession = function(self, value) self.profession = value end,
    getCharacterProfession = function(self) return self.profession end,
    getXPBoostMap = function(self) return self.boosts end,
}
system.setDescriptorProfession(descriptor, ranger)
assert(descriptor.profession == ranger:getType())
assert(descriptor.boosts.values.Foraging:intValue() == -1)
assert(next(definitions[VCMProfessionsBoostScratch]:getXpBoosts().values) == nil)
local player = {
    getDescriptor = function() return descriptor end,
    getCharacterTraits = function()
        return { getKnownTraits = function() return list({ rangerId, herbalist }) end }
    end,
}
assert(system.professionForPlayer(player) == ranger)
local conflicting = {
    getDescriptor = function() return descriptor end,
    getCharacterTraits = function()
        return { getKnownTraits = function() return list({ rangerId, moddedId }) end }
    end,
}
local multipleOk, multipleMessage = pcall(system.professionForPlayer, conflicting)
assert(not multipleOk and multipleMessage:find("multiple profession traits", 1, true))
descriptor.profession = unemployed:getType()
local ok, message = pcall(system.professionForPlayer, player)
assert(not ok and message:find("does not match", 1, true))
descriptor.profession = unemployed:getType()

for _, name in ipairs({ "ISUI/ISScrollingListBox", "OptionScreens/CharacterCreationProfession",
    "VCMProfessionsTraits" }) do package.loaded[name] = true end
SandboxVars = { VCMProfessions = { DisableSkillTraits = false } }
VCMProfessionsTraitsBySkill, VCMProfessionsTraitSet = {}, {}
VCMProfessionsTraits = { customTraitEnabled = function() end, grantsSkillLevels = function() return false end }
Perks = { None = "None", Fitness = "Fitness", Strength = "Strength" }
PerkFactory.getPerk = function(perk)
    return { getParent = function() return "Skills" end, getType = function() return perk end }
end
UIFont = { Small = 1, Medium = 2, NewSmall = 3 }
function getTextManager()
    return { getFontHeight = function() return 12 end, MeasureStringX = function() return 12 end }
end
ISScrollingListBox = { onMouseDown = function() end, onMouseMove = function() end }
MainScreen = { instance = { desc = descriptor } }
local function selectedList()
    return {
        items = {},
        getItem = function(self, index) return self.items[index or self.selected] end,
        size = function(self) return #self.items end,
    }
end
CharacterCreationProfession = {
    isTraitEnabled = function() return true end,
    isTraitExcluded = function(self, trait)
        for _, entry in ipairs(self.listboxTraitSelected.items) do
            if entry.item == trait or trait:isMutuallyExclusive(entry.item) then return true end
        end
        return false
    end,
    populateTraitList = function(self, list)
        list.items = {}
        local all = CharacterTraitDefinition.getTraits()
        for i = 0, all:size() - 1 do
            local trait = all:get(i)
            if not trait:isFree() and trait:getCost() > 0
                and self:isTraitEnabled(trait) and not self:isTraitExcluded(trait) then
                list:addItem(trait:getLabel(), trait, trait:getDescription())
            end
        end
    end,
    populateBadTraitList = function(self, list)
        list.items = {}
        local all = CharacterTraitDefinition.getTraits()
        for i = 0, all:size() - 1 do
            local trait = all:get(i)
            if not trait:isFree() and trait:getCost() < 0
                and self:isTraitEnabled(trait) and not self:isTraitExcluded(trait) then
                list:addItem(trait:getLabel(), trait, trait:getDescription())
            end
        end
    end,
    getTraitColor = function() return { r = 9, g = 8, b = 7 } end,
    drawTraitMap = function() return 911 end,
    PointToSpend = function(self) return self.pointToSpend + self.cost end,
    addTrait = function(self, trait)
        self.pointToSpend = self.pointToSpend - trait:getCost()
        self.listboxTraitSelected.items[#self.listboxTraitSelected.items + 1] = { item = trait }
        local granted = trait:getGrantedTraits()
        for i = 0, granted:size() - 1 do
            local child = definitions[granted:get(i)]
            self.freeTraits:add(child:getLabel())
            local exists = false
            for _, entry in ipairs(self.listboxTraitSelected.items) do
                if entry.item:getLabel() == child:getLabel() then exists = true end
            end
            if not exists then
                self.listboxTraitSelected.items[#self.listboxTraitSelected.items + 1] = { item = child }
            end
        end
    end,
    removeTrait = function(self, index)
        local trait = self.listboxTraitSelected.items[index].item
        if trait:isFree() then return end
        table.remove(self.listboxTraitSelected.items, index)
        self.pointToSpend = self.pointToSpend + trait:getCost()
        local granted = trait:getGrantedTraits()
        for i = 0, granted:size() - 1 do
            local child = definitions[granted:get(i)]
            self.freeTraits:remove(child:getLabel())
            if not self.freeTraits:contains(child:getLabel()) then
                for j = #self.listboxTraitSelected.items, 1, -1 do
                    if self.listboxTraitSelected.items[j].item == child then
                        table.remove(self.listboxTraitSelected.items, j)
                    end
                end
            end
        end
    end,
}
dofile(root .. [[client\VCMProfessionsCharacterCreation.lua]])
local bonusId = CharacterTrait.register("base:bonus")
local bonus = makeDefinition(bonusId, "Bonus", 1, false)
bonus:addXPBoost("Foraging", 2)
definitions[bonusId] = bonus
local drawbackId = CharacterTrait.register("base:drawback")
local drawback = makeDefinition(drawbackId, "Drawback", -2, false)
definitions[drawbackId] = drawback
local xpRows = {}
local panel = setmetatable({
    cost = 8, pointToSpend = 0, profession = unemployed,
    vcmSelectedSpecializations = {}, vcmSpecializationRows = {},
    listboxTraitSelected = selectedList(), listboxProf = {},
    listboxXpBoost = {
        clear = function() xpRows = {} end,
        addItem = function(_, name, item) xpRows[item.perk] = item; return { item = item } end,
        sort = function() end,
    },
    freeTraits = list({}),
    changeClothes = function() end,
    removeAllTraits = function(self)
        for i = #self.listboxTraitSelected.items, 1, -1 do self:removeTrait(i) end
    end,
}, { __index = CharacterCreationProfession })
local function availableList()
    return {
        items = {},
        addItem = function(self, label, trait)
            self.items[#self.items + 1] = { text = label, item = trait }
        end,
        removeMatchingItems = function(self, label)
            for i = #self.items, 1, -1 do
                if self.items[i].text == label then table.remove(self.items, i) end
            end
        end,
    }
end
local goodList, badList = availableList(), availableList()
panel:populateTraitList(goodList)
panel:populateBadTraitList(badList)
local function occurrences(list, trait)
    local count = 0
    for _, entry in ipairs(list.items) do
        if entry.item == trait then count = count + 1 end
    end
    return count
end
for _, trait in ipairs({ rangerTrait, definitions[moddedId], definitions[system.byProfession[pilot:getType()]] }) do
    assert(occurrences(goodList, trait) == 1, "profession trait must appear once in the positive list")
    assert(occurrences(badList, trait) == 0, "profession trait must not appear in the negative list")
end
assert(occurrences(goodList, bonus) == 1)
assert(occurrences(badList, drawback) == 1)
assert(occurrences(goodList, drawback) == 0)

local green = { getR = function() return 0.1 end, getG = function() return 0.8 end, getB = function() return 0.2 end }
function getCore() return { getGoodHighlitedColor = function() return green end } end
UI_BORDER_SPACING = nil
local drawn = {}
local listRenderer = {
    itemheight = 20, fontHgt = 12, selected = 0, mouseoverselected = 0,
    borderColor = { r = 1, g = 1, b = 1 }, itemheightoverride = {},
    getWidth = function() return 200 end,
    isMouseOverScrollBar = function() return false end,
    drawRectBorder = function() end, drawRect = function() end,
    drawTexture = function(_, _, x, y)
        assert(type(x) == "number" and type(y) == "number", "texture coordinates must be numeric")
    end,
    drawText = function(_, text, x, y, r, g, b)
        assert(type(x) == "number" and type(y) == "number", "text coordinates must be numeric")
        drawn[#drawn + 1] = { text = text, x = x, r = r, g = g, b = b }
    end,
    drawTextRight = function(_, text, x, y, r, g, b)
        assert(type(x) == "number" and type(y) == "number", "text coordinates must be numeric")
        drawn[#drawn + 1] = { text = text, x = x, r = r, g = g, b = b }
    end,
}
for _, trait in ipairs({ rangerTrait, definitions[moddedId], definitions[system.byProfession[pilot:getType()]] }) do
    drawn = {}
    local color = panel:getTraitColor(trait)
    assert(color.r == 0.1 and color.g == 0.8 and color.b == 0.2)
    assert(CharacterCreationProfession.drawTraitMap(listRenderer, 3, { item = trait, index = 1, height = 20 }, false) == 23)
    assert(#drawn == 2 and drawn[1].text == trait:getLabel() and drawn[2].text == trait:getRightLabel())
    assert(drawn[1].x == 38 and drawn[2].x == 180)
    for _, text in ipairs(drawn) do
        assert(text.r == 0.1 and text.g == 0.8 and text.b == 0.2)
    end
end
local pilotTrait = definitions[system.byProfession[pilot:getType()]]
pilotTrait:setTexture(nil)
drawn = {}
CharacterCreationProfession.drawTraitMap(listRenderer, 3, { item = pilotTrait, index = 1, height = 20 }, false)
assert(drawn[1].x == 10 and drawn[2].x == 180)
assert(panel:getTraitColor(bonus).r == 9)
assert(CharacterCreationProfession.drawTraitMap(listRenderer, 3, { item = bonus }, false) == 911)
local conflictingPanel = setmetatable({
    listboxTraitSelected = { items = { { item = herbalistDefinition } } },
    freeTraits = list({}),
}, { __index = CharacterCreationProfession })
assert(not conflictingPanel:isTraitEnabled(rangerTrait))
panel:addTrait(rangerTrait)
assert(panel:isTraitEnabled(rangerTrait))
assert(panel:getSelectedProf() == unemployed and descriptor.profession == ranger:getType())
assert(#panel.listboxTraitSelected.items == 2)
panel:populateTraitList(goodList)
assert(occurrences(goodList, rangerTrait) == 0 and occurrences(goodList, definitions[moddedId]) == 0)
assert(not panel:isTraitEnabled(definitions[moddedId]))
panel:addTrait(definitions[moddedId])
assert(#panel.listboxTraitSelected.items == 2)
panel:addTrait(bonus)
panel:checkXPBoost()
assert(xpRows.Foraging.level == 2)
panel:removeTrait(1)
assert(descriptor.profession == unemployed:getType())
assert(#panel.listboxTraitSelected.items == 1 and panel.listboxTraitSelected.items[1].item == bonus)
panel:populateTraitList(goodList)
assert(occurrences(goodList, rangerTrait) == 1 and occurrences(goodList, definitions[moddedId]) == 1)
panel.listboxTrait = { items = { { item = rangerTrait }, { item = bonus } } }
panel.listboxBadTrait = { items = { { item = definitions[moddedId] } } }
BCRC = { readSaveFile = function()
    return { build = "ranger;" .. rangerId:getName() .. ";" .. bonusId:getName() .. ";" }
end }
luautils = { split = function(value, separator)
    local parts = {}
    for part in value:gmatch("[^" .. separator .. "]+") do parts[#parts + 1] = part end
    return parts
end }
panel:loadBuild({ options = { "build" }, selected = 1 })
assert(panel:getSelectedProf() == unemployed and descriptor.profession == ranger:getType())
assert(#panel.listboxTraitSelected.items == 3)
panel:checkXPBoost()
assert(xpRows.Foraging.level == 2)
panel:resetBuild()
panel:addTrait(definitions[system.byProfession[burglar:getType()]])
assert(#panel.listboxTraitSelected.items == 2)
assert(descriptor.profession == burglar:getType())
print("Profession traits are selectable, exclusive, and restore their profession without its skill boosts")
