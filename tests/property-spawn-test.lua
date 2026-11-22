local root = [[Contents\mods\VCMProfessions\42.22\media\lua\client\]]
for _, name in ipairs({ "VCMProfessionsConfig", "OptionScreens/CharacterCreationProfession",
    "OptionScreens/CharacterCreationMain", "OptionScreens/CoopCharacterCreation",
    "OptionScreens/CoopMapSpawnSelect" }) do
    package.loaded[name] = true
end
local callbacks = {}
Events = {
    OnLoadedMapZones = { Add = function(f) callbacks.loaded = f end },
    OnCreatePlayer = { Add = function(f) callbacks.created = f end },
}
local enabled, client, fixed, safehouse, challenge = true, true, false, false, false
VCMProfessionsConfig = { traitModuleEnabled = function() return enabled end }
VCMProfessionsPropertyTraits = { homeless = "homeless", poor = "poor", successful = "successful" }
CharacterProfession = { UNEMPLOYED = { getName = function() return "unemployed" end } }
function isClient() return client end
function isDemo() return false end
function getCore() return { isChallenge = function() return challenge end, isTutorial = function() return false end } end
function getText(key) return key end
function ZombRand() return 0 end
local protected = {}
SafeHouse = { getSafehouseList = function()
    return { size = function() return #protected end, get = function(_, i) return protected[i + 1] end }
end }
local buildings = {}
local meta = {
    isValidSquare = function() return true end,
    getRoomAt = function(_, x, y, z)
        local b = buildings[x .. ":" .. y .. ":" .. z]
        if b then return { getBuilding = function() return b end } end
    end,
    getBuildingAt = function() return nil end,
}
local function building(max, residential)
    return {
        getMaxLevel = function() return max end,
        containsRoom = function(_, name) return residential and (name == "bedroom" or name == "kitchen") end,
    }
end
buildings["10770:10271:0"] = building(0, true)
buildings["100:200:0"] = building(0, true)
buildings["101:201:0"] = building(1, true)
buildings["102:202:0"] = building(1, false)
local region = { name = "Muldraugh, KY", points = { unemployed = {
    { posX = 10770, posY = 10271 }, { posX = 100, posY = 200 },
    { posX = 101, posY = 201 }, { posX = 102, posY = 202 },
    { posX = 103, posY = 203 },
} } }
local desc = { getCharacterProfession = function() return { getName = function() return "unemployed" end } end }
local world = {
    getMetaGrid = function() return meta end,
    getLuaPlayerDesc = function() return desc end,
    getLuaPosX = function(self) return self.x end,
    getLuaPosY = function(self) return self.y end,
    setLuaPosX = function(self, x) self.x = x end,
    setLuaPosY = function(self, y) self.y = y end,
    setLuaPosZ = function(self, z) self.z = z end,
}
function getWorld() return world end
local selector = {
    selectedRegion = region,
    getFixedSpawnRegion = function() return fixed and {} or nil end,
    getSafehouseSpawnRegion = function() return safehouse and {} or nil end,
}
MapSpawnSelect = { instance = selector }
CoopMapSpawnSelect = { instance = selector }
local screen = { listboxTraitSelected = { items = {} } }
CharacterCreationProfession = { instance = screen }
CharacterCreationMain = { onOptionMouseDown = function() end }
CoopCharacterCreation = { accept1 = function() return true end }
MainScreen = { instance = { desc = desc } }
local messages = {}
HaloTextHelper = { addBadText = function(_, text) messages[#messages + 1] = text end }
dofile(root .. "VCMProfessionsProperty.lua")
local function choose(mode) return VCMProfessionsProperty.choose(region, "unemployed", mode, meta) end
local function newCharacter()
    CharacterCreationMain:onOptionMouseDown({ internal = "NEXT" })
    callbacks.loaded()
end
assert(choose("poor").posX == 10770)
assert(choose("regular").posX == 100)
assert(choose("successful").posX == 101)
assert(choose("homeless").posX == 103)
local legacy = { name = "Other", points = { unemployed = { { worldX = 0, worldY = 0, posX = 101, posY = 201, posZ = 0 } } } }
assert(VCMProfessionsProperty.choose(legacy, "unemployed", "successful", meta) == legacy.points.unemployed[1])
protected[1] = { containsLocation = function(_, x) return x == 101 end }
assert(choose("successful") == nil)
protected[1] = nil
callbacks.loaded()
assert(world.x == nil)
newCharacter()
assert(world.x == 100 and world.y == 200 and world.z == 0)
screen.listboxTraitSelected.items = { { item = { getType = function() return "successful" end } } }
newCharacter()
assert(world.x == 101)
fixed = true
world.x = 999
newCharacter()
assert(world.x == 999)
callbacks.created(0, { getHoursSurvived = function() return 0 end })
assert(#messages == 1)
messages = {}
fixed = false
selector.selectedRegion = { name = "UI_mapspawn_Safehouse", points = region.points }
safehouse = true
newCharacter()
assert(world.x == 999)
safehouse = false
selector.selectedRegion = { key = "WithPlayer2", points = region.points }
local coop = setmetatable({ charCreationProfession = screen, playerIndex = 1 }, { __index = CoopCharacterCreation })
assert(coop:accept1() and world.x == 999)
selector.selectedRegion = region
enabled = false
newCharacter()
assert(world.x == 999)
enabled = true
assert(coop:accept1() and world.x == 101)
protected[1] = { containsLocation = function(_, x) return x == 101 end }
world.x = 999
newCharacter()
assert(world.x == 999)
callbacks.created(0, { getHoursSurvived = function() return 0 end })
assert(#messages == 1)
assert(#messages == 1 and messages[1] == "UI_VCMProfessions_PropertyFallback")
world.x, world.y = 101, 201
newCharacter()
assert(world.x == 10770 and world.y == 10271)
protected[1] = { containsLocation = function() return true end }
newCharacter()
assert(world.x == 10770)
callbacks.created(0, { getHoursSurvived = function() return 0 end })
assert(messages[#messages] == "UI_VCMProfessions_PropertyUnsafeFallback")
print("Property spawn classification, restrictions, overrides and fallback tests passed")
