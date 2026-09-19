"""Turn approved Higgsfield character outputs into clean runtime masters.

    python tools/art/prepare_characters.py tools/art/characters_v2.json

For every entry the tool keeps the full generation canvas (at least 1024x1536),
removes near-invisible alpha noise, bleeds edge colour into transparent texels
so linear filtering never pulls a dark or light matte into hair and hands,
optionally erases stray props with polygons, and aligns pose variants to their
base master so runtime cross-fades never jump. It prints each master's foot
pivot (normalised) so layouts can anchor feet exactly.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
ALPHA_FLOOR = 10


def clean_alpha(image: Image.Image, erase: list[list[list[float]]] | None = None) -> Image.Image:
    rgba = np.asarray(image.convert("RGBA"), dtype=np.float32)
    alpha = rgba[..., 3]
    alpha[alpha < ALPHA_FLOOR] = 0.0
    if erase:
        mask = Image.new("L", image.size, 0)
        draw = ImageDraw.Draw(mask)
        for polygon in erase:
            draw.polygon([(x * image.width, y * image.height) for x, y in polygon], fill=255)
        mask = mask.filter(ImageFilter.GaussianBlur(1.5))
        alpha *= 1.0 - np.asarray(mask, dtype=np.float32) / 255.0
    # Keep only the largest connected figure: generators sometimes leave specks.
    solid = alpha > 32
    rgba[..., 3] = alpha
    return _bleed(Image.fromarray(rgba.clip(0, 255).astype(np.uint8), "RGBA"), solid)


def _bleed(image: Image.Image, _solid: np.ndarray) -> Image.Image:
    """Extend edge colours outward under zero alpha (no visible change)."""
    rgba = np.asarray(image, dtype=np.float32)
    colour = rgba[..., :3].copy()
    weight = (rgba[..., 3] > 0).astype(np.float32)
    acc = colour * weight[..., None]
    for _ in range(12):
        blurred = np.asarray(Image.fromarray((acc).clip(0, 255).astype(np.uint8)).filter(
            ImageFilter.BoxBlur(2)), dtype=np.float32)
        wblur = np.asarray(Image.fromarray((weight * 255).astype(np.uint8)).filter(
            ImageFilter.BoxBlur(2)), dtype=np.float32) / 255.0
        fill = (weight <= 0) & (wblur > 0.001)
        acc[fill] = (blurred[fill] / np.maximum(wblur[fill, None], 1e-3))
        weight[fill] = 1.0
    out = rgba.copy()
    empty = rgba[..., 3] <= 0
    out[empty, :3] = acc[empty].clip(0, 255)
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def foot_pivot(image: Image.Image) -> tuple[float, float]:
    alpha = np.asarray(image.getchannel("A"), dtype=np.uint8)
    rows = np.where((alpha > 128).any(axis=1))[0]
    bottom = int(rows.max())
    band = alpha[max(0, bottom - 24):bottom + 1] > 128
    xs = np.where(band.any(axis=0))[0]
    return ((xs.min() + xs.max()) / 2.0 / image.width, (bottom + 1) / image.height)


def head_anchor(image: Image.Image) -> np.ndarray:
    """Centre of the topmost opaque mass (hair/head), used to align variants."""
    alpha = np.asarray(image.getchannel("A"), dtype=np.uint8) > 128
    rows = np.where(alpha.any(axis=1))[0]
    top = int(rows.min())
    band = alpha[top:top + int(image.height * 0.08)]
    ys, xs = np.nonzero(band)
    return np.array([xs.mean(), top + ys.mean()])


def align_to(image: Image.Image, base: Image.Image) -> Image.Image:
    if image.size != base.size:
        # Match heights without distorting proportions, then centre.
        width = round(image.width * base.height / image.height)
        scaled = image.resize((width, base.height), Image.LANCZOS)
        image = Image.new("RGBA", base.size, (0, 0, 0, 0))
        image.paste(scaled, ((base.width - width) // 2, 0))
    shift = head_anchor(base) - head_anchor(image)
    dx, dy = int(round(shift[0])), int(round(shift[1]))
    if abs(dx) > base.width * 0.06 or abs(dy) > base.height * 0.06:
        return image  # the head moved on purpose; keep the generator framing
    out = Image.new("RGBA", base.size, (0, 0, 0, 0))
    out.paste(image, (dx, dy))
    return out


def main(argv: list[str]) -> int:
    spec = json.loads(Path(argv[1]).read_text(encoding="utf-8"))
    bases: dict[str, Image.Image] = {}
    for entry in spec["characters"]:
        image = Image.open(ROOT / entry["source"]).convert("RGBA")
        if "align_to" in entry:
            image = align_to(image, bases[entry["align_to"]])
        image = clean_alpha(image, entry.get("erase"))
        bases[entry["output"]] = image
        # A transparent border guarantees clear corners even when the figure is
        # framed to the canvas edge (the dealer stops at mid-thigh).
        padded = Image.new("RGBA", (image.width + 32, image.height + 32), (0, 0, 0, 0))
        padded.paste(image, (16, 16))
        image = _bleed(padded, np.zeros(1))
        target = ROOT / entry["output"]
        target.parent.mkdir(parents=True, exist_ok=True)
        image.save(target, optimize=True)
        pivot = foot_pivot(image)
        corners = [image.getpixel(p)[3] for p in
                   ((0, 0), (image.width - 1, 0), (0, image.height - 1),
                    (image.width - 1, image.height - 1))]
        print(f"{entry['output']}: {image.size} pivot=({pivot[0]:.3f}, {pivot[1]:.3f}) "
              f"corner_alpha={corners}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
