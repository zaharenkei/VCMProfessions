require "VCMProfessionsConfig"
require "OptionScreens/CharacterCreationProfession"
require "OptionScreens/CharacterCreationMain"
require "OptionScreens/CoopCharacterCreation"
require "OptionScreens/CoopMapSpawnSelect"

VCMProfessionsProperty = {}
local property = VCMProfessionsProperty
local poorSpawns = {
    ["Muldraugh, KY"] = {
        ["10770:10271:0"] = true, ["10637:10267:0"] = true, ["10720:10195:0"] = true,
        ["10997:9699:0"] = true, ["10819:9437:0"] = true, ["10695:9383:0"] = true,
        ["10776:9764:0"] = true, ["10911:10037:0"] = true, ["10721:10630:0"] = true,
        ["10718:9989:0"] = true,
    },
    ["Riverside, KY"] = {
        ["5739:5258:0"] = true, ["5832:5233:0"] = true, ["6021:5364:0"] = true,
        ["6076:5375:0"] = true, ["6117:5473:0"] = true, ["6167:5412:0"] = true,
        ["6443:5562:0"] = true, ["6408:5498:0"] = true, ["7342:5981:0"] = true,
        ["7396:6017:0"] = true,
    },
    ["Rosewood, KY"] = {
        ["7976:11402:0"] = true, ["7822:11286:0"] = true, ["8035:11560:0"] = true,
        ["8078:11547:1"] = true, ["8042:11439:1"] = true, ["8303:11689:0"] = true,
        ["8495:11550:0"] = true, ["7989:11755:0"] = true, ["8114:12223:0"] = true,
        ["8431:12135:0"] = true,
    },
    ["West Point, KY"] = {
        ["11308:6671:0"] = true, ["11218:6796:0"] = true, ["10936:6645:0"] = true,
        ["11536:6934:0"] = true, ["12023:6980:0"] = true, ["11936:6749:0"] = true,
        ["11735:6691:0"] = true, ["10955:6964:0"] = true, ["11913:7070:0"] = true,
        ["11967:6749:0"] = true,
    },
}

local function coordinates(point)
    if point.position or type(point.posX) ~= "number" or type(point.posY) ~= "number" then
        return nil
    end
    local x, y = point.posX, point.posY
    if point.worldX ~= nil then
        if type(point.worldX) ~= "number" or type(point.worldY) ~= "number" then return nil end
        x, y = point.worldX * 300 + x, point.worldY * 300 + y
    end
    if point.posZ ~= nil and type(point.posZ) ~= "number" then return nil end
    return x, y, point.posZ or 0
end

local function isProtected(x, y)
    if not isClient() then return false end
    local houses = SafeHouse.getSafehouseList()
    for i = 0, houses:size() - 1 do
        if houses:get(i):containsLocation(x, y) then return true end
    end
    return false
end

local function matches(meta, region, point, mode)
    local x, y, z = coordinates(point)
    if not x or not meta:isValidSquare(x, y) or isProtected(x, y) then return false end
    local room = meta:getRoomAt(x, y, z)
    local building = room and room:getBuilding() or meta:getBuildingAt(x, y, z)
    if mode == "homeless" then return not room and not building end
    if not room or not building then return false end
    local key = tostring(x) .. ":" .. tostring(y) .. ":" .. tostring(z)
    local knownPoor = poorSpawns[region.name] and poorSpawns[region.name][key]
    if mode == "poor" then return knownPoor == true end
    if knownPoor or not building:containsRoom("bedroom") or not building:containsRoom("kitchen") then
        return false
    end
    local maxLevel = building:getMaxLevel()
    return (mode == "regular" and maxLevel == 0) or (mode == "successful" and maxLevel == 1)
end

function property.choose(region, professionName, mode, meta)
    local points = region.points[professionName] or region.points[CharacterProfession.UNEMPLOYED:getName()]
    if not points then return nil end
    local candidates = {}
    for _, point in ipairs(points) do
        if matches(meta, region, point, mode) then candidates[#candidates + 1] = point end
    end
    if #candidates == 0 then return nil end
    return candidates[ZombRand(#candidates) + 1]
end

local function ensureSafeFallback(world, region, professionName)
    local x, y = world:getLuaPosX(), world:getLuaPosY()
    if not isProtected(x, y) then return true end
    local points = region.points[professionName] or region.points[CharacterProfession.UNEMPLOYED:getName()]
    local candidates = {}
    for _, point in ipairs(points or {}) do
        local px, py = coordinates(point)
        if px and not isProtected(px, py) and world:getMetaGrid():isValidSquare(px, py) then
            candidates[#candidates + 1] = point
        end
    end
    if #candidates == 0 then
        return false
    end
    local px, py, pz = coordinates(candidates[ZombRand(#candidates) + 1])
    world:setLuaPosX(px)
    world:setLuaPosY(py)
    world:setLuaPosZ(pz)
    return true
end

local function selectedMode(screen)
    for _, entry in ipairs(screen.listboxTraitSelected.items) do
        for name, trait in pairs(VCMProfessionsPropertyTraits) do
            if entry.item:getType() == trait then return name end
        end
    end
    return "regular"
end

local function specialSpawn(selector, region)
    if getCore():isChallenge() or (region.key and region.key:match("^WithPlayer%d+$")) then return true end
    if not isClient() then return false end
    if selector:getFixedSpawnRegion() then return true end
    return region.name == getText("UI_mapspawn_Safehouse")
        and selector:getSafehouseSpawnRegion() ~= nil
end

local warnings = {}
local preparingPlayer = false
local originalCharacterAction = CharacterCreationMain.onOptionMouseDown
function CharacterCreationMain:onOptionMouseDown(button, x, y)
    if button.internal == "NEXT" then preparingPlayer = true end
    return originalCharacterAction(self, button, x, y)
end

local function applySpawn(selector, region, screen, playerIndex)
    warnings[playerIndex] = nil
    if not VCMProfessionsConfig.traitModuleEnabled("Property") or not region or not screen
        or not screen.listboxTraitSelected then return end
    if specialSpawn(selector, region) then
        warnings[playerIndex] = "UI_VCMProfessions_PropertyFallback"
        print("VCM Professions: server, safehouse, challenge or co-op spawn overrides property preferences")
        return
    end
    local world = getWorld()
    local mode = selectedMode(screen)
    local profession = MainScreen.instance.desc:getCharacterProfession():getName()
    local point = property.choose(region, profession, mode, world:getMetaGrid())
    if not point then
        local fallbackSafe = ensureSafeFallback(world, region, profession)
        warnings[playerIndex] = fallbackSafe and "UI_VCMProfessions_PropertyFallback"
            or "UI_VCMProfessions_PropertyUnsafeFallback"
        print("VCM Professions: no permitted " .. mode .. " property spawn in " .. tostring(region.name)
            .. "; using the normal spawn")
        if not fallbackSafe then
            print("VCM Professions: no known spawn outside safehouses; the vanilla fallback may be protected")
        end
        return
    end
    local x, y, z = coordinates(point)
    world:setLuaPosX(x)
    world:setLuaPosY(y)
    world:setLuaPosZ(z)
end

Events.OnLoadedMapZones.Add(function()
    if not preparingPlayer then return end
    preparingPlayer = false
    if isDemo() or getCore():isTutorial() or not MainScreen.instance
        or not MainScreen.instance.desc or not CharacterCreationProfession.instance
        or not MapSpawnSelect.instance then return end
    local world = getWorld()
    if world:getLuaPlayerDesc() ~= MainScreen.instance.desc then return end
    applySpawn(MapSpawnSelect.instance, MapSpawnSelect.instance.selectedRegion,
        CharacterCreationProfession.instance, 0)
end)

local originalAccept = CoopCharacterCreation.accept1
function CoopCharacterCreation:accept1()
    if not originalAccept(self) then return false end
    applySpawn(CoopMapSpawnSelect.instance, CoopMapSpawnSelect.instance.selectedRegion,
        self.charCreationProfession, self.playerIndex)
    return true
end

Events.OnCreatePlayer.Add(function(playerIndex, player)
    if warnings[playerIndex] then
        local message = warnings[playerIndex]
        warnings[playerIndex] = nil
        if player:getHoursSurvived() <= 0.25 then
            HaloTextHelper.addBadText(player, getText(message))
        end
    end
end)
