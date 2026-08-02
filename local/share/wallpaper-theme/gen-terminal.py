#!/usr/bin/env python3
"""Generate alacritty's colour scheme from the current wallpaper.

Neither matugen's base16 output nor pywal's ANSI slots keep the six chromatic
slots distinguishable -- both order colours by frequency, so on a monochrome
wallpaper `red` and `green` come out the same blue. That breaks git diff, ls
and error highlighting.

So: surfaces and text come from matugen (keeping the terminal in step with the
bar), while the six chromatic slots stay pinned to their semantic hues and only
borrow the wallpaper's saturation/brightness character, nudged slightly toward
the accent hue for cohesion.

Usage: gen-terminal.py <matugen.json> <output.toml>
"""

import colorsys
import json
import sys

# Semantic hue anchors, in degrees.
ANCHORS = {
    "red": 2,
    "green": 125,
    "yellow": 45,
    "blue": 222,
    "magenta": 300,
    "cyan": 187,
}

# How far each anchor drifts toward the accent hue. Enough to feel of-a-piece,
# not enough to collapse the hues into each other.
HUE_PULL = 0.12


def hex_to_hsv(h):
    h = h.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return colorsys.rgb_to_hsv(r, g, b)


def hsv_to_hex(h, s, v):
    r, g, b = colorsys.hsv_to_rgb(h % 1.0, max(0, min(1, s)), max(0, min(1, v)))
    return "#{:02x}{:02x}{:02x}".format(*(round(c * 255) for c in (r, g, b)))


def pull_toward(anchor_deg, target_deg, amount):
    """Shift anchor toward target along the shorter way round the wheel."""
    delta = ((target_deg - anchor_deg + 180) % 360) - 180
    return (anchor_deg + delta * amount) % 360


def main():
    matugen_json, out_path = sys.argv[1], sys.argv[2]
    with open(matugen_json) as f:
        c = json.load(f)["colors"]

    def role(name):
        return c[name]["default"]["color"]

    accent_h, accent_s, accent_v = hex_to_hsv(role("primary"))
    accent_deg = accent_h * 360

    # Borrow the accent's character, but keep it inside a legible band --
    # a washed-out or near-black accent must not yield unreadable ANSI text.
    sat = max(0.42, min(0.78, 0.45 + accent_s * 0.40))
    val = max(0.74, min(0.93, accent_v))

    normal, bright = {}, {}
    for name, anchor in ANCHORS.items():
        deg = pull_toward(anchor, accent_deg, HUE_PULL)
        normal[name] = hsv_to_hex(deg / 360, sat, val)
        bright[name] = hsv_to_hex(deg / 360, sat * 0.88, min(1.0, val * 1.13))

    lines = [
        "# GENERATED from the current wallpaper -- do not edit by hand.",
        "# Regenerate with:  wallpaper [/path/to/image]",
        "",
        "[colors.primary]",
        f'background = "{role("surface")}"',
        f'foreground = "{role("on_surface")}"',
        "",
        "[colors.cursor]",
        f'text = "{role("on_primary")}"',
        f'cursor = "{role("primary")}"',
        "",
        "[colors.selection]",
        f'text = "{role("on_primary")}"',
        f'background = "{role("primary")}"',
        "",
        "[colors.normal]",
        f'black = "{role("surface_container_lowest")}"',
        *(f'{n} = "{normal[n]}"' for n in ANCHORS),
        f'white = "{role("on_surface_variant")}"',
        "",
        "[colors.bright]",
        f'black = "{role("outline_variant")}"',
        *(f'{n} = "{bright[n]}"' for n in ANCHORS),
        f'white = "{role("on_surface")}"',
        "",
    ]
    with open(out_path, "w") as f:
        f.write("\n".join(lines))


if __name__ == "__main__":
    main()
