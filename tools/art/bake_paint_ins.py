"""Bake painted-in guests into a room background, inside blocked zones only.

Guests who sit or stand inside a collision zone can never be reached, walked
behind or walked in front of by the player, so they are painted into the real
furniture by an image-edit model and baked into the background. Only pixels
inside the named zone polygons (plus optional extra rectangles) are taken from
each edit; the rest of the master is untouched. Each edit is aligned and colour
matched to the clean master before a feathered paste:

    python tools/art/bake_paint_ins.py tools/art/bake_main_floor.json

SPEC: {"source": clean upscale png, "output": production background png,
"layout": room layout json, "patches": [{"edited": edit png, "crop": [x, y, w,
h] virtual px, "zones": [solid names], "extra_rects": [[x0, y0, x1, y1]]}]}.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
MASTER = (3840, 2160)
SCALE = 4.0
FEATHER = 5.0


def _fit_colour(edited: np.ndarray, original: np.ndarray, sample: np.ndarray) -> np.ndarray:
    """Undo global colour drift; a misregistered edit yields an implausible fit,
    in which case the edit is left untouched rather than washed out."""
    fits = [np.polyfit(edited[..., c][sample], original[..., c][sample], 1) for c in range(3)]
    if any(not 0.8 <= gain <= 1.25 or abs(offset) > 0.08 for gain, offset in fits):
        print("  colour fit rejected", [tuple(round(float(v), 3) for v in fit) for fit in fits])
        return edited
    result = edited.copy()
    for channel, (gain, offset) in enumerate(fits):
        result[..., channel] = np.clip(edited[..., channel] * gain + offset, 0.0, 1.0)
    return result


def _best_shift(edited: np.ndarray, original: np.ndarray, sample: np.ndarray) -> tuple[int, int]:
    best = (np.inf, 0, 0)
    for dy in range(-8, 9):
        for dx in range(-8, 9):
            shifted = np.roll(np.roll(edited, dy, 0), dx, 1)
            err = np.abs(shifted - original).mean(axis=2)[sample].mean()
            if err < best[0]:
                best = (err, dx, dy)
    return best[1], best[2]


def main(argv: list[str]) -> int:
    spec = json.loads(Path(argv[1]).read_text(encoding="utf-8"))
    layout = json.loads((ROOT / spec["layout"]).read_text(encoding="utf-8"))
    solids = {entry["name"]: entry["points"] for entry in layout["solids"]}
    master = Image.open(ROOT / spec["source"]).convert("RGB")
    if master.size != MASTER:
        master = master.resize(MASTER, Image.LANCZOS)
    canvas = np.asarray(master, dtype=np.float32) / 255.0
    for patch in spec["patches"]:
        cx, cy, cw, ch = patch["crop"]
        x0, y0 = round(cx * SCALE), round(cy * SCALE)
        size = (round(cw * SCALE), round(ch * SCALE))
        edited = np.asarray(Image.open(ROOT / patch["edited"]).convert("RGB").resize(
            size, Image.LANCZOS), dtype=np.float32) / 255.0
        # Crops that ran past the canvas edge were padded; keep the real part.
        size = (min(size[0], MASTER[0] - x0), min(size[1], MASTER[1] - y0))
        edited = edited[:size[1], :size[0]]
        original = canvas[y0:y0 + size[1], x0:x0 + size[0]]
        mask_image = Image.new("L", size, 0)
        draw = ImageDraw.Draw(mask_image)
        for name in patch["zones"]:
            draw.polygon([((x - cx) * SCALE, (y - cy) * SCALE) for x, y in solids[name]], fill=255)
        for rx0, ry0, rx1, ry1 in patch.get("extra_rects", []):
            draw.rectangle([(rx0 - cx) * SCALE, (ry0 - cy) * SCALE,
                            (rx1 - cx) * SCALE, (ry1 - cy) * SCALE], fill=255)
        hard = np.asarray(mask_image) > 0
        outside = ~np.asarray(mask_image.filter(ImageFilter.MaxFilter(41))).astype(bool)
        if outside.sum() < 1000:
            outside = ~hard
        small = (slice(None, None, 4), slice(None, None, 4))
        dx, dy = _best_shift(edited[small], original[small], outside[small])
        edited = np.roll(np.roll(edited, dy * 4, 0), dx * 4, 1)
        edited = _fit_colour(edited, original, outside)
        feather = mask_image.filter(ImageFilter.MinFilter(3)).filter(
            ImageFilter.GaussianBlur(FEATHER))
        alpha = (np.asarray(feather, dtype=np.float32) / 255.0)[..., None]
        canvas[y0:y0 + size[1], x0:x0 + size[0]] = edited * alpha + original * (1.0 - alpha)
        print(f"baked {patch['edited']} shift=({dx * 4},{dy * 4}) zones={patch['zones']}")
    out = Image.fromarray((np.clip(canvas, 0, 1) * 255.0 + 0.5).astype(np.uint8), "RGB")
    out.save(ROOT / spec["output"], optimize=True)
    print("wrote", spec["output"])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
