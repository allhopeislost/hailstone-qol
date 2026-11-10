# QoL add-on contributor notes

Start here. What the add-on does and why: `docs/decisions.md`. What it needs from the client:
`docs/client-api.md`. Decisions are an append-only log: never edit or delete one, add a new entry that
supersedes it.

## Working rules

- Code, comments and docs are in English; chat with the user in Dutch.
- Do not commit, push, publish or release unless asked. Never touch the client checkout or the signing key.
- Never guess a client API or record field. Check `docs/client-api.md`; if it is not there or marked unverified,
  say so, and prefer a small in-game check (print the table's keys) over assuming.
- A change is done when `tools/check.sh` passes, a focused test covers it, `docs/decisions.md` (new entry
  if a decision changed) and `docs/client-api.md` are updated where they apply, and the README still matches the features.
- Keep it cheap to maintain: no new switches, files or dependencies without a reason.

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
tools/check.sh
```

It runs every `tests/*.lua`, a `luac -p` syntax check of all Lua files and the Python tests, prints nothing but a
summary when all pass, and only the failing output otherwise.

Package checks should write to a temporary/output directory, never publish, sign, install or start the client.
Never change published manifests or old ZIPs.

## Testing locally

1. Remove qol in the add-on manager (Add-ons panel → Remove). While the manager has it installed, files that
   still match its hashes get the add-on's rights and changed ones get a hand-installed file's, and a module may not
   have fewer rights than the script that requires it (`module ... may not run`).
2. `python3 tools/deploy_local.py` replaces `scripts/qol` with exactly the runtime files of `tools/package.py`
   (`--home <dir>` or `HAILSTONE_HOME`; default `~/Games/Hailstone`). It refuses while the manager has qol.
3. In game: `/lua stop qol`, then `/lua run qol`. Check for no `module ... not found` or `may not run`, the options
   under Options → Plugins, a spell and an item window with a working close box, and nameplate levels.

A hand-installed copy does not test the manager's install, hashes or capability ceiling. For a change to
`CAPS` or the package contents, publish a GitHub pre-release and install it from its tag page
(`.../releases/tag/<tag>`); the repository link keeps pointing at the newest full release.

## Releasing

Only when asked. The signing key lives outside the repo (`*.key` is ignored): `--key`, `$HAILSTONE_QOL_KEY` or
`~/.local/share/hailstone-qol/hailstone-qol-sign.key`. `hailstone_sign` comes from `--sign-tool`, `$HAILSTONE_SIGN` or
the client's `build/`.

```sh
python3 tools/release.py 0.2.7 --change "What changed" --change "Another change" --dry-run
python3 tools/release.py 0.2.7 --change "What changed" --change "Another change"
python3 tools/release.py 0.2.7 --maintenance --change "Moved files into core/"
```

The dry run does everything up to signing in a temp folder and changes nothing. A real run checks, packages,
signs, verifies, bumps `VERSION` in `tools/package.py`, commits everything in the working tree, tags `vX.Y.Z`,
pushes, publishes the GitHub release (notes: a heading plus one bullet per `--change`; `--maintenance` headed
"Maintenance release") and compares the downloaded manifest with the repo's. Look at `git status` first: everything
uncommitted is part of the release. `--message` sets the commit message.

## Adding a feature

1. Keep changes within the add-on and its declared `read,ui,extend,commands,actions` capability ceiling; preserve graceful behavior
   where client hooks or server data are unavailable.
2. Add/adjust a focused test and document user-visible behavior and limitations in `README.md`.
3. If adding/removing a runtime file, update the explicit allowlist in `tools/package.py`; exclude tests, docs,
   tooling and generated release artifacts.
4. Keep dependencies minimal: use the Lua/client APIs already available, and do not add a dependency solely for
   packaging or tests. Coordinate the persisted-config filename/module rather than guessing it.
