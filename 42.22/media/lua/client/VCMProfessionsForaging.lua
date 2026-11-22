require "Foraging/ISBaseIcon"
require "Foraging/ISSearchManager"

local function radiusFactor(character)
    if character:hasTrait(VCMProfessionsForagingTraits.perceptive) then
        return 1.25
    elseif character:hasTrait(VCMProfessionsForagingTraits.blind) then
        return 0.75
    end
    return 1
end

local originalVisionCheck = ISBaseIcon.doVisionCheck
function ISBaseIcon:doVisionCheck()
    return originalVisionCheck(self) * radiusFactor(self.character)
end

local originalIsNearby = ISBaseIcon.isNearby
function ISBaseIcon:isNearby()
    local factor = radiusFactor(self.character)
    if factor == 1 then
        return originalIsNearby(self)
    end
    return self.distanceToPlayer <= self.maxRadius * factor
end

local originalUpdateAlpha = ISBaseIcon.updateAlpha
function ISBaseIcon:updateAlpha()
    local maxRadius = self.maxRadius
    self.maxRadius = maxRadius * radiusFactor(self.character)
    originalUpdateAlpha(self)
    self.maxRadius = maxRadius
end

local originalOverlayRadius = ISSearchManager.getOverlayRadius
function ISSearchManager:getOverlayRadius()
    return originalOverlayRadius(self) * radiusFactor(self.character)
end
