#!/usr/bin/env python3
"""Generate core/named_data.lua from the NMS / Project Triune release database dump.

Source: https://github.com/tunaria/NMS-Release
        Release-NMS-Server/database/release-peq.zip  ->  release-peq.sql (one big MySQL dump)

Usage:
    python3 tools/gen_named_data.py --dump /path/to/release-peq.sql
    python3 tools/gen_named_data.py --dump /path/to/release-peq.sql --out core/named_data.lua

The dump is streamed (no database server needed); the output is deterministic apart
from the `generated` date line: zones, named and drops are sorted, so re-running on a
new dump gives a clean diff. Only zones with at least one named NPC are written.

Named detection (npc_types):
    spawn_limit = 1 OR rare_spawn = 1 OR unique_ = 1 OR raid_target = 1
    OR lastname is set
    OR the name is not a placeholder (does not start with a_ / an_, no trailing digit,
       not #-prefixed). Service NPCs (trainers/bankers/merchants by class id) are excluded.

Drops: loottable -> loottable_entries(probability) -> lootdrop -> lootdrop_entries(item_id, chance);
effective chance = probability * chance / 100, kept when > 0.

Besides the named zones, a `loot` index maps every placeholder-style spawned name (a_.../an_...,
letters, no trailing digit) to its drops (effective chance >= 5%, at most 12 per name, keyed like
Lua's nameKey: lowercase, underscores read as spaces). The /named window's drop list falls back to
it for names a player tracks by hand, e.g. "a reanimated hand" in gukbottom, which the release
database does not flag as named (no spawn_limit/rare_spawn/unique_/raid_target/lastname) but the
community treats as one.
"""

from __future__ import annotations

import argparse
import datetime
import re
import sys
from pathlib import Path

# Class ids of service NPCs (same sets as core/findwalk.lua): not "named".
TRAINER_FIRST, TRAINER_LAST = 20, 35
BANKERS = {40, 66}
MERCHANTS = {41, 59, 61, 67, 68, 70}

# Names never listed as named, whatever their flags (server-specific NPCs, see docs/decisions.md D033):
# compared by name key (lowercase, underscores read as spaces).
EXCLUDED_NAMES = {"echo of the past"}

TABLES = {
    "zone", "spawn2", "spawnentry", "npc_types",
    "loottable_entries", "lootdrop_entries", "items",
}

# npc_types columns we keep (by name).
NPC_COLS = ("id", "name", "lastname", "level", "hp", "class", "loottable_id",
            "spawn_limit", "rare_spawn", "unique_", "raid_target")


def split_tuples(values: str):
    """Split a MySQL VALUES body into top-level row tuples (quote/escape aware)."""
    rows, cur, tok = [], None, []
    i, n = 0, len(values)
    in_str = False
    while i < n:
        c = values[i]
        if in_str:
            tok.append(c)
            if c == "\\" and i + 1 < n:
                tok.append(values[i + 1])
                i += 2
                continue
            if c == "'":
                in_str = False
            i += 1
            continue
        if c == "'":
            in_str = True
            tok.append(c)
        elif c == "(":
            cur, tok = [], []
        elif c == ")":
            if cur is not None:
                cur.append("".join(tok).strip())
                tok = []
                rows.append(cur)
                cur = None
        elif c == "," and cur is not None:
            cur.append("".join(tok).strip())
            tok = []
        else:
            tok.append(c)
        i += 1
    return rows


def unq(v: str):
    if v == "NULL":
        return None
    if v.startswith("'") and v.endswith("'"):
        return v[1:-1].replace("\\'", "'").replace('\\"', '"').replace("\\\\", "\\")
    try:
        return int(v)
    except ValueError:
        try:
            return float(v)
        except ValueError:
            return v


def columns_of(create_body: str):
    cols = []
    for line in create_body.splitlines():
        m = re.match(r"\s*`(\w+)`", line)
        if m:
            cols.append(m.group(1))
    return cols


def stream(path: str):
    """Yield (table, columns, rows) for each INSERT of a wanted table. Multi-line aware."""
    table, cols, buf = None, None, []
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            if line.startswith("CREATE TABLE `"):
                name = line.split("`")[1]
                if name in TABLES:
                    table, cols, buf = name, None, [line]
                else:
                    table = None
                continue
            if table is not None and cols is None:
                buf.append(line)
                if line.startswith(")"):
                    cols = columns_of("".join(buf))
                    buf = []
                continue
            if table is not None and line.startswith("INSERT INTO `") and line.split("`")[1] == table:
                stmt = line
                while not stmt.rstrip().endswith(";"):
                    stmt += next(f)
                body = stmt[stmt.index("VALUES") + 6:].rstrip().rstrip(";")
                yield table, cols, [[unq(v) for v in row] for row in split_tuples(body)]
            elif line.startswith("DROP TABLE") or line.startswith("CREATE TABLE"):
                table = None


def rowdict(cols, row):
    return dict(zip(cols, row))


def is_service(class_id) -> bool:
    if not isinstance(class_id, int):
        return False
    return (TRAINER_FIRST <= class_id <= TRAINER_LAST
            or class_id in BANKERS or class_id in MERCHANTS)


def is_placeholder_name(name: str) -> bool:
    low = name.lower()
    if not low or low.startswith("#"):
        return True
    if not re.search(r"[a-z]", low):  # "_", "__", ... are invisible/trigger names
        return True
    if low.startswith("a_") or low.startswith("an_"):
        return True
    if low[-1].isdigit():
        return True
    if "corpse" in low:
        return True
    return False


def is_named(npc: dict) -> bool:
    name = npc.get("name")
    if not isinstance(name, str) or not name:
        return False
    if not re.search(r"[a-z]", name.lower()):
        return False  # invisible/trigger names ("_", "__") are never named, whatever the flags
    if not is_placeholder_name(name):
        return True
    # placeholder-looking names ("a_...") can still be named via a flag or a lastname
    return (npc.get("spawn_limit") == 1 or npc.get("rare_spawn") == 1
            or npc.get("unique_") == 1 or npc.get("raid_target") == 1
            or bool(str(npc.get("lastname") or "").strip()))


def lua_str(s: str) -> str:
    return ('"' + s.replace("\\", "\\\\").replace('"', '\\"')
            .replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t") + '"')


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dump", required=True, help="path to release-peq.sql (unzipped)")
    parser.add_argument("--out", default=str(Path(__file__).resolve().parents[1] / "core" / "named_data.lua"))
    parser.add_argument("--source", default="https://github.com/tunaria/NMS-Release "
                        "(Release-NMS-Server/database/release-peq.zip)")
    parser.add_argument("--max-drops", type=int, default=200, help="cap drops per named (default 200)")
    args = parser.parse_args()

    # pass 1: zones, spawns, spawn entries
    zone_long = {}
    zone_groups = {}   # zone short -> set(spawngroupID)
    group_npcs = {}    # spawngroupID -> set(npcID)
    spawned_npc_ids = set()
    for table, cols, rows in stream(args.dump):
        if table == "zone":
            for r in rows:
                d = rowdict(cols, r)
                short = d.get("short_name")
                if isinstance(short, str) and short:
                    zone_long[short.lower()] = d.get("long_name") or short
        elif table == "spawn2":
            for r in rows:
                d = rowdict(cols, r)
                z = d.get("zone")
                if isinstance(z, str) and z:
                    zone_groups.setdefault(z.lower(), set()).add(d.get("spawngroupID"))
        elif table == "spawnentry":
            for r in rows:
                d = rowdict(cols, r)
                g, npc = d.get("spawngroupID"), d.get("npcID")
                if g is not None and npc is not None:
                    group_npcs.setdefault(g, set()).add(npc)
                    spawned_npc_ids.add(npc)
    print(f"pass 1: {len(zone_long)} zones, {len(zone_groups)} zones with spawns, "
          f"{len(group_npcs)} groups, {len(spawned_npc_ids)} spawned npc ids", file=sys.stderr)

    # pass 2: npc_types of spawned npcs (only the columns we need)
    npcs = {}  # id -> dict of NPC_COLS
    want_idx = None
    for table, cols, rows in stream(args.dump):
        if table == "npc_types":
            want_idx = [cols.index(c) for c in NPC_COLS]
            for r in rows:
                if r[want_idx[0]] in spawned_npc_ids:
                    npcs[r[want_idx[0]]] = {c: r[i] for c, i in zip(NPC_COLS, want_idx)}
    print(f"pass 2: {len(npcs)} npc_types kept", file=sys.stderr)

    # pass 3: loot chain and item names
    lte = {}  # loottable_id -> [(lootdrop_id, probability)]
    lde = {}  # lootdrop_id -> [(item_id, chance)]
    items = {}  # item id -> Name
    for table, cols, rows in stream(args.dump):
        if table == "loottable_entries":
            for r in rows:
                d = rowdict(cols, r)
                lte.setdefault(d.get("loottable_id"), []).append(
                    (d.get("lootdrop_id"), d.get("probability")))
        elif table == "lootdrop_entries":
            for r in rows:
                d = rowdict(cols, r)
                lde.setdefault(d.get("lootdrop_id"), []).append(
                    (d.get("item_id"), d.get("chance")))
        elif table == "items":
            for r in rows:
                d = rowdict(cols, r)
                items[d.get("id")] = d.get("Name")
    print(f"pass 3: {len(lte)} loottables, {len(lde)} lootdrops, {len(items)} items", file=sys.stderr)

    def drops_of(loottable_id):
        out = {}
        for ldid, prob in lte.get(loottable_id, []):
            for item_id, chance in lde.get(ldid, []):
                if not isinstance(item_id, int) or not isinstance(chance, (int, float)):
                    continue
                eff = round(min(100.0, (prob if isinstance(prob, (int, float)) else 100) * chance / 100.0), 2)
                if eff > 0:
                    out[item_id] = max(out.get(item_id, 0), eff)
        return sorted(((iid, c) for iid, c in out.items()), key=lambda x: (-x[1], x[0]))[:args.max_drops]

    # per zone: named npc entries, deduped by lower name (drops merged, max chance)
    zones = {}
    for zshort, groups in zone_groups.items():
        by_name = {}
        for g in groups:
            for nid in group_npcs.get(g, ()):
                npc = npcs.get(nid)
                if not npc or not isinstance(npc.get("name"), str):
                    continue
                if is_service(npc.get("class")):
                    continue
                if not is_named(npc):
                    continue
                key = npc["name"].lower()
                if re.sub(r"\s+", " ", key.replace("_", " ").strip()) in EXCLUDED_NAMES:
                    continue
                entry = by_name.get(key)
                if entry is None:
                    by_name[key] = {"name": npc["name"], "level": npc.get("level") or 0,
                                    "drops": drops_of(npc.get("loottable_id"))}
                else:
                    entry["level"] = max(entry["level"], npc.get("level") or 0)
                    merged = {iid: c for iid, c in entry["drops"]}
                    for iid, c in drops_of(npc.get("loottable_id")):
                        merged[iid] = max(merged.get(iid, 0), c)
                    entry["drops"] = sorted(merged.items(), key=lambda x: (-x[1], x[0]))[:args.max_drops]
        if by_name:
            named = sorted(by_name.values(), key=lambda e: e["name"].lower())
            zones[zshort] = {"long": zone_long.get(zshort, zshort), "named": named}

    used_items = sorted({iid for z in zones.values() for n in z["named"] for iid, _ in n["drops"]})

    # Loot index for placeholder-style names the named rule excludes (hand-tracked names get
    # their drops through this): a_.../an_..., letters, no trailing digit, not a corpse, not #.
    def loot_key(name: str):
        k = re.sub(r"\s+", " ", name.replace("_", " ").strip().lower())
        return k or None

    loot = {}
    for nid, npc in npcs.items():
        name = npc.get("name")
        if not isinstance(name, str) or not name:
            continue
        if is_service(npc.get("class")):
            continue
        low = name.lower()
        if not (low.startswith("a_") or low.startswith("an_")):
            continue
        if not re.search(r"[a-z]", low) or low[-1].isdigit() or "corpse" in low or low.startswith("#"):
            continue
        lt = npc.get("loottable_id")
        if not isinstance(lt, int) or not lt:
            continue
        key = loot_key(name)
        if not key:
            continue
        drops = [(iid, c) for iid, c in drops_of(lt) if c >= 5.0][:12]
        if not drops:
            continue
        if key not in loot:
            loot[key] = drops
        else:
            merged = {iid: c for iid, c in loot[key]}
            for iid, c in drops:
                merged[iid] = max(merged.get(iid, 0), c)
            loot[key] = sorted(merged.items(), key=lambda x: (-x[1], x[0]))[:12]

    used_items = sorted(set(used_items) | {iid for drops in loot.values() for iid, _ in drops})
    item_names = {iid: (items.get(iid) or str(iid)) for iid in used_items}

    today = datetime.date.today().isoformat()
    lines = [
        "-- Generated by tools/gen_named_data.py -- do not edit; regenerate instead.",
        f"-- Source: {args.source}",
        f"-- Generated: {today}",
        "-- zones[short] = { long = ..., named = { { name, level, drops = { {itemId, chance}, ... } }, ... } }",
        "-- items[itemId] = display name. Only zones with at least one named NPC are listed.",
        "-- loot[nameKey] = drops of a placeholder-style spawned name (for hand-tracked names):",
        "--   nameKey is lowercase with underscores read as spaces; drops are { {itemId, chance}, ... }.",
        "return {",
        f"  source = {lua_str(args.source)},",
        f"  generated = {lua_str(today)},",
        "  items = {",
    ]
    for iid in used_items:
        lines.append(f"    [{iid}] = {lua_str(item_names[iid])},")
    lines.append("  },")
    lines.append("  loot = {")
    for key in sorted(loot):
        drops = ", ".join(f"{{{iid}, {c}}}" for iid, c in loot[key])
        lines.append(f"    [{lua_str(key)}] = {{ {drops} }},")
    lines.append("  },")
    lines.append("  zones = {")
    for zshort in sorted(zones):
        z = zones[zshort]
        lines.append(f"    [{lua_str(zshort)}] = {{ long = {lua_str(z['long'])}, named = {{")
        for n in z["named"]:
            drops = ", ".join(f"{{{iid}, {c}}}" for iid, c in n["drops"])
            lines.append(f"      {{ name = {lua_str(n['name'])}, level = {n['level']}, "
                         f"drops = {{ {drops} }} }},")
        lines.append("    } },")
    lines.append("  },")
    lines.append("}")
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    n_named = sum(len(z["named"]) for z in zones.values())
    n_drops = sum(len(n["drops"]) for z in zones.values() for n in z["named"])
    print(f"wrote {out} ({out.stat().st_size / 1e6:.2f} MB): "
          f"{len(zones)} zones, {n_named} named, {n_drops} drops, {len(loot)} loot-index names, "
          f"{len(used_items)} items", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
