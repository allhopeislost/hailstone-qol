# Product decisions

An append-only log of what the add-on does and does not do, and why.

Rules:
- **Never edit or delete an entry.** The only allowed change to an old entry is its `Status` line.
- To change a decision, add a new entry that says what it replaces, and set the old entry's status to
  `Superseded by Dxxx`. The chain of entries is the history.
- Number entries in order (`D020`, `D021`, ...) and never reuse a number.
- Statuses: `Accepted`, `Superseded by Dxxx`, `Dropped` (no longer applies, nothing replaces it).
- `Recorded` is when the decision was written down; the first batch (D001-D019) was recorded together from earlier
  work, so its order is by topic, not by when each was made.

Template:

```
## Dxxx Short title
Status: Accepted
Recorded: YYYY-MM-DD
Decision: what is decided.
Why: the reason.
Rules out: what this prevents (optional).
Replaces: Dxxx (only when it supersedes one).
```

## D001 Modern UI only
Status: Accepted
Recorded: 2026-11-10
Decision: The add-on replaces and extends windows of the Modern UI pack only. There is no Gamepad UI support.
Why: One supported pack keeps the add-on small and cheap to maintain.
Rules out: Gamepad windows, or adapting a feature to the Gamepad UI.

## D002 Replacing a window is fine when the result is better
Status: Accepted
Recorded: 2026-11-10
Decision: The target, spell-display and item-display windows are replaced by the add-on's own layouts. The map is
loaded through a thin adapter instead, so map art and updates keep coming from the game.
Why: The windows need layouts the game's own cannot give; the map needs only an overlay.

## D003 As few switches as possible
Status: Accepted
Recorded: 2026-11-10
Decision: A feature gets its own option only when players reasonably want it off. Related displays share one switch.
Why: Every option is something to explain, test and keep working.
Rules out: A toggle per detail.

## D004 Options are persistent and live under Options → Plugins
Status: Accepted
Recorded: 2026-11-10
Decision: Settings are stored outside the add-on files, so updates never reset them. All options default to on
except `item_preview`.
Why: Players should not lose settings on update, and defaults should show the add-on working.

## D005 Nothing is guessed or made up
Status: Accepted
Recorded: 2026-11-10
Decision: An effect the add-on cannot show correctly is shown as a named raw line, so no data is lost. No cap level
is invented for an uncapped effect, and a scaling effect with no known caster level stays raw.
Why: A wrong number is worse than an unformatted one.
Rules out: Estimating values; matching spells by title or spellbook; inferring IDs from names.

## D006 Work from IDs the client provides
Status: Accepted
Recorded: 2026-11-10
Decision: The spell and item windows read the record the client hands over for that specific window.
Why: It is exact; title or spellbook matching is not.

## D007 Missing client hooks degrade quietly
Status: Accepted
Recorded: 2026-11-10
Decision: If a hook, API or field is absent, that extra is skipped and everything else keeps working.
Why: The add-on may run on a client without every extension; it must never error because of that.

## D008 Working client APIs are kept
Status: Accepted
Recorded: 2026-11-10
Decision: The nameplate hook, the map-spawn hook and the display-record functions stay the add-on's integration
points.
Why: They work, and the custom client provides them.

## D009 The class tag is for playable classes only
Status: Accepted
Recorded: 2026-11-10
Decision: A class short name (WAR to BER) is shown only for NPCs whose class id is one of the playable classes.
Merchants, bankers, trainers and spawns with no class add no class tag.
Why: A merchant's class id is not a class a player reads off a nameplate.

## D010 Services show no level either
Status: Accepted
Recorded: 2026-11-10
Decision: Merchants, bankers and trainers (class ids past the playable ones) show no level. A spawn with no class
field keeps its level. Since 0.2.5.
Why: Level and class should treat the same NPCs the same way; D009 already excluded these from the class tag.
Rules out: Hiding the level for pets or mercenaries was considered and not decided.

## D011 One switch for levels, one for class
Status: Accepted
Recorded: 2026-11-10
Decision: `target_level` controls levels in both the nameplates and the target window; `npc_class` controls the
class tag in both. The older separate nameplate-level setting no longer exists. Since 0.2.3.
Why: Players think of "levels", not of where they are drawn.

## D012 Spell effects are compact, with minimum and maximum
Status: Accepted
Recorded: 2026-11-10
Decision: Effects show a minimum and a maximum with the caster level each is reached at, in aligned columns.
Casting details and IDs are grouped below them.
Why: It is the quickest way to read a buff's strength.

## D013 Description and extra information share one scroll area
Status: Accepted
Recorded: 2026-11-10
Decision: The game's description and the add-on's additional information scroll together in the spell window.
Why: Two scroll areas in a small window are awkward.

## D014 Left out of the spell window on purpose
Status: Accepted
Recorded: 2026-11-10
Decision: The spell window shows no fixed / no-spell-cap flags, no explanation of how AC is calculated, and no cast
messages ("cast on you/other", "wears off").
Why: Noise for players; the information is available elsewhere.

## D015 Effects are spell values, not character totals
Status: Accepted
Recorded: 2026-11-10
Decision: The spell window shows what the spell gives, not what the character's sheet would add up to.
Why: Totals depend on gear and buffs the add-on does not know.

## D016 Item information is English text, additional only
Status: Accepted
Recorded: 2026-11-10
Decision: The extra item information is English text and leaves out the icon and item type.
Why: The window already shows the icon and type.

## D017 Other item versions are opt-in and Project Triune only
Status: Accepted
Recorded: 2026-11-10
Decision: A click asks the client to open the requested tier in its own separate item window. The option is off by
default, only works on Project Triune, never replaces, moves or closes an item window, and never claims the client
confirmed the window opened. Separate windows since 0.2.3; the option since 0.2.1.
Why: The client opens versions in ordinary windows and gives no acknowledgement.
Rules out: Replacing the clicked window; offering versions on other servers.

## D018 The map target line is a straight line
Status: Accepted
Recorded: 2026-11-10
Decision: The line runs from the player to the target on the large map only, and is hidden when either position is
unknown.
Why: It shows direction, not a route.
Rules out: Pathfinding; a minimap line.

## D019 Map NPCs follow the map's own layers and filters
Status: Accepted
Recorded: 2026-11-10
Decision: Living NPCs are marked, starting from the map's con colour and name. Corpses and players are left out.
Why: The marks should behave like the map's own.

## D020 The target line also runs on the minimap
Status: Accepted
Recorded: 2026-11-10
Supersedes: D018 (only where it ruled out a minimap line; the line stays straight)
Decision: The same option draws the straight line on the minimap too. It starts at the circle's centre (the player),
follows the minimap's rotation and, when the target is beyond the range, stops at the circle's edge without an end dot.
Why: The minimap is what players watch while moving; it needs the same direction cue.
Rules out: A separate option for the minimap; pathfinding.

## D021 Zone Find is a window, not an option
Status: Accepted
Recorded: 2026-11-11
Decision: `/zonefind [text]` (and a Plugins menu entry) opens a window that lists the zone's spawns from `hs.spawns()`:
a search box, NPC / PC / Corpse filters (only NPC on), columns Name, Role, Lvl and Dist that sort when their head is
clicked (again to reverse), and a Travel to button that sends `/target id N` and then `/nav id N`. There is no
Options entry; the filters and the sort live in the window and are not saved. Names are shown without the digits
and underscores the server adds. Distance is a whole number with no unit.
Why: A tool the player opens on purpose needs no switch. `/target id` picks the exact spawn, `/target <name>` takes the
nearest one of that name.
Rules out: A saved filter or sort; double click to travel; a unit on the distance.

## D022 The Role column is for merchants, bankers and trainers, and only when there are some
Status: Accepted
Recorded: 2026-11-11
Decision: A living NPC's class id gives a role: 20 to 35 Trainer (the tooltip says who it trains), 40 and 66 Banker,
41, 59, 61, 67, 68 and 70 Merchant. Other NPC-only ids have none. A role has no level (as D010). The Role column
shows only while a listed row has a role, and the window is 360 wide without it and 410 with it; when the sorted
column goes away the sort returns to distance. The search matches the role too.
Why: The class id is all the client gives; what a merchant sells (a spell vendor) is not in it. The ids come from the
reference client (`game/eq_names.cpp`), unverified against the custom client.
Rules out: A spell vendor role; a fixed-width window that hides the column.

## D023 The capability ceiling gains target and move
Status: Accepted
Recorded: 2026-11-11
Supersedes: the `read,ui,extend,commands,actions` ceiling
Decision: The manifest declares `read,ui,extend,commands,actions,target,move`. Travel to sends `/target` (the
`target` capability) and `/nav` (`move`); the client checks each command against them. Existing installs ask the
player to approve the update.
Why: Without them the button does nothing on a manager install.
Rules out: Reaching the commands some other way; the capability check is the same everywhere.

## D024 Zone Find is renamed FindWalk, command /findW
Status: Accepted
Recorded: 2026-11-11
Supersedes: D021 (the name and the command only); D022 and D023 apply to FindWalk unchanged
Decision: The window is called FindWalk and opens with `/findW [text]` (and the Plugins menu entry FindWalk). Its files
are `core/findwalk.lua` and `ui/modern/findwalk.lua`; the functions the window calls are `findwalk_state`,
`findwalk_close`, `findwalk_rows` and `findwalk_travel`.
Why: "Zone Find" promised more than it does: it lists spawns and walks to one, and it does not list zone lines.
Rules out: Keeping both names or both commands.

## D025 The window is titled Find
Status: Accepted
Recorded: 2026-11-11
Supersedes: D024 (only where it names the window and its menu entry FindWalk; the command and the files keep it)
Decision: The window's title bar and its Plugins menu entry say "Find". The feature, the files and the functions are
still FindWalk, and the command is still `/findW`.
Why: Inside the game the title only has to say what the window is; the stock Find window is a different screen.
Rules out: A second title for the same window.

## D026 FindWalk gets a switch, a double click and starts A to Z
Status: Accepted
Recorded: 2026-11-11
Supersedes: D021 (no Options entry; the default order is distance; no double click)
Decision: Options → Plugins has "Find window (/findW)", on by default and saved like the others. Off, `/findW` only says
where to turn it on, the window closes and its functions answer nothing. A double click on a row is Travel to (it
selects the row too); a single click only selects. The list starts sorted by name, A to Z, and returns to that when
the sorted Role column goes away. Clicking another head still starts ascending.
Why: The player asked for all three. One switch for a whole window is the same shape as the other options.
Rules out: Saving the filters or the sort.

## D027 A row's double click is read from the hovered row, not from its hit box
Status: Accepted
Recorded: 2026-11-11
Decision: FindWalk's rows ask `ui.IsMouseDoubleClicked` on the hovered row, apart from the `T.Hit` box that selects it.
Why: `T.Hit` is an `InvisibleButton`, which reports a click on mouse up, and `IsMouseDoubleClicked` is true on the
frame the mouse goes down, so the first version's check inside the hit box never ran ingame.
Rules out: Tracking two clicks by time in the window; a second hit box for the double click.

## D028 Named tracker
Status: Accepted
Recorded: 2026-11-11
Decision: `/named [zone]` (Plugins menu entry "Named") opens a window listing the named NPCs of a zone from the
bundled generated `core/named_data.lua`; in the player's current zone each row also shows whether the named is up
(from `hs.spawns()`) and how far away, and clicking it sends `/target id N`. Each row's item drops with chances are
listed below; clicking a drop asks the client to open that item's own window via `hs.inspect_item(id)` (Project
Triune only, as in D017). An "Edit list" window manages the player's own tracked names per zone, persisted in
`qol_named.lua`, with one-click suggestions from the bundled data. One option, `named_tracker`, default on. The data
is generated by `tools/gen_named_data.py` from the public Project Triune release database
(github.com/tunaria/NMS-Release, `Release-NMS-Server/database/release-peq.zip`): named = `spawn_limit` /
`rare_spawn` / `unique_` / `raid_target` flag, or a non-placeholder name, or a `lastname`; service NPCs (trainers,
bankers, merchants by class id) are excluded; drop chance = `loottable_entries.probability` ×
`lootdrop_entries.chance`.
Why: the client only exposes live spawns, so a named that is down can only come from bundled data; the database
dump is public and deterministic to parse. No new capabilities: `target` was already in the ceiling (D023) and
`hs.inspect_item` is already used (D017).
Rules out: Runtime web lookups (they would need the `web` capability and a server allowlist); name-prefix-only
detection (misses e.g. `a_frenzied_ghoul`, which is named via `spawn_limit`).

## D029 Named tracker: data loading and name matching in game
Status: Accepted
Recorded: 2026-11-11
Decision: `core/named_data.lua` is loaded with `require('core.named_data')`, not `dofile`: in a script the client's
`dofile`/`loadfile` resolve relative to the config directory (so `dofile('qol.lua')` reads the settings), while
`require` finds files next to the script. A hand-typed tracked name matches a live spawn not only exactly but also
when it is contained in the spawn's name (at least 3 characters), so "frenzied" finds "a_frenzied_ghoul"; exact
matches win, then the nearest. The windows use plain ASCII glyphs (`*`, `x`, `-`, `+`): the game fonts have no
star/cross/dash glyphs, they render as "?".
Why: the first in-game test showed an empty zone list ("Nothing known about this zone") because dofile looked in
`scripts/config/core/...`, and a hand-added "frenzied" never showed up while `a_frenzied_ghoul` was alive.

## D030 Named tracker: loot index for unflagged placeholder names
Status: Accepted
Recorded: 2026-11-11
Decision: `core/named_data.lua` also carries a `loot` index mapping every placeholder-style spawned name
(`a_...`/`an_...`, contains letters, no trailing digit, not a corpse/`#`-name; service NPCs excluded) to its
drops (effective chance >= 5%, at most 12 per name, keyed like Lua's `nameKey`: lowercase, underscores as
spaces). The zone list itself still only contains DB-flagged named; `named_drops` falls back to the index for
hand-tracked names, so e.g. `a reanimated hand` in gukbottom — not flagged `spawn_limit`/`rare_spawn`/`unique_`/
`raid_target`, no lastname, yet community-named with Serpentine Bracer 75% / Adamantite Band 25% — shows its
drops when tracked by hand.
Why: the release database does not flag classic-zone community named mobs (checked: no flag, `fixed`,
`unique_spawn_by_name` or loot pattern separates `a_reanimated_hand` from trash like `a_shadowed_man`); a
loot-threshold rule pulled in thousands of trash mobs. The index costs ~1 MB and keeps the zone list clean.
Rules out: listing all `a_`-style names as named (153k entries); loot-based named detection (false positives
like `a fire beetle` at 100% junk drops).

## D031 Named tracker: draggable divider between the two lists
Status: Accepted
Recorded: 2026-11-11
Decision: in the /named window the named list and the drops list share the height the window has beyond the fixed
parts; the divider between them is dragged with the mouse (a hit strip over the gap, accent line on hover/drag,
tooltip) and the position (design pixels of list height, clamped between MIN_LIST_H and the available height minus
MIN_DROPS_H) is persisted in `qol_named.lua` as `split` via the `named_split` / `named_split_set` ui_functions.
The window's own edge/corner resize (D029's `resizable`) is unchanged and clamps the divider to the available
height. The editor window keeps its automatic 50/50 split of the two panels.
Why: the user asked for a way to give either list more room without resizing the whole window; the client's own
scale setting zooms the whole window, so the split lives in the add-on's store, not in `hud.size`/`hud.scale`.

## D032 Named tracker: removing a name from the tracker window
Status: Accepted
Recorded: 2026-11-11
Decision: each row of the /named window has an "x" at its right edge. Clicking it (`named_hide`) removes the name
from that zone's list and stops tracking it; the name is kept in a per-zone `hidden` set in `qol_named.lua`. The
editor ("Named list") window's suggestion list shows hidden names again (they are simply untracked data named),
and adding one there (`named_add`) unhides it, so the row returns with its star. Hiding is per zone and persists.
Why: the user wants to declutter the tracker window per zone and get removed names back from the Named list window
instead of losing them. The star stays the track/untrack toggle; "x" is the remove-from-view action.

## D033 Named tracker: no track star in the window, server-specific NPCs excluded
Status: Accepted
Recorded: 2026-11-11
Decision: the tracker window no longer has the track/untrack star — tracking is managed only in the "Named list"
editor window (the star there was a no-op visually in the tracker: tracked rows differed only by the glyph). The
"x" per row (remove from the list, D032) stays. Also, `tools/gen_named_data.py` now excludes names in
`EXCLUDED_NAMES` (currently "echo of the past", a server-specific Project Triune NPC) from the generated named
list in every zone, whatever their flags; the regenerated `core/named_data.lua` has 8 named in gukbottom.
Why: the star button did nothing the editor did not already do better, and Echo of the Past is not a campable
named on Triune.

## D034 Named tracker: no TRACKED section in the editor window
Status: Accepted
Recorded: 2026-11-11
Decision: the "Named list" editor window no longer has the "TRACKED IN THIS ZONE" panel; it only has the
add-a-name input and the "KNOWN NAMED IN THIS ZONE" suggestion list (which includes names removed from the
tracker window, so `+` brings them back). The tracker window shows a passive gold `*` on tracked rows (no
button — D033 removed the track toggle there), so what is tracked stays visible in the tracker window itself.
Why: the user found the TRACKED panel redundant ("in Named you already see what you track"); removing a name is
the "x" in the tracker window, re-adding is the `+` in the editor.

## D035 Named tracker: blink when a named comes up
Status: Accepted
Recorded: 2026-11-12
Decision: when a row of the /named window changes from not spawned to spawned between two reads (the named
just came up in the current zone), the row blinks (accent wash, on/off every 250 ms) for 3 seconds. Tracked in
the window's state (blink marks per row name, reset on zone switch); no plugin change, no persistence.
Why: the user wants to notice a named coming up without watching the list.

## D035 Named tracker: blink when a named comes up
Status: Accepted
Recorded: 2026-11-12
Decision: when a row of the /named window changes from not-seen to seen (spawned false -> true between two
0.5 s reads), the row blinks (accent wash, 250 ms on/off) for 3 seconds. The transition is detected in the
window script's fetchList by comparing each row's spawned flag with the previous read; blink marks are reset on
zone switch and dropped for rows no longer listed.
Why: the user wants a visible signal the moment a named is up, without watching the up/down dots.

## D036 Pet chain integrated from the standalone petchain script
Status: Accepted
Recorded: 2026-11-12
Decision: the standalone `scripts/petchain` script is ported into the add-on as `core/petchain.lua` with the
`pet_chain` option (default on) in Options -> Plugins, the `/petchain` command and a Plugins menu entry. CAPS
gains `packets` (hs.on_packet watches the outgoing pet orders, OP_PetCommands and the #petcmd say). Differences
from the standalone script: no own main loop — the tick is driven per UI frame via the `petchain_tick`
ui_function from `ui/modern/petchain.lua`, throttled inside the module; the /target wait is a pending state in
the tick instead of a blocking mq.delay (a plugin call must not block); on/off lives in Options -> Plugins, the
command only reports and drives go/group/status.
Why: the user wants pet chain as a menu option of the QoL add-on instead of a separate script.

## D037 Pet chain: the last mob is never skipped, and the chain waits out the skip list
Status: Accepted
Recorded: 2026-11-12
Decision: in core/petchain.lua a mob that reaches MAX_TRIES orders at full health (or MAX_TRIES failed
targets) is put on the 60 s ignore list only when other mobs remain on the extended target list; the last
remaining mob keeps getting the order. When no mob is eligible because all remaining ones are on the ignore
list, the chain waits (does not stop) until the list runs out. The tick is wrapped in pcall and reports errors
in chat and stops, as the standalone script did.
Why: in-game report — at the last remaining mob the pets did not go there, because the chain stopped as soon
as next_mob() found nothing (the last mob was on the ignore list or was the current one).

## D038 Pet chain needs chat permission for Triune orders
Status: Accepted
Recorded: 2026-11-12
Decision: declare the `chat` capability in the add-on package alongside `packets`. Pet chain uses `/say` to send
Triune pet orders, so an installed add-on needs both the declared capability and the server's permission.
Why: the installed add-on could detect attacks but the client refused its follow-up `/say` commands.

## D039 Pet chain reacts to death packets
Status: Accepted
Recorded: 2026-11-12
Decision: watch incoming death packets for the current mob and trigger the next selection on the next UI frame,
after the client has processed the death. Check target confirmation each frame; retain the regular tick as fallback.
Why: shorten the delay between kills without changing targets during the client's death-packet processing.

## D040 Cache frame-loop work instead of rebuilding it
Status: Accepted
Recorded: 2026-11-16
Decision: data that is immutable for a given identity is prepared once and reused per frame: spell-window
details and effect order by spell id, item information and socket ids by item id, the target suffix by target
id plus both switches, the zone short name by zone_id, and the named zone lists by data reference. A named
refresh builds one keyed spawn index instead of scanning spawns per row. Two expensive reads are throttled:
buff slots at most every 0.15 s and item-display children every 0.5 s. Drawing and width-dependent layout
stay per frame; there are no performance switches.
Why: the same data was rebuilt tens of times a second without any visible benefit. The only accepted
behavior change is that a buff appearing or disappearing can be shown up to 0.15 s later; a target switch
forces an immediate buff scan.
Rules out: caching mutable fields, width-dependent layout or map-target positions; adding options for
internal caches.

## D041 QoL dialogs close with Esc by default
Status: Accepted
Recorded: 2026-11-16
Decision: each QoL window with its own screen (FindWalk `FindWalkWnd`, named `NamedWnd` and `NamedEditWnd`)
sets `hud.esc.<screen>` to "1" while that setting is empty, so Esc closes it like the client's own dialogs.
The spell and item displays need no change: they use the game's `SpellDisplayWindow` /
`ItemDisplayWindow` screens, which are already in `lib/escape.lua`'s default-on list. Only an empty setting is
written, so a player who unticked "Close with Esc" in a window's right-click menu keeps that choice.
Why: the client's escape handling is already wired into `hud.Dialog`; the add-on's screens simply were not in
the library's default-on list, so Esc did nothing until the player enabled it by hand. Adding an add-on
switch for Esc would work against the "as few switches as possible" rule.
Rules out: editing the client's `lib/escape.lua` (client source is reference material only); a new option;
changing how the spell and item displays close.

## D042 An item's spell is shown from its own spell ids
Status: Accepted
Recorded: 2026-11-16
Decision: the plugin function `item_spell_info(item)` takes the item window's record and returns the spell it
carries as `{id, name, kind, effects, metadata}`, with `effects` and `metadata` in exactly the `spell_view` shape.
The spell id comes from the record's own fields in a fixed order: `focus_spell`, `proc_spell`, `worn_spell`,
`click_spell`, `scroll_spell`; the first positive integer id wins and `kind` names that field (`Focus`, `Proc`,
`Worn`, `Click`, `Scroll`). `id` and `name` come from `hs.spell(id)`. It is part of the `item_info` switch, and
returns nil when that is off, the record has no spell id, or `hs.spell` is missing or has no record.
Why: a focus, proc or worn effect is what a player most wants explained on an item, and the client hands over the
id (D006), so the spell window's formatting can be reused without guessing (D005). One switch covers all item
information (D003); missing fields degrade to nil (D007).
Rules out: looking an item's spell up by name or description; a separate option; showing more than one spell.

## D043 Esc-to-close reads the key in the window, not hud.esc.*
Status: Accepted
Recorded: 2026-11-16
Supersedes: D041 (setting the default alone did not close the windows ingame)
Decision: FindWalk and the named windows read `ui.IsKeyPressed(ui.Key.Escape)` in their own draw body and close
themselves when it is down, honouring `hud.esc.<screen>` as the on/off switch the right-click menu already
writes. They still write the default "1" while that setting is empty, so the menu shows it on. A press closes
only the window that was opened or clicked last; the open/front stamps are shared between the QoL window scripts
in the UI's Lua globals. The spell and item displays are unchanged: their screens are in the client's own
default-on list and are still closed by the client's escape library.
Why: the client's `lib/escape.lua` reads `hud.esc.<screen>` in the **pack's** settings whenever a pack window
draws first, but a plugin's `ui.SetSetting` writes `plugin.script:qol.hud.esc.<screen>` in its own namespace,
which the pack never reads. Ingame the menu item showed on while Escape did nothing: a pack window consumed the
press and the shared selection could not see our screens. Reading the key from ImGui bypasses that hand-off.
Rules out: writing the pack's `hud.esc.*` (no plugin API can); depending on which window draws first; a new
option or a change to the spell and item displays.

## D044 Focus spells show one modifier row and one limits row
Status: Accepted
Recorded: 2026-11-17
Decision: A focus spell's modifier effects each get their own row (for example `Spell Damage +25%`), and every
limit slot is joined into one muted, wrapped `Limits` row (`instant, detrimental, mana >= 1, ...`) with no
MINIMUM/MAXIMUM columns. A limit or focus SPA whose meaning or sign the client source does not confirm stays a
named raw line (D005). The plain-text API returns `Limits: <phrases>`.
Why: A focus spell is read as "what it boosts, and under which conditions"; one line per limit slot buries that.
Rules out: guessing a sign for an unapplied focus SPA; a new option or a separate window.

## D045 Damage per mana is raw spell damage on its own line
Status: Accepted
Recorded: 2026-11-17
Decision: the spell window and the item display's spell section show `Damage per mana: <value>` on its own line,
directly under the summary line (`Duration: ... Mana: ... Classes: ...`) and in the same colour. The value is the
spell's own direct damage divided by its mana: SPA 0 (`HP`) and SPA 79 (`Instant HP`) with a negative base, each
slot `|base| + change(formula, level)` capped at `|max|`, with `level` the spell's lowest class level. SPA 0 with a
duration is damage per tick, so its total is per-tick x `duration_cap` ticks; SPA 79 is always instant. The line is
omitted when there is no damage slot, a scaling slot has no class level, the total is 0, or the spell costs no mana.
Why: a caster comparing nukes wants the efficiency at a glance, and the client already hands over the raw effects
and mana (D006), so it needs no new data or option.
Rules out: focus modifiers, resist, partials and crits (the client does not expose them here; a later task may add
focus); a new option, file or switch; guessing a level for a scaling slot.

## D046 An uncapped AC effect is a normal row with a generic scale note
Status: Accepted
Recorded: 2026-11-17
Decision: an AC effect (SPA 1) without a cap is shown as a normal effect row: its value at the spell's lowest class
level, no maximum, and the muted note `scales with level` (for example `Armor Class +7 (level 18), scales with
level`). The per-level rate is not shown, because the displayed AC is `floor(raw * 3 / 10)`, so the raw rate (for
example "+1 per 2 levels") would not describe what the player sees. A capped AC keeps its current row with the
minimum and the capped maximum and their levels.
Why: an uncapped AC slot (Feral Spirit, spell 139) fell back to a raw `Slot 6: Armor Class (SPA 1, base 15, ...)`
line, which is unreadable next to the other effects; the value and its level are known, only the rate is not
describable.
Rules out: inventing a per-level AC rate; a new option, file or switch; changing the capped AC row.

## D047 An area spell's damage per mana is labelled per target
Status: Accepted
Recorded: 2026-11-17
Decision: for an area spell the `Damage per mana` line (D045) ends with ` (per target)`, for example
`Damage per mana: 1.17 (per target)`; a single-target spell keeps the plain value. A spell counts as an area spell
when its `ae_range` is greater than 0, or when its `target_type` is one of 2, 4, 8, 20, 21, 22, 23, 24, 25, 28, 36,
37 or 40. The damage slot of those types applies to each target in the area, while the mana is spent once per cast,
so the unlabelled number read as damage per cast. The total damage is not shown because the client does not expose
the spell's target count.
Why: the number is correct but was easy to misread as the whole cast's damage; the label costs no new data, option
or arithmetic.
Rules out: showing a total or a target count (not available from the client); a new option, file or switch; changing
the damage arithmetic; adding a target type the client source does not name.

## D048 Every named SPA gets a normal effect row
Status: Accepted
Recorded: 2026-11-17
Decision: an effect slot whose SPA has no curated `KIND`/`DISPLAY` entry is shown as a normal row instead of a raw
line. Precedence is `KIND`/`DISPLAY`, then `FOCUS`, then `LIMIT`, then the shape rule; an SPA with no name in the
generated table, or one whose value cannot be shown, stays a raw line. The rule derives the row shape from the
client's SPA name: a pure state is a **flag** (name only), a record id is an **id** (`#N`), a name that says it is a
percentage is a **percent** (`+N%`), and everything else is a **number** (`+N`). The value uses the same arithmetic
as the curated numeric rows: `|base| + change(formula, level)`, capped at `|max|`, with `level` the spell's lowest
class level; a scaling slot without a class level stays raw, and `base2` is not shown. The existing skips stay: SPA
254 (empty slot), the charisma spacer (SPA 10 with base <= 1 or > 255), and the `base2 ~= 0` guard for curated kinds.
Why: a raw line such as `Slot 3: Casting Level (SPA 112, base 2, ...)` is unreadable next to the other effects, and
one name-based rule covers every SPA the client names without hundreds of per-SPA entries to maintain.
Rules out: a new option, file or marker character; guessing a level for a scaling slot; showing `base2`; changing a
curated row's output. Limitation: the shape follows the client's name, so an unusual SPA whose name does not
describe its value may need a curated `KIND` entry later. The generated name table covers SPA 0-500; an SPA it does
not name (for example 501-528 in the client's `spa_ids.h`) stays raw until the table is regenerated.

## D049 A proc or trigger row says what the fired spell does
Status: Accepted
Recorded: 2026-11-17
Decision: a proc row (SPA 85/201/323/419) and a trigger row (SPA 339) show the fired spell's name and, when one
can be built, a one-line summary: `Prismatic Strike II: 45 fire damage`. The summary is the spell's direct damage
(`spell_effects.damage`) with the resist name from the existing `RESIST` table in front of `damage` when the resist
is known and not unresistable, otherwise the first one or two formatted effect rows joined by `, `. It is built
without a lookup, so it cannot recurse. The `lookup` callback may now return either a name string (the old contract)
or `{name = <string>, summary = <string|nil>}`; the `Limit: Spell` phrase (SPA 139) uses the name only. A string
result keeps working exactly as before, and a lookup that returns nothing still shows `#<id>`.
Why: a row that names a spell the player cannot see the effects of is only half the answer; the summary costs no new
option, file or client data, and the depth stays 1 because the summary never looks anything up.
Rules out: a new option, file or switch; a recursive lookup; showing the summary in the `Limit: Spell` phrase.

## D050 Damage per mana opens the blue metadata block
Status: Accepted
Recorded: 2026-11-17
Decision: supersedes D045's placement and colour. The spell window and the item display's spell section draw
`Damage per mana: <value>` as the first line of the blue metadata block, directly above `Cast: ... Recovery: ...
Recast: ...`, in the same cyan (`EXTRA_COLOR`) as those lines. The shared `drawMetadata` draws it, so both windows
get it from one place; the summary line keeps only `Duration`/`Mana`/`Classes` in the normal text colour. The label,
value, `(per target)` suffix and omission rules are unchanged.
Why: the number is one of the spell's own figures, so it belongs with the timing and range lines rather than in the
header; the cyan block already groups exactly those numbers.
Rules out: a new option, file or switch; changing the value or its label; drawing it twice.

## D051 Item spell-id fields use camelCase
Status: Accepted
Recorded: 2026-11-18
Supersedes: D042 (only the spell-id field names)
Decision: the spell-ID fields are `focusSpell`, `procSpell`, `wornSpell`, `clickSpell`, `scrollSpell`, in that order;
the first positive integer id wins and `0` or `-1` means "no spell". This supersedes D042's snake_case names because
the merged client (PR #101, commit 66758e7) exposes them in camelCase.
Why: the client renamed the new fields to camelCase to match the rest of the record before merging to main.

## D052 Display caches honour live information options
Status: Accepted
Recorded: 2026-11-18
Clarifies: D004, D040, D042
Decision: spell and item displays read the read-only `display_options()` plugin snapshot once per frame per
display script, before cache access. Disabled details are hidden even on cache hits; IDs first seen while off
are not cached as missing data. The base window and description remain visible. Standalone spell APIs follow
`spell_info`; an item's extra text and spell section follow only `item_info`.
Why: immutable per-ID data may be cached, but an option is live state and must not be frozen with that data.

## D053 Pet chain keeps cheap health watches and one candidate scan
Status: Accepted
Recorded: 2026-11-18
Clarifies: D037, D039, D040
Decision: ordinary health watches use an early-exit membership lookup with one player read and no snapshot.
Selection uses one slot scan, retaining the first duplicate slot's hater type and filtering each distinct ID
once; the same result decides whether to wait for ignored mobs or stop. Last-mob safety checks stop at the
first other eligible mob, independent of ignores. Rare stall/skip transitions can perform separate membership,
safety and selection scans; there is no promise of one scan for every possible tick.
Idle ticks skip both settings and pcall. Active ticks read the option once inside pcall, including through
the UI bridge, so settings/client errors still report and stop the chain. Target wait, health stall, ignore
expiry and deferred death handling keep their existing timing.
Why: a full snapshot per health watch trades fewer candidate-round client calls for unnecessary common-path
allocations and slot reads. Separate small lookups keep the usual health-watch and pending paths cheap.

## D054 The target line wraps the pack's hs.UI map calls
Status: Accepted
Recorded: 2026-11-20
Clarifies: D018, D020
Decision: the map and minimap adapters wrap `hs.UI.map.DrawZone` and `hs.UI.map.DrawMinimap` in the add-on's own
environment, and keep wrapping the flat `eq.DrawZoneMap` / `eq.DrawMinimap` names for older files. All other fields
and functions pass through unchanged; the shared API is never written.
Why: the Modern pack's map draws through its `hs.UI` facade now. That facade captured the client function when the UI
started, so shadowing the flat `eq` name no longer intercepted it and the line silently disappeared.
Rules out: Patching the shared `hs.UI` table; copying the pack's map windows.

## D055 The map adapters replace their hook when a file reloads
Status: Accepted
Recorded: 2026-11-20
Clarifies: D054
Decision: the map and minimap adapters keep the client's own views, the client functions and the shadow tables in one
table in the plugin's globals (`qol_map_hooks`). Loading either file captures the client functions once and installs
its hook in the existing shadow; a failed pack load clears that adapter's hook instead of restoring a previous shadow.
Why: the host keeps a plugin folder's globals across a hot reload of one of its files (`lua_host.cpp`). The first
version read the draw function from the current `eq`/`hs`, which on a reload was its own wrapper: each reload added a
layer and drew the line twice, and a failed load put the stale wrapper back. D054's shadows carry no marker, so
updating a live session from D054 still wraps one stale layer: restart the plugin (`/lua stop qol`, `/lua run qol`),
which the local test steps do anyway.
Rules out: Reading `eq`/`hs` at the top of the file as the client's views; wrapping whatever the globals hold.

## D056 Every limit SPA the client names joins the Limits row
Status: Accepted
Recorded: 2026-11-20
Supersedes: D044 (only where a limit SPA whose meaning the client does not confirm stayed a raw line)
Decision: every focus limit joins the muted `Limits` row. The cases this decision added to `check_focus_limit`'s
switch have curated phrases: spell group (0x181), spell class (0x193), spell subclass (0x194), class mask (0x19b),
race mask (0x19c), item class (0x19f), hits >= N (0x1a6) and hit count type (0x1a7). Where the client decides the
sense with `match_or_exclude` (0x181, 0x193, 0x194), a negative base is the exclusion: `not spell group 385`,
`not spell class 3`, `not spell subclass 3`. The two masks are unsigned bitfields, shown as their raw 32-bit value
(`class mask 0x2`, `race mask 0x80000003`), so bit 31 is a bit and not a sign. 0x19f compares the item class and
subclass exactly and reserves -1 for "any", so base -1 reads `any item class`; 0x1a6 is `hit_count >= base`
(`hits >= 3`); 0x1a7 is `hit_count_type == base`, printed as stored. 0x89 (Limit Effect) keeps its effect-name list
and an id without a name reads `no effect N` for a negative base, `has effect N` for a positive one. The other
curated limit phrases (resist, target, level, mana, cast time, combat skills) are unchanged. Every remaining limit
condition is shown from its own name table entry: a generated name that starts with `Limit ` or `FF ` joins the
Limits row as that name without the prefix, lowercased, plus the base (`Limit HP Percent` base 50 is
`hp percent 50`). A slot whose generated name does not start with `Limit ` or `FF ` keeps its current shape, and one
the table has no name for stays a raw line (D048). Target types the table does not name are shown by number
(`target not type 20`). Types 16-18 are named by the client itself
(`code/src/game/mechanics/cast_spell.cpp`: `case 16 // plant`, `case 17 // giant`, `case 18 // dragon`), and the rest
of the table follows `target_type_name` in `code/src/app/spell_ui.cpp` (`target not giant`).
Why: the screenshot case showed `Slot 9: Limit Target (SPA 136, base -17, base2 0, max 0, formula 100)` and its base
-18 twin next to an otherwise clean effects list. The client's `check_focus_limit` applies both slots (a negative base
is "not this target type"), so they are ordinary limits, not unknown data. The same held for the other conditions the
client names, including ones outside its switch: a raw SPA dump hid a real restriction.
Rules out: guessing a sign or meaning the client does not confirm; a new option, file or switch; showing `base2`, max
or formula of a condition whose meaning is unknown.

## D057 Named detection uses guaranteed loot drops
Status: Accepted
Recorded: 2026-11-22
Supersedes: D028 (only the named-detection rule; the rest of the tracker stands), D030 (only the rejection of loot-based detection; the loot index stays)
Decision: `tools/gen_named_data.py` marks a spawned NPC as named when its loottable has at least one
`loottable_entries` row with `mindrop >= 1` — a guaranteed drop. Placeholder-style names (`a_...`/
`an_...`) count too, since classic named mostly have such names. Names that start with `#`, end in
a digit or contain "corpse" stay out, as do service NPCs and `EXCLUDED_NAMES`. The old
`spawn_limit` / `rare_spawn` / `unique_` / `raid_target` / `lastname` flags and the non-placeholder
name rule no longer make an NPC named. Drop lists still come straight from the database loot chain,
so upgraded item ids the DB lists in their own right (base id + 1,000,000 Enchanted and + 2,000,000
Legendary, with the DB's own names) are kept as-is. Regenerated data: 227 zones, 1,954 named,
23,251 drops, 7,943 loot-index names, 9,000 items (1.74 MB).
Why: community sites (Almar's Guides, EQ Atlas, EQ Legends Tools) list the classic named of Lower
Guk. The old flag rule found only 7 of them plus a junk spawn (`Zol_Ghoul_Knight`), while
`mindrop >= 1` finds all of them plus `a_reanimated_hand` and the other community named, and drops
the junk. Globally the old rule listed 10,751 zone/name pairs, many of them `#` event spawns and rare
placeholders; the new rule lists 1,954 and keeps the generated file roughly half the size. The
`mindrop` flag means "this droplist always gives at least one item", not "this item drops at 100%",
which is why it does not pull in the high-chance junk D030 rejected.
Rules out: the flag-based named rule; a generic loot-chance threshold. Known limitation: 150 zones
that had flagged named now have none, because their named have no guaranteed drop, and a few
container objects with large loottables (for example `a_moldy_chest`) pass the rule.

## D058 A scaling effect without a class level shows its level 1 value and rate
Status: Accepted
Recorded: 2026-11-22
Supersedes: D048 (only the rule that a scaling slot without a class level stays raw)
Decision: an effect slot whose formula scales with level, and whose spell has no class level (every `class_level`
entry 255, as on item proc spells), is shown as a normal row instead of a raw SPA line. It shows the level 1 value
(`|base| + change(formula, 1)`), the muted rate (`+1 per 4 levels`, or `scales with level` for AC as in D046) and,
when the slot has a cap, the capped value with the level that reaches it (`-15 to -27 (L48)`). The cap's level is a
property of the formula, so it needs no class level and nothing is guessed. With a cap the rate is carried in `note`
(the UI draws `scale` and `note` in the same muted line) so the plain-text line keeps it; without a cap it stays in
`scale`. A formula the client's `change` cannot express (tick based, random, HP based) and an SPA the client's table
does not name still stay raw. A `plain` row (a damage shield stored negative, a cure counter shown as removed) shows
the magnitude, so its rate follows the shown sign too (`Damage Shield 6, +1 per 4 levels`), with or without a class
level.
Why: Steal Strength (spell 944, an item proc) showed `Slot 1: STR (SPA 4, base -15, base2 0, max 27, formula 109)`
on Dark Reaver (Legendary) next to otherwise readable effects; the row can describe the value and its growth without
knowing the spell's own level.
Rules out: guessing a class or caster level; a made-up minimum for a formula that starts above level 1; showing
`base2`; changing a row for a spell that does have a class level.

## D059 The Resist type header uses the client's resist name
Status: Accepted
Recorded: 2026-11-22
Decision: the header of a detrimental spell shows `Resist type: <name>` with the client's own resist name
(`spell_resist_type_desc` in spell_effect_text.cpp): `unresistable` (0), `magic`, `fire`, `cold`, `poison`,
`disease`, `chromatic`, `prismatic`, `physical`, `corruption`. An id outside 0-9 keeps the number, because the
client has no name for it. The names are lowercase, like the limit phrases and the proc damage summary, and
`spell_effects.RESIST` stays the one table for both. Beneficial spells still show no resist line.
Why: the Dark Reaver (Legendary) item window showed `Resist type: 1` next to readable effects; the client names the
same field and the add-on already carried the table for proc summaries (`45 fire damage`).
Rules out: guessing a name for an id the client does not name; a second resist table; a new option or file.
