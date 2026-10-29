#!/usr/bin/env python3
"""ItamarOS public version cycle: .1 -> .5 -> .9 -> next major .1."""
from __future__ import annotations
import re
import sys

def next_version(version: str) -> str:
    value = version.strip()
    if not re.fullmatch(r"[0-9]+\.(?:1|5|9)", value):
        raise ValueError("Expected ItamarOS marketing version in the form MAJOR.1, .5 or .9")
    major_str, minor_str = value.split(".")
    major, minor = int(major_str), int(minor_str)
    if minor == 1:
        return f"{major}.5"
    if minor == 5:
        return f"{major}.9"
    return f"{major + 1}.1"

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 native/version.py 1.1", file=sys.stderr)
        raise SystemExit(2)
    print(next_version(sys.argv[1]))
