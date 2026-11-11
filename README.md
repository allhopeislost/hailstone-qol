# Hailstone QoL

A Hailstone add-on with small quality-of-life improvements for the **Modern UI**.

## Features

- **Target levels and class**: shows the level (and optionally the class) of living NPCs on nameplates and in the target window. Merchants, bankers and trainers are left out.
- **Spell display**: a richer spell window with readable effects, casting details and spell IDs.
- **Item display**: a richer item window with extra information such as base and tribute value, delay/damage ratio and lore.
- **Other item versions** (Project Triune only, off by default): buttons to open the Enchanted or Legendary version of an item.
- **Target line on map and minimap**: draws a line from you to your target on the large map and on the minimap.
  On the minimap the line follows its rotation and stops at the edge of the circle when the target is out of range.
- **All NPCs on the map**: shows every living NPC on the maps.
- **FindWalk**: `/findW` (or Plugins → Find in the menu) opens a window that lists the spawns in the zone, A to Z.
  Search by name, filter NPCs, players and corpses (only NPCs at first), and click a column head to sort by it (click
  again to reverse). A Role column marks merchants, bankers and trainers while any are listed. **Travel to**, or a
  double click on a row, targets that spawn and walks to it. `/findW gnoll` opens it with that search. The filters and
  the sort are not saved. Zone lines are not listed: the client does not give them to add-ons.

Every feature can be switched on or off under **Options → Plugins**.

## Install

In Hailstone's login-screen **Add-ons** panel, paste `https://github.com/allhopeislost/hailstone-qol` and choose **Install**.

## License

MIT
