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
