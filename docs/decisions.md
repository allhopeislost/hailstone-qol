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
