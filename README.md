# Hailstone QoL

Hailstone QoL is a Lua add-on for small quality-of-life details in Hailstone's **Modern UI**. The current release
is **0.2.2**, published from the public GitHub add-on repository
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
  including base/tribute value, delay/damage ratio and lore text. On Project Triune, the Stats heading also has
  small **Base / Enchanted / Legendary** preview buttons; see the experimental preview section below.
- Offers eight on/off options in **Options → Plugins**: `nameplate_level`, `target_level`, `npc_class`,
  `spell_info`, `item_info`, `item_preview`, `map_target_line`, and `map_npcs`. All default to on except the
  experimental `item_preview`, which defaults to off (see below). They are stored in the version-1
  configuration file, `qol.lua`. Settings use `mq.pickle`/`dofile` under MacroQuest's
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

## Experimental Triune tier preview

This experiment is opt-in: enable `item_preview` in **Options → Plugins** (it defaults to off). On Project Triune,
each Modern item window then shows small **Base / Enchanted / Legendary** buttons at the right of
its **Stats** heading (or a **Preview** heading when the item has no stats). The item's current tier is highlighted
at first, so an Enchanted item starts on Enchanted. Clicking another tier calls QoL's
`request_item_preview(itemId)` once from the running script, which validates the id, confirms the server is
Project Triune through `hs.server()`, and calls `hs.inspect_item(itemId)`. Nothing is requested while a window is
opened, drawn, or loaded.

The original item's name and icon stay in this window, with a small `<tier> preview` note. The stats, metadata,
flags, description and additional information then come from the server's response window for the requested id.
This is a read-only snapshot: while previewing, chat linking from the icon is disabled, the Modified switch and
augment actions are not drawn, and description links are not followed. Clicking the original tier returns to the
live original window and its normal controls.

This is an experiment: the client's response is a normal native item window, so **an extra item window may appear
and remain visible**. QoL does not close, hide or move it. If the client already has its maximum of six item
windows open, its own limit may replace the oldest one. If the response never appears, a different item id
appears, the API is missing or permission is refused, the preview shows a specific status and keeps the original
item selected and visible. Ids outside the known base, +1,000,000 and +2,000,000 ranges get no preview buttons;
there is no wrapping or guessing. The preview is limited to Project Triune. It changes no capability declarations
and adds no new request path: if the installation does not allow the item-inspect action, the status reports the
refusal.

## Install

Install it from Hailstone's login-screen **Add-ons** panel: paste the repository link for the latest release, or a specific release's tag-page link. Inspect the add-on
name/version and requested capabilities, then choose **Install**. The link forms are
`https://github.com/allhopeislost/hailstone-qol` and
`https://github.com/allhopeislost/hailstone-qol/releases/tag/v0.2.2`; use the repository or release/tag page, not a direct
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

The helper builds version 0.2.2 packages and a generated release manifest in that output directory; it does not
publish, sign, install or run the client. To cut a signed release, sign the generated manifest with
`hailstone_sign sign <secret-key-file> <out>/hailstone-addon.txt` (key kept outside the repository), verify it,
copy the signed manifest back to the repository root, and upload the manifest and ZIP as assets of the
corresponding GitHub release. The tracked manifest then matches the release exactly.
