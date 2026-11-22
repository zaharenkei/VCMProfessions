# VCM Professions

VCM Professions bundles the skill-specialization panel and settings from the
previous version. It replaces the older VCM Professions mod and uses the same
mod ID; do not enable it alongside the former VCM Profession mod.

## Features

The character-creation panel replaces the profession list with configurable
skill ranks and caps. Profession traits reuse profession names, icons and
granted traits; only one profession trait can be chosen. Their point cost is
the profession's point cost, reduced by one per positive skill bonus, including
bonuses from its directly granted traits. Those skill bonuses are excluded
from the character's starting skills.
The Unemployed profession trait uses a custom icon.

Profession traits appear in the positive trait list and in green regardless of
their point cost; their actual costs are unchanged. VCM Trait Groups is required
and displays them under **VCM Prof**.

The bundled system retains the `VCMProfessions` trait IDs and sandbox option
namespace for compatibility. All settings are on the VCM Professions sandbox
page. Test existing saves before migrating.

## Installation

Requires Project Zomboid 42.22 or later and VCM Trait Groups. Copy
`Contents\mods\VCMProfessions` to `%USERPROFILE%\Zomboid\mods\` and place
`LICENSE` in the copied mod folder, or run `deploy-local.bat`, then enable both
mods. The script replaces files of an existing local VCM Professions
installation. Install the same version on the server and clients for
multiplayer.

## Workshop staging

Run `deploy-workshop.bat` to copy runtime files, the license and the preview to
`%USERPROFILE%\Zomboid\Workshop\VCMProfessions`. It preserves existing Workshop
metadata and does not upload. Workshop item metadata must be configured through
the game before publishing.

## Development

The Lua regression tests in `tests` run from this directory, for example:

```powershell
Get-ChildItem tests\*-test.lua | ForEach-Object { lua $_.FullName }
```

In-game character creation and multiplayer should also be tested.

## License

MIT; see [LICENSE](LICENSE).
