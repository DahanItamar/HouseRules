"""Build themed control-deck UI kit plates from the raw Higgsfield outputs.

    python tools/art/prepare_ui_kit.py

Raw outputs under assets/source/layered_v2/ui_kit/ are never modified.

Every plate is a nine-slice: a painted border with a flat centre that the deck
stretches. The generator leaves the centre softly lit and slightly transparent,
which shows as a bloom down the middle of a stretched key, so the centre is
repainted here as one flat opaque colour sampled just inside the rim.

The script prints the two numbers `UiKit` needs per plate -- the opaque bounds
of the art in source pixels, and the patch margin that keeps the painted corner
out of the stretched edge -- so those constants stay checkable.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/source/layered_v2/ui_kit"
OUT = ROOT / "assets/production/ui/kit"

## Raw output -> production file. Medallions keep their painted centre: the "?"
## is drawn on top in code, so there is nothing to stretch and nothing to flatten.
PLATES: list[tuple[str, str, bool]] = [
    ("button_harlequin_0066278b.png", "button_harlequin.png", True),
    ("panel_harlequin_b9ac3d1f.png", "panel_harlequin.png", True),
    ("medallion_harlequin_2bde3eee.png", "medallion_harlequin.png", False),
    ("button_corsair_64a2b660.png", "button_corsair.png", True),
    ("medallion_corsair_b320faa6.png", "medallion_corsair.png", False),
]


def opaque_bounds(image: Image.Image, floor: int = 24) -> tuple[int, int, int, int]:
    """The box that holds every texel the plate actually paints."""
    alpha = np.asarray(image.getchannel("A")) > floor
    ys, xs = np.nonzero(alpha)
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def harden(image: Image.Image, floor: float = 0.62) -> Image.Image:
    """Snaps the soft alpha shoulder the generator leaves around the plate.

    A plate is either painted or it is not; a half-transparent rim reads as a
    grey halo once the deck draws the plate over a lit backdrop.
    """
    pixels = np.asarray(image, dtype=np.float32) / 255.0
    alpha = pixels[..., 3]
    pixels[..., 3] = np.where(alpha >= floor, 1.0, 0.0)
    return Image.fromarray((pixels * 255.0).round().astype(np.uint8), "RGBA")


def centre_colour(image: Image.Image, bounds: tuple[int, int, int, int]) -> tuple[int, int, int]:
    """The flat fill, taken as the median of the middle of the plate."""
    left, top, right, bottom = bounds
    width, height = right - left, bottom - top
    patch = np.asarray(
        image.crop(
            (
                left + int(width * 0.34),
                top + int(height * 0.34),
                left + int(width * 0.66),
                top + int(height * 0.66),
            )
        ).convert("RGB"),
        dtype=np.uint8,
    )
    return tuple(int(v) for v in np.median(patch.reshape(-1, 3), axis=0))


def border_width(image: Image.Image, bounds: tuple[int, int, int, int], fill, tol: int = 26) -> int:
    """How deep the painted border runs, measured in from the rim.

    Walks the middle row inward from each edge until the paint settles to the
    centre colour, and takes the deepest of the four so a corner ornament is
    never caught in a stretched edge.
    """
    left, top, right, bottom = bounds
    rgb = np.asarray(image.convert("RGB"), dtype=np.int16)
    target = np.array(fill, dtype=np.int16)
    middle_y, middle_x = (top + bottom) // 2, (left + right) // 2
    limit = min(right - left, bottom - top) // 2 - 2
    depths: list[int] = []
    for line, start, step in (
        (rgb[middle_y], left, 1),
        (rgb[middle_y], right - 1, -1),
        (rgb[:, middle_x], top, 1),
        (rgb[:, middle_x], bottom - 1, -1),
    ):
        depth = 0
        while depth < limit:
            spot = start + step * depth
            if int(np.abs(line[spot] - target).max()) <= tol:
                break
            depth += 1
        depths.append(depth)
    # A little past where the paint settles, so the stretch starts on flat fill.
    return min(limit, max(depths) + 6)


def build(source: str, name: str, flatten: bool) -> None:
    plate = harden(Image.open(SOURCE / source).convert("RGBA"))
    bounds = opaque_bounds(plate)
    fill = centre_colour(plate, bounds)
    margin = border_width(plate, bounds, fill)
    if flatten:
        left, top, right, bottom = bounds
        centre = Image.new("RGBA", (right - left - margin * 2, bottom - top - margin * 2), fill + (255,))
        plate.paste(centre, (left + margin, top + margin))
    plate.save(OUT / name, optimize=True)
    left, top, right, bottom = bounds
    print(
        "%-24s region=Rect2(%d, %d, %d, %d) margin=%d fill=#%02x%02x%02x"
        % (name, left, top, right - left, bottom - top, margin, *fill)
    )


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    for source, name, flatten in PLATES:
        build(source, name, flatten)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
