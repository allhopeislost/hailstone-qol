#!/usr/bin/env python3
"""Stage the QoL runtime allowlist and ask Hailstone's make_addon.py to package it."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]
VERSION = "0.3.3"

# The manifest's capability ceiling. `commands` lets the dialogs' close box
# (and Esc/menu Close) hide the game window; `actions` lets the displays'
# own clicks work (icon chat-link, sockets, Modified button, description
# links). Without them those calls silently do nothing on manager installs.
# `target` and `move` are for the FindWalk window's Travel to button, which sends
# `/target id N` and `/nav id N`; each command is checked against these bits.
CAPS = "read,ui,extend,commands,actions,target,move,packets,chat"

# Keep this list explicit: the client package must not include tests, docs, this tool,
# old packages, or generated manifests. `qol.lua` is user data in mq.configDir, not a
# runtime file to package; `core/settings.lua` is the code that loads/saves it.
RUNTIME_FILES = (
    "init.lua",
    "core/findwalk.lua",
    "core/info.lua",
    "core/named.lua",
    "core/named_data.lua",
    "core/petchain.lua",
    "core/settings.lua",
    "core/spell_effects.lua",
    "core/spell_spa_names.lua",
    "ui/modern/itemdisplay.lua",
    "ui/modern/maptargetline.lua",
    "ui/modern/minimaptargetline.lua",
    "ui/modern/spelldisplay.lua",
    "ui/modern/target.lua",
    "ui/modern/findwalk.lua",
    "ui/modern/named.lua",
    "ui/modern/petchain.lua",
)


def stage_runtime(source: Path, destination: Path) -> tuple[str, ...]:
    """Copy exactly the allowlisted runtime files into a clean staging directory."""
    destination.mkdir(parents=True, exist_ok=True)
    staged: list[str] = []
    for relative in RUNTIME_FILES:
        src = source
        for component in Path(relative).parts:
            src = src / component
            if src.is_symlink():
                raise FileNotFoundError(f"runtime path must not use symlinks: {src}")
        if not src.is_file():
            raise FileNotFoundError(f"required runtime file missing or not a regular file: {src}")
        dest = destination / relative
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, dest)
        staged.append(relative)
    return tuple(staged)


def resolve_output(path: Path, source: Path = ROOT) -> Path:
    """Resolve and reject a release output directory inside the add-on source tree."""
    output = path.expanduser().resolve()
    source = source.resolve()
    if output == source or source in output.parents:
        raise ValueError(f"--out must be outside the source tree: {output}")
    return output


def find_make_addon(explicit: str | None) -> Path:
    """Use an explicit path, env override, or the conventional sibling client checkout."""
    candidates = [explicit, os.environ.get("HAILSTONE_MAKE_ADDON")]
    candidates.append(str(ROOT.parents[1] / "Hailstone-dev" / "tools" / "make_addon.py"))
    for candidate in candidates:
        if candidate:
            path = Path(candidate).expanduser()
            if path.is_file():
                return path.resolve()
    raise FileNotFoundError(
        "Hailstone tools/make_addon.py not found; pass --make-addon or set HAILSTONE_MAKE_ADDON"
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, type=Path, help="release output directory")
    parser.add_argument("--make-addon", help="path to Hailstone tools/make_addon.py")
    parser.add_argument("--author", default="", help="author line for the manifest")
    parser.add_argument("--description", default="", help="description line for the manifest")
    parser.add_argument("--notes", default="", help="release-notes URL for the manifest")
    parser.add_argument("--version", default=VERSION, help=f"version for the manifest (default: {VERSION})")
    args = parser.parse_args()

    try:
        make_addon = find_make_addon(args.make_addon)
        output = resolve_output(args.out)
        output.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="hailstone-qol-") as temp:
            stage = Path(temp) / "qol"
            stage_runtime(ROOT, stage)
            command = [
                sys.executable,
                str(make_addon),
                "--name",
                "qol",
                "--kind",
                "script",
                "--version",
                args.version,
                "--caps",
                CAPS,
                "--dir",
                str(stage),
                "--out",
                str(output),
            ]
            if args.author:
                command += ["--author", args.author]
            if args.description:
                command += ["--description", args.description]
            if args.notes:
                command += ["--notes", args.notes]
            subprocess.run(command, check=True)
    except (FileNotFoundError, ValueError, subprocess.CalledProcessError) as exc:
        print(f"package: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
