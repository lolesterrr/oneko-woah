"""Makes <sheet>-gaze.png for oneko.js-layout sheets: the idle frame with its
eyes nudged one pixel toward each of N, NE, E, SE, S, SW, W, NW (256x32).
The chaser shows these while sitting, so it watches the cursor.

Eyes are found automatically (small dark marks either side of the head's
middle, in the eye band). That only works for some sheets, so the script
refuses a sheet it can't handle; check the result by eye before adding it.

Usage (needs Pillow): python3 tools/makegaze.py Resources/oneko.png ...
"""
import sys
from collections import Counter
from PIL import Image

DIRS = [(0, -1), (1, -1), (1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1)]


def idle_frame(sheet):
    cell = sheet.width // 8
    f = sheet.crop((3 * cell, 3 * cell, 4 * cell, 4 * cell))
    return f if cell == 32 else f.resize((32, 32), Image.NEAREST)


def find_eyes(f):
    px = f.load()
    opaque = {(x, y) for x in range(32) for y in range(32) if px[x, y][3] > 0}
    top = min(y for _, y in opaque)
    bottom = max(y for _, y in opaque)

    def n4(x, y):
        return [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]

    interior = {p for p in opaque if all(q in opaque for q in n4(*p))}
    eye_rows = range(top + round((bottom - top) * 0.15), top + round((bottom - top) * 0.42) + 1)
    fill = Counter(px[p] for p in interior if p[1] in eye_rows).most_common(1)[0][0]

    def stands_out(c):
        return abs(sum(c[:3]) - sum(fill[:3])) > 120

    marks = {p for p in interior if p[1] in eye_rows and px[p] != fill and stands_out(px[p])}
    head = [x for x, y in opaque if y in eye_rows]
    middle = (min(head) + max(head)) / 2
    left = {p for p in marks if middle - 7 < p[0] < middle - 1}
    right = {p for p in marks if middle + 1 < p[0] < middle + 7}
    if not left or not right or len(left) > 8 or len(right) > 8:
        return None
    return fill, left | right, interior


def gaze_strip(path):
    f = idle_frame(Image.open(path).convert("RGBA"))
    found = find_eyes(f)
    if not found:
        raise SystemExit(f"{path}: couldn't find the eyes")
    fill, eyes, interior = found
    src = f.load()
    strip = Image.new("RGBA", (256, 32), (0, 0, 0, 0))
    for i, (dx, dy) in enumerate(DIRS):
        frame = f.copy()
        out = frame.load()
        for p in eyes:
            out[p] = fill
        for p in eyes:
            q = (p[0] + dx, p[1] + dy)
            if q not in interior:
                raise SystemExit(f"{path}: eyes would leave the face looking {dx},{dy}")
            out[q] = src[p]
        strip.alpha_composite(frame, (i * 32, 0))
    return strip


if __name__ == "__main__":
    for path in sys.argv[1:]:
        gaze_strip(path).save(path[:-4] + "-gaze.png")
        print("wrote", path[:-4] + "-gaze.png")
