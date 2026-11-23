require "ISUI/ISScrollingListBox"
require "OptionScreens/CharacterCreationProfession"
require "VCMProfessionsConfig"
require "VCMProfessionsTraits"
require "VCMProfessionsProfessionTraits"

local config = VCMProfessionsConfig
local originalCreate = CharacterCreationProfession.create
local originalSetVisible = CharacterCreationProfession.setVisible
local originalRender = CharacterCreationProfession.render
local originalRemoveTrait = CharacterCreationProfession.removeTrait
local originalAddTrait = CharacterCreationProfession.addTrait
local originalOnSelectChosenTrait = CharacterCreationProfession.onSelectChosenTrait
local originalIsTraitEnabled = CharacterCreationProfession.isTraitEnabled
local originalPointToSpend = CharacterCreationProfession.PointToSpend
local originalOnOptionMouseDown = CharacterCreationProfession.onOptionMouseDown
local originalDrawXpBoostMap = CharacterCreationProfession.drawXpBoostMap
local originalPopulateTraitList = CharacterCreationProfession.populateTraitList
local originalPopulateBadTraitList = CharacterCreationProfession.populateBadTraitList
local originalGetTraitColor = CharacterCreationProfession.getTraitColor
local originalDrawTraitMap = CharacterCreationProfession.drawTraitMap
local originalListOnMouseDown = ISScrollingListBox.onMouseDown
local originalListOnMouseMove = ISScrollingListBox.onMouseMove

local STATE_ORDER = { "unexperienced", "novice", "confident", "master" }
local STATE_NAME_KEYS = {
    unexperienced = "UI_VCMProfessions_NameUnexperienced",
    novice = "UI_VCMProfessions_NameNovice",
    confident = "UI_VCMProfessions_NameConfident",
    master = "UI_VCMProfessions_NameMaster",
}
local STATE_TIERS = {
    novice = "novice",
    confident = "confident",
    master = "master",
}
local SKILL_GROUPS = {
    {
        title = "IGUI_perks_Survivalist",
        skills = { "Tracking", "Trapping", "Doctor", "Fishing", "PlantScavenging" },
    },
    {
        title = "IGUI_perks_CombatFirearms",
        skills = { "Reloading", "Aiming" },
    },
    {
        title = "IGUI_perks_CombatMelee",
        skills = { "LongBlade", "Blunt", "Spear", "SmallBlade", "SmallBlunt", "Maintenance", "Axe" },
    },
    {
        title = "IGUI_perks_FarmingCategory",
        skills = { "Butchering", "Husbandry", "Farming" },
    },
    {
        title = "IGUI_perks_Crafting",
        skills = {
            "Mechanics", "MetalWelding", "Pottery", "Masonry", "FlintKnapping",
            "Blacksmith", "Cooking", "Woodwork", "Carving", "Glassmaking",
            "Tailoring", "Electricity", "Melting",
        },
    },
    {
        title = "IGUI_perks_PhysicalCategory",
        skills = { "Sprinting", "Lightfoot", "Nimble", "Strength", "Fitness", "Sneak" },
    },
}

local SMALL_FONT_HGT = getTextManager():getFontHeight(UIFont.Small)
local MEDIUM_FONT_HGT = getTextManager():getFontHeight(UIFont.Medium)
local UI_BORDER_SPACING = 10
local STATE_BUTTON_FONT = UIFont.NewSmall
local STATE_BUTTON_FONT_HGT = getTextManager():getFontHeight(STATE_BUTTON_FONT)
local SKILL_ROW_HGT = SMALL_FONT_HGT + 8
local CATEGORY_ROW_HGT = SMALL_FONT_HGT + 8
local STATE_BUTTON_GAP = 2
local STATE_BUTTON_PADDING = 4
local STATE_BUTTON_RIGHT_PADDING = 24
local SKILL_LABEL_GAP = 8

local function stateLabel(state, skillName)
    if config.isPhysical(skillName) then
        return tostring(config.physicalStartLevel(skillName, STATE_TIERS[state]))
    end
    local level = config.regularStartLevel(STATE_TIERS[state])
    return level > 0 and "+" .. tostring(level) or "0"
end

local function getStateButtonLayout(width, stacked, skillName)
    local buttons = {}
    local totalWidth = 0
    local labelWidth = 0
    for _, state in ipairs(STATE_ORDER) do
        labelWidth = math.max(labelWidth, getTextManager():MeasureStringX(STATE_BUTTON_FONT, stateLabel(state, "Axe")))
    end
    if config.physicalEnabled() then
        for _, state in ipairs(STATE_ORDER) do
            for _, physicalSkill in ipairs({ "Strength", "Fitness" }) do
                labelWidth = math.max(labelWidth, getTextManager():MeasureStringX(STATE_BUTTON_FONT, stateLabel(state, physicalSkill)))
            end
        end
    end
    local buttonWidth = (labelWidth + STATE_BUTTON_PADDING) * 2
    for _, state in ipairs(STATE_ORDER) do
        local label = stateLabel(state, skillName)
        buttons[#buttons + 1] = { state = state, label = label, width = buttonWidth }
        totalWidth = totalWidth + buttonWidth + STATE_BUTTON_GAP
    end
    totalWidth = totalWidth - STATE_BUTTON_GAP

    local x = stacked and math.floor((width - totalWidth) / 2) or width - STATE_BUTTON_RIGHT_PADDING - totalWidth
    for _, button in ipairs(buttons) do
        button.x = x
        x = x + button.width + STATE_BUTTON_GAP
    end
    return buttons, buttons[1].x, totalWidth
end

local function skillLabel(skillName)
    local perk = Perks[skillName]
    if not perk then
        error("VCM Professions has no perk registered for " .. skillName)
    end
    return PerkFactory.getPerkName(perk)
end

local function getSkillPointsSpent(selections)
    local spent = 0
    for skillName, tier in pairs(selections) do
        spent = spent + config.cost(skillName, tier)
    end
    return spent
end

local function stateForTier(tier)
    return tier or "unexperienced"
end

local function stateDescription(state, skillName)
    local tier = STATE_TIERS[state]
    local tierName = getText(STATE_NAME_KEYS[state])
    local cap = config.cap(skillName, tier)
    local physical = config.isPhysical(skillName)
    local startLevel = physical and config.physicalStartLevel(skillName, tier) or config.regularStartLevel(tier)
    local startText = not physical and startLevel > 0 and "+" .. tostring(startLevel) or tostring(startLevel)
    local capText = cap and tostring(cap) or getText("UI_VCMProfessions_NoCap")
    local tooltip = physical and "UI_VCMProfessions_PhysicalStateTooltip" or "UI_VCMProfessions_StateTooltip"
    return getText(tooltip, tierName, startText, capText, config.cost(skillName, tier))
end

local function drawProfessionSkills(list, y, item, alt)
    local data = item.item
    local owner = data and data.owner or list.target
    if not owner then
        return y + item.height
    end
    local width = list:getWidth()
    local height = item.height

    if data.kind ~= "skill" then
        if list.selected == item.index then
            list:drawSelection(0, y, width, height - 1)
        elseif list.mouseoverselected == item.index and list:isMouseOver() and not list:isMouseOverScrollBar() then
            list:drawMouseOverHighlight(0, y, width, height - 1)
        end
    end

    if data.kind == "category" then
        list:drawText(data.label, 8, y + 2, 1, 1, 1, 1, UIFont.Small)
        list:drawRect(8, y + height - 2, width - 16, 1, 0.4, 0.55, 0.55, 0.55)
        return y + height
    end

    local tier = owner.vcmSelectedSpecializations[data.skillName]
    local state = stateForTier(tier)
    local buttons = getStateButtonLayout(width, owner.vcmStackedStateButtons, data.skillName)
    local textY = owner.vcmStackedStateButtons
        and y + 1
        or y + math.floor((height - SMALL_FONT_HGT) / 2)
    list:drawText(item.text, 8, textY, 1, 1, 1, 1, UIFont.Small)

    local buttonHeight = STATE_BUTTON_FONT_HGT + 4
    local buttonY = owner.vcmStackedStateButtons
        and y + SMALL_FONT_HGT + 3
        or y + math.floor((height - buttonHeight) / 2)

    for _, button in ipairs(buttons) do
        local selected = button.state == state
        local fill = selected and { a = 0.8, r = 0.55, g = 0.28, b = 0.12 }
            or { a = 0.35, r = 0.18, g = 0.18, b = 0.18 }
        local border = selected and { a = 1, r = 1, g = 0.7, b = 0.35 }
            or { a = 0.8, r = 0.55, g = 0.55, b = 0.55 }
        local text = { r = 0.86, g = 0.86, b = 0.86 }
        list:drawRect(button.x, buttonY, button.width, buttonHeight, fill.a, fill.r, fill.g, fill.b)
        list:drawRectBorder(button.x, buttonY, button.width, buttonHeight, border.a, border.r, border.g, border.b)
        list:drawText(
            button.label,
            button.x + (button.width - getTextManager():MeasureStringX(STATE_BUTTON_FONT, button.label)) / 2,
            buttonY + 2, text.r, text.g, text.b, 1, STATE_BUTTON_FONT
        )
    end

    return y + height
end

local function getTraitDefinition(skillName, tier)
    local traitId = VCMProfessionsTraitsBySkill[skillName][tier]
    local definition = CharacterTraitDefinition.getCharacterTraitDefinition(traitId)
    if not definition then
        error("VCM Professions could not find trait definition: " .. tostring(traitId))
    end
    return definition
end

local function setSpecialization(self, skillName, tier)
    local previousTier = self.vcmSelectedSpecializations[skillName]
    if previousTier == tier then
        return
    end

    if previousTier then
        local previousType = VCMProfessionsTraitsBySkill[skillName][previousTier]
        for index = #self.listboxTraitSelected.items, 1, -1 do
            local selectedTrait = self.listboxTraitSelected.items[index].item
            if selectedTrait:getType() == previousType then
                originalRemoveTrait(self, index)
                break
            end
        end
    end

    self.vcmSelectedSpecializations[skillName] = tier
    if tier then
        self:addTrait(getTraitDefinition(skillName, tier))
    end
    self:checkXPBoost()

    local row = self.vcmSpecializationRows[skillName]
    if row then
        row.tooltip = stateDescription(stateForTier(tier), skillName)
    end
end

local function clearSpecializations(self)
    local skillNames = {}
    for skillName in pairs(self.vcmSelectedSpecializations or {}) do
        skillNames[#skillNames + 1] = skillName
    end
    for _, skillName in ipairs(skillNames) do
        setSpecialization(self, skillName, nil)
    end
end

local function onSkillSelected(self, row)
    if row.kind ~= "skill" then
        return
    end

    local list = self.listboxProf
    local clickX = list.vcmClickX
    if not clickX then
        return
    end

    local buttons = getStateButtonLayout(list:getWidth(), self.vcmStackedStateButtons, row.skillName)
    if self.vcmStackedStateButtons then
        local rowY = list.vcmClickY - list:topOfItem(list.selected)
        if rowY < SMALL_FONT_HGT + 3 then
            return
        end
    end
    local selectedState
    for _, button in ipairs(buttons) do
        if clickX >= button.x and clickX <= button.x + button.width then
            selectedState = button.state
            break
        end
    end
    if not selectedState then
        return
    end

    setSpecialization(self, row.skillName, STATE_TIERS[selectedState])
end

local function addSkillRows(self)
    local list = self.listboxProf
    list:clear()
    local _, buttonStart = getStateButtonLayout(list:getWidth(), false)
    local maxSkillLabelWidth = 0
    for _, group in ipairs(SKILL_GROUPS) do
        for _, skillName in ipairs(group.skills) do
            if not config.isPhysical(skillName) or config.physicalEnabled() then
                maxSkillLabelWidth = math.max(
                    maxSkillLabelWidth,
                    getTextManager():MeasureStringX(UIFont.Small, skillLabel(skillName))
                )
            end
        end
    end
    self.vcmStackedStateButtons = buttonStart < maxSkillLabelWidth + SKILL_LABEL_GAP + 8
    list.itemheight = self.vcmStackedStateButtons
        and SMALL_FONT_HGT + STATE_BUTTON_FONT_HGT + 9
        or SKILL_ROW_HGT
    list.fontHgt = SMALL_FONT_HGT
    list.doDrawItem = drawProfessionSkills
    list:setOnMouseDownFunction(self, onSkillSelected)
    list.onMouseDown = function(self, x, y)
        self.vcmClickX = x
        self.vcmClickY = y
        originalListOnMouseDown(self, x, y)
        self.vcmClickX = nil
        self.vcmClickY = nil
    end
    list.onMouseMove = function(self, dx, dy)
        originalListOnMouseMove(self, dx, dy)
        local entry = self.items[self.mouseoverselected]
        local data = entry and entry.item
        if not data or data.kind ~= "skill" then
            return
        end

        local currentState = stateForTier(data.owner.vcmSelectedSpecializations[data.skillName])
        local hoveredState
        local rowY = self:getMouseY() - self:topOfItem(self.mouseoverselected)
        if not data.owner.vcmStackedStateButtons or rowY >= SMALL_FONT_HGT + 3 then
            for _, button in ipairs(getStateButtonLayout(self:getWidth(), data.owner.vcmStackedStateButtons, data.skillName)) do
                if self:getMouseX() >= button.x and self:getMouseX() <= button.x + button.width then
                    hoveredState = button.state
                    break
                end
            end
        end
        entry.tooltip = stateDescription(hoveredState or currentState, data.skillName)
    end
    list:setOnMouseDoubleClick(self, function() end)
    self.vcmSelectedSpecializations = self.vcmSelectedSpecializations or {}
    self.vcmSpecializationRows = {}

    local totalHeight = 0
    local firstSkillIndex
    for _, group in ipairs(SKILL_GROUPS) do
        local header = list:addItem("", { kind = "category", owner = self, label = getText(group.title) })
        header.height = CATEGORY_ROW_HGT
        totalHeight = totalHeight + header.height

        for _, skillName in ipairs(group.skills) do
            if not config.isPhysical(skillName) or config.physicalEnabled() then
                if not VCMProfessionsTraitsBySkill[skillName] then
                    error("VCM Professions skill is missing a trait registry: " .. skillName)
                end
                local row = list:addItem(skillLabel(skillName), { kind = "skill", owner = self, skillName = skillName })
                row.height = list.itemheight
                row.tooltip = stateDescription(stateForTier(self.vcmSelectedSpecializations[skillName]), skillName)
                self.vcmSpecializationRows[skillName] = row
                firstSkillIndex = firstSkillIndex or row.itemindex
                totalHeight = totalHeight + row.height
            end
        end
    end

    list.selected = firstSkillIndex or 1
    list:setScrollHeight(totalHeight)
    list:setYScroll(0)
end

local function getSpecializationForSavedTrait(traitName)
    for skillName, tiers in pairs(VCMProfessionsTraitsBySkill) do
        for _, tier in ipairs(config.tiers) do
            local definition = getTraitDefinition(skillName, tier)
            if definition:getType():getName() == traitName then
                return skillName, tier
            end
        end
    end
    return nil, nil
end

local function suppressEmptyTraitTooltips(list)
    local originalUpdateTooltip = list.updateTooltip
    list.updateTooltip = function(self)
        local row = self:rowAt(self:getMouseX(), self:getMouseY())
        local entry = self.items[row]
        if entry and type(entry.tooltip) == "string" and not entry.tooltip:find("%S") then
            entry.tooltip = nil
        end
        return originalUpdateTooltip(self)
    end
end

function CharacterCreationProfession.create(self)
    VCMProfessionsTraits.configure()
    VCMProfessionsProfessionTraits.refreshDisplay()
    originalCreate(self)
    suppressEmptyTraitTooltips(self.listboxTrait)
    suppressEmptyTraitTooltips(self.listboxBadTrait)
    suppressEmptyTraitTooltips(self.listboxTraitSelected)
    self.vcmTraitSettings = nil
    addSkillRows(self)
    self.vcmSkillSettings = nil
    self:checkXPBoost()
end

local function skillSettingsSignature()
    local settings = { tostring(config.physicalEnabled()) }
    for _, skill in ipairs({ "Axe", "Strength", "Fitness" }) do
        for _, state in ipairs(STATE_ORDER) do
            local tier = STATE_TIERS[state]
            local level = config.isPhysical(skill) and config.physicalStartLevel(skill, tier)
                or config.regularStartLevel(tier)
            settings[#settings + 1] = tostring(level)
            settings[#settings + 1] = tostring(config.cap(skill, tier))
            settings[#settings + 1] = tostring(config.cost(skill, tier))
        end
    end
    return table.concat(settings, ":")
end

function CharacterCreationProfession:refreshSkillSettings()
    if not self.listboxProf or not self.vcmSelectedSpecializations then
        return
    end
    local signature = skillSettingsSignature()
    if signature ~= self.vcmSkillSettings then
        self.vcmSkillSettings = signature
        if not config.physicalEnabled() then
            setSpecialization(self, "Strength", nil)
            setSpecialization(self, "Fitness", nil)
        end
        addSkillRows(self)
        self:checkXPBoost()
    end
end

local function traitSettingsSignature()
    local settings = {
        config.professionalTraitsEnabled(), config.hideVanillaTraits(), config.hideOtherModTraits(),
        config.traitModuleEnabled("Crafting"), config.traitModuleEnabled("Weight"),
        config.traitModuleEnabled("Weapons"), config.traitModuleEnabled("Foraging"),
        config.traitModuleEnabled("Personality"), config.traitModuleEnabled("Property"),
        config.craftingTraitCost(), config.craftingModRecipesEnabled(), config.disableSkillTraits(),
    }
    for i, value in ipairs(settings) do settings[i] = tostring(value) end
    return table.concat(settings, ":")
end

function CharacterCreationProfession:refreshTraitVisibility()
    if not self.listboxTrait or not self.listboxBadTrait or not self.listboxTraitSelected then
        return
    end
    local signature = traitSettingsSignature()
    if self.vcmTraitSettings ~= signature then
        self.vcmTraitSettings = signature
        VCMProfessionsTraits.configure()
        for index = #self.listboxTraitSelected.items, 1, -1 do
            local entry = self.listboxTraitSelected.items[index]
            local old = entry.item
            if not VCMProfessionsTraitSet[old:getType()] and not self.freeTraits:contains(old:getLabel()) then
                local current = CharacterTraitDefinition.getCharacterTraitDefinition(old:getType())
                if not current then
                    error("VCM Professions: selected trait definition missing: " .. tostring(old:getType()))
                elseif current:isFree() or not self:isTraitEnabled(current) then
                    originalRemoveTrait(self, index)
                elseif current ~= old then
                    self.pointToSpend = self.pointToSpend + old:getCost() - current:getCost()
                    entry.item = current
                    entry.text = current:getLabel()
                    entry.tooltip = current:getDescription()
                end
            end
        end
        self:repopulateTraitLists()
        self:checkXPBoost()
    end
end

function CharacterCreationProfession:setVisible(visible, joypadData)
    originalSetVisible(self, visible, joypadData)
    if visible then
        self:refreshTraitVisibility()
        self:refreshSkillSettings()
    end
end

function CharacterCreationProfession:checkXPBoost()
    self.listboxXpBoost:clear()
    local levels = {}
    local granted = self.vcmProfessionDefinition
        and VCMProfessionsProfessionTraits.grantedTraitSet(self.vcmProfessionDefinition) or {}
    local function addBoosts(definition)
        if definition and definition:getXpBoosts() then
            for perk, level in pairs(transformIntoKahluaTable(definition:getXpBoosts())) do
                levels[perk] = (levels[perk] or 0) + level:intValue()
            end
        end
    end
    for _, entry in ipairs(self.listboxTraitSelected and self.listboxTraitSelected.items or {}) do
        if not granted[entry.item:getType()] then
            addBoosts(entry.item)
        end
    end
    levels[Perks.Fitness] = (levels[Perks.Fitness] or 0) + 5
    levels[Perks.Strength] = (levels[Perks.Strength] or 0) + 5

    local selections = self.vcmSelectedSpecializations or {}
    for skillName in pairs(VCMProfessionsTraitsBySkill) do
        if not config.isPhysical(skillName) then
            local tier = selections[skillName]
            local adjustment = config.regularStartLevel(tier) - (config.startLevels[tier] or 0)
            if adjustment ~= 0 then
                local perk = Perks[skillName]
                levels[perk] = (levels[perk] or 0) + adjustment
            end
        end
    end
    for perk, rawLevel in pairs(levels) do
        local level = math.max(0, math.min(10, rawLevel))
        local definition = PerkFactory.getPerk(perk)
        if definition and definition:getParent() ~= Perks.None then
            local skillName = tostring(definition:getType())
            local tier = selections[skillName]
            if config.isPhysical(skillName) and config.physicalEnabled() then
                level = config.physicalStartLevel(skillName, tier)
            end
            local cap = config.cap(skillName, tier)
            local entry = self.listboxXpBoost:addItem(PerkFactory.getPerkName(perk), { perk = perk, level = level })
            if cap and level > cap then
                entry.item.vcmCap = cap
                entry.tooltip = getText("UI_VCMProfessions_CapWarningTooltip", cap)
            end
        else
            self.listboxXpBoost:addItem(PerkFactory.getPerkName(perk), { perk = perk, level = level })
        end
    end
    self.listboxXpBoost:sort()
end

function CharacterCreationProfession:drawXpBoostMap(y, item, alt)
    local cap = item.item.vcmCap
    if not cap then
        return originalDrawXpBoostMap(self, y, item, alt)
    end

    local dy = (self.itemheight - self.fontHgt) / 2
    local scrollBarWidth = 13
    local blitH = SMALL_FONT_HGT
    local blitW = math.floor(blitH / (10 / 3))
    local blitGap = math.floor(blitW / 4)
    local blitXOffset = getTextManager():MeasureStringX(UIFont.Small, "+ 100%") + scrollBarWidth
    local barsX = self.width - (blitXOffset + 12 * (blitW + blitGap))
    local warning = getText("UI_VCMProfessions_CappedAt", cap)
    local label = item.text .. " " .. warning
    local separateLine = 10 + getTextManager():MeasureStringX(UIFont.Small, label) > barsX
    local r, g, b = 1, 0.6, 0.2
    self:drawText(separateLine and item.text or label, 10, y + dy, r, g, b, 1, UIFont.Small)
    if separateLine then
        self:drawText(warning, 10, y + self.itemheight, r, g, b, 1, UIFont.Small)
    end

    local level = math.min(item.item.level, cap)
    for i = 1, level do
        self:drawTextureScaled(CharacterCreationProfession.instance.whiteBar,
            barsX + i * (blitW + blitGap), y + dy, blitW, blitH, 1, r, g, b)
    end
    if item.item.perk ~= Perks.Fitness and item.item.perk ~= Perks.Strength then
        local percentage = "+ 0%"
        if level == 1 then
            percentage = "+ 75%"
        elseif level == 2 then
            percentage = "+ 100%"
        elseif level >= 3 then
            percentage = "+ 125%"
        end
        self:drawTextRight(percentage, self.width - 10 - scrollBarWidth, y + dy, r, g, b, 1, UIFont.Small)
    end

    local height = self.itemheight + (separateLine and SMALL_FONT_HGT or 0)
    self:drawRectBorder(0, y, self:getWidth(), height, 0.5,
        self.borderColor.r, self.borderColor.g, self.borderColor.b)
    return y + height
end

function CharacterCreationProfession:PointToSpend()
    return originalPointToSpend(self) - self.cost - getSkillPointsSpent(self.vcmSelectedSpecializations or {})
end

function CharacterCreationProfession:onOptionMouseDown(button, x, y)
    if button.internal == "NEXT" and self:PointToSpend() < 0 then
        return
    end
    return originalOnOptionMouseDown(self, button, x, y)
end

function CharacterCreationProfession:resetBuild()
    clearSpecializations(self)
    self:removeAllTraits()
    self.listboxProf.selected = 1
    self.listboxTraitSelected.selected = -1
    self:checkXPBoost()
end

function CharacterCreationProfession:populateProfessionList(list)
    list:clear()
    local professions = CharacterProfessionDefinition.getProfessions()
    for index = 0, professions:size() - 1 do
        local profession = professions:get(index)
        if profession:getType() == CharacterProfession.UNEMPLOYED then
            local item = list:addItem(profession:getUIName(), profession)
            item.tooltip = profession:getDescription()
        end
    end
end

function CharacterCreationProfession:isTraitEnabled(trait)
    local traitType = trait:getType()
    if VCMProfessionsProfessionTraits.byTrait[traitType] then
        for _, entry in ipairs(self.listboxTraitSelected and self.listboxTraitSelected.items or {}) do
            if entry.item:getType() ~= traitType
                and VCMProfessionsProfessionTraits.byTrait[entry.item:getType()] then
                return false
            end
        end
        if self.listboxTraitSelected then
            local granted = trait:getGrantedTraits()
            for i = 0, granted:size() - 1 do
                local child = CharacterTraitDefinition.getCharacterTraitDefinition(granted:get(i))
                if not child then
                    error("VCM Professions: missing profession-granted trait definition: " .. tostring(granted:get(i)))
                end
                if self:isTraitExcluded(child) and not self.freeTraits:contains(child:getLabel()) then
                    return false
                end
            end
        end
        return originalIsTraitEnabled(self, trait)
    end
    local namespace = tostring(traitType):match("^([^:]+):")
    if not namespace then
        error("VCM Professions: trait has no namespace: " .. tostring(traitType))
    end
    if string.lower(namespace) == "vcmprofessions" then
        return false
    end
    if config.disableSkillTraits() and VCMProfessionsTraits.grantsSkillLevels(trait) then
        return false
    end
    return originalIsTraitEnabled(self, trait)
end

function CharacterCreationProfession:populateTraitList(list)
    originalPopulateTraitList(self, list)
    for trait in pairs(VCMProfessionsProfessionTraits.byTrait) do
        local definition = CharacterTraitDefinition.getCharacterTraitDefinition(trait)
        if definition:getCost() <= 0 and not definition:isFree()
            and self:isTraitEnabled(definition) and not self:isTraitExcluded(definition) then
            list:addItem(definition:getLabel(), definition, definition:getDescription())
        end
    end
end

function CharacterCreationProfession:populateBadTraitList(list)
    originalPopulateBadTraitList(self, list)
    for trait in pairs(VCMProfessionsProfessionTraits.byTrait) do
        local definition = CharacterTraitDefinition.getCharacterTraitDefinition(trait)
        if definition:getCost() < 0 then
            list:removeMatchingItems(definition:getLabel())
        end
    end
end

function CharacterCreationProfession:getTraitColor(trait)
    if not VCMProfessionsProfessionTraits.byTrait[trait:getType()] then
        return originalGetTraitColor(self, trait)
    end
    local color = getCore():getGoodHighlitedColor()
    return { r = color:getR(), g = color:getG(), b = color:getB() }
end

function CharacterCreationProfession:drawTraitMap(y, item, alt)
    if not VCMProfessionsProfessionTraits.byTrait[item.item:getType()] then
        return originalDrawTraitMap(self, y, item, alt)
    end

    self:drawRectBorder(0, y, self:getWidth(), self.itemheight - 1, 0.5,
        self.borderColor.r, self.borderColor.g, self.borderColor.b)
    local isMouseOver = self.mouseoverselected == item.index and not self:isMouseOverScrollBar()
    if self.selected == item.index then
        self:drawRect(0, y, self:getWidth(), self.itemheight - 1, 0.3, 0.7, 0.35, 0.15)
    elseif isMouseOver then
        self:drawRect(1, y + 1, self:getWidth() - 2, item.height - 4, 0.95, 0.05, 0.05, 0.05)
    end
    local texture = item.item:getTexture()
    if texture then
        self:drawTexture(texture, UI_BORDER_SPACING, y + (self.itemheight - texture:getHeight()) / 2, 1, 1, 1, 1)
    end
    local color = getCore():getGoodHighlitedColor()
    local x = texture and texture:getWidth() + UI_BORDER_SPACING * 2 or UI_BORDER_SPACING
    local dy = (self.itemheight - self.fontHgt) / 2
    self:drawText(item.item:getLabel(), x, y + dy, color:getR(), color:getG(), color:getB(), 0.9, UIFont.Small)
    self:drawTextRight(item.item:getRightLabel(), self:getWidth() - UI_BORDER_SPACING * 2, y + dy,
        color:getR(), color:getG(), color:getB(), 0.9, UIFont.Small)
    self.itemheightoverride[item.item:getLabel()] = self.itemheight
    return y + self.itemheight
end

function CharacterCreationProfession:addTrait(trait)
    if not VCMProfessionsTraitSet[trait:getType()] and not self:isTraitEnabled(trait) then
        return
    end
    local profession = VCMProfessionsProfessionTraits.byTrait[trait:getType()]
    if profession then
        self.vcmProfessionDefinition = profession
        VCMProfessionsProfessionTraits.setDescriptorProfession(MainScreen.instance.desc, profession)
    end
    local result = originalAddTrait(self, trait)
    if profession then
        self:changeClothes()
        self:checkXPBoost()
    end
    return result
end

function CharacterCreationProfession:onSelectChosenTrait(trait)
    if self.freeTraits:contains(trait:getLabel()) then
        self.removeTraitBtn:setEnable(false)
        return
    end
    return originalOnSelectChosenTrait(self, trait)
end

function CharacterCreationProfession:removeTrait(index)
    local entry = self.listboxTraitSelected and self.listboxTraitSelected:getItem(index)
    if entry and (VCMProfessionsTraitSet[entry.item:getType()] or self.freeTraits:contains(entry.item:getLabel())) then
        return
    end
    local profession = entry and VCMProfessionsProfessionTraits.byTrait[entry.item:getType()]
    local result = originalRemoveTrait(self, index)
    if profession then
        self.vcmProfessionDefinition = nil
        VCMProfessionsProfessionTraits.setDescriptorProfession(MainScreen.instance.desc, self.profession)
        self:changeClothes()
        self:checkXPBoost()
    end
    return result
end

function CharacterCreationProfession:getSelectedProf()
    return self.profession
end

function CharacterCreationProfession:resetTraits()
    self:resetBuild()
end

function CharacterCreationProfession:randomizeTraits()
    self:resetBuild()
    for _, list in ipairs({ self.listboxBadTrait, self.listboxTrait }) do
        local count = ZombRand(5) + 1
        for _ = 1, count do
            local candidates = {}
            for _, entry in ipairs(list.items) do
                if list == self.listboxBadTrait or entry.item:getCost() <= self:PointToSpend() then
                    candidates[#candidates + 1] = entry.item
                end
            end
            if #candidates == 0 then
                break
            end
            self:addTrait(candidates[ZombRand(#candidates) + 1])
        end
    end
    self:checkXPBoost()
end

function CharacterCreationProfession:loadBuild(box)
    local buildName = box.options[box.selected]
    if not buildName then
        return
    end

    local savedBuilds = BCRC.readSaveFile()
    local build = savedBuilds[buildName]
    if not build then
        return
    end

    local savedTraits = luautils.split(build, ";")
    self:resetBuild()
    local currentSkills = {}
    for skillName in pairs(self.vcmSelectedSpecializations) do
        currentSkills[#currentSkills + 1] = skillName
    end
    for _, skillName in ipairs(currentSkills) do
        setSpecialization(self, skillName, nil)
    end

    local savedNames = {}
    for index = 2, #savedTraits do
        savedNames[savedTraits[index]] = true
    end
    local deferred = {}
    local function loadTrait(traitName)
        if traitName and traitName ~= "" then
            local skillName, tier = getSpecializationForSavedTrait(traitName)
            if skillName then
                if config.isPhysical(skillName) and not config.physicalEnabled() then
                    print("VCM Professions: skipped disabled physical specialization in saved build: " .. traitName)
                else
                    setSpecialization(self, skillName, tier)
                end
            else
                local traitLists = { self.listboxTrait, self.listboxBadTrait }
                local found = false
                for _, item in ipairs(self.listboxTraitSelected.items) do
                    if item.item:getType():getName() == traitName and self.freeTraits:contains(item.item:getLabel()) then
                        found = true
                        break
                    end
                end
                for _, traitList in ipairs(traitLists) do
                    if found then
                        break
                    end
                    for traitIndex, item in ipairs(traitList.items) do
                        if item.item:getType():getName() == traitName and self:isTraitEnabled(item.item) then
                            traitList.selected = traitIndex
                            self:addTrait(item.item)
                            found = true
                            break
                        end
                    end
                    if found then
                        break
                    end
                end
                if not found then
                    print("VCM Professions: skipped unavailable trait in saved build: " .. traitName)
                end
            end
        end
    end
    for index = 2, #savedTraits do
        local traitName = savedTraits[index]
        if (traitName == CharacterTrait.UNDERWEIGHT:getName() and savedNames[CharacterTrait.WEIGHT_LOSS:getName()])
            or (traitName == CharacterTrait.OVERWEIGHT:getName() and savedNames[CharacterTrait.WEIGHT_GAIN:getName()]) then
            deferred[#deferred + 1] = traitName
        else
            loadTrait(traitName)
        end
    end
    for _, traitName in ipairs(deferred) do
        loadTrait(traitName)
    end
    self:checkXPBoost()
end

function CharacterCreationProfession:render()
    originalRender(self)
    local y = self.listboxProf:getY() - MEDIUM_FONT_HGT - 8
    self:drawRect(10, y - 2, self.listboxProf:getWidth(), MEDIUM_FONT_HGT + 4, 1, 0, 0, 0)
    self:drawText(getText("UI_VCMProfessions_Title"), 10, y, 1, 1, 1, 1, UIFont.Medium)
end

