require "OptionScreens/ServerSettingsScreen"
require "OptionScreens/SandboxOptions"
require "ISUI/AdminPanel/ISServerSandboxOptionsUI"

local groups = {
    {
        title = "Sandbox_VCMProfessions_SectionCaps",
        names = { "CappingEnabled", "PhysicalEnabled", "PhysicalCappingEnabled" },
    },
    {
        title = "Sandbox_VCMProfessions_SectionUnexperienced",
        names = { "UnexperiencedSkillLevel", "PhysicalUnexperiencedLevel", "FitnessUnexperiencedLevel",
            "UnqualifiedSkillCap", "PhysicalUnexperiencedCap", "FitnessUnexperiencedCap" },
    },
    {
        title = "Sandbox_VCMProfessions_SectionNovice",
        names = { "NoviceSkillLevel", "PhysicalNoviceLevel", "FitnessNoviceLevel",
            "NoviceSkillCost", "StrengthNoviceCost", "FitnessNoviceCost",
            "NoviceSkillCap", "PhysicalNoviceCap", "FitnessNoviceCap" },
    },
    {
        title = "Sandbox_VCMProfessions_SectionConfident",
        names = { "ConfidentSkillLevel", "PhysicalConfidentLevel", "FitnessConfidentLevel",
            "ConfidentSkillCost", "StrengthConfidentCost", "FitnessConfidentCost",
            "ConfidentSkillCap", "PhysicalConfidentCap", "FitnessConfidentCap" },
    },
    {
        title = "Sandbox_VCMProfessions_SectionMaster",
        names = { "MasterSkillLevel", "PhysicalMasterLevel", "FitnessMasterLevel",
            "MasterSkillCost", "StrengthMasterCost", "FitnessMasterCost",
            "MasterSkillCap", "PhysicalMasterCap", "FitnessMasterCap" },
    },
}
local regularCaps = {
    UnqualifiedSkillCap = true, NoviceSkillCap = true, ConfidentSkillCap = true, MasterSkillCap = true,
}
local physicalCaps = {
    PhysicalUnexperiencedCap = true, PhysicalNoviceCap = true,
    PhysicalConfidentCap = true, PhysicalMasterCap = true,
    FitnessUnexperiencedCap = true, FitnessNoviceCap = true,
    FitnessConfidentCap = true, FitnessMasterCap = true,
}

local function optionName(name)
    return "VCMProfessions." .. name
end

local function installLayout(panel)
    if not panel or not panel.controls or not panel.controls[optionName("NoviceSkillCost")] or panel.vcmLayout then
        return
    end
    panel.vcmLayout = true
    local oldPrerender = panel.prerender
    local sections = {}
    local fontHeight = getTextManager():getFontHeight(UIFont.Medium)
    local otherNames = {}
    local knownNames = {}
    for _, group in ipairs(groups) do
        local title = ISLabel:new(0, 0, fontHeight, getText(group.title), 1, 1, 1, 1, UIFont.Medium)
        title:initialise()
        panel:addChild(title)
        sections[group.title] = title
        for _, name in ipairs(group.names) do
            local key = optionName(name)
            knownNames[key] = true
            local control = panel.controls[key]
            if not control or not panel.labels[key] then
                error("VCM Professions sandbox control missing: " .. name)
            end
        end
    end
    for _, name in ipairs(panel.settingNames) do
        if not knownNames[name] then
            otherNames[#otherNames + 1] = name
        end
    end

    local joypadState = panel:recordJoypadState()
    panel:clearJoypadButtonsList()
    local orderedNames = {}
    local y = 11
    for _, key in ipairs(otherNames) do
        local label = panel.labels[key]
        local control = panel.controls[key]
        label:setY(y)
        control:setY(y)
        y = y + math.max(label:getHeight(), control:getHeight()) + 10
        panel:insertNewLineOfButtons(control)
        orderedNames[#orderedNames + 1] = key
    end
    for _, group in ipairs(groups) do
        local title = sections[group.title]
        local firstLabel = panel.labels[optionName(group.names[1])]
        title:setX(firstLabel:getX())
        title:setY(y)
        y = y + fontHeight + 10
        for _, name in ipairs(group.names) do
            local key = optionName(name)
            local control = panel.controls[key]
            local label = panel.labels[key]
            label:setY(y)
            control:setY(y)
            y = y + math.max(label:getHeight(), control:getHeight()) + 10
            panel:insertNewLineOfButtons(control)
            orderedNames[#orderedNames + 1] = key
        end
        y = y + 10
    end
    panel.settingNames = orderedNames
    panel:setScrollHeight(y)
    panel:setYScroll(math.max(panel:getYScroll(), math.min(0, panel:getHeight() - y)))
    panel:restoreJoypadState(joypadState)

    panel.vcmUpdateSettings = function(self)
        local controls = self.controls
        local capEnabled = controls[optionName("CappingEnabled")]:isSelected(1)
        local physicalEnabled = controls[optionName("PhysicalEnabled")]:isSelected(1)
        local physicalCapEnabled = physicalEnabled and controls[optionName("PhysicalCappingEnabled")]:isSelected(1)
        for _, group in ipairs(groups) do
            for _, name in ipairs(group.names) do
                local enabled = true
                if regularCaps[name] then
                    enabled = capEnabled
                elseif name == "PhysicalCappingEnabled" or physicalCaps[name]
                    or name:match("^Physical.*Level$") or name:match("^Fitness")
                    or name:match("^Strength") then
                    enabled = physicalEnabled and (not physicalCaps[name] or physicalCapEnabled)
                end
                local key = optionName(name)
                local control = controls[key]
                if not enabled then
                    local option = getSandboxOptions():getOptionByName(key)
                    if not option then
                        error("VCM Professions sandbox option missing: " .. key)
                    end
                    local default = option:getDefaultValue()
                    if control.isTickBox then
                        control:setSelected(1, default)
                    elseif control:getText() ~= tostring(default) then
                        control:setText(tostring(default))
                    end
                end
                local labelColor = enabled and 1 or 0.4
                self.labels[key]:setColor(labelColor, labelColor, labelColor)
                if control.isTickBox then
                    control:disableOption(control.optionsIndex[1], not enabled)
                    if control.vcmDefaultBorderAlpha == nil then
                        control.vcmDefaultBorderAlpha = control.borderColor.a
                    end
                    control.borderColor.a = enabled and control.vcmDefaultBorderAlpha or 0.1
                else
                    if control.vcmClearButton == nil then
                        control.vcmClearButton = control:hasClearButton()
                    end
                    if control.vcmEnabled ~= enabled then
                        control:setEditable(enabled)
                        control:setClearButton(enabled and control.vcmClearButton)
                        local color = enabled and 1 or 0.4
                        control:setTextRGBA(color, color, color, 1)
                        control.vcmEnabled = enabled
                    end
                end
            end
        end
    end

    panel.prerender = function(self)
        oldPrerender(self)
        self:vcmUpdateSettings()
    end
    return panel
end

local originalSandboxPanel = SandboxOptionsScreen.createPanel
function SandboxOptionsScreen:createPanel(page)
    local panel = originalSandboxPanel(self, page)
    self.vcmSandboxPanel = installLayout(panel) or self.vcmSandboxPanel
    return panel
end

local originalAdminPanel = ISServerSandboxOptionsUI.createPanel
function ISServerSandboxOptionsUI:createPanel(page)
    local panel = originalAdminPanel(self, page)
    self.vcmSandboxPanel = installLayout(panel) or self.vcmSandboxPanel
    return panel
end

local originalServerCreate = ServerSettingsScreen.create
function ServerSettingsScreen:create()
    originalServerCreate(self)
    for _, item in ipairs(self.pageEdit.listbox.items) do
        self.pageEdit.vcmSandboxPanel = installLayout(item.item.panel) or self.pageEdit.vcmSandboxPanel
    end
    local page = self.pageEdit
    local settingsToUI = page.settingsToUIAux
    page.settingsToUIAux = function(self, category, options)
        settingsToUI(self, category, options)
        if category == "Sandbox" and self.vcmSandboxPanel then
            self.vcmSandboxPanel:vcmUpdateSettings()
        end
    end
    local settingsFromUI = page.settingsFromUIAux
    page.settingsFromUIAux = function(self, category, options)
        if category == "Sandbox" and self.vcmSandboxPanel then
            self.vcmSandboxPanel:vcmUpdateSettings()
        end
        settingsFromUI(self, category, options)
    end
end

local function wrapSettingsMethods(screen)
    local settingsToUI = screen.settingsToUI
    screen.settingsToUI = function(self, options)
        settingsToUI(self, options)
        if self.vcmSandboxPanel then
            self.vcmSandboxPanel:vcmUpdateSettings()
        end
    end
    local settingsFromUI = screen.settingsFromUI
    screen.settingsFromUI = function(self, options)
        if self.vcmSandboxPanel then
            self.vcmSandboxPanel:vcmUpdateSettings()
        end
        settingsFromUI(self, options)
    end
end

wrapSettingsMethods(SandboxOptionsScreen)
wrapSettingsMethods(ISServerSandboxOptionsUI)

local originalSetSandboxVars = SandboxOptionsScreen.setSandboxVars
function SandboxOptionsScreen:setSandboxVars()
    originalSetSandboxVars(self)
    local professionScreen = MainScreen.instance and MainScreen.instance.charCreationProfession
    if professionScreen then
        professionScreen:refreshTraitVisibility()
        professionScreen:refreshSkillSettings()
    end
end
