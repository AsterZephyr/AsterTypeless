#!/usr/bin/env python3
"""Generate AsterTypeless App Icon at multiple sizes for macOS."""

import math
from PIL import Image, ImageDraw, ImageFilter

OUTPUT_DIR = "App/Resources/Assets.xcassets/AppIcon.appiconset"

# macOS icon sizes: (filename, pixel_size)
SIZES = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]


def lerp_color(c1, c2, t):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))


def gradient_color(t):
    """4-stop gradient: cyan -> blue -> violet -> fuchsia."""
    stops = [
        (0.00, (6, 182, 212)),    # cyan-400
        (0.35, (59, 130, 246)),   # blue-500
        (0.70, (139, 92, 246)),   # violet-500
        (1.00, (217, 70, 239)),   # fuchsia-500
    ]
    for i in range(len(stops) - 1):
        t0, c0 = stops[i]
        t1, c1 = stops[i + 1]
        if t <= t1:
            local_t = (t - t0) / (t1 - t0) if t1 > t0 else 0
            return lerp_color(c0, c1, local_t)
    return stops[-1][1]


def draw_squircle_mask(size, radius_pct=0.225):
    """Create a squircle (superellipse) mask."""
    mask = Image.new("L", (size, size), 0)
    cx, cy = size / 2, size / 2
    r = size / 2
    n = 5  # superellipse exponent for iOS/macOS style
    for y in range(size):
        for x in range(size):
            dx = abs(x - cx) / r
            dy = abs(y - cy) / r
            if dx ** n + dy ** n <= 1.0:
                mask.putpixel((x, y), 255)
    return mask


def draw_icon(size):
    """Draw the full icon at the given pixel size."""
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    
    # Icon area with padding (icon is ~78% of canvas, matching 400/512)
    pad = int(size * 0.11)
    icon_size = size - 2 * pad
    
    # Create squircle mask
    mask = draw_squircle_mask(icon_size)
    
    # Background: white to light gray gradient (top to bottom)
    bg = Image.new("RGBA", (icon_size, icon_size), (255, 255, 255, 255))
    bg_draw = ImageDraw.Draw(bg)
    for y in range(icon_size):
        t = y / max(icon_size - 1, 1)
        r = int(255 - t * 14)  # 255 -> 241
        g = int(255 - t * 12)  # 255 -> 243
        b = int(255 - t * 9)   # 255 -> 246
        bg_draw.line([(0, y), (icon_size - 1, y)], fill=(r, g, b, 255))
    
    # Apply squircle mask to background
    bg.putalpha(mask)
    
    # Subtle glow behind waveform
    glow = Image.new("RGBA", (icon_size, icon_size), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_r = int(icon_size * 0.275)
    cx, cy = icon_size // 2, icon_size // 2
    for ring in range(glow_r, 0, -1):
        alpha = int(40 * (ring / glow_r))
        t = ring / glow_r
        color = lerp_color((6, 182, 212), (217, 70, 239), t * 0.5 + 0.25)
        glow_draw.ellipse(
            [cx - ring, cy - ring, cx + ring, cy + ring],
            fill=(*color, alpha)
        )
    glow = glow.filter(ImageFilter.GaussianBlur(radius=max(1, icon_size // 10)))
    glow_masked = Image.new("RGBA", (icon_size, icon_size), (0, 0, 0, 0))
    glow_masked.paste(glow, mask=mask)
    
    # Composite background + glow
    icon = Image.new("RGBA", (icon_size, icon_size), (0, 0, 0, 0))
    icon = Image.alpha_composite(icon, bg)
    icon = Image.alpha_composite(icon, glow_masked)
    
    # Draw waveform bars
    # 11 bars from the HTML design, normalized heights (out of 120 viewBox)
    bars_data = [
        # (x_center_ratio, height_ratio) derived from HTML SVG
        (10/120, 20/120),    # bar 1: h=20
        (20/120, 36/120),    # bar 2: h=36
        (30/120, 60/120),    # bar 3: h=60
        (40/120, 84/120),    # bar 4: h=84
        (50/120, 110/120),   # bar 5: h=110 (tallest)
        (60/120, 96/120),    # bar 6: h=96
        (70/120, 106/120),   # bar 7: h=106
        (80/120, 76/120),    # bar 8: h=76
        (90/120, 50/120),    # bar 9: h=50
        (100/120, 30/120),   # bar 10: h=30
        (110/120, 16/120),   # bar 11: h=16
    ]
    
    wave_layer = Image.new("RGBA", (icon_size, icon_size), (0, 0, 0, 0))
    wave_draw = ImageDraw.Draw(wave_layer)
    
    # Waveform area: centered, about 60% of icon size
    wave_area = int(icon_size * 0.55)
    wave_left = (icon_size - wave_area) // 2
    wave_top = (icon_size - wave_area) // 2
    bar_width = max(2, int(wave_area * 6 / 120))
    bar_spacing = wave_area / 11
    
    for i, (x_ratio, h_ratio) in enumerate(bars_data):
        bx = wave_left + int(i * bar_spacing + bar_spacing / 2) - bar_width // 2
        bh = max(2, int(wave_area * h_ratio))
        by = (icon_size - bh) // 2
        
        # Gradient color based on x position
        t = i / max(len(bars_data) - 1, 1)
        color = gradient_color(t)
        
        # Draw rounded rect (pill shape)
        radius = bar_width // 2
        wave_draw.rounded_rectangle(
            [bx, by, bx + bar_width, by + bh],
            radius=radius,
            fill=(*color, 230)
        )
    
    # Apply mask to wave layer
    wave_masked = Image.new("RGBA", (icon_size, icon_size), (0, 0, 0, 0))
    wave_masked.paste(wave_layer, mask=mask)
    icon = Image.alpha_composite(icon, wave_masked)
    
    # Top-left highlight overlay
    highlight = Image.new("RGBA", (icon_size, icon_size), (0, 0, 0, 0))
    h_draw = ImageDraw.Draw(highlight)
    for y in range(icon_size // 2):
        for x in range(icon_size // 2):
            dist = math.sqrt((x / (icon_size / 2)) ** 2 + (y / (icon_size / 2)) ** 2)
            if dist < 1.0:
                alpha = int(30 * (1 - dist))
                h_draw.point((x, y), fill=(255, 255, 255, alpha))
    highlight_masked = Image.new("RGBA", (icon_size, icon_size), (0, 0, 0, 0))
    highlight_masked.paste(highlight, mask=mask)
    icon = Image.alpha_composite(icon, highlight_masked)
    
    # Border: subtle white inner stroke
    border = Image.new("RGBA", (icon_size, icon_size), (0, 0, 0, 0))
    border_mask_outer = draw_squircle_mask(icon_size)
    inner_size = icon_size - 2
    border_mask_inner = draw_squircle_mask(inner_size)
    # Expand inner mask to match outer
    inner_padded = Image.new("L", (icon_size, icon_size), 0)
    inner_padded.paste(border_mask_inner, (1, 1))
    # Border = outer - inner
    border_pixels = Image.new("RGBA", (icon_size, icon_size), (255, 255, 255, 60))
    border_alpha = Image.new("L", (icon_size, icon_size), 0)
    for y in range(icon_size):
        for x in range(icon_size):
            outer_val = border_mask_outer.getpixel((x, y))
            inner_val = inner_padded.getpixel((x, y))
            if outer_val > 0 and inner_val == 0:
                border_alpha.putpixel((x, y), 60)
    border_pixels.putalpha(border_alpha)
    icon = Image.alpha_composite(icon, border_pixels)
    
    # Place icon on canvas with padding
    canvas.paste(icon, (pad, pad), icon)
    
    # Drop shadow
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow_icon = Image.new("RGBA", (icon_size, icon_size), (0, 0, 0, 40))
    shadow_icon.putalpha(Image.fromarray(
        __import__('numpy').array(mask) * 40 // 255
    ) if False else mask)
    # Simple approach: paste darkened version offset down
    shadow_offset = max(1, size // 64)
    shadow.paste(shadow_icon, (pad, pad + shadow_offset), shadow_icon)
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=max(1, size // 32)))
    
    final = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    final = Image.alpha_composite(final, shadow)
    final = Image.alpha_composite(final, canvas)
    
    return final


def main():
    import os
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    # Generate all sizes
    for filename, pixel_size in SIZES:
        print(f"Generating {filename} ({pixel_size}x{pixel_size})...")
        img = draw_icon(pixel_size)
        img.save(os.path.join(OUTPUT_DIR, filename), "PNG")
    
    # Write Contents.json
    images = []
    size_entries = [
        ("16x16", "1x", "icon_16x16.png"),
        ("16x16", "2x", "icon_16x16@2x.png"),
        ("32x32", "1x", "icon_32x32.png"),
        ("32x32", "2x", "icon_32x32@2x.png"),
        ("128x128", "1x", "icon_128x128.png"),
        ("128x128", "2x", "icon_128x128@2x.png"),
        ("256x256", "1x", "icon_256x256.png"),
        ("256x256", "2x", "icon_256x256@2x.png"),
        ("512x512", "1x", "icon_512x512.png"),
        ("512x512", "2x", "icon_512x512@2x.png"),
    ]
    for size, scale, fname in size_entries:
        images.append({
            "filename": fname,
            "idiom": "mac",
            "scale": scale,
            "size": size,
        })
    
    import json
    contents = {
        "images": images,
        "info": {
            "author": "xcode",
            "version": 1,
        }
    }
    with open(os.path.join(OUTPUT_DIR, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)
    
    print("Done! All icon sizes generated.")


if __name__ == "__main__":
    main()
