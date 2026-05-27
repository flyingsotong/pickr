#!/usr/bin/env python3
"""
Generate 3 Mac App Store screenshots for Pickr (1280×800 @2x = 2560×1600 for retina).
We'll render at 2560x1600 for retina quality, then also save 1280x800 versions.
"""

import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import math

BASE = "/Users/alansoon/Documents/Pickr/website/screenshots"
FONTS = "/Users/alansoon/Library/Application Support/Claude/local-agent-mode-sessions/skills-plugin/fe3f53a9-d1aa-40af-a7c2-487565580a5f/86f2cab2-5531-4b98-9eac-b0167a47e961/skills/canvas-design/canvas-fonts"

# ── Colors ────────────────────────────────────────────
BG       = (13, 13, 15)          # #0d0d0f
WHITE    = (240, 240, 245)
WHITE2   = (240, 240, 245, 153)  # 60% alpha
WHITE3   = (240, 240, 245, 89)   # 35% alpha
BLUE     = (0, 122, 255)
BLUE_DIM = (0, 122, 255, 38)
GREEN    = (48, 209, 88)

# ── Canvas size (2x for retina, Mac App Store accepts 2560x1600) ──
W, H = 2560, 1600

def load_font(name, size):
    path = os.path.join(FONTS, name)
    return ImageFont.truetype(path, size)

def add_radial_glow(img, cx, cy, radius, color, intensity=0.55):
    """Add a soft radial glow behind the app window."""
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(glow)
    steps = 60
    for i in range(steps, 0, -1):
        r = int(radius * i / steps)
        alpha = int(intensity * 255 * (1 - (i / steps) ** 1.4))
        draw.ellipse(
            [cx - r, cy - r, cx + r, cy + r],
            fill=(*color, alpha)
        )
    glow = glow.filter(ImageFilter.GaussianBlur(radius * 0.25))
    img.paste(glow, mask=glow)

def add_noise(img, amount=3):
    """Very subtle noise for premium feel."""
    import random
    px = img.load()
    for x in range(0, img.width, 2):
        for y in range(0, img.height, 2):
            n = random.randint(-amount, amount)
            r, g, b, a = px[x, y]
            px[x, y] = (
                max(0, min(255, r + n)),
                max(0, min(255, g + n)),
                max(0, min(255, b + n)),
                a
            )

def draw_rounded_rect(draw, box, radius, fill=None, outline=None, width=1):
    """Draw a rounded rectangle."""
    x0, y0, x1, y1 = box
    draw.rounded_rectangle([x0, y0, x1, y1], radius=radius, fill=fill, outline=outline, width=width)

def paste_with_shadow(base, overlay, pos, shadow_blur=40, shadow_opacity=160):
    """Paste overlay onto base with a drop shadow."""
    ox, oy = pos
    shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    shadow_layer = Image.new("RGBA", overlay.size, (0, 0, 0, shadow_opacity))
    shadow.paste(shadow_layer, (ox + 20, oy + 30))
    shadow = shadow.filter(ImageFilter.GaussianBlur(shadow_blur))
    base.paste(shadow, mask=shadow)
    base.paste(overlay, pos, mask=overlay)

def make_canvas():
    return Image.new("RGBA", (W, H), (*BG, 255))

# ── Load & prep app screenshot ─────────────────────────
app_img_orig = Image.open(os.path.join(BASE, "pickr-popover.png")).convert("RGBA")

def scale_app(factor=1.0):
    w = int(app_img_orig.width * factor)
    h = int(app_img_orig.height * factor)
    return app_img_orig.resize((w, h), Image.LANCZOS)

# ─────────────────────────────────────────────────────────────────────────────
# SCREENSHOT 1 — "Your mics, one click away."
# ─────────────────────────────────────────────────────────────────────────────
def make_screenshot_1():
    img = make_canvas()
    draw = ImageDraw.Draw(img)

    # App image — right half, vertically centered, scale to ~680px tall
    scale = 680 / app_img_orig.height * 2  # 2x for retina canvas
    app = scale_app(scale)
    app_x = W - app.width - 240
    app_y = (H - app.height) // 2 - 20

    # Radial glow behind app
    add_radial_glow(img, app_x + app.width // 2, app_y + app.height // 2,
                    900, BLUE, intensity=0.18)

    # Shadow + paste
    paste_with_shadow(img, app, (app_x, app_y), shadow_blur=80, shadow_opacity=180)

    # ── Typography ────────────────────────────────────
    font_h1 = load_font("BricolageGrotesque-Bold.ttf", 148)
    font_h2 = load_font("BricolageGrotesque-Bold.ttf", 148)
    font_sub = load_font("InstrumentSans-Regular.ttf", 52)
    font_label = load_font("InstrumentSans-Regular.ttf", 38)

    text_x = 160
    line1_y = H // 2 - 220

    # "Your mics,"
    draw.text((text_x, line1_y), "Your mics,", font=font_h1, fill=(*WHITE, 255))
    bbox1 = draw.textbbox((0, 0), "Your mics,", font=font_h1)
    line1_h = bbox1[3] - bbox1[1]

    # "one click away." in blue
    draw.text((text_x, line1_y + line1_h + 16), "one click away.", font=font_h2, fill=(*BLUE, 255))
    bbox2 = draw.textbbox((0, 0), "one click away.", font=font_h2)
    line2_h = bbox2[3] - bbox2[1]

    # Subheadline
    sub_y = line1_y + line1_h + 16 + line2_h + 52
    draw.text((text_x, sub_y), "Switch instantly from your menu bar.",
              font=font_sub, fill=(*WHITE, 110))

    # Thin separator line
    sep_y = sub_y + 96
    draw.line([(text_x, sep_y), (text_x + 200, sep_y)],
              fill=(*BLUE, 80), width=2)

    # Bottom-left Pickr label
    label_y = H - 130
    # Mic dot
    dot_r = 16
    draw.ellipse([text_x, label_y + 6, text_x + dot_r * 2, label_y + 6 + dot_r * 2],
                 fill=(*BLUE, 220))
    draw.text((text_x + dot_r * 2 + 18, label_y), "Pickr",
              font=font_label, fill=(*WHITE, 100))

    return img

# ─────────────────────────────────────────────────────────────────────────────
# SCREENSHOT 2 — "See what you're hearing."
# ─────────────────────────────────────────────────────────────────────────────
def make_screenshot_2():
    img = make_canvas()
    draw = ImageDraw.Draw(img)

    # App image — crop to show INPUT section prominently
    # The input section is roughly the top 55% of the popover
    scale = 700 / app_img_orig.height * 2
    app_full = scale_app(scale)

    # Crop to top 62% (INPUT section with level meter)
    crop_h = int(app_full.height * 0.62)
    app = app_full.crop((0, 0, app_full.width, crop_h))

    # Add a soft fade at the bottom of the crop
    fade = Image.new("RGBA", app.size, (0, 0, 0, 0))
    fade_draw = ImageDraw.Draw(fade)
    fade_start = int(crop_h * 0.72)
    for i in range(fade_start, crop_h):
        alpha = int(255 * ((i - fade_start) / (crop_h - fade_start)) ** 1.5)
        fade_draw.line([(0, i), (app.width, i)], fill=(13, 13, 15, alpha))
    app = Image.alpha_composite(app, fade)

    app_x = W - app.width - 220
    app_y = (H - app.height) // 2

    # Green glow behind INPUT/level section (upper portion)
    add_radial_glow(img, app_x + app.width // 2, app_y + int(app.height * 0.55),
                    700, GREEN, intensity=0.12)
    add_radial_glow(img, app_x + app.width // 2, app_y + app.height // 2,
                    900, BLUE, intensity=0.10)

    paste_with_shadow(img, app, (app_x, app_y), shadow_blur=80, shadow_opacity=160)

    # ── Callout pill: "Live meter" ─────────────────────
    font_pill = load_font("InstrumentSans-Bold.ttf", 40)
    pill_text = "Live meter"
    pill_bbox = draw.textbbox((0, 0), pill_text, font=font_pill)
    pill_w = pill_bbox[2] - pill_bbox[0] + 60
    pill_h = pill_bbox[3] - pill_bbox[1] + 30

    # Pixel-exact level bar position: sampled at (389, 195) in 560×626 original
    # scale = 700/626 * 2;  app is cropped but level bar at y=195 is well within crop
    level_bar_x = app_x + int(389 * scale)
    level_row_y = app_y + int(195 * scale)

    # Place pill in the lower-left zone, safely below the subheadline
    pill_x = 160
    pill_y = H - 220 - pill_h

    # Diagonal connector line from pill centre-right to the exact level bar
    line_start = (pill_x + pill_w + 8, pill_y + pill_h // 2)
    line_end   = (level_bar_x, level_row_y)
    draw.line([line_start, line_end], fill=(*BLUE, 80), width=2)
    # Small dot at the target end
    draw.ellipse([line_end[0]-6, line_end[1]-6, line_end[0]+6, line_end[1]+6],
                 fill=(*BLUE, 180))

    # Pill background
    pill_layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    pill_draw = ImageDraw.Draw(pill_layer)
    draw_rounded_rect(pill_draw, [pill_x, pill_y, pill_x + pill_w, pill_y + pill_h],
                      radius=pill_h // 2,
                      fill=(*BLUE, 230))
    img.alpha_composite(pill_layer)
    draw = ImageDraw.Draw(img)

    text_ox = pill_x + (pill_w - (pill_bbox[2] - pill_bbox[0])) // 2 - pill_bbox[0]
    text_oy = pill_y + (pill_h - (pill_bbox[3] - pill_bbox[1])) // 2 - pill_bbox[1]
    draw.text((text_ox, text_oy), pill_text, font=font_pill, fill=(255, 255, 255, 255))

    # ── Typography ────────────────────────────────────
    font_h1 = load_font("BricolageGrotesque-Bold.ttf", 140)
    font_sub = load_font("InstrumentSans-Regular.ttf", 52)

    text_x = 160
    h1_y = H // 2 - 180

    draw.text((text_x, h1_y), "See what", font=font_h1, fill=(*WHITE, 255))
    bb1 = draw.textbbox((0, 0), "See what", font=font_h1)
    h1_line = bb1[3] - bb1[1]

    draw.text((text_x, h1_y + h1_line + 12), "you're hearing.", font=font_h1, fill=(*WHITE, 255))
    bb2 = draw.textbbox((0, 0), "you're hearing.", font=font_h1)
    h2_line = bb2[3] - bb2[1]

    sub_y = h1_y + h1_line + 12 + h2_line + 52
    draw.text((text_x, sub_y), "Live input level meter, always visible.",
              font=font_sub, fill=(*WHITE, 110))

    return img

# ─────────────────────────────────────────────────────────────────────────────
# SCREENSHOT 3 — "Mute in an instant."
# ─────────────────────────────────────────────────────────────────────────────
def make_screenshot_3():
    img = make_canvas()
    draw = ImageDraw.Draw(img)

    # App image — slightly smaller, center-right
    scale = 600 / app_img_orig.height * 2
    app = scale_app(scale)
    app_x = W - app.width - 260
    app_y = (H - app.height) // 2

    # Subtle blue/purple glow
    add_radial_glow(img, app_x + app.width // 2, app_y + app.height // 2,
                    850, BLUE, intensity=0.15)

    paste_with_shadow(img, app, (app_x, app_y), shadow_blur=80, shadow_opacity=160)

    # ── Keyboard shortcut: three key caps "opt" "cmd" "M" ─
    font_key = load_font("GeistMono-Bold.ttf", 44)
    keys = ["opt", "cmd", "M"]
    key_padding_x = 28
    key_padding_y = 20
    key_gap = 10
    key_radius = 14

    # Measure each key
    key_sizes = []
    for k in keys:
        bb = draw.textbbox((0, 0), k, font=font_key)
        kw = (bb[2] - bb[0]) + key_padding_x * 2
        kh = (bb[3] - bb[1]) + key_padding_y * 2
        key_sizes.append((kw, kh, bb))

    total_badge_w = sum(s[0] for s in key_sizes) + key_gap * (len(keys) - 1)
    max_kh = max(s[1] for s in key_sizes)

    # Pixel-exact Mute row: icon center sampled at (81, 477) in 560×626 original
    # scale = 600/626 * 2
    mute_row_y  = app_y + int(477 * scale)
    mute_icon_x = app_x + int(81  * scale)
    group_x = app_x - total_badge_w - 80
    group_y = mute_row_y - max_kh // 2

    # Connector line: from badge right edge to the mute icon inside the app
    draw.line([(group_x + total_badge_w + 6, mute_row_y),
               (mute_icon_x, mute_row_y)],
              fill=(*WHITE, 55), width=2)
    # Small dot on the icon
    draw.ellipse([mute_icon_x - 6, mute_row_y - 6,
                  mute_icon_x + 6, mute_row_y + 6],
                 fill=(*WHITE, 100))

    # Draw each key cap
    badge_layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    badge_draw = ImageDraw.Draw(badge_layer)

    cx = group_x
    for i, (k, (kw, kh, bb)) in enumerate(zip(keys, key_sizes)):
        ky = group_y + (max_kh - kh) // 2
        draw_rounded_rect(badge_draw,
                          [cx, ky, cx + kw, ky + kh],
                          radius=key_radius,
                          fill=(38, 38, 46, 230))
        draw_rounded_rect(badge_draw,
                          [cx, ky, cx + kw, ky + kh],
                          radius=key_radius,
                          outline=(255, 255, 255, 40), width=2)
        # Text centre in key
        tx = cx + (kw - (bb[2] - bb[0])) // 2 - bb[0]
        ty = ky + (kh - (bb[3] - bb[1])) // 2 - bb[1]
        badge_draw.text((tx, ty), k, font=font_key, fill=(*WHITE, 220))
        cx += kw + key_gap

    img.alpha_composite(badge_layer)
    draw = ImageDraw.Draw(img)

    # ── Typography ────────────────────────────────────
    font_h1 = load_font("BricolageGrotesque-Bold.ttf", 148)
    font_sub = load_font("InstrumentSans-Regular.ttf", 52)

    text_x = 160
    h1_y = H // 2 - 200

    draw.text((text_x, h1_y), "Mute in", font=font_h1, fill=(*WHITE, 255))
    bb1 = draw.textbbox((0, 0), "Mute in", font=font_h1)
    h1_line = bb1[3] - bb1[1]

    draw.text((text_x, h1_y + h1_line + 12), "an instant.", font=font_h1, fill=(*BLUE, 255))
    bb2 = draw.textbbox((0, 0), "an instant.", font=font_h1)
    h2_line = bb2[3] - bb2[1]

    sub_y = h1_y + h1_line + 12 + h2_line + 52
    draw.text((text_x, sub_y), "Set a global shortcut. Mute anywhere.",
              font=font_sub, fill=(*WHITE, 110))

    return img

# ─────────────────────────────────────────────────────────────────────────────
# Render and save
# ─────────────────────────────────────────────────────────────────────────────
print("Rendering screenshot 1...")
s1 = make_screenshot_1()
out1 = os.path.join(BASE, "appstore-1.png")
s1.convert("RGB").save(out1, "PNG", optimize=True)
print(f"  Saved: {out1}  ({s1.size[0]}×{s1.size[1]})")

print("Rendering screenshot 2...")
s2 = make_screenshot_2()
out2 = os.path.join(BASE, "appstore-2.png")
s2.convert("RGB").save(out2, "PNG", optimize=True)
print(f"  Saved: {out2}  ({s2.size[0]}×{s2.size[1]})")

print("Rendering screenshot 3...")
s3 = make_screenshot_3()
out3 = os.path.join(BASE, "appstore-3.png")
s3.convert("RGB").save(out3, "PNG", optimize=True)
print(f"  Saved: {out3}  ({s3.size[0]}×{s3.size[1]})")

print("\nAll done.")
