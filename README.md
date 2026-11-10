# Hailstone QoL

Hailstone QoL is a Lua add-on for small quality-of-life details in Hailstone's **Modern UI**. The current release
is **0.2.3**, published from the public GitHub add-on repository
`https://github.com/allhopeislost/hailstone-qol`.

## Features

- Living NPC nameplates show levels through `hs.hooks{nameplate = ...}`; the Modern target window shows
  target levels using the client's Target TLO and Hailstone spawn data. When `npc_class` is on, both append the
  spawn's class short name (`[12 ROG]`, or just `[ROG]` when levels are off) for the player classes WAR through BER;
  other spawn class ids (merchants, bankers, trainers) and a missing `class` field add nothing.
- Replaces the Modern target, spell-display and item-display windows with richer layouts. Each spell display uses
  `eq.DisplaySpellId(instance)` → `eq.Plugin('script:qol').spell_view(id)` → `hs.spell(id)` for additional
  metadata and readable effects. The game's description and the cyan additional information share one
  scrolling area; the colour matches MacroQuest's default spell information colour. There is no spellbook/title matching.
  Spell effects use compact aligned minimum/maximum columns, with the spell's casting details and identifiers grouped
  below; narrow windows still wrap and scroll.
  Supported beneficial buff stats render as readable lines (for example `Strength +20 (level 11) to
  Strength +45 (level 60)`); anything outside the supported set falls back to the raw
  `Slot N: SPA ..., base ..., base2 ..., max ..., formula ...` line so no data is lost. Cast messages
  (`cast on you/other`, `wears off`) are no longer shown in the additional information.
  Each item display uses `eq.DisplayItemData(instance)` → the plugin's `item_info(data)` for additional item data,
  including base/tribute value, delay/damage ratio and lore text. On Project Triune, **Other versions** below the
  additional information can open another tier of the same item in its own separate item window; see the item
  version section below.
- Offers seven on/off options in **Options → Plugins**: `target_level`, `npc_class`,
  `spell_info`, `item_info`, `item_preview`, `map_target_line`, and `map_npcs`. `item_preview` controls the
  **Other versions** controls and defaults to off (see below); the other options default to on. They are stored in
  the version-1 configuration file, `qol.lua`. **Show target Levels** (`target_level`) controls both NPC
  nameplate levels and target-window levels, using the existing target-level preference. The old
  `nameplate_level` field is retained for compatibility but no longer controls a display.
  Settings use `mq.pickle`/`dofile` under MacroQuest's
  `mq.configDir`, outside the add-on files, so add-on updates do not replace them.
- Draws a straight line from the player to the current target on the Modern large map when
  `map_target_line` is on. The standard map itself is loaded by a thin add-on adapter
  (`ui/modern/maptargetline.lua`) rather than copied, so map art and updates keep coming from the game.
- Shows every living NPC on the game's maps when `map_npcs` is on, instead of only the group, through
  `hs.hooks{map_spawn = ...}`. Corpses and players are left out; the minimap only asks about NPCs inside its circle.
  Each mark starts from the map's con colour and name and follows the map's layers and height filter.

These integrations target the user's supported, custom fixed Hailstone client, including its nameplate hook,
displayed-item/spell APIs and extended `hs.spell` records. An older/reference client lacking these extensions is not
the compatibility baseline. If an optional hook/API or data record is absent, that extra is skipped without guessing
IDs from names; available fields still format safely. Failed config saves produce a QoL chat warning.

The map target line is a straight compass-style line only; it is not pathfinding. It is supported on the
Modern large map, with no minimap support. When there is no target, or the needed player/target position data is
absent, the line is hidden. Map NPC marks are drawn by the client's own maps; a client without the `map_spawn`
hook simply shows no extra NPCs. Hailstone's server rules can restrict the add-on's declared capabilities
(`read`, `ui`, `extend`, `commands`, `actions`); relevant client APIs and server-provided data may also be
unavailable. Updating from 0.2.1 asks the player to approve the added `commands`/`actions` permissions.

Readable spell effects cover only SPA 1 (AC), 2 (attack), 4-10 (strength, dexterity, agility, stamina,
intelligence, wisdom, charisma), 11 (haste/slow), 216 (accuracy) and 292 (strikethrough), with formulas
100 (fixed), 101 (+1 per 2 levels) and 102 (+1 per level). The minimum is computed from the lowest valid
`class_level`; the cap level is the first level reaching a nonzero `max`. Uncapped effects show a scale hint
and never a fabricated cap. AC uses the MQ-style display `floor(abs(raw)*3/10)` while the cap level comes
from the raw value. Haste percent is `raw - 100` and slow percent is `100 - raw`; mixed ranges around 100,
negative bases/maxes, unknown formulas, unknown accuracy skills (known: 0 = 1H Blunt, -1 = all skills) and
other SPAs fall back to the raw SPA line. Values are spell-effect values, not character-sheet totals.
Uncapped AC scaling and caps unreachable within the client level byte also fall back to raw.
Scaling effects without a usable `class_level` fall back to raw (no level is ever guessed); fixed
effects need no level. Slows with a nonzero cap also stay raw, since the client snaps to the floor.
`info.spell_effects(s)` returns the effect rows and `info.spell_details(s)` returns
`{effects, metadata}` for UI rendering; both use plain tables only.

Modern UI is the supported UI pack. Gamepad UI is not supported and is outside this project's scope;
`ui/gamepad/target.lua` is retained only as legacy content, and no QoL feature development targets Gamepad.

## Other item versions

This is opt-in: enable `item_preview` in **Options → Plugins** (it defaults to off). On Project Triune, each
Modern item window then shows **Other versions** after its additional information, with two buttons for the other
tiers of the same item: **Enchanted** and **Legendary** for a Base item, Base and Legendary for Enchanted, and Base
and Enchanted for Legendary. The item's current tier is never offered. A click calls QoL's
`request_item_preview(itemId)` once from the running script, which validates the id, confirms the server is
Project Triune through `hs.server()`, and calls `hs.inspect_item(itemId)`. Nothing is requested while a window is
opened, drawn or loaded. The buttons wrap onto separate rows in a narrow window, and the helper text says
"Opens a separate item window."

The client opens the requested item in an ordinary, independent native item window. This window is never replaced:
its name, icon, stats, effects, Modified values and augment actions always stay live and usable, whatever version
was requested. Each opened window can offer its own other tiers, and asking for the same item again reuses the
window the client already has for it. QoL does not create duplicate windows, close, hide, move, scan or click any
item window, and does not claim focus for an existing one.

The requested version may not exist on the server, and the client cannot be asked to confirm that it opened a
window; after a click QoL only reports that the client was asked. If the API is missing, the option is off, the
server cannot be confirmed or permission is refused, a small status says why. Hailstone's client shows at most six
item windows; opening more follows its own limit. Ids outside the known base (1–999,999), +1,000,000 and
+2,000,000 ranges get no version buttons; there is no wrapping or guessing. The feature changes no capability
declarations and adds no new request path.

## Install

Install it from Hailstone's login-screen **Add-ons** panel: paste the repository link for the latest release, or a specific release's tag-page link. Inspect the add-on
name/version and requested capabilities, then choose **Install**. The link forms are
`https://github.com/allhopeislost/hailstone-qol` and
`https://github.com/allhopeislost/hailstone-qol/releases/tag/v0.2.3`; use the repository or release/tag page, not a direct
asset or ZIP-download link. Hailstone's add-on manager requires a public GitHub
repository/release to fetch the manifest and package. Branch links (`.../tree/<branch>`) are not supported:
the package is published as a release asset, not as a file in the branch.

## Development

From this directory, run the Lua tests, syntax checks and Python package tests:

```sh
lua tests/nameplate.lua
lua tests/info.lua
lua tests/spell_effects.lua
lua tests/settings.lua
lua tests/options.lua
lua tests/spelldisplay.lua
lua tests/itemdisplay.lua
lua tests/item_preview.lua
lua tests/map.lua
lua tests/mapnpcs.lua
find . -name '*.lua' -not -path './.git/*' -exec luac -p '{}' \;
python3 -m unittest discover -s tests -p 'test_*.py'
```

To also exercise the adapter against a client checkout's actual Modern map (without starting the client):

```sh
lua tests/map.lua /path/to/Hailstone-dev/ui/modern/map.lua
```

This restoration changes Lua source/tests/docs only; existing manifests and ZIPs are not rebuilt or updated.

For a separate release task, the package helper stages only its declared runtime-file allowlist, then delegates manifest and deterministic ZIP
creation to Hailstone's `tools/make_addon.py`. Give it an output directory outside the source tree. Pass the client
tool explicitly when it is not in the sibling `Hailstone-dev` checkout:

```sh
python3 tools/package.py --out /tmp/qol-release
python3 tools/package.py --make-addon /path/to/Hailstone-dev/tools/make_addon.py --out /tmp/qol-release
```

The helper builds version 0.2.3 packages and a generated release manifest in that output directory; it does not
publish, sign, install or run the client. To cut a signed release, sign the generated manifest with
`hailstone_sign sign <secret-key-file> <out>/hailstone-addon.txt` (key kept outside the repository), verify it,
copy the signed manifest back to the repository root, and upload the manifest and ZIP as assets of the
corresponding GitHub release. The tracked manifest then matches the release exactly.
