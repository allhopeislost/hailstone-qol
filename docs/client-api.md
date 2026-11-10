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
| `hs.server()` | detect Project Triune | source; `nil` before the world login |
| `hs.inspect_item(id)` | open another item version | source |
| `eq.DrawZoneMap` | the map line wraps it | source |
| `mq.pickle`, `mq.configDir` | save settings | source |

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
`class`, `name`, `x`, `y`.

## Capabilities

The manifest declares `read, ui, extend, commands, actions`. `commands` and `actions` are needed for the windows'
close box, icon chat-link, sockets and description links; without them those clicks silently do nothing.
