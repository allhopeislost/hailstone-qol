# QoL add-on contributor notes

## Scope and layout

- `init.lua` (the entry point), `core/` (settings, spell/item text, spell effects, generated SPA names) and
  `ui/modern/` are runtime files. Only the Modern UI is supported; there is no Gamepad UI.
- `tests/` contains local Lua checks. `tools/package.py` is release tooling; `README.md` documents player-facing
  behavior and release steps. Keep tests, docs, tooling, old ZIPs and generated manifests out of add-on packages.
- Hailstone client source is reference material only. Do not modify the client checkout.
- Compatibility baseline: the supported custom Hailstone client, not an older reference checkout. Preserve
  `hs.hooks{nameplate = ...}`, `hs.hooks{map_spawn = ...}`, `eq.DisplaySpellId(instance)` → plugin `spell_view(id)` →
  `hs.spell(id)` (`spell_info(id)` is the plain-text variant), and
  `eq.DisplayItemData(instance)` → plugin `item_info(data)`. Do not replace IDs with spellbook/title matching.
  Extended spell records include `spell_icon`, recovery/recast times, range/AE range, pushback, resist fields,
  class levels, raw effects and cast messages; item records include ID/icon, value/favor, delay/damage and lore.
  Every feature option is persistent and available in Options → Plugins; all default to on except `item_preview`.

## Checks

Run from this directory:

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

Package checks should write to a temporary/output directory, never publish, sign, install or start the client.
Never change published manifests or old ZIPs.

## Adding a feature

1. Keep changes within the add-on and its declared `read,ui,extend,commands,actions` capability ceiling; preserve graceful behavior
   where client hooks or server data are unavailable.
2. Add/adjust a focused test and document user-visible behavior and limitations in `README.md`.
3. If adding/removing a runtime file, update the explicit allowlist in `tools/package.py`; exclude tests, docs,
   tooling and generated release artifacts.
4. Keep dependencies minimal: use the Lua/client APIs already available, and do not add a dependency solely for
   packaging or tests. Coordinate the persisted-config filename/module rather than guessing it.
