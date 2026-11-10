# QoL add-on contributor notes

## Scope and layout

- `init.lua`, `info.lua`, `settings.lua`, and `ui/` are runtime files. `ui/modern/` is the supported UI.
  Gamepad UI is not supported and is permanently outside this project's feature scope; retain
  `ui/gamepad/target.lua` only as a legacy file, without adding or adapting Gamepad behavior.
- `tests/` contains local Lua checks. `tools/package.py` is release tooling; `README.md` documents player-facing
  behavior and release steps. Keep tests, docs, tooling, old ZIPs and generated manifests out of add-on packages.
- Hailstone client source is reference material only for this add-on task. Do not modify the client checkout.
- Compatibility baseline: the user's supported custom fixed client, not an older reference checkout. Preserve
  `hs.hooks{nameplate = ...}`, `hs.hooks{map_spawn = ...}`, `eq.DisplaySpellId(instance)` → plugin `spell_info(id)` →
  `hs.spell(id)`, and
  `eq.DisplayItemData(instance)` → plugin `item_info(data)`. Do not replace IDs with spellbook/title matching.
  Extended spell records include `spell_icon`, recovery/recast times, range/AE range, pushback, resist fields,
  class levels, raw effects and cast messages; item records include ID/icon, value/favor, delay/damage and lore.
  Keep every feature option enabled by default, persistent, and available in Options → Plugins.

## Checks

Run from this directory:

```sh
lua tests/nameplate.lua
lua tests/info.lua
lua tests/settings.lua
lua tests/options.lua
lua tests/spelldisplay.lua
lua tests/itemdisplay.lua
lua tests/map.lua
lua tests/mapnpcs.lua
find . -name '*.lua' -not -path './.git/*' -exec luac -p '{}' \;
python3 -m unittest discover -s tests -p 'test_*.py'
```

Package checks should write to a temporary/output directory, never publish, sign, install or start the client.
For the Lua restoration task, do not build/change packages, manifests or old ZIPs (read-only historical evidence).

## Adding a feature

1. Keep changes within the add-on and its declared `read,ui,extend,commands,actions` capability ceiling; preserve graceful behavior
   where client hooks or server data are unavailable.
2. Add/adjust a focused test and document user-visible behavior and limitations in `README.md`.
3. If adding/removing a runtime file, update the explicit allowlist in `tools/package.py`. Include the legacy
   `ui/gamepad/target.lua`; exclude tests, docs, tooling and generated release artifacts.
4. Keep dependencies minimal: use the Lua/client APIs already available, and do not add a dependency solely for
   packaging or tests. Coordinate the persisted-config filename/module rather than guessing it.
