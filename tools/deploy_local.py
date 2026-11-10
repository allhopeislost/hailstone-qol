#!/usr/bin/env python3
"""Copy the QoL runtime files into a Hailstone install's scripts/qol for local testing.

Uses the same allowlist as tools/package.py, so what you test is what a release contains. Refuses to run while the
add-on manager still has qol installed (its hashes would give the files different rights); remove it in the
Add-ons panel first.
"""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import shutil
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import package  # noqa: E402  (same directory)

DEFAULT_HOME = Path(os.environ.get("HAILSTONE_HOME", "~/Games/Hailstone")).expanduser()


def manager_has_qol(home: Path) -> bool:
    installed = home / "addons" / "installed.txt"
    if not installed.is_file():
        return False
    return any(line.strip() == "addon qol script" for line in installed.read_text(encoding="utf-8").splitlines())


def deploy(source: Path, home: Path) -> tuple[Path, tuple[str, ...]]:
    """Replace home/scripts/qol with exactly the runtime files. Raises ValueError when it must not."""
    if manager_has_qol(home):
        raise ValueError("qol is installed by the add-on manager (addons/installed.txt); remove it there first")
    scripts = home / "scripts"
    if not scripts.is_dir():
        raise ValueError(f"not a Hailstone folder (no scripts/): {home}")
    target = scripts / "qol"
    if target.is_symlink() or (target.exists() and not (target / "init.lua").is_file()):
        raise ValueError(f"refusing to replace {target}: it does not look like this add-on")
    if target.exists():
        shutil.rmtree(target)
    return target, package.stage_runtime(source, target)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--home", type=Path, default=DEFAULT_HOME,
                        help="Hailstone folder (default: $HAILSTONE_HOME or ~/Games/Hailstone)")
    args = parser.parse_args()
    try:
        target, staged = deploy(package.ROOT, args.home.expanduser())
    except (FileNotFoundError, ValueError) as exc:
        print(f"deploy: {exc}", file=sys.stderr)
        return 1
    print(f"{len(staged)} files copied to {target}")
    print("Reload in game: /lua stop qol, then /lua run qol")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
