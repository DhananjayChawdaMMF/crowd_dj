#!/usr/bin/env python3
"""Generates the CrowdDJ web icons (favicon, PWA, maskable, apple-touch).

Usage: python3 tool/generate_icons.py   (needs Pillow: pip install pillow)
Same look as the in-app logo: purple-to-blue gradient with equalizer bars.
"""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent / "web"
TOP, BOTTOM = (139, 92, 246), (59, 130, 246)  # primary -> secondary
BARS = [0.34, 0.62, 0.92, 0.56, 0.78, 0.46, 0.30]
N = 1024  # supersampled canvas


def gradient():
    img = Image.new("RGB", (N, N))
    px = img.load()
    for y in range(N):
        for x in range(N):
            t = (x + y) / (2 * (N - 1))
            px[x, y] = tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM))
    return img


def draw_bars(img, safe):
    """Draw the bars inside a centered square of `safe` * N pixels."""
    d = ImageDraw.Draw(img)
    box = N * safe
    left = (N - box) / 2
    n = len(BARS)
    slot = box / n
    bar_w = slot * 0.56
    for i, h in enumerate(BARS):
        bh = box * h
        cx = left + slot * (i + 0.5)
        top = (N - bh) / 2
        d.rounded_rectangle(
            [cx - bar_w / 2, top, cx + bar_w / 2, top + bh],
            radius=bar_w / 2,
            fill=(255, 255, 255),
        )


def icon(size, rounded, safe):
    img = gradient()
    draw_bars(img, safe)
    if rounded:
        mask = Image.new("L", (N, N), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, N - 1, N - 1], radius=int(N * 0.22), fill=255)
        out = Image.new("RGBA", (N, N), (0, 0, 0, 0))
        out.paste(img, (0, 0), mask)
        img = out
    return img.resize((size, size), Image.LANCZOS)


(ROOT / "icons").mkdir(exist_ok=True)
icon(192, True, 0.60).save(ROOT / "icons/Icon-192.png")
icon(512, True, 0.60).save(ROOT / "icons/Icon-512.png")
# Maskable icons are cropped to a circle/squircle by the OS: full bleed, content in the safe zone.
icon(192, False, 0.46).save(ROOT / "icons/Icon-maskable-192.png")
icon(512, False, 0.46).save(ROOT / "icons/Icon-maskable-512.png")
icon(180, False, 0.56).save(ROOT / "icons/apple-touch-icon.png")
icon(48, True, 0.66).save(ROOT / "favicon.png")
print("icons written to", ROOT)
