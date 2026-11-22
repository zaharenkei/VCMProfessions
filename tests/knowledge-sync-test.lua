local root = [[Contents\mods\VCMProfessions\42.22\media\lua\]]
package.loaded.VCMProfessionsConfig = true
package.loaded.VCMProfessionsProgression = true
VCMProfessionsGeneratorTrait = "generator"
VCMProfessionsCraftingTraits = { electrician = "electrician" }
VCMProfessionsProgression = { initializeServerPlayer = function() end }
local create, newGame, serverCommand
Events = {
    OnCreatePlayer = { Add = function(f) create = f end },
    OnNewGame = { Add = function(f) newGame = f end },
    OnClientCommand = { Add = function(f) serverCommand = f end },
}
local sent
function isClient() return true end
function sendClientCommand(player, module, command, args)
    sent = { player = player, module = module, command = command, args = args }
end
dofile(root .. [[shared\VCMProfessionsCrafting.lua]])
VCMProfessionsCrafting.recipes = function() return { electrician = {} } end
package.loaded.VCMProfessionsCrafting = true
dofile(root .. [[server\VCMProfessionsServer.lua]])
local function makePlayer(hasGenerator)
    local player = { recipes = {} }
    function player:hasTrait(trait) return hasGenerator and trait == "generator" end
    function player:learnRecipe(recipe, checkMeta)
        assert(checkMeta == false)
        self.recipes[recipe] = (self.recipes[recipe] or 0) + 1
    end
    return player
end
local clientPlayer, serverPlayer = makePlayer(true), makePlayer(true)
create(0, clientPlayer)
assert(clientPlayer.recipes.Generator == 1)
assert(sent.player == clientPlayer and sent.module == "VCMProfessions" and sent.command == "InitializeKnowledge")
serverCommand(sent.module, sent.command, serverPlayer, sent.args)
assert(serverPlayer.recipes.Generator == 1)
serverCommand(sent.module, sent.command, serverPlayer, sent.args)
assert(serverPlayer.recipes.Generator == 1)
local unqualified = makePlayer(false)
serverCommand(sent.module, sent.command, unqualified, { trait = "generator" })
assert(not unqualified.recipes.Generator)
local electricianClient, electricianServer = makePlayer(false), makePlayer(false)
function electricianClient:hasTrait(trait) return trait == "electrician" end
function electricianServer:hasTrait(trait) return trait == "electrician" end
create(0, electricianClient)
serverCommand(sent.module, sent.command, electricianServer, sent.args)
assert(electricianClient.recipes.Generator == 1 and electricianServer.recipes.Generator == 1)
print("Generator and Electrician knowledge is independently granted on client and server")
