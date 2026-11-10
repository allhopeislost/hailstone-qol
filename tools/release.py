#!/usr/bin/env python3
"""Cut a QoL release: checks, package, sign, verify, commit, tag, push and publish on GitHub.

    python3 tools/release.py 0.2.7 --change "What changed" [--change ...]
    python3 tools/release.py 0.2.7 --maintenance --change "Moved files into core/"
    python3 tools/release.py 0.2.7 --change "..." --dry-run     # everything up to signing; nothing is changed

Only run it when asked. The signing key lives outside the repo: --key, $HAILSTONE_QOL_KEY or
~/.local/share/hailstone-qol/hailstone-qol-sign.key. hailstone_sign comes from --sign-tool, $HAILSTONE_SIGN or the
sibling Hailstone-dev/build.
"""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import package  # noqa: E402

REPO = "allhopeislost/hailstone-qol"
AUTHOR = "allhopeislost"
DESCRIPTION = "Quality of life improvements."
VERSION_RE = re.compile(r"^\d+\.\d+\.\d+$")


def parse_version(text: str) -> tuple[int, ...]:
    if not VERSION_RE.match(text):
        raise ValueError(f"version must look like 1.2.3, got {text!r}")
    return tuple(int(part) for part in text.split("."))


def bump_package_version(source: str, version: str) -> str:
    """Return package.py's text with its VERSION constant set to `version`."""
    new, count = re.subn(r'^VERSION = "[^"]*"$', f'VERSION = "{version}"', source, count=1, flags=re.MULTILINE)
    if count != 1:
        raise ValueError("no VERSION constant found in tools/package.py")
    return new


def make_notes(changes: list[str], maintenance: bool) -> str:
    """Release notes as markdown: a heading and one bullet per change."""
    if not changes:
        raise ValueError("give at least one --change")
    lines = ["## Maintenance release" if maintenance else "## Changes", ""]
    if maintenance:
        lines += ["No new features.", ""]
    lines += [f"- {change.strip()}" for change in changes if change.strip()]
    return "\n".join(lines) + "\n"


def run(command: list[str], **kwargs) -> subprocess.CompletedProcess:
    return subprocess.run(command, check=True, text=True, cwd=ROOT, **kwargs)


def find_tool(explicit: str | None, env: str, fallback: Path, what: str) -> Path:
    for candidate in (explicit, os.environ.get(env), str(fallback)):
        if candidate and Path(candidate).expanduser().is_file():
            return Path(candidate).expanduser().resolve()
    raise FileNotFoundError(f"{what} not found; pass it or set ${env}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("version")
    parser.add_argument("--change", action="append", default=[], help="a release-note bullet (repeatable)")
    parser.add_argument("--maintenance", action="store_true", help='headed "Maintenance release"')
    parser.add_argument("--message", help="commit message (default: Release QoL <version>)")
    parser.add_argument("--dry-run", action="store_true", help="build, sign and verify in a temp folder, then stop")
    parser.add_argument("--key", help="secret signing key file")
    parser.add_argument("--sign-tool", help="path to hailstone_sign")
    args = parser.parse_args()

    try:
        version = args.version
        new = parse_version(version)
        current = parse_version(package.VERSION)
        if new <= current:
            raise ValueError(f"{version} is not newer than the current {package.VERSION}")
        tag = f"v{version}"
        notes = make_notes(args.change, args.maintenance)
        key = find_tool(args.key, "HAILSTONE_QOL_KEY",
                        Path.home() / ".local/share/hailstone-qol/hailstone-qol-sign.key", "signing key")
        sign = find_tool(args.sign_tool, "HAILSTONE_SIGN",
                         ROOT.parents[1] / "Hailstone-dev" / "build" / "hailstone_sign", "hailstone_sign")

        if not args.dry_run:
            if run(["git", "rev-parse", "--abbrev-ref", "HEAD"], capture_output=True).stdout.strip() != "main":
                raise ValueError("not on the main branch")
            if run(["git", "tag", "--list", tag], capture_output=True).stdout.strip():
                raise ValueError(f"tag {tag} already exists")

        print("== checks")
        run([str(ROOT / "tools" / "check.sh")])

        out = Path(tempfile.mkdtemp(prefix="qol-release-"))
        try:
            print("== package")
            run([sys.executable, str(ROOT / "tools" / "package.py"), "--out", str(out), "--version", version,
                 "--author", AUTHOR, "--description", DESCRIPTION,
                 "--notes", f"https://github.com/{REPO}/releases/tag/{tag}"], capture_output=True)
            manifest, zipfile = out / "hailstone-addon.txt", out / f"qol-{version}.zip"
            print("== sign and verify")
            run([str(sign), "sign", str(key), str(manifest)], capture_output=True)
            public = run([str(sign), "public", str(key)], capture_output=True).stdout.strip()
            run([str(sign), "verify", public, str(manifest)], capture_output=True)
            print(manifest.read_text(encoding="utf-8"))
            print(notes)
            if args.dry_run:
                print(f"dry run ok: {zipfile.name}; nothing in the repository was changed")
                return 0

            print("== commit, tag, push")
            source = ROOT / "tools" / "package.py"
            source.write_text(bump_package_version(source.read_text(encoding="utf-8"), version), encoding="utf-8")
            shutil.copyfile(manifest, ROOT / "hailstone-addon.txt")
            run(["git", "add", "-A"])
            run(["git", "status", "--short"])
            run(["git", "commit", "-q", "-m", args.message or f"Release QoL {version}"])
            run(["git", "tag", tag])
            run(["git", "push", "-q", "origin", "main", tag])

            print("== publish")
            notes_file = out / "notes.md"
            notes_file.write_text(notes, encoding="utf-8")
            run(["gh", "release", "create", tag, str(zipfile), str(manifest), "--repo", REPO,
                 "--title", f"QoL {version}", "--notes-file", str(notes_file)])

            url = f"https://github.com/{REPO}/releases/download/{tag}/hailstone-addon.txt"
            with urllib.request.urlopen(url) as response:
                same = response.read().decode("utf-8") == (ROOT / "hailstone-addon.txt").read_text(encoding="utf-8")
            print("manifest on GitHub matches the repo" if same else "WARNING: manifest on GitHub differs from the repo")
            return 0 if same else 1
        finally:
            shutil.rmtree(out, ignore_errors=True)
    except (ValueError, FileNotFoundError, subprocess.CalledProcessError, OSError) as exc:
        detail = getattr(exc, "stderr", None) or getattr(exc, "stdout", None) or ""
        print(f"release: {exc}\n{detail}".rstrip(), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
