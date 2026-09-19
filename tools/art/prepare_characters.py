"""Turn approved Higgsfield character outputs into clean runtime masters.

    python tools/art/prepare_characters.py tools/art/characters_v2.json

For every entry the tool keeps the full generation canvas (at least 1024x1536),
removes near-invisible alpha noise, bleeds edge colour into transparent texels
so linear filtering never pulls a dark or light matte into hair and hands,
optionally erases stray props with polygons, and aligns pose variants to their
base master so runtime cross-fades never jump. It prints each master's foot
pivot (normalised) so layouts can anchor feet exactly.

Optional colour keys keep one person's poses identical in colour and matched to
the room they appear in:

- ``"grade_to": {"image": room png, "rect": [x0, y0, x1, y1]}`` on a base entry
  fits the base's face-skin statistics (per-channel mean and spread) to the
  person's painted face in that room crop, and applies that linear room grade.
- ``"match_to": base output`` on a variant first fits the variant's face skin and
  head-to-torso colour to the ungraded base (undoing the edit model's exposure
  and white-balance drift), then applies the base's room grade.
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


def defringe(image: Image.Image, erode: int) -> Image.Image:
    """Remove the grey studio matte a background remover leaves on edges.

    The remover keeps the studio grey under transparent texels, so that grey is
    measured, un-mixed from partly transparent edge texels, and the alpha is
    pulled in by ``erode`` pixels with a soft rim so no light outline remains.
    """
    rgba = np.asarray(image.convert("RGBA"), dtype=np.float32)
    alpha = rgba[..., 3] / 255.0
    clear = alpha <= 0.0
    matte = np.median(rgba[..., :3][clear], axis=0) if clear.any() else np.zeros(3)
    edge = (alpha > 0.02) & (alpha < 0.98)
    colour = rgba[..., :3]
    unmixed = (colour - (1.0 - alpha[..., None]) * matte) / np.maximum(alpha[..., None], 0.02)
    colour[edge] = np.clip(unmixed[edge], 0.0, 255.0)
    mask = Image.fromarray((alpha * 255.0).astype(np.uint8))
    eroded = mask.filter(ImageFilter.MinFilter(erode * 2 + 1)).filter(ImageFilter.GaussianBlur(0.8))
    rgba[..., 3] = np.minimum(rgba[..., 3], np.asarray(eroded, dtype=np.float32))
    rgba[..., :3] = colour
    return Image.fromarray(rgba.clip(0, 255).astype(np.uint8), "RGBA")


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


def _skin_stats(rgb: np.ndarray, region: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Mean and spread of warm, lit skin-like texels inside ``region``."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    skin = region & (r > g) & (g > b) & (r - b > 0.06) & (r > 0.2)
    pixels = rgb[skin]
    if len(pixels) < 50:
        raise ValueError("too few skin texels to grade")
    return pixels.mean(axis=0), pixels.std(axis=0)


def head_skin_stats(image: Image.Image) -> tuple[np.ndarray, np.ndarray]:
    rgba = np.asarray(image.convert("RGBA"), dtype=np.float32) / 255.0
    solid = rgba[..., 3] > 0.98
    rows = np.where(solid.any(axis=1))[0]
    top, height = int(rows.min()), int(rows.max() - rows.min())
    centre = head_anchor(image)[0]
    region = np.zeros_like(solid)
    y0, y1 = top + int(height * 0.03), top + int(height * 0.13)
    x0, x1 = int(centre - image.width * 0.06), int(centre + image.width * 0.06)
    region[y0:y1, x0:x1] = True
    return _skin_stats(rgba[..., :3], region & solid)


def bust_stats(image: Image.Image) -> tuple[np.ndarray, np.ndarray]:
    """Mean and spread of every opaque texel from the head to mid-torso."""
    rgba = np.asarray(image.convert("RGBA"), dtype=np.float32) / 255.0
    solid = rgba[..., 3] > 0.98
    rows = np.where(solid.any(axis=1))[0]
    top, height = int(rows.min()), int(rows.max() - rows.min())
    region = np.zeros_like(solid)
    region[top:top + int(height * 0.42)] = True
    pixels = rgba[..., :3][region & solid]
    return pixels.mean(axis=0), pixels.std(axis=0)


def room_skin_stats(grade: dict) -> tuple[np.ndarray, np.ndarray]:
    room = np.asarray(Image.open(ROOT / grade["image"]).convert("RGB"), dtype=np.float32) / 255.0
    x0, y0, x1, y1 = grade["rect"]
    region = np.zeros(room.shape[:2], dtype=bool)
    region[y0:y1, x0:x1] = True
    return _skin_stats(room, region)


def fit(source: tuple[np.ndarray, np.ndarray],
        target: tuple[np.ndarray, np.ndarray]) -> tuple[np.ndarray, np.ndarray]:
    """Per-channel gain and offset that map the source statistics to the target."""
    gain = np.clip(target[1] / np.maximum(source[1], 1e-3), 0.5, 1.6)
    return gain, target[0] - gain * source[0]


def apply_fit(image: Image.Image, transform: tuple[np.ndarray, np.ndarray]) -> Image.Image:
    rgba = np.asarray(image.convert("RGBA"), dtype=np.float32) / 255.0
    rgba[..., :3] = np.clip(rgba[..., :3] * transform[0] + transform[1], 0.0, 1.0)
    return Image.fromarray((rgba * 255.0 + 0.5).astype(np.uint8), "RGBA")


def main(argv: list[str]) -> int:
    spec = json.loads(Path(argv[1]).read_text(encoding="utf-8"))
    bases: dict[str, Image.Image] = {}
    grades: dict[str, tuple[np.ndarray, np.ndarray]] = {}
    for entry in spec["characters"]:
        image = Image.open(ROOT / entry["source"]).convert("RGBA")
        if entry.get("defringe"):
            image = defringe(image, int(entry["defringe"]))
        if "align_to" in entry:
            image = align_to(image, bases[entry["align_to"]])
        image = clean_alpha(image, entry.get("erase"))
        bases[entry["output"]] = image
        if "grade_to" in entry:
            grades[entry["output"]] = fit(head_skin_stats(image), room_skin_stats(entry["grade_to"]))
            image = apply_fit(image, grades[entry["output"]])
        elif "match_to" in entry:
            base = entry["match_to"]
            # Skin and wardrobe are fitted together so face and clothes both match.
            skin = fit(head_skin_stats(image), head_skin_stats(bases[base]))
            bust = fit(bust_stats(image), bust_stats(bases[base]))
            image = apply_fit(image, ((skin[0] + bust[0]) * 0.5, (skin[1] + bust[1]) * 0.5))
            image = apply_fit(image, grades[base])
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
