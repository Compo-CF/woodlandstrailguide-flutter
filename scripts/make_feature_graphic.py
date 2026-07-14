"""
Builds the Play Store feature graphic (1024x500) from a real map
screenshot plus a text overlay. Not part of the app build -- a one-off
asset generator, kept here so the process is reproducible next time a
screenshot needs to be swapped in.

Usage:
    python scripts/make_feature_graphic.py
"""
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageEnhance
import os

DESKTOP = r"C:\Users\anthony.compofelice\OneDrive - Centric Fiber Op. Co. LLC\Desktop"
SOURCE = os.path.join(DESKTOP, "Screenshot_1784039788.png")  # dense map overview
OUT = os.path.join(DESKTOP, "feature_graphic_1024x500.png")

W, H = 1024, 500

# Natural palette (matches lib/theme/natural_palette.dart)
FOREST = (46, 122, 69)      # 0xFF2E7A45
FOREST_DARK = (24, 66, 38)
ROUTE = (212, 106, 61)      # 0xFFD46A3D
CREAM = (250, 247, 239)     # 0xFFFAF7EF

FONT_BOLD = r"C:\Windows\Fonts\segoeuib.ttf"
FONT_REG = r"C:\Windows\Fonts\segoeui.ttf"


def draw_text_with_shadow(draw, xy, text, font, fill, shadow=(0, 0, 0, 160), offset=(0, 3)):
    x, y = xy
    draw.text((x + offset[0], y + offset[1]), text, font=font, fill=shadow)
    draw.text((x, y), text, font=font, fill=fill)


def main():
    src = Image.open(SOURCE).convert("RGB")
    sw, sh = src.size  # 1080 x 2400 (phone screenshot)

    target_ratio = W / H  # 2.048
    crop_h = int(sw / target_ratio)
    # Bias the crop toward the right/lower-density part of the cluster so
    # the left two-thirds (where the text sits) has fewer overlapping pins.
    top = int(sh * 0.30)
    top = max(0, min(top, sh - crop_h))
    crop = src.crop((0, top, sw, top + crop_h))
    crop = crop.resize((int(W * 1.15), int(H * 1.15)), Image.LANCZOS)
    # Shift crop right so busier pin cluster moves toward the right edge,
    # away from the text block on the left.
    extra_w = crop.size[0] - W
    crop = crop.crop((extra_w, int((crop.size[1] - H) / 2),
                       extra_w + W, int((crop.size[1] - H) / 2) + H))

    crop = ImageEnhance.Color(crop).enhance(1.1)

    # Soft depth-of-field: blur the whole background slightly so the
    # crisp white text reads as the sharpest thing in the frame.
    bg = crop.filter(ImageFilter.GaussianBlur(2.2))
    bg = ImageEnhance.Brightness(bg).enhance(0.85)

    canvas = bg.convert("RGBA")

    # Strong left-to-right dark gradient (forest-green tint, not flat
    # black) so the text block has real contrast without looking like a
    # generic dark overlay slapped on a screenshot.
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    grad = Image.new("L", (W, H), 0)
    gd = ImageDraw.Draw(grad)
    fade_w = int(W * 0.72)
    for x in range(fade_w):
        alpha = int(235 * (1 - (x / fade_w) ** 1.3))
        gd.line([(x, 0), (x, H)], fill=alpha)
    tint = Image.new("RGBA", (W, H), (*FOREST_DARK, 255))
    canvas = Image.composite(tint, canvas, grad)

    # Subtle bottom shadow strip for grounding / brand-color accent line.
    accent_h = 6
    accent = Image.new("RGBA", (W, accent_h), (*ROUTE, 255))
    canvas.paste(accent, (0, H - accent_h), accent)

    draw = ImageDraw.Draw(canvas)

    title_font = ImageFont.truetype(FONT_BOLD, 68)
    tagline_font = ImageFont.truetype(FONT_REG, 30)
    stat_font = ImageFont.truetype(FONT_BOLD, 25)

    pad_x = 48

    draw_text_with_shadow(draw, (pad_x, 128), "Woodlands", title_font, CREAM)
    draw_text_with_shadow(draw, (pad_x, 196), "Trail Guide", title_font, CREAM)

    draw_text_with_shadow(draw, (pad_x, 278), "Hike & Bike The Woodlands",
                           tagline_font, (232, 224, 204, 255), shadow=(0, 0, 0, 120))

    chip_y = 336
    stats = ["200+ mi of pathways", "3,400+ points of interest"]
    cx = pad_x
    for s in stats:
        bbox = draw.textbbox((0, 0), s, font=stat_font)
        tw = bbox[2] - bbox[0]
        th = bbox[3] - bbox[1]
        chip_pad_x, chip_pad_y = 16, 9
        chip_w = tw + chip_pad_x * 2
        chip_h = th + chip_pad_y * 2
        draw.rounded_rectangle(
            [cx, chip_y, cx + chip_w, chip_y + chip_h],
            radius=chip_h // 2,
            fill=(*FOREST, 255),
        )
        draw.text((cx + chip_pad_x, chip_y + chip_pad_y - bbox[1]), s,
                   font=stat_font, fill=CREAM)
        cx += chip_w + 16

    canvas = canvas.convert("RGB")
    canvas.save(OUT, "PNG")
    print(f"Saved: {OUT}  ({canvas.size[0]}x{canvas.size[1]})")


if __name__ == "__main__":
    main()
