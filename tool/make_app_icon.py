"""Builds the Android launcher icon from icons/terminal_app_icon.jpg.

The source is a JPEG with a checkerboard baked into its "transparent" area, so
this first cuts the monitor out (flood-filling the light, colourless backdrop in
from the edges), then writes:

  * an adaptive icon (Android 8+): the monitor as the foreground layer on a
    solid phosphor-green background colour, kept inside the safe zone so no
    launcher mask (circle, squircle, teardrop) can clip it;
  * plain square icons for older Android.

Run from the repo root (needs Pillow: pip install pillow):
    python tool/make_app_icon.py
"""

import os
from collections import deque

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, 'icons', 'terminal_app_icon.jpg')
RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')

# Phosphor green: the default theme's colour and the glow on the monitor's
# screen, so the icon and the launcher agree, and the dark bezel stands out.
BACKGROUND = (0x2E, 0xE6, 0x6B)

# Adaptive icons are drawn on a 108dp canvas; only the middle 72dp circle is
# reliably visible, and 66dp is the guaranteed-safe circle. A square's corner
# is 1.41x its half width from the centre, so a monitor 52dp wide has its
# (rounded) corners just inside the visible circle.
MONITOR_DP = 52

DENSITIES = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0}


def cut_out_monitor(image):
    image = image.convert('RGB')
    w, h = image.size
    px = image.load()

    def is_backdrop(c):
        r, g, b = c
        return min(r, g, b) >= 205 and max(r, g, b) - min(r, g, b) <= 22

    seen = bytearray(w * h)
    queue = deque()
    for x in range(w):
        queue.extend(((x, 0), (x, h - 1)))
    for y in range(h):
        queue.extend(((0, y), (w - 1, y)))
    while queue:
        x, y = queue.popleft()
        if x < 0 or y < 0 or x >= w or y >= h or seen[y * w + x]:
            continue
        if not is_backdrop(px[x, y]):
            continue
        seen[y * w + x] = 1
        queue.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))

    mask = Image.new('L', (w, h), 0)
    mp = mask.load()
    for y in range(h):
        for x in range(w):
            if not seen[y * w + x]:
                mp[x, y] = 255
    rgba = image.convert('RGBA')
    rgba.putalpha(mask)
    return rgba.crop(mask.getbbox())


def fitted(monitor, width):
    scale = width / monitor.width
    return monitor.resize(
        (round(monitor.width * scale), round(monitor.height * scale)),
        Image.LANCZOS,
    )


def centred(layer, size, canvas):
    canvas.alpha_composite(
        layer, ((size - layer.width) // 2, (size - layer.height) // 2)
    )
    return canvas


def save(image, folder, name):
    path = os.path.join(RES, folder)
    os.makedirs(path, exist_ok=True)
    image.save(os.path.join(path, name), optimize=True)


def main():
    monitor = cut_out_monitor(Image.open(SOURCE))

    for name, density in DENSITIES.items():
        # Adaptive foreground: 108dp, monitor only, transparent around it.
        size = round(108 * density)
        foreground = centred(
            fitted(monitor, round(MONITOR_DP * density)),
            size,
            Image.new('RGBA', (size, size), (0, 0, 0, 0)),
        )
        save(foreground, f'mipmap-{name}', 'ic_launcher_foreground.png')

        # Legacy icon: 48dp rounded square with the monitor filling most of it.
        size = round(48 * density)
        legacy = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        square = Image.new('L', (size * 4, size * 4), 0)
        ImageDraw.Draw(square).rounded_rectangle(
            (0, 0, size * 4 - 1, size * 4 - 1), radius=size * 4 * 0.22, fill=255
        )
        square = square.resize((size, size), Image.LANCZOS)
        colour = Image.new('RGBA', (size, size), BACKGROUND + (255,))
        legacy.paste(colour, (0, 0), square)
        legacy = centred(fitted(monitor, round(size * 0.72)), size, legacy)
        save(legacy, f'mipmap-{name}', 'ic_launcher.png')

    os.makedirs(os.path.join(RES, 'mipmap-anydpi-v26'), exist_ok=True)
    with open(
        os.path.join(RES, 'mipmap-anydpi-v26', 'ic_launcher.xml'), 'w', newline='\n'
    ) as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <background android:drawable="@color/ic_launcher_background" />\n'
            '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
            '</adaptive-icon>\n'
        )
    with open(
        os.path.join(RES, 'values', 'ic_launcher_background.xml'), 'w', newline='\n'
    ) as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<resources>\n'
            '    <color name="ic_launcher_background">#%02X%02X%02X</color>\n'
            '</resources>\n' % BACKGROUND
        )
    print('icons written to', RES)


if __name__ == '__main__':
    main()
