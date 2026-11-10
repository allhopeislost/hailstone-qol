# Product decisions

Decisions about what the add-on does and does not do. Each entry says what was decided, why, and what it rules out.
Add a new entry when a decision is made; do not reverse one without replacing its entry.

## Scope

**Modern UI only.** The add-on replaces and extends windows of the Modern UI pack. There is no Gamepad UI support
and none is planned. *Rules out:* Gamepad windows, or adapting a feature to it.

**Replacing a window is fine, if the result is better.** The target, spell-display and item-display windows are
replaced by the add-on's own layouts. The map is the exception: it is loaded through a thin adapter so map art and
updates keep coming from the game.

**As few switches as possible.** A feature gets its own option only when players reasonably want it off. Related
displays share one switch (`target_level` covers nameplate and target-window levels). *Rules out:* a toggle per
detail.

**Options are persistent and live under Options → Plugins.** Settings are stored outside the add-on files, so
updates never reset them. All options default to on except `item_preview`.

## Behaviour

**Nothing is guessed or made up.** An effect the add-on cannot show correctly is shown as a named raw line, so no
data is lost. No cap level is invented for an uncapped effect, and a scaling effect with no known caster level stays
raw. *Rules out:* estimating values, matching spells by title or spellbook, or inferring IDs from names.

**Work from IDs the client provides.** The spell and item windows read the record the client hands over for that
specific window. *Rules out:* spellbook or title matching.

**Missing client hooks degrade quietly.** If a hook, API or field is absent, that extra is skipped and everything
else still works. The add-on never errors because a custom-client extra is missing.

**Existing working client APIs are kept.** The nameplate hook, the map-spawn hook and the display-record functions
are the add-on's integration points and stay as they are.

## Targets and nameplates

**Levels and class are for creatures, not services.** Merchants, bankers and trainers (class ids past the playable
ones) show neither level nor class. The class tag only appears for the playable classes (WAR to BER).

**One switch controls levels** in both the nameplates and the target window; class has its own switch.

## Spell display

**Compact effect lines.** Effects show a minimum and a maximum with the caster level each is reached at, in aligned
columns. Casting details and IDs are grouped below them.

**The game's description and the extra information share one scrolling area.**

**Left out on purpose:** the fixed / no-spell-cap flags, an explanation of how AC is calculated, and the cast
messages ("cast on you/other", "wears off").

**Effects show spell values, not character totals.**

## Item display

**English text, additional information only.** The extra item information leaves out the icon and item type, since
the window already shows them.

**Other item versions are opt-in and Project Triune only.** The option is off by default. A click asks the client to
open the requested tier in its own separate window; the window the player clicked in is never replaced, and the
add-on does not claim the client confirmed anything. *Rules out:* replacing, moving or closing item windows, and
offering versions on other servers.

## Map

**The target line is a straight line, not a route.** It is only drawn on the large map, and only when the player and
target positions are known. *Rules out:* pathfinding, a minimap line.

**Map NPCs follow the map's own layers and filters.** Living NPCs only; corpses and players are left out.
