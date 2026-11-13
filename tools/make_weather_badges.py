#!/usr/bin/env python3
"""Generate Glasdock's weather badge icons (shared/images/weather/*.svg).

Each badge is a rounded square with a sky gradient for the condition and a
simple flat glyph on top (sun, moon, clouds, rain, snow, fog, lightning).
Only SVG Tiny 1.2 features are used (no masks/filters), because that is what
Qt's SVG renderer supports.

    python3 tools/make_weather_badges.py
"""
import math
import os

OUT = os.path.join(os.path.dirname(__file__), "..", "shared", "images", "weather")
S = 128          # canvas size
R = 30           # badge corner radius

# sky gradients (top, bottom) per condition, day and night
SKY = {
    "clear":   {"day": ("#5BB8FF", "#1F6FE5"), "night": ("#2E3F78", "#0F1633")},
    "partly":  {"day": ("#6CB6F2", "#2D73C9"), "night": ("#344473", "#141B38")},
    "cloudy":  {"day": ("#A3B3C6", "#64758C"), "night": ("#4E5A70", "#232A3A")},
    "fog":     {"day": ("#B9C3CE", "#7F8B99"), "night": ("#56606E", "#2A313C")},
    "drizzle": {"day": ("#7F9DC0", "#45658E"), "night": ("#3F5170", "#1C2638")},
    "rain":    {"day": ("#5F7FA8", "#2F4A70"), "night": ("#33435F", "#151D2E")},
    "freezing":{"day": ("#8FB4D6", "#4F7AA6"), "night": ("#3D5677", "#18243A")},
    "snow":    {"day": ("#A9C6E6", "#6F93C0"), "night": ("#475E80", "#1E2A40")},
    "storm":   {"day": ("#5A4C8A", "#261C4A"), "night": ("#3A2F63", "#140E2B")},
    "unknown": {"day": ("#9AA6B4", "#5E6A78"), "night": ("#4A5260", "#22272F")},
}

SUN = "#FFD24A"
SUN_CORE = "#FFE680"
MOON = "#F4E7B5"
CLOUD = "#FFFFFF"
CLOUD_BACK = "#DCE6F2"
RAIN = "#8ED0FF"
ICE = "#D8F1FF"
BOLT = "#FFD24A"


def badge(top, bottom, body):
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{S}" height="{S}" viewBox="0 0 {S} {S}">
  <defs>
    <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="{top}"/>
      <stop offset="1" stop-color="{bottom}"/>
    </linearGradient>
    <linearGradient id="shine" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.22"/>
      <stop offset="0.5" stop-color="#FFFFFF" stop-opacity="0"/>
    </linearGradient>
  </defs>
  <rect x="0" y="0" width="{S}" height="{S}" rx="{R}" ry="{R}" fill="url(#sky)"/>
  <rect x="0" y="0" width="{S}" height="{S}" rx="{R}" ry="{R}" fill="url(#shine)"/>
{body}
</svg>
'''


def sun(cx, cy, r, rays=True):
    out = []
    if rays:
        for i in range(8):
            a = i * math.pi / 4
            x1, y1 = cx + math.cos(a) * (r + 6), cy + math.sin(a) * (r + 6)
            x2, y2 = cx + math.cos(a) * (r + 15), cy + math.sin(a) * (r + 15)
            out.append(f'  <line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" '
                       f'stroke="{SUN}" stroke-width="6" stroke-linecap="round"/>')
    out.append(f'  <circle cx="{cx}" cy="{cy}" r="{r}" fill="{SUN}"/>')
    out.append(f'  <circle cx="{cx - r * 0.25:.1f}" cy="{cy - r * 0.25:.1f}" r="{r * 0.55:.1f}" fill="{SUN_CORE}" opacity="0.6"/>')
    return "\n".join(out)


def moon(cx, cy, r):
    """Crescent as one path: the outer circle minus an offset inner circle
    (intersection points computed here, since SVG Tiny has no masks)."""
    ox, oy = cx + r * 0.55, cy - r * 0.45     # inner circle centre
    ri = r * 0.85
    d = math.hypot(ox - cx, oy - cy)
    a = (r * r - ri * ri + d * d) / (2 * d)
    h = math.sqrt(max(0.0, r * r - a * a))
    px, py = cx + a * (ox - cx) / d, cy + a * (oy - cy) / d
    p1 = (px + h * (oy - cy) / d, py - h * (ox - cx) / d)
    p2 = (px - h * (oy - cy) / d, py + h * (ox - cx) / d)
    path = (f"M {p1[0]:.1f} {p1[1]:.1f} A {r} {r} 0 1 0 {p2[0]:.1f} {p2[1]:.1f} "
            f"A {ri:.1f} {ri:.1f} 0 0 1 {p1[0]:.1f} {p1[1]:.1f} Z")
    return f'  <path d="{path}" fill="{MOON}"/>'


def stars():
    pts = [(30, 30, 2.6), (98, 36, 2.0), (90, 92, 1.6), (40, 96, 1.8)]
    return "\n".join(f'  <circle cx="{x}" cy="{y}" r="{r}" fill="#FFFFFF" opacity="0.75"/>' for x, y, r in pts)


def cloud(cx, cy, w, fill=CLOUD, opacity=1.0):
    """Flat cloud from three bumps on a rounded base (same colour, overlapping)."""
    h = w * 0.36
    base = (f'  <rect x="{cx - w / 2:.1f}" y="{cy - h / 2:.1f}" width="{w:.1f}" height="{h:.1f}" '
            f'rx="{h / 2:.1f}" ry="{h / 2:.1f}" fill="{fill}" opacity="{opacity}"/>')
    bumps = [
        (cx - w * 0.20, cy - h * 0.45, w * 0.20),
        (cx + w * 0.08, cy - h * 0.70, w * 0.26),
        (cx + w * 0.30, cy - h * 0.20, w * 0.15),
    ]
    circles = "\n".join(f'  <circle cx="{x:.1f}" cy="{y:.1f}" r="{r:.1f}" fill="{fill}" opacity="{opacity}"/>'
                        for x, y, r in bumps)
    return circles + "\n" + base


def drops(xs, y, length, colour=RAIN):
    return "\n".join(f'  <line x1="{x}" y1="{y}" x2="{x - 5}" y2="{y + length}" stroke="{colour}" '
                     f'stroke-width="6" stroke-linecap="round"/>' for x in xs)


def flakes(points):
    out = []
    for x, y in points:
        for i in range(3):
            a = i * math.pi / 3
            dx, dy = math.cos(a) * 7, math.sin(a) * 7
            out.append(f'  <line x1="{x - dx:.1f}" y1="{y - dy:.1f}" x2="{x + dx:.1f}" y2="{y + dy:.1f}" '
                       f'stroke="#FFFFFF" stroke-width="3.5" stroke-linecap="round"/>')
    return "\n".join(out)


def glyph(kind, night):
    if kind == "clear":
        return (stars() + "\n" + moon(64, 64, 30)) if night else sun(64, 64, 24)
    if kind == "partly":
        sky = moon(50, 46, 22) if night else sun(48, 46, 18)
        return sky + "\n" + cloud(70, 80, 64)
    if kind == "cloudy":
        return cloud(52, 56, 52, CLOUD_BACK, 0.9) + "\n" + cloud(70, 76, 66)
    if kind == "fog":
        lines = [(28, 52, 72), (36, 68, 60), (24, 84, 76)]
        return "\n".join(f'  <line x1="{x}" y1="{y}" x2="{x + w}" y2="{y}" stroke="#FFFFFF" '
                         f'stroke-width="7" stroke-linecap="round" opacity="0.9"/>' for x, y, w in lines)
    if kind == "drizzle":
        return cloud(64, 56, 70) + "\n" + drops([48, 66, 84], 82, 10)
    if kind == "rain":
        return cloud(64, 52, 72) + "\n" + drops([42, 58, 74, 90], 76, 20)
    if kind == "freezing":
        return cloud(64, 52, 72) + "\n" + drops([48, 80], 76, 18) + "\n" + flakes([(64, 92)])
    if kind == "snow":
        return cloud(64, 50, 72) + "\n" + flakes([(44, 86), (64, 96), (84, 86)])
    if kind == "storm":
        bolt = "M 66 70 L 52 96 L 64 96 L 58 114 L 80 86 L 67 86 L 74 70 Z"
        return cloud(64, 52, 74, "#E3E7F2") + f'\n  <path d="{bolt}" fill="{BOLT}"/>'
    return f'  <text x="64" y="80" font-size="48" text-anchor="middle" fill="#FFFFFF">?</text>'


def main():
    os.makedirs(OUT, exist_ok=True)
    for kind, skies in SKY.items():
        for when in ("day", "night"):
            top, bottom = skies[when]
            svg = badge(top, bottom, glyph(kind, when == "night"))
            with open(os.path.join(OUT, f"{kind}-{when}.svg"), "w") as f:
                f.write(svg)
    print("wrote", len(SKY) * 2, "badges to", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
