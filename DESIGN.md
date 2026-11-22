# Design

VCM Professions bundles the previous version's media files, including its skill
panel, sandbox settings, progression caps, and client/server synchronization.
Internal `VCMProfessions` identifiers are retained for existing skill traits and
sandbox settings. This version replaces the old VCM Professions mod and should
not be enabled alongside the former VCM Profession mod.

The bundled profession-trait system maps each profession to one selectable
trait. The trait carries its profession's granted traits but no direct XP
boosts. Character creation records the chosen profession on the descriptor and
offsets boosts from profession-granted traits; the skill list and initialization
also exclude those granted boosts. The cost uses the profession cost and the
positive direct and granted skill bonuses. A player may select at most one
profession trait.

The required VCM Trait Groups integration reads the existing
`VCMProfessionsTraitGroups` override table and displays these traits as
`VCM Prof`.
