#!/usr/bin/env python3
"""Generate original hand-ink system icons as SVG files.

The shapes are intentionally simple, readable at small sizes and built from our own
Trama visual language. They are not traced from any reference game.
"""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "icons" / "system"

STYLE = '''<g fill="none" stroke="#28241D" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round">{body}</g>'''

ICONS = {
    "health": '<path d="M32 53 C13 41 8 24 18 16 C25 10 31 14 32 21 C33 14 40 10 47 16 C57 24 51 41 32 53 Z"/>',
    "vigor": '<path d="M12 40 C18 17 36 9 52 13 C39 19 42 31 29 34 C21 36 17 42 16 51"/><path d="M17 44 C25 34 34 27 46 22"/>',
    "posture": '<path d="M15 13 L49 13 L45 40 L32 53 L19 40 Z"/><path d="M23 21 L41 21 M22 29 L42 29 M25 37 L39 37"/>',
    "guard": '<path d="M32 8 L52 16 V30 C52 43 44 52 32 57 C20 52 12 43 12 30 V16 Z"/><path d="M21 31 L28 38 L44 22"/>',
    "attack": '<path d="M12 50 L48 14 M40 12 L52 12 L52 24 M14 42 L22 50 M10 54 L18 46"/><path d="M18 54 L10 46"/>',
    "precision": '<circle cx="32" cy="32" r="18"/><circle cx="32" cy="32" r="8"/><path d="M32 6 V17 M32 47 V58 M6 32 H17 M47 32 H58"/>',
    "distance": '<path d="M10 32 H54 M10 32 L18 24 M10 32 L18 40 M54 32 L46 24 M54 32 L46 40"/><circle cx="32" cy="32" r="4"/>',
    "movement": '<path d="M13 43 C21 39 23 28 30 25 C37 22 42 29 51 21"/><path d="M44 18 L52 21 L49 29"/><path d="M16 50 L22 47 M10 46 L15 44"/>',
    "inventory": '<rect x="13" y="20" width="38" height="32" rx="5"/><path d="M23 20 C23 11 41 11 41 20 M23 31 H41 M32 27 V35"/>',
    "character": '<circle cx="32" cy="20" r="9"/><path d="M15 55 C16 40 22 33 32 33 C42 33 48 40 49 55"/><path d="M24 40 L32 47 L40 40"/>',
    "journal": '<path d="M13 12 C22 9 28 11 32 16 V54 C27 49 21 48 13 50 Z"/><path d="M51 12 C42 9 36 11 32 16 V54 C37 49 43 48 51 50 Z"/>',
    "map": '<path d="M10 15 L25 10 L39 15 L54 10 V49 L39 54 L25 49 L10 54 Z"/><path d="M25 10 V49 M39 15 V54"/><path d="M17 25 C23 18 30 31 36 23 C42 16 45 28 50 21"/>',
    "mark": '<path d="M32 8 L39 23 L56 26 L44 38 L47 55 L32 47 L17 55 L20 38 L8 26 L25 23 Z"/><circle cx="32" cy="32" r="5"/>',
    "debt": '<path d="M14 16 H49 L43 50 H20 Z"/><path d="M22 25 H40 M21 33 H38 M20 41 H32"/><path d="M47 11 L53 17 M53 11 L47 17"/>',
    "echo": '<path d="M18 16 C7 25 7 39 18 48"/><path d="M26 20 C17 27 17 37 26 44"/><path d="M34 24 C28 29 28 35 34 40"/><circle cx="43" cy="32" r="7"/>',
    "thread": '<path d="M8 18 C21 7 27 29 39 18 C50 8 57 19 50 29 C43 39 29 24 20 37 C14 45 20 55 31 52 C43 49 39 37 56 43"/><circle cx="8" cy="18" r="2"/><circle cx="56" cy="43" r="2"/>',
    "route": '<circle cx="13" cy="47" r="5"/><circle cx="51" cy="16" r="5"/><path d="M17 44 C27 38 21 27 33 25 C42 23 41 17 46 16"/><path d="M30 21 L34 25 L31 30"/>',
    "consequence": '<path d="M10 17 H28 L34 25 H54 M54 25 L47 18 M54 25 L47 32"/><path d="M10 47 H28 L34 39 H54 M54 39 L47 32 M54 39 L47 46"/>',
    "item_weapon": '<path d="M15 50 L47 18 M40 12 L52 12 L52 24 M12 43 L21 52 M10 54 L18 46"/>',
    "item_armor": '<path d="M20 13 L29 9 H35 L44 13 L54 24 L46 31 V55 H18 V31 L10 24 Z"/><path d="M26 15 C27 23 37 23 38 15"/>',
    "item_tool": '<path d="M17 50 L42 25"/><path d="M34 13 C42 8 51 15 49 23 L42 19 L36 25 L40 31 C32 33 25 25 29 18 Z"/><path d="M13 54 L21 46"/>',
    "item_talisman": '<circle cx="32" cy="34" r="15"/><path d="M32 19 V8 M27 8 H37 M23 34 H41 M32 25 V43"/>',
    "item_consumable": '<path d="M25 9 H39 M27 9 V19 C20 24 17 33 19 45 C20 53 44 53 45 45 C47 33 44 24 37 19 V9"/><path d="M22 37 H42"/>',
    "item_key": '<circle cx="21" cy="24" r="10"/><path d="M28 31 L51 54 M40 43 L46 37 M46 49 L52 43"/>',
    "currency": '<circle cx="32" cy="32" r="22"/><path d="M23 25 C29 17 43 22 41 29 C39 36 24 29 23 38 C22 46 38 49 43 39 M32 14 V50"/>',
    "essence": '<path d="M32 8 L49 20 L43 47 L32 56 L21 47 L15 20 Z"/><path d="M32 8 L32 56 M15 20 L49 20 M21 47 L43 47"/>',
    "provisions": '<path d="M13 25 C18 13 30 11 37 19 C45 13 54 18 52 28 C50 39 40 49 28 53 C17 48 9 37 13 25 Z"/><path d="M36 19 C36 12 40 8 47 9"/>',
    "load": '<path d="M17 25 H47 L52 54 H12 Z"/><path d="M23 25 C23 12 41 12 41 25"/><path d="M23 39 H41"/>',
    "merchant": '<path d="M12 20 H52 L47 32 H17 Z"/><path d="M19 32 V53 H45 V32 M26 53 V42 H38 V53"/><path d="M18 20 L22 12 H42 L46 20"/>',
    "boss": '<path d="M13 49 C13 31 18 19 32 10 C46 19 51 31 51 49"/><path d="M20 22 L11 14 M44 22 L53 14"/><path d="M23 38 L28 34 M41 38 L36 34 M27 47 H37"/>',
    "elite": '<path d="M32 7 L39 22 L55 24 L43 35 L47 52 L32 44 L17 52 L21 35 L9 24 L25 22 Z"/><path d="M24 32 L30 38 L42 25"/>',
    "warning": '<path d="M32 8 L57 54 H7 Z"/><path d="M32 23 V39 M32 47 V48"/>',
}


def svg(body: str) -> str:
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  {STYLE.format(body=body)}
</svg>\n'''


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, body in ICONS.items():
        (OUT / f"{name}.svg").write_text(svg(body), encoding="utf-8")
    print(f"generated {len(ICONS)} original system icons in {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
