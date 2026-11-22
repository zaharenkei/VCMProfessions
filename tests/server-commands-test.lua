local root = [[Contents\mods\VCMProfessions\42.22\media\lua\server\]]
package.loaded.VCMProfessionsProgression = true
package.loaded.VCMProfessionsCrafting = true
local skills, knowledge = {}, {}
VCMProfessionsProgression = { initializeServerPlayer = function(player) skills[player] = (skills[player] or 0) + 1 end }
VCMProfessionsCrafting = { grantKnowledge = function(player) knowledge[player] = (knowledge[player] or 0) + 1 end }
local dispatch
Events = { OnClientCommand = { Add = function(f) dispatch = f end } }
dofile(root .. "VCMProfessionsServer.lua")
local alice, bob = {}, {}
dispatch("OtherMod", "InitializeKnowledge", alice)
dispatch("VCMProfessions", "OtherCommand", alice)
assert(not knowledge[alice] and not skills[alice])
dispatch("VCMProfessions", "InitializeKnowledge", alice, { player = bob })
dispatch("VCMProfessions", "InitializeKnowledge", alice)
assert(knowledge[alice] == 1 and not knowledge[bob])
dispatch("VCMProfessions", "InitializeKnowledge", bob)
assert(knowledge[bob] == 1)
dispatch("VCMProfessions", "InitializeSkills", alice, { player = bob })
assert(skills[alice] == 1 and not skills[bob])
print("Server commands use the connection player and initialize knowledge once")
