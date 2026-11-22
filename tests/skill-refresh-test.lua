local root = [[Contents\mods\VCMProfessions\42.22\media\lua\]]
package.path = root .. [[shared\?.lua;]] .. package.path
for _, name in ipairs({ "ISUI/ISScrollingListBox", "OptionScreens/CharacterCreationProfession",
    "VCMProfessionsTraits", "VCMProfessionsProfessionTraits" }) do package.loaded[name] = true end
SandboxVars = { VCMProfessions = {} }
require "VCMProfessionsConfig"
VCMProfessionsTraitsBySkill = setmetatable({}, {
    __index = function(t, key)
        local tiers = { novice = key .. ":novice", confident = key .. ":confident", master = key .. ":master" }
        rawset(t, key, tiers)
        return tiers
    end,
})
VCMProfessionsTraitSet = {}
VCMProfessionsTraits = {
    configure = function() end,
    customTraitEnabled = function() return nil end,
    grantsSkillLevels = function(trait) return trait.skill end,
}
VCMProfessionsTraitGroups = { personality = "VCM Professions" }
VCMProfessionsProfessionTraits = {
    byTrait = {}, grantedTraitSet = function() return {} end, refreshDisplay = function() end,
}
CharacterTrait = {}
Perks = setmetatable({}, { __index = function(_, key) return key end })
PerkFactory = { getPerkName = function(perk) return perk end }
UIFont = { Small = 1, Medium = 2, NewSmall = 3 }
function getTextManager()
    return { getFontHeight = function() return 12 end, MeasureStringX = function(_, _, text) return #text * 6 end }
end
function getText(key, ...) return key .. ":" .. table.concat({ ... }, ",") end
ISScrollingListBox = { onMouseDown = function() end, onMouseMove = function() end }
Events = { OnMainMenuEnter = { Add = function() end } }
CharacterCreationProfession = {
    create = function() end,
    addTrait = function(self, trait) self.addedTrait = trait end,
    removeTrait = function(self, index) table.remove(self.listboxTraitSelected.items, index) end,
    populateTraitList = function() end,
    populateBadTraitList = function() end,
    isTraitEnabled = function() return true end,
    PointToSpend = function(self) return self.points + self.cost end,
}
dofile(root .. [[client\VCMProfessionsCharacterCreation.lua]])

SandboxVars.VCMProfessions.HideVanillaTraits = false
local selectableSkill = { skill = true, getType = function() return "base:skill" end }
local selectableNonSkill = { skill = false, getType = function() return "base:nonskill" end }
local professionTrait = { skill = false, getType = function() return "VCMProfessions:profession_123" end }
local otherModTrait = { skill = false, getType = function() return "othermod:trait" end }
VCMProfessionsTraitGroups[professionTrait:getType()] = "VCM Professions"
assert(not CharacterCreationProfession:isTraitEnabled(selectableSkill))
assert(CharacterCreationProfession:isTraitEnabled(selectableNonSkill))
assert(not CharacterCreationProfession:isTraitEnabled(professionTrait))
assert(not CharacterCreationProfession:isTraitEnabled(otherModTrait))
SandboxVars.VCMProfessions.DisableSkillTraits = false
assert(CharacterCreationProfession:isTraitEnabled(selectableSkill))
assert(not CharacterCreationProfession:isTraitEnabled(professionTrait))
local addPanel = setmetatable({}, { __index = CharacterCreationProfession })
addPanel:addTrait(professionTrait)
assert(addPanel.addedTrait == nil)
addPanel:addTrait(selectableSkill)
assert(addPanel.addedTrait == selectableSkill)
local rankTrait = { getType = function() return "VCMProfessions:rank" end }
VCMProfessionsTraitSet[rankTrait:getType()] = true
addPanel:addTrait(rankTrait)
assert(addPanel.addedTrait == rankTrait)
SandboxVars.VCMProfessions.DisableSkillTraits = true
local balance = setmetatable({ points = 2, cost = 8, vcmSelectedSpecializations = { Axe = "master" } },
    { __index = CharacterCreationProfession })
assert(balance:PointToSpend() == -2)

local function zeroCostTrait(id)
    return {
        getType = function() return id end, getCost = function() return 0 end,
        isFree = function() return false end, getLabel = function() return id end,
        getDescription = function() return id end,
    }
end
local zeroTraits = { zeroCostTrait("personality"), zeroCostTrait("weight") }
CharacterTraitDefinition = { getTraits = function()
    return { size = function() return #zeroTraits end,
        get = function(_, index) return zeroTraits[index + 1] end }
end }
local panelForTraits = setmetatable({
    isTraitEnabled = function() return true end, isTraitExcluded = function() return false end,
}, { __index = CharacterCreationProfession })
local positives = { items = {}, addItem = function(self, _, trait) self.items[#self.items + 1] = trait end }
panelForTraits:populateTraitList(positives)
assert(#positives.items == 0)

local list = {
    items = {},
    clear = function(self) self.items = {} end,
    getWidth = function() return 600 end,
    setOnMouseDownFunction = function() end,
    setOnMouseDoubleClick = function() end,
    setScrollHeight = function() end,
    setYScroll = function() end,
    addItem = function(self, text, item)
        local entry = { text = text, item = item, itemindex = #self.items + 1 }
        self.items[#self.items + 1] = entry
        return entry
    end,
}
local physical = VCMProfessionsTraitsBySkill.Strength.novice
local panel = setmetatable({
    listboxProf = list,
    listboxTraitSelected = { items = { { item = { getType = function() return physical end } } } },
    vcmSelectedSpecializations = { Axe = "master", Strength = "novice" },
    vcmSpecializationRows = {},
    checkXPBoost = function(self) self.previews = (self.previews or 0) + 1 end,
}, { __index = CharacterCreationProfession })
panel:refreshSkillSettings()
assert(panel.vcmSelectedSpecializations.Axe == "master")
assert(panel.vcmSpecializationRows.Axe.tooltip:find("+3", 1, true))
local previews = panel.previews
panel:refreshSkillSettings()
assert(panel.previews == previews)
SandboxVars.VCMProfessions.MasterSkillLevel = 5
panel:refreshSkillSettings()
assert(panel.vcmSelectedSpecializations.Axe == "master")
assert(panel.vcmSpecializationRows.Axe.tooltip:find("+5", 1, true))
assert(panel.previews == previews + 1)
SandboxVars.VCMProfessions.PhysicalEnabled = false
panel:refreshSkillSettings()
assert(panel.vcmSelectedSpecializations.Strength == nil and #panel.listboxTraitSelected.items == 0)
assert(panel.vcmSpecializationRows.Strength == nil and panel.vcmSelectedSpecializations.Axe == "master")

local function tooltipList()
    return {
        items = {}, hover = 1,
        rowAt = function(self) return self.hover end,
        getMouseX = function() return 0 end,
        getMouseY = function() return 0 end,
        updateTooltip = function(self)
            self.displayedTooltip = self.items[self.hover] and self.items[self.hover].tooltip
        end,
    }
end
local creation = setmetatable({
    listboxProf = list,
    listboxTrait = tooltipList(),
    listboxBadTrait = tooltipList(),
    listboxTraitSelected = tooltipList(),
    checkXPBoost = function() end,
}, { __index = CharacterCreationProfession })
local beforeGroup = creation.listboxBadTrait
local beforeUpdate = beforeGroup.updateTooltip
beforeGroup.updateTooltip = function(self)
    local entry = self.items[self.hover]
    if entry and entry.vcmHeader then
        local old = entry.tooltip
        entry.tooltip = "Group header"
        beforeUpdate(self)
        entry.tooltip = old
    else
        beforeUpdate(self)
    end
end
creation:create()
for _, traits in ipairs({ creation.listboxTrait, creation.listboxBadTrait, creation.listboxTraitSelected }) do
    traits.items = { { tooltip = "" }, { tooltip = " \n\t" }, { tooltip = "Description" }, {} }
    for i = 1, 4 do
        traits.hover = i
        traits:updateTooltip()
        assert(traits.displayedTooltip == (i == 3 and "Description" or nil))
    end
end
local grouped = creation.listboxTrait
local updateTraitTooltip = grouped.updateTooltip
grouped.items = { { tooltip = "", vcmHeader = true } }
grouped.hover = 1
grouped.updateTooltip = function(self)
    local old = self.items[1].tooltip
    self.items[1].tooltip = "Group header"
    updateTraitTooltip(self)
    self.items[1].tooltip = old
end
grouped:updateTooltip()
assert(grouped.displayedTooltip == "Group header")
beforeGroup.items = { { tooltip = "", vcmHeader = true } }
beforeGroup.hover = 1
beforeGroup:updateTooltip()
assert(beforeGroup.displayedTooltip == "Group header")
print("Skill settings refresh preserves ranks and removes disabled physical selections")
