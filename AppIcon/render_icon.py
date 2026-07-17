"""
Renders Cazzy's app icon — "Notebook & Flask" (an open notebook, a bubbling
flask resting on the cover, a grey paw print in the corner) — from the same
48x48-unit coordinates used in the original canvas/JS design mockup, so the
generated icon matches that design exactly rather than being redrawn by eye.

Technique: draw supersampled (8x) with PIL's normal anti-aliased primitives,
downsample to 48x48 with LANCZOS (mimicking a browser canvas's native-
resolution anti-aliased draw), then upscale to each target icon size with
NEAREST (mimicking image-rendering:pixelated) — so the blocky pixel-art look
is preserved at every size instead of turning smooth at 1024px.

Usage: python3 render_icon.py
Produces ./Cazzy.iconset/ (the 10 PNGs macOS expects) and ./Cazzy.icns
(via `iconutil`, if available) in this same directory.
"""
import os
import subprocess
from PIL import Image, ImageDraw

SS = 8  # supersample factor
NATIVE = 48
CANVAS = NATIVE * SS

INK = (43, 42, 40, 255)
FUR = (156, 148, 132, 255)
GLASS = (234, 246, 245, 255)
CREAM = (242, 233, 216, 255)
CORK = (201, 168, 118, 255)
TEAL = (58, 166, 160, 255)
TEAL_LIGHT = (191, 232, 228, 255)
DIVIDE = (201, 189, 160, 255)
SHINE = (245, 251, 251, 255)  # ~55% white blended over GLASS, precomputed
PAPER_BG = (246, 221, 224, 255)  # icon background (light pink) — macOS applies the corner mask itself

HERE = os.path.dirname(os.path.abspath(__file__))


def render():
    def s(v):
        return v * SS

    img = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rectangle([0, 0, CANVAS, CANVAS], fill=PAPER_BG)

    def rounded_rect(x, y, w, h, r, fill=None, outline=None, width=1):
        draw.rounded_rectangle(
            [s(x), s(y), s(x + w), s(y + h)], radius=s(r),
            fill=fill, outline=outline, width=max(1, int(width * SS))
        )

    def poly(points, fill=None, outline=None, width=1):
        pts = [(s(x), s(y)) for x, y in points]
        draw.polygon(pts, fill=fill)
        if outline and width:
            # polygon(outline=) always draws a 1px line, so retrace the
            # edges explicitly to get the requested stroke weight.
            draw.line(pts + [pts[0]], fill=outline, width=max(1, int(width * SS)), joint="curve")

    def ellipse(cx, cy, rx, ry, fill=None):
        draw.ellipse([s(cx - rx), s(cy - ry), s(cx + rx), s(cy + ry)], fill=fill)

    def circle(cx, cy, r, fill=None):
        ellipse(cx, cy, r, r, fill=fill)

    def line(x0, y0, x1, y1, fill, width=1):
        draw.line([(s(x0), s(y0)), (s(x1), s(y1))], fill=fill, width=max(1, int(width * SS)))

    def paw_print(cx, cy, color, scale=1.0):
        ellipse(cx, cy, 5 * scale, 3.4 * scale, fill=color)
        for dx, dy in [(-6, -5), (-2.5, -8), (2.5, -8), (6, -5)]:
            circle(cx + dx * scale, cy + dy * scale, 1.7 * scale, fill=color)

    # ---- Notebook ----
    rounded_rect(6, 26, 34, 18, 3, fill=CREAM, outline=INK, width=1.4)
    line(23, 27, 23, 43, DIVIDE, width=1)
    for y in (30, 34, 38, 42):
        circle(6, y, 1.1, fill=INK)

    # ---- Cork + flask ----
    cx = 23
    rounded_rect(cx - 4, 4, 8, 3, 1, fill=CORK, outline=INK, width=1.4)

    neck_half_w = 3
    draw.rectangle(
        [s(cx - neck_half_w), s(7), s(cx + neck_half_w), s(12)],
        fill=GLASS, outline=INK, width=max(1, int(1.4 * SS))
    )

    body_top, body_bottom, bottom_half_w = 12, 29, 8
    poly([(cx - neck_half_w, body_top), (cx + neck_half_w, body_top),
          (cx + bottom_half_w, body_bottom), (cx - bottom_half_w, body_bottom)],
         fill=GLASS, outline=INK, width=1.4)

    liquid_top_frac = 0.5
    liquid_top = body_top + (body_bottom - body_top) * liquid_top_frac
    frac = (liquid_top - body_top) / (body_bottom - body_top)
    liquid_half_w = neck_half_w + (bottom_half_w - neck_half_w) * frac
    poly([(cx - liquid_half_w, liquid_top), (cx + liquid_half_w, liquid_top),
          (cx + bottom_half_w, body_bottom), (cx - bottom_half_w, body_bottom)],
         fill=TEAL)

    line(cx - neck_half_w * 0.4, body_top + 2, cx - bottom_half_w * 0.55, body_bottom - 3, SHINE, width=1)
    circle(cx, 24, 1, fill=TEAL_LIGHT)

    # ---- Paw print (grey, 0.7 scale) ----
    paw_print(33, 38, FUR, scale=0.7)

    return img.resize((NATIVE, NATIVE), Image.LANCZOS)


def write_iconset(native_img, out_dir):
    sizes = {
        "icon_16x16.png": 16,
        "icon_16x16@2x.png": 32,
        "icon_32x32.png": 32,
        "icon_32x32@2x.png": 64,
        "icon_128x128.png": 128,
        "icon_128x128@2x.png": 256,
        "icon_256x256.png": 256,
        "icon_256x256@2x.png": 512,
        "icon_512x512.png": 512,
        "icon_512x512@2x.png": 1024,
    }
    os.makedirs(out_dir, exist_ok=True)
    for filename, size in sizes.items():
        native_img.resize((size, size), Image.NEAREST).save(os.path.join(out_dir, filename))


if __name__ == "__main__":
    native_img = render()
    iconset_dir = os.path.join(HERE, "Cazzy.iconset")
    write_iconset(native_img, iconset_dir)
    native_img.resize((512, 512), Image.NEAREST).save(os.path.join(HERE, "icon_preview_512.png"))

    icns_path = os.path.join(HERE, "Cazzy.icns")
    try:
        subprocess.run(["iconutil", "-c", "icns", iconset_dir, "-o", icns_path], check=True)
        print("Wrote", icns_path)
    except (subprocess.CalledProcessError, FileNotFoundError) as e:
        print("iconutil unavailable or failed ({}); iconset PNGs are still in {}".format(e, iconset_dir))
