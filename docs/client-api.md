# Client API contract

What the add-on relies on from the Hailstone client. The reference client source (`Hailstone-dev`) is only a
reference; the add-on targets the custom client, which has extras the reference does not.

Status:
- **source**: present in the reference client source
- **custom**: not in the reference source; provided by the custom client
- **ingame**: seen working in the game
- **unverified**: used, but not confirmed against a client

Update this file whenever the add-on starts using, or stops using, a client function or record field.

## Functions and hooks

| Name | Used for | Status |
|---|---|---|
| `hs.option{...}` | the options in Options → Plugins | source |
| `hs.ui_function(name, fn)`, `eq.Plugin('script:qol')` | the windows call into `init.lua` | source |
| `hs.hooks{nameplate = ...}` | level/class on nameplates | custom |
| `hs.hooks{map_spawn = ...}` | NPCs on the map | source (client side in `lua_eq_map.cpp`) |
| `eq.DisplaySpellId(instance)` | which spell a spell window shows | custom |
| `eq.DisplayItemData(instance)` | which item record an item window shows | custom |
| `hs.spell(id)` | spell record | source (see fields) |
| `hs.spawn(id)`, `hs.player()` | target and map data | source |
| `hs.spawns()` | every spawn in the zone, by id (FindWalk) | ingame |
| `hs.menu(label, command)` | the Plugins menu entry that runs `/findW` | ingame (hand install; the manifest's ceiling is not tested) |
| `mq.bind('/findW', fn)` | the command that opens FindWalk | ingame |
| `mq.cmd(line)` | `/target id N`, `/nav id N` (Travel to) | ingame (a hand-installed script runs with player rights) |
| `hs.server()` | detect Project Triune | source; `nil` before the world login |
| `hs.inspect_item(id)` | open another item version | source |
| `eq.DrawZoneMap` | the map line wraps it | source |
| `eq.DrawMinimap(cx, cy, r, range, rotate)` | the minimap line wraps it; returns north's screen direction `(sin, -cos)` of the heading; the player is the circle's centre, `r / range` pixels per map unit | ingame |
| `mq.pickle`, `mq.configDir` | save settings | source |

Two `ui` bindings are easy to combine wrongly: `ui.InvisibleButton` (the modern pack's `T.Hit`) returns true when
the mouse goes **up**, while `ui.IsMouseDoubleClicked` is true on the frame it goes **down**. A double click therefore
never shares a frame with the hit box's click; ask for it on its own, on the hovered item (`ui.IsItemHovered()`), as
the client's own list windows do (`ui/modern/spellbook.lua`, `abilitybook.lua`). FindWalk's rows do this.

## `hs.spell(id)` fields

The reference source returns only: `id`, `name`, `class_level`, `timer_id`, `cast_time`, `recovery_time`,
`recast_time`, `mana`, `target_type`, `skill`, `is_skill`, `gem_icon`.

The add-on also reads these, which come from the custom client's extended record and are **unverified field by
field** (the spell window works ingame, `name` is confirmed): `level`, `endurance`, `range`, `ae_range`,
`push_back`, `spell_type`, `resist`, `resist_adj`, `effects`, `duration_cap`, `spell_icon`, `cast_on_you`,
`wear_off`.

`skillName` is read by `info.lua`, but the reference source does not return it from `hs.spell`. Unverified, and
probably not provided. To check: run a script that prints every key of `hs.spell(<id>)`.

## Item record (`eq.DisplayItemData`)

Read: `id`, `name`, `req_level`, `stack`, `charges`, `bag_slots`, `weight`, `ac`, `hp`, `mana`, `click_spell`,
`scroll_spell`, `value`, `favor`, `damage`, `delay`, `lore`, `magic`. Custom; **unverified field by field**
(the item window works ingame).

## Spawn fields

From `hs.spawn(id)` (source): `id`, `name`, `level`, `class`, `race`, `owner`, `guild`, `npc`, `corpse`, `x`, `y`,
`z`, `heading`, `hp_percent`, `rider`, `mercenary`, `gm`, `body_type`. The add-on uses `npc`, `corpse`, `level`,
`class`, `name`, `x`, `y`, `z`, `id`. Names are the raw ones (`a_rat01`); FindWalk cleans them for display.

Class ids FindWalk reads (reference client `game/eq_names.cpp`; unverified against the custom client): 20 to 35
guildmasters (class `id - 19`), 40 and 66 bankers, 41, 59, 61, 67, 68 and 70 merchants. `world().spawns` holds players
and corpses as well as NPCs (`npc`, `corpse`).

Zone lines are not available: the client has them (zone regions, `OP_SendZonepoints`) but no Lua function returns them.

## Capabilities

The manifest declares `read, ui, extend, commands, actions, target, move`. `commands` and `actions` are needed for the
windows' close box, icon chat-link, sockets and description links; without them those clicks silently do nothing.
`target` and `move` are for FindWalk's Travel to: `/target` needs `target` and `/nav` needs `move` (docs/plugins.md in
the client, "Capabilities"); every command is checked against the running code's bits.
