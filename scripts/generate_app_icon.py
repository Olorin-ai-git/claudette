#!/usr/bin/env python3
"""Generate Claudette app icon matching Olorin ecosystem glassmorphic purple style.

Produces a 1024x1024 PNG with:
- Deep space purple background (#0D0D1A)
- Glassmorphic rounded rectangle with purple gradient border
- Purple glow/shadow effect
- White "C>" terminal prompt in monospaced bold
- Subtle radial gradient for depth
"""

import math
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

SIZE = 1024
CENTER = SIZE // 2

# Olorin ecosystem colors
BG_COLOR = (13, 13, 26)  # #0D0D1A - deep space purple
ACCENT = (168, 85, 247)  # #A855F7 - primary purple
ACCENT_LIGHT = (192, 132, 252)  # #C084FC - light purple
ACCENT_DARK = (126, 34, 206)  # #7E22CE - dark purple
GLASS_FILL = (255, 255, 255, 15)  # white at 6% opacity
GLASS_BORDER = (168, 85, 247, 102)  # purple at 40% opacity
GLOW_COLOR = (126, 34, 206, 64)  # purple glow at 25%


def draw_rounded_rect(draw, bbox, radius, fill=None, outline=None, width=1):
    """Draw a rounded rectangle."""
    x0, y0, x1, y1 = bbox
    r = radius

    if fill:
        draw.rectangle([x0 + r, y0, x1 - r, y1], fill=fill)
        draw.rectangle([x0, y0 + r, x1, y1 - r], fill=fill)
        draw.pieslice([x0, y0, x0 + 2 * r, y0 + 2 * r], 180, 270, fill=fill)
        draw.pieslice([x1 - 2 * r, y0, x1, y0 + 2 * r], 270, 360, fill=fill)
        draw.pieslice([x0, y1 - 2 * r, x0 + 2 * r, y1], 90, 180, fill=fill)
        draw.pieslice([x1 - 2 * r, y1 - 2 * r, x1, y1], 0, 90, fill=fill)

    if outline:
        draw.arc([x0, y0, x0 + 2 * r, y0 + 2 * r], 180, 270, fill=outline, width=width)
        draw.arc([x1 - 2 * r, y0, x1, y0 + 2 * r], 270, 360, fill=outline, width=width)
        draw.arc([x0, y1 - 2 * r, x0 + 2 * r, y1], 90, 180, fill=outline, width=width)
        draw.arc([x1 - 2 * r, y1 - 2 * r, x1, y1], 0, 90, fill=outline, width=width)
        draw.line([x0 + r, y0, x1 - r, y0], fill=outline, width=width)
        draw.line([x0 + r, y1, x1 - r, y1], fill=outline, width=width)
        draw.line([x0, y0 + r, x0, y1 - r], fill=outline, width=width)
        draw.line([x1, y0 + r, x1, y1 - r], fill=outline, width=width)


def create_radial_gradient(size, center, radius, color_center, color_edge):
    """Create a radial gradient image."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cx, cy = center

    for y in range(size):
        for x in range(size):
            dist = math.sqrt((x - cx) ** 2 + (y - cy) ** 2)
            t = min(dist / radius, 1.0)
            r = int(color_center[0] * (1 - t) + color_edge[0] * t)
            g = int(color_center[1] * (1 - t) + color_edge[1] * t)
            b = int(color_center[2] * (1 - t) + color_edge[2] * t)
            a = int(color_center[3] * (1 - t) + color_edge[3] * t)
            img.putpixel((x, y), (r, g, b, a))

    return img


def main():
    # Create base image
    img = Image.new("RGBA", (SIZE, SIZE), BG_COLOR + (255,))

    # Add subtle radial gradient for depth
    gradient = create_radial_gradient(
        SIZE,
        (CENTER, CENTER - 50),
        SIZE // 2,
        (ACCENT_DARK[0], ACCENT_DARK[1], ACCENT_DARK[2], 38),  # 15% opacity
        (0, 0, 0, 0),
    )
    img = Image.alpha_composite(img, gradient)

    # Create glow layer (blurred purple shape behind the card)
    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    card_margin = 140
    card_radius = 200
    draw_rounded_rect(
        glow_draw,
        [card_margin + 20, card_margin + 20, SIZE - card_margin - 20, SIZE - card_margin - 20],
        card_radius,
        fill=(ACCENT[0], ACCENT[1], ACCENT[2], 80),
    )
    glow = glow.filter(ImageFilter.GaussianBlur(radius=60))
    img = Image.alpha_composite(img, glow)

    # Draw glass card
    card = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    card_draw = ImageDraw.Draw(card)
    draw_rounded_rect(
        card_draw,
        [card_margin, card_margin, SIZE - card_margin, SIZE - card_margin],
        card_radius,
        fill=GLASS_FILL,
    )
    img = Image.alpha_composite(img, card)

    # Draw glass border with gradient effect
    border = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    border_draw = ImageDraw.Draw(border)
    border_width = 3
    draw_rounded_rect(
        border_draw,
        [card_margin, card_margin, SIZE - card_margin, SIZE - card_margin],
        card_radius,
        outline=GLASS_BORDER,
        width=border_width,
    )
    img = Image.alpha_composite(img, border)

    # Draw "C>" text
    text_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    text_draw = ImageDraw.Draw(text_layer)

    # Try to use SF Mono or Menlo, fall back to system monospaced
    font_size = 340
    font = None
    font_paths = [
        "/System/Library/Fonts/SFMono-Bold.otf",
        "/System/Library/Fonts/Supplemental/Menlo-Bold.ttf",
        "/Library/Fonts/SF-Mono-Bold.otf",
        "/System/Library/Fonts/Monaco.ttf",
        "/System/Library/Fonts/Menlo.ttc",
    ]

    for path in font_paths:
        try:
            font = ImageFont.truetype(path, font_size)
            break
        except (OSError, IOError):
            continue

    if font is None:
        font = ImageFont.load_default()

    text = "C>"
    bbox = text_draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    text_x = CENTER - text_width // 2 - bbox[0]
    text_y = CENTER - text_height // 2 - bbox[1]

    # Draw text with gradient: light purple at top to accent purple at bottom
    for y_offset in range(text_height + 20):
        t = y_offset / max(text_height, 1)
        r = int(ACCENT_LIGHT[0] * (1 - t) + ACCENT[0] * t)
        g = int(ACCENT_LIGHT[1] * (1 - t) + ACCENT[1] * t)
        b = int(ACCENT_LIGHT[2] * (1 - t) + ACCENT[2] * t)

        line_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        line_draw = ImageDraw.Draw(line_layer)
        line_draw.text((text_x, text_y), text, font=font, fill=(r, g, b, 255))

        mask = Image.new("L", (SIZE, SIZE), 0)
        mask_draw = ImageDraw.Draw(mask)
        y_pos = text_y + bbox[1] + y_offset
        mask_draw.rectangle([0, y_pos, SIZE, y_pos + 1], fill=255)

        text_layer.paste(line_layer, mask=mask)

    img = Image.alpha_composite(img, text_layer)

    # Save
    output_path = sys.argv[1] if len(sys.argv) > 1 else "AppIcon.png"
    img.save(output_path, "PNG")
    print(f"Icon saved to {output_path} ({SIZE}x{SIZE})")


if __name__ == "__main__":
    main()
