"""Build the House Rules logo lockup and key art.

    python tools/art/build_key_art.py

The lettering is drawn here rather than generated, for the same reason the UI
kit's medallions leave their centres empty: generated type comes out malformed
and is not allowed in shipped art. Drawing it also means the logo can be rebuilt
at any size, and on a transparent background for the README.

The lockup is the slot-game shape: a heavy bevelled word with a dark keyline, a
gold face that runs bright at the top into deep amber at the foot, an extruded
side under it and a drop shadow, over a burgundy ribbon.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
FONT = ROOT / "assets/fonts/BarlowCondensed-SemiBold.ttf"
SOURCE = ROOT / "assets/source/layered_v2/keyart"
OUT = ROOT / "assets/production/ui/keyart"

KEYLINE = (46, 22, 6)
FACE_TOP = (255, 236, 150)
FACE_MID = (247, 196, 58)
FACE_BOT = (206, 124, 20)
SHEEN = (255, 252, 226)
EXTRUDE = (122, 64, 12)
RIBBON = (138, 20, 32)
RIBBON_DARK = (92, 10, 20)
RIBBON_EDGE = (214, 170, 84)


def _gradient(size: tuple[int, int]) -> Image.Image:
    """Bright at the top, deep amber at the foot, with a hot band across the middle."""
    width, height = size
    ramp = Image.new("RGB", (1, height))
    px = ramp.load()
    for y in range(height):
        t = y / max(height - 1, 1)
        if t < 0.52:
            k = t / 0.52
            colour = tuple(round(FACE_TOP[i] + (FACE_MID[i] - FACE_TOP[i]) * k) for i in range(3))
        else:
            k = (t - 0.52) / 0.48
            colour = tuple(round(FACE_MID[i] + (FACE_BOT[i] - FACE_MID[i]) * k) for i in range(3))
        px[0, y] = colour
    return ramp.resize(size, Image.BILINEAR)


def word(text: str, size: int, track: int = 18, keyline: int = 0, depth: int = 0) -> Image.Image:
    """One word of the lockup, on its own transparent layer."""
    font = ImageFont.truetype(str(FONT), size)
    keyline = keyline or max(10, size // 16)
    depth = depth or max(12, size // 13)
    probe = ImageDraw.Draw(Image.new("L", (8, 8)))
    widths = [probe.textlength(c, font=font) for c in text]
    total = sum(widths) + track * (len(text) - 1)
    box = font.getbbox(text)
    pad = keyline * 2 + depth + 30
    canvas = (int(total + pad * 2), int((box[3] - box[1]) + pad * 2))
    origin = (pad, pad - box[1])

    def draw_run(target: ImageDraw.ImageDraw, dx: float, dy: float, fill, stroke, width: int):
        x = origin[0] + dx
        for c, w in zip(text, widths):
            target.text((x, origin[1] + dy), c, font=font, fill=fill,
                        stroke_width=width, stroke_fill=stroke)
            x += w + track

    # The silhouette, used both as the extrusion and as the mask for the face.
    silhouette = Image.new("L", canvas, 0)
    draw_run(ImageDraw.Draw(silhouette), 0, 0, 255, 255, keyline)
    face_mask = Image.new("L", canvas, 0)
    draw_run(ImageDraw.Draw(face_mask), 0, 0, 255, 255, max(1, keyline // 3))

    layer = Image.new("RGBA", canvas, (0, 0, 0, 0))
    # Extruded side first, deepest at the back.
    for i in range(depth, 0, -1):
        shade = tuple(round(EXTRUDE[k] * (0.45 + 0.55 * (1 - i / depth))) for k in range(3))
        block = Image.new("RGBA", canvas, shade + (255,))
        layer.paste(block, (0, i), silhouette)
    # The dark keyline, then the gold face inside it.
    layer.paste(Image.new("RGBA", canvas, KEYLINE + (255,)), (0, 0), silhouette)
    gradient = _gradient(canvas).convert("RGBA")
    layer.paste(gradient, (0, 0), face_mask)
    # A sheen along the top of each letter, clipped back inside the face.
    sheen = Image.new("RGBA", canvas, (0, 0, 0, 0))
    sheen_mask = Image.new("L", canvas, 0)
    draw_run(ImageDraw.Draw(sheen_mask), 0, -size * 0.10, 255, 255, max(1, keyline // 3))
    sheen.paste(Image.new("RGBA", canvas, SHEEN + (150,)), (0, 0), sheen_mask)
    clipped = Image.new("RGBA", canvas, (0, 0, 0, 0))
    clipped.paste(sheen, (0, 0), face_mask)
    layer.alpha_composite(clipped)
    return layer.crop(layer.getbbox())


def ribbon(width: int, height: int) -> Image.Image:
    """A burgundy banner with swallow-tailed ends and a brass edge."""
    layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    notch = height // 2
    body = [(0, 0), (width, 0), (width - notch, height // 2), (width, height),
            (0, height), (notch, height // 2)]
    d.polygon(body, fill=RIBBON + (255,))
    d.polygon([(0, 0), (width, 0), (width, height // 3), (0, height // 3)],
              fill=tuple(round(c * 1.18) for c in RIBBON) + (255,))
    d.polygon([(0, int(height * 0.72)), (width, int(height * 0.72)), (width, height), (0, height)],
              fill=RIBBON_DARK + (255,))
    d.line(body + [body[0]], fill=RIBBON_EDGE + (255,), width=max(3, height // 22))
    return layer


def lockup(scale: float = 1.0) -> Image.Image:
    """HOUSE over RULES on a ribbon, as one transparent piece."""
    house = word("HOUSE", round(330 * scale), track=round(16 * scale))
    rules = word("RULES", round(228 * scale), track=round(26 * scale))
    # The band is cut to the lower word so the word sits inside it rather than
    # hanging off both ends of it.
    band = ribbon(round(rules.width * 1.34), round(rules.height * 0.86))

    width = max(house.width, band.width) + round(90 * scale)
    rules_y = house.height - round(38 * scale)
    height = rules_y + rules.height + round(30 * scale)
    layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    layer.alpha_composite(band, ((width - band.width) // 2,
                                 rules_y + (rules.height - band.height) // 2))
    layer.alpha_composite(house, ((width - house.width) // 2, 0))
    layer.alpha_composite(rules, ((width - rules.width) // 2, rules_y))

    shadow = Image.new("RGBA", (width, height + round(30 * scale)), (0, 0, 0, 0))
    shadow.paste(Image.new("RGBA", layer.size, (0, 0, 0, 190)),
                 (0, round(22 * scale)), layer.getchannel("A"))
    shadow = shadow.filter(ImageFilter.GaussianBlur(round(20 * scale)))
    shadow.alpha_composite(layer)
    return shadow.crop(shadow.getbbox())


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    mark = lockup(1.0)
    mark.save(OUT / "house_rules_logo.png", optimize=True)
    print("house_rules_logo.png", mark.size)

    plates = sorted(SOURCE.glob("keyart_stylised_*.png"))
    if not plates:
        print("no keyart_stylised_*.png yet; logo only")
        return 0
    art = Image.open(plates[-1]).convert("RGBA")
    side = art.width
    art = art.resize((side, side), Image.LANCZOS) if art.width != art.height else art
    wanted = int(art.width * 0.86)
    logo = mark.resize((wanted, round(mark.height * wanted / mark.width)), Image.LANCZOS)
    art.alpha_composite(logo, ((art.width - logo.width) // 2,
                               int(art.height * 0.97) - logo.height))
    art.convert("RGB").save(OUT / "house_rules_key_art.png", optimize=True)
    print("house_rules_key_art.png", art.size)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
