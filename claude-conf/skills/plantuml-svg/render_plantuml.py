#!/usr/bin/env python3
"""Render ```plantuml blocks of a markdown file to SVG via the public PlantUML server.

Usage: render_plantuml.py <file.md> [--out-dir DIR] [NAME ...]

Each block is named by its `@startuml <name>` line (fallback: <md stem>_<n>) and
written to <out-dir>/<name>.svg. If NAMEs are given, only those blocks are rendered.
Exit code is 1 if any download fails or any SVG contains a PlantUML syntax error.
"""

import argparse
import base64
import re
import subprocess
import sys
import zlib
from pathlib import Path

SERVER = "https://www.plantuml.com/plantuml/svg/"
STD = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
PUML = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_"


def encode(source: str) -> str:
    # Raw deflate (no zlib header), then base64 with PlantUML's alphabet.
    c = zlib.compressobj(9, zlib.DEFLATED, -15)
    data = c.compress(source.encode("utf-8")) + c.flush()
    return (
        base64.b64encode(data).decode().rstrip("=").translate(str.maketrans(STD, PUML))
    )


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("markdown", type=Path)
    ap.add_argument("--out-dir", type=Path, default=None)
    ap.add_argument("names", nargs="*")
    args = ap.parse_args()

    out_dir = args.out_dir or args.markdown.parent
    blocks = re.findall(r"```plantuml\n(.*?)```", args.markdown.read_text(), re.S)
    if not blocks:
        print(f"no ```plantuml blocks in {args.markdown}")
        return 1

    failed = False
    for i, block in enumerate(blocks, 1):
        m = re.match(r"\s*@startuml[ \t]+(\S+)", block)
        name = m.group(1) if m else f"{args.markdown.stem}_{i}"
        if args.names and name not in args.names:
            continue
        out = out_dir / f"{name}.svg"
        # GET with the encoded source; POST to the public server returns an empty body.
        r = subprocess.run(["curl", "-s", "-f", SERVER + encode(block), "-o", str(out)])
        svg = (
            out.read_text(errors="replace")
            if r.returncode == 0 and out.exists()
            else ""
        )
        status = "ok"
        if r.returncode != 0 or not svg:
            status = f"FAILED (curl exit {r.returncode})"
        elif "yntax error" in svg:
            status = "SYNTAX ERROR"
        failed |= status != "ok"
        print(f"{name}: {out} ({len(svg)} bytes) {status}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
