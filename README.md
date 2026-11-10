# Hailstone QoL

Hailstone QoL is a Lua add-on for small quality-of-life details in Hailstone's **Modern UI**. The current release
is **0.2.4**, published from the public GitHub add-on repository
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
  the version-1 configuration file, `qol.lua`. **Show target levels** (`target_level`) controls both NPC
  nameplate levels and target-window levels.
  Settings use `mq.pickle`/`dofile` under MacroQuest's
  `mq.configDir`, outside the add-on files, so add-on updates do not replace them.
- Draws a straight line from the player to the current target on the Modern large map when
  `map_target_line` is on. The standard map itself is loaded by a thin add-on adapter
  (`ui/modern/maptargetline.lua`) rather than copied, so map art and updates keep coming from the game.
- Shows every living NPC on the game's maps when `map_npcs` is on, instead of only the group, through
  `hs.hooks{map_spawn = ...}`. Corpses and players are left out; the minimap only asks about NPCs inside its circle.
  Each mark starts from the map's con colour and name and follows the map's layers and height filter.

These integrations target a custom Hailstone client, including its nameplate hook,
displayed-item/spell APIs and extended `hs.spell` records. An older/reference client lacking these extensions is not
the compatibility baseline. If an optional hook/API or data record is absent, that extra is skipped without guessing
IDs from names; available fields still format safely. Failed config saves produce a QoL chat warning.

The map target line is a straight compass-style line only; it is not pathfinding. It is supported on the
Modern large map, with no minimap support. When there is no target, or the needed player/target position data is
absent, the line is hidden. Map NPC marks are drawn by the client's own maps; a client without the `map_spawn`
hook simply shows no extra NPCs. Hailstone's server rules can restrict the add-on's declared capabilities
(`read`, `ui`, `extend`, `commands`, `actions`); relevant client APIs and server-provided data may also be
unavailable. Updating from 0.2.1 asks the player to approve the added `commands`/`actions` permissions.

Spell effects are shown as readable lines through a table in `spell_effects.lua` that says how each SPA's numbers
are displayed: stats, resists, AC, attack, haste/slow, HP/mana/endurance (per tick when the spell has a duration),
damage shields, percentages, accuracy, stuns, procs, summons, counters and cures, plus name-only effects such as
invisibility or gate. Scaling follows the common level formulas (fixed, per-level, per-N-levels, and the
over-level-N ramps). The minimum is computed from the lowest valid `class_level`; the cap level is the first level
reaching a nonzero `max`. Uncapped effects show a scale hint and never a fabricated cap. AC uses the MQ-style display
`floor(abs(raw)*3/10)` while the cap level comes from the raw value. Haste percent is `raw - 100` and slow percent
is `100 - raw`. Anything the table does not cover (unknown SPAs or formulas, tick-based or random formulas,
mixed ranges around 100, unknown accuracy skills) falls back to a named raw line such as
`Slot 2: Root (SPA 99, base ..., max ..., formula ...)`, so no data is lost. Values are spell-effect values, not
character-sheet totals. Scaling effects without a usable `class_level` also stay raw (no level is ever guessed);
fixed effects need no level. Slows with a nonzero cap stay raw, since the client snaps to the floor.
`info.spell_effects(s)` returns the effect rows and `info.spell_details(s)` returns
`{effects, metadata}` for UI rendering; both use plain tables only.

Modern UI is the only supported UI pack; the Gamepad UI is not supported.

## Other item versions

This is opt-in: enable `item_preview` in **Options → Plugins** (it defaults to off). On Project Triune, each
Modern item window then shows **Other versions** after its additional information, with a button for each of the
other two tiers of the same item (Base, Enchanted, Legendary). Clicking one asks the client to open that tier in its
own, ordinary item window; the window you clicked in is left alone, and asking for the same item again reuses the
window the client already has. The client shows at most six item windows.

Under the hood, a click calls QoL's `request_item_preview(itemId)` once, which validates the id, confirms the server
is Project Triune through `hs.server()` and calls `hs.inspect_item(itemId)`. Nothing is requested while a window is
opened or drawn.

The requested version may not exist on the server, and the client does not confirm that a window opened; after a
click QoL only reports that the client was asked. If the API is missing, the option is off, the server cannot be
confirmed or permission is refused, a small status says why. Ids outside the known base (1–999,999),
+1,000,000 and +2,000,000 ranges get no buttons.

## Install

Install it from Hailstone's login-screen **Add-ons** panel: paste the repository link for the latest release, or a specific release's tag-page link. Inspect the add-on
name/version and requested capabilities, then choose **Install**. The link forms are
`https://github.com/allhopeislost/hailstone-qol` and
`https://github.com/allhopeislost/hailstone-qol/releases/tag/v0.2.4`; use the repository or release/tag page, not a direct
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

For a separate release task, the package helper stages only its declared runtime-file allowlist, then delegates manifest and deterministic ZIP
creation to Hailstone's `tools/make_addon.py`. Give it an output directory outside the source tree. Pass the client
tool explicitly when it is not in the sibling `Hailstone-dev` checkout:

```sh
python3 tools/package.py --out /tmp/qol-release
python3 tools/package.py --make-addon /path/to/Hailstone-dev/tools/make_addon.py --out /tmp/qol-release
```

The helper builds version 0.2.4 packages and a generated release manifest in that output directory; it does not
publish, sign, install or run the client. To cut a signed release, sign the generated manifest with
`hailstone_sign sign <secret-key-file> <out>/hailstone-addon.txt` (key kept outside the repository), verify it,
copy the signed manifest back to the repository root, and upload the manifest and ZIP as assets of the
corresponding GitHub release. The tracked manifest then matches the release exactly.
