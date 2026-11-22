local root = [[Contents\mods\VCMProfessions\42.22\media\lua\client\]]
for _, name in ipairs({
    "OptionScreens/ServerSettingsScreen", "OptionScreens/SandboxOptions",
    "ISUI/AdminPanel/ISServerSandboxOptionsUI",
}) do package.loaded[name] = true end

local function makeScreen(categoryControls)
    return {
        createPanel = function(self) return self.testPanel end,
        settingsToUI = function(self, options)
            for name, value in pairs(options) do self.controls[name].selected[1] = value end
        end,
        settingsFromUI = function(self, options)
            for name in pairs(options) do options[name] = self.controls[name].selected[1] end
        end,
    }
end
SandboxOptionsScreen = makeScreen()
SandboxOptionsScreen.setSandboxVars = function() end
ISServerSandboxOptionsUI = makeScreen()
ServerSettingsScreen = {
    create = function(self)
        local page = self.pageEdit
        page.settingsToUIAux = function(p, category, options)
            for name, value in pairs(options) do p.controls[category][name].selected[1] = value end
        end
        page.settingsFromUIAux = function(p, category, options)
            for name in pairs(options) do options[name] = p.controls[category][name].selected[1] end
        end
    end,
}
MainScreen = {}
dofile(root .. "VCMProfessionsSandboxUI.lua")
local skillTraits = "VCMProfessions.DisableSkillTraits"
local function controls()
    return { [skillTraits] = { selected = {} } }
end
local function exercise(screen, toUI, fromUI)
    local options = { [skillTraits] = true }
    toUI(screen, options)
    local c = screen.controls.Sandbox or screen.controls
    assert(c[skillTraits].selected[1] == true)
    c[skillTraits].selected[1] = false
    fromUI(screen, options)
    assert(options[skillTraits] == false)
    assert(c[skillTraits].selected[1] == false)
end
for _, class in ipairs({ SandboxOptionsScreen, ISServerSandboxOptionsUI }) do
    local screen = setmetatable({ controls = controls() }, { __index = class })
    exercise(screen, class.settingsToUI, class.settingsFromUI)
end
local server = setmetatable({ pageEdit = {
    controls = { Sandbox = controls() }, listbox = { items = {} },
} }, { __index = ServerSettingsScreen })
server:create()
exercise(server.pageEdit,
    function(p, options) p:settingsToUIAux("Sandbox", options) end,
    function(p, options) p:settingsFromUIAux("Sandbox", options) end)

local file = assert(io.open([[Contents\mods\VCMProfessions\42.22\media\sandbox-options.txt]], "r"))
local contents = file:read("*a")
file:close()
local settings = {}
for name, body in contents:gmatch("option%s+([%w%.]+)%s*(%b{})") do
    local page = body:match("page%s*=%s*([%w_]+)")
    assert(page == "VCMProfessions", name .. " is not on the merged page")
    local kind = assert(body:match("type%s*=%s*([%w_]+)"))
    local default = assert(body:match("default%s*=%s*([%w]+)"))
    settings[#settings + 1] = {
        name = name, kind = kind,
        default = kind == "boolean" and default == "true" or tonumber(default),
    }
end
assert(#settings > 1)

UIFont = { Medium = 1 }
function getTextManager() return { getFontHeight = function() return 12 end } end
function getText(key) return key end
local function widget()
    return {
        setX = function(self, x) self.x = x end,
        getX = function(self) return self.x or 10 end,
        setY = function(self, y) self.y = y end,
        getHeight = function() return 20 end,
        setColor = function() end,
        initialise = function() end,
    }
end
ISLabel = { new = function() return widget() end }
local defaults = {}
function getSandboxOptions()
    return { getOptionByName = function(_, name)
        assert(defaults[name] ~= nil, "missing default for " .. name)
        return { getDefaultValue = function() return defaults[name] end }
    end }
end
local function makePanel()
    local panel = {
        controls = {}, labels = {}, settingNames = {}, prerender = function() end,
        addChild = function() end, recordJoypadState = function() return {} end,
        clearJoypadButtonsList = function() end, insertNewLineOfButtons = function() end,
        setScrollHeight = function(self, value) self.scrollHeight = value end,
        getYScroll = function() return 0 end, setYScroll = function() end,
        getHeight = function() return 400 end, restoreJoypadState = function() end,
    }
    for _, setting in ipairs(settings) do
        defaults[setting.name] = setting.default
        local control = widget()
        if setting.kind == "boolean" then
            control.isTickBox = true
            control.selected = { setting.default }
            control.optionsIndex = { 1 }
            control.borderColor = { a = 1 }
            control.isSelected = function(self) return self.selected[1] end
            control.setSelected = function(self, _, value) self.selected[1] = value end
            control.disableOption = function(self, _, disabled) self.disabled = disabled end
        else
            control.text = tostring(setting.default)
            control.getText = function(self) return self.text end
            control.setText = function(self, value) self.text = value end
            control.hasClearButton = function() return true end
            control.setEditable = function(self, value) self.editable = value end
            control.setClearButton = function() end
            control.setTextRGBA = function() end
        end
        panel.controls[setting.name] = control
        panel.labels[setting.name] = widget()
        panel.settingNames[#panel.settingNames + 1] = setting.name
    end
    return panel
end
local function checkLayout(panel)
    assert(panel.vcmLayout and #panel.settingNames == #settings)
    assert(panel.settingNames[1] == skillTraits)
    local seen = {}
    for _, name in ipairs(panel.settingNames) do
        assert(not seen[name], "duplicate sandbox control " .. name)
        seen[name] = true
    end
    for _, setting in ipairs(settings) do assert(seen[setting.name], "missing " .. setting.name) end
    local controls = panel.controls
    controls[skillTraits]:setSelected(1, false)
    controls["VCMProfessions.CappingEnabled"]:setSelected(1, false)
    controls["VCMProfessions.NoviceSkillCap"]:setText("9")
    panel:vcmUpdateSettings()
    assert(controls[skillTraits]:isSelected(1) == false)
    assert(controls["VCMProfessions.NoviceSkillCap"]:getText() == "4")
    assert(controls["VCMProfessions.NoviceSkillCap"].editable == false)
    controls["VCMProfessions.CappingEnabled"]:setSelected(1, true)
    panel:vcmUpdateSettings()
    assert(controls["VCMProfessions.NoviceSkillCap"].editable == true)
end
for _, class in ipairs({ SandboxOptionsScreen, ISServerSandboxOptionsUI }) do
    local panel = makePanel()
    local screen = setmetatable({ testPanel = panel }, { __index = class })
    assert(screen:createPanel("VCMProfessions") == panel)
    checkLayout(panel)
end
local serverPanel = makePanel()
local serverWithPanel = setmetatable({ pageEdit = {
    controls = {}, listbox = { items = { { item = { panel = serverPanel } } } },
} }, { __index = ServerSettingsScreen })
serverWithPanel:create()
checkLayout(serverPanel)
print("Skill-trait checkbox preserves saved settings in all sandbox screens")
