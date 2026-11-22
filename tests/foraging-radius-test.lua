local root = [[Contents\mods\VCMProfessions\42.22\media\lua\client\]]
package.loaded["Foraging/ISBaseIcon"] = true
package.loaded["Foraging/ISSearchManager"] = true
VCMProfessionsForagingTraits = { perceptive = "perceptive", blind = "blind" }
ISBaseIcon = {
    doVisionCheck = function() return 8 end,
    isNearby = function(self) return self.distanceToPlayer <= self.maxRadius end,
    updateAlpha = function(self) self.alpha = 1 - self.distanceToPlayer / self.maxRadius end,
}
ISSearchManager = { getOverlayRadius = function() return 8 end }
dofile(root .. "VCMProfessionsForaging.lua")

local trait
local character = { hasTrait = function(_, id) return trait == id end }
local icon = setmetatable({ character = character, maxRadius = 10, distanceToPlayer = 8.5 },
    { __index = ISBaseIcon })
local manager = setmetatable({ character = character }, { __index = ISSearchManager })
assert(icon:doVisionCheck() == 8 and manager:getOverlayRadius() == 8)
assert(icon:isNearby())
trait = "perceptive"
assert(icon:doVisionCheck() == 10 and manager:getOverlayRadius() == 10)
icon.distanceToPlayer = 11
assert(icon:isNearby())
icon:updateAlpha()
assert(icon.alpha > 0 and icon.maxRadius == 10)
trait = "blind"
assert(icon:doVisionCheck() == 6 and manager:getOverlayRadius() == 6)
icon.distanceToPlayer = 8
assert(not icon:isNearby())
print("Foraging radius multipliers and icon visibility tests passed")
