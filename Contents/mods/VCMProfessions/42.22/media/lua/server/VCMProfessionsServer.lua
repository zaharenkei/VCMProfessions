require "VCMProfessionsProgression"
require "VCMProfessionsCrafting"

local initializedKnowledge = setmetatable({}, { __mode = "k" })
Events.OnClientCommand.Add(function(module, command, player)
    if module == "VCMProfessions" and command == "InitializeSkills" then
        VCMProfessionsProgression.initializeServerPlayer(player)
    elseif module == "VCMProfessions" and command == "InitializeKnowledge" and not initializedKnowledge[player] then
        VCMProfessionsCrafting.grantKnowledge(player)
        initializedKnowledge[player] = true
    end
end)
