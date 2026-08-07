#!/usr/bin/env python3
"""Generate the 48 base Mark glyphs for Veredas da Trama.

Six semantic families share a visual grammar but never the exact same geometry.
Final individual Marks can combine these bases with intensity ticks and domain accents.
"""
from __future__ import annotations

import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "icons" / "marks"

CATEGORIES = {
    "acao": ("#6B3F2C", 0),
    "vinculo": ("#45653A", 1),
    "conhecimento": ("#315B72", 2),
    "condicao": ("#7A382F", 3),
    "mundo": ("#7A622A", 4),
    "eco": ("#60447B", 5),
}


def polar(cx: float, cy: float, radius: float, angle: float) -> tuple[float, float]:
    r = math.radians(angle)
    return cx + math.cos(r) * radius, cy + math.sin(r) * radius


def path_points(points: list[tuple[float, float]], close: bool = False) -> str:
    if not points:
        return ""
    commands = [f"M{points[0][0]:.2f},{points[0][1]:.2f}"]
    commands.extend(f"L{x:.2f},{y:.2f}" for x, y in points[1:])
    if close:
        commands.append("Z")
    return " ".join(commands)


def glyph(category_index: int, variant: int, color: str) -> str:
    cx = cy = 48.0
    spokes = 4 + ((category_index + variant) % 5)
    rotation = category_index * 11 + variant * 7
    outer = 34 - (variant % 3) * 2
    inner = 10 + ((category_index * 3 + variant) % 8)

    lines = []
    for i in range(spokes):
        angle = rotation + i * (360.0 / spokes)
        x1, y1 = polar(cx, cy, inner, angle)
        x2, y2 = polar(cx, cy, outer, angle + (variant % 2) * 5)
        lines.append(f'<path d="M{x1:.2f},{y1:.2f} L{x2:.2f},{y2:.2f}"/>')

    ring_r = 20 + (category_index % 3) * 3
    gap_angle = rotation + variant * 13
    a1 = gap_angle + 28
    a2 = gap_angle + 332
    p1 = polar(cx, cy, ring_r, a1)
    p2 = polar(cx, cy, ring_r, a2)
    large_arc = 1
    ring = (
        f'<path d="M{p1[0]:.2f},{p1[1]:.2f} '
        f'A{ring_r},{ring_r} 0 {large_arc},1 {p2[0]:.2f},{p2[1]:.2f}"/>'
    )

    knot = []
    knot_points = 5 + (variant % 4)
    for i in range(knot_points):
        angle = rotation + i * (360.0 / knot_points)
        radius = 8 if i % 2 == 0 else 14
        knot.append(polar(cx, cy, radius, angle))
    knot_path = f'<path d="{path_points(knot, close=True)}"/>'

    # Category-specific signifier keeps semantics readable.
    signifiers = [
        '<path d="M33 55 L48 34 L63 55"/>',
        '<path d="M31 48 C37 35 42 34 48 45 C54 34 59 35 65 48"/>',
        '<path d="M31 48 C37 39 42 35 48 35 C54 35 59 39 65 48"/><circle cx="48" cy="42" r="3"/>',
        '<path d="M35 31 L61 61 M61 31 L35 61"/>',
        '<path d="M29 62 L48 28 L67 62 Z"/>',
        '<path d="M28 48 C34 31 44 26 48 48 C52 70 62 65 68 48"/>',
    ][category_index]

    body = "\n    ".join(lines + [ring, knot_path, signifiers])
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96" width="96" height="96">
  <g fill="none" stroke="{color}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
    {body}
  </g>
</svg>\n'''


def main() -> None:
    count = 0
    for category_index, (category, (color, _)) in enumerate(CATEGORIES.items()):
        folder = OUT / category
        folder.mkdir(parents=True, exist_ok=True)
        for variant in range(1, 9):
            (folder / f"{variant:02d}.svg").write_text(
                glyph(category_index, variant, color), encoding="utf-8"
            )
            count += 1
    print(f"generated {count} Mark base glyphs")


if __name__ == "__main__":
    main()
