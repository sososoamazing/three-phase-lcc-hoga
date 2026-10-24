#!/usr/bin/env python3
"""Verify the public package and regenerate SHA256SUMS.txt.

Checks:
  * relative Markdown links/images resolve;
  * relative HTML href/src resolve;
  * no leftover absolute paths / personal identifiers;
  * writes SHA256SUMS.txt.

Exit code 1 if any hard error is found.
"""
from __future__ import annotations

import hashlib
import re
import sys
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]
SKIP_DIRS = {".git", "__pycache__", ".pytest_cache"}
TEXT_SUFFIXES = {".md", ".html", ".txt", ".py", ".m", ".cff", ".json", ".yml", ".yaml"}
BAD_PATTERNS = [
    re.compile(r"[A-Za-z]:[/\\]codex_prj"),
    re.compile(r"C:[/\\]Users[/\\]"),
    re.compile(r"\bamazing\b"),
    re.compile(r"黄业超"),
]
LINK_RE_MD = re.compile(r"!?\[[^\]]*\]\(([^)\s]+)\)")
LINK_RE_HTML = re.compile(r'(?:href|src)="([^"]+)"')
SKIP_URL_PREFIXES = ("http://", "https://", "mailto:", "#", "data:", "javascript:")


def rel(p: Path) -> str:
    return p.relative_to(ROOT).as_posix()


def iter_files():
    for p in sorted(ROOT.rglob("*")):
        if not p.is_file():
            continue
        if any(part in SKIP_DIRS for part in p.parts):
            continue
        if p.name == "SHA256SUMS.txt":
            continue
        yield p


def check_target(src: Path, url: str) -> str | None:
    if url.startswith(SKIP_URL_PREFIXES) or url.startswith("//"):
        return None
    if url.startswith("/"):
        return f"root-absolute link is not portable: {url}"
    url = url.split("#", 1)[0].split("?", 1)[0]
    if not url:
        return None
    url = unquote(url)
    target = (src.parent / url).resolve()
    try:
        target.relative_to(ROOT.resolve())
    except ValueError:
        return f"link escapes repo: {url}"
    if not target.exists():
        return f"missing target: {url}"
    return None


def main() -> int:
    errors: list[str] = []
    warnings: list[str] = []
    counts = {"md": 0, "html": 0, "img": 0, "pdf": 0, "csv": 0, "m": 0, "slx": 0}
    for p in iter_files():
        counts["md"] += p.suffix.lower() == ".md"
        counts["html"] += p.suffix.lower() == ".html"
        counts["img"] += p.suffix.lower() in {".png", ".jpg", ".jpeg", ".svg"}
        counts["pdf"] += p.suffix.lower() == ".pdf"
        counts["csv"] += p.suffix.lower() == ".csv"
        counts["m"] += p.suffix.lower() == ".m"
        counts["slx"] += p.suffix.lower() == ".slx"

        if p.suffix.lower() in TEXT_SUFFIXES and p.name != "verify_package.py":
            try:
                text = p.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                warnings.append(f"non-utf8 text: {rel(p)}")
                continue
            for pat in BAD_PATTERNS:
                for m in pat.finditer(text):
                    line = text[: m.start()].count("\n") + 1
                    errors.append(f"bad pattern in {rel(p)}:{line}: {pat.pattern}")
            if p.suffix.lower() == ".md":
                for url in LINK_RE_MD.findall(text):
                    err = check_target(p, url)
                    if err:
                        errors.append(f"{rel(p)}: {err}")
            elif p.suffix.lower() == ".html":
                for url in LINK_RE_HTML.findall(text):
                    err = check_target(p, url)
                    if err:
                        errors.append(f"{rel(p)}: {err}")

    # Hash manifest.
    lines = []
    for p in iter_files():
        h = hashlib.sha256(p.read_bytes()).hexdigest()
        lines.append(f"{h}  {rel(p)}")
    (ROOT / "SHA256SUMS.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")

    print("Package summary")
    print(f"  root: {ROOT}")
    print(f"  files: {sum(1 for _ in iter_files())}")
    print(f"  md={counts['md']} html={counts['html']} png/svg={counts['img']} "
          f"pdf={counts['pdf']} csv={counts['csv']} m={counts['m']} slx={counts['slx']}")
    print(f"  total size: {sum(p.stat().st_size for p in iter_files()) / 1024 / 1024:.2f} MB")
    print(f"  SHA256SUMS.txt: {len(lines)} entries")

    if warnings:
        print("\nWarnings:")
        for w in warnings:
            print("  -", w)
    if errors:
        print(f"\nERRORS ({len(errors)}):")
        for e in errors[:80]:
            print("  -", e)
        if len(errors) > 80:
            print(f"  ... and {len(errors) - 80} more")
        return 1
    print("\nOK: no broken relative links, no bad patterns.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
